# See bottom of file for license and copyright information
package Foswiki::UI::Viewfile;

=begin TML

---+ package Foswiki::UI::Viewfile

UI delegate for viewfile function

=cut

use strict;
use integer;
use CGI::Carp qw( fatalsToBrowser );

use Foswiki                ();
use Foswiki::UI            ();
use Foswiki::Sandbox       ();
use Foswiki::OopsException ();

=begin TML

---++ StaticMethod viewfile( $session, $web, $topic, $query )

=viewfile= command handler.
This method is designed to be
invoked via the =UI::run= method.
Command handler for viewfile. View a file in the browser.
Some parameters are passed in CGI query:
| =filename= | Attachment to view |
| =rev= | Revision to view |

=cut

sub viewfile {
    my $session = shift;

    my $query = $session->{request};

    my $web   = $session->{webName};
    my $topic = $session->{topicName};

    my $fileName;
    my $pathInfo;

    if ( defined( $ENV{REDIRECT_STATUS} ) && defined( $ENV{REQUEST_URI} ) ) {

        # this is a redirect - can be used to make 404,401 etc URL's
        # more foswiki tailored and is also used in TWikiCompatibility
        $pathInfo = $ENV{REQUEST_URI};

        # ignore parameters, as apache would.
        $pathInfo =~ s/^(.*)(\?|#).*/$1/;
        $pathInfo =~ s|$Foswiki::cfg{PubUrlPath}||;    #remove pubUrlPath
    }
    elsif ( defined( $query->param('filename') ) ) {

        # Filename is an attachment to the topic in the standard path info
        # /Web/Topic?filename=Attachment.gif
        $fileName = $query->param('filename');
    }
    else {

        # This is a standard path extended by the attachment name e.g.
        # /Web/Topic/Attachment.gif
        $pathInfo = $query->path_info();
    }

    if ($pathInfo) {
        my @path = split( /\/+/, $pathInfo );
        shift(@path) unless ( $path[0] );    # remove leading empty string

        # work out the web, topic and filename
        $web = '';
        while ( $path[0]
            && ( $session->webExists( $web . $path[0] ) ) )
        {
            $web .= shift(@path) . '/';
        }

        # The web name has been validated, untaint
        chop($web);                          # trailing /
        $web = Foswiki::Sandbox::untaintUnchecked($web);

        # The next element on the path has to be the topic name
        $topic = shift(@path);
        if ( !$topic ) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'no_such_attachment',
                web    => $web,
                topic  => $topic || 'Unknown',
                status => 404,
                params => [ 'viewfile', '?' ]
            );
        }

        # Topic has been validated
        $topic = Foswiki::Sandbox::untaintUnchecked($topic);

        # What's left in the path is the attachment name.
        $fileName = join( '/', @path );
    }

    # According to SvenDowideit, you can't remove the /'s from the filename,
    # as there are directories below the pub/web/topic.
    #$fileName = Foswiki::Sandbox::sanitizeAttachmentName($fileName);
    $fileName = Foswiki::Sandbox::normalizeFileName($fileName);

    if ( !$fileName ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'no_such_attachment',
            web    => 'Unknown',
            topic  => 'Unknown',
            status => 404,
            params => [ 'viewfile', '?' ]
        );
    }

    #print STDERR "VIEWFILE: web($web), topic($topic), file($fileName)\n";

    my $rev = Foswiki::Store::cleanUpRevID( $query->param('rev') );
    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );

    # This check will fail if the attachment has no "presence" in metadata
    unless ( $fileName && $topicObject->hasAttachment($fileName) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'no_such_attachment',
            web    => $web,
            topic  => $topic,
            status => 404,
            params => [ 'viewfile', $fileName || '?' ]
        );
    }

    Foswiki::UI::checkAccess( $session, 'VIEW', $topicObject );

    my $logEntry = $fileName; 
    $logEntry .= ", r$rev" if $rev; 
	$session->logEvent( 'viewfile', $web.'.'.$topic, $logEntry ); 

    my $fh = $topicObject->openAttachment( $fileName, '<', version => $rev );

    my $type  = _suffixToMimeType($fileName);
    my $dispo = 'inline;filename=' . $fileName;

    #re-set to 200, in case this was a 404 or other redirect
    $session->{response}->status(200);
    $session->{response}
      ->header( -type => $type, qq(Content-Disposition="$dispo") );
    local $/;

    # SMELL: Maybe could be less memory hungry if we could
    # set the response body to the file handle.
    $session->{response}->print(<$fh>);
}

sub _suffixToMimeType {
    my ($attachment) = @_;

    my $mimeType = 'text/plain';
    if ( $attachment && $attachment =~ /\.([^.]+)$/ ) {
        my $suffix = $1;
        my $types  = Foswiki::readFile( $Foswiki::cfg{MimeTypesFileName} );
        if ( $types =~ /^([^#]\S*).*?\s$suffix(?:\s|$)/im ) {
            $mimeType = $1;
        }
    }
    return $mimeType;
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
and TWiki Contributors. All Rights Reserved.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
