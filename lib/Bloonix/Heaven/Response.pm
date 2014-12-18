=head1 NAME

Bloonix::Heaven::Response - Stores header data for the client response.

=head1 SYNOPSIS

    $c->res->cookie($name => $value);

    $c->res->header($name => $value);

    $c->res->redirect($location);

    $c->res->body($body);

    $c->res->content_type("text/html");

    $c->res->content_type_printed(1);

=head1 DESCRIPTION

=head1 METHODS

=head2 new, process

This methods are only for internal usage.

C<new> is called for each new request and C<process>
is called to send the header and body to the client.

=head2 cookie

Set a CGI cookie via

    $c->res->cookie(
        -name  => "foo",
        -value => "bar",
    );

=head2 header

Set additional header parameters:

    $c->res->header($name => $value);

=head2 redirect

Redirect via 302

    $c->res->redirect($location);

=head2 body

Pass the body to print to the client:

    $c->res->body($body);

=head2 content_type

Set the content type of the body:

    $c->res->content_type("text/html");

=head2 content_type_printed

If the content type was already printed to the client:

    $c->res->content_type_printed(1);

=head2 dump_body_to

Dump the body to a file before the body is send to the client.

    $c->res->dump_body_to($filename);

=head2 json

If you want to send data as json, then you can pass a reference
to a perl object. The object is encoded into a json string and
send to the browser with content type application/json and the
charset utf8.

    $c->res->json({ hello => world });

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Heaven::Response;

use strict;
use warnings;
use JSON;

use base qw(Bloonix::Heaven::Accessor);
__PACKAGE__->mk_accessors(qw/body cgi log content_type content_type_printed is_json redirect_active/);

sub new {
    my ($class, $cgi, $log) = @_;

    my $self = bless {
        cgi => $cgi,
        log => $log,
        body => "",
        header => {},
        content_type => "text/html",
        content_type_printed => 0,
        redirect_active => 0
    }, $class;

    return $self;
}

sub cookie {
    my ($self, @params) = @_;
    my $header = $self->{header};

    my $cookie = $self->{cgi}->cookie(@params);
    push @{$header->{cookies}}, $cookie;

    return $cookie;
}

sub redirect {
    my ($self, $location, $status) = @_;
    $location ||= "/";
    $status ||= 302;
    $self->{redirect_active} = 1;
    $self->{header}->{status} = "$status Found";
    $self->{header}->{location} = $location;
}   

sub header {
    my $self = shift;

    if (@_ == 2) {
        $self->{header}->{$_[0]} = $_[1];
    }

    return $self->{header};
}

sub process {
    my ($self, $c) = @_;

    if ($self->{dump_body_to}) {
        $c->log->info("dump body to $self->{dump_body_to}");
        if (open my $fh, ">>", $self->{dump_body_to}) {
            print $fh ref $self->{body} eq "SCALAR" ? ${$self->{body}} : $self->{body};
            close $fh;
        }
    }

    my $header = $self->{header};

    foreach my $key (keys %$header) {
        if ($key eq "cookies") {
            foreach my $cookie (@{$header->{cookies}}) {
                $c->log->info("header>> Set-Cookie: $cookie");
                print "Set-Cookie: $cookie\n";
            }
        } else {
            my $upper_key = ucfirst($key);
            $c->log->info("header>> $upper_key: $header->{$key}");
            print "$upper_key: $header->{$key}\n";
        }
    }

    if (!$self->{content_type_printed}) {
        $self->{content_type_printed} = 1;
        $c->log->info("header>> Content-Type: $self->{content_type}");
        print "Content-Type: $self->{content_type}\n\n";
    }

    if ($c->log->is_info) {
        my $length;
        if (ref($self->{body}) eq "SCALAR") {
            $length = length(${$self->{body}});
        } else {
            $length = length($self->{body});
        }
        $c->log->info("content-length>> $length");
    }

    if (ref($self->{body}) eq "SCALAR") {
        print ${$self->{body}};
    } else {
        print $self->{body};
    }

    $c->log->info("content written");
}

sub dump_body_to {
    my ($self, $file) = @_;

    $self->{dump_body_to} = $file;
}

1;
