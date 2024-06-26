# Tests for the Foswiki::Configure::Dependency class
# Author: Michael Tempest
package DependencyTests;

use strict;
use warnings;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Error qw( :try );
use File::Temp;
use Foswiki::Configure::Dependency;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    return $this;
}

sub test_check_dep_not_perl {
    my ($this) = @_;

    # Check an external dependency
    # 0, Module is type external, and cannot be automatically checked.
    my $dep = new Foswiki::Configure::Dependency(
        type    => "external",
        module  => "libpcap",
        version => "1.0.0"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 0, $ok );
    $this->assert_matches( qr/cannot be automatically checked/, $message );
}

sub test_check_dep_last_resort1 {
    my ($this) = @_;

    # Check a module that won't load, so that the
    # last resort "code scraping" is used to recover version.
    my $dep = new Foswiki::Configure::Dependency(
        type   => "perl",
        module => "Foswiki::Contrib::UnitTestContrib::LastResortWontLoad",
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok );
    $this->assert_matches(
qr/Foswiki::Contrib::UnitTestContrib::LastResortWontLoad version v1.2.3_100 installed/,
        $message
    );
}

sub test_check_dep_not_module {
    my ($this) = @_;

    # Check a non-existing module
    # 0,
    my $dep = new Foswiki::Configure::Dependency(
        type   => "perl",
        module => "Non::Existing::Module"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 0, $ok );
    $this->assert_matches(
qr/Non::Existing::Module version >=0 required\s*--\s*perl module is not installed/,
        $message
    );

}

sub test_check_foswiki_rev {
    my ($this) = @_;

    my $dep = new Foswiki::Configure::Dependency(
        type    => 'perl',
        module  => 'Foswiki',
        version => '1.1.3'
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok );

    # e.g. Foswiki version 17 Jun 2022 installed
    $this->assert_matches(
qr/^Foswiki version \d+ \w+ \d\d\d\d ((Alpha|alpha|Beta|beta)\s)?installed$/,
        $message
    );

}

sub test_check_dep_carp {
    my ($this) = @_;

    # Check a normally installed dependency
    # 1, Carp v1.03 installed
    my $dep =
      new Foswiki::Configure::Dependency( type => "cpan", module => "Carp" );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/Carp version .* installed/, $message );

}

sub test_check_dep_carp_with_version {
    my ($this) = @_;

    # Check a normally installed dependency
    # 1, Carp v1.03 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "cpan",
        module  => "Carp",
        version => 0.1
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/Carp version .* installed/, $message );

}

sub test_check_dep_version_too_high {
    my ($this) = @_;

    # Check a normal installed dependency with an absurd high version number
    # 0, HTML::Parser version 21.1 required--this is only version 1.05
    my $dep = new Foswiki::Configure::Dependency(
        type    => "cpan",
        module  => "HTML::Parser",
        version => "21.1"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 0, $ok );
    $this->assert_matches(
qr/HTML::Parser version >= 21.1 required\s*--\s*installed version is [\d.]+/,
        $message
    );

}

sub test_check_dep_version_with_superior {
    my ($this) = @_;

    # Check a normal installed dependency with a superior sign
    # 1, HTML::Parser v1.05 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "cpan",
        module  => "HTML::Parser",
        version => ">=0.9"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/HTML::Parser version \d+\.\d+ installed/,
        $message );

}

sub test_check_dep_version_with_inferior {
    my ($this) = @_;

    # Check a normal installed dependency with an inferior
    # 1, HTML::Parser v1.05 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "cpan",
        module  => "HTML::Parser",
        version => "<21.1"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok, $HTML::Parser::VERSION );
    $this->assert_matches( qr/HTML::Parser version \d+\.\d+ installed/,
        $message );

}

sub test_check_dep_version_with_inferior_failed {
    my ($this) = @_;

    # Check a normal installed dependency with an inferior too low
    # 0, Module HTML::Parser is version v3.60 and the dependency wants <1
    my $dep = new Foswiki::Configure::Dependency(
        type    => "cpan",
        module  => "HTML::Parser",
        version => "<1"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 0, $ok );
    $this->assert_matches(
qr/HTML::Parser version < 1 required\s*--\s*installed version is [\d.]+/,
        $message
    );

}

sub test_check_dep_version_with_rev {
    my ($this) = @_;

    # Check a normal installed dependency with a $Rev$ version number
    # 1, Foswiki::Contrib::JSCalendarContrib v1234 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki::Contrib::UnitTestContrib::DateBasedRelease",
        version => ">=20 Sep 2009"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok, $message );
    $this->assert_matches(
        qr/Foswiki::Contrib::UnitTestContrib::DateBasedRelease .* installed/,
        $message );
    $this->assert( $message =~ m/version (\d+) /, $message );
    my $revision = $1;
    $this->assert( $revision ne '999999' );
}

sub test_check_dep_version_with_implied_svn {
    my ($this) = @_;

    # Check a normal installed dependency with a svn version number
    # 1, Foswiki::Contrib::UnitTestContrib::MultiDottedVersion v1234 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki::Contrib::UnitTestContrib::MultiDottedVersion",
        version => ">1000"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok, $message );
    $this->assert_matches(
        qr/Foswiki::Contrib::UnitTestContrib::MultiDottedVersion .* installed/,
        $message
    );
    $this->assert( $message =~ m/version (\d+) /, $message );
    my $revision = $1;
    $this->assert( $revision ne '999999' );
}

sub test_check_dep_version_with_explicit_svn {
    my ($this) = @_;

    # Check a normal installed dependency with a svn version number
    # 1, Foswiki::Contrib::UnitTestContrib::MultiDottedVersion v1234 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki::Contrib::UnitTestContrib::MultiDottedVersion",
        version => ">r1000"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok, $message );
    $this->assert_matches(
        qr/Foswiki::Contrib::UnitTestContrib::MultiDottedVersion .* installed/,
        $message
    );
    $this->assert( $message =~ m/version (\d+) /, $message );
    my $revision = $1;
    $this->assert( $revision ne '999999' );
}

sub test_check_dep_version_with_unsatisfied_explicit_svn {
    my ($this) = @_;

    # Check a normal installed dependency with a svn version number
    # 1, Foswiki::Contrib::UnitTestContrib::MultiDottedVersion v1234 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki::Contrib::UnitTestContrib::MultiDottedVersion",
        version => "<r23"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 0, $ok, $message );
    $this->assert_matches(
qr/Foswiki::Contrib::UnitTestContrib::MultiDottedVersion version < r23 required/,
        $message
    );
    $this->assert( $message =~ m/version (\d+) /, $message );
    my $revision = $1;
    $this->assert( $revision ne '999999' );
}

sub test_check_dep_version_with_unsatisfied_svn {
    my ($this) = @_;

    # Check a normal installed dependency with a svn version number
    # 1, Foswiki::Contrib::UnitTestContrib::MultiDottedVersion v1234 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki::Contrib::UnitTestContrib::MultiDottedVersion",
        version => ">2000"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 0, $ok, $message );
    $this->assert_matches(
qr/Foswiki::Contrib::UnitTestContrib::MultiDottedVersion version > 2000 required/,
        $message
    );
    $this->assert( $message =~ m/version (\d+) /, $message );
    my $revision = $1;
    $this->assert( $revision ne '999999' );
}

sub test_check_dep_version_with_multi_part_number {
    my ($this) = @_;

    # Check a normal installed dependency with a 1.23.4 version number
    # 1, Foswiki::Contrib::UnitTestContrib::MultiDottedVersion v1.23.4 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki::Contrib::UnitTestContrib::MultiDottedVersion",
        version => ">=1.5.6"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok, $message );
    $this->assert_matches(
qr/Foswiki::Contrib::UnitTestContrib::MultiDottedVersion version 1\.23\.4 installed/,
        $message
    );
}

sub test_check_dep_with_missing_dependency {
    my ($this) = @_;

    # Check a normal dependency that is in turn missing dependencies  which
    # will cause a compile error trying to eval the module to obtain version.
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki::Contrib::UnitTestContrib::MissingDependency",
        version => ">=1.23.4"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok, $message );
    $this->assert_equals(
        '1.23.4',
        $dep->{installedRelease},
        "Unexpected version found $dep->{installedRelease}"
    );
    $this->assert_equals(
        '$Rev: 1234 (2010-01-19) $',
        $dep->{installedVersion},
        "Unexpected version found $dep->{installedVersion}"
    );
}

sub test_check_dep_version_with_underscore {
    my ($this) = @_;

    # Check a normal installed dependency with a version number that includes _
    # 1, Algorithm::Diff v1.19_01 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Algorithm::Diff",
        version => ">=1.18_45"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok );
    $this->assert_matches(
        qr/Algorithm::Diff version \d+\.\d+(?:_\d+)? installed/, $message );

}

sub test_check_dep_version_oddball_DBI {
    my ($this) = @_;

    # Check a normal installed dependency with a version number that includes _
    # 1, Algorithm::Diff v1.19_01 installed
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "DBI",
        version => ">=1"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/DBI version \d+\.\d+(?:_\d+)? installed/,
        $message );

}

sub test_compare_extension_versions {
    my ($this) = @_;

    # Each tuple describes one version comparison and the expected result
    # The first value is the expected result. 1 means "true" and 0 means "false.
    # The second and third are the "installed" Release and Version strings.
    # The forth value is the comparison operator as a string.
    # and the fifth value is the version/release to compare.
    my @comparisons = (

        #[ R IR IV ? RV ]
        # Plain integer versions
        [ 1, 2, undef, '<',  10 ],
        [ 1, 2, undef, '<=', 10 ],
        [ 0, 2, undef, '>',  10 ],
        [ 0, 2, undef, '>=', 10 ],
        [ 0, 2, undef, '=',  10 ],

        [ 0, 10, undef, '<',  2 ],
        [ 0, 10, undef, '<=', 2 ],
        [ 1, 10, undef, '>',  2 ],
        [ 1, 10, undef, '>=', 2 ],
        [ 0, 10, undef, '=',  2 ],

        [ 0, ' 10', undef, '<',  2 ],
        [ 0, ' 10', undef, '<=', 2 ],
        [ 1, ' 10', undef, '>',  2 ],
        [ 1, ' 10', undef, '>=', 2 ],
        [ 0, ' 10', undef, '=',  2 ],

        [ 0, '10 ', undef, '<',  2 ],
        [ 0, '10 ', undef, '<=', 2 ],
        [ 1, '10 ', undef, '>',  2 ],
        [ 1, '10 ', undef, '>=', 2 ],
        [ 0, '10 ', undef, '=',  2 ],

        [ 0, 2, undef, '<',  2 ],
        [ 1, 2, undef, '<=', 2 ],
        [ 0, 2, undef, '>',  2 ],
        [ 1, 2, undef, '>=', 2 ],
        [ 1, 2, undef, '=',  2 ],

        # trailing and leading spaces should not affect
        # the value of a version nuumber
        [ 1, ' 2',  undef, '=', 2 ],
        [ 1, '2 ',  undef, '=', 2 ],
        [ 1, ' 2 ', undef, '=', 2 ],
        [ 1, ' 2',  undef, '=', ' 2' ],
        [ 1, '2 ',  undef, '=', ' 2' ],
        [ 1, ' 2 ', undef, '=', ' 2' ],
        [ 1, ' 2',  undef, '=', '2 ' ],
        [ 1, '2 ',  undef, '=', '2 ' ],
        [ 1, ' 2 ', undef, '=', '2 ' ],
        [ 1, ' 2',  undef, '=', ' 2 ' ],
        [ 1, '2 ',  undef, '=', ' 2 ' ],
        [ 1, ' 2 ', undef, '=', ' 2 ' ],

        # SVN-style revision numbers should be treated like integers
        [ 1, undef, '$Rev: 2 $', '<',  10 ],
        [ 1, undef, '$Rev: 2 $', '<=', 10 ],
        [ 0, undef, '$Rev: 2 $', '>',  10 ],
        [ 0, undef, '$Rev: 2 $', '>=', 10 ],
        [ 0, undef, '$Rev: 2 $', '=',  10 ],

        [ 0, undef, '$Rev: 10 $', '<',  2 ],
        [ 0, undef, '$Rev: 10 $', '<=', 2 ],
        [ 1, undef, '$Rev: 10 $', '>',  2 ],
        [ 1, undef, '$Rev: 10 $', '>=', 2 ],
        [ 0, undef, '$Rev: 10 $', '=',  2 ],

        [ 0, undef, '$Rev: 2 $', '<',  2 ],
        [ 1, undef, '$Rev: 2 $', '<=', 2 ],
        [ 0, undef, '$Rev: 2 $', '>',  2 ],
        [ 1, undef, '$Rev: 2 $', '>=', 2 ],
        [ 1, undef, '$Rev: 2 $', '=',  2 ],

        # compare X.Y and X
        [ 1, 1.1, undef, '<',  2 ],
        [ 1, 1.1, undef, '<=', 2 ],
        [ 0, 1.1, undef, '>',  2 ],
        [ 0, 1.1, undef, '>=', 2 ],
        [ 0, 1.1, undef, '=',  2 ],

        # compare X.Y and X.Y.Z
        [ 1, 1.1, undef, '<',  '1.2.1' ],
        [ 1, 1.1, undef, '<=', '1.2.1' ],
        [ 0, 1.1, undef, '>',  '1.2.1' ],
        [ 0, 1.1, undef, '>=', '1.2.1' ],
        [ 0, 1.1, undef, '=',  '1.2.1' ],

        # Versions with _
        [ 1, '2.36_04', undef, '<',  '2.36_10' ],
        [ 1, '2.36_04', undef, '<=', '2.36_10' ],
        [ 0, '2.36_04', undef, '>',  '2.36_10' ],
        [ 0, '2.36_04', undef, '>=', '2.36_10' ],
        [ 0, '2.36_04', undef, '=',  '2.36_10' ],

        # Letters in the version number
        [ 1, '1.2.5', undef, '=', '1.2.5a' ],

        # compare vX.Y with X.Y
        [ 1, 'v1.2', undef, '<',  '2.2' ],
        [ 1, 'v1.2', undef, '<=', '2.2' ],
        [ 0, 'v1.2', undef, '>',  '2.2' ],
        [ 0, 'v1.2', undef, '>=', '2.2' ],
        [ 0, 'v1.2', undef, '=',  '2.2' ],

        # Presence or absence of leading v
        # makes no difference to the value of X.Y version numbers
        [ 0, 'v1.2', undef, '<',  '1.2' ],
        [ 1, 'v1.2', undef, '<=', '1.2' ],
        [ 0, 'v1.2', undef, '>',  '1.2' ],
        [ 1, 'v1.2', undef, '>=', '1.2' ],
        [ 1, 'v1.2', undef, '=',  '1.2' ],

        # dd Mmm yyyy dates
        [ 1, '1 Jan 2009',  undef, '<', '2 Jan 2009' ],
        [ 1, '2 Jan 2009',  undef, '=', ' 2 Jan 2009' ],
        [ 1, '2 Jan 2009',  undef, '=', '02 Jan 2009' ],
        [ 1, '2 Jan 2009',  undef, '<', '20 Jan 2009' ],
        [ 1, '21 Jan 2009', undef, '<', '22 Jan 2009' ],
        [ 0, '2 Jan 2009',  undef, '=', '20 Jan 2009' ],
        [ 0, '2 Jan 2009',  undef, '=', ' 3 Jan 2009' ],
        [ 0, '2 Jan 2009',  undef, '=', '03 Jan 2009' ],
        [ 0, '2 Jan 2009',  undef, '=', '2 Feb 2009' ],
        [ 0, '2 Jan 2009',  undef, '=', '2 Jan 2010' ],
        [ 1, '2 Jan 2009',  undef, '<', '10 Jan 2009' ],
        [ 1, '2 Feb 2009',  undef, '>', '10 Jan 2009' ],
        [ 1, '2 Feb 2009',  undef, '<', '10 Jan 2010' ],

        # ordering of months
        [ 1, '31 Jan 2000', undef, '<', '1 Feb 2000' ],
        [ 1, '29 Feb 2000', undef, '<', '1 Mar 2000' ],
        [ 1, '31 Mar 2000', undef, '<', '1 Jun 2000' ],
        [ 1, '30 Jun 2000', undef, '<', '1 Jul 2000' ],
        [ 1, '31 Jul 2000', undef, '<', '1 Aug 2000' ],
        [ 1, '31 Aug 2000', undef, '<', '1 Sep 2000' ],
        [ 1, '30 Sep 2000', undef, '<', '1 Oct 2000' ],
        [ 1, '31 Oct 2000', undef, '<', '1 Nov 2000' ],
        [ 1, '30 Nov 2000', undef, '<', '1 Dec 2000' ],
        [ 1, '31 Dec 2000', undef, '<', '1 Jan 2001' ],

        # ISO8601  dates
        [ 1, '2009-04-14', undef, '>', '2009-04-13' ],
        [ 1, '2009-04-14', undef, '=', '2009-04-14' ],
        [ 1, '2009-04-14', undef, '<', '2009-04-15' ],
        [ 1, '2009-04-14', undef, '>', '2009-03-14' ],
        [ 1, '2009-04-14', undef, '<', '2009-05-14' ],
        [ 1, '2009-04-14', undef, '<', '2009-11-14' ],
        [ 1, '2010-04-14', undef, '>', '2009-04-14' ],

        # Invalid  dates
        [ 0, '31 Abc 2000', undef, '<', '1 Jan 2001' ],
        [ 0, '2009-13-14',  undef, '>', '2009-04-13' ],
        [ 0, '2009-00-14',  undef, '>', '2009-04-13' ],
        [ 0, '0 Jan 2009',  undef, '<', '2 Jan 2010' ],
        [ 0, '1800-04-14',  undef, '>', '1900-04-14' ],

        # Various versions that must be greater than 0
        [ 1, '0.1',        undef, '>', 0 ],
        [ 1, '0.0.0.1',    undef, '>', 0 ],
        [ 1, 'v0.1',       undef, '>', 0 ],
        [ 1, 'v0.0.0.1',   undef, '>', 0 ],
        [ 1, '1 Jan 1990', undef, '>', 0 ],
        [ 1, '1990-01-01', undef, '>', 0 ],
        [ 1, '0.00_01',    undef, '>', 0 ],

        # An SVN-style version number
        # is not affected by the spacing
        # and is greater than 0
        [ 1, undef, '$Rev:   $', '=',  '$Rev$' ],
        [ 1, undef, '$Rev:  $',  '=',  '$Rev$' ],
        [ 1, undef, '$Rev: $',   '=',  '$Rev$' ],
        [ 1, undef, '$Rev:$',    '=',  '$Rev$' ],
        [ 1, undef, '$Rev $',    '=',  '$Rev$' ],
        [ 1, undef, '$Rev$',     '>',  0 ],
        [ 1, undef, '$Rev$',     '>=', 1 ],

        # Blank version number is less than 1
        [ 1, undef, '', '<',  1 ],
        [ 1, undef, '', '<=', 1 ],
        [ 0, undef, '', '>',  1 ],
        [ 0, undef, '', '>=', 1 ],
        [ 0, undef, '', '=',  1 ],

        # Undef Version and Release or comparsion  version always return 0
        [ 0, undef, undef, '<', 1 ],
        [ 0, 0,     undef, '=', undef ],

        # Blank comparator operator always gives false result
        # And undef inputs generate no warnings
        [ 0, 1,     undef, '', 1 ],
        [ 0, 1,     undef, '', 0 ],
        [ 0, 1,     undef, '', undef ],
        [ 0, 0,     undef, '', 1 ],
        [ 0, 0,     undef, '', 0 ],
        [ 0, 0,     undef, '', undef ],
        [ 0, undef, undef, '', 1 ],
        [ 0, undef, undef, '', 0 ],
        [ 0, undef, undef, '', undef ],

        [ 0, 1,     undef, 'x', 1 ],
        [ 0, 1,     undef, 'x', 0 ],
        [ 0, 1,     undef, 'x', undef ],
        [ 0, 0,     undef, 'x', 1 ],
        [ 0, 0,     undef, 'x', 0 ],
        [ 0, 0,     undef, 'x', undef ],
        [ 0, undef, undef, 'x', 1 ],
        [ 0, undef, undef, 'x', 0 ],
        [ 0, undef, undef, 'x', undef ],

        [ 0, 1,     undef, undef, 1 ],
        [ 0, 1,     undef, undef, 0 ],
        [ 0, 1,     undef, undef, undef ],
        [ 0, 0,     undef, undef, 1 ],
        [ 0, 0,     undef, undef, 0 ],
        [ 0, 0,     undef, undef, undef ],
        [ 0, undef, undef, undef, 1 ],
        [ 0, undef, undef, undef, 0 ],
        [ 0, undef, undef, undef, undef ],

        # dd Mmm yyyy dates compared to Triplet requested
        # Always true - assume migration from date to triplet
        [ 1, '1 Jan 2009', undef, '<', '1.2.3' ],
        [ 1, '1 Jan 2009', undef, '>', '1.2.3' ],

        # Triplet installed, compared to date requested
        # Always false - assume migration from date to triplet
        [ 0, '1.2.3', undef, '>', '1 Jan 2009' ],
        [ 0, '1.2.3', undef, '<', '1 Jan 2009' ],

        # Triplet installed, compared to svn rev requested
        # Always true - assume migration from rev to triplet
        [ 1, '1.2.3', '1.2.3', '>', '7429' ],
        [ 1, '1.2.3', '1.2.3', '<', '13213' ],
        [ 1, undef,   '1.2.3', '>', '7429' ],
        [ 1, undef,   '1.2.3', '<', '13213' ],
        [ 1, '1.2.3', undef,   '>', '7429' ],
        [ 1, '1.2.3', undef,   '<', '13213' ],

       # svn installed, tuple requested - svn is obsolete, so always return true
       # Except when the "tuple" is a simple integer.
        [ 1, '2.4.1', '$Rev: 15237 (2012-07-31) $', '<', 2.50 ],
        [ 1, '2.4.1', '$Rev: 15237 (2012-07-31) $', '>', 2.50 ],
        [ 1, '2.4.1', '$Rev: 15237 (2012-07-31) $', '<', 16000 ],
        [ 0, '2.4.1', '$Rev: 15237 (2012-07-31) $', '<', 13000 ],

        # Special case, even though "Release" 2.4.1 is > 2.4.0
        # the VERSION string is the authority.
        [ 1, '2.4.1', '$Rev: 15237 (2012-07-31) $', '<', '2.4.0' ],

        # Decimal rev installed, compared to svn rev requested
        # Always true - assume migration from rev to triplet
        [ 1, '1.2', '1.2', '>', '7429' ],
        [ 1, '1.2', '1.2', '<', '13213' ],
        [ 1, undef, '1.2', '>', '7429' ],
        [ 1, undef, '1.2', '<', '13213' ],
        [ 1, '1.2', undef, '>', '7429' ],
        [ 1, '1.2', undef, '<', '13213' ],

        # Mmmmmm yyyy - not supported, always false
        [ 0, 'November 2007', undef, '<', '1.2.3' ],
        [ 0, 'November 2007', undef, '>', '1.2.3' ],

        #[ R IR IV ? RV ]
        [ 0, '$Rev: 6156 (2010-01-27) $', '1.9.1', '>', '6156 (2010-01-27)' ],
        [ 0, '$Rev: 6156 (2010-01-27) $', '1.9.1', '>', ' 6156 (2010-01-27) ' ],
        [ 1, '$Rev: 6156 (2010-01-27) $', '1.9.1', '>', ' 6152 (2010-01-27) ' ],
        [
            0, '$Rev: 6156 (2010-01-27) $',
            '1.9.1', '>', '  $Rev: 6156 (2010-01-27) $ '
        ],
        [
            1, '$Rev: 6156 (2010-01-27) $',
            '1.9.1', '>', '  $Rev: 6152 (2010-01-27) $ '
        ],
        [ 0, '$Rev: 6156 (2010-01-27) $', '1.9.1', '<', ' 6152 (2010-01-27) ' ],
        [ 0, '$Rev: 6156 (2010-01-27) $', '1.9.1', '<', '6152' ],
        [ 1, '$Rev: 6156 (2010-01-27) $', '1.9.1', '<', '6157' ],
        [ 0, '$Rev: 6156 (2010-01-27) $', '1.9.1', '>', ' 1.9.2 ' ],
        [ 0, '$Rev: 6156 (2010-01-27) $', '1.9.1', '>', '1.9.2' ],
        [ 1, '$Rev: 6156 (2010-01-27) $', '1.9.1', '>', '1.9.0' ],
        [ 0, '$Rev: 6156 (2010-01-27) $', '1.9.1', '>', '6156 (2010-01-27)' ],
    );
    foreach my $set (@comparisons) {
        my $expected = $set->[0];
        my $dep      = new Foswiki::Configure::Dependency(
            name             => "Test",
            type             => 'perl',
            installedRelease => $set->[1],
            installedVersion => $set->[2]
        );
        my $actual = $dep->compare_versions( $set->[3], $set->[4] ) ? 1 : 0;

        #print STDERR  join(' ', '[', map({ defined($_) ? $_ : 'undef' } @$set),
        #         '] should give', $expected, "\n") ;

        $this->assert_equals(
            $expected,
            $actual,
            join( ' ',
                '[', map( { defined($_) ? $_ : 'undef' } @$set ),
                '] should give', $expected )
        );
    }
}

sub test_compare_cpan_versions {
    my ($this) = @_;

    # Each tuple describes one version comparison and the expected result
    # The first value is the expected result. 1 means "true" and 0 means "false.
    # The second and fourth values are the versions to compare.
    # The third value is the comparison operator as a string.
    my @comparisons = (

        # Plain integer versions
        [ 1, 2, '<',  10 ],
        [ 1, 2, '<=', 10 ],
        [ 0, 2, '>',  10 ],
        [ 0, 2, '>=', 10 ],
        [ 0, 2, '=',  10 ],

        [ 0, 10, '<',  2 ],
        [ 0, 10, '<=', 2 ],
        [ 1, 10, '>',  2 ],
        [ 1, 10, '>=', 2 ],
        [ 0, 10, '=',  2 ],

        [ 0, ' 10', '<',  2 ],    #11
        [ 0, ' 10', '<=', 2 ],
        [ 1, ' 10', '>',  2 ],
        [ 1, ' 10', '>=', 2 ],
        [ 0, ' 10', '=',  2 ],

        [ 0, '10 ', '<',  2 ],
        [ 0, '10 ', '<=', 2 ],
        [ 1, '10 ', '>',  2 ],
        [ 1, '10 ', '>=', 2 ],
        [ 0, '10 ', '=',  2 ],

        [ 0, 2, '<',  2 ],        #21
        [ 1, 2, '<=', 2 ],
        [ 0, 2, '>',  2 ],
        [ 1, 2, '>=', 2 ],
        [ 1, 2, '=',  2 ],

        # cpan decimal versions are compared as decimal numbers
        #  1.3 should be newer than 1.13
        [ 1, 1.1,  '>', 1 ],      #26
        [ 1, 1.13, '>', 1 ],
        [ 1, 1.23, '>', 1.13 ],
        [ 1, 1.2,  '>', 1.13 ],

        # trailing and leading spaces should not affect
        # the value of a version nuumber
        [ 1, ' 2',  '=', 2 ],       #30
        [ 1, '2 ',  '=', 2 ],
        [ 1, ' 2 ', '=', 2 ],
        [ 1, ' 2',  '=', ' 2' ],
        [ 1, '2 ',  '=', ' 2' ],
        [ 1, ' 2 ', '=', ' 2' ],
        [ 1, ' 2',  '=', '2 ' ],
        [ 1, '2 ',  '=', '2 ' ],
        [ 1, ' 2 ', '=', '2 ' ],
        [ 1, ' 2',  '=', ' 2 ' ],
        [ 1, '2 ',  '=', ' 2 ' ],
        [ 1, ' 2 ', '=', ' 2 ' ],

        # SVN-style revision numbers should be treated like integers
        [ 1, '$Rev: 2 $', '<',  10 ],    #42
        [ 1, '$Rev: 2 $', '<=', 10 ],
        [ 0, '$Rev: 2 $', '>',  10 ],
        [ 0, '$Rev: 2 $', '>=', 10 ],
        [ 0, '$Rev: 2 $', '=',  10 ],

        # SVN-style revision numbers should be treated like integers
        [ 1, '$Rev: 2 $', '<',  10 ],    #42
        [ 1, '$Rev: 2 $', '<=', 10 ],
        [ 0, '$Rev: 2 $', '>',  10 ],
        [ 0, '$Rev: 2 $', '>=', 10 ],
        [ 0, '$Rev: 2 $', '=',  10 ],

        [ 0, '$Rev: 10 $', '<',  2 ],    #47
        [ 0, '$Rev: 10 $', '<=', 2 ],
        [ 1, '$Rev: 10 $', '>',  2 ],
        [ 1, '$Rev: 10 $', '>=', 2 ],
        [ 0, '$Rev: 10 $', '=',  2 ],

        [ 0, '$Rev: 2 $', '<',  2 ],     #52
        [ 1, '$Rev: 2 $', '<=', 2 ],
        [ 0, '$Rev: 2 $', '>',  2 ],
        [ 1, '$Rev: 2 $', '>=', 2 ],
        [ 1, '$Rev: 2 $', '=',  2 ],

        # compare X.Y and X
        [ 1, 1.1, '<',  2 ],             #57
        [ 1, 1.1, '<=', 2 ],
        [ 0, 1.1, '>',  2 ],
        [ 0, 1.1, '>=', 2 ],
        [ 0, 1.1, '=',  2 ],

      # compare X.Y and X.Y.Z
      #  - These tests change.  1.1 normalizes to 1.100 when compared with 1.2.1
        [ 0, 1.1, '<',  '1.2.1' ],    #62
        [ 0, 1.1, '<=', '1.2.1' ],
        [ 1, 1.1, '>',  '1.2.1' ],
        [ 1, 1.1, '>=', '1.2.1' ],
        [ 0, 1.1, '=',  '1.2.1' ],

        # Versions with _
        [ 1, '2.36_04', '<',  '2.36_10' ],    #67
        [ 1, '2.36_04', '<=', '2.36_10' ],
        [ 0, '2.36_04', '>',  '2.36_10' ],
        [ 0, '2.36_04', '>=', '2.36_10' ],
        [ 0, '2.36_04', '=',  '2.36_10' ],

        # Letters in the version number
        [ 1, '1.2.4.5-beta1', '<',  '1.2.4.5-beta2' ],    #72
        [ 1, '1.2.4.5-beta1', '<=', '1.2.4.5-beta2' ],
        [ 0, '1.2.4.5-beta1', '>',  '1.2.4.5-beta2' ],
        [ 0, '1.2.4.5-beta1', '>=', '1.2.4.5-beta2' ],
        [ 0, '1.2.4.5-beta1', '=',  '1.2.4.5-beta2' ],

        # Special case: beta versions are less than non-beta versions
        [ 1, '1.2.4.5-beta1', '<',  '1.2.4.5' ],          #77
        [ 1, '1.2.4.5-beta1', '<=', '1.2.4.5' ],
        [ 0, '1.2.4.5-beta1', '>',  '1.2.4.5' ],
        [ 0, '1.2.4.5-beta1', '>=', '1.2.4.5' ],
        [ 0, '1.2.4.5-beta1', '=',  '1.2.4.5' ],

        # Letters in the version number
        [ 1, '1.2.5', '<',  '1.2.5a' ],                   #82
        [ 1, '1.2.5', '<=', '1.2.5a' ],
        [ 0, '1.2.5', '>',  '1.2.5a' ],
        [ 0, '1.2.5', '>=', '1.2.5a' ],
        [ 0, '1.2.5', '=',  '1.2.5a' ],

        # compare vX.Y with X.Y
        [ 1, 'v1.2', '<',  'v2.2' ],                      #87
        [ 1, 'v1.2', '<=', '2.2' ],
        [ 0, 'v1.2', '>',  '2.2' ],
        [ 0, 'v1.2', '>=', '2.2' ],
        [ 0, 'v1.2', '=',  '2.2' ],

# Presence or absence of leading v
# makes no difference to the value of X.Y version numbers
# NOT TRUE:  Perl CPAN version "normalizes" the string.   "1.2" becomes 1.200 without the leading V.
        [ 1, 'v1.2',   '<',  '1.2' ],
        [ 0, 'v1.200', '<',  '1.2' ],
        [ 1, 'v1.2',   '<=', '1.2' ],
        [ 0, 'v1.2',   '>',  '1.2' ],
        [ 0, 'v1.2',   '>=', '1.2' ],
        [ 0, 'v1.2',   '=',  '1.2' ],
        [ 1, 'v1.200', '=',  '1.2' ],

        # dd Mmm yyyy dates
        [ 1, '1 Jan 2009',  '<', '2 Jan 2009' ],
        [ 1, '2 Jan 2009',  '=', ' 2 Jan 2009' ],
        [ 1, '2 Jan 2009',  '=', '02 Jan 2009' ],
        [ 1, '2-Jan-2009',  '=', '2 Jan 2009' ],
        [ 1, '2 Jan 2009',  '<', '20 Jan 2009' ],
        [ 1, '21 Jan 2009', '<', '22 Jan 2009' ],
        [ 0, '2 Jan 2009',  '=', '20 Jan 2009' ],
        [ 0, '2 Jan 2009',  '=', ' 3 Jan 2009' ],
        [ 0, '2 Jan 2009',  '=', '03 Jan 2009' ],
        [ 0, '2 Jan 2009',  '=', '2 Feb 2009' ],
        [ 0, '2 Jan 2009',  '=', '2 Jan 2010' ],
        [ 1, '2 Jan 2009',  '<', '10 Jan 2009' ],
        [ 1, '2 Feb 2009',  '>', '10 Jan 2009' ],
        [ 1, '2 Feb 2009',  '<', '10 Jan 2010' ],

        # ordering of months
        [ 1, '31 Jan 2000', '<', '1 Feb 2000' ],
        [ 1, '29 Feb 2000', '<', '1 Mar 2000' ],
        [ 1, '31 Mar 2000', '<', '1 Jun 2000' ],
        [ 1, '30 Jun 2000', '<', '1 Jul 2000' ],
        [ 1, '31 Jul 2000', '<', '1 Aug 2000' ],
        [ 1, '31 Aug 2000', '<', '1 Sep 2000' ],
        [ 1, '30 Sep 2000', '<', '1 Oct 2000' ],
        [ 1, '31 Oct 2000', '<', '1 Nov 2000' ],
        [ 1, '30 Nov 2000', '<', '1 Dec 2000' ],
        [ 1, '31 Dec 2000', '<', '1 Jan 2001' ],

        # ISO dd-mm-yyyy dates
        [ 1, '1-2-2000',  '=', '01-2-2000' ],
        [ 1, '1-2-2000',  '=', '01-02-2000' ],
        [ 1, '1-2-2000',  '=', '1-02-2000' ],
        [ 1, '1-3-2000',  '<', '2-3-2000' ],
        [ 1, '10-3-2000', '<', '11-3-2000' ],
        [ 1, '10-4-2000', '>', '11-3-2000' ],
        [ 1, '10-3-2001', '>', '11-4-2000' ],

        # yyyymmdd dates
        [ 1, '20090414', '>', '20090413' ],
        [ 1, '20090414', '=', '20090414' ],
        [ 1, '20090414', '<', '20090415' ],
        [ 1, '20090414', '>', '20090314' ],
        [ 1, '20090414', '<', '20090514' ],
        [ 1, '20090414', '<', '20091114' ],
        [ 1, '20100414', '>', '20090414' ],

        # Various versions that must be greater than 0
        [ 1, '0.00_01',    '>', 0 ],
        [ 1, '0.1',        '>', 0 ],
        [ 1, '0.0.0.1',    '>', 0 ],
        [ 1, 'v0.1',       '>', 0 ],
        [ 1, 'v0.0.0.1',   '>', 0 ],
        [ 1, '1 Jan 1990', '>', 0 ],
        [ 1, '1-1-1990',   '>', 0 ],
        [ 1, '19900101',   '>', 0 ],

        # An SVN-style version number
        # is not affected by the spacing
        # and is greater than 0
        [ 1, '$Rev:   $', '=',  '$Rev$' ],
        [ 1, '$Rev:  $',  '=',  '$Rev$' ],
        [ 1, '$Rev: $',   '=',  '$Rev$' ],
        [ 1, '$Rev:$',    '=',  '$Rev$' ],
        [ 1, '$Rev $',    '=',  '$Rev$' ],
        [ 1, '$Rev$',     '>',  0 ],
        [ 1, '$Rev$',     '>=', 1 ],

        # Blank version number is less than 1
        [ 1, '', '<',  1 ],
        [ 1, '', '<=', 1 ],
        [ 0, '', '>',  1 ],
        [ 0, '', '>=', 1 ],
        [ 0, '', '=',  1 ],

        # Blank comparator operator always gives false result
        # And undef inputs generate no warnings
        [ 0, 1,     '', 1 ],
        [ 0, 1,     '', 0 ],
        [ 0, 1,     '', undef ],
        [ 0, 0,     '', 1 ],
        [ 0, 0,     '', 0 ],
        [ 0, 0,     '', undef ],
        [ 0, undef, '', 1 ],
        [ 0, undef, '', 0 ],
        [ 0, undef, '', undef ],

        [ 0, 1,     'x', 1 ],
        [ 0, 1,     'x', 0 ],
        [ 0, 1,     'x', undef ],
        [ 0, 0,     'x', 1 ],
        [ 0, 0,     'x', 0 ],
        [ 0, 0,     'x', undef ],
        [ 0, undef, 'x', 1 ],
        [ 0, undef, 'x', 0 ],
        [ 0, undef, 'x', undef ],

        [ 0, 1,     undef, 1 ],
        [ 0, 1,     undef, 0 ],
        [ 0, 1,     undef, undef ],
        [ 0, 0,     undef, 1 ],
        [ 0, 0,     undef, 0 ],
        [ 0, 0,     undef, undef ],
        [ 0, undef, undef, 1 ],
        [ 0, undef, undef, 0 ],
        [ 0, undef, undef, undef ],

    );
    my $case = 0;
    foreach my $set (@comparisons) {
        $case++;
        my $expected = $set->[0];
        my $dep      = new Foswiki::Configure::Dependency(
            module           => "Test",
            type             => 'cpan',
            installedVersion => $set->[1]
        );
        my $actual = $dep->compare_versions( $set->[2], $set->[3] ) ? 1 : 0;
        $this->assert_equals(
            $expected,
            $actual,
            join( ' ',
                '[',
                map( { defined($_) ? $_ : 'undef' } @$set ),
                '] should give',
                $expected, 'case', $case )
        );
    }
}

sub test_compare_cpan_version_objects {
    my ($this) = @_;

# Each tuple describes one version comparison and the expected result
# The first value is the expected result. 1 means "true" and 0 means "false.
# The second and fourth values are the versions to compare.
# The third value is the comparison operator as a string.
#
# This test also compares the result from CPAN:version with Foswiki::Configure::Dependency
    my @comparisons = (

        # Plain integer versions
        [ 1, 2, '<',  10 ],
        [ 1, 2, '<=', 10 ],
        [ 0, 2, '>',  10 ],
        [ 0, 2, '>=', 10 ],
        [ 0, 2, '=',  10 ],

        [ 0, 10, '<',  2 ],
        [ 0, 10, '<=', 2 ],
        [ 1, 10, '>',  2 ],
        [ 1, 10, '>=', 2 ],
        [ 0, 10, '=',  2 ],

        [ 0, 2, '<',  2 ],
        [ 1, 2, '<=', 2 ],
        [ 0, 2, '>',  2 ],
        [ 1, 2, '>=', 2 ],
        [ 1, 2, '=',  2 ],

        # compare X.Y and X
        [ 1, 1.1, '<',  2 ],
        [ 1, 1.1, '<=', 2 ],
        [ 0, 1.1, '>',  2 ],
        [ 0, 1.1, '>=', 2 ],
        [ 0, 1.1, '=',  2 ],

        # compare vX.Y.Z and X.Y.Z
        [ 1, 'v1.1.0',    '<',  'v1.2.1' ],
        [ 1, 'v1.1.0',    '<=', 'v1.2.1' ],
        [ 0, 'v1.1.0',    '>',  'v1.2.1' ],
        [ 0, 'v1.1.0',    '>=', 'v1.2.1' ],
        [ 0, 'v1.1.0',    '=',  'v1.2.1' ],
        [ 1, 'v1.110.0',  '>=', 'v1.99.1' ],
        [ 0, 'v1.11.0',   '>=', 'v1.99.1' ],
        [ 1, 'v001.11.1', '=',  'v1.11.1' ],

        # compare X.Y and vX.Y.Z
        [ 0, '1.1', '<',  'v1.2.1' ],    # 1.1. normalizes to 1.100
        [ 0, '1.1', '<=', 'v1.2.1' ],

        # Versions with alpha/beta  _
        [ 1, '2.36_04', '<',  '2.36_10' ],
        [ 1, '2.36_04', '<=', '2.36_10' ],
        [ 0, '2.36_04', '>',  '2.36_10' ],
        [ 0, '2.36_04', '>=', '2.36_10' ],
        [ 0, '2.36_04', '=',  '2.36_10' ],
        [ 1, '2.36_04', '>',  '2.36' ],
        [ 1, '2.37',    '>',  '2.36_04' ],

        # cpan decimal versions are compared as decimal numbers
        #  1.3 should be newer than 1.13
        [ 1, 1.1,  '>', 1 ],
        [ 1, 1.13, '>', 1 ],
        [ 1, 1.23, '>', 1.13 ],
        [ 1, 1.2,  '>', 1.13 ],

        # Versions with _
        [ 1, '2.36_04', '<',  '2.36_10' ],
        [ 1, '2.36_04', '<=', '2.36_10' ],
        [ 0, '2.36_04', '>',  '2.36_10' ],
        [ 0, '2.36_04', '>=', '2.36_10' ],
        [ 0, '2.36_04', '=',  '2.36_10' ],

    );

    foreach my $set (@comparisons) {
        my $expected = $set->[0];
        my $dep      = new Foswiki::Configure::Dependency(
            module           => "Test",
            type             => 'cpan',
            installedVersion => $set->[1]
        );
        my $actual = $dep->compare_versions( $set->[2], $set->[3] ) ? 1 : 0;

        use version qw/is_lax parse stringify/;
        $set->[2] = '==' if $set->[2] eq '=';
        my $ver1;
        my $ver2;

        if ( $set->[1] =~ m/v/ ) {
            $ver1 = version->declare("$set->[1]");
        }
        else {
            $ver1 = version->parse("$set->[1]");
        }
        if ( $set->[3] =~ m/v/ ) {
            $ver2 = version->declare("$set->[3]");
        }
        else {
            $ver2 = version->parse("$set->[3]");
        }
        my $ver1n = eval { $ver1->normal };
        my $ver2n = eval { $ver2->normal };

        unless (
            eval {
                     version->parse("$set->[1]")->is_lax
                  && version->parse("$set->[3]")->is_lax;
            }
          )
        {
            print STDERR " ($set->[1]) or ($set->[3]) - BAD VERSION STRING\n";
            next;
        }

        my $versionCond = eval "\$ver1 $set->[2] \$ver2;";
        $versionCond ||= '0';
        $this->assert_equals( $versionCond, $actual,
"CPAN::version ($versionCond) and Dependency($actual) disagree on  \"($set->[1]) ($ver1n) ($set->[2]) ($set->[3]) ($ver2n)\"\n"
        );

        $this->assert_equals(
            $expected,
            $actual,
            join( ' ',
                '[', map( { defined($_) ? $_ : 'undef' } @$set ),
                '] should give', $expected )
        );
    }
}
1;
