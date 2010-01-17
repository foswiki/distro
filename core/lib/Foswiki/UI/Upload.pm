# See bottom of file for license and copyright information
=begin TML

---+ package Foswiki::UI::Upload

UI delegate for attachment management functions

=cut

package Foswiki::UI::Upload;

use strict;
use Assert;
use Error qw( :try );

require Foswiki;
require Foswiki::UI;
require Foswiki::Sandbox;
require Foswiki::OopsException;

=begin TML

---++ StaticMethod attach( $session )

=attach= command handler.
This method is designed to be
invoked via the =UI::run= method.

Generates a prompt page for adding an attachment.

=cut

sub attach {
    my $session = shift;

    my $query   = $session->{request};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};

    my $fileName = $query->param('filename') || '';
    my $skin = $session->getSkin();

    Foswiki::UI::checkWebExists( $session, $webName, $topic, 'attach' );

    my $tmpl          = '';
    my $text          = '';
    my $meta          = '';
    my $atext         = '';
    my $fileUser      = '';
    my $isHideChecked = '';
    my $users         = $session->{users};

    Foswiki::UI::checkAccess( $session, $webName, $topic, 'CHANGE',
        $session->{user} );
    Foswiki::UI::checkTopicExists( $session, $webName, $topic,
        'upload files to' );

    ( $meta, $text ) =
      $session->{store}->readTopic( $session->{user}, $webName, $topic, undef );
    my $args = $meta->get( 'FILEATTACHMENT', $fileName );
    $args = {
        name    => $fileName,
        attr    => '',
        path    => '',
        comment => ''
      }
      unless ($args);

    if ( $args->{attr} =~ /h/o ) {
        $isHideChecked = 'checked';
    }

    # SMELL: why log attach before post is called?
    # FIXME: Move down, log only if successful (or with error msg?)
    # Attach is a read function, only has potential for a change
    if ( $Foswiki::cfg{Log}{attach} ) {

        # write log entry
        $session->logEvent('attach', $webName . '.' . $topic, $fileName );
    }

    my $fileWikiUser = '';
    if ($fileName) {
        $tmpl = $session->templates->readTemplate( 'attachagain', $skin );
        my $u = $args->{user};
        $fileWikiUser = $users->webDotWikiName($u) if $u;
    }
    else {
        $tmpl = $session->templates->readTemplate( 'attachnew', $skin );
    }
    if ($fileName) {

        # must come after templates have been read
        $atext .= $session->attach->formatVersions( $webName, $topic, %$args );
    }
    $tmpl =~ s/%ATTACHTABLE%/$atext/g;
    $tmpl =~ s/%FILEUSER%/$fileWikiUser/g;
    $tmpl =~ s/%FILENAME%/$fileName/g;
    $session->enterContext( 'can_render_meta', $meta );
    $tmpl = $session->handleCommonTags( $tmpl, $webName, $topic );
    $tmpl = $session->renderer->getRenderedVersion( $tmpl, $webName, $topic );
    $tmpl =~ s/%HIDEFILE%/$isHideChecked/g;
    $tmpl =~ s/%FILEPATH%/$args->{path}/g;
    $args->{comment} = Foswiki::entityEncode( $args->{comment} );
    $tmpl =~ s/%FILECOMMENT%/$args->{comment}/g;

    $session->writeCompletePage($tmpl);
}

=begin TML

---++ StaticMethod upload( $session )

=upload= command handler.
This method is designed to be
invoked via the =UI::run= method.
CGI parameters, passed in $query:

Does the work of uploading an attachment to a topic.

   * =hidefile= - if defined, will not show file in attachment table
   * =filepath= -
   * =filename= -
   * =filecomment= - comment to associate with file in attachment table
   * =createlink= - if defined, will create a link to file at end of topic
   * =changeproperties= -
   * =redirectto= - URL to redirect to after upload. ={AllowRedirectUrl}=
     must be enabled in =configure=. The parameter value can be a
     =TopicName=, a =Web.TopicName=, or a URL. Redirect to a URL only works
     if it is enabled in =configure=, and is ignored if =noredirect= is
     specified.
   * =noredirect= - Normally it will redirect to 'view' when the upload is
     complete, but also designed to be useable for REST-style calling using
     the 'noredirect' parameter. If this parameter is set it will return an
     appropriate HTTP status code and print a message to STDOUT, starting
     with 'OK' on success and 'ERROR' on failure.

=cut

sub upload {
    my $session = shift;

    my $query   = $session->{request};
    if ($query->param('noredirect')) {
        my $message;
        my $status = 200;
        try {
            $message = _upload($session);
        } catch Foswiki::OopsException with {
            my $e = shift;
            $status = $e->{status};
            if ($status >= 400) {
                $message = 'ERROR: '.$e->stringify();
            }
        } catch Foswiki::AccessControlException with {
            my $e = shift;
            $status = 403;
            $message = 'ERROR: '.$e->stringify();
        };
        if ($status < 400) {
            $message = 'OK '.$message;
        };
        $session->{response}->header(
            -status => $status,
            -type => 'text/plain');
        $session->{response}->print($message);
    } else {
        # allow exceptions to propagate
        _upload($session);

        my $nurl = $session->getScriptUrl(
            1, 'view', $session->{webName}, $session->{topicName} );
        $session->redirect( $session->redirectto( $nurl ));
    };
}

# Real work of upload
sub _upload {
    my $session = shift;

    my $query   = $session->{request};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $user    = $session->{user};

    Foswiki::UI::checkValidationKey( $session, 'upload', $webName, $topic );

    my $hideFile    = $query->param('hidefile')    || '';
    my $fileComment = $query->param('filecomment') || '';
    my $createLink  = $query->param('createlink')  || '';
    my $doPropsOnly = $query->param('changeproperties');
    my $filePath    = $query->param('filepath')    || '';
    my $fileName    = $query->param('filename')    || '';
    if ( $filePath && !$fileName ) {
        $filePath =~ m|([^/\\]*$)|;
        $fileName = $1;
    }

    $fileComment =~ s/\s+/ /go;
    $fileComment =~ s/^\s*//o;
    $fileComment =~ s/\s*$//o;
    $fileName    =~ s/\s*$//o;
    $filePath    =~ s/\s*$//o;

    Foswiki::UI::checkWebExists(
        $session, $webName, $topic, 'attach files to' );
    Foswiki::UI::checkTopicExists( $session, $webName, $topic,
                                   'attach files to' );
    Foswiki::UI::checkAccess(
        $session, $webName, $topic, 'CHANGE', $user );

    my $origName = $fileName;
    my $stream;
    my ( $fileSize, $fileDate, $tmpFilePath ) = '';

    unless ($doPropsOnly) {
        my $fh = $query->param('filepath');

        try {
            $tmpFilePath = $query->tmpFileName($fh);
        } catch Error::Simple with {

            # Item5130, Item5133 - Illegal file name, bad path,
            # something like that
            throw Foswiki::OopsException(
                'attention',
                def    => 'zero_size_upload',
                web    => $webName,
                topic  => $topic,
                params => [ ( $filePath || '""' ) ]
               );
        };

        $stream = $query->upload('filepath');
        ( $fileName, $origName ) =
          Foswiki::Sandbox::sanitizeAttachmentName($fileName);

        # check if upload has non zero size
        if ($stream) {
            my @stats = stat $stream;
            $fileSize = $stats[7];
            $fileDate = $stats[9];
        }
        unless ( $fileSize && $fileName ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'zero_size_upload',
                web    => $webName,
                topic  => $topic,
                params => [ ( $filePath || '""' ) ]
               );
        }

        my $maxSize =
          $session->{prefs}->getPreferencesValue('ATTACHFILESIZELIMIT') || 0;
        $maxSize =~ s/\s+$//;
        $maxSize = 0 unless ( $maxSize =~ /([0-9]+)/o );

        if ( $maxSize && $fileSize > $maxSize * 1024 ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'oversized_upload',
                web    => $webName,
                topic  => $topic,
                params => [ $fileName, $maxSize ]
               );
        }
    }
    try {
        $session->{store}->saveAttachment(
            $webName, $topic,
            $fileName,
            $user,
            {
                dontlog     => !$Foswiki::cfg{Log}{upload},
                comment     => $fileComment,
                hide        => $hideFile,
                createlink  => $createLink,
                stream      => $stream,
                filepath    => $filePath,
                filesize    => $fileSize,
                filedate    => $fileDate,
                tmpFilename => $tmpFilePath,
            }
           );
    } catch Error::Simple with {
        throw Foswiki::OopsException(
            'attention',
            def    => 'save_error',
            web    => $webName,
            topic  => $topic,
            params => [ shift->{-text} ]
           );
    };
    close($stream) if $stream;

    if ( $fileName ne $origName ) {
        throw Foswiki::OopsException(
            'attention',
            status => 200,
            def    => 'upload_name_changed',
            web    => $webName,
            topic  => $topic,
            params => [ $origName, $fileName ]
           );
    }

    # generate a message useful for those calling this script
    # from the command line
    return ($doPropsOnly) ? 'properties changed' :
      "$fileName uploaded";
}

1;
__DATA__
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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
