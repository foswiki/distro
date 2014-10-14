# See bottom of file for license and copyright information
use strict;
use warnings;

package SaveTests;

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
    $this->{lscpath} =
      Foswiki::Configure::FileUtil::findFileOnPath('Foswiki.spec');
    $this->{lscpath} =~ s/Foswiki\.spec/LocalSite.cfg/;
    $this->{test_work_dir} = $Foswiki::cfg{WorkingDir};
    if ( open( F, '<', $this->{lscpath} ) ) {
        local $/ = undef;
        my $c = <F>;
        close F;
        $this->{safe_lsc} = $c;
    }
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

    $this->SUPER::tear_down();
    print STDERR "Tearing down $this->{lscpath}\n";
    if ( $this->{safe_lsc} ) {
        open( F, '>', $this->{lscpath} );
        print F $this->{safe_lsc};
        close(F);
    }
    else {
        unlink $this->{lscpath};
    }
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

sub test_changecfg {
    my $this   = shift;
    my $params = {
        clear => [
            '{Plugins}{ConfigurePlugin}{Test}{EXPERT}',
            '{Plugins}{ConfigurePlugin}{Test}{URL}'
        ],
        set => {
            '{TestA}'                                  => 'Shingle',
            '{TestB}{Ruin}'                            => 'Ribbed',
            '{"Test-Key"}'                             => 'newtestkey',
            '{TestKey}'                                => 'newval',
            '{Plugins}{ConfigurePlugin}{Test}{SELECT}' => 'choice'
        },
        purge => 1,
    };
    my $result = Foswiki::Plugins::ConfigurePlugin::changecfg($params);
    $this->assert_num_equals( 4,  $result->{added} );
    $this->assert_num_equals( 1,  $result->{changed} );
    $this->assert_num_equals( 2,  $result->{cleared} );
    $this->assert_num_equals( 19, $result->{purged} );
    $this->assert_str_equals( 'newtestkey', $Foswiki::cfg{'Test-Key'} );
    $this->assert( !exists $Foswiki::cfg{Test}{Key} );
    $this->assert( !exists $Foswiki::cfg{TestDontCountMe} );
    $this->assert_str_equals( "Shingle", $Foswiki::cfg{TestA} );
    $this->assert_str_equals( "Ribbed",  $Foswiki::cfg{TestB}{Ruin} );

    # Check it was written correctly
    delete $Foswiki::cfg{Test};
    open( F, '<',
        Foswiki::Configure::FileUtil::findFileOnPath('LocalSite.cfg') )
      || die $@;
    local $/ = undef;
    my $c = <F>;
    close F;

    $c =~ s/^\$Foswiki::cfg/\$blah/gm;
    my %blah;
    eval $c;
    %Foswiki::cfg = ();    #{ConfigurationFinished} = 0;
    Foswiki::Configure::Load::readConfig( 1, 1 );
    delete $Foswiki::cfg{ConfigurationFinished};

    #$Data::Dumper::Sortkeys = 1;
    #my @x = split(/\n/, Data::Dumper->Dump([\%Foswiki::cfg]));
    #my @y = split(/\n/, Data::Dumper->Dump([\%blah]));
    #use Algorithm::Diff;
    #my $diff = Algorithm::Diff->new(\@x, \@y);
    #$diff->Base(1);
    #while(  $diff->Next()  ) {
    #    next   if  $diff->Same();
    #    my $sep = '';
    #    if(  ! $diff->Items(2)  ) {
    #        printf "%d,%dd%d\n",
    #        $diff->Get(qw( Min1 Max1 Max2 ));
    #    } elsif(  ! $diff->Items(1)  ) {
    #        printf "%da%d,%d\n",
    #        $diff->Get(qw( Max1 Min2 Max2 ));
    #    } else {
    #        $sep = "---\n";
    #        printf "%d,%dc%d,%d\n",
    #        $diff->Get(qw( Min1 Max1 Min2 Max2 ));
    #    }
    #    print "< $_\n"   for  $diff->Items(1);
    #    print $sep;
    #    print "> $_\n"   for  $diff->Items(2);
    #}

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
