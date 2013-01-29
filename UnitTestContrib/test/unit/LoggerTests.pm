# tests for Foswiki::Logger

package LoggerTests;
use strict;
use warnings;
use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Benchmark qw(:hireswallclock);
use File::Temp();
use File::Path();
use Foswiki::Logger::PlainFile();

# NOTE: Test logs are created in the test web so they get torn down when the
# web is torn down in the superclass.
our $logDir;

sub set_up {
    my $this = shift;
    delete $Foswiki::cfg{LogFileName};
    delete $Foswiki::cfg{DebugFileName};
    delete $Foswiki::cfg{WarningFileName};
    $this->SUPER::set_up();
    $logDir = "logDir$$";
    $Foswiki::cfg{Log}{Dir} = "$logDir";
    mkdir $Foswiki::cfg{Log}{Dir};

    return;
}

sub tear_down {
    my $this = shift;

    File::Path::rmtree($logDir);
    $this->SUPER::tear_down();

    return;
}

sub skip {
    my ( $this, $test ) = @_;

    my %skip_tests = (
        'LoggerTests::verify_timing_rotate_events_LogDispatchFileLogger' =>
          'Log::Dispatch does not perform file rotation',
        'LoggerTests::verify_timing_rotate_events_LogDispatchFileRollingLogger'
          => 'Log::Dispatch does not perform file rotation',
        'LoggerTests::verify_rotate_events_LogDispatchFileLogger' =>
          'Log::Dispatch does not perform file rotation',
        'LoggerTests::verify_rotate_events_LogDispatchFileRollingLogger' =>
          'Log::Dispatch does not perform file rotation',
        'LoggerTests::verify_rotate_debug_LogDispatchFileLogger' =>
          'Log::Dispatch does not perform file rotation',
        'LoggerTests::verify_rotate_debug_LogDispatchFileRollingLogger' =>
          'Log::Dispatch does not perform file rotation',
        'LoggerTests::verify_rotate_error_LogDispatchFileLogger' =>
          'Log::Dispatch does not perform file rotation',
        'LoggerTests::verify_rotate_error_LogDispatchFileRollingLogger' =>
          'Log::Dispatch does not perform file rotation',
        'LoggerTests::verify_eachEventSince_MultiLevelsV0_LogDispatchFileLogger'
          => 'Multilevel eachEvent not implemented yet',
'LoggerTests::verify_eachEventSince_MultiLevelsV0_LogDispatchFileObfuscatingLogger'
          => 'Multilevel eachEvent not implemented yet',
'LoggerTests::verify_eachEventSince_MultiLevelsV0_LogDispatchFileRollingLogger'
          => 'Multilevel eachEvent not implemented yet',
        'LoggerTests::verify_eachEventSince_MultiLevelsV1_LogDispatchFileLogger'
          => 'Multilevel eachEvent not implemented yet',
'LoggerTests::verify_eachEventSince_MultiLevelsV1_LogDispatchFileObfuscatingLogger'
          => 'Multilevel eachEvent not implemented yet',
'LoggerTests::verify_eachEventSince_MultiLevelsV1_LogDispatchFileRollingLogger'
          => 'Multilevel eachEvent not implemented yet',

    );

    return $skip_tests{$test}
      if ( defined $test && defined $skip_tests{$test} );

    return $this->SUPER::skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
'LoggerTests::verify_LogDispatchCompatRoutines_LogDispatchFileRollingLogger'
                  => 'LogDispatch compatibility calls not available before Foswiki 1.2',
'LoggerTests::verify_LogDispatchCompatRoutines_LogDispatchFileLogger'
                  => 'LogDispatch compatibility calls not available before Foswiki 1.2',
'LoggerTests::verify_LogDispatchCompatRoutines_CompatibilityLogger'
                  => 'LogDispatch compatibility calls not available before Foswiki 1.2',
                'LoggerTests::verify_LogDispatchCompatRoutines_PlainFileLogger'
                  => 'LogDispatch compatibility calls not available before Foswiki 1.2',
'LoggerTests::verify_LogDispatchCompatRoutines_ObfuscatingLogger'
                  => 'LogDispatch compatibility calls not available before Foswiki 1.2',
'LoggerTests::verify_LogDispatchCompatRoutines_LogDispatchFileObfuscatingLogger'
                  => 'LogDispatch compatibility calls not available before Foswiki 1.2',
            }
        },
        {
            condition => { without_dep => 'Log::Log4perl::DateFormat' },
            tests     => {
'LoggerTests::verify_eachEventSinceOnEmptyLog_LogDispatchFileRollingLogger'
                  => 'Missing Log::Log4perl::DateFormat',
'LoggerTests::verify_simpleWriteAndReplay_LogDispatchFileRollingLogger'
                  => 'Missing Log::Log4perl::DateFormat',
            }
        },
        {
            condition => {
                without_dep => 'Log::Dispatch',
                without_dep => 'Foswiki::Logger::LogDispatch'
            },
            tests => {
'LoggerTests::verify_eachEventSinceOnEmptyLog_LogDispatchFileLogger'
                  => 'Missing Log::Dispatch',
'LoggerTests::verify_eachEventSinceOnSeveralLogs_LogDispatchFileLogger'
                  => 'Missing Log::Dispatch',
'LoggerTests::verify_eachEventSinceOnSeveralLogs_LogDispatchFileRollingLogger'
                  => 'Missing Log::Dispatch',
                'LoggerTests::verify_filter_LogDispatchFileLogger' =>
                  'Missing Log::Dispatch',
                'LoggerTests::verify_filter_LogDispatchFileRollingLogger' =>
                  'Missing Log::Dispatch',
                'LoggerTests::verify_simpleWriteAndReplay_LogDispatchFileLogger'
                  => 'Missing Log::Dispatch',
'LoggerTests::verify_eachEventSinceOnEmptyLog_LogDispatchFileRollingLogger'
                  => 'Missing Log::Dispatch',
'LoggerTests::verify_simpleWriteAndReplay_LogDispatchFileRollingLogger'
                  => 'Missing Log::Dispatch',
                'LoggerTests::test_LogDispatchFileEachEventSinceOnSeveralLogs'
                  => 'Missing Log::Dispatch',
'LoggerTests::test_LogDispatchFileRollingEachEventSinceOnSeveralLogs'
                  => 'Missing Log::Dispatch',
'LoggerTests::verify_eachEventSinceOnEmptyLog_LogDispatchFileRollingLogger'
                  => 'Missing Log::Dispatch',
'LoggerTests::verify_simpleWriteAndReplay_LogDispatchFileRollingLogger'
                  => 'Missing Log::Dispatch',
            }
        },
    );
}

sub CompatibilityLogger {
    my $this = shift;
    require Foswiki::Logger::Compatibility;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::Compatibility';
    $this->{logger}                    = Foswiki::Logger::Compatibility->new();
    $Foswiki::cfg{LogFileName}         = "$logDir/logfile%DATE%";
    $Foswiki::cfg{DebugFileName}       = "$logDir/debug%DATE%";
    $Foswiki::cfg{WarningFileName}     = "$logDir/warn%DATE%!!";

    return;
}

sub PlainFileLogger {
    my $this = shift;
    require Foswiki::Logger::PlainFile;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::PlainFile';
    $this->{logger} = Foswiki::Logger::PlainFile->new();

    return;
}

sub ObfuscatingLogger {
    my $this = shift;
    require Foswiki::Logger::PlainFile::Obfuscating;
    $Foswiki::cfg{Log}{Implementation} =
      'Foswiki::Logger::PlainFile::Obfuscating';
    $Foswiki::cfg{Log}{Obfuscating}{MaskIP} = 1;
    $this->{logger} = Foswiki::Logger::PlainFile::Obfuscating->new();

    return;
}

sub LogDispatchFileLogger {
    my $this = shift;
    require Foswiki::Logger::LogDispatch;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::LogDispatch';
    $Foswiki::cfg{Log}{LogDispatch}{File}{Enabled}        = 1;
    $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = 0;
    $Foswiki::cfg{Log}{LogDispatch}{MaskIP}               = 'none';
    $Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled}      = 1;
    $Foswiki::cfg{Log}{LogDispatch}{File}{FileLevels}     = {
        'events' => 'info:info',
        'error'  => 'notice:emergency',
        'debug'  => 'debug:debug',
    };
    $this->{logger} = Foswiki::Logger::LogDispatch->new();

    return;
}

sub LogDispatchFileObfuscatingLogger {
    my $this = shift;
    require Foswiki::Logger::LogDispatch;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::LogDispatch';
    $Foswiki::cfg{Log}{LogDispatch}{File}{Enabled}        = 1;
    $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = 0;
    $Foswiki::cfg{Log}{LogDispatch}{MaskIP}               = 'x.x.x.x';
    $Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled}      = 1;
    $Foswiki::cfg{Log}{LogDispatch}{File}{FileLevels}     = {
        'events' => 'info:info',
        'error'  => 'notice:emergency',
        'debug'  => 'debug:debug',
    };
    $this->{logger} = Foswiki::Logger::LogDispatch->new();

    return;
}

sub LogDispatchFileRollingLogger {
    my $this = shift;
    require Foswiki::Logger::LogDispatch;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::LogDispatch';
    $Foswiki::cfg{Log}{LogDispatch}{File}{Enabled}        = 0;
    $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = 1;
    $Foswiki::cfg{Log}{LogDispatch}{MaskIP}               = 'none';
    $Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled}      = 1;
    $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern} = '-%d{yyyy-MM}.log';
    $this->{logger} = Foswiki::Logger::LogDispatch->new();

    return;
}

sub fixture_groups {
    my %algs;
    foreach my $dir (@INC) {
        if ( opendir( my $D, "$dir/Foswiki/Logger" ) ) {
            foreach my $alg ( readdir $D ) {
                next unless $alg =~ /^(\w+)\.pm$/;
                $algs{$1} = 1;
            }
            closedir($D);
        }
        if ( opendir( my $D, "$dir/Foswiki/Logger/PlainFile" ) ) {
            foreach my $alg ( readdir $D ) {
                next unless $alg =~ /^(\w+)\.pm$/;
                $algs{$1} = 1;
            }
            closedir($D);
        }
    }
    my @groups;
    foreach my $alg ( keys %algs ) {
        my $fn;
        if ( $alg eq 'LogDispatch' ) {
            foreach my $lt (qw(File FileRolling FileObfuscating)) {
                $fn = $alg . $lt . 'Logger';
                push( @groups, $fn );
            }
        }
        else {
            $fn = $alg . 'Logger';
            push( @groups, $fn );
        }
    }

    return \@groups;
}

sub verify_eachEventSince_MultiLevelsV0 {
    my $this   = shift;
    my $time   = time;
    my $ipaddr = '1.2.3.4';
    my $tmpIP  = $ipaddr;

#  For the PlainFile::Obfuscating logger,  have the warning record hash the IP addrss
#  SMELL: This is a bit bogus, as the logger only obfuscates the 6th parameter of the log call
#  and this is *only* used for "info" type messages.  The unit test however calls all log types
#  with multiple parameters, so Obfuscation happens on any log level.

    $this->{logger}->debug( 'blahdebug', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->info( 'blahinfo', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->notice( 'blahnotice', "Green", "Eggs", "and", $tmpIP )
      if $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/;
    sleep 1;
    $this->{logger}->error( 'blaherror', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->critical( 'blahcritical', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->alert( 'blahalert', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}
      ->emergency( 'blahemergency', "Green", "Eggs", "and", $tmpIP );
    sleep 1;
    $this->{logger}->error( 'blaherror', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->critical( 'blahcritical', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->alert( 'blahalert', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}
      ->emergency( 'blahemergency', "Green", "Eggs", "and", $tmpIP );
    sleep 1;
    $this->{logger}->debug( 'blahdebug', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->info( 'blahinfo', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->notice( 'blahnotice', "Green", "Eggs", "and", $tmpIP )
      if $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/;

    if ( $Foswiki::cfg{Log}{Implementation} eq
        'Foswiki::Logger::PlainFile::Obfuscating' )
    {
        $Foswiki::cfg{Log}{Obfuscating}{MaskIP} = 0;
    }
    $this->{logger}->warn( 'blahwarning', "Green", "Eggs", "and", $tmpIP );

    my $logIP =
      ( $Foswiki::cfg{Log}{Implementation} eq
          'Foswiki::Logger::PlainFile::Obfuscating' ) ? 'x.x.x.x' : '1.2.3.4';

    my @levels =
      ( $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/ )
      ? qw(debug info notice warning error critical alert emergency)
      : qw(debug info warning error critical alert emergency);

    my $testIP = $logIP;
    my $it = $this->{logger}->eachEventSince( $time, \@levels );
    $this->assert( $it->hasNext() );

    my $logCounter;
    my $checkTime = 0;

    # Verify that we got the 13 logs written, in ascending timestamp order.
    while ( $it->hasNext() ) {
        $logCounter++;
        my $data = $it->next();

        my $level = @$data[6];
        my $t     = shift( @{$data} );
        $this->assert( $t >= $checkTime, "$t not >=  $checkTime" );
        $checkTime = $t;
    }
    $this->assert( $logCounter == 13 );

    return;
}

sub verify_eachEventSince_MultiLevelsV1 {
    my $this   = shift;
    my $time   = time;
    my $ipaddr = '1.2.3.4';
    my $tmpIP  = $ipaddr;

#  For the PlainFile::Obfuscating logger,  have the warning record hash the IP addrss
#  SMELL: This is a bit bogus, as the logger only obfuscates the 6th parameter of the log call
#  and this is *only* used for "info" type messages.  The unit test however calls all log types
#  with multiple parameters, so Obfuscation happens on any log level.

    $this->{logger}->debug( 'blahdebug', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->info( 'blahinfo', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->notice( 'blahnotice', "Green", "Eggs", "and", $tmpIP )
      if $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/;
    sleep 1;
    $this->{logger}->error( 'blaherror', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->critical( 'blahcritical', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->alert( 'blahalert', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}
      ->emergency( 'blahemergency', "Green", "Eggs", "and", $tmpIP );
    sleep 1;
    $this->{logger}->error( 'blaherror', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->critical( 'blahcritical', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->alert( 'blahalert', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}
      ->emergency( 'blahemergency', "Green", "Eggs", "and", $tmpIP );
    sleep 1;
    $this->{logger}->debug( 'blahdebug', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->info( 'blahinfo', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->notice( 'blahnotice', "Green", "Eggs", "and", $tmpIP )
      if $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/;

    if ( $Foswiki::cfg{Log}{Implementation} eq
        'Foswiki::Logger::PlainFile::Obfuscating' )
    {
        $Foswiki::cfg{Log}{Obfuscating}{MaskIP} = 0;
    }
    $this->{logger}->warn( 'blahwarning', "Green", "Eggs", "and", $tmpIP );

    my $logIP =
      ( $Foswiki::cfg{Log}{Implementation} eq
          'Foswiki::Logger::PlainFile::Obfuscating' ) ? 'x.x.x.x' : '1.2.3.4';

    my @levels =
      ( $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/ )
      ? qw(debug info notice warning error critical alert emergency)
      : qw(debug info warning error critical alert emergency);

    my $testIP = $logIP;
    my $it = $this->{logger}->eachEventSince( $time, \@levels, 1 );
    $this->assert( $it->hasNext() );

    my $logCounter;
    my $checkTime = 0;

    # Verify that we got the 13 logs written, in ascending timestamp order.
    while ( $it->hasNext() ) {
        $logCounter++;
        my $data  = $it->next();
        my $level = $data->{level};

        $this->assert(
            $data->{epoch} >= $checkTime,
            "$data->{epoch} not >=  $checkTime"
        );
        $checkTime = $data->{epoch};

    }
    $this->assert( $logCounter == 13 );

    return;
}

sub verify_LogDispatchCompatRoutines {
    my $this   = shift;
    my $time   = time;
    my $ipaddr = '1.2.3.4';
    my $tmpIP  = $ipaddr;

#  For the PlainFile::Obfuscating logger,  have the warning record hash the IP addrss
#  SMELL: This is a bit bogus, as the logger only obfuscates the 6th parameter of the log call
#  and this is *only* used for "info" type messages.  The unit test however calls all log types
#  with multiple parameters, so Obfuscation happens on any log level.

    $this->{logger}->debug( 'blahdebug', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->info( 'blahinfo', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->notice( 'blahnotice', "Green", "Eggs", "and", $tmpIP )
      if $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/;
    $this->{logger}->error( 'blaherror', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->critical( 'blahcritical', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}->alert( 'blahalert', "Green", "Eggs", "and", $tmpIP );
    $this->{logger}
      ->emergency( 'blahemergency', "Green", "Eggs", "and", $tmpIP );

    if ( $Foswiki::cfg{Log}{Implementation} eq
        'Foswiki::Logger::PlainFile::Obfuscating' )
    {
        $Foswiki::cfg{Log}{Obfuscating}{MaskIP} = 0;
    }
    $this->{logger}->warn( 'blahwarning', "Green", "Eggs", "and", $tmpIP );

    my $logIP =
      ( $Foswiki::cfg{Log}{Implementation} eq
          'Foswiki::Logger::PlainFile::Obfuscating' ) ? 'x.x.x.x' : '1.2.3.4';

    my @levels =
      ( $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/ )
      ? qw(debug info notice warning error critical alert emergency)
      : qw(debug info warning error critical alert emergency);
    foreach my $level (@levels) {
        my $ipaddr = $logIP;
        my $it = $this->{logger}->eachEventSince( $time, $level );
        $this->assert( $it->hasNext(), $level );
        my $data = $it->next();
        my $t    = shift( @{$data} );
        $this->assert( $t >= $time, "$t $time" );
        $ipaddr = 'x.x.x.x'
          if ( $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/
            && defined $Foswiki::cfg{Log}{LogDispatch}{MaskIP}
            && $Foswiki::cfg{Log}{LogDispatch}{MaskIP} eq 'x.x.x.x'
            && $level eq 'info' );

        $ipaddr = '109.104.118.183'
          if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::PlainFile::Obfuscating'
            && $level eq 'warning' );

        my $expected =
          ( $level eq 'info' )
          ? join( '.',
            ( 'blah' . $level, 'Green', 'Eggs', 'and', $ipaddr, $level ) )
          : join( '.',
            ( '', '', '', "blah$level Green Eggs and $ipaddr", '', $level ) );
        $this->assert_str_equals( $expected, join( '.', @{$data} ) );
        $this->assert( !$it->hasNext() );
    }

    return;
}

sub verify_simpleWriteAndReplayEmbeddedNewlines {
    my $this   = shift;
    my $time   = time;
    my $ipaddr = '1.2.3.4';
    my $tmpIP  = $ipaddr;

    # Verify the three levels used by Foswiki; debug, info and warning
    foreach my $level (qw(debug info warning)) {

#  For the PlainFile::Obfuscating logger,  have the warning record hash the IP addrss
#  SMELL: This is a bit bogus, as the logger only obfuscates the 6th parameter of the log call
#  and this is *only* used for "info" type messages.  The unit test however calls all log types
#  with multiple parameters, so Obfuscation happens on any log level.

        if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::PlainFile::Obfuscating'
            && $level eq 'warning' )
        {
            $Foswiki::cfg{Log}{Obfuscating}{MaskIP} = 0;
        }

        $this->{logger}
          ->log( $level, $level, "Green", "Eggs", "and\n newline\n here",
            $tmpIP );
    }

    my $logIP =
      ( $Foswiki::cfg{Log}{Implementation} eq
          'Foswiki::Logger::PlainFile::Obfuscating' ) ? 'x.x.x.x' : '1.2.3.4';

    foreach my $level (qw(debug info warning)) {
        my $ipaddr = $logIP;
        my $it = $this->{logger}->eachEventSince( $time, $level );
        $this->assert( $it->hasNext(), $level );
        my $data = $it->next();
        my $t    = shift( @{$data} );
        $this->assert( $t >= $time, "$t $time" );
        $ipaddr = 'x.x.x.x'
          if ( $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/
            && defined $Foswiki::cfg{Log}{LogDispatch}{MaskIP}
            && $Foswiki::cfg{Log}{LogDispatch}{MaskIP} eq 'x.x.x.x'
            && $level eq 'info' );

        $ipaddr = '109.104.118.183'
          if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::PlainFile::Obfuscating'
            && $level eq 'warning' );

        my $expected =
          ( $level eq 'info' )
          ? join(
            '.',
            (
                $level, 'Green', 'Eggs', "and\n newline\n here", $ipaddr,
                $level
            )
          )
          : join(
            '.',
            (
                '', '', '', "$level Green Eggs and\n newline\n here $ipaddr",
                '', $level
            )
          );
        $this->assert_str_equals( $expected, join( '.', @{$data} ) );
        $this->assert( !$it->hasNext() );
    }

    return;
}

sub verify_simpleWriteAndReplay {
    my $this   = shift;
    my $time   = time;
    my $ipaddr = '1.2.3.4';
    my $tmpIP  = $ipaddr;

    # Verify the three levels used by Foswiki; debug, info and warning
    foreach my $level (qw(debug info warning)) {

#  For the PlainFile::Obfuscating logger,  have the warning record hash the IP addrss
#  SMELL: This is a bit bogus, as the logger only obfuscates the 6th parameter of the log call
#  and this is *only* used for "info" type messages.  The unit test however calls all log types
#  with multiple parameters, so Obfuscation happens on any log level.

        if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::PlainFile::Obfuscating'
            && $level eq 'warning' )
        {
            $Foswiki::cfg{Log}{Obfuscating}{MaskIP} = 0;
        }

        $this->{logger}->log( $level, $level, "Green", "Eggs", "and", $tmpIP );
    }

    my $logIP =
      ( $Foswiki::cfg{Log}{Implementation} eq
          'Foswiki::Logger::PlainFile::Obfuscating' ) ? 'x.x.x.x' : '1.2.3.4';

    foreach my $level (qw(debug info warning)) {
        my $ipaddr = $logIP;
        my $it = $this->{logger}->eachEventSince( $time, $level );
        $this->assert( $it->hasNext(), $level );
        my $data = $it->next();
        my $t    = shift( @{$data} );
        $this->assert( $t >= $time, "$t $time" );
        $ipaddr = 'x.x.x.x'
          if ( $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/
            && defined $Foswiki::cfg{Log}{LogDispatch}{MaskIP}
            && $Foswiki::cfg{Log}{LogDispatch}{MaskIP} eq 'x.x.x.x'
            && $level eq 'info' );

        $ipaddr = '109.104.118.183'
          if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::PlainFile::Obfuscating'
            && $level eq 'warning' );

        my $expected =
          ( $level eq 'info' )
          ? join( '.', ( $level, 'Green', 'Eggs', 'and', $ipaddr, $level ) )
          : join( '.',
            ( '', '', '', "$level Green Eggs and $ipaddr", '', $level ) );
        $this->assert_str_equals( $expected, join( '.', @{$data} ) );
        $this->assert( !$it->hasNext() );
    }

    return;
}

sub verify_simpleWriteAndReplayHashEventFilter {
    my $this   = shift;
    my $time   = time;
    my $ipaddr = '1.2.3.4';

    return unless $this->{logger}->{acceptsHash};

    # Filter dropped Eggs.
    $Foswiki::cfg{Log}{Action}{Dropped} = 0;

    # Verify the three levels used by Foswiki; debug, info and warning
    foreach my $level (qw(debug info warning)) {

        if ( $level eq 'info' ) {
            $this->{logger}->log(
                {
                    level      => $level,
                    user       => $level,
                    action     => 'Dropped',
                    webTopic   => 'Eggs',
                    extra      => 'and',
                    remoteAddr => $ipaddr
                }
            );
            $this->{logger}->log(
                {
                    level      => $level,
                    user       => $level,
                    action     => 'Green',
                    webTopic   => 'Eggs',
                    extra      => 'and',
                    remoteAddr => $ipaddr
                }
            );
        }
        else {
            my @fields = ( $level, "Green", "Eggs", "and", $ipaddr );
            $this->{logger}->log( { level => $level, extra => \@fields } );
        }
    }

    foreach my $level (qw(debug info warning)) {
        my $it = $this->{logger}->eachEventSince( $time, $level );
        $this->assert( $it->hasNext(), $level );
        my $data = $it->next();
        my $t    = shift( @{$data} );
        $this->assert( $t >= $time, "$t $time" );
        $ipaddr = (
            $Foswiki::cfg{Log}{Implementation} =~ /Obfuscat/
              || ( $level eq 'info'
                && $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/
                && $Foswiki::cfg{Log}{LogDispatch}{MaskIP} eq 'x.x.x.x' )
        ) ? 'x.x.x.x' : '1.2.3.4';

        my $expected =
          ( $level eq 'info' )
          ? join( '.', ( $level, 'Green', 'Eggs', 'and', $ipaddr, $level ) )
          : join( '.',
            ( '', '', '', "$level Green Eggs and $ipaddr", '', $level ) );
        $this->assert_str_equals( $expected, join( '.', @{$data} ) );
        $this->assert( !$it->hasNext() );
    }

    return;
}

sub verify_simpleWriteAndReplayHashInterface {
    my $this   = shift;
    my $time   = time;
    my $ipaddr = '1.2.3.4';
    my $tmpIP  = $ipaddr;

    return unless $this->{logger}->{acceptsHash};

    # Verify the three levels used by Foswiki; debug, info and warning
    foreach my $level (qw(debug info warning)) {

#  For the PlainFile::Obfuscating logger,  have the warning record hash the IP addrss
#  SMELL: This is a bit bogus, as the logger only obfuscates the 6th parameter of the log call
#  and this is *only* used for "info" type messages.  The unit test however calls all log types
#  with multiple parameters, so Obfuscation happens on any log level.

        if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::PlainFile::Obfuscating'
            && $level eq 'warning' )
        {
            $Foswiki::cfg{Log}{Obfuscating}{MaskIP} = 0;
        }
        if ( $level eq 'info' ) {
            $this->{logger}->log(
                {
                    level      => $level,
                    user       => $level,
                    action     => 'Green',
                    webTopic   => 'Eggs',
                    extra      => 'and',
                    remoteAddr => $tmpIP
                }
            );
        }
        else {
            my @fields = ( $level, "Green", "Eggs", "and", $tmpIP );
            $this->{logger}->log( { level => $level, extra => \@fields } );
        }
    }

    my $logIP =
      ( $Foswiki::cfg{Log}{Implementation} eq
          'Foswiki::Logger::PlainFile::Obfuscating' ) ? 'x.x.x.x' : '1.2.3.4';

    foreach my $level (qw(debug info warning)) {
        my $ipaddr = $logIP;
        my $it = $this->{logger}->eachEventSince( $time, $level );
        $this->assert( $it->hasNext(), $level );
        my $data = $it->next();
        my $t    = shift( @{$data} );
        $this->assert( $t >= $time, "$t $time" );
        $ipaddr = 'x.x.x.x'
          if ( $Foswiki::cfg{Log}{Implementation} =~ /LogDispatch/
            && defined $Foswiki::cfg{Log}{LogDispatch}{MaskIP}
            && $Foswiki::cfg{Log}{LogDispatch}{MaskIP} eq 'x.x.x.x'
            && $level eq 'info' );

        $ipaddr = '109.104.118.183'
          if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::PlainFile::Obfuscating'
            && $level eq 'warning' );

        my $expected =
          ( $level eq 'info' )
          ? join( '.', ( $level, 'Green', 'Eggs', 'and', $ipaddr, $level ) )
          : join( '.',
            ( '', '', '', "$level Green Eggs and $ipaddr", '', $level ) );
        $this->assert_str_equals( $expected, join( '.', @{$data} ) );
        $this->assert( !$it->hasNext() );
    }

    return;
}

sub verify_eachEventSinceOnEmptyLog {
    my $this = shift;
    foreach my $level (qw(debug info warning)) {
        my $it = $this->{logger}->eachEventSince( 0, $level );
        if ( $it->hasNext() ) {
            use Data::Dumper;
            die Data::Dumper->Dump( [ $it->next() ] );
        }
        $this->assert( !$it->hasNext() );
    }

    return;
}

my $plainFileTestTime;

sub PlainFileTestTime {
    return $plainFileTestTime;
}

# Test specific to PlainFile logger
sub test_PlainFileEachEventSinceOnSeveralLogs {
    my $this   = shift;
    my $logger = Foswiki::Logger::PlainFile->new();
    my $cache  = \&Foswiki::Logger::PlainFile::_time;
    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = \&PlainFileTestTime;
    use warnings 'redefine';

    $plainFileTestTime = 3600;
    $logger->log( 'info', "Seal" );
    my $firstTime = time - 2 * 32 * 24 * 60 * 60;
    $plainFileTestTime = $firstTime;    # 2 months ago
    $logger->log( 'info', "Dolphin" );
    $plainFileTestTime += 32 * 24 * 60 * 60;    # 1 month ago
    $logger->log( 'info', "Whale" );
    $plainFileTestTime = time;                  # today
    $logger->log( 'info', "Porpoise" );

    #print STDERR "Calling eachEventSince info\n";
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

    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = $cache;
    use warnings 'redefine';

    return;
}

# Test specific to LogDispatch File logger
sub test_LogDispatchFileEachEventSinceOnSeveralLogs {
    my $this = shift;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::LogDispatch';
    $Foswiki::cfg{Log}{LogDispatch}{File}{Enabled}        = 1;
    $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = 0;
    $Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled}      = 1;
    $Foswiki::cfg{Log}{LogDispatch}{File}{FileLevels}     = {
        'events' => 'info:info',
        'error'  => 'notice:emergency',
        'debug'  => 'debug:debug',
    };
    require Foswiki::Logger::LogDispatch;
    my $logger = Foswiki::Logger::LogDispatch->new();
    my $cache  = \&Foswiki::Logger::LogDispatch::_time;
    no warnings 'redefine';
    *Foswiki::Logger::LogDispatch::_time = \&PlainFileTestTime;
    use warnings 'redefine';

    $plainFileTestTime = 3600;
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

    no warnings 'redefine';
    *Foswiki::Logger::LogDispatch::_time = $cache;
    use warnings 'redefine';

    return;
}

# Test specific to LogDispatch FileRolling logger
sub test_LogDispatchFileRollingEachEventSinceOnSeveralLogs {
    my $this = shift;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::LogDispatch';
    $Foswiki::cfg{Log}{LogDispatch}{File}{Enabled}           = 0;
    $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled}    = 1;
    $Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled}         = 1;
    $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{FileLevels} = {
        'events' => 'info:info',
        'error'  => 'notice:emergency',
        'debug'  => 'debug:debug',
    };
    require Foswiki::Logger::LogDispatch;
    my $logger = Foswiki::Logger::LogDispatch->new();
    my $cache  = \&Foswiki::Logger::LogDispatch::_time;
    no warnings 'redefine';
    *Foswiki::Logger::LogDispatch::_time = \&PlainFileTestTime;
    use warnings 'redefine';

    $plainFileTestTime = 3600;
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

    no warnings 'redefine';
    *Foswiki::Logger::LogDispatch::_time = $cache;
    use warnings 'redefine';

    return;
}

sub verify_filter {

    # with PlainFile, warning up are all crammed into one logfile
    my $this   = shift;
    my $logger = $this->{logger};
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
    $this->assert_str_equals( "Shark", $data->[4] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Bite", $data->[4] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Hurts", $data->[4] );
    $this->assert( !$it->hasNext() );

    return;
}

my $mode;     # access mode
my $mtime;    # modify time

sub PlainFileTestStat {
    return ( 0, 0, $mode, 0, 0, 0, 0, 99, 0, $mtime, 0, 0, 0, 0 );
}

sub verify_rotate_events {
    my ( $this, $num_events ) = @_;

    return
      unless $Foswiki::cfg{Log}{Implementation} =~
      '^Foswiki::Logger::PlainFile';

    my $timecache = \&Foswiki::Logger::PlainFile::_time;
    my $statcache = \&Foswiki::Logger::PlainFile::_stat;
    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = \&PlainFileTestTime;
    *Foswiki::Logger::PlainFile::_stat = \&PlainFileTestStat;
    use warnings 'redefine';

    $Foswiki::Logger::PlainFile::dontRotate = 1;

    my $then = Foswiki::Time::parseTime("2000-02-01T00:00Z");

    $plainFileTestTime = $then;
    $mode              = oct(777);

    # Don't try to rotate a non-existant log
    my $lfn = "$Foswiki::cfg{Log}{Dir}/events.log";

    my $logger = Foswiki::Logger::PlainFile->new();
    $this->assert( !-e $lfn );
    $logger->_rotate($plainFileTestTime);
    $this->assert( !-e $lfn );

    # Create the log, the entry should be stamped at $then - 1000 (last month)
    $plainFileTestTime = Foswiki::Time::parseTime("2000-01-31T23:59Z");

    # If perf testing, log $num_events
    if ($num_events) {
        my $loops = $num_events;

        while ($loops) {
            $logger->log( 'info', 'Nil carborundum illegitami' );

            $loops -= 1;
        }
    }
    else {
        $logger->log( 'info', 'Nil carborundum illegitami' );
    }
    $logger->log( 'warning',   'Nil carborundum illegitami' );
    $logger->log( 'critical',  'Nil carborundum illegitami' );
    $logger->log( 'emergency', 'Nil carborundum illegitami' );
    $logger->log( 'error',     'Nil carborundum illegitami' );
    $logger->log( 'debug',     'Nil carborundum illegitami' );
    $logger->log( 'alert',     'Nil carborundum illegitami' );

    # fake the modify time
    $mtime = $plainFileTestTime;

    $Foswiki::Logger::PlainFile::dontRotate           = 0;
    $Foswiki::Logger::PlainFile::nextCheckDue{error}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{debug}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{events} = $then;

    # now advance the clock to this month, and add another log entry. This
    # should rotate the log.
    $plainFileTestTime = $then;

    # If perf testing, report how long the next log event takes
    if ($num_events) {
        my $benchmark = timeit(
            1,
            sub {
                $logger->log( 'info', 'Salve nauta' );
            }
        );

        print timestr($benchmark) . "\n";
    }
    else {
        $logger->log( 'info', 'Salve nauta' );
    }
    $logger->log( 'warning',   'Salve nauta' );
    $logger->log( 'critical',  'Salve nauta' );
    $logger->log( 'emergency', 'Salve nauta' );
    $logger->log( 'error',     'Salve nauta' );
    $logger->log( 'debug',     'Salve nauta' );
    $logger->log( 'alert',     'Salve nauta' );

    local $/ = undef;
    $this->assert( open( my $F, '<', $lfn ) );
    my $e = <$F>;
    $this->assert_equals( "| 2000-02-01T00:00:00Z info | Salve nauta |\n", $e );
    $this->assert( close($F) );

    # We should see the creation of a backup log with
    # the last-month entry, and the current log should be cut down to
    # this month's entry.
    my $backup = $lfn;
    $backup =~ s/log$/200001/;
    $this->assert( -e $backup );

    # Skip this check if we're perf timing for num_events
    if ( !defined $num_events ) {
        $this->assert( open( $F, '<', $backup ) );
        $e = <$F>;
        $this->assert_equals(
            "| 2000-01-31T23:59:00Z info | Nil carborundum illegitami |\n",
            $e );
        $this->assert( close($F) );
    }

    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = $timecache;
    *Foswiki::Logger::PlainFile::_stat = $statcache;
    use warnings 'redefine';

    return;
}

# Item12022
sub verify_timing_rotate_events {
    my ($this) = @_;

   # On PH's 2.0GHz VMs, rotating logs ~500k rows takes around a minute,
   # exceeding 30s mod_fcgid timeout.
   #
   # On my Xeon 3.0GHz PC, this test reports (prior to Item12022 fixes):
   # 0.440275 wallclock secs ( 0.44 usr +  0.00 sys =  0.44 CPU) @  2.27/s (n=1)
   # After Foswikirev:15248:
   # 0.117118 wallclock secs ( 0.11 usr +  0.00 sys =  0.11 CPU) @  9.09/s (n=1)
    return $this->verify_rotate_events(15000);
}

sub verify_rotate_debug {
    my $this = shift;

    return
      unless $Foswiki::cfg{Log}{Implementation} =~
      '^Foswiki::Logger::PlainFile';

    my $timecache = \&Foswiki::Logger::PlainFile::_time;
    my $statcache = \&Foswiki::Logger::PlainFile::_stat;
    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = \&PlainFileTestTime;
    *Foswiki::Logger::PlainFile::_stat = \&PlainFileTestStat;
    use warnings 'redefine';

    $Foswiki::Logger::PlainFile::dontRotate = 1;

    my $then = Foswiki::Time::parseTime("2000-02-01T00:00Z");

    $plainFileTestTime = $then;
    $mode              = oct(777);

    # Don't try to rotate a non-existant log
    my $lfn = "$Foswiki::cfg{Log}{Dir}/debug.log";

    my $logger = Foswiki::Logger::PlainFile->new();
    $this->assert( !-e $lfn );
    $logger->_rotate($plainFileTestTime);
    $this->assert( !-e $lfn );

    # Create the log, the entry should be stamped at $then - 1000 (last month)
    $plainFileTestTime = Foswiki::Time::parseTime("2000-01-31T23:59Z");
    $logger->log( 'info',      'Nil carborundum illegitami' );
    $logger->log( 'warning',   'Nil carborundum illegitami' );
    $logger->log( 'critical',  'Nil carborundum illegitami' );
    $logger->log( 'emergency', 'Nil carborundum illegitami' );
    $logger->log( 'error',     'Nil carborundum illegitami' );
    $logger->log( 'debug',     'Nil carborundum illegitami' );
    $logger->log( 'alert',     'Nil carborundum illegitami' );

    # fake the modify time
    $mtime = $plainFileTestTime;

    $Foswiki::Logger::PlainFile::dontRotate           = 0;
    $Foswiki::Logger::PlainFile::nextCheckDue{error}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{debug}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{events} = $then;

    # now advance the clock to this month, and add another log entry. This
    # should rotate the log.
    $plainFileTestTime = $then;
    $logger->log( 'info',      'Salve nauta' );
    $logger->log( 'warning',   'Salve nauta' );
    $logger->log( 'critical',  'Salve nauta' );
    $logger->log( 'emergency', 'Salve nauta' );
    $logger->log( 'error',     'Salve nauta' );
    $logger->log( 'debug',     'Salve nauta' );
    $logger->log( 'alert',     'Salve nauta' );

    local $/ = undef;
    $this->assert( open( my $F, '<', $lfn ) );
    my $e = <$F>;
    $this->assert_equals( "| 2000-02-01T00:00:00Z debug | Salve nauta |\n",
        $e );
    $this->assert( close($F) );

    # We should see the creation of a backup log with
    # the last-month entry, and the current log should be cut down to
    # this month's entry.
    my $backup = $lfn;
    $backup =~ s/log$/200001/;
    $this->assert( -e $backup );

    $this->assert( open( $F, '<', $backup ) );
    $e = <$F>;
    $this->assert_equals(
        "| 2000-01-31T23:59:00Z debug | Nil carborundum illegitami |\n", $e );
    $this->assert( close($F) );

    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = $timecache;
    *Foswiki::Logger::PlainFile::_stat = $statcache;
    use warnings 'redefine';

    return;
}

sub verify_rotate_error {
    my $this = shift;

    return
      unless $Foswiki::cfg{Log}{Implementation} =~
      '^Foswiki::Logger::PlainFile';

    my $timecache = \&Foswiki::Logger::PlainFile::_time;
    my $statcache = \&Foswiki::Logger::PlainFile::_stat;
    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = \&PlainFileTestTime;
    *Foswiki::Logger::PlainFile::_stat = \&PlainFileTestStat;

    $Foswiki::Logger::PlainFile::dontRotate = 1;

    my $then = Foswiki::Time::parseTime("2000-02-01T00:00Z");

    $plainFileTestTime = $then;
    $mode              = oct(777);

    # Don't try to rotate a non-existant log
    my $lfn = "$Foswiki::cfg{Log}{Dir}/error.log";

    my $logger = Foswiki::Logger::PlainFile->new();
    $this->assert( !-e $lfn );
    $logger->_rotate($plainFileTestTime);
    $this->assert( !-e $lfn );

    # Create the log, the entry should be stamped at $then - 1000 (last month)
    $plainFileTestTime = Foswiki::Time::parseTime("2000-01-31T23:59Z");
    $logger->log( 'info',      'Nil carborundum illegitami' );
    $logger->log( 'warning',   'Nil carborundum illegitami' );
    $logger->log( 'critical',  'Nil carborundum illegitami' );
    $logger->log( 'emergency', 'Nil carborundum illegitami' );
    $logger->log( 'error',     'Nil carborundum illegitami' );
    $logger->log( 'debug',     'Nil carborundum illegitami' );
    $logger->log( 'alert',     'Nil carborundum illegitami' );

    # fake the modify time
    $mtime = $plainFileTestTime;

    $Foswiki::Logger::PlainFile::dontRotate           = 0;
    $Foswiki::Logger::PlainFile::nextCheckDue{error}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{debug}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{events} = $then;

    # now advance the clock to this month, and add another log entry. This
    # should rotate the log.
    $plainFileTestTime = $then;
    $logger->log( 'info',      'Salve nauta' );
    $logger->log( 'warning',   'Salve nauta' );
    $logger->log( 'critical',  'Salve nauta' );
    $logger->log( 'emergency', 'Salve nauta' );
    $logger->log( 'error',     'Salve nauta' );
    $logger->log( 'debug',     'Salve nauta' );
    $logger->log( 'alert',     'Salve nauta' );

    local $/ = undef;
    $this->assert( open( my $F, '<', $lfn ) );
    my $e = <$F>;
    $this->assert( close($F) );
    $this->assert_equals( $e, <<'FILE' );
| 2000-02-01T00:00:00Z warning | Salve nauta |
| 2000-02-01T00:00:00Z critical | Salve nauta |
| 2000-02-01T00:00:00Z emergency | Salve nauta |
| 2000-02-01T00:00:00Z error | Salve nauta |
| 2000-02-01T00:00:00Z alert | Salve nauta |
FILE

    # We should see the creation of a backup log with
    # the last-month entry, and the current log should be cut down to
    # this month's entry.
    my $backup = $lfn;
    $backup =~ s/log$/200001/;
    $this->assert( -e $backup );

    $this->assert( open( $F, '<', $backup ) );
    $e = <$F>;
    $this->assert_equals( $e, <<'FILE' );
| 2000-01-31T23:59:00Z warning | Nil carborundum illegitami |
| 2000-01-31T23:59:00Z critical | Nil carborundum illegitami |
| 2000-01-31T23:59:00Z emergency | Nil carborundum illegitami |
| 2000-01-31T23:59:00Z error | Nil carborundum illegitami |
| 2000-01-31T23:59:00Z alert | Nil carborundum illegitami |
FILE
    $this->assert( close($F) );

    *Foswiki::Logger::PlainFile::_time = $timecache;
    *Foswiki::Logger::PlainFile::_stat = $statcache;
    use warnings 'redefine';

    return;
}

1;
