# See bottom of file for license and copyright

package FoswikiTestCase;

=begin TML

---+ package FoswikiTestCase

Base class of all Foswiki tests. Establishes base paths and adds
some useful Foswiki-specific functionality.

The basic strategy in all unit tests is to never write to normal
Foswiki data areas; only ever write to temporary test areas. If you
have to create a test fixture that duplicates an existing area,
you can always create a new web based on that web.

=cut

use strict;
use warnings;

use Assert;
use Unit::TestCase();
our @ISA = qw( Unit::TestCase );

use Data::Dumper;

use Foswiki();
use Foswiki::Meta();
use Foswiki::Plugins();
use Unit::Request();
use Unit::Response();
use Error qw( :try );

use constant SINGLE_SINGLETONS => 0;
use constant TRACE             => 0;

BEGIN {

# SMELL: These were tainting @INC,   TestRunner.pl already adds these to the path
#        Tests still seem to run without them being added here.
#push( @INC, "$ENV{FOSWIKI_HOME}/lib" ) if defined( $ENV{FOSWIKI_HOME} );
#unshift @INC, '../../bin';    # SMELL: dodgy
    require 'setlib.cfg';
    $SIG{__DIE__} = sub { Carp::confess $_[0] };
}

our $didOnlyOnceChecks = 0;

# Temporary directory to store work files in (sessions, logs etc).
# Will be cleaned up after running the tests unless the environment
# variable FOSWIKI_DEBUG_KEEP is true
use File::Temp;
my $cleanup = $ENV{FOSWIKI_DEBUG_KEEP} ? 0 : 1;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    return $self;
}

sub _test_with_deps {
    my ( $this, $test, %skip_data ) = @_;

}

=begin TML

---+++ ObjectMethod skip_test_if($test, @skip_data) -> $reason

Skip =$test= if it is listed under a satisified condition key in =%skip_data=,
return =$reason= string if the test should be skipped, undef otherwise.

   * =$test=        - name of the test under consideration
   * =@skip_data=   - array of hashrefs, containing two keys:
      * =condition= - value is a hashref understood by =check_conditions_met=
      * =tests=     - =$test => $reason= key/value pairs.

Example:
<verbatim>
sub skip {
    my ( $this, $test ) = @_;

    return $this->SUPER::skip_test_if(
        $test,
        {
            # This condition matches on Foswiki versions < 1.2
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                # All permutations of verify_TableParser are skipped
                'TestSuite::verify_TableParser' =>
                  'TableParser not implemented until Foswiki 1.2',
            }
        },
        {
            # This condition matches on Foswikis 1.2+ with ShortURL config
            condition => {
                with_dep => 'Foswiki,>=,1.2',
                using    => 'ShortURLs',
            },
            tests => {
                # Only this permutation of verify_request is skipped
                'TestSuite::verify_request_redirect' =>
                  'This test makes no sense on Foswiki 1.2+ w/ShortURLs',
            },
        },
        {
            # This condition matches when Webservice::Solr is missing
            condition => { without_dep => 'Webservice::Solr' },
            tests     => {
                # Example of skipping an individual test
                'TestSuite::test_solr_thing' => 'Solr perl library missing',
            },
        }
    );
}
</verbatim>
=cut

sub skip_test_if {
    my ( $this, $test, @list ) = @_;
    my $skip_reason;

    if ( defined $test ) {
        while ( !defined $skip_reason && scalar(@list) ) {
            my $item = shift(@list);

            ASSERT( ref( $item->{condition} ) eq 'HASH' );
            if ( $this->check_conditions_met( %{ $item->{condition} } ) ) {
                my $verify_name = $this->{verify_permutations}{$test};

                if ( defined $item->{tests}{$test} ) {
                    $skip_reason = $item->{tests}{$test};
                }
                elsif ( $verify_name && defined $item->{tests}{$verify_name} ) {
                    $skip_reason = $item->{tests}{$verify_name};
                }
            }
            elsif (TRACE) {
                print STDERR "Condition not met: " . Dump( $item->{condition} );
            }
        }
    }

    return $skip_reason;
}

# Checks we only need to run once per test run
sub _onceOnlyChecks {
    return if $didOnlyOnceChecks;

    # Make sure we can create directories in $Foswiki::cfg{DataDir}, otherwise
    # the tests will mysteriously fail.
    my $t = "$Foswiki::cfg{DataDir}/UnitTestCheckDir";
    if ( -e $t ) {
        rmdir($t) || die "Could not remove old $t: $!";
    }
    mkdir($t)
      || die "Could not create $t: $!\nUser running tests "
      . 'has to be able to create directories in $Foswiki::cfg{DataDir}';
    rmdir($t) || die "Could not remove $t: $!";

    # Make sure we can disallow write permissions. Foswiki tests should
    # always be run as a non-admin user, so that they can test scenarios
    # where access permissions are denied.
    $t = "$Foswiki::cfg{DataDir}/UnitTestCheckFile";
    if ( -e $t ) {
        unlink($t)
          || die "Could not remove old $t: $!";
    }
    open( F, '>', $t )
      || die "Could not create $t: $!\nUser running tests "
      . "has to be able to create files in $Foswiki::cfg{DataDir}";
    print F "Blah";
    close(F);
    chmod( 0444, $t )
      || die "Failed to change permissions on $t: $!\n User running tests "
      . "must be able to change permissions on files it creates.";
    if ( open( F, '>', $t ) ) {
        close(F);
        unlink($t);
        die "Failed to protect a $t for write\nUser running tests "
          . "must be able to protect a file from write. "
          . "Perhaps you are running as the superuser?";
    }
    chmod( 0777, $t )
      || die "Failed to change permissions on $t: $!\nUser running tests "
      . "must be able to change permissions on files it creates.";
    unlink($t) || die "Could not remove $t: $!";

    $didOnlyOnceChecks = 1;
}

my %foswiki_things = (
    'MongoDBPlugin' => sub {
        my ($this) = @_;

        return ( $this->check_plugin_enabled('MongoDBPlugin')
              || $Foswiki::cfg{Store}{SearchAlgorithm} =~ m/MongoDB/
              || $Foswiki::cfg{Store}{QueryAlgorithm}  =~ m/MongoDB/ );
    },
    'ShortURLs' => sub {
        return ( exists $Foswiki::cfg{ScriptUrlPaths}{view}
              && defined $Foswiki::cfg{ScriptUrlPaths}{view}
              && !( $Foswiki::cfg{ScriptUrlPaths}{view} =~ m/view$/ ) );
    },
    'PlatformWindows' => sub {
        return ( $Foswiki::cfg{OS} eq 'WINDOWS'
              && ( $Foswiki::cfg{DetailedOS} ne 'cygwin' ) );
    },
    'SearchAlgorithmForking' => sub {
        return ( $Foswiki::cfg{Store}{SearchAlgorithm} eq
              'Foswiki::Store::SearchAlgorithms::Forking' );
    }
);

=begin TML

---++ ObjectMethod check_plugin_enabled($plugin) -> $boolean

Checks to see if =$plugin= is enabled

=cut

sub check_plugin_enabled {
    my ( $this, $plugin ) = @_;

    # Many tests don't have a $session data member.
    #return (
    #    defined $this->{session}
    #    ? $this->{session}->inContext( $plugin . 'Enabled' )
    #    : $Foswiki::cfg{Plugins}{$plugin}{Enabled}
    #);
    return $Foswiki::cfg{Plugins}{$plugin}{Enabled};
}

=begin TML

---++ ObjectMethod check_using($what) -> $boolean

Checks to see if the Foswiki session under test is using a named feature(s),
configuration profile(s) or plugin(s).

See the =%foswiki_things= hash for the range of features/configuration profiles
which can be checked

   * =$what= - name (or arrayref of names) of feature(s), configuration
     profile(s) or enabled plugin(s). When an arrayref is passed, =check_using()=
     returns true if all are in use. Therefore =check_using(['a', 'b'])= is
     logically equivalent to =check_using('a') && check_using('b')=

Examples:
<verbatim class="perl">
# True if MongoDBPlugin is in use (enabled, and/or used as search/query algo)
$this->check_using( 'MongoDBPlugin' );

# True if both running on a windows OS AND search algo is forking
$this->check_using( ['PlatformWindows', 'SearchAlgorithmForking'] );
</verbatim>

=cut

sub check_using {
    my ( $this, $what ) = @_;
    my $result;

    if ( ref($what) eq 'ARRAY' ) {
        my $not_usingsomething;

        foreach my $thing ( @{$what} ) {
            $not_usingsomething ||= !$this->_check_using($thing);
        }

        $result = !$not_usingsomething;
    }
    else {
        $result = $this->_check_using($what);
    }
    print STDERR "check_using('$what') : $result\n" if TRACE;

    return $result;
}

sub _check_using {
    my ( $this, $what ) = @_;
    my $result;

    if ( $what =~ m/^[^:]+Plugin$/ ) {
        print STDERR "_check_using, plugin enabled\n" if TRACE;
        $result = $this->check_plugin_enabled($what);
    }
    if ( !$result ) {
        if ( exists $foswiki_things{$what} ) {
            print STDERR "_check_using, things\n" if TRACE;
            $result = $foswiki_things{$what}->($this);
        }
        else {
            $this->assert( 0,
                "Don't know how to check if we're using '$what'" );
        }
    }
    print STDERR "_check_using('$what') : $result\n" if TRACE;

    return $result;
}

=begin TML

---++ ObjectMethod check_dependency($what) -> $boolean

Checks to see if a given dependency is present, optionally of a specified version

This is a wrapper to =Foswiki::Configure::Dependency->checkDependency()=

   * =$what= - a string (or arrayref of strings) specifying module(s) to check
     for, optionally of specific version(s). The string(s) should be compatible
     with BuildContrib's =DEPENDENCIES= file. When an arrayref is passed,
     returns true if all dependencies are met. Therefore
     =check_dependency(['a', 'b'])= is logically equivalent to
     =check_dependency('a') && check_dependency('b')=

Examples:
<verbatim class="perl">
$this->check_dependency('JSON');
$this->check_dependency('CGI,=,3.43'),
$this->check_dependency(['CGI,=,3.43','Foswiki,<,2.0']),
</verbatim>

=cut

sub check_dependency {
    my ( $this, $what ) = @_;
    my $result;

    if ( ref($what) eq 'ARRAY' ) {
        my $not_usingsomething;

        print STDERR "check_dependency, multiple\n" if TRACE;
        foreach my $thing ( @{$what} ) {
            $not_usingsomething ||= !$this->_check_dependency($thing);
        }

        $result = !$not_usingsomething;
    }
    else {
        print STDERR "check_dependency, single\n" if TRACE;
        $result = $this->_check_dependency($what);
    }
    print STDERR "check_dependency('$what'): '$result'\n" if TRACE;

    return $result;
}

sub _check_dependency {
    my ( $this, $what ) = @_;
    my $result;

    # Eg. Foswiki::Plugins::ZonePlugin,>=3.1,perl
    # TODO: type?
    if ( $what =~ m/^([^,]+)\s*(,\s*([^,]+),([^,]+))?/ ) {
        require Foswiki::Configure::Dependency;
        my ( $module, $equality, $version ) = ( $1, $3, $4 );
        print STDERR "_check_dependency, testing $module "
          . ( $equality || '""' ) . ' '
          . ( $version  || '""' ) . "\n"
          if TRACE;
        my $type = $module =~ m/^(Foswiki|TWiki)\b/ ? 'perl' : 'cpan';
        my $dep =
          defined $version
          ? Foswiki::Configure::Dependency->new(
            type    => $type,
            module  => $module,
            version => $equality . $version
          )
          : Foswiki::Configure::Dependency->new(
            type   => $type,
            module => $module
          );

        ($result) = $dep->checkDependency();
    }
    else {
        $this->assert( 0, "Don't know how to check for module '$what'" );
    }
    print STDERR "_check_dependency('$what'): '$result'\n" if TRACE;

    return $result;
}

=begin TML

---++ ObjectMethod expect_failure([$reason,] [%conditions])

Flag that the test is expected to fail in the current environment. This
is used for example on platfroms where tests are known to fail e.g. case
sensitivity of filenames on Win32.

   * =$reason=       - Optional. String with reason for why failure is expected.
   * =%conditions=   - Optional. Conditions to be met for failure to be expected
                       see =check_conditions_met()=

Examples:
<verbatim class="perl">
$this->expect_failure();
$this->expect_failure('Feature not yet implemented');
$this->expect_failure( using => 'ShortURLs' );
$this->expect_failure( with_dep => 'Foswiki,<,1.1' );
$this->expect_failure(
    'Requires ADDTOZONE feature',
    not_using   => 'ZonePlugin'
    with_dep => 'Foswiki,<,1.1'
);
$this->expect_failure(
    'Javascript and perl/Foswiki have different ideas about true & false',
    using => 'MongoDBPlugin'
);
$this->expect_failure(
    'Can\'t grep on windows',
    using => ['PlatformWindows', 'SearchAlgorithmForking']
);
$this->expect_failure(
    'CGI.pm 3.43 causes double-encoding when using utf-8',
    using => 'unicode',
    with_dep => 'CGI,=,3.43'
);
</verbatim>

=cut

sub expect_failure {
    my ( $this, @args ) = @_;
    my $reason = scalar(@args) % 2 ? shift(@args) : undef;

    if ( scalar(@args) ) {
        if ( $this->check_conditions_met(@args) ) {
            $this->SUPER::expect_failure($reason);
        }
    }
    else {
        $this->SUPER::expect_failure($reason);
    }

    return;
}

=begin TML

---++ ObjectMethod check_conditions_met(%conditions) -> $boolean

Check that ALL =%conditions= are met in the environment under test.

   * =%conditions=   - Hash of conditions to check. All must be met. Keys:
      * =using=      - String (or arrayref of strings) of named configuration
                       profile(s), feature(s) or plugin(s) which must be in use
                       for the failure to be expected. See =check_using()=
      * =not_using=  - As with =using=, but inverted sense (expect failure when
                       NOT using feature(s)/config(s)/plugin(s))
      * =with_dep=   - String (or arrayref of strings) of module(s), optionally
                       of specific version(s) which must be present for the
                       failure to be expected. Same strings as each line in
                       BuildContrib's DEPENDENCIES. See =check_dependency()=
      * =without_dep=  - opposite of =with_dep=

=cut

sub check_conditions_met {
    my ( $this, %conditions ) = @_;
    my $conditions_met;

    foreach my $key ( keys %conditions ) {
        $this->assert_matches( qr/^(using|not_using|with_dep|without_dep)$/,
            $key, "Don't know how to apply condition $key" );
    }
    if ( exists $conditions{using} ) {
        $conditions_met = $this->check_using( $conditions{using} ) ? 1 : 0;
    }
    if ( ( !defined $conditions_met || $conditions_met )
        && exists $conditions{with_dep} )
    {
        $conditions_met =
          $this->check_dependency( $conditions{with_dep} ) ? 1 : 0;
    }
    if ( ( !defined $conditions_met || $conditions_met )
        && exists $conditions{without_dep} )
    {
        $conditions_met =
          $this->check_dependency( $conditions{without_dep} ) ? 0 : 1;
    }
    if ( ( !defined $conditions_met || $conditions_met )
        && exists $conditions{not_using} )
    {
        $conditions_met = $this->check_using( $conditions{not_using} ) ? 0 : 1;
    }

    return $conditions_met;
}

=begin TML

---++ ObjectMethod populateNewWeb($web, $template, $opts)

Creates a new web =$web= from the =$template= web (defaults to =_default=).

=cut

sub populateNewWeb {
    my ( $this, $web, $template, $opts ) = @_;
    my $webObject;

    require Foswiki::Store;
    if ( defined &Foswiki::Store::create ) {

        # store2
        $webObject = Foswiki::Store->create( address => { web => $web } );
    }
    else {

        # pre-store2, Foswiki 1.1.x and below
        $webObject = Foswiki::Meta->new( $Foswiki::Plugins::SESSION, $web );
    }
    $webObject->populateNewWeb( $template, $opts );
    return $webObject;
}

=begin TML

---++ ObjectMethod getUnloadedTopicObject($web, $topic) -> $topicObject

Get an unloaded topic object.

Equivalent to Foswiki::Meta->new, we take the session from $this->{session}.

That assumes all the tests are playing nice, and aren't doing Foswiki->new()
themselves (using createNewFoswikiSession instead).

=cut

sub getUnloadedTopicObject {
    my ( $this, $web, $topic ) = @_;

    ASSERT( defined $web );
    ASSERT( defined $topic );

    return Foswiki::Meta->new( $this->{session}, $web, $topic );
}

=begin TML

---++ ObjectMethod getWebObject($web) -> $webObject

Get an object representing a handle to a Foswiki =$web=

=cut

sub getWebObject {
    my ( $this, $web ) = @_;
    my $webObject;

    require Foswiki::Store;
    if ( defined &Foswiki::Store::create ) {

        # store2
        $webObject = Foswiki::Store->load( address => { web => $web } );
    }
    else {

        # pre-store2, Foswiki 1.1.x and below
        $webObject = Foswiki::Meta->new( $Foswiki::Plugins::SESSION, $web );
    }

    return $webObject;
}

# Override in subclasses to change the config on a per-testcase basis
sub loadExtraConfig {
    my $this    = shift;
    my $context = shift;
}

use Cwd;

# Use this to save the Foswiki cfg to a backing store during start_up
# so it can be temporarily changed during tests.
sub set_up {
    my $this = shift;

    $this->SUPER::set_up(@_);

    $this->{__EnvSafe} = {};
    foreach my $sym ( keys %ENV ) {
        next unless defined($sym);
        $this->{__EnvSafe}->{$sym} = $ENV{$sym};
    }

    # Tell the world we are running unit tests. Nasty, but needed to
    # avoid corruption of data spaces when unit tests are run alongside
    # a running wiki.
    $Foswiki::inUnitTestMode = 1;

    # This needs to be a deep copy
    $this->{__FoswikiSafe} =
      Data::Dumper->Dump( [ \%Foswiki::cfg ], ['*Foswiki::cfg'] );

    # Disable/enable plugins so that only core extensions (those defined
    # in lib/MANIFEST) are enabled, but they are *all* enabled.

    # First disable all plugins
    foreach my $k ( keys %{ $Foswiki::cfg{Plugins} } ) {
        next unless ref( $Foswiki::cfg{Plugins}{$k} ) eq 'HASH';
        $Foswiki::cfg{Plugins}{$k}{Enabled} = 0;
    }

    # then reenable only those listed in MANIFEST
    my $home = $ENV{FOSWIKI_HOME} || '../..';
    $home = '../..' unless -e "$ENV{FOSWIKI_HOME}/lib/MANIFEST";
    open( F, "$home/lib/MANIFEST" ) || die $!;
    my @moreConfig;
    local $/ = "\n";
    while (<F>) {
        if (/^!include .*?([^\/]+)\/([^\/]+)$/) {
            my ( $subdir, $extension ) = ( $1, $2 );
            chomp $extension;

            # Don't enable EmptyPlugin - Disabled by default
            if ( $extension =~ m/Plugin$/ && $extension ne 'EmptyPlugin' ) {
                unless ( exists $Foswiki::cfg{Plugins}{$extension}{Module} ) {
                    $Foswiki::cfg{Plugins}{$extension}{Module} =
                      'Foswiki::Plugins::' . $extension;
                    print STDERR "WARNING: $extension has no module defined, "
                      . "it might not load!\n"
                      . "\tGuessed it to $Foswiki::cfg{Plugins}{$extension}{Module}\n";
                }
                $Foswiki::cfg{Plugins}{$extension}{Enabled} = 1;
            }

            # Is there a Config.spec?
            if (
                open( G, "<",
                    "../../lib/Foswiki/$subdir/$extension/Config.spec"
                )
              )
            {
                local $/ = undef;
                my $config = <G>;
                close(G);

                # Add the config unless already defined in LocalSite.cfg
                $config =~
s/((\$Foswiki::cfg\{.*?\})\s*=.*?;)(?:\n|$)/push(@moreConfig, $1) unless (eval "exists $2"); ''/ges;
            }
        }
    }
    close(F);

    # Additional config picked up from plugins Config.spec's
    if ( scalar @moreConfig ) {
        unshift( @moreConfig, 'my $FALSE = 0; my $TRUE = 1;' );
        my $cmd = join( "\n", @moreConfig );

        #print STDERR $cmd; # Additional config from enabled extensions
        eval $cmd;
        die $@ if $@;
    }

    # Take a look at installed contribs and see if they demand any
    # additional setup.
    if ( opendir( F, "$home/lib/Foswiki/Contrib" ) ) {
        foreach my $d ( grep { /^[A-Za-z]+Contrib$/ } readdir(F) ) {
            next unless -e "$home/lib/Foswiki/Contrib/$d/UnitTestSetup.pm";
            my $setup = "Foswiki::Contrib::$d" . '::UnitTestSetup';
            $setup =~ m/^(.*)$/;    # untaint
            eval "require $1" || die $@;
            $setup->set_up();
        }
        closedir(F);
    }

    ASSERT( !defined $Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;

    my %tempDirOptions = ( CLEANUP => 1 );
    if ( $^O eq 'MSWin32' ) {

        #on windows, don't make a big old mess of c:\
        $ENV{TEMP} =~ m/(.*)/;
        $tempDirOptions{DIR} = $1;
    }
    $Foswiki::cfg{WorkingDir} = File::Temp::tempdir(%tempDirOptions);
    mkdir("$Foswiki::cfg{WorkingDir}/tmp");
    mkdir("$Foswiki::cfg{WorkingDir}/registration_approvals");
    mkdir("$Foswiki::cfg{WorkingDir}/work_areas");
    mkdir("$Foswiki::cfg{WorkingDir}/requestTmp");

    # Force completion of %Foswiki::cfg
    # This must be done before moving the logging.
    my $query = new Unit::Request();
    $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::PlainFile';
    my $tmp = new Foswiki( undef, $query );
    ASSERT( defined $Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;
    $tmp->finish();
    ASSERT( !defined $Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;

    # Note this does not do much, except for some tests that use it directly.
    # The first call to File::Temp caches the temp directory name, so
    # this value won't get used for anything created by File::Temp
    $Foswiki::cfg{TempfileDir} = "$Foswiki::cfg{WorkingDir}/requestTmp";

    # Move logging into a temporary directory
    my $logdir = Cwd::getcwd() . '/testlogs';
    $logdir =~ m/^(.*)$/;
    $logdir = $1;
    $Foswiki::cfg{Log}{Dir} = $logdir;
    mkdir($logdir) unless -d $logdir;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::Compatibility';
    $Foswiki::cfg{LogFileName}         = "$logdir/FoswikiTestCase.log";
    $Foswiki::cfg{WarningFileName}     = "$logdir/FoswikiTestCase.warn";
    $Foswiki::cfg{DebugFileName}       = "$logdir/FoswikiTestCase.debug";
    $Foswiki::cfg{AdminUserWikiName}   = 'AdminUser';
    $Foswiki::cfg{AdminUserLogin}      = 'root';
    $Foswiki::cfg{SuperAdminGroup}     = 'AdminGroup';

    # This must be done *after* disabling/enabling the plugins
    # so that tests derived from this class can enable additional plugins.
    # (Core plugins may be disabled, but their initPlugin method will still
    # have been called when the first Foswiki object was created, above.)
    $this->loadExtraConfig(@_);

    _onceOnlyChecks();

}

# Restores Foswiki::cfg and %ENV from backup
sub tear_down {
    my $this = shift;

    if ( $this->{session} ) {
        ASSERT( $this->{session}->isa('Foswiki') ) if SINGLE_SINGLETONS;
        $this->finishFoswikiSession();
    }
    eval { File::Path::rmtree( $Foswiki::cfg{WorkingDir} ); };
    %Foswiki::cfg = eval $this->{__FoswikiSafe};
    foreach my $sym ( keys %ENV ) {
        unless ( defined( $this->{__EnvSafe}->{$sym} ) ) {
            delete $ENV{$sym};
        }
        else {
            $ENV{$sym} = $this->{__EnvSafe}->{$sym};
        }
    }

    # Clear down non-default META types.
    foreach my $thing ( keys %$Foswiki::Meta::VALIDATE ) {
        delete $Foswiki::Meta::VALIDATE{$thing}
          unless $Foswiki::Meta::VALIDATE{$thing}->{_default};
    }
}

sub _copy {
    my $n = shift;

    return undef unless defined($n);

    if ( UNIVERSAL::isa( $n, 'ARRAY' ) ) {
        my @new;
        for ( 0 .. $#$n ) {
            push( @new, _copy( $n->[$_] ) );
        }
        return \@new;
    }
    elsif ( UNIVERSAL::isa( $n, 'HASH' ) ) {
        my %new;
        for ( keys %$n ) {
            $new{$_} = _copy( $n->{$_} );
        }
        return \%new;
    }
    elsif ( UNIVERSAL::isa( $n, 'REF' ) || UNIVERSAL::isa( $n, 'SCALAR' ) ) {
        $n = _copy($$n);
        return \$n;
    }
    elsif ( ref($n) eq 'Regexp' ) {
        return qr/$n/;
    }
    else {
        return $n;
    }
}

=begin TML

---++ ObjectMethod removeFromStore($web, $topic)

Remove =$web= from the store ( =$topic= not yet implemented)

=cut

sub removeFromStore {
    my ( $this, $web, $topic ) = @_;

    ASSERT( !defined $topic, '$topic not implemented' );
    $this->removeWebFixture( $this->{session}, $web );

    return;
}

=begin TML

---++ ObjectMethod removeWebFixture($session, $web)

Remove a temporary web fixture (data and pub)

=cut

sub removeWebFixture {
    my ( $this, $session, $web ) = @_;

    try {
        my $webObject = Foswiki::Meta->new( $session, $web );
        $webObject->removeFromStore();
    }
    otherwise {
        my $e = shift;
        print STDERR "Unexpected exception while removing web $web\n";
        print STDERR $e->stringify(), "\n" if $e;
    };
}

=begin TML

---++ ObjectMethod capture(\&fn, [,$session], ...) -> ($responseText, $result, $stdout, $stderr)

Like Unit::TestCase::captureSTD, except it captures the HTTP response
as well as STDOUT and STDERR.

$session can be passed in which case the response body will be taken from
that session; otherwise it will use $Foswiki::Plugins::SESSION.

$responseText includes HTTP headers.

$result is the result of the function.

=cut

sub capture {
    my ( $this, $fn, $session, @args ) = @_;

    # $fn may create a new Foswiki singleton, so it should take care to avoid
    # stomping on the existing one without $this->finishFoswikiSession() or
    # createNewFoswikiSession()
    my ( $stdout, $stderr, $result ) =
      $this->captureSTD( $fn, $session, @args );

    ASSERT( ref($session) || ref($Foswiki::Plugins::SESSION) );
    my $response =
      UNIVERSAL::isa( $session, 'Foswiki' )
      ? $session->{response}
      : $Foswiki::Plugins::SESSION->{response};

    my $responseText = '';
    if ( $response->outputHasStarted() ) {

        #we're streaming the output as we generate it
        #in 2010 (foswiki 1.1) this is used in the statistics script
        $responseText = $stdout;
    }
    else {

        # Capture headers
        require Foswiki::Engine;
        Foswiki::Engine->finalizeCookies($response);
        foreach my $header ( keys %{ $response->headers } ) {
            $responseText .= $header . ': ' . $_ . "\x0D\x0A"
              foreach $response->getHeader($header);
        }
        $responseText .= "\x0D\x0A";

        # Capture body
        $responseText .= $response->body() if $response->body();
    }

    return ( $responseText, $result, $stdout, $stderr );
}

=begin TML

---++ ObjectMethod captureWithKey(\&fn, [,$session], ...) -> ($responseText, $result, $stdout, $stderr)

Invoke capture with first setting a strikeone validation key
so it's authorized. First parameter is the action name,
rest is passed over to capture.

=cut

sub captureWithKey {
    my $this   = shift;
    my $action = shift;

    # Shortcut if user doesn't want validation
    return $this->capture(@_) if $Foswiki::cfg{Validation}{Method} eq 'none';

    # If we pass a Foswiki object to capture, use that
    # otherwise take $Foswiki::Plugins::SESSION
    # and we fallback to the one from the test object
    my $fatwilly;
    if ( UNIVERSAL::isa( $_[1], 'Foswiki' ) ) {
        $fatwilly = $_[1];
    }
    elsif ( UNIVERSAL::isa( $Foswiki::Plugins::SESSION, 'Foswiki' ) ) {
        $fatwilly = $Foswiki::Plugins::SESSION;
    }
    else {
        $fatwilly = $this->{twiki};
    }
    $this->assert( $fatwilly->isa('Foswiki'),
        "Could not find the Foswiki object" );

    # Now we have to manually craft the validation checkings
    require Foswiki::Validation;
    my $cgis = $fatwilly->getCGISession;
    my $strikeone = $Foswiki::cfg{Validation}{Method} eq 'strikeone';
    my $key =
      Foswiki::Validation::addValidationKey( $cgis, $action, $strikeone );
    unless (
        $key =~ qr/^<input .*name=['"](\w+)['"].*value=["']\??(.*)["'].*$/ )
    {
        $this->assert( 0, "Could not extract validation key from $key" );
    }
    my ( $k, $v ) = ( $1, $2 );
    my $request = $fatwilly->{request};
    $this->assert(
        (
                 $request->isa('Unit::Request')
              || $request->isa('Unit::Request::Attachment')
              || $request->isa('Unit::Request::Rest')
              || $request->isa('Unit::Request::JSON')
        ),
        "Could not find the Unit::Request object"
    );

    # As we won't be clicking using javascript, we have to fake that part too
    if ($strikeone) {
        require Digest::MD5;
        $v = Digest::MD5::md5_hex( $v, Foswiki::Validation::_getSecret($cgis) );
    }
    $request->param(
        -name  => $k,
        -value => $v
    );
    $request->method('POST');
    $this->capture(@_);
}

=begin TML

---++ ObjectMethod getUIFn($script) -> \&fn

Look up the $Foswiki::cfg{SwitchBoard} to get the UI function for a
specific script.

NOTE: there is NO POINT in checking the exit status from a capture
of one of these functions. It will just be some random string.

=cut

sub getUIFn {
    my $this   = shift;
    my $script = shift;
    require Foswiki::UI;
    $this->assert( $Foswiki::cfg{SwitchBoard}{$script}, $script );
    $this->assert( $Foswiki::cfg{SwitchBoard}{$script}->{package},
        "$script package not set" );
    my $fn = $Foswiki::cfg{SwitchBoard}{$script}->{package};
    eval "require $fn";
    die "DIED during (require $fn)\n" . $@ if $@;
    $this->assert( $Foswiki::cfg{SwitchBoard}{$script}->{function},
        "$script function not set" );
    $fn .= '::' . $Foswiki::cfg{SwitchBoard}{$script}->{function};
    return \&$fn;
}

=begin TML

---++ ObjectMethod createNewFoswikiSession(params) -> ref to new Foswiki obj

cleans up the existing Foswiki object, and creates a new one

params are passed directly to the new Foswiki() call

typically called to force a full re-initialisation either with new preferences, topics, users, groups or CFG

__DO NOT CALL session->finish() yourself__

=cut

sub createNewFoswikiSession {
    my ( $this, $user, $query, @args ) = @_;

    $this->{test_topicObject}->finish()           if $this->{test_topicObject};
    $this->{session}->finish()                    if $this->{session};
    ASSERT( !defined $Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;
    $Foswiki::cfg{Store}{Implementation} ||= 'Foswiki::Store::PlainFile';
    $this->{session} = Foswiki->new( $user, $query, @args );
    $this->{request} = $this->{session}{request};
    ASSERT( defined $Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;
    if ( $this->{test_web} && $this->{test_topic} ) {
        ( $this->{test_topicObject} ) =
          Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    }

    return $this->{session};
}

sub finishFoswikiSession {
    my ($this) = @_;

    $this->{session}->finish() if defined $this->{session};
    ASSERT( !$Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;
    $this->{session} = undef;

    return;
}

=begin TML

---++ ObjectMethod toSiteCharSet($s) -> $string

Encode in-file data into the site charset for passing to core functions
and checking results.

Test files using this function whether they 'use utf8' or not. in either
case, the string passed will be encoded into the correct representation for
the core.

Note that while it is only strictly necessary to call this on strings
that contain high-bit characters, for completeness and clean code it
should be called on *all* string constants used in tests.

=cut

sub toSiteCharSet {
    my ( $this, $string ) = @_;

    return $string unless $string;

    # Convert the string to unicode unambiguously
    my $unicode;
    if ( utf8::is_utf8($string) ) {

        # if the caller has 'use utf8' then strings passed in will already
        # be unicode, and the is_utf8 flag will be on.
        $unicode = $string;
    }
    else {
        # If the data is pure ASCII, then the encoding is unambiguous.
        # We have >=0x80 characters. We can assume that there are no
        # multi-byte characters in the string (because if there were, the
        # author would have turned 'use utf8' on, right?). In either case,
        # calling decode_utf8 is the right course of action (the only
        # encodings valid in test source files are utf8 and iso-8859-1)
        $unicode = Encode::decode_utf8($string);
    }

    return $unicode if $Foswiki::UNICODE;

    # If the site charset is not unicode, need to convert it
    return Encode::encode(
        $Foswiki::cfg{Site}{CharSet},
        $unicode,
        Encode::FB_CROAK    # should never happen
    );
}
1;
__DATA__

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2008-2015 Foswiki Contributors

Additional copyrights apply to some or all of the code in this file
as follows:

Copyright (C) 2007-2008 WikiRing, http://wikiring.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
