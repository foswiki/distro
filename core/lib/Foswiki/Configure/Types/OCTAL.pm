# See bottom of file for license and copyright information

package Foswiki::Configure::Types::OCTAL;

use strict;

use Foswiki::Configure::Types::NUMBER;

use base 'Foswiki::Configure::Types::NUMBER';

sub prompt {
    my ( $this, $id, $opts, $value ) = @_;
    return CGI::textfield(
        -name    => $id,
        -size    => 20,
        -default => sprintf( '0%o', $value ),
        -class   => 'foswikiInputField',
    );
}

sub string2value {
    my ( $this, $val ) = @_;
    $val ||= 0;
    $val = '0' . $val unless $val =~ /^0/;
    $val =~ /(\d+)/;
    $val = $1;    # protect the eval, just in case
                  # Use eval to force octal-decimal conversion (Item3529)
    eval "\$val = $val";
    return $val;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
