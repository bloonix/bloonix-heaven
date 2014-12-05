package Bloonix::Heaven::Template;

use strict;
use warnings;
use Params::Validate qw();
use base qw(Bloonix::Accessor);

__PACKAGE__->mk_accessors(qw/c cache log path/);

sub new {
    my $class = shift;
    my $c = shift;
    my $opts = $class->validate(@_);
    $opts->{c} = $c;
    $opts->{cache} = {};
    $opts->{log} = $c->log;
    return bless $opts, $class;
}

sub process {
    my ($self, $c) = @_;
    my $stash = $c->stash;
    my $template = delete $stash->{template};

    if (!$self->cache->{$template}) {
        $self->parse($template);
    }

    my $code = $self->cache->{$template};
    $self->c->res->content_type("text/html");
    $self->c->res->body(&$code($self->c, $stash));
}

sub parse {
    my ($self, $template) = @_;

    $self->log->notice("parsing new template $template");

    my $inner = $self->include($template);
    my $content = $self->{outer};
    $content =~ s!<%\s+content\s+%>!$inner!g;
    $content =~ s!<%\s+include (.+?)\s+%>!$self->include($1)!eg;

    my $code = join("\n",
        'sub {',
        '    my ($c, $stash) = @_;',
        '    my $content = "";',
        ''
    );

    foreach my $row (split /\n/, $content) {
        if ($row =~ s/^(\s*)%\s//) {
            $code .= "    $1";
            $code .= $row;
            $code .= "\n";
            next;
        }

        if ($row !~ /<%/) {
            $code .= '    $content .= '. '"' . $self->escape($row) . '\n";' . "\n";
            next;
        }

        $code .= "    ";
        my @parts = split /(<%={0,1}\s+.+?\s+%>)/, $row;

        foreach my $part (@parts) {
            if ($part =~ /<%\s+(.+?)\s+%>/) {
                $part = '$content .= $stash';
                my $var = $1;
                foreach my $v (split /\./, $var) {
                    $part .= '->{"'. $v . '"}';
                }
                $part .= ";";
            } elsif ($part =~ /<%=\s+(.+?)\s+%>/) {
                $part = '$content .= '. $1 .";";
            } elsif ($part ne "") {
                $part = $self->escape($part);
                $part = '$content .= ' . '"' . $part . '";';
            }
        }

        $code .= join("", @parts);
        $code .= '$content .= "\n";' . "\n";
    }

    $code .= "    return \$content;\n}";
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

    return \%opts;
}

1;
