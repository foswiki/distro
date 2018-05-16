# See bottom of file for license and copyright information

package Foswiki::Config::Expandable::PLUGINS;

use Assert;

require Foswiki::Configure::FileUtil;

use Foswiki::Class -app;
extends qw(Foswiki::Object);
with qw(Foswiki::Config::CfgObject);

sub compose {
    my $this = shift;

    my $cfgData = $this->cfg;

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
    foreach my $pluginName ( keys %{ $cfgData->{Plugins} } ) {
        next if $modules{$pluginName};
        next unless ref( $cfgData->{Plugins}{$pluginName} );
        $modules{$pluginName} = "Foswiki::Plugins::$pluginName";
        $expert{$pluginName}  = !$cfgData->{Plugins}{$pluginName}{Enabled};
    }

    my @specs;

    foreach my $plugin ( sort { lc($a) cmp lc($b) } keys %modules ) {

        # ignore EmptyPlugin
        next if ( $plugin eq 'EmptyPlugin' );

        # Plugin is already configured,  add keys to spec
        push @specs, "Plugins.$plugin" => [
            Enabled => BOOLEAN => [
                -label   => $plugin,
                -default => 0,
                ( $expert{$plugin} ? ( -expert ) : () ),
            ],
            Module => STRING => [
                -label   => "$plugin Module",
                -checker => 'PLUGIN_MODULE',
                -default => $modules{$plugin},
                -expert,
            ],
        ];

# Set the module name in the configuration, and tell save via the BOOTSTRAP
# list that keys have been discovered and should be saved in the new configuration
        if ( $cfgData->{isBOOTSTRAPPING} ) {
            unless ( $cfgData->{Plugins}{$plugin}{Module} ) {
                $cfgData->{Plugins}{$plugin}{Module} = $modules{$plugin};
                push( @{ $cfgData->{BOOTSTRAP} },
                    "{Plugins}{$plugin}{Module}" );
            }
        }
    }

    return @specs;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016-2017 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
