# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Plugins::EditRowPlugin::Enabled;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my ( $this, $value ) = @_;

    if (   $Foswiki::cfg{Plugins}{EditTablePlugin}{Enabled}
        && $Foswiki::cfg{Plugins}{EditRowPlugin}{Enabled} )
    {
        return $this->ERROR(<<MESSAGE);
Cannot enable both EditTablePlugin and EditRowPlugin at the same time.
Please choose one (EditRowPlugin if you are unsure)
MESSAGE
    }
    if ( $Foswiki::cfg{Plugins}{EditTablePlugin}{Enabled} ) {
        return $this->WARN(<<MESSAGE);
EditTablePlugin is being phased out and replaced by EditRowPlugin.
Please consider switching
MESSAGE
    }

    return $this->NOTE("This plugin replaces EditTablePlugin");
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
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
