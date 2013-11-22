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
    $this->{test_work_dir} = $Foswiki::cfg{WorkingDir};
    open( F, '<',
        Foswiki::Plugins::ConfigurePlugin::SpecEntry::findFileOnPath(
            'LocalSite.cfg')
    ) || die $@;
    local $/ = undef;
    my $c = <F>;
    close F;
    $this->{safe_lsc} = $c;
    $Foswiki::Plugins::SESSION = $this->{session};
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
    my $this   = shift;
    my $params = { "keys" => [ "{DataDir}", "{Store}{Implementation}" ] };
    my $result = Foswiki::Plugins::ConfigurePlugin::getcfg($params);
    $this->assert_deep_equals(
        {
            Store => { Implementation => $Foswiki::cfg{Store}{Implementation} },
            DataDir => $Foswiki::cfg{DataDir}
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
    my $params = { "keys" => "{DataDir}" };
    my $spec   = Foswiki::Plugins::ConfigurePlugin::getspec($params);
    $this->assert_num_equals( 1, scalar @$spec );
    $spec = $spec->[0];
    $this->assert_str_equals( 'PATH',                 $spec->{type} );
    $this->assert_str_equals( '{DataDir}',            $spec->{keys} );
    $this->assert_str_equals( $Foswiki::cfg{DataDir}, $spec->{value} );
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

sub test_check {
    my $this   = shift;
    my $params = { "{Log}{Implementation}" => 'Foswiki::Logger::PlainFile' };
    my $report = Foswiki::Plugins::ConfigurePlugin::check($params);
    $this->assert_num_equals( 1, scalar @$report );
    $report = $report->[0];
    $this->assert_str_equals( '{Log}{Implementation}', $report->{keys} );
    $this->assert_str_equals( 'warnings',              $report->{level} );
    $this->assert_str_equals( 'Logging and Statistics',
        $report->{sections}->[0] );
    $this->assert_str_equals( 'Logging', $report->{sections}->[1] );
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
    my $result = Foswiki::Plugins::ConfigurePlugin::changecfg($params);
    $this->assert_str_equals( 'Added: 3; Changed: 1; Cleared: 2', $result );
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
    %Foswiki::cfg = ();    #{ConfigurationFinished} = 0;
    Foswiki::Configure::Load::readConfig( 1, 1 );

    #die Data::Dumper->Dump([$Foswiki::cfg{Plugins}]);
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
