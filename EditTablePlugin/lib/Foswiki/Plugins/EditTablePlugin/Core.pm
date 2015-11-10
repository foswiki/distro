# See bottom of file for license and copyright information

=pod

Work in progress: changing the table based on form parameters

(sub handleTableChangeParams)

Test in topic:

%EDITTABLE{}%
| *AAA* |

---++ Add rows from table 1
<form name="edittable1" action="%SCRIPTURL{"viewauth"}%/Sandbox/EditTablePluginTest2#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
Position: <input type="text" class="foswikiInputField" size="8" name="etaddrows_position" value="1" />
Count: <input type="text" class="foswikiInputField" size="8" name="etaddrows_count" value="5" />
<input type="submit" name="etsave" id="etsave" value="Add rows" class="foswikiSubmit" />
</form>

---++ Delete rows from table 1
<form name="edittable1" action="%SCRIPTURL{"viewauth"}%/Sandbox/EditTablePluginTest2#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
Position: <input type="text" class="foswikiInputField" size="8" name="etdeleterows_position" value="1" />
Count: <input type="text" class="foswikiInputField" size="8" name="etdeleterows_count" value="5" />
<input type="submit" name="etsave" id="etsave" value="Delete rows" class="foswikiSubmit" />
</form>

=cut

package Foswiki::Plugins::EditTablePlugin::Core;

use strict;
use warnings;
use Assert;
use Error qw(:try);
use CGI qw( :all );

use Foswiki::Func;
use Foswiki::Plugins::EditTablePlugin::Data;
use Foswiki::Plugins::EditTablePlugin::EditTableData;

my $DEFAULT_FIELD_SIZE           = 16;
my $PLACEHOLDER_BUTTONROW_TOP    = 'PLACEHOLDER_BUTTONROW_TOP';
my $PLACEHOLDER_BUTTONROW_BOTTOM = 'PLACEHOLDER_BUTTONROW_BOTTOM';
my $PLACEHOLDER_SEPARATOR_SEARCH_RESULTS =
  'PLACEHOLDER_SEPARATOR_SEARCH_RESULTS';
my $HTML_TAGS =
qr'var|ul|u|tt|tr|th|td|table|sup|sub|strong|strike|span|small|samp|s|pre|p|ol|li|kbd|ins|img|i|hr|h|font|em|div|dfn|del|code|cite|center|br|blockquote|big|b|address|acronym|abbr|a';

my $prefCHANGEROWS;
my $prefEDIT_BUTTON;
my $prefSAVE_BUTTON;
my $prefQUIET_SAVE_BUTTON;
my $prefADD_ROW_BUTTON;
my $prefDELETE_LAST_ROW_BUTTON;
my $prefCANCEL_BUTTON;
my $prefMESSAGE_INCLUDED_TOPIC_DOES_NOT_EXIST;
my $prefQUIETSAVE;
my $preSp;
my %params;
my @format;
my @formatExpanded;
my $nrCols;
my $warningMessage;

my $PATTERN_EDITTABLEPLUGIN =
  $Foswiki::Plugins::EditTablePlugin::Data::PATTERN_EDITTABLEPLUGIN;
my $PATTERN_TABLEPLUGIN =
  $Foswiki::Plugins::EditTablePlugin::Data::PATTERN_TABLEPLUGIN;
my $PATTERN_EDITCELL               = qr'%EDITCELL\{(.*?)\}%';
my $PATTERN_TABLE_ROW_FULL         = qr'^(\s*)\|.*\|\s*$';
my $PATTERN_TABLE_ROW              = qr'^(\s*)\|(.*)';
my $PATTERN_SPREADSHEETPLUGIN_CALC = qr'%CALC(?:\{(.*?)\})?%';
my $SPREADSHEETPLUGIN_CALC_SUBSTITUTION =
  "<span class='editTableCalc'>CALC</span>";
my $MODE = {
    READ           => ( 1 << 1 ),
    EDIT           => ( 1 << 2 ),
    SAVE           => ( 1 << 3 ),
    SAVEQUIET      => ( 1 << 4 ),
    CANCEL         => ( 1 << 5 ),
    EDITNOTALLOWED => ( 1 << 6 ),
};
my %tableMatrix;
my $query;

=begin TML

Initializes variables.

=cut

sub init {
    $preSp                      = '';
    %params                     = ();
    @format                     = ();
    @formatExpanded             = ();
    $prefCHANGEROWS             = undef;
    $prefEDIT_BUTTON            = undef;
    $prefSAVE_BUTTON            = undef;
    $prefQUIET_SAVE_BUTTON      = undef;
    $prefADD_ROW_BUTTON         = undef;
    $prefDELETE_LAST_ROW_BUTTON = undef;
    $prefDELETE_LAST_ROW_BUTTON = undef;
    $prefQUIETSAVE              = undef;
    $nrCols                     = undef;
    $query                      = undef;
    $warningMessage             = '';
    %tableMatrix                = ();

    getPreferencesValues();
}

=begin TML

Init variables again. If called from INCLUDE this is the first time we init

=cut

sub initIncludedTopic {
    $preSp = '' unless $preSp;
    getPreferencesValues();
}

=begin TML

StaticMethod parseTables($text, $topic, $web)

Read and parse table data once for each topic.
Stores data in hash $tableMatrix{webname}{topicname}.
Even if we are just viewing table data (not editing), we can deal with text inside edit tables in a special way. For instance by calling handleTmlInTables on the table text.

=cut

sub parseTables {
    my ( $inText, $inTopic, $inWeb ) = @_;

    # my $text = $_[0]

    return if defined $tableMatrix{$inWeb}{$inTopic};

    my $tableData = Foswiki::Plugins::EditTablePlugin::Data->new();
    $_[0] = $tableData->parseText($inText);

    _debug("EditTablePlugin::Core::parseTables - after parseText, text=$_[0]");

    $tableMatrix{$inWeb}{$inTopic} = $tableData;
}

=begin TML

---+++ process( $text, $topic, $web, $includingTopic, $includingWeb )

Called from commonTagsHandler. Pass over to processText in 'no Save' mode.

=cut

sub process {

    # my $text = $_[0]
    # my $topic = $_[1]
    # my $web = $_[2]
    # my $includingTopic = $_[3]
    # my $includingWeb = $_[4]

    my $mode        = $MODE->{READ};
    my $saveTableNr = 0;
    processText( $mode, $saveTableNr, @_ );
}

=begin TML

---+++ processText( $mode, $saveTableNr, $text, $topic, $web, $includingTopic, $includingWeb )

Process the text line by line.
When a EditTablePlugin table is encountered, its contents is rendered according to the view:
   * View mode - default
   * Edit mode - when an Edit button is clicked, renders the rest of the table in edit mode
   * Save mode - when called from a Save button: calls processText again, only renders the selected table number, then saves the topic text

=cut

sub processText {
    my ( $inMode, $inSaveTableNr, $inText, $inTopic, $inWeb, $inIncludingTopic,
        $inIncludingWeb )
      = @_;

    my $mode = $inMode;
    my $doSave = ( $mode & $MODE->{SAVE} ) ? 1 : 0;
    $query = Foswiki::Func::getCgiQuery();

    # Item1458 ignore all saving unless it happened using POST method.
    $doSave = 0
      if ( $query && $query->method() && uc( $query->method() ) ne 'POST' );

    _debug(
"EditTablePlugin::Core::processText( inSaveTableNr=$inSaveTableNr; inText=$inText\ninTopic=$inTopic\ninWeb=$inWeb\ninIncludingTopic=$inIncludingTopic\ninIncludingWeb=$inIncludingWeb\nmode="
          . _modeToString($mode) );
    _debug( "query params=" . Dumper( $query->{param} ) );

    my $topic = $query->param('ettabletopic') || $inTopic;
    my $web   = $query->param('ettableweb')   || $inWeb;

    my $paramTableNr = $query->param('ettablenr') || 0;

    my $meta;
    my $topicText = $inText;

    if ($doSave) {
        ( $meta, $topicText ) = Foswiki::Func::readTopic( $web, $topic );

        # fill the matrix with fresh new table
        undef $tableMatrix{$web}{$topic};
        parseTables( $topicText, $topic, $web );
    }
    else {
        parseTables( $inText, $topic, $web );
    }
    my $tableData = $tableMatrix{$web}{$topic};

    # ========================================
    # LOOP THROUGH TABLES

    my $tableNr = 0;    # current EditTable table
    foreach my Foswiki::Plugins::EditTablePlugin::EditTableData $editTableData (
        @{ $tableData->{editTableDataList} } )
    {

        if ($Foswiki::Plugins::EditTablePlugin::debug) {
            use Data::Dumper;
            _debug( "EditTablePlugin::Core::processText; editTableData="
                  . Dumper($editTableData) );
        }

        my $isEditingTable = 0;
        my $editTableTag   = $editTableData->{'tagline'};

       # store processed lines of this tableText
       # the list of lines will be put back into the topic text after processing
        my @result = ();

        $tableNr++;

        # ========================================
        # START HANDLE EDITTABLE TAG

        if ( $mode & $MODE->{READ} ) {

            # process the tag contents
            handleEditTableTag( $web, $topic, $editTableData->{'params'} );

            # remove the original EDITTABLE{} in the tag pre_EDITTABLE{}_post
            # so we just have pre__post
            $editTableTag =
              $editTableData->{'pretag'} . $editTableData->{'posttag'};

            # expand macros in tagline without creating infinite recursion:
            $editTableTag =~ s/%EDITTABLE\{/%TMP_ETP_STUB_TAG{/;
            $editTableTag = Foswiki::Func::expandCommonVariables($editTableTag);

            # put tag back
            $editTableTag =~ s/TMP_ETP_STUB_TAG/EDITTABLE/;
        }

        # END HANDLE EDITTABLE TAG
        # ========================================

        # ========================================
        # START FOOTER AND HEADER ROW COUNT

        ( $editTableData->{headerRowCount}, $editTableData->{footerRowCount} )
          = getHeaderAndFooterCount($editTableTag);

        _debug(
"EditTablePlugin::Core::processText; headerRowCount=$editTableData->{headerRowCount}; footerRowCount=$editTableData->{footerRowCount}; tableText="
              . join( "\n", @{ $editTableData->{'lines'} } ) );

        # END FOOTER AND HEADER ROW COUNT
        # ========================================

        # ========================================
        # START HANDLE TABLE CHANGE PARAMETERS

        my $tableChanges =
          Foswiki::Plugins::EditTablePlugin::EditTableData::createTableChangesMap(
            $query->multi_param('ettablechanges') )
          ; # a mapping of rows and their changed state; keys are row numbers (starting with 0), values are row states: 0 (not changed), 1 (row to be added), -1 (row to be deleted); the map is created using the param 'ettablechanges'; the map is created and updated in EDIT mode, and used in SAVE mode.

        my $tableStats = $editTableData->getTableStatistics($tableChanges);

        if ( ( $mode & $MODE->{READ} ) || ( $tableNr == $inSaveTableNr ) ) {

            my $allowedToEdit = 0;

            if ( $tableNr == $inSaveTableNr ) {
                $mode =
                  handleTableChangeParams( $mode, $editTableData, $tableStats,
                    $tableChanges, $web, $topic );
                $tableStats = $editTableData->getTableStatistics($tableChanges);
            }

            if (
                ( $paramTableNr == $tableNr )
                && (  $web . '.'
                    . $topic eq
"$Foswiki::Plugins::EditTablePlugin::web.$Foswiki::Plugins::EditTablePlugin::topic"
                )
              )
            {
                $isEditingTable = 1;

                # handle button actions
                if ( $mode & $MODE->{READ} ) {

                    $mode =
                      handleButtonActions( $mode, $editTableData, $tableStats,
                        $tableChanges, $web, $topic );

                    if (   ( $mode & $MODE->{SAVE} )
                        || ( $mode & $MODE->{SAVEQUIET} ) )
                    {
                        return processText( $mode, $tableNr, $inText, $topic,
                            $web, $inIncludingTopic, $inIncludingWeb );
                    }
                    elsif ( $mode & $MODE->{CANCEL} ) {
                        return;    # in case browser does not redirect
                    }
                    elsif ( $mode & $MODE->{EDITNOTALLOWED} ) {
                        return;
                    }
                }
            }
        }   # if ( ( $mode & $MODE->{READ} ) || ( $tableNr == $inSaveTableNr ) )

        # END HANDLE TABLE CHANGE PARAMETERS
        # ========================================

        # ========================================
        # START FORM TOP

        my $doEdit = $isEditingTable ? 1 : 0;

        if ( ( $mode & $MODE->{READ} ) ) {
            my $tableStart = handleTableStart( $web, $topic, $inIncludingWeb,
                $inIncludingTopic, $tableNr, $doEdit );
            push( @result, $tableStart );
        }

        # END FORM TOP
        # ========================================

        # ========================================
        # START PROCESSING ROWS

        if ($isEditingTable) {
            ( my $processedTableData, $tableChanges ) =
              processTableData( $tableNr, $editTableData, $tableChanges,
                $doEdit, $doSave, $web, $topic );
            push( @result, @{$processedTableData} );
        }
        else {

            my $lines = $editTableData->{'lines'};

            # render the row: EDITCELL and format tokens
            my $rowNr = 0;
            for ( @{$lines} ) {
                my $isNewRow = 0;
s/$PATTERN_TABLE_ROW/handleTableRow( $1, $2, $tableNr, $isNewRow, $rowNr++, $doEdit, $doSave, $web, $topic )/e;
            }
            @{$lines} = map { $_ .= "\n" } @{$lines};
            handleTmlInTables($lines) if !$doSave;

            push( @result, @{$lines} );
        }

        # END PROCESSING ROWS
        # ========================================

        # ========================================
        # START PUT PROCESSED TABLE BACK IN TEXT

        my $resultText = join( "", @result );

        # We do not want TablePlugin to sort the table we are editing
        # So we use the special setting disableallsort which is added
        # to TABLE for exactly this purpose. Please do not remove this
        # feature again.
        if (  !$doSave
            && $isEditingTable )
        {
            _debug("editTableTag before changing TABLE tag=$editTableTag");
            my $TABLE_EDIT_TAGS = 'disableallsort="on" databg="#fff"';
            if ( $editTableTag !~ /%TABLE\{.*?\}%/ ) {

                # no TABLE tag at all
                $editTableTag .= "%TABLE{$TABLE_EDIT_TAGS}%";
            }
            elsif ( $editTableTag !~ /%TABLE\{.*?$TABLE_EDIT_TAGS.*?\}%/ ) {
                $editTableTag =~ s/(%TABLE\{.*?)(\}%)/$1 $TABLE_EDIT_TAGS$2/;
            }
            _debug("editTableTag after changing TABLE tag=$editTableTag");
        }

        # The Data::parseText merges a TABLE and EDITTABLE to one line
        # We split it again to make editing easier for the user
        # If the two were originally one line - they now become two unless
        # there was white space between them
        $editTableTag =~ s/(%EDITTABLE\{.*?\}%)(%TABLE\{.*?\}%)/$1\n$2/;
        $editTableTag =~ s/(%TABLE\{.*?\}%)(%EDITTABLE\{.*?\}%)/$1\n$2/;

        $resultText = "$editTableTag\n$resultText";

        # END PUT PROCESSED TABLE BACK IN TEXT
        # ========================================

        # ========================================
        # START FORM BOTTOM

        if ( ( $mode & $MODE->{READ} ) ) {
            my $tableEnd = handleTableEnd(
                $doEdit, $tableChanges,
                $tableStats->{headerRowCount},
                $tableStats->{footerRowCount}
            );
            $resultText .= $tableEnd;
        }
        chomp $resultText;    # remove spurious newline at end

        # END FORM BOTTOM
        # ========================================

        # ========================================
        # START BUTTON ROWS

        # button row at top or bottom
        if ( ( $mode & $MODE->{READ} ) ) {
            my $pos = $params{'buttonrow'} || 'bottom';
            my $buttonRow =
              createButtonRow( $web, $topic, $inIncludingWeb, $inIncludingTopic,
                $doEdit );
            if ( $pos eq 'top' ) {
                $resultText =~ s/$PLACEHOLDER_BUTTONROW_BOTTOM//g;    # remove
                $resultText =~ s/$PLACEHOLDER_BUTTONROW_TOP/$buttonRow/g;
            }
            else {
                $resultText =~ s/$PLACEHOLDER_BUTTONROW_TOP//g;       # remove
                $resultText =~ s/$PLACEHOLDER_BUTTONROW_BOTTOM/$buttonRow/g;
            }
        }

        # render variables (only in view mode)
        $resultText = Foswiki::Func::expandCommonVariables($resultText)
          if ( $mode & $MODE->{READ} );

        _debug("After parsing, resultText=$resultText");
        _debug("After parsing, tableNr=$tableNr");

        $topicText =~ s/<!--%EDITTABLESTUB\{$tableNr\}%-->/$resultText/g;

        # END BUTTON ROWS
        # ========================================

    }    # foreach

    # ========================================
    # START SAVE

    if ($doSave) {
        my $url = Foswiki::Func::getViewUrl( $web, $topic );
        try {
            Foswiki::Func::saveTopic( $web, $topic, $meta, $topicText,
                { dontlog => ( $mode & $MODE->{SAVEQUIET} ) } );
        }
        catch Error::Simple with {
            my $e = shift;
            $url =
              Foswiki::Func::getOopsUrl( $web, $topic, 'oopssaveerr',
                "Save failed: " . $e->{-text} );
        };
        Foswiki::Func::setTopicEditLock( $web, $topic, 0 );    # unlock Topic
        $url .= "#edittable$inSaveTableNr";
        Foswiki::Func::redirectCgiQuery( $query, $url );
        return;
    }

    # END SAVE
    # ========================================

    # update the text
    $_[2] = $topicText;

    _debug("After parsing, topic text=$_[2]");
}

=begin TML

NOT FULLY IMPLEMENTED YET

Change table by means of parameters:
   1 Adding rows:
      * param etaddrows_position
      * param etaddrows_count
   1 Deleting rows
      * param etdeleterows_position
      * param etdeleterows_count
   
TODO:
   * addRows: existing rows need to shift down
   * deleteRows: check limit start and end of table
   * create unit test 
   * write documentation
	
=cut

sub handleTableChangeParams {
    my ( $inMode, $inEditTableData, $inTableStats, $inTableChanges, $inWeb,
        $inTopic )
      = @_;

    return $inMode;    # until fully implemented

    # add rows
    {
        my $position = $query->param('etaddrows_position');
        my $count    = $query->param('etaddrows_count');
        if ( defined $position && defined $count ) {
            if ( !doEnableEdit( $inWeb, $inTopic, 1 ) ) {
                my $mode = $MODE->{EDITNOTALLOWED};
                return $mode;
            }
            addRows( $inTableStats, $inTableChanges, $position, $count );
        }
    }

    # delete rows
    {
        my $position = $query->param('etdeleterows_position');
        my $count    = $query->param('etdeleterows_count');
        if ( defined $position && defined $count ) {
            if ( !doEnableEdit( $inWeb, $inTopic, 1 ) ) {
                my $mode = $MODE->{EDITNOTALLOWED};
                return $mode;
            }
            deleteRows( $inTableStats, $inTableChanges, $position, $count );
        }
    }
}

=begin TML

StaticMethod handleButtonActions( $mode, $editTableData, $tableStats, $tableChanges, $web, $topic ) -> $mode

Handles button interaction; for each state updates the $mode to a value of $MODE.

=cut

sub handleButtonActions {
    my ( $inMode, $inEditTableData, $inTableStats, $inTableChanges, $inWeb,
        $inTopic )
      = @_;

    my $mode = $inMode;

    if ( $query->param('etcancel') ) {

        # [Cancel] button pressed
        doCancelEdit( $inWeb, $inTopic );
        $mode = $MODE->{CANCEL};
        return $mode;
    }

    # else
    if ( !doEnableEdit( $inWeb, $inTopic, 1 ) ) {
        $mode = $MODE->{EDITNOTALLOWED};
        return $mode;
    }

    # else
    if ( $query->param('etsave') ) {

        # [Save table] button pressed
        $mode = $MODE->{SAVE};
    }
    elsif ( $query->param('etqsave') ) {

        # [Quiet save] button pressed
        $mode = $MODE->{SAVE} | $MODE->{SAVEQUIET};
    }
    elsif ( $query->param('etaddrow') ) {

        # [Add row] button pressed
        my $rowNum =
          $inTableStats->{rowCount} - $inTableStats->{footerRowCount} + 1;
        addRows( $inTableStats, $inTableChanges, $rowNum, 1 );
    }
    elsif ( $query->param('etdelrow') ) {

        # [Delete row] button pressed
        my $rowNum =
          $inTableStats->{rowCount} - $inTableStats->{footerRowCount};
        deleteRows( $inTableStats, $inTableChanges, $rowNum, 1 );
    }
    elsif ( $query->param('etedit') ) {

        # [Edit table] button pressed
        # just continue
    }

    return $mode;
}

=begin TML

StaticMethod addRows( $tableStats, $tableChanges, $position, $count )

Adds one or more rows.

=cut

sub addRows {
    my ( $inTableStats, $inTableChanges, $inPosition, $inCount ) = @_;

    my $row = $inPosition;

    _debug("ADD ROW:$row");

    while ( $inCount-- ) {

# if we have set a row to 'delete' before, reset it to 2 first; otherwise set an existing row to 'add'
        $inTableChanges->{$row} =
          ( defined $inTableChanges->{$row} && $inTableChanges->{$row} == -1 )
          ? 2
          : 1;
        $row++;
    }
}

=begin TML

StaticMethod deleteRows( $tableStats, $tableChanges, $position, $count )

Deletes one or more rows.

=cut

sub deleteRows {
    my ( $inTableStats, $inTableChanges, $inPosition, $inCount ) = @_;

    my $row = $inPosition;

    # run backwards in rows to see which row has not been deleted yet
    while ($row) {
        last
          if ( !defined $inTableChanges->{$row}
            || $inTableChanges->{$row} != -1 );
        $row--;
    }

    while ( $inCount-- ) {

# if we have set a row to 'add' before, reset it to 0 first; otherwise set an existing row to 'delete'
        $inTableChanges->{$row} =
          ( defined $inTableChanges->{$row} && $inTableChanges->{$row} == 1 )
          ? 0
          : -1;
        $row--;
    }
}

=begin TML

StaticMethod processTableData( $tableNr, $editTableData, $tableChanges, $doEdit, $doSave, $web, $topic ) -> (\@processedText, \%tableChanges)

=cut

sub processTableData {
    my ( $inTableNr, $inEditTableData, $inTableChanges, $inDoEdit, $inDoSave,
        $inWeb, $inTopic )
      = @_;

    my @rows         = ();
    my $tableChanges = $inTableChanges;
    my @result       = ();
    my $tableStats   = $inEditTableData->getTableStatistics($tableChanges);

    _debug( "EditTablePlugin::processTableData - inEditTableData at start="
          . Dumper($inEditTableData) );
    _debug( "EditTablePlugin::processTableData - tableStats at start="
          . Dumper($tableStats) );
    _debug( "EditTablePlugin::processTableData - tableChanges at start="
          . Dumper($tableChanges) );

    my @headerRows = ();
    my @footerRows = ();
    my @bodyRows   = ();

    # ========================================
    my $bodyRowCount =
      $inEditTableData->{'rowCount'} -
      $inEditTableData->{'footerRowCount'} -
      $inEditTableData->{'headerRowCount'};
    $bodyRowCount = 0 if $bodyRowCount < 0;

    # map 'real' rows to types
    # at this point we still use the order as used in the topic
    # so the footer will be in the last rows
    # we are not yet using the updated state of $tableStats

    my @headerRowNums = ();
    my @footerRowNums = ();
    my @bodyRowNums   = ();
    my $rowNr         = 0;

    for ( @{ $inEditTableData->{'lines'} } ) {

        $rowNr++;
        $tableChanges->{$rowNr} ||= 0;

        if ( $rowNr <= $inEditTableData->{'headerRowCount'} ) {

            push @headerRowNums, $rowNr if ( $tableChanges->{$rowNr} != -1 );
        }
        elsif ( ( $rowNr > $inEditTableData->{'headerRowCount'} )
            && (
                $rowNr <= $inEditTableData->{'headerRowCount'} + $bodyRowCount )
          )
        {
            push @bodyRowNums, $rowNr if ( $tableChanges->{$rowNr} != -1 );
        }
        else {
            push @footerRowNums, $rowNr;
        }
    }

    # END GET THE ROW TYPE
    # ========================================

    # ========================================
    # START RENDER CURRENT ROWS

    foreach my $rowNr (@headerRowNums) {
        next
          if ( $inTableChanges
            && defined $inTableChanges->{$rowNr}
            && $inTableChanges->{$rowNr} == -1 );
        local $_ = $inEditTableData->{'lines'}->[ $rowNr - 1 ];

        my $rowId    = $rowNr;
        my $isNewRow = 0;

# a header row will not be edited, so do not render table row with handleTableRow

        # _handleSpreadsheetFormula($_);
        _debug("RENDER ROW: HEADER:rowNr=$rowNr; id=$rowId=$_");
        push( @headerRows, $_ );
    }

    foreach my $rowNr (@footerRowNums) {
        next
          if ( $inTableChanges
            && defined $inTableChanges->{$rowNr}
            && $inTableChanges->{$rowNr} == -1 );
        local $_ = $inEditTableData->{'lines'}->[ $rowNr - 1 ];

        my $rowId    = $rowNr;
        my $isNewRow = 0;

# a footer row will not be edited, so do not render table row with handleTableRow

        # _handleSpreadsheetFormula($_);
        _debug("RENDER ROW: FOOTER:rowNr=$rowNr; id=$rowId=$_");
        push( @footerRows, $_ );
    }

    foreach my $rowNr (@bodyRowNums) {
        next
          if ( $inTableChanges
            && defined $inTableChanges->{$rowNr}
            && $inTableChanges->{$rowNr} == -1 );
        local $_ = $inEditTableData->{'lines'}->[ $rowNr - 1 ];

        my $rowId    = @headerRows + scalar @bodyRows + 1;
        my $isNewRow = 0;
        if ( $tableChanges->{$rowId} && $tableChanges->{$rowId} == 2 ) {
            $isNewRow = 1;
            $tableChanges->{$rowId} = 0;
        }

s/$PATTERN_TABLE_ROW/handleTableRow( $1, $2, $inTableNr, $isNewRow, $rowId, $inDoEdit, $inDoSave, $inWeb, $inTopic )/eo;

        _debug("RENDER ROW: BODY:rowNr=$rowNr; id=$rowId=$_");
        push( @bodyRows, $_ );
    }

    # END RENDER CURRENT ROWS
    # ========================================

    # ========================================
    # START ADDING ROWS

    # START ADDING HEADER ROWS

    # add a header row if there is none,
    # but only if there are no body rows yet
    # (and not when a row has just been deleted)

    if ( !( scalar @bodyRows ) ) {

        my $headerRows = $query->param('etheaderrows') || 0;
        if ( $headerRows > scalar @headerRows ) {
            my $rowNr        = scalar @headerRows;
            my $newHeaderRow = $headerRows - @headerRows;
            while ( $newHeaderRow-- ) {

                my $rowId =
                  scalar @headerRows +
                  scalar @footerRows +
                  scalar @bodyRows + 1;
                next
                  if ( $tableChanges->{$rowId} == -1
                    || $tableChanges->{$rowId} == 2 );

                $tableChanges->{$rowId} = 1;    # store the new row
                my $isNewRow = 1;
                my $newRow   = handleTableRow(
                    '',     '',        $inTableNr, $isNewRow,
                    $rowId, $inDoEdit, $inDoSave,  $inWeb,
                    $inTopic
                );
                push @headerRows, $newRow;
            }
        }

        # to start with table editing right away, add a minimum of 1 body row
        if ( !$tableStats->{bodyRowCount} ) {

            # put row at bottom
            my $rowId =
              scalar @headerRows + scalar @footerRows + scalar @bodyRows + 1;
            $tableChanges->{$rowId} ||= 0;
            if (
                !(
                       $tableChanges->{$rowId} == -1
                    || $tableChanges->{$rowId} == 2
                )
              )
            {
                $tableChanges->{$rowId} = 1;    # store the new row
                my $isNewRow = 0;
                my $newRow   = handleTableRow(
                    '',     '',        $inTableNr, $isNewRow,
                    $rowId, $inDoEdit, $inDoSave,  $inWeb,
                    $inTopic
                );
                push @bodyRows, $newRow;
            }
        }

        # update table stats
        $tableStats = $inEditTableData->getTableStatistics($tableChanges);
    }

    # END ADDING HEADER ROWS

    # START ADDING BODY ROWS

    my $bodyRows = $tableStats->{bodyRowCount};

    if ( $bodyRows > scalar @bodyRows ) {

        my $rowNr = scalar @headerRows + scalar @footerRows + scalar @bodyRows;
        my $newBodyRow = $bodyRows - @bodyRows;

        _debug("ADD ROW: BODY: number=$newBodyRow");

        while ( $newBodyRow-- ) {
            $rowNr++;

            next
              if (
                (
                    defined $inTableChanges->{$rowNr}
                    && $inTableChanges->{$rowNr} == -1
                )
                || ( defined $inTableChanges->{$rowNr}
                    && $inTableChanges->{$rowNr} == 2 )
              );

            my $rowId = scalar @headerRows + scalar @bodyRows + 1;

            _debug("ADD ROW: BODY: rowId=$rowId");

            my $isNewRow = 0
              ; # otherwise values entered in new rows are not preserved when adding yet more rows

            my $newRow = handleTableRow(
                '',     '',        $inTableNr, $isNewRow,
                $rowId, $inDoEdit, $inDoSave,  $inWeb,
                $inTopic
            );

            _debug("ADD ROW: BODY: newRow=$newRow");

            push @bodyRows, $newRow;
        }

        # update table stats
        $tableStats = $inEditTableData->getTableStatistics($tableChanges);
    }

    # END ADDING BODY ROWS

    # END ADDING ROWS
    # ========================================

    _debug( "EditTablePlugin::processTableData - tableChanges at end="
          . Dumper($tableChanges) );
    _debug( "EditTablePlugin::processTableData - tableStats at end="
          . Dumper($tableStats) );

    _debug(
"EditTablePlugin::processTableData - headerRows=\n---------------------\n"
          . Dumper(@headerRows) );
    _debug(
        "EditTablePlugin::processTableData - bodyRows=\n---------------------\n"
          . Dumper(@bodyRows) );
    _debug(
"EditTablePlugin::processTableData - footerRows=\n---------------------\n"
          . Dumper(@footerRows) );

    my @combinedRows = ( @headerRows, @bodyRows, @footerRows );

    _debug(
"EditTablePlugin::processTableData - combinedRows=\n---------------------\n"
          . Dumper(@combinedRows) );

    push( @result, @combinedRows );

    @result = map { $_ .= "\n" } @result;

    return ( \@result, $tableChanges );
}

=begin TML

StaticMethod getPreferencesValues()

Read preferences from plugin topic of preferences.

=cut

sub getPreferencesValues {

    my $pluginName = $Foswiki::Plugins::EditTablePlugin::pluginName;

    $prefCHANGEROWS =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_CHANGEROWS") || 'on';

    $prefQUIETSAVE =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_QUIETSAVE") || 'on';

    $prefEDIT_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_EDIT_BUTTON")
      || '%MAKETEXT{"Edit this table"}%, %ATTACHURL%/edittable.gif';

    $prefSAVE_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_SAVE_BUTTON")
      || '%MAKETEXT{"Save table"}%';

    $prefQUIET_SAVE_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_QUIET_SAVE_BUTTON")
      || '%MAKETEXT{"Quiet save"}%';

    $prefADD_ROW_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_ADD_ROW_BUTTON")
      || '%MAKETEXT{"Add row"}%';

    $prefDELETE_LAST_ROW_BUTTON = Foswiki::Func::getPreferencesValue(
        "\U$pluginName\E_DELETE_LAST_ROW_BUTTON")
      || '%MAKETEXT{"Delete last row"}%';

    $prefCANCEL_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_CANCEL_BUTTON")
      || '%MAKETEXT{"Cancel"}%';

    $prefMESSAGE_INCLUDED_TOPIC_DOES_NOT_EXIST =
      Foswiki::Func::getPreferencesValue(
        "\U$pluginName\E_INCLUDED_TOPIC_DOES_NOT_EXIST")
      || '<span class="foswikiAlert">%MAKETEXT{"Warning: \'include\' topic does not exist!"}%</span>';
}

=begin TML

StaticMethod extractParams( $arguments, \%params ) 

=cut

sub extractParams {
    my ( $inArguments, $inParams ) = @_;

    my $tmp;

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments, 'header' );
    $$inParams{'header'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments, 'footer' );
    $$inParams{'footer'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments, 'headerislabel' );
    $$inParams{'headerislabel'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments, 'format' );
    $tmp =~ s/^\s*\|*\s*//;
    $tmp =~ s/\s*\|*\s*$//;
    $$inParams{'format'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments, 'changerows' );
    $$inParams{'changerows'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments, 'quietsave' );
    $$inParams{'quietsave'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments, 'helptopic' );
    $$inParams{'helptopic'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments, 'editbutton' );
    $$inParams{'editbutton'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments,
        'javascriptinterface' );
    $$inParams{'javascriptinterface'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $inArguments, 'buttonrow' );
    $$inParams{'buttonrow'} = $tmp if ($tmp);
}

=begin TML

=cut

sub parseFormat {
    my ( $theFormat, $inTopic, $inWeb, $doExpand ) = @_;

    $theFormat =~ s/\$nop(\(\))?//gs;         # remove filler
    $theFormat =~ s/\$quot(\(\))?/\"/gs;      # expand double quote
    $theFormat =~ s/\$percnt(\(\))?/\%/gs;    # expand percent
    $theFormat =~ s/\$dollar(\(\))?/\$/gs;    # expand dollar

    if ($doExpand) {

        # expanded form to be able to use %-vars in format
        $theFormat =~ s/<nop>//gs;
        $theFormat =
          Foswiki::Func::expandCommonVariables( $theFormat, $inTopic, $inWeb );
    }

    my @aFormat = split( /\s*\|\s*/, $theFormat );
    $aFormat[0] = "text,$DEFAULT_FIELD_SIZE" unless @aFormat;

    return @aFormat;
}

=begin TML

=cut

sub handleEditTableTag {
    my ( $inWeb, $inTopic, $inArguments ) = @_;

    %params = (
        'header'              => '',
        'footer'              => '',
        'headerislabel'       => "1",
        'format'              => '',
        'changerows'          => $prefCHANGEROWS,
        'quietsave'           => $prefQUIETSAVE,
        'helptopic'           => '',
        'editbutton'          => '',
        'javascriptinterface' => '',
        'buttonrow'           => '',
    );
    $warningMessage = '';

    # include topic to read definitions
    my $iTopic = Foswiki::Func::extractNameValuePair( $inArguments, 'include' );
    if ($iTopic) {
        ( $inWeb, $iTopic ) =
          Foswiki::Func::normalizeWebTopicName( $inWeb, $iTopic );

        unless ( Foswiki::Func::topicExists( $inWeb, $iTopic ) ) {
            $warningMessage = $prefMESSAGE_INCLUDED_TOPIC_DOES_NOT_EXIST;
        }
        else {

            my $text = Foswiki::Func::readTopicText( $inWeb, $iTopic );
            $text =~ /$PATTERN_EDITTABLEPLUGIN/s;
            if ($2) {
                my $args = $2;
                if (   $inWeb ne $Foswiki::Plugins::EditTablePlugin::web
                    || $iTopic ne $Foswiki::Plugins::EditTablePlugin::topic )
                {

                    # expand common vars, unless oneself to prevent recursion
                    $args =
                      Foswiki::Func::expandCommonVariables( $args, $iTopic,
                        $inWeb );
                }
                extractParams( $args, \%params );
            }
        }
    }

    # We allow expansion of macros in the EDITTABLE arguments so one can
    # set a macro that defines the arguments

    my $arguments =
      Foswiki::Func::expandCommonVariables( $inArguments, $inTopic, $inWeb );

    extractParams( $arguments, \%params );

    # FIXME: should use Foswiki::Func::extractParameters
    $params{'header'} = '' if ( $params{header} =~ /^(off|no)$/i );
    $params{'header'} =~ s/^\s*\|//;
    $params{'header'} =~ s/\|\s*$//;
    $params{'headerislabel'} = ''
      if ( $params{headerislabel} =~ /^(off|no)$/i );
    $params{'footer'} = '' if ( $params{footer} =~ /^(off|no)$/i );
    $params{'footer'} =~ s/^\s*\|//;
    $params{'footer'} =~ s/\|\s*$//;

    $params{'changerows'} = '' if ( $params{changerows} =~ /^(off|no)$/i );
    $params{'quietsave'}  = '' if ( $params{quietsave}  =~ /^(off|no)$/i );
    $params{'javascriptinterface'} = 'off'
      if ( $params{javascriptinterface} =~ /^(off|no)$/i );

    @format         = parseFormat( $params{format}, $inTopic, $inWeb, 0 );
    @formatExpanded = parseFormat( $params{format}, $inTopic, $inWeb, 1 );
    $nrCols         = scalar @format;
}

=begin TML

Creates the HTML for the start of the table.

=cut

sub handleTableStart {
    my ( $inWeb, $inTopic, $inIncludingWeb, $inIncludingTopic, $theTableNr,
        $doEdit )
      = @_;

    if ($doEdit) {
        require Foswiki::Contrib::JSCalendarContrib;
        unless ($@) {
            Foswiki::Contrib::JSCalendarContrib::addHEAD('foswiki');
        }
    }

    my $viewUrl = Foswiki::Func::getScriptUrl( $inWeb, $inTopic, 'viewauth' )
      . "\#edittable$theTableNr";

    my $text = '';
    $text .= "$preSp<noautolink>\n" if $doEdit;
    $text .= "$preSp<a name=\"edittable$theTableNr\"></a>\n"
      if ( "$inWeb.$inTopic" eq "$inIncludingWeb.$inIncludingTopic" );
    my $cssClass = 'editTable';
    if ($doEdit) {
        $cssClass .= ' editTableEdit';
    }
    $text .= "<div class=\"" . $cssClass . "\">\n";
    my $formName = "edittable$theTableNr";
    $formName .= "\_$inIncludingWeb\_$inIncludingTopic"
      if ( "$inWeb\_$inTopic" ne "$inIncludingWeb\_$inIncludingTopic" );
    $text .=
      "$preSp<form name=\"$formName\" action=\"$viewUrl\" method=\"post\">\n";

    $text .= $PLACEHOLDER_BUTTONROW_TOP;

    $text .= hiddenField( $preSp, 'ettablenr', $theTableNr, "\n" );
    $text .= hiddenField( $preSp, 'etedit',    'on',        "\n" );

    return $text;
}

=begin TML

=cut

sub handleTableEnd {
    my ( $inDoEdit, $inTableChanges, $inHeaderRowCount, $inFooterRowCount ) =
      @_;

    my $text = '';

    $text .= hiddenField(
        $preSp,
        'ettablechanges',
        Foswiki::Plugins::EditTablePlugin::EditTableData::tableChangesMapToParamString(
            $inTableChanges),
        "\n"
    );
    $text .= hiddenField( $preSp, 'etheaderrows', $inHeaderRowCount, "\n" );
    $text .= hiddenField( $preSp, 'etfooterrows', $inFooterRowCount, "\n" );

    $text .= $PLACEHOLDER_BUTTONROW_BOTTOM;

    $text .= "$preSp</form>\n";
    $text .= "</div><!-- /editTable -->";
    $text .= "</noautolink>" if $inDoEdit;

    return $text;
}

=begin TML

=cut

sub hiddenField {
    my ( $inPrefix, $inName, $inValue, $inSuffix ) = @_;

    my $prefix = defined $inPrefix ? $inPrefix : '';
    my $suffix = defined $inSuffix ? $inSuffix : '';

    # Somehow this does not work at all:
    # return $prefix
    #   . CGI::hidden(
    #     -name  => $name,
    #     -value => $value
    #   ) . $suffix;

    return
"$prefix<input type=\"hidden\" name=\"$inName\" value=\"$inValue\" />$suffix";
}

=begin TML

=cut

sub createButtonRow {
    my ( $inWeb, $inTopic, $inIncludingWeb, $inIncludingTopic, $doEdit ) = @_;

    my $text = '';
    if ( $doEdit
        && ( "$inWeb.$inTopic" eq "$inIncludingWeb.$inIncludingTopic" ) )
    {

        # Edit mode
        $text .=
"$preSp<input type=\"submit\" name=\"etsave\" id=\"etsave\" value=\"$prefSAVE_BUTTON\" class=\"foswikiSubmit\" />\n";
        if ( $params{'quietsave'} ) {
            $text .=
"$preSp<input type=\"submit\" name=\"etqsave\" id=\"etqsave\" value=\"$prefQUIET_SAVE_BUTTON\" class=\"foswikiButton\" />\n";
        }
        if ( $params{'changerows'} ) {
            $text .=
"$preSp<input type=\"submit\" name=\"etaddrow\" id=\"etaddrow\" value=\"$prefADD_ROW_BUTTON\" class=\"foswikiButton\" />\n";
            $text .=
"$preSp<input type=\"submit\" name=\"etdelrow\" id=\"etdelrow\" value=\"$prefDELETE_LAST_ROW_BUTTON\" class=\"foswikiButton\" />\n"
              unless ( $params{'changerows'} =~ /^add$/i );
        }
        $text .=
"$preSp<input type=\"submit\" name=\"etcancel\" id=\"etcancel\" value=\"$prefCANCEL_BUTTON\" class=\"foswikiButtonCancel\" />\n";

        if ( $params{'helptopic'} ) {

            # read help topic and show below the table
            if ( $params{'helptopic'} =~ /^([^\.]+)\.(.*)$/ ) {
                $inWeb = $1;
                $params{'helptopic'} = $2;
            }
            my $helpText =
              Foswiki::Func::readTopicText( $inWeb, $params{'helptopic'} );

            #Strip out the meta data so it won't be displayed.
            $helpText =~ s/%META:[A-Za-z0-9]+{.*?}%//g;
            if ($helpText) {
                $helpText =~ s/.*?%STARTINCLUDE%//s;
                $helpText =~ s/%STOPINCLUDE%.*//s;
                $text .= $helpText;
            }
        }

        # table specific script
        my $tableNr = $query->param('ettablenr');
        &Foswiki::Plugins::EditTablePlugin::addEditModeHeadersToHead( $tableNr,
            $params{'javascriptinterface'} );
        &Foswiki::Plugins::EditTablePlugin::addJavaScriptInterfaceDisabledToHead
          ($tableNr)
          if ( $params{'javascriptinterface'} eq 'off' );
        &Foswiki::Plugins::EditTablePlugin::addJavaScriptInterfaceDisabledToHead
          ($tableNr)
          if ( $params{'changerows'} eq '' );
    }
    else {
        $params{editbutton} |= '';

        # View mode
        if ( $params{editbutton} eq "hide" ) {

            # do nothing, button assumed to be in a cell
        }
        else {

            # Add edit button to end of table
            $text .=
              $preSp . viewEditCell("editbutton, 1, $params{'editbutton'}");
        }
    }
    return $text;
}

=begin TML

=cut

sub parseEditCellFormat {
    $_[1] = Foswiki::Func::extractNameValuePair( $_[0] );
    return '';
}

=begin TML

=cut

sub viewEditCell {
    my ($inAttr) = @_;

    my $attributes = Foswiki::Func::extractNameValuePair($inAttr);
    return '' unless ( $attributes =~ /^editbutton/ );

    $params{editbutton} = 'hide'
      unless ( $params{editbutton} );    # Hide below table edit button

    my @bits = split( /,\s*/, $attributes );
    my $value = '';
    $value = $bits[2] if ( @bits > 2 );
    my $img = '';
    $img = $bits[3] if ( @bits > 3 );

    unless ($value) {
        $value = $prefEDIT_BUTTON || '';
        $img = '';
        if ( $value =~ s/(.+),\s*(.+)/$1/o ) {
            $img = $2;
            $img =~ s|%ATTACHURL%|%PUBURL%/%SYSTEMWEB%/EditTablePlugin|;
            $img =~ s|%WEB%|%SYSTEMWEB%|;
        }
    }
    if ($img) {
        return
"<input class=\"editTableEditImageButton\" type=\"image\" src=\"$img\" alt=\"$value\" /> $warningMessage";
    }
    else {
        return
"<input class=\"foswikiButton editTableEditButton\" type=\"submit\" value=\"$value\" /> $warningMessage";
    }
}

=begin TML

=cut

sub saveEditCellFormat {
    my ( $theFormat, $theName ) = @_;

    return '' unless ($theFormat);
    $theName =~ s/cell/format/;
    return hiddenField( '', $theName, $theFormat, '' );
}

=begin TML

digestedCellValue: properly handle labels whose result may have been moved around by javascript, and therefore no longer correspond to the raw saved table text.

=cut

sub inputElement {
    my ( $inTableNr, $inRowNr, $inColumnNr, $inName, $inValue,
        $inDigestedCellValue, $inWeb, $inTopic )
      = @_;

    my $rawValue = $inValue;
    my $text     = '';
    my $i        = @format - 1;
    $i = $inColumnNr if ( $inColumnNr < $i );

    my @bits         = split( /,\s*/, $format[$i] );
    my @bitsExpanded = split( /,\s*/, $formatExpanded[$i] );

    my $cellFormat = '';
    $inValue =~
      s/\s*$PATTERN_EDITCELL/&parseEditCellFormat( $1, $cellFormat )/e;

    # If cell is empty we remove the space to not annoy the user when
    # he needs to add text to empty cell.
    $inValue = '' if ( $inValue eq ' ' );

    if ($cellFormat) {
        my @aFormat = parseFormat( $cellFormat, $inTopic, $inWeb, 0 );
        @bits = split( /,\s*/, $aFormat[0] );
        @aFormat = parseFormat( $cellFormat, $inTopic, $inWeb, 1 );
        @bitsExpanded = split( /,\s*/, $aFormat[0] );
    }

    my $type = 'text';
    $type = $bits[0] if @bits > 0;

    # a table header is considered a label if read only header flag set
    $type = 'label'
      if ( ( $params{'headerislabel'} ) && ( $inValue =~ /^\s*\*.*\*\s*$/ ) );
    $type = 'label' if ( $type eq 'editbutton' );    # Hide [Edit table] button
    my $size = 0;
    $size = $bits[1] if @bits > 1;

    my $val         = '';
    my $valExpanded = '';
    my $sel         = '';

    if ( $type eq 'select' ) {
        my $expandedValue =
          Foswiki::Func::expandCommonVariables( $inValue, $inTopic, $inWeb );
        $size = 1 if $size < 1;
        $text =
          "<select class=\"foswikiSelect\" name=\"$inName\" size=\"$size\">";
        $i = 2;
        while ( $i < @bits ) {
            $val         = $bits[$i]         || '';
            $valExpanded = $bitsExpanded[$i] || '';
            $expandedValue =~ s/^\s+//;
            $expandedValue =~ s/\s+$//;
            $valExpanded   =~ s/^\s+//;
            $valExpanded   =~ s/\s+$//;

            if ( $valExpanded eq $expandedValue ) {
                $text .= " <option selected=\"selected\">$val</option>";
            }
            else {
                $text .= " <option>$val</option>";
            }
            $i++;
        }
        $text .= "</select>";
        $text .= saveEditCellFormat( $cellFormat, $inName );

    }
    elsif ( $type eq "radio" ) {
        my $expandedValue =
          &Foswiki::Func::expandCommonVariables( $inValue, $inTopic, $inWeb );
        $size = 1 if $size < 1;
        my $elements = ( @bits - 2 );
        my $lines    = $elements / $size;
        $lines = ( $lines == int($lines) ) ? $lines : int( $lines + 1 );
        $text .= "<table class=\"editTableInnerTable\"><tr><td valign=\"top\">"
          if ( $lines > 1 );
        $i = 2;
        while ( $i < @bits ) {
            $val         = $bits[$i]         || "";
            $valExpanded = $bitsExpanded[$i] || "";
            $expandedValue =~ s/^\s+//;
            $expandedValue =~ s/\s+$//;
            $valExpanded   =~ s/^\s+//;
            $valExpanded   =~ s/\s+$//;
            $text .= "<input type=\"radio\" name=\"$inName\" value=\"$val\"";

            # make space to expand variables
            $val = addSpaceToBothSides($val);
            $text .= " checked=\"checked\""
              if ( $valExpanded eq $expandedValue );
            $text .= " />$val";
            if ( $lines > 1 ) {

                if ( ( $i - 1 ) % $lines ) {
                    $text .= "<br />";
                }
                elsif ( $i - 1 < $elements ) {
                    $text .= "</td><td valign=\"top\">";
                }
            }
            $i++;
        }
        $text .= "</td></tr></table>" if ( $lines > 1 );
        $text .= saveEditCellFormat( $cellFormat, $inName );

    }
    elsif ( $type eq "checkbox" ) {
        my $expandedValue =
          &Foswiki::Func::expandCommonVariables( $inValue, $inTopic, $inWeb );
        $size = 1 if $size < 1;
        my $elements = ( @bits - 2 );
        my $lines    = $elements / $size;
        my $names    = "Chkbx:";
        $lines = ( $lines == int($lines) ) ? $lines : int( $lines + 1 );
        $text .= "<table class=\"editTableInnerTable\"><tr><td valign=\"top\">"
          if ( $lines > 1 );
        $i = 2;

        while ( $i < @bits ) {
            $val         = $bits[$i]         || "";
            $valExpanded = $bitsExpanded[$i] || "";
            $expandedValue =~ s/^\s+//;
            $expandedValue =~ s/\s+$//;
            $valExpanded   =~ s/^\s+//;
            $valExpanded   =~ s/\s+$//;
            $names .= " ${inName}x$i";
            $text .=
              " <input type=\"checkbox\" name=\"${inName}x$i\" value=\"$val\"";

            $val = addSpaceToBothSides($val);

            $text .= " checked=\"checked\""
              if ( $expandedValue =~ /(^|\s*,\s*)\Q$valExpanded\E(\s*,\s*|$)/ );
            $text .= " />$val";

            if ( $lines > 1 ) {
                if ( ( $i - 1 ) % $lines ) {
                    $text .= "<br />";
                }
                elsif ( $i - 1 < $elements ) {
                    $text .= "</td><td valign=\"top\">";
                }
            }
            $i++;
        }
        $text .= "</td></tr></table>" if ( $lines > 1 );
        $text .= hiddenField( $preSp, $inName, $names );
        $text .= saveEditCellFormat( $cellFormat, $inName, "\n" );

    }
    elsif ( $type eq 'row' ) {
        $size = $size + $inRowNr;
        $text =
            "<span class=\"et_rowlabel\">"
          . hiddenField( $size, $inName, $size )
          . "</span>";
        $text .= saveEditCellFormat( $cellFormat, $inName );
    }
    elsif ( $type eq 'label' ) {

        # show label text as is, and add a hidden field with value
        my $isHeader = 0;
        $isHeader = 1 if ( $inValue =~ s/^\s*\*(.*)\*\s*$/$1/ );
        $text = $inValue;

        # Replace CALC in labels with the fixed string CALC to avoid errors
        # when editing.
        _handleSpreadsheetFormula($text);

        # To optimize things, only in the case where a read-only column is
        # being processed (inside of this unless() statement) do we actually
        # go out and read the original topic.  Thus the reason for the
        # following unless() so we only read the topic the first time through.

        unless ( defined $tableMatrix{$inWeb}{$inTopic}
            and $inDigestedCellValue )
        {

            # To deal with the situation where Foswiki variables, like
            # %CALC%, have already been processed and end up getting saved
            # in the table that way (processed), we need to read in the
            # topic page in raw format
            my $topicContents = Foswiki::Func::readTopicText(
                $Foswiki::Plugins::EditTablePlugin::web,
                $Foswiki::Plugins::EditTablePlugin::topic
            );
            parseTables( $topicContents, $inTopic, $inWeb );
        }
        my $table = $tableMatrix{$inWeb}{$inTopic};
        my $cell =
            $inDigestedCellValue
          ? $table->getCell( $inTableNr, $inRowNr - 1, $inColumnNr )
          : $rawValue;
        $inValue = $cell if ( defined $cell );    # original value from file
        Foswiki::Plugins::EditTablePlugin::encodeValue($inValue)
          unless ( $inValue eq '' );

        #$inValue = "\*$inValue\*" if ( $isHeader and $inDigestedCellValue );
        $text = "\*$text\*" if $isHeader;
        $text .= ' ' . hiddenField( $preSp, $inName, $inValue );
    }
    elsif ( $type eq 'textarea' ) {
        my ( $rows, $cols ) = split( /x/, $size );

        $rows |= 3  if !defined $rows;
        $cols |= 30 if !defined $cols;
        Foswiki::Plugins::EditTablePlugin::encodeValue($inValue)
          unless ( $inValue eq '' );
        $text .=
"<textarea class=\"foswikiTextarea editTableTextarea\" rows=\"$rows\" cols=\"$cols\" name=\"$inName\">$inValue</textarea>";
        $text .= saveEditCellFormat( $cellFormat, $inName );

    }
    elsif ( $type eq 'date' ) {

        # calendar format
        my $ifFormat = '';
        $ifFormat = $bits[3] if ( @bits > 3 );
        $ifFormat ||= $Foswiki::cfg{JSCalendarContrib}{format} || '%e %B %Y';

        # protect format from parsing
        Foswiki::Plugins::EditTablePlugin::encodeValue($ifFormat);

        $size = 10 if ( !$size || $size < 1 );

        Foswiki::Plugins::EditTablePlugin::encodeValue($inValue)
          unless ( $inValue eq '' );
        $text .= CGI::textfield(
            {
                name     => $inName,
                class    => 'foswikiInputField editTableInput',
                id       => 'id' . $inName,
                size     => $size,
                value    => $inValue,
                override => 1
            }
        );
        $text .= saveEditCellFormat( $cellFormat, $inName );
        eval 'use Foswiki::Contrib::JSCalendarContrib';

        unless ($@) {
            $text .= '<span class="foswikiMakeVisible">';
            $text .= CGI::image_button(
                -class   => 'editTableCalendarButton',
                -name    => 'calendar',
                -onclick => "return showCalendar('id$inName','$ifFormat')",
                -src     => Foswiki::Func::getPubUrlPath() . '/'
                  . $Foswiki::cfg{SystemWebName}
                  . '/JSCalendarContrib/img.gif',
                -alt   => 'Calendar',
                -align => 'middle'
            );
            $text .= '</span>';
        }
        $query->{'jscalendar'} = 1;

        # prevent wrapping of button below input field
        $text = "<nobr>$text</nobr>";
    }
    else {    #  if( $type eq 'text')
        $size = $DEFAULT_FIELD_SIZE if $size < 1;
        Foswiki::Plugins::EditTablePlugin::encodeValue($inValue)
          unless ( $inValue eq '' );
        $text =
"<input class=\"foswikiInputField editTableInput\" type=\"text\" name=\"$inName\" size=\"$size\" value=\"$inValue\" />";
        $text .= saveEditCellFormat( $cellFormat, $inName );
    }

    if ( $type ne 'textarea' ) {
        $text =~
          s/&#10;/<br \/>/g;    # change unicode linebreak character to <br />
    }
    return $text;
}

=begin TML

=cut

sub handleTableRow {
    my (
        $thePre, $theRow, $theTableNr, $isNewRow, $theRowNr,
        $doEdit, $doSave, $inWeb,      $inTopic
    ) = @_;

    _debug( "EditTablePlugin::Core::handleTableRow; params="
          . "\n\t thePre=$thePre."
          . "\n\t theRow=$theRow."
          . "\n\t theTableNr=$theTableNr"
          . "\n\t isNewRow=$isNewRow"
          . "\n\t theRowNr=$theRowNr"
          . "\n\t doEdit=$doEdit"
          . "\n\t doSave=$doSave"
          . "\n\t inWeb=$inWeb"
          . "\n\t inTopic=$inTopic" );

    $thePre |= '';
    my $text = "$thePre\|";

    if ($doEdit) {
        $theRow =~ s/\|\s*$//;

        # retrieve any params sent by javascript interface (see edittable.js)
        my $rowID = $query->param("etrow_id$theRowNr");
        $rowID = $theRowNr if !defined $rowID;

        my @cells;
        my $isNewRowFromHeader = ( $theRowNr <= 1 ) && ( $params{'header'} );
        @cells =
          $isNewRowFromHeader
          ? split( /\|/, $params{'header'} )
          : split( /\|/, $theRow );
        my $tmp = @cells;
        $nrCols = $tmp if ( $tmp > $nrCols );    # expand number of cols
        my $val         = '';
        my $cellFormat  = '';
        my $cell        = '';
        my $digested    = 0;
        my $cellDefined = 0;
        my $col         = 0;

        while ( $col < $nrCols ) {
            $col += 1;
            $cellDefined = 0;
            my $cellValueParam = "etcell${rowID}x$col";
            $val = $isNewRow ? undef : $query->param($cellValueParam);

           #my $tmpVal = defined $val ? $val : '';
           #_debug( "\t col=$col, cellValueParam=$cellValueParam; val=$tmpVal");

            if ( defined $val && $val =~ /^Chkbx: (etcell.*)/ ) {

      # Multiple checkboxes, val has format "Chkbx: etcell4x2x2 etcell4x2x3 ..."
                my $checkBoxNames  = $1;
                my $checkBoxValues = "";
                foreach ( split( /\s/, $checkBoxNames ) ) {
                    $val = $query->param($_);

                    #$checkBoxValues .= "$val," if ( defined $val );
                    if ( defined $val ) {

                        # make space to expand variables
                        $val = addSpaceToBothSides($val);
                        $checkBoxValues .= $val . ',';
                    }
                }
                $checkBoxValues =~ s/,\s*$//;
                $val = $checkBoxValues;
            }

            # SMELL NOTE: etformat is not specified. What should it do?
            $cellFormat = $query->param("etformat${rowID}x$col");
            $val .= " %EDITCELL{$cellFormat}%" if ($cellFormat);

            if ( defined $val ) {

                # change any new line character sequences to <br />
                $val =~ s/[\n\r]{2,}?/<br \/>/gs;

                # escape "|" to HTML entity
                $val =~ s/\|/\&\#124;/gs;
                $cellDefined = 1;

                # Expand %-vars
                $cell = $val;
            }
            elsif ( $col <= @cells ) {

                $cell = $cells[ $col - 1 ];
                $digested = 1;    # Flag that we are using non-raw cell text.
                $cellDefined = 1 if ( length($cell) > 0 );
                $cell =~ s/^\s*(.+?)\s*$/$1/
                  ; # remove spaces around content, but do not void a cell with just spaces
            }
            else {
                $cell = '';
            }
            if ($isNewRowFromHeader) {

                unless ($cell) {
                    if ( $params{'header'} =~ /^on$/i ) {
                        if (   ( @format >= $col )
                            && ( $format[ $col - 1 ] =~ /(.*?)\,/ ) )
                        {
                            $cell = $1;
                        }
                        $cell = 'text' unless $cell;
                        $cell = "*$cell*";
                    }
                    else {
                        my @hCells = split( /\|/, $params{'header'} );
                        $cell = $hCells[ $col - 1 ] if ( @hCells >= $col );
                        $cell = "*text*" unless $cell;
                    }
                }
                $cell = addSpaceToBothSides($cell);
                $text .= "$cell\|";
            }
            elsif ($doSave) {
                $cell = addSpaceToBothSides($cell);

            # Item5217 Avoid that deleting content of cell creates unwanted span
                $cell = ' ' if $cell eq '';

                $text .= "$cell\|";
            }
            else {
                if (
                       ( !$cellDefined )
                    && ( @format >= $col )
                    && ( $format[ $col - 1 ] =~
                        /^\s*(.*?)\,\s*(.*?)\,\s*(.*?)\s*$/ )
                  )
                {

                    # default value of "| text, 20, a, b, c |" cell is "a, b, c"
                    # default value of '| select, 1, a, b, c |' cell is "a"
                    $val = $1;    # type

                    $cell = $3;
                    $cell = ''
                      unless ( defined $cell && $cell ne '' )
                      ;           # Proper handling of '0'
                    $cell =~ s/\,.*$//
                      if ( $val eq 'select' || $val eq 'date' );
                }
                my $element = '';
                $cell = '' if $isNewRow;
                $element =
                  inputElement( $theTableNr, $theRowNr, $col - 1,
                    "etcell${theRowNr}x$col", $cell, $digested, $inWeb,
                    $inTopic );
                $element = " $element \|";
                $text .= $element;
            }
        }
    }
    else {

        # render EDITCELL in view mode
        $theRow =~ s/$PATTERN_EDITCELL/viewEditCell($1)/ge if !$doSave;
        $text .= $theRow;

    }    # /if ($doEdit)

    # render final value in view mode (not edit or save)
    Foswiki::Func::decodeFormatTokens($text)
      if ( !$doSave && !$doEdit );

    return $text;
}

=begin TML

Add one space to both sides of the text to allow TML expansion.
Convert multiple (existing) spaces to one space.

=cut

sub addSpaceToBothSides {
    my ($text) = @_;
    return $text if $text eq '';

    $text = " $text ";
    $text =~ s/^[[:space:]]+/ /;    # remove extra spaces
    $text =~ s/[[:space:]]+$/ /;
    return $text;
}

=begin TML

=cut

sub doCancelEdit {
    my ( $inWeb, $inTopic ) = @_;

    Foswiki::Func::setTopicEditLock( $inWeb, $inTopic, 0 );

    Foswiki::Func::redirectCgiQuery( $query,
        Foswiki::Func::getViewUrl( $inWeb, $inTopic ) );
}

=begin TML

=cut

sub doEnableEdit {
    my ( $inWeb, $inTopic, $doCheckIfLocked ) = @_;

    my $wikiUserName = Foswiki::Func::getWikiName();
    if (
        !Foswiki::Func::checkAccessPermission(
            'change', $wikiUserName, undef, $inTopic, $inWeb
        )
      )
    {

        # user has no permission to change the topic
        throw Foswiki::OopsException(
            'accessdenied',
            status => 403,
            def    => 'topic_access',
            web    => $inWeb,
            topic  => $inTopic,
            params => [ 'change', 'denied' ]
        );
    }

    my $breakLock = $query->param('breaklock') || '';
    unless ($breakLock) {
        my ( $oopsUrl, $lockUser ) =
          Foswiki::Func::checkTopicEditLock( $inWeb, $inTopic, 'view' );
        if ($oopsUrl) {
            my $loginUser = Foswiki::Func::wikiToUserName($wikiUserName);
            if ( $lockUser ne $loginUser ) {

                # change the default oopsleaseconflict url
                # use viewauth instead of view
                $oopsUrl =~ s/param4=view/param4=viewauth/;

                # add info of the edited table
                my $params = '';
                $query = Foswiki::Func::getCgiQuery();
                $params .= ';ettablenr=' . $query->param('ettablenr');
                $params .= ';etedit=on';
                $oopsUrl =~ s/($|#\w*)/$params/;

                # warn user that other person is editing this topic
                Foswiki::Func::redirectCgiQuery( $query, $oopsUrl );
                return 0;
            }
        }
    }

    # We are allowed to edit
    Foswiki::Func::setTopicEditLock( $inWeb, $inTopic, 1 );

    return 1;
}

=begin TML

stripCommentsFromRegex($pattern) -> $pattern

For debugging: removes all spaces and comments from a regular expression.

=cut

sub stripCommentsFromRegex {
    my ($inRegex) = @_;

    ( my $cleanRegex = $inRegex ) =~ s/\s*(.*?)\s*(#.*?)*(\r|\n|$)/$1/g;
    return $cleanRegex;
}

=begin TML

StaticMethod _handleSpreadsheetFormula( $text ) -> $text

Replaces a SpreadSheetPlugin formula by a static text.

=cut

sub _handleSpreadsheetFormula {

    return if !$_[0];
    $_[0] =~
      s/$PATTERN_SPREADSHEETPLUGIN_CALC/$SPREADSHEETPLUGIN_CALC_SUBSTITUTION/g;

}

=begin TML

StaticMethod handleTmlInTables( \@lines )

Users using the plugin would be confused when they enter newlines,
which get replaced with %BR%, and thus might not render their TML

So we hack it here so that all TML and HTML tags have spaces around them:
- adds spaces around %BR% to render TML around linebreaks
- add spaces around TML next to HTML tags, again to render TML
- expands variables, for example %CALC% 
Check Foswikibug:Item1017

=cut

sub handleTmlInTables {

    # my $lines = $_[0]

    map { $_ =~ s/(%BR%)/ $1 /gx; addSpacesToTmlNextToHtml($_) } @{ $_[0] };
}

=begin TML

StaticMethod addSpacesToTmlNextToHtml( \$text )

So that:

| *bold*<br />_italic_ |

gets rendered as:

|*bold* <br /> _italic_|

=cut

sub addSpacesToTmlNextToHtml {

    # my $text = $_[0]

    # also remove spaces at both sides to prevent extra spaces are added to the
    # cell, resulting in wrong alignment (when html tags are stripped in the
    # core table renderer)

    my $TMLpattern = qr/[_*=]*/;
    my $pattern    = qr(
	[[:space:]]*		# any space
	($TMLpattern)		# i1: optional TML syntax before html tag
	(					# i2: html tag
	</*				# start of tag (optional closing tag)
	(?:$HTML_TAGS)+		# any of the html tags
	[[:space:]]*     	# any space
	.*?				    # anything before the end of tag
	/*>				# end of tag (optional closing tag)
	)					# /i2
	($TMLpattern)		# i3: optional TML syntax after html tag
	[[:space:]]*		# any space
	)x;

    $_[0] =~ s/$pattern/$1 $2 $3/g;
}

=begin TML

StaticMethod getHeaderAndFooterCount( $text ) -> ($headerRowCount, $footerRowCount)

Reads the headerrows and footerrows parameters from the TABLE macro (if any) and returns them as tuple.

If no TABLE tag is present, returns (0,0).

=cut

sub getHeaderAndFooterCount {
    my ($inTag) = @_;

    my $tag = $inTag;

    # expand macros in tagline without creating infinite recursion,
    # so delete EDITTABLE as we won't need it here
    $tag =~ s/%EDITTABLE\{/_DELETED_/;
    $tag = Foswiki::Func::expandCommonVariables($tag);

    my $headerRowCount = 0;
    my $footerRowCount = 0;

    if ( $tag =~ m/$PATTERN_TABLEPLUGIN/ ) {

        # We want this info also when viewing, because the row count takes
        # header and footer rows into account
        # match with a TablePlugin line
        # works when TABLE tag is just above OR just below the EDITTABLE tag
        my %tablePluginParams = Foswiki::Func::extractParameters($1);
        $headerRowCount = $tablePluginParams{'headerrows'} || 0;
        $footerRowCount = $tablePluginParams{'footerrows'} || 0;
    }
    return ( $headerRowCount, $footerRowCount );
}

sub _modeToString {
    my ($mode) = @_;

    my $text = '';
    $text .= "; mode is READ"           if ( $mode & $MODE->{READ} );
    $text .= "; mode is EDIT"           if ( $mode & $MODE->{EDIT} );
    $text .= "; mode is SAVE"           if ( $mode & $MODE->{SAVE} );
    $text .= "; mode is SAVEQUIET"      if ( $mode & $MODE->{SAVEQUIET} );
    $text .= "; mode is CANCEL"         if ( $mode & $MODE->{CANCEL} );
    $text .= "; mode is EDITNOTALLOWED" if ( $mode & $MODE->{EDITNOTALLOWED} );

    return $text;
}

sub _writeDebug {
    my ($inText) = @_;

    Foswiki::Func::writeDebug($inText);
}

sub _debug {
    my ($inText) = @_;

    Foswiki::Func::writeDebug($inText)
      if $Foswiki::Plugins::EditTablePlugin::debug;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2008-2009 Arthur Clemens, arthur@visiblearea.com
and Foswiki contributors
Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org and
TWiki Contributors.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
