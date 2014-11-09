package Bloonix::Model::Database;

use strict;
use warnings;
use base qw(Bloonix::Accessor);
use base qw(Bloonix::DBI::ClassLoader);

sub load {
    my $self = shift;

    return (
        user => "Bloonix::Model::Schema::User",
        session => "Bloonix::Model::Schema::Session",
    );
}

1;
