# See bottom of file for license and copyright information
#
# This module contains the functions used by the extensions installer.
# It is not treated as a "standard" module because it has radically
# different environment requirements (i.e. as few as possible)
#
# It is invoked from the individual installer scripts shipped with
# extensions, and should not be run directly.
#
package Foswiki::Extender;
use strict;
use warnings;

use Cwd;
use File::Temp;
use File::Copy;
use File::Path;
use Getopt::Std;
use Cwd qw(abs_path);
use File::Basename;

no warnings 'redefine';

my $noconfirm       = 0;
my $downloadOK      = 0;
my $alreadyUnpacked = 0;
my $reuseOK         = 0;
my $simulate        = 0;
my $nocpan          = 0;
my $action          = 'install';    # Default target is install
my $session;
my $thispkg;                        # Package object for THIS module
my %available;
my $lwp;
my @archTypes = ( '.tgz', '.tar.gz', '.zip' );
my $installationRoot;
my $MODULE;
my $PACKAGES_URL;
my $MANIFEST;

sub _inform {
    print @_, "\n";
}

sub _warn {
    print "*WARNING* ", @_, "\n";
}

sub _shout {
    print "### ERROR ### ", @_, "\n";
}

sub _stop {
    _shout @_;
    die @_;
}

# processParameters
my %opts;
getopts( 'acdnoru', \%opts );
$noconfirm       = $opts{a};
$nocpan          = $opts{c};
$downloadOK      = $opts{d};
$reuseOK         = $opts{r};
$simulate        = $opts{n};
$alreadyUnpacked = $opts{u};
if ( @ARGV > 1 ) {
    usage();
    _stop( 'Too many parameters: ' . join( " ", @ARGV ) );
}
$action = $ARGV[0] if $ARGV[0];

$installationRoot = Cwd::getcwd();

# getcwd is often a simple `pwd` thus it's tainted, untaint it
$installationRoot =~ /^(.*)$/;
$installationRoot = $1;

my $check_perl_module = sub {
    my $module = shift;

    if ( eval "require $module" ) {
        $available{$module} = 1;
    }
    else {
        _warn(  "$module is not available on this server,"
              . " some installer functions have been disabled \n $@" );
        $available{$module} = 0;
    }
    return $available{$module};
};

unless ( -d 'lib' && -d 'data' && -e 'lib/LocalSite.cfg' ) {
    _stop(  'This installer must be run from the root directory'
          . ' of a Foswiki installation' );
}

my $bindir = getScriptDir('lib/LocalSite.cfg');

# read setlib.cfg
chdir($bindir);
require 'setlib.cfg';
chdir($installationRoot);

# See if we can make a Foswiki. If we can, then we can save topic
# and attachment histories. Key off Foswiki::Merge because it is
# fairly new and fairly unique.
unless ( &$check_perl_module('Foswiki::Merge') ) {
    _stop("Can't find Foswiki: $@");
}

# Use the CLI engine, and change to minimal mapper and password manager
# so that configure can run if the authentication contribs have problems
$Foswiki::cfg{Engine}             = 'Foswiki::Engine::CLI';
$Foswiki::cfg{PasswordManager}    = 'none';
$Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::BaseUserMapping';

# SMELL: The Cache uses $Foswiki::cfg variables that are not expanded when running
# in a configure setting.   Disable the cache because the init routine fails.
# This might leave stale cache entries for topics updated by the installer.
$Foswiki::cfg{Cache}{Enabled} = 0;

unless ( eval { require Foswiki } ) {
    _stop("Can't load Foswiki: $@");
}

# We have to get the admin user, as a guest user may be blocked.
my $user = $Foswiki::cfg{AdminUserLogin};
$session = new Foswiki($user);

&$check_perl_module('CPAN');

# Can't do this until we have setlib.cfg
require Foswiki::Configure::Dependency;
require Foswiki::Configure::Util;
require Foswiki::Configure::Package;

# Satisfy CPAN dependencies on modules, by checking:

sub satisfy {
    my $dep = shift;
    my $ok  = '';
    my $msg = '';

    if ( $dep->{type} =~ m/cpan/i && $available{CPAN} && !$nocpan ) {
        _inform <<'DONE';
This module is available from the CPAN archive (http://www.cpan.org). You
can download and install it from here. The module will be installed
to wherever you configured CPAN to install to.
DONE
        my $reply =
          ask(  'Would you like me to try to download '
              . 'and install the latest version of '
              . $dep->{module}
              . ' from cpan.org?' );
        return 0 unless $reply;

        my $mod = CPAN::Shell->expand( 'Module', $dep->{module} );
        unless ($mod) {
            _shout <<DONE;
$dep->{module} was not found on CPAN

Please check the dependencies for this package.  $dep->{module} may be incorrect.
Or the dependency will require manual resolution.
DONE
            return 0;
        }

        my $info = $mod->dslip_status();
        if ( $info->{D} eq 'S' ) {

            # Standard perl module!
            _shout <<DONE;
$dep->{module} is a standard perl module

I cannot install it without upgrading your version of perl, something
I'm not willing to do. Please either install the module manually (from
a package downloaded from cpan.org) or upgrade your perl to a version
that includes this module.
DONE
            return 0;
        }
        if ($noconfirm) {
            $CPAN::Config->{prerequisites_policy} = 'follow';
        }
        else {
            $CPAN::Config->{prerequisites_policy} = 'ask';
        }
        CPAN::install( $dep->{module} );
        ( $ok, $msg ) = $dep->check();
        return 1 if $ok;

        my $e = 'it';
        if ( $CPAN::Config->{makepl_arg} =~ /PREFIX=(\S+)/ ) {
            $e = $1;
        }
        _shout <<DONE;
I still can't find the module $dep->{module}

If you installed the module in a non-standard directory, make sure you
have followed the instructions in bin/setlib.cfg and added $e
to your \@INC path.

DONE
    }

    return 0;
}

=pod

---++ StaticMethod ask( $question ) -> $boolean
Ask a question.
Example: =if( ask( "Proceed?" )) { ... }=

=cut

sub ask {
    my $q = shift;
    my $reply;

    return 1 if $noconfirm;
    local $/ = "\n";

    $q .= '?' unless $q =~ /\?\s*$/;

    print $q. ' [y/n] ';
    while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
        print "Please answer yes or no\n";
    }
    return ( $reply =~ /^y/i ) ? 1 : 0;
}

=pod

---++ StaticMethod prompt( $question, $default ) -> $string
Prompt for a string, using a default if return is pressed.
Example: =$dir = prompt("Directory")=;

=cut

sub prompt {
    my ( $q, $default ) = @_;
    my $reply = '';
    local $/ = "\n";
    while ( !$reply ) {
        print $q;
        print " ($default)" if defined $default;
        print ': ';
        $reply = <STDIN>;
        chomp($reply);
        $reply ||= $default;
    }
    return $reply;
}

sub _loadInstaller {

    my $repository = {
        name => 'fromInstaller',
        data => '',
        pub  => "$PACKAGES_URL/"
    };

    my $fromDir = dirname( abs_path($0) );

    _inform "Package repository set to $PACKAGES_URL \n";
    _inform
" ... locally found installer scripts and archives will be used if available"
      if ($reuseOK);

    $thispkg = new Foswiki::Configure::Package(
        "$installationRoot/",
        $MODULE, $session,
        {
            SHELL    => 1,
            USELOCAL => $reuseOK,
            SIMULATE => $simulate,
            DIR      => $fromDir
        }
    );
    $thispkg->repository($repository);

    my ( $rslt, $err ) = $thispkg->loadInstaller()
      ;    # Use local package, don't download, as we were invoked from it.

    _inform "$rslt" if ($rslt);
    _stop "$err"    if ($err);
}

sub _uninstall {
    my $file;
    my $rslt = '';
    my $err  = '';
    my $sim  = '';
    $sim = 'Simulated - ' if ($simulate);

    my $reply = ask("Are you SURE you want to uninstall $MODULE?");
    if ($reply) {

        $rslt = $thispkg->uninstall();
        _inform "$rslt";

        $thispkg->finish();
        undef $thispkg;

        _inform "$sim $MODULE uninstalled";
    }
    return 1;
}

sub usage {
    _inform <<DONE;

Usage as a custom installer:

       ${MODULE}_installer -a -n -d -r -u -c install
       ${MODULE}_installer -a -n uninstall
       ${MODULE}_installer manifest
       ${MODULE}_installer dependencies

Usage as a generic installer:

       tools/extension_installer ${MODULE} -a -n -d -r -u -c install
       tools/extension_installer ${MODULE} -a -n uninstall
       tools/extension_installer ${MODULE} manifest
       tools/extension_installer ${MODULE} dependencies

If command (install, uninstall ..) is not provided, default is to 
install the extension.

Operates on the directory tree below where it is run from,
so should be run from the top level of your Foswiki installation.

Depending upon your installation, you may need to execute perl directly
  perl tools/extension_installer ...   or
  perl ${MODULE}_installer ...

"install" will check dependencies and perform any required
post-install steps.

"uninstall" will remove all files that were installed for
$MODULE even if they have been locally modified.

-a means don't prompt for confirmation before resolving
   dependencies
-d means auto-download if -a (no effect if not -a)
-r means reuse packages on disc if -a (no effect if not -a)
-u means the archive has already been downloaded and unpacked
-n means don't write any files into my current install, just
   tell me what you would have done
-c means don't try to use CPAN to install missing libraries

"manifest" will generate a list of the files in the package on
standard output. The list is generated in the same format as
the MANIFEST files used by BuildContrib.

"dependencies" will generate a list of dependencies on standard
output.

DONE
}

# 1 Check if there is already an install of this module, and seek
#   overwrite confirmation
# 2 Check dependencies and confirm that install should proceed
# 3 Install the package - which will resolve any Foswiki/TWiki dependencies
# 4 If any CPAN dependences are reported - offer to satisfy them
sub _install {
    my ($rootModule) = @_;

    my $path = $MODULE;

    if ( $path !~ /^(Foswiki|TWiki)::/ ) {
        my $source = 'Foswiki';
        my $type   = 'Contrib';
        if ( $path =~ /Plugin$/ ) {
            $type = 'Plugins';
        }
        $path = $source . '::' . $type . '::' . $rootModule;
    }

    my $selfDep = new Foswiki::Configure::Dependency(
        module => $path,
        type   => 'perl',
    );

    if ( $selfDep->studyInstallation() ) {

        # Module is already installed

        # XXX SMELL: Could be more user-friendly:
        # test that current version isn't newest
        my $moduleVersion = 0;
        {
            $moduleVersion = $selfDep->{installedVersion};

            # remove the SVN marker text from the version number, if it is there
            $moduleVersion =~ s/^\$Rev: (\d+) \$$/$1/;
        }

        if ($moduleVersion) {
            return 0
              unless ask(
                          "$MODULE version $moduleVersion is already installed."
                        . " Are you sure you want to re-install this module?"
              );
        }
    }

    my ( $installed, $missing, @wiki, @cpan, @manual ) =
      $thispkg->checkDependencies();
    _inform $installed;
    _inform $missing;

    my $instmsg = "$MODULE ready to be installed ";
    $instmsg .= "along with Foswiki dependencies identified above\n"
      if ($missing);
    $instmsg .= "(you will be asked later about any CPAN dependencies)\n"
      if ($missing);
    $instmsg .= "Do you want to proceed with installation of $MODULE";
    $instmsg .= " and Dependencies" if ($missing);
    $instmsg .= '?';

    return 0
      unless ask("$instmsg");

    my ( $rslt, $plugins, $depCPAN ) = $thispkg->install();
    _inform $rslt;
    $rslt = '';

    my $unsatisfied = 0;
    foreach my $depkey ( keys %$depCPAN ) {
        unless ( satisfy( \%{ $depCPAN->{$depkey} } ) ) {
            $unsatisfied++;
        }
    }

    my $err = $thispkg->errors();
    if ($err) {
        _shout($err);
    }
    else {
        _inform("No errors encountered during installation\n");
    }

    $thispkg->finish();
    undef $thispkg;

    return 0;
}

# Invoked when the user installs a new extension using
# the configure script. It is used to ensure the perl module dependencies
# provided by the module are real module names, and not some random garbage
# which could be potentially insecure.
sub _validatePerlModule {
    my $module = shift;

    # Remove all non alpha-numeric caracters and :
    # Do not use \w as this is localized, and might be tainted
    my $replacements = $module =~ s/[^a-zA-Z:_0-9]//g;
    _warn 'validatePerlModule removed '
      . $replacements
      . ' characters, leading to '
      . $module . "\n"
      if $replacements;
    return $module;
}

=begin TML

---++ StaticMethod getScriptDir( )
This routine will recover the Script Directory from LocalSite.cfg
without processing the entire file.  

=cut

sub getScriptDir {

    my $lscFile = shift;

    #  - Single-quoted string
    my $reSqString = qr{
          \'
          ([^\']+)
          \'
        }x;

    #  - Double-quoted string
    my $reDqString = qr{
          \"
          ([^\"]+)
          \"
        }x;

    my $reBinDir = qr{
      ^\s*\$Foswiki::cfg\{ScriptDir\}                           # Variable
      \s*=\s*                                                   # Equal sign - optional spaces
      (?: (?:$reSqString) | (?:$reDqString) )                   # delimited value
      \s*;\s*$                                                  # ending bracket
    }msx;

    my $cfgfh = open my $cfg, '<', "$lscFile";
    if ( !$cfgfh ) {
        return 0;
    }
    my $cfgfile = do { local $/; <$cfg> };

    $cfgfile =~ m/$reBinDir/ms;
    return $1 || $2;

}

#
#  Install is the main routine called by the [package]_installer script
#
sub install {
    $PACKAGES_URL = shift;
    $MODULE       = shift;
    my $rootModule = shift;
    push( @_, '' ) if ( scalar(@_) & 1 );

    unshift( @INC, 'lib' );

    if ( $action eq 'usage' ) {
        usage();
        exit 0;
    }

    $reuseOK = ask(
"Do you want to use locally found installer scripts and archives to install $MODULE and any dependencies.\nIf you reply n, then fresh copies will be downloaded from this repository."
    ) unless ($reuseOK);

    _loadInstaller();

    if ( $action eq 'manifest' ) {
        _inform $thispkg->Manifest();
        exit 0;
    }

    if ( $action eq 'dependencies' ) {
        my ( $installed, $missing, @wiki, @cpan, @manual ) =
          $thispkg->checkDependencies();

        _inform $installed;
        _inform $missing;

        exit 0;
    }

    _inform "\n${MODULE} Installer";
    _inform <<DONE;
This installer must be run from the root directory of your Foswiki
installation.
DONE
    unless ($noconfirm) {
        _inform <<DONE
    * The script will not do anything without asking you for
      confirmation first (unless you used -a).
DONE
    }
    _inform <<DONE;
    * You can abort the script at any point and re-run it later
    * If you answer 'no' to any questions you can always re-run
      the script again later
DONE

    if ( $action eq 'install' ) {
        _install($rootModule);
    }
    elsif ( $action eq 'uninstall' ) {
        _uninstall();
    }
}

1;
__END__
Author: Crawford Currie http://wikiring.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
