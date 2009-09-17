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
my $currTablePre;
my $didWriteDefaultStyle;
my $defaultAttrs;          # to write generic table CSS
my $tableSpecificAttrs;    # to write table specific table CSS
my $combinedTableAttrs;    # default and specific table attributes
my $styles = {};           # hash of default and specific styles

# not yet refactored:
my $tableCount;
my $sortCol;
my $MAX_SORT_COLS;
my $requestedTable;
my $up;
my $sortTablesInText;
my $sortAttachments;
my $sortColFromUrl;
my $url;
my $currentSortDirection;
my @rowspan;

my $HEAD_ID_DEFAULT_STYLE =
  'TABLEPLUGIN_default';    # this name is part of the API, do not change
my $HEAD_ID_SPECIFIC_STYLE =
  'TABLEPLUGIN_specific';    # this name is part of the API, do not change

my $PATTERN_TABLE = qr/%TABLE(?:{(.*?)})?%/;
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

my $TABLE_RULES = {};
$TABLE_RULES->{all}->{TD}        = $TABLE_RULES->{all}->{TH} =
  $TABLE_RULES->{data_all}->{TD} = $TABLE_RULES->{header_all}->{TH} =
  'border-style:solid';
$TABLE_RULES->{none}->{TD}        = $TABLE_RULES->{none}->{TH} =
  $TABLE_RULES->{data_none}->{TD} = $TABLE_RULES->{header_none}->{TH} =
  'border-style:none';
$TABLE_RULES->{cols}->{TD}        = $TABLE_RULES->{cols}->{TH} =
  $TABLE_RULES->{data_cols}->{TD} = $TABLE_RULES->{header_cols}->{TH} =
  'border-style:none solid';
$TABLE_RULES->{rows}->{TD}        = $TABLE_RULES->{rows}->{TH} =
  $TABLE_RULES->{data_rows}->{TD} = $TABLE_RULES->{header_rows}->{TH} =
  'border-style:solid none';
$TABLE_RULES->{groups}->{TD} = 'border-style:none';
$TABLE_RULES->{groups}->{TH} = 'border-style:solid none';

my $TABLE_FRAME = {};
$TABLE_FRAME->{void}   = 'border-style:none';
$TABLE_FRAME->{above}  = 'border-style:solid none none none';
$TABLE_FRAME->{below}  = 'border-style:none none solid none';
$TABLE_FRAME->{lhs}    = 'border-style:none none none solid';
$TABLE_FRAME->{rhs}    = 'border-style:none solid none none';
$TABLE_FRAME->{hsides} = 'border-style:solid none solid none';
$TABLE_FRAME->{vsides} = 'border-style:none solid none solid';
$TABLE_FRAME->{box}    = 'border-style:solid';
$TABLE_FRAME->{border} = 'border-style:solid';

BEGIN {
    $translationToken = "\0";

    # the maximum number of columns we will handle
    $MAX_SORT_COLS        = 10000;
    $didWriteDefaultStyle = 0;
    $tableCount           = 0;
    $currTablePre         = '';
    $combinedTableAttrs   = {};
    $tableSpecificAttrs   = {};
}

sub _initDefaults {
    _debug('_initDefaults');
    $defaultAttrs                  = {};
    $defaultAttrs->{headerrows}    = 1;
    $defaultAttrs->{footerrows}    = 0;
    $defaultAttrs->{class}         = 'foswikiTable';
    $defaultAttrs->{sortAllTables} = $sortTablesInText;

    _parseDefaultAttributes(
        %{Foswiki::Plugins::TablePlugin::pluginAttributes} );

    $combinedTableAttrs = _mergeHashes( {}, $defaultAttrs );

    # create CSS styles tables in general
    my ( $id, @styles ) = _createCssStyles( 1, $defaultAttrs );
    _addHeadStyles( $HEAD_ID_DEFAULT_STYLE, @styles ) if scalar @styles;
}

sub _resetReusedVariables {
    _debug('_resetReusedVariables');
    $currTablePre       = '';
    $combinedTableAttrs = _mergeHashes( {}, $defaultAttrs );
    $tableSpecificAttrs = {};
    $sortCol            = 0;
}

=pod

=cut

sub _storeAttribute {
    my ( $inAttrName, $inValue, $inCollection ) = @_;

    if ( !$inCollection ) {
        _debug('_storeAttribute -- missing inCollection!');
        return;
    }
    return if !defined $inValue;
    return if !defined $inAttrName || $inAttrName eq '';
    $inCollection->{$inAttrName} = $inValue;
}

=pod

=cut

sub _parseDefaultAttributes {
    my (%params) = @_;

    _debug('_parseDefaultAttributes');

    _parseAttributes( 0, $defaultAttrs, \%params );
}

=pod

=cut

sub _parseTableSpecificTableAttributes {
    my (%params) = @_;

    _debug('_parseTableSpecificTableAttributes');

    _parseAttributes( 1, $tableSpecificAttrs, \%params );

    # remove default values from hash
    while ( my ( $key, $value ) = each %{$tableSpecificAttrs} ) {
        delete $tableSpecificAttrs->{$key}
          if $defaultAttrs->{$key} && $value eq $defaultAttrs->{$key};
    }
    $combinedTableAttrs =
      _mergeHashes( $combinedTableAttrs, $tableSpecificAttrs );
    _debugData( 'combinedTableAttrs', $combinedTableAttrs );

    # create CSS styles for this table only
    my ( $id, @styles ) = _createCssStyles( 0, $tableSpecificAttrs );
    _debugData( "after _createCssStyles, id=$id; styles", \@styles );

    _addHeadStyles( $id, @styles ) if scalar @styles;

    return $currTablePre . '<nop>';
}

=pod

=cut

sub _cleanParamValue {
    my ($inValue) = @_;

    return undef if !$inValue;

    $inValue =~ s/ //go;    # remove spaces
    return $inValue;
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

    _debugData( "modeSpecific=$modeSpecific; _parseAttributes=", $inParams );

    # include topic to read definitions
    my $includeTopicParam = $inParams->{include};
    $inParams = _getIncludeParams($includeTopicParam) if $includeTopicParam;
    
    # table attributes
    # some will be used for css styling as well

    # sort
    if ($modeSpecific) {
        my $sort = Foswiki::Func::isTrue( $inParams->{sort} || 'on' );
        _storeAttribute( 'sort', $sort, $inCollection );
        _storeAttribute( 'initSort', $inParams->{initsort}, $inCollection );
        _storeAttribute( 'sortAllTables', $sort, $inCollection );
        if ( $inParams->{initdirection} ) {
            _storeAttribute( 'initDirection', $SORT_DIRECTION->{'ASCENDING'},
                $inCollection )
              if $inParams->{initdirection} =~ /^down$/i;
            _storeAttribute( 'initDirection', $SORT_DIRECTION->{'DESCENDING'},
                $inCollection )
              if $inParams->{initdirection} =~ /^up$/i;
        }

        # If EditTablePlugin is installed and we are editing a table,
        # the CGI parameter 'sort' is defined as "off" to disable all
        # header sorting ((Item5135)
        my $cgi          = Foswiki::Func::getCgiQuery();
        my $urlParamSort = $cgi->param('sort');
        if ( $urlParamSort && $urlParamSort =~ /^off$/oi ) {
            delete $inCollection->{sortAllTables};
        }

      # If EditTablePlugin is installed and we are editing a table, the
      # 'disableallsort' TABLE parameter is added to disable initsort and header
      # sorting in the table that is being edited. (Item5135)
        if ( Foswiki::Func::isTrue( $inParams->{disableallsort} ) ) {
            $inCollection->{sortAllTables} = 0;
            delete $inCollection->{initSort};
        }
    }

    if ($modeSpecific) {
        _storeAttribute( 'summary', $inParams->{summary}, $inCollection );
        my $id = $inParams->{id}
          || 'table'
          . $Foswiki::Plugins::TablePlugin::topic
          . ( $tableCount + 1 );
        _storeAttribute( 'id',         $id,                     $inCollection );
        _storeAttribute( 'headerrows', $inParams->{headerrows}, $inCollection );
        _storeAttribute( 'footerrows', $inParams->{footerrows}, $inCollection );
    }
    _storeAttribute( 'border', $inParams->{tableborder}, $inCollection );
    _storeAttribute( 'tableBorderColor', $inParams->{tablebordercolor},
        $inCollection );
    _storeAttribute( 'cellpadding', $inParams->{cellpadding}, $inCollection );
    _storeAttribute( 'cellspacing', $inParams->{cellspacing}, $inCollection );
    _storeAttribute( 'frame',       $inParams->{tableframe},  $inCollection );

    # tablerules css settings
    my @tableRulesList = ();
    if ( $inParams->{tablerules} ) {

        # store tablerules as array, so that headerrules and datarules
        # can be appended to that list
        my $param = _cleanParamValue( $inParams->{tablerules} );
        if ($param) {
            push( @tableRulesList, $param );
        }
    }
    if ( $inParams->{headerrules} ) {
        my $param = _cleanParamValue( $inParams->{headerrules} );
        if ($param) {
            $param = "header_$param";
            push( @tableRulesList, $param );
        }
    }
    if ( $inParams->{datarules} ) {
        my $param = _cleanParamValue( $inParams->{datarules} );
        if ($param) {
            $param = "data_$param";
            push( @tableRulesList, $param );
        }
    }
    $inCollection->{tableRules} = \@tableRulesList if scalar @tableRulesList;

    # use 'rules' as table attribute only (not to define css styles)
    # but set to
    my $rules =
      ( defined $inParams->{headerrules} || defined $inParams->{datarules} )
      ? 'none'
      : $inParams->{tablerules};
    _storeAttribute( 'rules', $rules, $inCollection );

    _storeAttribute( 'width', $inParams->{tablewidth}, $inCollection );

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

    _debugData( '_parseAttributes result:', $inCollection );
}

=pod

_getIncludeParams( $includeTopic ) -> \%params

From $includeTopic read the first TABLE tag and return its parameters.

=cut

sub _getIncludeParams {
    my ($inIncludeTopic) = @_;

    my ( $includeWeb, $includeTopic ) =
      Foswiki::Func::normalizeWebTopicName( $Foswiki::Plugins::TablePlugin::web,
        $inIncludeTopic );

    _debug("_getIncludeParams:$inIncludeTopic");
    _debug("\t includeTopic=$includeTopic") if $includeTopic;
    
    if ( !Foswiki::Func::topicExists( $includeWeb, $includeTopic ) ) {
        _debug("TablePlugin: included topic $inIncludeTopic does not exist.");
        die("TablePlugin: included topic $inIncludeTopic does not exist.");
    }
    else {

        my $text = Foswiki::Func::readTopicText( $includeWeb, $includeTopic );

        $text =~ /$PATTERN_TABLE/os;
        if ($1) {
            my $paramString = $1;

            if (   $includeWeb ne $Foswiki::Plugins::TablePlugin::web
                || $includeTopic ne $Foswiki::Plugins::TablePlugin::topic )
            {

                # expand common vars, except oneself to prevent recursion
                $paramString =
                  Foswiki::Func::expandCommonVariables( $paramString,
                    $includeTopic, $includeWeb );
            }
            my %params = Foswiki::Func::extractParameters($paramString);
            return \%params;
        }
    }
    return undef;
}

=pod

Convert text to number and date if syntactically possible

=cut

sub _convertToNumberAndDate {
    my ($text) = @_;

    $text = _stripHtml($text);
    _debug("_convertToNumberAndDate:$text");
    if ( $text =~ /^\s*$/ ) {
        return ( undef, undef );
    }

    my $num  = undef;
    my $date = undef;

    # Unless the table cell is a pure number
    # we test if it is a date.
    if ( $text =~ /^\s*-?[0-9]+(\.[0-9]+)?\s*$/ ) {
        _debug("\t this is a number");
        $num = $text;
    }
    else {
        try {
            $date = _parseTime($text);
        }
        catch Error::Simple with {

            # nope, wasn't a date
            _debug("\t this is not a date");
        };
    }
    _debug("\t this is a date") if defined $date;
    if ( !defined $num && !defined $date ) {

        # very course testing on IP (could in fact be anything with n.n. syntax
        if ( $text =~ /^\s*\b\d{1,}\.\d{1,}\.(?:.*?)$/ ) {
            _debug("\t this looks like an IP address, or something similar");

            # should be sorted by text

        }
        elsif ( $text =~ /^\s*(-?[0-9]+)(\.[0-9]+)?/ ) {

            # test for:
            # 8 - whole numbers
            # 8.1 - decimal numbers
            # 8K - strings that start with a number
            # 8.1K - idem

            _debug("\t this is a number with decimal");
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
            $sortCol = $sortColFromUrl;
            $sortCol = $MAX_SORT_COLS if ( $sortCol > $MAX_SORT_COLS );
            $currentSortDirection = _getCurrentSortDirection($up);
        }
        elsif ( defined $combinedTableAttrs->{initSort} ) {
            $sortCol = $combinedTableAttrs->{initSort} - 1;
            $sortCol = $MAX_SORT_COLS if ( $sortCol > $MAX_SORT_COLS );
            $currentSortDirection =
              _getCurrentSortDirection( $combinedTableAttrs->{initDirection} );
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

    return 0 unless $combinedTableAttrs->{sortAllTables};

    # All cells in header are headings?
    #foreach my $cell (@$header) {
    #return 0 if ( $cell->{type} ne 'th' );
    #}

    return 1;
}

# Guess if column is a date, number or plain text
sub _guessColumnType {
    my ($col)         = @_;
    my $isDate        = 0;
    my $isNum         = 0;
    my $columnIsValid = 0;
    foreach my $row (@curTable) {
        next if ( $row->[$col]->{text} =~ /^\s*$/ );

        # else
        $columnIsValid = 1;
        my ( $num, $date ) = _convertToNumberAndDate( $row->[$col]->{text} );

        if ( defined $date ) {
            $isDate = 1;
            $row->[$col]->{date} = $date;
        }
        elsif ( defined $num ) {
            $isNum = 1;
            $row->[$col]->{number} = $num;
        }
        else {
            last;
        }
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

    my $_styles      = {};
    my $setAttribute = sub {
        my ( $tableSelector, $type, $rule ) = @_;

        return if !$rule;
        $type ||= '#';    # for table selector only, if no type
        my $storedType = $_styles->{$tableSelector}->{$type} || '';
        if ( !defined $storedType ) {
            @{ $_styles->{$tableSelector}->{$type} } = ();
        }
        if ( $rule ne $storedType ) {
            push @{ $_styles->{$tableSelector}->{$type} }, $rule;
        }
    };

    if ( $writeDefaults && !$didWriteDefaultStyle ) {
        my $tableSelector = '.foswikiTable';
        my $attr          = 'padding-left:.3em; vertical-align:text-bottom';
        &$setAttribute( $tableSelector, '.tableSortIcon img', $attr );

        if ( $inAttrs->{cellpadding} ) {
            my $attr =
              'padding:' . addDefaultSizeUnit( $inAttrs->{cellpadding} );
            &$setAttribute( $tableSelector, 'td', $attr );
            &$setAttribute( $tableSelector, 'th', $attr );
        }
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
    if ( $inAttrs->{tableRules} ) {
        my @rules = @{ $inAttrs->{tableRules} };

        my $attr_td;
        my $attr_th;
        foreach my $rule (@rules) {
            $attr_td = $TABLE_RULES->{$rule}->{TD}
              if $TABLE_RULES->{$rule}->{TD};
            $attr_th = $TABLE_RULES->{$rule}->{TH}
              if $TABLE_RULES->{$rule}->{TH};
        }
        &$setAttribute( $tableSelector, 'th', $attr_th );
        &$setAttribute( $tableSelector, 'td', $attr_td );
    }

    # tableframe
    if ( $inAttrs->{frame} ) {
        my $attr = $TABLE_FRAME->{ $inAttrs->{frame} };
        &$setAttribute( $tableSelector, '', $attr );
    }

    # tableborder
    if ( defined $inAttrs->{border} ) {
        my $tableBorderWidth = $inAttrs->{border} || 0;
        my $attr = 'border-width:' . addDefaultSizeUnit($tableBorderWidth);
        &$setAttribute( $tableSelector, '', $attr );
    }

    # tableBorderColor
    if ( defined $inAttrs->{tableBorderColor} ) {
        my $attr;
        $attr = 'border-color:' . $inAttrs->{tableBorderColor};
        &$setAttribute( $tableSelector, '', $attr );
        $attr = 'border-top-color:' . $inAttrs->{tableBorderColor};
        &$setAttribute( $tableSelector, '', $attr );
        $attr = 'border-bottom-color:' . $inAttrs->{tableBorderColor};
        &$setAttribute( $tableSelector, '', $attr );
        $attr = 'border-left-color:' . $inAttrs->{tableBorderColor};
        &$setAttribute( $tableSelector, '', $attr );
        $attr = 'border-right-color:' . $inAttrs->{tableBorderColor};
        &$setAttribute( $tableSelector, '', $attr );
    }

    # cellSpacing
    if ( defined $inAttrs->{cellspacing} ) {

        # do not use border-collapse:collapse
        my $attr = 'border-collapse:separate';
        &$setAttribute( $tableSelector, '', $attr );
    }

    # cellpadding
    if ( defined $inAttrs->{cellpadding} ) {
        my $attr = 'padding:' . addDefaultSizeUnit( $inAttrs->{cellpadding} );
        &$setAttribute( $tableSelector, 'td', $attr );
        &$setAttribute( $tableSelector, 'th', $attr );
    }

    # cellborder
    if ( defined $inAttrs->{cellBorder} ) {
        my $cellBorderWidth = $inAttrs->{cellBorder} || 0;
        my $attr = 'border-width:' . addDefaultSizeUnit($cellBorderWidth);
        &$setAttribute( $tableSelector, 'td', $attr );
        &$setAttribute( $tableSelector, 'th', $attr );
    }

    # tablewidth
    if ( defined $inAttrs->{width} ) {
        my $width = addDefaultSizeUnit( $inAttrs->{width} );
        my $attr  = 'width:' . $width;
        &$setAttribute( $tableSelector, '', $attr );
    }

    # valign
    if ( defined $inAttrs->{vAlign} ) {
        my $attr = 'vertical-align:' . $inAttrs->{vAlign};
        &$setAttribute( $tableSelector, 'td', $attr );
        &$setAttribute( $tableSelector, 'th', $attr );
    }

    # headerVAlign
    if ( defined $inAttrs->{headerVAlign} ) {
        my $attr = 'vertical-align:' . $inAttrs->{headerVAlign};
        &$setAttribute( $tableSelector, 'th', $attr );
    }

    # dataVAlign
    if ( defined $inAttrs->{dataVAlign} ) {
        my $attr = 'vertical-align:' . $inAttrs->{dataVAlign};
        &$setAttribute( $tableSelector, 'td', $attr );
    }

    # headerbg
    if ( defined $inAttrs->{headerBg} ) {
        unless ( $inAttrs->{headerBg} =~ /none/i ) {
            my $attr = 'background-color:' . $inAttrs->{headerBg};
            &$setAttribute( $tableSelector, 'th', $attr );
        }
    }

    # headerbgsorted
    if ( defined $inAttrs->{headerBgSorted} ) {
        unless ( $inAttrs->{headerBgSorted} =~ /none/i ) {
            my $attr = 'background-color:' . $inAttrs->{headerBgSorted};
            &$setAttribute( $tableSelector, 'th.foswikiSortedCol', $attr );
        }
    }

    # headercolor
    if ( defined $inAttrs->{headerColor} ) {
        my $attr = 'color:' . $inAttrs->{headerColor};
        &$setAttribute( $tableSelector, 'th',           $attr );
        &$setAttribute( $tableSelector, 'th a:link',    $attr );
        &$setAttribute( $tableSelector, 'th a:visited', $attr );
        &$setAttribute( $tableSelector, 'th a:xhover',  $attr )
          ; # just to make sorting work: hover should be last. below we will remove the x again.
        if ( defined $inAttrs->{headerBg} ) {
            my $hoverBackgroundColor = $inAttrs->{headerBg};
            $attr = 'background-color:' . $hoverBackgroundColor;
            &$setAttribute( $tableSelector, 'th a:xhover', $attr );
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
                my $attr        = "background-color:$color";
                &$setAttribute( $tableSelector, "tr.$rowSelector td", $attr );
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
                my $attr        = "background-color:$color";
                &$setAttribute( $tableSelector,
                    "tr.$rowSelector td.foswikiSortedCol", $attr );
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
                my $attr        = "color:$color";
                &$setAttribute( $tableSelector, "tr.$rowSelector td", $attr );
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
            my $attr = 'width:' . $width;
            &$setAttribute( $tableSelector, "td.$colSelector", $attr );
            &$setAttribute( $tableSelector, "th.$colSelector", $attr );
            $count++;
        }
    }

    # headeralign
    if ( defined $inAttrs->{headerAlignListRef} ) {
        my @headerAlign = @{ $inAttrs->{headerAlignListRef} };
        if ( scalar @headerAlign == 1 ) {
            my $align = $headerAlign[0];
            my $attr  = 'text-align:' . $align;
            &$setAttribute( $tableSelector, 'th', $attr );
        }
        else {
            my $count = 0;
            foreach my $align (@headerAlign) {
                next if !$align;
                my $colSelector = 'foswikiTableCol';
                $colSelector .= $count;
                my $attr = 'text-align:' . $align;
                &$setAttribute( $tableSelector, "th.$colSelector", $attr );
                $count++;
            }
        }
    }

    # dataAlign
    if ( defined $inAttrs->{dataAlignListRef} ) {
        my @dataAlign = @{ $inAttrs->{dataAlignListRef} };
        if ( scalar @dataAlign == 1 ) {
            my $align = $dataAlign[0];
            my $attr  = 'text-align:' . $align;
            &$setAttribute( $tableSelector, 'td', $attr );
        }
        else {
            my $count = 0;
            foreach my $align (@dataAlign) {
                next if !$align;
                my $colSelector = 'foswikiTableCol';
                $colSelector .= $count;
                my $attr = 'text-align:' . $align;
                &$setAttribute( $tableSelector, "td.$colSelector", $attr );
                $count++;
            }
        }
    }

    my @styles = ();
    foreach my $tableSelector ( sort keys %{$_styles} ) {
        foreach my $selector ( sort keys %{ $_styles->{$tableSelector} } ) {
            my $selectors =
              join( '; ', @{ $_styles->{$tableSelector}->{$selector} } );
            $selector =~ s/xhover/hover/go;    # remove sorting hack
                 # TODO: optimize by combining identical rules
            if ( $selector eq '#' ) {
                push @styles, "$tableSelector {$selectors}";
            }
            else {
                push @styles, "$tableSelector $selector {$selectors}";
            }
        }
    }

    return ( $id, @styles );
}

sub _addHeadStyles {
    my ( $inId, @inStyles ) = @_;

    return if !scalar @inStyles;

    $styles->{seendIds}->{$inId} = 1;
    if ( $inId eq $HEAD_ID_DEFAULT_STYLE ) {
        $styles->{$HEAD_ID_DEFAULT_STYLE}->{'default'} = \@inStyles;
        _writeStyleToHead( $HEAD_ID_DEFAULT_STYLE,
            $styles->{$HEAD_ID_DEFAULT_STYLE} );
    }
    else {
        $styles->{$HEAD_ID_SPECIFIC_STYLE}->{$inId} = \@inStyles;
        _writeStyleToHead( $HEAD_ID_SPECIFIC_STYLE,
            $styles->{$HEAD_ID_SPECIFIC_STYLE} );
    }
}

sub _writeStyleToHead {
    my ( $inId, $inStyles ) = @_;

    my @allStyles = ();
    foreach my $id ( sort keys %{$inStyles} ) {
        push @allStyles, @{ $inStyles->{$id} };
    }
    my $styleText = join( "\n", @allStyles );

    my $header = <<EOS;
<style type="text/css" media="all">
$styleText
</style>
EOS
    $header =~ s/(.*?)\s*$/$1/;    # remove last newline
    Foswiki::Func::addToHEAD( $inId, $header, $HEAD_ID_DEFAULT_STYLE );
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

    _debug('emitTable');

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
      || undef;
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

        _debug("Sort by:$stype");
        _debug("currentSortDirection:$currentSortDirection");

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
    _resetReusedVariables();

    return $text;
}

sub handler {
    ### my ( $text, $removed ) = @_;

    _debug('handler');

    unless ($Foswiki::Plugins::TablePlugin::initialised) {
        $insideTABLE = 0;

        # Even if $tableCount is initialized already at plugin init
        # we need to reset it again each time preRenderingHandler
        # calls this handler sub. Important for initialiseWhenRender API
        $tableCount = 0;

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

        _initDefaults();    # first time
        $Foswiki::Plugins::TablePlugin::initialised = 1;
    }

    $insideTABLE = 0;

    my $defaultSort = $combinedTableAttrs->{sortAllTables};

    my $acceptable = $combinedTableAttrs->{sortAllTables};
    my @lines = split( /\r?\n/, $_[0] );
    for (@lines) {
        if (
s/$PATTERN_TABLE/_parseTableSpecificTableAttributes(Foswiki::Func::extractParameters($1))/se
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
            $combinedTableAttrs->{sortAllTables} = $defaultSort;
            $acceptable = $defaultSort;
        }
    }
    $_[0] = join( "\n", @lines );

    if ($insideTABLE) {
        $_[0] .= emitTable();
    }
}

# SMELL: does not account for leap years
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

=begin TML

Copied from Foswiki::Time and changed the unresolved return value from 0 to undef.
Can be removed when Foswiki::Time::parseTime is fixed (http://foswiki.org/Tasks/Item2043).

---++ StaticMethod _parseTime( $szDate, $defaultLocal ) -> $iSecs

Convert string date/time string to seconds since epoch (1970-01-01T00:00:00Z).
   * =$sDate= - date/time string

Handles the following formats:

Default Foswiki format
   * 31 Dec 2001 - 23:59

Foswiki format without time (defaults to 00:00)
   * 31 Dec 2001

Date separated by '/', '.' or '-', time with '.' or ':'
Date and time separated by ' ', '.' and/or '-'
   * 2001/12/31 23:59:59
   * 2001.12.31.23.59.59
   * 2001/12/31 23:59
   * 2001.12.31.23.59
   * 2001-12-31 23:59
   * 2001-12-31 - 23:59
   * 2009-1-12
   * 2009-1
   * 2009

ISO format
   * 2001-12-31T23:59:59
   * 2001-12-31T

ISO dates may have a timezone specifier, either Z or a signed difference
in hh:mm format. For example:
   * 2001-12-31T23:59:59+01:00
   * 2001-12-31T23:59Z
The default timezone is Z, unless $defaultLocal is true in which case
the local timezone will be assumed.

If the date format was not recognised, will return 0.

=cut

sub _parseTime {
    my ( $date, $defaultLocal ) = @_;

    $date =~ s/^\s*//;    #remove leading spaces without de-tainting.
    $date =~ s/\s*$//;

    require Time::Local;

    # NOTE: This routine *will break* if input is not one of below formats!
    my $tzadj = 0;        # Zulu
    if ($defaultLocal) {

        # Local time at midnight on the epoch gives us minus the
        # local difference. e.g. CST is GMT + 1, so midnight Jan 1 1970 CST
        # is -01:00Z
        $tzadj = -Time::Local::timelocal( 0, 0, 0, 1, 0, 70 );
    }

    # try "31 Dec 2001 - 23:59"  (Foswiki date)
    # or "31 Dec 2001"
    #TODO: allow /.: too
    if ( $date =~ /(\d+)\s+([a-z]{3})\s+(\d+)(?:[-\s]+(\d+):(\d+))?/i ) {
        my $year = $3;
        $year -= 1900 if ( $year > 1900 );

        #TODO: %MON2NUM needs to be updated to use i8n
        #TODO: and should really work for long form of the month name too.
        return Time::Local::timegm( 0, $5 || 0, $4 || 0, $1, $MON2NUM{ lc($2) },
            $year ) - $tzadj;
    }

    # ISO date 2001-12-31T23:59:59+01:00
    # Sven is going to presume that _all_ ISO dated must have a 'T' in them.
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

    #any date that leads with a year (2 digit years too)
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

        #no defaulting yet so we can detect the 2009--12 error
        my ( $year, $M, $D, $h, $m, $s ) = ( $1, $2, $3, $4, $5, $6 );

#without range checking on the 12 Jan 2009 case above, there is abmiguity - what is 14 Jan 12 ?
#similarly, how would you decide what Jan 02 and 02 Jan are?
#$month_p = $MON2NUM{ lc($month_p) } if (defined($MON2NUM{ lc($month_p) }));

        #TODO: unhappily, this means 09 == 1909 not 2009
        $year -= 1900 if ( $year > 1900 );

        #range checks
        return undef if ( defined($M) && ( $M < 1 || $M > 12 ) );
        my $month = ( $M || 1 ) - 1;
        return undef
          if ( defined($D) && ( $D < 0 || $D > $MONTHLENS[$month] ) );
        return undef if ( defined($h) && ( $h < 0 || $h > 24 ) );
        return undef if ( defined($m) && ( $m < 0 || $m > 60 ) );
        return undef if ( defined($s) && ( $s < 0 || $s > 60 ) );
        return undef if ( defined($year) && $year < 60 );

        my $day  = $D || 1;
        my $hour = $h || 0;
        my $min  = $m || 0;
        my $sec  = $s || 0;

        return Time::Local::timegm( $sec, $min, $hour, $day, $month, $year ) -
          $tzadj;
    }

    # give up
    return undef;
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
    return Foswiki::Plugins::TablePlugin::debug( 'TablePlugin::Core', @_ );
}

sub _debugData {
    return Foswiki::Plugins::TablePlugin::debugData( 'TablePlugin::Core', @_ );
}

1;
