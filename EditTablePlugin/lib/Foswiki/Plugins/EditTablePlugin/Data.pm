package Foswiki::Plugins::EditTablePlugin::Data;

use strict;
use warnings;
use Assert;

=pod

Helper class parses tables to take out table texts, and stores table cell data.

=cut

my $RENDER_HACK = "\n<nop>\n";
my $PLACEHOLDER_ESCAPE_TAG       = 'E_T_P_NOP';

our $PATTERN_EDITTABLEPLUGIN = qr'%EDITTABLE{(.*)}%'o; # NOTE: greedy match to catch macros inside the parameters - but this requires special handling of TABLE tags directly follow the EDITTABLE tags (on the same line) - see _placeTABLEtagOnSeparateLine
our $PATTERN_TABLEPLUGIN     = qr'%TABLE(?:{(.*?)})?%'o;

=pod

Constructor

=cut

sub new {
    my ($class) = @_;
    my $this = {};
    bless $this, $class;
    return $this;
}

=pod

parseText($text)

The guts of this routine was initially copied from SpreadSheetPlugin.pm
and were used in the ChartPlugin Table object which this was copied from,
but this has been modified to support the functionality needed by the
EditTablePlugin.  One major change is to only count and save tables
following an %EDITTABLE{.*}% tag.

This routine basically returns an array of hashes where each hash
contains the information for a single table.  Thus the first hash in the
array represents the first table found on the topic page, the second hash
in the array represents the second table found on the topic page, etc.

=cut

sub parseText {

    my ( $this, $topicText ) = @_;

    my $tableNum = 1;    # Table number (only count tables with EDITTABLE tag)
    my @tableMatrix;     # Currently parsed table.

    my $inEditTable    = 0;    # Flag to keep track if in an EDITTABLE table
    my $insidePRE      = 0;
    my $insideTABLE    = 0;
    my $line           = '';
    my @row            = ();
    my @tableLines     = ();
    my $editTableTag   = '';
    my $storedTableRow = '';

    my $tablesTakenOutText = '';
    my $editTableObjects;

    $topicText =~
      s/\r//go;    # strip out all \r chars (may be pasted into a table cell)
    $topicText =~ s/\\\n//go;    # Join lines ending in "\"
    $topicText .= $RENDER_HACK
      ;    # appended stuff is a hack to handle EDITTABLE correctly if at end

    $topicText =~ s/%EDITTABLE{(.*)}%/&_placeTABLEtagOnSeparateLine($1)/ge;
	
    foreach ( split( /\n/, $topicText ) ) {

        my $doCopyLine      = 1;
        my $hasEditTableTag = 0;

        # change state:
        m#<(?:pre|verbatim)\b#i && ( $insidePRE++ );
        m#</(?:pre|verbatim)>#i && ( $insidePRE-- );

        # If we are in a pre or verbatim block, ignore it
        next if $insidePRE;

        if (/$PATTERN_EDITTABLEPLUGIN/) {
            if (/$PATTERN_TABLEPLUGIN/) {

                # EDITTABLE and TABLE on one line (order does not matter)
                # NO LONGER NEEDED? _putTmpTagInTableTagLine($_);
            }
            elsif ( $storedTableRow ne '' ) {

                # only EDITTABLE
                # store the TABLE tag from the previous line together
                # with the current EDITTABLE tag
                # NO LONGER NEEDED? _putTmpTagInTableTagLine($storedTableRow);
                $editTableTag .= $storedTableRow . "\n";
                $storedTableRow = '';
            }
            $inEditTable = 1;
            $tablesTakenOutText .= "<!--edittable$tableNum-->";
            $doCopyLine = 0;
            $editTableTag .= $_;
            $hasEditTableTag = 1;
        }
        elsif ( $inEditTable && /$PATTERN_TABLEPLUGIN/ ) {

            # TABLE on the line after EDITTABLE
            # we will include it in the editTableTag
            # NO LONGER NEEDED? _putTmpTagInTableTagLine($_);
            $doCopyLine = 0;
            $editTableTag .= "\n" . $_;
            $hasEditTableTag = 1;
        }
        elsif ( !$inEditTable && /$PATTERN_TABLEPLUGIN/ ) {

         # this might be TABLE on the line before EDITTABLE, but we are not sure
            $storedTableRow = $_;
            $doCopyLine     = 0;
        }
        elsif ( $storedTableRow ne '' ) {

# we had stored the TABLE tag, but no EDITTABLE tag was just below it; add it to the text and clear
            $tablesTakenOutText .= $storedTableRow . "\n";
            $storedTableRow = '';
        }
        if ( $inEditTable && !$hasEditTableTag ) {

            if (/^\s*\|.*\|\s*$/) {

                $doCopyLine = 0;
                push( @tableLines, $_ );

                # inside | table |
                $insideTABLE = 1;
                $line        = $_;
                $line =~ s/^(\s*\|)(.*)\|\s*$/$2/o;    # Remove starting '|'
                @row = split( /\|/o, $line, -1 );
                _trimCellsInRow( \@row );
                push( @tableMatrix, [@row] );

            }
            else {

                # outside | table |
                if ($insideTABLE) {

                    # We were inside a table and are now outside of it so
                    # save the table info into the Table object.
                    $insideTABLE = 0;
                    $inEditTable = 0;

                    if ( @tableMatrix != 0 ) {

                        # Save the table via its table number
                        $$this{"TABLE_$tableNum"} = [@tableMatrix];
                    }
                    undef @tableMatrix;    # reset table matrix
                }
                else {

                    # not (or no longer) inside a table
                    $doCopyLine  = 1;
                    $inEditTable = 0;
                }
                my $tableRef;
                $tableRef->{'text'} = join( "\n", @tableLines );
                $tableRef->{'tag'} = $editTableTag;

                push( @{$editTableObjects}, $tableRef );
                $tableNum++;

                @tableLines   = ();
                $editTableTag = '';
            }
        }

        $tablesTakenOutText .= $_ . "\n" if $doCopyLine;
    }    # foreach

    # clean up hack that handles EDITTABLE correctly if at end
    $tablesTakenOutText =~ s/($RENDER_HACK)+$//go;

    if ($Foswiki::Plugins::EditTablePlugin::debug) {
        Foswiki::Func::writeDebug(
"- EditTablePlugin::parseText; tablesTakenOutText=\n$tablesTakenOutText"
        );
        my $text = '';
        foreach my $eto ( @{$editTableObjects} ) {
            $text .= "tag=$eto->{tag}\n";
            $text .= "text=$eto->{text}\n";
        }
        Foswiki::Func::writeDebug(
            "- EditTablePlugin::parseText; editTableObjects=\n$text");
    }

    $this->{tablesTakenOutText} = $tablesTakenOutText;
    $this->{editTableObjects}   = $editTableObjects;
}

=pod

_trimCellsInRow (\@rowCells)

Trim any leading and trailing white space and/or '*'.

=cut

sub _trimCellsInRow {
    my ($rowCells) = @_;
    for my $cell ( @{$rowCells} ) {
        $cell =~ s/^[[:space:]]+//s;    # trim at start
        $cell =~ s/[[:space:]]+$//s;    # trim at end
    }
}

=pod
NO LONGER NEEDED?
sub _putTmpTagInTableTagLine {
    $_[0] =~
s/(%TABLE{.*?)(}%)/$1 "START_EDITTABLEPLUGIN_TMP_TAG""END_EDITTABLEPLUGIN_TMP_TAG"$2/;
}
=cut

=pod

Puts %TABLE{}% tags on a new line to better deal with TablePlugin variables: because $PATTERN_EDITTABLEPLUGIN is greedy this tag would otherwise be grabbed together with the EDITTABLE tag

=cut

sub _placeTABLEtagOnSeparateLine {
    my ( $tagLine ) = @_;
		
	# unprotect TABLE and put in on a new line
	$tagLine =~ s/%TABLE{/\n%TABLE{/go;
	
	return "%EDITTABLE{$tagLine}%";
}

=pod

Return the contents of the specified cell

=cut

sub getCell {
    my ( $this, $tableNum, $row, $column ) = @_;

    my @selectedTable = $this->getTable($tableNum);
    my $value         = $selectedTable[$row][$column];
    return $value;
}

=pod

Return an entire table, or an empty list

=cut

sub getTable {
    my ( $this, $tableNumber ) = @_;
    my $table = $$this{"TABLE_$tableNumber"};
    return @$table if defined($table);
    return ();
}

1;

__DATA__
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Arthur Clemens, arthur@visiblearea.com and Foswiki contributors
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org and
# TWiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# This is the EditTablePlugin used to edit tables in place.
