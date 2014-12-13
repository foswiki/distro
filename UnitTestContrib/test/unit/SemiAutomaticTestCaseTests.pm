package SemiAutomaticTestCaseTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::UI::View();
use Error qw( :try );

my $VIEW_UI_FN;

# Some data used only by TestCaseAutoSearchOrder
my @test_comma_v = (
    <<'T1',
head	1.1;
access;
symbols;
locks; strict;
comment	@# @;
expand	@o@;


1.1
date	2005.12.14.21.56.33;	author KennethLavrsen;	state Exp;
branches;
next	;


desc
@none
@


1.1
log
@none
@
text
@%META:TOPICINFO{author="KennethLavrsen" date="1134597393" format="1.1" version="1.1"}%

%META:FORM{name="SearchWebForm"}%
%META:FIELD{name="TextItem" title="Text Item" value="Value_1"}%
%META:FIELD{name="NumberItem" title="Number Item" value="3"}%
@
T1

    <<'T2',
head	1.2;
access;
symbols;
locks; strict;
comment	@# @;
expand	@o@;


1.2
date	2005.12.14.22.23.23;	author KennethLavrsen;	state Exp;
branches;
next	1.1;

1.1
date	2005.12.14.21.58.17;	author KennethLavrsen;	state Exp;
branches;
next	;


desc
@none
@


1.2
log
@none
@
text
@%META:TOPICINFO{author="KennethLavrsen" date="1134599003" format="1.1" version="1.2"}%

%META:FORM{name="SearchWebForm"}%
%META:FIELD{name="TextItem" title="Text Item" value="Value_2"}%
%META:FIELD{name="NumberItem" title="Number Item" value="2"}%
@


1.1
log
@none
@
text
@d1 1
a1 1
%META:TOPICINFO{author="KennethLavrsen" date="1134597497" format="1.1" version="1.1"}%
@
T2

    <<'T3');
head	1.1;
access;
symbols;
locks; strict;
comment	@# @;
expand	@o@;


1.1
date	2005.12.14.21.59.27;	author KennethLavrsen;	state Exp;
branches;
next	;


desc
@none
@


1.1
log
@none
@
text
@%META:TOPICINFO{author="KennethLavrsen" date="1134597567" format="1.1" version="1.1"}%

%META:FORM{name="SearchWebForm"}%
%META:FIELD{name="TextItem" title="Text Item" value="Value_3"}%
%META:FIELD{name="NumberItem" title="Number Item" value="1"}%
@
T3

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    # Testcases are written using good anchors
    $Foswiki::cfg{RequireCompatibleAnchors} = 0;

    # Test using an RCS store, fo which we have some bogus topics.
    $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsLite';
    for ( my $i = 1 ; $i <= scalar @test_comma_v ; $i++ ) {
        my $f = "$Foswiki::cfg{DataDir}/TestCases/SearchTestTopic$i.txt,v";
        unlink $f if -e $f;
        open( F, '>', $f ) || die $!;
        print F $test_comma_v[ $i - 1 ];
        close(F);
    }

    $VIEW_UI_FN ||= $this->getUIFn('view');

    # This user is used in some testcases. All we need to do is make sure
    # their topic exists in the test users web
    if ( !$this->{session}
        ->topicExists( $Foswiki::cfg{UsersWebName}, 'WikiGuest' ) )
    {
        my ($to) =
          Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName}, 'WikiGuest' );
        $to->text('This user is used in some testcases');
        $to->save();
        $to->finish();
    }
    if ( !$this->{session}
        ->topicExists( $Foswiki::cfg{UsersWebName}, 'UnknownUser' ) )
    {
        my ($to) =
          Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
            'UnknownUser' );
        $to->text('This user is used in some testcases');
        $to->save();
        $to->finish();
    }

    return;
}

sub tear_down {
    my $this = shift;
    for ( my $i = 1 ; $i <= scalar @test_comma_v ; $i++ ) {
        my $f = "$Foswiki::cfg{DataDir}/TestCases/SearchTestTopic$i.txt,v";
        unlink $f if -e $f;
    }
    $this->SUPER::tear_down();
}

sub list_tests {
    my ( $this, $suite ) = @_;
    my @set = $this->SUPER::list_tests(@_);

    $this->createNewFoswikiSession();
    unless ( $this->{session}->webExists('TestCases') ) {
        print STDERR
          "Cannot run semi-automatic test cases; TestCases web not found";
        return;
    }

    if ( !eval "require Foswiki::Plugins::TestFixturePlugin; 1;" ) {
        print STDERR
"Cannot run semi-automatic test cases; could not find TestFixturePlugin";
        return;
    }
    foreach my $case ( Foswiki::Func::getTopicList('TestCases') ) {
        next unless $case =~ /^TestCaseAuto/;
        my $test = 'SemiAutomaticTestCaseTests::test_' . $case;
        no strict 'refs';
        *{$test} = sub { shift->run_testcase($case) };
        use strict 'refs';
        push( @set, $test );
    }
    $this->finishFoswikiSession();
    return @set;
}

sub run_testcase {
    my ( $this, $testcase ) = @_;
    my $query = Unit::Request->new(
        {
            test => 'compare',
            debugenableplugins =>
              'TestFixturePlugin,SpreadSheetPlugin,InterwikiPlugin',
            skin => 'pattern'
        }
    );
    $query->path_info("/TestCases/$testcase");
    $Foswiki::cfg{INCLUDE}{AllowURLs} = 1;
    $Foswiki::cfg{Plugins}{TestFixturePlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{TestFixturePlugin}{Module} =
      'Foswiki::Plugins::TestFixturePlugin';
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, 'ProjectContributor' );
    $topicObject->text('none');
    $topicObject->save();
    $topicObject->finish();
    my ($text) = $this->capture( $VIEW_UI_FN, $this->{session} );

    unless ( $text =~ m#<font color="green">ALL TESTS PASSED</font># ) {
        $this->assert( open( my $F, '>', "${testcase}_run.html" ) );
        print $F $text;
        $this->assert( close $F );
        $query->delete('test');
        ($text) = $this->capture( $VIEW_UI_FN, $this->{session} );
        $this->assert( open( $F, '>', "${testcase}.html" ) );
        print $F $text;
        $this->assert( close $F );
        $this->assert( 0,
"$testcase FAILED - output in ${testcase}.html and ${testcase}_run.html"
        );
    }

    return;
}

sub test_suppresswarning {
    return;
}

1;
