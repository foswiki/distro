# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Plugins::EditRowPlugin::Enabled;
use v5.14;

use Moo;
extends qw(Foswiki::Configure::Checker);

sub check {
    my ( $this, $value ) = @_;

    my $resp;

    if (   $Foswiki::cfg{Plugins}{EditTablePlugin}{Enabled}
        && $Foswiki::cfg{Plugins}{EditRowPlugin}{Enabled} )
    {
        if (   $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro}
            && $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro} eq 'EDITTABLE' )
        {
            $resp = $this->ERROR(<<MESSAGE);
={Plugins}{EditRowPlugin}{Macro}= is currently set to EDITTABLE and will conflict
with the EditTablePlugin.  Recommend changing it to EDITROW, or disable the EditTablePlugin
MESSAGE
        }
        $resp .= $this->WARN(<<MESSAGE);
Enabling both EditTablePlugin and EditRowPlugin is considered experimental.
MESSAGE
    }
    if ( $Foswiki::cfg{Plugins}{EditTablePlugin}{Enabled} ) {
        $resp .= $this->WARN(<<MESSAGE);
EditTablePlugin is being phased out and replaced by EditRowPlugin.
Please consider switching
MESSAGE
    }
    return $resp if ($resp);

    return $this->NOTE("This plugin replaces EditTablePlugin");
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012-2015 Foswiki Contributors. Foswiki Contributors
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
