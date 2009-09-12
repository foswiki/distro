# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors.
# Copyright (C) 2005-2006 TWiki Contributors
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.

use strict;

package Foswiki::Plugins::TablePlugin::Core;

use Foswiki::Time;
use Error qw(:try);

my @curTable;
my $translationToken;
my $insideTABLE;
my $tableCount;
my $currTablePre;
my $didWriteDefaultStyle;
my $defaultAttrs;          # to write generic table CSS
my $tableSpecificAttrs;    # to write table specific table CSS
my $combinedTableAttrs;    # default and specific table attributes

# not yet refactored:
my $sortCol;
my $maxSortCols;
my $requestedTable;
my $up;
my $sortTablesInText;
my $sortAttachments;
my $sortColFromUrl;
my $sortAllTables;
my $url;
my $currentSortDirection;
my @rowspan;
my $unsortEnabled;    # SMELL: is always true
my $initDirection;

my $URL_ICON =
    Foswiki::Func::getPubUrlPath() . '/'
  . $Foswiki::cfg{SystemWebName}
  . '/DocumentGraphics/';
my $GIF_TABLE_SORT_ASCENDING = CGI::img(
    {
        src    => $URL_ICON . 'tablesortup.gif',
        border => 0,
        width  => 11,
        height => 13,
        alt    => 'Sorted ascending',
        title  => 'Sorted ascending'
    }
);

my $GIF_TABLE_SORT_DESCENDING = CGI::img(
    {
        src    => $URL_ICON . 'tablesortdown.gif',
        border => 0,
        width  => 11,
        height => 13,
        alt    => 'Sorted descending',
        title  => 'Sorted descending'
    }
);

my $GIF_TABLE_SORT_BOTH = CGI::img(
    {
        src    => $URL_ICON . 'tablesortdiamond.gif',
        border => 0,
        width  => 11,
        height => 13,
        alt    => 'Sort',
        title  => 'Sort'
    }
);
my $CHAR_SORT_ASCENDING = CGI::span( { class => 'tableSortIcon tableSortUp' },
    $GIF_TABLE_SORT_ASCENDING );
my $CHAR_SORT_DESCENDING =
  CGI::span( { class => 'tableSortIcon tableSortDown' },
    $GIF_TABLE_SORT_DESCENDING );
my $CHAR_SORT_BOTH =
  CGI::span( { class => 'tableSortIcon tableSortUp' }, $GIF_TABLE_SORT_BOTH );

my $SORT_DIRECTION = {
    'ASCENDING'  => 0,
    'DESCENDING' => 1,
    'NONE'       => 2,
};
my $COLUMN_TYPE = {
    'TEXT'      => 'text',
    'DATE'      => 'date',
    'NUMBER'    => 'number',
    'UNDEFINED' => 'undefined',
};

my $PATTERN_ATTRIBUTE_SIZE = qr'([0-9]+)(px|%)*'o;

BEGIN {
    $translationToken = "\0";

    # the maximum number of columns we will handle
    $maxSortCols          = 10000;
    $unsortEnabled        = 1;       # if true, table columns can be unsorted
    $didWriteDefaultStyle = 0;
}

sub _setDefaults {
    _debug("_setDefaults");
    $tableCount                 = 0;
    $initDirection              = $SORT_DIRECTION->{'ASCENDING'};
    $sortAllTables              = $sortTablesInText;
    $currTablePre               = '';
    $combinedTableAttrs         = {};
    $defaultAttrs               = {};
    $tableSpecificAttrs         = {};
    $defaultAttrs->{headerrows} = 1;
    $defaultAttrs->{footerrows} = 0;
    $defaultAttrs->{class}      = 'foswikiTable';

    _parseDefaultAttributes(
        %{Foswiki::Plugins::TablePlugin::pluginAttributes} );
}

=pod

=cut

sub _storeAttribute {
    my ( $inAttrName, $inValue, $inCollection ) = @_;

    return if !defined $inValue;
    return if !defined $inAttrName || $inAttrName eq '';
    $inCollection->{$inAttrName} = $inValue;
}

=pod

=cut

sub _parseDefaultAttributes {
    my (%params) = @_;

    _debugData("_parseDefaultTableAttributes");

    _parseAttributes( 0, $defaultAttrs, \%params );
    $combinedTableAttrs = _mergeHashes( $combinedTableAttrs, $defaultAttrs );

    # create CSS styles tables in general
    my ( $id, @styles ) = _createCssStyles( 1, $defaultAttrs );
    _debugData( "after _createCssStyles, id=$id; styles=", \@styles );
    _writeStyleToHead( $id, @styles ) if scalar @styles;
}

=pod

=cut

sub _parseTableSpecificTableAttributes {
    my (%params) = @_;

    _debugData("_parseTableSpecificTableAttributes");

    _parseAttributes( 1, $tableSpecificAttrs, \%params );

    # remove default values from hash
    while ( my ( $key, $value ) = each %{$tableSpecificAttrs} ) {
        delete $tableSpecificAttrs->{$key}
          if $defaultAttrs->{$key} && $value eq $defaultAttrs->{$key};
    }
    $combinedTableAttrs =
      _mergeHashes( $combinedTableAttrs, $tableSpecificAttrs );
    _debugData( "combinedTableAttrs", $combinedTableAttrs );

    # create CSS styles for this table only
    my ( $id, @styles ) = _createCssStyles( 0, $tableSpecificAttrs );
    _debugData( "after _createCssStyles, id=$id; styles=", \@styles );
    _writeStyleToHead( $id, @styles ) if scalar @styles;

    return $currTablePre . '<nop>';
}

=pod

=cut

sub _arrayRefFromParam {
    my ($inValue) = @_;

    return undef if !$inValue;

    $inValue =~ s/ //go;    # remove spaces
    my @list = split( /,/, $inValue );
    return \@list;
}

=pod

=cut

sub _parseAttributes {
    my ( $modeSpecific, $inCollection, $inParams ) = @_;

    # table attributes
    # some will be used for css styling as well

    # sort
    if ($modeSpecific) {
        _storeAttribute( 'sort',
            Foswiki::Func::isTrue( $inParams->{sort} || 'on' ),
            $inCollection );
        if ( $inCollection->{sort} ) {
            _storeAttribute( 'initSort', $inParams->{initsort}, $inCollection );
            _storeAttribute( 'sortAllTables', 1, $inCollection );
        }
        my $initDirection = $inParams->{initdirection};
        if ($initDirection) {
            _storeAttribute( 'sortAllTables', $SORT_DIRECTION->{'ASCENDING'} )
              if $initDirection =~ /^down$/i;
            _storeAttribute( 'sortAllTables', $SORT_DIRECTION->{'DESCENDING'} )
              if $initDirection =~ /^up$/i;
        }

# If EditTablePlugin is installed and we are editing a table, the CGI
# parameter 'sort' is defined as "off" to disable all header sorting ((Item5135)
        my $cgi          = Foswiki::Func::getCgiQuery();
        my $urlParamSort = $cgi->param('sort');
        if ( $urlParamSort && $urlParamSort =~ /^off$/oi ) {
            delete $inCollection->{sortAllTables};
        }

      # If EditTablePlugin is installed and we are editing a table, the
      # 'disableallsort' TABLE parameter is added to disable initsort and header
      # sorting in the table that is being edited. (Item5135)
        if ( Foswiki::Func::isTrue( $inParams->{disableallsort} ) ) {
            delete $inCollection->{sortAllTables};
            delete $inCollection->{initSort};
        }
    }

    if ($modeSpecific) {
        _storeAttribute( 'summary', $inParams->{summary}, $inCollection );
        my $id = $inParams->{id} || 'table' . ( $tableCount + 1 );
        _storeAttribute( 'id',         $id,                     $inCollection );
        _storeAttribute( 'headerrows', $inParams->{headerrows}, $inCollection );
        _storeAttribute( 'footerrows', $inParams->{footerrows}, $inCollection );
    }
    _storeAttribute( 'border',      $inParams->{tableborder}, $inCollection );
    _storeAttribute( 'cellpadding', $inParams->{cellpadding}, $inCollection );
    _storeAttribute( 'cellspacing', $inParams->{cellspacing}, $inCollection );
    _storeAttribute( 'frame',       $inParams->{tableframe},  $inCollection );

    # table rules and cellspacing cannot be used at the same time
    _storeAttribute( 'rules', $inParams->{tablerules}, $inCollection )
      if !( defined $inCollection->{cellspacing} );
    _storeAttribute( 'width', $inParams->{tableswidth}, $inCollection );

    # css attributes
    _storeAttribute( 'headerColor', $inParams->{headercolor}, $inCollection );
    _storeAttribute( 'headerBg',    $inParams->{headerbg},    $inCollection );
    _storeAttribute( 'cellBorder',  $inParams->{cellborder},  $inCollection );
    _storeAttribute( 'headerAlignListRef',
        _arrayRefFromParam( $inParams->{headeralign} ),
        $inCollection );
    _storeAttribute( 'dataAlignListRef',
        _arrayRefFromParam( $inParams->{dataalign} ),
        $inCollection );
    _storeAttribute( 'columnWidthsListRef',
        _arrayRefFromParam( $inParams->{columnwidths} ),
        $inCollection );
    _storeAttribute( 'vAlign', $inParams->{valign} || 'top', $inCollection );
    _storeAttribute( 'dataVAlign',   $inParams->{datavalign},   $inCollection );
    _storeAttribute( 'headerVAlign', $inParams->{headervalign}, $inCollection );
    _storeAttribute( 'headerBgSorted',
        $inParams->{headerbgsorted} || $inParams->{headerbg},
        $inCollection );
    _storeAttribute( 'dataBgListRef', _arrayRefFromParam( $inParams->{databg} ),
        $inCollection );
    _storeAttribute(
        'dataBgSortedListRef',
        _arrayRefFromParam( $inParams->{databgsorted} || $inParams->{databg} ),
        $inCollection
    );
    _storeAttribute( 'dataColorListRef',
        _arrayRefFromParam( $inParams->{datacolor} ),
        $inCollection );
    _storeAttribute( 'tableCaption', $inParams->{caption}, $inCollection );

    # remove empty attributes
    while ( my ( $key, $value ) = each %{$inCollection} ) {
        delete $inCollection->{$key} if !defined $value || $value eq '';
    }

    _debugData( "_parseAttributes result:", $inCollection );
}

=pod

Convert text to number and date if syntactically possible

=cut

sub _convertToNumberAndDate {
    my ($text) = @_;

    $text = _stripHtml($text);

    if ( $text =~ /^\s*$/ ) {
        return ( 0, 0 );
    }

    my $num  = undef;
    my $date = undef;

    # Unless the table cell is a pure number
    # we test if it is a date.
    if ( $text =~ /^\s*-?[0-9]+(\.[0-9]+)?\s*$/ ) {
        $num = $text;
    }
    else {
        try {
            $date = Foswiki::Time::parseTime($text);
        }
        catch Error::Simple with {

            # nope, wasn't a date
        };
    }

    unless ($date) {
        $date = undef;
        if ( $text =~ /^\s*(-?[0-9]+)(\.[0-9]+)?/ ) {

            # for example for attachment sizes: 1.1 K
            # but also for other strings that start with a number
            my $num1 = $1 || 0;
            my $num2 = $2 || 0;
            $num = scalar("$num1$num2");
        }
    }

    return ( $num, $date );
}

sub _processTableRow {
    my ( $thePre, $theRow ) = @_;

    $currTablePre = $thePre || '';
    my $span = 0;
    my $l1   = 0;
    my $l2   = 0;

    if ( !$insideTABLE ) {
        @curTable = ();
        @rowspan  = ();

        $tableCount++;
        $currentSortDirection = $SORT_DIRECTION->{'NONE'};

        if (   defined $requestedTable
            && $requestedTable == $tableCount
            && defined $sortColFromUrl )
        {
            $sortCol              = $sortColFromUrl;
            $sortCol              = $maxSortCols if ( $sortCol > $maxSortCols );
            $currentSortDirection = _getCurrentSortDirection($up);
        }
        elsif ( defined $combinedTableAttrs->{initSort} ) {
            $sortCol              = $combinedTableAttrs->{initSort} - 1;
            $sortCol              = $maxSortCols if ( $sortCol > $maxSortCols );
            $currentSortDirection = _getCurrentSortDirection($initDirection);
        }

    }

    $theRow =~ s/\t/   /go;    # change tabs to space
    $theRow =~ s/\s*$//o;      # remove trailing spaces
    $theRow =~
      s/(\|\|+)/'colspan'.$translationToken.length($1)."\|"/geo;  # calc COLSPAN
    my $colCount = 0;
    my @row      = ();
    $span = 0;
    my $value = '';

    foreach ( split( /\|/, $theRow ) ) {
        my $attr = {};
        $span = 1;

        #AS 25-5-01 Fix to avoid matching also single columns
        if (s/colspan$translationToken([0-9]+)//) {
            $span = $1;
            $attr->{colspan} = $span;
        }
        s/^\s+$/ &nbsp; /o;
        ( $l1, $l2 ) = ( 0, 0 );
        if (/^(\s*).*?(\s*)$/) {
            $l1 = length($1);
            $l2 = length($2);
        }
        if ( $l1 >= 2 ) {
            if ( $l2 <= 1 ) {
                $attr->{align} = 'right';
            }
            else {
                $attr->{align} = 'center';
            }
        }
        if ( $span <= 2 ) {
            $attr->{class} =
              _appendColNumberCssClass( $attr->{class}, $colCount );
        }

        if (/^(\s|<[^>]*>)*\^(\s|<[^>]*>)*$/) {    # row span above
            $rowspan[$colCount]++;
            push @row, { text => $value, type => 'Y' };
        }
        else {
            for ( my $col = $colCount ; $col < ( $colCount + $span ) ; $col++ )
            {
                if ( defined( $rowspan[$col] ) && $rowspan[$col] ) {
                    my $nRows = scalar(@curTable);
                    my $rspan = $rowspan[$col] + 1;
                    if ( $rspan > 1 ) {
                        $curTable[ $nRows - $rspan ][$col]->{attrs}->{rowspan} =
                          $rspan;
                    }
                    undef( $rowspan[$col] );
                }
            }

            if (
                (
                    (
                        defined $requestedTable
                        && $requestedTable == $tableCount
                    )
                    || defined $combinedTableAttrs->{initSort}
                )
                && defined $sortCol
                && $colCount == $sortCol
              )
            {

                # CSS class name
                if ( $currentSortDirection == $SORT_DIRECTION->{'ASCENDING'} ) {
                    $attr->{class} =
                      _appendSortedAscendingCssClass( $attr->{class} );
                }
                if ( $currentSortDirection == $SORT_DIRECTION->{'DESCENDING'} )
                {
                    $attr->{class} =
                      _appendSortedDescendingCssClass( $attr->{class} );
                }
            }

            my $type = '';
            if (/^\s*\*(.*)\*\s*$/) {
                $value = $1;
                $type  = 'th';
            }
            else {
                if (/^\s*(.*?)\s*$/) {    # strip white spaces
                    $_ = $1;
                }
                $value = $_;
                $type  = 'td';
            }

            push @row, { text => $value, attrs => $attr, type => $type };
        }
        while ( $span > 1 ) {
            push @row, { text => $value, type => 'X' };
            $colCount++;
            $span--;
        }
        $colCount++;
    }
    push @curTable, \@row;
    return $currTablePre
      . '<nop>';    # Avoid Foswiki converting empty lines to new paras
}

# Determine whether to generate sorting headers for this table. The header
# indicates the context of the table (body or file attachment)
sub _shouldISortThisTable {
    my ($header) = @_;

    return 0 unless $sortAllTables;

    # All cells in header are headings?
    #foreach my $cell (@$header) {
    #return 0 if ( $cell->{type} ne 'th' );
    #}

    return 1;
}

# Guess if column is a date, number or plain text
sub _guessColumnType {
    my ($col)         = @_;
    my $isDate        = 1;
    my $isNum         = 1;
    my $num           = '';
    my $date          = '';
    my $columnIsValid = 0;
    foreach my $row (@curTable) {
        next if ( $row->[$col]->{text} =~ /^\s*$/ );

        # else
        $columnIsValid = 1;
        ( $num, $date ) = _convertToNumberAndDate( $row->[$col]->{text} );

        $isDate = 0 if ( !defined($date) );
        $isNum  = 0 if ( !defined($num) );
        last if ( !$isDate && !$isNum );
        $row->[$col]->{date}   = $date;
        $row->[$col]->{number} = $num;
    }
    return $COLUMN_TYPE->{'UNDEFINED'} if ( !$columnIsValid );
    my $type = $COLUMN_TYPE->{'TEXT'};
    if ($isDate) {
        $type = $COLUMN_TYPE->{'DATE'};
    }
    elsif ($isNum) {
        $type = $COLUMN_TYPE->{'NUMBER'};
    }
    return $type;
}

# Remove HTML from text so it can be sorted
sub _stripHtml {
    my ($text) = @_;

    $text =~
      s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/go; # extract label from [[...][...]] link

    my $orgtext =
      $text;    # in case we will remove all contents with stripping html
    $text =~ s/<[^>]+>//go;    # strip HTML
    $text =~ s/\&nbsp;/ /go;
    $text = _getImageTextForSorting($orgtext) if ( $text eq '' );
    $text =~ s/[\[\]\*\|=_\&\<\>]/ /g;    # remove Wiki formatting chars
    $text =~ s/^ *//go;                   # strip leading space space

    return $text;
}

=pod

Retrieve text data from an image html tag to be used for sorting.
First try the alt tag string. If not available, return the url string.
If not available, return the original string.

=cut

sub _getImageTextForSorting {
    my ($text) = @_;

    # try to see _if_ there is any img data for sorting
    my $hasImageTag = ( $text =~ m/\<\s*img([^>]+)>/ );
    return $text if ( !$hasImageTag );

    # first try to get the alt text
    my $key = 'alt';
    $text =~ m/$key=\s*[\"\']([^\"\']*)/;
    return $1 if ( $1 ne '' );

    # else

    # no alt text; use the url
    $key = 'url';
    $text =~ m/$key=\s*[\"\']([^\"\']*)/;
    return $1 if ( $1 ne '' );

    # else

    return $text;
}

=pod

Appends $className to $classList, separated by a space.  

=cut

sub _appendToClassList {
    my ( $classList, $className ) = @_;
    $classList = $classList ? $classList .= ' ' : '';
    $classList .= $className;
    return $classList;
}

sub _appendSortedCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'foswikiSortedCol' );
}

sub _appendRowNumberCssClass {
    my ( $classList, $colListName, $rowNum ) = @_;

    my $rowClassName = 'foswikiTableRow' . $colListName . $rowNum;
    return _appendToClassList( $classList, $rowClassName );
}

sub _appendColNumberCssClass {
    my ( $classList, $colNum ) = @_;

    my $colClassName = 'foswikiTableCol' . $colNum;
    return _appendToClassList( $classList, $colClassName );
}

sub _appendFirstColumnCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'foswikiFirstCol' );
}

sub _appendLastColumnCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'foswikiLastCol' );
}

sub _appendLastRowCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'foswikiLast' );
}

sub _appendSortedAscendingCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'foswikiSortedAscendingCol' );
}

sub _appendSortedDescendingCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'foswikiSortedDescendingCol' );
}

# The default sort direction.
sub _getDefaultSortDirection {
    return $SORT_DIRECTION->{'ASCENDING'};
}

# Gets the current sort direction.
sub _getCurrentSortDirection {
    my ($currentDirection) = @_;
    $currentDirection ||= _getDefaultSortDirection();
    return $currentDirection;
}

# Gets the new sort direction (needed for sort button) based on the current sort
# direction.
sub _getNewSortDirection {
    my ($currentDirection) = @_;
    if ( !defined $currentDirection ) {
        return _getDefaultSortDirection();
    }
    my $newDirection;
    if ( $currentDirection == $SORT_DIRECTION->{'ASCENDING'} ) {
        $newDirection = $SORT_DIRECTION->{'DESCENDING'};
    }
    if ( $currentDirection == $SORT_DIRECTION->{'DESCENDING'} ) {
        $newDirection = $SORT_DIRECTION->{'NONE'};
    }
    if ( $currentDirection == $SORT_DIRECTION->{'NONE'} ) {
        $newDirection = $SORT_DIRECTION->{'ASCENDING'};
    }
    return $newDirection;
}

=pod

_createCssStyles( $writeDefaults, $inAttrs ) -> ($id, @styles)

Explicitly set styles override html styling (in this file marked with comment '# html attribute').

=cut

sub _createCssStyles {
    my ( $writeDefaults, $inAttrs ) = @_;

    _debug("_createCssStyles; writeDefaults=$writeDefaults");

    my @styles = ();

    if ( $writeDefaults && !$didWriteDefaultStyle ) {
        my $tableSelector = '.foswikiTable';
        my $attr          = 'padding-left:.3em; vertical-align:text-bottom;';
        push( @styles, ".tableSortIcon img {$attr}" );

        if ( $inAttrs->{cellpadding} ) {
            my $attr =
              'padding:' . addDefaultSizeUnit( $inAttrs->{cellpadding} ) . ';';
            push( @styles, "$tableSelector td {$attr}" );
            push( @styles, "$tableSelector th {$attr}" );
        }
        $didWriteDefaultStyle = 1;
    }

    my $tableSelector;
    my $id;
    if ($writeDefaults) {
        $id            = 'default';
        $tableSelector = ".foswikiTable";
    }
    else {
        $id            = $inAttrs->{id};
        $tableSelector = ".foswikiTable#$id";
    }

    # tablerules
    if ( $inAttrs->{rules} ) {
        my $attr_table = {};
        $attr_table->{all}->{td} = $attr_table->{all}->{th} =
          'border-style:solid;';
        $attr_table->{none}->{td} = $attr_table->{none}->{th} =
          'border-style:none;';
        $attr_table->{cols}->{td} = $attr_table->{cols}->{th} =
          'border-style:none solid;';
        $attr_table->{rows}->{td} = $attr_table->{rows}->{th} =
          'border-style:solid none;';
        $attr_table->{groups}->{td} = 'border-style:none;';
        $attr_table->{groups}->{th} = 'border-style:solid none;';
        my $attr_td = $attr_table->{ $inAttrs->{rules} }->{td};
        my $attr_th = $attr_table->{ $inAttrs->{rules} }->{th};
        push( @styles, "$tableSelector th {$attr_th}" );
        push( @styles, "$tableSelector td {$attr_td}" );
    }

    # tableframe
    if ( $inAttrs->{frame} ) {

        my $attr_table = {};
        $attr_table->{void}   = 'border-style:none;';
        $attr_table->{above}  = 'border-style:solid none none none;';
        $attr_table->{below}  = 'border-style:none none solid none;';
        $attr_table->{lhs}    = 'border-style:none none none solid;';
        $attr_table->{rhs}    = 'border-style:none solid none none;';
        $attr_table->{hsides} = 'border-style:solid none solid none;';
        $attr_table->{vsides} = 'border-style:none solid none solid;';
        $attr_table->{box}    = 'border-style:solid;';
        $attr_table->{border} = 'border-style:solid;';
        my $attr = $attr_table->{ $inAttrs->{frame} };
        push( @styles, "$tableSelector {$attr}" );
    }

    # tableborder
    if ( defined $inAttrs->{border} ) {
        my $tableBorderWidth = $inAttrs->{border} || 0;
        my $attr =
          'border-width:' . addDefaultSizeUnit($tableBorderWidth) . ';';
        push( @styles, "$tableSelector {$attr}" );
    }

    # cellSpacing
    if ( defined $inAttrs->{cellspacing} ) {

        # do not use border-collapse:collapse
        my $attr = 'border-collapse:separate;';
        push( @styles, "$tableSelector {$attr}" );
    }

    # cellborder
    if ( defined $inAttrs->{cellBorder} ) {
        my $cellBorderWidth = $inAttrs->{cellBorder} || 0;
        my $attr = 'border-width:' . addDefaultSizeUnit($cellBorderWidth) . ';';
        push( @styles, "$tableSelector td {$attr}" );
        push( @styles, "$tableSelector th {$attr}" );
    }

    # tablewidth
    if ( defined $inAttrs->{width} ) {
        my $width = addDefaultSizeUnit( $inAttrs->{width} );
        my $attr  = 'width:' . $width . ';';
        push( @styles, "$tableSelector {$attr}" );
    }

    # valign
    if ( defined $inAttrs->{vAlign} ) {
        my $attr = 'vertical-align:' . $inAttrs->{vAlign} . ';';
        push( @styles, "$tableSelector td {$attr}" );
        push( @styles, "$tableSelector th {$attr}" );
    }

    # headerVAlign
    if ( defined $inAttrs->{headerVAlign} ) {
        my $attr = 'vertical-align:' . $inAttrs->{headerVAlign} . ';';
        push( @styles, "$tableSelector th {$attr}" );
    }

    # dataVAlign
    if ( defined $inAttrs->{dataVAlign} ) {
        my $attr = 'vertical-align:' . $inAttrs->{dataVAlign} . ';';
        push( @styles, "$tableSelector td {$attr}" );
    }

    # headerbg
    if ( defined $inAttrs->{headerBg} ) {
        unless ( $inAttrs->{headerBg} =~ /none/i ) {
            my $attr = 'background-color:' . $inAttrs->{headerBg} . ';';
            push( @styles, "$tableSelector th {$attr}" );
        }
    }

    # headerbgsorted
    if ( defined $inAttrs->{headerBgSorted} ) {
        unless ( $inAttrs->{headerBgSorted} =~ /none/i ) {
            my $attr = 'background-color:' . $inAttrs->{headerBgSorted} . ';';
            push( @styles, "$tableSelector th.foswikiSortedCol {$attr}" );
        }
    }

    # headercolor
    if ( defined $inAttrs->{headerColor} ) {
        my $attr = 'color:' . $inAttrs->{headerColor} . ';';
        push( @styles, "$tableSelector th {$attr}" );
        push( @styles,
"$tableSelector th a:link, $tableSelector th a:visited, $tableSelector th a:hover {$attr}"
        );
        if ( defined $inAttrs->{headerBg} ) {
            my $hoverBackgroundColor = $inAttrs->{headerBg};
            $attr = 'background-color:' . $hoverBackgroundColor . ';';
            push( @styles, "$tableSelector th a:hover {$attr}" );
        }
    }

    # databg (array)
    if ( defined $inAttrs->{dataBgListRef} ) {
        my @dataBg = @{ $inAttrs->{dataBgListRef} };
        unless ( $dataBg[0] =~ /none/i ) {
            my $count = 0;
            foreach my $color (@dataBg) {
                next if !$color;
                my $rowSelector = 'foswikiTableRow' . 'dataBg' . $count;
                my $attr        = "background-color:$color;";
                push( @styles, "$tableSelector tr.$rowSelector td {$attr}" );
                $count++;
            }
        }
    }

    # databgsorted (array)
    if ( defined $inAttrs->{dataBgSortedListRef} ) {
        my @dataBgSorted = @{ $inAttrs->{dataBgSortedListRef} };
        unless ( $dataBgSorted[0] =~ /none/i ) {
            my $count = 0;
            foreach my $color (@dataBgSorted) {
                next if !$color;
                my $rowSelector = 'foswikiTableRow' . 'dataBg' . $count;
                my $attr        = "background-color:$color;";
                push( @styles,
                    "$tableSelector tr.$rowSelector td.foswikiSortedCol {$attr}"
                );
                $count++;
            }
        }
    }

    # datacolor (array)
    if ( defined $inAttrs->{dataColorListRef} ) {
        my @dataColor = @{ $inAttrs->{dataColorListRef} };
        unless ( $dataColor[0] =~ /none/i ) {
            my $count = 0;
            foreach my $color (@dataColor) {
                next if !$color;
                my $rowSelector = 'foswikiTableRow' . 'dataColor' . $count;
                my $attr        = "color:$color;";
                push( @styles, "$tableSelector tr.$rowSelector td {$attr}" );
                $count++;
            }
        }
    }

    # columnwidths
    if ( defined $inAttrs->{columnWidthsListRef} ) {
        my @columnWidths = @{ $inAttrs->{columnWidthsListRef} };
        my $count        = 0;
        foreach my $width (@columnWidths) {
            next if !$width;
            $width = addDefaultSizeUnit($width);
            my $colSelector = 'foswikiTableCol';
            $colSelector .= $count;
            my $attr = 'width:' . $width . ';';
            push( @styles, "$tableSelector td.$colSelector {$attr}" );
            push( @styles, "$tableSelector th.$colSelector {$attr}" );
            $count++;
        }
    }

    # headeralign
    if ( defined $inAttrs->{headerAlignListRef} ) {
        my @headerAlign = @{ $inAttrs->{headerAlignListRef} };
        if ( scalar @headerAlign == 1 ) {
            my $align = $headerAlign[0];
            my $attr  = 'text-align:' . $align . ';';
            push( @styles, "$tableSelector th {$attr}" );
        }
        else {
            my $count = 0;
            foreach my $align (@headerAlign) {
                next if !$align;
                my $colSelector = 'foswikiTableCol';
                $colSelector .= $count;
                my $attr = 'text-align:' . $align . ';';
                push( @styles, "$tableSelector th.$colSelector {$attr}" );
                $count++;
            }
        }
    }

    # dataAlign
    if ( defined $inAttrs->{dataAlignListRef} ) {
        my @dataAlign = @{ $inAttrs->{dataAlignListRef} };
        if ( scalar @dataAlign == 1 ) {
            my $align = $dataAlign[0];
            my $attr  = 'text-align:' . $align . ';';
            push( @styles, "$tableSelector td {$attr}" );
        }
        else {
            my $count = 0;
            foreach my $align (@dataAlign) {
                next if !$align;
                my $colSelector = 'foswikiTableCol';
                $colSelector .= $count;
                my $attr = 'text-align:' . $align . ';';
                push( @styles, "$tableSelector td.$colSelector {$attr}" );
                $count++;
            }
        }
    }

    # cellspacing : no good css equivalent; use table tag attribute

    # cellpadding
    if ( defined $inAttrs->{cellpadding} ) {
        my $attr =
          'padding:' . addDefaultSizeUnit( $inAttrs->{cellpadding} ) . ';';
        push( @styles, "$tableSelector td {$attr}" );
        push( @styles, "$tableSelector th {$attr}" );
    }

    return ( $id, @styles );
}

sub _writeStyleToHead {
    my ( $id, @styles ) = @_;

    my $style = join( "\n", @styles );
    my $header =
      '<style type="text/css" media="all">' . "\n" . $style . "\n" . '</style>';
    _debug("_writeStyleToHead; header=$header");
    Foswiki::Func::addToHEAD( 'TABLEPLUGIN_' . $id, $header );
}

=pod

StaticMethod addDefaultSizeUnit ($text) -> $text

Adds size unit 'px' if this is missing from the size text.

=cut

sub addDefaultSizeUnit {
    my ($inSize) = @_;

    my $unit = '';
    if ( $inSize =~ m/$PATTERN_ATTRIBUTE_SIZE/ ) {
        $unit = 'px' if !$2;
    }
    return "$inSize$unit";
}

sub emitTable {

    _debug("emitTable");

    #Validate headerrows/footerrows and modify if out of range
    if ( $combinedTableAttrs->{headerrows} > scalar @curTable ) {
        $combinedTableAttrs->{headerrows} =
          scalar @curTable;    # limit header to size of table!
    }
    if ( $combinedTableAttrs->{headerrows} + $combinedTableAttrs->{footerrows} >
        @curTable )
    {
        $combinedTableAttrs->{footerrows} = scalar @curTable -
          $combinedTableAttrs->{headerrows};    # and footer to whatever is left
    }

    my $sortThisTable = _shouldISortThisTable(
        $curTable[ $combinedTableAttrs->{headerrows} - 1 ] );

    my $tableTagAttributes = {};
    $tableTagAttributes->{class}       = $combinedTableAttrs->{class};
    $tableTagAttributes->{border}      = $combinedTableAttrs->{border};
    $tableTagAttributes->{cellspacing} = $combinedTableAttrs->{cellspacing};
    $tableTagAttributes->{cellpadding} = $combinedTableAttrs->{cellpadding};
    $tableTagAttributes->{id}          = $combinedTableAttrs->{id}
      || 'table' . $tableCount;
    $tableTagAttributes->{summary} = $combinedTableAttrs->{summary};
    $tableTagAttributes->{frame}   = $combinedTableAttrs->{frame};
    $tableTagAttributes->{rules}   = $combinedTableAttrs->{rules};
    $tableTagAttributes->{width}   = $combinedTableAttrs->{width};

    # remove empty attributes
    while ( my ( $key, $value ) = each %{$tableTagAttributes} ) {
        delete $tableTagAttributes->{$key} if !defined $value || $value eq '';
    }

    my $text = $currTablePre . CGI::start_table($tableTagAttributes);
    $text .= $currTablePre . CGI::caption( $combinedTableAttrs->{tableCaption} )
      if $combinedTableAttrs->{tableCaption};
    my $stype = '';

    # count the number of cols to prevent looping over non-existing columns
    my $maxCols = 0;

    #Flush out any remaining rowspans
    for ( my $i = 0 ; $i < @rowspan ; $i++ ) {
        if ( defined( $rowspan[$i] ) && $rowspan[$i] ) {
            my $nRows = scalar(@curTable);
            my $rspan = $rowspan[$i] + 1;
            my $r     = $nRows - $rspan;
            $curTable[$r][$i]->{attrs} ||= {};
            if ( $rspan > 1 ) {
                $curTable[$r][$i]->{attrs}->{rowspan} = $rspan;
            }
        }
    }

    if (
        (
               defined $sortCol
            && defined $requestedTable
            && $requestedTable == $tableCount
        )
        || defined $combinedTableAttrs->{initSort}
      )
    {

        # DG 08 Aug 2002: Allow multi-line headers
        my @header = splice( @curTable, 0, $combinedTableAttrs->{headerrows} );

        # DG 08 Aug 2002: Skip sorting any trailers as well
        my @trailer = ();
        if ( $combinedTableAttrs->{footerrows}
            && scalar(@curTable) > $combinedTableAttrs->{footerrows} )
        {
            @trailer = splice( @curTable, -$combinedTableAttrs->{footerrows} );
        }

        # Count the maximum number of columns of this table
        for my $row ( 0 .. $#curTable ) {
            my $thisRowMaxColCount = 0;
            for my $col ( 0 .. $#{ $curTable[$row] } ) {
                $thisRowMaxColCount++;
            }
            $maxCols = $thisRowMaxColCount
              if ( $thisRowMaxColCount > $maxCols );
        }

        # Handle multi-row labels by killing rowspans in sorted tables
        for my $row ( 0 .. $#curTable ) {
            for my $col ( 0 .. $#{ $curTable[$row] } ) {

                # SMELL: why do we need to specify a rowspan of 1?
                $curTable[$row][$col]->{attrs}->{rowspan} = 1;
                if ( $curTable[$row][$col]->{type} eq 'Y' ) {
                    $curTable[$row][$col]->{text} =
                      $curTable[ $row - 1 ][$col]->{text};
                    $curTable[$row][$col]->{type} = 'td';
                }
            }
        }

        $stype = $COLUMN_TYPE->{'UNDEFINED'};    # default value

        # only get the column type if within bounds
        if ( $sortCol < $maxCols ) {
            $stype = _guessColumnType($sortCol);
        }

        # invalidate sorting if no valid column
        if ( $stype eq $COLUMN_TYPE->{'UNDEFINED'} ) {
            delete $combinedTableAttrs->{initSort};
            undef $sortCol;
        }
        elsif ( $stype eq $COLUMN_TYPE->{'TEXT'} ) {
            if ( $currentSortDirection == $SORT_DIRECTION->{'DESCENDING'} ) {

                # efficient way of sorting stripped HTML text
                # SMELL: efficient? That's not efficient!
                @curTable = map { $_->[0] }
                  sort { $b->[1] cmp $a->[1] }
                  map { [ $_, lc( $_->[$sortCol]->{text} ) ] } @curTable;
            }
            if ( $currentSortDirection == $SORT_DIRECTION->{'ASCENDING'} ) {
                @curTable = map { $_->[0] }
                  sort { $a->[1] cmp $b->[1] }
                  map { [ $_, lc( $_->[$sortCol]->{text} ) ] } @curTable;
            }
        }
        else {
            if ( $currentSortDirection == $SORT_DIRECTION->{'DESCENDING'} ) {
                @curTable =
                  sort { $b->[$sortCol]->{$stype} <=> $a->[$sortCol]->{$stype} }
                  @curTable;
            }
            if ( $currentSortDirection == $SORT_DIRECTION->{'ASCENDING'} ) {
                @curTable =
                  sort { $a->[$sortCol]->{$stype} <=> $b->[$sortCol]->{$stype} }
                  @curTable;
            }

        }

        # DG 08 Aug 2002: Cleanup after the header/trailer splicing
        # this is probably awfully inefficient - but how big is a table?
        @curTable = ( @header, @curTable, @trailer );
    }    # if defined $sortCol ...

    my $rowCount       = 0;
    my $numberOfRows   = scalar(@curTable);
    my $dataColorCount = 0;

    my @headerRowList = ();
    my @bodyRowList   = ();
    my @footerRowList = ();

    my $isPastHeaderRows = 0;
    my $singleIndent     = "\n\t";
    my $doubleIndent     = "\n\t\t";
    my $tripleIndent     = "\n\t\t\t";
    my $sortLinksWritten = 0;
    my $writingSortLinks = 0;

    foreach my $row (@curTable) {
        my $rowtext  = '';
        my $colCount = 0;

        # keep track of header cells: if all cells are header cells, do not
        # update the data color count
        my $headerCellCount = 0;
        my $numberOfCols    = scalar(@$row);

        foreach my $fcell (@$row) {

            # check if cell exists
            next if ( !$fcell || !$fcell->{type} );

            my $tableAnchor = '';
            next
              if ( $fcell->{type} eq 'X' )
              ;    # data was there so sort could work with col spanning
            my $type = $fcell->{type};
            my $cell = $fcell->{text};
            my $attr = $fcell->{attrs} || {};

            my $newDirection;
            my $isSorted = 0;

            if (
                   $currentSortDirection != $SORT_DIRECTION->{'NONE'}
                && defined $sortCol
                && $colCount == $sortCol

                # Removing the line below hides the marking of sorted columns
                # until the user clicks on a header (KJL)
                # && defined $requestedTable && $requestedTable == $tableCount
                && $stype ne ''
              )
            {
                $isSorted     = 1;
                $newDirection = _getNewSortDirection($currentSortDirection);
            }
            else {
                $newDirection = _getDefaultSortDirection();
            }

            if ( $type eq 'th' ) {
                $headerCellCount++;

                if ($isSorted) {
                    if ( $currentSortDirection ==
                        $SORT_DIRECTION->{'ASCENDING'} )
                    {
                        $tableAnchor = $CHAR_SORT_ASCENDING;
                    }
                    if ( $currentSortDirection ==
                        $SORT_DIRECTION->{'DESCENDING'} )
                    {
                        $tableAnchor = $CHAR_SORT_DESCENDING;
                    }
                }

                if (   defined $sortCol
                    && $colCount == $sortCol
                    && defined $requestedTable
                    && $requestedTable == $tableCount )
                {

                    $tableAnchor =
                      CGI::a( { name => 'sorted_table' }, '<!-- -->' )
                      . $tableAnchor;
                }

    # just allow this table to be sorted.
    #                if (   $sortThisTable
    #                    && $rowCount == $combinedTableAttrs->{headerrows} - 1 )
                if ( $sortThisTable && !$sortLinksWritten ) {
                    $writingSortLinks = 1;
                    my $debugText      = '';
                    my $linkAttributes = {
                        href => $url
                          . 'sortcol='
                          . $colCount
                          . ';table='
                          . $tableCount . ';up='
                          . $newDirection
                          . '#sorted_table',
                        rel   => 'nofollow',
                        title => 'Sort by this column'
                    };
                    if ( $cell =~ /\[\[|href/o ) {
                        $cell .=
                            $debugText . ' '
                          . CGI::a( $linkAttributes, $CHAR_SORT_BOTH )
                          . $tableAnchor;
                    }
                    else {
                        $cell =
                            $debugText
                          . CGI::a( $linkAttributes, $cell )
                          . $tableAnchor;
                    }
                }

            }
            else {

                $type = 'td' unless $type eq 'Y';
            }    ###if( $type eq 'th' )

            if ($isSorted) {
                $attr->{class} = _appendSortedCssClass( $attr->{class} );
            }

            my $isLastRow = ( $rowCount == $numberOfRows - 1 );
            if ( $attr->{rowspan} ) {
                $isLastRow =
                  ( ( $rowCount + ( $attr->{rowspan} - 1 ) ) ==
                      $numberOfRows - 1 );
            }

            # CSS class name
            $attr->{class} = _appendFirstColumnCssClass( $attr->{class} )
              if $colCount == 0;
            my $isLastCol = ( $colCount == $numberOfCols - 1 );
            $attr->{class} = _appendLastColumnCssClass( $attr->{class} )
              if $isLastCol;

            $attr->{class} = _appendLastRowCssClass( $attr->{class} )
              if $isLastRow;

            $colCount++;
            next if ( $type eq 'Y' );
            my $fn = 'CGI::' . $type;
            no strict 'refs';
            $rowtext .= "$tripleIndent" . &$fn( $attr, " $cell " );
            use strict 'refs';
        }    # foreach my $fcell ( @$row )

        if ($writingSortLinks) {
            $writingSortLinks = 0;
            $sortLinksWritten = 1;
        }

        # assign css class names to tr
        # based on settings: dataBg, dataBgSorted
        my $trClassName = '';

        # just 2 css names is too limited, but we will keep it for compatibility
        # with existing style sheets
        my $rowTypeName =
          ( $rowCount % 2 ) ? 'foswikiTableEven' : 'foswikiTableOdd';
        $trClassName = _appendToClassList( $trClassName, $rowTypeName );

        if ( $combinedTableAttrs->{dataBgSortedListRef} ) {
            my @dataBgSorted = @{ $combinedTableAttrs->{dataBgSortedListRef} };
            my $modRowNum = $dataColorCount % ( $#dataBgSorted + 1 );
            $trClassName =
              _appendRowNumberCssClass( $trClassName, 'dataBgSorted',
                $modRowNum );
        }
        if ( $combinedTableAttrs->{dataBgListRef} ) {
            my @dataBg = @{ $combinedTableAttrs->{dataBgListRef} };
            my $modRowNum = $dataColorCount % ( $#dataBg + 1 );
            $trClassName =
              _appendRowNumberCssClass( $trClassName, 'dataBg', $modRowNum );
        }
        if ( $combinedTableAttrs->{dataColorListRef} ) {
            my @dataColor = @{ $combinedTableAttrs->{dataColorListRef} };
            my $modRowNum = $dataColorCount % ( $#dataColor + 1 );
            $trClassName =
              _appendRowNumberCssClass( $trClassName, 'dataColor', $modRowNum );
        }
        $rowtext .= $doubleIndent;
        my $rowHTML =
          $doubleIndent . CGI::Tr( { class => $trClassName }, $rowtext );

        my $isHeaderRow = ( $headerCellCount == $colCount );
        my $isFooterRow =
          ( ( $numberOfRows - $rowCount ) <=
              $combinedTableAttrs->{footerrows} );

        if ( !$isHeaderRow && !$isFooterRow ) {

        # don't include non-adjacent header rows to the top block of header rows
            $isPastHeaderRows = 1;
        }

        if ($isFooterRow) {
            push @footerRowList, $rowHTML;
        }
        elsif ( $isHeaderRow && !$isPastHeaderRows ) {
            push( @headerRowList, $rowHTML );
        }
        else {
            push @bodyRowList, $rowHTML;
            $dataColorCount++;
        }

        if ($isHeaderRow) {

            # reset data color count to start with first color after
            # each table heading
            $dataColorCount = 0;
        }

        $rowCount++;
    }    # foreach my $row ( @curTable )

    my $thead =
        "$singleIndent<thead>"
      . join( "", @headerRowList )
      . "$singleIndent</thead>";
    $text .= $currTablePre . $thead if scalar @headerRowList;

    my $tfoot =
        "$singleIndent<tfoot>"
      . join( "", @footerRowList )
      . "$singleIndent</tfoot>";
    $text .= $currTablePre . $tfoot if scalar @footerRowList;

    my $tbody =
        "$singleIndent<tbody>"
      . join( "", @bodyRowList )
      . "$singleIndent</tbody>";
    $text .= $currTablePre . $tbody if scalar @bodyRowList;

    $text .= $currTablePre . CGI::end_table() . "\n";

    # prepare for next table
    _setDefaults();

    return $text;
}

sub handler {
    ### my ( $text, $removed ) = @_;

    _debug("handler");

    unless ($Foswiki::Plugins::TablePlugin::initialised) {
        $insideTABLE = 0;
        $tableCount  = 0;

        my $cgi = Foswiki::Func::getCgiQuery();
        return unless $cgi;

        # Copy existing values
        my ( @origSort, @origTable, @origUp );
        @origSort  = $cgi->param('sortcol');
        @origTable = $cgi->param('table');
        @origUp    = $cgi->param('up');        # NOTE: internal parameter
        $cgi->delete( 'sortcol', 'table', 'up' );
        $url = $cgi->url( -absolute => 1, -path => 1 ) . '?';
        my $queryString = $cgi->query_string();
        $url .= $queryString . ';' if $queryString;

        # Restore parameters, so we don't interfere on the remaining execution
        $cgi->param( -name => 'sortcol', -value => \@origSort )  if @origSort;
        $cgi->param( -name => 'table',   -value => \@origTable ) if @origTable;
        $cgi->param( -name => 'up',      -value => \@origUp )    if @origUp;

        $sortColFromUrl =
          $cgi->param('sortcol');              # zero based: 0 is first column
        $requestedTable = $cgi->param('table');
        $up             = $cgi->param('up');

        $sortTablesInText = 0;
        $sortAttachments  = 0;
        my $tmp = Foswiki::Func::getPreferencesValue('TABLEPLUGIN_SORT')
          || 'all';
        if ( !$tmp || $tmp =~ /^all$/oi ) {
            $sortTablesInText = 1;
            $sortAttachments  = 1;
        }
        elsif ( $tmp =~ /^attachments$/oi ) {
            $sortAttachments = 1;
        }

        _setDefaults();    # first time
        $Foswiki::Plugins::TablePlugin::initialised = 1;
    }

    #delete $combinedTableAttrs->{initSort};
    $insideTABLE = 0;

    my $defaultSort = $sortAllTables;

    my $acceptable = $sortAllTables;
    my @lines = split( /\r?\n/, $_[0] );
    for (@lines) {
        if (
s/%TABLE(?:{(.*?)})?%/_parseTableSpecificTableAttributes(Foswiki::Func::extractParameters($1))/se
          )
        {
            $acceptable = 1;
        }
        elsif (s/^(\s*)\|(.*\|\s*)$/_processTableRow($1,$2)/eo) {
            $insideTABLE = 1;
        }
        elsif ($insideTABLE) {
            $_           = emitTable() . $_;
            $insideTABLE = 0;

            #            delete $combinedTableAttrs->{initSort};
            $sortAllTables = $defaultSort;
            $acceptable    = $defaultSort;
        }
    }
    $_[0] = join( "\n", @lines );

    if ($insideTABLE) {
        $_[0] .= emitTable();
    }
}

=pod

_mergeHashes (\%a, \%b ) -> \%merged

Merges 2 hash references.

=cut

sub _mergeHashes {
    my ( $A, $B ) = @_;

    my %merged = ();
    while ( my ( $k, $v ) = each(%$A) ) {
        $merged{$k} = $v;
    }
    while ( my ( $k, $v ) = each(%$B) ) {
        $merged{$k} = $v;
    }
    return \%merged;
}

=pod

Shorthand debugging call.

=cut

sub _debug {
    return Foswiki::Plugins::TablePlugin::debug(@_);
}

sub _debugData {
    return Foswiki::Plugins::TablePlugin::debugData(@_);
}

1;
