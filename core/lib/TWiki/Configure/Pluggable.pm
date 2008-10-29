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
# A placeholder in a configuration representing a pluggable UI block.
# A pluggable block has special semantics, may have a special UI which
# may override the behaviors of a standard item. Normally pluggables
# are sections, containing values and other sections. If this isn't
# appropriate, you will have to implement a new visit() function for
# saving configuration data.
package TWiki::Configure::Pluggable;

use strict;

use TWiki::Configure::Section;

use base 'TWiki::Configure::Section';

sub load {
    my ($name) = @_;

    my $modelName = 'TWiki::Configure::'.$name;
    eval "use $modelName";
    Carp::confess $@ if $@;

    no strict 'refs';
    my $model = $modelName->new();
    use strict 'refs';

    return $model;
}

1;
