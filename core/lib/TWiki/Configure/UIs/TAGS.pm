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
package TWiki::Configure::UIs::TAGS;

use strict;

use base 'TWiki::Configure::UI';

use TWiki::Configure::Type;
use TWiki::Configure::Value;

sub ui {
    my %modules;
    my $scanner = TWiki::Configure::Type::load('SELECTCLASS');
    my $classes = $scanner->findClasses('TWiki::Tags::*');
    foreach my $module ( @$classes ) {
        $module =~ s/^.*::([^:]*)/$1/;
        $TWiki::cfg{Tags}{$module}{Enabled} ||= 0;
        # only add the first instance of any tag, as only
        # the first can get loaded from @INC.
        unless( $modules{$module} ) {
            $modules{$module} = 1;
        }
    }
    my $block = '';
    foreach my $m ( sort keys %modules ) {
        my $value = new TWiki::Configure::Value(
            'BOOLEAN', '',
            # SMELL - i'm assuming that the Tag topic is in the SystemWeb :(
            # Which of course it isn't.
            "<a rel=\"nofollow\" href=\"$TWiki::cfg{ScriptUrlPath}/view$TWiki::cfg{ScriptSuffix}/$TWiki::cfg{SystemWebName}/$m\">$m</a>",
            '{Tags}{'.$m.'}{Enabled}'
           );
        $block .= $value->buildInputFields();
    }

    return $block;
}

1;
