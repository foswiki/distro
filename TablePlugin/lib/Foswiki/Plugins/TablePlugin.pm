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

use vars qw( $topic $installWeb $initialised );

our $VERSION = '$Rev$';
our $RELEASE = '1.1';
our $SHORTDESCRIPTION =
  'Control attributes of tables and sorting of table columns';
our $NO_PREFS_IN_TOPIC = 1;
our %pluginAttributes;

sub initPlugin {
    my ( $web, $user );
    ( $topic, $web, $user, $installWeb ) = @_;

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

sub _readPluginSettings {
    my $configureAttrStr =
      $Foswiki::cfg{Plugins}{TablePlugin}{DefaultAttributes};
    my $pluginAttrStr =
      Foswiki::Func::getPreferencesValue('TABLEPLUGIN_TABLEATTRIBUTES');
    my $prefsAttrStr = Foswiki::Func::getPreferencesValue('TABLEATTRIBUTES');

    debug("_readPluginSettings");
    debug("\t configureAttrStr=$configureAttrStr") if $configureAttrStr;
    debug("\t pluginAttrStr=$pluginAttrStr")       if $pluginAttrStr;
    debug("\t prefsAttrStr=$prefsAttrStr")         if $prefsAttrStr;

    my %configureParams = Foswiki::Func::extractParameters($configureAttrStr);
    my %pluginParams    = Foswiki::Func::extractParameters($pluginAttrStr);
    my %prefsParams     = Foswiki::Func::extractParameters($prefsAttrStr);

    %pluginAttributes = ( %configureParams, %pluginParams, %prefsParams );
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
