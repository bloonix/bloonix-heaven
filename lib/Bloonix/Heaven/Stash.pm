=head1 NAME

Bloonix::Heaven::Stash - Stash data.

=head1 SYNOPSIS

    my $stash = Bloonix::Heaven::Stash->new();

=head1 DESCRIPTION

This module is just for internal usage!

Bloonix::Heaven::Stash creates a stash object that can be used to store data
from a controller. The data will be forwarded to the view after the
controller finished its work. The stash can also be used for all
interactions between different controllers. The stash will be destroyed
if the view is finished and a new stash is created for each request.

=head1 METHODS

=head2 new

This is the constructor. Call C<new> to create a new stash object.

=head2 data

    $stash->data({ foo => bar });   # overwrite
    $stash->data(foo => bar);       # append to hash
    $stash->data("foobar");         # set a scalar

=head2 object

Can be used for different purposes. As example a auto() method
can store an object that is usable for each other action.

=head2 status

    $stash->status("ok");           # the default
    $stash->status("err-411");      # set a status

=head2 success, error, fatal

Call one of the methods if you want to store messages on operations
with a successful, failed or fatal return status. The messages are
stored into an array.

    $stash->success("user a successfully updated");
    $stash->success("user b successfully updated");

    foreach my $message ($stash->success) {
        print $message;
    }

=head2 destroy

Call C<destroy> if you want to delete all stash data.

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Heaven::Stash;

use strict;
use warnings;
use base qw(Bloonix::Accessor);

__PACKAGE__->mk_accessors(qw/offset total status version meta/);

sub new {
    my $class = shift;

    return bless { status => "ok" }, $class;
}

sub data {
    my $self = shift;

    if (@_ == 1) {
        $self->{data} = shift;
    } else {
        $self->{data} //= { };

        while (@_) {
            my ($key, $value) = (shift, shift);
            $self->{data}->{$key} = $value;
        }
    }

    return $self->{data};
}

sub object {
    my ($self, $object) = @_;

    if ($object) {
        $self->{object} = $object;
    }

    return $self->{object};
}

sub success {
    my $self = shift;

    if (@_) {
        push @{ $self->{success} }, @_;
    }

    if (wantarray) {
        return $self->{success} ? @{ $self->{success} } : ();
    }

    return $self->{success};
}

sub error {
    my $self = shift;

    if (@_) {
        push @{ $self->{error} }, @_;
    }

    if (wantarray) {
        return $self->{error} ? @{ $self->{error} } : ();
    }

    return $self->{error};
}

sub fatal {
    my $self = shift;

    if (@_) {
        push @{ $self->{fatal} }, @_;
    }

    return wantarray ? @{ $self->{fatal} } : $self->{fatal};
}

sub for {
    my ($self, $str) = @_;

    if (defined $self->{$str}) {
        if (ref $self->{$str} eq "ARRAY") {
            return @{$self->{$str}};
        } elsif (ref $self->{$str} eq "HASH") {
            return (keys %{$self->{$str}});
        }
    }

    return ();
}

sub destroy {
    my $self = shift;
    # Very simple... just delete all keys.
    delete $self->{$_} for keys %$self;
}

1;
