# RenderFormPlugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Daniel Rohde
#
# For licensing info read LICENSE file in the Foswiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.

package Foswiki::Plugins::RenderFormPlugin;

use strict;

use vars qw( $VERSION $RELEASE $REVISION $debug $pluginName );

$VERSION = '1.007';

$RELEASE = '18 Aug 2010';

#$REVISION = '1.007'; #Paul Harvey# fix plugin code to only require JSCalendarContrib once
#$REVISION = '1.006'; #Paul Harvey# added redirectto parameter
#$REVISION = '1.005'; #Daniel Rohde# fixed performance problem
#$REVISION = '1.004'; #Kenneth Lavrsen# Fixed a bug that causes JSCalendarContrib to stack overflow. Fix includes changing to official API way to add JSCalendar.
#$REVISION = '1.003'; #Kenneth Lavrsen# Changed to Foswiki name space
#$REVISION = '1.002'; #dro# added layout feature; fixed date field bug; added missing docs;
#$REVISION = '1.001'; #dro# changed topicparent default; added and fixed docs; fixed date field bug; fixed non-word character in field names bug;
#$REVISION = '1.000'; #dro# initial version

$pluginName = 'RenderFormPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }
    _requireJSCalendarContrib();

    # Plugin correctly initialized
    return 1;
}

sub commonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    Foswiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    use Foswiki::Plugins::RenderFormPlugin::Core;
    $_[0] =~
s/\%RENDERFORM{(.*?)}\%/Foswiki::Plugins::RenderFormPlugin::Core::render($1,$_[1],$_[2])/ge;
    $_[0] =~ s/\%STARTRENDERFORMLAYOUT(.*?)STOPRENDERFORMLAYOUT\%//sg;
}

sub _requireJSCalendarContrib {

    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;
    #
    #
    eval {
        require Foswiki::Contrib::JSCalendarContrib;
        unless ($@) {
            Foswiki::Contrib::JSCalendarContrib::addHEAD('foswiki');
        }
    };
}

1;
