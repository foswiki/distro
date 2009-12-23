# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Arthur Clemens, arthur@visiblearea.com and Foswiki contributors
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org and TWiki
# Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# This is the EditTablePlugin used to edit tables in place.

package Foswiki::Plugins::EditTablePlugin;

use strict;

our $VERSION = '$Rev$';

# Please note that the second is now two digit.
# Someone increased 4.22 to 4.3 which is not correct.
our $RELEASE = '4.34';

our $pluginName        = 'EditTablePlugin';
our $ENCODE_START      = '--EditTableEncodeStart--';
our $ENCODE_END        = '--EditTableEncodeEnd--';
our $ASSET_URL         = '%PUBURL%/%SYSTEMWEB%/EditTablePlugin';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
  'Edit tables using edit fields, date pickers and drop down boxes';
our $web;
our $topic;
our $user;
our $debug;
our $usesJavascriptInterface;
our $viewModeHeaderDone;
our $editModeHeaderDone;
our $recursionBlock;

=pod

=cut

sub initPlugin {
    ( $topic, $web, $user ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between EditTablePlugin and Plugins.pm");
        return 0;
    }

    my $query = Foswiki::Func::getCgiQuery();
    if ( !$query ) {
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPreferencesFlag('EDITTABLEPLUGIN_DEBUG');
    $usesJavascriptInterface =
      Foswiki::Func::getPreferencesFlag('EDITTABLEPLUGIN_JAVASCRIPTINTERFACE')
      || 1;
    $viewModeHeaderDone = 0;
    $editModeHeaderDone = 0;

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::EditTablePlugin::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

=pod

Calls EditTablePlugin::Core::parseTables to lift out tables and put them back later.
But because tables inside INCLUDEd topics won't expand - beforeCommonTagsHandler is called only once for the parent topic - parseTables needs to get called for included topics separatedly in commonTagsHandler.

We cannot do table parsing in commonTagsHandler because by then the TML has been rendered, and tags like %ICON{pdf}% rendered to their <img ... /> equivalent.

=cut

sub beforeCommonTagsHandler {
    return unless $_[0] =~ /%EDIT(?:TABLE|CELL){.*}%/o;
    Foswiki::Func::writeDebug(
        "EditTablePlugin::beforeCommonTagsHandler( $web.$topic )")
      if $debug;

    my $query     = Foswiki::Func::getCgiQuery();
    my $tableNr   = $query->param('ettablenr');
    my $isEditing = defined $query->param('etedit')
      && defined $tableNr;

    require Foswiki::Plugins::EditTablePlugin::Core;
    Foswiki::Plugins::EditTablePlugin::Core::init();
    if ($isEditing) {
        Foswiki::Plugins::EditTablePlugin::Core::parseTables( $_[0], $_[1],
            $_[2] );
    }
}

=pod

Calls EditTablePlugin::Core::parseTables for INCLUDEd topics.

=cut

sub commonTagsHandler {
    return unless $_[0] =~ /%EDIT(?:TABLE|CELL|TABLESTUB){.*}%/o;

    Foswiki::Func::writeDebug(
        "EditTablePlugin::commonTagsHandler( $web.$topic )")
      if $debug;

    return if $recursionBlock;
    $recursionBlock = 1;
    addViewModeHeadersToHead();
    require Foswiki::Plugins::EditTablePlugin::Core;

    Foswiki::Plugins::EditTablePlugin::Core::initIncludedTopic();
    Foswiki::Plugins::EditTablePlugin::Core::parseTables( $_[0], $_[1], $_[2] );
    Foswiki::Plugins::EditTablePlugin::Core::process( $_[0], $_[1], $_[2],
        $topic, $web );
    $recursionBlock = 0;
}

=pod

=cut

sub postRenderingHandler {
    Foswiki::Func::writeDebug(
        "EditTablePlugin::postRenderingHandler( $web.$topic )")
      if $debug;
    $_[0] =~ s/$ENCODE_START(.*?)$ENCODE_END/decodeValue($1)/geos;
}

=pod

=cut

sub encodeValue {

    # FIXME: *very* crude encoding to escape Wiki rendering inside form fields
    # also prevents urls to get expanded to links
    $_[0] =~ s/\./%dot%/gos;
    $_[0] =~ s/(.)/\.$1/gos;

    # convert <br /> markup to unicode linebreak character for text areas
    $_[0] =~ s/.<.b.r. .\/.>/&#10;/gos;
    $_[0] = $ENCODE_START . $_[0] . $ENCODE_END;
}

=pod

=cut

sub decodeValue {
    my ($theText) = @_;

    $theText =~ s/\.(.)/$1/gos;
    $theText =~ s/%dot%/\./gos;
    $theText =~ s/\&([^#a-z])/&amp;$1/go;    # escape non-entities
    $theText =~ s/</\&lt;/go;                # change < to entity
    $theText =~ s/>/\&gt;/go;                # change > to entity
    $theText =~ s/\"/\&quot;/go;             # change " to entity
    return $theText;
}

=pod

=cut

sub decodeFormatTokens {
    return if ( !$_[0] );
    $_[0] =~ s/\$n\(\)/\n/gos;               # expand '$n()' to new line
    my $alpha = Foswiki::Func::getRegularExpression('mixedAlpha');
    $_[0] =~ s/\$n([^$alpha]|$)/\n$1/gos;    # expand '$n' to new line
    $_[0] =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nested search
    $_[0] =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
    $_[0] =~ s/\$percnt(\(\))?/\%/gos; # expand percent
    $_[0] =~ s/\$dollar(\(\))?/\$/gos; # expand dollar
}

=begin TML

Style sheet for table in view mode

=cut

sub addViewModeHeadersToHead {
    return if $viewModeHeaderDone;

    $viewModeHeaderDone = 1;

    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%SYSTEMWEB%/EditTablePlugin/edittable.css");
</style>
EOF
    Foswiki::Func::addToHEAD( 'EDITTABLEPLUGIN', $header );
}

=begin TML

Style sheet and javascript for table in edit mode

=cut

sub addEditModeHeadersToHead {
    my ( $tableNr, $paramJavascriptInterface ) = @_;
    return if $editModeHeaderDone;
    return
      if !$usesJavascriptInterface && ( $paramJavascriptInterface ne 'on' );

    require Foswiki::Contrib::BehaviourContrib;
    Foswiki::Contrib::BehaviourContrib::addHEAD();

    $editModeHeaderDone = 1;

    my $formName = "edittable$tableNr";
    my $header   = "";
    $header .=
      '<meta name="EDITTABLEPLUGIN_FormName" content="' . $formName . '" />';
    $header .= "\n"
      . '<meta name="EDITTABLEPLUGIN_EditTableUrl" content="'
      . $ASSET_URL . '" />';
    $header .= <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%SYSTEMWEB%/EditTablePlugin/edittable.css");
</style>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/EditTablePlugin/edittable.js"></script>
EOF

    Foswiki::Func::addToHEAD( 'EDITTABLEPLUGIN', $header );
}

=begin TML

If param javscriptinterface="off", adds field to html meta.

=cut

sub addJavaScriptInterfaceDisabledToHead {
    my ($tableNr) = @_;

    my $tableId = "edittable$tableNr";
    my $header  = "";
    $header .=
'<meta name="EDITTABLEPLUGIN_NO_JAVASCRIPTINTERFACE_EditTableId" content="'
      . $tableId . '" />';
    $header .= "\n";
    Foswiki::Func::addToHEAD( 'EDITTABLEPLUGIN_NO_JAVASCRIPTINTERFACE',
        $header );
}

1;
