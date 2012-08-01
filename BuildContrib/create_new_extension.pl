#!/usr/bin/perl -w
# Script for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Author: Crawford Currie http://c-dot.co.uk
#
# Copyright (C) 2008-2012 FoswikiContributors. All rights reserved.
# FoswikiContributors are listed in the AUTHORS file in the root of
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
use warnings;

use File::Path ();

# The script works by creating a new directory structure from an
# existing DS, either an Empty* template or a user-specified
# existing DS. First, a file-set of required files is built up
# and populated with the known minimum requirements. This is then
# enhanced with other files found in the template. Then each
# file is processed, importing it using renaming rules to map
# from the name of the template (e.g. EmptyContrib) to a
# symbolic name (e.g. %$MODULE%). This processed form is then
# output to the target directory after processing to expand
# all the known %$VARIABLES%.

use constant MONITOR => 1;

my %def;
$def{MODULE} = $ARGV[0];
usage() unless $def{MODULE};

$def{MODULE} =~ /^.*?(Skin|JQueryPlugin|Plugin|Contrib|AddOn)$/;
$def{TYPE} = $1;
usage() unless $def{TYPE};

$def{STUBS} = $def{TYPE} =~ /Plugin$/ ? 'Plugins' : 'Contrib';

our $templateModule;
if ( $#ARGV >= 1 ) {
    $templateModule = $ARGV[1];
}
else {
    $templateModule = "Empty$def{TYPE}";
}

unless ( $templateModule && -d $templateModule ) {
    usage( error => "Template directory ($templateModule) does not exist" );
}

print "Creating $def{MODULE} from templates in $templateModule\n";

$def{SHORTDESCRIPTION} =
  prompt( "Enter a one-line description of the extension: ", '' );
$def{SHORTDESCRIPTION} =~ s/'/\\'/g;

$def{AUTHOR} =
  prompt( "Enter the wikiname of the author (e.g. ThomasHardy): ", '' );

my $modPath = "lib/Foswiki/$def{STUBS}/$def{MODULE}";

my $fileset = {
    "$modPath/DEPENDENCIES" => {
        template   => "lib/Foswiki/$def{STUBS}/$templateModule/DEPENDENCIES",
        extract    => \&commonEmptyExtract,
        unmanifest => 1
    },
    "$modPath/build.pl" => {
        template   => "lib/Foswiki/$def{STUBS}/$templateModule/build.pl",
        extract    => \&commonEmptyExtract,
        unmanifest => 1,
        mask       => 0555
    },
    "$modPath/Config.spec" => {
        template => "lib/Foswiki/$def{STUBS}/$templateModule/Config.spec",
        extract  => \&commonEmptyExtract
    },
    "$modPath/MANIFEST" => {
        template   => "lib/Foswiki/$def{STUBS}/$templateModule/MANIFEST",
        expand     => \&manifest,
        extract    => \&manifestExtract,
        unmanifest => 1
    },
    "data/System/$def{MODULE}.txt" => {
        template => "data/System/$templateModule.txt",
        extract  => \&commonEmptyExtract
    }
};

# Different filesets for different types of extension. We can't drive this
# from the MANIFEST for several reasons:
#    1) Some files may need to be renamed
#    2) Some files don't get listed in the MANIFEST
#    3) Some files have odd rewriting rules (e.g. JQuery plugins)
# so instead we ignore the manifest in the template and generate a new one
# from the fileset
if ( $def{TYPE} eq 'JQueryPlugin' ) {
    $def{JQUERYPLUGIN} =
      prompt( "Enter the name of the JQuery plugin you're wrapping: ", '' );

    $def{JQUERYPLUGIN} =~ s/'/\\'/g;
    $def{JQUERYPLUGINMODULE}   = uc( $def{JQUERYPLUGIN} );
    $def{JQUERYPLUGINMODULELC} = lc( $def{JQUERYPLUGIN} );

    # Add in the extra files a JQuery plugin requires
    $fileset->{"$modPath/$def{JQUERYPLUGINMODULE}.pm"} = {
        template => "lib/Foswiki/Plugins/EmptyJQueryPlugin/YOUR.pm",
        extract  => \&jqpPMExtract
    };

    $fileset->{"data/System/JQuery$def{JQUERYPLUGIN}.txt"} = {
        template => "data/System/JQueryYour.txt",
        extract  => \&jqpExtract
    };

    $fileset->{"pub/System/$def{MODULE}/jquery.$def{JQUERYPLUGINMODULELC}.js"} =
      {
        template => "pub/System/EmptyJQueryPlugin/jquery.your.js",
        extract  => \&jqpPMExtract
      };
}

# If we have a template dir, override the default files with those from the template
# and add any missing.
if ($templateModule) {
    populateFrom( '', $templateModule );
}

# Expand the file set
foreach my $k ( keys %$fileset ) {
    my $v = $fileset->{$k};
    if ( $v->{expand} ) {
        my $data = getTemplate( $v->{template} );
        &{ $v->{expand} }($data);
    }
}

if (MONITOR) {
    foreach my $k ( sort keys %$fileset ) {
        my $v = $fileset->{$k};
        print STDERR "$k <= $v->{template}\n";
    }
}

foreach my $k ( keys %$fileset ) {
    my $v    = $fileset->{$k};
    my $data = getTemplate( $v->{template} );
    die "No such template $v->{template}" unless defined $data;
    if ( $v->{extract} ) {
        $data = &{ $v->{extract} }($data);
    }
    writeFile( "$def{MODULE}/$k", expandVars($data), $v->{mask} );
}

### Utility subs.

sub populateFrom {
    my ( $path, $root ) = @_;
    my $dh;
    if ( opendir( $dh, "$root/$path" ) ) {
        foreach my $e ( readdir($dh) ) {
            next if ( $e =~ /^\./ );
            next if ( $e =~ /~$/ );
            my $f = $path ? "$path/$e" : $e;
            if ( -d "$root/$f" ) {
                populateFrom( $f, $root );
            }
            else {
                my $mask = ( stat("$root/$f") )[2];

                # Already known?
                my $found = 0;
                while ( my ( $k, $v ) = each %$fileset ) {
                    if ( $v->{template} eq $f ) {
                        if ( $mask
                            && ( !defined $v->{mask} || $v->{mask} != $mask ) )
                        {
                            $v->{mask} = $mask;
                        }
                        $found = 1;
                    }
                }
                unless ($found) {
                    add2Manifest( "template", $f, $mask, '' );
                }
            }
        }
        closedir($dh);
    }
}

sub expandVars {
    my $vars = shift;
    $vars =~ s/%\$(\w+)%/expandVar($1)/ge;
    $vars =~ s/%\$NOP%//g;
    return $vars;
}

sub expandVar {
    my $var = shift;
    return '%$' . $var . '%' unless defined $def{$var};
    return $def{$var};
}

sub writeFile {
    my ( $filepath, $content, $mask ) = @_;
    $filepath =~ m#(.*)/(.*?)#;
    my ( $path, $file ) = ( $1, $2 );
    unless ( -d $path ) {
        File::Path::mkpath($path) || die "Failed to mkdir $path: $!";
    }
    if ( -e $filepath ) {

        # existing file
        my ( $edata, $fh ) = '';
        if ( open( $fh, "<$filepath" ) ) {
            local $/ = undef;
            $edata = <$fh>;
        }
        if ( $content eq $edata ) {
            print "Skipping unchanged $filepath\n";
            return;
        }
        unless ( $content eq $edata || ask("Overwrite $filepath") ) {
            print "Skipping $filepath";
            return;
        }
    }
    print "Writing $filepath\n";
    open( F, ">$filepath" ) || die "Failed to create $filepath: $!";
    print F $content;
    close(F);
    $mask |= 0200;    # make sure creator can write
    chmod( $mask, "$filepath" ) if defined $mask;
}

sub getFile {
    my $file = shift;
    local $/ = undef;
    open( F, "<$file" ) || die "Failed to open $file: $!";
    my $content = <F>;
    close(F);
    return $content;
}

# get template file from Empty
sub getTemplate {
    my ($path) = @_;

    my $found;

    if ( $templateModule && -e "$templateModule/$path" ) {

        # Found in user specified template dir
        $found = "$templateModule/$path";
    }
    elsif ( -e "$def{MODULE}/$path" ) {

        # probably in a checkout
        $found = "$def{MODULE}/$path";
    }
    elsif ( -e "core/$path" ) {

        # core subdir in a new-style checkout
        $found = "core/$path";
    }
    elsif ( -e $path ) {

        # in an install? Maybe?
        $found = $path;
    }
    elsif ( $ENV{FOSWIKI_HOME} && -e "$ENV{FOSWIKI_HOME}/$path" ) {
        $found = "$ENV{FOSWIKI_HOME}/$path";
    }
    elsif ( $ENV{FOSWIKI_LIBS} && -e "$ENV{FOSWIKI_LIBS}/$path" ) {
        $found = "$ENV{FOSWIKI_LIBS}/$path";
    }
    die "Template '$path' not found in $templateModule" unless $found;
    return getFile($found);
}

# Functions that extract templates to generic reference syntax

sub manifest {
    my $s = shift;

    # If any paths in the manifest are missing from the fileset, add them
    foreach my $m ( split( /\n/, $s ) ) {
        if ( $m =~ /^(\w\S+)(.*)$/ ) {
            my ( $f, $e ) = ( $1, $2 );
            my $mask = 0444;
            if ( $e && $e =~ /^\s*(\d+)\s+(.*)$/ ) {
                $mask = eval $1;
                $e    = $2;
            }
            if ( $fileset->{$f} ) {
                $fileset->{$f}->{extra} = $e if $e;
                $fileset->{$f}->{mask} = $mask;
            }
            else {
                add2Manifest( "manifest", $f, $mask, $e );
            }
        }
    }
    $s = "!noci\n";
    while ( my ( $k, $v ) = each %$fileset ) {
        next if $v->{unmanifest};
        $v->{extra} = ''   unless defined $v->{extra};
        $v->{mask}  = 0444 unless defined $v->{mask};
        $s .= "$k $v->{mask} $v->{extra}\n";
    }

    return $s;
}

sub add2Manifest {
    my ( $what, $f, $mask, $e ) = @_;
    my $rw = \&commonEmptyExtract;
    if ( $f =~ /\.(\w+)/ ) {
        my $fn = "${1}EmptyExtract";
        $rw = eval "\\&$fn" if ( defined(&$fn) );
    }

    #print STDERR "$f ======= $rw\n";
    my $to = expandVars( manifestExtract($f) );
    $fileset->{$to} = {
        template   => $f,
        extract    => $rw,
        extra      => $e,
        mask       => $mask,
        unmanifest => ( $f =~ m#^test/# ? 1 : 0 )
    };
    if (MONITOR) {
        print STDERR "Adding $what path $f => $to ",
          ( $fileset->{$to}->{unmanifest} ? "\n" : "to MANIFEST\n" );
    }
}

sub commonEmptyExtract {
    my $s = shift;
    die unless defined $s;
    $s =~ s/$templateModule/%\$MODULE%/g;
    return $s;
}

sub manifestExtract {
    my $s = shift;

    # Rename templatemodule to this module
    $s =~ s/$templateModule/$def{MODULE}/gs;

    $s = commonEmptyExtract($s);

    # Special case for renaming
    $s =~ s/your\.(\w+)$/'%$JQUERYPLUGINMODULELC%'.$1/e;
    $s =~ s/Your\.(\w+)$/'%$JQUERYPLUGIN%'..$1/e;
    $s =~ s/YOUR\.(\w+)$/'%$JQUERYPLUGINMODULE%'.$1/e;
    return $s;
}

sub pmEmptyExtract {
    my $s = commonEmptyExtract(shift);
    $s =~ s/^# change the package name.*$//m;    # we're doing it!
    $s =~ s/(\$SHORTDESCRIPTION = ').*?'/$1.'%$SHORTDESCRIPTION%'."';"/e;
    return $s;
}

sub jqpExtract {
    my $s = commonEmptyExtract(shift);
    $s =~ s/Your/%\$JQUERYPLUGIN%/sg;
    $s =~ s/YOUR/%\$JQUERYPLUGINMODULE%/sg;
    return $s;
}

sub jqpPMExtract {
    my $s = jqpExtract(shift);
    $s =~ s/your/%\$JQUERYPLUGINMODULELC%/sg;
    return $s;
}

# Prompt for a yes/no answer, with possible default to be applied
# when enter is hit
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

# Prompt for an answer, with possible default when enter is hit
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

# Generate help
sub usage {
    my %param = @_;
    print STDERR <<HERE;
Usage: $0 <name of new extension> [ existing extension ]

This script will generate a new extension in a directory under the
current directory, suitable for building using the BuildContrib.

You pass the name of your new extension - which must end in Skin,
JQueryPlugin, Plugin, or Contrib - to the script. For example,

$0 MyNewSkin

will create the directory structure and support files for a new skin
called "MyNewSkin"

You can also build a new extension using sources from an existing
extension.  When you build from an existing extension, copies of all
the files in that extension will automatically be added to the new
extension. The existing extension must exist in a subdirectory of the
current directory. For example:

$0 MyNewPlugin ExistingPlugin

will generate "MyNewPlugin" using sources from ExistingPlugin as a
template.

HERE
    print STDERR "\n\nERROR: $param{error}\n\n" if ( defined( $param{error} ) );
    exit 1;
}

1;
