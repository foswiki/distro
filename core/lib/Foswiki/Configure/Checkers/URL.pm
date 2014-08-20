# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::URL;

use strict;
use warnings;

use Foswiki::IP qw/$IPv6Avail :regexp :info/;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

# This is a generic (item-independent) checker for URIs.
# 
# CHECKoptions:
#    * expand = expand $Foswiki::cfg variables in value
#    * nullok = allow item to be empty
#    * parts:scheme,authority,path,query,fragment
#           Parts allowed in item
#           Default: scheme,authority,path
#    * notrail = remove trailing / from (https?) paths
#    * partsreq = Parts required in item
#    * schemes = schemes allowd in item
#           Default: http,https
#    * authtype = authority types allowed in item
#           host - dns hostname
#           ip   - IP address
#           hostip = hostname or IP address
#           Default: host
#    * user = Permit user@host syntax
#    * pass = Permit user:pass@host syntax
# 
# CHECKoptions default to whatever is in the model if not provided

# Fallback validation expression:
# (scheme, authority, path, query, frag)
# Technically, ? & # aren't part of query or frag, but including
# them makes parsing and error reporting easier.

my $uriRE = qr|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(\?[^#]*)?(#.*)?|o;

sub check_current_value {
    my ($this, $reporter) = @_;
    my $keys = $this->{item}->{keys};

    $this->showExpandedValue($reporter);

    my ($check) = $this->{item}->getChecks();
    checkURI($reporter, $this->getCfgUndefOk(), %$check);
}

sub _vlist {
    my ( $options, $item ) = @_;

    return { map { $_ => 1 } @{ $options->{$item} || [] } };
}

sub checkURI {
    my( $reporter, $uri, %check) = @_;

    $check{expand}   ||= [0];
    $check{parts}    ||= [qw/scheme authority path/];
    $check{partsreq} ||= [qw/scheme authority/];
    $check{schemes}  ||= [qw/http https/];
    $check{authtype} ||= ['host'];
    $check{notrail}  ||= [0];
    $check{pass}     ||= [0];
    $check{user}     ||= $check{pass}[0] ? [1] : [0];

    if ( $check{expand}[0] ) {
        Foswiki::Configure::Load::expandValue($uri);
    }

    $uri =~ s/^\s*(.*?)\s*$/$1/ if defined $uri;

    return if ( !( defined $uri && length($uri) ) && $check{nullok}[0] );

    unless ( $uri =~ $uriRE ) {
        $reporter->ERROR("Syntax error: $uri is not a valid URI");
        return;
    }

    my ( $scheme, $authority, $path, $query, $fragment ) =
      ( $1, $2, $3, $4, $5 );
    undef $authority if ( defined $authority && !length $authority );
    undef $path      if ( defined $path      && !length $path );

    my $parts    = _vlist( \%check, 'parts' );
    my $partsReq = _vlist( \%check, 'partsreq' );

    if ( $parts->{scheme} ) {
        if ( defined $scheme ) {
            my $s = _vlist( \%check, 'schemes' );
            $reporter->ERROR("Scheme $scheme is not permitted in $uri")
              unless ( $s->{ lc $scheme } );
        }
        elsif ( $partsReq->{scheme} ) {
            $reporter->ERROR("Scheme is required in $uri");
        }
    }
    else {
        $reporter->ERROR("Scheme ($scheme) is not permitted in $uri")
          if ( defined $scheme );
    }
    $scheme = '' unless ( defined $scheme );

    if ( $parts->{authority} ) {
        if ( defined $authority ) {
            my $auth = $authority;
            if ( $auth =~ s/^([^:\@]+)(?::[^\@]+)?\@// ) {
                my ( $user, $pass ) = ( $1, $2 );
                if ( $check{user}[0] ) {
                    if ( defined $pass ) {
                        unless ( $check{pass}[0] ) {
                            $reporter->ERROR(
"Embedded password is not permitted in $uri"
                            );
                        }
                    }
                }
                else {
                    $reporter->ERROR(
"Embedded authentication is not permitted in $uri"
                    );
                }
            }
            my $hi = hostInfo($auth);
            if ( $hi->{error} ) {
                $reporter->ERROR(
"$auth is not a valid authority specifier: $hi->{error}"
                );
            }
            else {
                if ( $hi->{ipaddr} ) {
                    $reporter->ERROR(
                        "IP address is not permitted in $uri")
                      unless ( $check{authtype}[0] =~ /ip$/ );
                    $reporter->ERROR("IP address is required in $uri")
                      if ( $check{authtype}[0] eq 'ip' );
                    $reporter->ERROR(
"$auth is an IPv6 address, but Foswiki can not use it unless you install IO::Socket::IP"
                    ) if ( !$IPv6Avail && $hi->{ipv6addr} );
                }
                else {
                    if ( $check{authtype}[0] =~ /^host/ ) {
                        if ( !$IPv6Avail && @{ $hi->{v6addrs} } ) {
                            if ( @{ $hi->{v4addrs} } ) {
                                $reporter->NOTE(
"$auth has an IPv6 address, but Foswiki can not use it unless you install IO::Socket::IP"
                                );
                            }
                            else {
                                $reporter->ERROR(
"$auth only has an IPv6 address, but Foswiki can not use it unless you install IO::Socket::IP"
                                );
                            }
                        }
                        $reporter->ERROR(
"$auth has no IP addresses. Verify DNS or hostname."
                        ) unless ( @{ $hi->{addrs} } );
                    }
                    else {
                        $reporter->ERROR(
                            "Hostname is not permitted in $uri");
                    }
                }
            }
        }
        elsif ( $partsReq->{authority} ) {
            $reporter->ERROR(
"Authority ($check{authtype}[0]) is required in $uri"
            );
        }
    }
    else {
        $reporter->ERROR(
            "Authority ($authority) is not permitted in $uri")
          if ( defined $authority );
    }
    $authority = '' unless ( defined $authority );

    if ( $parts->{path} ) {
        if ( defined $path ) {
            if ( $scheme =~ /^https?$/i || !$parts->{scheme} ) {
                unless ( $path =~
m{^(?:/|(?:/(?:[~+a-zA-Z0-9\$_\@.&!*"'(),-]|%[[:xdigit:]]{2})+)*/?)$}
                  )
                {
                    $reporter->ERROR("Path ($path) is not valid");
                }
                if ( $check{notrail}[0] ) {
                    $path =~ s,/$,,;
                }
            }    # Checks for other schemes?
        }
        elsif ( $partsReq->{path} ) {
            $reporter->ERROR("Path is required in $uri");
        }
    }
    else {
        $reporter->ERROR("Path ($path) is not permitted in $uri")
          if ( defined $path );
    }
    $path = '' unless ( defined $path );

    if ( $parts->{query} ) {
        if ( defined $query ) {
            unless ( $query =~
                m{^\?(?:[a-zA-Z0-9\$_\@.&!*"'(),=&;-]|%[[:xdigit:]]{2})*$} )
            {
                $reporter->ERROR("Query ($query) is not valid");
            }
        }
        elsif ( $partsReq->{query} ) {
            $reporter->ERROR("Query is required in $uri");
        }
    }
    else {
        $reporter->ERROR("Query ($query) is not permitted in $uri")
          if ( defined $query );
    }
    $query = '' unless ( defined $query );

    if ( $parts->{fragment} ) {
        if ( defined $fragment ) {
            if ( $scheme =~ /^https?$/i ) {
                unless ( $fragment =~
                    m{^#(?:[a-zA-Z0-9\$_\@.&!*"'(),-]|%[[:xdigit:]]{2})*$} )
                {
                    $reporter->ERROR("Fragment ($fragment) is not valid");
                }
            }    # Checks for other schemes?
        }
        elsif ( $partsReq->{fragment} ) {
            $reporter->ERROR("Fragment is required in $uri");
        }
    }
    else {
        $reporter->ERROR(
            "Fragment ($fragment) is not permitted in $uri")
          if ( defined $fragment );
    }
    $fragment = '' unless ( defined $fragment );

    if ( eval "require URI;" ) {
        my $urio = URI->new($uri);
        if ($urio) {
            my $can   = $urio->canonical();
            my $canon = '';
            my $p     = $can->scheme;
            $canon .= $p . ':'
              if ( defined $p && $parts->{scheme} );
            $p = $can->authority;
            $canon .= '//' . $p
              if ( defined $p && $parts->{authority} );
            $p = $can->path;
            if ( defined $p && $parts->{path} ) {
                $canon .= $p;
                if ( $check{notrail}[0] ) {
                    $canon =~ s,/$,,;
                }
            }
            $p = $can->query;
            $canon .= '?' . $p
              if ( defined $p && $parts->{query} );
            $p = $can->fragment;
            $canon .= '#' . $p
              if ( defined $p && $parts->{fragment} );
            $uri = $canon;
        }
        else {
            $reporter->ERROR("Unable to parse $uri");
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
