# See bottom of file for license and copyright information
#
# See Plugin topic for history and plugin information

package Foswiki::Plugins::CommentPlugin;

use strict;
use warnings;
use Assert;
use Error ':try';

use Foswiki::Func    ();
use Foswiki::Plugins ();

our $VERSION = 'v2.0.3';
our $RELEASE = '2.0.3';
our $SHORTDESCRIPTION =
  'Quickly post comments to a page without an edit/save cycle';
our $NO_PREFS_IN_TOPIC = 1;

# Reset when the plugin is reset, this counter counts the instances of the
# %COMMENT macro and indexes them.
our $commentIndex;

sub initPlugin {

    my ( $topic, $web, $user, $installWeb ) = @_;
    $commentIndex = 0;

    Foswiki::Func::registerTagHandler( 'COMMENT', \&_COMMENT );
    Foswiki::Func::registerRESTHandler(
        'comment', \&_restSave,

        # validate   => 1, # TODO: needs javascript work
        http_allow => 'POST'
    );

    if (   (DEBUG)
        && $web   eq $Foswiki::cfg{SystemWebName}
        && $topic eq 'InstalledPlugins' )
    {

        # Compilation check
        require Foswiki::Plugins::CommentPlugin::Comment;
    }
    return 1;
}

sub _COMMENT {
    my ( $session, $params, $topic, $web ) = @_;

    # Indexing each macro instance
    $params->{comment_index} = $commentIndex++;

    # Check the context has 'view' script
    my $context  = Foswiki::Func::getContext();
    my $disabled = '';
    if ( $context->{command_line} ) {
        $disabled = Foswiki::Func::expandCommonVariables(
'%MAKETEXT{"Commenting is disabled while running from the command line"}%'
        );
    }
    elsif ( $context->{static} ) {
        $disabled = Foswiki::Func::expandCommonVariables(
            '%MAKETEXT{"Commenting is disabled for static viewing"}%');
    }
    elsif ( !$context->{view} ) {
        $disabled = Foswiki::Func::expandCommonVariables(
            '%MAKETEXT{"Commenting is disabled when not in view context"}%');
    }
    elsif (
        !(
               $Foswiki::cfg{Plugins}{CommentPlugin}{GuestCanComment}
            || $context->{authenticated}
        )
      )
    {
        $disabled = Foswiki::Func::expandCommonVariables(
            '%MAKETEXT{"Commenting is disabled while not logged in"}%');
    }

    require Foswiki::Plugins::CommentPlugin::Comment;

    Foswiki::Plugins::CommentPlugin::Comment::prompt( $params, $web, $topic,
        $disabled );
}

# REST handler for save operator. We use a REST handler because we need
# to be able to bypass the permissions checking that the save script
# would do. We handle the return in several different ways; first, if
# everything is OK, we set a 200 status and drop back to allow any
# endPoint to be handled. Second, if we get an exception, and the
# 'comment_ajax' parameter is set, we return a 500 status. If the
# parameter is not set, we pass the exception on to the UI package.

sub _restSave {
    my $session  = shift;
    my $response = $session->{response};
    my $query    = Foswiki::Func::getCgiQuery();

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef, $query->param('topic') );

    if ( $query->param('comment_target') ) {
        ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $web,
            $query->param('comment_target') );
    }

    $web =
      Foswiki::Sandbox::untaint( $web, \&Foswiki::Sandbox::validateWebName );

    unless ( Foswiki::Func::webExists($web) ) {
        if ( $query->param('comment_ajax') ) {
            $response->header( -status => 500 );
            $response->body(shift);
        }
        else {
            throw Foswiki::OopsException(
                'oopsattention',
                status => 403,
                def    => 'web_not_found',
                params => [ $web, "$web.$topic" ]
            );
        }
    }

    # Note: missing topic is okay,  will be created if allowed.
    # but it needs to be a valid name.

    my $origTopic = $topic;    # (Stash topic name in case it's bad)
    $topic = Foswiki::Sandbox::untaint( $topic,
        \&Foswiki::Sandbox::validateTopicName );

    unless ($topic) {

        # validation failed - illegal name, don't have a topic name
        if ( $query->param('comment_ajax') ) {
            $response->header( -status => 500 );
            $response->body(shift);
        }
        else {
            throw Foswiki::OopsException(
                'oopsattention',
                status => 403,
                def    => 'invalid_topic_parameter',
                params => [ "$origTopic", 'comment_target' ]
            );
        }
    }

   # SMELL: Foswiki.pm ensures that the web cannot access a topic beginning with
   # lower case letter,  so force it here as well.
    $topic = ucfirst($topic);

    if ( $query->param('redirectto') ) {
        Foswiki::Func::writeWarning(
"CommentPlugin: obsolete redirectto parameter overriding endPoint in $web.$topic"
        );
        $query->param(
            -name  => 'endPoint',
            -value => $query->param('redirectto')
        );
    }

    try {
        require Foswiki::Plugins::CommentPlugin::Comment;

        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

        # The save function does access control checking
        $text =
          Foswiki::Plugins::CommentPlugin::Comment::save( $text, $web, $topic );

        if ( defined $text ) {

            # Don't save anything if nothing to save
            Foswiki::Func::saveTopic( $web, $topic, $meta, $text,
                { ignorepermissions => 1 } );

            $response->header( -status => 200 );
            $response->body("$web.$topic");
        }
    }
    catch Foswiki::AccessControlException with {
        if ( $query->param('comment_ajax') ) {
            $response->header( -status => 404 );
            $response->body(shift);
        }
        else {
            shift->throw();
        }
    }
    catch Error::Simple with {
        my $e = shift;

        # Redirect already requested to clear the endpoint
        if ( $e =~ 'restauth-redirect' ) {
            $query->param( endPoint => '' );
        }
        else {
            $e->throw();
        }
    }
    otherwise {
        if ( $query->param('comment_ajax') ) {
            $response->header( -status => 500 );
            $response->body(shift);
        }
        else {
            shift->throw();
        }
    };
    return undef;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2001-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.
Copyright (C) 2004-2008 Crawford Currie

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
