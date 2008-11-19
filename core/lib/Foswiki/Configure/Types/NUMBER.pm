#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2006 Foswiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
package Foswiki::Configure::Types::NUMBER;

use strict;

use Foswiki::Configure::Type;

use base 'Foswiki::Configure::Type';

sub prompt {
    my ( $this, $id, $opts, $value ) = @_;
    unless ( $opts =~ /\s(\d+)\s/ ) {

        # fix the size
        $opts .= ' 20 ';
    }
    return $this->SUPER::prompt( $id, $opts, $value );
}

sub string2value {
    my ( $this, $val ) = @_;
    $val ||= 0;
    return 0 + $val;
}

sub equals {
    my ( $this, $val, $def ) = @_;

    return $val + 1 == $def + 1;
}

1;
