
# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin::TableRow;

use strict;
use Assert;

use Foswiki::Func ();
use Foswiki::Plugins::EditRowPlugin::TableCell ();

sub new {
    my ( $class, $table, $number, $precruft, $postcruft, $cols ) = @_;
    my $this = bless( {}, $class );
    $this->{table}     = $table;
    $this->{number}    = $number; # 0-based index of the row in the *raw* table
    $this->{isHeader}  = 0;
    $this->{isFooter}  = 0;
    $this->{precruft}  = $precruft;
    $this->{postcruft} = $postcruft;

    # pad out the cols to the width of the format
    my $ncols = scalar( @{ $table->{colTypes} } );
    while ( scalar(@$cols) < $ncols ) {
        push( @$cols, '' );
    }
    $this->{cols} = [];
    $this->setRow($cols);
    return $this;
}

sub getID {
    my $this = shift;
    return $this->{table}->getID() . '_' . $this->{number};
}

sub getAnchor {
    my $this = shift;
    return 'erp_' . $this->getID();
}

sub getEditAnchor {
    my $this = shift;
    return 'erp_edit_' . $this->getID();
}

sub isHeader {
    my $this = shift;
    foreach my $cell ( @{ $this->{cols} } ) {
        return 0 unless $cell->{isHeader};
        return 1 if $cell->{isHeader};
    }
    return 0;
}

# Find a row anchor within range of the row being edited that gives a
# reasonable amount of context (3 rows) above the edited row
sub getRowAnchor {
    my $this       = shift;
    my $row_anchor = 1;
    if ( $this->{number} > 3 ) {
        $row_anchor = $this->{number} - 1;
    }
    return 'erp_' . $this->{table}->getID() . '_' . $row_anchor;
}

# break cycles to ensure we release back to garbage
sub finish {
    my $this = shift;
    $this->{table} = undef;
    foreach my $cell ( @{ $this->{cols} } ) {
        $cell->finish();
    }
    undef( $this->{cols} );
}

# Set the columns in the row. Adapts to widen or narrow the row as required.
sub setRow {
    my ( $this, $cols ) = @_;

    while ( scalar( @{ $this->{cols} } ) > scalar(@$cols) ) {
        pop( @{ $this->{cols} } )->finish();
    }
    my $n = 0;
    foreach my $val (@$cols) {
        if ( $n < scalar( @{ $this->{cols} } ) ) {

            # Restore the EDITCELL from the old value, if present
            if (   $val !~ /%EDITCELL{.*?}%/
                && $this->{cols}->[$n]->{text} =~ /(%EDITCELL{.*?}%)/ )
            {
                $val .= $1;
            }
            $this->{cols}->[$n]->{text} = $val;
        }
        else {
            push(
                @{ $this->{cols} },
                Foswiki::Plugins::EditRowPlugin::TableCell->new(
                    $this, $val, $n + 1
                )
            );
        }
        $n++;
    }
}

sub stringify {
    my $this = shift;
    return '|' . join( '|', map { $_->stringify() } @{ $this->{cols} } ) . '|';
}

sub can_edit {
    my $this = shift;
    return $this->{table}->can_edit();
}

sub getURLParams {
    my ($this, %more) = @_;
    return { erp_active_row => $this->{number}, %more };
}

# col_defs - column definitions (required)
# for_edit - true if we are editing
# orient - "horizontal" or "vertical" editor orientation
# with_controls - if we want row controls
# js - assumed, preferred or ignored
sub render {
    my ( $this, $opts ) = @_;
    my $id        = $this->getID();
    my $addAnchor = 1;
    my $anchor    = '<a name="' . $this->getAnchor() . '"></a> ';
    my $empties = '|' x ( scalar( @{ $this->{cols} } ) - 1 );
    my @cols = ();
    my $buttons = '';
    my $editing = $opts->{for_edit} && $opts->{js} ne 'assumed';
    my $buttons_right = ($this->{table}->{attrs}->{buttons} eq "right");

    if ($editing) {
	$buttons = $this->{table}->generateEditButtons(
	    $this->{number}, $opts->{orient} eq 'vertical', 0 ).$anchor;
	$addAnchor = 0;
    }

    if ( $editing && $opts->{orient} eq 'vertical') {

        # Each column is presented as a row
        # Number of empty columns at end of each row
        my $hdrs = $this->{table}->getLabelRow();
        my $col  = 0;
	my @rows;
	my $first_col = 1;
        foreach my $cell ( @{ $this->{cols} } ) {

            # get the column label
            my $hdr = $hdrs->{cols}->[$col];
            $hdr = $hdr->{text} if $hdr;
            my $text = $cell->render({
		col_defs => $opts->{col_defs},
		in_row => $this,
		for_edit => 1,
		first_row => $opts->{first_row},
		first_col => $first_col} );

            push( @rows, "| $hdr|$text$anchor|$empties" );
            $anchor = '';
            $col++;
	    $first_col  = 0;
        }
        if ($opts->{with_controls}) {
            push( @rows, "| $buttons ||$empties" );
        }
	# The edit controls override the with_controls, so simply....
	return join("\n", @rows);
    }

    # Not for edit, or orientation horizontal, or JS required
    my $text;

    $opts->{in_row} = $this;
    $opts->{first_col} = 1;
    foreach my $cell ( @{ $this->{cols} } ) {

	$text = $cell->render($opts);
	$opts->{first_col} = 0;

	# Add the row anchor for editing. It's added to the first non-empty
	# cell or, failing that, the first cell. This is to minimise the
	# risk of breaking up implied colspans.
	if ( $addAnchor && $opts->{js} ne 'assumed' && $text =~ /\S/ ) {
		
	    # If the cell has *'s, it is seen by TablePlugin as a header.
	    # We have to respect that.
	    if ( $text =~ /^(\s*.*)(\*\s*)$/ ) {
		$text = $1 . $anchor . $2;
	    }
	    else {
		$text .= $anchor;
	    }
	    $addAnchor = 0;
	}
	push( @cols, $text );
    }

    if ($opts->{with_controls} && $opts->{js} ne 'assumed') {
	# Generate the controls column
	if ($opts->{for_edit}) {
	    if ($buttons_right) {
		push( @cols, $buttons );
	    } else {
		unshift( @cols, $buttons );
	    }
	    my $help = $this->{table}->generateHelp();
	    push( @cols, "\n", $help, '', $empties) if $help;
	} else {
	    my $active_topic =
		$this->{table}->getWeb() . '.' . $this->{table}->getTopic();

	    if ( $this->{isHeader} || $this->{isFooter} ) {

		# The ** fools TablePlugin into thinking this is a header.
		# Otherwise it disables sorting :-(
		my $text = '';
		if ($addAnchor) {
		    $text .= $anchor;
		    $addAnchor = 0;
		}
		if ($buttons_right) {
		    push( @cols, " *$text* " );
		} else {
		    unshift( @cols, " *$text* " );
		}
	    }
	    else {
		my $script = 'view';
		if ( !Foswiki::Func::getContext()->{authenticated} ) {
		    $script = 'viewauth';
		}
		my $url = Foswiki::Func::getScriptUrl(
		    $this->{table}->getWeb(),
		    $this->{table}->getTopic(),
		    $script,
		    erp_active_topic => $active_topic,
		    erp_active_table => $this->{table}->getID(),
		    erp_active_row   => $this->{number},
		    '#'              => $this->getRowAnchor()
		    );

		my $buttons = "<a href='$url' class='"
		    . ($opts->{js} ne 'ignored' ? 'erpJS_willDiscard' : '')
		    . " ui-icon ui-icon-pencil'>edit</a>";
		if ($addAnchor) {
		    $buttons .= $anchor;
		    $addAnchor = 0;
		}
		#if ($opts->{js} ne 'ignored') {
		# add any other HTML for handling rows here
		#}
		if ($buttons_right) {
		    push( @cols, $buttons );
		} else {
		    unshift( @cols, $buttons );
		}
	    }
	    if ($addAnchor) {

		# All cells were empty; we have to shoehorn the anchor into the
		# final cell.
		my $cell = pop(@cols);
		$cell->{text} .= $anchor;
		push( @cols, $cell->render( { col_defs => $opts->{col_defs} } ) );
	    }
	}
    }
    return $this->{precruft} . join( '|', @cols ) . $this->{postcruft};
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2009 Foswiki Contributors
Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
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

This is an object that represents a single row in a table.

=pod

---++ new(\$table, $rno)
Constructor
   * \$table - pointer to the table
   * $rno - what row number this is (start at 1)

---++ finish()
Must be called to dispose of the object. This method disconnects internal pointers that would
otherwise make a Table and its rows and cells self-referential.

---++ stringify()
Generate a TML representation of the row

---++ render() -> $text
Render the row for editing or display. Standard TML is used to construct the table.

=cut
