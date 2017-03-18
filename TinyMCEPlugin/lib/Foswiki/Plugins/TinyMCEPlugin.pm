# See bottom of file for license and copyright information

package Foswiki::Plugins::TinyMCEPlugin;

use strict;
use warnings;

use Assert;

our $VERSION           = '1.31';
our $RELEASE           = '1.31';
our $SHORTDESCRIPTION  = 'Integration of the Tiny MCE WYSIWYG Editor';
our $NO_PREFS_IN_TOPIC = 1;

use Foswiki::Func ();
my $query;

sub initPlugin {
    $query = Foswiki::Func::getCgiQuery();
    return 0 unless $query;

    unless ( $Foswiki::cfg{Plugins}{WysiwygPlugin}{Enabled} ) {
        Foswiki::Func::writeWarning(
"TinyMCEPlugin is enabled but WysiwygPlugin is not. Both must be installed and enabled for TinyMCE."
        );
        return 0;
    }
    unless ( $Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled} ) {
        Foswiki::Func::writeWarning(
"TinyMCEPlugin is enabled but JQueryPlugin is not. Both must be installed and enabled for TinyMCE."
        );
        return 0;
    }

    return 1;
}

sub _notAvailable {
    for my $c (qw(TINYMCEPLUGIN_DISABLE NOWYSIWYG)) {
        return "Disabled by * Set $c = "
          . Foswiki::Func::getPreferencesValue($c)
          if Foswiki::Func::getPreferencesFlag($c);
    }

    # Disable TinyMCE if we are on a specialised edit skin
    my $skin = Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_WYSIWYGSKIN');
    return "$skin is active"
      if ( $skin && Foswiki::Func::getSkin() =~ m/\b$skin\b/ );

    return "No browser" unless $query;

    return "Disabled by URL parameter" if $query->param('nowysiwyg');

    # Check the client browser to see if it is blacklisted
    my $ua = Foswiki::Func::getPreferencesValue('TINYMCEPLUGIN_BAD_BROWSERS')
      || '(?i-xsm:Konqueror)';
    return 'Unsupported browser: ' . $query->user_agent()
      if $ua && $query->user_agent() && $query->user_agent() =~ m/$ua/;

    # This should only ever happen on Foswiki 1.0.9 and earlier
    return 'TinyMCEPlugin requires ZonePlugin to be installed and enabled'
      unless ( defined &Foswiki::Func::addToZone );

    return 0;
}

sub beforeEditHandler {
    my ( $text, $topic, $web ) = @_;

    my $mess = _notAvailable();
    if ($mess) {
        my $disabled = ( $mess !~ /^Disabled/ );
        $mess = 'WYSIWYG could not be started: ' . $mess;
        if ( ( $disabled || DEBUG )
            && defined &Foswiki::Func::setPreferencesValue )
        {
            Foswiki::Func::setPreferencesValue( 'EDITOR_MESSAGE', $mess );
        }
        Foswiki::Func::writeDebug($mess) if DEBUG;
        return;
    }
    if ( defined &Foswiki::Func::setPreferencesValue ) {
        Foswiki::Func::setPreferencesValue( 'EDITOR_HELP', 'TinyMCEQuickHelp' );
    }

    my $initTopic =
      Foswiki::Func::getPreferencesValue('TINYMCEPLUGIN_INIT_TOPIC')
      || $Foswiki::cfg{SystemWebName} . '.TinyMCEPlugin';
    my $init = Foswiki::Func::getPreferencesValue('TINYMCEPLUGIN_INIT')
      || Foswiki::Func::expandCommonVariables(
        '%INCLUDE{"'
          . $initTopic
          . '" section="TINYMCEPLUGIN_INIT" warn="off"}%',
        $topic, $web
      );

    require Foswiki::Plugins::WysiwygPlugin;
    my ( $browser, $defaultINIT_BROWSER ) =
      Foswiki::Plugins::WysiwygPlugin::getBrowserName();

    if ($browser) {
        my $settings =
          Foswiki::Func::getPreferencesValue( 'TINYMCEPLUGIN_INIT_' . $browser )
          || $defaultINIT_BROWSER;
        if ($settings) {
            $init =
              join( ',', ( split( ',', $init ), split( ',', $settings ) ) );
        }
    }

    $mess = Foswiki::Plugins::WysiwygPlugin::notWysiwygEditable($text);
    if ($mess) {
        $mess = 'WYSIWYG could not be started: ' . $mess;
        if ( defined &Foswiki::Func::setPreferencesValue ) {
            Foswiki::Func::setPreferencesValue( 'EDITOR_MESSAGE', $mess );
            Foswiki::Func::setPreferencesValue( 'EDITOR_HELP',    undef );
        }
        Foswiki::Func::writeDebug($mess) if DEBUG;
        return;
    }

    installTinyMCE( 'TinyMCEPluginTextArea', $init );

    return;
}

sub installTinyMCE {
    my $sectionName = shift;
    my $init        = shift;

    require Foswiki::Plugins::JQueryPlugin;
    Foswiki::Plugins::JQueryPlugin::createPlugin("tinymce");

    my $scripts = <<"SCRIPT";
<script type="text/javascript">
jQuery(function(\$) { FoswikiTiny.install(); });
FoswikiTiny.init = {$init};
</script>
SCRIPT

    Foswiki::Func::addToZone( 'script', $sectionName,
        Foswiki::Func::expandCommonVariables($scripts),
        'JQUERYPLUGIN::TINYMCE' );

    # See %SYSTEMWEB%.IfStatements for a description of this context id.
    Foswiki::Func::getContext()->{textareas_hijacked} = 1;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2017 Foswiki Contributors. Foswiki Contributors
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
