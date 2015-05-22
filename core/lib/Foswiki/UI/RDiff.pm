# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::RDiff

UI functions for diffing.

=cut

package Foswiki::UI::RDiff;

use strict;
use warnings;
use Assert;
use Error qw( :try );

use Foswiki     ();
use Foswiki::UI ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

#TODO: this needs to be exposed to plugins and whoever might want to over-ride the rendering of diffs
#Hash, indexed by diffType (+,-,c,u,l.....)
#contains {colour, CssClassName}
my %format = (
    '+' => [ '#ccccff', 'foswikiDiffAddedMarker' ],
    '-' => [ '#ff9999', 'foswikiDiffDeletedMarker' ],
    'c' => [ '#99ff99', 'foswikiDiffChangedText' ],
    'u' => [ '#ffffff', 'foswikiDiffUnchangedText' ],
    'l' => [ '#eeeeee', 'foswikiDiffLineNumberHeader' ]
);

#SVEN - new design.
#main gets the info (NO MAJOR CHANGES NEEDED)
#parseDiffs reads the diffs and interprets the information into types {"+", "-", "u", "c", "l"} (add, remove, unchanged, changed, lineNumber} where line number is for diffs that skip unchanged lines (diff -u etc)
#so renderDiffs would get an array of [changeType, $oldstring, $newstring]
#		corresponding to Algorithm::Diff's output
#renderDiffs iterates through the interpreted info and makes it into TML / HTML? (mmm)
#and can be over-ridden :)
#(now can we do this in a way that automagically can cope eith word / letter based diffs?)
#NOTE: if we do our own diffs in perl we can go straight to renderDiffs
#TODO: I'm starting to think that we should have a variable number of lines of context. more context if you are doing a 1.13 tp 1.14 diff, less when you do a show page history.
#TODO: ***URGENT*** the diff rendering dies badly when you have table cell changes and context
#TODO: ?type={history|diff} so that you can do a normal diff between r1.3 and r1.32 (rather than a history) (and when doing a history, we maybe should not expand %SEARCH...

#| Description: | renders a cell of data from a diff |
#| Parameter: =$data= |  |
#| Parameter: =$topic= |  |
#| Return: =$text= | Formatted html text |
#| TODO: | this should move to Render.pm |
sub _renderCellData {
    my ( $session, $data, $topicObject ) = @_;

    if ($data) {

        # SMELL: assumption about storage of meta-data embedded in topic
        # text
        $data =~ s/^%META:FIELD\{(.*)\}%.*$/
          _renderAttrs($1, '|*FORM FIELD $title*|$name|$value|')/gem;
        $data =~ s/^%META:([A-Z]+)\{(.*)\}%$/
          '|*META '.$1.'*|'._renderAttrs($2).'||'/gem;
        if ( Foswiki::Func::getContext()->{'TablePluginEnabled'} ) {
            $data = "\n"
              . '%TABLE{summary="'
              . $session->i18n->maketext('Topic data')
              . '" tablerules="all" databg="#ffffff" headeralign="left"}%'
              . "\n"
              . $data;
        }
        $data = $topicObject->expandMacros($data);
        $data = $topicObject->renderTML($data);

        # Match up table tags, remove comments
        if ( $data =~ m/<\/?(th|td|table)\b/i ) {

            # data has <th> or <td>, need to fix ables
            my $bTable = ( $data =~ s/(<table)/$1/gis )   || 0;
            my $eTable = ( $data =~ s/(<\/table)/$1/gis ) || 0;
            while ( $eTable < $bTable ) {
                $data .= CGI::end_table();
                $eTable++;
            }
            while ( $bTable < $eTable ) {
                $data = CGI::start_table() . $data;
                $bTable++;
            }
            unless ($bTable) {
                $data = CGI::start_table() . $data . CGI::end_table();
            }
        }

        # unhide html comments (<!-- --> type tags)
        $data =~ s/<!--(.*?)-->/<pre>&lt;--$1--&gt;<\/pre>/gs;
    }
    return $data;
}

# Simple method to expand attribute values in a format string
sub _renderAttrs {
    my ( $p, $f ) = @_;
    require Foswiki::Attrs;
    my $attrs = new Foswiki::Attrs($p);
    require Foswiki::Store;
    if ($f) {
        for my $key ( keys %$attrs ) {
            my $av = Foswiki::Meta::dataDecode( $attrs->{$key} );
            $f =~ s/\$$key\b/$av/g;
        }
    }
    else {
        $f = $attrs->stringify();
    }
    return $f;
}

sub _sideBySideRow {
    my ( $left, $right, $lc, $rc ) = @_;

    my $d1 = CGI::td(
        {
            bgcolor => $format{$lc}[0],
            class   => $format{$lc}[1],
            valign  => 'top'
        },
        $left . '&nbsp;'
    );
    my $d2 = CGI::td(
        {
            bgcolor => $format{$rc}[0],
            class   => $format{$rc}[1],
            valign  => 'top'
        },
        $right . '&nbsp;'
    );
    return CGI::Tr( {}, $d1 . $d2 );
}

#| Description: | render the Diff entry using side by side |
#| Parameter: =$diffType= | {+,-,u,c,l} denotes the patch operation |
#| Parameter: =$left= | the text blob before the opteration |
#| Parameter: =$right= | the text after the operation |
#| Return: =$result= | Formatted html text |
#| TODO: | this should move to Render.pm |
sub _renderSideBySide {
    my ( $session, $topicObject, $diffType, $left, $right ) = @_;
    my $result = '';

    $left  = _renderCellData( $session, $left,  $topicObject );
    $right = _renderCellData( $session, $right, $topicObject );

    if ( $diffType eq '-' ) {
        $result .= _sideBySideRow( $left, $right, '-', 'u' );
    }
    elsif ( $diffType eq "+" ) {
        $result .= _sideBySideRow( $left, $right, 'u', '+' );
    }
    elsif ( $diffType eq "u" ) {
        $result .= _sideBySideRow( $left, $right, 'u', 'u' );
    }
    elsif ( $diffType eq "c" ) {
        $result .= _sideBySideRow( $left, $right, 'c', 'c' );
    }
    elsif ( $diffType eq "l" && $left ne '' && $right ne '' ) {
        $result .= CGI::Tr(
            {
                bgcolor => $format{l}[0],
                class   => $format{l}[1],
            },
            CGI::th( ( $session->i18n->maketext( 'Line: [_1]', $left ) ) )
              . CGI::th( ( $session->i18n->maketext( 'Line: [_1]', $right ) ) )
        );
    }

    # unhide html comments (<!-- --> type tags)
    $result =~ s/<!--(.*?)-->/<pre>&lt;--$1--&gt;<\/pre>/gs;

    return $result;
}

#| Description: | render the Diff array (no TML conversion) |
#| Parameter: =$diffType= | {+,-,u,c,l} denotes the patch operation |
#| Parameter: =$left= | the text blob before the opteration |
#| Parameter: =$right= | the text after the operation |
#| Return: =$result= | Formatted html text |
#| TODO: | this should move to Render.pm |
sub _renderDebug {
    my ( $diffType, $left, $right ) = @_;
    my $result = '';

    #de-html-ize
    $left  =~ s/&/&amp;/g;
    $left  =~ s/</&lt;/g;
    $left  =~ s/>/&gt;/g;
    $right =~ s/&/&amp;/g;
    $right =~ s/</&lt;/g;
    $right =~ s/>/&gt;/g;

    $result = CGI::Tr( {}, CGI::td( {}, 'type: ' . $diffType ) );

    my %classMap = (
        '+' => ['foswikiDiffAddedText'],
        '-' => ['foswikiDiffDeletedText'],
        'c' => ['foswikiDiffChangedText'],
        'u' => ['foswikiDiffUnchangedText'],
        'l' => ['foswikiDiffLineNumberHeader']
    );

    my $styleClass = ' ' . $classMap{$diffType}[0] || '';
    my $styleClassLeft = ( $diffType ne 'c' ) ? $styleClass : '';
    my $styleClassRight = $styleClass;

    if ( $diffType ne '+' ) {
        $result .= CGI::Tr(
            { class => 'foswikiDiffDebug' },
            CGI::td(
                { class => 'foswikiDiffDebugLeft ' . $styleClassLeft },
                CGI::div( {}, $left )
            )
        );
    }
    if ( ( $diffType ne '-' ) && ( $diffType ne 'l' ) ) {
        $result .= CGI::Tr(
            { class => 'foswikiDiffDebug' },
            CGI::td(
                { class => 'foswikiDiffDebugRight ' . $styleClassRight },
                CGI::div( {}, $right )
            )
        );
    }

    # unhide html comments (<!-- --> type tags)
    $result =~ s/<!--(.*?)-->/<pre>&lt;--$1--&gt;<\/pre>/gs;

    return $result;
}

sub _sequentialRow {
    my ( $bg, $hdrcls, $bodycls, $data, $code, $char, $session ) = @_;
    my $row = '';
    if ($char) {
        $row = CGI::td(
            {
                bgcolor => $format{$code}[0],
                class   => $format{$code}[1],
                valign  => 'top',
                width   => "1%"
            },
            $char . CGI::br() . $char
        );
    }
    else {
        $row = CGI::td( { class => 'foswikiDiffUnchangedMarker', }, '&nbsp;' );
    }
    $row .= CGI::td( { class => "foswikiDiff${bodycls}Text" }, $data );
    $row = CGI::Tr( {}, $row );
    if ($bg) {
        return CGI::Tr(
            {},
            CGI::td(
                {
                    bgcolor => $bg,
                    class   => "foswikiDiff${hdrcls}Header",
                    colspan => 9
                },
                CGI::b( {}, $session->i18n->maketext($hdrcls) . ': ' )
            )
        ) . $row;
    }
    else {
        return $row;
    }
}

#| Description: | render the Diff using old style sequential blocks |
#| Parameter: =$diffType= | {+,-,u,c,l} denotes the patch operation |
#| Parameter: =$left= | the text blob before the opteration |
#| Parameter: =$right= | the text after the operation |
#| Return: =$result= | Formatted html text |
#| TODO: | this should move to Render.pm |
sub _renderSequential {
    my ( $session, $topicObject, $diffType, $left, $right ) = @_;
    my $result = '';

#note: I have made the colspan 9 to make sure that it spans all columns (thought there are only 2 now)
    if ( $diffType eq '-' ) {
        $result .=
          _sequentialRow( '#FFD7D7', 'Deleted', 'Deleted',
            _renderCellData( $session, $left, $topicObject ),
            '-', '&lt;', $session );
    }
    elsif ( $diffType eq '+' ) {
        $result .=
          _sequentialRow( '#D0FFD0', 'Added', 'Added',
            _renderCellData( $session, $right, $topicObject ),
            '+', '&gt;', $session );
    }
    elsif ( $diffType eq 'u' ) {
        $result .=
          _sequentialRow( undef, 'Unchanged', 'Unchanged',
            _renderCellData( $session, $right, $topicObject ),
            'u', '', $session );
    }
    elsif ( $diffType eq 'c' ) {
        $result .=
          _sequentialRow( '#D0FFD0', 'Changed', 'Deleted',
            _renderCellData( $session, $left, $topicObject ),
            '-', '&lt;', $session );
        $result .=
          _sequentialRow( undef, 'Changed', 'Added',
            _renderCellData( $session, $right, $topicObject ),
            '+', '&gt;', $session );
    }
    elsif ( $diffType eq 'l' && $left ne '' && $right ne '' ) {
        $result .= CGI::Tr(
            {
                bgcolor => $format{l}[0],
                class   => 'foswikiDiffLineNumberHeader'
            },
            CGI::th(
                { colspan => 9 },
                (
                    $session->i18n->maketext(
                        'Line: [_1] to [_2]',
                        $left, $right
                    )
                )
            )
        );
    }

    # unhide html comments (<!-- --> type tags)
    $result =~ s/<!--(.*?)-->/<pre>&lt;--$1--&gt;<\/pre>/gs;

    return $result;
}

#| Description: | uses renderStyle to choose the rendering function to use |
#| Parameter: =$diffArray= | array generated by parseRevisionDiff |
#| Parameter: =$renderStyle= | style of rendering { debug, sequential, sidebyside} |
#| Return: =$text= | output html for one renderes revision diff |
#| TODO: | move into Render.pm |
sub _renderRevisionDiff {
    my ( $session, $topicObject, $sdiffArray_ref, $renderStyle ) = @_;

    #combine sequential array elements that are the same diffType
    my @diffArray = ();
    foreach my $ele (@$sdiffArray_ref) {
        if (   ( @$ele[1] =~ m/^\%META\:TOPICINFO/ )
            || ( @$ele[2] =~ m/^\%META\:TOPICINFO/ ) )
        {

# do nothing, ignore redundant topic info
# FIXME: Intelligently remove followup lines in case META:TOPICINFO is the only change
        }
        elsif ((@diffArray)
            && ( @{ $diffArray[$#diffArray] }[0] eq @$ele[0] ) )
        {
            @{ $diffArray[$#diffArray] }[1] .= "\n" . @$ele[1];
            @{ $diffArray[$#diffArray] }[2] .= "\n" . @$ele[2];
        }
        else {

# Store doesn't expand REVINFO and we don't have rev info available now; escape tags to avoid confusion
            @$ele[1] =~ s/\%REVINFO/\%<nop>REVINFO/
              unless $renderStyle eq 'debug';
            @$ele[2] =~ s/\%REVINFO/\%<nop>REVINFO/
              unless $renderStyle eq 'debug';
            push @diffArray, $ele;
        }
    }
    my $diffArray_ref = \@diffArray;

    my $result   = "";
    my $data     = '';
    my $diff_ref = undef;
    for my $next_ref (@$diffArray_ref) {
        if (   ( @$next_ref[0] eq 'l' )
            && ( @$next_ref[1] eq 0 )
            && ( @$next_ref[2] eq 0 ) )
        {
            next;
        }
        if ( !$diff_ref ) {
            $diff_ref = $next_ref;
            next;
        }
        if ( ( @$diff_ref[0] eq '-' ) && ( @$next_ref[0] eq '+' ) ) {
            $diff_ref = [ 'c', @$diff_ref[1], @$next_ref[2] ];
            $next_ref = undef;
        }
        if ( $renderStyle eq 'sequential' ) {
            $result .= _renderSequential( $session, $topicObject, @$diff_ref );
        }
        elsif ( $renderStyle eq 'sidebyside' ) {
            $result .= CGI::Tr(
                {},
                CGI::td( { width => '50%' }, '' ),
                CGI::td( { width => '50%' }, '' )
            );
            $result .= _renderSideBySide( $session, $topicObject, @$diff_ref );
        }
        elsif ( $renderStyle eq 'debug' ) {
            $result .= _renderDebug(@$diff_ref);
        }
        $diff_ref = $next_ref;
    }

    #don't forget the last one ;)
    if ($diff_ref) {
        if ( $renderStyle eq 'sequential' ) {
            $result .= _renderSequential( $session, $topicObject, @$diff_ref );
        }
        elsif ( $renderStyle eq 'sidebyside' ) {
            $result .= CGI::Tr(
                {},
                CGI::td( { width => '50%' }, '' ),
                CGI::td( { width => '50%' }, '' )
            );
            $result .= _renderSideBySide( $session, $topicObject, @$diff_ref );
        }
        elsif ( $renderStyle eq 'debug' ) {
            $result .= _renderDebug(@$diff_ref);
        }
    }
    return CGI::table(
        {
            class       => 'foswikiDiffTable',
            summary     => 'changes to ' . $topicObject->topic,
            width       => '100%',
            cellspacing => 0,
            cellpadding => 0
        },
        $result
    );
}

=begin TML

---++ StaticMethod diff( $session )

=diff= command handler.
This method is designed to be
invoked via the =UI::run= method.

Renders the differences between version of a topic
| topic | topic that we are showing the differences of |
| rev1 | the higher revision |
| rev2 | the lower revision |
| render | the rendering style {sequential, sidebyside, raw, debug} | (preferences) DIFFRENDERSTYLE, =sequential= |
| type | {history, diff, last} history diff, version to version, last version to previous | =history= |
| context | number of lines of context |
| skin | the skin(s) to use to display the diff |
TODO:
   * add a {word} render style
   * move the common CGI param handling to one place
   * move defaults somewhere

=cut

sub diff {
    my $session = shift;

    my $query = $session->{request};
    my $web   = $session->{webName};
    my $topic = $session->{topicName};

    Foswiki::UI::checkWebExists( $session, $web, 'diff' );
    Foswiki::UI::checkTopicExists( $session, $web, $topic, 'diff' );

    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );

    my $renderStyle =
         $query->param('render')
      || $session->{prefs}->getPreference('DIFFRENDERSTYLE')
      || 'sequential';
    my $diffType = $query->param('type') || 'history';
    my $contextLines = $query->param('context');
    unless ( defined $contextLines ) {
        $session->{prefs}->getPreference('DIFFCONTEXTLINES');
        $contextLines = 3 unless defined $contextLines;
    }
    my $revHigh =
      Foswiki::Store::cleanUpRevID( scalar( $query->param('rev1') ) );
    my $revLow =
      Foswiki::Store::cleanUpRevID( scalar( $query->param('rev2') ) );

    my $tmpl = $session->templates->readTemplate('rdiff');
    $tmpl =~ s/\%META\{.*?\}\%//g;    # remove %META{'parent'}%

    # The template is split by up to 4 %REPEAT% tags. The sections are:
    # $before - text before any output
    # $difftmpl - template for a single diff
    # $after - text after the diffs
    # tail - appears to generate revision info for each of the
    # displayed revisions, but not sure - looks like a legacy thing, it's
    # not used in any of the existing templates.
    my ( $before, $difftmpl, $after, $tail ) = split( /%REPEAT%/, $tmpl, 4 );

    $before ||= '';
    $after  ||= '';
    $tail   ||= '';

    my $revIt   = $topicObject->getRevisionHistory();
    my @history = $revIt->all();                        # most recent rev first

    my ( $olderi, $neweri );                            # indexes into history
    if ( $diffType eq 'last' ) {
        $neweri = 0;
        $olderi = ( scalar(@history) > 1 ) ? $neweri + 1 : 0;
    }
    else {
        for ( my $i = 0 ; $i <= $#history ; $i++ ) {
            $neweri = $i if ( $history[$i] == $revHigh );
            $olderi = $i if ( $history[$i] == $revLow );
            last if ( defined $olderi && defined $neweri );
        }
        $neweri = 0         unless defined $neweri;
        $olderi = $#history unless defined $olderi;
    }

    my $revTitleHigh = $history[$neweri];
    my $revTitleLow = ( $olderi != $neweri ) ? $history[$olderi] : '';

    # Limit the total number of diffs to avoid DoS
    my $step =
      int( ( $olderi - $neweri ) / $Foswiki::cfg{MaxRevisionsInADiff} + 0.5 );
    $step = 1 if $step < 1;

    $before =~ s/%REVTITLE1%/$revTitleHigh/g;
    $before =~ s/%REVTITLE2%/$revTitleLow/g;
    $before = $topicObject->expandMacros($before);
    $before = $topicObject->renderTML($before);

    my $page = $before;

    # do one or more diffs
    $difftmpl = $topicObject->expandMacros($difftmpl);
    my $rNewer         = $neweri;
    my $rOlder         = $olderi;
    my $isMultipleDiff = 0;

    if ( $diffType eq 'history' && $olderi > $neweri + 1 ) {
        $rOlder         = $neweri + $step;
        $isMultipleDiff = 1;
    }

    # If we are applying control to the raw view:
    if (   $renderStyle eq 'debug'
        && defined $Foswiki::cfg{FeatureAccess}{AllowRaw}
        && $Foswiki::cfg{FeatureAccess}{AllowRaw} ne 'all' )
    {

        if ( $Foswiki::cfg{FeatureAccess}{AllowRaw} eq 'authenticated' ) {
            throw Foswiki::AccessControlException( 'authenticated',
                $session->{user}, $web, $topic, $Foswiki::Meta::reason )
              unless $session->inContext("authenticated");
        }
        else {
            Foswiki::UI::checkAccess( $session, 'RAW', $topicObject )
              unless $topicObject->haveAccess('CHANGE');
        }
    }

    # If we are applying control to the revisions:
    if ( defined $Foswiki::cfg{FeatureAccess}{AllowHistory}
        && $Foswiki::cfg{FeatureAccess}{AllowHistory} ne 'all' )
    {

        if ( $Foswiki::cfg{FeatureAccess}{AllowHistory} eq 'authenticated' ) {
            throw Foswiki::AccessControlException( 'authenticated',
                $session->{user}, $web, $topic, $Foswiki::Meta::reason )
              unless $session->inContext("authenticated");
        }
        else {
            Foswiki::UI::checkAccess( $session, 'HISTORY', $topicObject );
        }
    }

    my %toms;

    do {
        last if ( $rOlder > $#history );

        my $rHigh = $history[$rNewer];
        my $rLow  = $history[$rOlder];

        # Load the revs being diffed
        $toms{$rHigh} =
          Foswiki::Meta->load( $session, $topicObject->web, $topicObject->topic,
            $rHigh )
          unless $toms{$rHigh};
        ASSERT(
            $toms{$rHigh}->getLoadedRev() == $rHigh,
            $toms{$rHigh}->getLoadedRev() . " == $rHigh"
        ) if DEBUG;
        $toms{$rLow} =
          Foswiki::Meta->load( $session, $topicObject->web, $topicObject->topic,
            $rLow )
          unless $toms{$rLow};
        ASSERT(
            $toms{$rLow}->getLoadedRev() == $rLow,
            $toms{$rLow}->getLoadedRev() . " == $rLow"
        ) if DEBUG;

        my $diff = $difftmpl;
        $diff =~ s/%REVTITLE1%/$rHigh/g;
        $diff =~ s/%REVTITLE2%/$rLow/g;

        my $rInfo  = '';
        my $rInfo2 = '';
        my $text;
        if ( $rHigh > $rLow + 1 ) {
            $rInfo = $session->i18n->maketext( "Changes from r[_1] to r[_2]",
                $rLow, $rHigh );
        }
        else {
            $rInfo =
              $session->renderer->renderRevisionInfo( $topicObject, $rHigh,
                '$date - $wikiusername' );
            $rInfo2 =
              $session->renderer->renderRevisionInfo( $topicObject, $rHigh,
                '$rev ($date - $time) - $wikiusername' );
        }

        # eliminate white space to prevent wrap around in HR table:
        $rInfo  =~ s/\s+/&nbsp;/g;
        $rInfo2 =~ s/\s+/&nbsp;/g;

        # Check access rights
        my $rd;
        if ( !$toms{$rHigh}->haveAccess() ) {
            $rd = [ [ '-', " *Revision $rHigh is unreadable* ", '' ] ];
            if ( !$toms{$rLow}->haveAccess() ) {
                push( @$rd, [ '+', '', " *Revision $rLow is unreadable* " ] );
            }
            else {
                foreach ( split( "\n", $rLow ) ) {
                    push( @$rd, [ '+', '', $_ ] );
                }
            }
        }
        elsif ( !$toms{$rLow}->haveAccess() ) {
            $rd = [ [ '+', '', " *Revision $rLow is unreadable* " ] ];
            foreach ( split( "\n", $rHigh ) ) {
                push( @$rd, [ '-', $_, '' ] );
            }
        }
        else {
            $rd = $toms{$rLow}->getDifferences( $rHigh, $contextLines );
        }

        $text =
          _renderRevisionDiff( $session, $topicObject, $rd, $renderStyle );

        $diff =~ s/%REVINFO1%/$rInfo/g;
        $diff =~ s/%REVINFO2%/$rInfo2/g;
        $diff =~ s/%TEXT%/$text/g;
        $page .= $diff;
        $rNewer += $step;
        $rOlder += $step;
        $rOlder = $#history if $rOlder > $#history;
    } while ( $diffType eq 'history' && $rNewer < $olderi );

    $session->logger->log(
        {
            level    => 'info',
            action   => 'rdiff',
            webTopic => $web . '.' . $topic,
            extra    => "$revHigh $revLow"
        }
    );

    # Generate the revisions navigator
    require Foswiki::UI::View;
    my $revisions =
      Foswiki::UI::View::revisionsAround( $session, $topicObject,
        $history[$neweri], $history[$neweri], $history[0] );

    my $tailResult = '';

    if ( defined $tail ) {

        # SMELL: made this conditional as it doesn't seem to be used
        # Generate information about each of the revs shown
        my $i        = $neweri;
        my $revTitle = '';
        while ( $i <= $olderi ) {
            last if ( $i > $#history );
            my $n = $history[$i];
            $revTitle = CGI::a(
                {
                    href => $session->getScriptUrl(
                        0, 'view', $web, $topic, rev => $n
                    ),
                    rel => 'nofollow'
                },
                $i
            );
            my $revInfo =
              $session->renderer->renderRevisionInfo( $topicObject, undef, $n );
            $tailResult .= $tail;
            $tailResult =~ s/%REVTITLE%/$revTitle/g;
            $tailResult =~ s/%REVINFO%/$revInfo/g;
            $i += $step;
        }
    }
    $after =~ s/%TAIL%/$tailResult/g;    # SMELL: unused in templates

    $after =~ s/%REVISIONS%/$revisions/g;
    $after =~ s/%CURRREV%/$revHigh/g;
    $after =~ s/%MAXREV%/$history[0]/g;

    $after = $topicObject->expandMacros($after);
    $after = $topicObject->renderTML($after);
    $page .= $after;

    $session->writeCompletePage($page);

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
