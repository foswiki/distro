# tests for Foswiki::Logger

package Logger;
use base qw( FoswikiTestCase );

use strict;
use File::Temp;
use File::Path;
use Foswiki::Logger::PlainFile;

# NOTE: Test logs are created in the test web so they get torn down when the
# web is torn down in the superclass.

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $Foswiki::cfg{Log}{Dir} = "logDir$$";
    mkdir $Foswiki::cfg{Log}{Dir};
}

sub tear_down {
    my $this = shift;

    File::Path::rmtree( $Foswiki::cfg{Log}{Dir} );
    $this->SUPER::tear_down();
}

sub fixture_groups {
    my %algs;
    foreach my $dir (@INC) {
        if ( opendir( D, "$dir/Foswiki/Logger" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ /^(\w+)\.pm$/;
                $algs{$1} = 1;
            }
            closedir(D);
        }
    }
    my @groups;
    foreach my $alg ( keys %algs ) {
        my $fn = $alg . 'Logger';
        push( @groups, $fn );
        next if ( defined(&$fn) );
        my $class = "Foswiki::Logger::$alg";
        eval <<HERE;
sub $fn {
    my \$this = shift;
    require $class;
    \$this->{logger} = new $class();
}
HERE
        die $@ if $@;
    }

    return \@groups;
}

sub verify_simpleWriteAndReplay {
    my $this = shift;
    my $time = time;

    # Verify the three levels used by Foswiki; debug, info and warning
    foreach my $level qw(debug info warning) {
        $this->{logger}->log( $level, $level, "Green", "Eggs", "and", "Ham" );
    }
    foreach my $level qw(debug info warning) {
        my $it = $this->{logger}->eachEventSince( $time, $level );
        $this->assert( $it->hasNext(), $level );
        my $data = $it->next();
        my $t    = shift(@$data);
        $this->assert( $t >= $time, "$t $time" );
        $this->assert_str_equals( "$level.Green.Eggs.and.Ham",
            join( '.', @$data ) );
        $this->assert( !$it->hasNext() );
    }
}

sub verify_eachEventSinceOnEmptyLog {
    my $this = shift;
    foreach my $level qw(debug info warning) {
        my $it = $this->{logger}->eachEventSince( 0, $level );
        $this->assert( !$it->hasNext() );
    }
}

my $plainFileTestTime;

sub PlainFileTestTime {
    return $plainFileTestTime;
}

# Test specific to PlainFile logger
sub test_eachEventSinceOnSeveralLogs {
    my $this   = shift;
    my $logger = new Foswiki::Logger::PlainFile();
    my $cache  = \&Foswiki::Logger::PlainFile::_time;
    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = \&PlainFileTestTime;
    $plainFileTestTime = 3600;    # 1am on 1st Jan 1970
    $logger->log( 'info', "Seal" );
    my $firstTime = time - 2 * 32 * 24 * 60 * 60;
    $plainFileTestTime = $firstTime;    # 2 months ago
    $logger->log( 'info', "Dolphin" );
    $plainFileTestTime += 32 * 24 * 60 * 60;    # 1 month ago
    $logger->log( 'info', "Whale" );
    $plainFileTestTime = time;                  # today
    $logger->log( 'info', "Porpoise" );

    my $it = $logger->eachEventSince( 0, 'info' );
    my $data;
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( 3600, $data->[0] );
    $this->assert_str_equals( "Seal", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( $firstTime, $data->[0] );
    $this->assert_str_equals( "Dolphin", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Whale", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( $plainFileTestTime, $data->[0] );
    $this->assert_str_equals( "Porpoise", $data->[1] );
    $this->assert( !$it->hasNext() );

    # Check the date filter
    $it = $logger->eachEventSince( $firstTime, 'info' );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( $firstTime, $data->[0] );
    $this->assert_str_equals( "Dolphin", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Whale", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( $plainFileTestTime, $data->[0] );
    $this->assert_str_equals( "Porpoise", $data->[1] );
    $this->assert( !$it->hasNext() );

    *Foswiki::Logger::PlainFile::_time = $cache;
    use warnings 'redefine';
}

sub test_filter {

    # with PlainFile, warning up are all crammed into one logfile
    my $this   = shift;
    my $logger = new Foswiki::Logger::PlainFile();
    $logger->log( 'warning',  "Shark" );
    $logger->log( 'error',    "Dolphin" );
    $logger->log( 'critical', "Injury" );
    $logger->log( 'warning',  "Bite" );
    $logger->log( 'alert',    "Ram" );
    $logger->log( 'warning',  "Hurts" );
    $logger->log( 'critical', "Doctors" );

    my $it = $logger->eachEventSince( 0, 'warning' );
    my $data;
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Shark", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Bite", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Hurts", $data->[1] );
    $this->assert( !$it->hasNext() );
}

1;
