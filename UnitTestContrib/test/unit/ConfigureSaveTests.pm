# See bottom of file for license and copyright information

# Tests for the core 'Save' wizard.

package ConfigureSaveTests;

use ConfigureTestCase;
our @ISA = qw( ConfigureTestCase );

use strict;
use warnings;
use Foswiki;
use Error qw(:try);

use Foswiki::Configure::Wizards::Save;
use Foswiki::Configure::Reporter;
use Foswiki::Sandbox;

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
            '{UnitTestContrib}{Configure}{undefok}' => undef,
        }
    };

    Foswiki::Configure::Load::readConfig( 0, 0 );

    my $wizard   = Foswiki::Configure::Wizards::Save->new($params);
    my $reporter = Foswiki::Configure::Reporter->new();
    $wizard->save($reporter);

    # Check report
    my %expected = (
        "| {OS} | ('') | \'$Foswiki::cfg{OS}\' |"                    => 'notes',
        '| {\'Test-Key\'} | undef | \'newtestkey\' |'                => 'notes',
        '| {TestA} | undef | \'Shingle\' |'                          => 'notes',
        '| {TestB}{Ruin} | undef | \'Ribbed\' |'                     => 'notes',
        '| {UnitTestContrib}{Configure}{NUMBER} | (666) | \'99\' |', => 'notes',
        '| {UnitTestContrib}{Configure}{PERL_ARRAY} | [5,6] | [3,4] |' =>
          'notes',
'| {UnitTestContrib}{Configure}{PERL_HASH} | {\'a\' => 5,\'b\' => 6} | {\'pootle\' => 1} |'
          => 'notes',
q<| {UnitTestContrib}{Configure}{REGEX} | ('^regex$') | '(black&#124;white)+' |>
          => 'notes',
        '| {UnitTestContrib}{Configure}{undefok} | \'value\' | undef |' =>
          'notes',
    );
    my $ms = $reporter->messages();

    #print STDERR Data::Dumper->Dump([$ms]);

    # Since fe67109ef03617bb76df0058fa880a2588ec138b the imposed config
    # in ConfigureTestCase is no longer the shole story, as all the crud from
    # Foswiki.spec and extension.specs will be added back in to the config.
    # So we have to be a bit selective about what we test.

    my $r = shift(@$ms);
    $this->assert_matches( qr/^Previous/, $r->{text} );
    $this->assert_str_equals( 'notes', $r->{level} );
    $r = shift(@$ms);
    $this->assert_matches( qr/^New/, $r->{text} );
    $this->assert_str_equals( 'notes', $r->{level} );
    $r = shift(@$ms);
    $this->assert_matches( qr/^\| \*Key/, $r->{text} );
    $this->assert_str_equals( 'notes', $r->{level} );
    $r = shift(@$ms);

    for ( my $i = 0 ; $i < scalar(@$ms) ; $i++ ) {
        my $r = $ms->[$i];
        if ( ( $expected{ $r->{text} } // '' ) eq $r->{level} ) {
            delete $expected{ $r->{text} };
        }
    }

    #print STDERR Data::Dumper->Dump([$ms]);
    $this->assert_num_equals(
        0,
        scalar keys %expected,
        Data::Dumper->Dump( [ \%expected ] )
    );

    # Check it was written correctly
    $this->assert( open( F, '<', $this->{lscpath} ), $@ );
    local $/ = undef;
    my $c = <F>;
    close F;

    # Check for expected messages
    $this->assert_matches( qr/^# \{'Test-Key'\} was not found in .spec$/m, $c );
    $this->assert_matches( qr/^# \{TestA\} was not found in .spec$/m,      $c );
    $this->assert_matches( qr/^# \{TestB\}\{Ruin\} was not found in .spec$/m,
        $c );

    # TODO: check backup succeeded

    $c =~ s/^\$Foswiki::cfg/\$blah/gm;
    $c = Foswiki::Sandbox::untaintUnchecked($c);
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
