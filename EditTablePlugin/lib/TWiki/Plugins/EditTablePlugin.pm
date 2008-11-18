# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Arthur Clemens, arthur@visiblearea.com
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

package TWiki::Plugins::EditTablePlugin;

use strict;

use vars qw(
  $web $topic $user $VERSION $RELEASE $debug
  $query $usesJavascriptInterface $viewModeHeaderDone $editModeHeaderDone $encodeStart $encodeEnd $prefsInitialized
  %editMode %saveMode $ASSET_URL
);

# This should always be $Rev: 17303 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 17303 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '4.9';

$encodeStart = '--EditTableEncodeStart--';
$encodeEnd   = '--EditTableEncodeEnd--';
%editMode    = ( 'NONE', 0, 'EDIT', 1 );
%saveMode    = ( 'NONE', 0, 'SAVE', 1, 'SAVEQUIET', 2 );
$ASSET_URL   = '%PUBURL%/%SYSTEMWEB%/EditTablePlugin';

sub initPlugin {
    ( $topic, $web, $user ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between EditTablePlugin and Plugins.pm");
        return 0;
    }

    $query = TWiki::Func::getCgiQuery();
    if ( !$query ) {
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag('EDITTABLEPLUGIN_DEBUG');
    $usesJavascriptInterface =
      TWiki::Func::getPreferencesFlag('EDITTABLEPLUGIN_JAVASCRIPTINTERFACE');
    $viewModeHeaderDone = 0;
    $editModeHeaderDone = 0;
    $prefsInitialized   = 0;

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::EditTablePlugin::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

sub beforeCommonTagsHandler {
    return unless $_[0] =~ /%EDIT(TABLE|CELL){(.*)}%/os;
    require TWiki::Plugins::EditTablePlugin::Core;
    TWiki::Plugins::EditTablePlugin::Core::protectVariables(
        $_[0] );
}

sub commonTagsHandler {
    return unless $_[0] =~ /%EDIT(TABLE|CELL){(.*)}%/os;

    addViewModeHeadersToHead();
    require TWiki::Plugins::EditTablePlugin::Core;
    TWiki::Plugins::EditTablePlugin::Core::process( $_[0], $_[1], $_[2], $topic,
        $web );
}

sub postRenderingHandler {
    $_[0] =~ s/$encodeStart(.*?)$encodeEnd/decodeValue($1)/geos;
}

sub encodeValue {

    # FIXME: *very* crude encoding to escape Wiki rendering inside form fields
    # also prevents urls to get expanded to links
    $_[0] =~ s/\./%dot%/gos;
    $_[0] =~ s/(.)/\.$1/gos;

    # convert <br /> markup to unicode linebreak character for text areas
    $_[0] =~ s/.<.b.r. .\/.>/&#10;/gos;
    $_[0] = $encodeStart . $_[0] . $encodeEnd;
}

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

sub decodeFormatTokens {
    return if ( !$_[0] );
    $_[0] =~ s/\$n\(\)/\n/gos;               # expand '$n()' to new line
    my $alpha = TWiki::Func::getRegularExpression('mixedAlpha');
    $_[0] =~ s/\$n([^$alpha]|$)/\n$1/gos;    # expand '$n' to new line
    $_[0] =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nested search
    $_[0] =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
    $_[0] =~ s/\$percnt(\(\))?/\%/gos; # expand percent
    $_[0] =~ s/\$dollar(\(\))?/\$/gos; # expand dollar
}

=pod

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
    TWiki::Func::addToHEAD( 'EDITTABLEPLUGIN', $header );
}

=pod

Style sheet and javascript for table in edit mode

=cut

sub addEditModeHeadersToHead {
    my ( $tableNr, $paramJavascriptInterface ) = @_;
    return if $editModeHeaderDone;
    return
      if !$usesJavascriptInterface && ( $paramJavascriptInterface ne 'on' );

    require TWiki::Contrib::BehaviourContrib;
    TWiki::Contrib::BehaviourContrib::addHEAD();

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

    TWiki::Func::addToHEAD( 'EDITTABLEPLUGIN', $header );
}

sub addJavaScriptInterfaceDisabledToHead {
    my ($tableNr) = @_;

    my $tableId = "edittable$tableNr";
    my $header  = "";
    $header .=
'<meta name="EDITTABLEPLUGIN_NO_JAVASCRIPTINTERFACE_EditTableId" content="'
      . $tableId . '" />';
    $header .= "\n";
    TWiki::Func::addToHEAD( 'EDITTABLEPLUGIN_NO_JAVASCRIPTINTERFACE', $header );
}

sub addHeaderAndFooterCountToHead {
    my ( $headerCount, $footerCount ) = @_;
    my $header = "";
    $header .= '<meta name="EDITTABLEPLUGIN_headerRows" content="'
      . $headerCount . '" />';
    $header .= "\n";
    $header .= '<meta name="EDITTABLEPLUGIN_footerRows" content="'
      . $footerCount . '" />';
    $header .= "\n";
    TWiki::Func::addToHEAD( 'EDITTABLEPLUGIN_HEADERFOOTERCOUNT', $header );
}

1;
