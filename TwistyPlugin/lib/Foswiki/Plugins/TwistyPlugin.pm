# See bottom of file for license and copyright information

=begin TML

---+ package TwistyPlugin

=cut

package Foswiki::Plugins::TwistyPlugin;
use strict;
use warnings;

use Foswiki::Func ();

our $VERSION = '$Rev$';

our $RELEASE = '1.6.0';
our $SHORTDESCRIPTION =
  'Twisty section Javascript library to open/close content dynamically';
our $NO_PREFS_IN_TOPIC = 1;

my $loadedCore;

#there is no need to document this.
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.1 ) {
        Foswiki::Func::writeWarning(
            'Version mismatch between TwistyPlugin and Plugins.pm');
        return 0;
    }

    if ( Foswiki::Func::getContext()->{JQueryPluginEnabled} ) {
        Foswiki::Plugins::JQueryPlugin::registerPlugin( 'twisty',
            'Foswiki::Plugins::TwistyPlugin::TWISTY' );
    }
    Foswiki::Func::registerTagHandler( 'TWISTYSHOW',      \&_TWISTYSHOW );
    Foswiki::Func::registerTagHandler( 'TWISTYHIDE',      \&_TWISTYHIDE );
    Foswiki::Func::registerTagHandler( 'TWISTYBUTTON',    \&_TWISTYBUTTON );
    Foswiki::Func::registerTagHandler( 'TWISTY',          \&_TWISTY );
    Foswiki::Func::registerTagHandler( 'ENDTWISTY',       \&_ENDTWISTYTOGGLE );
    Foswiki::Func::registerTagHandler( 'TWISTYTOGGLE',    \&_TWISTYTOGGLE );
    Foswiki::Func::registerTagHandler( 'ENDTWISTYTOGGLE', \&_ENDTWISTYTOGGLE );
    $loadedCore = 0;

    return 1;
}

sub _loadCore {
    if ( not $loadedCore ) {
        require Foswiki::Plugins::TwistyPlugin::Core;
        Foswiki::Plugins::TwistyPlugin::Core::init();
        $loadedCore = 1;
    }

    return;
}

sub _TWISTYSHOW {
    my (@args) = @_;

    _loadCore();

    return Foswiki::Plugins::TwistyPlugin::Core::TWISTYSHOW(@args);
}

sub _TWISTYHIDE {
    my (@args) = @_;

    _loadCore();

    return Foswiki::Plugins::TwistyPlugin::Core::TWISTYHIDE(@args);
}

sub _TWISTYBUTTON {
    my (@args) = @_;

    _loadCore();

    return Foswiki::Plugins::TwistyPlugin::Core::TWISTYBUTTON(@args);
}

sub _TWISTY {
    my (@args) = @_;

    _loadCore();

    return Foswiki::Plugins::TwistyPlugin::Core::TWISTY(@args);
}

sub _ENDTWISTYTOGGLE {
    my (@args) = @_;

    _loadCore();

    return Foswiki::Plugins::TwistyPlugin::Core::ENDTWISTYTOGGLE(@args);
}

sub _TWISTYTOGGLE {
    my (@args) = @_;

    _loadCore();

    return Foswiki::Plugins::TwistyPlugin::Core::TWISTYTOGGLE(@args);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) Michael Daum
Copyright (C) Arthur Clemens, arthur@visiblearea.com
Copyright (C) Rafael Alvarez, soronthar@sourceforge.net

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
