# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Pluggables::PLUGINS
Pluggable for finding and handling plugins. Implements 
<nop>*PLUGINS* in Foswiki.spec.

=cut

package Foswiki::Configure::Pluggables::PLUGINS;

use strict;
use warnings;

use Assert;
use Foswiki::Configure::Value    ();
use Foswiki::Configure::FileUtil ();

sub construct {
    my ( $settings, $file, $line ) = @_;

    # Inspect @INC to find plugins
    my @classes = (
        Foswiki::Configure::FileUtil::findPackages('Foswiki::Plugins::*Plugin'),
        Foswiki::Configure::FileUtil::findPackages('TWiki::Plugins::*Plugin')
    );

    my %modules;

    foreach my $module (@classes) {
        my $pluginName = $module;
        $pluginName =~ s/^.*::([^:]*)/$1/;

        # only add the first instance of any plugin, as only
        # the first can get loaded from @INC.
        next if $modules{$pluginName};

        $modules{$pluginName} = $module;
    }

    my %expert;

    # Add any others present in $Foswiki::cfg but not found on @INC,
    # but mark them as EXPERT unless enabled.
    foreach my $pluginName ( keys %{ $Foswiki::cfg{Plugins} } ) {
        next if $modules{$pluginName};
        next unless ref( $Foswiki::cfg{Plugins}{$pluginName} );
        $modules{$pluginName} = "Foswiki::Plugins::$pluginName";
        $expert{$pluginName}  = !$Foswiki::cfg{Plugins}{$pluginName}{Enabled};
    }

    foreach my $plugin ( sort { lc($a) cmp lc($b) } keys %modules ) {

        # ignore EmptyPlugin
        next if ( $plugin eq 'EmptyPlugin' );

        # Plugin is already configured,  add keys to spec
        push(
            @$settings,
            Foswiki::Configure::Value->new(
                'BOOLEAN',
                LABEL   => $plugin,
                keys    => "{Plugins}{$plugin}{Enabled}",
                default => '0',                             # Not enabled
                EXPERT  => $expert{$plugin}
            )
        );
        push(
            @$settings,
            Foswiki::Configure::Value->new(
                'STRING',
                CHECKER => 'PLUGIN_MODULE',
                LABEL   => "$plugin Module",
                keys    => "{Plugins}{$plugin}{Module}",

                # Note: as tempting as it may seem, DO NOT set
                # undefok. Otherwise hints will be invisible.
                default => "$modules{$plugin}",
                EXPERT  => 1
            )
        );

# Set the module name in the configuration, and tell save via the BOOTSTRAP
# list that keys have been discovered and should be saved in the new configuration
        if ( $Foswiki::cfg{isBOOTSTRAPPING} ) {
            unless ( $Foswiki::cfg{Plugins}{$plugin}{Module} ) {
                $Foswiki::cfg{Plugins}{$plugin}{Module} = $modules{$plugin};
                push(
                    @{ $Foswiki::cfg{BOOTSTRAP} },
                    "{Plugins}{$plugin}{Module}"
                );
            }
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
