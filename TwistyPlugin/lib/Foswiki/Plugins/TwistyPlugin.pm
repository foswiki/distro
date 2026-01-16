# See bottom of file for license and copyright information

=begin TML

---+ package TwistyPlugin

=cut

package Foswiki::Plugins::TwistyPlugin;

use strict;
use warnings;

use Foswiki::Func ();

our $VERSION = '4.00';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION =
  'Twisty section Javascript library to open/close content dynamically';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub initPlugin {

    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'twisty',
        'Foswiki::Plugins::TwistyPlugin::TWISTY' );

    Foswiki::Func::registerTagHandler(
        'TWISTYSHOW',
        sub {
            getCore(shift)->TWISTYSHOW(@_);
        }
    );

    Foswiki::Func::registerTagHandler(
        'TWISTYHIDE',
        sub {
            getCore(shift)->TWISTYHIDE(@_);
        }
    );

    Foswiki::Func::registerTagHandler(
        'TWISTYBUTTON',
        sub {
            getCore(shift)->TWISTYBUTTON(@_);
        }
    );

    Foswiki::Func::registerTagHandler(
        'TWISTY',
        sub {
            getCore(shift)->TWISTY(@_);
        }
    );

    Foswiki::Func::registerTagHandler(
        'ENDTWISTY',
        sub {
            getCore(shift)->ENDTWISTYTOGGLE(@_);
        }
    );

    Foswiki::Func::registerTagHandler(
        'TWISTYTOGGLE',
        sub {
            getCore(shift)->TWISTYTOGGLE(@_);
        }
    );

    Foswiki::Func::registerTagHandler(
        'ENDTWISTYTOGGLE',
        sub {
            getCore(shift)->ENDTWISTYTOGGLE(@_);
        }
    );

    return 1;
}

sub getCore {
    unless ($core) {
        require Foswiki::Plugins::TwistyPlugin::Core;
        $core = Foswiki::Plugins::TwistyPlugin::Core->new(shift);
    }

    return $core;
}

sub finishPlugin {
    if ( defined $core ) {
        $core->finish();
        undef $core;
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2026 Foswiki Contributors. Foswiki Contributors
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
