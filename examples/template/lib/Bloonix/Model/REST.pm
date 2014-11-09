package Bloonix::Model::REST;

use strict;
use warnings;
use base qw(Bloonix::Heaven::ModelLoader);

sub load {
    my $self = shift;

    return (
        base => "Bloonix::Model::REST::Base"
    );
}

1;
