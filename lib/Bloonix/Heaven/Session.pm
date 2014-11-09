=head1 NAME

Bloonix::Heaven::Session - Session data serializer.

=head1 SYNOPSIS

    my $session = Bloonix::Heaven::Session->new();

=head1 DESCRIPTION

This module is just for internal usage!

Bloonix::Heaven::Session creates a session stash object that can be used to store
data for a user. You can store the data to the database if you want.

=head1 METHODS

=head2 new

This is the constructor. Call C<new> to create a new stash object.

=head2 set

Pass serialized data to C<set>. The stash will be initialized and overwritten.

    my $json = "---\nfoo: bar\n";

    # Init the stash
    $session->set($json);

    # Get the json data de-serialized
    my $hash = $session->stash;

=head2 get

Returns the session data serialized.

    my $json = $session->get;

=head2 stash

Returns the stash as a hash reference.

Note:

If you want to store data to the stash then please use the method C<store>!!!

=head2 store

Returns the stash data and mark the stash internal to be refreshed.

=head2 remove

Remove keys from the stash.

=head2 refresh

Returns true if the stash was modified with C<store>.

=head2 destroy

Returns true if a controller marks the stash should be destroyed.

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Heaven::Session;

use strict;
use warnings;
use JSON;

use base qw(Bloonix::Heaven::Accessor);
__PACKAGE__->mk_accessors(qw/refresh destroy json/);

sub new {
    my $class = shift;
    my $self = bless { }, $class;

    $self->{json} = JSON->new();

    return $self;
}

sub set {
    my ($self, $stash) = @_;

    $self->{stash} = $stash;
    $self->_init;

    return $self->{stash};
}

sub get {
    my $self = shift;

    if ($self->{stash}) {
        return $self->json->encode($self->{stash});
    }

    return "";
}

sub stash {
    my $self = shift;

    $self->_init;

    return $self->{stash};
}

sub remove {
    my ($self, @remove) = @_;

    $self->_init;

    foreach my $key (@remove) {
        delete $self->{stash}->{$key};
    }

    if (!scalar keys %{$self->{stash}}) {
        $self->destroy(1);
    }
}

sub store {
    my ($self, @stash) = @_;

    $self->_init;

    while (@stash) {
        my $key = shift @stash;
        my $val = shift @stash;
        $self->{stash}->{$key} = $val;
    }

    $self->refresh(1);
    $self->destroy(0);
    return $self->{stash};
}

sub _init {
    my $self = shift;

    if (ref($self->{stash}) ne "HASH") {
        if (!$self->{stash}) {
            $self->{stash} = { };
        } elsif ($self->{stash} =~ /^{/) {
            $self->{stash} = $self->json->decode($self->{stash});
        } else {
            die "invalid session stash '$self->{stash}'";
        }
    }
}

1;
