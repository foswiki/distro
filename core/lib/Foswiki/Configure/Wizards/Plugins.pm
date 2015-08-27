# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::Plugins;

=begin TML

---++ package Foswiki::Configure::Wizards::ScriptHash

Wizard to verify script paths.

=cut

use strict;
use warnings;

use Assert;
use Foswiki;

use Foswiki::Configure::Load ();

require Foswiki::Configure::Wizard;
our @ISA = ('Foswiki::Configure::Wizard');

=begin TML

---++ WIZARD import

Called when a module may have been installed outside the scope of
=configure. In this case, we need to both verify *and* repair the
configuration as necessary to import the new module's Config.spec
   * All plugins found on path are defined in the configuration
   * No duplicate modules are found in the @INC path
   * All plugins defined in the configuration exist on the path.

=cut

sub check_current_value {
    goto &import;
}

sub import {
    my ( $this, $reporter, $spec ) = @_;

    my $enable;

    my $args = $this->param('args');
    while ( my ( $opt, $val ) = each %$args ) {
        if ( $opt eq 'ENABLE' ) {
            $enable = Foswiki::isTrue($val);
            next;
        }
        $reporter->ERROR("Unknown parameter ($opt)");
        return '';
    }

    my $changes = 0;    # Set if repair applicable.

    # Inspect @INC to find plugins
    my @classes = (
        Foswiki::Configure::FileUtil::findPackages('Foswiki::Plugins::*Plugin'),
        Foswiki::Configure::FileUtil::findPackages('TWiki::Plugins::*Plugin')
    );

    my %modules;

    # Find all possible plugin modules on the @INC path, both Foswiki and TWiki
    foreach my $module (@classes) {
        my $pluginName = $module;

        $pluginName =~ s/^.*::([^:]*)/$1/;
        next if $pluginName eq 'EmptyPlugin';

        if ( $modules{$pluginName} ) {
            $reporter->NOTE("Duplicate plugin $pluginName found on \@INC path");
            $reporter->NOTE("  $module duplicate of  $modules{$pluginName} ");
        }

        $reporter->NOTE(
"Module $module was found on the path, but is not referenced in the configuration."
          )
          unless ( defined $Foswiki::cfg{Plugins}{$pluginName}{Module}
            && $Foswiki::cfg{Plugins}{$pluginName}{Module} eq $module );

        next if $modules{$pluginName};    # Already processed

        if ( !defined $Foswiki::cfg{Plugins}{$pluginName}{Module} ) {
            $changes++;
            _setModule( $spec, $reporter, $pluginName,
                "Foswiki::Plugins::$pluginName" );
        }
        if (  !defined $Foswiki::cfg{Plugins}{$pluginName}{Enabled}
            && defined $enable )
        {
            $changes++;
            _setEnable( $spec, $reporter, $pluginName, $enable );
        }

        # only add the first instance of any plugin, as only
        # the first can get loaded from @INC.
        $modules{$pluginName} = $module;
    }

    # Report any plugins in $Foswiki::cfg but not found on @INC,
    foreach my $pluginName ( keys %{ $Foswiki::cfg{Plugins} } ) {
        next if $modules{$pluginName};
        next unless ref( $Foswiki::cfg{Plugins}{$pluginName} );
        $reporter->NOTE(
"Plugin $pluginName found in configuration, no module found on path."
        );
        my $module = $Foswiki::cfg{Plugins}{$pluginName}{Module} || 'undefined';
        if ( $Foswiki::cfg{Plugins}{$pluginName}{Enabled} ) {
            $reporter->WARN(" - Module $module is Enabled.");
            _setEnable( $spec, $reporter, $pluginName, 0 );
            $changes++;
        }

        #$changes++;
        # SMELL: Cannot undef / delete the Module.  Save will abort.
        #_setModule( $spec, $reporter, $pluginName );
    }

    # SMELL:  The Pluggables::Plugins function will auto-define
    # all missing plugins, and add them to the BOOTSTRAP variable.
    # This really is only functional during the initial bootstrap
    # process.  So report them here:

    foreach my $plugin ( @{ $Foswiki::cfg{BOOTSTRAP} } ) {
        $plugin =~ m/\{Plugins\}\{([^}]+)\}.*/;
        my $pluginName   = $1;
        my $pluginModule = eval "\$Foswiki::cfg$plugin";

        # ignore EmptyPlugin
        next if ( $pluginName eq 'EmptyPlugin' );
        $reporter->NOTE(
"Plugin $pluginName - Module detected $pluginModule is not configured."
        );
        $changes++;
        _setModule( $spec, $reporter, $pluginName, $pluginModule );
        _setEnable( $spec, $reporter, $pluginName, $enable )
          if ( defined $enable );
    }

    foreach my $ext ( Foswiki::Configure::Load::specChanged() ) {
        my $specfile = ( $ext eq 'the core' ) ? 'Foswiki.spec' : 'Config.spec';
        $reporter->WARN(
"The $specfile for $ext is more recent than the latest configuration. 'save of extension settings' is required."
        );
        $changes++;
    }

    if ($changes) {
        $reporter->WARN("Configuration changes are required.");
        $reporter->hint( "require_save", 1 );
        if ( defined $Foswiki::cfg{Engine}
            && $Foswiki::cfg{Engine} !~ /(CLI|Legacy)$/ )
        {
            $reporter->WARN(
"You should save the configuration, and reload =$Foswiki::cfg{ScriptUrlPath}/configure= to verify any new settings."
            );
        }
        else {
            $reporter->WARN(
"If you did not include the -save option, you should rerun this wizard, specifying -save."
            );
        }
    }
    else {
        $reporter->NOTE("No changes to the configuration needed.");
    }

# SMELL:   If anything but undef is returned,  that result is passed back to the caller as a report.
# If config changes are to be applied by the wizard, it must return undef.
    return undef;

}

sub _setEnable {
    my ( $spec, $reporter, $plu, $value ) = @_;

    my $clef = "{Plugins}{$plu}";

    if ( defined $value ) {
        eval("\$Foswiki::cfg${clef}{Enabled}=$value");
    }
    else {
        if ( eval("exists \$Foswiki::cfg${clef}{Enabled}") ) {
            eval("delete \$Foswiki::cfg${clef}{Enabled}");
        }
    }

    if ( defined $value ) {

        # Add it to the $spec
        $spec->addChild(
            Foswiki::Configure::Value->new(
                'BOOLEAN',
                LABEL   => $plu,
                keys    => "${clef}{Enabled}",
                CHECKER => 'PLUGIN_MODULE',
                default => '0'
            )
        );
    }

    $reporter->CHANGED("{Plugins}{$plu}{Enabled}");

    return;
}

sub _setModule {
    my ( $spec, $reporter, $plu, $value ) = @_;
    if ( defined $value ) {
        eval("\$Foswiki::cfg{Plugins}{$plu}{Module}=\$value");
    }
    else {
        if ( eval("exists \$Foswiki::cfg{Plugins}{$plu}{Module}") ) {
            eval("delete \$Foswiki::cfg{Plugins}{$plu}{Module}");
        }
    }
    if ( defined $value ) {

        # Add it to the $spec
        $spec->addChild(
            Foswiki::Configure::Value->new(
                'STRING',
                LABEL   => "$plu Module",
                keys    => "{Plugins}{$plu}{Module}",
                CHECKER => 'PLUGIN_MODULE',
                default => 'Foswiki::Plugins::$plu'
            )
        );
    }

    $reporter->CHANGED("{Plugins}{$plu}{Module}");
}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2015 Foswiki Contributors. Foswiki Contributors
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
