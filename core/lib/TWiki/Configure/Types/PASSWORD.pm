#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
package TWiki::Configure::Types::PASSWORD;

use strict;

use TWiki::Configure::Types::STRING;

use base 'TWiki::Configure::Types::STRING';

sub prompt {
    my( $this, $id, $opts, $value ) = @_;
    my $size = '55%';
    if( $opts =~ /\s(\d+)\s/ ) {
        $size = $1;
        # These numbers are somewhat arbitrary..
        if ($size > 25) {
            $size = '55%';
        }
    }

    return CGI::password_field( -name => $id, -size=>$size, -default=>$value, -autocomplete=>'off' );
}

1;
