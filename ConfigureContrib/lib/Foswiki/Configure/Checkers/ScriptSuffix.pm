# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ScriptSuffix;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $currentSuffix;
    require Foswiki::Configure::CGI;
    my $scriptName = Foswiki::Configure::CGI::getScriptName();
    ($currentSuffix) = $scriptName =~ m/configure(.*)$/;

    if ( defined $currentSuffix && $currentSuffix ) {
        return $this->WARN( 'this script ('
              . $scriptName
              . ') has a different suffix than the current ScriptSuffix setting ('
              . $Foswiki::cfg{ScriptSuffix}
              . ')' )
          unless ( $Foswiki::cfg{ScriptSuffix} eq $currentSuffix );
    }
    else {
        return $this->WARN( 'this script ('
              . $scriptName
              . ') does not use the script suffix ('
              . $Foswiki::cfg{ScriptSuffix}
              . ')' )
          if ( $Foswiki::cfg{ScriptSuffix} );
    }
    return '';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
