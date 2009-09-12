# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2005-2007 TWiki Contributors
# Copyright (C) 2008-2009 Foswiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.
#
# Allow sorting of tables, plus setting of background colour for
# headings and data cells. See %SYSTEMWEB%.TablePlugin for details of use

use strict;

package Foswiki::Plugins::TablePlugin;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION = '$Rev$';
our $RELEASE = '1.100';
our $SHORTDESCRIPTION =
  'Control attributes of tables and sorting of table columns';
our $NO_PREFS_IN_TOPIC = 1;
our %pluginAttributes;

our $topic;
our $web;
our $user;
our $installWeb;
our $initialised;
my $DEFAULT_TABLE_SETTINGS =
'tableborder="1" valign="top" headercolor="#ffffff" headerbg="#687684" headerbgsorted="#334455" databg="#ffffff,#edf4f9" databgsorted="#f1f7fc,#ddebf6" tablerules="rows"';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    debug("TablePlugin initPlugin");

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            'Version mismatch between TablePlugin and Plugins.pm');
        return 0;
    }

    my $cgi = Foswiki::Func::getCgiQuery();
    return 0 unless $cgi;

    $initialised = 0;

    return 1;
}

sub preRenderingHandler {
    ### my ( $text, $removed ) = @_;
    debug("TablePlugin preRenderingHandler");
    my $sort = Foswiki::Func::getPreferencesValue('TABLEPLUGIN_SORT')
      || 'all';
    return
      unless ( $sort && $sort =~ /^(all|attachments)$/ )
      || $_[0] =~ /%TABLE{.*?}%/;

    _readPluginSettings() if !%pluginAttributes;

    # on-demand inclusion
    use Foswiki::Plugins::TablePlugin::Core;
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
    
=cut

sub _readPluginSettings {
    debug("TablePlugin _readPluginSettings");

    my $settings =
         Foswiki::Func::getPreferencesValue('TABLEPLUGIN_TABLEATTRIBUTES')
      || $Foswiki::cfg{Plugins}{TablePlugin}{DefaultAttributes}
      || $DEFAULT_TABLE_SETTINGS;

    debug("\t settings=$settings");

    $settings =
      Foswiki::Func::expandCommonVariables( $settings, $topic, $web, undef );
    %pluginAttributes = Foswiki::Func::extractParameters($settings);
}

=pod

Shorthand debugging call.

=cut

sub debug {
    my ($text) = @_;
    return if !$Foswiki::cfg{Plugins}{TablePlugin}{Debug};

    $text = "TablePlugin: $text";

    #print STDERR $text . "\n";
    Foswiki::Func::writeDebug("$text");
}

sub debugData {
    my ( $text, $data ) = @_;

    return if !$Foswiki::cfg{Plugins}{TablePlugin}{Debug};
    Foswiki::Func::writeDebug("TablePlugin; $text:");
    if ($data) {
        eval
'use Data::Dumper; local $Data::Dumper::Terse = 1; local $Data::Dumper::Indent = 1; Foswiki::Func::writeDebug(Dumper($data));';
    }
}

1;
