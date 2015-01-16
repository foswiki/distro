# See bottom of file for license and copyright information

# Tests for the core 'Save' wizard.

package ConfigureTestCase;

use strict;
use warnings;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Error qw(:try);

use Foswiki::Configure::FileUtil;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->{lscpath} =
      Foswiki::Configure::FileUtil::findFileOnPath('LocalSite.cfg');
    $this->{test_work_dir} = $Foswiki::cfg{WorkingDir};
    local $/ = undef;

    if ( -e $this->{lscpath} ) {
        open( F, '<', $this->{lscpath} )
          or die "Can't open  $this->{lscpath} for read: $!";
        my $c = <F>;
        close F;
        $this->{safe_lsc} = $c;
    }

    if ( open( F, '>', $this->{lscpath} ) ) {
        print F <<'LSC';
$Foswiki::cfg{SystemWebName} = 'System'; # TWikiCompatibilityPlugin needs this
$Foswiki::cfg{UnitTestContrib}{Configure}{STRING} = 'Rope';
$Foswiki::cfg{UnitTestContrib}{Configure}{BOOLEAN} = 0;
$Foswiki::cfg{UnitTestContrib}{Configure}{COMMAND} = 'Instruction';
$Foswiki::cfg{UnitTestContrib}{Configure}{DATE} = '23 Jan 2012';
$Foswiki::cfg{UnitTestContrib}{Configure}{EMAILADDRESS} = 'oleg@spam.ru';
$Foswiki::cfg{UnitTestContrib}{Configure}{OCTAL} = 333;
$Foswiki::cfg{UnitTestContrib}{Configure}{PASSWORD} = 'pass';
$Foswiki::cfg{UnitTestContrib}{Configure}{PATH} = 'road';
$Foswiki::cfg{UnitTestContrib}{Configure}{SELECTCLASS} = 'Foswiki::Configure::Value';
$Foswiki::cfg{UnitTestContrib}{Configure}{SELECT} = 'drive';
$Foswiki::cfg{UnitTestContrib}{Configure}{URLPATH} = '/nowhere';
$Foswiki::cfg{UnitTestContrib}{Configure}{URL} = 'http://google.com';
$Foswiki::cfg{UnitTestContrib}{Configure}{H} = 'hidden';
$Foswiki::cfg{UnitTestContrib}{Configure}{EXPERT} = 'iot';
$Foswiki::cfg{UnitTestContrib}{Configure}{empty} = 'full';
$Foswiki::cfg{UnitTestContrib}{Configure}{undefok} = 'value';
$Foswiki::cfg{UnitTestContrib}{Configure}{DEP_STRING} = 'xxx$Foswiki::cfg{UnitTestContrib}{Configure}{H}xxx';
$Foswiki::cfg{UnitTestContrib}{Configure}{DEP_PERL} = {
    'string' => 'real$Foswiki::cfg{UnitTestContrib}{Configure}{URL}/man'
};
$Foswiki::cfg{UnitTestContrib}{Configure}{PERL_HASH} = { a => 5, b => 6 };
$Foswiki::cfg{UnitTestContrib}{Configure}{PERL_ARRAY} = [ 5, 6 ];
1;
LSC
        close F;
        utime( time - 36000, time - 36000, $this->{lscpath} );
        $this->{wrote_lsc} = 1;
    }
    else {
        die "Can't open  $this->{lscpath} for write: $!" if -e $this->{lscpath};
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

    #print STDERR "Tearing down $this->{lscpath}\n";
    if ( $this->{wrote_lsc} ) {
        $this->{wrote_lsc} = 0;
        if ( $this->{safe_lsc} ) {
            open( F, '>', $this->{lscpath} )
              || die "Can't open  $this->{lscpath} for write: $!";
            print F $this->{safe_lsc};
            close F;
        }
        else {
            unlink $this->{lscpath};
        }
    }
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
