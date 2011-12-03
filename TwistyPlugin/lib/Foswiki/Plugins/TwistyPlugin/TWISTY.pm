# See bottom of file for license and copyright information
package Foswiki::Plugins::TwistyPlugin::TWISTY;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::TWISTY

This is the perl stub for the jquery.twisty plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = bless(
        $class->SUPER::new(
            $session,
            name         => 'Twisty',
            version      => '1.6.0',
            author       => 'Rafael Alvarez, Michael Daum, Arthur Clemens',
            homepage     => 'http://foswiki.org/Extensions/TwistyPlugin',
            puburl       => '%PUBURLPATH%/%SYSTEMWEB%/TwistyPlugin',
            dependencies => [ 'livequery', 'JavascriptFiles/foswikiPref' ],
            javascript   => ['jquery.twisty.js'],
            css          => ['twisty.css']
        ),
        $class
    );

    # The jquery plugin code is using 'sub-cookies' within the FOSWIKIPREF
    # cookie.
    my $foswikiPrefs =
      Foswiki::Func::expandTemplate('JavascriptFiles/foswikiPref');

    Foswiki::Func::expandCommonVariables($foswikiPrefs);

    return $this;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
