# Copyright (C) 2005 ILOG http://www.ilog.fr
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
#equire 5.006;

package WysiwygPluginSuite;

use strict;

use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub include_tests {
    return qw(TranslatorTests ExtendedTranslatorTests WysiwygPluginTests);
}

1;
