# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::TAGS;

use strict;

use base 'Foswiki::Configure::UI';

use Foswiki::Configure::Type;
use Foswiki::Configure::Value;

sub ui {
    my %modules;
    my $scanner = Foswiki::Configure::Type::load('SELECTCLASS');
    my $classes = $scanner->findClasses('Foswiki::Tags::*');
    foreach my $module (@$classes) {
        $module =~ s/^.*::([^:]*)/$1/;
        $Foswiki::cfg{Tags}{$module}{Enabled} ||= 0;

        # only add the first instance of any tag, as only
        # the first can get loaded from @INC.
        unless ( $modules{$module} ) {
            $modules{$module} = 1;
        }
    }
    my $block = '';
    foreach my $m ( sort keys %modules ) {
        my $value = new Foswiki::Configure::Value(
            'BOOLEAN', '',

            # SMELL - i'm assuming that the Tag topic is in the SystemWeb :(
            # Which of course it isn't.
"<a rel=\"nofollow\" href=\"$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}/$Foswiki::cfg{SystemWebName}/$m\">$m</a>",
            '{Tags}{' . $m . '}{Enabled}'
        );
        $block .= $value->buildInputFields();
    }

    return $block;
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
