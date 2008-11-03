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
#
# The root of all configurations
package TWiki::Configure::Root;

use TWiki::Configure::Section;

use base 'TWiki::Configure::Section';

use strict;

sub new {
    my $class = shift;
    my $this = bless( $class->SUPER::new( 'root', 0 ), $class );
    return $this;
}

1;
