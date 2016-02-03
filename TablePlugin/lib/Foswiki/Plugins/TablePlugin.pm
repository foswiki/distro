# See bottom of file for license and copyright information
#
# Allow sorting of tables, plus setting of background colour for
# headings and data cells. See %SYSTEMWEB%.TablePlugin for details of use

package Foswiki::Plugins::TablePlugin;

use strict;
use warnings;
use Foswiki::Request ();

BEGIN {
    # Backwards compatibility for Foswiki 1.1.x
    unless ( Foswiki::Request->can('multi_param') ) {
        no warnings 'redefine';
        *Foswiki::Request::multi_param = \&Foswiki::Request::param;
        use warnings 'redefine';
    }
}

# Simple decimal version, use parse method, no leading "v"
our $VERSION = '1.154';
our $RELEASE = '03 Feb 2016';
our $SHORTDESCRIPTION =
  'Control attributes of tables and sorting of table columns';
our $NO_PREFS_IN_TOPIC = 1;
our %pluginAttributes;

our $DEBUG_FROM_UNIT_TEST = 0;
our $topic;
our $web;
our $user;
our $installWeb;
our $initialised;
my $DEFAULT_TABLE_SETTINGS =
'tableborder="1" valign="top" headercolor="#000000" headerbg="#d6d3cf" headerbgsorted="#c4c1ba" databg="#ffffff,#edf4f9" databgsorted="#f1f7fc,#ddebf6" tablerules="rows" headerrules="cols"';
my $styles = {};    # hash to keep track of web->topic
my $readyForHandler;
our $writtenToHead = 0;

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    debug( 'TablePlugin', "initPlugin:$web.$topic" );

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            'Version mismatch between TablePlugin and Plugins.pm');
        return 0;
    }

    my $cgi = Foswiki::Func::getCgiQuery();
    return 0 unless $cgi;

    $initialised      = 0;
    $readyForHandler  = 0;
    $writtenToHead    = 0;
    %pluginAttributes = ();

    debug( 'TablePlugin', "inited" );

    return 1;
}

sub preRenderingHandler {
    ### my ( $text, $removed ) = @_;
    debug( 'TablePlugin', 'preRenderingHandler' );
    my $sort = Foswiki::Func::getPreferencesValue('TABLEPLUGIN_SORT')
      || 'all';
    return
      unless ( $sort && $sort =~ m/^(all|attachments)$/ )
      || $_[0] =~ m/%TABLE\{.*?\}%/;

    _readPluginSettings() if !%pluginAttributes;

    # on-demand inclusion
    require Foswiki::Plugins::TablePlugin::Core;
    if ( !$readyForHandler ) {
        Foswiki::Plugins::TablePlugin::Core::_init();
        $readyForHandler = 1;
    }
    Foswiki::Plugins::TablePlugin::Core::handler(@_);
}

=begin TML
---++ StaticMethod initialiseWhenRender() -> 1

Official API call for TablePlugin. Other plugins can reinitialise the plugin
which will reset all table counters etc next time the preRenderingHandler
is run. The preRenderingHandler is called again when a plugin uses the
Foswiki::Func::renderText method.
A plugin like !CompareRevisionsAddOn uses initialiseWhenRender between the
rendering of two revisions of the same topic to avoid table numbers to
continue counting up when rendering the topic the second time.

Example of use in a plugin taking care to check for TablePlugin being
installed and being of a version that contains this method.
Otherwise using a "mother of hacks" to get to the same result.

    if ( defined &Foswiki::Plugins::TablePlugin::initPlugin ) {
        if ( defined &Foswiki::Plugins::TablePlugin::initialiseWhenRender ) {
            Foswiki::Plugins::TablePlugin::initialiseWhenRender();
        }
        else {
            # If TablePlugin does not have the reinitialise API
            # we use try a shameless hack instead
            if ( defined $Foswiki::Plugins::TablePlugin::initialised ) {
                $Foswiki::Plugins::TablePlugin::initialised = 0;
            }
        }
    }

=cut

sub initialiseWhenRender {

    $initialised = 0;

    return 1;
}

=pod

Read in plugin settings from TABLEPLUGIN_TABLEATTRIBUTES
TABLEATTRIBUTES are no longer supported (NO_PREFS_IN_TOPIC).
If no settings are found, use the default settings from configure.
And if these cannot be read, use the default values defined here in this plugin.

Settings are applied by the principle of 'filling in the gaps'  
=cut

sub _readPluginSettings {
    debug( 'TablePlugin', '_readPluginSettings' );
    my $configureAttrStr =
      $Foswiki::cfg{Plugins}{TablePlugin}{DefaultAttributes};
    my $pluginAttrStr =
      Foswiki::Func::getPreferencesValue('TABLEPLUGIN_TABLEATTRIBUTES');

    debug( 'TablePlugin', "\t configureAttrStr=$configureAttrStr" )
      if defined $configureAttrStr;
    debug( 'TablePlugin', "\t pluginAttrStr=$pluginAttrStr" )
      if defined $pluginAttrStr;
    debug( 'TablePlugin',
        "\t no settings from configure could be read; using default values" )
      unless defined $configureAttrStr;

    $configureAttrStr = $DEFAULT_TABLE_SETTINGS
      unless defined $configureAttrStr;

    $configureAttrStr = Foswiki::Func::expandCommonVariables( $configureAttrStr,
        $topic, $web, undef )
      if defined $configureAttrStr;

    $pluginAttrStr = Foswiki::Func::expandCommonVariables( $pluginAttrStr,
        $topic, $web, undef )
      if defined $pluginAttrStr;

    my %configureParams = Foswiki::Func::extractParameters($configureAttrStr);
    my %pluginParams    = Foswiki::Func::extractParameters($pluginAttrStr);

    %pluginAttributes = ( %configureParams, %pluginParams );
}

sub afterCommonTagsHandler {

    #debug( '', 'afterCommonTagsHandler' );
    _writeStyleToHead();
}

=pod

addHeadStyles( $id, \@styles ) 

Store list of CSS lines to be written.

=cut

sub addHeadStyles {
    my ( $inId, $inStyles ) = @_;

    $styles->{$web}->{$topic}->{$inId} = $inStyles;
}

sub _writeStyleToHead {

    return if !$styles->{$web}->{$topic};

    my @allStyles = ();
    foreach my $id ( sort keys %{ $styles->{$web}->{$topic} } ) {
        push @allStyles, @{ $styles->{$web}->{$topic}->{$id} };
    }
    my $styleText = join( "\n", @allStyles );
    debug( 'TablePlugin', "_writeStyleToHead; styleText=$styleText" );

    my $header = <<EOS;
<style type="text/css" media="all">
$styleText
</style>
EOS
    Foswiki::Func::addToZone( "head", "TABLEPLUGIN_${web}_${topic}", $header );
}

=pod

Shorthand debugging call.

=cut

sub debug {
    my ( $origin, $text ) = @_;
    return if !$Foswiki::cfg{Plugins}{TablePlugin}{Debug};
    return if !$text;

    $origin ||= 'TablePlugin';
    $text = "$origin: $text";

    print STDERR $text . "\n" if $DEBUG_FROM_UNIT_TEST;
    Foswiki::Func::writeDebug("$text");
}

sub debugData {
    my ( $origin, $text, $data ) = @_;

    return if !$Foswiki::cfg{Plugins}{TablePlugin}{Debug};
    $origin ||= 'TablePlugin';
    Foswiki::Func::writeDebug("$origin: $text:");
    print STDERR "$origin: $text:" . "\n" if $DEBUG_FROM_UNIT_TEST;
    if ($data) {
        eval
'use Data::Dumper; local $Data::Dumper::Terse = 1; local $Data::Dumper::Indent = 1; Foswiki::Func::writeDebug(Dumper($data));';
        print STDERR Dumper($data) . "\n" if $DEBUG_FROM_UNIT_TEST;
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2006 TWiki Contributors
Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.org
Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
