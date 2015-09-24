# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub URLPARAM {
    my ( $this, $params ) = @_;
    my $param     = $params->{_DEFAULT} || '';
    my $newLine   = $params->{newline};
    my $encode    = $params->{encode} || 'safe';
    my $multiple  = $params->{multiple};
    my $separator = $params->{separator};
    my $default   = $params->{default};

    $separator = "\n" unless ( defined $separator );

    my $value = '';
    if ( $this->{request} ) {
        if ( Foswiki::isTrue($multiple) ) {
            my @valueArray = $this->{request}->multi_param($param);
            if (@valueArray) {

                # join multiple values properly
                unless ( $multiple =~ m/^on$/i ) {
                    my $item = '';
                    @valueArray = map {
                        $item = $_;
                        $_    = $multiple;
                        $_ .= $item unless (s/\$item/$item/g);
                        expandStandardEscapes($_)
                    } @valueArray;
                }

                # SMELL: the $separator is not being encoded
                $value = join(
                    $separator,
                    map {
                        _handleURLPARAMValue( $_, $newLine, $encode, $default )
                    } @valueArray
                );
            }
            else {
                $value = $default;
                $value = '' unless defined $value;
            }
        }
        else {
            $value = $this->{request}->param($param);
            $value =
              _handleURLPARAMValue( $value, $newLine, $encode, $default );
        }
    }
    return $value;
}

sub _handleURLPARAMValue {
    my ( $value, $newLine, $encode, $default ) = @_;

    if ( defined $value ) {
        $value =~ s/\r?\n/$newLine/g if ( defined $newLine );
        foreach my $e ( split( /\s*,\s*/, $encode ) ) {
            if ( $e =~ m/entit(y|ies)/i ) {
                $value = entityEncode($value);
            }
            elsif ( $e =~ m/^quotes?$/i ) {
                $value =~
                  s/\"/\\"/g; # escape quotes with backslash (Bugs:Item3383 fix)
            }
            elsif ( $e =~ m/^url$/i ) {

                # Legacy, see ENCODE
                #$value =~ s/\r*\n\r*/<br \/>/;
                $value = urlEncode($value);
            }
            elsif ( $e =~ m/^safe$/i ) {

                # entity encode ' " < > and %
                $value =~ s/([<>%'"])/'&#'.ord($1).';'/ge;
            }
        }
    }
    unless ( defined $value ) {
        $value = $default;
        $value = '' unless defined $value;
    }

    # Block expansion of %URLPARAM in the value to prevent recursion
    $value =~ s/%URLPARAM\{/%<nop>URLPARAM{/g;
    return $value;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
