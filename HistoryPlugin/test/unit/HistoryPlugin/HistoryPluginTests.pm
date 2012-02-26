# See bottom of file for license and copyright information
# tests for basic formatting
package HistoryPluginTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::Time();
use Error qw( :try );
my $TEST_WEB_NAME = 'TemporaryTableFormattingTestWebHistoryPlugin';
my $tableCount    = 1;
my $debug         = 0;

sub new {
    my $self = shift()->SUPER::new( 'HistoryPlugin', @_ );
    return $self;
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
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();

    $Foswiki::cfg{Plugins}{HistoryPlugin}{Enabled} = 1;
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ( $this, $expected, $actual ) = @_;
    my $session   = $this->{session};
    my $webName   = $this->{test_web};
    my $topicName = $this->{test_topic};

    $actual =
      Foswiki::Func::expandCommonVariables( $actual, $topicName, $webName );
    $actual = Foswiki::Func::renderText( $actual, $webName, $topicName );

    $this->assert_html_equals( $expected, $actual );
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

sub _getDate {
    my ( $this, $topicObject ) = @_;

    my $epoch = $topicObject->{TOPICINFO}->[0]->{date};
    my $date =
      Foswiki::Time::formatTime( $epoch, '$day $month $year - $hour:$min' );
    return $date;
}

sub _getTopicUrl {
    my ( $this, $topicObject ) = @_;

    my $url = $topicObject->expandMacros("%SCRIPTURLPATH{view}%");
    return $url;
}

sub _trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

=pod

=cut

sub test_simple {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_format {
    my $this = shift;

    my $topicObject = $this->_createHistory( undef, 1 );
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $epoch    = $topicObject->{TOPICINFO}->[0]->{date};
    my $time     = Foswiki::Time::formatTime( $epoch, '$hour:$min:$sec' );
    my $seconds  = Foswiki::Time::formatTime( $epoch, '$seconds' );
    my $minutes  = Foswiki::Time::formatTime( $epoch, '$minutes' );
    my $hours    = Foswiki::Time::formatTime( $epoch, '$hour' );
    my $day      = Foswiki::Time::formatTime( $epoch, '$day' );
    my $wday     = Foswiki::Time::formatTime( $epoch, '$wday' );
    my $dow      = Foswiki::Time::formatTime( $epoch, '$dow' );
    my $week     = Foswiki::Time::formatTime( $epoch, '$week' );
    my $month    = Foswiki::Time::formatTime( $epoch, '$month' );
    my $mo       = Foswiki::Time::formatTime( $epoch, '$mo' );
    my $year     = Foswiki::Time::formatTime( $epoch, '$year' );
    my $ye       = Foswiki::Time::formatTime( $epoch, '$ye' );
    my $iso      = Foswiki::Time::formatTime( $epoch, '$iso' );
    my $rcs      = Foswiki::Time::formatTime( $epoch, '$rcs' );
    my $http     = Foswiki::Time::formatTime( $epoch, '$http' );
    my $longdate = Foswiki::Time::formatTime( $epoch, '$longdate' );
    my $tz       = Foswiki::Time::formatTime( $epoch, '$tz' );

    my $revInfoFormat =
'seconds=$seconds, minutes=$minutes, hours=$hours, day=$day, wday=$wday, dow=$dow, week=$week, month=$month, mo=$mo, year=$year, ye=$ye, tz=$tz, iso=$iso, rcs=$rcs, http=$http, epoch=$epoch, longdate=$longdate';
    my $revInfo = Foswiki::Func::expandCommonVariables(
        '%REVINFO{"' . $revInfoFormat . '"}%',
        $topicObject->{topic}, $topicObject->{web} );

    my $expected = <<EXPECTED;
<br /><noautolink>web=TemporaryHistoryPluginTestWebHistoryPlugin, topic=BlessMySoul, rev=1, username=ScumBag, ScumBag=ScumBag, wikiusername=TemporaryHistoryPluginUsersWeb.ScumBag, date=$date, time=$time, seconds=$seconds, minutes=$minutes, hours=$hours, day=$day, wday=$wday, dow=$dow, week=$week, month=$month, mo=$mo, year=$year, ye=$ye, tz=$tz, iso=$iso, rcs=$rcs, http=$http, epoch=$epoch, longdate=$longdate</noautolink>
EXPECTED

    my $actual = $topicObject->expandMacros(
'%HISTORY{format="<noautolink>web=$web, topic=$topic, rev=$rev, username=$username, $wikiname=$wikiname, wikiusername=$wikiusername, date=$date, time=$time, '
          . $revInfoFormat
          . '</noautolink>"}%' );

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_topic {
    my $this = shift;

    my $topicName   = 'LaysanAlbatross';
    my $topicObject = $this->_createHistory( $topicName, 5 );
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br /><noautolink>5 - LaysanAlbatross</noautolink>
<noautolink>4 - LaysanAlbatross</noautolink>
<noautolink>3 - LaysanAlbatross</noautolink>
<noautolink>2 - LaysanAlbatross</noautolink>
<noautolink>1 - LaysanAlbatross</noautolink>
EXPECTED

    my $actual =
      $topicObject->expandMacros( '%HISTORY{topic="'
          . $topicName
          . '" format="<noautolink>$rev - $topic</noautolink>"}%' );

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_topic_doesnotexist {
    my $this = shift;

    my $topicObject = $this->_createHistory();

    my $expected = <<EXPECTED;
<noautolink><span class='foswikiAlert'>HistoryPlugin error: Topic TemporaryHistoryPluginTestWebHistoryPlugin.XYZ does not exist</noautolink>
EXPECTED

    my $actual = $topicObject->expandMacros(
        '%HISTORY{topic="XYZ" format="$rev - $topic"}%');

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_topic_webtopic {
    my $this = shift;

    my $topicName   = 'LaysanAlbatross';
    my $topicObject = $this->_createHistory( $topicName, 5 );
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br /><noautolink>5 - LaysanAlbatross</noautolink>
<noautolink>4 - LaysanAlbatross</noautolink>
<noautolink>3 - LaysanAlbatross</noautolink>
<noautolink>2 - LaysanAlbatross</noautolink>
<noautolink>1 - LaysanAlbatross</noautolink>
EXPECTED

    my $webtopic = $this->{test_web} . '.' . $topicName;
    my $actual =
      $topicObject->expandMacros( '%HISTORY{topic="'
          . $webtopic
          . '" format="<noautolink>$rev - $topic</noautolink>"}%' );

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_web {
    my $this = shift;

    my $topicName   = 'LaysanAlbatross';
    my $topicObject = $this->_createHistory( $topicName, 5 );
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br /><noautolink>5 - LaysanAlbatross</noautolink>
<noautolink>4 - LaysanAlbatross</noautolink>
<noautolink>3 - LaysanAlbatross</noautolink>
<noautolink>2 - LaysanAlbatross</noautolink>
<noautolink>1 - LaysanAlbatross</noautolink>
EXPECTED

    my $web = $this->{test_web};
    my $actual =
      $topicObject->expandMacros( '%HISTORY{topic="'
          . $topicName
          . '" web="'
          . $web
          . '" format="<noautolink>$rev - $topic</noautolink>"}%' );

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_header {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<nop><h2 id="header"> header </h2>
r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
header="---++ header$n()"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_footer {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
<nop><h2 id="footer"> footer </h2>
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
footer="---++ footer$n()"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_versions_start {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="2"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_versions_start_dotdot {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="2.."
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_versions_start_dotdot_end {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="2..3"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_versions_dotdot_end {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="..2"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_versions_dotdot {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions=".."
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

versions="-1" equals versions="3" (with 4 revisions)

=cut

sub test_versions_start_minus_one {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="-1"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

versions="..-1" equals versions="3.." (with 4 revisions)

=cut

sub test_versions_end_minus_one {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="..-1"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_versions_start_zero {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="0.."
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_versions_end_zero {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="..0"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_versions_end_invalid_large {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="..99"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_versions_reverse_order {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
versions="4..2"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_rev1 {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
rev1="3"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_rev1_invalid {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
rev1="-1"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_rev2 {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
rev2="3"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_rev2_invalid_small {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />
r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
rev2="-1"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_rev1_rev2 {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
rev1="2"
rev2="3"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_rev1_rev2_reverseorder {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
rev2="2"
rev1="3"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_reverse_off {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r1 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
reverse="off"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_reverse_off_rev1_rev2 {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
reverse="off"
rev1="2"
rev2="3"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_nrev {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
<br />r4 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
nrev="2"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_deprecated_nrev_rev1_rev2 {
    my $this = shift;

    my $topicObject = $this->_createHistory();
    my $url         = $this->_getTopicUrl($topicObject);
    my $date        = $this->_getDate($topicObject);

    my $expected = <<EXPECTED;
...<br />
r3 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
r2 - $date - <a href="$url/$this->{users_web}/ScumBag">ScumBag</a><br />
...
EXPECTED

    my $actual = $topicObject->expandMacros(<<'ACTUAL');
%HISTORY{
nrev="2"
rev1="2"
rev2="3"
}%
ACTUAL

    _trimSpaces($expected);
    _trimSpaces($actual);

    $this->do_test( $expected, $actual );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
