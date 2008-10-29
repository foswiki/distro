#
# Base class of all TWiki tests. Establishes base paths and adds
# some useful functionality such as comparing HTML
#
# The basic strategy in all unit tests is to never write to normal
# TWiki data areas; only ever write to temporary test areas. If you
# have to create a test fixture that duplicates an existing area,
# you can always create a new web based on that web.
#
package TWikiTestCase;
use base 'Unit::TestCase';

use Data::Dumper;

use TWiki;
use Unit::Request;
use Unit::Response;
use strict;
use Error qw( :try );

BEGIN {
    push( @INC, "$ENV{TWIKI_HOME}/lib" ) if defined($ENV{TWIKI_HOME});
    unshift @INC, '../../bin'; # SMELL: dodgy
    require 'setlib.cfg';
    $SIG{__DIE__} = sub { Carp::confess $_[0] };
};

our $didOnlyOnceChecks = 0;

# Temporary directory to store work files in (sessions, logs etc).
# Will be cleaned up after running the tests unless the environment
# variable TWIKI_DEBUG_KEEP is true
use File::Temp;
my $cleanup  =  $ENV{TWIKI_DEBUG_KEEP} ? 0 : 1;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

# Checks we only need to run once per test run
sub onceOnlyChecks {
    return if $didOnlyOnceChecks;

    # Make sure we can create directories in $TWiki::cfg{DataDir}, otherwise
    # the tests will mysteriously fail.
    my $t = "$TWiki::cfg{DataDir}/UnitTestCheckDir";
    if (-e $t) {
        rmdir($t) || die "Could not remove old $t: $!";
    }
    mkdir($t)
      || die "Could not create $t: $!\nUser running tests ".
        "has to be able to create directories in $TWiki::cfg{DataDir}";
    rmdir($t) || die "Could not remove $t: $!";

    # Make sure we can disallow write permissions. TWiki tests should
    # always be run as a non-admin user, so that they can test scenarios
    # where access permissions are denied.
    $t = "$TWiki::cfg{DataDir}/UnitTestCheckFile";
    if (-e $t) {
        unlink($t)
          || die "Could not remove old $t: $!";
    }
    open(F, '>', $t)
      || die "Could not create $t: $!\nUser running tests ".
        "has to be able to create files in $TWiki::cfg{DataDir}";
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
# Use this to save the TWiki cfg to a backing store during start_up
# so it can be temporarily changed during tests.
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{__EnvSafe} = {};
    foreach my $sym (%ENV) {
        next unless defined($sym);
        $this->{__EnvSafe}->{$sym} = $ENV{$sym};
    }

    # force a read of $TWiki::cfg
	my $query = new Unit::Request();
    my $tmp = new TWiki(undef, $query);
    # This needs to be a deep copy
    $this->{__TWikiSafe} = Data::Dumper->Dump([\%TWiki::cfg], ['*TWiki::cfg']);
    $tmp->finish();

    $TWiki::cfg{WorkingDir} = File::Temp::tempdir( CLEANUP => $cleanup );
    mkdir("$TWiki::cfg{WorkingDir}/tmp");
    mkdir("$TWiki::cfg{WorkingDir}/registration_approvals");
    mkdir("$TWiki::cfg{WorkingDir}/work_areas");

    # Move logging into a temporary directory
    $TWiki::cfg{LogFileName} = "$TWiki::cfg{TempfileDir}/TWikiTestCase.log";
    $TWiki::cfg{WarningFileName} = "$TWiki::cfg{TempfileDir}/TWikiTestCase.warn";
    $TWiki::cfg{AdminUserWikiName} = 'AdminUser';
    $TWiki::cfg{AdminUserLogin} = 'root';
    $TWiki::cfg{SuperAdminGroup} = 'AdminGroup';

    onceOnlyChecks();

    # Disable/enable plugins so that only core extensions (those defined
    # in lib/MANIFEST) are enabled, but they are *all* enabled.

    # First disable all plugins
    foreach my $k (keys %{$TWiki::cfg{Plugins}}) {
        $TWiki::cfg{Plugins}{$k}{Enabled} = 0;
    }
    # then reenable only those listed in MANIFEST
    if ($ENV{TWIKI_HOME} && -e "$ENV{TWIKI_HOME}/lib/MANIFEST") {
        open(F, "$ENV{TWIKI_HOME}/lib/MANIFEST") || die $!;
    } else {
        open(F, "../../lib/MANIFEST") || die $!;
    }
    local $/ = "\n";
    while (<F>) {
        if (/^!include .*?([^\/]+Plugin)$/) {
            $TWiki::cfg{Plugins}{$1}{Enabled} = 1;
        }
    }
    close(F);
}

# Restores TWiki::cfg and %ENV from backup
sub tear_down {
    my $this = shift;
    $this->{twiki}->finish() if $this->{twiki};
    eval {
	File::Path::rmtree($TWiki::cfg{WorkingDir});
    };
    %TWiki::cfg = eval $this->{__TWikiSafe};
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

1;
