# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Javascript is Copyright (C) 2012 Sven Dowideit - SvenDowideit@fosiki.com
#

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details,
# published at http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TinyMCEPlugin::TinyMCE;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::TinyMCEPlugin::TinyMCE

This is the perl stub for tinyMCE.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

<script type="text/javascript" src="$pluginURL/foswiki$USE_SRC.js?v=$encodedVersion"></script>

=cut

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    # URL-encode the version number to include in the .js URLs, so that
    # the browser re-fetches the .js when this plugin is upgraded.
    my $encodedVersion = $Foswiki::Plugins::TinyMCEPlugin::VERSION;

    # SMELL: This regex (and the one applied to $metainit, above)
    # duplicates Foswiki::urlEncode(), but Foswiki::Func.pm does not
    # expose that function, so plugins may not use it
    #$encodedVersion =~
    #  s/([^0-9a-zA-Z-_.:~!*'\/%])/'%'.sprintf('%02x',ord($1))/ge;

    my $this = bless(
        $class->SUPER::new(
            name          => 'TinyMCE',
            version       => $encodedVersion,
            author        => 'Foswiki Contributors',
            homepage      => 'http://foswiki.org/Extensions/TinyMCEPlugin',
            documentation => "$Foswiki::cfg{SystemWebName}.TinyMCEPlugin",
            puburl        => '%PUBURLPATH%/%SYSTEMWEB%/TinyMCEPlugin',
            javascript    => [
                'foswiki_tiny.js', 'foswiki.js',
                '/tinymce/jscripts/tiny_mce/tiny_mce.js'
            ],
            dependencies => ['JQUERYPLUGIN::FOSWIKI']
        ),
        $class
    );

    return $this;
}

sub renderJS {
    my ( $this, $text ) = @_;

    $text =~ s/\.js$/_src.js/
      if ( $this->{debug} )
      || ( Foswiki::Func::getPreferencesValue('TINYMCEPLUGIN_DEBUG') );
    $text .= '?version=' . $this->{version} if ( $this->{version} =~ '$Rev$' );
    $text =
      "<script type='text/javascript' src='$this->{puburl}/$text'></script>\n";
    return $text;
}

1;
