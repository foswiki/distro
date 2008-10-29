# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

=pod

---+ package TWiki::UI::Upload

UI delegate for attachment management functions

=cut

package TWiki::UI::Upload;

use strict;
use Assert;
use Error qw( :try );

require TWiki;
require TWiki::UI;
require TWiki::Sandbox;
require TWiki::OopsException;

=pod

---++ StaticMethod attach( $session )

=attach= command handler.
This method is designed to be
invoked via the =UI::run= method.

Generates a prompt page for adding an attachment.

=cut

sub attach {
    my $session = shift;

    my $query = $session->{request};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    my $fileName = $query->param( 'filename' ) || '';
    my $skin = $session->getSkin();

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'attach' );

    my $tmpl = '';
    my $text = '';
    my $meta = '';
    my $atext = '';
    my $fileUser = '';
    my $isHideChecked = '';
    my $users = $session->{users};

    TWiki::UI::checkMirror( $session, $webName, $topic );

    TWiki::UI::checkAccess( $session, $webName, $topic,
                            'CHANGE', $session->{user} );
    TWiki::UI::checkTopicExists( $session, $webName, $topic,
                                 'upload files to' );

    ( $meta, $text ) =
      $session->{store}->readTopic( $session->{user}, $webName, $topic, undef );
    my $args = $meta->get( 'FILEATTACHMENT', $fileName );
    $args = {
             name => $fileName,
             attr => '',
             path => '',
             comment => ''
            } unless( $args );

    if ( $args->{attr} =~ /h/o ) {
        $isHideChecked = 'checked';
    }

    # SMELL: why log attach before post is called?
    # FIXME: Move down, log only if successful (or with error msg?)
    # Attach is a read function, only has potential for a change
    if( $TWiki::cfg{Log}{attach} ) {
        # write log entry
        $session->writeLog( 'attach', $webName.'.'.$topic, $fileName );
    }

    my $fileWikiUser = '';
    if( $fileName ) {
        $tmpl = $session->templates->readTemplate( 'attachagain', $skin );
        my $u = $args->{user};
        $fileWikiUser = $users->webDotWikiName($u) if $u;
    } else {
        $tmpl = $session->templates->readTemplate( 'attachnew', $skin );
    }
    if ( $fileName ) {
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
    $args->{comment} = TWiki::entityEncode( $args->{comment} );
    $tmpl =~ s/%FILECOMMENT%/$args->{comment}/g;

    $session->writeCompletePage( $tmpl );
}

=pod

---++ StaticMethod upload( $session )

=upload= command handler.
This method is designed to be
invoked via the =UI::run= method.
CGI parameters, passed in $query:

| =hidefile= | if defined, will not show file in attachment table |
| =filepath= | |
| =filename= | |
| =filecomment= | comment to associate with file in attachment table |
| =createlink= | if defined, will create a link to file at end of topic |
| =changeproperties= | |
| =redirectto= | URL to redirect to after upload. ={AllowRedirectUrl}= must be enabled in =configure=. The parameter value can be a =TopicName=, a =Web.TopicName=, or a URL. Redirect to a URL only works if it is enabled in =configure=. |

Does the work of uploading a file to a topic. Designed to be useable for
a crude RPC (it will redirect to the 'view' script unless the
'noredirect' parameter is specified, in which case it will print a message to
STDOUT, starting with 'OK' on success and 'ERROR' on failure.

=cut

sub upload {
    my $session = shift;

    my $query = $session->{request};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $user = $session->{user};

    my $hideFile = $query->param( 'hidefile' ) || '';
    my $fileComment = $query->param( 'filecomment' ) || '';
    my $createLink = $query->param( 'createlink' ) || '';
    my $doPropsOnly = $query->param( 'changeproperties' );
    my $filePath = $query->param( 'filepath' ) || '';
    my $fileName = $query->param( 'filename' ) || '';
    if ( $filePath && ! $fileName ) {
        $filePath =~ m|([^/\\]*$)|;
        $fileName = $1;
    }

    $fileComment =~ s/\s+/ /go;
    $fileComment =~ s/^\s*//o;
    $fileComment =~ s/\s*$//o;
    $fileName =~ s/\s*$//o;
    $filePath =~ s/\s*$//o;

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'attach files to' );
    TWiki::UI::checkTopicExists( $session, $webName, $topic, 'attach files to' );
    TWiki::UI::checkMirror( $session, $webName, $topic );
    TWiki::UI::checkAccess( $session, $webName, $topic,
                            'CHANGE', $user );

    my $origName = $fileName;
    my $stream;
    my ( $fileSize, $fileDate, $tmpFilePath ) = '';

    unless( $doPropsOnly ) {
        my $fh = $query->param( 'filepath' );

        try {
            $tmpFilePath = $query->tmpFileName( $fh );
        } catch Error::Simple with {
            # Item5130, Item5133 - Illegal file name, bad path,
            # something like that
            throw TWiki::OopsException(
                'attention',
                def => 'zero_size_upload',
                web => $webName,
                topic => $topic,
                params => [ ($filePath || '""') ] );
        };

        $stream = $query->upload( 'filepath' );
        ( $fileName, $origName ) =
          TWiki::Sandbox::sanitizeAttachmentName( $fileName );

        # check if upload has non zero size
        if( $stream ) {
            my @stats = stat $stream;
            $fileSize = $stats[7];
            $fileDate = $stats[9];
        }
        unless( $fileSize && $fileName ) {
            throw TWiki::OopsException(
                'attention',
                def => 'zero_size_upload',
                web => $webName,
                topic => $topic,
                params => [ ($filePath || '""') ] );
        }

        my $maxSize = $session->{prefs}->getPreferencesValue(
            'ATTACHFILESIZELIMIT' );
        $maxSize = 0 unless ( $maxSize =~ /([0-9]+)/o );

        if( $maxSize && $fileSize > $maxSize * 1024 ) {
            throw TWiki::OopsException(
                'attention',
                def => 'oversized_upload',
                web => $webName,
                topic => $topic,
                params => [ $fileName, $maxSize ] );
        }
    }
    try {
        $session->{store}->saveAttachment(
            $webName, $topic, $fileName, $user,
            {
                dontlog => !$TWiki::cfg{Log}{upload},
                comment => $fileComment,
                hide => $hideFile,
                createlink => $createLink,
                stream => $stream,
                filepath => $filePath,
                filesize => $fileSize,
                filedate => $fileDate,
                tmpFilename => $tmpFilePath,
            } );
    } catch Error::Simple with {
        throw TWiki::OopsException( 'attention',
                                    def => 'save_error',
                                    web => $webName,
                                    topic => $topic,
                                    params => [ shift->{-text} ] );
    };
    close( $stream ) if $stream;

    if( $fileName eq $origName ) {
        $session->redirect(
            $session->getScriptUrl( 1, 'view', $webName, $topic ), undef, 1 );
    } else {
        throw TWiki::OopsException( 'attention',
                                    def => 'upload_name_changed',
                                    web => $webName,
                                    topic => $topic,
                                    params => [ $origName, $fileName ] );
    }

    # generate a message useful for those calling this script from the command line
    my $message = ( $doPropsOnly ) ?
      'properties changed' : "$fileName uploaded";

    print 'OK ',$message,"\n" if $session->inContext('command_line');
}

1;
