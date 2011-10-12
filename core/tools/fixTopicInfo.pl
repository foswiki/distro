#!perl

use strict;
use warnings;

# ------------------------------------------------------------------- #
# PERL - Fix Foswiki META TOPICINFO
# ------------------------------------------------------------------- #
# Parms: filename of file containing list of files to update.
#
# ------------------------------------------------------------------- #
# Notes:
#   - process topic.txt files, reset the TOPICINFO
#     1) Set topic version to 1.
#     2) Set format to 1.1  (Topics containing old encoded data are skipped)
#     3) Set author to ProjectContributor
#     4) Set date to the date of the last checkin to the topic.
#     5) Remove any reprev or comment
#
# pseudo-install default, and change to the root of the git checkout
# Following command will generate the input file
#  find core/data -name "*.txt" | xargs grep -l ^%META:TOPICINFO | grep -v TestCase  > topiclist
#
# The script will dereference symlinks.
#
# Run command with perl fixTopicInfo.pl -Icore/bin topiclist
#
# ------------------------------------------------------------------- #
#
BEGIN {
    unshift @INC, '.';
    require 'setlib.cfg';
}

use Foswiki::Time;
use Cwd qw( cwd);

my $a_fn  = shift(@ARGV);    #-- get file name
my $cntin = 0;

# ------------------------------------------------------------------- #
# get first list into array
# ------------------------------------------------------------------- #
open( my $fh, "<", $a_fn ) || die "<ERR> Opened Failed for Curr File ($a_fn)\n";
my @filelist = <$fh>;
close $fh;

print "Process New FIle list :\n";
print "   - Input file     => $a_fn\n";

my $curDir = Cwd::cwd();

#
foreach my $fn (@filelist) {
    chomp($fn);
    $cntin++;
    if ( -l $fn ) {
        print "... SYMLINK: ";
        my $lfn = readlink $fn;
        $lfn =~ s/$curDir/./;
        $fn = $lfn;
    }

    print "\nPROCESSING $fn\n";
    my ( $gitHash, $commitDate, $svnRev ) = getCommitInfo($fn);
    my $tdate   = Foswiki::Time::parseTime($commitDate);
    my $comment = "Last commit: git $gitHash, svn rev: $svnRev";
    rewriteInfo( $fn, $tdate, $comment );
}    #--end foreach
exit

  #
  # finish up
  #
  print "   - Input Records  => $cntin\n";

#
# Pull the most recent log record.  Return
#  ( Git hash, SVN Rev,  Commit Date )

sub getCommitInfo {
    my $path = shift;
    my @results;

    my $logMsg = `git log -1 --format=%h^%ci^%b $path`;
    my @info = split( /\^/, $logMsg );

    push( @results, $info[0] );
    my @dp = split( / /, $info[1] );
    push( @results,
            "$dp[0]T$dp[1]"
          . substr( $dp[2], 0, 3 ) . ':'
          . substr( $dp[2], 3, 2 ) );
    my ($svnRev) = $info[2] =~ m/git-svn-id:.*?@([0-9]+)\s/;
    push( @results, $svnRev );

    return @results;
}

#
# ------------------------------------------------------------------- #
# Read in the file and write out an updated TOPICINFO line
# ------------------------------------------------------------------- #
sub rewriteInfo {
    my ( $fn, $timestamp, $comment ) = @_;

    my $topicText;
    local $/ = undef;    # set to read to EOF
    if ( open( my $fh, '<', $fn ) ) {
        $topicText = <$fh>;
        close($fh);
    }

    if (   $topicText =~ m/^%META:TOPICINFO{.*format="1.0"/
        && $topicText =~ m/%_N_%|%_Q_%|%_P_%/ )
    {
        print "WARNING $fn contains old meta - bypassing topic\n";
        return;
    }

    # Replace version with 1
    $topicText =~ s/^(%META:TOPICINFO{.*version=").*?(".*}%)$/${1}1$2/m;
    $topicText =~ s/^(%META:TOPICINFO{.*format=").*?(".*}%)$/${1}1.1$2/m;
    $topicText =~
      s/^(%META:TOPICINFO{.*author=").*?(".*}%)$/${1}ProjectContributor$2/m;
    $topicText =~ s/^(%META:TOPICINFO{.*date=").*?(".*}%)$/${1}$timestamp$2/m;
    $topicText =~ s/^(%META:TOPICINFO{.*)( reprev=".*?")(.*}%)$/${1}$3/m
      if ( $topicText =~ m/^%META:TOPICINFO{.*reprev/ );
    $topicText =~ s/^(%META:TOPICINFO{.*)( comment=".*?")(.*}%)$/${1}$3/m
      if ( $topicText =~ m/^%META:TOPICINFO{.*comment/ );

    # Optional:  Set a topic comment with svn/git commit information
    #
    #if ( $topicText =~ m/^%META:TOPICINFO{.*comment="/ ) {
    #    $topicText =~
    #      s/^(%META:TOPICINFO{.*comment=").*?(".*}%)$/${1}$comment$2/m;
    #}
    #else {
    #    $topicText =~
    ##      s/^(%META:TOPICINFO{.*)( version=")/${1} comment="$comment"$2/m;
    #}

    open( my $fh, ">", $fn );
    binmode $fh;
    print $fh $topicText;
    close $fh;
}
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
