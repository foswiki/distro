package SemiAutomaticTestCaseTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::UI::View();
use Error qw( :try );

my $VIEW_UI_FN;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    # Testcases are written using good anchors
    $Foswiki::cfg{RequireCompatibleAnchors} = 0;
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
