# See bottom of file for license and copyright information
package Foswiki::UI::Viewfile;

=begin TML

---+ package Foswiki::UI::Viewfile

UI delegate for viewfile function

=cut

use strict;
use warnings;
use integer;

use Assert;
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

    my $web      = $query->web();
    my $topic    = $query->topic();
    my $fileName = $query->attachment();

    if ( !$topic ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'no_such_attachment',
            web    => $web,
            topic  => 'Unknown',
            status => 404,
            params => ['?']
        );
    }

    if ( !$fileName ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'no_such_attachment',
            web    => $web,
            topic  => $topic,
            status => 404,
            params => ['?']
        );
    }

    #print STDERR "VIEWFILE: web($web), topic($topic), file($fileName)\n";

    my $rev = Foswiki::Store::cleanUpRevID( scalar( $query->param('rev') ) );
    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );

    # This check will fail if the attachment has no "presence" in metadata
    unless ( $topicObject->hasAttachment($fileName) ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'no_such_attachment',
            web    => $web,
            topic  => $topic,
            status => 404,
            params => ["$web/$topic/$fileName"]
        );
    }

    # The whole point of viewfile....
    Foswiki::UI::checkAccess( $session, 'VIEW', $topicObject );

    my $logEntry = $fileName;
    $logEntry .= ", r$rev" if $rev;
    $session->logger->log(
        {
            level    => 'info',
            action   => 'viewfile',
            webTopic => $web . '.' . $topic,
            extra    => $logEntry,
        }
    );

    my $fh = $topicObject->openAttachment( $fileName, '<', version => $rev );

    my $type = _suffixToMimeType($fileName);

    #re-set to 200, in case this was a 404 or other redirect
    $session->{response}->status(200);

# Write a custom Content_Disposition header.  The -attachment option does not
# write the file as "inline", so graphics would get a File Save dialog instead of displayed.
    $session->{response}->header(
        -type                => $type,
        -content_disposition => "inline; filename=\"$fileName\""
    );

    local $/;

    # SMELL: Maybe could be less memory hungry if we could
    # set the response body to the file handle.
    $session->{response}->body(<$fh>);
}

sub _suffixToMimeType {
    my ($attachment) = @_;

    my $mimeType = 'text/plain';
    if ( $attachment && $attachment =~ m/\.([^.]+)$/ ) {
        my $suffix = $1;
        if ( open( my $fh, '<', $Foswiki::cfg{MimeTypesFileName} ) ) {
            local $/ = undef;
            my $types = <$fh>;
            close($fh);
            if ( $types =~ m/^([^#]\S*).*?\s$suffix(?:\s|$)/im ) {
                $mimeType = $1;
            }
        }
        elsif (DEBUG) {
            ASSERT(0);
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
