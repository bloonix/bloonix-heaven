=head1 NAME

Bloonix::Heaven::View - The model loader.

=head1 SYNOPSIS

    $self->view->load($accessor => $class => $config);

=head1 DESCRIPTION

This module is just for internal usage.

=head1 METHODS

=head2 new

=head2 load

=head2 process

=head2 render

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Heaven::View;

use strict;
use warnings;

sub new {
    my ($class, $c) = @_;

    my $self = bless { __c => $c }, $class;
    $self->load(plain => "Bloonix::Heaven::View::Plain");

    return $self;
}

sub load {
    my ($self, $accessor, $class, $config) = @_;

    eval "use $class";
    die $@ if $@;

    $self->{$accessor} = $class->new($self->{__c}, $config);

    {
        no strict 'refs';
        *{"Bloonix::Heaven::View::Render::$accessor"} = sub {
            $self->{__view} = $accessor;
        };
    }
}

sub render {
    my ($self, $view) = @_;

    if ($view) {
        $self->{__view} = $view;
    }

    return "Bloonix::Heaven::View::Render";
}

sub process {
    my ($self, $stash) = @_;
    my $view = $self->{__view};

    if ($view) {
        if (exists $self->{$view}) {
            $self->{$view}->process($stash);
        } else {
            die "view '$view' does not exists!";
        }
    }
}

package Bloonix::Heaven::View::Render;
# Pseudo class.

1;
