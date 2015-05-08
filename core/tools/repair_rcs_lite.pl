#! /usr/bin/env perl
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved.
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
# For licensing info read LICENSE file in the Foswiki root.
#
# Author: Crawford Currie

#
# This is a mashup of various bits of Foswiki code, used to create a
# stand-alone script that checks and repairs ,v files that have been
# damaged by TWiki RcsLite
#

use strict;

use Time::Local ();
use FileHandle  ();

{

    # Cut-down of Foswiki::Store::RcsLite + RcsFile
    package RcsLite;

    our @MONTHLENS = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );

    our %MON2NUM = (
        jan => 0,
        feb => 1,
        mar => 2,
        apr => 3,
        may => 4,
        jun => 5,
        jul => 6,
        aug => 7,
        sep => 8,
        oct => 9,
        nov => 10,
        dec => 11
    );

    sub new {
        my ( $class, $file ) = @_;
        my $this = bless(
            {
                rcsFile => $file,
                head    => 0,
                access  => '',
                symbols => '',
                comment => '# ',
                desc    => 'none',
                expand  => 'o',
            }
        );
        return $this;
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

    sub _ensureProcessed {
        my ($this) = @_;
        if ( !$this->{state} ) {
            _process($this);
        }
    }

    sub parseTime {
        my ( $date, $defaultLocal ) = @_;

        $date =~ s/^\s*//;    #remove leading spaces without de-tainting.
        $date =~ s/\s*$//;

        my $tzadj = 0;        # Zulu
        if ($defaultLocal) {

            $tzadj = -Time::Local::timelocal( 0, 0, 0, 1, 0, 70 );
        }

        if ( $date =~ /(\d+)\s+([a-z]{3})\s+(\d+)(?:[-\s]+(\d+):(\d+))?/i ) {
            my $year = $3;
            $year -= 1900 if ( $year > 1900 );
            return Time::Local::timegm( 0, $5 || 0, $4 || 0, $1,
                $MON2NUM{ lc($2) }, $year ) - $tzadj;
        }

        if (
            ( $date =~ /T/ )
            && ( $date =~
/(\d\d\d\d)(?:-(\d\d)(?:-(\d\d))?)?(?:T(\d\d)(?::(\d\d)(?::(\d\d(?:\.\d+)?))?)?)?(Z|[-+]\d\d(?::\d\d)?)?/
            )
          )
        {
            my ( $Y, $M, $D, $h, $m, $s, $tz ) =
              ( $1, $2 || 1, $3 || 1, $4 || 0, $5 || 0, $6 || 0, $7 || '' );
            $M--;
            $Y -= 1900 if ( $Y > 1900 );
            if ( $tz eq 'Z' ) {
                $tzadj = 0;    # Zulu
            }
            elsif ( $tz =~ /([-+])(\d\d)(?::(\d\d))?/ ) {
                $tzadj = ( $1 || '' ) . ( ( ( $2 * 60 ) + ( $3 || 0 ) ) * 60 );
                $tzadj -= 0;
            }
            return Time::Local::timegm( $s, $m, $h, $D, $M, $Y ) - $tzadj;
        }

        if (
            $date =~ m|^
                       (\d\d+)                                 #year
                       (?:\s*[/\s.-]\s*                        #datesep
                       (\d\d?)                             #month
                       (?:\s*[/\s.-]\s*                    #datesep
                       (\d\d?)                         #day
                       (?:\s*[/\s.-]\s*                #datetimesep
                       (\d\d?)                     #hour
                       (?:\s*[:.]\s*               #timesep
                       (\d\d?)                 #min
                       (?:\s*[:.]\s*           #timesep
                       (\d\d?)
                      )?
                      )?
                      )?
                      )?
                      )?
                       $|x
          )
        {
            my ( $year, $M, $D, $h, $m, $s ) = ( $1, $2, $3, $4, $5, $6 );

            $year -= 1900 if ( $year > 1900 );

            return 0 if ( defined($M) && ( $M < 1 || $M > 12 ) );
            my $month = ( $M || 1 ) - 1;
            return 0
              if ( defined($D) && ( $D < 0 || $D > $MONTHLENS[$month] ) );
            return 0 if ( defined($h) && ( $h < 0 || $h > 24 ) );
            return 0 if ( defined($m) && ( $m < 0 || $m > 60 ) );
            return 0 if ( defined($s) && ( $s < 0 || $s > 60 ) );
            return 0 if ( defined($year) && $year < 60 );

            my $day  = $D || 1;
            my $hour = $h || 0;
            my $min  = $m || 0;
            my $sec  = $s || 0;

            return Time::Local::timegm( $sec, $min, $hour, $day, $month, $year )
              - $tzadj;
        }

        return 0;
    }

    sub _process {
        my ($this) = @_;
        my $rcsFile = $this->{rcsFile};
        if ( !-e $rcsFile ) {
            $this->{state} = 'nocommav';
            return;
        }
        my $fh = new FileHandle();
        if ( !$fh->open($rcsFile) ) {
            $this->{session}
              ->logger->log( 'warning', 'Failed to open ' . $rcsFile );
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

                    # Implicit untaint OK; data from ,v file
                    $this->{access} = $1;
                }
                else {
                    last;
                }
            }
            elsif ( $state eq 'admin.symbols' ) {
                if (/^symbols(.*);$/) {
                    $state = 'admin.locks';

                    # Implicit untaint OK; data from ,v file
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
                (
                       $state eq 'admin.postStrict'
                    || $state eq 'admin.postComment'
                )
                && /^expand\s/
              )
            {
                $state = 'admin.postExpand';
                $this->{expand} = $string;
            }
            elsif ($state eq 'admin.postStrict'
                || $state eq 'admin.postComment'
                || $state eq 'admin.postExpand'
                || $state eq 'delta.date' )
            {
                if (/^([0-9]+)\.([0-9]+)\s+date\s+(\d\d(\d\d)?(\.\d\d){5}?);$/o)
                {
                    $state              = 'delta.author';
                    $num                = $2;
                    $revs[$num]->{date} = parseTime($3);
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
                if (/desc\s*$/o) {
                    $this->{desc} = $string;
                    $state = 'deltatext.log';
                }
            }
            elsif ( $state eq 'deltatext.log' ) {
                if (/\d+\.(\d+)\s+log\s+$/o) {
                    $dnum = $1;
                    $string =~ s/\n*$//o;
                    $revs[$dnum]->{log} = $string;
                    $state = 'deltatext.text';
                }
            }
            elsif ( $state eq 'deltatext.text' ) {
                if (/text\s*$/o) {
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
            my $error =
              $this->{rcsFile} . ' is corrupt; parsed up to ' . $state;
            $this->{session}->logger->log( 'warning', $error );

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

    sub _epochToRcsDateTime {
        my ($dateTime) = @_;
        my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday ) =
          gmtime($dateTime);
        $year += 1900 if ( $year > 99 );
        my $rcsDateTime = sprintf '%d.%02d.%02d.%02d.%02d.%02d',
          ( $year, $mon + 1, $mday, $hour, $min, $sec );
        return $rcsDateTime;
    }

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
        print $file 'comment', "\t", _formatString( $this->{comment} ), ';',
          "\n";
        if ( $this->{expand} ) {
            print $file 'expand', "\t", _formatString( $this->{expand} ),
              ';' . "\n";
        }

        print $file "\n";

        # most recent rev first
        for ( my $i = $this->{head} ; $i > 0 ; $i-- ) {
            my $d       = $this->{revs}[$i]->{date};
            my $rcsDate = _epochToRcsDateTime($d);
            print $file <<HERE;

1.$i
date	$rcsDate;	author $this->{revs}[$i]->{author};	state Exp;
branches;
HERE
            print $file 'next', "\t";
            print $file '1.', ( $i - 1 ) if ( $i > 1 );
            print $file ";\n";
        }

        print $file "\n\n", 'desc', "\n",
          _formatString( $this->{desc} . "\n" ) . "\n\n";

        for ( my $i = $this->{head} ; $i > 0 ; $i-- ) {
            print $file "\n", '1.', $i, "\n",
              'log', "\n", _formatString( $this->{revs}[$i]->{log} . "\n" ),
              "\n", 'text', "\n", _formatString( $this->{revs}[$i]->{text} ),
              "\n" . ( $i == 1 ? '' : "\n" );
        }
        $this->{state} = 'parsed';    # now known clean
    }

    sub writeRCS {
        my ($this)    = @_;
        my $dataError = '';
        my $out       = new FileHandle();

        chmod( 0644, $this->{rcsFile} );
        if ( !$out->open( '>' . $this->{rcsFile} ) ) {
            die( 'Cannot open ' . $this->{rcsFile} . ' for write: ' . $! );
        }
        else {
            binmode($out);
            _write( $this, $out );
            close($out);
        }
        chmod( 0644, $this->{rcsFile} );

        return $dataError;
    }

    # Apply delta (patch) to text.  Note that RCS stores reverse deltas,
    # so the text for revision x is patched to produce text for revision x-1.
    sub _patch {

        # Both params are references to arrays
        my ( $text, $delta ) = @_;
        my $adj     = 0;
        my $pos     = 0;
        my $fixed   = 0;
        my $max     = $#$delta;
        my $loffset = 0;
        while ( $pos <= $max ) {
            my $d = $delta->[$pos];

            #print "DIFF: $d in $#$text\n";
            if ( $d =~ /^([ad])(\d+)\s(\d+)$/ ) {
                my $act    = $1;
                my $offset = $2;
                my $length = $3;
                if ( $offset < $loffset ) {
                    $delta->[$pos] = "$act$loffset $length";

                    #print "ARSEWISE $delta->[$pos]\n";
                    $offset = $loffset;
                    $fixed  = 1;
                }
                $loffset = $offset;
                if ( $act eq 'd' ) {
                    my $start = $offset + $adj - 1;
                    splice( @$text, $start, $length );
                    $adj -= $length;
                    $pos++;
                }
                elsif ( $act eq 'a' ) {

                    #print "\tSNIFF: $offset $length at $pos\n";
                    if (   $pos + $length > $max
                        || $delta->[ $pos + $length ] =~ /^[ad](\d+)\s\d+$/ )
                    {

                        #print "\t\tFIX!\n";
                        splice( @$delta, $pos + $length, 0, "" );
                        $fixed = 1;
                    }
                    splice( @$text, $offset + $adj,
                        0, @$delta[ $pos + 1 .. $pos + $length ] );
                    $adj += $length;
                    $pos += $length + 1;
                }
            }
            else {
                last;
            }
        }
        return $fixed;
    }

    # Apply reverse diffs until we reach our target rev, repairing as we go
    sub _patchN {
        my ( $this, $text, $version, $target ) = @_;
        my $fixed = 0;
        while ( $version >= $target ) {

            #print "Check $version\n";
            my $deltaText = $this->{revs}[ $version-- ]->{text};
            my $delta     = _split($deltaText);
            if ( _patch( $text, $delta ) ) {

                # Was fixed
                $this->{revs}[ $version + 1 ]->{text} = join( "\n", @$delta );
                $fixed = 1;
            }
        }
        return $fixed;
    }

    sub repair {
        my $this = shift;

        _ensureProcessed($this);

        die if $this->{state} eq 'nocommav';

        my $head = $this->{head};
        die unless $head;

        my $headText = $this->{revs}[$head]->{text};
        my $text     = _split($headText);
        return _patchN( $this, $text, $head - 1, 1 );
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

    sub stringify {
        my $this = shift;

        my $s = '';
        foreach my $key (qw(web topic attachment file rcsFile)) {
            if ( defined $this->{$key} ) {
                $s .= " $key=$this->{$key}";
            }
        }
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
}

my $verify = 0;

sub fixDir {
    my ($dir) = @_;

    my $w;
    if ( opendir( $w, $dir ) ) {
        foreach my $f ( readdir($w) ) {
            next if $f =~ /^\./;
            my $file = "$dir/$f";
            if ( -d $file ) {
                fixDir($file);
                next;
            }
            next unless $file =~ /,v$/;
            next unless -e $file;
            print "Process $file\n";
            my $h = new RcsLite($file);
            if ( $h->repair() ) {
                if ( -w $file ) {
                    $h->writeRCS();
                    print "$file: FIXED\n";
                    if ($verify) {
                        my $err = `rlog $file 2>&1`;
                        if ($?) {
                            print "\tStill knackered: $err";
                        }
                    }
                }
                else {
                    print "$file: FUBAR and unfixable\n";
                }
            }
        }
        closedir($w);
    }
}

print <<HELP;

Repair RCS histories that have been damaged by broken versions of the
RcsLite module. You will not normally need to run it unless you have run
with RcsLite and subsequently switched to RcsWrap. All RcsLite versions
prior to Foswiki 1.0.5 have the potential to cause problems.

You will know you need to run this script if you get an error message in
Foswiki that ends with "rlog aborted".

Note that this script fixes the most common error in RCS files. However there
is another error that sometimes occurs that cannot be fixed by this script,
indicated by the rlog message "backward deletion in diff output".
In that event the only thing you can do is try to fix the ,v file manually,
which is sometimes obvious (tip: often deleting the line the rlog aborted on
will repair the file), and other times requires a deep understanding of
how it works. Failing that, your only choice is to back up the history file
(,v) and delete it, forcing Foswiki to restart a new history.

The script has to be run from the root of a Foswiki installation. It will
repair ,v files in the data and pub subdirectories. If you are on a UNIX
platform you can pass the script the -v option which will run rlog on the
fixed output to detect still-broken files.

The script will not touch files unless it detects an error. The user running
the script must have write access to all ,v files.
HELP

if ( scalar(@ARGV) && $ARGV[0] eq '-v' ) {
    $verify = 1;
}

unless ( -d "data" && -d "pub" ) {
    die "Current dir is not the root of an installation; "
      . "expected data and pub\n";
}

my $data;
if ( opendir( $data, 'data' ) ) {
    foreach my $w ( readdir($data) ) {
        if ( $w !~ /^\./ && -d "data/$w" ) {
            fixDir("data/$w");
            fixDir("pub/$w");
        }
    }
}
else {
    die "Failed to open data; $!";
}

1;
