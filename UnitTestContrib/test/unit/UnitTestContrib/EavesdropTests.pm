use strict;

# Test the Unit::Eavesdrop package

package EavesdropTests;

use Unit::TestCase;
our @ISA = qw( Unit::TestCase );

use Error qw( :try );

use Unit::Eavesdrop;

my $topicquery;

my $testFilename = __PACKAGE__.".$$.temp";
my $teeFilename = "$testFilename.tee";

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

}

sub tear_down {
    my $this = shift;
    
    eval { close EAVESDROPTESTS; }; # in case it was still open
    if (-e $testFilename) {
        unlink $testFilename or die $!;
    }
    if (-e $teeFilename) {
        unlink $teeFilename or die $!;
    }

    # Always do this, and always do it last
    $this->SUPER::tear_down();
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

#================================================================================
#================================================================================

sub test_printOnUnopenedFile {
    my $this = shift;

    my $result = open EAVESDROPTESTS, ">", $testFilename;
    $this->assert($result, "open $testFilename to write: $!");
    $result = print EAVESDROPTESTS "Before eavesdropping\n";
    $this->assert($result, "print before eavesdropping: $!");

    my $filehandleName = __PACKAGE__.'::'.'EAVESDROPTESTS';

    my $eavesdropper = new Unit::Eavesdrop($filehandleName);
    $this->assert($eavesdropper, "new Unit::Eavesdropper: $@");

    $result = open my $tee, ">", $teeFilename;
    $this->assert($result, "open $teeFilename to write: $!");
    $eavesdropper->teeTo($tee);

    $result = print EAVESDROPTESTS "After eavesdropping\n";
    $this->assert($result, "print after eavesdropping: $!");

    $result = close EAVESDROPTESTS;
    $this->assert($result, "close EAVESDROPTESTS: $!");

    {
        local $^W = 1; # expect warnings
        local $SIG{__WARN__} = sub { die $_[0]; };
        $result = "Magic string";
        eval { $result = print EAVESDROPTESTS "Never-never land"; };
        $this->assert_matches(qr/^print on closed filehandle $filehandleName at \S*EavesdropTests.pm line \d+/, $@);
        $this->assert_str_equals("Magic string", $result);
    }

    {
        local $^W = 0; # ignore warnings
        $result = print EAVESDROPTESTS "Hear something that was never said\n";
    }
    $this->assert_null($result, "print to closed filehandle should fail");

    $eavesdropper->finish();
    undef $eavesdropper;

    $result = open my $readback, "<", $testFilename;
    $this->assert($result, "open $testFilename to read: $!");
    local $/ = undef; # slurp entire file
    $this->assert_str_equals(<<'EXPECTED', <$readback>);
Before eavesdropping
After eavesdropping
EXPECTED

    $result = open $tee, "<", $teeFilename;
    $this->assert($result, "open $teeFilename to read: $!");
    $this->assert_str_equals(<<'EXPECTED', <$tee>);
After eavesdropping
Hear something that was never said
EXPECTED

}

#================================================================================

1;
