package ExtenderTests;

use strict;

use base qw(FoswikiTestCase);

use Error qw( :try );
use File::Temp;

# Establish where we are
my @path = ( 'tools', 'extender.pl' );
my $wd = Cwd::cwd();
$wd =~ /^(.*)test.unit$/;    # untaint
unshift( @path, $1 ) if $1;
my $script = File::Spec->catfile(@path);
chdir $1;                    # extender.pl needs this

unless ( my $return = do $script ) {
    my $message = <<MESSAGE;
************************************************************
Could not load $script
MESSAGE

    if ($@) {
        $message .= "There was a compile error: $@\n";
    }
    elsif ( defined $return ) {
        $message .= "There was a file error: $!\n";
    }
    else {
        $message .= "An unspecified error occurred\n";
    }
    $message .= <<MESSAGE;
(if this is a TWiki release prior to 4.2, you can download this
 file from: http://twiki.org/cgi-bin/view/Codev/ExtenderScript
 and place it in
 $wd/tools
 Create the directory if necessary).
************************************************************
MESSAGE
    die $message;    # Propagate
}
chdir $wd;           # Return after loading extender.pl

sub test_check_dep_not_perl {
    my ($this) = @_;

    # Check an external dependency
    # 0, Module is type external, and cannot be automatically checked.
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        { type => "external", name => "libpcap", version => "1.0.0" } );
    $this->assert_equals( 0, $ok );
    $this->assert_matches( qr/cannot be automatically checked/, $message );
}

sub test_check_dep_not_module {
    my ($this) = @_;

    # Check a non-existing module
    # 0,
    my ( $ok, $message ) =
      Foswiki::Extender::check_dep( { type => "perl", name => "Non::Existing::Module" } );
    $this->assert_equals( 0, $ok );
    $this->assert_matches( qr/Can't locate Non.*Existing.*Module/, $message );

}

sub test_check_dep_carp {
    my ($this) = @_;

    # Check a normally installed dependency
    # 1, Carp v1.03 loaded
    my ( $ok, $message ) =
      Foswiki::Extender::check_dep( { type => "perl", name => "Carp" } );
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/Carp v.* loaded/, $message );

}

sub test_check_dep_carp_with_version {
    my ($this) = @_;

    # Check a normally installed dependency
    # 1, Carp v1.03 loaded
    my ( $ok, $message ) =
      Foswiki::Extender::check_dep( { type => "perl", name => "Carp", version => 0.1 } );
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/Carp v.* loaded/, $message );

}

sub test_check_dep_version_too_high {
    my ($this) = @_;

    # Check a normal installed dependency with an absurd high version number
    # 0, HTML::Parser version 21.1 required--this is only version 1.05
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        { type => "cpan", name => "HTML::Parser", version => "21.1" } );
    $this->assert_equals( 0, $ok );
    $this->assert_matches(
        qr/HTML::Parser version 21\.1 required--this is only version/,
        $message );

}

sub test_check_dep_version_with_superior {
    my ($this) = @_;

    # Check a normal installed dependency with a superior sign
    # 1, HTML::Parser v1.05 loaded
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        { type => "cpan", name => "HTML::Parser", version => ">=0.9" } );
    $this->assert_equals( 1, $ok );
    $this->assert_matches(
        qr/HTML::Parser v\d+\.\d+ loaded/,
        $message );

}

sub test_check_dep_version_with_inferior {
    my ($this) = @_;

    # Check a normal installed dependency with an inferior
    # 1, HTML::Parser v1.05 loaded
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        { type => "cpan", name => "HTML::Parser", version => "<21.1" } );
    $this->assert_equals( 1, $ok );
    $this->assert_matches(
        qr/HTML::Parser v\d+\.\d+ loaded/,
        $message );

}

sub test_check_dep_version_with_inferior_failed {
    my ($this) = @_;

    # Check a normal installed dependency with an inferior too low
    # 0, Module HTML::Parser is version v3.60 and the dependency wants <1
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        { type => "cpan", name => "HTML::Parser", version => "<1" } );
    $this->assert_equals( 0, $ok );
    $this->assert_matches(
        qr/HTML::Parser is version v\d+\.\d+ and the dependency wants <1/,
        $message );

}

sub test_check_dep_version_with_rev {
    my ($this) = @_;

    # Check a normal installed dependency with a $Rev$ version number
    # 1, Foswiki::Contrib::JSCalendarContrib v1234 loaded
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        {
            type    => "perl",
            name    => "Foswiki::Contrib::JSCalendarContrib",
            version => ">=0.961"
        }
    );
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/Foswiki::Contrib::JSCalendarContrib v.* loaded/,
        $message );
    $this->assert($message =~ /v(\d+) /, $message);
    my $revision = $1;
    $this->assert($revision ne '999999');
}

sub test_check_dep_version_with_multi_part_number {
    my ($this) = @_;

    # Check a normal installed dependency with a 1.23.4 version number
    # 1, Foswiki::Contrib::UnitTestContrib::MultiDottedVersion v1.23.4 loaded
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        {
            type    => "perl",
            name    => "Foswiki::Contrib::UnitTestContrib::MultiDottedVersion",
            version => ">=1.5.6"
        }
    );
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/Foswiki::Contrib::UnitTestContrib::MultiDottedVersion v1\.23\.4 loaded/,
        $message );
}

sub test_check_dep_version_with_underscore {
    my ($this) = @_;

    # Check a normal installed dependency with a version number that includes _
    # 1, Algorithm::Diff v1.19_01 loaded
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        {
            type    => "perl",
            name    => "Algorithm::Diff",
            version => ">=1.18_45"
        }
    );
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/Algorithm::Diff v\d+\.\d+(?:_\d+)? loaded/,
        $message );

}

sub test_compare_versions {
    my ($this) = @_;

    # Each tuple describes one version comparison and the expected result
    # The first value is the expected result. 1 means "true" and 0 means "false.
    # The second and fourth values are the versions to compare.
    # The third value is the comparison operator as a string.
    my @comparisons = (
        # Plain integer versions
        [1, 2, '<',  10],
        [1, 2, '<=', 10],
        [0, 2, '>',  10],
        [0, 2, '>=', 10],
        [0, 2, '=',  10],

        [0, 10, '<',  2],
        [0, 10, '<=', 2],
        [1, 10, '>',  2],
        [1, 10, '>=', 2],
        [0, 10, '=',  2],

        [0, ' 10', '<',  2],
        [0, ' 10', '<=', 2],
        [1, ' 10', '>',  2],
        [1, ' 10', '>=', 2],
        [0, ' 10', '=',  2],

        [0, '10 ', '<',  2],
        [0, '10 ', '<=', 2],
        [1, '10 ', '>',  2],
        [1, '10 ', '>=', 2],
        [0, '10 ', '=',  2],

        [0, 2, '<',  2],
        [1, 2, '<=', 2],
        [0, 2, '>',  2],
        [1, 2, '>=', 2],
        [1, 2, '=',  2],

        # trailing and leading spaces should not affect 
        # the value of a version nuumber
        [1, ' 2',  '=',  2],
        [1, '2 ',  '=',  2],
        [1, ' 2 ', '=',  2],
        [1, ' 2',  '=',  ' 2'],
        [1, '2 ',  '=',  ' 2'],
        [1, ' 2 ', '=',  ' 2'],
        [1, ' 2',  '=',  '2 '],
        [1, '2 ',  '=',  '2 '],
        [1, ' 2 ', '=',  '2 '],
        [1, ' 2',  '=',  ' 2 '],
        [1, '2 ',  '=',  ' 2 '],
        [1, ' 2 ', '=',  ' 2 '],

        # SVN-style revision numbers should be treated like integers
        [1, '$Rev: 2 $', '<',  10],
        [1, '$Rev: 2 $', '<=', 10],
        [0, '$Rev: 2 $', '>',  10],
        [0, '$Rev: 2 $', '>=', 10],
        [0, '$Rev: 2 $', '=',  10],

        [0, '$Rev: 10 $', '<',  2],
        [0, '$Rev: 10 $', '<=', 2],
        [1, '$Rev: 10 $', '>',  2],
        [1, '$Rev: 10 $', '>=', 2],
        [0, '$Rev: 10 $', '=',  2],

        [0, '$Rev: 2 $', '<',  2],
        [1, '$Rev: 2 $', '<=', 2],
        [0, '$Rev: 2 $', '>',  2],
        [1, '$Rev: 2 $', '>=', 2],
        [1, '$Rev: 2 $', '=',  2],

        # compare X.Y and X
        [1, 1.1, '<',  2],
        [1, 1.1, '<=', 2],
        [0, 1.1, '>',  2],
        [0, 1.1, '>=', 2],
        [0, 1.1, '=',  2],

        # compare X.Y and X.Y.Z
        [1, 1.1, '<',  '1.2.1'],
        [1, 1.1, '<=', '1.2.1'],
        [0, 1.1, '>',  '1.2.1'],
        [0, 1.1, '>=', '1.2.1'],
        [0, 1.1, '=',  '1.2.1'],

        # Versions with _ 
        [1, '2.36_04', '<',  '2.36_10'],
        [1, '2.36_04', '<=', '2.36_10'],
        [0, '2.36_04', '>',  '2.36_10'],
        [0, '2.36_04', '>=', '2.36_10'],
        [0, '2.36_04', '=',  '2.36_10'],

        # Letters in the version number
        [1, '1.2.4.5-beta1', '<',  '1.2.4.5-beta2'],
        [1, '1.2.4.5-beta1', '<=', '1.2.4.5-beta2'],
        [0, '1.2.4.5-beta1', '>',  '1.2.4.5-beta2'],
        [0, '1.2.4.5-beta1', '>=', '1.2.4.5-beta2'],
        [0, '1.2.4.5-beta1', '=',  '1.2.4.5-beta2'],

        # Special case: beta versions are less than non-beta versions
        [1, '1.2.4.5-beta1', '<',  '1.2.4.5'],
        [1, '1.2.4.5-beta1', '<=', '1.2.4.5'],
        [0, '1.2.4.5-beta1', '>',  '1.2.4.5'],
        [0, '1.2.4.5-beta1', '>=', '1.2.4.5'],
        [0, '1.2.4.5-beta1', '=',  '1.2.4.5'],

        # Letters in the version number
        [1, '1.2.5', '<',  '1.2.5a'],
        [1, '1.2.5', '<=', '1.2.5a'],
        [0, '1.2.5', '>',  '1.2.5a'],
        [0, '1.2.5', '>=', '1.2.5a'],
        [0, '1.2.5', '=',  '1.2.5a'],

        # compare vX.Y with X.Y
        [1, 'v1.2', '<',  '2.2'],
        [1, 'v1.2', '<=', '2.2'],
        [0, 'v1.2', '>',  '2.2'],
        [0, 'v1.2', '>=', '2.2'],
        [0, 'v1.2', '=',  '2.2'],
        
        # Presence or absence of leading v
        # makes no difference to the value of X.Y version numbers
        [0, 'v1.2', '<',  '1.2'],
        [1, 'v1.2', '<=', '1.2'],
        [0, 'v1.2', '>',  '1.2'],
        [1, 'v1.2', '>=', '1.2'],
        [1, 'v1.2', '=',  '1.2'],

        # dd Mmm yyyy dates
        [1, '1 Jan 2009',  '<', '2 Jan 2009'],
        [1, '2 Jan 2009',  '=', ' 2 Jan 2009'],
        [1, '2 Jan 2009',  '=', '02 Jan 2009'],
        [1, '2-Jan-2009',  '=', '2 Jan 2009'],
        [1, '2 Jan 2009',  '<', '20 Jan 2009'],
        [1, '21 Jan 2009', '<', '22 Jan 2009'],
        [0, '2 Jan 2009',  '=', '20 Jan 2009'],
        [0, '2 Jan 2009',  '=', ' 3 Jan 2009'],
        [0, '2 Jan 2009',  '=', '03 Jan 2009'],
        [0, '2 Jan 2009',  '=', '2 Feb 2009'],
        [0, '2 Jan 2009',  '=', '2 Jan 2010'],
        [1, '2 Jan 2009',  '<', '10 Jan 2009'],
        [1, '2 Feb 2009',  '>', '10 Jan 2009'],
        [1, '2 Feb 2009',  '<', '10 Jan 2010'],

        # ordering of months
        [1, '31 Jan 2000', '<', '1 Feb 2000'],
        [1, '29 Feb 2000', '<', '1 Mar 2000'],
        [1, '31 Mar 2000', '<', '1 Jun 2000'],
        [1, '30 Jun 2000', '<', '1 Jul 2000'],
        [1, '31 Jul 2000', '<', '1 Aug 2000'],
        [1, '31 Aug 2000', '<', '1 Sep 2000'],
        [1, '30 Sep 2000', '<', '1 Oct 2000'],
        [1, '31 Oct 2000', '<', '1 Nov 2000'],
        [1, '30 Nov 2000', '<', '1 Dec 2000'],
        [1, '31 Dec 2000', '<', '1 Jan 2001'],

        # ISO dd-mm-yyyy dates
        [1, '1-2-2000',  '=', '01-2-2000'],
        [1, '1-2-2000',  '=', '01-02-2000'],
        [1, '1-2-2000',  '=', '1-02-2000'],
        [1, '1-3-2000',  '<', '2-3-2000'],
        [1, '10-3-2000', '<', '11-3-2000'],
        [1, '10-4-2000', '>', '11-3-2000'],
        [1, '10-3-2001', '>', '11-4-2000'],

        # yyyymmdd dates
        [1, '20090414', '>', '20090413'],
        [1, '20090414', '=', '20090414'],
        [1, '20090414', '<', '20090415'],
        [1, '20090414', '>', '20090314'],
        [1, '20090414', '<', '20090514'],
        [1, '20090414', '<', '20091114'],
        [1, '20100414', '>', '20090414'],

        # Various versions that must be greater than 0
        [1, '0.00_01',    '>', 0],
        [1, '0.1',        '>', 0],
        [1, '0.0.0.1',    '>', 0],
        [1, 'v0.1',       '>', 0],
        [1, 'v0.0.0.1',   '>', 0],
        [1, '1 Jan 1990', '>', 0],
        [1, '1-1-1990',   '>', 0],
        [1, '19900101',   '>', 0],

        # An SVN-style version number
        # is not affected by the spacing
        # and is greater than 0
        [1, '$Rev:   $', '=',  '$Rev$'],
        [1, '$Rev:  $',  '=',  '$Rev$'],
        [1, '$Rev: $',   '=',  '$Rev$'],
        [1, '$Rev:$',    '=',  '$Rev$'],
        [1, '$Rev $',    '=',  '$Rev$'],
        [1, '$Rev$',     '>',  0],
        [1, '$Rev$',     '>=', 1],

        # Blank version number is less than 1
        [1, '', '<',  1],
        [1, '', '<=', 1],
        [0, '', '>',  1],
        [0, '', '>=', 1],
        [0, '', '=',  1],

        # Blank comparator operator always gives false result
        # And undef inputs generate no warnings
        [0, 1,     '', 1],
        [0, 1,     '', 0],
        [0, 1,     '', undef],
        [0, 0,     '', 1],
        [0, 0,     '', 0],
        [0, 0,     '', undef],
        [0, undef, '', 1],
        [0, undef, '', 0],
        [0, undef, '', undef],

        [0, 1,     'x', 1],
        [0, 1,     'x', 0],
        [0, 1,     'x', undef],
        [0, 0,     'x', 1],
        [0, 0,     'x', 0],
        [0, 0,     'x', undef],
        [0, undef, 'x', 1],
        [0, undef, 'x', 0],
        [0, undef, 'x', undef],

        [0, 1,     undef, 1],
        [0, 1,     undef, 0],
        [0, 1,     undef, undef],
        [0, 0,     undef, 1],
        [0, 0,     undef, 0],
        [0, 0,     undef, undef],
        [0, undef, undef, 1],
        [0, undef, undef, 0],
        [0, undef, undef, undef],

    );
    foreach my $set (@comparisons) {
        my $expected = shift @$set;
        my $actual = Foswiki::Extender::compare_versions(@$set) ? 1 : 0;
        $this->assert_equals( $expected, 
                              $actual, 
                              join(' ', '[', map({ defined($_) ? $_ : 'undef' } @$set), '] should give', $expected) );
    }
}

1;
