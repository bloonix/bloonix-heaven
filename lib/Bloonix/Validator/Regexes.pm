=head1 NAME

Bloonix::Validator::Regexes - Validator regexes.

=head1 SYNOPSIS

=head1 DESCRIPTION

Just for internal usage!

=head1 METHODS

=head2 new

=cut

package Bloonix::Validator::Regexes;

use strict;
use warnings;
use base qw(Bloonix::Accessor);

__PACKAGE__->mk_accessors(qw/
    digit number float alphas non_alphas
    bool true false email
    time date datetime datehourmin
    ipv4 ipv6 ipv6_strict ipv6_long ipaddr
/);

our $VERSION = "0.1";

my $rx_digit      = qr/^\d\z/;
my $rx_number     = qr/^\d+\z/;
my $rx_float      = qr/^\d+\.\d+\z/;
my $rx_alphas     = qr/^\w+\z/;
my $rx_non_alphas = qr/^\W+\z/;
my $rx_bool       = qr/^[01]\z/;
my $rx_true       = qr/^1\z/;
my $rx_false      = qr/^0\z/;

# In the past I used Mail::RFC822::Address to parse mail addresses,
# but RFC822 really sucks! It allows mail addresses like
#
#   user@[IPv6:2001:db8:1ff::a0b:dbd0]
#   "very.(),:;<>[]\".VERY.\"very@\\ \"very\".unusual"@strange.example.com
#   "()<>[]:,;@\\\"!#$%&'*+-/=?^_`{}| ~.a"@example.org
#
# For this reason I wrote my own mail parser.
#
#   - only the signs a-z, A-Z, 0-9 and .-+_ are allowed in the name part
#   - doubled signs of .-+_ are not allowed in the name part
#   - only the signs a-z, A-Z, 0-9 and .- are allowed in the host part
#   - doubled signs of .- are not allowed in the host part
#   - both, the name and host part must begin and end with a-z, A-Z or 0-9
#
my $rx_email = qr/
    ^                                       # The beginning of the hell
    [a-zA-Z0-9]+([\.\-\+=_][a-zA-Z0-9]+)*   # this is the name part
    @                                       # delimiter between the name and host
    [a-zA-Z0-9]+([\.\-][a-zA-Z0-9]+)*       # subdomain with domain name
    \.                                      # delimiter betwenn domain and tld
    [a-zA-Z]{2,}                            # the top level domain name
    \z                                      # the end of the hell
/x;

my $rx_year  = qr/\d{4}/;
my $rx_month = qr/(?:0[1-9]|1[0-2])/;
my $rx_day   = qr/(?:0[1-9]|[1-2][0-9]|3[0-1])/;
my $rx_hour  = qr/(?:[0-1][0-9]|2[0-3])/;
my $rx_min   = qr/[0-5][0-9]/;
my $rx_sec   = $rx_min;
my $rx_date  = qr/^$rx_year-$rx_month-$rx_day\z/;
my $rx_time  = qr/^$rx_hour:$rx_min:$rx_sec\z/;

my $rx_datetime    = qr/^$rx_year-$rx_month-$rx_day\s$rx_hour:$rx_min:$rx_sec\z/;
my $rx_datehourmin = qr/^$rx_year-$rx_month-$rx_day\s$rx_hour:$rx_min\z/;

my $rx_port = qr/
    ^(?:
        6553[0-5]|655[0-2][0-9]|65[0-4][0-9]{2}|6[0-4][0-9]{3}|
        [0-5]?[0-9]{4}|
        [0-9]{2,4}|
        [1-9]
    )\z
/x;

my $rx_ipv4 = qr/^
    (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | [1-9][0-9] | [0-9] ) \.
    (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | [1-9][0-9] | [0-9] ) \.
    (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | [1-9][0-9] | [0-9] ) \.
    (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | [1-9][0-9] | [0-9] )
\z/x;

# A single block of a ipv6 address
my $ipv6a = '[0-9A-Fa-f]{1,4}';
# No leading 0 is allowed
my $ipv6s = '([1-9A-Fa-f][0-9A-Fa-f]{1,3}|[0-9A-Fa-f])';

my $rx_ipv6 = qr/^
    (
        ($ipv6a:){7}$ipv6a
        |($ipv6a:){6}:$ipv6a
        |($ipv6a:){5}(:$ipv6a){2}
        |($ipv6a:){4}(:$ipv6a){3}
        |($ipv6a:){3}(:$ipv6a){4}
        |($ipv6a:){2}(:$ipv6a){5}
        |$ipv6a:(:$ipv6a){6}
        |($ipv6a:){5}:$ipv6a
        |($ipv6a:){4}(:$ipv6a){2}
        |($ipv6a:){2}(:$ipv6a){4}
        |$ipv6a:(:$ipv6a){5}
        |($ipv6a:){4}:$ipv6a
        |$ipv6a:(:$ipv6a){4}
        |($ipv6a:){1,3}(:$ipv6a){1,3}
        |:(:$ipv6a){1,7}
        |($ipv6a:){1,7}:
    )
\z/x;

my $rx_ipv6_strict = qr/^
    (
        ($ipv6s:){7}$ipv6s
        |($ipv6s:){6}:$ipv6s
        |($ipv6s:){5}(:$ipv6s){2}
        |($ipv6s:){4}(:$ipv6s){3}
        |($ipv6s:){3}(:$ipv6s){4}
        |($ipv6s:){2}(:$ipv6s){5}
        |$ipv6s:(:$ipv6s){6}
        |($ipv6s:){5}:$ipv6s
        |($ipv6s:){4}(:$ipv6s){2}
        |($ipv6s:){2}(:$ipv6s){4}
        |$ipv6s:(:$ipv6s){5}
        |($ipv6s:){4}:$ipv6s
        |$ipv6s:(:$ipv6s){4}
        |($ipv6s:){1,3}(:$ipv6s){1,3}
        |:(:$ipv6s){1,7}
        |($ipv6s:){1,7}:
    )
\z/x;

my $rx_ipv6_long = qr/^
    ($ipv6a:){7}$ipv6a
\z/x;

my $rx_ipaddr = qr/
    ($rx_ipv4|$rx_ipv6)
/x;

sub new {
    my $class = shift;

    my $self = bless {
        digit       => $rx_digit,
        number      => $rx_number,
        float       => $rx_float,
        alphas      => $rx_alphas,
        non_alphas  => $rx_non_alphas,
        bool        => $rx_bool,
        true        => $rx_true,
        false       => $rx_false,
        email       => $rx_email,
        ipv4        => $rx_ipv4,
        ipv6        => $rx_ipv6,
        ipv6_strict => $rx_ipv6_strict,
        ipv6_long   => $rx_ipv6_long,
        ipaddr      => $rx_ipaddr,
        time        => $rx_time,
        date        => $rx_date,
        datetime    => $rx_datetime,
        datehourmin => $rx_datehourmin,
    }, $class;

    return $self;
}

1;
