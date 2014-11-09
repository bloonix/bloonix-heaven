=head1 NAME

Bloonix::Language::Format - Create language accessors.

=head1 SYNOPSIS

    my $de = Bloonix::Language::Format->new();

    $de->set(hello => "Hello %s!");
    $de->get(hello => "World");

    # Output

    Hello World!

=head1 DESCRIPTION

Create simple accessors.

=head1 METHODS

=head2 new

Call C<new> to create a new language object.

=head2 set($key => $value)

Set a key-value pair.

    $lang->set("say.hello" => "Hello %s!");

=head2 get($key => $value)

Get a formatted string.

    $lang->set("fruit.color" => "%s are a %s fruit")
    $lang->get("fruit.color" => "Bananas" => "yellow");

C<get> would return "Bananas are a yellow fruit".

=head2 htmlwrap($key, $begin, $value, $end)

    $lang->htmlwrap("fruit.color" => "<b>" => "Bananas" => "</b>");

This would return

    <b>Bananas are a yellow fruit</b>

Note that some special characters of the value will be converted.

    &   &amp;
    <   &lt;
    >   &gt;
    "   &quot;

=head2 exists($key)

Check if a key exists. The method returns true or false.

=head2 finish

This method is necessary if C<@@makro@@> makros are used
and will be called after a language file were read.

=head1 PREREQUISITES

No prerequisites.

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Language::Format;

use strict;
use warnings;

our $VERSION = "0.1";

sub new {
    my $class = shift;

    return bless { }, $class;
}

sub set {
    my ($self, $key, $value) = @_;

    if ($value =~ /@@(.+?)@@/) {
        if (exists $self->{$1}) {
            $value =~ s/@@(.+?)@@/$self->{$1}/;
        } else {
            $self->{__ON_HOLD__}->{$key} = $value;
            return;
        }
    }

    if (exists $self->{$key}) {
        if (ref($self->{$key}) eq "ARRAY") {
            push @{$self->{$key}}, $value;
        } else {
            $self->{$key} = [ $self->{$key}, $value ];
        }
    } else {
        $self->{$key} = $value;
    }
}

sub get {
    my ($self, $key, @values) = @_;

    if (!exists $self->{$key}) {
        die "unknown language key '$key'";
    }

    return sprintf($self->{$key}, @values);
}

sub htmlwrap {
    my ($self, $key, @wrap) = @_;
    my @values;

    while (@wrap) {
        my $begin = shift @wrap || "";
        my $value = shift @wrap || "";
        my $end   = shift @wrap || "";

        $value =~ s/&/&amp;/g;
        $value =~ s/</&lt;/g;
        $value =~ s/>/&gt;/g;
        $value =~ s/"/&quot;/g;

        push @values, "$begin$value$end";
    }

    return $self->get($key, @values);
}

sub exists {
    my ($self, @keys) = @_;

    my $key = join(".", @keys);

    return $self->{$key} ? 1 : 0;
}

sub finish {
    my $self = shift;

    if ($self->{__ON_HOLD__}) {
        foreach my $key (keys %{$self->{__ON_HOLD__}}) {
            my $value = $self->{__ON_HOLD__}->{$key};
            $value =~ s/@@(.+?)@@/$self->{$1}/;
            $self->{$key} = $value;
        }
        delete $self->{__ON_HOLD__};
    }
}

1;
