# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::URL;

use strict;
use warnings;

use Assert;

use Foswiki::IP qw/$IPv6Avail :regexp :info/;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

# This is a generic (item-independent) checker for URIs.
#
# CHECK options:
#    * expand = expand $Foswiki::cfg variables in value
#    * undefok = allow item to be empty
#    * parts:scheme,authority,path,query,fragment
#           Parts allowed in item
#           Default: scheme,authority,path
#    * trail = allow trailing / on (https?) paths
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
# CHECK options default to whatever is in the model if not provided

# Fallback validation expression:
# (scheme, authority, path, query, frag)
# Technically, ? & # aren't part of query or frag, but including
# them makes parsing and error reporting easier.

my $uriRE = qr|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(\?[^#]*)?(#.*)?|o;

sub check_current_value {
    my ( $this, $reporter ) = @_;
    my $keys = $this->{item}->{keys};

    my $val = $this->checkExpandedValue($reporter);

    checkURI( $reporter, $val, %{ $this->{item}->{CHECK} } );
}

sub _list2hash {
    my ($item) = @_;

    return map { $_ => 1 } @{ $item || [] };
}

sub checkURI {
    my ( $reporter, $uri, %checks ) = @_;

    if ( defined $uri && $uri eq '' ) {
        $reporter->ERROR("Not a valid URI") unless $checks{emptyok};
        return;
    }
    unless ( defined $uri ) {
        $reporter->ERROR("Not a valid URI") unless $checks{undefok};
        return;
    }

    # Apply defaults
    $checks{parts}    ||= [qw/scheme authority path/];
    $checks{partsreq} ||= [qw/scheme authority/];
    $checks{schemes}  ||= [qw/http https/];
    $checks{authtype} ||= ['host'];
    $checks{trail} = 1             unless defined $checks{trail};
    $checks{pass}  = 0             unless defined $checks{pass};
    $checks{user}  = $checks{pass} unless defined $checks{user};

    $uri =~ s/^\s*(.*?)\s*$/$1/ if defined $uri;

    return if ( !( defined $uri && length($uri) ) && $checks{undefok} );

    unless ( $uri =~ $uriRE ) {
        $reporter->ERROR("Syntax error: $uri is not a valid URI");
        return;
    }

    my ( $scheme, $authority, $path, $query, $fragment ) =
      ( $1, $2, $3, $4, $5 );
    undef $authority if ( defined $authority && !length $authority );
    undef $path      if ( defined $path      && !length $path );

    my %parts    = _list2hash( $checks{parts} );
    my %partsreq = _list2hash( $checks{partsreq} );

    if ( $parts{scheme} ) {
        if ( defined $scheme && scalar( @{ $checks{schemes} } ) ) {
            my %s = _list2hash( $checks{schemes} );
            $reporter->ERROR("Scheme '$scheme' is not permitted in $uri")
              unless ( $s{ lc $scheme } );
        }
        elsif ( $partsreq{scheme} ) {
            $reporter->ERROR("Scheme (e.g. http:) is required in $uri");
        }
    }
    else {
        $reporter->ERROR("Scheme '$scheme' is not permitted in $uri")
          if ( defined $scheme );
    }
    $scheme = '' unless ( defined $scheme );

    if ( $parts{authority} ) {
        if ( defined $authority ) {
            my $auth = $authority;
            if ( $auth =~ s/^([^:\@]+)(?::[^\@]+)?\@// ) {
                my ( $user, $pass ) = ( $1, $2 );
                if ( $checks{user} ) {
                    if ( defined $pass ) {
                        unless ( $checks{pass} ) {
                            $reporter->ERROR(
                                "Embedded password is not permitted in $uri");
                        }
                    }
                }
                else {
                    $reporter->ERROR(
                        "Embedded authentication is not permitted in $uri");
                }
            }
            my $hi = hostInfo($auth);
            if ( $hi->{error} ) {
                $reporter->WARN(
"$auth is not a valid authority specifier (hostname). Lookup returned: $hi->{error}"
                );
            }
            else {
                if ( $hi->{ipaddr} ) {
                    $reporter->ERROR("IP address is not permitted in $uri")
                      unless ( $checks{authtype}[0] =~ m/ip$/ );
                    $reporter->ERROR("IP address is required in $uri")
                      if ( $checks{authtype}[0] eq 'ip' );
                    $reporter->ERROR(
"$auth is an IPv6 address, but Foswiki can not use it unless you install IO::Socket::IP"
                    ) if ( !$IPv6Avail && $hi->{ipv6addr} );
                }
                else {
                    if ( $checks{authtype}[0] =~ m/^host/ ) {
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
                        $reporter->ERROR("Hostname is not permitted in $uri");
                    }
                }
            }
        }
        elsif ( $partsreq{authority} ) {
            $reporter->ERROR(
                "Authority ($checks{authtype}[0]) is required in $uri");
        }
    }
    else {
        $reporter->ERROR("Authority ($authority) is not permitted in $uri")
          if ( defined $authority );
    }
    $authority = '' unless ( defined $authority );

    if ( $parts{path} ) {
        if ( defined $path ) {
            if ( $scheme =~ m/^https?$/i || !$parts{scheme} ) {
                unless ( $path =~
m{^(?:/|(?:/(?:[~+a-zA-Z0-9\$_\@.&!*"'(),-]|%[[:xdigit:]]{2})+)*/?)$}
                  )
                {
                    $reporter->ERROR("Path ($path) is not valid");
                }
                if ( !$checks{trail} && $path =~ m{/$} ) {
                    $reporter->ERROR("Trailing / not allowed");
                }
            }    # Checks for other schemes?
        }
        elsif ( $partsreq{path} ) {
            $reporter->ERROR("Path is required in $uri");
        }
    }
    else {
        $reporter->ERROR("Path ($path) is not permitted in $uri")
          if ( defined $path );
    }
    $path = '' unless ( defined $path );

    if ( $parts{query} ) {
        if ( defined $query ) {
            unless ( $query =~
                m{^\?(?:[a-zA-Z0-9\$_\@.&!*"'(),=&;-]|%[[:xdigit:]]{2})*$} )
            {
                $reporter->ERROR("Query ($query) is not valid");
            }
        }
        elsif ( $partsreq{query} ) {
            $reporter->ERROR("Query is required in $uri");
        }
    }
    else {
        $reporter->ERROR("Query ($query) is not permitted in $uri")
          if ( defined $query );
    }
    $query = '' unless ( defined $query );

    if ( $parts{fragment} ) {
        if ( defined $fragment ) {
            if ( $scheme =~ m/^https?$/i ) {
                unless ( $fragment =~
                    m{^#(?:[a-zA-Z0-9\$_\@.&!*"'(),-]|%[[:xdigit:]]{2})*$} )
                {
                    $reporter->ERROR("Fragment ($fragment) is not valid");
                }
            }    # Checks for other schemes?
        }
        elsif ( $partsreq{fragment} ) {
            $reporter->ERROR("Fragment is required in $uri");
        }
    }
    else {
        $reporter->ERROR("Fragment ($fragment) is not permitted in $uri")
          if ( defined $fragment );
    }
    $fragment = '' unless ( defined $fragment );

    if ( eval('require URI') ) {
        my $urio = URI->new($uri);
        unless ($urio) {
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
