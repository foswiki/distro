# tests for the correct expansion of REVINFO

package Fn_REVINFO;
use v5.14;

use Foswiki();
use Foswiki::Time();
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

has guest_wikiname     => ( is => 'rw', );
has test_user_wikiname => ( is => 'rw', );

around BUILDARGS => sub {
    my $orig = shift;

    # SMELL Wouldn't it be better set in set_up and restored in tear_up?
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    return $orig->( @_, testSuite => 'REVINFO' );
};

around set_up => sub {
    my $orig = shift;
    my $this = shift;
    $orig->( $this, @_ );
    $this->guest_wikiname( Foswiki::Func::getWikiName() );
    $this->app->user( $this->test_user_cuid );    # OUCH
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->users_web, "GropeGroup" );
    $topicObject->text("   * Set GROUP = ScumBag,WikiGuest\n");
    $topicObject->save();
    undef $topicObject;
    ($topicObject) = Foswiki::Func::readTopic( $this->test_web, "GlumDrop" );
    $topicObject->text("Burble\n");
    $topicObject->save();

    return;
};

sub test_basic {
    my $this = shift;

    my $ui             = $this->test_topicObject->expandMacros('%REVINFO%');
    my $users_web      = $this->users_web;
    my $guest_wikiname = $this->guest_wikiname;
    unless ( $ui =~
        m/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $users_web\.$guest_wikiname$/ )
    {
        $this->assert( 0, $ui );
    }

    return;
}

sub test_basic2 {
    my $this = shift;

    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'GlumDrop' );
    my $ui            = $topicObject->expandMacros('%REVINFO%');
    my $users_web     = $this->users_web;
    my $test_user_wikiname = $this->test_user_wikiname;
    unless ( $ui =~
        m/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $users_web\.$test_user_wikiname$/ )
    {
        $this->assert( 0, $ui );
    }

    return;
}

sub test_basic3 {
    my $this = shift;

    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'GlumDrop' );
    my $ui        = $topicObject->expandMacros('%REVINFO{topic="GlumDrop"}%');
    my $users_web = $this->users_web;
    my $test_user_wikiname = $this->test_user_wikiname;
    unless ( $ui =~
        m/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $users_web\.$test_user_wikiname$/ )
    {
        $this->assert( 0, $ui );
    }

    return;
}

sub test_thisWebVars {
    my $this = shift;

    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'GlumDrop' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{topic="%BASEWEB%.GlumDrop"}%');
    my $users_web          = $this->users_web;
    my $test_user_wikiname = $this->test_user_wikiname;
    unless ( $ui =~
        m/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $users_web\.$test_user_wikiname$/ )
    {
        $this->assert( 0, $ui );
    }

    return;
}

#the following 2 return with reasonable looking non-0, but with WikiGuest as author - perhaps there's a bigger bug out there.
sub BROKENtest_thisTopicVars {
    my $this = shift;

    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'GlumDrop' );
    my $ui = $topicObject->expandMacros('%REVINFO{topic="%BASETOPIC%"}%');
    my $users_web          = $this->users_web;
    my $test_user_wikiname = $this->test_user_wikiname;
    unless ( $ui =~
        m/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $users_web\.$test_user_wikiname$/ )
    {
        $this->assert( 0, $ui );
    }

    return;
}

sub BROKENtest_thisWebTopicVars {
    my $this = shift;

    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'GlumDrop' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{topic="%BASEWEB%.%BASETOPIC%"}%');
    my $users_web          = $this->users_web;
    my $test_user_wikiname = $this->test_user_wikiname;
    unless ( $ui =~
        m/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $users_web\.$test_user_wikiname$/ )
    {
        $this->assert( 0, $ui );
    }

    return;
}

sub test_otherWeb {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{topic="GropeGroup" web="' . $this->users_web . '"}%',
    );
    my $users_web          = $this->users_web;
    my $test_user_wikiname = $this->test_user_wikiname;
    unless ( $ui =~
        m/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $users_web\.$test_user_wikiname$/ )
    {
        $this->assert( 0, $ui );
    }

    return;
}

sub test_otherWeb2 {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{topic="' . $this->users_web . '.GropeGroup"}%' );
    my $users_web          = $this->users_web;
    my $test_user_wikiname = $this->test_user_wikiname;
    unless ( $ui =~
        m/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $users_web\.$test_user_wikiname$/ )
    {
        $this->assert( 0, $ui );
    }

    return;
}

sub test_formatUser {
    my $this = shift;

    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'GlumDrop' );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username $wikiname $wikiusername"}%');
    $this->assert_str_equals(
        $this->test_user_login . " "
          . $this->test_user_wikiname . " "
          . $this->users_web . "."
          . $this->test_user_wikiname,
        $ui
    );

    return;
}

sub test_std_escapes {
    my $this = shift;

    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'GlumDrop' );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username$comma $wikiname $lt$wikiusername$gt"}%');
    $this->assert_str_equals(
        $this->test_user_login . ", "
          . $this->test_user_wikiname . " <"
          . $this->users_web . "."
          . $this->test_user_wikiname . ">",
        $ui
    );

    return;
}

sub test_compatibility1 {
    my $this = shift;

    # Create a topic with raw meta to force a wikiname into the author field.
    # The wikiname must be for a user who is in WikiUsers.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if ( $Foswiki::cfg{Store}{Implementation} !~ /(Rcs(Lite|Wrap)|PlainFile)$/ )
    {
        return;
    }
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, 'CrikeyMoses' );
    $topicObject->put(
        'TOPICINFO',
        {
            author  => "ScumBag",
            date    => "1120846368",
            format  => "1.1",
            version => '$Rev$'
        }
    );
    $topicObject->save();
    undef $topicObject;
    ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'CrikeyMoses' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{format="$username $wikiname"}%');
    $this->assert_str_equals( "scum ScumBag", $ui );

    return;
}

sub test_compatibility2 {
    my $this = shift;

    # Create a topic with raw meta to force a login into the author field.
    # The login must be for a user who is in WikiUsers.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if ( $Foswiki::cfg{Store}{Implementation} !~ /Rcs(Lite|Wrap)$/ ) {
        return;
    }
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, 'CrikeyMoses' );
    $topicObject->put(
        'TOPICINFO',
        {
            author  => "ScumBag",
            date    => "1120846368",
            format  => "1.1",
            version => '$Rev$'
        }
    );
    $topicObject->save();
    undef $topicObject;
    ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'CrikeyMoses' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{format="$username $wikiname"}%');
    $this->assert_str_equals( "scum ScumBag", $ui );

    return;
}

sub test_5873 {
    my $this = shift;

    # Create a topic with raw meta to force a login into the author field.
    # The login must be for a user who does not exist.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if ( $Foswiki::cfg{Store}{Implementation} !~ /Rcs(Lite|Wrap)$ / ) {
        return;
    }
    $this->assert(
        open(
            my $F, '>',
            "$Foswiki::cfg{DataDir}/" . $this->test_web . "/GeeWillikins.txt"
        )
    );
    print $F <<'HERE';
%META:TOPICINFO{author="eltonjohn" date="1120846368" format="1.1" version="$Rev$"}%
HERE
    $this->assert( close($F) );
    $Foswiki::cfg{RenderLoggedInButUnknownUsers} = 0;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, 'GeeWillikins' );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username $wikiname $wikiusername"}%');
    $this->assert_str_equals( "eltonjohn eltonjohn eltonjohn", $ui );
    $Foswiki::cfg{RenderLoggedInButUnknownUsers} = 1;
    $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username $wikiname $wikiusername"}%');
    $this->assert_str_equals( "unknown unknown unknown", $ui );

    return;
}

sub test_42 {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, "HappyPill" );
    $topicObject->text("   * Set ALLOWTOPICVIEW = CarlosCastenada\n");
    $topicObject->save();
    undef $topicObject;
    $this->createNewFoswikiApp;
    ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'GlumDrop' );
    my $ui = $topicObject->expandMacros(
            '%REVINFO{topic="'
          . $this->test_web
          . '.HappyPill" format="$username $wikiname $wikiusername"}%',
    );
    $this->assert( $ui =~ m/No permission to view/ );

    return;
}

#see http://trunk.foswiki.org/Tasks/Item8708
#since pre-history, there were 'i' options on the regex's for formatRevision
#this is undoccoed, and kills SpreadSheetPlugin's attempts to use $DATE and $TIME as _its_ inner language.
#so I've removed it.
sub test_CaseSensitiveFormatString {
    my $this = shift;

    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'GlumDrop' );
    my $ui = $topicObject->expandMacros( '%REVINFO{format="$DATE"}%', );
    $this->assert_str_equals( '$DATE', $ui );

    return;
}

# test for different revs and format strings
sub test_Item9538 {
    my $this = shift;

    my ($topicObject) = $this->_createHistory();

    my $test_web = $this->test_web;
    my $ui       = $topicObject->expandMacros(<<'OFNIVER');
%REVINFO{"$rev" rev="1"}%
%REVINFO{"$rev" rev="1.2"}%
%REVINFO{"$rev" topic="BlessMySoul" rev="3"}%
%REVINFO{"$rev" topic="BlessMySoul" rev="1.4"}%
%REVINFO{"$rev"}%
%REVINFO{"$web $rev" rev="0"}%
%REVINFO{"$topic $rev" rev=""}%
%REVINFO{"$rev" topic="BlessMySoul"}%
OFNIVER
    $this->assert_str_equals( <<"OFNIVER", $ui );
1
2
3
4
4
$test_web 4
BlessMySoul 4
4
OFNIVER

    my $t = $topicObject->expandMacros('%REVINFO{"$epoch"}%');
    $this->assert( $t =~ m/^\d+$/ && $t != 0, $t );

    my $x = Foswiki::Time::formatTime( $t, '$hour:$min:$sec' );
    my $y = $topicObject->expandMacros('%REVINFO{"$time"}%');
    $x = Foswiki::Time::formatTime( $t, $Foswiki::cfg{DefaultDateFormat} );
    $y = $topicObject->expandMacros('%REVINFO{"$date"}%');
    $this->assert_str_equals( $x, $y );

    foreach my $f (
        qw(rcs http email iso longdate sec min hou day wday
        dow week we mo ye epoch tz)
      )
    {
        my $tf = '$' . $f;
        $x = Foswiki::Time::formatTime( $t, $tf );
        $y = $topicObject->expandMacros("%REVINFO{\"$tf\"}%");
        $this->assert_str_equals( $x, $y );
    }

    return;
}

# test for combinations of format strings
sub test_Item10476 {
    my $this = shift;

    my ($topicObject) = $this->_createHistory();
    my $format =
'sec=$sec, seconds=$seconds, min=$min, minutes=$minutes, hou=$hou, hours=$hours, day=$day, wday=$wday, dow=$dow, week=$week, we=$we, month=$month, mo=$mo, ye=$ye, year=$year, ye=$ye, tz=$tz, iso=$iso, isotz=$isotz, rcs=$rcs, http=$http, epoch=$epoch, longdate=$longdate';

    my $ui = $topicObject->expandMacros( '%REVINFO{"' . $format . '"}%' );

    my $epoch = $topicObject->expandMacros('%REVINFO{"$epoch"}%');
    my $expected = Foswiki::Time::formatTime( $epoch, $format );
    $this->assert_str_equals( $ui, $expected );

    return;
}

sub _createHistory {
    my ( $this, $topic, $num ) = @_;

    $topic ||= 'BlessMySoul';
    $num   ||= 4;

    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, $topic );
    $topicObject->save();    # rev 1

    my @texts = [
        'Spontaneous eructation',
        'Inspired delusion',
        'Painful truth',
        'Shitload of money'
    ];
    my @versionTexts = @texts[ 1 .. $num - 1 ];

    foreach my $text (@versionTexts) {
        $topicObject->text($text);
        $topicObject->save( forcenewrevision => 1 );
    }

    return $topicObject;
}
1;
