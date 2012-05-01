#!/usr/bin/perl -w
# Script for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2008 ProjectContributors. All rights reserved.
# ProjectContributors are listed in the AUTHORS file in the root of
# the distribution.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
use strict;

sub ask {
    my ( $q, $default ) = @_;
    my $reply;
    local $/ = "\n";

    $q .= '?' unless $q =~ /\?\s*$/;

    my $yorn = 'y/n';
    if ( defined $default ) {
        if ( $default =~ /y/i ) {
            $default = 'yes';
            $yorn    = 'Y/n';
        }
        elsif ( $default =~ /n/i ) {
            $default = 'no';
            $yorn    = 'y/N';
        }
        else {
            $default = undef;
        }
    }
    print $q. ' [' . $yorn . '] ';

    while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
        if ( $reply =~ /^\s*$/ && defined($default) ) {
            $reply = $default;
            last;
        }
        print "Please answer yes or no\n";
    }
    return ( $reply =~ /^y/i ) ? 1 : 0;
}

sub prompt {
    my ( $q, $default ) = @_;
    local $/ = "\n";
    my $reply = '';
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

sub usage {
    print STDERR <<HERE;
This script will generate a new extension in a directory under
the current directory, suitable for building using the
BuildContrib. Stubs for all required files will be generated.

You must be cd'ed to the 'core' directory, and you must
pass the name of your extension - which must end in Skin, Plugin,
or Contrib - to the script. The extension directory
must not already exist.

Subversion users: Once you have created your new extension you can
move it to the root of your checkout before adding to SVN.

Usage: $0 <name of new extension>
HERE
}

use File::Path;

# For each key in %def, the corresponding %$..% string will be expanded
# in all output files. So %$MODULE% will expand to the name of the module.
# %$...% keys not found will be left unexpanded.
my %def;
$def{MODULE} = $ARGV[0];
usage(), exit 1 unless $def{MODULE};
usage(), exit 1 if -d $def{MODULE};

$def{MODULE} =~ /^.*?(Skin|Plugin|Contrib|AddOn)$/;
$def{TYPE} = $1;
usage(), exit 1 unless $def{TYPE};

$def{STUBS} = $def{TYPE} eq 'Plugin' ? 'Plugins' : 'Contrib';

$def{SHORTDESCRIPTION} =
  prompt( "Enter a one-line description of the extension: ", '' );
$def{SHORTDESCRIPTION} =~ s/'/\\'/g;

# Templates for all required files are in this script, after __DATA__
$/ = undef;
my @DATA = split( /<<<< (.*?) >>>>\s*\n/, <DATA> );
shift @DATA;
my %data     = @DATA;
my $stubPath = "$def{MODULE}/lib/Foswiki/$def{STUBS}";
if ( $def{TYPE} eq 'Plugin' ) {
    my $rewrite;

    # Look in all the possible places for EmptyPlugin
    if ( -e "EmptyPlugin/lib/Foswiki/Plugins/EmptyPlugin.pm" ) {

        # probably running in a checkout
        $rewrite = getFile("EmptyPlugin/lib/Foswiki/Plugins/EmptyPlugin.pm");
    }
    elsif ( -e "../EmptyPlugin/lib/Foswiki/Plugins/EmptyPlugin.pm" ) {

        # core subdir in a new-style checkout
        $rewrite = getFile("../EmptyPlugin/lib/Foswiki/Plugins/EmptyPlugin.pm");
    }
    elsif ( -e "lib/Foswiki/Plugins/EmptyPlugin.pm" ) {

        # last ditch, get it from the install
        $rewrite = getFile("lib/Foswiki/Plugins/EmptyPlugin.pm");
    }

    # Tidy up
    $rewrite =~ s/Copyright .*(# This program)/$1/s;
    $rewrite =~ s/^.*?__NOTE:__ /$data{PLUGIN_HEADER}/s;
    $rewrite =~ s/^# change the package name.*$//m;
    $rewrite =~ s/(SHORTDESCRIPTION = ').*?'/$1%\$SHORTDESCRIPTION%'/;
    $rewrite =~ s/EmptyPlugin/%\$MODULE%/sg;
    writeFile( $stubPath, "$def{MODULE}.pm", $rewrite );
}
else {
    writeFile( $stubPath, "$def{MODULE}.pm",
        $data{PM} . ( $data{"PM_$def{TYPE}"} || '' ) );
}
my $modPath = "$stubPath/$def{MODULE}";
$def{UPLOADTARGETPUB}    = 'http://foswiki.org/pub';
$def{UPLOADTARGETSCRIPT} = 'http://foswiki.org/bin';
$def{UPLOADTARGETSUFFIX} = '';
$def{UPLOADTARGETWEB}    = "Extensions";
while (1) {
    print <<END;
The 'upload' target in the generated script will use the following defaults:
Web:     $def{UPLOADTARGETWEB}
PubDir:  $def{UPLOADTARGETPUB}
Scripts: $def{UPLOADTARGETSCRIPT}
Suffix:  $def{UPLOADTARGETSUFFIX}
END
    last if ask( "Is that correct? Answer 'n' to change", 1 );
    print
      "Enter the name of the Foswiki web that contains the target repository\n";
    $def{UPLOADTARGETWEB} = prompt( "Web", $def{UPLOADTARGETWEB} );
    print "Enter the full URL path to the Foswiki pub directory\n";
    $def{UPLOADTARGETPUB} = prompt( "PubDir", $def{UPLOADTARGETPUB} );
    print "Enter the full URL path to the Foswiki bin directory\n";
    $def{UPLOADTARGETSCRIPT} = prompt( "Scripts", $def{UPLOADTARGETSCRIPT} );
    print
"Enter the file suffix used on scripts in the Foswiki bin directory (enter 'none' for none)\n";
    $def{UPLOADTARGETSUFFIX} = prompt( "Suffix", $def{UPLOADTARGETSUFFIX} );
    $def{UPLOADTARGETSUFFIX} = '' if $def{UPLOADTARGETSUFFIX} eq 'none';
}

writeFile( $modPath, "build.pl", $data{"build.pl"} );
chmod 0775, "$modPath/build.pl";
writeFile( $modPath, "DEPENDENCIES", $data{DEPENDENCIES} );
writeFile( $modPath, "MANIFEST",     $data{MANIFEST} );

writeFile( "$def{MODULE}/data/System", "$def{MODULE}.txt",
    ( $data{"TXT_$def{TYPE}"} || $data{TXT} ) );

sub expandVars {
    my $content = shift;
    $content =~ s/%\$(\w+)%/expandVar($1)/ge;
    return $content;
}

sub expandVar {
    my $var = shift;
    return '%$' . $var . '%' unless defined $def{$var};
    return $def{$var};
}

sub writeFile {
    my ( $path, $file, $content ) = @_;
    print "Writing $path/$file\n";
    unless ( -d $path ) {
        File::Path::mkpath("./$path") || die "Failed to mkdir $path: $!";
    }
    $content = expandVars($content);
    $content =~ s/%\$NOP%//g;
    open( F, ">$path/$file" ) || die "Failed to create $path/$file: $!";
    print F $content;
    close(F);
}

sub getFile {
    my $file = shift;
    local $/ = undef;
    open( F, "<$file" ) || die "Failed to open $file: $!";
    my $content = <F>;
    close(F);
    return $content;
}

__DATA__
<<<< build.pl >>>>
#!/usr/bin/perl -w
BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }
use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('%$MODULE%');

# (Optional) Set the details of the repository for uploads.
# This can be any web on any accessible Foswiki installation.
# These defaults will be used when expanding tokens in .txt
# files, but be warned, they can be overridden at upload time!

# name of web to upload to
$build->{UPLOADTARGETWEB} = '%$UPLOADTARGETWEB%';
# Full URL of pub directory
$build->{UPLOADTARGETPUB} = '%$UPLOADTARGETPUB%';
# Full URL of bin directory
$build->{UPLOADTARGETSCRIPT} = '%$UPLOADTARGETSCRIPT%';
# Script extension
$build->{UPLOADTARGETSUFFIX} = '%$UPLOADTARGETSUFFIX%';

# Build the target on the command line, or the default target
$build->build($build->{target});

<<<< DEPENDENCIES >>>>
# Dependencies for %$MODULE%
# Example:
# Time::ParseDate,>=2003.0211,cpan,Required.
# Foswiki::Plugins,>=1.2,perl,Requires version 1.2 of handler API.

<<<< MANIFEST >>>>
# Release manifest for %$MODULE%
data/System/%$MODULE%.txt 0644 Documentation
lib/Foswiki/%$STUBS%/%$MODULE%.pm 0644 Perl module

<<<< PLUGIN_HEADER >>>>
# %$TYPE% for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=pod

---+ package Foswiki::Plugins::%$MODULE%

<<<< PM >>>>
# %$TYPE% for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::%$STUBS%::%$MODULE%;

use strict;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev: 3193 $ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev$'; # version of *this file*.

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# You can use any of the following formats:
# tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
#           usually refer to major.minor.patch release or similar. You can
#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
# isodate - a date in ISO8601 format e.g. 2009-08-07
# date    - a date in 1 Jun 2009 format. Three letter English month names only.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
our $RELEASE = '1.1.1';

our $SHORTDESCRIPTION = '%$SHORTDESCRIPTION%';

<<<< TXT >>>>
---+!! !%$MODULE%
<!--
One line description, required for extensions repository catalog.
BuildContrib will fill in the SHORTDESCRIPTION with the value of
$SHORTDESCRIPTION from the .pm module, or you can redefine it here if you
prefer.
   * Set SHORTDESCRIPTION = %$SHORT%$NOP%DESCRIPTION%
-->
%SHORTDESCRIPTION%

%TOC%

---++ Usage

---++ Examples

---++ Installation Instructions

%$INSTALL_INSTRUCTIONS%

---++ Info

Many thanks to the following sponsors for supporting this work:
   * Acknowledge any sponsors here

|  Author(s): | |
|  Copyright: | &copy; |
|  License: | [[http://www.gnu.org/licenses/gpl.html][GPL (Gnu General Public License)]] |
|  Release: | %$RELEASE% |
|  Version: | %$VERSION% |
|  Change History: | <!-- versions below in reverse order -->&nbsp; |
|  Dependencies: | %$DEPENDENCIES% |
|  Home page: | %$UPLOADTARGETSCRIPT%/view%$UPLOADTARGETSUFFIX%/%$UPLOADTARGETWEB%/%$MODULE% |
|  Support: | %$UPLOADTARGETSCRIPT%/view%$UPLOADTARGETSUFFIX%/Support/%$MODULE% |

<!-- Do _not_ attempt to edit this topic; it is auto-generated. -->
