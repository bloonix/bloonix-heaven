=head1 NAME

Bloonix::Heaven::Model - The model loader.

=head1 SYNOPSIS

    $self->model->load($accessor => $class => $config);

=head1 DESCRIPTION

This module is just for internal usage.

=head1 METHODS

=head2 new

=head2 load

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Heaven::Model;

use strict;
use warnings;

sub new {
    my ($class, $c) = @_;

    my $self = bless { __c => $c }, $class;

    return $self;
}

sub load {
    my ($self, $accessor, $class, $config) = @_;

    eval "use $class";
    die $@ if $@;

    $self->{$class} = $class->new($self->{__c}, $config);

    {
        no strict "refs";
        *{$accessor} = sub { return shift->{$class} };
    }
}

1;
