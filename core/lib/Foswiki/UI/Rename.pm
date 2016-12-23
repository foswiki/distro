# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Rename

UI functions for renaming.

=cut

package Foswiki::UI::Rename;

use strict;
use warnings;
use Assert;
use Error qw(:try);

use Foswiki::UI     ();
use Foswiki::Render ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our $MARKER = "\02\03";

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
| =onlywikiname= | if defined, only a wikiword is acceptable for the new topic name |
| =redirectto= | If the rename process is successful, rename will redirect to this topic or URL. The parameter value can be a =TopicName=, a =Web.TopicName=, or a URL.%BR% __Note:__ Redirect to a URL only works if it is enabled in =configure= (Miscellaneous ={AllowRedirectUrl}=). |

=cut

# This function is entered twice during an interaction renaming session. The
# first time is when the parameters for the rename are being gathered
# referring topics etc) and in this case, it will terminate at either
# newWebScreen or newTopicOrAttachmentScreen. The second times is when the
# rename is proceeding, and/or all the appropriate parameters have been
# passed by the caller. In this case the rename proceeds.
sub rename {
    my $session = shift;

    my $oldWeb           = $session->{webName};
    my $oldTopic         = $session->{topicName};
    my $query            = $session->{request};
    my $action           = $session->{cgiQuery}->param('action') || '';
    my $redirectto_param = $session->{cgiQuery}->param('redirectto') || '';

    Foswiki::UI::checkWebExists( $session, $oldWeb, 'rename' );

    if ( $session->{invalidTopic} ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 404,
            def    => 'invalid_topic_name',
            web    => $oldWeb,
            topic  => $oldTopic,
            params => [ $session->{invalidTopic} ]
        );
    }

    my $new_url;
    if ( $action eq 'renameweb' ) {
        $new_url = _renameWeb( $session, $oldWeb );
    }
    else {
        $new_url = _renameTopicOrAttachment( $session, $oldWeb, $oldTopic );
    }

    if ( $redirectto_param ne '' ) {
        $new_url = $session->redirectto($redirectto_param);
    }

    $session->redirect($new_url) if $new_url;
}

# Rename a topic
sub _renameTopicOrAttachment {
    my ( $session, $oldWeb, $oldTopic ) = @_;

    my $query    = $session->{cgiQuery};
    my $newTopic = $query->param('newtopic') || '';
    my $newWeb   = $query->param('newweb') || '';

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

    my $confirm = $query->param('confirm');

    unless ( $session->topicExists( $oldWeb, $oldTopic ) ) {

        # Item3270: check for the same name starting with a lower case letter.
        unless ( $session->topicExists( $oldWeb, lcfirst($oldTopic) ) ) {
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
            !Foswiki::isTrue( scalar( $query->param('onlywikiname') ) )
        );
    }

    my $attachment    = $query->param('attachment');
    my $newAttachment = $query->param('newattachment');

    my $old = Foswiki::Meta->load( $session, $oldWeb, $oldTopic );

    if ($attachment) {

        # Does old attachment exist?
        # Attachment exists, validated
        $attachment = Foswiki::Sandbox::untaint(
            $attachment,
            sub {
                my ($att) = @_;
                if ( !$old->hasAttachment($att) ) {
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
                                'Attachment does not exist.')
                        ]
                    );
                }
                return $att;
            }
        );

        # Validate the new attachment name, if one was provided
        if ($newAttachment) {
            $newAttachment = Foswiki::Sandbox::untaint( $newAttachment,
                \&Foswiki::Sandbox::validateAttachmentName );
        }

        if ( $newWeb && $newTopic && $newAttachment ) {

            Foswiki::UI::checkTopicExists( $session, $newWeb, $newTopic,
                'rename' );

            my $new = Foswiki::Meta->load( $session, $newWeb, $newTopic );

            # does new attachment already exist?
            if ( $new->hasAttachment($newAttachment) ) {
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'move_err',
                    web    => $oldWeb,
                    topic  => $oldTopic,
                    params => [
                        $newWeb,
                        $newTopic,
                        $newAttachment,
                        $session->i18n->maketext(
'An attachment with the same name already exists in this topic.'
                        )
                    ]
                );
            }
        }    # else fall through to new topic screen
    }
    elsif ($newTopic) {
        ( $newWeb, $newTopic ) =
          $session->normalizeWebTopicName( $newWeb, $newTopic );

        Foswiki::UI::checkWebExists( $session, $newWeb, $newTopic, 'rename' );
        if ( $session->topicExists( $newWeb, $newTopic ) ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'rename_topic_exists',
                web    => $oldWeb,
                topic  => $oldTopic,
                params => [ $newWeb, $newTopic ]
            );
        }
    }

    # Only check RENAME authority if the topic itself is being renamed.
    if ( ( $newWeb || $newTopic ) && !( $newAttachment || $attachment ) ) {
        Foswiki::UI::checkAccess( $session, 'RENAME', $old );
    }
    else {
        Foswiki::UI::checkAccess( $session, 'CHANGE', $old );
    }

    my $new = Foswiki::Meta->new(
        $session,
        $newWeb   || $old->web,
        $newTopic || $old->topic
    );

    # Has user selected new name yet?
    if ( !$newTopic || ( $attachment && !$newAttachment ) || $confirm ) {
        $newAttachment ||= $attachment;

        # Must be able to view the source to rename it
        Foswiki::UI::checkAccess( $session, 'VIEW', $old );

        _newTopicOrAttachmentScreen( $session, $old, $new, $attachment,
            $newAttachment, $confirm );
        return;

    }

    unless ( $session->inContext('command_line') ) {
        if ( uc( $session->{request}->method() ) ne 'POST' ) {
            throw Foswiki::OopsException(
                'attention',
                web    => $session->{webName},
                topic  => $session->{topicName},
                def    => 'post_method_only',
                params => ['rename']
            );
        }
    }

    Foswiki::UI::checkValidationKey($session);

    # Update references in referring pages - not applicable to attachments.
    my $refs;
    unless ($attachment) {
        $refs =
          _getReferringTopicsListFromURL( $session, $oldWeb, $oldTopic, $newWeb,
            $newTopic );
    }

    _moveTopicOrAttachment( $session, $old, $new, $attachment, $newAttachment,
        $refs );

    my $new_url;
    if (   $newWeb eq $Foswiki::cfg{TrashWebName}
        && $oldWeb ne $Foswiki::cfg{TrashWebName} )
    {

        # deleting something

        if ($attachment) {

            # go back to old topic after deleting an attachment
            $new_url =
              $session->getScriptUrl( 0, 'view', $old->web, $old->topic );

        }
        else {

            # redirect to parent topic, if set
            my $meta = Foswiki::Meta->load( $session, $new->web, $new->topic );
            my $parent = $meta->get('TOPICPARENT');
            my ( $parentWeb, $parentTopic );
            if ( $parent && defined $parent->{name} ) {
                ( $parentWeb, $parentTopic ) =
                  $session->normalizeWebTopicName( $oldWeb, $parent->{name} );
            }
            if (   $parentTopic
                && !( $parentWeb eq $oldWeb && $parentTopic eq $oldTopic )
                && $session->topicExists( $parentWeb, $parentTopic ) )
            {
                $new_url =
                  $session->getScriptUrl( 0, 'view', $parentWeb, $parentTopic );
            }
            else {

                # No parent topic, redirect to home topic
                $new_url =
                  $session->getScriptUrl( 0, 'view', $oldWeb,
                    $Foswiki::cfg{HomeTopicName} );
            }
        }
    }
    else {
        unless ( $session->inContext('command_line') ) {

            # redirect to new topic
            $new_url = $session->getScriptUrl( 0, 'view', $newWeb, $newTopic );
            $session->{webName}   = $newWeb;
            $session->{topicName} = $newTopic;
        }
    }

    return $new_url;
}

sub _safeTopicName {
    my ($topic) = @_;

    $topic =~ s/\s//g;
    $topic = ucfirst $topic;    # Item3270
    $topic =~ s![./]!_!g;
    $topic =~ s/($Foswiki::cfg{NameFilter})//g;

    return $topic;
}

#| =skin= | skin(s) to use |
#| =newsubweb= | new web name |
#| =newparentweb= | new parent web name |
#| =confirm= | if defined, requires a second level of confirmation.  Currently accepted values are "getlock", "continue", and "cancel" |
sub _renameWeb {
    my ( $session, $oldWeb ) = @_;

    my $oldWebObject = Foswiki::Meta->new( $session, $oldWeb );

    my $query = $session->{request};
    my $cUID  = $session->{user};

    # If the user is not allowed to rename anything in the current
    # web - stop here
    Foswiki::UI::checkAccess( $session, 'RENAME', $oldWebObject );

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

    if ( $newParentWeb eq $oldWeb
        || ( defined $newWeb && $newParentWeb eq $newWeb ) )
    {
        throw Foswiki::OopsException(
            'attention',
            web    => $oldWeb,
            def    => 'invalid_web_parent',
            params => [ $newSubWeb, $newParentWeb ]
        );
    }

    if (   $oldWeb eq $Foswiki::cfg{SystemWebName}
        || $oldWeb eq $Foswiki::cfg{UsersWebName} )
    {
        throw Foswiki::OopsException(
            'attention',
            web    => $oldWeb,
            topic  => '',
            def    => 'rename_web_err',
            params => [
                "Rename is not permitted, it would damage the installation",
                'anything'
            ]
        );
    }

    # Determine the parent of the 'from' web
    my @tmp = split( /[\/\.]/, $oldWeb );
    pop(@tmp);
    my $oldParentWeb = join( '/', @tmp );

    # If the user is not allowed to rename anything in the parent web
    # - stop here
    # This also ensures we check root webs for ALLOWROOTRENAME and
    # DENYROOTRENAME
    my $oldParentWebObject =
      new Foswiki::Meta( $session, $oldParentWeb || undef );
    Foswiki::UI::checkAccess( $session, 'RENAME', $oldParentWebObject );

    # If old web is a root web then also stop if ALLOW/DENYROOTCHANGE
    # prevents access
    if ( !$oldParentWeb ) {
        Foswiki::UI::checkAccess( $session, 'CHANGE', $oldParentWebObject );
    }

    my $newTopic;
    my $lockFailure = '';
    my $confirm = $query->param('confirm') || '';

    Foswiki::UI::checkWebExists( $session, $oldWeb,
        $Foswiki::cfg{WebPrefsTopicName}, 'rename' );

    if ($newWeb) {
        if ($newParentWeb) {
            Foswiki::UI::checkWebExists( $session, $newParentWeb,
                $Foswiki::cfg{WebPrefsTopicName}, 'rename' );
        }
        if ( $session->webExists($newWeb) ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'rename_web_exists',
                web    => $oldWeb,
                topic  => $Foswiki::cfg{WebPrefsTopicName},
                params => [ $newWeb, $Foswiki::cfg{WebPrefsTopicName} ]
            );
        }

        # Check if we have change permission in the new parent
        my $newParentWebObject = new Foswiki::Meta( $session, $newParentWeb );
        Foswiki::UI::checkAccess( $session, 'CHANGE', $newParentWebObject );
    }

    if ( !$newWeb || $confirm ) {
        my %refs;
        my $info = {
            totalReferralAccess   => 1,
            totalWebAccess        => 1,
            modifyingLockedTopics => 0,
            movingLockedTopics    => 0
        };

        # get a topic list for all the topics referring to this web,
        # and build up a hash containing permissions and lock info.
        my $refs0 = _getReferringTopics( $session, $oldWebObject, 0 );
        my $refs1 = _getReferringTopics( $session, $oldWebObject, 1 );
        %refs = ( %$refs0, %$refs1 );

        $info->{referring}{refs0} = $refs0;
        $info->{referring}{refs1} = $refs1;

        my $lease_ref;
        foreach my $ref ( keys %refs ) {
            if ( defined($ref) && $ref ne "" ) {
                my (@path) = split( /[.\/]/, $ref );
                my $webTopic = pop(@path);
                my $webIter = join( '/', @path );

                my $topicObject =
                  Foswiki::Meta->new( $session, $webIter, $webTopic );
                if ( $confirm eq 'getlock' ) {
                    $topicObject->setLease( $Foswiki::cfg{LeaseLength} );
                    $lease_ref = $topicObject->getLease();
                }
                elsif ( $confirm eq 'cancel' ) {
                    $lease_ref = $topicObject->getLease();
                    if ( $lease_ref->{user} eq $cUID ) {
                        $topicObject->clearLease();
                    }
                }
                my $wit = $webIter . '/' . $webTopic;
                $info->{modify}{$wit}{leaseuser} = $lease_ref->{user};
                $info->{modify}{$wit}{leasetime} = $lease_ref->{taken};

                $info->{modifyingLockedTopics}++
                  if ( defined( $info->{modify}{$ref}{leaseuser} )
                    && $info->{modify}{$ref}{leaseuser} ne $cUID );
                $info->{modify}{$ref}{access} =
                  $topicObject->haveAccess('CHANGE');
                if ( !$info->{modify}{$ref}{access} ) {
                    $info->{modify}{$ref}{accessReason} =
                      $Foswiki::Meta::reason;
                }
                $info->{totalReferralAccess} = 0
                  unless $info->{modify}{$ref}{access};
            }
        }

        # Lease topics and build
        # up a hash containing permissions and lock info.
        my $it = $oldWebObject->eachWeb(1);
        _leaseContents( $session, $info, $oldWebObject->web, $confirm );
        while ( $it->hasNext() ) {
            my $subweb = $it->next();
            require Foswiki::WebFilter;
            next unless Foswiki::WebFilter->public()->ok( $session, $subweb );
            _leaseContents( $session, $info, $oldWebObject->web . '/' . $subweb,
                $confirm );
        }

        if (   !$info->{totalReferralAccess}
            || !$info->{totalWebAccess}
            || $info->{movingLockedTopics}
            || $info->{modifyingLockedTopics} )
        {

            # check if the user can rename all the topics in this web.
            push(
                @{ $info->{movedenied} },
                grep { !$info->{move}{$_}{access} }
                  sort keys %{ $info->{move} }
            );

            # check if there are any locked topics in this web or
            # its subwebs.
            push(
                @{ $info->{movelocked} },
                grep {
                    defined( $info->{move}{$_}{leaseuser} )
                      && $info->{move}{$_}{leaseuser} ne $cUID
                  }
                  sort keys %{ $info->{move} }
            );

            # Next, build up a list of all the referrers which the
            # user doesn't have permission to change.
            push(
                @{ $info->{modifydenied} },
                grep { !$info->{modify}{$_}{access} }
                  sort keys %{ $info->{modify} }
            );

            # Next, build up a list of all the referrers which are
            # currently locked.
            push(
                @{ $info->{modifylocked} },
                grep {
                    defined( $info->{modify}{$_}{leaseuser} )
                      && $info->{modify}{$_}{leaseuser} ne $cUID
                  }
                  sort keys %{ $info->{modify} }
            );

            unless ($confirm) {
                my $nocontinue = '';
                if (   @{ $info->{movedenied} }
                    || @{ $info->{movelocked} } )
                {
                    $nocontinue = 'style="display:none;"';
                }
                my $mvd = join( ' ', @{ $info->{movedenied} } )
                  || ( $session->i18n->maketext('(none)') );
                $mvd = substr( $mvd, 0, 300 ) . '... (more)'
                  if ( length($mvd) > 300 );
                my $mvl = join( ' ', @{ $info->{movelocked} } )
                  || ( $session->i18n->maketext('(none)') );
                $mvl = substr( $mvl, 0, 300 ) . '... (more)'
                  if ( length($mvl) > 300 );
                my $mdd = join( ' ', @{ $info->{modifydenied} } )
                  || ( $session->i18n->maketext('(none)') );
                $mdd = substr( $mdd, 0, 300 ) . '... (more)'
                  if ( length($mdd) > 300 );
                my $mdl = join( ' ', @{ $info->{modifylocked} } )
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
                && $info->{modifyingLockedTopics}
                && $info->{movingLockedTopics} )
          )
        {

            # Has user selected new name yet?
            _newWebScreen( $session, $oldWebObject, $newWeb, $confirm, $info );
            return;
        }
    }

    Foswiki::UI::checkValidationKey($session);

    my $newWebObject = Foswiki::Meta->new( $session, $newWeb );

    Foswiki::UI::checkAccess( $session, 'CHANGE', $oldWebObject );
    Foswiki::UI::checkAccess( $session, 'CHANGE', $newWebObject );

    my $refs = _getReferringTopicsListFromURL($session);

    # update referrers.  We need to do this before moving,
    # because there might be topics inside the newWeb which need updating.
    _updateReferringTopics( $session, $refs, \&_replaceWebReferences,
        { oldWeb => $oldWeb, newWeb => $newWeb, noautolink => 1 } );

    # Now, we can move the web.
    try {
        $oldWebObject->move($newWebObject);
    }
    catch Foswiki::OopsException with {
        shift->throw();    # propagate
    }
    catch Error with {
        $session->logger->log( 'error', shift->{-text} );
        throw Foswiki::OopsException(
            'attention',
            web    => $oldWeb,
            topic  => '',
            def    => 'rename_web_err',
            params => [
                $session->i18n->maketext(
                    'Operation [_1] failed with an internal error', 'move'
                ),
                $newWeb
            ],
        );
    }

    # now remove leases on all topics inside $newWeb.
    my $nwom = Foswiki::Meta->new( $session, $newWeb );
    my $it = $nwom->eachWeb(1);
    _releaseContents( $session, $newWeb );
    while ( $it->hasNext() ) {
        my $subweb = $it->next();
        require Foswiki::WebFilter;
        next unless Foswiki::WebFilter->public()->ok( $session, $subweb );
        _releaseContents( $session, "$newWeb/$subweb" );
    }

    # also remove lease on all referring topics
    foreach my $ref (@$refs) {
        my @path        = split( /[.\/]/, $ref );
        my $webTopic    = pop(@path);
        my $webIter     = join( '/', @path );
        my $topicObject = Foswiki::Meta->new( $session, $webIter, $webTopic );
        $topicObject->clearLease();
    }

    my $new_url = '';
    if (   $newWeb =~ m/^$Foswiki::cfg{TrashWebName}\b/
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
        $session->{webName}   = $newWeb;
        $session->{topicName} = $Foswiki::cfg{HomeTopicName};
    }

    return $new_url;
}

sub _leaseContents {
    my ( $session, $info, $web, $confirm ) = @_;

    my $webObject = Foswiki::Meta->new( $session, $web );
    my $it = $webObject->eachTopic();
    while ( $it->hasNext() ) {
        my $topic = $it->next();
        my $lease_ref;
        my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
        if ( $confirm eq 'getlock' ) {
            $topicObject->setLease( $Foswiki::cfg{LeaseLength} );
            $lease_ref = $topicObject->getLease();
        }
        elsif ( $confirm eq 'cancel' ) {
            $lease_ref = $topicObject->getLease();
            if ( $lease_ref->{user} eq $session->{user} ) {
                $topicObject->clearLease();
            }
        }
        my $wit = $web . '/' . $topic;
        $info->{move}{$wit}{leaseuser} = $lease_ref->{user};
        $info->{move}{$wit}{leasetime} = $lease_ref->{taken};

        $info->{movingLockedTopics}++
          if ( defined( $info->{move}{$wit}{leaseuser} )
            && $info->{move}{$wit}{leaseuser} ne $session->{user} );
        $info->{move}{$wit}{access}       = $topicObject->haveAccess('RENAME');
        $info->{move}{$wit}{accessReason} = $Foswiki::Meta::reason;
        $info->{totalWebAccess} =
          ( $info->{totalWebAccess} & $info->{move}{$wit}{access} );
    }
}

sub _releaseContents {
    my ( $session, $web ) = @_;

    my $webObject = Foswiki::Meta->new( $session, $web );
    my $it = $webObject->eachTopic();
    while ( $it->hasNext() ) {
        my $topic = $it->next();
        my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
        $topicObject->clearLease();
    }
}

# Move the given topic, or an attachment in the topic, correcting refs to the topic in the topic itself, and
# in the list of topics (specified as web.topic pairs) in the \@refs array.
#
#    * =$session= - reference to session object
#    * =$from= - old topic
#    * =$to= - new topic
#    * =$attachment= - name of the attachment to move (from oldtopic to newtopic) (undef to move the topic) - must be untaineted
#    * =\@refs= - array of webg.topics that must have refs to this topic converted
# Will throw Foswiki::OopsException on an error.
sub _moveTopicOrAttachment {
    my ( $session, $from, $to, $attachment, $toattachment, $refs ) = @_;

    Foswiki::UI::checkAccess( $session, 'CHANGE', $from );
    Foswiki::UI::checkAccess( $session, 'CHANGE', $to );

    if ($attachment) {
        try {
            $from->moveAttachment( $attachment, $to,
                new_name => $toattachment );
        }
        catch Foswiki::OopsException with {
            shift->throw();    # propagate
        }
        catch Error with {
            $session->logger->log( 'error', shift->{-text} );
            throw Foswiki::OopsException(
                'attention',
                web    => $from->web,
                topic  => $from->topic,
                def    => 'move_err',
                params => [
                    $to->web,
                    $to->topic,
                    $attachment,
                    $session->i18n->maketext(
                        'Operation [_1] failed with an internal error',
                        'moveAttachment'
                    )
                ]
            );
        };
    }
    else {
        try {
            $from->move($to);
        }
        catch Foswiki::OopsException with {
            shift->throw();    # propagate
        }
        catch Error with {
            $session->logger->log( 'error', shift->{-text} );
            throw Foswiki::OopsException(
                'attention',
                web    => $from->web,
                topic  => $from->topic,
                def    => 'rename_err',
                params => [
                    $session->i18n->maketext(
                        'Operation [_1] failed with an internal error', 'move'
                    ),
                    $to->web,
                    $to->topic
                ]
            );
        };

        # Force reload of new object, as it's been moved. This is safe
        # because the $to object is entirely local to the code in this
        # package.
        $to->unload();
        $to = $to->load();

        # Now let's replace all self-referential links:
        require Foswiki::Render;
        my $text    = $to->text();
        my $options = {
            oldWeb    => $from->web,
            oldTopic  => $from->topic,
            newWeb    => $to->web,
            newTopic  => $to->topic,
            inWeb     => $to->web,
            fullPaths => 0,

           # Process noautolink blocks. forEachLine will set in_noautolink when
           # processing links in a noautolink block.  _getReferenceRE will force
           # squabbed links when in_noautolink is set.
            noautolink => 1,
        };
        $text =
          $session->renderer->forEachLine( $text, \&_replaceTopicReferences,
            $options );
        $to->text($text);

        $to->put(
            'TOPICMOVED',
            {
                from => $from->web . '.' . $from->topic,
                to   => $to->web . '.' . $to->topic,
                date => time(),
                by   => $session->{user},
            }
        );

        $to->save( minor => 1, comment => 'rename' );

        # update referrers - but _not_ including the moved topic
        _updateReferringTopics( $session, $refs, \&_replaceTopicReferences,
            $options );
    }
}

# _replaceTopicReferences( $text, \%options ) -> $text
#
# Callback designed for use with forEachLine, to replace topic references.
# \%options contains:
#   * =oldWeb= => Web of reference to replace
#   * =oldTopic= => Topic of reference to replace
#   * =newWeb= => Web of new reference
#   * =newTopic= => Topic of new reference
#   * =inWeb= => the web which the text we are presently processing resides in
#   * =fullPaths= => optional, if set forces all links to full web.topic form
#   * =noautolink= => Set to process links in noautolink blocks
#   * =in_noautolink= => Set by calling forEachLine if inside a noautolink block
sub _replaceTopicReferences {
    my ( $text, $args ) = @_;

    ASSERT( defined $args->{oldWeb} )   if DEBUG;
    ASSERT( defined $args->{oldTopic} ) if DEBUG;

    ASSERT( defined $args->{newWeb} )   if DEBUG;
    ASSERT( defined $args->{newTopic} ) if DEBUG;

    ASSERT( defined $args->{inWeb} ) if DEBUG;

    # Do the traditional Foswiki topic references first
    my $oldTopic = $args->{oldTopic};
    my $newTopic = $args->{newTopic};
    my $repl     = $newTopic;

    my $newWeb  = $args->{newWeb};
    my $oldWeb  = $args->{oldWeb};
    my $sameWeb = ( $oldWeb eq $newWeb );

    if ( $args->{inWeb} ne $newWeb || $args->{fullPaths} ) {
        $repl = $newWeb . '.' . $repl;
    }

    my $re = _getReferenceRE( $oldWeb, $oldTopic, %$args );
    $text =~ s/($re)/_doReplace($1, $newWeb, $repl)/ge;

    # Do any references for Templates
    if ( $oldTopic =~ m/(.*)Template$/ ) {
        my $ot = $1;

        # Only if the rename is also to a template, otherwise give up.
        if ( $repl =~ m/(.*)Template$/ ) {
            my $nt = $1;

            # Handle META Preference settings
            if (   $nt
                && $args->{_type}
                && $args->{_type} eq 'PREFERENCE'
                && $args->{_key}  eq 'value' )
            {
                $re = _getReferenceRE( $oldWeb, $ot, nosot => 1 );
                $text =~ s/($re)/_doReplace($1, $newWeb, $nt)/ge;
            }

            # Handle Set/Local statements inline
            $re = _getReferenceRE(
                $oldWeb, $ot,
                nosot    => 1,
                template => 1
            );

            # SMELL:  This will rewrite qualified topic names to be unqualified
            # But regex is matching too much to use the _doReplace routine
            $text =~ s/$re/$1$nt/g;
        }
    }

    # Now URL form
    $repl = "/$newWeb/$newTopic";
    $re = _getReferenceRE( $oldWeb, $oldTopic, url => 1 );
    $text =~ s/$re/$repl/g;

    return $text;
}

sub _doReplace {
    my ( $match, $web, $repl ) = @_;

    # TWikibug:Item4661 If there is a web defined in the match, then
    # make sure there's a web defined in the replacement.
    if ( $match =~ m/\./ && $repl !~ /\./ ) {
        $repl = $web . '.' . $repl;
    }
    return $repl;
}

# _replaceWebReferences( $text, \%options ) -> $text
#
# Callback designed for use with forEachLine, to replace text references
# to a web.
# \%options contains:
#   * =oldWeb= => Web of reference to replace
#   * =newWeb= => Web of new reference
#   * =noautolink => 1  -  Process noautolink blocks as well.
sub _replaceWebReferences {
    my ( $text, $args ) = @_;

    ASSERT( defined $args->{oldWeb} ) if DEBUG;
    ASSERT( defined $args->{newWeb} ) if DEBUG;
    ASSERT( $text !~ /$MARKER/ )      if DEBUG;

    my $newWeb = $args->{newWeb};
    my $oldWeb = $args->{oldWeb};

    return $text if $oldWeb eq $newWeb;

    # Replace stand-alone web references with $MARKER, to
    # prevent matching $newWeb as a URL fragment in the second RE
    my $re = _getReferenceRE( $oldWeb, undef, %$args );
    $text =~ s/$re/$MARKER$1/g;

    # Now do URLs.
    $args->{url} = 1;
    $re = _getReferenceRE( $oldWeb, undef, %$args );
    $text =~ s#$re#/$newWeb/#g;
    $args->{url} = 0;

    # Finally do the marker.
    $text =~ s/$MARKER/$newWeb/g;

    return $text;
}

# Display screen so user can decide on new web, topic, attachment names.
sub _newTopicOrAttachmentScreen {
    my ( $session, $from, $to, $attachment, $toattachment, $confirm ) = @_;

    my $query          = $session->{cgiQuery};
    my $tmpl           = '';
    my $currentWebOnly = $query->param('currentwebonly') || '';

    if ($attachment) {
        my $tmplname = $query->param('template');
        $tmpl =
          $session->templates->readTemplate( $tmplname || 'moveattachment' );
    }
    elsif ($confirm) {
        $tmpl = $session->templates->readTemplate('renameconfirm');
    }
    elsif ($to->web eq $Foswiki::cfg{TrashWebName}
        && $from->web ne $Foswiki::cfg{TrashWebName} )
    {
        $tmpl = $session->templates->readTemplate('renamedelete');
    }
    else {
        $tmpl = $session->templates->readTemplate('rename');
    }

    if ( $to->web eq $Foswiki::cfg{TrashWebName} ) {

        # Deleting an attachment or a topic
        if ($attachment) {

            # Trashing an attachment; look for a non-conflicting name in the
            # trash web
            my $base = $toattachment || $attachment;
            my $ext = '';
            if ( $base =~ s/^(.*)(\..*?)$/$1_/ ) {
                $ext = $2;
            }
            my $n = 1;
            while ( $to->hasAttachment($toattachment) ) {
                $toattachment = $base . $n . $ext;
                $n++;
            }
        }
        else {

            # Trashing a topic; look for a non-conflicting name in the
            # trash web
            my $renamedTopic = $from->web . $to->topic;
            $renamedTopic =~ s/\///g;
            my $n    = 1;
            my $base = $to->topic;
            while ( $session->topicExists( $to->web, $renamedTopic ) ) {
                $renamedTopic = $base . $n;
                $n++;
            }
            $to = Foswiki::Meta->new( $session, $to->web, $renamedTopic );
        }
    }

    $attachment   = '' if not defined $attachment;
    $toattachment = '' if not defined $toattachment;

    $attachment   = Foswiki::entityEncode($attachment);
    $toattachment = Foswiki::entityEncode($toattachment);

    $tmpl =~ s/%FILENAME%/$attachment/g;
    $tmpl =~ s/%NEW_FILENAME%/$toattachment/g;
    $tmpl =~ s/%NEW_WEB%/$to->web()/ge;
    $tmpl =~ s/%NEW_TOPIC%/$to->topic()/ge;

    if ( !$attachment ) {
        my $refs;
        my $search      = '';
        my $resultCount = 0;
        my $isDelete =
          (      $to->web eq $Foswiki::cfg{TrashWebName}
              && $from->web ne $Foswiki::cfg{TrashWebName} );
        my $checkboxAttrs = {
            type  => 'checkbox',
            class => 'foswikiCheckBox foswikiGlobalCheckable',
            name  => 'referring_topics'
        };
        $checkboxAttrs->{checked} = 'checked' if !$isDelete;

        if ($currentWebOnly) {
            $search = $session->i18n->maketext('(skipped)');
        }
        else {
            if ( $tmpl =~ m/%GLOBAL_SEARCH%/ ) {
                $refs = _getReferringTopics( $session, $from, 1 );
                $resultCount += keys %$refs;
                foreach my $entry ( sort keys %$refs ) {
                    $checkboxAttrs->{value} = $entry;
                    $search .= CGI::div( { class => 'foswikiTopRow' },
                        CGI::input($checkboxAttrs) . " [[$entry]] " );
                }
                unless ($search) {
                    $search = ( $session->i18n->maketext('(none)') );
                }
            }
        }
        $tmpl =~ s/%GLOBAL_SEARCH%/$search/;

        if ( $tmpl =~ m/%LOCAL_SEARCH%/ ) {
            $refs = _getReferringTopics( $session, $from, 0 );
            $resultCount += keys %$refs;
            $search = '';
            foreach my $entry ( sort keys %$refs ) {
                $checkboxAttrs->{value} = $entry;
                $search .= CGI::div( { class => 'foswikiTopRow' },
                    CGI::input($checkboxAttrs) . " [[$entry]] " );
            }
            unless ($search) {
                $search = ( $session->i18n->maketext('(none)') );
            }
            $tmpl =~ s/%LOCAL_SEARCH%/$search/g;
        }
        $tmpl =~ s/%SEARCH_COUNT%/$resultCount/g;
    }

    $tmpl = $from->expandMacros($tmpl);
    $tmpl = $from->renderTML($tmpl);

    $session->writeCompletePage($tmpl);
}

# Display screen so user can decide on new web.
# a Refresh mechanism is provided after submission of the form
# so the user can refresh the display until lease conflicts
# are resolved.

sub _newWebScreen {
    my ( $session, $from, $toWeb, $confirm, $infoRef ) = @_;

    $toWeb = $from->web() unless ($toWeb);

    my @newParentPath = split( '/', $toWeb );
    my $newSubWeb     = pop(@newParentPath);
    my $newParent     = join( '/', @newParentPath );

    my $tmpl = '';
    if ( $confirm eq 'getlock' ) {
        $tmpl = $session->templates->readTemplate('renamewebconfirm');
    }
    elsif ( $toWeb eq $Foswiki::cfg{TrashWebName} ) {
        $tmpl = $session->templates->readTemplate('renamewebdelete');
    }
    else {
        $tmpl = $session->templates->readTemplate('renameweb');
    }

    # Trashing a web; look for a non-conflicting name
    if ( $toWeb eq $Foswiki::cfg{TrashWebName} ) {
        my $renamedWeb = $Foswiki::cfg{TrashWebName} . '/' . $from->web;
        my $n          = 1;
        my $base       = $renamedWeb;
        while ( $session->webExists($renamedWeb) ) {
            $renamedWeb = $base . $n;
            $n++;
        }
        $toWeb = $renamedWeb;
    }

    $tmpl =~ s/%NEW_PARENTWEB%/$newParent/g;
    $tmpl =~ s/%NEW_SUBWEB%/$newSubWeb/g;
    $tmpl =~ s/%TOPIC%/$Foswiki::cfg{HomeTopicName}/g;

    my ( $movelocked, $refdenied, $reflocked ) = ( '', '', '' );
    $movelocked = join( ', ', @{ $infoRef->{movelocked} } )
      if $infoRef->{movelocked};
    $movelocked = ( $session->i18n->maketext('(none)') ) unless $movelocked;
    $refdenied = join( ', ', @{ $infoRef->{modifydenied} } )
      if $infoRef->{modifydenied};
    $refdenied = ( $session->i18n->maketext('(none)') ) unless $refdenied;
    $reflocked = join( ', ', @{ $infoRef->{modifylocked} } )
      if $infoRef->{modifylocked};
    $reflocked = ( $session->i18n->maketext('(none)') ) unless $reflocked;

    $tmpl =~ s/%MOVE_LOCKED%/$movelocked/;
    $tmpl =~ s/%REF_DENIED%/$refdenied/;
    $tmpl =~ s/%REF_LOCKED%/$reflocked/;

    my $refresh_prompt = ( $session->i18n->maketext('Refresh') );
    my $submit_prompt  = ( $session->i18n->maketext('Move/Rename') );

    my $submitAction =
      ( $movelocked || $reflocked ) ? $refresh_prompt : $submit_prompt;
    $tmpl =~ s/%RENAMEWEB_SUBMIT%/$submitAction/g;

    my $refs;
    my $search      = '';
    my $resultCount = 0;

    $refs = ${$infoRef}{referring}{refs1};
    $resultCount += keys %$refs;
    foreach my $entry ( sort keys %$refs ) {
        $search .= CGI::div(
            { class => 'foswikiTopRow' },
            CGI::input(
                {
                    type    => 'checkbox',
                    class   => 'foswikiCheckBox foswikiGlobalCheckable',
                    name    => 'referring_topics',
                    value   => $entry,
                    checked => 'checked'
                }
              )
              . " [[$entry]] "
        );
    }
    unless ($search) {
        $search = ( $session->i18n->maketext('(none)') );
    }
    $tmpl =~ s/%GLOBAL_SEARCH%/$search/;

    $refs = $infoRef->{referring}{refs0};
    $resultCount += keys %$refs;
    $search = '';
    foreach my $entry ( sort keys %$refs ) {
        $search .= CGI::div(
            { class => 'foswikiTopRow' },
            CGI::input(
                {
                    type    => 'checkbox',
                    class   => 'foswikiCheckBox foswikiGlobalCheckable',
                    name    => 'referring_topics',
                    value   => $entry,
                    checked => 'checked'
                }
              )
              . " [[$entry]] "
        );
    }
    unless ($search) {
        $search = ( $session->i18n->maketext('(none)') );
    }
    $tmpl =~ s/%LOCAL_SEARCH%/$search/g;
    $tmpl =~ s/%SEARCH_COUNT%/$resultCount/g;

    my $fromWebHome =
      new Foswiki::Meta( $session, $from->web, $Foswiki::cfg{HomeTopicName} );
    $tmpl = $fromWebHome->expandMacros($tmpl);
    $tmpl = $fromWebHome->renderTML($tmpl);

    $session->writeCompletePage($tmpl);
}

# Returns the list of topics that have been found that refer
# to the renamed topic. Returns a list of topics.
sub _getReferringTopicsListFromURL {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my @result;
    foreach my $topic ( $query->multi_param('referring_topics') ) {
        my ( $itemWeb, $itemTopic ) =
          $session->normalizeWebTopicName( '', $topic );

        # Check validity of web and topic
        $itemWeb = Foswiki::Sandbox::untaint( $itemWeb,
            \&Foswiki::Sandbox::validateWebName );
        $itemTopic = Foswiki::Sandbox::untaint( $itemTopic,
            \&Foswiki::Sandbox::validateTopicName );

        # Skip web.topic that fails validation
        next unless ( $itemWeb && $itemTopic );

        ASSERT( $itemWeb !~ /\./ ) if DEBUG;    # cos we will split on . later
        push @result, "$itemWeb.$itemTopic";
    }
    return \@result;
}

# _getReferenceRE($web, $topic, %options) -> $re
#
#    * $web, $topic - specify the topic being referred to, or web if $topic is
#      undef.
#    * %options - the following options are available
#       * =interweb= - if true, then fully web-qualified references are required.
#       * =grep= - if true, generate a GNU-grep compatible RE instead of the
#         default Perl RE.
#       * =nosot= - If true, do not generate "Spaced out text" match
#       * =template= - If true, match for template setting in Set/Local statement
#       * =in_noautolink= - Only match explicit (squabbed) WikiWords.   Used in <noautolink> blocks
#       * =inMeta= - Re should match exact string. No delimiters needed.
#       * =url= - if set, generates an expression that will match a Foswiki
#         URL that points to the web/topic, instead of the default which
#         matches topic links in plain text.
# Generate a regular expression that can be used to match references to the
# specified web/topic. Note that the resultant RE will only match fully
# qualified (i.e. with web specifier) topic names and topic names that
# are wikiwords in text. Works for spaced-out wikiwords for topic names.
#
# The RE returned is designed to be used with =s///=

sub _getReferenceRE {
    my ( $web, $topic, %options ) = @_;

    my $matchWeb = $web;

    # Convert . and / to [./] (subweb separators) and quote
    # special characters
    $matchWeb =~ s#[./]#\0#g;
    $matchWeb = quotemeta($matchWeb);

# SMELL: Item10176 -  Adding doublequote as a WikiWord delimiter.   This causes non-linking quoted
# WikiWords in tml to be incorrectly renamed.   But does handle quoted topic names inside macro parameters.
# But this doesn't really fully fix the issue - $quotWikiWord for example.
    my $reSTARTWW = qr/^|(?<=[\s"\*=_\(])/m;
    my $reENDWW   = qr/$|(?=[\s"\*#=_,.;:!?)])/m;

    # \0 is escaped by quotemeta so we need to match the escape
    $matchWeb =~ s#\\\0#[./]#g;

    # Item1468/5791 - Quote special characters
    $topic = quotemeta($topic) if defined $topic;

    # Note use of \b to match the empty string at the
    # edges of a word.
    my ( $bow, $eow, $forward, $back ) = ( '\b_?', '_?\b', '?=', '?<=' );
    if ( $options{grep} ) {
        $bow     = '\b_?';
        $eow     = '_?\b';
        $forward = '';
        $back    = '';
    }
    my $squabo = "($back\\[\\[)";
    my $squabc = "($forward(?:#.*?)?\\][][])";

    my $re = '';

    if ( $options{url} ) {

        # URL fragment. Assume / separator (while . is legal, it's
        # undocumented and is not common usage)
        $re = "/$web/";
        $re .= $topic . $eow if $topic;
    }
    else {
        if ( defined($topic) ) {

            my $sot;
            unless ( $options{nosot} ) {

                # Work out spaced-out version (allows lc first chars on words)
                $sot = Foswiki::spaceOutWikiWord( $topic, ' *' );
                if ( $sot ne $topic ) {
                    $sot =~ s/\b([a-zA-Z])/'['.uc($1).lc($1).']'/ge;
                }
                else {
                    $sot = undef;
                }
            }

            if ( $options{interweb} ) {

                # Require web specifier
                if ( $options{grep} ) {
                    $re = "$bow$matchWeb\\.$topic$eow";
                }
                elsif ( $options{template} ) {

# $1 is used in replace.  Can't use lookbehind because of variable length restriction
                    $re = '('
                      . $Foswiki::regex{setRegex}
                      . '(?:VIEW|EDIT)_TEMPLATE\s*=\s*)('
                      . $matchWeb . '\\.'
                      . $topic . ')\s*$';
                }
                elsif ( $options{in_noautolink} ) {
                    $re = "$squabo$matchWeb\\.$topic$squabc";
                }
                else {
                    $re = "$reSTARTWW$matchWeb\\.$topic$reENDWW";
                }

                # Matching of spaced out topic names.
                if ($sot) {

                    # match spaced out in squabs only
                    $re .= "|$squabo$matchWeb\\.$sot$squabc";
                }
            }
            else {

                # Optional web specifier - but *only* if the topic name
                # is a wikiword
                if ( $topic =~ m/$Foswiki::regex{wikiWordRegex}/ ) {

                    # Bit of jigger-pokery at the front to avoid matching
                    # subweb specifiers
                    if ( $options{grep} ) {
                        $re = "(($back\[^./])|^)$bow($matchWeb\\.)?$topic$eow";
                    }
                    elsif ( $options{template} ) {

# $1 is used in replace.  Can't use lookbehind because of variable length restriction
                        $re = '('
                          . $Foswiki::regex{setRegex}
                          . '(?:VIEW|EDIT)_TEMPLATE\s*=\s*)'
                          . "($matchWeb\\.)?$topic" . '\s*$';
                    }
                    elsif ( $options{in_noautolink} ) {
                        $re = "$squabo($matchWeb\\.)?$topic$squabc";
                    }
                    else {
                        $re = "$reSTARTWW($matchWeb\\.)?$topic$reENDWW";
                    }

                    if ($sot) {

                        # match spaced out in squabs only
                        $re .= "|$squabo($matchWeb\\.)?$sot$squabc";
                    }
                }
                else {
                    if ( $options{inMeta} ) {
                        $re = "^($matchWeb\\.)?$topic\$"
                          ;  # Updating a META item,  Exact match, no delimiters
                    }
                    else {

                        # Non-wikiword; require web specifier or squabs
                        $re = "$squabo$topic$squabc";    # Squabbed topic
                        $re .= "|\"($matchWeb\\.)?$topic\""
                          ;    # Quoted string in Meta and Macros
                        $re .= "|(($back\[^./])|^)$bow$matchWeb\\.$topic$eow"
                          unless ( $options{in_noautolink} )
                          ;    # Web qualified topic outside of autolink blocks.
                    }
                }
            }
        }
        else {

            # Searching for a web
            # SMELL:  Does this web search also need to allow for quoted
            # "Web.Topic" strings found in macros and META usage?

            if ( $options{interweb} ) {

                if ( $options{in_noautolink} ) {

                    # web name used to refer to a topic
                    $re = $squabo . $matchWeb . "(\.[[:alnum:]]+)" . $squabc;
                }
                else {
                    $re = $bow . $matchWeb . "(\.[[:alnum:]]+)" . $eow;
                }
            }
            else {

                # most general search for a reference to a topic or subweb
                # note that Foswiki::UI::Rename::_replaceWebReferences()
                # uses $1 from this regex
                if ( $options{in_noautolink} ) {
                    $re =
                        $squabo
                      . $matchWeb
                      . "(([\/\.][[:upper:]]"
                      . "[[:alnum:]_]*)+"
                      . "\.[[:alnum:]]*)"
                      . $squabc;
                }
                else {
                    $re =
                        $bow
                      . $matchWeb
                      . "(([\/\.][[:upper:]]"
                      . "[[:alnum:]_]*)+"
                      . "\.[[:alnum:]]*)"
                      . $eow;
                }
            }
        }
    }

#my $optsx = '';
#$optsx .= "NOSOT=$options{nosot} " if ($options{nosot});
#$optsx .= "GREP=$options{grep} " if ($options{grep});
#$optsx .= "URL=$options{url} " if ($options{url});
#$optsx .= "INNOAUTOLINK=$options{in_noautolink} " if ($options{in_noautolink});
#$optsx .= "INTERWEB=$options{interweb} " if ($options{interweb});
#print STDERR "ReferenceRE returns $re $optsx  \n";
    return $re;
}

#   * =$session= - the session
#   * =$om= - web or topic to search for
#   * =$allWebs= - 0 to search $web only. 1 to search all webs
# _except_ $web.
sub _getReferringTopics {
    my ( $session, $om, $allWebs ) = @_;
    my $renderer = $session->renderer;
    require Foswiki::Render;

    my @webs = ( $om->web );

    if ($allWebs) {
        my $root = Foswiki::Meta->new($session);
        my $it   = $root->eachWeb(1);
        while ( $it->hasNext() ) {
            push( @webs, $it->next() );
        }
    }
    my %results;
    foreach my $searchWeb (@webs) {
        my $interWeb = ( $searchWeb ne $om->web() );
        next if ( $allWebs && !$interWeb );

        my $webObject = Foswiki::Meta->new( $session, $searchWeb );
        next unless $webObject->haveAccess('VIEW');

        # Search for both the foswiki form and the URL form
        my $searchString = _getReferenceRE(
            $om->web(), $om->topic(),
            grep     => 1,
            interweb => $interWeb
        );
        $searchString .= '|'
          . _getReferenceRE(
            $om->web(), $om->topic(),
            grep     => 1,
            interweb => $interWeb,
            url      => 1
          );

        # If the topic is a Template,  search for set or meta that references it
        if ( $om->topic() && $om->topic() =~ m/(.*)Template$/ ) {
            my $refre = '(VIEW|EDIT)_TEMPLATE.*';
            $refre .= _getReferenceRE(
                $om->web(), $1,
                grep     => 1,
                nosot    => 1,
                interweb => $interWeb,
            );
            $searchString .= '|' . $refre;
        }

        my $options =
          { casesensitive => 1, type => 'regex', web => $searchWeb };
        my $query = $session->search->parseSearch( $searchString, $options );
        my $matches = Foswiki::Meta::query( $query, undef, $options );

        while ( $matches->hasNext ) {
            my $webtopic = $matches->next;
            my ( $web, $searchTopic ) =
              $session->normalizeWebTopicName( $searchWeb, $webtopic );
            next
              if ( $searchWeb eq $om->web
                && $om->topic
                && $searchTopic eq $om->topic );

            # Individual topics may be view restricted. Only return
            # those we can see.
            my $m = Foswiki::Meta->new( $session, $searchWeb, $searchTopic );
            next unless $m->haveAccess('VIEW');

            $results{ $searchWeb . '.' . $searchTopic } = 1;
        }
    }
    return \%results;
}

# Update pages that refer to a page that is being renamed/moved.
# SMELL: this might be done more efficiently if it was behind the
# store interface
sub _updateReferringTopics {
    my ( $session, $refs, $fn, $options ) = @_;

    my $renderer = $session->renderer;
    require Foswiki::Render;

    $options->{pre} = 1;    # process lines in PRE blocks

    foreach my $item (@$refs) {
        my ( $itemWeb, $itemTopic ) = split( /\./, $item, 2 );

        if ( $session->topicExists( $itemWeb, $itemTopic ) ) {
            my $topicObject =
              Foswiki::Meta->load( $session, $itemWeb, $itemTopic );
            unless ( $topicObject->haveAccess('CHANGE') ) {
                $session->logger->log( 'warning',
                    "Access to CHANGE $itemWeb.$itemTopic is denied: "
                      . $Foswiki::Meta::reason );
                next;
            }
            $options->{inWeb} = $itemWeb;
            my $text =
              $renderer->forEachLine( $topicObject->text(), $fn, $options );
            $options->{inMeta} = 1;
            $topicObject->forEachSelectedValue(
                qw/^(FIELD|FORM|PREFERENCE|TOPICPARENT)$/,
                undef, $fn, $options );
            $options->{inMeta} = 0;
            $topicObject->text($text);
            $topicObject->save( minor => 1 );
        }
    }
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
