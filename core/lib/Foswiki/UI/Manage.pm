# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Manage

UI functions for web, topic and user management. The =manage= script is
a dispatcher for a number of admin functions that are gathered
in one place.

=cut

package Foswiki::UI::Manage;

use strict;
use Assert;
use Error qw( :try );

require Foswiki;
require Foswiki::UI;
require Foswiki::OopsException;
require Foswiki::Sandbox;

=begin TML

---++ StaticMethod manage( $session )

=manage= command handler.
This method is designed to be invoked via the =UI::run= method.

=cut

sub manage {
    my $session = shift;

    my $action = $session->{request}->param('action');

    # Dispatch to action function
    if ( defined $action ) {
        my $method = 'Foswiki::UI::Manage::_action_' . $action;

        if ( defined &$method ) {
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
    require Foswiki::UI::Register;
    Foswiki::UI::checkValidationKey( $session );
    Foswiki::UI::Register::changePassword($session);
}

sub _action_resetPassword {
    my $session = shift;
    require Foswiki::UI::Register;
    Foswiki::UI::checkValidationKey( $session );
    Foswiki::UI::Register::resetPassword($session);
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

sub _isValidHTMLColor {
    my $c = shift;
    return $c =~
m/^(#[0-9a-f]{6}|black|silver|gray|white|maroon|red|purple|fuchsia|green|lime|olive|yellow|navy|blue|teal|aqua)/i;

}

sub _action_createweb {
    my $session = shift;

    my $topicName = $session->{topicName};
    my $webName   = $session->{webName};
    my $query     = $session->{request};
    my $cUID      = $session->{user};

    my $newWeb = $query->param('newweb');

    # Validate and untaint
    $newWeb = Foswiki::Sandbox::untaint(
        $newWeb,
        sub {
            unless ($newWeb) {
                throw Foswiki::OopsException( 'attention',
                    def => 'web_missing' );
            }
            unless ( Foswiki::isValidWebName( $newWeb, 1 ) ) {
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'invalid_web_name',
                    params => [$newWeb]
                );
            }
            return $newWeb;
        }
    );

    # check permission, user authorized to create web here?
    my $parent = undef;    # default is root if no parent web
    if ( $newWeb =~ m|^(.*)[./](.*?)$| ) {
        $parent = $1;
    }
    Foswiki::UI::checkAccess( $session, $parent, undef, 'CHANGE',
        $session->{user} );

    my $baseWeb = $query->param('baseweb') || '';

    # Validate the base web name
    $baseWeb = Foswiki::Sandbox::untaint(
        $baseWeb,
        sub {
            my $web = shift;
            unless ( $session->{store}->webExists($baseWeb) ) {
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'base_web_missing',
                    params => [$baseWeb]
                );
            }
            return $web;
        }
    );

    if ( $session->{store}->webExists($newWeb) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'web_exists',
            params => [$newWeb]
        );
    }

    my $webBGColor = $query->param('WEBBGCOLOR') || '';
    unless ( _isValidHTMLColor($webBGColor) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'invalid_web_color',
            params => [$webBGColor]
        );
    }

    # Get options from the form (only those options that are already
    # set in the template WebPreferences topic are changed, so we can
    # just copy everything)
    my $me = $session->{users}->getWikiName($cUID);
    my $opts = {

        # Set permissions such that only the creating user can modify the
        # web preferences
        ALLOWTOPICCHANGE => $me,
        ALLOWTOPICRENAME => 'nobody',
        ALLOWWEBCHANGE => $me,
        ALLOWWEBRENAME => $me,
    };
    foreach my $p ( $query->param() ) {
        $opts->{ uc($p) } = $query->param($p);
    }

    Foswiki::UI::checkValidationKey( $session );

    my $err = $session->{store}->createWeb( $cUID, $newWeb, $baseWeb, $opts );
    if ($err) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'web_creation_error',
            params => [ $newWeb, $err ]
        );
    }

    my $newTopic = $query->param('newtopic');

    if ($newTopic) {

        # Purify the new topic name
        $newTopic = _safeTopicName($newTopic);

        # Validate
        $newTopic = Foswiki::Sandbox::untaint(
            $newTopic,
            sub {
                my ( $topic, $nonww ) = @_;
                if ( !Foswiki::isValidTopicName( $topic, $nonww ) ) {
                    throw Foswiki::OopsException(
                        'attention',
                        web    => $newWeb,
                        topic  => $newTopic,
                        def    => 'not_wikiword',
                        params => [$topic]
                    );
                }
                return $topic;
            },
            Foswiki::isTrue( $query->param('nonwikiword') )
        );
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

---++ StaticMethod rename( $session )

=rename= command handler.
This method is designed to be
invoked via the =UI::run= method.
Rename the given topic. Details of the new topic name are passed in CGI
parameters:

| =skin= | skin(s) to use |
| =newweb= | new web name |
| =newtopic= | new topic name |
| =breaklock= | |
| =attachment= | |
| =confirm= | if defined, requires a second level of confirmation |
| =currentwebonly= | if defined, searches current web only for links to this topic |
| =nonwikiword= | if defined, a non-wikiword is acceptable for the new topic name |
| =redirectto= | If the rename process is successful, rename will redirect to this topic or URL. The parameter value can be a =TopicName=, a =Web.TopicName=, or a URL.%BR% __Note:__ Redirect to a URL only works if it is enabled in =configure= (Miscellaneous ={AllowRedirectUrl}=). |

=cut

sub rename {
    my $session = shift;

    my $oldTopic = $session->{topicName};
    my $oldWeb   = $session->{webName};
    my $query    = $session->{request};
    my $action   = $query->param('action') || '';

    if ( $action eq 'renameweb' ) {
        _renameweb($session);
        return;
    }

    my $newTopic = $query->param('newtopic') || '';

    my $newWeb = $query->param('newweb') || '';

    # Validate the new web name
    $newWeb = Foswiki::Sandbox::untaint(
        $newWeb,
        sub {
            my ($web) = @_;
            unless ( !$web || Foswiki::isValidWebName( $web, 1 ) ) {
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'invalid_web_name',
                    params => [$web]
                );
            }
            return $web;
        }
    );

    my $lockFailure = '';
    my $breakLock   = $query->param('breaklock');

    my $confirm = $query->param('confirm');
    my $store   = $session->{store};

    Foswiki::UI::checkWebExists( $session, $oldWeb, $oldTopic, 'rename' );

    unless ( $session->{store}->topicExists( $oldWeb, $oldTopic ) ) {

        # Item3270: check for the same name starting with a lower case letter.
        unless ( $session->{store}->topicExists( $oldWeb, lcfirst($oldTopic) ) )
        {
            throw Foswiki::OopsException(
                'accessdenied',
                status => 403,
                def    => 'no_such_topic_rename',
                web    => $oldWeb,
                topic  => $oldTopic
            );
        }

        # Untaint is required is use locale is in force
        $oldTopic = Foswiki::Sandbox::untaintUnchecked( lcfirst($oldTopic) );
    }

    if ($newTopic) {

        # Purify the new topic name
        $newTopic = _safeTopicName($newTopic);

        # Validate
        $newTopic = Foswiki::Sandbox::untaint(
            $newTopic,
            sub {
                my ( $topic, $nonww ) = @_;
                if ( !Foswiki::isValidTopicName( $topic, $nonww ) ) {
                    throw Foswiki::OopsException(
                        'attention',
                        web    => $oldWeb,
                        topic  => $oldTopic,
                        def    => 'not_wikiword',
                        params => [$topic]
                    );
                }
                return $topic;
            },
            Foswiki::isTrue( $query->param('nonwikiword') )
        );
    }

    my $attachment = $query->param('attachment');

    if ($attachment) {

        # Does old attachment exist?
        # Attachment exists, validated
        $attachment = Foswiki::Sandbox::untaint(
            $attachment,
            sub {
                my ($att) = @_;
                if ( !$store->attachmentExists( $oldWeb, $oldTopic, $att ) ) {
                    my $tmplname = $query->param('template') || '';
                    throw Foswiki::OopsException(
                        'attention',
                        web   => $oldWeb,
                        topic => $oldTopic,
                        def   => ( $tmplname eq 'deleteattachment' )
                        ? 'delete_err'
                        : 'move_err',
                        params => [
                            $newWeb,
                            $newTopic,
                            $attachment,
                            $session->i18n->maketext(
                                'Attachment does not exist')
                        ]
                    );
                }
                return $att;
            }
        );

        if ( $newWeb && $newTopic ) {
            Foswiki::UI::checkTopicExists( $session, $newWeb, $newTopic,
                'rename' );

            # does new attachment already exist?
            if ( $store->attachmentExists( $newWeb, $newTopic, $attachment ) ) {
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'move_err',
                    web    => $oldWeb,
                    topic  => $oldTopic,
                    params => [
                        $newWeb,
                        $newTopic,
                        $attachment,
                        $session->i18n->maketext(
                            'Attachment already exists in new topic')
                    ]
                );
            }
        }    # else fall through to new topic screen
    }
    elsif ($newTopic) {
        ( $newWeb, $newTopic ) =
          $session->normalizeWebTopicName( $newWeb, $newTopic );

        Foswiki::UI::checkWebExists( $session, $newWeb, $newTopic, 'rename' );
        if ( $store->topicExists( $newWeb, $newTopic ) ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'rename_topic_exists',
                web    => $oldWeb,
                topic  => $oldTopic,
                params => [ $newWeb, $newTopic ]
            );
        }
    }

    Foswiki::UI::checkAccess( $session, $oldWeb, $oldTopic, 'RENAME',
        $session->{user} );

    # Has user selected new name yet?
    if ( !$newTopic || $confirm ) {

        # Must be able to view the source to rename it
        Foswiki::UI::checkAccess( $session, $oldWeb, $oldTopic, 'VIEW',
            $session->{user} );
        _newTopicScreen(
            $session,  $oldWeb,     $oldTopic, $newWeb,
            $newTopic, $attachment, $confirm
        );
        return;
    }

    return undef if ($query && $query->method() &&
                       uc($query->method()) ne 'POST');

    Foswiki::UI::checkValidationKey( $session );

    # Update references in referring pages - not applicable to attachments.
    my $refs;
    unless ($attachment) {
        $refs =
          _getReferringTopicsListFromURL( $session, $oldWeb, $oldTopic, $newWeb,
            $newTopic );
    }
    move( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $attachment,
        $refs );

    my $new_url;
    if (   $newWeb eq $Foswiki::cfg{TrashWebName}
        && $oldWeb ne $Foswiki::cfg{TrashWebName} )
    {

        # deleting something

        if ($attachment) {

            # go back to old topic after deleting an attachment
            $new_url = $session->getScriptUrl( 0, 'view', $oldWeb, $oldTopic );

        }
        else {

            # redirect to parent topic, if set
            my ( $meta, $text ) =
              $store->readTopic( undef, $newWeb, $newTopic, undef );
            my $parent = $meta->get('TOPICPARENT');
            my ( $parentWeb, $parentTopic );
            if ( $parent && defined $parent->{name} ) {
                ( $parentWeb, $parentTopic ) =
                  $session->normalizeWebTopicName( '', $parent->{name} );
            }
            if (   $parentTopic
                && !( $parentWeb eq $oldTopic && $parentTopic eq $oldTopic )
                && $store->topicExists( $parentWeb, $parentTopic ) )
            {
                $new_url =
                  $session->getScriptUrl( 0, 'view', $parentWeb, $parentTopic );
            }
            else {
                $new_url =
                  $session->getScriptUrl( 0, 'view', $oldWeb,
                    $Foswiki::cfg{HomeTopicName} );
            }
        }
    }
    else {

        #redirect to new topic
        $new_url = $session->getScriptUrl( 0, 'view', $newWeb, $newTopic );
    }

    # follow redirectto
    $session->redirect( $session->redirectto($new_url) );
}

=begin TML

---++ StaticMethod _safeTopicName( $topic ) -> $topic

Filter out dangerous characters . and / may cause issues with pathnames.

Note that the resut may be tainted.

=cut

sub _safeTopicName {
    my ($topic) = @_;

    $topic =~ s/\s//go;
    $topic = ucfirst $topic;    # Item3270
    $topic =~ s![./]!_!g;
    $topic =~ s/($Foswiki::cfg{NameFilter})//go;

    return $topic;
}

=begin TML

---++ StaticMethod _action_create()

Creates a topic to new topic with name passed in query param 'topic'.
Creates an exception when the topic name is not valid; the topic name does not have to be a WikiWord if parameter 'nonwikiword' is set to 'on'.
Redirects to the edit screen.

Copy an existing topic using:
	<form action="%SCRIPTURL{manage}%/%WEB%/">
	<input type="text" name="topic" class="foswikiInputField" value="%TOPIC%Copy" size="30">
	<input type="hidden" name="action" value="create" />
	<input type="hidden" name="templatetopic" value="%TOPIC%" />
	<input type="hidden" name="action_save" value="1" />
	...
	</form>

=cut

sub _action_create {
    my ($session) = @_;

    my $query = $session->{request};

    # distill web and topic from Web.Topic input
    my ( $newWeb, $newTopic ) =
      Foswiki::Func::normalizeWebTopicName( $session->{webName},
        $query->param('topic') );

    # Validate topic name
    $newTopic = Foswiki::Sandbox::untaint(
        $newTopic,
        sub {
            my ($topic) = @_;
            unless ($topic) {
                throw Foswiki::OopsException(
                    'attention',
                    web    => $newWeb,
                    topic  => $newTopic,
                    def    => 'empty_topic_name',
                    params => undef
                );
            }
            unless (
                Foswiki::isValidTopicName(
                    $topic, Foswiki::isTrue( $query->param('nonwikiword') )
                )
              )
            {
                throw Foswiki::OopsException(
                    'attention',
                    web    => $newWeb,
                    topic  => $newTopic,
                    def    => 'not_wikiword',
                    params => [$newTopic]
                );
            }
            return $topic;
        }
    );

    # Validate web name
    $newWeb = Foswiki::Sandbox::untaint(
        $newWeb,
        sub {
            my ($web) = @_;
            unless ( $session->{store}->webExists($web) ) {
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

    # user must have change access
    Foswiki::UI::checkAccess( $session, $newWeb, $newTopic, 'CHANGE',
        $session->{user} );

    my $oldWeb   = $session->{webName};
    my $oldTopic = $session->{topicName};

    $session->{topicName} = $newTopic;
    $session->{webName}   = $newWeb;

    require Foswiki::UI::Edit;
    Foswiki::UI::Edit::edit($session);
}

#| =skin= | skin(s) to use |
#| =newsubweb= | new web name |
#| =newparentweb= | new parent web name |
#| =confirm= | if defined, requires a second level of confirmation.  Currently accepted values are "getlock", "continue", and "cancel" |
sub _renameweb {
    my $session = shift;

    my $oldWeb = $session->{webName};
    my $query  = $session->{request};
    my $cUID   = $session->{user};

    # If the user is not allowed to rename anything in the current
    # web - stop here
    Foswiki::UI::checkAccess( $session, $oldWeb, undef, 'RENAME',
        $session->{user} );

    my $newParentWeb = $query->param('newparentweb') || '';

    # Validate
    if ( $newParentWeb ne "" ) {
        $newParentWeb = Foswiki::Sandbox::untaint(
            $newParentWeb,
            sub {
                my $web = shift;
                return $web if Foswiki::isValidWebName( $web, 1 );
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'invalid_web_name',
                    params => [$web]
                );
            }
        );
    }
    my $newSubWeb = $query->param('newsubweb') || '';

    # Validate
    if ( $newSubWeb ne "" ) {
        $newSubWeb = Foswiki::Sandbox::untaint(
            $newSubWeb,
            sub {
                my $web = shift;
                return $web if Foswiki::isValidWebName( $web, 1 );
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'invalid_web_name',
                    params => [$web]
                );
            }
        );
    }
    my $newWeb;
    if ($newSubWeb) {
        if ($newParentWeb) {
            $newWeb = $newParentWeb . '/' . $newSubWeb;
        }
        else {
            $newWeb = $newSubWeb;
        }
    }

    my @tmp = split( /[\/\.]/, $oldWeb );
    pop(@tmp);
    my $oldParentWeb = join( '/', @tmp );

   # If the user is not allowed to rename anything in the parent web - stop here
   # This also ensures we check root webs for ALLOWROOTRENAME and DENYROOTRENAME
    Foswiki::UI::checkAccess( $session, $oldParentWeb || undef,
        undef, 'RENAME', $session->{user} );

# If old web is a root web then also stop if ALLOW/DENYROOTCHANGE prevents access
    if ( !$oldParentWeb ) {
        Foswiki::UI::checkAccess( $session, $oldParentWeb || undef,
            undef, 'CHANGE', $session->{user} );
    }

    my $newTopic;
    my $lockFailure = '';
    my $breakLock   = $query->param('breaklock');
    my $confirm     = $query->param('confirm') || '';
    my $store       = $session->{store};

    Foswiki::UI::checkWebExists( $session, $oldWeb,
        $Foswiki::cfg{WebPrefsTopicName}, 'rename' );

    if ($newWeb) {
        if ($newParentWeb) {
            Foswiki::UI::checkWebExists( $session, $newParentWeb,
                $Foswiki::cfg{WebPrefsTopicName}, 'rename' );
        }

        if ( $store->webExists($newWeb) ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'rename_web_exists',
                web    => $oldWeb,
                topic  => $Foswiki::cfg{WebPrefsTopicName},
                params => [ $newWeb, $Foswiki::cfg{WebPrefsTopicName} ]
            );
        }

        # Check if we have change permission in the new parent
        Foswiki::UI::checkAccess( $session, $newParentWeb || undef,
            undef, 'CHANGE', $session->{user} );
    }

    if ( !$newWeb || $confirm ) {
        my %refs;
        my $totalReferralAccess = 1;
        my $totalWebAccess      = 1;
        my $modifyingLockedTopics;
        my $movingLockedTopics;
        my %webTopicInfo;
        my @webList;

        # get a topic list for all the topics referring to this web,
        # and build up a hash containing permissions and lock info.
        my $refs0 = getReferringTopics( $session, $oldWeb, undef, 0 );
        my $refs1 = getReferringTopics( $session, $oldWeb, undef, 1 );
        %refs = ( %$refs0, %$refs1 );

        $webTopicInfo{referring}{refs0} = $refs0;
        $webTopicInfo{referring}{refs1} = $refs1;

        my $lease_ref;
        foreach my $ref ( keys %refs ) {
            if ( defined($ref) && $ref ne "" ) {
                $ref =~ s/\./\//go;
                my (@path) = split( /\//, $ref );
                my $webTopic = pop(@path);
                my $webIter = join( '/', @path );

                if ( $confirm eq 'getlock' ) {
                    $store->setLease( $webIter, $webTopic, $cUID,
                        $Foswiki::cfg{LeaseLength} );
                    $lease_ref = $store->getLease( $webIter, $webTopic );
                }
                elsif ( $confirm eq 'cancel' ) {
                    $lease_ref = $store->getLease( $webIter, $webTopic );
                    if ( $lease_ref->{user} eq $cUID ) {
                        $store->clearLease( $webIter, $webTopic );
                    }
                }
                my $wit = $webIter . '/' . $webTopic;
                $webTopicInfo{modify}{$wit}{leaseuser} = $lease_ref->{user};
                $webTopicInfo{modify}{$wit}{leasetime} = $lease_ref->{taken};

                $modifyingLockedTopics++
                  if ( defined( $webTopicInfo{modify}{$ref}{leaseuser} )
                    && $webTopicInfo{modify}{$ref}{leaseuser} ne $cUID );
                $webTopicInfo{modify}{$ref}{summary} = $refs{$ref};
                $webTopicInfo{modify}{$ref}{access} =
                  $session->security->checkAccessPermission( 'CHANGE', $cUID,
                    undef, undef, $webTopic, $webIter );
                if ( !$webTopicInfo{modify}{$ref}{access} ) {
                    $webTopicInfo{modify}{$ref}{accessReason} =
                      $session->security->getReason();
                }
                $totalReferralAccess = 0
                  unless $webTopicInfo{modify}{$ref}{access};
            }
        }

        # get a topic list for this web and all its subwebs, and build
        # up a hash containing permissions and lock info.
        (@webList) = $store->getListOfWebs( 'public', $oldWeb );
        unshift( @webList, $oldWeb );
        foreach my $webIter (@webList) {
            my @webTopicList = $store->getTopicNames($webIter);
            foreach my $webTopic (@webTopicList) {
                if ( $confirm eq 'getlock' ) {
                    $store->setLease( $webIter, $webTopic, $cUID,
                        $Foswiki::cfg{LeaseLength} );
                    $lease_ref = $store->getLease( $webIter, $webTopic );
                }
                elsif ( $confirm eq 'cancel' ) {
                    $lease_ref = $store->getLease( $webIter, $webTopic );
                    if ( $lease_ref->{user} eq $cUID ) {
                        $store->clearLease( $webIter, $webTopic );
                    }
                }
                my $wit = $webIter . '/' . $webTopic;
                $webTopicInfo{move}{$wit}{leaseuser} = $lease_ref->{user};
                $webTopicInfo{move}{$wit}{leasetime} = $lease_ref->{taken};

                $movingLockedTopics++
                  if ( defined( $webTopicInfo{move}{$wit}{leaseuser} )
                    && $webTopicInfo{move}{$wit}{leaseuser} ne $cUID );
                $webTopicInfo{move}{$wit}{access} =
                  $session->security->checkAccessPermission( 'RENAME', $cUID,
                    undef, undef, $webTopic, $webIter );
                $webTopicInfo{move}{$wit}{accessReason} =
                  $session->security->getReason();
                $totalWebAccess =
                  ( $totalWebAccess & $webTopicInfo{move}{$wit}{access} );
            }
        }

        if (   !$totalReferralAccess
            || !$totalWebAccess
            || $movingLockedTopics
            || $modifyingLockedTopics )
        {

            # check if the user can rename all the topics in this web.
            push(
                @{ $webTopicInfo{movedenied} },
                grep { !$webTopicInfo{move}{$_}{access} }
                  sort keys %{ $webTopicInfo{move} }
            );

            # check if there are any locked topics in this web or
            # its subwebs.
            push(
                @{ $webTopicInfo{movelocked} },
                grep {
                    defined( $webTopicInfo{move}{$_}{leaseuser} )
                      && $webTopicInfo{move}{$_}{leaseuser} ne $cUID
                  }
                  sort keys %{ $webTopicInfo{move} }
            );

            # Next, build up a list of all the referrers which the
            # user doesn't have permission to change.
            push(
                @{ $webTopicInfo{modifydenied} },
                grep { !$webTopicInfo{modify}{$_}{access} }
                  sort keys %{ $webTopicInfo{modify} }
            );

            # Next, build up a list of all the referrers which are
            # currently locked.
            push(
                @{ $webTopicInfo{modifylocked} },
                grep {
                    defined( $webTopicInfo{modify}{$_}{leaseuser} )
                      && $webTopicInfo{modify}{$_}{leaseuser} ne $cUID
                  }
                  sort keys %{ $webTopicInfo{modify} }
            );

            unless ($confirm) {
                my $nocontinue = '';
                if (   @{ $webTopicInfo{movedenied} }
                    || @{ $webTopicInfo{movelocked} } )
                {
                    $nocontinue = 'style="display:none;"';
                }
                my $mvd = join( ' ', @{ $webTopicInfo{movedenied} } )
                  || ( $session->i18n->maketext('(none)') );
                $mvd = substr( $mvd, 0, 300 ) . '... (more)'
                  if ( length($mvd) > 300 );
                my $mvl = join( ' ', @{ $webTopicInfo{movelocked} } )
                  || ( $session->i18n->maketext('(none)') );
                $mvl = substr( $mvl, 0, 300 ) . '... (more)'
                  if ( length($mvl) > 300 );
                my $mdd = join( ' ', @{ $webTopicInfo{modifydenied} } )
                  || ( $session->i18n->maketext('(none)') );
                $mdd = substr( $mdd, 0, 300 ) . '... (more)'
                  if ( length($mdd) > 300 );
                my $mdl = join( ' ', @{ $webTopicInfo{modifylocked} } )
                  || ( $session->i18n->maketext('(none)') );
                $mdl = substr( $mdl, 0, 300 ) . '... (more)'
                  if ( length($mdl) > 300 );
                throw Foswiki::OopsException(
                    'attention',
                    web    => $oldWeb,
                    topic  => '',
                    def    => 'rename_web_prerequisites',
                    params => [ $mvd, $mvl, $mdd, $mdl, $nocontinue ]
                );
            }
        }

        if ( $confirm eq 'cancel' ) {

            # redirect to original web
            my $viewURL =
              $session->getScriptUrl( 0, 'view', $oldWeb,
                $Foswiki::cfg{HomeTopicName} );
            $session->redirect($viewURL);
        }
        elsif (
            $confirm ne 'getlock'
            || (   $confirm eq 'getlock'
                && $modifyingLockedTopics
                && $movingLockedTopics )
          )
        {

            # Has user selected new name yet?
            _newWebScreen( $session, $oldWeb, $newWeb, $confirm,
                \%webTopicInfo );
            return;
        }
    }

    return undef if ($query && $query->method() && $query->method() ne 'POST');

    Foswiki::UI::checkValidationKey( $session );

    # Update references in referring pages
    my $refs =
      _getReferringTopicsListFromURL( $session, $oldWeb,
        $Foswiki::cfg{HomeTopicName},
        $newWeb, $Foswiki::cfg{HomeTopicName} );

    # Now, we can move the web.
    _moveWeb( $session, $oldWeb, $newWeb, $refs );

    # now remove lease on all topics inside $newWeb.
    my (@webList) = $store->getListOfWebs( 'public', $newWeb );
    unshift( @webList, $newWeb );
    foreach my $webIter (@webList) {
        my @webTopicList = $store->getTopicNames($webIter);
        foreach my $webTopic (@webTopicList) {
            $store->clearLease( $webIter, $webTopic );
        }
    }

    # also remove lease on all referring topics
    foreach my $ref (@$refs) {
        $ref =~ s/\./\//go;
        my (@path) = split( /\//, $ref );
        my $webTopic =
          Foswiki::Sandbox::untaint( pop(@path),
            \&Foswiki::Sandbox::validateWebName );
        my $webIter = Foswiki::Sandbox::untaint( join( "/", @path ),
            \&Foswiki::Sandbox::validateTopicName );
        $store->clearLease( $webIter, $webTopic );
    }

    my $new_url = '';
    if (   $newWeb =~ /^$Foswiki::cfg{TrashWebName}\b/
        && $oldWeb !~ /^$Foswiki::cfg{TrashWebName}\b/ )
    {

        # redirect to parent
        if ($oldParentWeb) {
            $new_url =
              $session->getScriptUrl( 0, 'view', $oldParentWeb,
                $Foswiki::cfg{HomeTopicName} );
        }
        else {
            $new_url = $session->getScriptUrl(
                0, 'view',
                $Foswiki::cfg{UsersWebName},
                $Foswiki::cfg{HomeTopicName}
            );
        }
    }
    else {

        # redirect to new web
        $new_url =
          $session->getScriptUrl( 0, 'view', $newWeb,
            $Foswiki::cfg{HomeTopicName} );
    }

    $session->redirect($new_url);
}

=begin TML

---++ StaticMethod move($session, $oldWeb, $oldTopic, $newWeb, $newTopic, $attachment, \@refs )

Move the given topic, or an attachment in the topic, correcting refs to the topic in the topic itself, and
in the list of topics (specified as web.topic pairs) in the \@refs array.

   * =$session= - reference to session object
   * =$oldWeb= - name of old web - must be untained
   * =$oldTopic= - name of old topic - must be untained
   * =$newWeb= - name of new web - must be untained
   * =$newTopic= - name of new topic - must be untained
   * =$attachment= - name of the attachment to move (from oldtopic to newtopic) (undef to move the topic) - must be untaineted
   * =\@refs= - array of webg.topics that must have refs to this topic converted
Will throw Foswiki::OopsException or Foswiki::AccessControlException on an error.

=cut

sub move {
    my ( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $attachment, $refs )
      = @_;
    my $store = $session->{store};

    if ($attachment) {
        try {
            $store->moveAttachment( $oldWeb, $oldTopic, $attachment, $newWeb,
                $newTopic, $attachment, $session->{user} );
        }
        catch Error::Simple with {
            throw Foswiki::OopsException(
                'attention',
                web    => $oldWeb,
                topic  => $oldTopic,
                def    => 'move_err',
                params => [ $newWeb, $newTopic, $attachment, shift->{-text} ]
            );
        };
        return;
    }

    try {
        $store->moveTopic( $oldWeb, $oldTopic, $newWeb, $newTopic,
            $session->{user} );
    }
    catch Error::Simple with {
        throw Foswiki::OopsException(
            'attention',
            web    => $oldWeb,
            topic  => $oldTopic,
            def    => 'rename_err',
            params => [ shift->{-text}, $newWeb, $newTopic ]
        );
    };

    my ( $meta, $text ) = $store->readTopic( undef, $newWeb, $newTopic );

    if ( $oldWeb ne $newWeb ) {

        # If the web changed, replace local refs to the topics
        # in $oldWeb with full $oldWeb.topic references so that
        # they still work.
        $session->renderer->replaceWebInternalReferences( \$text, $meta,
            $oldWeb, $oldTopic, $newWeb, $newTopic );
    }

    # Ok, now let's replace all self-referential links:
    my $options = {
        oldWeb    => $newWeb,
        oldTopic  => $oldTopic,
        newTopic  => $newTopic,
        newWeb    => $newWeb,
        inWeb     => $newWeb,
        fullPaths => 0,
    };
    require Foswiki::Render;
    $text = $session->renderer->forEachLine( $text,
        \&Foswiki::Render::replaceTopicReferences, $options );

    $store->saveTopic( $session->{user}, $newWeb, $newTopic, $text, $meta,
        { minor => 1, comment => 'rename' } );

    # update referrers - but _not_ including the moved topic
    _updateReferringTopics( $session, $oldWeb, $oldTopic, $newWeb, $newTopic,
        $refs );
}

# Display screen so user can decide on new web and topic.
sub _newTopicScreen {
    my (
        $session,  $oldWeb,     $oldTopic, $newWeb,
        $newTopic, $attachment, $confirm
    ) = @_;

    my $query          = $session->{request};
    my $tmplname       = $query->param('template') || '';
    my $tmpl           = '';
    my $skin           = $session->getSkin();
    my $currentWebOnly = $query->param('currentwebonly') || '';

    $newTopic = $oldTopic unless ($newTopic);
    $newWeb   = $oldWeb   unless ($newWeb);

    if ($attachment) {
        $tmpl =
          $session->templates->readTemplate( $tmplname || 'moveattachment',
            $skin );
        $tmpl =~ s/%FILENAME%/$attachment/go;
    }
    elsif ($confirm) {
        $tmpl = $session->templates->readTemplate( 'renameconfirm', $skin );
    }
    elsif ($newWeb eq $Foswiki::cfg{TrashWebName}
        && $oldWeb ne $Foswiki::cfg{TrashWebName} )
    {
        $tmpl = $session->templates->readTemplate( 'renamedelete', $skin );
    }
    else {
        $tmpl = $session->templates->readTemplate( 'rename', $skin );
    }

    if ( !$attachment && $newWeb eq $Foswiki::cfg{TrashWebName} ) {

        # Trashing a topic; look for a non-conflicting name
        $newTopic = $oldWeb . $newTopic;
        my $n    = 1;
        my $base = $newTopic;
        while ( $session->{store}->topicExists( $newWeb, $newTopic ) ) {
            $newTopic = $base . $n;
            $n++;
        }
    }

    $tmpl =~ s/%NEW_WEB%/$newWeb/go;
    $tmpl =~ s/%NEW_TOPIC%/$newTopic/go;

    if ( !$attachment ) {
        my $refs;
        my $search = '';
        if ($currentWebOnly) {
            $search = $session->i18n->maketext('(skipped)');
        }
        else {
            $refs = getReferringTopics( $session, $oldWeb, $oldTopic, 1 );
            foreach my $entry ( sort keys %$refs ) {
                $search .= CGI::Tr(
                    CGI::td(
                        { class => 'foswikiTopRow' },
                        CGI::input(
                            {
                                type    => 'checkbox',
                                class   => 'foswikiCheckbox',
                                name    => 'referring_topics',
                                value   => $entry,
                                checked => 'checked'
                            }
                          )
                          . " [[$entry]] "
                      )
                      . CGI::td(
                        { class => 'foswikiSummary foswikiGrayText' },
                        $refs->{$entry}
                      )
                );
            }
            unless ($search) {
                $search = ( $session->i18n->maketext('(none)') );
            }
            else {
                $search = CGI::start_table() . $search . CGI::end_table();
            }
        }
        $tmpl =~ s/%GLOBAL_SEARCH%/$search/o;

        $refs = getReferringTopics( $session, $oldWeb, $oldTopic, 0 );

        $search = '';
        foreach my $entry ( sort keys %$refs ) {
            $search .= CGI::Tr(
                CGI::td(
                    { class => 'foswikiTopRow' },
                    CGI::input(
                        {
                            type    => 'checkbox',
                            class   => 'foswikiCheckbox',
                            name    => 'referring_topics',
                            value   => $entry,
                            checked => 'checked'
                        }
                      )
                      . " [[$entry]] "
                  )
                  . CGI::td(
                    { class => 'foswikiSummary foswikiGrayText' },
                    $refs->{$entry}
                  )
            );
        }
        unless ($search) {
            $search = ( $session->i18n->maketext('(none)') );
        }
        else {
            $search = CGI::start_table() . $search . CGI::end_table();
        }
        $tmpl =~ s/%LOCAL_SEARCH%/$search/go;
    }

    $tmpl = $session->handleCommonTags( $tmpl, $oldWeb, $oldTopic );
    $tmpl = $session->renderer->getRenderedVersion( $tmpl, $oldWeb, $oldTopic );
    $session->writeCompletePage($tmpl);
}

# _moveWeb($session, $oldWeb,  $newWeb, \@refs )
#
# Move the given web, correcting refs to the web in the web itself, and
# in the list of topics (specified as web.topic pairs) in the \@refs array.
# Currently only called by _renameweb
#
# All permissions and lease conflicts should be resolved before calling this method.
#
#    * =$session= - reference to session object
#    * =$oldWeb= - name of old web
#    * =$newWeb= - name of new web
#    * =\@refs= - array of webg.topics that must have refs to this topic converted
# Will throw Foswiki::OopsException on an error.

sub _moveWeb {
    my ( $session, $oldWeb, $newWeb, $refs ) = @_;
    my $store = $session->{store};

    $oldWeb =~ s/\./\//go;
    $newWeb =~ s/\./\//go;

    my $cUID = $session->{user};

    if ( $store->webExists($newWeb) ) {
        throw Foswiki::OopsException(
            'attention',
            web    => $oldWeb,
            topic  => '',
            def    => 'rename_web_exists',
            params => [$newWeb]
        );
    }

    # update referrers.  We need to do this before moving,
    # because there might be topics inside the newWeb which need updating.
    _updateWebReferringTopics( $session, $oldWeb, $newWeb, $refs );

    try {
        $store->moveWeb( $oldWeb, $newWeb, $cUID );
    }
    catch Error::Simple with {
        my $e = shift;
        throw Foswiki::OopsException(
            'attention',
            web    => $oldWeb,
            topic  => '',
            def    => 'rename_web_err',
            params => [ $e->{-text}, $newWeb ]
        );
    }
}

# Display screen so user can decide on new web.
# a Refresh mechanism is provided after submission of the form
# so the user can refresh the display until lease conflicts
# are resolved.

sub _newWebScreen {
    my ( $session, $oldWeb, $newWeb, $confirm, $webTopicInfoRef ) = @_;

    my $query = $session->{request};
    my $tmpl  = '';

    $newWeb = $oldWeb unless ($newWeb);

    my @newParentPath    = split( /\//, $newWeb );
    my $newSubWeb        = pop(@newParentPath);
    my $newParent        = join( '/', @newParentPath );
    my $accessCheckWeb   = $newParent;
    my $accessCheckTopic = $Foswiki::cfg{WebPrefsTopicName};
    my $templates        = $session->templates;

    if ( $confirm eq 'getlock' ) {
        $tmpl = $templates->readTemplate('renamewebconfirm');
    }
    elsif ( $newWeb eq $Foswiki::cfg{TrashWebName} ) {
        $tmpl = $templates->readTemplate('renamewebdelete');
    }
    else {
        $tmpl = $templates->readTemplate('renameweb');
    }

    # Trashing a web; look for a non-conflicting name
    if ( $newWeb eq $Foswiki::cfg{TrashWebName} ) {
        $newWeb = "$Foswiki::cfg{TrashWebName}/$oldWeb";
        my $n    = 1;
        my $base = $newWeb;
        while ( $session->{store}->webExists($newWeb) ) {
            $newWeb = $base . $n;
            $n++;
        }
    }

    $tmpl =~ s/%NEW_PARENTWEB%/$newParent/go;
    $tmpl =~ s/%NEW_SUBWEB%/$newSubWeb/go;
    $tmpl =~ s/%TOPIC%/$Foswiki::cfg{HomeTopicName}/go;

    my ( $movelocked, $refdenied, $reflocked ) = ( '', '', '' );
    $movelocked = join( ', ', @{ $webTopicInfoRef->{movelocked} } )
      if $webTopicInfoRef->{movelocked};
    $movelocked = ( $session->i18n->maketext('(none)') ) unless $movelocked;
    $refdenied = join( ', ', @{ $webTopicInfoRef->{modifydenied} } )
      if $webTopicInfoRef->{modifydenied};
    $refdenied = ( $session->i18n->maketext('(none)') ) unless $refdenied;
    $reflocked = join( ', ', @{ $webTopicInfoRef->{modifylocked} } )
      if $webTopicInfoRef->{modifylocked};
    $reflocked = ( $session->i18n->maketext('(none)') ) unless $reflocked;

    $tmpl =~ s/%MOVE_LOCKED%/$movelocked/;
    $tmpl =~ s/%REF_DENIED%/$refdenied/;
    $tmpl =~ s/%REF_LOCKED%/$reflocked/;

    my $refresh_prompt = ( $session->i18n->maketext('Refresh') );
    my $submit_prompt  = ( $session->i18n->maketext('Move/Rename') );

    my $submitAction =
      ( $movelocked || $reflocked ) ? $refresh_prompt : $submit_prompt;
    $tmpl =~ s/%RENAMEWEB_SUBMIT%/$submitAction/go;

    my $refs;
    my $search = '';

    $refs = ${$webTopicInfoRef}{referring}{refs1};
    foreach my $entry ( sort keys %$refs ) {
        $search .= CGI::Tr(
            CGI::td(
                { class => 'foswikiTopRow' },
                CGI::input(
                    {
                        type    => 'checkbox',
                        class   => 'foswikiCheckbox',
                        name    => 'referring_topics',
                        value   => $entry,
                        checked => 'checked'
                    }
                  )
                  . " [[$entry]] "
              )
              . CGI::td(
                { class => 'foswikiSummary foswikiGrayText' },
                $refs->{$entry}
              )
        );
    }
    unless ($search) {
        $search = ( $session->i18n->maketext('(none)') );
    }
    else {
        $search = CGI::start_table() . $search . CGI::end_table();
    }
    $tmpl =~ s/%GLOBAL_SEARCH%/$search/o;

    $refs   = $webTopicInfoRef->{referring}{refs0};
    $search = '';
    foreach my $entry ( sort keys %$refs ) {
        $search .= CGI::Tr(
            CGI::td(
                { class => 'foswikiTopRow' },
                CGI::input(
                    {
                        type    => 'checkbox',
                        class   => 'foswikiCheckbox',
                        name    => 'referring_topics',
                        value   => $entry,
                        checked => 'checked'
                    }
                  )
                  . " [[$entry]] "
              )
              . CGI::td(
                { class => 'foswikiSummary foswikiGrayText' },
                $refs->{$entry}
              )
        );
    }
    unless ($search) {
        $search = ( $session->i18n->maketext('(none)') );
    }
    else {
        $search = CGI::start_table() . $search . CGI::end_table();
    }
    $tmpl =~ s/%LOCAL_SEARCH%/$search/go;

    $tmpl =
      $session->handleCommonTags( $tmpl, $oldWeb,
        $Foswiki::cfg{HomeTopicName} );
    $tmpl =
      $session->renderer->getRenderedVersion( $tmpl, $oldWeb,
        $Foswiki::cfg{HomeTopicName} );
    $session->writeCompletePage($tmpl);
}

# Returns the list of topics that have been found that refer
# to the renamed topic. Returns a list of topics.
sub _getReferringTopicsListFromURL {
    my ( $session, $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;

    my $query = $session->{request};
    my @result;
    foreach my $topic ( $query->param('referring_topics') ) {
        my ( $itemWeb, $itemTopic ) =
          $session->normalizeWebTopicName( '', $topic );

        # Check validity of web and topic
        $itemWeb = Foswiki::Sandbox::untaint(
            $itemWeb, \&Foswiki::Sandbox::validateWebName);
        $itemTopic = Foswiki::Sandbox::untaint(
            $itemTopic, \&Foswiki::Sandbox::validateTopicName);

        # Skip web.topic that fails validation
        next unless ($itemWeb && $itemTopic);

        ASSERT($itemWeb !~ /\./) if DEBUG; # cos we will split on . later

        push @result, "$itemWeb.$itemTopic";
    }
    return \@result;
}

=begin TML

---++ StaticMethod getReferringTopics($session, $web, $topic, $allWebs) -> \%matches

   * =$session= - the session
   * =$web= - web to search for
   * =$topic= - topic to search for
   * =$allWebs= - 0 to search $web only. 1 to search all webs _except_ $web.
Returns a hash that maps the web.topic name to a summary of the lines that matched. Will _not_ return $web.$topic in the list

=cut

# SMELL: this will only work as long as searchInWebContent searches meta-data
# as well. It sould really do a query over the meta-data as well, but at the
# moment that is just duplication and it's too slow already.
sub getReferringTopics {
    my ( $session, $web, $topic, $allWebs ) = @_;
    my $store    = $session->{store};
    my $renderer = $session->renderer;
    require Foswiki::Render;

    $web =~ s#\.#/#go;
    my @webs = ($web);

    if ($allWebs) {
        @webs = $store->getListOfWebs();
    }

    my %results;
    foreach my $searchWeb (@webs) {
        next if ( $allWebs && $searchWeb eq $web );

        # Search for both the twiki form and the URL form
        my $searchString = Foswiki::Render::getReferenceRE(
            $web, $topic,
            grep    => 1,
            interweb => ( $searchWeb ne $web )
          )
          . '|'
          . Foswiki::Render::getReferenceRE(
            $web, $topic,
            grep    => 1,
            interweb => ( $searchWeb ne $web ),
            url     => 1
          );

        my @topicList = $store->getTopicNames($searchWeb);
        my $matches =
          $store->searchInWebContent( $searchString, $searchWeb, \@topicList,
            { casesensitive => 1, type => 'regex' } );

        foreach my $searchTopic ( keys %$matches ) {
            next if ( $searchWeb eq $web && $topic && $searchTopic eq $topic );

            my $t = join( '...', @{ $matches->{$searchTopic} } );
            $t = $renderer->TML2PlainText( $t, $searchWeb, $searchTopic,
                "showvar;showmeta" );
            $t =~ s/^\s+//;
            if ( length($t) > 100 ) {
                $t =~ s/^(.{100}).*$/$1/;
            }
            $results{ $searchWeb . '.' . $searchTopic } = $t;
        }
    }
    return \%results;
}

# Update pages that refer to a page that is being renamed/moved.
# SMELL: this might be done more efficiently if it was behind the
# store interface
sub _updateReferringTopics {
    my ( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $refs ) = @_;
    my $store    = $session->{store};
    my $renderer = $session->renderer;
    require Foswiki::Render;
    my $cUID    = $session->{user};
    my $options = {
        pre      => 1,           # process lines in PRE blocks
        oldWeb   => $oldWeb,
        oldTopic => $oldTopic,
        newWeb   => $newWeb,
        newTopic => $newTopic,
    };

    foreach my $item (@$refs) {
        my ( $itemWeb, $itemTopic ) = split('\.', $item, 2);

        if ( $store->topicExists( $itemWeb, $itemTopic ) ) {
            $store->lockTopic( $cUID, $itemWeb, $itemTopic );
            try {
                my ( $meta, $text ) =
                  $store->readTopic( undef, $itemWeb, $itemTopic, undef );
                $options->{inWeb} = $itemWeb;
                $text = $renderer->forEachLine( $text,
                    \&Foswiki::Render::replaceTopicReferences, $options );
                $meta->forEachSelectedValue(
                    qw/^(FIELD|FORM|TOPICPARENT)$/,            undef,
                    \&Foswiki::Render::replaceTopicReferences, $options
                );

                $store->saveTopic( $cUID, $itemWeb, $itemTopic, $text, $meta,
                    { minor => 1 } );
            }
            catch Foswiki::AccessControlException with {
                my $e = shift;
                $session->logger->log( 'warning', $e->stringify() );
            }
            finally {
                $store->unlockTopic( $cUID, $itemWeb, $itemTopic );
            };
        }
    }
}

# Update pages that refer to a web that is being renamed/moved.
sub _updateWebReferringTopics {
    my ( $session, $oldWeb, $newWeb, $refs ) = @_;
    my $store    = $session->{store};
    my $renderer = $session->renderer;
    require Foswiki::Render;

    my $cUID    = $session->{user};
    my $options = {
        oldWeb => $oldWeb,
        newWeb => $newWeb
    };

    foreach my $item (@$refs) {
        my ( $itemWeb, $itemTopic ) = split('\.', $item, 2);

        if ( $store->topicExists( $itemWeb, $itemTopic ) ) {
            $store->lockTopic( $cUID, $itemWeb, $itemTopic );
            try {
                my ( $meta, $text ) =
                  $store->readTopic( undef, $itemWeb, $itemTopic, undef );
                $options->{inWeb} = $itemWeb;

                $text = $renderer->forEachLine( $text,
                    \&Foswiki::Render::replaceWebReferences, $options );
                $meta->forEachSelectedValue(
                    qw/^(FIELD|FORM|TOPICPARENT)$/,          undef,
                    \&Foswiki::Render::replaceWebReferences, $options
                );

                $store->saveTopic( $cUID, $itemWeb, $itemTopic, $text, $meta,
                    { minor => 1 } );
            }
            catch Foswiki::AccessControlException with {
                my $e = shift;
                $session->logger->log( 'warning', $e->stringify() );
            }
            finally {
                $store->unlockTopic( $cUID, $itemWeb, $itemTopic );
            };
        }
    }
}

sub _action_editSettings {
    my $session = shift;
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};

    my ( $meta, $text ) =
      $session->{store}->readTopic( $session->{user}, $web, $topic, undef );
    my ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();

    my $settings = "";

    my @fields = $meta->find('PREFERENCE');
    foreach my $field (@fields) {
        my $name  = $field->{name};
        my $value = $field->{value};
        $settings .= '   * '
          . ( ( $field->{type} eq 'Local' ) ? 'Local' : 'Set' ) . ' '
          . $name . ' = '
          . $value . "\n";
    }

    my $skin = $session->getSkin();
    my $tmpl = $session->templates->readTemplate( 'settings', $skin );
    $tmpl = $session->handleCommonTags( $tmpl, $web, $topic, $meta );
    $tmpl = $session->renderer->getRenderedVersion( $tmpl, $web, $topic );

    $tmpl =~ s/%TEXT%/$settings/o;
    $tmpl =~ s/%ORIGINALREV%/$orgRev/g;

    $session->writeCompletePage($tmpl);

}

sub _action_saveSettings {
    my $session = shift;
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $cUID    = $session->{user};

    # set up editing session
    my ( $currMeta, $currText ) =
      $session->{store}->readTopic( undef, $web, $topic, undef );
    require Foswiki::Meta;
    my $newMeta = new Foswiki::Meta( $session, $web, $topic );
    $newMeta->copyFrom($currMeta);

    my $query       = $session->{request};
    my $settings    = $query->param('text');
    my $originalrev = $query->param('originalrev');

    $newMeta->remove('PREFERENCE');    # delete previous settings
     # Note: $Foswiki::regex{setVarRegex} cannot be used as it requires use in code
     # that parses multiline settings line by line.
    $settings =~
s(^(?:\t|   )+\*\s+(Set|Local)\s+($Foswiki::regex{tagNameRegex})\s*=\s*?(.*)$)
       (&_handleSave($web, $topic, $1, $2, $3, $newMeta))mgeo;

    my $saveOpts = {};
    $saveOpts->{minor}            = 1;    # don't notify
    $saveOpts->{forcenewrevision} = 1;    # always new revision

    # Merge changes in meta data
    if ($originalrev) {
        my ( $date, $author, $rev ) = $newMeta->getRevisionInfo();

        # If the last save was by me, don't merge
        if ( $rev ne $originalrev && $author ne $cUID ) {
            $newMeta->merge($currMeta);
        }
    }

    try {
        $session->{store}
          ->saveTopic( $cUID, $web, $topic, $currText, $newMeta, $saveOpts );
    }
    catch Error::Simple with {
        throw Foswiki::OopsException(
            'attention',
            def    => 'save_error',
            web    => $web,
            topic  => $topic,
            params => [ shift->{-text} ]
        );
    };
    my $viewURL = $session->getScriptUrl( 0, 'view', $web, $topic );
    $session->redirect( $session->redirectto($viewURL) );
}

sub _handleSave {
    my ( $web, $topic, $type, $name, $value, $meta ) = @_;

    $value =~ s/^\s*(.*?)\s*$/$1/ge;

    my $args = {
        name  => $name,
        title => $name,
        value => $value,
        type  => $type
    };
    $meta->putKeyed( 'PREFERENCE', $args );
    return '';
}

sub _action_restoreRevision {
    my ($session) = @_;

    # edit handles all the parameters we require
    $session->{request}->delete('action');
    require Foswiki::UI::Edit;
    Foswiki::UI::Edit::edit($session);
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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
# As per the GPL, removal of this notice is prohibited.
