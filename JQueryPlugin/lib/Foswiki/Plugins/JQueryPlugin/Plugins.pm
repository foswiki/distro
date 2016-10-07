# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::Plugins;

use strict;
use warnings;
use Foswiki::Func();

my @iconSearchPath;
my %iconCache;
my %plugins;
my %themes;
my $debug;
my $currentTheme;

use constant JQUERY1_DEFAULT => 'jquery-1.12.4';
use constant JQUERY2_DEFAULT => 'jquery-2.2.4';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin

Container for jQuery and plugins

=cut

=begin TML

---++ init()

initialize plugin container

=cut

sub init {

    $debug = $Foswiki::cfg{JQueryPlugin}{Debug} || 0;

    # get all plugins
    foreach
      my $pluginName ( sort keys %{ $Foswiki::cfg{JQueryPlugin}{Plugins} } )
    {
        registerPlugin($pluginName)
          if $Foswiki::cfg{JQueryPlugin}{Plugins}{$pluginName}{Enabled};
    }

    # get all themes
    foreach my $themeName ( sort keys %{ $Foswiki::cfg{JQueryPlugin}{Themes} } )
    {
        registerTheme($themeName)
          if $Foswiki::cfg{JQueryPlugin}{Themes}{$themeName}{Enabled};
    }
    $currentTheme = $Foswiki::cfg{JQueryPlugin}{JQueryTheme};

    # load jquery
    my $jQuery = $Foswiki::cfg{JQueryPlugin}{JQueryVersion}
      || JQUERY2_DEFAULT;

    # test for the jquery library to be present
    unless ( -e $Foswiki::cfg{PubDir} . '/'
        . $Foswiki::cfg{SystemWebName}
        . '/JQueryPlugin/'
        . $jQuery
        . '.js' )
    {
        Foswiki::Func::writeWarning(
"CAUTION: jQuery $jQuery not found. please fix the {JQueryPlugin}{JQueryVersion} settings."
        );
        $jQuery = JQUERY2_DEFAULT;
    }

    $jQuery .= ".uncompressed" if $debug;

    my $jQueryIE = $Foswiki::cfg{JQueryPlugin}{JQueryVersionForOldIEs};
    $jQueryIE = JQUERY1_DEFAULT unless defined $jQueryIE;

    my $code;
    if ($jQueryIE) {

        # test for the jquery library to be present
        unless ( -e $Foswiki::cfg{PubDir} . '/'
            . $Foswiki::cfg{SystemWebName}
            . '/JQueryPlugin/'
            . $jQueryIE
            . '.js' )
        {
            Foswiki::Func::writeWarning(
"CAUTION: jQuery $jQueryIE not found. please fix the {JQueryPlugin}{JQueryVersionForOldIEs} settings."
            );
            $jQueryIE = JQUERY1_DEFAULT;
        }

        $jQueryIE .= ".uncompressed" if $debug;

        $code = <<"HERE";
<literal><!--[if lte IE 9]>
<script type='text/javascript' src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$jQueryIE.js'></script>
<![endif]-->
<!--[if gt IE 9]><!-->
<script type='text/javascript' src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$jQuery.js'></script>
<!--<![endif]-->
</literal>
HERE
    }
    else {
        $code = <<"HERE";
<script type='text/javascript' src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$jQuery.js'></script>
HERE
    }

    # switch on noconflict mode
    if ( $Foswiki::cfg{JQueryPlugin}{NoConflict} ) {
        my $noConflict = 'noconflict';
        $noConflict .= ".uncompressed" if $debug;

        $code .= <<"HERE";
<script type='text/javascript' src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$noConflict.js'></script>
HERE
    }

    Foswiki::Func::addToZone( 'script', 'JQUERYPLUGIN', $code );

    # initial plugins
    createPlugin('Foswiki');    # this one is needed anyway

    my $defaultPlugins = $Foswiki::cfg{JQueryPlugin}{DefaultPlugins};
    if ($defaultPlugins) {
        foreach my $pluginName ( split( /\s*,\s*/, $defaultPlugins ) ) {
            createPlugin($pluginName);
        }
    }

  # enable migrate for jQuery > 1.9.x as long as we still have 3rd party plugins
  # making use of deprecated and removed features
    unless ( $defaultPlugins && $defaultPlugins =~ /\bmigrate\b/i ) {
        if ( $jQuery =~ /^jquery-(\d+)\.(\d+)\.(\d+)/ ) {
            my $jqVersion = $1 * 10000 + $2 * 100 + $3;
            if ( $jqVersion > 10900 ) {
                createPlugin("Migrate");
            }
        }
    }
}

=begin TML

---++ ObjectMethod createPlugin( $pluginName, ... ) -> $plugin

Helper method to establish plugin dependencies. See =load()=.

=cut

sub createPlugin {
    my $plugin = load(@_);
    $plugin->init() if $plugin;
    return $plugin;
}

=begin TML

---++ ObjectMethd createTheme ($themeName, $url) -> $boolean

Helper method to switch on a theme. Returns true
if =$themeName= has been loaded successfully. Note that a previously
loaded theme will be replaced with the new one as there can only
be one theme per html page. The $url parameter optionally specifies
from where to load the theme. It defaults to the url registered
in =configure= for the named theme.

=cut

sub createTheme {
    my ( $themeName, $url ) = @_;

    $themeName ||= $currentTheme;
    return 0 unless $themeName;

    my $normalizedName = lc($themeName);

    unless ($url) {
        my $themeDesc = $themes{$normalizedName};
        return 0 unless defined $themeDesc;
        $url = $themeDesc->{url};
    }

    # remember last choice
    $currentTheme = $themeName;

    Foswiki::Func::addToZone( "head", "JQUERYPLUGIN::THEME",
        <<HERE, "JQUERYPLUGIN::FOSWIKI, JQUERYPLUGIN::UI" );
<link rel="stylesheet" href="$url" type="text/css" media="all" />
HERE

    return 1;
}

=begin TML

---++ ObjectMethod registerPlugin( $pluginName, $class ) -> $descriptor

Helper method to register a plugin.

=cut

sub registerPlugin {
    my ( $pluginName, $class ) = @_;

    $class ||= $Foswiki::cfg{JQueryPlugin}{Plugins}{$pluginName}{Module}
      || 'Foswiki::Plugins::JQueryPlugin::' . uc($pluginName);

    my $contextID = $pluginName . 'Registered';
    $contextID =~ s/\W//g;
    Foswiki::Func::getContext()->{$contextID} = 1;

    return $plugins{ lc($pluginName) } = {
        'class'    => $class,
        'name'     => $pluginName,
        'instance' => undef,
    };
}

=begin TML

---++ ObjectMethod registerTheme( $themeName, $url ) -> $descriptor

Helper method to register a theme.

=cut

sub registerTheme {
    my ( $themeName, $url ) = @_;

    my $normalizedName = lc($themeName);

    $url ||= $Foswiki::cfg{JQueryPlugin}{Themes}{$themeName}{Url}
      || '%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/ui/themes/'
      . $normalizedName
      . '/jquery-ui.css';

    return $themes{$normalizedName} = {
        'url'  => $url,
        'name' => $themeName,
    };
}

=begin TML

finalizer

=cut

sub finish {

    undef %plugins;
    undef %themes;
    undef @iconSearchPath;
    undef %iconCache;
    undef $currentTheme;
}

=begin TML

---++ ObjectMethod load ( $pluginName ) -> $plugin

Loads a plugin and runs its initializer.

parameters
   * =$pluginName=: name of plugin

returns
   * =$plugin=: returns the plugin object or false if instantiating
     the plugin failed

=cut

sub load {
    my $pluginName = shift;

    my $normalizedName = lc($pluginName);
    my $pluginDesc     = $plugins{$normalizedName};

    return unless $pluginDesc;

    unless ( defined $pluginDesc->{instance} ) {

        eval "require $pluginDesc->{class};";

        if ($@) {
            Foswiki::Func::writeDebug(
                "ERROR: can't load jQuery plugin $pluginName: $@");
            $pluginDesc->{instance} = 0;
        }
        else {
            $pluginDesc->{instance} = $pluginDesc->{class}->new();
        }
    }

    return $pluginDesc->{instance};
}

=begin TML

---++ ObjectMethod expandVariables( $format, %params) -> $string

Helper function to expand standard escape sequences =$percnt=, =$nop=,
=$n= and =$dollar=.

   * =$format=: format string to be expaneded
   * =%params=: optional hash array containing further key-value pairs to be
     expanded as well, that is all occurences of =$key= will
     be replaced by its =value= as defined in %params
   * =$string=: returns the resulting text

=cut

sub expandVariables {
    my ( $format, %params ) = @_;

    return '' unless $format;

    foreach my $key ( keys %params ) {
        my $val = $params{$key};
        $val = '' unless defined $val;
        $format =~ s/\$$key\b/$val/g;
    }
    $format = Foswiki::Func::decodeFormatTokens($format);

    return $format;
}

=begin TML

---++ ObjectMethod getIconUrlPath ( $iconName ) -> $pubUrlPath

Returns the path to the named icon searching along a given icon search path.
This path can be in =$Foswiki::cfg{JQueryPlugin}{IconSearchPath}= or will fall
back to =FamFamFamSilkIcons=, =FamFamFamSilkCompanion1Icons=,
=FamFamFamFlagIcons=, =FamFamFamMiniIcons=, =FamFamFamMintIcons= As you see
installing Foswiki:Extensions/FamFamFamContrib would be nice to have.

   = =$iconName=: name of icon; you will have to know the icon name by heart as listed in your
     favorite icon set, meaning there's no mapping between something like "semantic" and "physical" icons
   = =$pubUrlPath=: the path to the icon as it is attached somewhere in your wiki or the empty
     string if the icon was not found

=cut

sub getIconUrlPath {
    my ($iconName) = @_;

    return '' unless $iconName;

    unless (@iconSearchPath) {
        my $iconSearchPath = $Foswiki::cfg{JQueryPlugin}{IconSearchPath}
          || 'FamFamFamSilkIcons, FamFamFamSilkCompanion1Icons, FamFamFamSilkCompanion2Icons, FamFamFamSilkGeoSilkIcons, FamFamFamFlagIcons, FamFamFamMiniIcons, FamFamFamMintIcons';
        @iconSearchPath = split( /\s*,\s*/, $iconSearchPath );
    }

    $iconName =~ s/^.*\.(.*?)$/$1/;    # strip file extension

    my $iconPath = $iconCache{$iconName};

    unless ($iconPath) {
        foreach my $item (@iconSearchPath) {
            my ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName(
                $Foswiki::cfg{SystemWebName}, $item );

            # SMELL: store violation assumes the we have got file-level access
            # better use store api
            my $iconDir =
                $Foswiki::cfg{PubDir} . '/'
              . $web . '/'
              . $topic . '/'
              . $iconName . '.png';
            if ( -f $iconDir ) {
                $iconPath =
                    Foswiki::Func::getPubUrlPath() . '/'
                  . $web . '/'
                  . $topic . '/'
                  . $iconName . '.png';
                last;    # first come first serve
            }
        }

        $iconPath ||= '';
        $iconCache{$iconName} = $iconPath;
    }

    return $iconPath;
}

=begin TML

---++ ClassMethod getPlugins () -> @plugins

returns a list of all known plugins

=cut

sub getPlugins {
    my ($include) = @_;

    my @plugins = ();
    foreach my $key ( sort keys %plugins ) {
        next if $key eq 'empty';
        next if $include && $key !~ /^($include)$/;
        my $pluginDesc = $plugins{$key};
        my $plugin     = load( $pluginDesc->{name} );
        push @plugins, $plugin if $plugin;
    }

    return @plugins;
}

=begin TML

---++ ClassMethod getRandom () -> $integer

returns a random positive integer between 1 and 10000.
this can be used to
generate html element IDs which are not
allowed to clash within the same html page,
even not when it got extended via ajax.

=cut

sub getRandom {
    return int( rand(10000) ) + 1;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
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
