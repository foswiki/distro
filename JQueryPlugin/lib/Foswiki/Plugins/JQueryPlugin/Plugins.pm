# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::Plugins;

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin

Container for jQuery and plugins

=cut

use strict;
use warnings;
use Foswiki::Func();
use Foswiki::Plugins();
use Foswiki::Plugins::JQueryPlugin ();

my %plugins;
my $debug;

use constant JQUERY_DEFAULT => 'jquery-2.2.4';

=begin TML

---++ PackageMethod init()

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

    if ( $Foswiki::Plugins::VERSION >= 2.5 && $Foswiki::cfg{JQueryPlugin}{Combine}{Enabled} ) {
        Foswiki::Plugins::JQueryPlugin::getCombineService()->run();
    }
    else {
        legacyInit();
    }

    # initial plugins
    createPlugin('foswiki');    # these are needed anyway

    my $defaultPlugins = $Foswiki::cfg{JQueryPlugin}{DefaultPlugins};
    if ($defaultPlugins) {
        foreach my $pluginName ( split( /\s*,\s*/, $defaultPlugins ) ) {
            createPlugin($pluginName);
        }
    }

  # enable migrate for jQuery > 1.9.x as long as we still have 3rd party plugins
  # making use of deprecated and removed features
    unless ( $defaultPlugins && $defaultPlugins =~ /\bmigrate\b/i ) {
        my $jQuery = $Foswiki::cfg{JQueryPlugin}{JQueryVersion}
          || JQUERY_DEFAULT;

        if ( $jQuery =~ /^jquery-(\d+)\.(\d+)\.(\d+)/ ) {
            my $jqVersion = $1 * 10000 + $2 * 100 + $3;
            if ( $jqVersion > 10900 ) {
                createPlugin("Migrate");
            }
        }
    }
}

sub legacyInit {

    # load jquery
    my $jQuery = $Foswiki::cfg{JQueryPlugin}{JQueryVersion}
      || JQUERY_DEFAULT;

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
        $jQuery = JQUERY_DEFAULT;
    }

    $jQuery .= ".uncompressed" if $debug;

    my $code = <<"HERE";
<script src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$jQuery.js'></script>
HERE

    # switch on noconflict mode
    if ( $Foswiki::cfg{JQueryPlugin}{NoConflict} ) {
        my $noConflict = 'noconflict';
        $noConflict .= ".uncompressed" if $debug;

        $code .= <<"HERE";
<script src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$noConflict.js'></script>
HERE
    }

    Foswiki::Func::addToZone( 'script', 'JQUERYPLUGIN', $code );
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

---++ ObjectMethod finish

finalizer

=cut

sub finish {

    undef %plugins;
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

        my $path = $pluginDesc->{class} . '.pm';
        $path =~ s/::/\//g;
        eval { require $path };

        if ($@) {
            print STDERR "ERROR: can't load jQuery plugin $pluginName: $@\n";
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

Copyright (C) 2010-2025 Foswiki Contributors. Foswiki Contributors
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
