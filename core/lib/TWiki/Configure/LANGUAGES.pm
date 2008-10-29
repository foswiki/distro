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
package TWiki::Configure::LANGUAGES;

use strict;

use TWiki::Configure::Pluggable;

use base 'TWiki::Configure::Pluggable';

use Error;

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new('Languages');

    opendir( DIR, $TWiki::cfg{LocalesDir}) or
      return $this;

    foreach my $file ( readdir DIR ) {
        next unless ($file =~ m/^(.*)\.po$/);
        my $lang = $1;
        $lang = "'$lang'" if $lang =~ /\W/;

        $this->addChild(
            new TWiki::Configure::Value(
                parent=>$this,
                keys => '{Languages}{'.$lang.'}{Enabled}',
                typename => 'BOOLEAN'));
    }
    closedir( DIR );
    return $this;
}

1;
