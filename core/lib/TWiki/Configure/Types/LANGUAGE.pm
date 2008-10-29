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
package TWiki::Configure::Types::LANGUAGE;

# Enable switch for the languages array
use strict;

use base 'TWiki::Configure::Types::BOOLEAN';

# When any language changes, delete the cache
sub onUpdate {
    my $this = shift;
    if ( -f $TWiki::cfg{LocalesDir}.'/languages.cache' ) {
        unlink($TWiki::cfg{LocalesDir}.'/languages.cache');
    }
    $this->SUPER::onUpdate(@_);
}

1;
