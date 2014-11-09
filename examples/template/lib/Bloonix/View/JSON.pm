package Bloonix::View::JSON;

use strict;
use warnings;
use JSON;
use base qw(Bloonix::Accessor);
use Sys::Hostname;

__PACKAGE__->mk_accessors(qw/json/);

sub new {
    my ($class, $c) = @_;

    my $self = bless {
        who_am_i => $c->config->{webapp}->{hostname} || Sys::Hostname::hostname(),
        json => JSON->new
    }, $class;
}

sub process {
    my ($self, $c) = @_;

    my $stash = $c->stash;
    my $pretty = $c->req->exist("pretty");

    if ($pretty) {
        $self->json->pretty(1);
    }

    my $size = ref $stash->data eq "HASH"
        ? scalar keys %{$stash->data}
        : ref $stash->data eq "ARRAY"
            ? scalar @{$stash->data}
            : defined $stash->data
                ? 1
                : 0;

    my $total = defined $stash->{total}
        ? $stash->{total}
        : $size;

    # Status:
    #   ok, error, forbidden
    #   form-success, form-error
    my $time = sprintf("%.3f", scalar Time::HiRes::gettimeofday());
    $time =~ s/\.//;

    my $data = $self->json->encode({
        server_time => $time,
        who_am_i => $self->{who_am_i},
        status => $stash->status,
        data => $stash->data,
        offset => $stash->{offset} || 0,
        size => $size,
        total => $total
    });

    if ($pretty) {
        $self->json->pretty(0);
    }

    $c->res->content_type("application/json; charset=utf-8");
    $c->res->body(\$data);
    $c->res->is_json(1);
}

1
