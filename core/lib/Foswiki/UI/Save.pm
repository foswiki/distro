# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Save

UI delegate for save function

=cut

package Foswiki::UI::Save;

use strict;
use Error qw( :try );
use Assert;

require Foswiki;
require Foswiki::UI;
require Foswiki::Meta;
require Foswiki::OopsException;

# Used by save and preview
sub buildNewTopic {
    my ( $session, $script ) = @_;

    my $query    = $session->{request};
    my $webName  = $session->{webName};
    my $topic    = $session->{topicName};
    my $store    = $session->{store};
    my $revision = $query->param('rev') || undef;

    unless ( scalar( $query->param() ) ) {

        # insufficient parameters to save
        throw Foswiki::OopsException(
            'attention',
            def    => 'bad_script_parameters',
            web    => $session->{webName},
            topic  => $session->{topicName},
            params => [$script]
        );
    }

    Foswiki::UI::checkWebExists( $session, $webName, $topic, 'save' );

    my $topicExists = $store->topicExists( $webName, $topic );

    # Prevent saving existing topic?
    my $onlyNewTopic = Foswiki::isTrue( $query->param('onlynewtopic') );
    if ( $onlyNewTopic && $topicExists ) {

        # Topic exists and user requested oops if it exists
        throw Foswiki::OopsException(
            'attention',
            def   => 'topic_exists',
            web   => $webName,
            topic => $topic
        );
    }

    # prevent non-Wiki names?
    my $onlyWikiName = Foswiki::isTrue( $query->param('onlywikiname') );
    if (   ($onlyWikiName)
        && ( !$topicExists )
        && ( !Foswiki::isValidTopicName($topic) ) )
    {

        # do not allow non-wikinames
        throw Foswiki::OopsException(
            'attention',
            def    => 'not_wikiword',
            web    => $webName,
            topic  => $topic,
            params => [$topic]
        );
    }

    my $user = $session->{user};
    Foswiki::UI::checkAccess( $session, $webName, $topic, 'CHANGE', $user );

    my $saveOpts = {};
    $saveOpts->{minor} = 1 if $query->param('dontnotify');
    my $originalrev = $query->param('originalrev');    # rev edit started on

    # Populate the new meta data
    my $newMeta = new Foswiki::Meta( $session, $webName, $topic );

    my ( $prevMeta,     $prevText );
    my ( $templateText, $templateMeta );
    my $templatetopic = $query->param('templatetopic');
    my $templateweb   = $webName;

    if ($templatetopic) {
        ( $templateweb, $templatetopic ) =
          $session->normalizeWebTopicName( $templateweb, $templatetopic );

        if ( $store->topicExists( $templateweb, $templatetopic ) ) {
            # Validated
            $templateweb =
              Foswiki::Sandbox::untaintUnchecked( $templateweb );
            $templatetopic =
              Foswiki::Sandbox::untaintUnchecked( $templatetopic );
        } else {
            throw Foswiki::OopsException(
                'attention',
                def   => 'no_such_topic_template',
                web   => $templateweb,
                topic => $templatetopic
            );
        }
    }

    if ($topicExists) {
        ( $prevMeta, $prevText ) =
          $store->readTopic( $user, $webName, $topic, $revision );
        if ($prevMeta) {
            foreach my $k ( keys %$prevMeta ) {
                unless ( $k =~ /^_/
                    || $k eq 'FORM'
                    || $k eq 'TOPICPARENT'
                    || $k eq 'FIELD' )
                {
                    $newMeta->copyFrom( $prevMeta, $k );
                }
            }
        }
    }
    elsif ($templatetopic) {
        ( $templateMeta, $templateText ) =
          $store->readTopic( $user, $templateweb, $templatetopic, $revision );
        $templateText = '' if $query->param('newtopic');    # created by edit
        $templateText =
          $session->expandVariablesOnTopicCreation( $templateText, $user,
            $webName, $topic );
        foreach my $k ( keys %$templateMeta ) {
            unless ( $k =~ /^_/
                || $k eq 'FORM'
                || $k eq 'TOPICPARENT'
                || $k eq 'FIELD'
                || $k eq 'TOPICMOVED' )
            {
                $newMeta->copyFrom( $templateMeta, $k );
            }
        }

        # topic creation, there is no original rev
        $originalrev = 0;
    }

    # Determine the new text
    my $newText = $query->param('text');

    my $forceNewRev = $query->param('forcenewrevision');
    $saveOpts->{forcenewrevision} = $forceNewRev;
    my $newParent = $query->param('topicparent');

    if ( defined($newText) ) {

        # text is defined in the query, save that text
        $newText =~ s/\r//g;
        $newText .= "\n" unless $newText =~ /\n$/s;

    }
    elsif ( defined $templateText ) {

        # no text in the query, but we have a templatetopic
        $newText     = $templateText;
        $originalrev = 0;               # disable merge

    }
    else {
        $newText = '';
        if ( defined $prevText ) {
            $newText     = $prevText;
            $originalrev = 0;           # disable merge
        }
    }

    my $mum;
    if ($newParent) {
        if ( $newParent ne 'none' ) {
            $mum = { 'name' => $newParent };
        }
    }
    elsif ($templateMeta) {
        $mum = $templateMeta->get('TOPICPARENT');
    }
    elsif ($prevMeta) {
        $mum = $prevMeta->get('TOPICPARENT');
    }
    $newMeta->put( 'TOPICPARENT', $mum ) if $mum;

    my $formName = $query->param('formtemplate');
    my $formDef;
    my $copyMeta;

    if ($formName) {

        # new form, default field values will be null
        $formName = '' if ( $formName eq 'none' );
    }
    elsif ($templateMeta) {

        # populate the meta-data with field values from the template
        $formName = $templateMeta->get('FORM');
        $formName = $formName->{name} if $formName;
        $copyMeta = $templateMeta;
    }
    elsif ($prevMeta) {

        # populate the meta-data with field values from the existing topic
        $formName = $prevMeta->get('FORM');
        $formName = $formName->{name} if $formName;
        $copyMeta = $prevMeta;
    }

    if ($formName) {
        require Foswiki::Form;
        $formDef = new Foswiki::Form( $session, $webName, $formName );
        unless ($formDef) {
            unless ($prevMeta) {
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'no_form_def',
                    web    => $session->{webName},
                    topic  => $session->{topicName},
                    params => [ $webName, $formName ]
                );
            }

            # Recreate the form fields from the previous rev of the topic.
            $formDef =
              new Foswiki::Form( $session, $webName, $formName, $prevMeta );
        }
        $newMeta->put( 'FORM', { name => $formName } );
    }
    if ( $copyMeta && $formDef ) {

        # Copy existing fields into new form, filtering on the
        # known field names so we don't copy dead data. Though we
        # really should, of course. That comes later.
        my $filter = join( '|',
            map    { $_->{name} }
              grep { $_->{name} } @{ $formDef->getFields() } );
        $newMeta->copyFrom( $copyMeta, 'FIELD', qr/^($filter)$/ );
    }
    if ($formDef) {

        # override with values from the query
        my ( $seen, $missing ) =
          $formDef->getFieldValuesFromQuery( $query, $newMeta );
        if ( $seen && @$missing ) {

            # chuck up if there is at least one field value defined in the
            # query and a mandatory field was not defined in the
            # query or by an existing value.
            # Item5428: clean up <nop>'s
            @$missing = map {
                s/<nop>//g;
                $_
            } @$missing;
            throw Foswiki::OopsException(
                'attention',
                def    => 'mandatory_field',
                web    => $session->{webName},
                topic  => $session->{topicName},
                params => [ join( ' ', @$missing ) ]
            );
        }
    }

    my $merged;

    # If the topic exists, see if we need to merge
    if ( $topicExists && $originalrev ) {
        my ( $orev, $odate );
        if ( $originalrev =~ /^(\d+)_(\d+)$/ ) {
            ( $orev, $odate ) = ( $1, $2 );
        }
        elsif ( $originalrev =~ /^\d+$/ ) {
            $orev = $originalrev;
        }
        else {
            $orev = 0;
        }
        my ( $date, $author, $rev, $comment ) = $newMeta->getRevisionInfo();

        # If the last save was by me, don't merge
        if ( ( $orev ne $rev || $odate && $date && $odate ne $date )
            && $author ne $user )
        {

            require Foswiki::Merge;

            my $pti = $prevMeta->get('TOPICINFO');
            if (   $pti
                && $pti->{reprev}
                && $pti->{version}
                && $pti->{reprev} == $pti->{version} )
            {

                # If the ancestor revision was generated by a reprev,
                # then the original is lost and we can't 3-way merge

                $session->{plugins}
                  ->dispatch( 'beforeMergeHandler', $newText, $pti->{version},
                    $prevText, undef, undef, $webName, $topic );

                $newText =
                  Foswiki::Merge::merge2( $pti->{version}, $prevText, $rev,
                    $newText, '.*?\n', $session );
            }
            else {

                # common ancestor; we can 3-way merge
                my ( $ancestorMeta, $ancestorText ) =
                  $store->readTopic( undef, $webName, $topic, $orev );

                $session->{plugins}
                  ->dispatch( 'beforeMergeHandler', $newText, $rev, $prevText,
                    $orev, $ancestorText, $webName, $topic );

                $newText =
                  Foswiki::Merge::merge3( $orev, $ancestorText, $rev, $prevText,
                    'new', $newText, '.*?\n', $session );
            }
            if ( $formDef && $prevMeta ) {
                $newMeta->merge( $prevMeta, $formDef );
            }
            $merged =
              [ $orev, $session->{users}->getWikiName($author), $rev || 1 ];
        }
    }

    return ( $newMeta, $newText, $saveOpts, $merged );
}

=begin TML

---++ StaticMethod save($session)

Command handler for =save= command.
This method is designed to be
invoked via the =UI::run= method.

See System.CommandAndCGIScripts for details of parameters.

Note: =cmd= has been deprecated in favour of =action=. It will be deleted at
some point.

=cut

sub save {
    my $session = shift;

    my $query = $session->{request};
    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    my $store = $session->{store};
    my $user  = $session->{user};

    # Do not remove, keep as undocumented feature for compatibility with
    # TWiki 4.0.x: Allow for dynamic topic creation by replacing strings
    # of at least 10 x's XXXXXX with a next-in-sequence number.
    # See Codev.AllowDynamicTopicNameCreation
    if ( $topic =~ /X{10}/ ) {
        my $n         = 0;
        my $baseTopic = $topic;
        $store->clearLease( $web, $baseTopic );
        do {
            $topic = $baseTopic;
            $topic =~ s/X{10}X*/$n/e;
            $n++;
        } while ( $store->topicExists( $web, $topic ) );
        $session->{topicName} = $topic;
    }

    # Allow for more flexible topic creation with sortable names and
    # better performance. See Codev.AutoIncTopicNameOnSave
    if ( $topic =~ /AUTOINC([0-9]+)/ ) {
        my $start     = $1;
        my $baseTopic = $topic;
        $store->clearLease( $web, $baseTopic );
        my $nameFilter = $topic;
        $nameFilter =~ s/AUTOINC([0-9]+)/([0-9]+)/;
        my @list =
          sort { $a <=> $b }
          map { s/^$nameFilter$/$1/; s/^0*([0-9])/$1/; $_ }
          grep { /^$nameFilter$/ } $store->getTopicNames($web);
        if ( scalar @list ) {

            # find last one, and increment by one
            my $next = $list[$#list] + 1;
            my $len  = length($start);
            $start =~ s/^0*([0-9])/$1/;    # cut leading zeros
            $next = $start if ( $start > $next );
            my $pad = $len - length($next);
            if ( $pad > 0 ) {
                $next = '0' x $pad . $next;    # zero-pad
            }
            $topic =~ s/AUTOINC[0-9]+/$next/;
        }
        else {

            # first auto-inc topic
            $topic =~ s/AUTOINC[0-9]+/$start/;
        }
        $session->{topicName} = $topic;
    }

    my $saveaction = '';
    foreach my $action qw( save checkpoint quietsave cancel preview
      addform replaceform delRev repRev ) {
        if ( $query->param( 'action_' . $action ) )
        {
            $saveaction = $action;
            last;
        }
      }

      # the 'action' parameter has been deprecated, though is still available
      # for compatibility with old templates.
      if ( !$saveaction && $query->param('action') ) {
        $saveaction = lc( $query->param('action') );
        $session->logger->log('warning',<<WARN);
Use of deprecated "action" parameter to "save". Correct your templates!
WARN

        # handle old values for form-related actions:
        $saveaction = 'addform'     if ( $saveaction eq 'add form' );
        $saveaction = 'replaceform' if ( $saveaction eq 'replace form...' );
    }

    if ( $saveaction eq 'cancel' ) {
        my $lease = $store->getLease( $web, $topic );
        if ( $lease && $lease->{user} eq $user ) {
            $store->clearLease( $web, $topic );
        }

        # redirect to a sensible place (a topic that exists)
        my ( $w, $t ) = ( '', '' );
        foreach my $test ( $topic, $query->param('topicparent'),
            $Foswiki::cfg{HomeTopicName} )
        {
            ( $w, $t ) = $session->normalizeWebTopicName( $web, $test );
            last if ( $store->topicExists( $w, $t ) );
        }
        my $viewURL = $session->getScriptUrl( 1, 'view', $w, $t );
        $session->redirect( $session->redirectto($viewURL) );

        return;
    }

    if ( $saveaction eq 'preview' ) {
        require Foswiki::UI::Preview;
        Foswiki::UI::Preview::preview($session);
        return;
    }

    # Do this *before* we do any query parameter rewriting
    Foswiki::UI::checkValidationKey($session, 'save', $web, $topic);

    my $editaction = lc( $query->param('editaction') ) || '';
    my $edit       = $query->param('edit')             || 'edit';
    my $editparams = $query->param('editparams')       || '';

    ## SMELL: The form affecting actions do not preserve edit and editparams
    if (   $saveaction eq 'addform'
        || $saveaction eq 'replaceform'
        || $saveaction eq 'preview' && $query->param('submitChangeForm') )
    {
        require Foswiki::UI::ChangeForm;
        $session->writeCompletePage(
            Foswiki::UI::ChangeForm::generate(
                $session, $web, $topic, $editaction
            )
        );
        return;
    }

    my $redirecturl;

    if ( $saveaction eq 'checkpoint' ) {
        $query->param( -name => 'dontnotify', -value => 'checked' );
        my $edittemplate = $query->param( 'template' );
        my $editURL = $session->getScriptUrl( 1, $edit, $web, $topic );
        $redirecturl = $editURL . '?t=' . time();
        $redirecturl .= '&redirectto=' . $query->param('redirectto')
          if $query->param('redirectto');

        # select the appropriate edit template
        $redirecturl .= '&action=' . $editaction if $editaction;
        $redirecturl .= '&template=' . $edittemplate if $edittemplate;

        $redirecturl .= '&skin=' . $query->param('skin')
          if $query->param('skin');
        $redirecturl .= '&cover=' . $query->param('cover')
          if $query->param('cover');
        $redirecturl .= '&nowysiwyg=' . $query->param('nowysiwyg')
          if $query->param('nowysiwyg');
        $redirecturl .= '&action=' . $query->param('action')
          if $query->param('action');
        $redirecturl .= $editparams
          if $editparams;    # May contain anchor
        my $lease = $store->getLease( $web, $topic );
        if ( $lease && $lease->{user} eq $user ) {
            $store->setLease( $web, $topic, $user, $Foswiki::cfg{LeaseLength} );
        }

        # drop through
    } else {
         $redirecturl = $session->getScriptUrl( 1, 'view', $web, $topic );
     }

    # Do we have ?redirectto=
    if ($saveaction ne 'checkpoint') {
        $redirecturl = $session->redirectto($redirecturl);
    }

    if ( $saveaction eq 'quietsave' ) {
        $query->param( -name => 'dontnotify', -value => 'checked' );
        $saveaction = 'save';

        # drop through
    }

    if ( $saveaction =~ /^(del|rep)Rev$/ ) {

        # hidden, largely undocumented functions, used by administrators for
        # reverting spammed topics. These functions support rewriting
        # history, in a Joe Stalin kind of way. They should be replaced with
        # mechanisms for hiding revisions.
        $query->param( -name => 'cmd', -value => $saveaction );

        # drop through
    }

    my $saveCmd = $query->param('cmd') || 0;
    if ( $saveCmd && !$session->{users}->isAdmin( $session->{user} ) ) {
        throw Foswiki::OopsException(
            'accessdenied', status => 403,
            def    => 'only_group',
            web    => $web,
            topic  => $topic,
            params => [ $Foswiki::cfg{SuperAdminGroup} ]
        );
    }

    #success - redirect to topic view (unless its a checkpoint save)

    if ( $saveCmd eq 'delRev' ) {

        # delete top revision
        try {
            $store->delRev( $user, $web, $topic );
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

        $session->redirect( $redirecturl );
        return;
    }

    if ( $saveCmd eq 'repRev' ) {

        # replace top revision with the text from the query, trying to
        # make it look as much like the original as possible. The query
        # text is expected to contain %META as well as text.
        my $meta =
          new Foswiki::Meta( $session, $web, $topic, $query->param('text') );
        my $saveOpts = {
            timetravel => 1,
            operation  => 'cmd',
        };

        try {
            $store->repRev( $user, $web, $topic, $meta->text(), $meta,
                $saveOpts );
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

        $session->redirect( $redirecturl);
        return;
    }

    my ( $newMeta, $newText, $saveOpts, $merged ) =
      buildNewTopic( $session, 'save' );

    if ( $saveaction =~ /^(save|checkpoint)$/ ) {
        $session->{plugins}
          ->dispatch( 'afterEditHandler', $newText, $topic, $web, $newMeta );
    }

    try {
        $store->saveTopic( $user, $web, $topic, $newText, $newMeta, $saveOpts );
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

    my $lease = $store->getLease( $web, $topic );

    # clear the lease, if (and only if) we own it
    if ( $lease && $lease->{user} eq $user ) {
        $store->clearLease( $web, $topic );
    }

    if ($merged) {
        throw Foswiki::OopsException(
            'attention', status => 200,
            def    => 'merge_notice',
            web    => $web,
            topic  => $topic,
            params => $merged
        );
    }

    $session->redirect( $redirecturl );
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
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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
