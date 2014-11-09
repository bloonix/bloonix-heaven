=head1 NAME

Bloonix::Heaven::Accessor - Create fast accessors.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS

=head2 mk_accessors

=head2 mk_counters

=head2 make_accessor

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Heaven::Accessor;

use strict;
use warnings;

sub mk_accessors {
    my ($class, @accessors) = @_;

    foreach my $accessor (@accessors) {
        $class->make_accessor(
            $accessor => sub {
                $_[0]->{$accessor} = $_[1] if @_ == 2;
                return $_[0]->{$accessor};
            }
        );
    }
}

sub mk_counters {
    my ($class, @accessors) = @_;

    foreach my $accessor (@accessors) {
        $class->make_accessor(
            $accessor => sub {
                $_[0]->{$accessor} += $_[1] if @_ == 2;
                return $_[0]->{$accessor} || 0;
            }
        );
    }
}

sub make_accessor {
    my ($class, $accessor, $code) = @_;
    no strict 'refs';
    *{"${class}::$accessor"} = $code;
}

1;
