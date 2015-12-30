# See bottom of file for license and copyright information

use strict;
use warnings;

package Foswiki::Plugins::TablePlugin::Core;

use Foswiki::Func;
use Foswiki::Plugins::TablePlugin ();
use Foswiki::Time;
use Error qw(:try);

use Unicode::Normalize;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

my @curTable;
my $translationToken;
my $insideTABLE;
my $currTablePre;
my $didWriteDefaultStyle;
my $defaultAttrs;          # to write generic table CSS
my $tableSpecificAttrs;    # to write table specific table CSS
my $combinedTableAttrs;    # default and specific table attributes
my $styles   = {};         # hash of default and specific styles
my @messages = ();

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
my $URL_ICON;
my $GIF_TABLE_SORT_ASCENDING;
my $GIF_TABLE_SORT_DESCENDING;
my $GIF_TABLE_SORT_BOTH;
my $CHAR_SORT_ASCENDING;
my $CHAR_SORT_DESCENDING;
my $CHAR_SORT_BOTH;

my $SORT_DIRECTION;

my $PATTERN_ATTRIBUTE_SIZE =
  qr'([0-9]+)(ch|cm|em|ex|in|mm|pc|pt|px|rem|vh|vmax|vmin|vw|%)?'o;

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

sub _init {
    _debug("_init");
    $translationToken = "\0";

    # the maximum number of columns we will handle
    $MAX_SORT_COLS        = 10000;
    $didWriteDefaultStyle = 0;
    $tableCount           = 0;
    $currTablePre         = '';
    $combinedTableAttrs   = {};
    $tableSpecificAttrs   = {};
    $styles               = {};
    $URL_ICON =
        Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName}
      . '/DocumentGraphics/';
    $GIF_TABLE_SORT_ASCENDING = CGI::img(
        {
            src    => $URL_ICON . 'tablesortup.gif',
            border => 0,
            width  => 11,
            height => 13,
            alt    => 'Sorted ascending',
            title  => 'Sorted ascending'
        }
    );

    $GIF_TABLE_SORT_DESCENDING = CGI::img(
        {
            src    => $URL_ICON . 'tablesortdown.gif',
            border => 0,
            width  => 11,
            height => 13,
            alt    => 'Sorted descending',
            title  => 'Sorted descending'
        }
    );

    $GIF_TABLE_SORT_BOTH = CGI::img(
        {
            src    => $URL_ICON . 'tablesortdiamond.gif',
            border => 0,
            width  => 11,
            height => 13,
            alt    => 'Sort',
            title  => 'Sort'
        }
    );
    $CHAR_SORT_ASCENDING = CGI::span( { class => 'tableSortIcon tableSortUp' },
        $GIF_TABLE_SORT_ASCENDING );
    $CHAR_SORT_DESCENDING =
      CGI::span( { class => 'tableSortIcon tableSortDown' },
        $GIF_TABLE_SORT_DESCENDING );
    $CHAR_SORT_BOTH = CGI::span( { class => 'tableSortIcon tableSortUp' },
        $GIF_TABLE_SORT_BOTH );

    $SORT_DIRECTION = {
        'ASCENDING'  => 0,
        'DESCENDING' => 1,
        'NONE'       => 2,
    };
}

# called one time
sub _initDefaults {
    _debug('_initDefaults');
    $defaultAttrs = {
        headerrows    => 0,
        footerrows    => 0,
        sort          => 1,
        class         => 'foswikiTable',
        sortAllTables => $sortTablesInText,
    };
    _parseDefaultAttributes(
        %{Foswiki::Plugins::TablePlugin::pluginAttributes} );

    $combinedTableAttrs = _mergeHashes( {}, $defaultAttrs );
}

sub _addDefaultStyles {
    return if $Foswiki::Plugins::TablePlugin::writtenToHead;
    $Foswiki::Plugins::TablePlugin::writtenToHead = 1;

    # create CSS styles tables in general
    my ( $id, @styles ) = _createCssStyles( 1, $defaultAttrs );
    _addHeadStyles( $HEAD_ID_DEFAULT_STYLE, @styles ) if scalar(@styles);
}

sub _resetReusedVariables {
    _debug('_resetReusedVariables');
    $currTablePre       = '';
    $combinedTableAttrs = _mergeHashes( {}, $defaultAttrs );
    $tableSpecificAttrs = {};
    $sortCol            = 0;
    @messages           = ();
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

    _addHeadStyles( $id, @styles ) if scalar(@styles);

    return $currTablePre . '<nop>';
}

=pod

=cut

sub _parseAttributes {
    my ( $isTableSpecific, $inCollection, $inParams ) = @_;

    _debugData( "isTableSpecific=$isTableSpecific; _parseAttributes=",
        $inParams );

    # include topic to read definitions
    if ( $inParams->{include} ) {
        my ( $includeParams, $message ) =
          _getIncludeParams( $inParams->{include} );

        if ($includeParams) {
            $inParams = $includeParams;
        }
        if ($message) {
            push( @messages, $message );
        }
    }

    # table attributes
    # some will be used for css styling as well

    _storeAttribute( 'generateInlineMarkup',
        Foswiki::Func::isTrue( $inParams->{inlinemarkup} ),
        $inCollection )
      if defined $inParams->{inlinemarkup};

    # sort attributes
    if ( defined $inParams->{sort} ) {
        my $sort = Foswiki::Func::isTrue( $inParams->{sort} );
        _storeAttribute( 'sort',          $sort, $inCollection );
        _storeAttribute( 'sortAllTables', $sort, $inCollection );
    }
    if ( defined( $inParams->{initsort} )
        and int( $inParams->{initsort} ) > 0 )
    {
        _storeAttribute( 'initSort', $inParams->{initsort}, $inCollection );

        # override sort attribute: we are sorting after all
        _storeAttribute( 'sort', 1, $inCollection );
    }

    if ( $inParams->{initdirection} ) {
        _storeAttribute( 'initDirection', $SORT_DIRECTION->{'ASCENDING'},
            $inCollection )
          if $inParams->{initdirection} =~ /^down$/i;
        _storeAttribute( 'initDirection', $SORT_DIRECTION->{'DESCENDING'},
            $inCollection )
          if $inParams->{initdirection} =~ /^up$/i;
    }

    # Don't allow sort requests when rendering for static use.
    # Force sort=off but allow initsort / initdirection
    my $context = Foswiki::Func::getContext();
    if ( $context->{static} ) {
        delete $inCollection->{sortAllTables};
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

    if ($isTableSpecific) {

        _storeAttribute( 'summary', $inParams->{summary}, $inCollection );
        my $id =
          defined $inParams->{id}
          ? $inParams->{id}
          : 'table'
          . $Foswiki::Plugins::TablePlugin::topic
          . ( $tableCount + 1 );
        _storeAttribute( 'id', $id, $inCollection );

        my $class =
          defined $inParams->{class}
          ? $defaultAttrs->{class} . ' ' . $inParams->{class}
          : $defaultAttrs->{class};
        _storeAttribute( 'class', $class, $inCollection );

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
    $inCollection->{tableRules} = \@tableRulesList if scalar(@tableRulesList);

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
    _storeAttribute( 'vAlign',       $inParams->{valign},       $inCollection );
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
        return ( undef,
'%MAKETEXT{"Warning: \'include\' topic <nop>[_1] does not exist!" args="'
              . "$includeWeb.$includeTopic"
              . '"}%' );
    }
    else {

        my $text = Foswiki::Func::readTopicText( $includeWeb, $includeTopic );

        if ( $text =~ m/$PATTERN_TABLE/s ) {
            _debug("\t PATTERN_TABLE=$PATTERN_TABLE; 1=$1");
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
            return ( \%params, undef );
        }
        else {
            return ( undef,
'%MAKETEXT{"Warning: table definition in \'include\' topic [_1] does not exist!" args="'
                  . "$includeWeb.$includeTopic"
                  . '"}%' );
        }
    }
}

=pod

_convertStringToDate ( $text ) -> $number

Convert text to number if syntactically possible, otherwise return undef.
Assumes that the text has been stripped from HTML markup.

=cut

sub _convertStringToDate {
    my ($text) = @_;

    return undef if !defined $text;
    return undef if $text eq '';
    return undef if ( $text =~ /^\s*$/ );

    my $date = undef;

    if ( $text =~ /^\s*-?[0-9]+(\.[0-9])*\s*$/ ) {
        _debug("\t this is a number");
    }
    else {
        try {
            $date = Foswiki::Time::parseTime($text);
            _debug("\t is a date");
        }
        catch Error::Simple with {

            # nope, wasn't a date
            _debug("\t $text is not a date");
        };
    }

    return $date;
}

=pod

_convertStringToNumber ( $text ) -> $number

Convert text to number if syntactically possible, otherwise return undef.
Assumes that the text has been stripped from HTML markup.

=cut

sub _convertStringToNumber {
    my ($text) = @_;

    return undef if !defined $text;
    return undef if $text eq '';
    return undef if ( $text =~ /^\s*$/ );

    # very course testing on IP (could in fact be anything with n.n. syntax
    if (
        $text =~ m/
    	^		
    	\s*			# any space
    	(?:			# don't need to capture
    	[0-9]+		# digits
    	\.			# dot
    	)			#
    	{2,}		# repeat more than once: exclude decimal numbers 
    	.*?			# any string
    	$
    	/x
      )
    {
        _debug("\t $text looks like an IP address, or something similar");

        # should be sorted by text
        return undef;
    }

    if (
        $text =~ m/
		^
		\s*			# any space
		(			# 
		-*			# possible minus
		[0-9]+		# digits
		\.*         # possible decimal
		[0-9]*		# possible fracture digits
		)			# end capture of number
		.*$			# any string
		/x
      )
    {

        _debug("\t $1 is a number");

        # make sure to return a number, not a string
        return $1 * 1.0;
    }
    return undef;
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
            $sortCol = 0 unless ( $sortCol =~ m/^[0-9]+$/ );
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

        # Item13309: adjust for ERP empty column
        if (  !$tableSpecificAttrs->{sort_adjusted}
            && $colCount == 0
            && /erpJS_willDiscard/ )
        {
            if ( $combinedTableAttrs->{initSort} ) {
                $combinedTableAttrs->{initSort}++;
                $sortCol++;
            }

            $tableSpecificAttrs->{sort_adjusted} = 1;
        }

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
                $attr->{style} = 'text-align:right';
            }
            else {
                $attr->{style} = 'text-align:center';
            }
        }
        if ( $span <= 2 ) {
            $attr->{class} =
              _appendColNumberCssClass( $attr->{class}, $colCount );
        }

        # html attribute: (column) width
        if ( $combinedTableAttrs->{generateInlineMarkup}
            && defined $combinedTableAttrs->{columnWidthsListRef} )
        {
            my @columnWidths = @{ $combinedTableAttrs->{columnWidthsListRef} };
            if (   defined $columnWidths[$colCount]
                && $columnWidths[$colCount]
                && $span <= 2 )
            {
                $attr->{width} = $columnWidths[$colCount];
            }
        }

        # END html attribute

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
                        $curTable[ $nRows - $rspan ][$col]->{attrs}->{rowspan}
                          = $rspan;
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

            # Fixup for EditRowPlugin - add ** if erpJS_sort
            s/(.*)/*$1*/ if /erpJS_sort \{headrows: \d/;

            if (/^\s*\*(.*)\*\s*$/) {
                $value = $1;
                $type  = 'th';

                # html attribute: align
                if ( $combinedTableAttrs->{generateInlineMarkup}
                    && defined $combinedTableAttrs->{headerAlignListRef} )
                {
                    my @headerAlign =
                      @{ $combinedTableAttrs->{headerAlignListRef} };
                    if (@headerAlign) {
                        my $align =
                          @headerAlign[ $colCount % ( $#headerAlign + 1 ) ];
                        $attr->{style} = "text-align:$align";
                    }
                }

                # END html attribute

                # html attribute: valign
                if ( $combinedTableAttrs->{generateInlineMarkup} ) {
                    if ( defined $combinedTableAttrs->{headerVAlign} ) {
                        $attr->{valign} = $combinedTableAttrs->{headerVAlign};
                    }
                    elsif ( defined $combinedTableAttrs->{vAlign} ) {
                        $attr->{valign} = $combinedTableAttrs->{vAlign};
                    }
                }

                # END html attribute
            }
            else {
                if (/^\s*(.*?)\s*$/) {    # strip white spaces
                    $_ = $1;
                }
                $value = $_;
                $type  = 'td';

                # html attribute: align
                if ( $combinedTableAttrs->{generateInlineMarkup}
                    && defined $combinedTableAttrs->{dataAlignListRef} )
                {
                    my @dataAlign =
                      @{ $combinedTableAttrs->{dataAlignListRef} };
                    if (@dataAlign) {
                        my $align =
                          @dataAlign[ $colCount % ( $#dataAlign + 1 ) ];
                        $attr->{style} = "text-align:$align";
                    }
                }

                # END html attribute

                # html attribute: valign
                if ( $combinedTableAttrs->{generateInlineMarkup} ) {
                    if ( defined $combinedTableAttrs->{dataVAlign} ) {
                        $attr->{valign} = $combinedTableAttrs->{dataVAlign};
                    }
                    elsif ( defined $combinedTableAttrs->{vAlign} ) {
                        $attr->{valign} = $combinedTableAttrs->{vAlign};
                    }
                }

                # END html attribute
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

sub _headerRowCount {
    my ($table) = @_;

    my $headerCount = 0;
    my $footerCount = 0;
    my $endheader   = 0;

    # All cells in header are headings?
    foreach my $row (@$table) {
        my $isHeader = 1;
        foreach my $cell (@$row) {
            if ( $cell->{type} ne 'th' ) {
                $isHeader    = 0;
                $endheader   = 1;
                $footerCount = 0 if $footerCount;
            }
        }
        unless ($endheader) {
            $headerCount++ if $isHeader;
        }
        else {
            $footerCount++ if $isHeader;
        }
    }

    # Some cells came after the footer - so there isn't one.
    $footerCount = 0 if ( $endheader > 1 );

    return ( $headerCount, $footerCount );
}

=pod

_setSortTypeForCells ( $col, \@table )

Sets a sort key for each cell.

=cut

sub _setSortTypeForCells {
    my ( $col, $table ) = @_;

    foreach my $row ( @{$table} ) {

        my $rowText = _stripHtml( $row->[$col]->{text} );

        my $num  = _convertStringToNumber($rowText);
        my $date = _convertStringToDate($rowText);

        $row->[$col]->{sortText}   = '';
        $row->[$col]->{number}     = 0;
        $row->[$col]->{dateString} = '';

        if ( defined $date ) {

            # date has just converted to a number
            $row->[$col]->{number} = $date;

            # add dateString value in case dates are equal
            $row->[$col]->{dateString} = $rowText;
        }
        elsif ( defined $num ) {
            $row->[$col]->{number} = $num;

# when sorting mixed numbers and text, make the text sort value as low as possible
            $row->[$col]->{sortText} = ' ';
        }
        else {
            $row->[$col]->{sortText} = lc $rowText;
        }

    }
}

# Remove HTML from text so it can be sorted
sub _stripHtml {
    my ($text) = @_;

    return undef if !defined $text;
    $text =~
      s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/go; # extract label from [[...][...]] link

    my $orgtext =
      $text;    # in case we will have removed all contents with stripping html
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
    $currentDirection = $SORT_DIRECTION->{'ASCENDING'}
      unless defined $currentDirection && $currentDirection =~ m/[0-2]+/;
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
    elsif ( $currentDirection == $SORT_DIRECTION->{'DESCENDING'} ) {
        $newDirection = $SORT_DIRECTION->{'NONE'};
    }
    elsif ( $currentDirection == $SORT_DIRECTION->{'NONE'} ) {
        $newDirection = $SORT_DIRECTION->{'ASCENDING'};
    }
    else {
        $newDirection = _getDefaultSortDirection();
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
        my $color =
          ( $inAttrs->{headerBg} =~ /none/i )
          ? 'transparent'
          : $inAttrs->{headerBg};
        my $attr = 'background-color:' . $color;
        &$setAttribute( $tableSelector, 'th', $attr );
    }

    # headerbgsorted
    if ( defined $inAttrs->{headerBgSorted} ) {
        my $color =
          ( $inAttrs->{headerBgSorted} =~ /none/i )
          ? 'transparent'
          : $inAttrs->{headerBgSorted};
        my $attr = 'background-color:' . $color;
        &$setAttribute( $tableSelector, 'th.foswikiSortedCol', $attr );
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
        my @dataBg    = @{ $inAttrs->{dataBgListRef} };
        my $noneColor = ( $dataBg[0] =~ /none/i ) ? 'transparent' : '';
        my $count     = 0;
        foreach my $color (@dataBg) {
            $color = $noneColor if $noneColor;
            next if !$color;
            my $rowSelector = 'foswikiTableRow' . 'dataBg' . $count;
            my $attr        = "background-color:$color";
            &$setAttribute( $tableSelector, "tr.$rowSelector td", $attr );
            $count++;
        }
    }

    # databgsorted (array)
    if ( defined $inAttrs->{dataBgSortedListRef} ) {
        my @dataBgSorted = @{ $inAttrs->{dataBgSortedListRef} };
        my $noneColor    = ( $dataBgSorted[0] =~ /none/i ) ? 'transparent' : '';
        my $count        = 0;
        foreach my $color (@dataBgSorted) {
            $color = $noneColor if $noneColor;
            next if !$color;
            my $rowSelector = 'foswikiTableRow' . 'dataBg' . $count;
            my $attr        = "background-color:$color";
            &$setAttribute( $tableSelector,
                "tr.$rowSelector td.foswikiSortedCol", $attr );
            $count++;
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
        if ( scalar(@headerAlign) == 1 ) {
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
        if ( scalar(@dataAlign) == 1 ) {
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
                push @styles, "body $tableSelector {$selectors}";
            }
            else {
                push @styles, "body $tableSelector $selector {$selectors}";
            }
        }
    }

    return ( $id, @styles );
}

sub _addHeadStyles {
    my ( $inId, @inStyles ) = @_;

    return if !scalar(@inStyles);

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
    Foswiki::Func::addToZone( "head", $inId, $header, $HEAD_ID_DEFAULT_STYLE );
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

    _addDefaultStyles();

    _debug('emitTable');

    #Validate headerrows/footerrows and modify if out of range
    if ( $combinedTableAttrs->{headerrows} > scalar(@curTable) ) {
        $combinedTableAttrs->{headerrows} =
          scalar(@curTable);    # limit header to size of table!
    }
    if ( $combinedTableAttrs->{headerrows} + $combinedTableAttrs->{footerrows} >
        @curTable )
    {
        $combinedTableAttrs->{footerrows} =
          scalar(@curTable) -
          $combinedTableAttrs->{headerrows};    # and footer to whatever is left
    }

    my $sortThisTable =
      ( !defined $combinedTableAttrs->{sortAllTables}
          || $combinedTableAttrs->{sortAllTables} == 0 )
      ? 0
      : $combinedTableAttrs->{sort};

    if ( $combinedTableAttrs->{headerrows} == 0 ) {
        my ( $headerRowCount, $footerRowCount ) = _headerRowCount( \@curTable );

        # override default setting with calculated header count
        $combinedTableAttrs->{headerrows} = $headerRowCount;
        $combinedTableAttrs->{footerrows} = $footerRowCount;
    }

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

    # count the number of cols to prevent looping over non-existing columns
    my $maxCols = 0;

    # Flush out any remaining rowspans
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
               $sortThisTable
            && defined $sortCol
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

       # url requested sort on column beyond end of table.  Force to last column
        $sortCol = 0 unless ( $sortCol =~ m/^[0-9]+$/ );
        $sortCol = $maxCols - 1 if ( $sortCol >= $maxCols );

        # only get the column type if within bounds
        if ( $sortCol < $maxCols ) {
            _setSortTypeForCells( $sortCol, \@curTable );
        }

        _debug("currentSortDirection:$currentSortDirection");

        if (   $combinedTableAttrs->{sort}
            && $currentSortDirection == $SORT_DIRECTION->{'ASCENDING'} )
        {
            @curTable = sort {
                NFKD( $a->[$sortCol]->{sortText} )
                  cmp NFKD( $b->[$sortCol]->{sortText} )
                  || $a->[$sortCol]->{number} <=> $b->[$sortCol]->{number}
                  || $a->[$sortCol]->{dateString}
                  cmp $b->[$sortCol]->{dateString}
            } @curTable;
        }
        elsif ($combinedTableAttrs->{sort}
            && $currentSortDirection == $SORT_DIRECTION->{'DESCENDING'} )
        {
            @curTable = sort {
                NFKD( $b->[$sortCol]->{sortText} )
                  cmp NFKD( $a->[$sortCol]->{sortText} )
                  || $b->[$sortCol]->{number} <=> $a->[$sortCol]->{number}
                  || $b->[$sortCol]->{dateString}
                  cmp $a->[$sortCol]->{dateString}
            } @curTable;
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

    # Only *one* row of the table has sort links, and it will either
    # be the last row in the header or the first row in the footer.
    my $sortLinksWritten = 0;

    foreach my $row (@curTable) {
        my $rowtext  = '';
        my $colCount = 0;

        # keep track of header cells: if all cells are header cells, do not
        # update the data color count
        my $headerCellCount  = 0;
        my $numberOfCols     = scalar(@$row);
        my $writingSortLinks = 0;

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
                #                && $sortType ne ''
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

                # html attribute: bgcolor
                if ( $combinedTableAttrs->{generateInlineMarkup}
                    && defined $combinedTableAttrs->{headerBg} )
                {
                    $attr->{bgcolor} = $combinedTableAttrs->{headerBg}
                      unless ( $combinedTableAttrs->{headerBg} =~ /none/i );
                }

                # END html attribute

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

                    # html attribute: (sorted header cell) bgcolor
                    # overrides earlier set bgcolor
                    if ( $combinedTableAttrs->{generateInlineMarkup}
                        && defined $combinedTableAttrs->{headerBgSorted} )
                    {
                        $attr->{bgcolor} = $combinedTableAttrs->{headerBgSorted}
                          unless (
                            $combinedTableAttrs->{headerBgSorted} =~ /none/i );
                    }

                    # END html attribute
                }

                if (
                       defined $sortCol
                    && $colCount == $sortCol
                    && defined $requestedTable
                    && $requestedTable == $tableCount
                    && (   $combinedTableAttrs->{headerrows}
                        || $combinedTableAttrs->{footerrows} )
                  )
                {

                    $tableAnchor =
                      CGI::a( { name => 'sorted_table' }, '<!-- -->' )
                      . $tableAnchor;
                }

                # html attribute: headercolor (font style)
                if ( $combinedTableAttrs->{generateInlineMarkup}
                    && defined $combinedTableAttrs->{headerColor} )
                {
                    my $fontStyle =
                      { color => $combinedTableAttrs->{headerColor} };
                    $cell = CGI::font( $fontStyle, $cell );
                }

                # END html attribute

                if (
                    $sortThisTable
                    && (
                        ( $rowCount == $combinedTableAttrs->{headerrows} - 1 )
                        || (  !$combinedTableAttrs->{headerrows}
                            && $rowCount ==
                            $numberOfRows - $combinedTableAttrs->{footerrows} )
                    )
                    && ( $writingSortLinks || !$sortLinksWritten )
                  )
                {
                    $writingSortLinks = 1;
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
                        $cell .= CGI::a( $linkAttributes, $CHAR_SORT_BOTH )
                          . $tableAnchor;
                    }
                    else {
                        $cell = CGI::a( $linkAttributes, $cell ) . $tableAnchor;
                    }
                }

            }
            else {

                $type = 'td' unless $type eq 'Y';

                # html attribute: bgcolor
                if ( $combinedTableAttrs->{generateInlineMarkup} ) {
                    if ( $isSorted
                        && defined $combinedTableAttrs->{dataBgSortedListRef} )
                    {
                        my @dataBg =
                          @{ $combinedTableAttrs->{dataBgSortedListRef} };

                        unless ( $dataBg[0] =~ /none/ ) {
                            $attr->{bgcolor} =
                              $dataBg[ $dataColorCount % ( $#dataBg + 1 ) ];
                        }
                    }
                    elsif ( defined $combinedTableAttrs->{dataBgListRef} ) {
                        my @dataBg = @{ $combinedTableAttrs->{dataBgListRef} };
                        unless ( $dataBg[0] =~ /none/i ) {
                            $attr->{bgcolor} =
                              $dataBg[ $dataColorCount % ( $#dataBg + 1 ) ];
                        }
                    }
                }

                # END html attribute

                # html attribute: datacolor (font style)
                if ( $combinedTableAttrs->{generateInlineMarkup}
                    && defined $combinedTableAttrs->{dataColorListRef} )
                {
                    my @dataColor =
                      @{ $combinedTableAttrs->{dataColorListRef} };
                    my $color =
                      $dataColor[ $dataColorCount % ( $#dataColor + 1 ) ];
                    unless ( $color =~ /^(none)$/i ) {
                        my $cellAttrs = { color => $color };
                        $cell = CGI::font( $cellAttrs, ' ' . $cell . ' ' );
                    }
                }

                # END html attribute

            }    ###if( $type eq 'th' )

            if ($isSorted) {
                $attr->{class} = _appendSortedCssClass( $attr->{class} );
            }

            if ($writingSortLinks) {
                $sortLinksWritten = 1;
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

        my $isHeaderRow =
          $rowCount <
          $combinedTableAttrs->{headerrows}; #( $headerCellCount == $colCount );
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
    $text .= $currTablePre . $thead if scalar(@headerRowList);

    my $tfoot =
        "$singleIndent<tfoot>"
      . join( "", @footerRowList )
      . "$singleIndent</tfoot>";
    $text .= $currTablePre . $tfoot if scalar(@footerRowList);

    my $tbody;
    if ( scalar(@bodyRowList) ) {
        $tbody =
            "$singleIndent<tbody>"
          . join( "", @bodyRowList )
          . "$singleIndent</tbody>";
    }
    else {

        # A HTML table requires a body, which cannot be empty (Item8991).
        # So we provide one, but prevent it from being displayed.
        $tbody =
"$singleIndent<tbody>$doubleIndent<tr style=\"display:none;\">$tripleIndent<td></td>$doubleIndent</tr>$singleIndent</tbody>\n";
    }

    if ( scalar(@messages) ) {
        $text =
            '<span class="foswikiAlert">'
          . Foswiki::Func::expandCommonVariables( join( "\n", @messages ) )
          . '</span>' . "\n"
          . $text;
    }

    $text .= $currTablePre . $tbody;
    $text .= $currTablePre . CGI::end_table() . "\n";

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
        @origSort  = $cgi->multi_param('sortcol');
        @origTable = $cgi->multi_param('table');
        @origUp    = $cgi->multi_param('up');        # NOTE: internal parameter
        $cgi->delete( 'sortcol', 'table', 'up' );
        $url =
          NFC(
            Foswiki::urlDecode( $cgi->url( -absolute => 1, -path => 1 ) . '?' )
          );
        my $queryString = $cgi->query_string();

        if ($queryString) {
            $url .= $queryString . ';';
        }

        # Restore parameters, so we don't interfere on the remaining execution
        $cgi->param( -name => 'sortcol', -value => \@origSort )  if @origSort;
        $cgi->param( -name => 'table',   -value => \@origTable ) if @origTable;
        $cgi->param( -name => 'up',      -value => \@origUp )    if @origUp;

        $sortColFromUrl =
          $cgi->param('sortcol');    # zero based: 0 is first column
        if ( defined $sortColFromUrl && $sortColFromUrl !~ m/^[0-9]+$/ ) {
            $sortColFromUrl = 0;
        }

        $requestedTable = $cgi->param('table');
        $requestedTable = 0
          unless ( defined $requestedTable && $requestedTable =~ m/^[0-9]+$/ );

        $up = $cgi->param('up');

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

            $combinedTableAttrs->{sortAllTables} = $defaultSort;
            $acceptable = $defaultSort;

            # prepare for next table
            _resetReusedVariables();
        }
    }
    $_[0] = join( "\n", @lines );

    if ($insideTABLE) {
        $_[0] .= emitTable();
    }

    # prepare for next table
    _resetReusedVariables();
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

Shorthand debugging call.

=cut

sub _debug {
    return Foswiki::Plugins::TablePlugin::debug( 'TablePlugin::Core', @_ );
}

sub _debugData {
    return Foswiki::Plugins::TablePlugin::debugData( 'TablePlugin::Core', @_ );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2006 TWiki Contributors
Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.org
Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
