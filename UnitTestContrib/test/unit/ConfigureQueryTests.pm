# See bottom of file for license and copyright information
use strict;
use warnings;

package ConfigureQueryTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;
use Foswiki;
use Error qw(:try);

use Foswiki::Configure::Query;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $Foswiki::Plugins::SESSION = $this->{session};
}

sub test_getcfg {
    my $this   = shift;
    my $params = {
        "keys" => [
            "{UnitTestContrib}{Configure}{STRING}",
            "{UnitTestContrib}{Configure}{COMMAND}",
            "{UnitTestContrib}{Configure}{REGEX}"
        ]
    };
    my $reporter = Foswiki::Configure::Reporter->new();
    my $result = Foswiki::Configure::Query::getcfg( $params, $reporter );
    $this->assert( !$reporter->has_level('errors') );

    #print STDERR Data::Dumper->Dump([$result]);
    $this->assert_deep_equals(
        {
            UnitTestContrib => {
                Configure => {
                    STRING  => 'STRING',
                    COMMAND => 'COMMAND',
                    REGEX   => '^regex$'
                }
            }
        },
        $result
    );
}

#sub test_getcfg_all {
#    my $this   = shift;
#    my $params = {};
#    my $result = Foswiki::Configure::Query::getcfg($params, $reporter);
#    $this->assert_deep_equals( \%Foswiki::cfg, $result );
#}

sub test_getcfg_badkey {
    my $this     = shift;
    my $params   = { "keys" => ["Not a key"] };
    my $reporter = Foswiki::Configure::Reporter->new();
    Foswiki::Configure::Query::getcfg( $params, $reporter );
    $this->assert( $reporter->has_level('errors') );
    $this->assert_matches( qr/^Bad key 'Not a key'/,
        $reporter->messages()->[0]->{text} );
}

sub test_getcfg_nokey {
    my $this     = shift;
    my $params   = { "keys" => ["{Peed}{Skills}"] };
    my $reporter = Foswiki::Configure::Reporter->new();
    Foswiki::Configure::Query::getcfg( $params, $reporter );
    $this->assert( $reporter->has_level('errors') );
    $this->assert_matches( qr/^{Peed}{Skills} not defined/,
        $reporter->messages()->[0]->{text} );
}

# For stripping parents in the spec tree if needed for print debug
sub unparent {
    my $what = shift;
    my $type = ref($what);
    return unless $type;
    if ( $type eq 'ARRAY' ) {
        foreach my $vv (@$what) {
            unparent($vv);
        }
    }
    else {
        delete $what->{parent};
        foreach my $v ( values %$what ) {
            unparent($v);
        }
    }
    return $what;
}

sub test_getspec_headline {
    my $this     = shift;
    my %params   = ( get => { headline => 'UnitTestContrib' } );
    my $reporter = Foswiki::Configure::Reporter->new();
    my $spec     = Foswiki::Configure::Query::getspec( \%params, $reporter );
    $this->assert( !$reporter->has_level('errors') );
    $this->assert_num_equals( 1, scalar @$spec );
    $this->assert_str_equals( 'UnitTestContrib', $spec->[0]->{headline} );
    my $N = scalar @{ $spec->[0]->{children} };
    $this->assert($N);
    my $i = 0;

    while ( $i < $N && $spec->[0]->{children}->[$i]->{headline} ne 'Configure' )
    {
        $i++;
    }
    $this->assert( $i < $N );
    $this->assert_str_equals( 'Configure',
        $spec->[0]->{children}->[$i]->{headline} );
    my $brats = $spec->[0]->{children}->[$i]->{children};
    $this->assert_not_null($brats);
    $this->assert_str_equals( '{UnitTestContrib}{Configure}{STRING}',
        $brats->[0]->{keys} );

    $params{depth} = 1;
    $spec = Foswiki::Configure::Query::getspec( \%params, $reporter );
    $this->assert( !$reporter->has_level('errors') );
    $this->assert_num_equals( 1, scalar @$spec );
    $this->assert_str_equals( 'UnitTestContrib', $spec->[0]->{headline} );
    $N = scalar @{ $spec->[0]->{children} };
    $this->assert($N);
    $i = 0;
    while ( $i < $N && $spec->[0]->{children}->[$i]->{headline} ne 'Configure' )
    {
        $i++;
    }
    $this->assert( $i < $N );
    $this->assert_str_equals( 'Configure',
        $spec->[0]->{children}->[$i]->{headline} );
    $this->assert_null( $spec->[0]->{children}->[$i]->{children} );
}

sub test_getspec_parent {
    my $this     = shift;
    my %params   = ( get => { parent => { headline => 'UnitTestContrib' } } );
    my $reporter = Foswiki::Configure::Reporter->new();
    my $spec     = Foswiki::Configure::Query::getspec( \%params, $reporter );
    $this->assert( !$reporter->has_level('errors') );
    my $N = scalar @$spec;
    $this->assert($N);
    my $i = 0;

    while ( $i < $N && $spec->[$i]->{headline} ne 'Configure' ) {
        $i++;
    }
    $this->assert( $i < $N );
}

sub test_getspec_STRING {
    my $this = shift;
    my %params = ( get => { keys => '{UnitTestContrib}{Configure}{STRING}' } );
    my $reporter = Foswiki::Configure::Reporter->new();
    my $spec = Foswiki::Configure::Query::getspec( \%params, $reporter );
    $this->assert( !$reporter->has_level('errors') );
    $this->assert_num_equals( 1, scalar @$spec );
    $spec = $spec->[0];
    $this->assert_str_equals( 'STRING', $spec->{typename} );
    $this->assert_str_equals( 'STRING', $spec->{default} );
    $this->assert_str_equals( '{UnitTestContrib}{Configure}{STRING}',
        $spec->{keys} );
    $this->assert_matches( qr/^When you press.*of report.*$/s, $spec->{desc} );
    $this->assert_num_equals( 4, $spec->{depth} );
    $this->assert_num_equals( 2, scalar @{ $spec->{defined_at} } );
    $this->assert_num_equals( 2, scalar @{ $spec->{FEEDBACK} } );
    my $fb = $spec->{FEEDBACK}->[0];
    $this->assert( $fb->{auth} );
    $this->assert_str_equals( 'Test',     $fb->{wizard} );
    $this->assert_str_equals( 'test1',    $fb->{method} );
    $this->assert_str_equals( 'Test one', $fb->{label} );
    $fb = $spec->{FEEDBACK}->[1];
    $this->assert( !$fb->{auth} );
    $this->assert_str_equals( 'Test',     $fb->{wizard} );
    $this->assert_str_equals( 'test1',    $fb->{method} );
    $this->assert_str_equals( 'Test two', $fb->{label} );

    my $ch = $spec->{CHECK};
    $this->assert_num_equals( 1,  scalar @$ch );
    $this->assert_num_equals( 3,  $ch->[0]->{min}->[0] );
    $this->assert_num_equals( 20, $ch->[0]->{max}->[0] );

    $params{get}->{keys} = '{UnitTestContrib}{Configure}{empty}';
    $spec = Foswiki::Configure::Query::getspec( \%params, $reporter );
    $this->assert( !$reporter->has_level('errors') );
    $this->assert_num_equals( 1, scalar @$spec );
    $spec = $spec->[0];
    $this->assert_str_equals( $params{get}->{keys}, $spec->{keys} );
    $this->assert_str_equals( 'PATH',               $spec->{typename} );
    $this->assert_str_equals( 'empty',              $spec->{default} );
}

sub test_getspec_REGEX {
    my $this = shift;
    my %params = ( get => { keys => '{UnitTestContrib}{Configure}{REGEX}' } );
    $Foswiki::cfg{UnitTestContrib}{Configure}{REGEX} = 'punk junk';
    my $reporter = Foswiki::Configure::Reporter->new();
    my $spec = Foswiki::Configure::Query::getspec( \%params, $reporter );

    #print STDERR Data::Dumper->Dump( [$spec] );
    $this->assert( !$reporter->has_level('errors') );
    $this->assert_num_equals( 1, scalar @$spec );
    $spec = $spec->[0];
    $this->assert_str_equals( 'REGEX',                $spec->{typename} );
    $this->assert_str_equals( '^regex$',              $spec->{default} );
    $this->assert_str_equals( 'Default: \'^regex$\'', $spec->{desc} );
    $this->assert_str_equals( '{UnitTestContrib}{Configure}{REGEX}',
        $spec->{keys} );
}

sub test_getspec_no_LSC {
    my $this = shift;

    # Kill the config
    $Foswiki::cfg = ();

    # Make sure we can still getspec without the whole shebange
    # going up in flames
    my $reporter = Foswiki::Configure::Reporter->new();
    my $spec = Foswiki::Configure::Query::getspec( {}, $reporter );
    $this->assert( !$reporter->has_level('errors') );
    $this->assert_num_equals( 1, scalar @$spec );
    $spec = $spec->[0];
    $this->assert_str_equals( 'SECTION', $spec->{typename} );
}

sub test_getspec_badkey {
    my $this     = shift;
    my $params   = { "keys" => "{BadKey}" };
    my $reporter = Foswiki::Configure::Reporter->new();
    try {
        Foswiki::Configure::Query::getspec( $params, $reporter );
        $this->assert( !$reporter->has_level('errors') );
    }
    catch Error::Simple with {
        my $mess = shift;
        $this->assert_matches(
            qr/^\$Not_found = {\s*\'keys\' => \'{BadKey}\'\s*};/, $mess );
    }
    otherwise {
        $this->assert(0);
    };
}

#use Foswiki::Configure::Checker;
#{
#
#    package Foswiki::Configure::Checkers::UnitTestContrib::Configure::STRING;
#    our @ISA = ('Foswiki::Configure::Checker');
#
#    sub check {
#        my ( $this, $val ) = @_;
#        return
#            $this->ERROR('Error')
#          . $this->WARN('Warning')
#          . $this->NOTE('Note');
#    }
#}

sub test_generic_check_EMAILADDRESS {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = {
        keys => ['{UnitTestContrib}{Configure}{EMAILADDRESS}'],
        set  => { '{UnitTestContrib}{Configure}{EMAILADDRESS}' => 'punk junk' }
    };
    my ( $report, $r );

    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 2, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                   $r->{level} );
    $this->assert_str_equals( 'Expands to: =punk junk=', $r->{text} );
    $r = $report->{reports}->[1];
    $this->assert_str_equals( 'warnings', $r->{level} );
    $this->assert_matches( qr/does not appear to be/, $r->{text} );

    $params->{set}->{'{UnitTestContrib}{Configure}{EMAILADDRESS}'} =
      'punk@junk.tv';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                      $r->{level} );
    $this->assert_str_equals( 'Expands to: =punk@junk.tv=', $r->{text} );
}

sub test_generic_check_DATE {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = { keys => ['{UnitTestContrib}{Configure}{DATE}'] };
    my ( $report, $r );

    $params->{set}->{'{UnitTestContrib}{Configure}{DATE}'} = 'punk junk';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 2, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                   $r->{level} );
    $this->assert_str_equals( 'Expands to: =punk junk=', $r->{text} );
    $r = $report->{reports}->[1];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/Unrecognized format/, $r->{text} );

    $params->{set}->{'{UnitTestContrib}{Configure}{DATE}'} = '10 May 1245';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 2, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                     $r->{level} );
    $this->assert_str_equals( 'Expands to: =10 May 1245=', $r->{text} );
    $r = $report->{reports}->[1];
    $this->assert_str_equals( 'notes', $r->{level} );
    $this->assert_matches( qr/ISO8601/, $r->{text} );
}

sub test_generic_check_NUMBER {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = { keys => ['{UnitTestContrib}{Configure}{NUMBER}'] };
    my ( $report, $r );

    $params->{set}->{'{UnitTestContrib}{Configure}{NUMBER}'} = 'punk junk';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/Number format/, $r->{text} );

    $params->{set}->{'{UnitTestContrib}{Configure}{NUMBER}'} = 666;
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 0, scalar( @{ $report->{reports} } ) );
}

sub test_generic_check_OCTAL {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = { keys => ['{UnitTestContrib}{Configure}{OCTAL}'] };
    my ( $report, $r );

    $params->{set}->{'{UnitTestContrib}{Configure}{OCTAL}'} = '123456789';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/Number format/, $r->{text} );

    $params->{set}->{'{UnitTestContrib}{Configure}{OCTAL}'} = '35';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 0, scalar( @{ $report->{reports} } ) );

    $params->{set}->{'{UnitTestContrib}{Configure}{OCTAL}'} = '777';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/must be no greater than 70/, $r->{text} );

    $params->{set}->{'{UnitTestContrib}{Configure}{OCTAL}'} = '0';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/must be at least 30/, $r->{text} );
}

sub test_generic_check_PATH {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = { keys => ['{UnitTestContrib}{Configure}{PATH}'] };
    my ( $report, $r );

    $params->{set}->{'{UnitTestContrib}{Configure}{PATH}'} = 'punk\\junk';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 2, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                    $r->{level} );
    $this->assert_str_equals( 'Expands to: =punk\\junk=', $r->{text} );
    $r = $report->{reports}->[1];
    $this->assert_str_equals( 'warnings', $r->{level} );
    $this->assert_matches( qr/You should use/, $r->{text} );
}

sub test_generic_check_PERL {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = { keys => ['{UnitTestContrib}{Configure}{PERL}'] };
    my ( $report, $r );

    # Can't use a set because of syntax errors
    $Foswiki::cfg{UnitTestContrib}{Configure}{PERL} = 'punk junk';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    # print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/Not a valid PERL value/, $r->{text} );
}

sub test_generic_check_REGEX_Item13077 {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = {
        keys => ['{UnitTestContrib}{Configure}{REGEX}'],
        set =>
          { '{UnitTestContrib}{Configure}{REGEX}' => '^mismatched( paren$' }
    };
    my ( $report, $r );

    # make sure Foswiki::cfg is overridden by the set
    $Foswiki::cfg{UnitTestContrib}{Configure}{REGEX} = 'punk junk';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    print STDERR Data::Dumper->Dump( [$report] );
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

}

sub test_generic_check_REGEX {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = {
        keys => ['{UnitTestContrib}{Configure}{REGEX}'],
        set  => { '{UnitTestContrib}{Configure}{REGEX}' => 'skank/fank' }
    };
    my ( $report, $r );

    # make sure Foswiki::cfg is overridden by the set
    $Foswiki::cfg{UnitTestContrib}{Configure}{REGEX} = 'punk junk';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                    $r->{level} );
    $this->assert_str_equals( 'Expands to: =skank/fank=', $r->{text} );

    # Can't use set because it will barf on the syntax
    $params->{set} = undef;
    $Foswiki::cfg{UnitTestContrib}{Configure}{REGEX} = 'oh/n[o';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$reporter]) unless $report;
    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 2, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                $r->{level} );
    $this->assert_str_equals( 'Expands to: =oh/n[o=', $r->{text} );
    $r = $report->{reports}->[1];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/Invalid regular expression/, $r->{text} );
}

sub test_generic_check_STRING {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = { keys => ['{UnitTestContrib}{Configure}{STRING}'] };
    my ( $report, $r );

    $params->{set}->{'{UnitTestContrib}{Configure}{STRING}'} = 'some garbage';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 0, scalar( @{ $report->{reports} } ) );

    $params->{set}->{'{UnitTestContrib}{Configure}{STRING}'} = 'x';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/Length must be at least/, $r->{text} );

    # H does not have nullEXPERT has nullok
    $params = {
        keys => [
            '{UnitTestContrib}{Configure}{H}',
            '{UnitTestContrib}{Configure}{EXPERT}'
        ]
    };
    $params->{set}->{'{UnitTestContrib}{Configure}{H}'}      = '';
    $params->{set}->{'{UnitTestContrib}{Configure}{EXPERT}'} = '';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 2, scalar @$report );
    $this->assert_str_equals( $params->{keys}->[0], $report->[0]->{keys} );
    $this->assert_num_equals( 1, scalar( @{ $report->[0]->{reports} } ) );
    $r = $report->[0]->{reports}->[0];
    $this->assert_str_equals( 'errors',            $r->{level} );
    $this->assert_str_equals( 'Must be non-empty', $r->{text} );

    $report = $report->[1];
    $this->assert_str_equals( $params->{keys}->[1], $report->{keys} );
    $this->assert_num_equals( 0, scalar( @{ $report->{reports} } ) );
}

sub test_generic_check_URL {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = { keys => ['{UnitTestContrib}{Configure}{URL}'] };
    my ( $report, $r );

    $params->{set}->{'{UnitTestContrib}{Configure}{URL}'} = 'not a url';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 3, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                   $r->{level} );
    $this->assert_str_equals( 'Expands to: =not a url=', $r->{text} );
    $r = $report->{reports}->[1];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/^Scheme/, $r->{text} );
    $r = $report->{reports}->[2];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/^Authority/, $r->{text} );

    $params->{set}->{'{UnitTestContrib}{Configure}{URL}'} = 'http://localhost';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                          $r->{level} );
    $this->assert_str_equals( 'Expands to: =http://localhost=', $r->{text} );
}

sub test_generic_check_URLPATH {
    my $this     = shift;
    my $reporter = Foswiki::Configure::Reporter->new();
    my @ui_path  = ( 'Extensions', 'UnitTestContrib', 'Configure' );
    my $params   = { keys => ['{UnitTestContrib}{Configure}{URLPATH}'] };
    my ( $report, $r );

    $params->{set}->{'{UnitTestContrib}{Configure}{URLPATH}'} = 'punk junk';
    $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );

    #print STDERR Data::Dumper->Dump([$report]);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];

    # keys
    $this->assert_str_equals( $params->{keys}->[0], $report->{keys} );

    # path
    $this->assert_deep_equals( \@ui_path, $report->{path} );

    # reports
    $this->assert_num_equals( 2, scalar( @{ $report->{reports} } ) );
    $r = $report->{reports}->[0];
    $this->assert_str_equals( 'notes',                   $r->{level} );
    $this->assert_str_equals( 'Expands to: =punk junk=', $r->{text} );
    $r = $report->{reports}->[1];
    $this->assert_str_equals( 'errors', $r->{level} );
    $this->assert_matches( qr/is not valid/, $r->{text} );
}

sub test_check_dependencies {
    my $this = shift;

    # DEPENDS depends on H and EXPERT
    my $params = {
        keys => ['{UnitTestContrib}{Configure}{H}'],
        set  => { '{UnitTestContrib}{Configure}{H}' => 'fruitbat' },
        check_dependencies => 1
    };
    my $reporter = Foswiki::Configure::Reporter->new();
    my $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );
    $this->assert( !$reporter->has_level('errors') );
    $this->assert_num_equals(
        3,
        scalar @$report,
        Data::Dumper->Dump( [$report] )
    );
    my @r = sort { $a->{keys} cmp $b->{keys} } @$report;
    $this->assert_str_equals( '{UnitTestContrib}{Configure}{DEP_PERL}',
        $r[0]->{keys} );
    $this->assert_str_equals( '{UnitTestContrib}{Configure}{DEP_STRING}',
        $r[1]->{keys} );
    $this->assert_str_equals( '{UnitTestContrib}{Configure}{H}',
        $r[2]->{keys} );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
