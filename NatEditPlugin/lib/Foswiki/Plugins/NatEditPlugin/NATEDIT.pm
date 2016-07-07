# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2015 Michael Daum, http://michaeldaumconsulting.com
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
use v5.14;

use Foswiki::Func ();

use Moo;
use namespace::clean;
extends qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::NatEditPlugin::NATEDIT

This is the perl stub for the jquery.natedit plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;

    my $app = $params{app};

    return $orig->(
        $class, @_,
        name          => 'NatEdit',
        version       => '4.01',
        author        => 'Michael Daum',
        homepage      => 'http://foswiki.org/Extensions/NatEditPlugin',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/NatEditPlugin',
        css           => ['styles.css'],
        documentation => $app->cfg->data->{SystemWebName} . ".NatEditPlugin",
        javascript    => ['jquery.natedit.js'],
        dependencies  => [
            'JQUERYPLUGIN::FOSWIKI::PREFERENCES', 'textboxlist',
            'pnotify',                            'fontawesome',
            'form',                               'validate',
            'ui',                                 'ui::dialog',
            'ui::tooltip',                        'tabpane',
            'ui::autocomplete',                   'ui::button',
            'button',                             'loader',
            'JQUERYPLUGIN::UPLOADER',             'blockui',
            'render',
        ],
    );
};

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the html header

=cut

around init => sub {
    my $orig = shift;
    my $this = shift;

    return unless $orig->( $this, @_ );

    Foswiki::Func::addToZone(
        "script", "NATEDIT::PREFERENCES",
        <<'HERE', "JQUERYPLUGIN::FOSWIKI::PREFERENCES" );
<script class='$zone $id foswikiPreferences' type='text/json'>{ 
  "NatEditPlugin": {
    "MathEnabled": %IF{"context MathModePluginEnabled or context MathJaxPluginEnabled" then="true" else="false"}%,
    "ImagePluginEnabled": %IF{"context ImagePluginEnabled" then="true" else="false"}%,
    "TopicInteractionPluginEnabled": %IF{"context TopicInteractionPluginEnabled" then="true" else="false"}%,
    "FarbtasticEnabled": %IF{"context FarbtasticEnabled" then="true" else="false"}%
  }
}</script>
HERE
};

1;
