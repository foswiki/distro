#
# Base class of all Foswiki tests. Establishes base paths and adds
# some useful functionality such as comparing HTML
#
# The basic strategy in all unit tests is to never write to normal
# Foswiki data areas; only ever write to temporary test areas. If you
# have to create a test fixture that duplicates an existing area,
# you can always create a new web based on that web.
#
package FoswikiTestCase;
use base 'Unit::TestCase';

use Data::Dumper;

use Foswiki;
use Unit::Request;
use Unit::Response;
use strict;
use Error qw( :try );

BEGIN {
    push( @INC, "$ENV{FOSWIKI_HOME}/lib" ) if defined($ENV{FOSWIKI_HOME});
    unshift @INC, '../../bin'; # SMELL: dodgy
    require 'setlib.cfg';
    $SIG{__DIE__} = sub { Carp::confess $_[0] };
};

our $didOnlyOnceChecks = 0;

# Temporary directory to store work files in (sessions, logs etc).
# Will be cleaned up after running the tests unless the environment
# variable FOSWIKI_DEBUG_KEEP is true
use File::Temp;
my $cleanup  =  $ENV{FOSWIKI_DEBUG_KEEP} ? 0 : 1;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

# Checks we only need to run once per test run
sub onceOnlyChecks {
    return if $didOnlyOnceChecks;

    # Make sure we can create directories in $Foswiki::cfg{DataDir}, otherwise
    # the tests will mysteriously fail.
    my $t = "$Foswiki::cfg{DataDir}/UnitTestCheckDir";
    if (-e $t) {
        rmdir($t) || die "Could not remove old $t: $!";
    }
    mkdir($t)
      || die "Could not create $t: $!\nUser running tests ".
        "has to be able to create directories in $Foswiki::cfg{DataDir}";
    rmdir($t) || die "Could not remove $t: $!";

    # Make sure we can disallow write permissions. Foswiki tests should
    # always be run as a non-admin user, so that they can test scenarios
    # where access permissions are denied.
    $t = "$Foswiki::cfg{DataDir}/UnitTestCheckFile";
    if (-e $t) {
        unlink($t)
          || die "Could not remove old $t: $!";
    }
    open(F, '>', $t)
      || die "Could not create $t: $!\nUser running tests ".
        "has to be able to create files in $Foswiki::cfg{DataDir}";
    print F "Blah";
    close(F);
    chmod(0444, $t)
      || die "Failed to change permissions on $t: $!\n User running tests ".
        "must be able to change permissions on files it creates.";
    if (open(F, '>', $t)) {
        close(F);
        unlink($t);
        die "Failed to protect a $t for write\nUser running tests ".
          "must be able to protect a file from write. ".
            "Perhaps you are running as the superuser?";
    }
    chmod(0777, $t)
      || die "Failed to change permissions on $t: $!\nUser running tests ".
        "must be able to change permissions on files it creates.";
    unlink($t) || die "Could not remove $t: $!";

    $didOnlyOnceChecks = 1;
}

use Cwd;
# Use this to save the Foswiki cfg to a backing store during start_up
# so it can be temporarily changed during tests.
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{__EnvSafe} = {};
    foreach my $sym (%ENV) {
        next unless defined($sym);
        $this->{__EnvSafe}->{$sym} = $ENV{$sym};
    }

    # force a read of $Foswiki::cfg
	my $query = new Unit::Request();
    my $tmp = new Foswiki(undef, $query);
    # This needs to be a deep copy
    $this->{__FoswikiSafe} = Data::Dumper->Dump([\%Foswiki::cfg], ['*Foswiki::cfg']);
    $tmp->finish();

    $Foswiki::cfg{WorkingDir} = File::Temp::tempdir( CLEANUP => $cleanup );
    mkdir("$Foswiki::cfg{WorkingDir}/tmp");
    mkdir("$Foswiki::cfg{WorkingDir}/registration_approvals");
    mkdir("$Foswiki::cfg{WorkingDir}/work_areas");

    # Move logging into a temporary directory
    $Foswiki::cfg{LogFileName} = "$Foswiki::cfg{TempfileDir}/FoswikiTestCase.log";
    $Foswiki::cfg{WarningFileName} = "$Foswiki::cfg{TempfileDir}/FoswikiTestCase.warn";
    $Foswiki::cfg{AdminUserWikiName} = 'AdminUser';
    $Foswiki::cfg{AdminUserLogin} = 'root';
    $Foswiki::cfg{SuperAdminGroup} = 'AdminGroup';

    onceOnlyChecks();

    # Disable/enable plugins so that only core extensions (those defined
    # in lib/MANIFEST) are enabled, but they are *all* enabled.

    # First disable all plugins
    foreach my $k (keys %{$Foswiki::cfg{Plugins}}) {
        next unless ref($Foswiki::cfg{Plugins}{$k}) eq 'HASH';
        $Foswiki::cfg{Plugins}{$k}{Enabled} = 0;
    }
    # then reenable only those listed in MANIFEST
    if ($ENV{FOSWIKI_HOME} && -e "$ENV{FOSWIKI_HOME}/lib/MANIFEST") {
        open(F, "$ENV{FOSWIKI_HOME}/lib/MANIFEST") || die $!;
    } else {
        open(F, "../../lib/MANIFEST") || die $!;
    }
    local $/ = "\n";
    while (<F>) {
        if (/^!include .*?([^\/]+Plugin)$/) {
            $Foswiki::cfg{Plugins}{$1}{Enabled} = 1;
        }
    }
    close(F);
}

# Restores Foswiki::cfg and %ENV from backup
sub tear_down {
    my $this = shift;
    $this->{twiki}->finish() if $this->{twiki};
    eval {
	File::Path::rmtree($Foswiki::cfg{WorkingDir});
    };
    %Foswiki::cfg = eval $this->{__FoswikiSafe};
    foreach my $sym (keys %ENV) {
        unless( defined( $this->{__EnvSafe}->{$sym} )) {
            delete $ENV{$sym};
        } else {
            $ENV{$sym} = $this->{__EnvSafe}->{$sym};
        }
    }
}

sub _copy {
    my $n = shift;

    return undef unless defined( $n );

    if (UNIVERSAL::isa($n, 'ARRAY')) {
        my @new;
        for ( 0..$#$n ) {
            push(@new, _copy( $n->[$_] ));
        }
        return \@new;
    }
    elsif (UNIVERSAL::isa($n, 'HASH')) {
        my %new;
        for ( keys %$n ) {
            $new{$_} = _copy( $n->{$_} );
        }
        return \%new;
    }
    elsif (UNIVERSAL::isa($n, 'REF') || UNIVERSAL::isa($n, 'SCALAR')) {
        $n = _copy($$n);
        return \$n;
    }
    elsif (ref($n) eq 'Regexp') {
        return qr/$n/;
    }
    else {
        return $n;
    }
}

sub removeWebFixture {
    my( $this, $twiki, $web ) = @_;

    try {
        $twiki->{store}->removeWeb($twiki->{user}, $web);
    } otherwise {
        my $e = shift;
        print STDERR "Unexpected exception while removing web $web\n";
        print STDERR $e->stringify(),"\n" if $e;
    };
}

# invoke capture with first setting a key
# so it's authorized. First parameter is the action name,
# rest is passed over to capture
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
    $this->assert( $request->isa('Unit::Request'),
        "Could not find the Unit::Request object" );

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

1;
