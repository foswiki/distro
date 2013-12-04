# See bottom of file for license and copyright information
use strict;
use warnings;

package ConfigurePluginTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use strict;
use warnings;
use Foswiki;
use Error qw(:try);

use Foswiki::Plugins::ConfigurePlugin;

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
            "{Plugins}{ConfigurePlugin}{Test}{STRING}",
            "{Plugins}{ConfigurePlugin}{Test}{COMMAND}"
        ]
    };
    my $result = Foswiki::Plugins::ConfigurePlugin::getcfg($params);
    $this->assert_deep_equals(
        {
            Plugins => {
                ConfigurePlugin => {
                    Test => {
                        STRING  => 'STRING',
                        COMMAND => 'COMMAND'
                    }
                }
            }
        },
        $result
    );
}

sub test_getcfg_all {
    my $this   = shift;
    my $params = {};
    my $result = Foswiki::Plugins::ConfigurePlugin::getcfg($params);
    $this->assert_deep_equals( \%Foswiki::cfg, $result );
}

sub test_getcfg_badkey {
    my $this = shift;
    my $params = { "keys" => ["Not a key"] };
    try {
        Foswiki::Plugins::ConfigurePlugin::getcfg($params);
    }
    catch Error::Simple with {
        my $mess = shift;
        $this->assert_matches( qr/^Bad key 'Not a key'/, $mess );
    }
    otherwise {
        $this->assert(0);
    };
}

sub test_getcfg_nokey {
    my $this = shift;
    my $params = { "keys" => ["{Peed}{Skills}"] };
    try {
        Foswiki::Plugins::ConfigurePlugin::getcfg($params);
    }
    catch Error::Simple with {
        my $mess = shift;
        $this->assert_matches( qr/^{Peed}{Skills} not defined/, $mess );
    }
    otherwise {
        $this->assert(0);
    };
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

sub test_getspec {
    my $this   = shift;
    my %params = ( keys => '{Plugins}{ConfigurePlugin}{Test}{STRING}' );
    my $spec   = Foswiki::Plugins::ConfigurePlugin::getspec( \%params );
    $this->assert_num_equals( 1, scalar @$spec );
    $spec = $spec->[0];
    $this->assert_str_equals( 'STRING',      $spec->{type} );
    $this->assert_str_equals( $params{keys}, $spec->{keys} );
    $this->assert_str_equals( 'STRING',      $spec->{spec_value} );

    $params{keys} = '{Plugins}{ConfigurePlugin}{Test}{empty}';
    $spec = Foswiki::Plugins::ConfigurePlugin::getspec( \%params );
    $this->assert_num_equals( 1, scalar @$spec );
    $spec = $spec->[0];
    $this->assert_str_equals( 'PATH',        $spec->{type} );
    $this->assert_str_equals( $params{keys}, $spec->{keys} );
    $this->assert_str_equals( 'empty',       $spec->{spec_value} );
}

sub test_getspec_no_LSC {
    my $this = shift;

    # Kill the config
    $Foswiki::cfg = ();

    # Make sure we can still getspec without the whole shebange
    # going up in flames
    my $spec = Foswiki::Plugins::ConfigurePlugin::getspec( {} );
    $this->assert_num_equals( 1, scalar @$spec );
    $spec = $spec->[0];
    $this->assert_str_equals( 'ROOT', $spec->{type} );
}

sub test_getspec_children {
    my $this = shift;
    my $use_section;
    my $params = { children => 1 };
    my $ss = Foswiki::Plugins::ConfigurePlugin::getspec($params);
    $this->assert_num_equals( 1, scalar(@$ss) );
    $this->assert_equals( "ROOT", $ss->[0]->{type} );
    $this->assert_null( $ss->[0]->{title} );
    $this->assert( scalar( @{ $ss->[0]->{children} } ) );

    foreach my $spec ( @{ $ss->[0]->{children} } ) {
        $this->assert( $spec->{type} eq 'SECTION', $spec->{type} );
        $this->assert_null( $spec->{children} );
        if ( !$use_section ) {
            $use_section = $spec->{title};
        }
    }

    $params = { parent => { title => $use_section }, children => 0 };
    $ss = Foswiki::Plugins::ConfigurePlugin::getspec($params);
    foreach my $spec (@$ss) {
        $this->assert_equals( $use_section, $spec->{parent}->{title} );
        $this->assert_null( $spec->{children} );
    }

    $params = { title => $use_section, children => 1 };
    $ss = Foswiki::Plugins::ConfigurePlugin::getspec($params);
    foreach my $spec (@$ss) {
        $this->assert_not_null( $spec->{children} );
        foreach my $subspec ( @{ $spec->{children} } ) {
            $this->assert_null( $subspec->{children} );
        }
    }

    # Check pluggables
}

sub test_getspec_badkey {
    my $this = shift;
    my $params = { "keys" => "{BadKey}" };
    try {
        Foswiki::Plugins::ConfigurePlugin::getspec($params);
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

    package Foswiki::Configure::Checkers::Plugins::ConfigurePlugin::Test::STRING;
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
    my $this   = shift;
    my $params = { "{Plugins}{ConfigurePlugin}{Test}{STRING}" => 'Theory' };
    my $report = Foswiki::Plugins::ConfigurePlugin::check($params);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];
    $this->assert_str_equals( '{Plugins}{ConfigurePlugin}{Test}{STRING}',
        $report->{keys} );
    $this->assert_str_equals( 'errors',          $report->{level} );
    $this->assert_str_equals( 'Extensions',      $report->{sections}->[0] );
    $this->assert_str_equals( 'ConfigurePlugin', $report->{sections}->[1] );
    $this->assert_str_equals( 'Testing',         $report->{sections}->[2] );
    $this->assert_matches( qr/Error/,   $report->{message} );
    $this->assert_matches( qr/Warning/, $report->{message} );
    $this->assert_matches( qr/Note/,    $report->{message} );
}

sub test_check_dependencies {
    my $this = shift;

    # DEPENDS depends on H and EXPERT
    my $params = {
        '{Plugins}{ConfigurePlugin}{Test}{H}' => 'fruitbat',
        'check_dependent'                     => 1
    };
    my $report = Foswiki::Plugins::ConfigurePlugin::check($params);
    $this->assert_num_equals( 2, scalar @$report );
    my ( $first, $second );
    if ( $report->[0]->{keys} =~ /DEPENDS/ ) {
        ( $first, $second ) = ( $report->[0], $report->[1] );
    }
    else {
        ( $first, $second ) = ( $report->[1], $report->[0] );
    }
    $this->assert_str_equals( '{Plugins}{ConfigurePlugin}{Test}{DEPENDS}',
        $first->{keys} );
    $this->assert_str_equals( '{Plugins}{ConfigurePlugin}{Test}{H}',
        $second->{keys} );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
