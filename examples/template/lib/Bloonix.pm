package Bloonix;

use strict;
use warnings;
use base qw(Bloonix::Heaven);

sub init {
    my $self = shift;

    # Plugins
    #$self->plugin->load("Util");

    # Routes
    $self->load("Root");
}

1;
