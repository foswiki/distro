# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Crawford Currie
# Copyright (C) 2001-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
#
# For licensing info read LICENSE file in the TWiki root.
#
# See Plugin topic for history and plugin information

package TWiki::Plugins::CommentPlugin;

use strict;

require TWiki::Func;
require TWiki::Plugins;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC );

# This should always be $Rev: 15788 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 15788 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '03 Aug 2008';

$SHORTDESCRIPTION = 'Allows users to quickly post comments to a page without an edit/preview/save cycle';

sub initPlugin {
    #my ( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "CommentPlugin $VERSION requires TWiki::Plugins::VERSION >= 1.026, $TWiki::Plugins::VERSION found." );
        return 0;
    }

    return 1;
}

sub commonTagsHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    require TWiki::Plugins::CommentPlugin::Comment;

    my $query = TWiki::Func::getCgiQuery();
    return unless( defined( $query ));

    return unless $_[0] =~ m/%COMMENT({.*?})?%/o;

    # SMELL: Nasty, tacky way to find out where we were invoked from
    my $scriptname = $ENV{'SCRIPT_NAME'} || '';
    # SMELL: unreliable
    my $previewing = ($scriptname =~ /\/(preview|gnusave|rdiff)/);
    TWiki::Plugins::CommentPlugin::Comment::prompt( $previewing,
                                                    $_[0], $web, $topic );
}

sub beforeSaveHandler {
    #my ( $text, $topic, $web ) = @_;

    require TWiki::Plugins::CommentPlugin::Comment;

    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    my $action = $query->param('comment_action');

    return unless( defined( $action ) && $action eq 'save' );
    TWiki::Plugins::CommentPlugin::Comment::save( @_ );
}

1;
