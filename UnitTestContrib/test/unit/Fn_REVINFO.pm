use strict;

# tests for the correct expansion of REVINFO

package Fn_REVINFO;
use base qw( TWikiFnTestCase );

use strict;
use TWiki;
use Error qw( :try );

sub new {
    $TWiki::cfg{Register}{AllowLoginName} =  1;
    my $self = shift()->SUPER::new('REVINFO', @_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $this->{twiki}->{store}->saveTopic(
        $this->{test_user_cuid}, $this->{users_web},
        "GropeGroup",
        "   * Set GROUP = ScumBag,WikiGuest\n");
    $this->{twiki}->{store}->saveTopic(
        $this->{test_user_cuid}, $this->{test_web},
        "GlumDrop", "Burble\n");
}

sub test_basic {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO%', $this->{test_web}, $this->{test_topic});
    my $guest = TWiki::Func::getWikiName();
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$guest$/) {
        $this->assert(0, $ui);
    }
}

sub test_basic2 {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO%', $this->{test_web}, 'GlumDrop');
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/) {
        $this->assert(0, $ui);
    }
}

sub test_basic3 {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{topic="GlumDrop"}%', $this->{test_web}, 'GlumDrop');
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/) {
        $this->assert(0, $ui);
    }
}
sub test_thisWebVars {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{topic="%BASEWEB%.GlumDrop"}%', $this->{test_web}, 'GlumDrop');
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/) {
        $this->assert(0, $ui);
    }
}

#the following 2 return with reasonable looking non-0, but with WikiGuest as author - perhaps there's a bigger bug out there.
sub BROKENtest_thisTopicVars {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{topic="%BASETOPIC%"}%', $this->{test_web}, 'GlumDrop');
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/) {
        $this->assert(0, $ui);
    }
}

sub BROKENtest_thisWebTopicVars {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{topic="%BASEWEB%.%BASETOPIC%"}%', $this->{test_web}, 'GlumDrop');
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/) {
        $this->assert(0, $ui);
    }
}

sub test_otherWeb {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{topic="GropeGroup" web="'.$this->{users_web}.'"}%',
        $this->{test_web}, $this->{test_topic});
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/) {
        $this->assert(0, $ui);
    }
}

sub test_otherWeb2 {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{topic="'.$this->{users_web}.'.GropeGroup"}%',
        $this->{test_web}, $this->{test_topic});
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/) {
        $this->assert(0, $ui);
    }
}

sub test_formatUser {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{format="$username $wikiname $wikiusername"}%',
        $this->{test_web}, 'GlumDrop');
    $this->assert_str_equals("$this->{test_user_login} $this->{test_user_wikiname} $this->{users_web}\.$this->{test_user_wikiname}", $ui);
}

sub test_compatibility1 {
    my $this = shift;
    # Create a topic with raw meta to force a wikiname into the author field.
    # The wikiname must be for a user who is in WikiUsers.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if ($TWiki::cfg{StoreImpl} ne 'RcsLite' &&
          $TWiki::cfg{StoreImpl} ne 'RcsWrap') {
        return;
    }
    $this->assert(open(
        F, '>', "$TWiki::cfg{DataDir}/$this->{test_web}/CrikeyMoses.txt"));
    print F <<'HERE';
%META:TOPICINFO{author="ScumBag" date="1120846368" format="1.1" version="$Rev: 16686 $"}%
HERE
    close(F);
    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{format="$username $wikiname"}%',
        $this->{test_web}, 'CrikeyMoses');
    $this->assert_str_equals("scum ScumBag", $ui);

}

sub test_compatibility2 {
    my $this = shift;
    # Create a topic with raw meta to force a login into the author field.
    # The login must be for a user who is in WikiUsers.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if ($TWiki::cfg{StoreImpl} ne 'RcsLite' &&
          $TWiki::cfg{StoreImpl} ne 'RcsWrap') {
        return;
    }
    $this->assert(open(
        F, '>', "$TWiki::cfg{DataDir}/$this->{test_web}/CrikeyMoses.txt"));
    print F <<'HERE';
%META:TOPICINFO{author="scum" date="1120846368" format="1.1" version="$Rev: 16686 $"}%
HERE
    close(F);
    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{format="$username $wikiname"}%',
        $this->{test_web}, 'CrikeyMoses');
    $this->assert_str_equals("scum ScumBag", $ui);

}

sub test_5873 {
    my $this = shift;
    # Create a topic with raw meta to force a login into the author field.
    # The login must be for a user who does not exist.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if ($TWiki::cfg{StoreImpl} ne 'RcsLite' &&
          $TWiki::cfg{StoreImpl} ne 'RcsWrap') {
        return;
    }
    $this->assert(open(
        F, '>', "$TWiki::cfg{DataDir}/$this->{test_web}/GeeWillikins.txt"));
    print F <<'HERE';
%META:TOPICINFO{author="eltonjohn" date="1120846368" format="1.1" version="$Rev: 16686 $"}%
HERE
    close(F);
    $TWiki::cfg{RenderLoggedInButUnknownUsers} = 0;
    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{format="$username $wikiname $wikiusername"}%',
        $this->{test_web}, 'GeeWillikins');
    $this->assert_str_equals("eltonjohn eltonjohn eltonjohn", $ui);
    $TWiki::cfg{RenderLoggedInButUnknownUsers} = 1;
    $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{format="$username $wikiname $wikiusername"}%',
        $this->{test_web}, 'GeeWillikins');
    $this->assert_str_equals("unknown unknown unknown", $ui);
}

# SMELL: need to test for other revs specified by the 'rev' parameter

# SMELL: need to test for the format parameter strings:
# $web $topic $rev $time $date $rcs $http $email $iso $sec $min $hou
# $day $wday $dow $week $mo $ye $epoch $tz $comment 

1;
