# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2016 Michael Daum, http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::NatEditPlugin::NATEDIT;
use strict;
use warnings;

use Foswiki::Func                          ();
use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::NatEditPlugin::NATEDIT

This is the perl stub for the jquery.natedit plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            name          => 'NatEdit',
            version       => '4.99',
            author        => 'Michael Daum',
            homepage      => 'http://foswiki.org/Extensions/NatEditPlugin',
            puburl        => '%PUBURLPATH%/%SYSTEMWEB%/NatEditPlugin',
            css           => ['styles.css'],
            documentation => "$Foswiki::cfg{SystemWebName}.NatEditPlugin",
            javascript    => [ 'jquery.natedit.js', 'engine/base/engine.js' ],
            i18n => $Foswiki::cfg{SystemWebName} . "/NatEditPlugin/i18n",
            dependencies => [
                'JQUERYPLUGIN::FOSWIKI::PREFERENCES', 'textboxlist',
                'pnotify',                            'fontawesome',
                'form',                               'validate',
                'ui',                                 'ui::dialog',
                'ui::tooltip',                        'tabpane',
                'ui::autocomplete',                   'ui::button',
                'button',                             'loader',
                'JQUERYPLUGIN::UPLOADER',             'blockui',
                'render',                             'imagesloaded'
            ],
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the html header

=cut

sub init {
    my $this = shift;

    return unless $this->SUPER::init();

    my $request = Foswiki::Func::getRequestObject();
    my $engine =
         $request->param("natedit_engine")
      || Foswiki::Func::getPreferencesValue("NATEDIT_ENGINE")
      || $Foswiki::cfg{NatEditPlugin}{DefaultEngine}
      || 'raw';

# force into raw as it is the only engine compatible with TinyMCEPlugin loading TinyMCE on its own
    $engine = 'tinymce_native' if _isTinyMCEEnabled();

    Foswiki::Func::addToZone(
        "script", "NATEDIT::PREFERENCES",
        <<"HERE", "JQUERYPLUGIN::FOSWIKI::PREFERENCES" );
<script class='\$zone \$id foswikiPreferences' type='text/json'>{ 
  "NatEditPlugin": {
    "Engine": "$engine",
    "ContentCSS": ["%PUBURLPATH%/%SYSTEMWEB%/TinyMCEPlugin/wysiwyg.css","%PUBURLPATH%/%SYSTEMWEB%/SkinTemplates/base.css","%FOSWIKI_STYLE_URL%","%FOSWIKI_COLORS_URL%"],
    "MathEnabled": %IF{"context MathModePluginEnabled or context MathJaxPluginEnabled" then="true" else="false"}%,
    "ImagePluginEnabled": %IF{"context ImagePluginEnabled" then="true" else="false"}%,
    "TopicInteractionPluginEnabled": %IF{"context TopicInteractionPluginEnabled" then="true" else="false"}%,
    "FarbtasticEnabled": %IF{"context FarbtasticEnabled" then="true" else="false"}%
  }
}</script>
HERE
}

# SMELL: see for Foswiki::Plugins::TinyMCEPLugin::_notAvailable
sub _isTinyMCEEnabled {
    for my $c (qw(TINYMCEPLUGIN_DISABLE NOWYSIWYG)) {
        return 0 if Foswiki::Func::getPreferencesFlag($c);
    }

    my $skin = Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_WYSIWYGSKIN');
    return 0 if $skin && Foswiki::Func::getSkin() =~ m/\b$skin\b/;

    my $query = Foswiki::Func::getCgiQuery();
    return 0 unless $query;
    return 0 if $query->param('nowysiwyg');

    return 1;
}

1;
