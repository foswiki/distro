package RCSConfigureTests;

use strict;
use warnings;

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Error qw( :try );
use File::Temp();
use FindBin;
use File::Path qw(mkpath rmtree);

use Foswiki::Configure::Checkers::RCSChecker        ();

#Item11955
sub test_checkRCSProgram {
    my ($this) = @_;
    my $checkerObj =
      Foswiki::Configure::Checkers::RCSChecker->new('Test::Foswiki::Configure::Dummy');

    $this->assert( !exists $Foswiki::cfg{RCS}{foo} );
    local $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsWrap';

    # Don't forget that the cmd is sanitized/untainted...
    local $Foswiki::cfg{RCS}{foo} = 'rcs';
    $this->assert( !$checkerObj->checkRCSProgram('foo') );

    return;
}

{

    package Test::Foswiki::Configure::Dummy;
    use Foswiki::Configure::Value();
    local our @ISA = 'Foswiki::Configure::Value';

    sub inc { }
}

1;
