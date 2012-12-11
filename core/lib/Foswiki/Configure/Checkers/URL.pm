# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::URL;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
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
   * parts:scheme,authority,path,query,fragment
          Parts allowed in item
          Default: scheme,authority,path
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

=cut

# Fallback validation expression:
# (scheme, authority, path, query, frag)

my $uriRE =
  qr|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|o;

# IPv6 - Regexp::Ipv6 needed
my $ipAddrRE = qr/^(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\.
                   (?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\.
                   (?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\.
                   (?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])$/x;

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

    $e .= $this->ERROR(".SPEC error: multiple CHECK options for NUMBER")
      if ( @optionList > 1 );

    my $options = $optionList[0];

    $options->{expand}   ||= [0];
    $options->{parts}    ||= [qw/scheme authority path/];
    $options->{partsreq} ||= [qw/scheme authority/];
    $options->{schemes}  ||= [qw/http https/];
    $options->{authtype} ||= ['host'];
    $options->{pass}     ||= [0];
    $options->{user}     ||= $options->{pass}[0] ? [1] : [0];

    my $value   = $this->getItemCurrentValue($keys);
    my $baseval = $value;

    if ( $options->{expand}[0] ) {
        Foswiki::Configure::Load::expandValue($value);
        $n .= $this->showExpandedValue($baseval);
    }

    return "$e$n"
      if ( !$value && $options->{nullok}[0] );

    $e .= $this->guessed(0)
      if ( $this->{GuessedValue} && !$this->{FeedbackProvided} );

    if ( $value =~ $uriRE ) {
        my ( $scheme, $authority, $path, $query, $fragment ) =
          ( $1, $2, $3, $4, $5 );
        undef $authority if ( defined $authority && !length $authority );
        undef $path      if ( defined $path      && !length $path );

        my $parts    = vlist( $options, 'parts' );
        my $partsReq = vlist( $options, 'partsreq' );

        if ( $parts->{scheme} ) {
            if ( defined $scheme ) {
                my $s = vlist( $options, 'schemes' );
                $e .= $this->ERROR("$scheme is not permitted for this item")
                  unless ( $s->{ lc $scheme } );
            }
            elsif ( $partsReq->{scheme} ) {
                $e .= $this->ERROR("Scheme is required for this item");
            }
        }
        else {
            $e .= $this->ERROR("Scheme is not permitted for this item")
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
"Embedded password is not permitted for this item"
                                );
                            }
                        }
                    }
                    else {
                        $e .= $this->ERROR(
"Embedded authentication is not permitted for this item"
                        );
                    }
                }
                if ( $auth =~ /^(?:$ipAddrRE|\[$ipAddrRE\])(?::\d+)?$/ ) {
                    $this->ERROR("IP address is not permitted for this item")
                      unless ( $options->{authtype}[0] =~ /ip$/ );
                }
                elsif ( $auth =~ /^([^:]+)(?::(\d+))?$/ ) {
                    my ( $host, $port ) = ( $1, $2 );
                    if ( $options->{authtype}[0] =~ /^host/ ) {
                        unless ( gethostbyname($host) ) {
                            $e .= $this->ERROR("$host is not a valid hostname");
                        }
                    }
                    else {
                        $e .= $this->ERROR(
                            "Hostname is not permitted for this item");
                    }
                }
                else {
                    $e .=
                      $this->ERROR("$auth is not a valid authority specifier");
                }
            }
            elsif ( $partsReq->{authority} ) {
                $e .= $this->ERROR(
"Authority ($options->{authtype}[0]) is required for this item"
                );
            }
        }
        else {
            $e .= $this->ERROR("Authority is not permitted for this item")
              if ( defined $authority );
        }
        $authority = '' unless ( defined $authority );

        if ( $parts->{path} ) {
            if ( defined $path ) {
                if ( $scheme =~ /^https?$/i || !$parts->{scheme} ) {
                    unless (
                        $path =~ m,^(?:/|(?:/(?:\w|%[[:xdigit:]]{2})+)*)$, )
                    {
                        $e .= $this->ERROR("Path is not valid");
                    }
                }    # Checks for other schemes?
            }
            elsif ( $partsReq->{path} ) {
                $e .= $this->ERROR("Path is required for this item");
            }
        }
        else {
            $e .= $this->ERROR("Path is not permitted for this item")
              if ( defined $path );
        }
        $path = '' unless ( defined $path );

        if ( $parts->{query} ) {
            if ( defined $query ) {
                ;    # Validate?
            }
            elsif ( $partsReq->{query} ) {
                $e .= $this->ERROR("Query is required for this item");
            }
        }
        else {
            $e .= $this->ERROR("Query is not permitted for this item")
              if ( defined $query );
        }
        $query = '' unless ( defined $query );

        if ( $parts->{fragment} ) {
            if ( defined $fragment ) {
                if ( $scheme =~ /^https?$/i ) {
                    unless ( $fragment =~ m,(?:/(?:\w|%[[:xdigit:]]{2}))*, ) {
                        $e .= $this->ERROR("Fragment is not valid");
                    }
                }    # Checks for other schemes?
            }
            elsif ( $partsReq->{fragment} ) {
                $e .= $this->ERROR("Fragment is required for this item");
            }
        }
        else {
            $e .= $this->ERROR("Fragment is not permitted for this item")
              if ( defined $fragment );
        }
        $fragment = '' unless ( defined $fragment );

        if ( eval "require URI;" ) {
            my $uri = URI->new($value);
            if ($uri) {
                my $canon = $uri->canonical();
                if ( $canon ne $value ) {
                    $this->setItemValue( $canon, $keys );
                    if ( exists $this->{GuessedValue} ) {
                        $this->{GuessedValue} = $canon;
                    }
                    else {
                        $this->{UpdatedValue} = $canon;
                    }
                }
            }
            else {
                $e .= $this->ERROR("Unable to parse $value");
            }
        }
    }
    else {
        $e .= $this->ERROR("Syntax error: not a valid URI");
    }

    return $n . $e;
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    my $keys = $valobj->getKeys();

    delete $this->{FeedbackProvided};

    if ( $this->{GuessedValue} ) {
        $e .=
            $this->guessed(0)
          . $this->FB_VALUE( $keys, delete $this->{GuessedValue} );
    }
    elsif ( $this->{UpdatedValue} ) {
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
