# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Dependency

This module defines a dependency required by a Foswiki module and provides
functions to test if the dependency is installed, and compare versions with
the required version.

It is also used to examine the installed version of a Foswiki module.

=cut

package Foswiki::Configure::Dependency;

use strict;
use warnings;

my @MNAMES  = qw(jan feb mar apr may jun jul aug sep oct nov dec);
my $mnamess = join( '|', @MNAMES );
my $MNAME   = qr/$mnamess/i;
my %M2N;
foreach ( 0 .. $#MNAMES ) { $M2N{ $MNAMES[$_] } = $_ + 1; }

my %STRINGOPMAP = (
    'eq' => 'eq',
    'ne' => 'ne',
    'lt' => 'lt',
    'gt' => 'gt',
    'le' => 'le',
    'ge' => 'ge',
    '='  => 'eq',
    '==' => 'eq',
    '!=' => 'ne',
    '<'  => 'lt',
    '>'  => 'gt',
    '<=' => 'le',
    '>=' => 'ge'
);

=begin TML

---++ ClassMethod new( %opts ) 

Create an object instance representing a single dependency, as read from DEPENDENCIES
   * %opts
      * =name             => unqualified name e.g. SafeWikiPlugin=
      * =module           => qualified module e.g Foswiki::Plugins::SafeWikiPlugin=
         * If a qualified =module= is not provided, all possible Foswiki/TWiki module types are searched for =type=perl=
      * =type             => perl|cpan|external=
         * =perl= is a Foswiki or TWiki module.  =external= is used for any program other than a perl module.  External dependencies are __not__ checked.
      * =version          => version condition e.g. ">1.2.3"=
      * =trigger          => ONLYIF condition= (Specifies a version of another module, such as the Foswiki Func API)
      * =description      => text=

   * Instance variables set by calling studyInstallation() or indirectly by calling check() 
      * =installedVersion => $VERSION string from module=
      * =installedRelease => $RELEASE string from module (or $VERSION)=
      * =notes            => text   Notes on condition of module= (ex. fails due to missing dependency)

=cut

sub new {
    my ( $class, %opts ) = @_;
    my $this = bless( \%opts, $class );

    # If {module} is defined but not {name}, we can usually work it out
    if ( $this->{module} && !$this->{name} ) {
        $this->{name} = $this->{module};
        $this->{name} =~ s/^.*:://;
    }

    # If {name} is defined but {module} is not, we'll have to work that
    # out when we try to load the module in studyInstallation.
    die "No name or module in dependency" unless $this->{name};

    # If no version condition is given, assume we will just test that the
    # module is installed (any version)
    $this->{version} ||= '>=0';

    # Other defaults
    $this->{trigger}     ||= 1;
    $this->{type}        ||= 'external';             # assume external module
    $this->{description} ||= 'Nondescript module';
    $this->{notes} = '';

    return $this;
}

=begin TML

---++ ObjectMethod check()

Check whether the dependency is satisfied by a currently-installed module.
   * Return: ($ok, $msg)
      * $ok is a boolean indicating success/failure
      * $msg is a helpful message describing the failure
      * $release is the installed release of the module, as determined from the values of $RELEASE and $VERSION in the module.

=cut

sub check {
    my $this = shift;

    # reject non-Perl dependencies
    if ( $this->{type} !~ /^(?:perl|cpan)$/i ) {
        return ( 0, <<LALA );
$this->{module} is type $this->{type}, and cannot be automatically checked.
Please check it manually and install if necessary.
LALA
    }

    # Examine the current install of the module
    if ( !$this->studyInstallation() ) {
        return ( 0, <<LALA );
$this->{module} version $this->{version} required
 -- $this->{type} $this->{notes}
LALA
    }
    elsif ( $this->{version} =~ /^\s*([<>=]+)?\s*(.+)/ ) {

        # the version field is a condition
        my $op = $1 || '>=';
        my $requiredVersion = $2;
        unless ( $this->compare_versions( $op, $requiredVersion ) ) {

            # module doesn't meet this condition
            return ( 0, <<LALA);
$this->{module} version $op $requiredVersion required
 -- installed version is $this->{installedRelease}
LALA
        }
    }
    return ( 1, <<LALA );
$this->{module} version $this->{installedRelease} loaded
LALA
}

=begin TML

---++ ObjectMethod studyInstallation()

Check the current installation, populating the ={installedRelease}= and ={installedVersion}= fields, and returning true if the extension is installed. 
={notes}= will also be set when certain conditions are discovered (example:  missing dependencies or other compile failures).

   * Return: $ok
      * $ok is a boolean indicating success/failure.  If the module is found and a VERSION and RELEASE are discovered, the method returns true.

=cut

sub studyInstallation {
    my $this        = shift;
    my $load_errors = '';

    if ( !$this->{module} ) {
        my $lib = ( $this->{name} =~ /Plugin$/ ) ? 'Plugins' : 'Contrib';
        foreach my $namespace qw(Foswiki TWiki) {
            my $path = $namespace . '::' . $lib . '::' . $this->{name};
            eval "require $path";
            unless ( $@ && $@ =~ m/^Can't locate $path/ ) {
                $this->{module} = $path;
                $load_errors = $@ if ($@);
                last;
            }
        }
    }
    return 0 unless $this->{module};

    unless ($load_errors) {
        eval "require $this->{module}";
        $load_errors = $@ if ($@);
    }

    my $path = $this->{module};
    $path =~ s#::#/#g;
    $path .= '.pm';

    if ( $load_errors =~ m/^Can't locate $path/ ) {
        $this->{notes} = "module is not installed";
        return;
    }
    elsif ( $load_errors =~ m/^(Couldn't require|Can't locate|Insecure dep)/ ) {
        $this->{notes} = "module missing required dependencies";
        print STDERR
"Unexpected errors attempting to determine version of dependency\n$load_errors\n";
        return 1 if ( $this->_recover_versions($path) );
        return;
    }
    elsif ( $load_errors =~ m/^Died/) {
        $this->{notes} = "module died with errors when loaded";
        print STDERR
"Unexpected errors attempting to determine version of dependency\n$load_errors\n";
        return 1 if ( $this->_recover_versions($path) );
        return;
    }
    elsif ( $load_errors ) {
        $this->{notes} = "Unknown errors loading module";
        print STDERR
"Unexpected errors attempting to determine version of dependency\n$load_errors\n";
        return 1 if ( $this->_recover_versions($path) );
        return;
    }

    no strict 'refs';
    $this->{installedVersion} = ${"$this->{module}::VERSION"} || 0;
    $this->{installedRelease} = ${"$this->{module}::RELEASE"}
      || $this->{installedVersion};
    use strict 'refs';

    # Check if it's pseudo installed. Only works on platforms that
    # support soft links (and assumes the pseudo-install was -l)
    $path = $this->{module};
    $path =~ s#::#/#g;
    $path .= '.pm';
    foreach my $dir (@INC) {
        if ( -e "$dir/$path" ) {
            if ( -l "$dir/$path" ) {

                # Assume pseudo-installed
                $this->{installedVersion} = 'HEAD';
            }
            last;
        }
    }

    return 1;
}

sub _recover_versions {
    my ( $this, $path ) = @_;
    foreach my $dir (@INC) {
        if ( -e "$dir/$path" ) {

            my $modfh = open my $mod, '<', "$dir/$path";
            if ( !$modfh ) {
                return 0;
            }
            my $file_contents = do { local $/; <$mod> };
            my $VERSION;
            my $RELEASE;

            my ($version) = $file_contents =~ m/^\s*(?:our)?\s*(\$VERSION\s*=.*?);/sm;
            my ($release) =
              $file_contents =~ m/^\s*(?:our)?\s*(\$RELEASE\s*=.*?);/sm;

            eval $version if ($version);
            eval $release if ($release);

            $this->{installedVersion} = $VERSION || 0;
            $this->{installedRelease} = $RELEASE || $this->{installedVersion};

            return 1;

        }
    }
}

=begin TML

---++ ObjectMethod compare_versions ($condition, $release) 

 Compare versions (provided as $RELEASE, $VERSION) with a release specifier

 Returns the boolean result of the comparison

=cut

sub compare_versions {
    my $this = shift;
    if ( $this->{type} eq 'perl' ) {
        return $this->_compare_extension_versions(@_);
    }
    else {
        return $this->_compare_cpan_versions(@_);
    }
}

# Heuristically compare version strings in cpan modules
sub _compare_cpan_versions {
    my ( $this, $op, $b ) = @_;

    my $a = $this->{installedVersion};

    return 0 if not defined $op or not exists $STRINGOPMAP{$op};
    my $string_op = $STRINGOPMAP{$op};

    # CDot: changed largest char because collation order makes string
    # comparison weird in non-iso8859 locales
    my $largest_char = 'z';

    # remove leading and trailing whitespace
    # because ' X' should compare equal to 'X'
    $a =~ s/^\s+//;
    $a =~ s/\s+$//;
    $b =~ s/^\s+//;
    $b =~ s/\s+$//;

    # $Rev$ without a number should compare higher than anything else
    $a =~ s/^\$Rev:?\s*\$$/$largest_char/;
    $b =~ s/^\$Rev:?\s*\$$/$largest_char/;

    # remove the SVN marker text from the version number, if it is there
    $a =~ s/^\$Rev: (\d+) \$$/$1/;
    $b =~ s/^\$Rev: (\d+) \$$/$1/;

    # swap the day-of-month and year around for ISO dates
    my $isoDatePattern = qr/^\d{1,2}-\d{1,2}-\d{4}$/;
    if ( $a =~ $isoDatePattern and $b =~ $isoDatePattern ) {
        $a =~ s/^(\d+)-(\d+)-(\d+)$/$3-$2-$1/;
        $b =~ s/^(\d+)-(\d+)-(\d+)$/$3-$2-$1/;
    }

    # Change separator characters to be the same,
    # because X-Y-Z should compare equal to X.Y.Z
    # and combine adjacent separators,
    # because '6  jun 2009' should compare equal to '6 jun 2009'
    my $separator = '.';
    $a =~ s([ ./_-]+)($separator)g;
    $b =~ s([ ./_-]+)($separator)g;

    # Replace month-names with numbers and swap day-of-month and year
    # around to make them sortable as strings
    # but only do this if both versions look like a date
    my $datePattern = qr(\b\d{1,2}$separator$MNAME$separator\d{4}\b);
    if ( $a =~ $datePattern and $b =~ $datePattern ) {
        $a =~
s/(\d+)$separator($MNAME)$separator(\d+)/$3.$separator.$M2N{ lc($2) }.$separator.$1/ge;
        $b =~
s/(\d+)$separator($MNAME)$separator(\d+)/$3.$separator.$M2N{ lc($2) }.$separator.$1/ge;
    }

    # convert to lowercase
    # because 'cairo' should compare less than 'Dakar'
    $a = lc($a);
    $b = lc($b);

    # remove a leading 'v' if both are of the form X.Y
    # because vX.Y should compare equal to X.Y
    my $xDotYPattern = qr/^v?\s*\d+(?:$separator\d+)+/;
    if ( $a =~ $xDotYPattern and $b =~ $xDotYPattern ) {
        $a =~ s/^v\s*//;
        $b =~ s/^v\s*//;
    }

    # work out how many characters there are in the longest sequence
    # of digits between the two versions
    my ($maxDigits) =
      reverse
      sort( map { length($_) } ( $a =~ /(\d+)/g ), ( $b =~ /(\d+)/g ), );

    # justify digit sequences so that they compare correctly.
    # E.g. '063' lt '103'
    $a =~ s/(\d+)/sprintf('%0'.$maxDigits.'u', $1)/ge;
    $b =~ s/(\d+)/sprintf('%0'.$maxDigits.'u', $1)/ge;

    # there is no need to justify non-digit sequences
    # because 'alpha' compares less than 'beta'

    # X should compare greater than X-beta1
    # so append a high-value character to the
    # non-beta version if one version looks like
    # a beta and the other does not
    if ( $a =~ /^$b$separator?beta/ ) {

        # $a is beta of $b
        # $b should compare greater than $a
        $b .= $largest_char;
    }
    elsif ( $b =~ /^$a$separator?beta/ ) {

        # $b is beta of $a
        # $a should compare greater than $b
        $a .= $largest_char;
    }

    my $comparison;
    if ( $a =~ /^(\d+)(\.\d*)?$/ && $b =~ /^(\d+)(\.\d*)?$/ ) {
        $op = '==' if $op eq '=';
        $a += 0;
        $b += 0;
        $comparison = "$a $op $b";
    }
    else {
        $comparison = "'$a' $string_op '$b'";
    }
    my $result = eval $comparison;

    #print STDERR "[$comparison]->$result;\n";
    return $result;
}

# Compare foswiki extension versions using more rigorous rules
sub _compare_extension_versions {

    # $aRELEASE, $aVERSION - module release and svn version
    # $b - what we are comparing to (from DEPENDENCIES)
    my ( $this, $op, $b ) = @_;

    my $aRELEASE = $this->{installedRelease};
    my $aVERSION = $this->{installedVersion};

    return 0 if not defined $op or not exists $STRINGOPMAP{$op};
    my $string_op = $STRINGOPMAP{$op};
    my $e         = $b;

    # remove leading and trailing whitespace
    # because ' X' should compare equal to 'X'
    $b =~ s/^\s+//;
    $b =~ s/\s+$//;

    # What format is the version identifier? We support comparison
    # of four formats:
    # 1. A simple number (subversion revision). Also support $Rev$
    # 2. A dd Mmm yyyy format date
    # 3. An ISO yyyy-mm-dd format date
    # 4. A tuple N(.M)+

    # First see what format the RELEASE string is in, and break it
    # down into a tuple (most significant first)
    my @atuple;
    my @btuple;
    my $expect = 'svn';
    my $maxInt = 0x7FFFFFFF;
    if ( defined $aRELEASE ) {
        $aRELEASE =~ s/^\s+//;
        $aRELEASE =~ s/\s+$//;
        if ( $aRELEASE =~ /^(\d{4})-(\d{2})-(\d{2}).*$/ ) {

            # ISO date
            @atuple = ( $1, $2, $3 );
            $expect = 'date';
        }
        elsif ( $aRELEASE =~ /^(\d+)\s+($MNAME)\s+(\d+).*$/io ) {

            # dd Mmm YYY date
            @atuple = ( $3, $M2N{ lc $2 }, $1 );
            $expect = 'date';
        }
        elsif ( $aRELEASE =~ s/^V?(\d+([-_.]\d+)*).*?$/$1/i ) {

            # tuple e.g. 1.23.4
            @atuple = split( /[-_.]/, $aRELEASE );
            $expect = 'tuple';
        }
        else {
            print STDERR
              "Warning: $this->{name} has badly formatted RELEASE: $aRELEASE\n";

            # otherwise format not recognised; fall through to using $aVERSION
        }
    }

# SMELL:  Deal with poorly written DEPENDENCY files that compare for SVN release number.
    $expect = 'svn'
      if ( $b =~ m/^[0-9]{4,5}$/ )
      ;    # If we are looking for a 4 digit number, assume SVN

    if ( $b =~ m/^r([0-9]){1,6}$/ )
    {      # If we are looking for a r followed by 1-6 digit number, compare SVN
        $b      = $1;      # Strip the leading r
        $expect = 'svn'    # And force SVN comparison
    }

    if ( $expect eq 'svn' ) {

        # Didn't get a good RELEASE; fall back to subversion
        return 0 unless defined $aVERSION;
        $aVERSION =~ s/^\s+//;
        $aVERSION =~ s/\s+$//;
        $aVERSION =~ s/^\$Rev: (\d+).*\$$/$1/;
        $aVERSION =~ s/^\$Rev:?.*\$$/$maxInt/;
        @atuple = ( $aVERSION || 0 );

        # $Rev$
        $b =~ s/^\$Rev:?\s*\$.*$/$maxInt/;

        # $Rev: 1234$
        $b =~ s/^\$Rev: (\d+) \$.*$/$1/;

        # 1234 (7 Aug 2009)
        # 1234 (2009-08-07)
        $b =~ s/^(\d+)\s*\(.*\)$/$1/;

        unless ( $b =~ /^\d+$/ ) {
            print STDERR
"Warning: $this->{name} has badly formatted svn id in DEPENDENCIES: $e\n";
            return 0;
        }
        @btuple = ($b);
    }
    elsif ( $expect eq 'date' ) {
        if ( $b =~ /^(\d{4})-(\d{2})-(\d{2}).*$/ ) {

            # ISO date
            @btuple = ( $1, $2, $3 );
        }
        elsif ( $b =~ /^(\d+)\s+($mnamess)\s+(\d+).*$/io ) {

            # dd Mmm YYY date
            @btuple = ( $3, $M2N{ lc $2 }, $1 );
        }
        elsif ( $b =~ /^\d+$/ ) {
            @btuple = ($b);    # special case
        }
        else {
            print STDERR
"Warning: $this->{name} has badly formatted date in DEPENDENCIES: $e\n";
            return 0;
        }
    }
    elsif ( $expect eq 'tuple' ) {
        if ( $b =~ s/^[Vv]?(\d+([-._]\d+)*).*?$/$1/ ) {
            @btuple = split( /[-._]/, $b );
        }
        else {
            print STDERR
"Warning: $this->{name} has badly formatted tuple in DEPENDENCIES: $e\n";
            return 0;
        }
    }
    ( my $a, $b ) = _digitise_tuples( \@atuple, \@btuple );
    my $comparison = "'$a' $string_op '$b'";
    my $result     = eval $comparison;

    #print "[$comparison]->$result\n";
    return $result;
}

# Given two tuples, convert them both into number strings, padding with
# zeroes as necessary.
sub _digitise_tuples {
    my ( $a, $b ) = @_;

    my ($maxDigits) = reverse sort ( map { length($_) } ( @$a, @$b ) );
    $a = join(
        '',
        map {
            if   ( $_ eq 'HEAD' ) { $_ }
            else                  { sprintf( '%0' . $maxDigits . 'u', $_ ); }
          } @$a
    );
    $b = join(
        '',
        map {
            if   ( $_ eq 'HEAD' ) { $_ }
            else                  { sprintf( '%0' . $maxDigits . 'u', $_ ); }
          } @$b
    );

    # Pad with zeroes to equal length
    if ( length($b) > length($a) ) {
        $a .= '0' x ( length($b) - length($a) );
    }
    elsif ( length($a) > length($b) ) {
        $b .= '0' x ( length($a) - length($b) );
    }
    return ( $a, $b );
}

1;
__END__
Author: Crawford Currie http://wikiring.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
