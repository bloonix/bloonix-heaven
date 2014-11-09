package Bloonix::Heaven::Route;

use strict;
use warnings;
use Log::Handler;
use base qw(Bloonix::Accessor);

__PACKAGE__->mk_accessors(qw/c log/);

sub new {
    my ($class, $c) = @_;

    my $self = bless {
        c => $c,
        log => $c->log,
        routes => { }
    }, $class;

    return $self;
}

sub maps {
    my ($self, @targets) = @_;
    my ($caller) = caller;

    $self->{__route} = undef;
    $self->{__routes} = undef;
    $self->{__args} = undef;

    $self->log->info("routes from caller $caller", @targets);

    foreach my $target (@targets) {
        my $route;

        if ($target =~ /^[a-z_]+\z/) {
            my $controller = join("::", $self->c->base, "Controller");
            $target = join("::", $caller, $target);
            $target =~ s/^${controller}:://;
            $route = $target;
            $route =~ s/^${controller}:://;
        } else {
            $route = $target;
        }

        $route =~ s!::!/!g;
        $route =~ tr/A-Z/a-z/;
        $route = "/$route";

        $self->map($route)->to($target);
    }
}

sub map {
    my ($self, $route) = @_;
    my $routes = $self->{routes};
    $self->{_route} = $route;

    if ($route eq "/") {
        $route = "index";
    } elsif ($route !~ m!^/!) {
        my ($caller) = caller;
        my $controller = join("::", $self->c->base, "Controller");
        $caller =~ s/^${controller}:://;
        $caller =~ s!::!/!g;
        $caller =~ tr!A-Z!a-z!;
        $route = "/$caller/$route";
    }

    $route =~ s!^/!!;
    $route =~ s!/\z!!;

    foreach my $path (split /\//, $route) {
        if ($path =~ /^:/) {
            if (!exists $routes->{match_by_alias}->{$path}) {
                my $new_match = { };
                $routes->{match_by_alias}->{$path} = $new_match;
                push @{$routes->{match}}, $new_match;
            }
            $routes = $routes->{match_by_alias}->{$path};
        } else {
            $routes->{route}->{$path} //= { };
            $routes = $routes->{route}->{$path};
        }
    }

    $self->{_routes} = $routes;
    return $self;
}

sub to {
    my ($self, $target) = @_;

    my ($caller) = caller;
    my $route = $self->{_route};
    my $routes = $self->{_routes};
    my ($action, $controller);

    $self->log->info("route $route to $target caller $caller");

    if ($target =~ /^[a-z_]+\z/) {
        $action = $target;
        ($controller) = $caller;
    } else {
        my @targets = split /::/, $target;
        $action = pop @targets;
        $controller = join("::", $self->c->base, "Controller", @targets);
    }

    $routes->{to} = {
        controller => $controller,
        action => $action
    };

    if ($self->{_args}) {
        $routes->{to}->{args} = $self->{_args};
    }

    $self->c->{_controller}->{$controller} //= { };
    $self->{_routes} = $routes;
    return $self;
}

sub args {
    my $self = shift;
    my $opts = @_ > 1 ? {@_} : shift;

    if ($self->{_routes}) {
        $self->{_routes}->{to}->{args} = $opts;
    } else {
        $self->{_args} = $opts;
    }

    return $self;
}

sub init {
    my ($self, $routes) = @_;
    $routes //= $self->{routes};

    if (exists $routes->{route}) {
        foreach my $action (keys %{$routes->{route}}) {
            $self->init($routes->{route}->{$action});
        }
    }

    if (exists $routes->{match_by_alias}) {
        my $matches = delete $routes->{match_by_alias};

        foreach my $match (keys %$matches) {
            my ($regex, $alias);

            if ($match eq ":id" || $match =~ /^:[\w\-]+_id\z/) {
                $alias = do { $match =~ /^:(.+)/; $1 };
                $regex = qr/^([1-9]\d{0,18})\z/;
            } elsif ($match =~ /^:([\w\-]+)(\(.+?\))\z/) {
                $alias = $1;
                $regex = qr/^$2\z/;
            } elsif ($match =~ /^:(\(.+?\))\z/) {
                $alias = undef;
                $regex = qr/^$1\z/,
            } else {
                $alias = do { $match =~ /^:(.+)/; $1 };
                $regex = qr/^(.+)\z/;
            }

            $matches->{$match}->{alias} = $alias;
            $matches->{$match}->{regex} = $regex;
        }
    }

    if (exists $routes->{match}) {
        foreach my $match (@{$routes->{match}}) {
            $self->init($match);
        }
    }
}

sub parse {
    my ($self, @path) = @_;
    my $routes = $self->{routes};

    PATH:
    while (@path) {
        my $route = $routes->{route};
        my $match = $routes->{match};
        my $path = shift @path;

        if (exists $route->{$path}) {
            $routes = $route->{$path};
            next PATH;
        }

        if ($match) {
            foreach my $m (@$match) {
                if ($path =~ $m->{regex}) {
                    if (defined $m->{alias}) {
                        $self->c->args->{$m->{alias}} = $1;
                    }
                    $routes = $m;
                    next PATH;
                }
            }
        }

        unshift @path, $path;
        last;
    }

    if (@path || !exists $routes->{to}) {
        $self->log->info("no route matched");
        $self->c->controller($self->c->root);
        $self->c->action("default");
        $self->c->action_path("default");
    } else {
        $self->c->controller($routes->{to}->{controller});
        $self->c->action($routes->{to}->{action});
        if ($routes->{args}) {
            foreach my $key (keys %{$routes->{args}}) {
                if (!defined $self->c->args->{$key}) {
                    $self->c->args->{$key} = $routes->{args}->{$key};
                }
            }
        }
    }
}

1;

=head1 NAME

Bloonix::Heaven::Route - The heaven route handler.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=head2 init

=head2 maps

=head2 map

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

=head2 args

=head2 parse

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut
