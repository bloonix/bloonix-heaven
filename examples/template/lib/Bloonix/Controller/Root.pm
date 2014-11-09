package Bloonix::Controller::Root;

use strict;
use warnings;

sub startup {
    my ($self, $c) = @_;

    $c->route->map("/")->to("index");
}

sub auto {
    my ($self, $c) = @_;

    $c->view->render->template;

    $c->stash->version({
        js => 1,
        css => 1
    });

    return 1;
}

sub default {
    my ($self, $c) = @_;

    $self->index($c);
}

sub error {
    die "Internal error";
}

sub index {
    my ($self, $c) = @_;

    $c->stash->{template} = "index.tt";
}

sub end {
    my ($self, $c) = @_;

    return 1;
}

1;
