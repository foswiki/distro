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
            "{UnitTestContrib}{Configure}{COMMAND}"
        ]
    };
    my $reporter = Foswiki::Configure::Reporter->new();
    my $result = Foswiki::Configure::Query::getcfg( $params, $reporter );
    $this->assert( !$reporter->has_level('errors') );
    $this->assert_deep_equals(
        {
            UnitTestContrib => {
                Configure => {
                    STRING  => 'STRING',
                    COMMAND => 'COMMAND'
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

sub test_getspec {
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
    $this->assert_matches( qr/^When you press.*of report.$/s, $spec->{desc} );
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

use Foswiki::Configure::Checker;
{

    package Foswiki::Configure::Checkers::UnitTestContrib::Configure::STRING;
    our @ISA = ('Foswiki::Configure::Checker');

    sub check {
        my ( $this, $val ) = @_;
        return
            $this->ERROR('Error')
          . $this->WARN('Warning')
          . $this->NOTE('Note');
    }
}

sub test_check {
    my $this = shift;

    # force an error - STRING length
    my $params = {
        keys => ["{UnitTestContrib}{Configure}{STRING}"],
        set  => { "{UnitTestContrib}{Configure}{STRING}" => 'no' }
    };
    my $reporter = Foswiki::Configure::Reporter->new();
    my $report =
      Foswiki::Configure::Query::check_current_value( $params, $reporter );
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];
    $this->assert_str_equals( '{UnitTestContrib}{Configure}{STRING}',
        $report->{keys} );
    $this->assert_str_equals( 'Extensions',      $report->{path}->[0] );
    $this->assert_str_equals( 'UnitTestContrib', $report->{path}->[1] );
    $this->assert_str_equals( 'Configure',       $report->{path}->[2] );
    $this->assert_num_equals( 1, scalar( @{ $report->{reports} } ) );
    $this->assert_str_equals( 'errors', $report->{reports}->[0]->{level} );
    $this->assert_matches( qr/3/, $report->{reports}->[0]->{text} );
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
