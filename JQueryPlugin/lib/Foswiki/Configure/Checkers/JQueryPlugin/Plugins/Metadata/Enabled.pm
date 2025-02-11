# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::JQueryPlugin::Plugins::Metadata::Enabled;

use warnings;
use strict;

use Foswiki::Configure::Checker ();
our @ISA = qw( Foswiki::Configure::Checker );

sub check_current_value {
    my ( $this, $reporter ) = @_;

    if ( $Foswiki::cfg{JQueryPlugin}{Plugins}{Metadata}{Enabled} ) {
        $reporter->WARN(<<'HERE');
Meta has been deprecated. Please use HTML5 data attribures instead. 
HERE
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2025 Foswiki Contributors. Foswiki Contributors
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
