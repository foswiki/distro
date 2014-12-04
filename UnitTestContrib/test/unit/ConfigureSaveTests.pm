# See bottom of file for license and copyright information

# Tests for the core 'Save' wizard.

package ConfigureSaveTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use strict;
use warnings;
use Foswiki;
use Error qw(:try);

use Foswiki::Configure::Wizards::Save;
use Foswiki::Configure::Reporter;

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

    #print STDERR "Tearing down $this->{lscpath}\n";
    if ( $this->{safe_lsc} ) {
        open( F, '>', $this->{lscpath} );
        print F $this->{safe_lsc};
        close(F);
    }
    else {
        unlink $this->{lscpath};
    }
}

# TODO: this needs to test that backups are correctly made
sub test_changecfg {
    my $this   = shift;
    my $params = {
        set => {

            # Unspecced items
            '{TestA}'       => 'Shingle',
            '{TestB}{Ruin}' => 'Ribbed',
            '{"Test-Key"}'  => 'newtestkey',

            # Specced items
            '{UnitTestContrib}{Configure}{NUMBER}' => '99',

            # Some PERL items, array and hash
            '{UnitTestContrib}{Configure}{PERL_ARRAY}' => '[ 3, 4 ]',
            '{UnitTestContrib}{Configure}{PERL_HASH}'  => '{ pootle=>1 }',

            # REGEX item
            '{UnitTestContrib}{Configure}{REGEX}' => '(black|white)+',

            # Undeffable
            '{TempfileDir}' => '',
        }
    };
    my $wizard   = Foswiki::Configure::Wizards::Save->new($params);
    my $reporter = Foswiki::Configure::Reporter->new();
    $wizard->save($reporter);

    # Check report
    my $expected = [
        {
            text  => "| {OS} | undef | \'$Foswiki::cfg{OS}\' |",
            level => 'notes'
        },
        {
            level => 'notes',
            text  => '| {\'Test-Key\'} | undef | \'newtestkey\' |'
        },
        {
            'level' => 'notes',
            'text'  => '| {TestA} | undef | \'Shingle\' |'
        },
        {
            'level' => 'notes',
            'text'  => '| {TestB}{Ruin} | undef | \'Ribbed\' |'
        },
        {
            level => 'notes',
            text => '| {UnitTestContrib}{Configure}{NUMBER} | (666) | \'99\' |',
        },
        {
            level => 'notes',
            text =>
              '| {UnitTestContrib}{Configure}{PERL_ARRAY} | ([1,2]) | [3,4] |',
        },
        {
            level => 'notes',
            text =>
'| {UnitTestContrib}{Configure}{PERL_HASH} | ({\'a\' => 1,\'b\' => 2}) | {\'pootle\' => 1} |',
        },
        {
            level => 'notes',
            text =>
q<| {UnitTestContrib}{Configure}{REGEX} | (^regex$) | qr/(black&#124;white)+/ |>,
        }
    ];
    my $ms = $reporter->messages();
    my $r  = shift(@$ms);
    $this->assert_matches( qr/^Previous/, $r->{text} );
    $this->assert_str_equals( 'notes', $r->{level} );
    $r = shift(@$ms);
    $this->assert_matches( qr/^New/, $r->{text} );
    $this->assert_str_equals( 'notes', $r->{level} );
    $r = shift(@$ms);
    $this->assert_matches( qr/^\| \*Key/, $r->{text} );
    $this->assert_str_equals( 'notes', $r->{level} );

    #print STDERR Data::Dumper->Dump([$ms]);
    $this->assert_deep_equals( $ms, $expected );

    # Check it was written correctly
    open( F, '<',
        Foswiki::Configure::FileUtil::findFileOnPath('LocalSite.cfg') )
      || die $@;
    local $/ = undef;
    my $c = <F>;
    close F;

    # TODO: check backup succeeded

    $c =~ s/^\$Foswiki::cfg/\$blah/gm;
    my %blah;
    eval $c;
    %Foswiki::cfg = ();    #{ConfigurationFinished} = 0;
    Foswiki::Configure::Load::readConfig( 1, 1 );

    #print STDERR Data::Dumper->Dump([\%Foswiki::cfg]);
    delete $Foswiki::cfg{ConfigurationFinished};

    $this->assert_null( $blah{TempfileDir} );
    $this->assert_num_equals( 99, $blah{UnitTestContrib}{Configure}{NUMBER} );
    $this->assert_str_equals( 'newtestkey', $blah{'Test-Key'} );
    $this->assert_str_equals( 'Shingle',    $blah{'TestA'} );
    $this->assert_str_equals( 'Ribbed',     $blah{'TestB'}{'Ruin'} );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2014 Foswiki Contributors. Foswiki Contributors
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
