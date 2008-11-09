use strict;

package SemiAutomaticTestCaseTests;

use base qw(TWikiFnTestCase);

use strict;
use TWiki;
use TWiki::UI::View;
use Error qw( :try );

sub list_tests {
    my ($this, $suite) = @_;
    my @set = $this->SUPER::list_tests(@_);

    my $twiki = new TWiki();
    unless( $twiki->{store}->webExists('TestCases')) {
        print STDERR "Cannot run semi-automatic test cases; TestCases web not found";
        return;
    }
    eval "use TWiki::Plugins::TestFixturePlugin";
    if ($@) {
        print STDERR "Cannot run semi-automatic test cases; could not find TestFixturePlugin";
        $twiki->finish();
        return;
    }
    foreach my $case ($twiki->{store}->getTopicNames('TestCases')) {
        next unless $case =~ /^TestCaseAuto/;
        my $test = 'SemiAutomaticTestCaseTests::test_'.$case;
        no strict 'refs';
        *$test = sub { shift->run_testcase($case) };
        use strict 'refs';
        push(@set, $test);
    }
    $twiki->finish();
    return @set;
}

sub run_testcase {
    my ( $this, $testcase ) = @_;
    my $query = new Unit::Request({
        test=>'compare',
        debugenableplugins=>'TestFixturePlugin,InterwikiPlugin',
        skin=>'pattern'});
    $query->path_info( "/TestCases/$testcase" );
    $TWiki::cfg{Plugins}{TestFixturePlugin}{Enabled} = 1;
    my $twiki = new TWiki( $this->{test_user_login}, $query );
    $twiki->{store}->saveTopic(
        $twiki->{user}, $this->{users_web}, 'ProjectContributor', 'none');
    my ($text, $result) = $this->capture( \&TWiki::UI::View::view, $twiki);
    unless( $text =~ m#<font color="green">ALL TESTS PASSED</font># ) {
        open(F,">${testcase}_run.html");
        print F $text;
        close F;
        $query->delete('test');
        ($text, $result) = $this->capture( \&TWiki::UI::View::view, $twiki);
        open(F,">${testcase}.html");
        print F $text;
        close F;
        $this->assert(0, "$testcase FAILED - output in ${testcase}.html and ${testcase}_run.html");
    }
    $twiki->finish();
}

sub test_suppresswarning {
}

1;
