# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2008-2009 Eugen Mayer, Arthur Clemens, Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.
# Authors: Eugen Mayer, http://foswiki.org/Main/EugenMayer

package Foswiki::Plugins::SlideShowPlugin;

use strict;

use vars qw(
  $web $topic $user $installWeb $debug $addedHead
);

our $VERSION = '$Rev$';
our $RELEASE = '31 Mar 2009';
our $SHORTDESCRIPTION = 'Create web based presentations based on topics with headings';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    $addedHead = 0;
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between SlideShowPlugin and Plugins.pm");
        return 0;
    }

    return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    if ( $_[0] =~ /%SLIDESHOWSTART/ ) {
        _addHeader();
        require Foswiki::Plugins::SlideShowPlugin::SlideShow;
        Foswiki::Plugins::SlideShowPlugin::SlideShow::init($installWeb);
        $_[0] = Foswiki::Plugins::SlideShowPlugin::SlideShow::handler(@_);
    }
}

sub _addHeader {

    return if $addedHead;
    $header .= <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%SYSTEMWEB%/SlideShowPlugin/slideshow.css");
</style>
EOF
    Foswiki::Func::addToHEAD( 'SLIDESHOWPLUGIN', $header );
    $addedHead = 1;
}

1;
