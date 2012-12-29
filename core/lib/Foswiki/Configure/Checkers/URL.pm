# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::URL;

use strict;
use warnings;

use Foswiki::IP qw/$IPv6Avail :regexp :info/;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

=begin TML

---++ ObjectMethod check($valobj) -> $checkmsg

This is a generic (item-independent) checker for URIs.

This checker is the default for items of type URL.  It can be subclassed
if an individual item needs additional checks, but for most items, this is
all that is necessary.

This checker is normally instantiated by Types/URL (see =makeChecker=).

CHECK= options:
   * expand = expand $Foswiki::cfg variables in value
   * nullok = allow item to be empty
   * parts:scheme,authority,path,query,fragment
          Parts allowed in item
          Default: scheme,authority,path
   * notrail = remove trailing / from (https?) paths
   * partsreq = Parts required in item
   * schemes = schemes allowd in item
          Default: http,https
   * authtype = authority types allowed in item
          host - dns hostname
          ip   - IP address
          hostip = hostname or IP address
          Default: host
   * user = Permit user@host syntax
   * pass = Permit user:pass@host syntax
   * list:regexp = Allow a list of URLS delimited by regexp.
     (Default:'\\\\s+') No capturing ()s allowed.  Do not include
     characters valid in URL (e.g. ',' if path/query/frag allowed.)

=cut

# Fallback validation expression:
# (scheme, authority, path, query, frag)

my $uriRE =
  qr|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|o;

sub vlist {
    my ( $options, $item ) = @_;

    return { map { $_ => 1 } @{ $options->{$item} || [] } };
}

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = ref($valobj) ? $valobj->getKeys() : $valobj
      or die "No keys for value";

    my $e = '';
    my $n = '';

    my @optionList = ( @_ ? @_ : $this->parseOptions() );

    $optionList[0] = {} unless (@optionList);

    $e .= $this->ERROR(".SPEC error: multiple CHECK options for URL $keys")
      if ( @optionList > 1 );

    my $options = $optionList[0];

    $options->{expand}   ||= [0];
    $options->{parts}    ||= [qw/scheme authority path/];
    $options->{partsreq} ||= [qw/scheme authority/];
    $options->{schemes}  ||= [qw/http https/];
    $options->{authtype} ||= ['host'];
    $options->{notrail}  ||= [0];
    $options->{pass}     ||= [0];
    $options->{user}     ||= $options->{pass}[0] ? [1] : [0];

    my $value   = $this->getItemCurrentValue($keys);
    my $baseval = $value;

    if ( $options->{expand}[0] ) {
        Foswiki::Configure::Load::expandValue($value);
        $n .= $this->showExpandedValue($baseval);
    }

    $baseval = $value;
    if ( defined $value ) {
        $value =~ s/^\s+//;
        $value =~ s/\s+$//;
    }
    return "$e$n"
      if ( !$value && $options->{nullok}[0] );

    my @values = $value || '';
    if ( my $regex = $options->{list}[0] ) {
        if ( $regex eq '1' ) {    # default (1) is not a sensible regex.
            $regex = '\\s+';
        }
        @values = split( qr/($regex)/, $value );
    }

    my $i        = 0;
    my $newValue = '';
    my $list     = @values > 1;

    while (@values) {
        my ( $value, $delim ) = splice( @values, 0, 2 );
        $i++;
        my $id = $list ? "Item $i \"$value\": " : '';

        unless ($value) {
            $e .= $this->ERROR("${id}Empty list item");
            next;
        }
        my ( $note, $err, $newval ) =
          $this->_checkEntry( $id, $options, $value );

        $n        .= $note;
        $e        .= $err;
        $newValue .= $newval;
        $newValue .= $delim if ( defined $delim && @values );
    }

    if ( $newValue ne $baseval && !$e ) {
        $this->setItemValue( $newValue, $keys );
        if ( exists $this->{GuessedValue} ) {
            $this->{GuessedValue} = $newValue;
        }
        else {
            $this->{UpdatedValue} = $newValue;
        }
    }

    $n .= $this->guessed(0)
      if ( $this->{GuessedValue} && !$this->{FeedbackProvided} );

    return $n . $e;
}

sub _checkEntry {
    my $this = shift;
    my ( $id, $options, $value ) = @_;

    my $e = '';
    my $n = '';

    return ( '', $this->ERROR("${id}Syntax error: not a valid URI"), $value )
      unless ( $value =~ $uriRE );

    my ( $scheme, $authority, $path, $query, $fragment ) =
      ( $1, $2, $3, $4, $5 );
    undef $authority if ( defined $authority && !length $authority );
    undef $path      if ( defined $path      && !length $path );

    my $parts    = vlist( $options, 'parts' );
    my $partsReq = vlist( $options, 'partsreq' );

    if ( $parts->{scheme} ) {
        if ( defined $scheme ) {
            my $s = vlist( $options, 'schemes' );
            $e .= $this->ERROR("${id}$scheme is not permitted for this item")
              unless ( $s->{ lc $scheme } );
        }
        elsif ( $partsReq->{scheme} ) {
            $e .= $this->ERROR("${id}Scheme is required for this item");
        }
    }
    else {
        $e .= $this->ERROR("${id}Scheme is not permitted for this item")
          if ( defined $scheme );
    }
    $scheme = '' unless ( defined $scheme );

    if ( $parts->{authority} ) {
        if ( defined $authority ) {
            my $auth = $authority;
            if ( $auth =~ s/^([^:\@]+)(?::[^\@]+)?\@// ) {
                my ( $user, $pass ) = ( $1, $2 );
                if ( $options->{user}[0] ) {
                    if ( defined $pass ) {
                        unless ( $options->{pass}[0] ) {
                            $e .= $this->ERROR(
"${id}Embedded password is not permitted for this item"
                            );
                        }
                    }
                }
                else {
                    $e .= $this->ERROR(
"${id}Embedded authentication is not permitted for this item"
                    );
                }
            }
            my $hi = hostInfo($auth);
            if ( $hi->{error} ) {
                $e .= $this->ERROR(
"${id}$auth is not a valid authority specifier: $hi->{error}"
                );
            }
            else {
                if ( $hi->{ipaddr} ) {
                    $e .= $this->ERROR(
                        "${id}IP address is not permitted for this item")
                      unless ( $options->{authtype}[0] =~ /ip$/ );
                    $e .=
                      $this->ERROR("${id}IP address is required for this item")
                      if ( $options->{authtype}[0] eq 'ip' );
                    $e .= $this->ERROR(
"${id}$auth is an IPv6 address, but Foswiki can not use it unless you install IO::Socket::IP"
                    ) if ( !$e && !$IPv6Avail && $hi->{ipv6addr} );
                }
                else {
                    if ( $options->{authtype}[0] =~ /^host/ ) {
                        if ( !$IPv6Avail && @{ $hi->{v6addrs} } ) {
                            if ( @{ $hi->{v4addrs} } ) {
                                $n .= $this->NOTE(
"${id}$auth has an IPv6 address, but Foswiki can not use it unless you install IO::Socket::IP"
                                );
                            }
                            else {
                                $e .= $this->ERROR(
"${id}$auth only has an IPv6 address, but Foswiki can not use it unless you install IO::Socket::IP"
                                );
                            }
                        }
                        $e .= $this->ERROR("${id}$auth has no IP addresses")
                          unless ( @{ $hi->{addrs} } );
                    }
                    else {
                        $e .= $this->ERROR(
                            "${id}Hostname is not permitted for this item");
                    }
                }
            }
        }
        elsif ( $partsReq->{authority} ) {
            $e .= $this->ERROR(
"${id}Authority ($options->{authtype}[0]) is required for this item"
            );
        }
    }
    else {
        $e .= $this->ERROR("${id}Authority is not permitted for this item")
          if ( defined $authority );
    }
    $authority = '' unless ( defined $authority );

    if ( $parts->{path} ) {
        if ( defined $path ) {
            if ( $scheme =~ /^https?$/i || !$parts->{scheme} ) {
                unless ( $path =~
m{^(?:/|(?:/(?:[~+a-zA-Z0-9\$_\@.&!*"'(),-]|%[[:xdigit:]]{2})+)*)$}
                  )
                {
                    $e .= $this->ERROR("${id}Path is not valid");
                }
                if ( $options->{notrail}[0] ) {
                    $path =~ s,/$,,;
                }
            }    # Checks for other schemes?
        }
        elsif ( $partsReq->{path} ) {
            $e .= $this->ERROR("${id}Path is required for this item");
        }
    }
    else {
        $e .= $this->ERROR("${id}Path is not permitted for this item")
          if ( defined $path );
    }
    $path = '' unless ( defined $path );

    if ( $parts->{query} ) {
        if ( defined $query ) {
            unless ( $query =~
                m{\?(?:[a-zA-Z0-9\$_\@.&!*"'(),-]|%[[:xdigit:]]{2})*} )
            {
                $e .= $this->ERROR("${id}Query is not valid");
            }
        }
        elsif ( $partsReq->{query} ) {
            $e .= $this->ERROR("${id}Query is required for this item");
        }
    }
    else {
        $e .= $this->ERROR("${id}Query is not permitted for this item")
          if ( defined $query );
    }
    $query = '' unless ( defined $query );

    if ( $parts->{fragment} ) {
        if ( defined $fragment ) {
            if ( $scheme =~ /^https?$/i ) {
                unless ( $fragment =~
                    m{#(?:[a-zA-Z0-9\$_\@.&!*"'(),-]|%[[:xdigit:]]{2})*} )
                {
                    $e .= $this->ERROR("${id}Fragment is not valid");
                }
            }    # Checks for other schemes?
        }
        elsif ( $partsReq->{fragment} ) {
            $e .= $this->ERROR("${id}Fragment is required for this item");
        }
    }
    else {
        $e .= $this->ERROR("${id}Fragment is not permitted for this item")
          if ( defined $fragment );
    }
    $fragment = '' unless ( defined $fragment );

    if ( eval "require URI;" ) {
        my $uri = URI->new($value);
        if ($uri) {
            my $can   = $uri->canonical();
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
                if ( $options->{notrail}[0] ) {
                    $canon =~ s,/$,,;
                }
            }
            $p = $can->query;
            $canon .= '?' . $p
              if ( defined $p && $parts->{query} );
            $p = $can->fragment;
            $canon .= '#' . $p
              if ( defined $p && $parts->{fragment} );
            $value = $canon;
        }
        else {
            $e .= $this->ERROR("${id}Unable to parse $value");
        }
    }

    return ( $n, $e, $value );
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    my $keys = $valobj->getKeys();

    delete $this->{FeedbackProvided};

    if ( defined $this->{GuessedValue} ) {
        $e .=
            $this->guessed(0)
          . $this->FB_VALUE( $keys, delete $this->{GuessedValue} );
    }
    elsif ( defined $this->{UpdatedValue} ) {
        $e .= $this->FB_VALUE( $keys, delete $this->{UpdatedValue} );
    }
    if ( delete $this->{JSContent} ) {
        $e .= $this->FB_ACTION( $keys, 'j' );
    }

    return wantarray ? ( $e, 0 ) : $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
