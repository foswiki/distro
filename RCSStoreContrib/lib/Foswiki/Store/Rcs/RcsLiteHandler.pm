# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::Rcs::RcsLiteHandler

This class implements the pure methods of the Foswiki::Store::Rcs::Handler
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
041-176 and 240-377, and white space characters are codes 010-015 and
040.

Dates, which appear after the date keyword, are of the form
Y.mm.dd.hh.mm.ss, where Y is the year, mm the month (01-12), dd the
day (01-31), hh the hour (00-23), mm the minute (00-59), and ss the
second (00-60). Y contains just the last two digits of the year for
years from 1900 through 1999, and all the digits of years
thereafter. Dates use the Gregorian calendar; times use UTC.

The newphrase productions in the grammar are reserved for future
extensions to the format of RCS files. No newphrase will begin with
any keyword already in use.

The head of the revisions array contains the plain text of the file in
it's most recent incarnation.

Earlier revisions consist of a sequence of 'a' and 'd' edits that need
to be applied to rev N+1 to get rev N. Each edit has an offset (number
of lines from start) and length (number of lines). For 'a', the edit
is followed by length lines (the lines to be inserted in the
text). For example:

d1 3     means "delete three lines starting with line 1
a4 2     means "insert two lines at line 4'
xxxxxx   is the new line 4
yyyyyy   is the new line 5

Edits are applied sequentially i.e. edits are relative to the text as
it exists after the previous edit has been applied.

=cut

package Foswiki::Store::Rcs::RcsLiteHandler;
use strict;
use warnings;

use Foswiki::Store::Rcs::Store   ();
use Foswiki::Store::Rcs::Handler ();
our @ISA = ('Foswiki::Store::Rcs::Handler');

use Assert;
use Error qw( :try );

use Foswiki::Store   ();
use Foswiki::Sandbox ();

# SMELL: This code uses the log field for the checkin comment. This
# field is alongside the actual text of the revision, and is not
# recorded in the history. This is a PITA because it means the comment
# field can't be retrieved without reading up to the text change for the
# version requested - even though foswiki doesn't actually use that part
# of the info record for anything much. We could rework the store API to
# separate the log info, but it would be a lot of work. Using this
# constant you can ignore the log info in getInfo calls. The tests will
# fail, but the code will run faster.
use constant CAN_IGNORE_COMMENT => 0;    # 1

#
# As well as the fields inherited from Rcs::Handler, the object for each file
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

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    *_decode = \&Foswiki::Store::decode;
    *_encode = \&Foswiki::Store::encode;
}

# implements Rcs::Handler
sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    unless ( $this->{initialised} ) {
        $this->{initialised} = 1;
        $this->{state}       = 'admin.head';
        $this->{head}        = 0;
        $this->{access}      = '';
        $this->{symbols}     = '';
        $this->{comment}     = '# ';           # Default comment for Rcs
        $this->{desc}        = 'none';
        initText($this);                       # Set default expand to 'o'
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

my %is_space = ( ' ' => 1, "\t" => 1, "\n" => 1, "\r" => 1 );

sub _readTo {
    my ( $file, $term ) = @_;
    my $buf = '';
    my $ch;
    my $space  = 1;   # there's a pseudo-newline before every new token
    my $string = '';
    my $state  = 0;   # 0 = looking for @, 1 = reading string, 2 = seen second @

    while ( read( $file, $ch, 1 ) ) {

        if ( $ch eq '@' ) {
            if ( $state == 1 ) {    # if $state eq '@'
                $state = 2;         #     $state = 'e'
            }
            elsif ( $state == 2 ) {    # elsif $state eq 'e'
                $state = 1;            #     $state = '@'
                $string .= '@';
            }
            else {
                $state = 1;            #     $state = '@'
            }
            next;
        }

        if ( $state == 2 ) {           # if $state eq 'e'
            $state = 0;                #     $state = ''
            last if ( $term eq '@' );  # End of string
        }
        elsif ( $state == 1 ) {        # if $state eq '@'
            $string .= $ch;
            next;
        }

        if ( $is_space{$ch} ) {
            unless ($space) {
                $buf .= ' ';
                $space = 1;
            }
        }
        else {
            $space = 0;
            $buf .= $ch;
            last if ( $ch eq $term );
        }
    }

    return ( $buf, $string );
}

# Ensure a ,v file is read. If $historyOnly is true, will only require
# the history to be read; if it's false, the entire file (including
# all changes) is required. If $upToVersion is set, then data will be
# read up to and including that version, but no more. Thus:
#
# $downToVersion 0, $historyOnly=1
#     Only the history for the head version will be read
# $downToVersion -1, $historyOnly = 1
#     Entire history will be read
# $downToVersion N, $historyOnly=1
#     Only the history will be read, up to version
# $downToVersion 0, $historyOnly=0
#     The entire history and the text for the head version will be read
# $downToVersion -1, $historyOnly = 0
#     Entire history and entire text will be read
# $downToVersion N, $historyOnly=0
#     Entire history and text for versions up to and including N will be read
#
# Common signatures are:
# (0, 1) read the history for the most recent version only
# (0, 0) read everything for the most recent version
# (-1, 1) read the entire history but no text
# (-1, 0) read the entire history and text
# ($N, 0) read everything down to version N

sub _ensureRead {
    my ( $this, $downToVersion, $historyOnly ) = @_;

    return
         if $this->{state} eq 'parsed'
      || $this->{state} eq 'nocommav'
      || ( $historyOnly && $this->{state} eq 'desc' );

    $downToVersion ||= 0;    # just in case

    # If we only need the latest and we already have the head, that's our rev
    $downToVersion = $this->{head} if ( !$downToVersion && $this->{head} );

    $downToVersion = 1 if $downToVersion < 0;    # read everything

    if ($downToVersion) {

        # Don't read if we already have the info
        if ( defined $this->{revs}->[$downToVersion] ) {
            return
              if $historyOnly || defined $this->{revs}->[$downToVersion]->{log};
        }
    }

    my $fh;
    unless ( open( $fh, '<', _encode( $this->{rcsFile}, 1 ) ) ) {

        #warn( 'Failed to open ' . $this->{rcsFile} . ': ' . $!);
        $this->{state} = 'nocommav';
        return;
    }
    binmode($fh);

    my $state   = 'admin.head';    # reset to start
    my $term    = ';';
    my $string  = '';
    my $num     = '';
    my $headNum = 0;
    my @revs    = ();
    my $dnum    = '';

    # We *will* end up re-reading the history if we previously only
    # read the history; there is no way to restart the parse mid-stream
    # (though an ftell and fseek would do it if we saved the rest of the
    # state)
    while (1) {
        ( $_, $string ) = _readTo( $fh, $term );
        last if ( !$_ );

        if ( $state eq 'admin.head' ) {
            if (/^head\s+([0-9]+)\.([0-9]+);$/) {
                ASSERT( $1 eq 1 ) if DEBUG;
                $headNum = $2;

                # If $downToVersion is 0, we now know what version to read up to
                $downToVersion = $headNum
                  if $downToVersion <= 0
                  || $downToVersion > $headNum;

                $state = 'admin.access';    # Don't support branches
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
            if (/^([0-9]+)\.([0-9]+)\s+date\s+(\d\d(\d\d)?(\.\d\d){5});$/) {
                $state = 'delta.author';
                $num   = $2;
                last if $historyOnly && $num < $downToVersion;
                require Foswiki::Time;
                $revs[$num]->{date} = Foswiki::Time::parseTime($3);
            }
        }
        elsif ( $state eq 'delta.author' ) {
            if (/^author\s+(.*);$/) {
                $revs[$num]->{author} = $1 || '';
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
                last if $historyOnly;
                $this->{desc} = $string;
                $state = 'deltatext.log';
            }
        }
        elsif ( $state eq 'deltatext.log' ) {
            if (/\d+\.(\d+)\s+log\s+$/) {
                $dnum = $1;
                last if $dnum < $downToVersion;
                $string =~ s/\n*$//o;
                $revs[$dnum]->{log} = $string;
                $state = 'deltatext.text';
            }
        }
        elsif ( $state eq 'deltatext.text' ) {
            if (/text\s*$/) {
                $state = 'deltatext.log';

                # SMELL: This is an hack to repair corrupt history. It
                # detects the situation where a diff has been fed as
                # the text to _diff - it's unclear how this happens,
                # or if indeed it still happens. The most recent
                # instance we have of it is on 1.1.9, but there is
                # insufficient information to reproduce it. Note this
                # repair will stick after the next time the topic is
                # saved.
                if ( $string =~ s/^d\d+ \d+\na\d+ \d+\n([ad]\d+ \d+\n)/$1/s ) {
                    print STDERR
"WARNING: Potentially corrupt RCS history $this->{file} at revision $dnum appears to be a diff of diffs, and has been repaired\n";
                }
                $revs[$dnum]->{text} = $string;
                if ( $dnum == 1 ) {
                    $state = 'parsed';
                    last;
                }
            }
        }
    }

    unless ( $state eq 'parsed'
        || $historyOnly  && $num < $downToVersion
        || !$historyOnly && $dnum < $downToVersion
        || $historyOnly  && $state eq 'desc' )
    {
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
        my $d = $this->{revs}[$i]->{date};
        if ( defined $d ) {
            if ( $i < $this->{head} ) {
                print $file 'next', "\t";
                print $file '1.',   $i;
                print $file ";\n";
            }
            my $rcsDate = Foswiki::Store::Rcs::Handler::_epochToRcsDateTime($d);
            print $file <<HERE;

1.$i
date	$rcsDate;	author $this->{revs}[$i]->{author};	state Exp;
branches;
HERE
        }
    }
    print $file 'next', "\t";
    print $file ";\n";

    print $file "\n\n", 'desc', "\n", _formatString( $this->{desc} ) . "\n\n";

    for ( my $i = $this->{head} ; $i > 0 ; $i-- ) {
        print $file "\n", '1.', $i, "\n",
          'log', "\n", _formatString( $this->{revs}[$i]->{log} ),
          "\n", 'text', "\n", _formatString( $this->{revs}[$i]->{text} ),
          "\n" . ( $i == 1 ? '' : "\n" );
    }
    $this->{state} = 'parsed';    # now known clean
}

# implements Rcs::Handler
sub initBinary {
    my ($this) = @_;

    # Nothing to be done but note for re-writing
    $this->{expand} = 'b';
}

# implements Rcs::Handler
sub initText {
    my ($this) = @_;

    # Nothing to be done but note for re-writing
    $this->{expand} = 'o';
}

# implements Rcs::Handler
sub _numRevisions {
    my ($this) = @_;

    $this->_ensureRead( 0, 1 );    # min read

    # if state is nocommav, and the file exists, there is only one revision
    if ( $this->{state} eq 'nocommav' ) {
        return 1 if $this->storedDataExists();
        return 0;
    }
    return $this->{head};
}

sub ci {
    my ( $this, $isStream, $data, $log, $author, $date ) = @_;

    # If the author is null, then we get a corrupt ,v
    ASSERT($author) if DEBUG;

    $this->_ensureRead( -1, 0 );    # read all of everything

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
        my $lNew = _split($data);
        # Head rev is always plain text
        my $lOld = _split( $this->{revs}[$head]->{text} );
        my $delta = _diff( $lNew, $lOld );

        # No longer the head ref, it's now delta
        $this->{revs}[$head]->{text} = $delta;
    }
    $head++;

    # New head rev is plain text
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

    chmod(
        $Foswiki::cfg{Store}{filePermission},
        _encode( $this->{rcsFile}, 1 )
    );
    unless ( open( $out, '>', _encode( $this->{rcsFile}, 1 ) ) ) {
        throw Error::Simple(
            'Cannot open ' . $this->{rcsFile} . ' for write: ' . $! );
    }
    else {
        binmode($out);
        _write( $this, $out );
        close($out);
    }
    chmod(
        $Foswiki::cfg{Store}{filePermission},
        _encode( $this->{rcsFile}, 1 )
    );
}

# implements Rcs::Handler
sub repRev {
    my ( $this, $text, $comment, $user, $date ) = @_;
    $this->_ensureRead( -1, 0 );

    # If the head is rev 1, simply rewrite
    if ( $this->{head} == 1 ) {
        $this->saveFile( $this->{file}, $text );
        $this->{revs}[1]->{text}   = $text;
        $this->{revs}[1]->{log}    = $comment;
        $this->{revs}[1]->{author} = $user;
        $this->{revs}[1]->{date}   = ( defined $date ? $date : time() );

        _writeMe($this);
    }
    else {
        # otherwise delete the latest rev and check in a new one
        _delLastRevision($this);
        return $this->ci( 0, $text, $comment, $user, $date );
    }
}

# implements Rcs::Handler
sub deleteRevision {
    my ($this) = @_;
    $this->_ensureRead( -1, 0 );

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

    # Recover plain text of prev rev
    my ( $lastText, $isl ) = $this->getRevision($numRevisions);
    ASSERT( !$isl, "NR $numRevisions HD $this->{head}" ) if DEBUG;
    $this->{revs}[$numRevisions]->{text} = $lastText;
    $this->{head} = $numRevisions;
    $this->saveFile( $this->{file}, $lastText );
}

# implements Rcs::Handler
# Recovers the two revisions and uses sdiff on them. Simplest way to do
# this operation.
# rev1 is the lower, rev2 is the higher revision
sub revisionDiff {
    my ( $this, $rev1, $rev2, $contextLines ) = @_;
    my @list;

    my ($text1) = $this->getRevision($rev1);
    my ($text2) = $this->getRevision($rev2);

    # prevent diffing TOPICINFO
    $text1 =~ s/^%META:TOPICINFO\{(.*)\}%\n//m;
    $text2 =~ s/^%META:TOPICINFO\{(.*)\}%\n//m;

    my $lNew = _split($text1);
    my $lOld = _split($text2);
    require Algorithm::Diff;
    my $diff = Algorithm::Diff::sdiff( $lNew, $lOld );

    foreach my $ele (@$diff) {
        push @list, $ele;
    }
    return \@list;
}

# implements Rcs::Handler
sub getInfo {
    my ( $this, $version ) = @_;

    $this->_ensureRead( $version, CAN_IGNORE_COMMENT );

    if (   ( $this->noCheckinPending() )
        && ( !$version || $version > $this->_numRevisions() ) )
    {
        $version = $this->_numRevisions();
    }
    else {
        $version = $this->_numRevisions() + 1
          unless ( $version && $version <= $this->_numRevisions() );
    }

    my $info;
    if ( $version <= $this->{head} ) {
        if ( $this->{state} ne 'nocommav' ) {
            if ( !$version || $version > $this->{head} ) {
                $version = $this->{head} || 1;
            }
            $info = {
                version => $version,
                date    => $this->{revs}[$version]->{date},
                author  => $this->{revs}[$version]->{author},
                comment => $this->{revs}[$version]->{log}
            };
            return $info;
        }
    }
    return $this->SUPER::getInfo($version);
}

# Apply delta (patch) to text
# \@text reference to array of text lines
# \@delta reference to aray of edits
# $rev the revision we're building (for debug only)
sub _patch {
    my ( $this, $text, $delta, $rev ) = @_;
    local $SIG{__WARN__} = sub {
        print STDERR
"WARNING: Potentially corrupt RCS history $this->{file} at revision $rev: "
          . shift(@_) . "\n";
    };

    my $adj       = 0;
    my $delta_i   = 0;
    my $delta_max = $#$delta;

    while ( $delta_i <= $delta_max ) {
        my $d = $delta->[$delta_i];
        if ( $d =~ /^([ad])(\d+)\s(\d+)$/ ) {
            my $act    = $1;
            my $offset = $2;
            my $length = $3;
            if ( $act eq 'd' ) {
                my $start = $offset + $adj - 1;

                # If the splice fails, it's almost certainly a problem in the
                # later revision
                if ( $start + $length > scalar(@$text) ) {

                    # Skip it?
                    warn "Underflow at $d, only "
                      . scalar(@$text)
                      . " available";
                    $length = scalar(@$text) - $start;
                }
                my @removed = splice( @$text, $start, $length );
                $adj -= $length;
                $delta_i++;
            }
            elsif ( $act eq 'a' ) {
                my @toAdd = @$delta[ $delta_i + 1 .. $delta_i + $length ];

                # Fixes for twikibug Item2957
                # Check if the last element of what is to be
                # added contains a valid marker. If it does, the chances
                # are very high that this topic was saved using a broken
                # version of RcsLite, and a line ending has been lost.
                # As soon as a topic containing this problem is re-saved
                # using this code, the need for this hack should go away,
                # as the line endings will now be correct.
                # If the first element contains a valid marker this is
                # also indicative  of a problem, but it's unclear how to
                # resolve that as the cause is unknown.
                if (   scalar(@toAdd)
                    && $toAdd[$#toAdd] =~ /^([ad])(\d+)\s(\d+)$/
                    && $2 > $delta_i )
                {
                    ASSERT(0) if DEBUG;
                    pop(@toAdd);
                    push( @toAdd, <<'HERE');
<div class="foswikiAlert">WARNING: THIS TEXT WAS ADDED BY THE SYSTEM TO CORRECT A PROBABLE ERROR IN THE HISTORY OF THIS TOPIC.</div>
HERE
                    $delta_i
                      --;    # so when we add $length we get to the right place
                }
                splice( @$text, $offset + $adj, 0, @toAdd );

                $adj += $length;
                $delta_i += $length + 1;
            }
        }
        else {
            # Potentially corrupt delta?
            ASSERT( !$d, $d ) if DEBUG;
            last;
        }
    }
}

# implements Rcs::Handler
sub getRevision {
    my ( $this, $version ) = @_;

    $version = 0 if !$version || $version < 0;

    # If !$version always get latest (which may not be checked in yet)
    unless ($version) {
        return ( $this->readFile( $this->{file} ), 1 )
          if $this->storedDataExists();

        # If there's no stored data, fall through to use the the
        # head of the ,v
    }

    # Make sure we're read up to the target version
    $this->_ensureRead( $version, 0 );

    # If there's no history, return latest
    if ( $this->{state} eq 'nocommav' || !$this->{head} ) {
        return ( $this->readFile( $this->{file} ), 1 )
          if $this->storedDataExists();
        die "Cannot getRevision($version) of non-existant $this->{file}";
    }

    my $head     = $this->{head};
    my $headText = $this->{revs}[$head]->{text};

    # If we're undecided or above the history, return the (possibly
    # unchecked-in) head
    if ( $version <= 0 || $version > $head ) {
        return ( $this->readFile( $this->{file} ), 1 )
          if ( $this->storedDataExists() );

        # No file, so return the head
        $version = $head;
    }

    # Head version is the top plain text
    return ( $headText, 1 ) if $version == $head;

    # Otherwise we need to unwrap deltas
    my $lines   = _split($headText);
    my $cur_ver = $head;

    # Apply reverse diffs until we reach our target rev
    while ( $cur_ver > $version ) {
        my $deltaText = $this->{revs}[ --$cur_ver ]->{text};
        $this->_patch( $lines, _split($deltaText), $cur_ver );
    }
    return ( join( "\n", @$lines ), 0 );
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

# implements Rcs::Handler
sub getRevisionAtTime {
    my ( $this, $date ) = @_;

    $this->_ensureRead( -1, 1 );    # read history only
    if ( $this->{state} eq 'nocommav' ) {
        return ( $date >= ( stat( _encode( $this->{file}, 1 ) ) )[9] )
          ? 1
          : undef;
    }

    my $version = $this->{head};
    while ( $this->{revs}[$version]->{date} > $date ) {
        $version--;
        return undef if $version == 0;
    }

    if ( $version == $this->{head} && !$this->noCheckinPending() ) {

        # Check the file date
        $version++ if ( $date >= ( stat( _encode( $this->{file}, 1 ) ) )[9] );
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

Copyright (C) 2008-2015 Foswiki Contributors. All Rights Reserved.
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
