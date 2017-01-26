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

use version 0.77;

use Assert;

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

my $MAXINT = 0x7FFFFFFF;

#--------------------------------------------------------------------------#
# LAX Version regexp components TAKEN FROM VERSION 0.96
#  - version 0.77 requried for core doesn't have the regex
#  SMELL: Replace this with $version::LAX once version 0.78 or > is required
#--------------------------------------------------------------------------#

# Fraction part of a decimal version number.  This is a common part of
# both strict and lax decimal versions

my $FRACTION_PART = qr/\.[0-9]+/;

# First part of either decimal or dotted-decimal lax version number.
# Unsigned integer, but allowing leading zeros.  Always interpreted
# as decimal.  However, some forms of the resulting syntax give odd
# results if used as ordinary Perl expressions, due to how perl treats
# octals.  E.g.
#   version->new("010" ) == 10
#   version->new( 010  ) == 8
#   version->new( 010.2) == 82  # "8" . "2"

my $LAX_INTEGER_PART = qr/[0-9]+/;

# Second and subsequent part of a lax dotted-decimal version number.
# Leading zeroes are permitted, and the number is always decimal.  No
# limit on the numerical value or number of digits, so there is the
# possibility of overflow when converting to decimal form.

my $LAX_DOTTED_DECIMAL_PART = qr/\.[0-9]+/;

# Alpha suffix part of lax version number syntax.  Acts like a
# dotted-decimal part.

my $LAX_ALPHA_PART = qr/_[0-9]+/;

#--------------------------------------------------------------------------#
# Lax version regexp definitions
#--------------------------------------------------------------------------#

# Lax decimal version number.  Just like the strict one except for
# allowing an alpha suffix or allowing a leading or trailing
# decimal-point

my $LAX_DECIMAL_VERSION =
  qr/ $LAX_INTEGER_PART (?: \. | $FRACTION_PART $LAX_ALPHA_PART? )?
	|
	$FRACTION_PART $LAX_ALPHA_PART?
    /x;

# Lax dotted-decimal version number.  Distinguished by having either
# leading "v" or at least three non-alpha parts.  Alpha part is only
# permitted if there are at least two non-alpha parts. Strangely
# enough, without the leading "v", Perl takes .1.2 to mean v0.1.2,
# so when there is no "v", the leading part is optional

my $LAX_DOTTED_DECIMAL_VERSION = qr/
	v $LAX_INTEGER_PART (?: $LAX_DOTTED_DECIMAL_PART+ $LAX_ALPHA_PART? )?
	|
	$LAX_INTEGER_PART? $LAX_DOTTED_DECIMAL_PART{2,} $LAX_ALPHA_PART?
    /x;

# Complete lax version number syntax -- should generally be used
# anchored: qr/ \A $LAX \z /x
#
# REMOVED:
# The string 'undef' is a special case to make for easier handling
# of return values from ExtUtils::MM->parse_version

my $LAX = qr/ $LAX_DECIMAL_VERSION | $LAX_DOTTED_DECIMAL_VERSION /x;

#--------------------------------------------------------------------------#

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
      * =installed        => True if module is installed=
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
    $this->{trigger} ||= 1;
    $this->{type} ||= 'external';    # assume external module
    $this->{description} ||= 'This module has no description.';
    $this->{notes} = '';

    return $this;
}

=begin TML

---++ ObjectMethod check() -> ($ok, $msg)

Check whether the dependency is satisfied by a currently-installed module.
   * Return: ($ok, $msg)
      * $ok is a boolean indicating success/failure
      * $msg is a helpful message describing the failure

=cut

sub checkDependency {
    my $this = shift;

    # reject non-Perl dependencies
    if ( $this->{type} !~ /^(?:perl|cpan)$/i ) {
        return ( 0, <<LALA );
$this->{module} is type '$this->{type}', and cannot be automatically checked.
Please check it manually and install if necessary.
LALA
    }

    # Examine the current install of the module
    if ( !$this->studyInstallation() ) {
        return ( 0, <<TINKYWINKY );
$this->{module} version $this->{version} required
-- $this->{type} $this->{notes}
TINKYWINKY
    }
    elsif ( $this->{version} =~ m/^\s*([<>=]+)?\s*(.+)/ ) {

        # the version field is a condition
        my $op = $1 || '>=';
        my $requiredVersion = $2;
        unless ( $this->compare_versions( $op, $requiredVersion ) ) {

            # module doesn't meet this condition
            return ( 0, <<PO );
$this->{module} version $op $requiredVersion required
-- installed version is $this->{installedRelease}
PO
        }
    }
    return ( 1, <<DIPSY );
$this->{module} version $this->{installedRelease} installed
DIPSY
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

    my ( $inst, $ver, $loc, $rel );

    if ( !$this->{module} ) {
        my $lib = ( $this->{name} =~ m/Plugin$/ ) ? 'Plugins' : 'Contrib';
        foreach my $namespace (qw(Foswiki TWiki)) {
            my $path = $namespace . '::' . $lib . '::' . $this->{name};
            ( $inst, $ver, $loc, $rel ) =
              extractModuleVersion( $path, 'magic' );
            if ($inst) {
                $this->{module} = $path;
                last;
            }
        }
    }
    else {
        ( $inst, $ver, $loc, $rel ) =
          extractModuleVersion( $this->{module},
            $this->{module} =~ m/(?:Foswiki|TWiki)/ );
    }

    if ($inst) {
        $this->{installedVersion} = $ver;
        $this->{installedRelease} = $rel || $ver;
        $this->{installed}        = 1;
        $this->{location}         = $loc;
        if ( -l $loc ) {

            # Assume pseudo-installed
            $this->{installedVersion} = '9999.99_999';
        }
    }
    else {
        $this->{notes}            = "module is not installed";
        $this->{installedVersion} = '';
        $this->{installedRelease} = '';
        $this->{location}         = '';
        return 0;
    }

    return 0 unless $this->{module};
    return 1;
}

sub compare_using_cpan_version {

    my $va   = shift;
    my $verA = ( $va =~ m/^v/ ) ? version->declare($va) : version->parse($va);
    my $op   = shift;
    $op = '==' if $op eq '=';
    my $vb = shift;
    my $verB = ( $vb =~ m/^v/ ) ? version->declare($vb) : version->parse($vb);
    my $comparison = "\$verA $op \$verB";
    return eval($comparison);
}

=begin TML

---++ ObjectMethod compare_versions ($condition, $release) 

 Compare versions (provided as $RELEASE, $VERSION) with a release specifier

 Returns the boolean result of the comparison

=cut

sub compare_versions {
    my $this = shift;
    if ( $this->{type} eq 'perl' ) {

       #print STDERR "Comparing TYPE PERL $this->{module}\n" if $this->{module};
        return $this->_compare_extension_versions(@_);
    }
    else {

        #print STDERR "Comparing TYPE cpan $this->{module}\n";
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
# Note: _ is not changed,  it has special alpha significance for perl CPAN:version
    my $separator = '.';
    $a =~ s([ ./-]+)($separator)g;
    $b =~ s([ ./-]+)($separator)g;

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

# See if these are sane perl version strings,  if so we can use CPAN version to compare
    if ( $a =~ m/^$LAX$/ && $b =~ m/^$LAX$/ ) {

#print STDERR "$a and $b match LAX version rules, TEST $op ";
#print STDERR ( compare_using_cpan_version( $a, $op, $b )) ? " - TRUE\n" : " - FALSE \n";
        return ( compare_using_cpan_version( $a, $op, $b ) );
    }

    # remove a leading 'v' if either are of the form X.Y
    # because vX.Y should compare equal to X.Y
    my $xDotYPattern = qr/^v?\s*\d+(?:$separator\d+)+/;
    if ( $a =~ $xDotYPattern or $b =~ $xDotYPattern ) {
        $a =~ s/^v\s*//;
        $b =~ s/^v\s*//;
    }

    # work out how many characters there are in the longest sequence
    # of digits between the two versions
    my ($maxDigits) =
      reverse
      sort( map { length($_) } ( $a =~ m/(\d+)/g ), ( $b =~ m/(\d+)/g ), );

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
    if ( $a =~ m/^$b$separator?beta/ ) {

        # $a is beta of $b
        # $b should compare greater than $a
        $b .= $largest_char;
    }
    elsif ( $b =~ m/^$a$separator?beta/ ) {

        # $b is beta of $a
        # $a should compare greater than $b
        $a .= $largest_char;
    }

    my $comparison;
    if ( $a =~ m/^(\d+)(\.\d*)?$/ && $b =~ m/^(\d+)(\.\d*)?$/ ) {
        $op = '==' if $op eq '=';
        $a += 0;
        $b += 0;
        $comparison = "$a $op $b";
    }
    else {
        $comparison = "'$a' $string_op '$b'";
    }
    my $result = eval($comparison);

    #print STDERR "[$comparison]->$result;\n";
    return $result;
}

# Compare foswiki extension versions using more rigorous rules
# Returns true if the condition is true, false if not true, or invalid comparison
sub _compare_extension_versions {

    # $aRELEASE, $aVERSION - module release and svn version
    # $b - what we are comparing to (from DEPENDENCIES or configure FastReport)
    my ( $this, $op, $reqVer ) = @_;

    #print STDERR "Requiring $op $reqVer\n";

    my $aRELEASE = $this->{installedRelease};
    my $aVERSION = $this->{installedVersion};

    # If the operator is not defined, or invalid, return false
    if ( not defined $op or not exists $STRINGOPMAP{$op} ) {
        $op = '"undefined"' unless defined $op;

        #print STDERR "Unknown Operator $op \n";
        return 0;
    }

    my $string_op = $STRINGOPMAP{$op};
    my $e         = $b;

    # First see what format the RELEASE string is in, and break it
    # down into a tuple (most significant first)
    my @atuple;
    my @btuple;
    my $baseType = '';    # Type of version/release string for this module
    my $reqType  = '';    # Type of version/release string requested

    unless ( defined $reqVer ) {

        #print STDERR "Comparison not defined\n";
        return 0;
    }

    ( $reqType, @btuple ) = _decodeReleaseString($reqVer);

    #print STDERR "WANT TO COMPARE TO $reqType\n";

    # Try version first.   If it's a svn string,  then need to try release
    if ( defined $aVERSION ) {

        #print STDERR "Version $aVERSION defined\n";
        ( $baseType, @atuple ) =
          _decodeReleaseString($aVERSION);    # if defined $aVERSION;
    }

    #print STDERR "VERSION $aVERSION  decoded to $baseType\n" if ($baseType);
    unless ( defined $aVERSION ) {
        if ( defined $aRELEASE ) {

            #print STDERR "Version undef, $aRELEASE defined\n";
            ( $baseType, @atuple ) = _decodeReleaseString($aRELEASE);
        }
    }
    if ( $reqType eq 'svn' ) {

        #print STDERR "reqType is svn\n";
        unless ( $baseType eq 'svn' ) {

            #print STDERR "Try a different comparison\n";
            # Inconsistent VERSION, so try RELEASE
            if ( defined $aRELEASE ) {

                #print STDERR "Release $aRELEASE defined\n";
                ( $baseType, @atuple ) = _decodeReleaseString($aRELEASE);
            }
        }
    }

    if ( $reqType eq 'date' ) {

        #print STDERR "reqType is date\n";
        unless ( $baseType eq 'date' ) {

            # Inconsistent VERSION, so try RELEASE
            if ( defined $aRELEASE ) {

                #print STDERR "Release $aRELEASE defined\n";
                ( $baseType, @atuple ) = _decodeReleaseString($aRELEASE);
            }
        }
    }
    unless ($baseType) {

        #print STDERR "Unable to determine what to compare.\n";
        return 0;
    }

    #print STDERR "EXPECT $baseType $string_op BEXPECT $reqType \n";

# Requested version is a svn release,  Need to use VERSION instead of RELEASE stirng
    if ( $reqType eq 'svn' ) {

        #print STDERR "Expecting SVN comparison, but RELEASE was $baseType \n";
        ( $baseType, @atuple ) = _decodeReleaseString($aVERSION)
          if ( defined $aVERSION && $baseType ne 'svn' );
        return 1 if ( $baseType eq 'tuple' );
        return 0 unless ( $baseType eq 'svn' );

    }

    # See if request is for anything > 0.  If so, return true.
    if (   $reqType eq 'tuple'
        && scalar(@btuple) == 1
        && $btuple[0] == 0
        && $string_op eq 'gt' )
    {

        #print STDERR "'SPECIAL CASE - zero expected just means present\n";
        return 1;
    }

    # special handling for dates.
    if ( $reqType eq 'date' || $baseType eq 'date' ) {

      # special case,  if requested tuple, and installed date,  this is probably
      # a migration to a version tuple, so return true to trigger an update
        return 1
          if ( $reqType eq 'tuple'
            && $baseType eq 'date' );

        if ( $reqType ne $baseType ) {

            return 0;
        }

        if ( scalar(@btuple) != scalar(@atuple) || scalar(@btuple) != 3 ) {

            #print STDERR "Incorrectly formatted date in $aRELEASE or $b\n";
        }

        # Simple validations - grossly invalid year, month or day.
        return 0 if ( $atuple[0] < 1970 || $btuple[0] < 1970 );
        return 0 if ( $atuple[1] > 12   || $btuple[1] > 12 );
        return 0 if ( $atuple[1] < 1    || $btuple[1] < 1 );
        return 0 if ( $atuple[2] > 31   || $btuple[2] > 31 );
        return 0 if ( $atuple[2] < 1    || $btuple[2] < 1 );
    }

    if ( $baseType eq 'svn' && $reqType ne 'svn' ) {

        # Anything to SVN other than SVN or Integers needs to succeed.
        return 1 unless $reqVer =~ m/^\d+$/;    #keep going for integers
    }

    # We can't figure out the types, so just return false.
    return 0 if ( $baseType eq 'unknown' || $reqType eq 'unknown' );

    #print STDERR "have basetype $baseType reqType $reqType\n";

    # Do the comparisons
    ( my $a, $b ) = _digitise_tuples( \@atuple, \@btuple );

    #print STDERR "Doing the comparison  $a $string_op $b\n";

    my $comparison = "'$a' $string_op '$b'";
    my $result     = eval($comparison);

    #print STDERR "[$comparison]->$result\n";
    return $result;
}

#  Returns the type of the passed string
#
# What format is the release identifier? We support comparison
# of five formats:
# 1. A simple number (subversion revision).
# 2  Encoded SVN $Rev$ formats
# 3. A dd Mmm yyyy format date
# 4. An ISO yyyy-mm-dd format date
# 5. A tuple N(.M)+

# SVN Versions should always be an SVN release number
# coded in 3 formats
# 1. $Rev: <some number> $
# 2. $Rev: <some number> (date)$   (Date is ignored)
# 3. $Rev$ An unassigned Rev indicating a SVN checkout.

sub _decodeReleaseString {

    my ($rel) = @_;

    #print STDERR "_decodeReleaseString called with ($rel)\n";
    my $form;
    my @tuple;

    $rel =~ s/^\s+//;
    $rel =~ s/\s+$//;

    if ( $rel =~ m/^(\d{4})-(\d{2})-(\d{2}).*$/ ) {

        # ISO date
        @tuple = ( $1, $2, $3 );
        $form = 'date';
    }
    elsif ( $rel =~ m/^(\d+)\s+($MNAME)\s+(\d+).*$/i ) {

        # dd Mmm YYY date
        @tuple = ( $3, $M2N{ lc $2 }, $1 );
        $form = 'date';
    }
    elsif ( $rel =~ m/^([0-9]{4,5})$/ ) {

        #print STDERR "matching a svn VERSION\n";
        # svn rev,  4-5 digit number
        @tuple = ($1);
        $form  = 'svn';
    }
    elsif ( $rel =~ m/^r([0-9]{1,6})$/ ) {

        # svn rev, a 1-6 digit number prefixed by 'r'
        #print STDERR "matching a svn r VERSION\n";
        @tuple = ($1);
        $form  = 'svn';
    }
    elsif ( $rel =~ m/^\$Rev: (\d+)\s*\(.*\)$/ ) {

        # $Rev: 1234 (7 Aug 2009)
        # $Rev: 1234 (2009-08-07)
        #print STDERR "matching a svn \$Rev:  VERSION\n";
        @tuple = ($1);
        $form  = 'svn';
    }
    elsif ( $rel =~ m/^(\d+)\s*\(.*\)$/ ) {

        # 1234 (7 Aug 2009)
        # 1234 (2009-08-07)
        #print STDERR "matching a svn nnnn (date)  VERSION\n";
        @tuple = ($1);
        $form  = 'svn';
    }
    elsif ( $rel =~ m/^V?(\d+([-_.]\d+)*).*?$/i ) {

     # tuple e.g. 1.23.4   Note that a simple tuple could also be a low SVN rev.
     #print STDERR "matching a tuple with optional V prefix\n";
        @tuple = split( /[-_.]/, $1 );
        $form = 'tuple';
    }
    elsif ( $rel =~ m/^\$Rev: (\d+).*\$$/ ) {

        # $Rev: 1234$
        # print STDERR "matching a \$Rev: nnn\$ svn\n";
        @tuple = ($1);
        $form  = 'svn';
    }
    elsif ( $rel =~ m/^\$Rev:?\s*\$.*$/ ) {

        # $Rev$
        #print STDERR "matching a \$Rev: \$ undefined svn revision\n";
        @tuple = ($MAXINT);
        $form  = 'svn';
    }
    elsif ( $rel =~ m/^\s?$/ ) {

        # Blank or empty version
        @tuple = (0);
        $form  = 'tuple';
    }
    elsif ( $rel =~ m/^Foswiki-(\d+([-_.]\d+)*).*?$/i ) {

        #print STDERR "matching a Foswiki- version string\n";
        @tuple = split( /[-_.]/, $1 );
        $form = 'tuple';
    }
    else {

        # Some other format
        @tuple = (0);
        $form  = 'unknown';
    }

    #print STDERR "RELEASE $rel decodes as $form, @tuple \n";

    return ( $form, @tuple );
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

=begin TML

---++ StaticMethod extractModuleVersion ($moduleName, $magic) -> ($moduleFound, $moduleVersion, $modulePath)

Locates a module in @INC and parses it to determine its version.  If the second parameter is
true, it magically handles Foswiki.pm's version construction.

Returns:
  $moduleFound - True if the module was found (and could be opended for read)
  $moduleVersion - The module version that was extracted, or undef if none was found.
  $modulePath - The full path to the module.

Require was used previously, but it doesn't scale and can have side-effects such a
loading many unused dependencies, even LocalSite.cfg if it's a Foswiki module.

Since $VERSION is usually declared early in a module, we can also avoid reading
most of (most) files.

This parser was inspired by Module::Extract::VERSION, though this is simplified and
has special magic for the Foswiki build.

=cut

sub extractModuleVersion {
    my $module    = shift;
    my $FoswikiPM = shift;

    my $file = $module;
    $file =~ s,::,/,g;
    $file .= '.pm';

    # If module is available but no version, don't return undefined
    my $mod_version = '0';
    my $mod_release = '0';

    foreach my $dir (@INC) {
        open( my $mf, '<', "$dir/$file" ) or next;
        local $/ = "\n";
        local $_;
        my $pod;
        while (<$mf>) {
            chomp;
            if (/^=cut/) {
                $pod = 0;
                next;
            }
            if (/^=/) {
                $pod = 1;
                next;
            }
            next if ($pod);
            next if m/eval/; # Some modules issue $VERSION = eval $VERSION ... bypass that line
            s/\s*#.*$//;
            if ($FoswikiPM) {
                last if ( $mod_version && $mod_release );
                if (/^\s*(?:our\s+)?\$(?:\w*::)*VERSION\s*=~\s*(.*?);/) {
                    my $exp = $1;
                    $exp =~ s/\$RELEASE/\$mod_release/g;
                    eval("\$mod_version =~ $exp;");
                    print STDERR
"Dependency.pm 1-Failed to eval $1 from $_ in $file at line $.: $@\n"
                      if ($@);
                    last;
                }

                if (
/\$VERSION\s*=\s*version->(?:new|parse|declare)\s*\(\s*['"]([vV]?\d+\.\d+(?:\.\d+)?(?:_\d+)?)['"]\s*\)/
                  )
                {
                    $mod_version = $1;
                }
                if (
/^\s*(?:our\s+)?\$(?:\w*::)*(RELEASE|VERSION)\s*=(?!~)\s*(.*);/
                  )
                {
                    eval( "\$mod_" . lc($1) . " = $2;" );
                    print STDERR
"Dependency.pm 2-Failed to eval $2 from $_ in $file at line $.: $@\n"
                      if ($@);
                    next;
                }
                next;
            }
            next unless (/^\s*(?:our\s+)?\$(?:\w*::)*VERSION\s*=\s*(.*?);/);
            eval("\$mod_version = $1;");

    # die "Failed to eval $1 from $_ in $file at line $. $@\n" if( $@ ); # DEBUG
            last;
        }
        close $mf;
        return ( 1, $mod_version, "$dir/$file", $mod_release );
    }

    return ( 0, undef );
}

=begin TML

---++ StaticMethod checkPerlModules(@mods)

Examine the status of perl modules. Takes an array of references to hashes.
Each module hash needs:
  name - e.g. Car::Wreck
  usage - description of what it's for
  disposition - 'required', 'recommended'
  minimumVersion - lowest acceptable $Module::VERSION

If the module is installed, the hash will be updated to add
=installedVersion= - the version installed (or 'Unknown version'
or 'Not installed')

The result of the check is written to the =check_result= field.

=cut

sub checkPerlModules {

    foreach my $mod (@_) {

        $mod->{minimumVersion} ||= 0;
        $mod->{disposition}    ||= 'required';
        $mod->{condition}      ||= '>=';

        my $type = $mod->{name} =~ m/^(Foswiki|TWiki)\b/ ? 'perl' : 'cpan';

        my $dep = Foswiki::Configure::Dependency->new(
            module  => $mod->{name},
            type    => $type,
            version => $mod->{condition} . $mod->{minimumVersion},
        );
        my ( $ok, $msg ) = $dep->checkDependency();

        if ( $dep->{installed} ) {
            $mod->{installedVersion} =
              $dep->{installedVersion} || 'Unknown version';
            $mod->{location} = $dep->{location};
            $mod->{ok}       = $ok;
            $mod->{check_result} =
              $mod->{name} . ' ' . $mod->{installedVersion} . ' installed';
            unless ($ok) {
                $mod->{check_result} .=
                    ' *Version '
                  . $mod->{minimumVersion} . ' '
                  . $mod->{disposition};
            }
            $mod->{check_result} .= " for $mod->{usage}" if $mod->{usage};
            $mod->{check_result} .= '*' unless $ok;
            $mod->{check_result} .= " $msg"
              if $msg
              && ( !$ok || $mod->{installedVersion} eq 'Unknown version' );
        }
        else {
            $mod->{ok}               = 0;
            $mod->{installedVersion} = 'Not installed';
            $mod->{check_result} =
              $mod->{name} . ' is not installed. ' . $mod->{usage};
        }
    }
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
