# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Upload

UI delegate for attachment management functions

=cut

package Foswiki::UI::Upload;

use strict;
use warnings;
use Assert;
use Error qw( :try );

use Foswiki                ();
use Foswiki::UI            ();
use Foswiki::Sandbox       ();
use Foswiki::OopsException ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
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

    my $query = $session->{request};
    if ( $query->param('noredirect') ) {
        my $message;
        my $status = 200;
        try {
            $message = _upload($session);
        }
        catch Foswiki::OopsException with {
            my $e = shift;
            $status  = $e->{status};
            $message = $e->stringify();
        }
        catch Foswiki::AccessControlException with {
            my $e = shift;
            $status  = 403;
            $message = $e->stringify();
        }
        catch Foswiki::ValidationException with {
            my $e = shift;
            $status  = 403;
            $message = $e->stringify();
        };
        $message = ( ( $status < 400 ) ? 'OK' : 'ERROR' ) . ": $message";

        $session->{response}->header(
            -status => $status,
            -type   => 'text/plain'
        );
        $session->{response}->print($message);
    }
    else {

        # allow exceptions to propagate
        _upload($session);

        my $nurl =
          $session->redirectto("$session->{webName}.$session->{topicName}")
          || $session->getScriptUrl( 1, 'view', $session->{webName},
            $session->{topicName} );
        $session->redirect($nurl) if ($nurl);

    }
}

# Real work of upload
sub _upload {
    my $session = shift;

    my $query = $session->{request};
    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    my $user  = $session->{user};

    Foswiki::UI::checkValidationKey($session);

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

    $fileComment =~ s/\s+/ /g;
    $fileComment =~ s/^\s*//;
    $fileComment =~ s/\s*$//;
    $fileName    =~ s/\s*$//;
    $filePath    =~ s/\s*$//;

    Foswiki::UI::checkWebExists( $session, $web, $topic, 'attach files to' );
    Foswiki::UI::checkTopicExists( $session, $web, $topic, 'attach files to' );
    my ($topicObject) = Foswiki::Func::readTopic( $web, $topic );
    Foswiki::UI::checkAccess( $session, 'CHANGE', $topicObject );

    my $origName = $fileName;

    # SMELL: would be much better to throw an exception if an attempt
    # is made to upload an invalid filename. However, it has always
    # been this way :-(
    ( $fileName, $origName ) =
      Foswiki::Sandbox::sanitizeAttachmentName($fileName);

    my $stream;
    my ( $fileSize, $fileDate, $tmpFilePath ) = '';

    unless ($doPropsOnly) {
        my $fh = $query->param('filepath');

        try {
            $tmpFilePath = $query->tmpFileName($fh);
        }
        catch Error with {

            # Item5130, Item5133 - Illegal file name, bad path,
            # something like that
            throw Foswiki::OopsException(
                'attention',
                def    => 'zero_size_upload',
                web    => $web,
                topic  => $topic,
                params => [ ( $filePath || '""' ) ]
            );
        };

        $stream = $query->upload('filepath');

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
                web    => $web,
                topic  => $topic,
                params => [ ( $filePath || '""' ) ]
            );
        }

        my $maxSize = $session->{prefs}->getPreference('ATTACHFILESIZELIMIT')
          || 0;
        $maxSize =~ s/\s+$//;
        $maxSize = 0 unless ( $maxSize =~ m/([0-9]+)/ );

        if ( $maxSize && $fileSize > $maxSize * 1024 ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'oversized_upload',
                web    => $web,
                topic  => $topic,
                params => [ $fileName, $maxSize ]
            );
        }
    }
    try {
        $topicObject->attach(
            name       => $fileName,
            comment    => $fileComment,
            hide       => $hideFile,
            createlink => $createLink,
            stream     => $stream,
            file       => $tmpFilePath,
            filepath   => $filePath,
            filesize   => $fileSize,
            filedate   => $fileDate,
        );
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
    close($stream) if $stream;

    if ( $fileName ne $origName ) {
        throw Foswiki::OopsException(
            'attention',
            status => 200,
            def    => 'upload_name_changed',
            web    => $web,
            topic  => $topic,
            params => [ $origName, $fileName ]
        );
    }

    # generate a message useful for those calling this script
    # from the command line
    return ($doPropsOnly)
      ? 'properties changed'
      : "$fileName uploaded";
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
