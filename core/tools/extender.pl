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
use FindBin;
use Getopt::Long;

#no warnings 'redefine';

my $noconfirm  = 0;
my $downloadOK = 0;
my $expanded   = '';
my $reuseOK    = 0;
my $nodeps     = 0;
my $simulate   = 0;
my $action     = '';
my $enable     = 1;    # Default is to enable plugins
my $thispkg;           # Package object for THIS module
my $MODULE = '<package>';
my $PACKAGES_URL;
my $MANIFEST;

GetOptions(
    "auto"       => \$noconfirm,     # -a    #OBSOLETE
    "download"   => \$downloadOK,    # -d    #OBSOLETE
    "reuse"      => \$reuseOK,       # -r       USELOCAL
    "simulate|n" => \$simulate,      # -n       SIMULATE
    "nodeps|o"   => \$nodeps,        # -o       NODEPS
    "expanded|x=s" =>
      \$expanded,    # -x       EXPANDED  (Pass in directory location)
    "enable!" => \$enable,    # -e       ENABLE
) or die("Error in command line arguments\n");

if ( @ARGV == 0 ) {
    usage();
    print STDERR
"## ERROR: DEFAULT 'install' action is no longer active.  Specify 'install' if you want to install this extension.\n";
    exit(0);
}
elsif ( @ARGV > 1 ) {
    usage();
    print STDERR '## ERROR: Too many parameters: ' . join( " ", @ARGV ) . "\n";
    exit(0);
}
$action = $ARGV[0] if $ARGV[0];

unless ( $action =~ m/^(install|uninstall|dependencies|manifest|usage)$/ ) {
    usage();
    print STDERR
"## ERROR: Action $action is not known.  Valid actions are 'install', 'uninstall', 'dependencies' and 'manifest'\n";
    exit(0);
}

unless ( -d 'lib' && -d 'data' && -e 'lib/LocalSite.cfg' ) {
    _stop(  'This installer must be run from the root directory'
          . ' of a Foswiki installation' );
}

# When run as a <SomeExtension_installer>,  the "bin directory" might be
# installation root, or possibly working/configure/pkgdata
# But this must always be run from the installation root.

my $installationRoot = Cwd::getcwd();

# getcwd is often a simple `pwd` thus it's tainted, untaint it
$installationRoot =~ /^(.*)$/;
$installationRoot = $1;

# Make sure tools/configure can find setlib.cfg and Assert.
unshift @INC, "$installationRoot/bin";
unshift @INC, "$installationRoot/lib";

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

sub usage {
    print STDERR <<DONE ;

This is Foswiki extensions installer. It is called either as part of a custom
installer, or from the tools/extension_installer generic installation script.

When used as a custom installer:

       ${MODULE}_installer -n -r -o -u -e install
       ${MODULE}_installer -n uninstall
       ${MODULE}_installer manifest
       ${MODULE}_installer dependencies

When used from the generic installer:

       tools/extension_installer ${MODULE} -n -r -u install
       tools/extension_installer ${MODULE} -n uninstall
       tools/extension_installer ${MODULE} manifest
       tools/extension_installer ${MODULE} dependencies

Operates on the directory tree below where it is run from,
so should be run from the top level of your Foswiki installation.

Depending upon your installation, you may need to execute perl directly
  perl tools/extension_installer ...   or
  perl ${MODULE}_installer ...

"install" will check dependencies and perform any required
post-install steps.

"uninstall" will remove all files that were installed for
$MODULE even if they have been locally modified.

The "install" and "uninstall" actions make a backup of the extension before
making any changes.  The backup is based up on the files listed in the manifest.

-r reuse packages previously downloaded
-x <directory> Use expanded: the archive has already been downloaded and unpacked into <directory>
-n Simulate; don't write any files into my current install, just tell me what you would have done
-o Only install the single extension, no dependencies.
-e enable any installed plugins (This is the default),  specify -noe or --noenable to negate.

The -r "reuse" option will look for previously downloaded files in two locations:
   The Foswiki "installation root" - the parent directory of the Locales directory
   The working/configure/download directory.
If the archive or installer file are not found, then new copies will be downloaded.

The -x "expanded" argument requires that the ${MODULE}_installer file be located in that directory

"manifest" will generate a list of the files in the package on
standard output. The list is generated in the same format as
the MANIFEST files used by BuildContrib.

"dependencies" will generate a list of dependencies on standard
output.

Note: CPAN dependencies are not installed with this tool.  Use your
local OS package manager, or a tool like cpanm to resolve dependencies
from CPAN.

# Obsolete parameters are ignored:
# -a means don't prompt for confirmation before resolving
#    dependencies
# -d means auto-download if -a (no effect if not -a)

DONE
}

#
#  Install is the main routine called by the [package]_installer script
#
sub install {
    $PACKAGES_URL = shift;
    $MODULE       = shift;
    my $rootModule = shift;
    push( @_, '' ) if ( scalar(@_) & 1 );

    if ( $action eq 'usage' ) {
        usage();
        exit 0;
    }

    $reuseOK = ask(
"Do you want to use locally found installer scripts and archives to install $MODULE and any dependencies.\nIf you reply n, then fresh copies will be downloaded from this repository."
    ) unless ($reuseOK);

    @ARGV = ( '-wizard', 'InstallExtensions', '-args', "$MODULE=Foswiki.org" );

    push @ARGV, (qw( -args USELOCAL=1)) if ($reuseOK);

    if ($expanded) {
        push @ARGV, (qw( -args EXPANDED=1));
        push @ARGV, ( '-args', "DIR=$expanded" );
    }

    if ( $action eq 'manifest' ) {
        push @ARGV, (qw( -method manifest));
    }
    elsif ( $action eq 'dependencies' ) {
        push @ARGV, (qw( -method depreport));
    }
    elsif ( $action =~ m/install$/ ) {
        unshift @ARGV, '-save' unless ($simulate);
        push @ARGV, (qw( -args SIMULATE=1)) if ($simulate);
        push @ARGV, (qw( -args NODEPS=1))   if ($nodeps);
        if ( $action eq 'install' ) {
            push @ARGV, (qw( -method add ));
            push @ARGV, ( '-args', "ENABLE=$enable" );
        }
        elsif ( $action eq 'uninstall' ) {
            push @ARGV, (qw( -method remove ));
        }
    }

    print STDERR "\n=========\n"
      . 'tools/configure '
      . join( ' ', @ARGV )
      . "\n========\n";

    unless ( my $return = do 'tools/configure' ) {
        warn "couldn't parse tools/configure : $@" if $@;
        warn "couldn't do tools/configure: $!" unless defined $return;
        warn "couldn't run tools/configure" unless $return;
    }
}

1;
__END__
Author: Crawford Currie http://wikiring.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
