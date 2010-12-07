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
use Unit::TestCase;
our @ISA = qw( Unit::TestCase );

use Data::Dumper;

use Foswiki;
use Foswiki::Meta;
use Foswiki::Plugins;
use Unit::Request;
use Unit::Response;
use Error qw( :try );

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
      . "has to be able to create directories in $Foswiki::cfg{DataDir}";
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

# Override in subclasses to change the config on a per-testcase basis
sub loadExtraConfig {
    my $this = shift;
    my $context = shift;
}

use Cwd;

# Use this to save the Foswiki cfg to a backing store during start_up
# so it can be temporarily changed during tests.
sub set_up {
    my $this = shift;

    $this->SUPER::set_up(@_);

    $this->{__EnvSafe} = {};
    foreach my $sym (keys %ENV) {
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
    if ( $ENV{FOSWIKI_HOME} && -e "$ENV{FOSWIKI_HOME}/lib/MANIFEST" ) {
        open( F, "$ENV{FOSWIKI_HOME}/lib/MANIFEST" ) || die $!;
    }
    else {
        open( F, "../../lib/MANIFEST" ) || die $!;
    }
    local $/ = "\n";
    while (<F>) {
        if (/^!include .*?([^\/]+Plugin)$/) {
            # Don't enable EmptyPlugin - Disabled by default
            next if $1 eq 'EmptyPlugin';
            unless( exists $Foswiki::cfg{Plugins}{$1}{Module} ) {
                $Foswiki::cfg{Plugins}{$1}{Module} = 'Foswiki::Plugins::' . $1;
                print STDERR "WARNING: $1 has no module defined, "
                    ."it might not load!\n"
                    ."\tGuessed it to $Foswiki::cfg{Plugins}{$1}{Module}\n";
            }
            $Foswiki::cfg{Plugins}{$1}{Enabled} = 1;
        }
    }
    close(F);

    # Force completion of %Foswiki::cfg
    # This must be done before moving the logging.
    my $query = new Unit::Request();
    my $tmp = new Foswiki( undef, $query );
    $tmp->finish();

    my %tempDirOptions = (
        CLEANUP => 1
    );
    if ($^O eq 'MSWin32') {
        #on windows, don't make a big old mess of c:\
        $ENV{TEMP} =~ /(.*)/;
        $tempDirOptions{DIR} = $1;
    }
    $Foswiki::cfg{WorkingDir} = File::Temp::tempdir( %tempDirOptions );
    mkdir("$Foswiki::cfg{WorkingDir}/tmp");
    mkdir("$Foswiki::cfg{WorkingDir}/registration_approvals");
    mkdir("$Foswiki::cfg{WorkingDir}/work_areas");

    # Move logging into a temporary directory
    $Foswiki::cfg{LogFileName} =
      "$Foswiki::cfg{TempfileDir}/FoswikiTestCase.log";
    $Foswiki::cfg{WarningFileName} =
      "$Foswiki::cfg{TempfileDir}/FoswikiTestCase.warn";
    $Foswiki::cfg{AdminUserWikiName} = 'AdminUser';
    $Foswiki::cfg{AdminUserLogin}    = 'root';
    $Foswiki::cfg{SuperAdminGroup}   = 'AdminGroup';

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
    $this->{session}->finish() if $this->{session};
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
    foreach my $thing (keys %$Foswiki::Meta::VALIDATE) {
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
    my $this = shift;

    my ($stdout, $stderr, $result) = $this->captureSTD(@_);
    my $fn = shift;

    my $response  =
      UNIVERSAL::isa( $_[0], 'Foswiki' )
      ? $_[0]->{response}
      : $Foswiki::Plugins::SESSION->{response};

    my $responseText = '';
    if ($response->outputHasStarted()) {
        #we're streaming the output as we generate it
        #in 2010 (foswiki 1.1) this is used in the statistics script
        $responseText = $stdout;
    } else {
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
    

    return ($responseText, $result, $stdout, $stderr);
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
    $this->assert($Foswiki::cfg{SwitchBoard}{$script}->{package}, "$script package not set");
    my $fn = $Foswiki::cfg{SwitchBoard}{$script}->{package};
    eval "require $fn";
    die "DIED during (require $fn)\n".$@ if $@;
    $this->assert($Foswiki::cfg{SwitchBoard}{$script}->{function}, "$script function not set");
    $fn .= '::' . $Foswiki::cfg{SwitchBoard}{$script}->{function};
    return \&$fn;
}

1;
__DATA__

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2008-2010 Foswiki Contributors

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
