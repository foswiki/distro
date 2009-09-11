# See bottom of file for license and copyright information
#
# See Plugin topic for history and plugin information

package Foswiki::Plugins::CommentPlugin;

use strict;

require Foswiki::Func;
require Foswiki::Plugins;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC );

our $VERSION = '$Rev$';
our $RELEASE = '12 Sep 2009';
our $SHORTDESCRIPTION =
  'Quickly post comments to a page without an edit/preview/save cycle';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    #my ( $topic, $web, $user, $installWeb ) = @_;
    return 1;
}

sub commonTagsHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    require Foswiki::Plugins::CommentPlugin::Comment;

    my $query = Foswiki::Func::getCgiQuery();
    return unless( defined( $query ) );

    return unless $_[0] =~ m/%COMMENT({.*?})?%/o;

    # SMELL: Nasty, tacky way to find out where we were invoked from
    my $scriptname = $ENV{'SCRIPT_NAME'} || '';

    # SMELL: unreliable
    my $previewing = ( $scriptname =~ /\/(preview|gnusave|rdiff|compare)/ );
    Foswiki::Plugins::CommentPlugin::Comment::prompt( $previewing,
                                                    $_[0], $web, $topic );
}

sub beforeSaveHandler {
    #my ( $text, $topic, $web ) = @_;

    require Foswiki::Plugins::CommentPlugin::Comment;

    my $query = Foswiki::Func::getCgiQuery();
    return unless $query;

    my $action = $query->param('comment_action');

    return unless( defined( $action ) && $action eq 'save' );
    Foswiki::Plugins::CommentPlugin::Comment::save( @_ );
}

1;
__DATA__
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2001-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
# Copyright (C) 2004-2008 Crawford Currie
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
