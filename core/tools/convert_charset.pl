#!/usr/bin/perl
#
# Static charset converter. Converts the character set used in a Foswiki
# DB to UTF8. ONLY FOR USE ON RCS STORES.
#
# cd to the tools directory to run it
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2011 Foswiki Contributors.
#
# Author: Crawford Currie http://c-dot.co.uk
#
# For licensing info read LICENSE file in the Foswiki root.
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
# As per the GPL, removal of this notice is prohibited.

use strict;
use warnings;
use Encode;

BEGIN { do '../bin/setlib.cfg'; }

use Foswiki;
use Foswiki::Store::VC::RcsLiteHandler;
use Carp;

# Must do this before we construct the session object, otherwise the store
# cache gets populated with Wrap handlers
$Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsLite';

my $session = new Foswiki();

my $inform_only = 0;

if ( $#ARGV >= 0 && $ARGV[0] eq '-i' ) {
    $inform_only = 1;
} else {
    print <<INTRO;

Foswiki RCS database character set conversion

This script will convert the Foswiki RCS database pointed at by
{DataDir} and {PubDir} from the existing character set (as set
by {Site}{CharSet}) to UTF8.

You can run the script in "inspection" mode by passing -i on the
command line. No changes will be made to the database.

Once you have run the script without -i, all:
    * web names
    * topic names
    * attachment names
    * topic content
will be converted to UTF8. The conversion is performed *in place* on the data
and pub directories.

Note that no conversion is performed on
   * log files
   * working/
   * temporary files

Once conversion is complete you must change your {Site}{CharSet} to 'utf-8'

INTRO

    ask( "Have you backed up your data ($Foswiki::cfg{DataDir}) and pub ($Foswiki::cfg{PubDir}) directories?" )
	|| die "Cannot proceed without backup confirmation";
    ask( "Do you have write permission on all files and directories in $Foswiki::cfg{DataDir} and $Foswiki::cfg{PubDir}?" )
	|| die "Cannot proceed without confirmation of access permissions";
    ask( "\$Foswiki::cfg{Site}{CharSet} is set to '$Foswiki::cfg{Site}{CharSet}'. Is that correct for the data in your Foswiki database" )
	|| die "Cannot proceed until you confirm that data is consistent with this setting";
}

# First we rename all webs and files as necessary by calling the recursive collection
# rename on the root web
rename_collection('');

# Now we convert the content of topics
convert_topics_contents('');

# And that's it!

##########################################################

# Prompt user for a confirmation
sub ask {
    my $q = shift;
    my $reply;

    local $/ = "\n";

    $q .= '?' unless $q =~ /\?\s*$/;

    print $q. ' [y/n] ';
    while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
        print "Please answer yes or no\n";
    }
    return ( $reply =~ /^y/i ) ? 1 : 0;
}

sub _rename {
    print STDERR "Rename $_[0]\n    to $_[1]\n";
    return if ($inform_only);
    rename( $_[0], $_[1] )
	|| print STDERR "Failed to rename $_[0] to $_[1]: $!";
}

# Convert a byte string encoded in the {Site}{CharSet} to a byte string encoded in utf8
# Return 1 if a conversion happened, 0 otherwise
sub _convert {
    my $old = $_[0];
    confess unless defined $old;
    # Convert octets encoded using site charset to unicode codepoints. Note that we use
    # Encode::FB_HTMLCREF; this should be a nop as unicode can accomodate all characters.
    $_[0] = Encode::decode($Foswiki::cfg{Site}{CharSet}, $_[0], Encode::FB_HTMLCREF);

    # Note that when we come to print the changes, the unicode does *not* cause a wide
    # character in print error. I don't understand why, but it works.

    return ($_[0] ne $old) ? 1 : 0;
}

# Rename a web and all it's contents if necessary
sub rename_collection {
    my $fromweb = shift;
    my $web = $fromweb;
    my $dir;

    opendir($dir, "$Foswiki::cfg{DataDir}/$web") || die "Failed to open '$web' $!";
    foreach my $e (readdir($dir)) {
	next if $e =~ /^\./;
	my $ne = $e;
	if (_convert($ne)) {
	    _rename( "$Foswiki::cfg{DataDir}/$web/$e", "$Foswiki::cfg{DataDir}/$web/$ne" );
	    $e = $ne;
	}
	if (-d "$Foswiki::cfg{DataDir}/$web/$e"
	    && -e "$Foswiki::cfg{DataDir}/$web/$e/WebPreferences.txt") {
	    rename_collection($web ? "$web/$e" : $e);
	}
    }
    closedir($dir);

    if (-d "$Foswiki::cfg{PubDir}/$web") {
	opendir($dir, "$Foswiki::cfg{PubDir}/$web") || die "Failed to open '$web' $!";
	foreach my $e (readdir($dir)) {
	    next if $e =~ /^\./;
	    my $ne = $e;
	    if (_convert($ne)) {
		_rename( "$Foswiki::cfg{PubDir}/$web/$e", "$Foswiki::cfg{PubDir}/$web/$ne" );
	    }
	}
	closedir($dir);
    }
}

# Convert the contents (*not* the name) of a topic
# The history conversion is done by loading the topic into RCSLite and performing the
# charset conversion on the fields.
sub convert_topic {
    my ($web, $topic) = @_;
    my $converted = 0;

    # Convert .txt,v
    my $handler = Foswiki::Store::VC::RcsLiteHandler->new($session->{store}, $web, $topic);
    eval {
	$handler->_ensureProcessed();
    };
    if ($@) {
	print STDERR "Aborted processing of $handler->{web}.$handler->{topic} history: $@\n";
    } elsif ( $handler->{state} ne 'nocommav' ) {
	# need to convert fields
	foreach my $rev (@{$handler->{revs}}) {
	    $converted += _convert($rev->{text}) if defined $rev->{text};
	    $converted += _convert($rev->{log}) if defined $rev->{log};
	    $converted += _convert($rev->{comment}) if defined $rev->{comment};
	    $converted += _convert($rev->{desc}) if defined $rev->{desc};
	    $converted += _convert($rev->{author}) if defined $rev->{author};
	}
	if ($converted) {
	    print STDERR "Converted history of $handler->{web}.$handler->{topic} ($converted changes)\n";
	    unless ($inform_only) {
		eval {
		    $handler->_writeMe();
		};
		if ($@) {
		    print STDERR "Failed to write $handler->{web}.$handler->{topic} history. Existing history may be corrupt: $@";
		}
	    }
	}
    }

    # Convert .txt
    my $raw = $handler->readFile($handler->{file});
    $converted = _convert($raw);
    if ($converted) {
	print STDERR "Converted content of $handler->{web}.$handler->{topic}\n";
	$handler->saveFile($handler->{file}, $raw) unless $inform_only;
    }
}

# Convert the contents (*not* the names) of topics found in a web dir
sub convert_topics_contents {
    my $web = shift;
    my $dir;

    opendir($dir, "$Foswiki::cfg{DataDir}/$web") || die "Failed to open '$web' $!";
    foreach my $e (readdir($dir)) {
	next if $e =~ /^\./;
	if ($web && $e =~ /^(.*)\.txt$/) {
	    convert_topic($web, $1);
	} elsif (-d "$Foswiki::cfg{DataDir}/$web/$e"
		 && -e "$Foswiki::cfg{DataDir}/$web/$e/WebPreferences.txt") {
	    convert_topics_contents($web ? "$web/$e" : $e);
	}
    }
}

1;
