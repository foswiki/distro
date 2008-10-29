# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
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

package TWiki::Plugins::EditTablePlugin::Core;

use strict;
use Assert;

use vars qw(
  $preSp %params @format @formatExpanded
  $prefsInitialized $prefCHANGEROWS $prefEDIT_BUTTON $prefSAVE_BUTTON $prefQUIET_SAVE_BUTTON
  $prefADD_ROW_BUTTON $prefDELETE_LAST_ROW_BUTTON $prefCANCEL_BUTTON
  $prefMESSAGE_INCLUDED_TOPIC_DOES_NOT_EXIST $prefQUIETSAVE
  $nrCols $encodeStart $encodeEnd $table $query %regex
  $warningMessage
);

my $RENDER_HACK        = "\n<nop>\n";
my $DEFAULT_FIELD_SIZE = 16;

BEGIN {
    %regex                    = ();
    $regex{edit_table_plugin} = '%EDITTABLE{(.*?)}%';
    $regex{table_plugin}      = '%TABLE(?:{(.*?)})?%';
    $regex{table_row_full}    = '^(\s*)\|.*\|\s*$';
    $regex{table_row}         = '^(\s*)\|(.*)';
}

sub init {
    $preSp                      = '';
    %params                     = ();
    @format                     = ();
    @formatExpanded             = ();
    $prefsInitialized           = undef;
    $prefCHANGEROWS             = undef;
    $prefEDIT_BUTTON            = undef;
    $prefSAVE_BUTTON            = undef;
    $prefQUIET_SAVE_BUTTON      = undef;
    $prefADD_ROW_BUTTON         = undef;
    $prefDELETE_LAST_ROW_BUTTON = undef;
    $prefDELETE_LAST_ROW_BUTTON = undef;
    $prefQUIETSAVE              = undef;
    $nrCols                     = undef;
    $encodeStart                = undef;
    $encodeEnd                  = undef;
    $table                      = undef;
    $query                      = undef;
    $warningMessage             = '';
}

sub preProcessSpreadsheetPluginTags {
    $query = TWiki::Func::getCgiQuery();
    if ( ( $query->param('etedit') ) && ( $query->param('ettablenr') ) ) {
        my $paramTableNr = $query->param('ettablenr');
        my $tmptable     = TWiki::Plugins::EditTable->new();
        my ( $tablesTakenOutText, @tableTextRefs ) =
          $tmptable->parseText( $_[0] );
        my $tableNr   = 1;
        my $tableDone = 0;
        foreach my $tableTextRef (@tableTextRefs) {
            my $tableText    = $tableTextRef->{'text'};
            my $editTableTag = $tableTextRef->{'tag'};
            if ( !$tableDone && $tableNr eq $paramTableNr ) {

                # escape variables
                $tableText =~ s/%(.*?\{*.*?\}*)%/%E_T_P_NOP$1%/go;
                $tableText =~ s/%E_T_P_NOPBR%/&#10;/go;
                $tableDone = 1;
            }
            $tableText = $editTableTag . "\n" . $tableText;
            $tablesTakenOutText =~ s/<!--edittable$tableNr-->/$tableText\n/;
            $tableNr++;
        }
        $_[0] = $tablesTakenOutText;
    }
}

=pod

---+++ process( $doSave, $saveTableNr, $doSaveQuiet, $text, $topic, $web )

Called from commonTagsHandler. Pass over to processText in 'no Save' mode.

=cut

sub process {
    init();
    my $saveMode      = $TWiki::Plugins::EditTablePlugin::saveMode{'NONE'};
    my $saveTableNr   = 0;
    my $saveQuietMode = $TWiki::Plugins::EditTablePlugin::saveMode{'SAVEQUIET'};
    processText( $saveMode, $saveTableNr, $saveQuietMode, @_ );
}

=pod

---+++ processText( $doSave, $saveTableNr, $doSaveQuiet, $text, $topic, $web )

Process the text line by line.
When a EditTablePlugin table is encountered, its contents is rendered according to the view: 
   * View mode - default
   * Edit mode - when an Edit button is clicked, renders the rest of the table in edit mode
   * Save mode - when called from a Save button: calls processText again, only renders the selected table number, then saves the topic text

=cut

sub processText {

    my $doSave = ( shift == $TWiki::Plugins::EditTablePlugin::saveMode{'SAVE'} )
      || 0;
    my $saveTableNr = shift;
    my $doSaveQuiet =
      ( shift == $TWiki::Plugins::EditTablePlugin::saveMode{'SAVEQUIET'} ) || 0;

    $query = TWiki::Func::getCgiQuery();

    TWiki::Func::writeDebug(
        "- EditTablePlugin::commonTagsHandler( $_[2].$_[1] )")
      if $TWiki::Plugins::EditTablePlugin::debug;

    unless ($prefsInitialized) {
        $prefCHANGEROWS =
             TWiki::Func::getPreferencesValue('CHANGEROWS')
          || TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_CHANGEROWS')
          || 'on';
        $prefQUIETSAVE =
             TWiki::Func::getPreferencesValue('QUIETSAVE')
          || TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_QUIETSAVE')
          || 'on';
        $prefEDIT_BUTTON =
             TWiki::Func::getPreferencesValue('EDIT_BUTTON')
          || TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_EDIT_BUTTON')
          || 'Edit table';
        $prefSAVE_BUTTON =
             TWiki::Func::getPreferencesValue('SAVE_BUTTON')
          || TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_SAVE_BUTTON')
          || 'Save table';
        $prefQUIET_SAVE_BUTTON =
          TWiki::Func::getPreferencesValue('QUIET_SAVE_BUTTON')
          || TWiki::Func::getPreferencesValue(
            'EDITTABLEPLUGIN_QUIET_SAVE_BUTTON')
          || 'Quiet save';
        $prefADD_ROW_BUTTON =
             TWiki::Func::getPreferencesValue('ADD_ROW_BUTTON')
          || TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_ADD_ROW_BUTTON')
          || 'Add row';
        $prefDELETE_LAST_ROW_BUTTON =
          TWiki::Func::getPreferencesValue('DELETE_LAST_ROW_BUTTON')
          || TWiki::Func::getPreferencesValue(
            'EDITTABLEPLUGIN_DELETE_LAST_ROW_BUTTON')
          || 'Delete last row';
        $prefCANCEL_BUTTON =
             TWiki::Func::getPreferencesValue('CANCEL_BUTTON')
          || TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_CANCEL_BUTTON')
          || 'Cancel';
        $prefMESSAGE_INCLUDED_TOPIC_DOES_NOT_EXIST =
          TWiki::Func::getPreferencesValue('INCLUDED_TOPIC_DOES_NOT_EXIST')
          || TWiki::Func::getPreferencesValue(
            'EDITTABLEPLUGIN_INCLUDED_TOPIC_DOES_NOT_EXIST')
          || 'Warning: \'include\' topic does not exist!';

        $prefsInitialized = 1;
    }

    my $theTopic = $query->param('ettabletopic') || $_[1];
    my $theWeb   = $query->param('ettableweb')   || $_[2];

    my $paramTableNr = 0;
    my $tableNr      = 0;    # current EditTable table
    my $isParamTable = 0;
    my $rowNr        = 0;    # current row number; starting at 1
    my $doEdit       = 0;    #$doSave;
    my @rows         = ();
    my $etrows       = -1
      ; # the number of content rows as passed as form parameter: only available on edit or save; -1 if not rendered
    my $etrowsParam;
    my $addedRowCount      = 0;
    my $addedRowCountParam = 0;
    my $headerRowCount     = 0;
    my $footerRowCount     = 0;

    # performance: do nothing in view mode if the table is included
    my $webTopic       = $theWeb . '.' . $theTopic;
    my $includingTopic = $_[3];
    my $includingWeb   = $_[4];

    my $topicText;
    my $meta;
    my $tablesTakenOutText;
    my @tableTextRefs;
    if ($doSave) {
        ( $meta, $topicText ) = TWiki::Func::readTopic( $theWeb, $theTopic );
        $table = TWiki::Plugins::EditTable->new();
        ( $tablesTakenOutText, @tableTextRefs ) = $table->parseText($topicText);
    }
    else {
        $topicText = $_[0];
        if ( !defined $table ) {
            $table = TWiki::Plugins::EditTable->new();
            ( $tablesTakenOutText, @tableTextRefs ) =
              $table->parseText($topicText);
        }
    }

    # ========================================
    # LOOP THROUGH EXISTING TABLES
    foreach my $tableTextRef (@tableTextRefs) {

        my $tableText    = $tableTextRef->{'text'};
        my $editTableTag = $tableTextRef->{'tag'};

        # store processed lines of this tableText
        my @result = ();

        $tableNr++;

        # ========================================
        # HANDLE EDITTABLE TAG

        if ( !$doSave ) {

            # process the tag contents
            my $editTablePluginRE = "(.*?)$regex{edit_table_plugin}";
            $editTableTag =~
s/$editTablePluginRE/&handleEditTableTag( $theWeb, $theTopic, $1, $2 )/geo;
        }

        if ( $doSave && ( $tableNr != $saveTableNr ) ) {

            # nothing (TODO: rewrite this condition...)
        }
        else {

            $paramTableNr = $query->param('ettablenr')
              || 0;    # only on save and edit
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
                && (  $theWeb . '.'
                    . $theTopic eq
"$TWiki::Plugins::EditTablePlugin::web.$TWiki::Plugins::EditTablePlugin::topic"
                )
              )
            {
                $isParamTable = 1;
                if ( !$doSave && $query->param('etsave') ) {

                    # [Save table] button pressed
                    my $theSaveMode =
                      $TWiki::Plugins::EditTablePlugin::saveMode{'SAVE'};
                    my $theSaveQuietMode =
                      $TWiki::Plugins::EditTablePlugin::saveMode{'NONE'};

                    return processText( $theSaveMode, $tableNr,
                        $theSaveQuietMode, @_ );
                }
                elsif ( !$doSave && $query->param('etqsave') ) {

                    # [Quiet save] button pressed
                    my $theSaveMode =
                      $TWiki::Plugins::EditTablePlugin::saveMode{'SAVE'};
                    my $theSaveQuietMode =
                      $TWiki::Plugins::EditTablePlugin::saveMode{'SAVEQUIET'};
                    return processText( $theSaveMode, $tableNr,
                        $theSaveQuietMode, @_ );
                }
                elsif ( $query->param('etcancel') ) {

                    # [Cancel] button pressed
                    doCancelEdit( $theWeb, $theTopic );
                    ASSERT(0) if DEBUG;
                    return;    # in case browser does not redirect
                }
                elsif ( $query->param('etaddrow') ) {

                    # [Add row] button pressed
                    $etrows = ( $etrows == -1 ) ? 1 : $etrows + 1;
                    $addedRowCount++;
                    $doEdit = doEnableEdit( $theWeb, $theTopic, 0 );
                    return unless ($doEdit);
                }
                elsif ( $query->param('etdelrow') ) {

                    # [Delete row] button pressed
                    if ( $etrows > 0 ) {
                        $etrows--;
                    }
                    $addedRowCount--;
                    $doEdit = doEnableEdit( $theWeb, $theTopic, 0 );
                    return unless ($doEdit);
                }
                elsif ( $query->param('etedit') ) {

                    # [Edit table] button pressed
                    $doEdit = doEnableEdit( $theWeb, $theTopic, 1 );

                    # never return if locked or no permission
                    return unless ($doEdit);
                }
            }
        }

        $doEdit = $isParamTable ? 1 : 0;

        # END HANDLE EDITTABLE TAG
        # ========================================

        # ========================================
        # START FOOTER AND HEADER ROW COUNT

        if ( $editTableTag =~ m/$regex{table_plugin}/ ) {

            # We want this info also when viewing, because the row count takes
            # header and footer rows into account

            # match with a TablePlugin line
            # works when TABLE tag is just above OR just below the EDITTABLE tag
            my %tablePluginParams = TWiki::Func::extractParameters($1);
            $headerRowCount = $tablePluginParams{'headerrows'} || 0;
            $footerRowCount = $tablePluginParams{'footerrows'} || 0;
        }

        # END FOOTER AND HEADER ROW COUNT
        # ========================================

        # ========================================
        # START FORM
        if ( !$doSave ) {
            my $tableStart =
              handleTableStart( $theWeb, $theTopic, $includingWeb,
                $includingTopic, $tableNr, $doEdit, $headerRowCount,
                $footerRowCount );
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
s/$regex{table_row}/handleTableRow( $1, $2, $tableNr, $isNewRow, $theRowNr, $doEdit, $doSave, $theWeb, $theTopic )/eo;
                push @rows, $_;

                next;
            }    # if ( $doEdit || $doSave )
                 # just render the row: EDITCELL and format tokens
            my $isNewRow = 0;
s/^(\s*)\|(.*)/handleTableRow( $1, $2, $tableNr, $isNewRow, $rowNr, $doEdit, $doSave, $theWeb, $theTopic )/eo;

            push( @result, "$_\n" );

        }    # for (@lines)
             # END LOOP THROUGH LINES
             # ========================================

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
            if ( !$doSave ) {

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
                    $theRowNr, $doEdit, $doSave,  $theWeb,
                    $theTopic
                );
                push @bodyRows, $newRow;
            }

            my @combinedRows = ( @headerRows, @bodyRows, @footerRows );

            # after re-ordering, renumber the cells
            my $rowCounter = 0;
            for my $cellRow (@combinedRows) {
                $rowCounter++;
                $cellRow =~ s/(etcell)([0-9]+)(x)([0-9]+)/$1$rowCounter$3$4/go;
            }
            push( @result, join( "\n", @combinedRows ) );
            if ( $doEdit && !$doSave ) {
                push( @result, "\n" );    # somewhere is a newline too few
            }
        }

        # END WRITE OUT PROCESSED ROWS
        # ========================================

        # ========================================
        # FORM END
        my $rowCount = 0;
        if ( !$doSave && !$doEdit ) {
            $rowCount = $rowNr - $headerRowCount - $footerRowCount;
        }
        if ($doEdit) {
            $rowCount = scalar @bodyRows;
        }
        if ( !$doSave ) {
            my $tableEnd = handleTableEnd(
                $theWeb,         $theTopic,       $includingWeb,
                $includingTopic, $rowCount,       $doEdit,
                $headerRowCount, $footerRowCount, $addedRowCount
            );
            push( @result, $tableEnd );
        }

        # END FORM END
        # ========================================

        # ========================================
        # START PUT PROCESSED TABLE BACK IN TEXT
        my $resultText = join( "", @result );
        if ( $doEdit && !$doSave && ( $paramTableNr == $tableNr ) ) {
            insertTmpTagInTableTagLine( $editTableTag,
                ' disableallsort="on" ' );
        }
        else {
            removeTmpTagInTableTagLine($editTableTag);
        }
        $resultText = $editTableTag . "\n" . $resultText;
        $tablesTakenOutText =~ s/<!--edittable$tableNr-->/$resultText\n/;

        # END PUT PROCESSED TABLE BACK IN TEXT
        # ========================================

        # ========================================
        # START RE-INIT VALUES
        $rowNr          = 0;
        $etrows         = -1;
        @rows           = ();
        @result         = ();
        $isParamTable   = 0;
        $paramTableNr   = 0;
        $headerRowCount = 0;
        $footerRowCount = 0;

        # END RE-INIT VALUES
        # ========================================

    }    # foreach my $tableText (@tableTexts) {

    if ($doSave) {
        my $error =
          TWiki::Func::saveTopic( $theWeb, $theTopic, $meta,
            $tablesTakenOutText, { dontlog => $doSaveQuiet } );

        TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 0 );   # unlock Topic
        my $url = TWiki::Func::getViewUrl( $theWeb, $theTopic );
        if ($error) {
            $url = TWiki::Func::getOopsUrl( $theWeb, $theTopic, 'oopssaveerr',
                $error );
        }
        TWiki::Func::redirectCgiQuery( $query, $url );
        return;
    }
    $_[0] = $tablesTakenOutText;
}

=pod

=cut

sub extractParams {
    my ( $theArgs, $theHashRef ) = @_;

    my $tmp;

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'header' );
    $$theHashRef{'header'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'footer' );
    $$theHashRef{'footer'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'headerislabel' );
    $$theHashRef{'headerislabel'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'format' );
    $tmp =~ s/^\s*\|*\s*//o;
    $tmp =~ s/\s*\|*\s*$//o;
    $$theHashRef{'format'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'changerows' );
    $$theHashRef{'changerows'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'quietsave' );
    $$theHashRef{'quietsave'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'helptopic' );
    $$theHashRef{'helptopic'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'editbutton' );
    $$theHashRef{'editbutton'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'javascriptinterface' );
    $$theHashRef{'javascriptinterface'} = $tmp if ($tmp);

    return;
}

=pod

=cut

sub parseFormat {
    my ( $theFormat, $theTopic, $theWeb, $doExpand ) = @_;

    $theFormat =~ s/\$nop(\(\))?//gos;         # remove filler
    $theFormat =~ s/\$quot(\(\))?/\"/gos;      # expand double quote
    $theFormat =~ s/\$percnt(\(\))?/\%/gos;    # expand percent
    $theFormat =~ s/\$dollar(\(\))?/\$/gos;    # expand dollar

    if ($doExpand) {

        # expanded form to be able to use %-vars in format
        $theFormat =~ s/<nop>//gos;
        $theFormat =
          TWiki::Func::expandCommonVariables( $theFormat, $theTopic, $theWeb );
    }

    my @aFormat = split( /\s*\|\s*/, $theFormat );
    $aFormat[0] = "text,$DEFAULT_FIELD_SIZE" unless @aFormat;

    return @aFormat;
}

=pod

=cut

sub handleEditTableTag {
    my ( $theWeb, $theTopic, $thePreSpace, $theArgs ) = @_;

    my $preSp = $thePreSpace || '';

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
    );
    $warningMessage = '';

    # include topic to read definitions
    my $iTopic = TWiki::Func::extractNameValuePair( $theArgs, 'include' );
    my $iTopicExists = 0;
    if ($iTopic) {
        if ( $iTopic =~ /^([^\.]+)\.(.*)$/o ) {
            $theWeb = $1;
            $iTopic = $2;
        }

        $iTopicExists = TWiki::Func::topicExists( $theWeb, $iTopic )
          if $iTopic ne '';
        if ( $iTopic && !$iTopicExists ) {
            $warningMessage = $prefMESSAGE_INCLUDED_TOPIC_DOES_NOT_EXIST;
        }
        if ($iTopicExists) {

            my $text = TWiki::Func::readTopicText( $theWeb, $iTopic );
            $text =~ /$regex{edit_table_plugin}/os;
            if ($1) {
                my $args = $1;
                if (   $theWeb ne $TWiki::Plugins::EditTablePlugin::web
                    || $iTopic ne $TWiki::Plugins::EditTablePlugin::topic )
                {

                    # expand common vars, unless oneself to prevent recursion
                    $args = TWiki::Func::expandCommonVariables( $1, $iTopic,
                        $theWeb );
                }
                extractParams( $args, \%params );
            }
        }
    }

    extractParams( $theArgs, \%params );

    # FIXME: should use TWiki::Func::extractParameters
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

    @format         = parseFormat( $params{format}, $theTopic, $theWeb, 0 );
    @formatExpanded = parseFormat( $params{format}, $theTopic, $theWeb, 1 );
    $nrCols         = @format;

    return "$preSp";
}

=pod

=cut

sub handleTableStart {
    my ( $theWeb, $theTopic, $includingWeb, $includingTopic, $theTableNr,
        $doEdit, $headerRowCount, $footerRowCount )
      = @_;

    my $viewUrl = TWiki::Func::getScriptUrl( $theWeb, $theTopic, 'viewauth' )
      . "\#edittable$theTableNr";
    my $text = '';
    if ($doEdit) {
        require TWiki::Contrib::JSCalendarContrib;
        unless ($@) {
            TWiki::Contrib::JSCalendarContrib::addHEAD('twiki');
        }
    }
    $text .= "$preSp<noautolink>\n" if $doEdit;
    $text .= "$preSp<a name=\"edittable$theTableNr\"></a>\n"
      if ( "$theWeb.$theTopic" eq "$includingWeb.$includingTopic" );
    my $cssClass = 'editTable';
    if ($doEdit) {
        $cssClass .= ' editTableEdit';
    }
    $text .= "<div class=\"" . $cssClass . "\">\n";
    my $formName = "edittable$theTableNr";
    $formName .= "\_$includingWeb\_$includingTopic"
      if ( "$theWeb\_$theTopic" ne "$includingWeb\_$includingTopic" );
    $text .=
      "$preSp<form name=\"$formName\" action=\"$viewUrl\" method=\"post\">\n";
    $text .= hiddenField( $preSp, 'ettablenr', $theTableNr, "\n" );
    $text .= hiddenField( $preSp, 'etedit',    'on',        "\n" )
      unless $doEdit;

    # pass to javascript (through META tag vars) how many header rows
    # and footer rows we have
    &TWiki::Plugins::EditTablePlugin::addHeaderAndFooterCountToHead(
        $headerRowCount, $footerRowCount )
      if ( $doEdit
        && ( "$theWeb.$theTopic" eq "$includingWeb.$includingTopic" ) );

    return $text;
}

sub hiddenField {
    my ( $prefix, $name, $value, $suffix ) = @_;
    $prefix = defined $prefix ? $prefix : '';
    $suffix = defined $suffix ? $suffix : '';
    return
      "$prefix<input type=\"hidden\" name=\"$name\" value=\"$value\" />$suffix";
}

=pod

=cut

sub handleTableEnd {
    my (
        $theWeb,         $theTopic,       $includingWeb,
        $includingTopic, $rowCount,       $doEdit,
        $headerRowCount, $footerRowCount, $addedRowCount
    ) = @_;
    my $text = '';
    $text .= hiddenField( $preSp, 'etrows',      $rowCount,      "\n" );
    $text .= hiddenField( $preSp, 'etaddedrows', $addedRowCount, "\n" )
      if $addedRowCount;

    if ( $doEdit && ( "$theWeb.$theTopic" eq "$includingWeb.$includingTopic" ) )
    {

        # Edit mode
        $text .=
"$preSp<input type=\"submit\" name=\"etsave\" id=\"etsave\" value=\"$prefSAVE_BUTTON\" class=\"twikiSubmit\" />\n";
        if ( $params{'quietsave'} ) {
            $text .=
"$preSp<input type=\"submit\" name=\"etqsave\" id=\"etqsave\" value=\"$prefQUIET_SAVE_BUTTON\" class=\"twikiButton\" />\n";
        }
        if ( $params{'changerows'} ) {
            $text .=
"$preSp<input type=\"submit\" name=\"etaddrow\" id=\"etaddrow\" value=\"$prefADD_ROW_BUTTON\" class=\"twikiButton\" />\n";
            $text .=
"$preSp<input type=\"submit\" name=\"etdelrow\" id=\"etdelrow\" value=\"$prefDELETE_LAST_ROW_BUTTON\" class=\"twikiButton\" />\n"
              unless ( $params{'changerows'} =~ /^add$/oi );
        }
        $text .=
"$preSp<input type=\"submit\" name=\"etcancel\" id=\"etcancel\" value=\"$prefCANCEL_BUTTON\" class=\"twikiButton twikiButtonCancel\" />\n";

        if ( $params{'helptopic'} ) {

            # read help topic and show below the table
            if ( $params{'helptopic'} =~ /^([^\.]+)\.(.*)$/o ) {
                $theWeb = $1;
                $params{'helptopic'} = $2;
            }
            my $helpText =
              TWiki::Func::readTopicText( $theWeb, $params{'helptopic'} );

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
        &TWiki::Plugins::EditTablePlugin::addEditModeHeadersToHead( $tableNr,
            $params{'javascriptinterface'} );
        &TWiki::Plugins::EditTablePlugin::addJavaScriptInterfaceDisabledToHead(
            $tableNr)
          if ( $params{'javascriptinterface'} eq 'off' );
        &TWiki::Plugins::EditTablePlugin::addJavaScriptInterfaceDisabledToHead(
            $tableNr)
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
    $text .= "$preSp</form>\n";
    $text .= "</div><!-- /editTable -->";
    $text .= "</noautolink>" if $doEdit;

    #    $text .= "\n";
    return $text;
}

=pod

=cut

sub parseEditCellFormat {
    $_[1] = TWiki::Func::extractNameValuePair( $_[0] );
    return '';
}

=pod

=cut

sub viewEditCell {
    my ($theAttr) = @_;
    $theAttr = TWiki::Func::extractNameValuePair($theAttr);
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
            $img =~ s|%ATTACHURL%|%PUBURL%/%TWIKIWEB%/EditTablePlugin|o;
            $img =~ s|%WEB%|%TWIKIWEB%|o;
        }
    }
    if ($img) {
        return
"<input class=\"editTableEditImageButton\" type=\"image\" src=\"$img\" alt=\"$value\" /> $warningMessage";
    }
    else {
        return
"<input class=\"twikiButton editTableEditButton\" type=\"submit\" value=\"$value\" /> $warningMessage";
    }
}

=pod

=cut

sub saveEditCellFormat {
    my ( $theFormat, $theName ) = @_;
    return '' unless ($theFormat);
    $theName =~ s/cell/format/;
    return hiddenField( '', $theName, $theFormat, '' );
}

=pod

digestedCellValue: properly handle labels whose result may have been moved around by javascript, and therefore no longer correspond to the raw saved table text.

=cut

sub inputElement {
    my ( $theTableNr, $theRowNr, $theCol, $theName, $theValue,
        $digestedCellValue, $theWeb, $theTopic )
      = @_;

    my $rawValue = $theValue;
    my $text     = '';
    my $i        = @format - 1;
    $i = $theCol if ( $theCol < $i );

    my @bits         = split( /,\s*/, $format[$i] );
    my @bitsExpanded = split( /,\s*/, $formatExpanded[$i] );

    my $cellFormat = '';
    $theValue =~
      s/\s*%EDITCELL{(.*?)}%/&parseEditCellFormat( $1, $cellFormat )/eo;

    # If cell is empty we remove the space to not annoy the user when
    # he needs to add text to empty cell.
    $theValue = '' if ( $theValue eq ' ' );

    if ($cellFormat) {
        my @aFormat = parseFormat( $cellFormat, $theTopic, $theWeb, 0 );
        @bits = split( /,\s*/, $aFormat[0] );
        @aFormat = parseFormat( $cellFormat, $theTopic, $theWeb, 1 );
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
          TWiki::Func::expandCommonVariables( $theValue, $theTopic, $theWeb );
        $size = 1 if $size < 1;
        $text =
          "<select class=\"twikiSelect\" name=\"$theName\" size=\"$size\">";
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
          &TWiki::Func::expandCommonVariables( $theValue, $theTopic, $theWeb );
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
          &TWiki::Func::expandCommonVariables( $theValue, $theTopic, $theWeb );
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

        # To optimize things, only in the case where a read-only column is
        # being processed (inside of this unless() statement) do we actually
        # go out and read the original topic.  Thus the reason for the
        # following unless() so we only read the topic the first time through.

        unless ( defined $table and $digestedCellValue ) {

            # To deal with the situation where TWiki variables, like
            # %CALC%, have already been processed and end up getting saved
            # in the table that way (processed), we need to read in the
            # topic page in raw format
            my $topicContents = TWiki::Func::readTopicText(
                $TWiki::Plugins::EditTablePlugin::web,
                $TWiki::Plugins::EditTablePlugin::topic
            );
            $table = TWiki::Plugins::EditTable->new();
            $table->parseText($topicContents);
        }
        my $cell =
            $digestedCellValue
          ? $table->getCell( $theTableNr, $theRowNr - 1, $theCol )
          : $rawValue;
        $theValue = $cell if ( defined $cell );    # original value from file
        TWiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );

        #$theValue = "\*$theValue\*" if ( $isHeader and $digestedCellValue );
        $text = "\*$text\*" if ($isHeader);
        $text .= ' ' . hiddenField( $preSp, $theName, $theValue );

    }
    elsif ( $type eq 'textarea' ) {
        my ( $rows, $cols ) = split( /x/, $size );

        $rows |= 3  if !defined $rows;
        $cols |= 30 if !defined $cols;
        TWiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $text .=
"<textarea class=\"twikiTextarea editTableTextarea\" rows=\"$rows\" cols=\"$cols\" name=\"$theName\">$theValue</textarea>";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq 'date' ) {
        my $ifFormat = '';
        $ifFormat = $bits[3] if ( @bits > 3 );
        $ifFormat ||= $TWiki::cfg{JSCalendarContrib}{format} || '%e %B %Y';
        $size = 10 if ( !$size || $size < 1 );
        TWiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $text .= CGI::textfield(
            {
                name     => $theName,
                class    => 'twikiInputField editTableInput',
                id       => 'id' . $theName,
                size     => $size,
                value    => $theValue,
                override => 1
            }
        );
        $text .= saveEditCellFormat( $cellFormat, $theName );
        eval 'use TWiki::Contrib::JSCalendarContrib';

        unless ($@) {
            $text .= '<span class="twikiMakeVisible">';
            $text .= CGI::image_button(
                -class   => 'editTableCalendarButton',
                -name    => 'calendar',
                -onclick => "return showCalendar('id$theName','$ifFormat')",
                -src     => TWiki::Func::getPubUrlPath() . '/'
                  . TWiki::Func::getTwikiWebname()
                  . '/JSCalendarContrib/img.gif',
                -alt   => 'Calendar',
                -align => 'middle'
            );
            $text .= '</span>';
        }
        $query->{'jscalendar'} = 1;
    }
    else {    #  if( $type eq 'text')
        $size = $DEFAULT_FIELD_SIZE if $size < 1;
        TWiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $text =
"<input class=\"twikiInputField editTableInput\" type=\"text\" name=\"$theName\" size=\"$size\" value=\"$theValue\" />";
        $text .= saveEditCellFormat( $cellFormat, $theName );
    }

    if ( $type ne 'textarea' ) {
        $text =~
          s/&#10;/<br \/>/go;    # change unicode linebreak character to <br />
    }
    return $text;
}

=pod

=cut

sub handleTableRow {
    my (
        $thePre, $theRow, $theTableNr, $isNewRow, $theRowNr,
        $doEdit, $doSave, $theWeb,     $theTopic
    ) = @_;
    $thePre |= '';
    my $text = "$thePre\|";
    if ($doEdit) {
        $theRow =~ s/\|\s*$//o;
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
            $val = $isNewRow ? undef : $query->param("etcell${rowID}x$col");
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

            $cell =~
              s/E_T_P_NOP//go;    # remove escaping of variables inside cells

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
                    "etcell${theRowNr}x$col", $cell, $digested, $theWeb,
                    $theTopic );
                $element = " $element \|";
                $text .= $element;
            }
        }
    }
    else {
        $theRow =~ s/%EDITCELL{(.*?)}%/viewEditCell($1)/geo;
        $text .= $theRow;
    }

    # render final value in view mode (not edit or save)
    TWiki::Plugins::EditTablePlugin::decodeFormatTokens($text)
      if ( !$doSave && !$doEdit );

    # put one space before linebreak (but not more than one)
    # so TML can get expanded
    $text =~ s/\s*<br \/>/ <br \/>/go;
    return $text;
}

=pod

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

=pod

=cut

sub doCancelEdit {
    my ( $theWeb, $theTopic ) = @_;

    TWiki::Func::writeDebug(
        "- EditTablePlugin::doCancelEdit( $theWeb, $theTopic )")
      if $TWiki::Plugins::EditTablePlugin::debug;

    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 0 );

    TWiki::Func::redirectCgiQuery( $query,
        TWiki::Func::getViewUrl( $theWeb, $theTopic ) );
}

=pod

=cut

sub doEnableEdit {
    my ( $theWeb, $theTopic, $doCheckIfLocked ) = @_;

    TWiki::Func::writeDebug(
        "- EditTablePlugin::doEnableEdit( $theWeb, $theTopic )")
      if $TWiki::Plugins::EditTablePlugin::debug;

    my $wikiUserName = TWiki::Func::getWikiName();
    if (
        !TWiki::Func::checkAccessPermission(
            'change', $wikiUserName, undef, $theTopic, $theWeb
        )
      )
    {

        # user has no permission to change the topic
        throw TWiki::OopsException(
            'accessdenied',
            def    => 'topic_access',
            web    => $theWeb,
            topic  => $theTopic,
            params => [ 'change', 'denied' ]
        );
    }

    my $breakLock = $query->param('breaklock') || '';
    unless ($breakLock) {
        my ( $oopsUrl, $lockUser ) =
          TWiki::Func::checkTopicEditLock( $theWeb, $theTopic, 'view' );
        if ($oopsUrl) {
            my $loginUser = TWiki::Func::wikiToUserName($wikiUserName);
            if ( $lockUser ne $loginUser ) {

                # change the default oopsleaseconflict url
                # use viewauth instead of view
                $oopsUrl =~ s/param4=view/param4=viewauth/;

                # add info of the edited table
                my $params = '';
                $query = TWiki::Func::getCgiQuery();
                $params .= ';ettablenr=' . $query->param('ettablenr');
                $params .= ';etedit=on';
                $oopsUrl =~ s/($|#\w*)/$params/;

                # warn user that other person is editing this topic
                TWiki::Func::redirectCgiQuery( $query, $oopsUrl );
                return 0;
            }
        }
    }

    # We are allowed to edit
    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 1 );

    return 1;
}

sub putTmpTagInTableTagLine {
    $_[0] =~
s/(%TABLE{.*?)(}%)/$1 "START_EDITTABLEPLUGIN_TMP_TAG""END_EDITTABLEPLUGIN_TMP_TAG"$2/;
}

sub insertTmpTagInTableTagLine {
    $_[0] =~
s/( "START_EDITTABLEPLUGIN_TMP_TAG")("END_EDITTABLEPLUGIN_TMP_TAG")/$1$_[1]$2/;
}

sub removeTmpTagInTableTagLine {
    $_[0] =~
      s/ "START_EDITTABLEPLUGIN_TMP_TAG"(.*?)"END_EDITTABLEPLUGIN_TMP_TAG"//go;
}

=pod

Helper class parses tables to take out table texts, and stores table cell data.

=cut

package TWiki::Plugins::EditTable;

use vars qw(
  %regex
);

BEGIN {
    $regex{edit_table_plugin} = '%EDITTABLE{(.*?)}%';
    $regex{table_plugin}      = '%TABLE(?:{(.*?)})?%';
}

=pod

=cut

sub new {
    my ($class) = @_;
    my $this = {};
    bless $this, $class;
    return $this;
}

sub parseText {
    my ( $this, $text ) = @_;
    return $this->_takeOutTables($text);
}

=pod

TODO: this is currently only used for label tags, so this seams a lot of overhead for such a small thing

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

sub _takeOutTables {
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
    my @tableTexts         = ();

    $topicText =~
      s/\r//go;    # strip out all \r chars (may be pasted into a table cell)
    $topicText =~ s/\\\n//go;    # Join lines ending in "\"
    $topicText .= $RENDER_HACK
      ;    # appended stuff is a hack to handle EDITTABLE correctly if at end

    foreach ( split( /\n/, $topicText ) ) {

        my $doCopyLine      = 1;
        my $hasEditTableTag = 0;

        # change state:
        m|<pre\b|i      && ( $insidePRE = 1 );
        m|<verbatim\b|i && ( $insidePRE = 1 );
        m|</pre>|i      && ( $insidePRE = 0 );
        m|</verbatim>|i && ( $insidePRE = 0 );

        if ( !$insidePRE ) {

            if ( /$regex{edit_table_plugin}/ && /$regex{table_plugin}/ ) {

                # EDITTABLE and TABLE on one line (order does not matter)
                TWiki::Plugins::EditTablePlugin::Core::putTmpTagInTableTagLine(
                    $_);
                $inEditTable = 1;
                $tablesTakenOutText .= "<!--edittable$tableNum-->";
                $doCopyLine = 0;
                $editTableTag .= $_;
                $hasEditTableTag = 1;
            }
            elsif (/$regex{edit_table_plugin}/) {

                # only EDITTABLE
                if ( $storedTableRow ne '' ) {

# store the TABLE tag from the previous line together with the current EDITTABLE tag
                    TWiki::Plugins::EditTablePlugin::Core::putTmpTagInTableTagLine(
                        $storedTableRow);
                    $editTableTag .= $storedTableRow . "\n";
                    $storedTableRow = '';
                }
                $inEditTable = 1;
                $tablesTakenOutText .= "<!--edittable$tableNum-->";
                $doCopyLine = 0;
                $editTableTag .= $_;
                $hasEditTableTag = 1;
            }
            elsif ( $inEditTable && /$regex{table_plugin}/ ) {

                # TABLE on the line after EDITTABLE
                # we will include it in the editTableTag
                TWiki::Plugins::EditTablePlugin::Core::putTmpTagInTableTagLine(
                    $_);
                $doCopyLine = 0;
                $editTableTag .= "\n" . $_;
                $hasEditTableTag = 1;
            }
            elsif ( !$inEditTable && /$regex{table_plugin}/ ) {

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
                    _trim( \@row );
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
                    push( @tableTexts, $tableRef );
                    $tableNum++;

                    @tableLines   = ();
                    $editTableTag = '';
                }
            }
        }    # if ( !$insidePRE )

        $tablesTakenOutText .= $_ . "\n" if $doCopyLine;
    }    # foreach

    # clean up hack that handles EDITTABLE correctly if at end
    $tablesTakenOutText =~ s/($RENDER_HACK)+$//go;
    $$this{NUM_TABLES} = $tableNum;
    return ( $tablesTakenOutText, @tableTexts );
}

=pod

Trim any leading and trailing white space and/or '*'.

=cut

sub _trim {
    my ($totrim) = @_;
    for my $element (@$totrim) {
        $element =~ s/^[[:space:]]+//;    # Strip leading spaces
        $element =~ s/[[:space:]]+$//;    # Strip trailing spaces
    }
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

=cut

sub getTable {
    my ( $this, $tableNumber ) = @_;
    my $table = $$this{"TABLE_$tableNumber"};
    return @$table if defined($table);
    return ();
}

1;
