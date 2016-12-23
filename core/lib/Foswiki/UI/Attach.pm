# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Attach

UI delegate for attachment management functions

=cut

package Foswiki::UI::Attach;

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

---++ StaticMethod attach( $session )

=attach= command handler.
This method is designed to be
invoked via the =UI::run= method.

Generates a prompt page for adding an attachment.

=cut

sub attach {
    my $session = shift;

    my $query = $session->{request};
    my $web   = $session->{webName};
    my $topic = $session->{topicName};

    Foswiki::UI::checkWebExists( $session, $web,, 'attach' );
    Foswiki::UI::checkTopicExists( $session, $web, $topic, 'upload files to' );

    my $topicObject = Foswiki::Meta->load( $session, $web, $topic );
    Foswiki::UI::checkAccess( $session, 'VIEW',   $topicObject );
    Foswiki::UI::checkAccess( $session, 'CHANGE', $topicObject );

    my $fileName = $query->param('filename') || '';
    my $args = $topicObject->get( 'FILEATTACHMENT', $fileName );
    $args = {
        name    => $fileName,
        path    => '',
        comment => ''
      }
      unless ($args);
    $args->{attr} ||= '';

    my $isHideChecked = ( $args->{attr} =~ m/h/ ) ? 'checked' : '';

    # SMELL: why log attach before post is called?
    # FIXME: Move down, log only if successful (or with error msg?)
    # Attach is a read function, only has potential for a change

    $session->logger->log(
        {
            level    => 'info',
            action   => 'attach',
            webTopic => $web . '.' . $topic,
            extra    => $fileName
        }
    );

    my $fileWikiUser = '';
    my $tmpl         = '';
    my $atext        = '';
    if ($fileName) {
        $tmpl = $session->templates->readTemplate('attachagain');
        my $u = $args->{user};
        $fileWikiUser = $session->{users}->webDotWikiName($u) if $u;
    }
    else {
        $tmpl = $session->templates->readTemplate('attachnew');
    }
    if ($fileName) {

        # must come after templates have been read
        $atext .= $session->attach->formatVersions( $topicObject, %$args );
        $fileName = Foswiki::entityEncode($fileName);
    }

    $tmpl =~ s/%ATTACHTABLE%/$atext/g;
    $tmpl =~ s/%FILEUSER%/$fileWikiUser/g;
    $tmpl =~ s/%FILENAME%/$fileName/g;
    $tmpl =~ s/%HIDEFILE%/$isHideChecked/g;

    my $filePath = $args->{path} || $fileName;
    $tmpl =~ s/%FILEPATH%/$filePath/g;
    $args->{comment} = Foswiki::entityEncode( $args->{comment} );
    $tmpl =~ s/%FILECOMMENT%/$args->{comment}/g;

    $tmpl = $topicObject->expandMacros($tmpl);
    $tmpl = $topicObject->renderTML($tmpl);

    $session->writeCompletePage($tmpl);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
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
