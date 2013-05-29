# See bottom of file for license and copyright information
use strict;
use warnings;

package ConfigurePluginTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use strict;
use warnings;
use Foswiki;
use CGI;

use Foswiki::Plugins::ConfigurePlugin;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->{test_work_dir} = $Foswiki::cfg{WorkingDir};
    open( F, '<',
        Foswiki::Plugins::ConfigurePlugin::SpecEntry::findFileOnPath(
            'LocalSite.cfg')
    ) || die $@;
    local $/ = undef;
    my $c = <F>;
    close F;
    $this->{safe_lsc} = $c;
}

sub tear_down {
    my $this = shift;

    # make sure the correct config comes back
    $Foswiki::cfg{ConfigurationFinished} = 0;
    Foswiki::Configure::Load::readConfig( 0, 0 );

    # Got to restore this, otherwise SUPER::tear_down will eat
    # the one restored from LSC
    $Foswiki::cfg{WorkingDir} = $this->{test_work_dir};
    open( F, '>',
        Foswiki::Plugins::ConfigurePlugin::SpecEntry::findFileOnPath(
            'LocalSite.cfg')
    ) || die $@;
    print F $this->{safe_lsc};
    close(F);
    $this->SUPER::tear_down();
}

sub test_getcfg {
    my $this = shift;
    my $params = { "keys" => [ "{DataDir}", "{Store}{Implementation}" ] };
    my @result =
      Foswiki::Plugins::ConfigurePlugin::getcfg( $this->{session}, $params );
    $this->assert_num_equals( 200, $result[0] );
    $this->assert_null( $result[1] );
    $this->assert_deep_equals(
        {
            Store => { Implementation => $Foswiki::cfg{Store}{Implementation} },
            DataDir => $Foswiki::cfg{DataDir}
        },
        $result[2]
    );
}

sub test_getcfg_all {
    my $this   = shift;
    my $params = {};
    my @result =
      Foswiki::Plugins::ConfigurePlugin::getcfg( $this->{session}, $params );
    $this->assert_num_equals( 200, $result[0] );
    $this->assert_null( $result[1] );
    $this->assert_deep_equals( \%Foswiki::cfg, $result[2] );
}

sub test_getcfg_badkey {
    my $this = shift;
    my $params = { "keys" => ["Not a key"] };
    my @result =
      Foswiki::Plugins::ConfigurePlugin::getcfg( $this->{session}, $params );
    $this->assert_num_equals( 400, $result[0] );
    $this->assert_str_equals( "Bad key 'Not a key'", $result[1] );
    $this->assert_null( $result[2] );
}

sub test_getcfg_nokey {
    my $this = shift;
    my $params = { "keys" => ["{Peed}{Skills}"] };
    my @result =
      Foswiki::Plugins::ConfigurePlugin::getcfg( $this->{session}, $params );
    $this->assert_num_equals( 404, $result[0] );
    $this->assert_str_equals( "{Peed}{Skills} not defined", $result[1] );
    $this->assert_null( $result[2] );
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
    my $this = shift;
    my $params = { "keys" => "{DataDir}" };
    my @result =
      Foswiki::Plugins::ConfigurePlugin::getspec( $this->{session}, $params );
    $this->assert_num_equals( 200, $result[0] );
    $this->assert_null( $result[1] );
    my $spec = $result[2];
    $this->assert_str_equals( 'PATH',      $spec->{type} );
    $this->assert_str_equals( '{DataDir}', $spec->{keys} );
}

sub test_getspec_badkey {
    my $this = shift;
    my $params = { "keys" => "{BadKey}" };
    my @result =
      Foswiki::Plugins::ConfigurePlugin::getspec( $this->{session}, $params );
    $this->assert_num_equals( 404, $result[0] );
    $this->assert_matches( qr/^\$Not_found = {\s*\'keys\' => \'{BadKey}\'\s*};/,
        $result[1] );
}

sub test_check {
    my $this = shift;
    my $params = { Log => { Implementation => 'Foswiki::Logger::PlainFile' } };
    my @result =
      Foswiki::Plugins::ConfigurePlugin::check( $this->{session}, $params );
    $this->assert_num_equals( 200, $result[0] );
    my $report = $result[1];
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];
    $this->assert_str_equals( '{Log}{Implementation}', $report->{keys} );
    $this->assert_str_equals( 'warnings',              $report->{level} );
    $this->assert_matches( qr/On busy systems/, $report->{message} );
}

sub test_changecfg {
    my $this = shift;
    $Foswiki::cfg{Test}{Key}  = 'value1';
    $Foswiki::cfg{'Test-Key'} = 'value2';
    $Foswiki::cfg{'TestKey'}  = 'value3';
    delete $Foswiki::cfg{TestA};
    delete $Foswiki::cfg{TestB}{Ruin};
    my $params = {
        clear => [ '{Test-Key}', '{Test}{Key}', '{TestDontCountMe}' ],
        set   => {
            '{TestA}'       => 'Shingle',
            '{TestB}{Ruin}' => 'Ribbed',
            '{Test-Key}'    => 'newtestkey',
            '{TestKey}'     => 'newval'
        }
    };
    my @result =
      Foswiki::Plugins::ConfigurePlugin::changecfg( $this->{session}, $params );
    $this->assert( 200, $result[0] );
    $this->assert_null( $result[1] );
    $this->assert_str_equals( 'Added: 3; Changed: 1; Cleared: 2', $result[2] );
    $this->assert_str_equals( 'newtestkey', $Foswiki::cfg{'Test-Key'} );
    $this->assert( !exists $Foswiki::cfg{Test}{Key} );
    $this->assert( !exists $Foswiki::cfg{TestDontCountMe} );
    $this->assert_str_equals( "Shingle", $Foswiki::cfg{TestA} );
    $this->assert_str_equals( "Ribbed",  $Foswiki::cfg{TestB}{Ruin} );

    # Check it was written correctly
    delete $Foswiki::cfg{Test};
    open( F, '<',
        Foswiki::Plugins::ConfigurePlugin::SpecEntry::findFileOnPath(
            'LocalSite.cfg')
    ) || die $@;
    local $/ = undef;
    my $c = <F>;
    close F;
    $c =~ s/^\$Foswiki::cfg/\$blah/gm;
    my %blah;
    eval $c;
    die $@ if $@;
    $Foswiki::cfg{ConfigurationFinished} = 0;
    Foswiki::Configure::Load::readConfig( 1, 1 );
    $this->assert_deep_equals( \%Foswiki::cfg, \%blah );
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
