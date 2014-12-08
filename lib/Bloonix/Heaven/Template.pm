package Bloonix::Heaven::Template;

use strict;
use warnings;
use Params::Validate qw();
use base qw(Bloonix::Accessor);

__PACKAGE__->mk_accessors(qw/c cache log path pid/);

sub new {
    my ($class, $c) = (shift, shift);
    my $opts = $class->validate(@_);
    my $self = bless $opts, $class;

    $self->c($c);
    $self->log($c->log);
    $self->cache({});
    $self->pid($$);

    return $self;
}

sub process {
    my ($self, $c) = @_;

    # If the pid changed then a new process were forked.
    if ($$ != $self->pid) {
        $self->pid($$);
        $SIG{USR1} = sub {
            $self->log->warning("signal USR1 received, flushing cache");
            $self->cache({});
        };
    }

    my $stash = $c->stash;
    my $template = delete $stash->{template};

    if (!defined $template || !length $template) {
        die "template missing";
    }

    if (!$self->cache->{$template}) {
        $self->parse($template);
    }

    my $code = $self->{cache_enabled}
        ? $self->cache->{$template}
        : delete $self->cache->{$template};

    $self->c->res->content_type("text/html");
    $self->c->res->body(&$code($self->c, $stash));
}

sub parse {
    my ($self, $template) = @_;

    $self->log->notice("parsing new template $template");

    my $inner = $self->include($template);
    my $content = $self->{outer};
    $content =~ s!<%\s+content\s+%>!$inner!g;
    while ($content =~ s!<%\s+include (.+?)\s+%>!$self->include($1)!eg){}

    my $code = join("\n",
        'sub { # 1',
        '    my ($c, $stash) = @_; # 2',
        '    my $content = ""; # 3',
        ''
    );

    my $i = 4;

    foreach my $row (split /\n/, $content) {
        if ($row =~ s/^(\s*)%\s//) {
            $code .= "    $1";
            $code .= $row;
            $code .= " # $i\n";
            $i++;
            next;
        }

        if ($row !~ /<%/) {
            $code .= '    $content .= '. '"' . $self->escape($row) . '\n";' . " # $i\n";
            $i++;
            next;
        }

        $code .= "    ";
        my @parts = split /(<%={0,1}\s+.+?\s+%>)/, $row;

        foreach my $part (@parts) {
            if ($part =~ /<%\s+(.+?)\s+%>/) {
                my $var = $1;
                $part = '$content .= $stash';
                foreach my $v (split /\./, $var) {
                    $part .= '->{"'. $v . '"}';
                }
                $part .= " // '';";
            } elsif ($part =~ /<%=\s+(.+?)\s+%>/) {
                $part = '$content .= '. $1 ." // '';";
            } elsif ($part ne "") {
                $part = $self->escape($part);
                $part = '$content .= ' . '"' . $part . '";';
            }
        }

        $code .= join("", @parts);
        $code .= '$content .= "\n";' . " # $i\n";
        $i++;
    }

    $code .= "    return \$content; # $i\n}";
    $self->log->debug("code\n$code");
    $self->cache->{$template} = eval $code;
}

sub include {
    my ($self, $template) = @_;
    my $file = join("/", $self->path, $template);

    $self->log->notice("parsing new template $file");

    open my $fh, "<", $file
        or die "unable to open template '$file' for reading: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    return $content;
}

sub escape {
    my ($self, $str) = @_;
    $str =~ s/\\/\\\\/g;
    $str =~ s/"/\\"/g;
    $str =~ s/\$/\\\$/g;
    $str =~ s/\@/\\\@/g;
    return $str;
}

sub validate {
    my $class = shift;

    my %opts = Params::Validate::validate(@_, {
        path => {
            type => Params::Validate::SCALAR
        },
        wrapper => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        cache_enabled => {
            type => Params::Validate::SCALAR,
            regex => qr/^(yes|no|1|0)\z/,
            default => "yes"
        }
    });

    if ($opts{wrapper}) {
        my $file = join("/", $opts{path}, $opts{wrapper});
        open my $fh, "<", $file or die "unable to open wrapper '$file' for reading: $!";
        $opts{outer} = do { local $/; <$fh> };
        close $fh;
    } else {
        $opts{outer} = "<% content %>";
    }

    if ($opts{cache_enabled} eq "no") {
        $opts{cache_enabled} = 0;
    }

    return \%opts;
}

1;
