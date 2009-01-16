# See bottom of file for license and copyright information

#
# A placeholder in a configuration representing a pluggable UI block.
# A pluggable block has special semantics, may have a special UI which
# may override the behaviors of a standard item. Normally pluggables
# are sections, containing values and other sections. If this isn't
# appropriate, you will have to implement a new visit() function for
# saving configuration data.
package Foswiki::Configure::Pluggable;

use strict;

use Foswiki::Configure::Section;

use base 'Foswiki::Configure::Section';

sub load {
    my ($name) = @_;

    my $modelName = 'Foswiki::Configure::' . $name;
    eval "use $modelName";
    Carp::confess $@ if $@;

    no strict 'refs';
    my $model = $modelName->new();
    use strict 'refs';

    return $model;
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
