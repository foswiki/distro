# See bottom of file for license and copyright information
package Foswiki::Plugins::TinyMCEPlugin::TinyMCE;
use v5.14;

use Foswiki::Func;
use Foswiki::Plugins;
use JSON();

use Moo;
use namespace::clean;
extends qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::FOSWIKI

This is the perl stub for the jquery.foswiki plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

our %pluginParams = (
    name    => 'TinyMCE',
    version => 1.2,

#  version      => $encodedVersion;   # SMELL: version should be dynamically determined.
    author        => 'Foswiki Contributors',
    homepage      => 'https://foswiki.org/Extensions/TinyMCEPlugin',
    documentation => "$Foswiki::cfg{SystemWebName}.TinyMCEPlugin",
    puburl        => '%PUBURLPATH%/%SYSTEMWEB%/TinyMCEPlugin',
    javascript    => [
        'foswiki_tiny.js', 'foswiki.js',
        '/tinymce/jscripts/tiny_mce/tiny_mce.js'
    ],
    dependencies => ['foswiki'],
);

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the html header

Constructor

<script type="text/javascript" src="$pluginURL/foswiki$USE_SRC.js?v=$encodedVersion"></script>

=cut

around init => sub {
    my $class = shift;

    # URL-encode the version number to include in the .js URLs, so that
    # the browser re-fetches the .js when this plugin is upgraded.
    my $encodedVersion = $Foswiki::Plugins::TinyMCEPlugin::VERSION;

    # SMELL: This regex (and the one applied to $metainit, above)
    # duplicates Foswiki::urlEncode(), but Foswiki::Func.pm does not
    # expose that function, so plugins may not use it
    #$encodedVersion =~
    #  s/([^0-9a-zA-Z-_.:~!*'\/%])/'%'.sprintf('%02x',ord($1))/ge;

    return;
};

sub renderJS {
    my $this = shift;
    my $text = shift;

    print STDERR "renderJS entered with $text\n";

    $text .= '?version=' . $this->{version} if ( $this->{version} =~ '$Rev$' );
    $text =
      "<script type='text/javascript' src='$this->{puburl}/$text'></script>\n";
    return $text;
}

1;

__END__

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
#  Javascript is Copyright (C) 2012 Sven Dowideit - SvenDowideit@fosiki.com
# 
#  This program is free software; you can redistribute it and/or modify it under
#  the terms of the GNU General Public License as published by the Free Software
#  Foundation; either version 2 of the License, or (at your option) any later
#  version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details,
#  published at http://www.gnu.org/copyleft/gpl.html
#
