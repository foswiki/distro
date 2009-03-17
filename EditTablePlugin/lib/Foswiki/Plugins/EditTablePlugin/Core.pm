package Foswiki::Plugins::EditTablePlugin::Core;

use strict;
use warnings;
use Assert;
use Foswiki::Func;
use CGI qw( :all );
use Foswiki::Plugins::EditTablePlugin::Data;

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
my $PATTERN_EDITCELL               = qr'%EDITCELL{(.*?)}%'o;
my $PATTERN_TABLE_ROW_FULL         = qr'^(\s*)\|.*\|\s*$'o;
my $PATTERN_TABLE_ROW              = qr'^(\s*)\|(.*)'o;
my $PATTERN_SPREADSHEETPLUGIN_CALC = qr'%CALC(?:{(.*)})?%'o;
my $MODE                           = {
    READ      => ( 1 << 1 ),
    EDIT      => ( 1 << 2 ),
    SAVE      => ( 1 << 3 ),
    SAVEQUIET => ( 1 << 4 ),
};
my %tableMatrix;
my $query;

=begin TML

Resets variables.

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

sub reinit {
    $preSp                      = '' unless $preSp;
    %params                     = () unless %params;
    @format                     = () unless @format;
    @formatExpanded             = () unless @formatExpanded;

    getPreferencesValues();
}

=begin TML

StaticMethod parseTables($text, $topic, $web)

Read and parse table data once for each topic.
Stores data in hash $tableMatrix{webname}{topicname}.
Even if we are just viewing table data (not editing), we can deal with text inside edit tables in a special way. For instance by calling handleTmlInTables on the table text.

View and edit mode act differently on the stored data:

VIEW mode: 

EDIT mode:

=cut

sub parseTables {

    # my $text = $_[0]
    # my $topic = $_[1]
    # my $web = $_[2]

    return if defined $tableMatrix{ $_[2] }{ $_[1] };

    my $query     = Foswiki::Func::getCgiQuery();
    my $tableNr   = $query->param('ettablenr');
    my $isEditing = defined $query->param('etedit')
      && defined $tableNr;

    my $tableData = Foswiki::Plugins::EditTablePlugin::Data->new();
    $_[0] = $tableData->parseText( $_[0] );

    Foswiki::Func::writeDebug(
        "EditTablePlugin::Core::parseTables - after parseText, text=$_[0]")
      if $Foswiki::Plugins::EditTablePlugin::debug;

    $tableMatrix{ $_[2] }{ $_[1] } = $tableData;
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

    if ($Foswiki::Plugins::EditTablePlugin::debug) {
        Foswiki::Func::writeDebug(
"EditTablePlugin::Core::processText( inMode=$inMode; inSaveTableNr=$inSaveTableNr; inText=$inText; inTopic=$inTopic; inWeb=$inWeb; inIncludingTopic=$inIncludingTopic; inIncludingWeb=$inIncludingWeb"
        );
        Foswiki::Func::writeDebug("\t mode is READ")
          if ( $mode & $MODE->{READ} );
        Foswiki::Func::writeDebug("\t mode is EDIT")
          if ( $mode & $MODE->{EDIT} );
        Foswiki::Func::writeDebug("\t mode is SAVE")
          if ( $mode & $MODE->{SAVE} );
    }

    my $topic = $query->param('ettabletopic') || $inTopic;
    my $web   = $query->param('ettableweb')   || $inWeb;

    my $paramTableNr = $query->param('ettablenr') || 0;
    my $tableNr      = 0;                              # current EditTable table
    my $isParamTable = 0;
    my $rowNr         = 0;    # current row number; starting at 1
    my $doEdit        = 0;
    my $allowedToEdit = 0;
    my @rows          = ();
    my $etrows        = -1
      ; # the number of content rows as passed as form parameter: only available on edit or save; -1 if not rendered
    my $etrowsParam;
    my $addedRowCount      = 0;
    my $addedRowCountParam = 0;

    my $includingTopic = $inIncludingTopic;
    my $includingWeb   = $inIncludingWeb;
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

    handleSearchResultsBelowEditTables( $topicText, $paramTableNr, $tableData );

    my $editTableObjects = $tableData->{editTableObjects};

    # ========================================
    # LOOP THROUGH TABLES
    foreach my $editTableObject ( @{$editTableObjects} ) {

        my $tableText    = $editTableObject->{'text'};
        my $editTableTag = $editTableObject->{'tagline'};

        if ($Foswiki::Plugins::EditTablePlugin::debug) {
            use Data::Dumper;
            Foswiki::Func::writeDebug(
                "EditTablePlugin::Core::processText; editTableObject="
                  . Dumper($editTableObject) );
        }

       # store processed lines of this tableText
       # the list of lines will be put back into the topic text after processing
        my @result = ();

        $tableNr++;

        # ========================================
        # HANDLE EDITTABLE TAG

        if ( $mode & $MODE->{READ} ) {

            # process the tag contents
            handleEditTableTag( $web, $topic, $editTableObject->{'params'} );

            # remove the original EDITTABLE{} in the tag pre_EDITTABLE{}_post
            # so we just have pre__post
            $editTableTag =
              $editTableObject->{'pretag'} . $editTableObject->{'posttag'};

            # expand macros in tagline without creating infinite recursion:
            $editTableTag =~ s/%EDITTABLE{/%TMP_ETP_STUB_TAG{/o;
            $editTableTag = Foswiki::Func::expandCommonVariables($editTableTag);

            # put tag back
            $editTableTag =~ s/TMP_ETP_STUB_TAG/EDITTABLE/o;
        }

        if ( ( $mode & $MODE->{READ} ) || ( $tableNr == $inSaveTableNr ) ) {

            $etrowsParam = $query->param('etrows');
            $etrows =
              ( defined $etrowsParam )
              ? $etrowsParam
              : -1;

            $addedRowCountParam = $query->param('etaddedrows') || 0;
            $addedRowCount = $addedRowCountParam;

            $isParamTable = 0;
            if (
                ( $paramTableNr == $tableNr )
                && (  $web . '.'
                    . $topic eq
"$Foswiki::Plugins::EditTablePlugin::web.$Foswiki::Plugins::EditTablePlugin::topic"
                )
              )
            {
                $isParamTable = 1;
                if ( ( $mode & $MODE->{READ} ) && $query->param('etsave') ) {

                    # [Save table] button pressed
                    $mode = $MODE->{SAVE};

                    return processText( $mode, $tableNr, $inText, $inTopic,
                        $inWeb, $inIncludingTopic, $inIncludingWeb );
                }
                elsif ( ( $mode & $MODE->{READ} ) && $query->param('etqsave') )
                {

                    # [Quiet save] button pressed
                    $mode = $MODE->{SAVE} | $MODE->{SAVEQUIET};
                    return processText( $mode, $tableNr, $inText, $inTopic,
                        $inWeb, $inIncludingTopic, $inIncludingWeb );
                }
                elsif ( $query->param('etcancel') ) {

                    # [Cancel] button pressed
                    doCancelEdit( $web, $topic );
                    return;    # in case browser does not redirect
                }
                elsif ( $query->param('etaddrow') ) {

                    # [Add row] button pressed
                    $etrows = ( $etrows == -1 ) ? 1 : $etrows + 1;
                    $addedRowCount++;
                    $allowedToEdit = doEnableEdit( $web, $topic, 0 );
                    return unless ($allowedToEdit);
                }
                elsif ( $query->param('etdelrow') ) {

                    # [Delete row] button pressed
                    if ( $etrows > 0 ) {
                        $etrows--;
                    }
                    $addedRowCount--;
                    $allowedToEdit = doEnableEdit( $web, $topic, 0 );
                    return unless ($allowedToEdit);
                }
                elsif ( $query->param('etedit') ) {

                    # [Edit table] button pressed
                    $allowedToEdit = doEnableEdit( $web, $topic, 1 );

                    # never return if locked or no permission
                    return unless ($allowedToEdit);
                }
            }
        }

        my $doEdit = $isParamTable ? 1 : 0;

        if ( !$doEdit && !( $mode & $MODE->{SAVE} ) ) {
            handleTmlInTables($tableText);
        }

        # END HANDLE EDITTABLE TAG
        # ========================================

        # ========================================
        # START FOOTER AND HEADER ROW COUNT

        my ( $headerRowCount, $footerRowCount ) =
          getHeaderAndFooterCount($editTableTag);

        if ($Foswiki::Plugins::EditTablePlugin::debug) {
            Foswiki::Func::writeDebug(
"EditTablePlugin::Core::processText; headerRowCount=$headerRowCount; footerRowCount=$footerRowCount"
            );
        }

        # END FOOTER AND HEADER ROW COUNT
        # ========================================

        # ========================================
        # START FORM
        if ( ( $mode & $MODE->{READ} ) ) {
            my $tableStart =
              handleTableStart( $web, $topic, $includingWeb, $includingTopic,
                $tableNr, $doEdit, $headerRowCount, $footerRowCount );
            push( @result, $tableStart );
        }

        # END START FORM
        # ========================================

        # ========================================
        # LOOP THROUGH LINES
        my @lines = split( /\n/, $tableText );

        for (@lines) {
            $rowNr++;

            if ( $doEdit || $doSave ) {

# when adding new rows, previously entered values will be mapped onto the new table rows
# when the last row is not the newly added, as may happen with footer rows, we need to adjust the mapping
# we introduce a 'rowNr shift' for values
# we assume that new rows are added just before the footer
                my $shift = 0;
                if ( $footerRowCount > 0 ) {
                    my $bodyRowNr = $rowNr - $headerRowCount;
                    if ( $bodyRowNr > ( $etrows - $addedRowCount ) ) {
                        $shift = $addedRowCountParam;
                    }
                }
                my $theRowNr = $rowNr + $shift;
                my $isNewRow = 0;
s/$PATTERN_TABLE_ROW/handleTableRow( $1, $2, $tableNr, $isNewRow, $theRowNr, $doEdit, $doSave, $web, $topic )/eo;
                push @rows, $_;

                next;
            }    # if ( $doEdit || $doSave )

            # just render the row: EDITCELL and format tokens
            my $isNewRow = 0;
s/$PATTERN_TABLE_ROW/handleTableRow( $1, $2, $tableNr, $isNewRow, $rowNr, $doEdit, $doSave, $web, $topic )/eo;

            push( @result, "$_\n" );

        }    # for (@lines)
             # END LOOP THROUGH LINES
             # ========================================

        if ($Foswiki::Plugins::EditTablePlugin::debug) {
            use Data::Dumper;
            Foswiki::Func::writeDebug(
                "EditTablePlugin::Core::processText; rows=" . Dumper(@rows) );
        }

        # ========================================
        # WRITE OUT PROCESSED ROWS
        my @bodyRows;
        if ( $doEdit || $doSave ) {
            my @headerRows = ();
            my @footerRows = ();
            @bodyRows = @rows;    #clone

            if ( $headerRowCount > 0 ) {
                @headerRows = @rows;    # clone
                splice @headerRows, $headerRowCount;

                # remove the header rows from the body rows
                splice @bodyRows, 0, $headerRowCount;
            }

            if ( $footerRowCount > 0 ) {
                @footerRows = @rows;    # clone
                splice @footerRows, 0, ( scalar @footerRows - $footerRowCount );

                # remove the footer rows from the body rows
                splice @bodyRows,
                  ( scalar @bodyRows - $footerRowCount ),
                  $footerRowCount;
            }

            # delete rows?
            if ( scalar @bodyRows > ( $etrows - $footerRowCount )
                && $etrows != -1 )
            {
                splice( @bodyRows, $etrows );
            }

            # no table at all?
            if ( ( $mode & $MODE->{READ} ) ) {

                # if we are starting with an empty table, we force
                # create a row, with an optional header row
                my $addHeader =
                  ( $params{'header'} && $headerRowCount == 0 )
                  ? 1
                  : 0;
                my $firstRowsCount = 1 + $addHeader;

                if ( scalar @bodyRows < $firstRowsCount
                    && !$query->param('etdelrow') )
                {
                    if ( $etrows < $firstRowsCount ) {
                        $etrows = $firstRowsCount;
                    }
                }
            }

            # add rows?
            while ( scalar @bodyRows < $etrows ) {

                $rowNr++;
                my $newBodyRowNr = scalar @bodyRows + 1;
                my $theRowNr     = $newBodyRowNr + $headerRowCount;

                my $isNewRow =
                  ( defined $etrowsParam && $newBodyRowNr > $etrowsParam )
                  ? 1
                  : 0;

                my $newRow = handleTableRow(
                    '',        '',      $tableNr, $isNewRow,
                    $theRowNr, $doEdit, $doSave,  $web,
                    $topic
                );
                push @bodyRows, $newRow;
            }

            if ($Foswiki::Plugins::EditTablePlugin::debug) {
                use Data::Dumper;
                Foswiki::Func::writeDebug(
                    "EditTablePlugin::Core::processText; headerRows="
                      . Dumper(@headerRows) );
                Foswiki::Func::writeDebug(
                    "EditTablePlugin::Core::processText; bodyRows="
                      . Dumper(@bodyRows) );
                Foswiki::Func::writeDebug(
                    "EditTablePlugin::Core::processText; footerRows="
                      . Dumper(@footerRows) );
            }

            my @combinedRows = ( @headerRows, @bodyRows, @footerRows );

            # after re-ordering, renumber the cells
            my $rowCounter = 0;
            for my $cellRow (@combinedRows) {
                $rowCounter++;
                $cellRow =~ s/(etcell)([0-9]+)(x)([0-9]+)/$1$rowCounter$3$4/go;
            }
            push( @result, join( "\n", @combinedRows ) );
            if ( $doEdit && ( $mode & $MODE->{READ} ) ) {
                push( @result, "\n" );    # somewhere is a newline too few
            }
        }

        # END WRITE OUT PROCESSED ROWS
        # ========================================

        # ========================================
        # START PUT PROCESSED TABLE BACK IN TEXT
        my $resultText = join( "", @result );

        my $searchResultsText = $editTableObject->{'searchResults'} || '';
        $resultText .= $searchResultsText;

        $resultText = "$editTableTag\n$resultText";

        Foswiki::Func::writeDebug(
"EditTablePlugin::Core::processText - after processing, resultText before expandCommonVariables:$resultText"
        ) if $Foswiki::Plugins::EditTablePlugin::debug;

        # ========================================
        # FORM END
        my $rowCount = 0;
        if ( ( $mode & $MODE->{READ} ) && !$doEdit ) {
            $rowCount = $rowNr - $headerRowCount - $footerRowCount;
        }
        if ($doEdit) {
            $rowCount = scalar @bodyRows;
        }
        if ( ( $mode & $MODE->{READ} ) ) {
            my $tableEnd = handleTableEnd(
                $web,            $topic,          $includingWeb,
                $includingTopic, $rowCount,       $doEdit,
                $headerRowCount, $footerRowCount, $addedRowCount
            );
            $resultText .= $tableEnd;
        }

        # END FORM END
        # ========================================

        # button row at top or bottom
        if ( ( $mode & $MODE->{READ} ) ) {
            my $pos = $params{'buttonrow'} || 'bottom';
            my $buttonRow =
              createButtonRow( $web, $topic, $includingWeb, $includingTopic,
                $doEdit );
            if ( $pos eq 'top' ) {
                $resultText =~ s/$PLACEHOLDER_BUTTONROW_BOTTOM//go;    # remove
                $resultText =~ s/$PLACEHOLDER_BUTTONROW_TOP/$buttonRow/go;
            }
            else {
                $resultText =~ s/$PLACEHOLDER_BUTTONROW_TOP//go;       # remove
                $resultText =~ s/$PLACEHOLDER_BUTTONROW_BOTTOM/$buttonRow/go;
            }
        }

        # render variables (only in view mode)
        $resultText = Foswiki::Func::expandCommonVariables($resultText)
          if ( !$doEdit && ( $mode & $MODE->{READ} ) );
        $topicText =~ s/<!--%EDITTABLESTUB\{$tableNr\}%-->/$resultText/;

        # END PUT PROCESSED TABLE BACK IN TEXT
        # ========================================

        # ========================================
        # START RE-INIT VALUES
        $rowNr          = 0;
        $etrows         = -1;
        @rows           = ();
        @result         = ();
        $isParamTable   = 0;
        $headerRowCount = 0;
        $footerRowCount = 0;

        # END RE-INIT VALUES
        # ========================================

    }    # foreach my $tableText (@editTableObjects) {

    if ($doSave) {
        my $error =
          Foswiki::Func::saveTopic( $web, $topic, $meta, $topicText,
            { dontlog => ( $mode & $MODE->{SAVEQUIET} ) } );

        Foswiki::Func::setTopicEditLock( $web, $topic, 0 );    # unlock Topic
        my $url = Foswiki::Func::getViewUrl( $web, $topic );
        if ($error) {
            $url =
              Foswiki::Func::getOopsUrl( $web, $topic, 'oopssaveerr', $error );
        }
        Foswiki::Func::redirectCgiQuery( $query, $url );
        return;
    }

    # update the text
    $_[2] = $topicText;
}

=begin TML

=cut

sub getPreferencesValues {

    my $pluginName = $Foswiki::Plugins::EditTablePlugin::pluginName;

    $prefCHANGEROWS =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_CHANGEROWS") || 'on';

    $prefQUIETSAVE =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_QUIETSAVE") || 'on';

    $prefEDIT_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_EDIT_BUTTON")
      || 'Edit table';

    $prefSAVE_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_SAVE_BUTTON")
      || 'Save table';

    $prefQUIET_SAVE_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_QUIET_SAVE_BUTTON")
      || 'Quiet save';

    $prefADD_ROW_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_ADD_ROW_BUTTON")
      || 'Add row';

    $prefDELETE_LAST_ROW_BUTTON = Foswiki::Func::getPreferencesValue(
        "\U$pluginName\E_DELETE_LAST_ROW_BUTTON")
      || 'Delete last row';
    $prefCANCEL_BUTTON =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_CANCEL_BUTTON")
      || 'Cancel';
    $prefMESSAGE_INCLUDED_TOPIC_DOES_NOT_EXIST =
      Foswiki::Func::getPreferencesValue(
        "\U$pluginName\E_INCLUDED_TOPIC_DOES_NOT_EXIST")
      || 'Warning: \'include\' topic does not exist!';
}

=begin TML

=cut

sub extractParams {
    my ( $theArgs, $theHashRef ) = @_;

    my $tmp;

    $tmp = Foswiki::Func::extractNameValuePair( $theArgs, 'header' );
    $$theHashRef{'header'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $theArgs, 'footer' );
    $$theHashRef{'footer'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $theArgs, 'headerislabel' );
    $$theHashRef{'headerislabel'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $theArgs, 'format' );
    $tmp =~ s/^\s*\|*\s*//o;
    $tmp =~ s/\s*\|*\s*$//o;
    $$theHashRef{'format'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $theArgs, 'changerows' );
    $$theHashRef{'changerows'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $theArgs, 'quietsave' );
    $$theHashRef{'quietsave'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $theArgs, 'helptopic' );
    $$theHashRef{'helptopic'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $theArgs, 'editbutton' );
    $$theHashRef{'editbutton'} = $tmp if ($tmp);

    $tmp =
      Foswiki::Func::extractNameValuePair( $theArgs, 'javascriptinterface' );
    $$theHashRef{'javascriptinterface'} = $tmp if ($tmp);

    $tmp = Foswiki::Func::extractNameValuePair( $theArgs, 'buttonrow' );
    $$theHashRef{'buttonrow'} = $tmp if ($tmp);

    return;
}

=begin TML

=cut

sub parseFormat {
    my ( $theFormat, $inTopic, $inWeb, $doExpand ) = @_;

    $theFormat =~ s/\$nop(\(\))?//gos;         # remove filler
    $theFormat =~ s/\$quot(\(\))?/\"/gos;      # expand double quote
    $theFormat =~ s/\$percnt(\(\))?/\%/gos;    # expand percent
    $theFormat =~ s/\$dollar(\(\))?/\$/gos;    # expand dollar

    if ($doExpand) {

        # expanded form to be able to use %-vars in format
        $theFormat =~ s/<nop>//gos;
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
    my ( $inWeb, $inTopic, $theArgs ) = @_;

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
    my $iTopic = Foswiki::Func::extractNameValuePair( $theArgs, 'include' );
    my $iTopicExists = 0;
    if ($iTopic) {
        if ( $iTopic =~ /^([^\.]+)\.(.*)$/o ) {
            $inWeb  = $1;
            $iTopic = $2;
        }

        $iTopicExists = Foswiki::Func::topicExists( $inWeb, $iTopic )
          if $iTopic ne '';
        if ( $iTopic && !$iTopicExists ) {
            $warningMessage = $prefMESSAGE_INCLUDED_TOPIC_DOES_NOT_EXIST;
        }
        if ($iTopicExists) {

            my $text = Foswiki::Func::readTopicText( $inWeb, $iTopic );
            $text =~ /$PATTERN_EDITTABLEPLUGIN/os;
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
    $theArgs =
      Foswiki::Func::expandCommonVariables( $theArgs, $inTopic, $inWeb );

    extractParams( $theArgs, \%params );

    # FIXME: should use Foswiki::Func::extractParameters
    $params{'header'} = '' if ( $params{header} =~ /^(off|no)$/oi );
    $params{'header'} =~ s/^\s*\|//o;
    $params{'header'} =~ s/\|\s*$//o;
    $params{'headerislabel'} = ''
      if ( $params{headerislabel} =~ /^(off|no)$/oi );
    $params{'footer'} = '' if ( $params{footer} =~ /^(off|no)$/oi );
    $params{'footer'} =~ s/^\s*\|//o;
    $params{'footer'} =~ s/\|\s*$//o;

    $params{'changerows'} = '' if ( $params{changerows} =~ /^(off|no)$/oi );
    $params{'quietsave'}  = '' if ( $params{quietsave}  =~ /^(off|no)$/oi );
    $params{'javascriptinterface'} = 'off'
      if ( $params{javascriptinterface} =~ /^(off|no)$/oi );

    @format         = parseFormat( $params{format}, $inTopic, $inWeb, 0 );
    @formatExpanded = parseFormat( $params{format}, $inTopic, $inWeb, 1 );
    $nrCols         = scalar @format;
}

=begin TML

=cut

sub handleTableStart {
    my ( $inWeb, $inTopic, $includingWeb, $includingTopic, $theTableNr, $doEdit,
        $headerRowCount, $footerRowCount )
      = @_;

    my $viewUrl = Foswiki::Func::getScriptUrl( $inWeb, $inTopic, 'viewauth' )
      . "\#edittable$theTableNr";
    my $text = '';
    if ($doEdit) {
        require Foswiki::Contrib::JSCalendarContrib;
        unless ($@) {
            Foswiki::Contrib::JSCalendarContrib::addHEAD('foswiki');
        }
    }
    $text .= "$preSp<noautolink>\n" if $doEdit;
    $text .= "$preSp<a name=\"edittable$theTableNr\"></a>\n"
      if ( "$inWeb.$inTopic" eq "$includingWeb.$includingTopic" );
    my $cssClass = 'editTable';
    if ($doEdit) {
        $cssClass .= ' editTableEdit';
    }
    $text .= "<div class=\"" . $cssClass . "\">\n";
    my $formName = "edittable$theTableNr";
    $formName .= "\_$includingWeb\_$includingTopic"
      if ( "$inWeb\_$inTopic" ne "$includingWeb\_$includingTopic" );
    $text .=
      "$preSp<form name=\"$formName\" action=\"$viewUrl\" method=\"post\">\n";

    $text .= $PLACEHOLDER_BUTTONROW_TOP;

    $text .= hiddenField( $preSp, 'ettablenr', $theTableNr, "\n" );
    $text .= hiddenField( $preSp, 'etedit',    'on',        "\n" )
      unless $doEdit;

    # pass to javascript (through META tag vars) how many header rows
    # and footer rows we have
    &Foswiki::Plugins::EditTablePlugin::addHeaderAndFooterCountToHead(
        $headerRowCount, $footerRowCount )
      if ( $doEdit
        && ( "$inWeb.$inTopic" eq "$includingWeb.$includingTopic" ) );

    return $text;
}

=begin TML

=cut

sub hiddenField {
    my ( $prefix, $name, $value, $suffix ) = @_;

    $prefix ||= '';
    $suffix ||= '';

    # Somehow this does not work at all:
    # return $prefix
    #   . CGI::hidden(
    #     -name  => $name,
    #     -value => $value
    #   ) . $suffix;

    return
      "$prefix<input type=\"hidden\" name=\"$name\" value=\"$value\" />$suffix";
}

=begin TML

=cut

sub handleTableEnd {
    my (
        $inWeb,          $inTopic,        $includingWeb,
        $includingTopic, $rowCount,       $doEdit,
        $headerRowCount, $footerRowCount, $addedRowCount
    ) = @_;
    my $text = '';
    $text .= hiddenField( $preSp, 'etrows',      $rowCount,      "\n" );
    $text .= hiddenField( $preSp, 'etaddedrows', $addedRowCount, "\n" )
      if $addedRowCount;

    $text .= $PLACEHOLDER_BUTTONROW_BOTTOM;

    $text .= "$preSp</form>\n";
    $text .= "</div><!-- /editTable -->";
    $text .= "</noautolink>" if $doEdit;

    return $text;
}

=begin TML

=cut

sub createButtonRow {
    my ( $inWeb, $inTopic, $includingWeb, $includingTopic, $doEdit ) = @_;

    my $text = '';
    if ( $doEdit && ( "$inWeb.$inTopic" eq "$includingWeb.$includingTopic" ) ) {

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
              unless ( $params{'changerows'} =~ /^add$/oi );
        }
        $text .=
"$preSp<input type=\"submit\" name=\"etcancel\" id=\"etcancel\" value=\"$prefCANCEL_BUTTON\" class=\"foswikiButtonCancel\" />\n";

        if ( $params{'helptopic'} ) {

            # read help topic and show below the table
            if ( $params{'helptopic'} =~ /^([^\.]+)\.(.*)$/o ) {
                $inWeb = $1;
                $params{'helptopic'} = $2;
            }
            my $helpText =
              Foswiki::Func::readTopicText( $inWeb, $params{'helptopic'} );

            #Strip out the meta data so it won't be displayed.
            $helpText =~ s/%META:[A-Za-z0-9]+{.*?}%//g;
            if ($helpText) {
                $helpText =~ s/.*?%STARTINCLUDE%//os;
                $helpText =~ s/%STOPINCLUDE%.*//os;
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
    my ($theAttr) = @_;
    $theAttr = Foswiki::Func::extractNameValuePair($theAttr);
    return '' unless ( $theAttr =~ /^editbutton/ );

    $params{editbutton} = 'hide'
      unless ( $params{editbutton} );    # Hide below table edit button

    my @bits = split( /,\s*/, $theAttr );
    my $value = '';
    $value = $bits[2] if ( @bits > 2 );
    my $img = '';
    $img = $bits[3] if ( @bits > 3 );

    unless ($value) {
        $value = $prefEDIT_BUTTON || '';
        $img = '';
        if ( $value =~ s/(.+),\s*(.+)/$1/o ) {
            $img = $2;
            $img =~ s|%ATTACHURL%|%PUBURL%/%SYSTEMWEB%/EditTablePlugin|o;
            $img =~ s|%WEB%|%SYSTEMWEB%|o;
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
    my ( $theTableNr, $theRowNr, $theCol, $theName, $theValue,
        $digestedCellValue, $inWeb, $inTopic )
      = @_;

    my $rawValue = $theValue;
    my $text     = '';
    my $i        = @format - 1;
    $i = $theCol if ( $theCol < $i );

    my @bits         = split( /,\s*/, $format[$i] );
    my @bitsExpanded = split( /,\s*/, $formatExpanded[$i] );

    my $cellFormat = '';
    $theValue =~
      s/\s*$PATTERN_EDITCELL/&parseEditCellFormat( $1, $cellFormat )/eo;

    # If cell is empty we remove the space to not annoy the user when
    # he needs to add text to empty cell.
    $theValue = '' if ( $theValue eq ' ' );

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
      if ( ( $params{'headerislabel'} ) && ( $theValue =~ /^\s*\*.*\*\s*$/ ) );
    $type = 'label' if ( $type eq 'editbutton' );    # Hide [Edit table] button
    my $size = 0;
    $size = $bits[1] if @bits > 1;
    my $val         = '';
    my $valExpanded = '';
    my $sel         = '';

    if ( $type eq 'select' ) {
        my $expandedValue =
          Foswiki::Func::expandCommonVariables( $theValue, $inTopic, $inWeb );
        $size = 1 if $size < 1;
        $text =
          "<select class=\"foswikiSelect\" name=\"$theName\" size=\"$size\">";
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
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq "radio" ) {
        my $expandedValue =
          &Foswiki::Func::expandCommonVariables( $theValue, $inTopic, $inWeb );
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
            $text .= "<input type=\"radio\" name=\"$theName\" value=\"$val\"";

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
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq "checkbox" ) {
        my $expandedValue =
          &Foswiki::Func::expandCommonVariables( $theValue, $inTopic, $inWeb );
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
            $names .= " ${theName}x$i";
            $text .=
              " <input type=\"checkbox\" name=\"${theName}x$i\" value=\"$val\"";

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
        $text .= hiddenField( $preSp, $theName, $names );
        $text .= saveEditCellFormat( $cellFormat, $theName, "\n" );

    }
    elsif ( $type eq 'row' ) {
        $size = $size + $theRowNr;
        $text =
            "<span class=\"et_rowlabel\">"
          . hiddenField( $size, $theName, $size )
          . "</span>";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq 'label' ) {

        # show label text as is, and add a hidden field with value
        my $isHeader = 0;
        $isHeader = 1 if ( $theValue =~ s/^\s*\*(.*)\*\s*$/$1/o );
        $text = $theValue;

#        $text =~ s/($PATTERN_SPREADSHEETPLUGIN_CALC)/handleSpreadsheetFormula($1)/geox;

        # To optimize things, only in the case where a read-only column is
        # being processed (inside of this unless() statement) do we actually
        # go out and read the original topic.  Thus the reason for the
        # following unless() so we only read the topic the first time through.

        unless ( defined $tableMatrix{$inWeb}{$inTopic} and $digestedCellValue )
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
            $digestedCellValue
          ? $table->getCell( $theTableNr, $theRowNr - 1, $theCol )
          : $rawValue;
        $theValue = $cell if ( defined $cell );    # original value from file
        Foswiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );

        #$theValue = "\*$theValue\*" if ( $isHeader and $digestedCellValue );
        $text = "\*$text\*" if $isHeader;
        $text .= ' ' . hiddenField( $preSp, $theName, $theValue );
    }
    elsif ( $type eq 'textarea' ) {
        my ( $rows, $cols ) = split( /x/, $size );

        $rows |= 3  if !defined $rows;
        $cols |= 30 if !defined $cols;
        Foswiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $text .=
"<textarea class=\"foswikiTextarea editTableTextarea\" rows=\"$rows\" cols=\"$cols\" name=\"$theName\">$theValue</textarea>";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq 'date' ) {
        my $ifFormat = '';
        $ifFormat = $bits[3] if ( @bits > 3 );
        $ifFormat ||= $Foswiki::cfg{JSCalendarContrib}{format} || '%e %B %Y';
        $size = 10 if ( !$size || $size < 1 );
        Foswiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $text .= CGI::textfield(
            {
                name     => $theName,
                class    => 'foswikiInputField editTableInput',
                id       => 'id' . $theName,
                size     => $size,
                value    => $theValue,
                override => 1
            }
        );
        $text .= saveEditCellFormat( $cellFormat, $theName );
        eval 'use Foswiki::Contrib::JSCalendarContrib';

        unless ($@) {
            $text .= '<span class="foswikiMakeVisible">';
            $text .= CGI::image_button(
                -class   => 'editTableCalendarButton',
                -name    => 'calendar',
                -onclick => "return showCalendar('id$theName','$ifFormat')",
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
        Foswiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $text =
"<input class=\"foswikiInputField editTableInput\" type=\"text\" name=\"$theName\" size=\"$size\" value=\"$theValue\" />";
        $text .= saveEditCellFormat( $cellFormat, $theName );
    }

    if ( $type ne 'textarea' ) {
        $text =~
          s/&#10;/<br \/>/go;    # change unicode linebreak character to <br />
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

    if ($Foswiki::Plugins::EditTablePlugin::debug) {
        Foswiki::Func::writeDebug(
                "EditTablePlugin::Core::handleTableRow; params="
              . "\n\t thePre=$thePre"
              . "\n\t theRow=$theRow"
              . "\n\t theTableNr=$theTableNr"
              . "\n\t isNewRow=$isNewRow"
              . "\n\t theRowNr=$theRowNr"
              . "\n\t doEdit=$doEdit"
              . "\n\t doSave=$doSave"
              . "\n\t inWeb=$inWeb"
              . "\n\t inTopic=$inTopic" );
    }

    $thePre |= '';
    my $text = "$thePre\|";

    if ($doEdit) {
        $theRow =~ s/\|\s*$//o;

        # retrieve any params sent by javascript interface (see edittable.js)
        my $rowID = $query->param("etrow_id$theRowNr");
        $rowID = $theRowNr if !defined $rowID;

        if ($Foswiki::Plugins::EditTablePlugin::debug) {
            Foswiki::Func::writeDebug( "\t query->param(etrow_id$theRowNr)="
                  . $query->param("etrow_id$theRowNr")
                  . ";rowID=$rowID" );
        }

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
            $val = $isNewRow ? undef : $query->param("etcell${rowID}x$col");

            if ($Foswiki::Plugins::EditTablePlugin::debug) {
                Foswiki::Func::writeDebug(
                    "\t rowID=$rowID; isNewRow=$isNewRow; val=$val");
            }

            if ( $val && $val =~ /^Chkbx: (etcell.*)/ ) {

      # Multiple checkboxes, val has format "Chkbx: etcell4x2x2 etcell4x2x3 ..."
                my $chkBoxeNames = $1;
                my $chkBoxVals   = "";
                foreach ( split( /\s/, $chkBoxeNames ) ) {
                    $val = $query->param($_);

                    #$chkBoxVals .= "$val," if ( defined $val );
                    if ( defined $val ) {

                        # make space to expand variables
                        $val = addSpaceToBothSides($val);
                        $chkBoxVals .= $val . ',';
                    }
                }
                $chkBoxVals =~ s/,\s*$//;
                $val = $chkBoxVals;
            }
            $cellFormat = $query->param("etformat${rowID}x$col");
            $val .= " %EDITCELL{$cellFormat}%" if ($cellFormat);
            if ( defined $val ) {

                # change any new line character sequences to <br />
                $val =~ s/[\n\r]{2,}?/<br \/>/gos;

                # escape "|" to HTML entity
                $val =~ s/\|/\&\#124;/gos;
                $cellDefined = 1;

                # Expand %-vars
                $cell = $val;
            }
            elsif ( $col <= @cells ) {
                $cell = $cells[ $col - 1 ];
                $digested = 1;    # Flag that we are using non-raw cell text.
                $cellDefined = 1 if ( length($cell) > 0 );
                $cell =~ s/^\s*(.+?)\s*$/$1/o
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
                    $val  = $1;    # type
                    $cell = $3;
                    $cell = ''
                      unless ( defined $cell && $cell ne '' )
                      ;            # Proper handling of '0'
                    $cell =~ s/\,.*$//o
                      if ( $val eq 'select' || $val eq 'date' );
                }
                my $element = '';
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
        $theRow =~ s/$PATTERN_EDITCELL/viewEditCell($1)/geo if !$doSave;
        $text .= $theRow;
    }    # /if ($doEdit)

    # render final value in view mode (not edit or save)
    Foswiki::Plugins::EditTablePlugin::decodeFormatTokens($text)
      if ( !$doSave && !$doEdit );

    if ($Foswiki::Plugins::EditTablePlugin::debug) {
        Foswiki::Func::writeDebug(
            "EditTablePlugin::Core::handleTableRow; return text=$text");
    }

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

    Foswiki::Func::writeDebug(
        "EditTablePlugin::Core::doCancelEdit( $inWeb, $inTopic )")
      if $Foswiki::Plugins::EditTablePlugin::debug;

    Foswiki::Func::setTopicEditLock( $inWeb, $inTopic, 0 );

    Foswiki::Func::redirectCgiQuery( $query,
        Foswiki::Func::getViewUrl( $inWeb, $inTopic ) );
}

=begin TML

=cut

sub doEnableEdit {
    my ( $inWeb, $inTopic, $doCheckIfLocked ) = @_;

    Foswiki::Func::writeDebug(
        "EditTablePlugin::Core::doEnableEdit( $inWeb, $inTopic )")
      if $Foswiki::Plugins::EditTablePlugin::debug;

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

    ( my $cleanRegex = $inRegex ) =~ s/\s*(.*?)\s*(#.*?)*(\r|\n|$)/$1/go;
    return $cleanRegex;
}

=begin TML

StaticMethod _handleSpreadsheetFormula( $text ) -> $htmlTextfield

Puts a SpreadSheetPlugin formula inside a read-only textfield to limit the screen size and keep it visible.
Should be done only for label fields because the text is otherwise not editable.

=cut

# unused until bug free

sub handleSpreadsheetFormula {
    my ($inFormula) = @_;

    my $textfield = CGI::textfield(
        {
            class    => 'foswikiInputFieldReadOnly',
            size     => 12,
            value    => $inFormula,
            readonly => 'readonly',
            style    => 'font-weight:bold;',
        }
    );
    return $textfield;
}

=begin TML

StaticMethod handleTmlInTables( $text )

Users using the plugin would be confused when they enter newlines,
which get replaced with %BR%, and thus might not render their TML

So we hack it here so that all TML and HTML tags have spaces around them:
- adds spaces around %BR% to render TML around linebreaks
- add spaces around TML next to HTML tags, again to render TML
- expands variables, for example %CALC% 
Check Foswikibug:Item1017

=cut

sub handleTmlInTables {

    # my $text = $_[0]

    # add spaces around %BR%
    $_[0] =~ s/(%BR%)/ $1 /gox;

    # add spaces around TML next to HTML
    addSpacesToTmlNextToHtml( $_[0] );
}

=begin TML

Handles search results that is formatted as table below an EDITTABLE tag.

For instance:

%EDITTABLE{}%
| *Project* | *Assignee* | *Launch Date* |
%SEARCH{search="test" topic="*" format="| $formfield(name) | $formfield(author) | $formfield(date) |" nonoise="on" limit="5"}%

=cut

sub handleSearchResultsBelowEditTables {

    # my $text = $_[0]
    # my $editTableNr = $_[1]
    # my $tableData = $_[2]

    $_[0] =~
s/(<!--%EDITTABLESTUB{([0-9]+)}%-->\s+)((\s*)\|.*\|)\s+/addSearchResultsTableTextToTableObject($_[2], $_[1], $1, $2, $3)/geos;
}

sub addSearchResultsTableTextToTableObject {
    my ( $inTableData, $inEditTableNr, $inTag, $inTableNumber, $inTableText ) =
      @_;

    # do not offer expanded table in edit mode
    return "$inTag$inTableText\n" if ( $inEditTableNr == $inTableNumber );

    $inTableData->{editTableObjects}->[ $inTableNumber - 1 ]->{searchResults} =
      "$inTableText\n";

    return $inTag;
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

    my $TMLpattern = qr/[_*=]*/o;
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
	)ox;

    $_[0] =~ s/$pattern/$1 $2 $3/go;
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
    $tag =~ s/%EDITTABLE{/_DELETED_/o;
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
