# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PERL;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ($this, $reporter) = @_;

    $this->showExpandedValue($reporter);

    my $value = $this->getCfgUndefOk();
    return '' if ( defined $value );

    return $this->ERROR("Unexpected undefined PERL value");
}

sub check_potential_value {
    my ($this, $string, $reporter) = @_;
 
    if ( defined $string ) {
        my $s = _rvalue($string);
        if ( $s ) {
            $reporter->ERROR("Cannot parse PERL value: failed at: '$s'");
        }
    }
}

# Simple parse of a perl value to determine if it matches a simple
# grammar. Returns the remainder of the string at the point completed.
# If the parse completed, this will be the empty string.
sub _rvalue {
    my ( $s, $term ) = @_;
    $s =~ s/^\s+(.*?)$/$1/s;
    while ( length($s) > 0 && ( !$term || $s !~ s/^\s*$term// ) ) {
        if ( $s =~ s/^\s*'//s ) {
            my $escaped = 0;
            while ( length($s) > 0 && $s =~ s/^(.)//s ) {
                last if ( $1 eq "'" && !$escaped );
                $escaped = ( $escaped ? 0 : $1 eq '\\' );
            }
        }
        elsif ( $s =~ s/^\s*"//s ) {
            my $escaped = 0;
            while ( length($s) > 0 && $s =~ s/^(.)//s ) {
                last if ( $1 eq '"' && !$escaped );
                $escaped = ( $escaped ? 0 : $1 eq '\\' );
            }
        }
        elsif ( $s =~ s/^\s*(\w+)//s ) {
        }
        elsif ( $s =~ s/^\s*\[//s ) {
            $s = _rvalue( $s, ']' );
        }
        elsif ( $s =~ s/^\s*{//s ) {
            $s = _rvalue( $s, '}' );
        }
        elsif ( $s =~ s/^\s*(,|=>)//s ) {
        }
        else {
            last;
        }
    }
    $s =~ s/^\s+//s;

    return $s;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
