# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::FOSWIKI;
use strict;
use warnings;
use Foswiki::Func;
use Foswiki::Plugins;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::FOSWIKI

This is the perl stub for the jquery.foswiki plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            name         => 'Foswiki',
            version      => '2.01',
            author       => 'Michael Daum',
            homepage     => 'http://foswiki.org/Extensions/JQueryPlugin',
            javascript   => ['jquery.foswiki.js'],
            dependencies => [ 'JQUERYPLUGIN', 'livequery' ],
            tags         => 'JQTHEME, JQREQUIRE, JQICON, JQICONPATH, JQPLUGINS',
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

    # get exported prefs
    my $prefs = Foswiki::Func::getPreferencesValue('EXPORTEDPREFERENCES') || '';

    # try a little harder for foswiki engines < 1.1
    if ( $Foswiki::Plugins::VERSION < 2.1 ) {

        # defaults since foswiki >= 1.1.0
        $prefs =
'PUBURL, PUBURLPATH, SCRIPTSUFFIX, SCRIPTURL, SCRIPTURLPATH, SERVERTIME, SKIN, SYSTEMWEB, TOPIC, USERNAME, USERSWEB, WEB, WIKINAME, WIKIUSERNAME, NAMEFILTER';
        $prefs .= ', TWISTYANIMATIONSPEED'
          if $Foswiki::cfg{Plugins}{TwistyPlugin}
              {Enabled};    # can't use context during init
    }

    # init NAMEFILTER
    unless ( Foswiki::Func::getPreferencesValue('NAMEFILTER') ) {
        Foswiki::Func::setPreferencesValue( 'NAMEFILTER',
            $Foswiki::cfg{NameFilter} );
    }

    # add exported preferences to head
    my $text = '';
    foreach my $pref ( split( /\s*,\s*/, $prefs ) ) {
        $text .=
            '<meta name="foswiki.' 
          . $pref
          . '" content="%ENCODE{"%'
          . $pref
          . '%"}%" />'
          . " <!-- $pref -->\n";
    }

    Foswiki::Func::addToZone( "head", "JQUERYPLUGIN::FOSWIKI::META", $text );
}

1;
__END__
Author: Michael Daum, http://michaeldaumconsulting.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2006-2010 Michael Daum http://michaeldaumconsulting.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
