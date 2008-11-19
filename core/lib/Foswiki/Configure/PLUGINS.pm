#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2006 Foswiki Contributors.
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
package Foswiki::Configure::PLUGINS;
use base 'Foswiki::Configure::Pluggable';

use strict;

use Foswiki::Configure::Pluggable;
use Foswiki::Configure::Type;
use Foswiki::Configure::Value;

my $scanner = Foswiki::Configure::Type::load('SELECTCLASS');

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new('Installed Plugins');
    my %modules;
    my $classes = $scanner->findClasses('Foswiki::Plugins::*Plugin');
    my $twikiclasses = $scanner->findClasses('TWiki::Plugins::*Plugin');
    push(@$classes, @$twikiclasses);
    foreach my $module (@$classes) {
        my $simple = $module;
        $simple =~ s/^.*::([^:]*)/$1/;

        # only add the first instance of any plugin, as only
        # the first can get loaded from @INC.
        $modules{$simple} = $module;
    }
    foreach my $module ( sort { lc $a cmp lc $b } keys %modules ) {
        $this->addChild(
            new Foswiki::Configure::Value(
                parent   => $this,
                keys     => '{Plugins}{' . $module . '}{Enabled}',
                typename => 'BOOLEAN'
            )
        );
        $this->addChild(
            new Foswiki::Configure::Value(
                parent   => $this,
                keys     => '{Plugins}{' . $module . '}{Module}',
                typename => 'STRING'
            )
        );
        $Foswiki::cfg{Plugins}{$module}{Module} ||=
          $modules{$module};
    }
    return $this;
}

1;
