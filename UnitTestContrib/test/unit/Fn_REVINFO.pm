# tests for the correct expansion of REVINFO

package Fn_REVINFO;
use strict;
use warnings;
use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::Time();
use Error qw( :try );

sub new {
    my ( $class, @args ) = @_;

    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    return $class->SUPER::new( 'REVINFO', @args );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $this->{guest_wikiname} = Foswiki::Func::getWikiName();
    $this->{session}->{user} = $this->{test_user_cuid};    # OUCH
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "GropeGroup" );
    $topicObject->text("   * Set GROUP = ScumBag,WikiGuest\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, "GlumDrop" );
    $topicObject->text("Burble\n");
    $topicObject->save();
    $topicObject->finish();

    return;
}

sub test_basic {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%REVINFO%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{guest_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }

    return;
}

sub test_basic2 {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros('%REVINFO%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
    $topicObject->finish();

    return;
}

sub test_basic3 {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros('%REVINFO{topic="GlumDrop"}%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
    $topicObject->finish();

    return;
}

sub test_thisWebVars {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'GlumDrop' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{topic="%BASEWEB%.GlumDrop"}%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
    $topicObject->finish();

    return;
}

#the following 2 return with reasonable looking non-0, but with WikiGuest as author - perhaps there's a bigger bug out there.
sub BROKENtest_thisTopicVars {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros('%REVINFO{topic="%BASETOPIC%"}%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
    $topicObject->finish();

    return;
}

sub BROKENtest_thisWebTopicVars {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'GlumDrop' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{topic="%BASEWEB%.%BASETOPIC%"}%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
    $topicObject->finish();

    return;
}

sub test_otherWeb {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{topic="GropeGroup" web="' . $this->{users_web} . '"}%',
    );
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
    $topicObject->finish();

    return;
}

sub test_otherWeb2 {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{topic="' . $this->{users_web} . '.GropeGroup"}%' );
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
    $topicObject->finish();

    return;
}

sub test_formatUser {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username $wikiname $wikiusername"}%');
    $this->assert_str_equals(
"$this->{test_user_login} $this->{test_user_wikiname} $this->{users_web}\.$this->{test_user_wikiname}",
        $ui
    );
    $topicObject->finish();

    return;
}

sub test_compatibility1 {
    my $this = shift;

    # Create a topic with raw meta to force a wikiname into the author field.
    # The wikiname must be for a user who is in WikiUsers.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if ( $Foswiki::cfg{Store}{Implementation} !~ /Rcs(Lite|Wrap)$/ ) {
        return;
    }
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'CrikeyMoses' );
    $topicObject->text( <<'HERE');
%META:TOPICINFO{author="ScumBag" date="1120846368" format="1.1" version="$Rev$"}%
HERE
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'CrikeyMoses' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{format="$username $wikiname"}%');
    $this->assert_str_equals( "scum ScumBag", $ui );
    $topicObject->finish();

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
      Foswiki::Func::readTopic( $this->{test_web}, 'CrikeyMoses' );
    $topicObject->text( <<'HERE');
%META:TOPICINFO{author="scum" date="1120846368" format="1.1" version="$Rev$"}%
HERE
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'CrikeyMoses' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{format="$username $wikiname"}%');
    $this->assert_str_equals( "scum ScumBag", $ui );
    $topicObject->finish();

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
            "$Foswiki::cfg{DataDir}/$this->{test_web}/GeeWillikins.txt"
        )
    );
    print $F <<'HERE';
%META:TOPICINFO{author="eltonjohn" date="1120846368" format="1.1" version="$Rev$"}%
HERE
    $this->assert( close($F) );
    $Foswiki::cfg{RenderLoggedInButUnknownUsers} = 0;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'GeeWillikins' );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username $wikiname $wikiusername"}%');
    $this->assert_str_equals( "eltonjohn eltonjohn eltonjohn", $ui );
    $Foswiki::cfg{RenderLoggedInButUnknownUsers} = 1;
    $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username $wikiname $wikiusername"}%');
    $this->assert_str_equals( "unknown unknown unknown", $ui );
    $topicObject->finish();

    return;
}

sub test_42 {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "HappyPill" );
    $topicObject->text("   * Set ALLOWTOPICVIEW = CarlosCastenada\n");
    $topicObject->save();
    $topicObject->finish();
    $this->createNewFoswikiSession();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros(
            '%REVINFO{topic="'
          . $this->{test_web}
          . '.HappyPill" format="$username $wikiname $wikiusername"}%',
    );
    $this->assert( $ui =~ /No permission to view/ );
    $topicObject->finish();

    return;
}

#see http://trunk.foswiki.org/Tasks/Item8708
#since pre-history, there were 'i' options on the regex's for formatRevision
#this is undoccoed, and kills SpreadSheetPlugin's attempts to use $DATE and $TIME as _its_ inner language.
#so I've removed it.
sub test_CaseSensitiveFormatString {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros( '%REVINFO{format="$DATE"}%', );
    $this->assert_str_equals( '$DATE', $ui );
    $topicObject->finish();

    return;
}

# test for different revs and format strings
sub test_Item9538 {
    my $this = shift;

    my ($topicObject) = $this->_createHistory();

    my $ui = $topicObject->expandMacros(<<'OFNIVER');
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
$this->{test_web} 4
BlessMySoul 4
4
OFNIVER

    my $t = $topicObject->expandMacros('%REVINFO{"$epoch"}%');
    $this->assert( $t =~ /^\d+$/ && $t != 0, $t );

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
    $topicObject->finish();

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
    $topicObject->finish();

    return;
}

sub _createHistory {
    my ( $this, $topic, $num ) = @_;

    $topic ||= 'BlessMySoul';
    $num   ||= 4;

    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
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
