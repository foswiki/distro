#!/usr/bin/perl -w
# Script for Foswiki - The Free Open Source Wiki, http://foswiki.org/
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
the twikiplugins directory, suitable for building using the
BuildContrib. Stubs for all required files will be generated.

You must be cd'ed to the twikiplugins directory, and you must
pass the name of your extension - which must end in Skin, Plugin,
Contrib, AddOn or TWikiApp - to the script. The extension directory
must not already exist.

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

$def{MODULE} =~ /^.*?(Skin|Plugin|Contrib|AddOn|TWikiApp)$/;
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
my $stubPath = "$def{MODULE}/lib/TWiki/$def{STUBS}";
if ( $def{TYPE} eq 'Plugin' ) {
    my $rewrite;
    # Look in all the possible places for EmptyPlugin
    if (-e "EmptyPlugin/lib/TWiki/Plugins/EmptyPlugin.pm") {
        # probably running in a checkout
        $rewrite = getFile("EmptyPlugin/lib/TWiki/Plugins/EmptyPlugin.pm");
    } elsif (-e "twikiplugins/EmptyPlugin/lib/TWiki/Plugins/EmptyPlugin.pm") {
        # Old-style checkout
        $rewrite = getFile("twikiplugins/EmptyPlugin/lib/TWiki/Plugins/EmptyPlugin.pm");
    } elsif (-e "../EmptyPlugin/lib/TWiki/Plugins/EmptyPlugin.pm") {
        # core subdir in a new-style checkout
        $rewrite = getFile("../EmptyPlugin/lib/TWiki/Plugins/EmptyPlugin.pm");
    } elsif (-e "lib/TWiki/Plugins/EmptyPlugin.pm") {
        # last ditch, get it from the install
        $rewrite = getFile("lib/TWiki/Plugins/EmptyPlugin.pm");
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
$def{UPLOADTARGETPUB}    = 'http://nextwiki.org/pub';
$def{UPLOADTARGETSCRIPT} = 'http://nextwiki.org/bin';
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
      "Enter the name of the TWiki web that contains the target repository\n";
    $def{UPLOADTARGETWEB} = prompt( "Web", $def{UPLOADTARGETWEB} );
    print "Enter the full URL path to the TWiki pub directory\n";
    $def{UPLOADTARGETPUB} = prompt( "PubDir", $def{UPLOADTARGETPUB} );
    print "Enter the full URL path to the TWiki bin directory\n";
    $def{UPLOADTARGETSCRIPT} = prompt( "Scripts", $def{UPLOADTARGETSCRIPT} );
    print
"Enter the file suffix used on scripts in the TWiki bin directory (enter 'none' for none)\n";
    $def{UPLOADTARGETSUFFIX} = prompt( "Suffix", $def{UPLOADTARGETSUFFIX} );
    $def{UPLOADTARGETSUFFIX} = '' if $def{UPLOADTARGETSUFFIX} eq 'none';
}

writeFile( $modPath, "build.pl", $data{"build.pl"} );
chmod 0775, "$modPath/build.pl";
writeFile( $modPath, "DEPENDENCIES", $data{DEPENDENCIES} );
writeFile( $modPath, "MANIFEST",     $data{MANIFEST} );

writeFile( "$def{MODULE}/data/TWiki", "$def{MODULE}.txt",
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
    open( F, ">$path/$file" ) || die "Failed to create $path/$file: $!";
    print F expandVars($content);
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
BEGIN {
    unshift @INC, split( /:/, $ENV{TWIKI_LIBS} );
}
use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build('%$MODULE%');

# (Optional) Set the details of the repository for uploads.
# This can be any web on any accessible TWiki installation.
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
# TWiki::Plugins,>=1.15,perl,TWiki 4.1 release.

<<<< MANIFEST >>>>
# Release manifest for %$MODULE%
data/TWiki/%$MODULE%.txt 0644 Documentation
lib/TWiki/%$STUBS%/%$MODULE%.pm 0644 Perl module

<<<< PLUGIN_HEADER >>>>
# %$TYPE% for Foswiki - The Free Open Source Wiki, http://foswiki.org/
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

---+ package TWiki::Plugins::%$MODULE%

<<<< PM >>>>
# %$TYPE% for Foswiki - The Free Open Source Wiki, http://foswiki.org/
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

package TWiki::%$STUBS%::%$MODULE%;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = '';
$SHORTDESCRIPTION = '%$SHORTDESCRIPTION%';

<<<< TXT >>>>
---+!! !%$MODULE%
<!--
One line description, required for extensions repository catalog.
   * Set SHORTDESCRIPTION = %$SHORTDESCRIPTION%
-->
%SHORTDESCRIPTION%

%TOC%

---++ Usage

---++ Examples

---++ Installation Instructions

%$INSTALL_INSTRUCTIONS%

---++ %$TYPE% Info

Many thanks to the following sponsors for supporting this work:
   * Acknowledge any sponsors here

|  %$TYPE% Author(s): | |
|  Copyright: | &copy; |
|  License: | [[http://www.gnu.org/licenses/gpl.html][GPL (Gnu General Public License)]] |
|  %$TYPE% Version: | %$VERSION% |
|  Change History: | <!-- versions below in reverse order -->&nbsp; |
|  Dependencies: | %$DEPENDENCIES% |
|  %$TYPE% Home: | %$UPLOADTARGETSCRIPT%/view%$UPLOADTARGETSUFFIX%/%$UPLOADTARGETWEB%/%$MODULE% |
|  Feedback: | %$UPLOADTARGETSCRIPT%/view%$UPLOADTARGETSUFFIX%/%$UPLOADTARGETWEB%/%$MODULE%Dev |
|  Appraisal: | %$UPLOADTARGETSCRIPT%/view%$UPLOADTARGETSUFFIX%/%$UPLOADTARGETWEB%/%$MODULE%Appraisal |

__Related Topics:__ %SYSTEMWEB%.TWiki%$TYPE%s, %SYSTEMWEB%.DeveloperDocumentationCategory, %SYSTEMWEB%.AdminDocumentationCategory, %SYSTEMWEB%.DefaultPreferences, %USERSWEB%.SitePreferences

<!-- Do _not_ attempt to edit this topic; it is auto-generated. Please add comments/questions/remarks to the feedback topic on twiki.org instead. -->
