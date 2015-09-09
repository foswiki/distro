# See bottom of file for license and copyright information

package Foswiki::Plugins::HistoryPlugin;

use strict;
use warnings;
use Foswiki::Func ();
use Error qw(:try);
use Foswiki::AccessControlException ();

# =========================
#   Simple decimal version,  no leading "v"
our $VERSION           = "1.13";
our $RELEASE           = '1.13';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION  = 'Shows a complete history of a topic';

# =========================
sub initPlugin {

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.021 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between HistoryPlugin and Plugins.pm");
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'HISTORY', \&_handleHistory );

    return 1;
}

sub _handleHistory {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $web   = $params->{web}   || $theWeb;
    my $topic = $params->{topic} || $theTopic;
    ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );

    # check topic exists
    unless ( Foswiki::Func::topicExists( $web, $topic ) ) {
        return
"<noautolink><span class='foswikiAlert'>HistoryPlugin error: Topic $web.$topic does not exist</noautolink>";
    }

    # check access permissions
    unless (
        Foswiki::Func::checkAccessPermission(
            "VIEW", $session->{user}, undef, $topic, $web
        )
      )
    {
        throw Foswiki::AccessControlException( "VIEW", $session->{user}, $web,
            $topic, $Foswiki::Meta::reason );
    }

    my $reverse = Foswiki::Func::isTrue( $params->{reverse}, 1 );

    my $versions = $params->{versions};
    my $versionStart;
    my $versionEnd;
    my $maxrev = ( Foswiki::Func::getRevisionInfo( $web, $topic ) )[2];
    my $rev1 = $params->{rev1} ? $params->{rev1} : 1;
    my $rev2 = $params->{rev2} ? $params->{rev2} : $maxrev;
    my $nrev = $params->{nrev} ? $params->{nrev} : 10;

    if ($versions) {
        $versions =~ m/([0-9\-]*)(\.\.)*([0-9\-]*)/;
        if ( defined $1 && length $1 ) {
            $rev1 = $1;
        }
        if ( defined $2 && length $2 ) {

            # dots
            $rev2 = $3 if ( defined $3 && length $3 );
        }
        else {
            $rev2 = $rev1;
        }

        # wrap
        $rev1 = $maxrev + $rev1 if $rev1 < 0;
        $rev2 = $maxrev + $rev2 if $rev2 < 0;

        # normalize
        $rev1 = 1       if $rev1 == 0;
        $rev2 = 1       if $rev2 == 0;
        $rev1 = $maxrev if $rev1 > $maxrev;
        $rev2 = $maxrev if $rev2 > $maxrev;
        if ( $rev1 > $rev2 ) {
            $reverse = 0;
            ( $rev1, $rev2 ) = ( $rev2, $rev1 );
        }
    }
    else {

        # deprecated syntax

        $rev1 = $params->{rev1};
        $rev1 =~ s/1\.// if $rev1;
        $rev2 = $params->{rev2};
        $rev2 =~ s/1\.// if $rev2;
        $nrev = $params->{nrev} || 10;

        $rev2 ||= $rev1 ? $rev1 + $nrev - 1 : $maxrev;
        $rev1 ||= $rev2 - $nrev + 1;

        ( $rev1, $rev2 ) = ( $rev2, $rev1 ) if $rev1 > $rev2;
        $rev1 = $maxrev if $rev1 > $maxrev;
        $rev1 = 1       if $rev1 < 1;
        $rev2 = $maxrev if $rev2 > $maxrev;
        $rev2 = 1       if $rev2 < 1;
    }

    my $format =
         $params->{format}
      || $params->{_DEFAULT}
      || 'r$rev - $date - $wikiusername%BR%';
    my $header = $params->{header};
    $header = "\$next{'...'}%BR%" unless defined($header);
    my $footer = $params->{footer};
    $footer = "\$previous{'...'}" unless defined($footer);

    Foswiki::Func::setPreferencesValue( "HISTORY_MAXREV", $maxrev );
    Foswiki::Func::setPreferencesValue( "HISTORY_REV1",   $rev1 );
    Foswiki::Func::setPreferencesValue( "HISTORY_REV2",   $rev2 );
    Foswiki::Func::setPreferencesValue( "HISTORY_NREV",   $nrev );

    # Start the output
    my $out = _handleHeadFoot( $header, $rev1, $rev2, $nrev, $maxrev );

    # Print revision info

    my @revs = ( $rev1 .. $rev2 );

    @revs = reverse(@revs) if $reverse;
    my $mixedAlphaNum = Foswiki::Func::getRegularExpression('mixedAlphaNum');
    my $checkFlag     = 0;

    foreach my $rev (@revs) {

        my ( $date, $user, $revout, $comment ) =
          Foswiki::Func::getRevisionInfo( $web, $topic, $rev );

        my $wikiName     = Foswiki::Func::userToWikiName( $user, 1 );
        my $wikiUserName = Foswiki::Func::userToWikiName( $user, 0 );

        my $revinfo  = $format;
        my $checked1 = '';
        my $checked2 = '';
        $checked1 = 'checked' if $checkFlag == 0;
        $checked2 = 'checked' if $checkFlag == 1;
        $checkFlag++;
        $revinfo =~ s/\$web/$web/g;
        $revinfo =~ s/\$topic/$topic/g;
        $revinfo =~ s/\$rev/$rev/g;
        $revinfo =~ s/\$date/Foswiki::Func::formatTime($date)/ge;
        $revinfo =~
s/\$(year|ye|week|web|wday|tz|topic|time|seconds|rev|rcs|month|mo|minutes|longdate|isotz|iso|http|hours|epoch|email|dow|day)/_formatTime("\$$1", $topic, $web)/ge;
        $revinfo =~ s/\$username/$user/g;
        $revinfo =~ s/\$wikiname/$wikiName/g;
        $revinfo =~ s/\$wikiusername/$wikiUserName/g;
        $revinfo =~ s/\$checked1/$checked1/g;
        $revinfo =~ s/\$checked2/$checked2/g;

        # This space to tabs conversion must be for Cairo compatibility
        $revinfo =~ s|^((   )+)|"\t" x (length($1)/3)|e;

        $out .= $revinfo . "\n";

        $rev--;
    }
    $out .= _handleHeadFoot( $footer, $rev1, $rev2, $nrev, $maxrev );
    $out = Foswiki::Func::decodeFormatTokens($out);

    return $out;
}

sub _formatTime {
    my ( $format, $topic, $web ) = @_;

    return Foswiki::Func::expandCommonVariables( '%REVINFO{"' . $format . '"}%',
        $topic, $web );
}

sub _handleHeadFoot {

    my ( $text, $rev1, $rev2, $nrev, $maxrev ) = @_;

    if ( $rev2 >= $maxrev ) {
        $text =~ s/\$next({.*?})//g;
    }
    else {
        while ( $text =~ m/\$next({(.*?)})/ ) {
            my $args = $2 || '';

            my $newrev1 = $rev2 < $maxrev ? $rev2 + 1 : $rev2;
            my $newrev2 = $newrev1 + $nrev - 1;
            $newrev2 = $maxrev if $newrev2 > $maxrev;

            $args =~ s/'/"/g;
            $args =~ s/\$rev1/$newrev1/g;
            $args =~ s/\$rev2/$newrev2/g;
            $args =~ s/\$nrev/$nrev/g;

            my %params  = Foswiki::Func::extractParameters($args);
            my $newtext = $params{text} || $params{_DEFAULT} || '';
            my $url     = $params{url} || '';
            my $replace =
              $url
              ? "<a href='$url' class='foswikiButton'>$newtext</a>"
              : $newtext;
            $text =~ s/\$next({.*?})/$replace/;
        }
    }

    if ( $rev1 <= 1 ) {
        $text =~ s/\$previous({.*?})//g;
    }
    else {
        while ( $text =~ m/\$previous({(.*?)})/ ) {
            my $args = $2 || '';

            my $newrev2 = $rev1 > 1 ? $rev1 - 1 : 1;
            my $newrev1 = $newrev2 - $nrev + 1;
            $newrev1 = 1 if $newrev1 < 1;

            $args =~ s/'/"/g;
            $args =~ s/\$rev1/$newrev1/g;
            $args =~ s/\$rev2/$newrev2/g;
            $args =~ s/\$nrev/$nrev/g;

            my %params  = Foswiki::Func::extractParameters($args);
            my $newtext = $params{text} || $params{_DEFAULT} || '';
            my $url     = $params{url} || '';
            my $replace =
              $url
              ? "<a href='$url' class='foswikiButton'>$newtext</a>"
              : $newtext;
            $text =~ s/\$previous({.*?})/$replace/;
        }
    }

    return $text;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
