# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PLUGIN_ENABLED;

# Common (type) checker used by all {Plugins}{Enabled} sub-keys.
# It is selected in Pluggables/PLUGINS. It should *not* be used in
# .spec files.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Checkers::PLUGIN_MODULE ();

sub check_current_value {
    # Disable this to prevent recursion
}

sub check_potential_value {
    my ($this, $reporter) = @_;

    if ($this->getCfg()) {
        Foswiki::Configure::Checkers::PLUGIN_MODULE::check_current_value(
            $this, $reporter);
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
