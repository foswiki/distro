# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Upload

UI delegate for attachment management functions

=cut

package Foswiki::UI::Upload;
use v5.14;

use Assert;
use Try::Tiny;

use Foswiki                ();
use Foswiki::Sandbox       ();
use Foswiki::OopsException ();

use Moo;
use namespace::clean;
extends qw(Foswiki::UI);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ObjectMethod upload

=upload= command handler.
This method is designed to be
invoked via the =UI::run= method.
CGI parameters, passed in $req:

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
    my $this = shift;

    my $app = $this->app;
    my $req = $app->request;
    if ( $req->param('noredirect') ) {
        my $message;
        my $status = 200;
        try {
            $message = $this->_upload;
        }
        catch {
            my $e = $_;
            unless ( ref($e) && $e->isa('Foswiki::Exception') ) {

                # SMELL Perhaps $status = 500 would be more correct?
                Foswiki::Exception::Fatal->rethrow($e);
            }
            if ( $e->isa('Foswiki::OopsException') ) {
                $status  = $e->status;
                $message = $e->stringify;
            }
            elsif ($e->isa('Foswiki::AccessControlException')
                || $e->isa('Foswiki::ValidationException') )
            {
                $status  = 403;
                $message = $e->stringify;
            }
        };
        $message = ( ( $status < 400 ) ? 'OK' : 'ERROR' ) . ": $message";

        my $res = $app->response;
        $res->header( -type => 'text/plain' );
        $res->status($status);
        $res->print($message);
    }
    else {

        # allow exceptions to propagate
        $this->_upload;

        my $req   = $app->request;
        my $web   = $req->web;
        my $topic = $req->topic;
        my $nurl  = $app->redirectto( $web . "." . $topic )
          || $app->cfg->getScriptUrl( 1, 'view', $web, $topic );
        $app->redirect($nurl) if ($nurl);

    }
}

sub _upload {
    my $this = shift;

    my @msgs;
    foreach my $upload ( values %{ $this->app->request->uploads } ) {
        push @msgs, $this->_upload_file($upload);
    }

    # XXX Temporary!
    # SMELL Any other way to return mupltiple messages? A template?
    return join( '', map { "<p>$_</p>" } @msgs );
}

# Real work of upload
sub _upload_file {
    my $this   = shift;
    my $upload = shift;

    my $app   = $this->app;
    my $req   = $app->request;
    my $web   = $req->web;
    my $topic = $req->topic;
    my $user  = $app->user;

    $this->checkValidationKey;

    my $hideFile    = $req->param('hidefile')    || '';
    my $fileComment = $req->param('filecomment') || '';
    my $createLink  = $req->param('createlink')  || '';
    my $doPropsOnly = $req->param('changeproperties');
    my $filePath    = $upload->filename          || '';
    my $fileName    = $upload->basename          || '';
    my $tmpFilePath = $upload->tmpname;
    my $fileSize    = $upload->size;
    if ( $filePath && !$fileName ) {
        $filePath =~ m|([^/\\]*$)|;
        $fileName = $1;
    }

    $fileComment =~ s/\s+/ /g;
    $fileComment =~ s/^\s*//;
    $fileComment =~ s/\s*$//;
    $fileName    =~ s/\s*$//;
    $filePath    =~ s/\s*$//;

    $this->checkWebExists( $web, $topic, 'attach files to' );
    $this->checkTopicExists( $web, $topic, 'attach files to' );
    my ($topicObject) = Foswiki::Func::readTopic( $web, $topic );
    $this->checkAccess( 'CHANGE', $topicObject );

    my $origName = $fileName;

    # SMELL: would be much better to throw an exception if an attempt
    # is made to upload an invalid filename. However, it has always
    # been this way :-(
    ( $fileName, $origName ) =
      Foswiki::Sandbox::sanitizeAttachmentName($fileName);

    my $stream;
    my ( $streamSize, $fileDate );

    unless ($doPropsOnly) {
        $stream = $upload->handle;

        # check if upload has non zero size
        if ($stream) {
            my @stats = stat $stream;
            $streamSize = $stats[7];
            $fileDate   = $stats[9];
        }
        unless ( $streamSize && $fileName ) {
            Foswiki::OopsException->throw(
                app      => $app,
                template => 'attention',
                def      => 'zero_size_upload',
                web      => $web,
                topic    => $topic,
                params   => [ ( $filePath || '""' ) ],
                status   => 400,
            );
        }
        unless ( $streamSize == $fileSize ) {

            # TODO Check if actual file size is the same as declared in POST
            # headers. Prevent broken uploads.
        }

        my $maxSize = $app->prefs->getPreference('ATTACHFILESIZELIMIT')
          || 0;
        $maxSize =~ s/\s+$//;
        $maxSize = 0 unless ( $maxSize =~ m/([0-9]+)/ );

        if ( $maxSize && $fileSize > $maxSize * 1024 ) {
            Foswiki::OopsException->throw(
                app      => $app,
                template => 'attention',
                def      => 'oversized_upload',
                web      => $web,
                topic    => $topic,
                params   => [ $fileName, $maxSize ],
                status   => 400,
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
    catch {
        $app->logger->log( 'error', ( ref($_) ? $_->stringify : $_ ) );
        Foswiki::OopsException->rethrowAs(
            $_,
            app      => $app,
            template => 'attention',
            def      => 'save_error',
            web      => $web,
            topic    => $topic,
            params   => [
                $app->i18n->maketext(
                    'Operation [_1] failed with an internal error', 'save'
                )
            ],
        );
    };
    close($stream) if $stream;

    if ( $fileName ne $origName ) {
        Foswiki::OopsException->throw(
            app      => $app,
            template => 'attention',
            status   => 200,
            def      => 'upload_name_changed',
            web      => $web,
            topic    => $topic,
            params   => [ $origName, $fileName ]
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
