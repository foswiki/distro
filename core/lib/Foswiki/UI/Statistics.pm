# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Statistics

Statistics extraction and presentation

=cut

package Foswiki::UI::Statistics;

use strict;
use warnings;
use Assert;
use File::Copy qw(copy);
use IO::File ();
use Error qw( :try );

use Foswiki                         ();
use Foswiki::Sandbox                ();
use Foswiki::UI                     ();
use Foswiki::WebFilter              ();
use Foswiki::Time                   ();
use Foswiki::Meta                   ();
use Foswiki::AccessControlException ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod statistics( $session )

=statistics= command handler.
This method is designed to be
invoked via the =UI::run= method.

Generate statistics topic.
If a web is specified in the session object, generate WebStatistics
topic update for that web. Otherwise do it for all webs

=cut

sub statistics {
    my $session = shift;

    my $webName = $session->{webName};

    my $tmp = '';

    # web to redirect to after finishing
    my $destWeb = $Foswiki::cfg{UsersWebName};
    my $logDate = $session->{request}->param('logdate') || '';
    $logDate =~ s/[^0-9]//g;    # remove all non numerals

    unless ( $session->inContext('command_line') ) {

        # running from CGI
        $session->generateHTTPHeaders();
        $session->{response}->print(
            CGI::start_html( -title => 'Foswiki: Create Usage Statistics' ) );

        if ( uc( $session->{request}->method() ) ne 'POST' ) {
            throw Foswiki::OopsException(
                'attention',
                web    => $session->{webName},
                topic  => $session->{topicName},
                def    => 'post_method_only',
                params => ['statistics']
            );
        }
    }

    if ( defined $Foswiki::cfg{Stats}{StatisticsGroup}
        && length( $Foswiki::cfg{Stats}{StatisticsGroup} ) > 0 )
    {
        unless (
            Foswiki::Func::isGroupMember(
                $Foswiki::cfg{Stats}{StatisticsGroup}
            )
            || Foswiki::Func::isAnAdmin()
          )
        {
            _printMsg( $session,
                'Statistics not permitted for user - exiting' );
            return;
        }
    }

    # Initial messages
    _printMsg( $session, 'Foswiki: Create Usage Statistics' );
    _printMsg( $session, '!Do not interrupt this script!' );
    _printMsg( $session, '(Please wait until page download has finished)' );

    unless ($logDate) {
        $logDate =
          Foswiki::Time::formatTime( time(), '$year$mo', 'servertime' );
    }

    my $logMonth;
    my $logYear;
    if ( $logDate =~ m/^(\d\d\d\d)(\d\d)$/ ) {
        $logYear  = $1;
        $logMonth = $2;
    }
    else {
        _printMsg( $session, "!Error in date $logDate - must be YYYYMM" );
        return;
    }

    my $logMonthYear =
      $Foswiki::Time::ISOMONTH[ $logMonth - 1 ] . ' ' . $logYear;
    _printMsg( $session, "* Statistics for $logMonthYear" );

    # Do a single data collection pass on the temporary copy of logfile,
    # then process each web once.
    my $data = _collectLogData( $session, $logMonth, $logYear );

    my @weblist;

    # requestedWebName is the web from the URI, but validated with
    # topic rules which are more forgiving than the Web validations.
    # This field will be missing rather than defaulted if no web is
    # specified in the URL.
    my $webSet = $session->{request}->param('webs')
      || $session->{requestedWebName};

    my $recurse =
      Foswiki::Func::isTrue( scalar( $session->{request}->param('subwebs') ) );

    if ($webSet) {

        # do specific webs
        foreach my $web ( split( /,\s*/, $webSet ) ) {
            $web = Foswiki::Sandbox::untaint( $web,
                \&Foswiki::Sandbox::validateWebName );
            if ($web) {
                push( @weblist, $web );
                if ($recurse) {
                    my $webObj = Foswiki::Meta->new( $session, $web );
                    my $subweb = $webObj->web();
                    my $it     = $webObj->eachWeb($recurse);
                    while ( $it->hasNext() ) {
                        my $w = $it->next();
                        next
                          unless Foswiki::WebFilter->user()
                          ->ok( $session, "$subweb/$w" );
                        push( @weblist, "$subweb/$w" );
                    }
                    $webObj->finish();
                }
            }
        }
    }
    else {

        # otherwise do all user webs:
        my $root = Foswiki::Meta->new($session);
        my $it   = $root->eachWeb($recurse);
        while ( $it->hasNext() ) {
            my $w = $it->next();
            next unless Foswiki::WebFilter->user()->ok( $session, $w );
            push( @weblist, $w );
        }
    }

    my $firstTime = 1;
    foreach my $web (@weblist) {
        try {
            $destWeb =
              _processWeb( $session, $web, $logMonthYear, $data, $firstTime );
        }
        catch Foswiki::AccessControlException with {
            _printMsg( $session,
                '!  - ERROR: no permission to CHANGE statistics topic in '
                  . $web );
        }
        $firstTime = 0;

        if ( !$session->inContext('command_line') ) {
            $tmp = $Foswiki::cfg{Stats}{TopicName};
            my $url = $session->getScriptUrl( 0, 'view', $web, $tmp );
            _printMsg(
                $session,
                '* Go to '
                  . CGI::a(
                    {
                        href => $url,
                        rel  => 'nofollow'
                    },
                    "$web.$tmp"
                  )
                  . CGI::br()
            );
        }
    }
    _printMsg( $session, 'End creating usage statistics' );
    $session->{response}->print( CGI::end_html() )
      unless ( $session->inContext('command_line') );
}

# Debug only
# Print all entries in a view or contrib hash, sorted by web and item name
sub _debugPrintHash {
    my ($statsRef) = @_;

# print "Main.WebHome views = " . ${$statsRef}{'Main'}{'WebHome'}."\n";
# print "Main web, WikiGuest contribs = " . ${$statsRef}{'Main'}{'Main.WikiGuest'}."\n";
    foreach my $web ( sort keys %$statsRef ) {
        my $count = 0;
        print $web, ' web:', "\n";

        # Get reference to the sub-hash for this web
        my $webhashref = ${$statsRef}{$web};

        # print 'webhashref is ' . ref ($webhashref) ."\n";
        # Items can be topics (for view hash) or users (for contrib hash)
        foreach my $item ( sort keys %$webhashref ) {
            print "  $item = ", ( ${$webhashref}{$item} || 0 ), "\n";
            $count += ${$webhashref}{$item};
        }
        print "  WEB TOTAL = $count\n";
    }
}

# Process the whole log file and collect information in hash tables.
# Must build stats for all webs, to handle case of renames into web
# requested for a single-web statistics run.
#
# Main hash tables are divided by web:
#
#   $view{$web}{$TopicName} == number of views, by topic
#   $contrib{$web}{"Main.".$WikiName} == number of saves/uploads, by user

sub _collectLogData {
    my ( $session, $startMonth, $startYear ) = @_;

    # Log file contains: $user, $action, $webTopic, $extra, $remoteAddr
    # $user - cUID of user - default current user,
    # or failing that the user agent
    # $action - what happened, e.g. view, save, rename
    # $webTopic - what it happened to
    # $extra - extra info, such as minor flag
    # $remoteAddr = e.g. 127.0.0.5
    my $start = Foswiki::Time::parseTime("$startYear-$startMonth-01");
    my $end   = Foswiki::Time::parseTime(
        $startMonth == 12
        ? ( $startYear + 1 ) . "-01-01"
        : "$startYear-" . ( $startMonth + 1 ) . "-01"
    );

    my $data = {
        viewRef    => {},  # Hash of hashes, counts topic views by (web, topic)
        contribRef => {},  # Hash of hashes, counts uploads/saves by (web, user)
             # Hashes for each type of statistic, one hash entry per web
        statViewsRef   => {},
        statSavesRef   => {},
        statUploadsRef => {}
    };

    my $users = $session->{users};

    my $it = $session->logger->eachEventSince( $start, 'info' );
    while ( $it->hasNext() ) {
        my $line = $it->next();
        my $date = shift(@$line);
        last if $date > $end;    # Stop processing when we've done one month

        my $logFileUserName = shift @$line;

        # Use Func::getCanonicalUserID because it accepts login,
        # wikiname or web.wikiname
        my $canonicalUID = Foswiki::Func::getCanonicalUserID($logFileUserName);
        $logFileUserName = $canonicalUID if ($canonicalUID);

        my ( $opName, $webTopic, $notes, $ip ) = @$line;

        # ignore events that are not statistically helpful
        next if ( $notes && $notes =~ m/dontlog/ );

# ignore events statistics doesn't understand for now - idea: make a "top search phrase list"
        next
          if ( $opName
            && $opName =~
            m/search|renameweb|changepasswd|resetpasswd|sudo login|logout/ );

        # .+ is used because topics name can contain stuff like
        # !, (, ), =, -, _ and they should have stats anyway
        if (   $webTopic
            && $opName
            && $webTopic =~
m/(^$Foswiki::regex{webNameRegex})\.($Foswiki::regex{wikiWordRegex}$|$Foswiki::regex{abbrevRegex}|.+)/
          )
        {
            my $webName   = $1;
            my $topicName = $2;

            if ( $opName eq 'view' ) {
                next if ( $topicName eq 'WebRss' );
                next if ( $topicName eq 'WebAtom' );
                $data->{statViewsRef}{$webName}++;
                unless ( $notes && $notes =~ m/\(not exist\)/ ) {
                    $data->{viewRef}->{$webName}{$topicName}++;
                }

            }
            elsif ( $opName eq 'save' ) {
                $data->{statSavesRef}->{$webName}++;
                $data->{contribRef}
                  ->{$webName}{ $users->webDotWikiName($logFileUserName) }++;

            }
            elsif ( $opName eq 'upload' ) {
                $data->{statUploadsRef}->{$webName}++;
                $data->{contribRef}
                  ->{$webName}{ $users->webDotWikiName($logFileUserName) }++;

            }
            elsif ( $opName eq 'rename' ) {

                # Pick up the old and new topic names
                $notes =~
m/moved to ($Foswiki::regex{webNameRegex})\.($Foswiki::regex{wikiWordRegex}|$Foswiki::regex{abbrevRegex}|\w+)/;
                my $newTopicWeb  = $1;
                my $newTopicName = $2;

                # Get number of views for old topic this month (may be zero)
                my $oldViews = $data->{viewRef}->{$webName}{$topicName} || 0;

                # Transfer views from old to new topic
                $data->{viewRef}->{$newTopicWeb}{$newTopicName} = $oldViews;
                delete $data->{viewRef}->{$webName}{$topicName};

                # Transfer views from old to new web
                if ( $newTopicWeb ne $webName ) {
                    $data->{statViewsRef}{$webName} -= $oldViews;
                    $data->{statViewsRef}{$newTopicWeb} += $oldViews;
                }
            }
        }
        else {

            # ignore template webs.  (Regex copied from Foswiki::WebFilter)
            if ( defined $webTopic ) {
                my ( $w, $t ) = split( /\./, $webTopic );
                next if $w && $w =~ m/(?:^_|\/_)/;
            }

            $session->logger->log( 'debug',
                'WebStatistics: Bad logfile line ' . join( '|', @$line ) )
              if (DEBUG);
        }
    }

    return $data;
}

sub _processWeb {
    my ( $session, $web, $theLogMonthYear, $data, $isFirstTime ) = @_;

    my ( $topic, $user ) = ( $session->{topicName}, $session->{user} );

    if ($isFirstTime) {
        _printMsg( $session, '* Executed by ' . $user );
    }

    _printMsg( $session, "* Reporting on $web web" );

    unless ( Foswiki::Func::webExists($web) ) {
        _printMsg( $session, "!Web $web does not exist,  skipping.." );
        return;
    }

    # Handle null values, print summary message to browser/stdout
    my $statViews   = $data->{statViewsRef}->{$web};
    my $statSaves   = $data->{statSavesRef}->{$web};
    my $statUploads = $data->{statUploadsRef}->{$web};
    $statViews   ||= 0;
    $statSaves   ||= 0;
    $statUploads ||= 0;
    _printMsg( $session,
        "  - view: $statViews, save: $statSaves, upload: $statUploads" );

    # Get the top N views and contribs in this web
    my (@topViews) =
      _getTopList( $Foswiki::cfg{Stats}{TopViews}, $web, $data->{viewRef} );
    my (@topContribs) =
      _getTopList( $Foswiki::cfg{Stats}{TopContrib}, $web,
        $data->{contribRef} );

    # Print information to stdout
    my $statTopViews        = '';
    my $statTopContributors = '';
    if (@topViews) {
        $statTopViews = join( CGI::br(), @topViews );
        $topViews[0] =~ s/[\[\]]*//g;
        _printMsg( $session, '  - top view: ' . $topViews[0] );
    }
    if (@topContribs) {
        $statTopContributors = join( CGI::br(), @topContribs );
        _printMsg( $session, '  - top contributor: ' . $topContribs[0] );
    }

    # Update the WebStatistics topic

    my $tmp;
    my $meta;
    my $statsTopic = $Foswiki::cfg{Stats}{TopicName};

    # DEBUG
    # $statsTopic = 'TestStatistics';		# Create this by hand

    my $statsTemplateWeb = '';
    my $tmplObject;

    my $autoCreate    = 0;
    my $autoCreateMsg = 'prohibited';
    if ( defined $Foswiki::cfg{Stats}{AutoCreateTopic} ) {
        if ( $Foswiki::cfg{Stats}{AutoCreateTopic} eq 'Allowed' ) {
            $autoCreateMsg = 'not requested';
            $autoCreate    = $session->{request}->param('autocreate')
              if defined $session->{request}->param('autocreate');
        }
        else {
            $autoCreate = 1
              if ( $Foswiki::cfg{Stats}{AutoCreateTopic} eq 'Always' );
        }
    }

    unless ( $session->topicExists( $web, $statsTopic ) ) {
        if ($autoCreate) {
            my $statsTemplate = $statsTopic . 'Template';
            if (
                $session->topicExists(
                    $Foswiki::cfg{UsersWebName},
                    $statsTemplate
                )
              )
            {
                $statsTemplateWeb = $Foswiki::cfg{UsersWebName};
            }
            elsif (
                $session->topicExists(
                    $Foswiki::cfg{SystemWebName},
                    $statsTemplate
                )
              )
            {
                $statsTemplateWeb = $Foswiki::cfg{SystemWebName};
            }
            if ($statsTemplateWeb) {
                my $webMeta = Foswiki::Meta->load( $session, $web );
                Foswiki::UI::checkAccess( $session, 'CHANGE', $webMeta );
                _printMsg( $session,
"* Creating $web.$statsTopic using template $statsTemplateWeb.$statsTemplate"
                );
                $tmplObject = Foswiki::Meta->load( $session, $statsTemplateWeb,
                    $statsTemplate );
                Foswiki::UI::checkAccess( $session, 'VIEW', $tmplObject );
                $meta = Foswiki::Meta->new( $session, $web, $statsTopic );
                $meta->copyFrom($tmplObject);
                $meta->text( $tmplObject->text() );
            }
            else {
                _printMsg( $session,
"! Warning: Template topic $statsTemplate not found in $Foswiki::cfg{UsersWebName} or $Foswiki::cfg{SystemWebName}.  Unable to generate statistics in $web web."
                );
                return $web;
            }
        }
        else {
            _printMsg( $session,
"! Warning: No updates done, topic $web.$statsTopic does not exist, and autocreate $autoCreateMsg."
            );
            return $web;
        }
    }
    else {
        $meta = Foswiki::Meta->load( $session, $web, $statsTopic );
    }

    Foswiki::UI::checkAccess( $session, 'CHANGE', $meta );
    my @lines = split( /\r?\n/, $meta->text );
    my $statLine;
    my $idxStat = -1;
    my $idxTmpl = -1;
    for ( my $x = 0 ; $x < @lines ; $x++ ) {
        $tmp = $lines[$x];

        # Check for existing line for this month+year
        if ( $tmp =~ m/$theLogMonthYear/ ) {
            $idxStat = $x;
        }
        elsif ( $tmp =~ m/<\!\-\-statDate\-\->/ ) {
            $statLine = $tmp;
            $idxTmpl  = $x;
        }
    }
    if ( !$statLine ) {
        $statLine =
'| <!--statDate--> | <!--statViews--> | <!--statSaves--> | <!--statUploads--> | <!--statTopViews--> | <!--statTopContributors--> |';
    }
    $statLine =~ s/<\!\-\-statDate\-\->/$theLogMonthYear/;
    $statLine =~ s/<\!\-\-statViews\-\->/ $statViews/;
    $statLine =~ s/<\!\-\-statSaves\-\->/ $statSaves/;
    $statLine =~ s/<\!\-\-statUploads\-\->/ $statUploads/;
    $statLine =~ s/<\!\-\-statTopViews\-\->/$statTopViews/;
    $statLine =~ s/<\!\-\-statTopContributors\-\->/$statTopContributors/;

    if ( $idxStat >= 0 ) {

        # entry already exists, need to update
        $lines[$idxStat] = $statLine;

    }
    elsif ( $idxTmpl >= 0 ) {

        # entry does not exist, add after <!--statDate--> line
        $lines[$idxTmpl] = "$lines[$idxTmpl]\n$statLine";

    }
    else {

        # entry does not exist, add at the end
        $lines[@lines] = $statLine;
    }
    my $text = join( "\n", @lines );
    $text .= "\n";
    $meta->text($text);
    $meta->save( minor => 1, dontlog => 1 );

    _printMsg( $session, "  - Topic $statsTopic updated" );

    return $web;
}

# Get the items with top N frequency counts
# Items can be topics (for view hash) or users (for contrib hash)
sub _getTopList {
    my ( $theMaxNum, $webName, $statsRef ) = @_;

    # Get reference to the sub-hash for this web
    my $webhashref = $statsRef->{$webName};

# print "Main.WebHome views = " . $statsRef->{$webName}{'WebHome'}."\n";
# print "Main web, WikiGuest contribs = " . ${$statsRef}{$webName}{'Main.WikiGuest'}."\n";

    my @list = ();
    my $topicName;
    my $statValue;

    # Convert sub hash of item=>statsvalue pairs into an array, @list,
    # of '$statValue $topicName', ready for sorting.
    while ( ( $topicName, $statValue ) = each(%$webhashref) ) {

        # Right-align statistic value for sorting
        $statValue = sprintf '%7d', $statValue;

        # Add new array item at end of array
        if ( $topicName =~ m/\./ ) {
            $list[@list] = "$statValue $topicName";
        }
        else {
            $list[@list] = "$statValue [[$topicName]]";
        }
    }

    # DEBUG
    # print " top N list for $webName\n";
    # print join "\n", @list;

    # Sort @list by frequency and pick the top N entries
    if (@list) {

        # Strip initial spaces
        @list = map { s/^\s*//; $_ } @list;

        @list =    # Prepend spaces depending on no. of digits
          map { s/^([0-9][0-9][^0-9])/\&nbsp\;$1/;    $_ }
          map { s/^([0-9][^0-9])/\&nbsp\;\&nbsp\;$1/; $_ }

          # Sort numerically, descending order
          sort { ( split / /, $b )[0] <=> ( split / /, $a )[0] } @list;

        if ( $theMaxNum >= @list ) {
            $theMaxNum = @list - 1;
        }
        return @list[ 0 .. $theMaxNum ];
    }
    return @list;
}

sub _printMsg {
    my ( $session, $msg ) = @_;

    if ( $session->inContext('command_line') ) {
        $msg =~ s/&nbsp;/ /g;
    }
    else {
        if ( $msg =~ s/^\!// ) {
            $msg =
              CGI::h4( {}, CGI::span( { class => 'foswikiAlert' }, $msg ) );
        }
        elsif ( $msg =~ m/^[A-Z]/ ) {

            # SMELL: does not support internationalised script messages
            $msg =~ s/^([A-Z].*)/CGI::h3({},$1)/ge;
        }
        else {
            $msg =~ s/(\*\*\*.*)/CGI::span( { class=>'foswikiAlert' }, $1 )/ge;
            $msg =~ s/^\s\s/&nbsp;&nbsp;/g;
            $msg =~ s/^\s/&nbsp;/g;
            $msg .= CGI::br();
        }
        $msg =~
s/==([A-Z]*)==/'=='.CGI::span( { class=>'foswikiAlert' }, $1 ).'=='/ge;
    }
    $session->{response}->print( $msg . "\n" ) if $msg;
    $Foswiki::engine->flush( $session->{response}, $session->{request} );
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
Copyright (C) 2002 Richard Donkin, rdonkin@bigfoot.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
