=head1 NAME

Bloonix::Language - Create language accessors.

=head1 SYNOPSIS

    my $lang = Bloonix::Language->new( path to the language files );

    print $lang->de->text(key => @values);

=head1 DESCRIPTION

Create language accessors for your application.

=head1 METHODS

=head2 new( $path )

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

package Bloonix::Language;

use strict;
use warnings;
use Bloonix::Language::Format;

our $VERSION = "0.1";

sub new {
    my ($class, $path) = @_;
    my $self = bless { }, $class;

    if (!$path) {
        die "no path set";
    }

    opendir my $fd, $path or die "unable to open dir '$path'";
    my @files = grep /^[a-z]+/, readdir $fd;
    closedir $fd;

    foreach my $file (@files) {
        open my $fh, "<", "$path/$file" or die $!;

        my ($key, $value, $append);
        my $lang  = $file;
        $lang =~ s/\..+//;
        $self->{$lang} = Bloonix::Language::Format->new();

        while (my $line = <$fh>) {
            chomp $line;

            if ($line =~ /^([^\s].+?):\s(.+)/) {
                if (defined $key && defined $value) {
                    $self->{$lang}->set($key, $value);
                }
                ($key, $value) = ($1, $2);
            } elsif ($key && $line =~ /^\s([^\s].*)/) {
                $value .= "\n$1";
            }
        }

        if (defined $key && defined $value) {
            $self->{$lang}->set($key, $value);
        }

        close $fh;
        $self->{$lang}->finish;
    }

    return $self;
}

1;
