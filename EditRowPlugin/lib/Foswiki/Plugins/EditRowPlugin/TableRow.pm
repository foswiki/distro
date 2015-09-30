# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin::TableRow;

use strict;
use Assert;

use Foswiki::Func ();

use Foswiki::Tables::Row ();
our @ISA = ('Foswiki::Tables::Row');

use Foswiki::Plugins::EditRowPlugin::TableCell ();

sub new {
    my ( $class, $table, $number, $precruft, $postcruft, $cols ) = @_;

    my $this =
      $class->SUPER::new( $table, $number, $precruft, $postcruft, $cols );
    return $this;
}

sub cell_class {
    return 'Foswiki::Plugins::EditRowPlugin::TableCell';
}

# SMELL: why is this different to getEditAnchor?
sub getAnchor {
    my $this = shift;
    return 'erp_' . $this->getID();
}

sub getEditAnchor {
    my $this = shift;
    return 'erp_edit_' . $this->getID();
}

# Find a row anchor within range of the row being edited that gives a
# reasonable amount of context (3 rows) above the edited row
sub getRowAnchor {
    my $this       = shift;
    my $row_anchor = $this->{number} - 3;
    $row_anchor = 0 if $row_anchor < 0;
    return 'erp_' . $this->{table}->getID() . '_' . $row_anchor;
}

# Set the columns in the row. Adapts to widen or narrow the row as required.
# Used to set an entire row on save from the table editor.
sub setRow {
    my ( $this, $cols ) = @_;

    while ( scalar( @{ $this->{cols} } ) > scalar(@$cols) ) {
        pop( @{ $this->{cols} } )->finish();
    }
    my $n = 0;
    foreach my $val (@$cols) {
        if ( $n < scalar( @{ $this->{cols} } ) ) {

            # Skip undef cols, leave old value in place
            next unless defined $val;

            # Restore the EDITCELL from the old value, if present
            if (   $val !~ /%EDITCELL\{.*?\}%/
                && $this->{cols}->[$n]->{text} =~ /(%EDITCELL\{.*?\}%)/ )
            {
                $val .= $1;
            }
            $this->{cols}->[$n]->{text} = $val;
        }
        else {
            if ( !ref($val) ) {
                my @cell = Foswiki::Tables::Parser::split_cell($val);
                $val = \@cell;
            }

            # Use pushCell so the cell gets numbered
            $this->pushCell(
                Foswiki::Plugins::EditRowPlugin::TableCell->new( $this, @$val )
            );
        }
        $n++;
    }
}

# True if this row is in an editable table.
#TODO: unless its a header=""
sub can_edit {
    my $this = shift;
    return $this->{table}->can_edit()
      && !( $this->isFooter() || $this->isFooter() );
}

# add URL params needed to address this row
sub getParams {
    my ( $this, $prefix ) = @_;

    $prefix ||= '';

    return ( "${prefix}row" => $this->{number} );
}

# col_defs - column definitions (required)
# for_edit - true if we are editing
# orient - "horizontal" or "vertical" editor orientation
# with_controls - if we want row controls
# js - assumed, preferred or ignored
sub render {
    my ( $this, $opts, $render_opts ) = @_;
    my $id = $this->getID();

    # The row anchor is added into a cell at the first opportunity
    my $anchor = Foswiki::Render::html( 'a', { name => $this->getAnchor() } );
    my $empties       = '|' x ( scalar( @{ $this->{cols} } ) - 1 );
    my @cols          = ();
    my $buttons       = '';
    my $editing       = $opts->{for_edit} && $opts->{js} ne 'assumed';
    my $buttons_right = ( $this->{table}->{attrs}->{buttons} eq "right" );

    if ($editing) {
        $buttons =
          $this->{table}->generateEditButtons( $this->{number},
            $opts->{orient} eq 'vertical', 0 )
          . $anchor;
        $anchor = '';
    }

    if ( $editing && $opts->{orient} eq 'vertical' ) {

        # Each column is presented as a row
        # Number of empty columns at end of each row
        my $hdrs = $this->{table}->getLabelRow();
        my $col  = 0;
        my @rows;
        $render_opts->{need_trdata} = 1;
        foreach my $cell ( @{ $this->{cols} } ) {

            # get the column label
            my $hdr = $hdrs->{cols}->[$col];
            $hdr = $hdr->{text} if $hdr;
            my $text = $cell->render(
                {
                    col_defs => $opts->{col_defs},
                    in_row   => $this,
                    for_edit => 1,
                    js       => $opts->{js}
                },
                $render_opts
            );

            push( @rows, "| $hdr|$text$anchor|$empties" );
            $anchor = '';
            $col++;
        }
        if ( $opts->{with_controls} ) {
            push( @rows, "| $buttons ||$empties" );
        }

        # The edit controls override the with_controls, so simply....
        my $s = join( "\n", @rows );
        return $s;
    }

    # Not for edit, or orientation horizontal
    my $text;

    if ( $opts->{with_controls} && $opts->{js} ne 'assumed' ) {

        # Remark the controls column
        $this->{table}->{dead_cols} = 1;
    }

    $opts->{in_row}             = $this;
    $render_opts->{need_trdata} = 1;
    foreach my $cell ( @{ $this->{cols} } ) {

        $text = $cell->render( $opts, $render_opts );

        # Add the row anchor for editing. It's added to the first non-empty
        # cell or, failing that, the first cell. This is to minimise the
        # risk of breaking up implied colspans.
        if ( $anchor && $opts->{js} ne 'assumed' && $text =~ /\S/ ) {

            # If the cell has *'s, it is seen by TablePlugin as a header.
            # We have to respect that, and put the anchor inside the *'s.
            if ( $text =~ /^(\s*.*)(\*\s*)$/ ) {
                $text = "$1$anchor$2";
            }
            else {
                $text .= "$anchor";
            }
            undef $anchor;
        }
        push( @cols, $text );
    }

    if ( $opts->{with_controls} && $opts->{js} ne 'assumed' ) {

        # Generate the controls column
        if ( $opts->{for_edit} ) {
            if ($buttons_right) {
                push( @cols, $buttons );
            }
            else {
                unshift( @cols, $buttons );
            }
            my $help = $this->{table}->generateHelp();
            if ($anchor) {
                $help .= $anchor;
                undef $anchor;
            }
            push( @cols, "\n", $help, '', $empties ) if $help;
        }
        else {
            my $active_topic =
              $this->{table}->getWeb() . '.' . $this->{table}->getTopic();

            if ( $this->isHeader() || $this->isFooter() ) {

                # The ** fools TablePlugin into thinking this is a header.
                # Otherwise it disables sorting :-(
                my $text = '';
                if ($anchor) {
                    $text .= $anchor;
                    undef $anchor;
                }
                if ($buttons_right) {
                    push( @cols, " *$text* " );
                }
                else {
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
                    erp_topic => $this->{table}->getWeb() . '.'
                      . $this->{table}->getTopic(),
                    erp_table => $this->{table}->getID(),
                    erp_row   => $this->{number},
                    '#'       => $this->getRowAnchor()
                );

                my $buttons = Foswiki::Render::html(
                    'a',
                    {
                        href  => $url,
                        title => 'Edit this row',
                        class => (
                            $opts->{js} ne 'ignored' ? 'erpJS_willDiscard' : ''
                          )
                          . ' ui-icon ui-icon-pencil'
                    },
                    'edit'
                );
                if ($anchor) {
                    $buttons .= $anchor;
                    undef $anchor;
                }

                #if ($opts->{js} ne 'ignored') {
                # add any other HTML for handling rows here
                #}

                if ($buttons_right) {
                    push( @cols, $buttons );
                }
                else {
                    unshift( @cols, $buttons );
                }
            }
            if ($anchor) {

                # All cells were empty; we have to shoehorn the anchor into the
                # final cell.
                my $cell = pop(@cols);
                $cell->{text} .= $anchor;
                undef $anchor;
                push( @cols,
                    $cell->render( { col_defs => $opts->{col_defs} } ) );
            }
        }
        ASSERT( !$anchor ) if DEBUG;
    }
    my $s = join( '|', @cols );
    return "$this->{precruft}|$s|$this->{postcruft}";
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
