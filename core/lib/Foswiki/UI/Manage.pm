# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Manage

UI functions for web, topic and user management. The =manage= script is
a dispatcher for a number of admin functions that are gathered
in one place.

=cut

package Foswiki::UI::Manage;

use strict;
use warnings;
use Assert;
use Error qw( :try );

use Foswiki                ();
use Foswiki::UI            ();
use Foswiki::OopsException ();
use Foswiki::Sandbox       ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod manage( $session )

=manage= command handler.
This method is designed to be invoked via the =UI::run= method.

=cut

sub manage {
    my $session = shift;

    my $action = $session->{request}->param('action');

    # Dispatch to action function
    if ( defined $action && $action =~ m/^([a-z]+)$/i ) {
        my $method = 'Foswiki::UI::Manage::_action_' . $1;

        if ( defined &$method ) {
            $session->logger->log( { level => 'info', action => $action } );
            no strict 'refs';
            &$method($session);
        }
        else {
            throw Foswiki::OopsException(
                'attention',
                def    => 'unrecognized_action',
                params => [$action]
            );
        }
    }
    else {
        throw Foswiki::OopsException( 'attention', def => 'missing_action' );
    }
}

sub _action_changePassword {
    my $session = shift;
    require Foswiki::UI::Passwords;
    Foswiki::UI::Passwords::changePasswordAndOrEmail($session);
}

sub _action_resetPassword {
    my $session = shift;
    require Foswiki::UI::Passwords;
    Foswiki::UI::Passwords::resetPassword($session);
}

sub _action_bulkRegister {
    my $session = shift;
    require Foswiki::UI::Register;
    Foswiki::UI::Register::bulkRegister($session);
}

sub _action_deleteUserAccount {
    my $session = shift;

    require Foswiki::UI::Register;
    Foswiki::UI::Register::deleteUser($session);
}

sub _action_addUserToGroup {
    my $session = shift;

    require Foswiki::UI::Register;
    Foswiki::UI::Register::addUserToGroup($session);
}

sub _action_removeUserFromGroup {
    my $session = shift;

    require Foswiki::UI::Register;
    Foswiki::UI::Register::removeUserFromGroup($session);
}

# now using the Extended color keywords (plus transparent) that have been implemented at least since 2005
#TODO: what about rgb(), hsl()&hsla(), html 5, there's also rgba()??
sub _isValidHTMLColor {
    my $c = shift;
    return $c =~ m/^(\#[0-9a-f]{6}|transparent|peru|fuscia|seagreen|olivedrab|
                    honeydew|khaki|indigo|cyan|springgreen|darkorange|orange|
                    mediumturquoise|chocolate|moccasin|antiquewhite|whitesmoke|
                    gray|maroon|deepskyblue|purple|mistyrose|darkslateblue|
                    blanchedalmond|steelblue|darkorchid|darkgoldenrod|linen|
                    turquoise|seashell|peachpuff|darkslategray|
                    lightgoldenrodyellow|aqua|darkolivegreen|salmon|rosybrown|
                    lightcyan|lightblue|plum|oldlace|lemonchiffon|palegoldenrod|
                    teal|lightslategray|red|navajowhite|ghostwhite|sandybrown|
                    forestgreen|mediumpurple|mediumaquamarine|lightpink|
                    gainsboro|darkcyan|mediumvioletred|tan|grey|lightsteelblue|
                    pink|azure|tomato|slateblue|lightyellow|darkslategrey|
                    darkgreen|lavenderblush|lightskyblue|lightgrey|slategrey|
                    lightgreen|dimgray|fuchsia|mediumslateblue|mediumblue|
                    lightsalmon|saddlebrown|mediumorchid|dodgerblue|green|navy|
                    orchid|brown|yellowgreen|yellow|burlywood|lime|mintcream|
                    orangered|palevioletred|chartreuse|lawngreen|wheat|ivory|olive|
                    darkgray|palegreen|slategray|darkmagenta|mediumspringgreen|
                    black|darksalmon|deeppink|goldenrod|midnightblue|lavender|
                    darkgrey|darkseagreen|darkblue|darkturquoise|royalblue|
                    powderblue|blueviolet|cadetblue|thistle|lightseagreen|
                    papayawhip|crimson|silver|greenyellow|skyblue|lightgray|
                    paleturquoise|darkred|white|sienna|cornflowerblue|darkkhaki|
                    violet|coral|lightcoral|beige|indianred|floralwhite|
                    lightslategrey|cornsilk|bisque|hotpink|gold|blue|
                    darkviolet|firebrick|limegreen|snow|magenta|dimgrey|
                    aliceblue|mediumseagreen|aquamarine)/ix;

}

sub _action_createweb {
    my $session = shift;

    my $topicName = $session->{topicName};
    my $webName   = $session->{webName};
    my $query     = $session->{request};
    my $cUID      = $session->{user};

    # Validate and untaint
    my $newWeb = Foswiki::Sandbox::untaint(
        scalar( $query->param('newweb') ),
        \&Foswiki::Sandbox::validateWebName
    );

    unless ($newWeb) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'invalid_web_name',
            params => [ scalar( $query->param('newweb') ) || '' ]
        );
    }

    # For hierarchical webs, check that parent web exists
    my $parent = undef;    # default is root if no parent web
    if ( $newWeb =~ m|^(.*)[./](.*?)$| ) {
        $parent = $1;
    }
    if ($parent) {
        Foswiki::UI::checkWebExists( $session, $parent, 'create' );
    }

    # check permission, user authorized to create web here?
    my $webObject = Foswiki::Meta->new( $session, $parent );
    Foswiki::UI::checkAccess( $session, 'CHANGE', $webObject );

    my $baseWeb = $query->param('baseweb') || '';
    $baseWeb =~ s#\.#/#g;    # normalizeWebTopicName does this

    # Validate the base web name
    $baseWeb = Foswiki::Sandbox::untaint( $baseWeb,
        \&Foswiki::Sandbox::validateWebName );
    unless ( Foswiki::isValidWebName( $baseWeb, 1 ) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'invalid_web_name',
            params => [ scalar( $query->param('baseweb') ) || '' ]
        );
    }

    unless ( $session->webExists($baseWeb) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'base_web_missing',
            params => [$baseWeb]
        );
    }

    if ( $session->webExists($newWeb) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'web_exists',
            params => [$newWeb]
        );
    }

    Foswiki::UI::checkValidationKey($session);

    # Get options from the form (only those options that are already
    # set in the template WebPreferences topic are changed, so we can
    # just copy everything)
    my $me   = $session->{users}->getWikiName($cUID);
    my $opts = {

        # Set permissions such that only the creating user can modify the
        # web preferences
        ALLOWTOPICCHANGE => '%USERSWEB%.' . $me,
        ALLOWTOPICRENAME => '%USERSWEB%.' . $me,
        ALLOWWEBCHANGE   => '%USERSWEB%.' . $me,
        ALLOWWEBRENAME   => '%USERSWEB%.' . $me,
    };
    foreach my $p ( $query->multi_param() ) {
        $opts->{ uc($p) } = $query->param($p);
    }

    my $webBGColor = $opts->{'WEBBGCOLOR'} || '';
    unless ( _isValidHTMLColor($webBGColor) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'invalid_web_color',
            params => [$webBGColor]
        );
    }

    $webObject = Foswiki::Meta->new( $session, $newWeb );
    try {
        $webObject->populateNewWeb( $baseWeb, $opts );
    }
    catch Foswiki::OopsException with {
        shift->throw();    # propagate
    }
    catch Error with {
        $session->logger->log( 'error', shift->{-text} );
        throw Foswiki::OopsException(
            'attention',
            def    => 'web_creation_error',
            params => [
                $newWeb,
                $session->i18n->maketext(
                    'Operation [_1] failed with an internal error',
                    'populateNewWeb'
                )
            ]
        );
    };

    my $newTopic = $query->param('newtopic');

    if ($newTopic) {
        my $nonww = !Foswiki::isTrue( scalar( $query->param('onlywikiname') ) );

        # Validate
        $newTopic = Foswiki::Sandbox::untaint(
            $newTopic,
            sub {
                my $topic = shift;
                return $topic if Foswiki::isValidTopicName( $topic, $nonww );
                return;
            }
        );
        unless ($newTopic) {
            throw Foswiki::OopsException(
                'attention',
                web    => $newWeb,
                topic  => $newTopic,
                def    => 'not_wikiword',
                params => [ scalar( $query->param('newtopic') ) ]
            );
        }
    }

    # everything OK, redirect to last message
    throw Foswiki::OopsException(
        'attention',
        status => 200,
        web    => $newWeb,
        topic  => $newTopic,
        def    => 'created_web'
    );
}

=begin TML

---++ StaticMethod _action_create()

Creates a topic to new topic with name passed in query param 'topic'.
Creates an exception when the topic name is not valid; the topic name does not have to be a
WikiWord if parameter 'onlywikiname' is set to 'off'. Redirects to the edit screen.

Copy an existing topic using:
	<form action="%SCRIPTURL{manage}%/%WEB%/">
	<input type="text" name="topic" class="foswikiInputField" value="%TOPIC%Copy" size="30">
	<input type="hidden" name="action" value="create" />
	<input type="hidden" name="templatetopic" value="%TOPIC%" />
	<input type="hidden" name="notemplateexpansion" value="on" />
	<input type="hidden" name="action_save" value="1" />
	...
	</form>

=cut

sub _action_create {
    my ($session) = @_;

    my $query = $session->{request};

    # distill web and topic from Web.Topic input
    my $newTopic = $query->param('topic');
    ( my $newWeb, $newTopic ) =
      Foswiki::Func::normalizeWebTopicName( $session->{webName}, $newTopic );

    # Validate web name first so it can be used in topic oops.
    $newWeb = Foswiki::Sandbox::untaint(
        $newWeb,
        sub {
            my ($web) = @_;
            unless ( $session->webExists($web) ) {
                throw Foswiki::OopsException(
                    'accessdenied',
                    status => 403,
                    def    => 'no_such_web',
                    web    => $web,
                    params => ['create']
                );
            }
            return $web;
        }
    );

    # Validate topic name
    $newTopic = Foswiki::Sandbox::untaint(
        $newTopic,
        sub {
            my ($topic) = @_;
            unless ($topic) {
                throw Foswiki::OopsException(
                    'attention',
                    web    => $newWeb,
                    topic  => $topic,
                    def    => 'empty_topic_name',
                    params => undef
                );
            }
            unless (
                Foswiki::isValidTopicName(
                    $topic,
                    !Foswiki::isTrue( scalar( $query->param('onlywikiname') ) )
                )
              )
            {
                throw Foswiki::OopsException(
                    'attention',
                    web    => $newWeb,
                    topic  => $topic,
                    def    => 'not_wikiword',
                    params => [$topic]
                );
            }
            return $topic;
        }
    );

    Foswiki::UI::checkValidationKey($session);

    # user must have change access
    my $topicObject = Foswiki::Meta->new( $session, $newWeb, $newTopic );
    Foswiki::UI::checkAccess( $session, 'CHANGE', $topicObject );

    my $oldWeb   = $session->{webName};
    my $oldTopic = $session->{topicName};

    $session->{topicName} = $newTopic;
    $session->{webName}   = $newWeb;

    require Foswiki::UI::Edit;
    Foswiki::UI::Edit::edit($session);
}

sub _action_editSettings {
    my $session = shift;
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $query   = $session->{request};
    my $user    = $session->{user};
    my $users   = $session->{users};

    my $topicObject = Foswiki::Meta->load( $session, $web, $topic );
    Foswiki::UI::checkAccess( $session, 'VIEW',   $topicObject );
    Foswiki::UI::checkAccess( $session, 'CHANGE', $topicObject );

    # Check lease, unless we have been instructed to ignore it
    # or if we are using the 10X's or AUTOINC topic name for
    # dynamic topic names.
    my $breakLock = $query->param('breaklock') || '';
    unless ($breakLock) {
        my $lease = $topicObject->getLease();
        if ($lease) {
            my $who = $users->webDotWikiName( $lease->{user} );

            if ( $who ne $users->webDotWikiName($user) ) {

                # redirect; we are trying to break someone else's lease
                my ( $future, $past );
                my $why = $lease->{message};
                my $def;
                my $t = time();
                require Foswiki::Time;

                if ( $t > $lease->{expires} ) {

                    # The lease has expired, but see if we are still
                    # expected to issue a "less forceful' warning
                    if (   $Foswiki::cfg{LeaseLengthLessForceful} < 0
                        || $t < $lease->{expires} +
                        $Foswiki::cfg{LeaseLengthLessForceful} )
                    {
                        $def = 'lease_old';
                        $past =
                          Foswiki::Time::formatDelta( $t - $lease->{expires},
                            $session->i18n );
                        $future = '';
                    }
                }
                else {

                    # The lease is active
                    $def  = 'lease_active';
                    $past = Foswiki::Time::formatDelta( $t - $lease->{taken},
                        $session->i18n );
                    $future =
                      Foswiki::Time::formatDelta( $lease->{expires} - $t,
                        $session->i18n );
                }
                if ($def) {

                    # use a 'keep' redirect to ensure we pass parameter
                    # values in the query on to the oops script
                    throw Foswiki::OopsException(
                        'leaseconflict',
                        def    => $def,
                        web    => $web,
                        topic  => $topic,
                        keep   => 1,
                        params => [ $who, $past, $future, 'manage' ]
                    );
                }
            }
        }
    }

    my $settings = "";
    $topicObject->setLease( $Foswiki::cfg{LeaseLength} );

    my @fields = $topicObject->find('PREFERENCE');
    foreach my $field (@fields) {
        my $name  = $field->{name};
        my $value = $field->{value};
        $settings .= '   * '
          . (
            ( defined( $field->{type} ) and $field->{type} eq 'Local' )
            ? 'Local'
            : 'Set'
          )
          . ' '
          . $name . ' = '
          . $value . "\n";
    }

    my $tmpl = $session->templates->readTemplate('settings');
    $tmpl = $topicObject->expandMacros($tmpl);
    $tmpl = $topicObject->renderTML($tmpl);

    $tmpl =~ s/%TEXT%/$settings/;

    my $info = $topicObject->getRevisionInfo();
    $tmpl =~ s/%ORIGINALREV%/$info->{version}/g;

    $session->writeCompletePage($tmpl);
}

sub _action_saveSettings {
    my $session = shift;
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $cUID    = $session->{user};
    my $query   = $session->{request};

    if ( defined $query->param('action_cancel')
        && $query->param('action_cancel') ne '' )
    {
        my $topicObject = Foswiki::Meta->new( $session, $web, $topic );

        my $lease = $topicObject->getLease();
        if ( $lease && $lease->{user} eq $session->{user} ) {
            $topicObject->clearLease();
        }
    }
    elsif ( defined $query->param('action_save')
        && $query->param('action_save') ne '' )
    {

        # set up editing session
        require Foswiki::Meta;
        my $newTopicObject = Foswiki::Meta->load( $session, $web, $topic );

        Foswiki::UI::checkAccess( $session, 'VIEW',   $newTopicObject );
        Foswiki::UI::checkAccess( $session, 'CHANGE', $newTopicObject );
        Foswiki::UI::checkValidationKey($session);

        my $settings    = $query->param('text');
        my $originalrev = $query->param('originalrev');

        $newTopicObject->remove('PREFERENCE');    # delete previous settings
            # Note: $Foswiki::regex{setVarRegex} cannot be used as it requires
            # use in code that parses multiline settings line by line.
        $settings =~
s(^(?:\t|   )+\*\s+(Set|Local)\s+($Foswiki::regex{tagNameRegex})\s*=\s*?(.*)$)
            (_parsePreferenceValue($newTopicObject, $1, $2, $3))mge;

        my $saveOpts = {};
        $saveOpts->{minor}            = 1;    # don't notify
        $saveOpts->{forcenewrevision} = 1;    # always new revision

        # Merge changes in meta data
        if ($originalrev) {
            my $info = $newTopicObject->getRevisionInfo();

            # If the last save was by me, don't merge
            if (   $info->{version} ne $originalrev
                && $info->{author} ne $session->{user} )
            {
                my $currTopicObject =
                  Foswiki::Meta->load( $session, $web, $topic );
                $newTopicObject->merge($currTopicObject);
            }
        }

        try {
            $newTopicObject->save( minor => 1, forcenewrevision => 1 );
        }
        catch Foswiki::OopsException with {
            shift->throw();    # propagate
        }
        catch Error with {
            $session->logger->log( 'error', shift->{-text} );
            throw Foswiki::OopsException(
                'attention',
                def    => 'save_error',
                web    => $web,
                topic  => $topic,
                params => [
                    $session->i18n->maketext(
                        'Operation [_1] failed with an internal error', 'save'
                    )
                ],
            );
        };
    }
    else {
        throw Foswiki::OopsException(
            'attention',
            def    => 'invalid_field',
            web    => $web,
            topic  => $topic,
            params => ['action_save or action_cancel']
        );
    }

    $session->redirect( $session->redirectto("$web.$topic") );
}

sub _parsePreferenceValue {
    my ( $topicObject, $type, $name, $value ) = @_;

    $value =~ s/^\s*(.*?)\s*$/$1/ge;

    my $args = {
        name  => $name,
        title => $name,
        value => $value,
        type  => $type
    };
    $topicObject->putKeyed( 'PREFERENCE', $args );
    return '';
}

sub _action_restoreRevision {
    my ($session) = @_;
    my $query = $session->{request};
    my ( $web, $topic ) =
      $session->normalizeWebTopicName( $session->{webName},
        $session->{topicName} );

    # read the current topic
    my $meta = Foswiki::Meta->load( $session, $web, $topic );

    if ( !$meta->haveAccess('CHANGE') ) {

        # user has no permission to change the topic
        throw Foswiki::OopsException(
            'accessdenied',
            def    => 'topic_access',
            web    => $web,
            topic  => $topic,
            params => [ 'change', 'denied' ]
        );
    }

    # read the old topic
    my $rev          = $query->param('rev');
    my $requestedRev = Foswiki::Store::cleanUpRevID($rev);

    unless ($requestedRev) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'restore_invalid_rev',
            params => [ $rev, $meta->getLoadedRev() ]
        );
    }

    my $oldmeta = Foswiki::Meta->load( $session, $web, $topic, $requestedRev );

#print STDERR "REVS (".$meta->getLoadedRev().") (".$oldmeta->getLoadedRev().") ($requestedRev) \n";

    if (   !defined $oldmeta->getLoadedRev()
        || $meta->getLoadedRev() == $oldmeta->getLoadedRev()
        || $oldmeta->getLoadedRev() != $rev )
    {
        throw Foswiki::OopsException(
            'attention',
            def    => 'restore_invalid_rev',
            params => [ $rev, $meta->getLoadedRev() ]
        );
    }

    Foswiki::UI::checkValidationKey($session);

    foreach my $k ( sort keys %$meta ) {
        next if $k =~ m/^_/;
        next if $k eq 'TOPICINFO';         # Don't revert topicinfo
        next if $k eq 'FILEATTACHMENT';    # Don't revert attachments
        $meta->remove($k) unless $oldmeta->{$k};
    }

    foreach my $k ( sort keys %$oldmeta ) {
        next if $k =~ m/^_/;
        next if $k eq 'TOPICINFO';         # Don't revert topicinfo
        next if $k eq 'FILEATTACHMENT';    # Don't revert attachments
        $meta->copyFrom( $oldmeta, $k );
    }

    $meta->text( $oldmeta->text() );       # copy the old text

    $meta->save( ( forcenewrevision => 1 ) );

    $session->{cgiQuery}->delete('action');

    $session->redirect( $session->redirectto("$web.$topic") );

    #require Foswiki::UI::Edit;
    #Foswiki::UI::Edit::edit($session);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
