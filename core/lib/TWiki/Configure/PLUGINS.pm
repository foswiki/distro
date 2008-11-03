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
# Plug-in module for finding and handling plugins
package TWiki::Configure::PLUGINS;
use base 'TWiki::Configure::Pluggable';

use strict;

use TWiki::Configure::Pluggable;
use TWiki::Configure::Type;
use TWiki::Configure::Value;

my $scanner = TWiki::Configure::Type::load('SELECTCLASS');

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new('Installed Plugins');
    my %modules;
    my $classes = $scanner->findClasses('TWiki::Plugins::*Plugin');
    foreach my $module (@$classes) {
        $module =~ s/^.*::([^:]*)/$1/;

        # only add the first instance of any plugin, as only
        # the first can get loaded from @INC.
        $modules{$module} = 1;
    }
    foreach my $module ( sort { lc $a cmp lc $b } keys %modules ) {
        $this->addChild(
            new TWiki::Configure::Value(
                parent   => $this,
                keys     => '{Plugins}{' . $module . '}{Enabled}',
                typename => 'BOOLEAN'
            )
        );
    }
    return $this;
}

1;
