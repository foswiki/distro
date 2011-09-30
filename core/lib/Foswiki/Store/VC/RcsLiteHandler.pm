# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::VC::RcsLiteHandler

This class implements the pure methods of the Foswiki::Store::VC::Handler
superclass. See the superclass for detailed documentation of the methods.

For readers who are familiar with Foswiki version 1.0, this class
is analagous to the old =Foswiki::Store::RcsLite=.

Simple pure perl replacement for RCS. Doesn't support:
   * branches
   * locking

This module doesn't know anything about the content of the topic

There is one of these objects for each file stored under RcsLite.

This class is PACKAGE PRIVATE to Store, and should NEVER be
used from anywhere else.

---++ File format

<verbatim>
rcstext    ::=  admin {delta}* desc {deltatext}*
admin      ::=  head {num};
                { branch   {num}; }
                access {id}*;
                symbols {sym : num}*;
                locks {id : num}*;  {strict  ;}
                { comment  {string}; }
                { expand   {string}; }
                { newphrase }*
delta      ::=  num
                date num;
                author id;
                state {id};
                branches {num}*;
                next {num};
                { newphrase }*
desc       ::=  desc string
deltatext  ::=  num
                log string
                { newphrase }*
                text string
num        ::=  {digit | .}+
digit      ::=  0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
id         ::=  {num} idchar {idchar | num }*
sym        ::=  {digit}* idchar {idchar | digit }*
idchar     ::=  any visible graphic character except special
special    ::=  $ | , | . | : | ; | @
string     ::=  @{any character, with @ doubled}*@
newphrase  ::=  id word* ;
word       ::=  id | num | string | :
</verbatim>
Identifiers are case sensitive. Keywords are in lower case only. The
sets of keywords and identifiers can overlap. In most environments RCS
uses the ISO 8859/1 encoding: visible graphic characters are codes
041-176 and 240-377, and white space characters are codes 010-015 and 040.

Dates, which appear after the date keyword, are of the form Y.mm.dd.hh.mm.ss,
where Y is the year, mm the month (01-12), dd the day (01-31), hh the hour
(00-23), mm the minute (00-59), and ss the second (00-60). Y contains just
the last two digits of the year for years from 1900 through 1999, and all
the digits of years thereafter. Dates use the Gregorian calendar; times
use UTC.

The newphrase productions in the grammar are reserved for future extensions
to the format of RCS files. No newphrase will begin with any keyword already
in use.

Revisions consist of a sequence of 'a' and 'd' edits that need to be
applied to rev N+1 to get rev N. Each edit has an offset (number of lines
from start) and length (number of lines). For 'a', the edit is followed by
length lines (the lines to be inserted in the text). For example:

d1 3     means "delete three lines starting with line 1
a4 2     means "insert two lines at line 4'
xxxxxx   is the new line 4
yyyyyy   is the new line 5

=cut

package Foswiki::Store::VC::RcsLiteHandler;
use strict;
use warnings;

use Foswiki::Store::VC::Handler ();
our @ISA = ('Foswiki::Store::VC::Handler');

use Assert;
use Error qw( :try );

use Foswiki::Store   ();
use Foswiki::Sandbox ();

#
# As well as the field inherited from VC::Handler, the object for each file
# read consists of the following fields:
# head    - version number of head
# access  - the access field from the file
# symbols - the symbols field from the file
# comment - the comment field from the file
# desc    - the desc field from the file
# expand  - 'b' for binary, or 'o' for text
# author  - ref to array of version authors
# date    - ref to array of dates indexed by version number
# log     - ref to array of messages indexed by version
# delta   - ref to array of deltas indexed by version
# where   - 'nofile' if there is no ,v file, or a text string
#           representing the parse state when the parse finished.
#           If the parse was successful this will be 'parsed'.
#

# implements VC::Handler
sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    unless ( $this->{initialised} ) {
        $this->{initialised} = 1;
        $this->{head}        = 0;
        $this->{access}      = '';
        $this->{symbols}     = '';
        $this->{comment}     = '# ';     # Default comment for Rcs
        $this->{desc}        = 'none';
        initText($this);                 # Set default expand to 'o'
    }

    return $this;
}

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{state};
    undef $this->{head};
    undef $this->{access};
    undef $this->{symbols};
    undef $this->{comment};
    undef $this->{expand};
    undef $this->{revs};
    undef $this->{desc};
}

sub _readTo {
    my ( $file, $char ) = @_;
    my $buf = '';
    my $ch;
    my $space  = 0;
    my $string = '';
    my $state  = '';
    while ( read( $file, $ch, 1 ) ) {
        if ( $ch eq '@' ) {
            if ( $state eq '@' ) {
                $state = 'e';
                next;
            }
            elsif ( $state eq 'e' ) {
                $state = '@';
                $string .= '@';
                next;
            }
            else {
                $state = '@';
                next;
            }
        }
        else {
            if ( $state eq 'e' ) {
                $state = '';
                if ( $char eq '@' ) {
                    last;
                }

                # End of string
            }
            elsif ( $state eq '@' ) {
                $string .= $ch;
                next;
            }
        }
        if ( $ch =~ /\s/ ) {
            if ( length($buf) == 0 ) {
                next;
            }
            elsif ($space) {
                next;
            }
            else {
                $space = 1;
                $ch    = ' ';
            }
        }
        else {
            $space = 0;
        }
        $buf .= $ch;
        if ( $ch eq $char ) {
            last;
        }
    }
    return ( $buf, $string );
}

# Make sure RCS file has been read in and there is history
sub _ensureProcessed {
    my ($this) = @_;

    return if $this->{state};

    if ( !-e $this->{rcsFile} ) {
        $this->{state} = 'nocommav';
        return;
    }
    my $fh;
    unless ( open( $fh, '<', $this->{rcsFile} ) ) {
        warn( 'Failed to open ' . $this->{rcsFile} );
        $this->{state} = 'nocommav';
        return;
    }
    binmode($fh);
    my $state   = 'admin.head';
    my $term    = ';';
    my $string  = '';
    my $num     = '';
    my $headNum = 0;
    my @revs    = ();
    my $dnum    = '';

    while (1) {
        ( $_, $string ) = _readTo( $fh, $term );
        last if ( !$_ );

        if ( $state eq 'admin.head' ) {
            if (/^head\s+([0-9]+)\.([0-9]+);$/o) {
                ASSERT( $1 eq 1 ) if DEBUG;
                $headNum = $2;
                $state   = 'admin.access';    # Don't support branches
            }
            else {
                last;
            }
        }
        elsif ( $state eq 'admin.access' ) {
            if (/^access\s*(.*);$/) {
                $state = 'admin.symbols';
                $this->{access} = $1;
            }
            else {
                last;
            }
        }
        elsif ( $state eq 'admin.symbols' ) {
            if (/^symbols(.*);$/) {
                $state = 'admin.locks';
                $this->{symbols} = $1;
            }
            else {
                last;
            }
        }
        elsif ( $state eq 'admin.locks' ) {
            if (/^locks.*;$/) {
                $state = 'admin.postLocks';
            }
            else {
                last;
            }
        }
        elsif ( $state eq 'admin.postLocks' ) {
            if (/^strict\s*;/) {
                $state = 'admin.postStrict';
            }
        }
        elsif ( $state eq 'admin.postStrict'
            && /^comment\s.*$/ )
        {
            $state = 'admin.postComment';
            $this->{comment} = $string;
        }
        elsif (
            ( $state eq 'admin.postStrict' || $state eq 'admin.postComment' )
            && /^expand\s/ )
        {
            $state = 'admin.postExpand';
            $this->{expand} = $string;
        }
        elsif ($state eq 'admin.postStrict'
            || $state eq 'admin.postComment'
            || $state eq 'admin.postExpand'
            || $state eq 'delta.date' )
        {
            if (/^([0-9]+)\.([0-9]+)\s+date\s+(\d\d(\d\d)?(\.\d\d){5}?);$/) {
                $state = 'delta.author';
                $num   = $2;
                require Foswiki::Time;
                $revs[$num]->{date} = Foswiki::Time::parseTime($3);
            }
        }
        elsif ( $state eq 'delta.author' ) {
            if (/^author\s+(.*);$/) {
                $revs[$num]->{author} = $1;
                if ( $num == 1 ) {
                    $state = 'desc';
                    $term  = '@';
                }
                else {
                    $state = 'delta.date';
                }
            }
        }
        elsif ( $state eq 'desc' ) {
            if (/desc\s*$/) {
                $this->{desc} = $string;
                $state = 'deltatext.log';
            }
        }
        elsif ( $state eq 'deltatext.log' ) {
            if (/\d+\.(\d+)\s+log\s+$/) {
                $dnum = $1;
                $string =~ s/\n*$//o;
                $revs[$dnum]->{log} = $string;
                $state = 'deltatext.text';
            }
        }
        elsif ( $state eq 'deltatext.text' ) {
            if (/text\s*$/) {
                $state = 'deltatext.log';
                $revs[$dnum]->{text} = $string;
                if ( $dnum == 1 ) {
                    $state = 'parsed';
                    last;
                }
            }
        }
    }

    unless ( $state eq 'parsed' ) {
        warn( $this->{rcsFile} . ' is corrupt; parsed up to ' . $state );

        #ASSERT(0) if DEBUG;
        $headNum = 0;
        $state   = 'nocommav';    # ignore the RCS file; graceful recovery
    }

    $this->{head}  = $headNum;
    $this->{state} = $state;
    $this->{revs}  = \@revs;

    close($fh);
}

sub _formatString {
    my ($str) = @_;
    $str ||= '';
    $str =~ s/@/@@/go;
    return '@' . $str . '@';
}

# Write content of the RCS file
sub _write {
    my ( $this, $file ) = @_;

    # admin
    my $nr = $this->{head} || 1;
    print $file <<HERE;
head	1.$nr;
access$this->{access};
symbols$this->{symbols};
locks; strict;
HERE
    print $file 'comment', "\t", _formatString( $this->{comment} ), ';', "\n";
    if ( $this->{expand} ) {
        print $file 'expand', "\t", _formatString( $this->{expand} ),
          ';' . "\n";
    }

    print $file "\n";

    # most recent rev first
    for ( my $i = $this->{head} ; $i > 0 ; $i-- ) {
	my $d       = $this->{revs}[$i]->{date};
	if (defined $d) {
	    if ($i < $this->{head}) {
		print $file 'next', "\t";
		print $file '1.', $i;
		print $file ";\n";
	    }
	    my $rcsDate = Foswiki::Store::VC::Handler::_epochToRcsDateTime($d);
	    print $file <<HERE;

1.$i
date	$rcsDate;	author $this->{revs}[$i]->{author};	state Exp;
branches;
HERE
	}
    }
    print $file 'next', "\t";
    print $file ";\n";

    print $file "\n\n", 'desc', "\n",
      _formatString( $this->{desc} . "\n" ) . "\n\n";

    for ( my $i = $this->{head} ; $i > 0 ; $i-- ) {
        print $file "\n", '1.', $i, "\n",
          'log', "\n", _formatString( $this->{revs}[$i]->{log} ),
          "\n", 'text', "\n", _formatString( $this->{revs}[$i]->{text} ),
          "\n" . ( $i == 1 ? '' : "\n" );
    }
    $this->{state} = 'parsed';    # now known clean
}

# implements VC::Handler
sub initBinary {
    my ($this) = @_;

    # Nothing to be done but note for re-writing
    $this->{expand} = 'b';
}

# implements VC::Handler
sub initText {
    my ($this) = @_;

    # Nothing to be done but note for re-writing
    $this->{expand} = 'o';
}

# implements VC::Handler
sub _numRevisions {
    my ($this) = @_;
    _ensureProcessed($this);

    # if state is nocommav, and the file exists, there is only one revision
    if ( $this->{state} eq 'nocommav' ) {
        return 1 if ( -e $this->{file} );
        return 0;
    }
    return $this->{head};
}

sub ci {
    my ( $this, $isStream, $data, $log, $author, $date ) = @_;

    _ensureProcessed($this);

    if ($isStream) {
        $this->saveStream($data);

        # SMELL: for big attachments, this is a dog
        $data = $this->readFile( $this->{file} );
    }
    else {
        $this->saveFile( $this->{file}, $data );
    }
    my $head = $this->{head} || 0;
    if ($head) {
        my $lNew  = _split($data);
        my $lOld  = _split( $this->{revs}[$head]->{text} );
        my $delta = _diff( $lNew, $lOld );
        $this->{revs}[$head]->{text} = $delta;
    }
    $head++;
    $this->{revs}[$head]->{text}   = $data;
    $this->{head}                  = $head;
    $this->{revs}[$head]->{log}    = $log;
    $this->{revs}[$head]->{author} = $author;
    $this->{revs}[$head]->{date}   = ( defined $date ? $date : time() );

    _writeMe($this);
}

sub _writeMe {
    my ($this) = @_;
    my $out;

    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{rcsFile} );
    unless ( open( $out, '>', $this->{rcsFile} ) ) {
        throw Error::Simple(
            'Cannot open ' . $this->{rcsFile} . ' for write: ' . $! );
    }
    else {
        binmode($out);
        _write( $this, $out );
        close($out);
    }
    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{rcsFile} );
}

# implements VC::Handler
sub repRev {
    my ( $this, $text, $comment, $user, $date ) = @_;
    _ensureProcessed($this);
    _delLastRevision($this);
    return $this->ci( 0, $text, $comment, $user, $date );
}

# implements VC::Handler
sub deleteRevision {
    my ($this) = @_;
    _ensureProcessed($this);

    # Can't delete revision 1
    return unless $this->{head} > 1;
    _delLastRevision($this);
    _writeMe($this);
}

sub _delLastRevision {
    my ($this) = @_;
    my $numRevisions = $this->{head};
    return unless $numRevisions;
    $numRevisions--;
    my ($lastText) = $this->getRevision($numRevisions);
    $this->{revs}[$numRevisions]->{text} = $lastText;
    $this->{head} = $numRevisions;
    Foswiki::Store::VC::Handler::saveFile( $this, $this->{file}, $lastText );
}

# implements VC::Handler
# Recovers the two revisions and uses sdiff on them. Simplest way to do
# this operation.
# rev1 is the lower, rev2 is the higher revision
sub revisionDiff {
    my ( $this, $rev1, $rev2, $contextLines ) = @_;
    my @list;
    _ensureProcessed($this);
    my ($text1) = $this->getRevision($rev1);
    my ($text2) = $this->getRevision($rev2);

    my $lNew = _split($text1);
    my $lOld = _split($text2);
    require Algorithm::Diff;
    my $diff = Algorithm::Diff::sdiff( $lNew, $lOld );

    foreach my $ele (@$diff) {
        push @list, $ele;
    }
    return \@list;
}

# implements VC::Handler
sub getInfo {
    my ( $this, $version ) = @_;

    _ensureProcessed($this);
    my $info;
    if ( $this->{state} ne 'nocommav') {
        if ( !$version || $version > $this->{head} ) {
            $version = $this->{head} || 1;
        }
        $info = {
            version => $version,
            date    => $this->{revs}[$version]->{date},
            author  => $this->{revs}[$version]->{author},
            comment => $this->{revs}[$version]->{log}
        };
	# We have to check that there is not a pending version in the .txt
	unless ($this->noCheckinPending()) {
	    # There's a pending version in the .txt
	    $info->{version}++;
	    $info->{author} = $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;
	    $info->{comment} = "pending";
	    $info->{date} = time();
	}
    }
    else {
        $info = $this->SUPER::getInfo($version);
    }
    return $info;
}

# Apply delta (patch) to text.  Note that RCS stores reverse deltas,
# so the text for revision x is patched to produce text for revision x-1.
sub _patch {

    # Both params are references to arrays
    my ( $text, $delta ) = @_;
    my $adj = 0;
    my $pos = 0;
    my $max = $#$delta;
    while ( $pos <= $max ) {
        my $d = $delta->[$pos];
        if ( $d =~ /^([ad])(\d+)\s(\d+)$/ ) {
            my $act    = $1;
            my $offset = $2;
            my $length = $3;
            if ( $act eq 'd' ) {
                my $start = $offset + $adj - 1;
                my @removed = splice( @$text, $start, $length );
                $adj -= $length;
                $pos++;
            }
            elsif ( $act eq 'a' ) {
                my @toAdd = @$delta[ $pos + 1 .. $pos + $length ];

                # Fix for Item2957
                # Check if the last element of what is to be added contains
                # a valid marker. If it does, the chances are very high that
                # this topic was saved using a broken version of RcsLite, and
                # a line ending has been lost.
                # As soon as a topic containing this problem is re-saved
                # using this code, the need for this hack should go away,
                # as the line endings will now be correct.
                if (   scalar(@toAdd)
                    && $toAdd[$#toAdd] =~ /^([ad])(\d+)\s(\d+)$/
                    && $2 > $pos )
                {
                    pop(@toAdd);
                    push( @toAdd, <<'HERE');
<div class="foswikiAlert">WARNING: THIS TEXT WAS ADDED BY THE SYSTEM TO CORRECT A PROBABLE ERROR IN THE HISTORY OF THIS TOPIC.</div>
HERE
                    $pos--;   # so when we add $length we get to the right place
                }
                splice( @$text, $offset + $adj, 0, @toAdd );

                $adj += $length;
                $pos += $length + 1;
            }
        }
        else {
            last;
        }
    }
}

# implements VC::Handler
sub getRevision {
    my ( $this, $version ) = @_;

    return $this->SUPER::getRevision($version) unless $version;

    _ensureProcessed($this);

    return $this->SUPER::getRevision($version)
      if $this->{state} eq 'nocommav';

    my $head = $this->{head};
    return $this->SUPER::getRevision($version) unless $head;
    if ( $version == $head ) {
        return ($this->{revs}[$version]->{text}, 1);
    }
    $version = $head if $version > $head;
    my $headText = $this->{revs}[$head]->{text};
    my $text     = _split($headText);
    return (_patchN( $this, $text, $head - 1, $version ), 0);
}

# Apply reverse diffs until we reach our target rev
sub _patchN {
    my ( $this, $text, $version, $target ) = @_;

    while ( $version >= $target ) {
        my $deltaText = $this->{revs}[ $version-- ]->{text};
        my $delta     = _split($deltaText);
        _patch( $text, $delta );
    }
    return join( "\n", @$text );
}

# Split a string on \n making sure we have all newlines. If the string
# ends with \n there will be a '' at the end of the split.
sub _split {

    #my $text = shift;

    my @list = ();
    return \@list unless defined $_[0];

    my $nl = 1;
    foreach my $i ( split( /(\n)/o, $_[0] ) ) {
        if ( $i eq "\n" ) {
            push( @list, '' ) if $nl;
            $nl = 1;
        }
        else {
            push( @list, $i );
            $nl = 0;
        }
    }
    push( @list, '' ) if ($nl);

    return \@list;
}

# Extract the differences between two arrays of lines, returning a string
# of differences in RCS difference format.
sub _diff {
    my ( $new, $old ) = @_;
    require Algorithm::Diff;
    my $diffs = Algorithm::Diff::diff( $new, $old );

    #print STDERR "DIFF '",join('\n',@$new),"' and '",join('\n',@$old),"'\n";
    # Convert the differences to RCS format
    my $adj   = 0;
    my $out   = '';
    my $start = 0;
    foreach my $chunk (@$diffs) {
        my $count++;
        my $chunkSign;
        my @lines = ();
        foreach my $line (@$chunk) {
            my ( $sign, $pos, $what ) = @$line;

            #print STDERR "....$sign $pos $what\n";
            if ( $chunkSign && $chunkSign ne $sign ) {
                $adj += _addChunk( $chunkSign, \$out, \@lines, $start, $adj );
            }
            if ( !@lines ) {
                $start = $pos;
            }
            $chunkSign = $sign;
            push( @lines, $what );
        }

        $adj += _addChunk( $chunkSign, \$out, \@lines, $start, $adj );
    }

    #print STDERR "CONVERTED\n",$out,"\n";
    return $out;
}

# Add a hunk of differences, returning the total number of lines in the
# text
sub _addChunk {
    my ( $chunkSign, $out, $lines, $start, $adj ) = @_;

    my $nLines = scalar(@$lines);
    if ( $nLines > 0 ) {
        $$out .= "\n" if ( $$out && $$out !~ /\n$/o );
        if ( $chunkSign eq '+' ) {

            # Added "\n" at end to correct Item2957
            $$out .= 'a'
              . ( $start - $adj ) . ' '
              . $nLines . "\n"
              . join( "\n", @$lines ) . "\n";
        }
        else {

            # Added "\n" at end to correct Item945
            $$out .= 'd' . ( $start + 1 ) . ' ' . $nLines . "\n";
            $nLines *= -1;
        }
        @$lines = ();
    }
    return $nLines;
}

# implements VC::Handler
sub getRevisionAtTime {
    my ( $this, $date ) = @_;

    _ensureProcessed($this);
    if ($this->{state} eq 'nocommav') {
 	return ($date >= (stat($this->{file}))[9]) ? 1 : undef;
   }

    my $version = $this->{head};
    while ( $this->{revs}[$version]->{date} > $date ) {
        $version--;
        return undef if $version == 0;
    }

    if ($version == $this->{head} && !$this->noCheckinPending()) {
	# Check the file date
	$version++ if ($date >= (stat($this->{file}))[9]);
    }
    return $version;
}

sub stringify {
    my $this = shift;

    my $s = $this->SUPER::stringify();
    $s .= " access=$this->{access}"   if $this->{access};
    $s .= " symbols=$this->{symbols}" if $this->{symbols};
    $s .= " comment=$this->{comment}" if $this->{comment};
    $s .= " expand=$this->{expand}"   if $this->{expand};
    $s .= " [";
    if ( $this->{head} ) {
        for ( my $i = $this->{head} ; $i > 0 ; $i-- ) {
            $s .= "\tRev $i : { d=$this->{revs}[$i]->{date}";
            $s .= " l=$this->{revs}[$i]->{log}";
            $s .= " t=$this->{revs}[$i]->{text}}\n";
        }
    }
    return "$s]\n";
}

1;
__END__

Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some of the code in this file, as follows

Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
Copyright (C) 2001-2008 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
