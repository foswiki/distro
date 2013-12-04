# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Pluggables::PLUGINS
Pluggable for finding and handling plugins. Implements 
<nop>*PLUGINS* in Foswiki.spec.

=cut

package Foswiki::Plugins::ConfigurePlugin::PLUGINS;

use strict;
use warnings;

# Load spec entries for a pluggable section.
# Return a list of spec entries, which will be added to the
# tree where the pluggable section was referenced in the .spec
sub load {
    my ($factory) = @_;

    # *PLUGINS* occurs within a ---+++ section already,
    my %modules;

    # Inspect @INC to find available plugins
    my @classes = Foswiki::Plugins::ConfigurePlugin::SpecEntry::_findClasses(
        'Foswiki::Plugins::*Plugin');
    my @twikiclasses =
      Foswiki::Plugins::ConfigurePlugin::SpecEntry::_findClasses(
        'TWiki::Plugins::*Plugin');
    push( @classes, @twikiclasses );

    foreach my $module (@classes) {
        my $simple = $module;
        $simple =~ s/^.*::([^:]*)/$1/;

        # only add the first instance of any plugin, as only
        # the first can get loaded from @INC.
        next if $modules{$simple};

        $modules{$simple} = $module;
    }

    my @entries;
    foreach my $module ( sort { lc($a) cmp lc($b) } keys %modules ) {
        next
          if ( $module eq 'EmptyPlugin' )
          ;    #don't show EmptyPlugin, and don't add it to the cfg
        push(
            @entries,
            $factory->createSpecEntry(
                type => 'BOOLEAN',
                keys => '{Plugins}{' . $module . '}{Enabled}',
            )
        );
        push(
            @entries,
            $factory->createSpecEntry(
                type    => 'STRING',
                keys    => '{Plugins}{' . $module . '}{Module}',
                options => 'EXPERT'
            )
        );
    }
    return @entries;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
