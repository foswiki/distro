
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package TWiki::Plugins::TinyMCEPlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );
use Assert;

$VERSION = '$Rev$';
$RELEASE = '03 Aug 2008';
$SHORTDESCRIPTION = 'Integration of TinyMCE with WysiwygPlugin';

use TWiki::Func;

my $query;
# Info about browser type
my %browserInfo;

sub initPlugin {
    $query = TWiki::Func::getCgiQuery();
    return 0 unless $query;
    unless( $TWiki::cfg{Plugins}{WysiwygPlugin}{Enabled} ) {
        TWiki::Func::writeWarning("TinyMCEPlugin is enabled but WysiwygPlugin is not enabled. Both plugins must be installed and enabled for TinyMCE.");
        return 0;
    }

    # Identify the browser from the user agent string
    my $ua = $query->user_agent();
    if ($ua) {
        $browserInfo{isMSIE} = $ua =~ /MSIE/;
        $browserInfo{isMSIE5} = $browserInfo{isMSIE} && ($ua =~ /MSIE 5/);
        $browserInfo{isMSIE5_0} = $browserInfo{isMSIE} && ($ua =~ /MSIE 5.0/);
        $browserInfo{isMSIE6} = $browserInfo{isMSIE} && $ua =~ /MSIE 6/;
        $browserInfo{isMSIE7} = $browserInfo{isMSIE} && $ua =~ /MSIE 7/;
        $browserInfo{isGecko} = $ua =~ /Gecko/; # Will also be true on Safari
        $browserInfo{isSafari} = $ua =~ /Safari/;
        $browserInfo{isOpera} = $ua =~ /Opera/;
        $browserInfo{isMac} = $ua =~ /Mac/;
        $browserInfo{isNS7} = $ua =~ /Netscape\/7/;
        $browserInfo{isNS71} = $ua =~ /Netscape\/7.1/;
    }

    return 1;
}

sub _notAvailable {
    return "Disabled by preference '".TWiki::Func::getPreferencesValue('TINYMCEPLUGIN_DISABLE')."'" if
      TWiki::Func::getPreferencesFlag('TINYMCEPLUGIN_DISABLE');

    # Disable TinyMCE if we are on a specialised edit skin
    my $skin = TWiki::Func::getPreferencesValue('WYSIWYGPLUGIN_WYSIWYGSKIN');
    return "$skin is active"
      if( $skin && TWiki::Func::getSkin() =~ /\b$skin\b/o );

    return "No browser" unless $query;

    return "Disabled by URL parameter" if $query->param('nowysiwyg');

    # Check the client browser to see if it is blacklisted
    my $ua = TWiki::Func::getPreferencesValue('TINYMCEPLUGIN_BAD_BROWSERS') ||
      '(?i-xsm:Konqueror|Opera)';
    return 'Unsupported browser: '.$query->user_agent()
      if $ua && $query->user_agent() && $query->user_agent() =~ /$ua/;

    return 0;
}

sub beforeEditHandler {
    #my ($text, $topic, $web) = @_;

    my $mess = _notAvailable();
    if ($mess) {
        if (($mess !~ /^Disabled/ || DEBUG) &&
              defined &TWiki::Func::setPreferencesValue) {
            TWiki::Func::setPreferencesValue(
                'EDITOR_MESSAGE',
                'WYSIWYG could not be started: '.$mess);
        }
        return;
    }
    if (defined &TWiki::Func::setPreferencesValue) {
        TWiki::Func::setPreferencesValue('EDITOR_HELP', 'TinyMCEQuickHelp');
    }

    my $init = TWiki::Func::getPreferencesValue('TINYMCEPLUGIN_INIT')
      || <<'HERE';
'
HERE
    my $extras = '';
    # The order of these conditions is important, because browsers
    # spoof eachother
    if ($browserInfo{isSafari}) {
        $extras = 'SAFARI';
    } elsif ($browserInfo{isOpera}) {
        $extras = 'OPERA';
    } elsif ($browserInfo{isGecko}) {
        $extras = 'GECKO';
    } elsif ($browserInfo{isMSIE}) {
        $extras = 'MSIE';
    }
    if ($extras) {
        $extras = TWiki::Func::getPreferencesValue(
            'TINYMCEPLUGIN_INIT_'.$extras);
        if (defined $extras) {
            $init = join(',', (split(',',$init), split(',',$extras)));
        }
    }

    require TWiki::Plugins::WysiwygPlugin;

    $mess = TWiki::Plugins::WysiwygPlugin::notWysiwygEditable($_[0]);
    if ($mess) {
        if (defined &TWiki::Func::setPreferencesValue) {
            TWiki::Func::setPreferencesValue(
                'EDITOR_MESSAGE',
                'WYSIWYG could not be started: '.$mess);
        }
        return;
    }

    my $USE_SRC = '';
    if (TWiki::Func::getPreferencesValue('TINYMCEPLUGIN_DEBUG')) {
        $USE_SRC = '_src';
    }

    # Add the Javascript for the editor. When it starts up the editor will
    # use a REST call to the WysiwygPlugin tml2html REST handler to convert
    # the textarea content from TML to HTML.
    my $pluginURL = '%PUBURL%/%TWIKIWEB%/TinyMCEPlugin';
    my $tmceURL = $pluginURL.'/tinymce/jscripts/tiny_mce';
    # expand and URL-encode the init string
    my $metainit = TWiki::Func::expandCommonVariables($init);
    $metainit =~ s/([^0-9a-zA-Z-_.:~!*'\/%])/'%'.sprintf('%02x',ord($1))/ge;
    my $behaving;
    eval {
        require TWiki::Contrib::BehaviourContrib;
        if (defined(&TWiki::Contrib::BehaviourContrib::addHEAD)) {
            TWiki::Contrib::BehaviourContrib::addHEAD();
            $behaving = 1;
        }
    };
    unless ($behaving) {
        TWiki::Func::addToHEAD(
            'BEHAVIOURCONTRIB',
            '<script type="text/javascript" src="%PUBURLPATH%/%TWIKIWEB%/BehaviourContrib/behaviour.js"></script>');
    }
    TWiki::Func::addToHEAD('tinyMCE', <<SCRIPT);
<meta name="TINYMCEPLUGIN_INIT" content="$metainit" />
<script language="javascript" type="text/javascript" src="$tmceURL/tiny_mce$USE_SRC.js"></script>
<script language="javascript" type="text/javascript" src="$pluginURL/twiki_tiny$USE_SRC.js"></script>
<script language="javascript" type="text/javascript" src="$pluginURL/twiki$USE_SRC.js"></script>
SCRIPT

    # See TWiki.IfStatements for a description of this context id.
    TWiki::Func::getContext()->{textareas_hijacked} = 1;
}

1;

