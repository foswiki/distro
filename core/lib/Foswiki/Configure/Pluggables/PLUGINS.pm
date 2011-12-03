# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Pluggables::PLUGINS
Pluggable for finding and handling plugins. Implements 
<nop>*PLUGINS* in Foswiki.spec.

=cut

package Foswiki::Configure::Pluggables::PLUGINS;

use strict;
use warnings;

use Foswiki::Configure::Pluggable ();
our @ISA = ('Foswiki::Configure::Pluggable');

use Foswiki::Configure::Type  ();
use Foswiki::Configure::Value ();

my $scanner = Foswiki::Configure::Type::load('SELECTCLASS');

sub new {
    my ($class) = @_;

    # Create a new section for plugins. This is an unnamed subsection
    # because *PLUGINS* occurs within a ---++ Plugins section already
    my $this = $class->SUPER::new('');
    my %modules;

    # Inspect @INC to find plugins
    my $classes      = $scanner->findClasses('Foswiki::Plugins::*Plugin');
    my $twikiclasses = $scanner->findClasses('TWiki::Plugins::*Plugin');
    push( @$classes, @$twikiclasses );

    foreach my $module (@$classes) {
        my $simple = $module;
        $simple =~ s/^.*::([^:]*)/$1/;

        # only add the first instance of any plugin, as only
        # the first can get loaded from @INC.
        $modules{$simple} = $module;
    }
    foreach my $module ( sort { lc($a) cmp lc($b) } keys %modules ) {
        next
          if ( $module eq 'EmptyPlugin' )
          ;    #don't show EmptyPlugin, and don't add it to the cfg
        $this->addChild(
            new Foswiki::Configure::Value(
                'BOOLEAN',
                parent => $this,
                keys   => '{Plugins}{' . $module . '}{Enabled}',
            )
        );
        $this->addChild(
            new Foswiki::Configure::Value(
                'STRING',
                parent      => $this,
                keys        => '{Plugins}{' . $module . '}{Module}',
                expertsOnly => 1
            )
        );
        $Foswiki::cfg{Plugins}{$module}{Module} ||= $modules{$module};
    }

    foreach my $plug ( keys %{ $Foswiki::cfg{Plugins} } ) {
        next unless ( $plug =~ m/Plugin$/ );
        my $simple = $plug;
        $simple =~ s/^.*::([^:]*)/$1/;
        unless ( $modules{$simple} ) {
            $modules{$simple} = $plug;
            $this->addChild(
                new Foswiki::Configure::Value(
                    'BOOLEAN',
                    parent      => $this,
                    keys        => '{Plugins}{' . $plug . '}{Enabled}',
                    expertsOnly => !$Foswiki::cfg{Plugins}{$plug}{Enabled}
                )
            );
            $this->addChild(
                new Foswiki::Configure::Value(
                    'STRING',
                    parent      => $this,
                    keys        => '{Plugins}{' . $plug . '}{Module}',
                    expertsOnly => 1
                )
            );
        }
    }

    return $this;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
