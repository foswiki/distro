# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WEB;

# Default checker for WEBTOPIC items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#
#   exists:{webname} - Web or WebTopic must exist.   If a {webname} key is provided,
#                      it will be used as the default web to check.
#
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Assert;
use Foswiki::Configure::Checker            ();
use Foswiki::Configure::Checkers::WEBTOPIC ();
our @ISA = ('Foswiki::Configure::Checkers::WEBTOPIC');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    $this->SUPER::check_current_value($reporter);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2018 Foswiki Contributors. Foswiki Contributors
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
