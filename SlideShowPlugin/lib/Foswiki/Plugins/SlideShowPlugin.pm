# See bottom of file for license and copyright information
package Foswiki::Plugins::SlideShowPlugin;

use strict;
use warnings;

use Foswiki::Request;

BEGIN {
    # Backwards compatibility for Foswiki 1.1.x
    unless ( Foswiki::Request->can('multi_param') ) {
        no warnings 'redefine';
        *Foswiki::Request::multi_param = \&Foswiki::Request::param;
        use warnings 'redefine';
    }
}

our $VERSION = 2.32;
our $RELEASE = '06 Sep 2016';
our $SHORTDESCRIPTION =
  'Create web based presentations based on topics with headings';
our $NO_PREFS_IN_TOPIC = 1;

our $core;

sub initPlugin {

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between SlideShowPlugin and Plugins.pm");
        return 0;
    }
    $core = undef;

    return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    if ( $_[0] =~ m/%SLIDESHOWSTART/ ) {
        unless ($core) {
            require Foswiki::Plugins::SlideShowPlugin::SlideShow;
            $core = new Foswiki::Plugins::SlideShowPlugin::SlideShow();
        }
        $_[0] = $core->renderSlideShow(@_);
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
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
