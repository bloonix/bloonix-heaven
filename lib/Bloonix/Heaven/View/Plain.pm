package Bloonix::Heaven::View::Plain;

use strict;
use warnings;

sub new {
    my ($class, $c) = @_;

    return bless {}, $class;
}

sub process {
    my ($self, $c) = @_;

    if (!$c->response->content_type) {
        $c->response->content_type("text/html");
    }

    if (!defined $c->response->body) {
        $c->response->body(\"");
    }

    return 1;
}

1;
