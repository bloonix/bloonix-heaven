package Bloonix::Heaven;

use strict;
use warnings;
use Bloonix::Config;
use Bloonix::HangUp;
use Bloonix::FCGI;
use Bloonix::ProcManager;
use Bloonix::Validator;
use Bloonix::Timezone;
use Getopt::Long qw(:config no_ignore_case);
use Log::Handler;
use Params::Validate qw();
use POSIX qw(getgid getuid setgid setuid);
use JSON;

use Bloonix::Heaven::Route;
use Bloonix::Heaven::Plugin;
use Bloonix::Heaven::Response;
use Bloonix::Heaven::Stash;
use Bloonix::Heaven::Session;
use Bloonix::Heaven::Model;
use Bloonix::Heaven::View;
use Bloonix::Heaven::Template;

our $VERSION = "0.13";

use base qw(Bloonix::Heaven::Accessor);
__PACKAGE__->mk_accessors(qw/model view controller base root/);
__PACKAGE__->mk_accessors(qw/action action_path auto args route/);
__PACKAGE__->mk_accessors(qw/config config_base log plugin/);
__PACKAGE__->mk_accessors(qw/proc proc_helper fcgi req request res response version/);
__PACKAGE__->mk_accessors(qw/stash session user lang text validator tz json/);

sub run {
    my $class = shift;
    my $self = bless { version => {} }, $class;

    # Init the machine
    $self->__init;

    # Exception handler
    $self->log->info("set die and warn handler");
    local $SIG{__DIE__} = sub { $self->log->trace(error => @_) };
    local $SIG{__WARN__} = sub { $self->log->trace(warning => @_) };

    $self->log->info("load fcgi manager");
    my $fcgi = Bloonix::FCGI->new($self->config->{fcgi_server});
    $self->fcgi($fcgi);

    # ProcManager handles sig HUP, TERM, INT, USR1, USR2
    $self->log->info("load proc manager");
    my $proc = Bloonix::ProcManager->new($self->config->{proc_manager});
    $self->proc($proc);

    # Go Bloonix go :-)
    $self->log->info("start processing");

    # Reload is ignored
    while (!$proc->done) {
        $proc->reload(0);
        $proc->set_status_waiting;

        if ($fcgi->accept) {
            $proc->set_status_reading;
            my $cgi = $fcgi->get_new_cgi;

            if ($cgi) {
                if ($self->__is_server_status($cgi, $proc)) {
                    next;
                }

                $proc->set_status_processing(
                    client  => $cgi->remote_addr,
                    request => join(" ", $cgi->request_method, $cgi->request_uri)
                );

                eval { $self->__dispatch_request($cgi) };

                if ($@) {
                    $self->__sw_error($@);
                }
            }
        }

        # Falling back to the default timezone
        # before processing the next request.
        $ENV{TZ} = $self->config->{system}->{timezone};
    }
}

sub load {
    my ($self, $controller) = @_;

    $controller = join("::",
        $self->base,
        "Controller",
        $controller
    );

    $self->{_controller}->{$controller} //= { };
}

sub __init {
    my $self = shift;

    eval {
        $self->__load_argv(@_);
        $self->__load_config;
        $self->__validate_config;
        $self->__load_permissions;
        $self->__load_logger;
        $self->__load_plugin;
        $self->__init_app;
        $self->__load_model;
        $self->__load_view;
        $self->__load_controller;
        $self->__init_routes;
    };

    if ($@) {
        print STDERR $@;
        if ($self->log) {
            $self->log->error($@);
        }
        exit 9;
    }
}

sub __load_argv {
    my ($self, @args) = @_;
    my $class = ref $self;
    my ($config_file, $pid_file, $help);
    my $progname = do { $0 =~ m!([^/]+)\z!; $1 };

    if (!@args) {
        @args = @ARGV;
    }

    Getopt::Long::GetOptionsFromArray(\@args,
        "c|config-file=s" => \$config_file,
        "p|pid-file=s" => \$pid_file,
        "h|help" => \$help,
    ) or exit 1;

    if ($help) {
        print "Usage: $progname [ options ]\n";
        print "-c, --config-file <config>\n";
        print "    The configuration file.\n";
        print "-p, --pid-file <file>\n";
        print "    Where to store the daemon pid.\n";
        print "-h, --help\n";
        print "    Print the help.\n";
        exit 0;
    }

    if (!$config_file) {
        print "ERR: missing mandatory parameter --config-file\n";
        exit 1;
    }

    if (!-e $config_file) {
        print "ERR: the configuration file '$config_file' does not exists\n";
        exit 1;
    }

    if (!$pid_file) {
        print "ERR: missing mandatory parameter --pid-file\n";
        exit 1;
    }

    $self->{config_base} = $self->{config_file} = $config_file;
    $self->{config_base} =~ s!/[^/]+\z!!;
    $self->{pid_file} = $pid_file;
}

sub __load_permissions {
    my $self = shift;

    Bloonix::HangUp->now(
        user => $self->config->{system}->{user},
        group => $self->config->{system}->{group},
        pid_file => $self->{pid_file}
    );
}

sub __load_config {
    my $self = shift;

    $self->{config} = Bloonix::Config->parse(
        $self->{config_file}
    );

    if ($self->config->{log}) {
        $self->config->{logger} = delete $self->config->{log};
    }

    if (!$self->config->{system}->{timezone}) {
        my $timezone;

        if (open my $fh, "<", "/etc/timezone") {
            $timezone = <$fh>;
            chomp $timezone;
            close $fh;
        } else {
            $timezone = "Europe/Berlin";
        }

        # Set the default timezone!
        $self->config->{system}->{timezone} = $timezone;
    }

    $ENV{TZ} = $self->config->{system}->{timezone};
}

sub __validate_config {
    my $self = shift;
    my $config = $self->config;

    if (!$config->{proc_manager}) {
        die "missing proc manager configuration";
    }

    if (!$config->{fcgi_server}) {
        die "missing fcgi server configuration";
    }

    if (!$config->{proc_manager}->{lockfile}) {
        $config->{proc_manager}->{lockfile} = "/var/lib/bloonix/ipc/webgui.%P.lock";
    }

    $config->{server_status} ||= {};
    $config->{server_status} = $self->__validate_server_status($config->{server_status});
}

sub __validate_server_status {
    my $self = shift;

    my %opts = Params::Validate::validate(@_, {
        enabled => {
            type => Params::Validate::SCALAR,
            default => "yes",
            regex => qr/^(0|1|no|yes)\z/
        },
        allow_from => {
            type => Params::Validate::SCALAR,
            default => "127.0.0.1"
        },
        authkey => {
            type => Params::Validate::SCALAR,
            optional => 1
        }
    });

    if ($opts{enabled} eq "no") {
        $opts{enabled} = 0;
    }

    $opts{allow_from} =~ s/\s//g;
    $opts{allow_from} = {
        map { $_, 1 } split(/,/, $opts{allow_from})
    };

    return \%opts;
}

sub __load_logger {
    my $self = shift;
    my $class = ref($self);
    my $config = $self->{config}->{logger};

    if (!$config) {
        $config = {
            screen => {
                log_to   => "STDERR",
                maxlevel => "debug",
                minlevel => "emerg",
                message_layout => "(%t) %m",
            },
        };
    }

    $self->log(Log::Handler->create_logger("bloonix"));
    $self->log->set_default_param(die_on_errors => 0);
    $self->log->set_pattern("%X", "user_id", "n/a");
    $self->log->set_pattern("%Y", "username", "n/a");
    $self->log->config(config => $config);
    $self->log->info("-- heaven logger initialized");
}

sub __load_plugin {
    my $self = shift;

    $self->{plugin} = Bloonix::Heaven::Plugin->new($self);
}

sub __init_app {
    my $self = shift;

    $self->tz(Bloonix::Timezone->new);
    $self->json(JSON->new);
    $self->route(Bloonix::Heaven::Route->new($self));
    $self->base($self->config->{heaven}->{app} || ref($self));
    $self->root(join("::", $self->base, "Controller", "Root"));
    $self->init();
}

sub __init_routes {
    my $self = shift;

    $self->route->init;
    $self->log->info("all routes loaded");
}

sub __load_model {
    my $self = shift;

    $self->{model} = Bloonix::Heaven::Model->new($self);

    if ($self->config->{heaven}->{model}) {
        foreach my $model (split /\s*,\s*/, $self->config->{heaven}->{model}) {
            my $module = join("::", $self->base, "Model", $model);
            my $accessor = lc($model);
            my $config = $self->config->{$module} || $self->config->{$accessor};
            $self->log->info("load model $module");
            $self->model->load($accessor => $module => $config);
        }
    }
}

sub __load_view {
    my $self = shift;

    $self->{view} = Bloonix::Heaven::View->new($self);

    if ($self->config->{heaven}->{view}) {
        foreach my $view (split /\s*,\s*/, $self->config->{heaven}->{view}) {
            if ($view eq "Template") {
                $self->log->info("load view Bloonix::Heaven::Template");
                $self->view->load("template", "Bloonix::Heaven::Template", $self->config->{template});
            } else {
                my $module = join("::", $self->base, "View", $view);
                my $accessor = lc($view);
                my $config = $self->config->{$module} || $self->config->{$accessor};
                $self->log->info("load view $module");
                $self->view->load($accessor => $module => $config);
            }
        }
    }
}

sub __load_controller {
    my $self = shift;

    foreach my $controller (keys %{$self->{_controller}}) {
        $self->log->info("load controller $controller");
        eval "use $controller";

        if ($@) {
            $self->log->die(error => "unable to load controller $controller - $@");
        }

        my $obj = $controller->can("new")
            ? $controller->new($self, $self->config->{$controller})
            : bless { }, $controller;

        if ($controller->can("startup")) {
            $self->log->info("startup controller $controller");
            $obj->startup($self);
        }

        foreach my $method (qw/auto begin end/) {
            if ($controller->can($method)) {
                $self->log->info("found method $method of controller $controller");
                $self->{_controller}->{$controller}->{$method} = 1;
            }
        }

        if ($controller eq $self->root) {
            foreach my $method (qw/default error/) {
                if (!$controller->can($method)) {
                    die "mandatory method $method does not exists in root controller";
                }
            }
        }

        $self->{_controller}->{$controller}->{object} = $obj;
    }

    $self->log->info("all controller loaded");
}

sub __is_server_status {
    my ($self, $cgi, $proc) = @_;

    my $status = $self->config->{server_status}
        or return undef;

    if ($status->{enabled} && $cgi->path_info eq "/server-status") {
        my $addr = $cgi->remote_addr || "n/a";
        my $authkey = $cgi->param("authkey") || "";
        my $plain = defined $cgi->param("plain") ? 1 : 0;
        my $pretty = defined $cgi->param("pretty") ? 1 : 0;
        my $allow_from = $status->{allow_from};

        $proc->set_status_processing(
            client  => $addr,
            request => "/server-status"
        );

        if ($allow_from->{all} || $allow_from->{$addr} || ($self->{authkey} && $self->{authkey} eq $authkey)) {
            $self->log->info("server status request from $addr - access allowed");
            $proc->set_status_sending;

            if ($plain) {
                print "Content-Type: text/plain\n\n";
                print $proc->get_plain_server_status;
            } else {
                print "Content-Type: application/json\n\n";
                print $proc->get_json_server_status(pretty => $pretty);
            }
        } else {
            $self->log->warning("server status request from $addr - access denied");
            print "Content-Type: text/plain\n\n";
            print "access denied\n";
        }

        return 1;
    }

    return undef;
}

sub __dispatch_request {
    my ($self, $cgi) = @_;
    my $path = $cgi->path_info;

    $self->log->notice("***** start to dispatch request $path *****");
    $self->__init_request($cgi);
    $self->__process_path_info($path);
    $self->__process_controller;
    $self->__process_view;
    $self->__process_output;
    $self->__process_size;
    $self->log->notice("end processing request $path");
}

sub __init_request {
    my ($self, $cgi) = @_;
    my $log = $self->log;

    # Initialize request based things
    $self->{action} = undef;
    $self->{auto} = [ ];
    $self->{args} = { };
    $self->{user} = { };
    $self->{lang} = { };
    $self->{stash} = Bloonix::Heaven::Stash->new;
    $self->{session} = Bloonix::Heaven::Session->new;
    $self->{req} = $self->{request}  = $cgi;
    $self->{res} = $self->{response} = Bloonix::Heaven::Response->new($cgi, $log);
    $self->{validator} = Bloonix::Validator->new;
    $self->log->set_pattern("%X", "user_id", "0");
    $self->log->set_pattern("%Y", "username", "n/a");
    $self->view->render("");
}

sub __process_path_info {
    my ($self, $path) = @_;

    $self->log->info("starting request for $path");
    $path =~ s!/+!/!g;
    $path =~ s!^/!!;
    $path =~ s!/\z!!;

    my @parts = split /\//, $path;

    if (@parts == 0) {
        push @parts, "index";
    }

    $self->action_path(join("/", @parts));
    $self->log->info("action path", $self->action_path);
    #$self->log->dump(info => $self->route->{routes});
    #$self->log->dump(info => \@parts);

    $self->route->parse(@parts);
    $self->__load_auto_path;

    $self->log->info("--> controller:", $self->controller);
    $self->log->info("--> action:", $self->action);
    $self->log->info("--> action path:", $self->action_path);
    $self->log->info("--> auto path:", join(", ", reverse @{$self->auto}) || "no paths");
}

sub __load_auto_path {
    my $self = shift;
    my $controller = $self->controller;
    my $exists = $self->{_controller};
    my $root_controller = $exists->{$self->root};

    while ($controller) {
        if ($exists->{$controller}) {
            my $c = $exists->{$controller};
            if ($c->{auto}) {
                push @{$self->{auto}}, $controller;
            }
        }
        $controller =~ s!:*[^:]*\z!!;
    }

    if ($root_controller->{auto} && $self->controller ne $self->root) {
        push @{$self->{auto}}, $self->root;
    }
}

sub __process_controller {
    my $self = shift;

    if ($self->__process_auto_path) {
        $self->__process_action_controller;
    }
}

sub __process_auto_path {
    my $self = shift;
    my $auto = $self->auto;
    my $controller = $self->{_controller};
    my $root_controller = $self->{_controller}->{$self->root};
    my @args = scalar keys %{$self->args} ? ($self->args) : ();
    my $success = 1;

    if (@$auto) {
        foreach my $auto_controller (reverse @$auto) {
            $self->log->info("execute $auto_controller -> auto()");

            my $ret;
            eval {
                $ret = $controller->{$auto_controller}->{object}->auto($self, @args);
            };

            if ($@) {
                $self->log->info("auto() of $auto_controller died - $@");
                eval { $root_controller->{object}->error($self, @args) };

                if ($@) {
                    $self->__internal_error;
                }

                $success = 0;
                last;
            }

            if (!$ret) {
                $self->log->info("auto() of $auto_controller was not successful");
                $success = 0;
                last;
            }
        }
    }

    return $success;
}

sub __process_action_controller {
    my $self = shift;
    my $controller = $self->controller;
    my $action = $self->action;
    my $action_controller = $self->{_controller}->{$controller};
    my $root_controller = $self->{_controller}->{$self->root};
    my @args = scalar keys %{$self->args} ? ($self->args) : ();
    my $ret;

    $self->log->info("process action controller $controller");

    eval {
        my $begin_success = 1;

        if ($action_controller->{begin}) {
            $self->log->info("execute $controller -> begin()");
            $begin_success = $action_controller->{object}->begin($self, @args);
        }

        if ($begin_success) {
            $self->log->info("execute $controller -> $action()");
            $action_controller->{object}->$action($self, @args);
        }

        if ($action_controller->{end}) {
            $self->log->info("execute $controller -> end()");
            $action_controller->{object}->end($self, @args);
        }
    };

    if ($@) {
        $self->log->error("execution of $controller action $action died:", $@);

        eval { $root_controller->{object}->error($self, @args) };

        if ($@) {
            $self->__internal_error;
        }
    }

    eval {
        if ($root_controller->{end}) {
            $root_controller->{object}->end($self, @args);
        }
    };

    if ($@) {
        $self->log->error("execution of root controller method clear died:", $@);
        $self->__internal_error;
    }
}

sub __process_view {
    my $self  = shift;

    # Do not process the view if a redirect is active!
    if (!$self->res->redirect_active && $self->view) {
        $self->log->info("process view");

        eval { $self->view->process($self) };

        if ($@) {
            $self->__internal_error;
        }
    }
}

sub __process_output {
    my $self = shift;

    $self->res->process($self);
}

sub __process_size {
    my $self = shift;

    # stats are maybe not available
    if ($self->proc->statm) {
        if ($self->proc->statm->{resident} && $self->proc->statm->{resident} > 0) {
            $self->log->notice(
                "current process size:",
                sprintf("%.1fMB", $self->proc->statm->{resident} / 1048576)
            );
        }
    }
}

sub __internal_error {
    my $self = shift;

    $self->{stash} = Bloonix::Heaven::Stash->new;
    $self->log->info("execute error handler");
    $self->view->render->plain;
    $self->res->content_type("text/html");
    $self->res->body(
        join("\n",
            '<!DOCTYPE html>',
            '<html lang="en">',
            '<head>',
            '    <title>Internal error</title>',
            '    <meta http-equiv="content-type" content="text/html; charset=UTF-8">',
            '</head>',
            '<body style="background-color: #bbbbbb; padding: 1em;">',
            '<div style="background-color: #775555; padding: 1em;">',
            '<div style="background-color: #eeeeee; padding: 1em;">',
            '<pre>',
            '(en) Please come back later',
            '(fr) SVP veuillez revenir plus tard',
            '(es) Por favor, vuelva más tarde',
            '(de) Bitte versuchen sie es spaeter nocheinmal',
            "(at) Konnten's bitt'schoen spaeter nochmal reinschauen",
            '(no) Vennligst prov igjen senere',
            '(dk) Venligst prov igen senere',
            '(pl) Prosze sprobowac pozniej',
            '(pt) Por favor volte mais tarde',
            '(ru) Попробуйте еще раз позже',
            '(ua) Спробуйте ще раз пізніше',
            '(cn) 請稍後再來',
            '</pre>',
            '</div>',
            '</div>',
            '</body>',
            '</html>',
        )
    );
}

# If really all goes wrong...
sub __sw_error {
    my ($self, $error) = @_;

    $self->log->error("err:", $error);

    if (!$self->response->content_type_printed) {
        print "Content-Type: text/html\n\n";
    }

    print "<h1>Internal software error!</h1>\n";
    print "<h3>Please contact the administrator.</h3>\n";    
}

1;

=head1 NAME

Bloonix::Heaven - A tiny MVC webframework.

=head1 SYNOPSIS

    package MyApp;
    use strict;
    use warnings;
    use base qw(Bloonix::Heaven);

    our $VERSION = "0.1";

    sub init {
        my $self = shift;

        $self->plugin->load(form => "Bloonix::Heaven::Plugin::Foo");
        $self->plugin->load(user => "Bloonix::Heaven::Plugin::Bar");
        $self->plugin->load(util => "Bloonix::Heaven::Plugin::Baz");
    }

=head1 DESCRIPTION

=head1 ORDER

The order to execute a action is

    Root        ->  auto
    Controller  ->  auto
    Controller  ->  begin
    Controller  ->  action
    Controller  ->  end
    Root        ->  end

Each auto() method is executed on the way to the action.

As example if the URL path /foo/bar/baz/action routes to
MyApp::Controller::Foo::Bar::Baz::action(), the execution order is

    MyApp::Controller::Root::auto()
    MyApp::Controller::Foo::auto()
    MyApp::Controller::Foo::Bar::auto()
    MyApp::Controller::Foo::Bar::Baz::auto()
    MyApp::Controller::Foo::Bar::Baz::begin()
    MyApp::Controller::Foo::Bar::Baz::action()
    MyApp::Controller::Foo::Bar::Baz::end()
    MyApp::Controller::Root::end()

If any auto() method returns false, the order is aborted.

If a path does not match, then

    Root::default()

is executed. If an error occurs, then

    Root::error()

is executed.

=head1 METHODS

=head2 run

=head2 model

=head2 view

=head2 controller

=head2 action

=head2 action_path

=head2 config

=head2 log

=head2 logaction

=head2 plugin

=head2 req, request

=head2 res, response

=head2 stash

=head2 lang

=head2 user

=head2 route

=over 4

=item Route with no capture

    /hello/foo/world
    /hello/bar/world
    /hello/baz/world

    /hello/:(foo|bar)/world

=item Route with caputes

    /user/1/edit

    /user/:id/edit

The placeholder :id has the feature that it must be a number and
it's not allowed that the number starts with 0. The same applies
to placeholders that ends with _id.

=item Route with a captured regular expression

    /hello/foo
    /hello/bar
    /hello/baz

    /hello/:name(foo|bar|baz)

=item Complex routes

    /user/:id/:drink(beer|cola)/:eat(steak|chips)/at/:(home|restaurant)

=back

=head2 to

=head2 load

=head2 root

=head2 base

=head1 EXPORTS

No exports.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009 by Jonny Schulz. All rights reserved.

=cut
