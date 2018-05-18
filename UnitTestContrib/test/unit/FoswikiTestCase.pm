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

use Assert;

use Data::Dumper;
use Scalar::Util qw(blessed);

require Digest::MD5;
require Foswiki::Validation;

use Foswiki          ();
use Foswiki::Meta    ();
use Foswiki::Plugins ();
use Foswiki::Store   ();

#use Unit::Response();
use Try::Tiny;
use Storable ();

use constant SINGLE_SINGLETONS => 0;
use constant TRACE             => 0;

# Temporary directory to store work files in (sessions, logs etc).
# Will be cleaned up after running the tests unless the environment
# variable FOSWIKI_DEBUG_KEEP is true
use File::Temp;
my $cleanup = $ENV{FOSWIKI_DEBUG_KEEP} ? 0 : 1;

our $didOnlyOnceChecks = 0;

use Foswiki::Class -types;
extends qw(Unit::TestCase);
with qw(Foswiki::Util::Localize Unit::FoswikiTestRole);

#has twiki =>
#  ( is => 'rw', clearer => 1, lazy => 1, default => sub { $_[0]->app }, );
has test_topicObject => (
    is        => 'rw',
    clearer   => 1,
    predicate => 1,
    isa       => Maybe [ InstanceOf ['Foswiki::Meta'] ],

    # For compatibility with Foswiki::Func::readTopic we accept arrayref and
    # fetch it's first element if it is a Foswiki::Meta object but only if it
    # totaling of two elems.
    coerce => sub {
        return
             defined $_[0]
          && ref( $_[0] ) eq 'ARRAY'
          && $#{ $_[0] } == 2
          && defined( $_[0]->[0] )
          && $_[0]->[0]->isa('Foswiki::Meta') ? $_[0]->[0] : $_[0];
    },
);
has request => (
    is       => 'rw',
    weak_ref => 1,
    lazy     => 1,
    default  => sub {
        $_[0]->app->request;
    },
    clearer => 1,
    isa     => InstanceOf ['Foswiki::Request'],
);

BEGIN {

# SMELL: These were tainting @INC,   TestRunner.pl already adds these to the path
#        Tests still seem to run without them being added here.
#push( @INC, "$ENV{FOSWIKI_HOME}/lib" ) if defined( $ENV{FOSWIKI_HOME} );
#unshift @INC, '../../bin';    # SMELL: dodgy
#    require 'setlib.cfg';
#$SIG{__DIE__} = sub { Carp::confess $_[0] };
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
                my $verify_name = $this->verify_permutations->{$test};

                if ( defined $item->{tests}->{$test} ) {
                    $skip_reason = $item->{tests}->{$test};
                }
                elsif ( $verify_name && defined $item->{tests}->{$verify_name} )
                {
                    $skip_reason = $item->{tests}->{$verify_name};
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
    my $this = shift;
    return if $didOnlyOnceChecks;

    my $cfgData = $this->app->cfg->data;

    # Make sure we can create directories in $Foswiki::cfg{DataDir}, otherwise
    # the tests will mysteriously fail.
    my $t = $cfgData->{DataDir} . "/UnitTestCheckDir";
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
    $t = $cfgData->{DataDir} . "/UnitTestCheckFile";
    if ( -e $t ) {
        unlink($t)
          || die "Could not remove old $t: $!";
    }
    open( F, '>', $t )
      || die "Could not create $t: $!\nUser running tests "
      . "has to be able to create files in "
      . $cfgData->{DataDir};
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

    # Many tests don't have a $app data member.
    #return (
    #    $this->has_app
    #    ? $this->app->inContext( $plugin . 'Enabled' )
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
        Foswiki::load_package('Foswiki::Configure::Dependency');
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
            $this->expecting_failure($reason);
        }
    }
    else {
        $this->expecting_failure($reason);
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

    # SMELL It seems like create method was supposed to be a part of new
    # Foswiki::Store (so called 'Store 2') semantics which actually wasn't
    # developed after all. For now it conflicts with Foswiki::Object create
    # method and has to be avoided.
    if ( 0 && defined &Foswiki::Store::create ) {

        # store2
        $webObject = Foswiki::Store->create( address => { web => $web } );
    }
    else {

        # pre-store2, Foswiki 1.1.x and below
        $webObject = $this->create( 'Foswiki::Meta', web => $web );
    }
    $webObject->populateNewWeb( $template, $opts );
    return $webObject;
}

=begin TML

---++ ObjectMethod getUnloadedTopicObject($web, $topic) -> $topicObject

Get an unloaded topic object.

Equivalent to Foswiki::Meta->new, we take the app from $this->app.

That assumes all the tests are playing nice, and aren't doing Unit::TestApp->new()
themselves (using createNewFoswikiApp instead).

=cut

sub getUnloadedTopicObject {
    my ( $this, $web, $topic ) = @_;

    ASSERT( defined $web );
    ASSERT( defined $topic );

    return $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
}

=begin TML

---++ ObjectMethod getWebObject($web) -> $webObject

Get an object representing a handle to a Foswiki =$web=

=cut

sub getWebObject {
    my ( $this, $web ) = @_;
    my $webObject;

    # SMELL It seems like create method was supposed to be a part of new
    # Foswiki::Store (so called 'Store 2') semantics which actually wasn't
    # developed after all. For now it conflicts with Foswiki::Object create
    # method and has to be avoided.
    if ( 0 && Foswiki::Store->can('create') ) {

        # store2
        $webObject = Foswiki::Store->load( address => { web => $web } );
    }
    else {

        # pre-store2, Foswiki 1.1.x and below
        $webObject = $this->create( 'Foswiki::Meta', web => $web );
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
around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );
    my $cfgData = $this->app->cfg->data;

    # Tell the world we are running unit tests. Nasty, but needed to
    # avoid corruption of data spaces when unit tests are run alongside
    # a running wiki.
    $Foswiki::inUnitTestMode = 1;

    # This is about both config and %ENV
    $this->preserveEnvironment;

    $this->setupPlugins;

    ASSERT( !defined $Foswiki::app ) if SINGLE_SINGLETONS;

    # Force completion of %Foswiki::cfg
    # This must be done before moving the logging.
    $cfgData->{Store}{Implementation} = 'Foswiki::Store::PlainFile';

    $this->setupDirs;

    $this->setupAdminUser;

    # The unit tests really need CGI sessions or captureWithKey fails
    $cfgData->{Sessions}{EnableGuestSessions} = 1;

    # This must be done *after* disabling/enabling the plugins
    # so that tests derived from this class can enable additional plugins.
    # (Core plugins may be disabled, but their initPlugin method will still
    # have been called when the first Foswiki object was created, above.)
    $this->loadExtraConfig(@_);

    $this->_onceOnlyChecks();

};

# Restores Foswiki::cfg and %ENV from backup
around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    $this->_clear_tempDir;

    $this->restoreEnvironment;

    # Clear down non-default META types.
    foreach my $thing ( keys %$Foswiki::Meta::VALIDATE ) {
        delete $Foswiki::Meta::VALIDATE{$thing}
          unless $Foswiki::Meta::VALIDATE{$thing}->{_default};
    }

    if ( $this->has_app ) {
        ASSERT( $this->app->isa('Unit::TestApp') ) if SINGLE_SINGLETONS;
        $this->finishFoswikiSession;
    }
};

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
    $this->removeWebFixture($web);

    return;
}

=begin TML

---++ ObjectMethod removeWebFixture($web)

Remove a temporary web fixture (data and pub)

=cut

sub removeWebFixture {
    my ( $this, $web ) = @_;

    ASSERT( !ref( $_[1] ), "Non-OO call to removeWebFixture" );

    try {
        my $webObject = $this->create( 'Foswiki::Meta', web => $web );
        $webObject->removeFromStore();
    }
    catch {
        say STDERR "Unexpected exception while removing web $web";
        say STDERR Foswiki::Exception::errorStr($_);
    };
}

=begin TML

---++ ObjectMethod capture(\&fn, [,$app], ...) -> ($responseText, $result, $stdout, $stderr)

Like Unit::TestCase::captureSTD, except it captures the HTTP response
as well as STDOUT and STDERR.

$app can be passed in which case the response body will be taken from
that app; otherwise it will use $Foswiki::app.

$responseText includes HTTP headers.

$result is the result of the function.

=cut

sub capture {
    my ( $this, $fn, @args ) = @_;

    # $fn may create a new Foswiki singleton, so it should take care to avoid
    # stomping on the existing one without $this->finishFoswikiSession() or
    # createNewFoswikiApp()
    my ( $stdout, $stderr, $result ) = $this->captureSTD( $fn, @args );

    my $app      = $this->app;
    my $response = $app->response;
    my $engine   = $app->engine;

    my $psgiMode = !$engine->isa('Engine::Test') || $engine->simulate eq 'psgi';

    my $responseText = '';
    if ( !$psgiMode && $response->outputHasStarted ) {

        #we're streaming the output as we generate it
        #in 2010 (foswiki 1.1) this is used in the statistics script
        $responseText = $stdout;
    }
    else {

        # Capture headers
        my $return = $response->as_array;

        # Put back Status header which is expected by a number of tests.
        push @{ $return->[1] }, 'Status' => $return->[0];
        $responseText = $engine->stringifyHeaders($return);

        # Capture body
        $responseText .= join( '', @{ $return->[2] } );
    }

    return ( $responseText, $result, $stdout, $stderr );
}

sub _generateValidation {
    my $this = shift;
    my ($action) = @_;

    my $app = $this->app;

    $this->assert( $app->isa('Unit::TestApp'),
        "Could not find the Foswiki object" );

    my $req = $app->request;
    my $cfg = $app->cfg;

    # Now we have to manually craft the validation checkings
    my $cgis = $app->users->getCGISession;
    my $strikeone = $cfg->data->{Validation}{Method} eq 'strikeone';
    my $key =
      Foswiki::Validation::addValidationKey( $cgis, $action, $strikeone );
    unless (
        $key =~ qr/^<input .*name=['"](\w+)['"].*value=["']\??(.*)["'].*$/ )
    {
        $this->assert( 0, "Could not extract validation key from $key" );
    }
    my ( $k, $v ) = ( $1, $2 );
    $this->assert( $req->isa('Foswiki::Request'),
        "Could not find the Foswiki::Request object" );

    # As we won't be clicking using javascript, we have to fake that part too
    if ($strikeone) {
        $v = Digest::MD5::md5_hex( $v, Foswiki::Validation::_getSecret($cgis) );
    }
    $req->param(
        -name  => $k,
        -value => $v
    );
    $req->method('POST');
}

=begin TML

---++ ObjectMethod captureWithKey(\&fn, [,$app], ...) -> ($responseText, $result, $stdout, $stderr)

Invoke capture with first setting a strikeone validation key
so it's authorized. First parameter is the action name,
rest is passed over to capture.

=cut

sub captureWithKey {
    my $this   = shift;
    my $action = shift;

    # Shortcut if user doesn't want validation
    return $this->capture(@_)
      if $this->app->cfg->data->{Validation}{Method} eq 'none';

    $this->_generateValidation($action);
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
    my $cfg = $this->app->cfg;
    $this->assert( $cfg->data->{SwitchBoard}{$script}, $script );
    $this->assert( $cfg->data->{SwitchBoard}{$script}->{package},
        "$script package not set" );
    my $fn = $cfg->data->{SwitchBoard}{$script}->{package};
    Foswiki::load_package( $fn,
        method => $cfg->data->{SwitchBoard}{$script}->{function}, );

    #eval "require $fn";
    #die "DIED during (require $fn)\n" . $@ if $@;
    $this->assert( $cfg->data->{SwitchBoard}{$script}->{function},
        "$script function not set" );
    $fn .= '::' . $cfg->data->{SwitchBoard}{$script}->{function};
    return \&$fn;
}

=begin TML

---++ ObjectMethod reCreateFoswikiApp

Creates a new app object using currently active one as the template.

=cut

sub reCreateFoswikiApp {
    my $this = shift;

    my $app    = $this->app;
    my $req    = $app->request;
    my $engine = $app->engine;

    # SMELL This is incomplete set of parameters to be set. Would be extended as
    # needed.
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => (
                defined $req->_initializer
                ? $req->_initializer
                : ''
            ),
        },
        engineParams => {
            simulate          => $engine->simulate,
            initialAttributes => {
                path_info => $req->pathInfo,
                method    => $req->method,
                action    => $req->action,
            },
        },
        @_
    );
}

sub finishFoswikiSession {
    my ($this) = @_;

    #use Devel::Refcount;
    #say STDERR "app refcount: ", Devel::Refcount::refcount($this->app);
    $this->clear_app;
    undef $Foswiki::app if $Foswiki::app;
    ASSERT( !$Foswiki::app ) if SINGLE_SINGLETONS;

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

sub setLocalizableAttributes {
    return qw(app twiki test_topicObject);
}

around setLocalizeFlags => sub {
    my $orig = shift;

    # Don't clean app on localizing as we might need it until the new one is
    # created.
    return $orig->(@_), clearAttributes => 0;
};

around createNewFoswikiApp => sub {
    my $orig = shift;
    my $this = shift;

    $this->clear_test_topicObject;
    $this->clear_request;

    my $newApp = $orig->( $this, @_ );

    if ( $this->test_web && $this->test_topic ) {
        $this->test_topicObject(
            ( $newApp->readTopic( $this->test_web, $this->test_topic ) )[0] );
    }

    return $newApp;
};

1;
__END__

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2008-2017 Foswiki Contributors

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
