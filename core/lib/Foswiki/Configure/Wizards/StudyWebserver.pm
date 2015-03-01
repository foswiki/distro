# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::StudyWebserver;

=begin TML

---++ package Foswiki::Configure::Wizards::StudyWebserver

=cut

use strict;
use warnings;

use CGI        ();
use FindBin    ();
use File::Spec ();
use JSON       ();

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

use Foswiki::Net ();

our $inc_rubric =
'@INC library path _This is the Perl library path, used to load Foswiki modules, third-party modules used by some plugins, and Perl built-in modules_ ';

=begin TML

---++ WIZARD report

Analyse and report on webserver.

=cut

sub report {
    my ( $this, $reporter ) = @_;

    $reporter->NOTE('---+ Environment Variables');

    # Check the execution environment

    my $XENV = $this->_getScriptENV($reporter);

    my $uid = getlogin() || getpwuid($>);

    my @groups;
    eval {
        @groups = map { lc( getgrgid($_) ) } split( ' ', $( );
    };
    if ($@) {

        # Try to use Cygwin's 'id' command - may be on the path,
        # since Cygwin is probably installed to supply ls, egrep,
        # etc - if it isn't, give up. Run command without stderr
        # output, to avoid CGI giving error.
        # Get names of primary and other groups.
        # This is down here because it takes 30s to run on
        # Strawberry perl!
        @groups =
          ( lc( qx(sh -c '( id -un ; id -gn) 2>/dev/null' 2>nul ) || 'n/a' ) );
    }

    if ( !$XENV ) {
        $reporter->WARN(
"Unable to query execution environment. The following analysis only reflects the configure environment."
        );
        $reporter->NOTE('| *Variable* | *Configure* |');
        for my $key ( sort keys %ENV ) {
            my $value   = $ENV{$key};
            my $decoded = '';
            if ( $key eq 'HTTP_COOKIE' && $value ) {

                # url decode for readability
                $value =~ s/%7C/ | /g;
                $value =~ s/%3D/=/g;
                $decoded = ' _Cookie string decoded for readability_ ';
            }
            $value =~ s/\n/\\n/g;
            $reporter->NOTE("| $key | $value$decoded |");
        }

        $reporter->NOTE('---+ General Environment');

        # Report the Umask
        my $pUmask = sprintf( '%03o', umask() );
        $reporter->NOTE("| UMASK | $pUmask |");

        my $ipath = join( ' ', @INC );
        $reporter->NOTE("| $inc_rubric | $ipath |");

        my $user =
            'userid: '
          . ( $uid ? "*$uid*" : 'unknown' )
          . ' groups: *'
          . join( ', ', @groups ) . '*';
        $reporter->NOTE(
            "| User _Your scripts are executing as this user_ | $user |");
    }
    else {
        $reporter->NOTE('| *Variable* | *Execution* | *Configure* |');
        _compareHashes( $reporter, $XENV->{ENV}, \%ENV );

        $reporter->NOTE('---+ General Environment');

        $reporter->NOTE('| | *Execution* | *Configure* |');

        # Report the Umask
        my $cUmask = sprintf( '%03o', umask );
        my $xUmask = sprintf( '%03o', $XENV->{umask} || 0 );
        _compareHashes( $reporter, { UMASK => $xUmask }, { UMASK => $cUmask } );

        # Perl @INC (lib path)
        _compareHashes(
            $reporter,
            { $inc_rubric => join( " ", @{ $XENV->{'@INC'} } ) },
            { $inc_rubric => join( " ", @INC ) },
        );

        my $user =
            'userid: '
          . ( $uid ? "*$uid*" : 'unknown' )
          . ' groups: *'
          . join( ', ', @groups ) . '*';

        my $xuser =
            'userid: '
          . ( $XENV->{uid} ? "*$XENV->{uid}*" : 'unknown' )
          . ' groups: *'
          . join( ', ', @{ $XENV->{groups} } ) . '*';

        my $rubric =
          'Webserver user _Your CGI scripts are executing as this user_';
        _compareHashes( $reporter, { $rubric => $user },
            { $rubric => $xuser } );
    }

    # Check for writable install root.  This used to be (incorrectly)
    # associated with DOCUMENT_ROOT.
    # Some misbehaved extensions (GENPDFAddOn is one) drop files in
    # the install root.
    # UI.pm (now) computes the foswiki root the same way.

    $FindBin::Bin =~ m/(.*)/;
    my $bin = $1;

    # In early initialization, we don't yet have LSC, so we will look there.
    # Probably the only way to have everything work is to insist on symlinks
    # from a root directory.

    my $dataDir = $Foswiki::cfg{DataDir};
    my $binDir  = $this->{bin};
    my @roots;
    foreach my $root ( $dataDir, $binDir ) {
        next unless ($root);
        my @root = File::Spec->splitdir($root);
        pop(@root);

        # SMELL: Force a trailing separator - Linux and Windows are inconsistent

        $root = File::Spec->catfile( @root, 'x' );
        chop $root;
        push @roots, $root;
    }

    if (   @roots >= 2
        && $roots[0] ne $roots[1] )
    {
        my $dd = Cwd::abs_path( $roots[0] ) || 'undef';
        my $bd = Cwd::abs_path( $roots[1] ) || 'undef';
        if ( $dd ne $bd ) {
            $reporter->WARN(
"{DataDir} => $roots[0] ($dd) vs. {ScriptDir} => $roots[1] ($bd)"
            );
        }
    }

    my $root = $roots[0];

    $reporter->NOTE( '| Foswiki root directory | '
          . join( '', $root =~ m,^(.*?)[\\/\]>]$, )
          . '|' );

    unless ( -w $root ) {
        $reporter->WARN(<<HERE);
The Foswiki root directory $root is not writable.  This can cause issues when installing some extensions that write files into the server root. Writing to the server root is deprecated, so this may not be an immediate concern.
HERE
    }

    # Detect whether mod_perl was loaded into Apache
    # This won't work is most places because ServerTokens defaults to OS or less
    # in current distributions.

    $Foswiki::cfg{DETECTED}{ModPerlLoaded} =
      ( exists $ENV{SERVER_SOFTWARE}
          && ( $ENV{SERVER_SOFTWARE} =~ m/mod_perl/ ) )
      || ( exists $XENV->{ENV}->{SERVER_SOFTWARE}
        && ( $XENV->{ENV}->{SERVER_SOFTWARE} =~ m/mod_perl/ ) );

    # Detect whether we are actually running under mod_perl
    # - test for MOD_PERL alone, which is enough.
    $Foswiki::cfg{DETECTED}{UsingModPerl} = exists $ENV{MOD_PERL};

    $Foswiki::cfg{DETECTED}{ModPerlVersion} =
      eval('use mod_perl2; return $mod_perl2::VERSION');
    $Foswiki::cfg{DETECTED}{ModPerlVersion} =
      eval('use mod_perl; return $mod_perl::VERSION')
      if ($@);

    # Get the version of mod_perl if it's being used
    if ( $Foswiki::cfg{DETECTED}{UsingModPerl} ) {
        $reporter->WARN(<<HERE);
You are running =configure= with =mod_perl=. This
is risky because mod_perl will remember old values of configuration
variables. You are *highly* recommended not to run configure under
mod_perl (though the rest of Foswiki can be run with mod_perl)
HERE
    }

    my $cgiver = $CGI::VERSION || '';
    if ( $cgiver =~ m/^(2\.89|3\.37|3\.43|3\.47)$/ ) {
        $reporter->WARN( <<HERE );
You are using a version of \$CGI that is known to have issues with Foswiki.
CGI should be upgraded to a version > 3.11, avoiding 3.37, 3.43, and 3.47.
HERE
    }

    # Check for potential CGI.pm module upgrade
    # CGI.pm version, on some platforms - actually need CGI 2.93 for
    # mod_perl 2.0 and CGI 2.90 for Cygwin Perl 5.8.0.  See
    # http://perl.apache.org/products/apache-modules.html#
    #       Porting_CPAN_modules_to_mod_perl_2_0_Status
    if ( $CGI::VERSION < 2.93 ) {
        if ( $Config::Config{osname} eq 'cygwin' && $] >= 5.008 ) {

            # Recommend CGI.pm upgrade if using Cygwin Perl 5.8.0
            $reporter->WARN( <<HERE );
Perl CGI version 3.11 or higher is recommended to avoid problems with
attachment uploads on Cygwin Perl.
HERE
        }
        elsif ($Foswiki::cfg{DETECTED}{ModPerlVersion}
            && $Foswiki::cfg{DETECTED}{ModPerlVersion} >= 1.99 )
        {

            # Recommend CGI.pm upgrade if using mod_perl 2.0, which
            # is reported as version 1.99 and implies Apache 2.0
            $reporter->WARN( <<HERE );
Perl CGI version 3.11 or higher is recommended to avoid problems with
mod_perl.
HERE
        }
    }

    #OS
    my $n =
        ucfirst( lc( $Config::Config{osname} ) ) . ' '
      . $Config::Config{osvers} . ' ('
      . $Config::Config{archname} . ')';
    $reporter->NOTE("| Operating system | $n |");

    # Perl version and type
    if ( $] =~ m/^(\d+)\.(\d{3})(\d{3})$/ ) {
        $n = sprintf( "%d.%d.%d", $1, $2, $3 );
    }
    else {
        $n = $];
    }
    $n .= " ($Config::Config{osname})";

    if ( $] < 5.008 ) {
        $reporter->WARN(<<HERE);
Perl version is older than 5.8.0. Recommended version 5.8.4 or later.
Foswiki is tested on Perl 5.8.X and 5.10.X.  Older versions may
work, but you may need to upgrade Perl libraries and tweak the
Foswiki code.
HERE
    }

    $reporter->NOTE("| Perl version | $n |");

    $reporter->NOTE( "| CGI bin directory | " . $this->_getBinDir() . '|' );

    # mod_perl
    my $mpUsed = $Foswiki::cfg{DETECTED}{UsingModPerl}
      || exists $XENV->{ENV}->{MOD_PERL};

    if ( $Foswiki::cfg{DETECTED}{ModPerlVersion} ) {
        if ( $Foswiki::cfg{DETECTED}{ModPerlVersion} =~
            m/^(\d+)\.(\d{3})(\d{3})$/ )
        {
            $n = sprintf( "%d.%d.%d", $1, $2, $3 );
        }
        else {
            $n = $Foswiki::cfg{DETECTED}{ModPerlVersion};
        }
        $n = "version $n is installed";
    }
    else {
        $n = "not detected";
    }

    if ( !$Foswiki::cfg{DETECTED}{ModPerlLoaded}
        && ( $Foswiki::cfg{DETECTED}{ModPerlVersion} || $mpUsed ) )
    {
        $reporter->WARN(
'mod_perl may not be loaded into the webserver. It is not reported as present in the SERVER_SOFTWARE environment variable, but this is not definitive because the ServerTokens directive often is used to suppress this information.'
        );
    }

    $reporter->NOTE("| mod_perl installation | $n |");

    # Check for a broken version of mod_perl 2.0
    if ( $mpUsed && $Foswiki::cfg{DETECTED}{ModPerlVersion} =~ m/1\.99_?11/ ) {

        # Recommend mod_perl upgrade if using a mod_perl 2.0 version
        # with PATH_INFO bug (see Support.RegistryCookerBadFileDescriptor
        # and Bugs:Item82)
        $reporter->ERROR(<<HERE);
Version $Foswiki::cfg{DETECTED}{ModPerlVersion} of mod_perl is known to have major bugs that prevent its use with Foswiki. 1.99_12 or higher is recommended.
HERE
    }

    if ( $Foswiki::cfg{DETECTED}{UsingModPerl} ) {
        $reporter->WARN("mod_perl is used for this script - it should not be");
    }
    elsif ($XENV) {
        if ( exists $XENV->{ENV}->{MOD_PERL} ) {
            $n = 'Yes, in the script execution environment';
        }
        else {
            $n = 'No';
        }
    }
    else {
        $n = 'unable to determine';
        $reporter->WARN(<<BADXENV);
I could not see your execution environment to test for mod_perl. Please re-run this analysis once the problem preventing configure from querying the execution environment is resolved.
BADXENV
    }
    $reporter->NOTE("| mod_perl enabled? | $n (Only =jsonrpc= is tested) |");
    return undef;
}

sub _compareHashes {
    my ( $reporter, $execution, $configure ) = @_;

    my $content = '';

    my %keys = map { $_ => 1 } ( keys %$configure, keys %$execution );

    foreach my $key ( sort keys %keys ) {

        my ( $c_val, $e_val ) = ( $configure->{$key}, $execution->{$key} );
        if ( $key eq 'HTTP_COOKIE' ) {
            foreach ( $c_val, $e_val ) {
                next unless ( defined $_ );

                # url decode for readability
                s/%7C/ | /g;
                s/%3D/=/g;
                $_ .= ' _Cookie string decoded for readability_ ';
            }
        }
        foreach ( $c_val, $e_val ) {
            $_ = '_undefined_' unless ( defined $_ );
            $_ =~ s/\n/\\n/g;
        }
        $c_val ||= '';
        $e_val ||= '';
        $reporter->NOTE("| $key | $e_val | $c_val |");
    }
}

# Return %XENV = env from the script execution environment
# We perform JSON RPC back to this wizard in order to get this
# information. This may seem circular, but remember that the current
# instance may be running from the command line. We're checking what
# the *remote* server has to say for itself.
#
# REQUIRES ConfigurePlugin

sub _getScriptENV {
    my ( $this, $reporter ) = @_;

    my @pars = (
        -name    => 'FOSWIKI_CONFIGURATION',
        -value   => time,
        -path    => '/',
        -expires => "+1h"
    );
    push @pars, -secure => 1 if ( $ENV{HTTPS} && $ENV{HTTPS} eq 'on' );
    my $cookie = CGI->cookie(@pars);
    local $Foswiki::VERSION = "CONFIGURATION";
    my $net = Foswiki::Net->new;

    my $url =
        $Foswiki::cfg{DefaultUrlHost}
      . $Foswiki::cfg{ScriptUrlPath}
      . '/jsonrpc'
      . ( $Foswiki::cfg{ScriptSuffix} || '' )
      . '/configure';

    my ( $limit, $try ) = (10);
    my %headers = (
        Cookie         => join( '=', $cookie->name, $cookie->value ),
        'Content-type' => 'application/json'
    );

    my $user = $this->param('cfgusername');

    my $password = $this->param('cfgpassword');
    if ($user) {
        require MIME::Base64;
        my $auth = MIME::Base64::encode_base64( "$user:$password", '' );
        $headers{Authorization} = "Basic $auth";
    }

    my $data = {
        jsonrpc => '2.0',
        id      => 'configurationTest' . time(),
        method  => 'wizard',
        params  => {
            wizard => 'StudyWebserver',
            method => 'request_environment'
        }
    };

    for ( $try = 1 ; $try <= $limit ; $try++ ) {
        my $response = $net->getExternalResource(
            $url,
            headers => \%headers,
            method  => 'POST',
            content => JSON->new->encode($data)
        );
        if ( $response->is_error ) {
            my $content = $response->content || '';
            $content =~ s/<([^>]*)>/&lt;$1&gt;/g;
            $reporter->ERROR(
                "Failed to access =$url= "
                  . $response->code . ' '
                  . $response->message,
                '<verbatim>', $content, '</verbatim>'
            );
            last;
        }
        if ( $response->is_redirect ) {
            $url = $response->header('location') || '';
            unless ($url) {
                $reporter->ERROR( "Redirected ("
                      . $response->code . ") "
                      . 'without a =location= header' );
                last;
            }
            next;
        }

        my $xenv;
        eval {
            $xenv = JSON->new->allow_nonref->decode( $response->content || '' );
        };
        if ($@) {
            $reporter->ERROR("Server returned incorrect diagnostic data: $@");
            return undef;
        }
        else {
            return $xenv->{result};
        }
        last;
    }
    $reporter->ERROR("Excessive redirects (>$limit) stopped diagnostic.");
    return undef;
}

sub _getBinDir {
    my $dir = $ENV{SCRIPT_FILENAME} || '.';
    $dir =~ s(/+configure[^/]*$)();
    return $dir;
}

=begin TML

---++ WIZARD request_environment

Respond to a test request from this module.

=cut

sub request_environment {
    my ( $this, $reporter ) = @_;

    # Get environment

    my $data = { action => $2 };

    my @cgivars = (

        # CGI 'Standard'
        qw/AUTH_TYPE CONTENT_LENGTH CONTENT_TYPE GATEWAY_INTERFACE/,
        qw/PATH_INFO PATH_TRANSLATED QUERY_STRING REMOTE_ADDR/,
        qw/REMOTE_HOST REMOTE_IDENT REMOTE_USER REQUEST_METHOD/,
        qw/SCRIPT_NAME SERVER_NAME SERVER_PORT SERVER_PROTOCOL/,
        qw/SERVER_SOFTWARE/,

        # Apache/common extensions
        qw/DOCUMENT_ROOT PATH_TRANSLATED REQUEST_URI SCRIPT_FILENAME/,
        qw/SCRIPT_URI SCRIPT_URL SERVER_ADDR SERVER_ADMIN SERVER_SIGNATURE/,

        # HTTP headers & SSL data
        grep( /^(?:HTTP|SSL)_/, keys %ENV ),

        # Other
        qw/PATH MOD_PERL MOD_PERL_API_VERSION/,
    );

    foreach my $var ( sort @cgivars ) {
        next unless ( exists $ENV{$var} );
        $data->{ENV}->{$var} = $ENV{$var};
    }

    $data->{'@INC'} = [@INC];
    my @gids;
    eval {
        @gids = map { lc getgrgid($_) } split( ' ', $( );
    };
    if ($@) {
        @gids =
          ( lc( qx(sh -c '( id -un ; id -gn) 2>/dev/null' 2>nul ) || 'n/a' ) );
    }
    $data->{groups} = [@gids];

    $data->{uid} = getlogin() || getpwuid($>);
    $data->{umask} = umask;

    return $data;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
