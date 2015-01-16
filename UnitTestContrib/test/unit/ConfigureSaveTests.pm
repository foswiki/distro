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
              '| {UnitTestContrib}{Configure}{PERL_ARRAY} | [5,6] | [3,4] |',
        },
        {
            level => 'notes',
            text =>
'| {UnitTestContrib}{Configure}{PERL_HASH} | {\'a\' => 5,\'b\' => 6} | {\'pootle\' => 1} |',
        },
        {
            level => 'notes',
            text =>
q<| {UnitTestContrib}{Configure}{REGEX} | (^regex$) | '(black&#124;white)+' |>,
        },
        {
            level => 'notes',
            text =>
              '| {UnitTestContrib}{Configure}{undefok} | \'value\' | undef |',
        },
    ];
    my $ms = $reporter->messages();

    #print STDERR Data::Dumper->Dump([$ms]);

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
    $this->assert_matches( qr/^\| {DetailedOS}/, $r->{text} );
    $this->assert_str_equals( 'notes', $r->{level} );

    #print STDERR Data::Dumper->Dump([$ms]);
    $this->assert_deep_equals( $ms, $expected );

    # Check it was written correctly
    $this->assert( open( F, '<', $this->{lscpath} ), $@ );
    local $/ = undef;
    my $c = <F>;
    close F;

    # Check for expected messages
    $this->assert_matches( qr/^# {'Test-Key'} was not found in .spec$/m,  $c );
    $this->assert_matches( qr/^# {TestA} was not found in .spec$/m,       $c );
    $this->assert_matches( qr/^# {TestB}{Ruin} was not found in .spec$/m, $c );

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
