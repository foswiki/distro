# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

package TWiki::UI::Changes;

use strict;

use Assert;
use Error qw( :try );

require TWiki;
require TWiki::UI;
require TWiki::Time;

# Command handler for changes command
sub changes {
    my $session = shift;

    my $query   = $session->{request};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'find changes in' );

    my $skin = $session->getSkin();

    my $text = $session->templates->readTemplate( 'changes', $skin );

    my ( $page, $eachChange, $after ) = split( /%REPEAT%/, $text );

    my $showMinor = $query->param('minor');
    unless ($showMinor) {
        my $comment =
            CGI::b('Note: ') 
          . 'This page is showing major changes only. '
          . CGI::a(
            {
                href => $query->url() . "/$webName?minor=1",
                rel  => 'nofollow'
            },
            'View all changes'
          );
        $comment = CGI::div( { class => 'twikiHelp' }, $comment );
        $page .= $comment;
    }
    my %done = ();

    my $iterator = $session->{store}->eachChange( $webName, 0 );

    while ( $iterator->hasNext() ) {
        my $change = $iterator->next();
        next
          if ( !$showMinor && $change->{more} && $change->{more} =~ /minor/ );
        next if $done{ $change->{topic} };
        next
          unless $session->{store}->topicExists( $webName, $change->{topic} );
        try {
            my $summary = $session->renderer->summariseChanges(
                $session->{user}, $webName,
                $change->{topic}, $change->{revision}
            );
            my $thisChange = $eachChange;
            $thisChange =~ s/%TOPICNAME%/$change->{topic}/go;
            my $wikiuser =
                $change->{user}
              ? $session->{users}->webDotWikiName( $change->{user} )
              : '';
            $thisChange =~ s/%AUTHOR%/$wikiuser/go;
            my $time = TWiki::Time::formatTime( $change->{time} );
            $change->{revision} = 1 unless $change->{revision};
            my $srev = 'r' . $change->{revision};

            if ( $change->{revision} == 1 ) {
                $srev = CGI::span( { class => 'twikiNew' }, 'NEW' );
            }
            $thisChange =~ s/%TIME%/$time/g;
            $thisChange =~ s/%REVISION%/$srev/go;
            $thisChange =
              $session->renderer->getRenderedVersion( $thisChange, $webName,
                $change->{topic} );
            $thisChange =~ s/%TEXTHEAD%/$summary/go;
            $page .= $thisChange;
        }
        catch TWiki::AccessControlException with {

            # ignore changes we can't see
        };
        $done{ $change->{topic} } = 1;
    }
    if ( $TWiki::cfg{Log}{changes} ) {

        # write log entry
        $session->writeLog( 'changes', $webName, '' );
    }
    $page .= $after;

    $page = $session->handleCommonTags( $page, $webName, $topic );
    $page = $session->renderer->getRenderedVersion( $page, $webName, $topic );

    $session->writeCompletePage($page);
}

1;
