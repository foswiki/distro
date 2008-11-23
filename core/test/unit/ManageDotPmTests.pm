# NOTE: this is a VERY limited subset of subroutines in Manage.pm and should NOT be considered as unit test.

use strict;
use warnings;
use diagnostics;

package ManageDotPmTests;

use base qw(FoswikiTestCase);
use Foswiki;
use Foswiki::UI::Manage;

my $debug = 1;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub test_isValidTopicName_WebHome {
    my $this = shift;

    my $result   = Foswiki::UI::Manage::_isValidTopicName('WebHome', 'on');
    my $expected = 1;
    print("result=$result.\n")     if $debug;
    print("expected=$expected.\n") if $debug;
    $this->assert( $result eq $expected );
}

sub test_isValidTopicName_WebHome_NOT_nonwikiword {
    my $this = shift;

    my $result   = Foswiki::UI::Manage::_isValidTopicName('WebHome', '');
    my $expected = 1;
    print("result=$result.\n")     if $debug;
    print("expected=$expected.\n") if $debug;
    $this->assert( $result eq $expected );
}

sub test_isValidTopicName_Aa_nonwikiword {
    my $this = shift;

    my $result   = Foswiki::UI::Manage::_isValidTopicName('Aa', 'on');
    my $expected = 1;
    print("result=$result.\n")     if $debug;
    print("expected=$expected.\n") if $debug;
    $this->assert( $result eq $expected );
}

sub test_isValidTopicName_Aa_NOT_nonwikiword {
    my $this = shift;

    my $result   = Foswiki::UI::Manage::_isValidTopicName('Aa', '');
    my $expected = 0;
    print("result=$result.\n")     if $debug;
    print("expected=$expected.\n") if $debug;
    $this->assert( $result eq $expected );
}

sub test_makeSafeTopicName {
    my $this = shift;

	{
		my $result   = Foswiki::UI::Manage::_safeTopicName('Abc/Def');
		my $expected = 'Abc_Def';
		print("result=$result.\n")     if $debug;
		print("expected=$expected.\n") if $debug;
		$this->assert( $result eq $expected );
	}
	{
		my $result   = Foswiki::UI::Manage::_safeTopicName('Abc.Def');
		my $expected = 'Abc_Def';
		print("result=$result.\n")     if $debug;
		print("expected=$expected.\n") if $debug;
		$this->assert( $result eq $expected );
	}
	{
		my $result   = Foswiki::UI::Manage::_safeTopicName('Abc Def');
		my $expected = 'AbcDef';
		print("result=$result.\n")     if $debug;
		print("expected=$expected.\n") if $debug;
		$this->assert( $result eq $expected );
	}
}





1;
