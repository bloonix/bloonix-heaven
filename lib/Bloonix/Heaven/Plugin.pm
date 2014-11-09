=head1 NAME

Bloonix::Heaven::Plugin - The plugin loader.

=head1 SYNOPSIS

    $self->plugin->load(accessor => $module);

=head1 DESCRIPTION

This module is just for internal usage.

=head1 METHODS

=head2 new

=head2 load

Load plugins and create accessors.

Example:

    $plugin->load("MyApp::Plugin::Token")        $c->plugin->token()
    $plugin->load("MyApp::Plugin::LogAction")    $c->plugin->log_action()
    $plugin->load("MyApp::Plugin::FooBarBaz")    $c->plugin->foo_bar_baz()
    $plugin->load("MyApp::Plugin::DoINIT")       $c->plugin->do_init()
    $plugin->load("MyApp::Plugin::INET")         $c->plugin->inet()

It's possible to pass to arguments where the first argument is the accessor name:

    $plugin->load(FooBarBaz => "MyApp::Plugin::FooBarBaz")    $c->plugin->FooBarBaz()

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Heaven::Plugin;

use strict;
use warnings;

sub new {
    my ($class, $c) = @_;

    my $self = bless {
        __c => $c,
        __b => join("::", ref $c, "Plugin"),
    }, $class;

    return $self;
}

sub load {
    my $self = shift;
    my ($accessor, $class, $object);

    if (@_ == 2) {
        ($accessor, $class) = @_;
    } elsif (@_ == 1) {
        $class = join("::", $self->{__b}, @_);
        $accessor = shift;
        $accessor =~ s/([a-z])([A-Z])/${1}_${2}/g;
        $accessor =~ tr/A-Z/a-z/;
    }

    eval "use $class";    

    if ($@) {
        die "unable to load plugin '$class' - $@";
    }

    $object = $class->new($self->{__c});

    {
        no strict 'refs';
        *{"$accessor"} = sub {
            my $self = shift;
            return $self->{$class};
        };
    }

    $self->{$class} = $object;
}

1;
