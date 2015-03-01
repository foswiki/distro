# See bottom of file for license and copyright information
package Foswiki::IP;

use strict;
use warnings;

# Network utility functions
# Use these instead of IPv4-specific functions like
# gethostbyaddr & gethostbyname.  These functions
# support IPv6 - if IO::Socket::IP is installed, as well
# as providing parsing/error checking support.
# If IO::Socket::IP is not installed, they fall back to the
# old functions.

use Socket qw/SOCK_RAW AF_INET inet_ntoa inet_aton/;

use Exporter;
our @ISA = (qw/Exporter/);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

#our @EXPORT;
our @EXPORT_OK   = (qw/$IPv6Avail/);
our %EXPORT_TAGS = (
    info => [qw/verifyHostname hostInfo addrInfo/],
    regexp =>
      [qw/$IPv4Re $IPv4DecodeRe $IPv6Re $IPv6ZidRe $IPv6UsRe $IPv6UzRe/],
    getregexp => [qw/get4Re get6Re/],
    validate  => [qw/verifyHostname verifyAddress/],
);
{
    my %seen;
    for my $taglist ( values %EXPORT_TAGS ) {
        my @new = grep { !$seen{$_}++ } @$taglist;
        push @EXPORT_OK, @new;
        push @{ $EXPORT_TAGS{all} }, @new;
    }

    #    push @{ $EXPORT_TAGS{all} }, grep { !$seen{$_}++ } @EXPORT;
}

our $IPv6Avail = eval "require IO::Socket::IP;";

# IPv4 address
our $IPv4Re =
qr{(?:(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d))}o;

# IPv4 address capturing octets
our $IPv4decodeRe =
qr{(?:(25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d))}o;

# Strictly speaking, IPv6 address must have digits a-f in lower case
# Otherwise, we could use [[:xdigit:]] instead of [\da-f].  If you want
# liberal input rules, lowercase the input.

# IPv6 address
our $IPv6Re =
qr{(?:(?:[\da-f]{1,4}:){0,6}[\da-f]{1,4}::|(?:(?:[\da-f]{1,4}:){7}|::(?:[\da-f]{1,4}:){0,6}|[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,5}|(?:[\da-f]{1,4}:)?[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,4}|(?:[\da-f]{1,4}:){0,2}[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,3}|(?:[\da-f]{1,4}:){0,3}[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,2}|(?:[\da-f]{1,4}:){0,4}[\da-f]{1,4}::(?:[\da-f]{1,4}:)?|(?:[\da-f]{1,4}:){0,5}[\da-f]{1,4}::)[\da-f]{1,4}|(?:::|(?:[\da-f]{1,4}:){6}|(?:[\da-f]{1,4}:){1,4}:(?:[\da-f]{1,4}:){1,2}|(?:[\da-f]{1,4}:){1,3}:(?:[\da-f]{1,4}:){1,3}|(?:[\da-f]{1,4}:){1,2}:(?:[\da-f]{1,4}:){1,4}|(?:[\da-f]{1,4})?::(?:[\da-f]{1,4}:){1,5}|(?:[\da-f]{1,4}:){1,5}(?::[\da-f]{1,4})?:)(?:(?:25[0-5]|1[\d]{2}|(?:2[0-4]|[1-9])?[\d])\.){3}(?:25[0-5]|1[\d]{2}|(?:2[0-4]|[1-9])?[\d]))}o;

# IPv6 address with zone-id
our $IPv6ZidRe =
qr{(?:(?:(?:[\da-f]{1,4}:){0,6}[\da-f]{1,4}::|(?:(?:[\da-f]{1,4}:){7}|::(?:[\da-f]{1,4}:){0,6}|[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,5}|(?:[\da-f]{1,4}:)?[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,4}|(?:[\da-f]{1,4}:){0,2}[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,3}|(?:[\da-f]{1,4}:){0,3}[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,2}|(?:[\da-f]{1,4}:){0,4}[\da-f]{1,4}::(?:[\da-f]{1,4}:)?|(?:[\da-f]{1,4}:){0,5}[\da-f]{1,4}::)[\da-f]{1,4}|(?:::|(?:[\da-f]{1,4}:){6}|(?:[\da-f]{1,4}:){1,4}:(?:[\da-f]{1,4}:){1,2}|(?:[\da-f]{1,4}:){1,3}:(?:[\da-f]{1,4}:){1,3}|(?:[\da-f]{1,4}:){1,2}:(?:[\da-f]{1,4}:){1,4}|(?:[\da-f]{1,4})?::(?:[\da-f]{1,4}:){1,5}|(?:[\da-f]{1,4}:){1,5}(?::[\da-f]{1,4})?:)(?:(?:25[0-5]|1[\d]{2}|(?:2[0-4]|[1-9])?[\d])\.){3}(?:25[0-5]|1[\d]{2}|(?:2[0-4]|[1-9])?[\d]))(?:\%[\w_.-]+)?)}o;

# IPv6 address including the unspecified address (::)
our $IPv6UsRe =
qr{(?:::|(?:(?:[\da-f]{1,4}:){0,6}[\da-f]{1,4}::|(?:(?:[\da-f]{1,4}:){7}|::(?:[\da-f]{1,4}:){0,6}|[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,5}|(?:[\da-f]{1,4}:)?[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,4}|(?:[\da-f]{1,4}:){0,2}[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,3}|(?:[\da-f]{1,4}:){0,3}[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,2}|(?:[\da-f]{1,4}:){0,4}[\da-f]{1,4}::(?:[\da-f]{1,4}:)?|(?:[\da-f]{1,4}:){0,5}[\da-f]{1,4}::)[\da-f]{1,4}|(?:::|(?:[\da-f]{1,4}:){6}|(?:[\da-f]{1,4}:){1,4}:(?:[\da-f]{1,4}:){1,2}|(?:[\da-f]{1,4}:){1,3}:(?:[\da-f]{1,4}:){1,3}|(?:[\da-f]{1,4}:){1,2}:(?:[\da-f]{1,4}:){1,4}|(?:[\da-f]{1,4})?::(?:[\da-f]{1,4}:){1,5}|(?:[\da-f]{1,4}:){1,5}(?::[\da-f]{1,4})?:)(?:(?:25[0-5]|1[\d]{2}|(?:2[0-4]|[1-9])?[\d])\.){3}(?:25[0-5]|1[\d]{2}|(?:2[0-4]|[1-9])?[\d])))}o;

# IPv6 address with unspecified and zone-id
our $IPv6UzRe =
qr{(?:::|(?:(?:[\da-f]{1,4}:){0,6}[\da-f]{1,4}::|(?:(?:[\da-f]{1,4}:){7}|::(?:[\da-f]{1,4}:){0,6}|[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,5}|(?:[\da-f]{1,4}:)?[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,4}|(?:[\da-f]{1,4}:){0,2}[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,3}|(?:[\da-f]{1,4}:){0,3}[\da-f]{1,4}::(?:[\da-f]{1,4}:){0,2}|(?:[\da-f]{1,4}:){0,4}[\da-f]{1,4}::(?:[\da-f]{1,4}:)?|(?:[\da-f]{1,4}:){0,5}[\da-f]{1,4}::)[\da-f]{1,4}|(?:::|(?:[\da-f]{1,4}:){6}|(?:[\da-f]{1,4}:){1,4}:(?:[\da-f]{1,4}:){1,2}|(?:[\da-f]{1,4}:){1,3}:(?:[\da-f]{1,4}:){1,3}|(?:[\da-f]{1,4}:){1,2}:(?:[\da-f]{1,4}:){1,4}|(?:[\da-f]{1,4})?::(?:[\da-f]{1,4}:){1,5}|(?:[\da-f]{1,4}:){1,5}(?::[\da-f]{1,4})?:)(?:(?:25[0-5]|1[\d]{2}|(?:2[0-4]|[1-9])?[\d])\.){3}(?:25[0-5]|1[\d]{2}|(?:2[0-4]|[1-9])?[\d]))(?:\%[\w_.-]+)?)}o;

sub verifyHostname {
    my $name = shift;

    my $hi = hostInfo($name);
    if ( $hi->{error} ) {
        return $hi->{error};
    }
    unless ( @{ $hi->{addrs} } ) {
        return "$name has no IP address";
    }
    return '';
}

# Takes a hostname or hostname:port or [v6ip]:port or v4ip:port
# Optional hash:
#   unspec : true if unspecified address OK (::)
#   zoneindex : true if zone-index allowed (%interface)

# Returns a hash:
# error : Error string if error encountered, else ''
# addrs : [ all addresses in order for connect ]
# v4addrs : [ all IPv4 addresses ] [] if none
# v6addrs : same for IPv6
# name : name (or address); any port removed.
# port : port number (or undef)
# ipv4addr : true if input was an IPv4 address
# ipv6addr : same for IPv6
# ipaddr : true if input was an IP address

sub hostInfo {
    my $name = shift;
    my $opts = shift || {};

    my $v6re = get6Re($opts);

    my $result = { addrs => [], error => '', v4addrs => [], v6addrs => [], };

    if ( $name =~ m/^\[($IPv6ZidRe|$IPv4Re)\](?::(\d+))?$/ ) {
        if ( defined $2 && ( $2 < 10 || $2 > 65535 ) ) {
            $result->{error} = "Invalid port number $2";
            return $result;
        }
        $name           = $1;
        $result->{name} = $1;
        $result->{port} = $2;
    }
    elsif ( $name =~ m/^$IPv6ZidRe$/ ) {
        $result->{name} = $name;
        $name =~ m/^(.*)$/;
        $name = $1;
    }
    else {
        if ( $name =~ m/^([^:]+)(?::(\d+))?$/ ) {
            if ( defined $2 && ( $2 < 10 || $2 > 65535 ) ) {
                $result->{error} = "Invalid port number $2";
                return $result;
            }
            $name           = $1;
            $result->{name} = $1;
            $result->{port} = $2;
        }
        else {
            $result->{error} =
"Invalid syntax: use hostname:port, IPv4-address:port, or [IPv6-address]:port.  :port is optional.";
            return $result;
        }
    }

    if ( $name =~ m/^$IPv4Re$/ ) {
        $result->{ipv4addr} = 1;
        $result->{ipaddr}   = 1;
        if ( !$opts->{unspec} && $result->{name} eq '0.0.0.0' ) {
            $result->{error} = "Unspecified addresss is not permitted";
            return $result;
        }
    }
    elsif ( $name =~ m/^$IPv6ZidRe$/ ) {
        $result->{ipv6addr} = 1;
        $result->{ipaddr}   = 1;
        unless ( $name =~ m/$v6re/ ) {
            $result->{error} = "This type of IPv6 address is not permitted";
            return $result;
        }
    }
    if ($IPv6Avail) {
        eval {
            Socket->import(qw/:addrinfo/);

            my ( $err, @res ) =
              getaddrinfo( $name, "", { socktype => SOCK_RAW() } );
            $result->{error} = "$err" || '';
            return $result if ($err);

            while ( my $ai = shift @res ) {
                my ( $err, $ipaddr ) =
                  getnameinfo( $ai->{addr}, NI_NUMERICHOST(), NIx_NOSERV() );

                $result->{error} .= "$err" || '';
                return $result if ($err);

                # In returned priority order:
                push @{ $result->{addrs} }, $ipaddr;

                if ( $ai->{family} == AF_INET() ) {
                    push @{ $result->{v4addrs} }, $ipaddr;
                }
                else {
                    push @{ $result->{v6addrs} }, $ipaddr;
                }
            }
            return $result;
        };
    }
    else {
        $@ = 'Use gethostbyname';
    }

    if ($@) {
        my ( undef, undef, undef, undef, @addrs ) = gethostbyname($name);

        $result->{addrs} = $result->{v4addrs} =
          [ map { inet_ntoa($_) } @addrs ];
    }
    return $result;
}

# Information about an IP address
# Input: address
# Returns hash
#  error: string or ''
#  names: [all names] - 1 for IPv6, + aliases for IPv4.  NOT full RDNS

sub addrInfo {
    my $address = shift;

    my $result = {};

    $address =~ m/^(.*)$/;
    $address = $1;

    # We don't take the trouble to ask DNS for multiple PTR records.
    # One name should be enough.  For IPv4, use gethostbyaddr as it
    # trivially returns aliases.

    my ( $error, @addrs );

    if ( $IPv6Avail && $address !~ /^$IPv4Re$/ ) {
        Socket->import(qw/:addrinfo/);

        ( $error, @addrs ) =
          getaddrinfo( $address, 0, { flags => AI_NUMERICHOST() } );
        $result->{error} = "$error" || '';
        return $result if ($error);

        my $name;
        ( $error, $name, undef ) =
          getnameinfo( $addrs[0]->{addr}, NI_NAMEREQD(), NIx_NOSERV() );

        $result->{error} = "$error" || '';
        return $result if ( $result->{error} );

        $result->{names} = [$name];
        return $result;
    }

    my $ipaddr = inet_aton($address);
    my ( $name, $aliases ) = gethostbyaddr( $ipaddr, AF_INET() );

    unless ( defined $name ) {
        $result->{error} = "$!" || '';
        return $result;
    }
    $result->{names} = [$name];
    if ($aliases) {
        foreach my $alias ( split( /\s+/, $aliases ) ) {
            push @{ $result->{names} }, $alias if ( $alias ne $name );
        }
    }
    return $result;
}

# Return a regexp for matching an IPv4 address
# options:
#  capture = RE will capture each octet

sub get4Re {
    my $opts = shift;

    if ( $opts->{capture} ) {
        return $IPv4decodeRe;
    }
    else {
        return $IPv4Re;
    }
    return $IPv6Re;

}

# Return a regexp for matching an IPv6 address
# options:
#  unspec = allow the "unspecified" address (::)
#  zoneindex = allow a zone index (%nn or %interface)

sub get6Re {
    my $opts = shift;

    if ( $opts->{unspec} ) {
        if ( $opts->{zoneindex} ) {
            return $IPv6UzRe;
        }
        else {
            return $IPv6UsRe;
        }
    }
    if ( $opts->{zoneindex} ) {
        return $IPv6ZidRe;
    }
    return $IPv6Re;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
