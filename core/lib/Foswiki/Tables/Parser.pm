# See bottom of file for copyright and license information

=begin TML

---+ package Foswiki::Parsers::Table

Re-usable sequential access event-based parser for TML tables.

A sequential access event-based parser works by parsing content
and calling back to "event listeners" when syntactic constructs
are recognised.

=cut

package Foswiki::Tables::Parser;

use strict;
use Assert;

use constant TRACE => 0;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod parse( $text, \&dispatch )

   * $text - text to parse
   * \&dispatch($event_name, ...) - event dispatcher (function)

This is a sequential event-based parser. As each line in the text is read,
it is analysed and if it meets the criteria for an event, it is fired.

In keeping with the line-oriented nature of TML, the parser works on
a line-by-line basis. =&lt;verbatim&gt;= and =&lt;literal&gt;= blocks are
respected.

Events are fired by a call to $dispatch( ... ). The following events are
fired:

---+++ =open_table($line)=
Opens a new table with the given line. Note that this same line will be passed
to new_row as well.

---+++ =close_table()=
Close the currently open table.

---+++ =line($line)=
Called for any line that is not part of a table.

---+++ =open_tr($before)=
Called on each row in an open table (including the header and footer rows)
   * =$before= - leading content (spaces and |)

---+++ =th($pre, $data, $post)=
Called to create a table header cell.
   * =$pre= - preamble (spaces)
   * =$data= - real content
   * =$post= - postamble (spaces)

---+++ =td($pre, $data, $post)=
Called to create a table cell.
   * =$pre= - preamble (spaces)
   * =$data= - real content
   * =$post= - postamble (spaces)

---+++ =close_tr($after)=
Called to close an open table row.
   * =$after= - trailing content (| and spaces)

---+++ =end_of_input()=
Called at end of all input.

An additional event is provided for those seeking to perform special
processing of certain lines, including rewriting them.

---+++ =early_line($line) -> $integer=
Provided for handling lines other than TML content that may
interact with tables during a static parse e.g. special macros such
as %EDITTABLE.

If early_line returns a positive result, then the parser will open a
table on the next line, whether or not it is a table line, *BUT ONLY
IF* the early_line handler for that next line returns 0. Any
non-whitespace left in $line will be inserted as text.

If it returns a negative result, then any non-whitespace left in
$line will be inserted as text, but no other processing will be performed.

Otherwise the line is processed normally.

Note that =early_line= operates on the internal representation of the
line in the parser. Certain constructs, such as verbatim blocks, are
specially marked in this content. =early_line= can be used to rewrite
the $line in place, but only with *great care*. Caveat emptor.

The =early_line= handler is fired for all lines that may be part of
a table (i.e. not verbatim or literal lines).

=cut

sub parse {
    my ( $text, $dispatch ) = @_;

    # Are we parsing a form definition? These have subtle syntactic
    # differences (legacy)
    # SMELL: Should this be a flag in the call, rather than caller magic
    my $parsing_formdef = ( (caller)[0] eq 'Foswiki::Form' );

    # Are we defining a table already?
    my $in_table = 0;

    # Are we to create a table even if the next line isn't a table line?
    my $require_new_table = 0;

    # Depth of tag scopes
    my %scope = ( verbatim => 0, literal => 0, include => 0 );

    my $openRow;
    my @comments;

    # Protect other forms of comment
    $text =~ s/(<!--.*?-->)/
      push(@comments, $1); "\001-$#comments-\001"/seg;

  LINE:
    foreach my $line ( split( /\r?\n/, $text ) ) {

        foreach my $tag ( $line =~ m/<(\/?(?:verbatim|literal)).*?>/g ) {
            $tag =~ m#^(/)?(.*)$#;
            $scope{$2} += ($1) ? -1 : 1;
            print STDERR "scope{$2}  UNBALANCED\n"
              if ( ( $scope{$2} < 0 ) && TRACE );
            $scope{$2} = 0 if ( $scope{$2} < 0 );
            print STDERR "scope{$2} = $scope{$2}\n" if TRACE;
        }

        if ( defined $openRow ) {
            $line = "$openRow$line";
            print STDERR "append to give $line\n" if TRACE;
            $openRow = undef;
        }

        unless ( _macros_are_balanced($line) ) {

            # Unclosed %MACRO{
            print STDERR "unbalanced % in $line\n" if TRACE;
            $openRow = defined $openRow ? "$openRow$line\n" : "$line\n";
            next LINE;
        }

        my $analysis          = 0;
        my $dont_change_table = 0;

        if ( !_in_blocking_scope( \%scope ) ) {
            print STDERR "Processing $line\n" if TRACE;
            my $origline = $line;

            # Call the per-line event. This handles macros.
            $analysis = &$dispatch( 'early_line', $line, $in_table );

            print STDERR
"early_line $analysis, it=$in_table, rnt=$require_new_table, dct=$dont_change_table, line '$line' => "
              if TRACE && $analysis;

            if ( $analysis > 0 ) {

                # A macro, such as EDITTABLE, is forcing creation
                # of a new table.
                print STDERR "open new table\n" if TRACE;

                # fall through to allow dispatch of line event,
                # which will close the current table and open a
                # new one (because $require_new_table is true)
                $require_new_table = 1;
            }
            elsif ( $analysis < 0 ) {
                print STDERR "ignore macro\n" if TRACE;

                # Don't handle $require_new_table yet if this is a
                # blank line (or just contains a TABLE macro)
                $require_new_table = 1 unless $in_table;
                $dont_change_table = 1 unless $line =~ /\S/;
            }

            if ( $line =~ m/^\s*\|.*(\|\s*|\\)$/ ) {

                print STDERR "Tablerow $line\n" if TRACE;

                # A table has been encountered, we don't need to
                # force it.
                $require_new_table = 0;

                if ( $line =~ s/\\$// ) {

                    # terminating \
                    print STDERR "terminating \\\n" if TRACE;
                    $openRow = $line;
                    next LINE;
                }

                my $precruft = '';
                $precruft = $1 if $line =~ s/^(\s*)\|//;
                my $postcruft = '';
                $postcruft = $1 if $line =~ s/\|(\s*)$//;
                if ( !$in_table ) {
                    print STDERR "Open TABLE\n" if TRACE;
                    &$dispatch('open_table');
                    $in_table = 1;
                }

                print STDERR "Open TR\n" if TRACE;

                &$dispatch( 'open_tr', $precruft, $postcruft );

                if ( length($line) ) {

                    # Expand comments again after we split
                    my @cols =
                      map { _rewrite( $_, \@comments ) }
                      split( /\|/, $line, -1 );

                    # Note use of LIMIT=-1 on the split so we don't lose
                    # empty columns

                    my $rowlen = scalar @cols;
                    for ( my $i = 0 ; $i < $rowlen ; $i++ ) {
                        if (   $parsing_formdef
                            && $i == 3
                            && ( substr( $cols[$i], -1 ) eq '\\' )
                            && $i < $rowlen )
                        {
                            # Form definitions allow use of \| escapes in
                            # the initial values column - column 4
                            # So this code removes the "splits" from within
                            # the initial values. But only when processing
                            # a form definition.  See Item13385
                            print STDERR "Merging Form values column.\n"
                              if TRACE;
                            chop $cols[$i];
                            $cols[$i] .= '|' . splice( @cols, $i + 1, 1 );
                            $rowlen--;
                            redo;
                        }
                        else {
                            my ( $prec, $text, $postc, $ish ) =
                              split_cell( $cols[$i] );
                            if ($ish) {
                                print STDERR "TH '$prec', '$text', '$postc'\n"
                                  if TRACE;
                                &$dispatch( 'th', $prec, $text, $postc );
                            }
                            else {
                                print STDERR "TD '$prec', '$text', '$postc'\n"
                                  if TRACE;
                                &$dispatch( 'td', $prec, $text, $postc );
                            }
                        }
                    }
                }

                print STDERR "Close TR\n" if TRACE;
                &$dispatch('close_tr');

                next LINE;

            }
        }
        elsif (TRACE) {
            print STDERR "blocked: $line\n";
        }
        if ( $in_table && !$dont_change_table ) {

            # open table has been terminated
            print STDERR "Close TABLE\n" if TRACE;
            $in_table = 0;
            &$dispatch('close_table');

            # fall through to allow dispatch of line event
        }
        if ( $require_new_table && !$dont_change_table ) {

            # Something encountered by the early_line handler
            # requires the immediate creation of a new table.
            print STDERR "*Force* Open TABLE\n" if TRACE;
            &$dispatch('open_table');
            $in_table          = 1;
            $require_new_table = 0;
        }

        unless ( $analysis && $line !~ /\S/ ) {
            print STDERR "Dispatch $line\n" if TRACE;
            &$dispatch( 'line', _rewrite( $line, \@comments ) );
        }

    }    # end of per-line loop

    if ($in_table) {
        print STDERR "Close TABLE (mop-up)\n" if TRACE;
        &$dispatch('close_table');    #
    }
    if ($require_new_table) {

        print STDERR "*Force* Open TABLE (mop-up)\n" if TRACE;
        &$dispatch('open_table');
        &$dispatch('close_table');
    }
    &$dispatch('end_of_input');
}

=begin TML

---++ StaticMethod split_cell($cell) -> ($pre, $main, $post, $ish)

Given a table cell datum with significant leading and trailing space,
split the cell data into pre-, main-, and post- text, and set $ish
if it is a header cell.

=cut

sub split_cell {
    my $cell = shift;
    my ( $prec, $main, $postc, $ish ) = ( '', '', '', 0 );
    if ( $cell =~ s/^(\s*)\*(.*)\*(\s*)$/$2/ ) {

        # Balanced header marks
        ( $prec, $main, $postc, $ish ) = ( $1, $2, $3, 1 );
    }
    elsif ( $cell =~ s/^(\s*)(\S.*?)(\s*)$/$2/ ) {

        # no header marks
        $prec  = $1 if defined $1;
        $main  = $2 if defined $2;
        $postc = $3 if defined $3;
    }
    else {

        # just spaces.
        my $l    = length($cell);
        my $half = int( $l / 2 );
        $prec = ' ' x $half;
        $postc = ' ' x ( $l - $half );

        #$prec .= "$half ($l)";
        #$postc .= ($l - $half);
    }
    return ( $prec, $main, $postc, $ish );
}

sub _in_blocking_scope {
    my $scope = shift;
    return $scope->{verbatim} != 0 || $scope->{literal} != 0;
}

sub _rewrite {
    my ( $t, $comments ) = @_;
    $t =~ s/\001-(\d+)-\001/$comments->[$1]/ges;
    return $t;
}

# Return false unless TML macro brackets are balanced
sub _macros_are_balanced {
    my $line = shift;
    my $n    = 0;

    map { $_ eq '}%' ? $n-- : $n++ }
      grep { /%[a-z0-9_:]*{|}%/i }
      split( /(%[a-z0-9_:]*{|}%)/i, $line );
    return $n <= 0;    # hanging }% is allowed
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2012 Foswiki Contributors
All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.
