# See bottom of file for license and copyright information
package Foswiki::Render;

=begin TML

---+ package Foswiki::Render

This module provides most of the actual HTML rendering code in Foswiki.

=cut

use strict;
use Assert;
use Error qw(:try);

use Foswiki::Time ();

# Used to generate unique placeholders for when we lift blocks out of the
# text during rendering.
our $placeholderMarker = 0;

# limiting lookbehind and lookahead for wikiwords and emphasis
# use like \b
#SMELL: they really limit the number of places emphasis can happen.
our $STARTWW = qr/^|(?<=[\s\(])/m;
our $ENDWW   = qr/$|(?=[\s,.;:!?)])/m;

# marker used to tage the start of a table
our $TABLEMARKER = "\0\1\2TABLE\2\1\0";

# Marker used to indicate table rows that are valid header/footer rows
our $TRMARK = "is\1all\1th";

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new ($session)

Creates a new renderer

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{NEWLINKFORMAT};
    undef $this->{LINKTOOLTIPINFO};
    undef $this->{LIST};
    undef $this->{ffCache};
    undef $this->{session};
}

sub _newLinkFormat {
    my $this = shift;
    unless ( $this->{NEWLINKFORMAT} ) {
        $this->{NEWLINKFORMAT} =
          $this->{session}->{prefs}->getPreference('NEWLINKFORMAT')
          || '<span class="foswikiNewLink">$text<a href="%SCRIPTURLPATH{edit}%/$web/$topic?topicparent=%WEB%.%TOPIC%" '
          . 'rel="nofollow" title="%MAKETEXT{"Create this topic"}%">'
          . '?</a></span>';
    }
    return $this->{NEWLINKFORMAT};
}

=begin TML

---++ ObjectMethod renderParent($topicObject, $params) -> $text

Render parent meta-data

=cut

sub renderParent {
    my ( $this, $topicObject, $ah ) = @_;
    my $dontRecurse = $ah->{dontrecurse} || 0;
    my $depth       = $ah->{depth}       || 0;
    my $noWebHome   = $ah->{nowebhome}   || 0;
    my $prefix      = $ah->{prefix}      || '';
    my $suffix      = $ah->{suffix}      || '';
    my $usesep      = $ah->{separator}   || ' &gt; ';
    my $format      = $ah->{format}      || '[[$web.$topic][$topic]]';

    my ( $web, $topic ) = ( $topicObject->web, $topicObject->topic );
    return '' unless $web && $topic;

    my %visited;
    $visited{ $web . '.' . $topic } = 1;

    my $pWeb = $web;
    my $pTopic;
    my $text       = '';
    my $parentMeta = $topicObject->get('TOPICPARENT');
    my $parent;

    $parent = $parentMeta->{name} if $parentMeta;

    my @stack;
    my $currentDepth = 0;
    $depth = 1 if $dontRecurse;

    while ($parent) {
        $currentDepth++;
        ( $pWeb, $pTopic ) =
          $this->{session}->normalizeWebTopicName( $pWeb, $parent );
        $parent = $pWeb . '.' . $pTopic;
        last
          if ( $noWebHome && ( $pTopic eq $Foswiki::cfg{HomeTopicName} )
            || $visited{$parent} );
        $visited{$parent} = 1;
        $text = $format;
        $text =~ s/\$web/$pWeb/g;
        $text =~ s/\$topic/$pTopic/g;
        if( ! $depth or $currentDepth == $depth ) {
            unshift( @stack, $text );
        }
        last if $currentDepth == $depth;

        # Compromise; rather than supporting a hack in the store to support
        # rapid access to parent meta (as in TWiki) accept the hit
        # of reading the whole topic.
        my $topicObject =
          Foswiki::Meta->load( $this->{session}, $pWeb, $pTopic );
        my $parentMeta = $topicObject->get('TOPICPARENT');
        $parent = $parentMeta->{name} if $parentMeta;
    }
    $text = join( $usesep, @stack );

    if ($text) {
        $text = $prefix . $text if ($prefix);
        $text .= $suffix if ($suffix);
    }

    return $text;
}

=begin TML

---++ ObjectMethod renderMoved($topicObject, $params) -> $text

Render moved meta-data

=cut

sub renderMoved {
    my ( $this, $topicObject, $params ) = @_;
    my $text  = '';
    my $moved = $topicObject->get('TOPICMOVED');

    if ($moved) {
        my ( $fromWeb, $fromTopic ) =
          $this->{session}
          ->normalizeWebTopicName( $topicObject->web, $moved->{from} );
        my ( $toWeb, $toTopic ) =
          $this->{session}
          ->normalizeWebTopicName( $topicObject->web, $moved->{to} );
        my $by    = $moved->{by};
        my $u     = $by;
        my $users = $this->{session}->{users};
        $by = $users->webDotWikiName($u) if $u;
        my $date = Foswiki::Time::formatTime( $moved->{date}, '', 'gmtime' );

        # Only allow put back if current web and topic match
        # stored information
        my $putBack = '';
        if ( $topicObject->web eq $toWeb && $topicObject->topic eq $toTopic ) {
            $putBack = ' - '
              . CGI::a(
                {
                    title => (
                        $this->{session}->i18n->maketext(
'Click to move topic back to previous location, with option to change references.'
                        )
                    ),
                    href => $this->{session}->getScriptUrl(
                        0, 'rename', $topicObject->web, $topicObject->topic,
                        newweb      => $fromWeb,
                        newtopic    => $fromTopic,
                        confirm     => 'on',
                        nonwikiword => 'checked'
                    ),
                    rel => 'nofollow'
                },
                $this->{session}->i18n->maketext('put it back')
              );
        }
        $text = CGI::i(
            $this->{session}->i18n->maketext(
                "[_1] moved from [_2] on [_3] by [_4]",
                "<nop>$toWeb.<nop>$toTopic", "<nop>$fromWeb.<nop>$fromTopic",
                $date, $by
            )
        ) . $putBack;
    }
    return $text;
}

# Add a list item, of the given type and indent depth. The list item may
# cause the opening or closing of lists currently being handled.
sub _addListItem {
    my ( $this, $result, $type, $element, $indent ) = @_;

    $indent =~ s/   /\t/g;
    my $depth = length($indent);

    my $size = scalar( @{ $this->{LIST} } );

    # The whitespaces either side of the tags are required for the
    # emphasis REs to work.
    if ( $size < $depth ) {
        my $firstTime = 1;
        while ( $size < $depth ) {
            push( @{ $this->{LIST} }, { type => $type, element => $element } );
            push @$result, ' <' . $element . ">\n" unless ($firstTime);
            push @$result, ' <' . $type . ">\n";
            $firstTime = 0;
            $size++;
        }
    }
    else {
        while ( $size > $depth ) {
            my $tags = pop( @{ $this->{LIST} } );
            push @$result,
              "\n</" . $tags->{element} . '></' . $tags->{type} . '> ';
            $size--;
        }
        if ($size) {
            push @$result,
              "\n</" . $this->{LIST}->[ $size - 1 ]->{element} . '> ';
        }
        else {
            push @$result, "\n";
        }
    }

    if ($size) {
        my $oldt = $this->{LIST}->[ $size - 1 ];
        if ( $oldt->{type} ne $type ) {
            push @$result, ' </' . $oldt->{type} . '><' . $type . ">\n";
            pop( @{ $this->{LIST} } );
            push( @{ $this->{LIST} }, { type => $type, element => $element } );
        }
    }
}

# Given that we have just seen the end of a table, work out the thead,
# tbody and tfoot sections
sub _addTHEADandTFOOT {
    my ($lines) = @_;

    # scan back to the head of the table
    my $i = scalar(@$lines) - 1;
    my @thRows;
    my $inFoot    = 1;
    my $footLines = 0;
    my $headLines = 0;
    while ( $i >= 0 && $lines->[$i] ne $TABLEMARKER ) {
        if ( $lines->[$i] =~ /^\s*$/ ) {

            # Remove blank lines in tables; they generate spurious <p>'s
            splice( @$lines, $i, 1 );
        }
        elsif ( $lines->[$i] =~ s/$TRMARK=(["'])(.*?)\1//i ) {
            if ($2) {
                if ($inFoot) {
                    $footLines++;
                }
                else {
                    $headLines++;
                }
            }
            else {
                $inFoot    = 0;
                $headLines = 0;
            }
        }
        $i--;
    }
    $lines->[$i] = CGI::start_table(
        {
            class       => 'foswikiTable',
            border      => 1,
            cellspacing => 0,
            cellpadding => 0
        }
    );
    if ( $footLines && !$headLines ) {
        $headLines = $footLines;
        $footLines = 0;
    }
    if ($footLines) {
        push( @$lines, '</tfoot>' );
        my $firstFoot = scalar(@$lines) - $footLines;
        splice( @$lines, $firstFoot, 0, '</tbody><tfoot>' );
    }
    else {
        push( @$lines, '</tbody>' );
    }
    if ($headLines) {
        splice( @$lines, $i + 1 + $headLines, 0, '</thead><tbody>' );
        splice( @$lines, $i + 1, 0, '<thead>' );
    }
    else {
        splice( @$lines, $i + 1, 0, '<tbody>' );
    }
}

sub _emitTR {
    my ( $this, $row ) = @_;

    $row =~ s/\t/   /g;    # change tabs to space
    $row =~ s/\s*$//;      # remove trailing spaces
                              # calc COLSPAN
    $row =~ s/(\|\|+)/
      'colspan'.$Foswiki::TranslationToken.length($1).'|'/ge;
    my $cells = '';
    my $containsTableHeader;
    my $isAllTH = 1;
    foreach ( split( /\|/, $row ) ) {
        my @attr;

        # Avoid matching single columns
        if (s/colspan$Foswiki::TranslationToken([0-9]+)//o) {
            push( @attr, colspan => $1 );
        }
        s/^\s+$/ &nbsp; /;
        my ( $l1, $l2 ) = ( 0, 0 );
        if (/^(\s*).*?(\s*)$/) {
            $l1 = length($1);
            $l2 = length($2);
        }
        if ( $l1 >= 2 ) {
            if ( $l2 <= 1 ) {
                push( @attr, align => 'right' );
            }
            else {
                push( @attr, align => 'center' );
            }
        }

        # implicit untaint is OK, because we are just taking topic data
        # and rendering it; no security step is bypassed.
        if (/^\s*\*(.*)\*\s*$/) {
            $cells .= CGI::th( {@attr}, CGI::strong(" $1 ") ) . "\n";
        }
        else {
            $cells .= CGI::td( {@attr}, " $_ " ) . "\n";
            $isAllTH = 0;
        }
    }
    return CGI::Tr( { $TRMARK => $isAllTH }, $cells );
}

sub _fixedFontText {
    my ( $text, $embolden ) = @_;

    # preserve white space, so replace it by '&nbsp; ' patterns
    $text =~ s/\t/   /g;
    $text =~ s|((?:[\s]{2})+)([^\s])|'&nbsp; ' x (length($1) / 2) . $2|eg;
    $text = CGI->b($text) if $embolden;
    return CGI->code($text);
}

# Build an HTML &lt;Hn> element with suitable anchor for linking
# from %<nop>TOC%
sub _makeAnchorHeading {
    my ( $this, $text, $level, $topicObject ) = @_;

    # - Build '<nop><h1><a name='atext'></a> heading </h1>' markup
    # - Initial '<nop>' is needed to prevent subsequent matches.
    # filter '!!', '%NOTOC%'
    $text =~ s/$Foswiki::regex{headerPatternNoTOC}//o;

    my $html = '<nop><h' . $level . '>'
      . $this->_makeAnchorTarget( $topicObject, $text )
        . ' ' . $text . ' </h' . $level . '>';

    return $html;
}

# Make an anchor that can be used as the target of links.
sub _makeAnchorTarget {
    my ($this, $topicObject, $text) = @_;

    my $goodAnchor = $this->_makeAnchorName( $text );
    my $html = CGI::a( {
        name => $this->_makeAnchorNameUnique($topicObject, $goodAnchor),
    }, '' );

    if ($Foswiki::cfg{RequireCompatibleAnchors}) {
        # Add in extra anchors compatible with old formats, as required
        require Foswiki::Compatibility;
        my @extras = Foswiki::Compatibility::makeCompatibleAnchors( $text );
        foreach my $extra ( @extras ) {
            next if ($extra eq $goodAnchor);
            $html .= CGI::a( {
                name => $this->_makeAnchorNameUnique( $topicObject, $extra ),
            }, '' );
        }
    }
    return $html;
}

# Make an anchor name from the base test in =$anchorName=
# 1. Given the same text, this function must always return the same
#    anchor name
# 2. NAME tokens must begin with a letter ([A-Za-z]) and may be
#    followed by any number of letters, digits ([0-9]), hyphens ("-"),
#    underscores ("_"), colons (":"), and periods (".").
#    (from http://www.w3.org/TR/html401/struct/links.html#h-12.2.1)
sub _makeAnchorName {
    my ( $this, $text ) = @_;

    $text =~ s/^\s*(.*?)\s*$/$1/;
    $text =~ s/$Foswiki::regex{headerPatternNoTOC}//go;

    if ( $text =~ /^$Foswiki::regex{anchorRegex}$/ ) {
        # accept, already valid -- just remove leading #
        return substr( $text, 1 );
    }

    # $anchorName is a *byte* string. If it contains any wide characters
    # the encoding algorithm will not work.
    ASSERT($text !~ /[^\x00-\xFF]/) if DEBUG;

    # use _ as an escape character to escape any byte outside the
    # range specified by http://www.w3.org/TR/html401/struct/links.html
    $text =~ s/([^A-Za-z0-9:.])/'_'.sprintf('%02d', ord($1))/ge;

    # Ensure the anchor always starts with an [A-Za-z]
    $text = 'A'.$text;

    return $text;
}

# Returns =title='...'= tooltip info if the LINKTOOLTIPINFO preference
# is set. Warning: Slower performance if enabled.
sub _linkToolTipInfo {
    my ( $this, $web, $topic ) = @_;
    unless ( defined( $this->{LINKTOOLTIPINFO} ) ) {
        $this->{LINKTOOLTIPINFO} =
          $this->{session}->{prefs}->getPreference('LINKTOOLTIPINFO')
          || '';
        $this->{LINKTOOLTIPINFO} = '$username - $date - r$rev: $summary'
          if ( 'on' eq lc( $this->{LINKTOOLTIPINFO} ) );
    }
    return '' unless ( $this->{LINKTOOLTIPINFO} );
    return '' if ( $this->{LINKTOOLTIPINFO} =~ /^off$/i );
    return '' unless ( $this->{session}->inContext('view') );

 # FIXME: This is slow, it can be improved by caching topic rev info and summary
    my $users = $this->{session}->{users};

    # SMELL: we ought not to have to fake this. Topic object model, please!!
    require Foswiki::Meta;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    my $info = $meta->getRevisionInfo();
    my $text = $this->{LINKTOOLTIPINFO};
    $text =~ s/\$web/<nop>$web/g;
    $text =~ s/\$topic/<nop>$topic/g;
    $text =~ s/\$rev/1.$info->{version}/g;
    $text =~ s/\$date/Foswiki::Time::formatTime( $info->{date} )/ge;
    $text =~ s/\$username/$users->getLoginName($info->{author})/ge;
    $text =~ s/\$wikiname/$users->getWikiName($info->{author})/ge;
    $text =~ s/\$wikiusername/$users->webDotWikiName($info->{author})/ge;

    if ( $text =~ /\$summary/ ) {
        my $summary;
        my $topicObject = Foswiki::Meta->load( $this->{session}, $web, $topic );
        if ( $topicObject->haveAccess('VIEW') ) {
            $summary = $topicObject->text || '';
        }
        else {
            $summary =
              $this->{session}
              ->inlineAlert( 'alerts', 'access_denied', "$web.$topic" );
        }
        $summary = $topicObject->summarise();
        $summary =~
          s/[\"\']//g;    # remove quotes (not allowed in title attribute)
        $text =~ s/\$summary/$summary/g;
    }
    return $text;
}

=begin TML

---++ ObjectMethod internalLink ( $web, $topic, $linkText, $anchor, $linkIfAbsent, $keepWebPrefix, $hasExplicitLinkLabel ) -> $html

Generate a link.

Note: Topic names may be spaced out. Spaced out names are converted to <nop>WikWords,
for example, "spaced topic name" points to "SpacedTopicName".
   * =$web= - the web containing the topic
   * =$topic= - the topic to be link
   * =$linkText= - text to use for the link
   * =$anchor= - the link anchor, if any
   * =$linkIfAbsent= - boolean: false means suppress link for non-existing pages
   * =$keepWebPrefix= - boolean: true to keep web prefix (for non existing Web.TOPIC)
   * =$hasExplicitLinkLabel= - boolean: true in case of [[TopicName][explicit link label]]

Called by _handleWikiWord and _handleSquareBracketedLink and by Func::internalLink

Calls _renderWikiWord, which in turn will use Plurals.pm to match fold plurals to equivalency with their singular form

SMELL: why is this available to Func?

=cut

sub internalLink {
    my ( $this, $web, $topic, $linkText, $anchor, $linkIfAbsent,
        $keepWebPrefix, $hasExplicitLinkLabel )
      = @_;

    # SMELL - shouldn't it be callable by Foswiki::Func as well?

    #PN: Webname/Subweb/ -> Webname/Subweb
    $web =~ s/\/\Z//o;

    if ( $linkText eq $web ) {
        $linkText =~ s/\//\./go;
    }

    #WebHome links to tother webs render as the WebName
    if (   ( $linkText eq $Foswiki::cfg{HomeTopicName} )
        && ( $web ne $this->{session}->{webName} ) )
    {
        $linkText = $web;
    }

    # Get rid of leading/trailing spaces in topic name
    $topic =~ s/^\s*//o;
    $topic =~ s/\s*$//o;

    # Allow spacing out, etc.
    # Plugin authors use $hasExplicitLinkLabel to determine if the link label
    # should be rendered differently even if the topic author has used a
    # specific link label.
    $linkText =
      $this->{session}->{plugins}
      ->dispatch( 'renderWikiWordHandler', $linkText, $hasExplicitLinkLabel,
        $web, $topic )
      || $linkText;

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word. TODO: Try to turn this off,
    # avoiding spaces being stripped elsewhere
    $topic =~ s/^(.)/\U$1/;
    $topic =~ s/\s([$Foswiki::regex{mixedAlphaNum}])/\U$1/go;

    # Add <nop> before WikiWord inside link text to prevent double links
    $linkText =~ s/(?<=[\s\(])([$Foswiki::regex{upperAlpha}])/<nop>$1/go;
    return _renderWikiWord( $this, $web, $topic, $linkText, $anchor,
        $linkIfAbsent, $keepWebPrefix );
}

# TODO: this should be overridable by plugins.
sub _renderWikiWord {
    my ( $this, $web, $topic, $linkText, $anchor, $linkIfAbsent,
        $keepWebPrefix )
      = @_;
    my $session = $this->{session};
    my $topicExists = $session->topicExists( $web, $topic );

    my $singular = '';
    unless ($topicExists) {

        # topic not found - try to singularise
        require Foswiki::Plurals;
        $singular = Foswiki::Plurals::singularForm( $web, $topic );
        if ($singular) {
            $topicExists = $session->topicExists( $web, $singular );
            $topic = $singular if $topicExists;
        }
    }

    if ($topicExists) {
        return _renderExistingWikiWord( $this, $web, $topic, $linkText,
            $anchor );
    }
    if ($linkIfAbsent) {

        # CDot: disabled until SuggestSingularNotPlural is resolved
        # if ($singular && $singular ne $topic) {
        #     #unshift( @topics, $singular);
        # }
        return _renderNonExistingWikiWord( $this, $web, $topic, $linkText );
    }
    if ($keepWebPrefix) {
        return $web . '.' . $linkText;
    }

    return $linkText;
}

sub _renderExistingWikiWord {
    my ( $this, $web, $topic, $text, $anchor ) = @_;

    my $currentWebHome = '';
    $currentWebHome = 'foswikiCurrentWebHomeLink  '
      if ( ( $web eq $this->{session}->{webName} )
        && ( $topic eq $Foswiki::cfg{HomeTopicName} ) );

    my $currentTopic = '';
    $currentTopic = 'foswikiCurrentTopicLink'
      if ( ( $web eq $this->{session}->{webName} )
        && ( $topic eq $this->{session}->{topicName} ) );

    my @attrs;
    my $href = $this->{session}->getScriptUrl( 0, 'view', $web, $topic );
    if ($anchor) {
        $anchor = $this->_makeAnchorName( $anchor );
        # No point in trying to make it unique; just aim at the first
        # occurrence
        $href   = $href.'#'.Foswiki::urlEncode($anchor);
    }
    my $cssClassName = "$currentTopic$currentWebHome";
    $cssClassName =~ s/^(.*?)\s*$/$1/ if $cssClassName;
    push( @attrs, class => $cssClassName ) if $cssClassName;
    push( @attrs, href => $href );
    my $tooltip = _linkToolTipInfo( $this, $web, $topic );
    push( @attrs, title => $tooltip ) if ($tooltip);

    my $link = CGI::a( {@attrs}, $text );

    # When we pass the tooltip text to CGI::a it may contain
    # <nop>s, and CGI::a will convert the < to &lt;. This is a
    # basic problem with <nop>.
    $link =~ s/&lt;nop&gt;/<nop>/g;
    return $link;
}

sub _renderNonExistingWikiWord {
    my ( $this, $web, $topic, $text ) = @_;

    my $ans = $this->_newLinkFormat;
    $ans =~ s/\$web/$web/g;
    $ans =~ s/\$topic/$topic/g;
    $ans =~ s/\$text/$text/g;
    my $topicObject = Foswiki::Meta->new(
        $this->{session},
        $this->{session}->{webName},
        $this->{session}->{topicName}
    );
    return $topicObject->expandMacros($ans);
}

# _handleWikiWord is called for a wiki word that needs linking.
# Handle the various link constructions. e.g.:
# WikiWord
# Web.WikiWord
# Web.WikiWord#anchor
#
# This routine adds missing parameters before passing off to internallink
sub _handleWikiWord {
    my ( $this, $topicObject, $web, $topic, $anchor ) = @_;

    my $linkIfAbsent = 1;
    my $keepWeb      = 0;
    my $text;

    $web = $topicObject->web() unless ( defined($web) );
    if ( defined($anchor) ) {
        ASSERT( ( $anchor =~ m/\#.*/ ) ) if DEBUG;    # must include a hash.
    }
    else {
        $anchor = '';
    }

    if ( defined($anchor) ) {

        # 'Web.TopicName#anchor' or 'Web.ABBREV#anchor' link
        $text = $topic . $anchor;
    }
    else {
        $anchor = '';

        # 'Web.TopicName' or 'Web.ABBREV' link:
        if (   $topic eq $Foswiki::cfg{HomeTopicName}
            && $web ne $this->{session}->{webName} )
        {
            $text = $web;
        }
        else {
            $text = $topic;
        }
    }

    # true to keep web prefix for non-existing Web.TOPIC
    # Have to leave "web part" of ABR.ABR.ABR intact if topic not found
    $keepWeb =
      (      $topic =~ /^$Foswiki::regex{abbrevRegex}$/o
          && $web ne $this->{session}->{webName} );

    # false means suppress link for non-existing pages
    $linkIfAbsent = ( $topic !~ /^$Foswiki::regex{abbrevRegex}$/o );

    return $this->internalLink( $web, $topic, $text, $anchor, $linkIfAbsent,
        $keepWeb, undef );
}

# Handle SquareBracketed links mentioned on page $web.$topic
# format: [[$link]]
# format: [[$link][$text]]
sub _handleSquareBracketedLink {
    my ( $this, $topicObject, $link, $text ) = @_;

    # Strip leading/trailing spaces
    $link =~ s/^\s+//;
    $link =~ s/\s+$//;

    my $hasExplicitLinkLabel = $text ? 1 : undef;

    # Explicit external [[$link][$text]]-style can be handled directly
    if ( $link =~ m!^($Foswiki::regex{linkProtocolPattern}\:|/)! ) {
        if ( defined $text ) {

            # [[][]] style - protect text:
            # Prevent automatic WikiWord or CAPWORD linking in explicit links
            $text =~
s/(?<=[\s\(])($Foswiki::regex{wikiWordRegex}|[$Foswiki::regex{upperAlpha}])/<nop>$1/go;
        }
        else {

            # [[]] style - take care for legacy:
            # Prepare special case of '[[URL#anchor display text]]' link
            # implicit untaint is OK because we are just recyling topic content
            if ( $link =~ /^(\S+)\s+(.*)$/ ) {

                # '[[URL#anchor display text]]' link:
                $link = $1;
                $text = $2;
                $text =~
s/(?<=[\s\(])($Foswiki::regex{wikiWordRegex}|[$Foswiki::regex{upperAlpha}])/<nop>$1/go;
            }
        }
        return _externalLink( $this, $link, $text );
    }

    $text ||= $link;

    # Extract '#anchor'
    # $link =~ s/(\#[a-zA-Z_0-9\-]*$)//;
    my $anchor = '';
    if ( $link =~ s/($Foswiki::regex{anchorRegex}$)// ) {
        $anchor = $1;
    }

    # filter out &any; entities (legacy)
    $link =~ s/\&[a-z]+\;//gi;

    # filter out &#123; entities (legacy)
    $link =~ s/\&\#[0-9]+\;//g;

    # Filter junk
    $link =~ s/$Foswiki::cfg{NameFilter}+/ /g;

    # Capitalise first word
    $link =~ s/^(.)/\U$1/;

    # Collapse spaces and capitalise following letter
    $link =~ s/\s([$Foswiki::regex{mixedAlphaNum}])/\U$1/go;

    # Get rid of remaining spaces, i.e. spaces in front of -'s and ('s
    $link =~ s/\s//go;

    $link ||= $topicObject->topic;

    # Topic defaults to the current topic
    my ( $web, $topic ) =
      $this->{session}->normalizeWebTopicName( $topicObject->web, $link );
    return $this->internalLink( $web, $topic, $text, $anchor, 1, undef,
        $hasExplicitLinkLabel );
}

# Handle an external link typed directly into text. If it's an image
# (as indicated by the file type), and no text is specified, then use
# an img tag, otherwise generate a link.
sub _externalLink {
    my ( $this, $url, $text ) = @_;

    if ( $url =~ /^[^?]*\.(gif|jpg|jpeg|png)$/i && !$text ) {
        my $filename = $url;
        $filename =~ s@.*/([^/]*)@$1@go;
        return CGI::img( { src => $url, alt => $filename } );
    }
    my $opt = '';
    if ( $url =~ /^mailto:/i ) {
        if ( $Foswiki::cfg{AntiSpam}{EmailPadding} ) {
            $url =~
              s/(\@[\w\_\-\+]+)(\.)/$1$Foswiki::cfg{AntiSpam}{EmailPadding}$2/;
            if ($text) {
                $text =~
s/(\@[\w\_\-\+]+)(\.)/$1$Foswiki::cfg{AntiSpam}{EmailPadding}$2/;
            }
        }
        if ( $Foswiki::cfg{AntiSpam}{HideUserDetails} ) {

            # Much harder obfuscation scheme. For link text we only encode '@'
            # See also Item2928 and Item3430 before touching this
            $url =~ s/(\W)/'&#'.ord($1).';'/ge;
            if ($text) {
                $text =~ s/\@/'&#'.ord('@').';'/ge;
            }
        }
    }
    else {
        $opt = ' target="_top"';
    }
    $text ||= $url;
    $url =~ s/ /%20/g
      ; #Item5787: if a url has spaces, escape them so the url has less chance of being broken by later parsing.
        # SMELL: Can't use CGI::a here, because it encodes ampersands in
        # the link, and those have already been encoded once in the
        # rendering loop (they are identified as "stand-alone"). One
        # encoding works; two is too many. None would be better for everyone!
    return '<a href="' . $url . '"' . $opt . '>' . $text . '</a>';
}

# Generate a "mailTo" link
sub _mailLink {
    my ( $this, $text ) = @_;

    my $url = $text;
    $url = 'mailto:' . $url unless $url =~ /^mailto:/i;
    return _externalLink( $this, $url, $text );
}

=begin TML

---++ ObjectMethod renderFORMFIELD ( %params, $topic, $web ) -> $html

Returns the fully rendered expansion of a %FORMFIELD{}% tag.

=cut

sub renderFORMFIELD {
    my ( $this, $params, $topicObject ) = @_;

    my $formField = $params->{_DEFAULT};
    return '' unless defined $formField;
    my $altText   = $params->{alttext};
    my $default   = $params->{default};
    my $rev       = $params->{rev} || '';
    my $format    = $params->{format};

    unless (defined $format) {
        $format = '$value';
    }

    # SMELL: this local creation of a cache looks very suspicious. Suspect
    # this may have been a one-off optimisation.
    my $formTopicObject = $this->{ffCache}{ $topicObject->getPath().$rev };
    unless ($formTopicObject) {
        $formTopicObject = Foswiki::Meta->load(
            $this->{session}, $topicObject->web, $topicObject->topic, $rev );
        unless ( $formTopicObject->haveAccess('VIEW') ) {

            # Access violation, create dummy meta with empty text, so
            # it looks like it was already loaded.
            $formTopicObject = Foswiki::Meta->new(
                $this->{session}, $topicObject->web, $topicObject->topic, '' );
        }
        $this->{ffCache}{ $formTopicObject->getPath().$rev } =
          $formTopicObject;
    }

    my $text   = Foswiki::expandStandardEscapes($format);
    my $found  = 0;
    my $title  = '';
    my @fields = $formTopicObject->find('FIELD');
    foreach my $field (@fields) {
        my $name = $field->{name};
        $title = $field->{title} || $name;
        if ( $title eq $formField || $name eq $formField ) {
            $found = 1;
            $text =~ s/\$title/$title/go;
            my $value = $field->{value};

            if ( !length($value) ) {
                $value = defined($default) ? $default : '';
            }
            $text =~ s/\$value/$value/go;
            $text =~ s/\$name/$name/g;
            if ( $text =~ m/\$form/ ) {
                my @defform = $formTopicObject->find('FORM');
                my $form  = $defform[0];     # only one form per topic
                my $fname = $form->{name};
                $text =~ s/\$form/$fname/g;
            }

            last;                            # one hit suffices
        }
    }

    unless ($found) {
        $text = $altText || '';
    }

    return $text;
}

=begin TML

---++ ObjectMethod getRenderedVersion ( $text, $topicObject ) -> $html

The main rendering function.

=cut

sub getRenderedVersion {
    my ( $this, $text, $topicObject ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;

    return '' unless $text;    # nothing to do

    my $session = $this->{session};
    my $plugins = $session->{plugins};
    my $prefs   = $session->{prefs};

    @{ $this->{LIST} } = ();

    # Initial cleanup
    $text =~ s/\r//g;

    # whitespace before <! tag (if it is the first thing) is illegal
    $text =~ s/^\s+(<![a-z])/$1/i;

    # clutch to enforce correct rendering at end of doc
    $text =~ s/\n?$/\n<nop>\n/s;

    # Maps of placeholders to tag parameters and text
    my $removed = {};

    # verbatim before literal - see Item3431
    $text = $this->takeOutBlocks( $text, 'verbatim', $removed );
    $text = $this->takeOutBlocks( $text, 'literal',  $removed );

    $text =
      $this->_takeOutProtected( $text, qr/<\?([^?]*)\?>/s, 'comment',
        $removed );
    $text =
      $this->_takeOutProtected( $text, qr/<!DOCTYPE([^<>]*)>?/mi, 'comment',
        $removed );
    $text =
      $this->_takeOutProtected( $text, qr/<head.*?<\/head>/si, 'head',
        $removed );
    $text = $this->_takeOutProtected( $text, qr/<textarea\b.*?<\/textarea>/si,
        'textarea', $removed );
    $text =
      $this->_takeOutProtected( $text, qr/<script\b.*?<\/script>/si, 'script',
        $removed );

    # DEPRECATED startRenderingHandler before PRE removed
    # SMELL: could parse more efficiently if this wasn't
    # here.
    $plugins->dispatch( 'startRenderingHandler', $text, $topicObject->web,
        $topicObject->topic );

    $text = $this->takeOutBlocks( $text, 'pre', $removed );

    # Join lines ending in '\' (don't need \r?, it was removed already)
    $text =~ s/\\\n//gs;

    $plugins->dispatch( 'preRenderingHandler', $text, $removed );

    if ( $plugins->haveHandlerFor('insidePREHandler') ) {
        foreach my $region ( sort keys %$removed ) {
            next unless ( $region =~ /^pre\d+$/i );
            my @lines = split( /\r?\n/, $removed->{$region}{text} );
            my $rt = '';
            while ( scalar(@lines) ) {
                my $line = shift(@lines);
                $plugins->dispatch( 'insidePREHandler', $line );
                if ( $line =~ /\n/ ) {
                    unshift( @lines, split( /\r?\n/, $line ) );
                    next;
                }
                $rt .= $line . "\n";
            }
            $removed->{$region}{text} = $rt;
        }
    }

    if ( $plugins->haveHandlerFor('outsidePREHandler') ) {

        # DEPRECATED - this is the one call preventing
        # effective optimisation of the TML processing loop,
        # as it exposes the concept of a 'line loop' to plugins,
        # but HTML is not a line-oriented language (though TML is).
        # But without it, a lot of processing could be moved
        # outside the line loop.
        my @lines = split( /\r?\n/, $text );
        my $rt = '';
        while ( scalar(@lines) ) {
            my $line = shift(@lines);
            $plugins->dispatch( 'outsidePREHandler', $line );
            if ( $line =~ /\n/ ) {
                unshift( @lines, split( /\r?\n/, $line ) );
                next;
            }
            $rt .= $line . "\n";
        }

        $text = $rt;
    }

    # Escape rendering: Change ' !AnyWord' to ' <nop>AnyWord',
    # for final ' AnyWord' output
    $text =~ s/$STARTWW\!(?=[\w\*\=])/<nop>/gm;

    # Blockquoted email (indented with '> ')
    # Could be used to provide different colours for different numbers of '>'
    $text =~ s/^>(.*?)$/'&gt;'.CGI::cite( $1 ).CGI::br()/gem;

    # locate isolated < and > and translate to entities
    # Protect isolated <!-- and -->
    $text =~ s/<!--/{$Foswiki::TranslationToken!--/g;
    $text =~ s/-->/--}$Foswiki::TranslationToken/g;

    # SMELL: this next fragment does not handle the case where HTML tags
    # are embedded in the values provided to other tags. The only way to
    # do this correctly is to parse the HTML (bleagh!). So we just assume
    # they have been escaped.
    $text =~
s/<(\/?\w+(:\w+)?)>/{$Foswiki::TranslationToken$1}$Foswiki::TranslationToken/g;
    $text =~
s/<(\w+(:\w+)?(\s+.*?|\/)?)>/{$Foswiki::TranslationToken$1}$Foswiki::TranslationToken/g;

    # XML processing instruction only valid at start of text
    $text =~
s/^<(\?\w.*?\?)>/{$Foswiki::TranslationToken$1}$Foswiki::TranslationToken/g;

    # entitify lone < and >, praying that we haven't screwed up :-(
    # Item1985: CDATA sections are not lone < and >
    $text =~ s/<(?!\!\[CDATA\[)/&lt\;/g;
    $text =~ s/(?<!\]\])>/&gt\;/g;
    $text =~ s/{$Foswiki::TranslationToken/</go;
    $text =~ s/}$Foswiki::TranslationToken/>/go;

    # standard URI - don't modify if url(http://as) form
    $text =~
s/(^|(?<!url)[-*\s(|])($Foswiki::regex{linkProtocolPattern}:([^\s<>"]+[^\s*.,!?;:)<|]))/$1._externalLink( $this,$2)/geo;

    # other entities
    $text =~ s/&(\w+);/$Foswiki::TranslationToken$1;/g;              # "&abc;"
    $text =~ s/&(#x?[0-9a-f]+);/$Foswiki::TranslationToken$1;/gi;    # "&#123;"
    $text =~ s/&/&amp;/g;    # escape standalone "&"
    $text =~ s/$Foswiki::TranslationToken(#x?[0-9a-f]+;)/&$1/goi;
    $text =~ s/$Foswiki::TranslationToken(\w+;)/&$1/go;

    # clear the set of unique anchornames in order to inhibit
    # the 'relabeling' of anchor names if the same topic is processed
    # more than once, cf. explanation in expandMacros()
    $this->_clearAnchorNames( $topicObject );

    # '#WikiName' anchors. Don't attempt to make these unique; renaming
    # user-defined anchors is not sensible.
    # SMELL: if a user-defined anchor gets renamed, it should be warned
    # about somewhere.
    $text =~ s/^(\#)($Foswiki::regex{wikiWordRegex})/
      CGI::a({
          name => $this->_makeAnchorName($2)
         }, '')/geom;

    # Headings
    # '<h6>...</h6>' HTML rule
    $text =~ s/$Foswiki::regex{headerPatternHt}/
      _makeAnchorHeading($this, $2, $1, $topicObject)/geo;

    # '----+++++++' rule
    $text =~ s/$Foswiki::regex{headerPatternDa}/
      _makeAnchorHeading($this, $2, length($1), $topicObject)/geo;

    # Horizontal rule
    my $hr = CGI::hr();
    $text =~ s/^---+/$hr/gm;

    # Now we really _do_ need a line loop, to process TML
    # line-oriented stuff.
    my $isList   = 0;    # True when within a list
    my $tableRow = 0;
    my @result;
    my $isFirst = 1;

    foreach my $line ( split( /\r?\n/, $text ) ) {

        # Table: | cell | cell |
        # allow trailing white space after the last |
        if ( $line =~ m/^(\s*)\|.*\|\s*$/ ) {
            unless ($tableRow) {

                # mark the head of the table
                push( @result, $TABLEMARKER );
            }
            $line =~ s/^(\s*)\|(.*)/$1._emitTR( $this, $2 )/e;
            $tableRow++;
        }
        elsif ($tableRow) {
            _addTHEADandTFOOT( \@result );
            push( @result, '</table>' );
            $tableRow = 0;
        }

        # Lists and paragraphs
        if ( $line =~ m/^\s*$/ ) {
            unless ( $tableRow || $isFirst ) {
                $line = '<p />';
            }
            $isList = 0;
        }
        elsif ( $line =~ m/^\S/ ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^(\t|   )+\S/ ) {
            if ( $line =~
                s/^((\t|   )+)\$\s(([^:]+|:[^\s]+)+?):\s/<dt> $3 <\/dt><dd> / )
            {

                # Definition list
                _addListItem( $this, \@result, 'dl', 'dd', $1 );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+)(\S+?):\s/<dt> $3<\/dt><dd> /o ) {

                # Definition list
                _addListItem( $this, \@result, 'dl', 'dd', $1 );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+)\* /<li> /o ) {

                # Unnumbered list
                _addListItem( $this, \@result, 'ul', 'li', $1 );
                $isList = 1;
            }
            elsif ( $line =~ m/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/ ) {

                # Numbered list
                my $ot = $3;
                $ot =~ s/^(.).*/$1/;
                if ( $ot !~ /^\d$/ ) {
                    $ot = ' type="' . $ot . '"';
                }
                else {
                    $ot = '';
                }
                $line =~ s/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/<li$ot> /;
                _addListItem( $this, \@result, 'ol', 'li', $1 );
                $isList = 1;
            }
            elsif ( $isList && $line =~ /^(\t|   )+\s*\S/ ) {

                # indented line extending prior list item
                push( @result, $line );
                next;
            }
            else {
                $isList = 0;
            }
        }
        elsif ( $isList && $line =~ /^(\t|   )+\s*\S/ ) {

            # indented line extending prior list item; case where indent
            # starts with is at least 3 spaces or a tab, but may not be a
            # multiple of 3.
            push( @result, $line );
            next;
        }

        # Finish the list
        unless ( $isList || $isFirst ) {
            _addListItem( $this, \@result, '', '', '' );
        }

        push( @result, $line );
        $isFirst = 0;
    }

    if ($tableRow) {
        _addTHEADandTFOOT( \@result );
        push( @result, '</table>' );
    }
    _addListItem( $this, \@result, '', '', '' );

    $text = join( '', @result );

    # <nop>WikiWords
    $text =~ s/${STARTWW}==(\S+?|\S[^\n]*?\S)==$ENDWW/_fixedFontText($1,1)/gem;
    $text =~
s/${STARTWW}__(\S+?|\S[^\n]*?\S)__$ENDWW/<strong><em>$1<\/em><\/strong>/gm;
    $text =~ s/${STARTWW}\*(\S+?|\S[^\n]*?\S)\*$ENDWW/<strong>$1<\/strong>/gm;
    $text =~ s/${STARTWW}\_(\S+?|\S[^\n]*?\S)\_$ENDWW/<em>$1<\/em>/gm;
    $text =~ s/${STARTWW}\=(\S+?|\S[^\n]*?\S)\=$ENDWW/_fixedFontText($1,0)/gem;

    # Mailto
    # Email addresses must always be 7-bit, even within I18N sites

    # Normal mailto:foo@example.com ('mailto:' part optional)
    $text =~
s/$STARTWW((mailto\:)?$Foswiki::regex{emailAddrRegex})$ENDWW/_mailLink( $this, $1 )/gem;

# Handle [[][] and [[]] links
# Escape rendering: Change ' ![[...' to ' [<nop>[...', for final unrendered ' [[...' output
    $text =~ s/(^|\s)\!\[\[/$1\[<nop>\[/gm;

    # Spaced-out Wiki words with alternative link text
    # i.e. [[$1][$3]]
    $text =~
s/\[\[([^\]\[\n]+)\](\[([^\]\n]+)\])?\]/_handleSquareBracketedLink( $this,$topicObject,$1,$3)/ge;

    unless ( Foswiki::isTrue( $prefs->getPreference('NOAUTOLINK') ) ) {

        # Handle WikiWords
        $text = $this->takeOutBlocks( $text, 'noautolink', $removed );
        $text =~
s/$STARTWW(?:($Foswiki::regex{webNameRegex})\.)?($Foswiki::regex{wikiWordRegex}|$Foswiki::regex{abbrevRegex})($Foswiki::regex{anchorRegex})?/_handleWikiWord( $this, $topicObject, $1, $2, $3)/geom;
        $this->putBackBlocks( \$text, $removed, 'noautolink' );
    }

    $this->putBackBlocks( \$text, $removed, 'pre' );

    # DEPRECATED plugins hook after PRE re-inserted
    $plugins->dispatch( 'endRenderingHandler', $text );

    # replace verbatim with pre in the final output
    $this->putBackBlocks( \$text, $removed, 'verbatim', 'pre',
        \&verbatimCallBack );
    $text =~ s|\n?<nop>\n$||o;    # clean up clutch

    $this->_putBackProtected( \$text, 'script', $removed, \&_filterScript );
    $this->putBackBlocks( \$text, $removed, 'literal', '', \&_filterLiteral );

    $this->_putBackProtected( \$text, 'literal',  $removed );
    $this->_putBackProtected( \$text, 'comment',  $removed );
    $this->_putBackProtected( \$text, 'head',     $removed );
    $this->_putBackProtected( \$text, 'textarea', $removed );

    $this->{session}->{users}->{loginManager}->endRenderingHandler($text);

    $plugins->dispatch( 'postRenderingHandler', $text );
    return $text;
}

=begin TML

---++ StaticMethod verbatimCallBack

Callback for use with putBackBlocks that replaces &lt; and >
by their HTML entities &amp;lt; and &amp;gt;

=cut

sub verbatimCallBack {
    my $val = shift;

    # SMELL: A shame to do this, but been in Foswiki.org have converted
    # 3 spaces to tabs since day 1
    $val =~ s/\t/   /g;

    return Foswiki::entityEncode($val);
}

# Only put script and literal sections back if they are allowed by options
sub _filterLiteral {
    my $val = shift;
    return $val if ( $Foswiki::cfg{AllowInlineScript} );
    return CGI::comment('<literal> is not allowed on this site');
}

sub _filterScript {
    my $val = shift;
    return $val if ( $Foswiki::cfg{AllowInlineScript} );
    return CGI::comment('<script> is not allowed on this site');
}

=begin TML

---++ ObjectMethod TML2PlainText( $text, $topicObject, $opts ) -> $plainText

Clean up TML for display as plain text without pushing it
through the full rendering pipeline. Intended for generation of
topic and change summaries. Adds nop tags to prevent
subsequent rendering; nops get removed at the very end.

Defuses TML.

$opts:
   * showvar - shows !%VAR% names if not expanded
   * expandvar - expands !%VARS%
   * nohead - strips ---+ headings at the top of the text
   * showmeta - does not filter meta-data

=cut

sub TML2PlainText {
    my ( $this, $text, $topicObject, $opts ) = @_;
    $opts ||= '';

    $text =~ s/\r//g;    # SMELL, what about OS10?

    if ( $opts =~ /showmeta/ ) {
        $text =~ s/%META:/%<nop>META:/g;
    }
    else {
        $text =~ s/%META:[A-Z].*?}%//g;
    }

    if ( $opts =~ /expandvar/ ) {
        $text =~ s/(\%)(SEARCH){/$1<nop>$2/g;    # prevent recursion
        $topicObject = Foswiki::Meta->new( $this->{session} )
          unless $topicObject;
        $text = $topicObject->expandMacros($text);
    }
    else {
        $text =~ s/%WEB%/$topicObject->web() || ''/ge;
        $text =~ s/%TOPIC%/$topicObject->topic() || ''/ge;
        my $wtn = $this->{session}->{prefs}->getPreference('WIKITOOLNAME')
          || '';
        $text =~ s/%WIKITOOLNAME%/$wtn/g;
        if ( $opts =~ /showvar/ ) {
            $text =~ s/%(\w+({.*?}))%/$1/g;      # defuse
        }
        else {
            $text =~ s/%$Foswiki::regex{tagNameRegex}({.*?})?%//g;    # remove
        }
    }

    # Format e-mail to add spam padding (HTML tags removed later)
    $text =~
s/$STARTWW((mailto\:)?[a-zA-Z0-9-_.+]+@[a-zA-Z0-9-_.]+\.[a-zA-Z0-9-_]+)$ENDWW/_mailLink( $this, $1 )/gem;
    $text =~ s/<!--.*?-->//gs;       # remove all HTML comments
    $text =~ s/<(?!nop)[^>]*>//g;    # remove all HTML tags except <nop>
    $text =~ s/\&[a-z]+;/ /g;        # remove entities
    if ( $opts =~ /nohead/ ) {

        # skip headings on top
        while ( $text =~ s/^\s*\-\-\-+\+[^\n\r]*// ) { };    # remove heading
    }

    # keep only link text of legacy [[prot://uri.tld/ link text]]
    $text =~ s/
            \[
                \[$Foswiki::regex{linkProtocolPattern}\:
                    ([^\s<>"\]]+[^\s*.,!?;:)<|\]])
                        \s+([^\[\]]*?)
                \]
            \]/$3/gx;

    #keep only test portion of [[][]] links
    $text =~ s/\[\[([^\]]*\]\[)(.*?)\]\]/$2/g;

    # remove "Web." prefix from "Web.TopicName" link
    $text =~
s/$STARTWW(($Foswiki::regex{webNameRegex})\.($Foswiki::regex{wikiWordRegex}|$Foswiki::regex{abbrevRegex}))/$3/g;
    $text =~ s/[\[\]\*\|=_\&\<\>]/ /g;    # remove Wiki formatting chars
    $text =~ s/^\-\-\-+\+*\s*\!*/ /gm;    # remove heading formatting and hbar
    $text =~ s/[\+\-]+/ /g;               # remove special chars
    $text =~ s/^\s+//;                    # remove leading whitespace
    $text =~ s/\s+$//;                    # remove trailing whitespace
    $text =~ s/!(\w+)/$1/gs;    # remove all nop exclamation marks before words
    $text =~ s/[\r\n]+/\n/s;
    $text =~ s/[ \t]+/ /s;

    return $text;
}

=begin TML

---++ ObjectMethod protectPlainText($text) -> $tml

Protect plain text from expansions that would normally be done
duing rendering, such as wikiwords. Topic summaries, for example,
have to be protected this way.

=cut

sub protectPlainText {
    my ( $this, $text ) = @_;

# prevent text from getting rendered in inline search and link tool
# tip text by escaping links (external, internal, Interwiki)
#    $text =~ s/(?<=[\s\(])((($Foswiki::regex{webNameRegex})\.)?($Foswiki::regex{wikiWordRegex}|$Foswiki::regex{abbrevRegex}))/<nop>$1/g;
#    $text =~ s/(^|(<=\W))((($Foswiki::regex{webNameRegex})\.)?($Foswiki::regex{wikiWordRegex}|$Foswiki::regex{abbrevRegex}))/<nop>$1/g;
    $text =~
s/((($Foswiki::regex{webNameRegex})\.)?($Foswiki::regex{wikiWordRegex}|$Foswiki::regex{abbrevRegex}))/<nop>$1/g;

 #    $text =~ s/(?<=[\s\(])($Foswiki::regex{linkProtocolPattern}\:)/<nop>$1/go;
 #    $text =~ s/(^|(<=\W))($Foswiki::regex{linkProtocolPattern}\:)/<nop>$1/go;
    $text =~ s/($Foswiki::regex{linkProtocolPattern}\:)/<nop>$1/go;
    $text =~ s/([@%])/<nop>$1<nop>/g;    # email address, variable

    # Encode special chars into XML &#nnn; entities for use in RSS feeds
    # - no encoding for HTML pages, to avoid breaking international
    # characters. Only works for ISO-8859-1 sites, since the Unicode
    # encoding (&#nnn;) is identical for first 256 characters.
    # I18N TODO: Convert to Unicode from any site character set.
    if (   $this->{session}->inContext('rss')
        && defined( $Foswiki::cfg{Site}{CharSet} )
        && $Foswiki::cfg{Site}{CharSet} =~ /^iso-?8859-?1$/i )
    {
        $text =~ s/([\x7f-\xff])/"\&\#" . unpack( 'C', $1 ) .';'/ge;
    }

    return $text;
}

# DEPRECATED: retained for compatibility with various hack-job extensions
sub makeTopicSummary {
    my ( $this, $text, $topic, $web, $flags ) = @_;
    my $topicObject = Foswiki::Meta->new( $this->{session}, $web, $topic );
    return $topicObject->summariseText( '', $text );
}

# _takeOutProtected( \$text, $re, $id, \%map ) -> $text
#
#   * =$text= - Text to process
#   * =$re= - Regular expression that matches tag expressions to remove
#   * =\%map= - Reference to a hash to contain the removed blocks
#
# Return value: $text with blocks removed. Unlike takeOuBlocks, this
# *preserves* the tags.
#
# used to extract from $text comment type tags like &lt;!DOCTYPE blah>
#
# WARNING: if you want to take out &lt;!-- comments --> you _will_ need
# to re-write all the takeOuts to use a different placeholder
sub _takeOutProtected {
    my ( $this, $intext, $re, $id, $map ) = @_;

    $intext =~ s/($re)/_replaceBlock($1, $id, $map)/ge;

    return $intext;
}

sub _replaceBlock {
    my ( $scoop, $id, $map ) = @_;
    my $placeholder = $placeholderMarker;
    $placeholderMarker++;
    $map->{ $id . $placeholder }{text} = $scoop;

    return
        '<!--'
      . $Foswiki::TranslationToken
      . $id
      . $placeholder
      . $Foswiki::TranslationToken . '-->';
}

# _putBackProtected( \$text, $id, \%map, $callback ) -> $text
# Return value: $text with blocks added back
#   * =\$text= - reference to text to process
#   * =$id= - type of taken-out block e.g. 'verbatim'
#   * =\%map= - map placeholders to blocks removed by takeOutBlocks
#   * =$callback= - Reference to function to call on each block being inserted (optional)
#
#Reverses the actions of takeOutProtected.
sub _putBackProtected {
    my ( $this, $text, $id, $map, $callback ) = @_;
    ASSERT( ref($map) eq 'HASH' ) if DEBUG;

    foreach my $placeholder ( keys %$map ) {
        next unless $placeholder =~ /^$id\d+$/;
        my $val = $map->{$placeholder}{text};
        $val = &$callback($val) if ( defined($callback) );
        $$text =~
s/<!--$Foswiki::TranslationToken$placeholder$Foswiki::TranslationToken-->/$val/;
        delete( $map->{$placeholder} );
    }
}

=begin TML

---++ ObjectMethod takeOutBlocks( \$text, $tag, \%map ) -> $text

   * =$text= - Text to process
   * =$tag= - XHTML-style tag.
   * =\%map= - Reference to a hash to contain the removed blocks

Return value: $text with blocks removed

Searches through $text and extracts blocks delimited by a tag, appending each
onto the end of the @buffer and replacing with a token
string which is not affected by TML rendering.  The text after these
substitutions is returned.

Parameters to the open tag are recorded.

This is _different_ to takeOutProtected, because it requires tags
to be on their own line. it also supports a callback for post-
processing the data before re-insertion.

=cut

sub takeOutBlocks {
    my ( $this, $intext, $tag, $map ) = @_;

    return $intext unless ( $intext =~ m/<$tag\b/i );

    my $out   = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;

    foreach my $token ( split /(<\/?$tag[^>]*>)/i, $intext ) {
        if ( $token =~ /<$tag\b([^>]*)?>/i ) {
            $depth++;
            if ( $depth eq 1 ) {
                $tagParams = $1;
                next;
            }
        }
        elsif ( $token =~ /<\/$tag>/i ) {
            if ( $depth > 0 ) {
                $depth--;
                if ( $depth eq 0 ) {
                    my $placeholder = $tag . $placeholderMarker;
                    $placeholderMarker++;
                    $map->{$placeholder}{text}   = $scoop;
                    $map->{$placeholder}{params} = $tagParams;
                    $out .= '<!--'
                      . $Foswiki::TranslationToken
                      . $placeholder
                      . $Foswiki::TranslationToken . '-->';
                    $scoop = '';
                    next;
                }
            }
        }
        if ( $depth > 0 ) {
            $scoop .= $token;
        }
        else {
            $out .= $token;
        }
    }

    # unmatched tags
    if ( defined($scoop) && ( $scoop ne '' ) ) {
        my $placeholder = $tag . $placeholderMarker;
        $placeholderMarker++;
        $map->{$placeholder}{text}   = $scoop;
        $map->{$placeholder}{params} = $tagParams;
        $out .= '<!--'
          . $Foswiki::TranslationToken
          . $placeholder
          . $Foswiki::TranslationToken . '-->';
    }

    return $out;
}

=begin TML

---++ ObjectMethod putBackBlocks( \$text, \%map, $tag, $newtag, $callBack ) -> $text

Return value: $text with blocks added back
   * =\$text= - reference to text to process
   * =\%map= - map placeholders to blocks removed by takeOutBlocks
   * =$tag= - Tag name processed by takeOutBlocks
   * =$newtag= - Tag name to use in output, in place of $tag. If undefined, uses $tag.
   * =$callback= - Reference to function to call on each block being inserted (optional)

Reverses the actions of takeOutBlocks.

Each replaced block is processed by the callback (if there is one) before
re-insertion.

Parameters to the outermost cut block are replaced into the open tag,
even if that tag is changed. This allows things like
&lt;verbatim class=''>
to be mapped to
&lt;pre class=''>

Cool, eh what? Jolly good show.

And if you set $newtag to '', we replace the taken out block with the value itself
   * which i'm using to stop the rendering process, but then at the end put in the html directly
   (for &lt;literal> tag.

=cut

sub putBackBlocks {
    my ( $this, $text, $map, $tag, $newtag, $callback ) = @_;

    $newtag = $tag if ( !defined($newtag) );

    foreach my $placeholder ( keys %$map ) {
        if ( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params} || '';
            my $val = $map->{$placeholder}{text};
            $val = &$callback($val) if ( defined($callback) );
            if ( $newtag eq '' ) {
                $$text =~
s(<!--$Foswiki::TranslationToken$placeholder$Foswiki::TranslationToken-->)($val);
            }
            else {
                $$text =~
s(<!--$Foswiki::TranslationToken$placeholder$Foswiki::TranslationToken-->)
              	(<$newtag$params>$val</$newtag>);
            }
            delete( $map->{$placeholder} );
        }
    }
}

=begin TML

---++ ObjectMethod renderRevisionInfo($topicObject, $rev, $format) -> $string

Obtain and render revision info for a topic.
   * =$topicObject= - the topic
   * =$rev= - the rev number, defaults to latest rev
   * =$format= - the render format, defaults to =$rev - $time - $wikiusername=
=$format= can contain the following keys for expansion:
   | =$web= | the web name |
   | =$topic= | the topic name |
   | =$rev= | the rev number |
   | =$comment= | the comment |
   | =$username= | the login of the saving user |
   | =$wikiname= | the wikiname of the saving user |
   | =$wikiusername= | the web.wikiname of the saving user |
   | =$date= | the date of the rev (no time) |
   | =$time= | the time of the rev |
   | =$min=, =$sec=, etc. | Same date format qualifiers as GMTIME |

=cut

sub renderRevisionInfo {
    my ( $this, $topicObject, $rrev, $format ) = @_;

    my $users = $this->{session}->{users};
    if ($rrev) {
        $rrev = Foswiki::Store::cleanUpRevID($rrev);
        $topicObject->reload($rrev)
          unless $rrev == $topicObject->getLoadedRev();
    }
    my $info = $topicObject->getRevisionInfo();

    my $wun = '';
    my $wn  = '';
    my $un  = '';
    if ( $info->{author} ) {
        my $cUID = $users->getCanonicalUserID( $info->{author} );
        if ( !$cUID ) {
            my $ln = $users->getLoginName( $info->{author} );
            $cUID = $info->{author} if defined $ln && $ln ne 'unknown';
        }
        if ($cUID) {
            $wun = $users->webDotWikiName($cUID);
            $wn  = $users->getWikiName($cUID);
            $un  = $users->getLoginName($cUID);
        }

        # If we are still unsure, then use whatever is saved in the meta.
        # But obscure it if the RenderLoggedInButUnknownUsers is enabled.
        $info->{author} = 'unknown'
          if $Foswiki::cfg{RenderLoggedInButUnknownUsers};
        $wun ||= $info->{author};
        $wn  ||= $info->{author};
        $un  ||= $info->{author};
    }

    my $value = $format || 'r$rev - $date - $time - $wikiusername';
    $value =~ s/\$web/$topicObject->web() || ''/gei;
    $value =~ s/\$topic/$topicObject->topic() || ''/gei;
    $value =~ s/\$rev/$info->{version}/gi;
    $value =~ s/\$time/
      Foswiki::Time::formatTime($info->{date}, '$hour:$min:$sec')/gei;
    $value =~ s/\$date/
      Foswiki::Time::formatTime(
          $info->{date}, $Foswiki::cfg{DefaultDateFormat} )/gei;
    $value =~ s/(\$(rcs|http|email|iso))/
      Foswiki::Time::formatTime($info->{date}, $1 )/gei;

    if ( $value =~ /\$(sec|min|hou|day|wday|dow|week|mo|ye|epoch|tz)/ ) {
        $value = Foswiki::Time::formatTime( $info->{date}, $value );
    }
    $value =~ s/\$comment/$info->{comment}/gi;
    $value =~ s/\$username/$un/gi;
    $value =~ s/\$wikiname/$wn/gi;
    $value =~ s/\$wikiusername/$wun/gi;

    return $value;
}

=begin TML

---++ ObjectMethod forEachLine( $text, \&fn, \%options ) -> $newText

Iterate over each line, calling =\&fn= on each.
\%options may contain:
   * =pre= => true, will call fn for each line in pre blocks
   * =verbatim= => true, will call fn for each line in verbatim blocks
   * =literal= => true, will call fn for each line in literal blocks
   * =noautolink= => true, will call fn for each line in =noautolink= blocks
The spec of \&fn is =sub fn( $line, \%options ) -> $newLine=. The %options
hash passed into this function is passed down to the sub, and the keys
=in_literal=, =in_pre=, =in_verbatim= and =in_noautolink= are set boolean
TRUE if the line is from one (or more) of those block types.

The return result replaces $line in $newText.

=cut

sub forEachLine {
    my ( $this, $text, $fn, $options ) = @_;

    $options->{in_pre}        = 0;
    $options->{in_pre}        = 0;
    $options->{in_verbatim}   = 0;
    $options->{in_literal}    = 0;
    $options->{in_noautolink} = 0;
    my $newText = '';
    foreach my $line ( split( /([\r\n]+)/, $text ) ) {
        if ( $line =~ /[\r\n]/ ) {
            $newText .= $line;
            next;
        }
        $options->{in_verbatim}++ if ( $line =~ m|^\s*<verbatim\b[^>]*>\s*$|i );
        $options->{in_verbatim}-- if ( $line =~ m|^\s*</verbatim>\s*$|i );
        $options->{in_literal}++  if ( $line =~ m|^\s*<literal\b[^>]*>\s*$|i );
        $options->{in_literal}--  if ( $line =~ m|^\s*</literal>\s*$|i );
        unless ( ( $options->{in_verbatim} > 0 )
            || ( ( $options->{in_literal} > 0 ) ) )
        {
            $options->{in_pre}++ if ( $line =~ m|<pre\b|i );
            $options->{in_pre}-- if ( $line =~ m|</pre>|i );
            $options->{in_noautolink}++
              if ( $line =~ m|^\s*<noautolink\b[^>]*>\s*$|i );
            $options->{in_noautolink}--
              if ( $line =~ m|^\s*</noautolink>\s*|i );
        }
        unless ( $options->{in_pre} > 0 && !$options->{pre}
            || $options->{in_verbatim} > 0   && !$options->{verbatim}
            || $options->{in_literal} > 0    && !$options->{literal}
            || $options->{in_noautolink} > 0 && !$options->{noautolink} )
        {
            $line = &$fn( $line, $options );
        }
        $newText .= $line;
    }
    return $newText;
}

=begin TML

---++ StaticMethod getReferenceRE($web, $topic, %options) -> $re

   * $web, $topic - specify the topic being referred to, or web if $topic is
     undef.
   * %options - the following options are available
      * =interweb= - if true, then fully web-qualified references are required.
      * =grep= - if true, generate a GNU-grep compatible RE instead of the
        default Perl RE.
      * =url= - if set, generates an expression that will match a Foswiki
        URL that points to the web/topic, instead of the default which
        matches topic links in plain text.
Generate a regular expression that can be used to match references to the
specified web/topic. Note that the resultant RE will only match fully
qualified (i.e. with web specifier) topic names and topic names that
are wikiwords in text. Works for spaced-out wikiwords for topic names.

The RE returned is designed to be used with =s///=

=cut

sub getReferenceRE {
    my ( $web, $topic, %options ) = @_;

    my $matchWeb = $web;

    # Convert . and / to [./] (subweb separators)
    $matchWeb =~ s#[./]#[./]#go;

    # Note use of \< and \> to match the empty string at the
    # edges of a word.
    my ( $bow, $eow, $forward, $back ) = ( '\b', '\b', '?=', '?<=' );
    if ( $options{grep} ) {
        $bow     = '\<';
        $eow     = '\>';
        $forward = '';
        $back    = '';
    }
    my $squabo = "($back\\[\\[)";
    my $squabc = "($forward\\][][])";

    my $re;

    if ( $options{url} ) {

        # URL fragment. Assume / separator (while . is legal, it's
        # undocumented and is not common usage)
        $re = "/$web/";
        $re .= $topic . $eow if $topic;
    }
    else {
        if ( defined($topic) ) {

            # Work out spaced-out version (allows lc first chars on words)
            my $sot = Foswiki::spaceOutWikiWord( $topic, ' *' );
            if ( $sot ne $topic ) {
                $sot =~ s/\b([a-zA-Z])/'['.uc($1).lc($1).']'/ge;
            }
            else {
                $sot = undef;
            }

            if ( $options{interweb} ) {

                # Require web specifier
                $re = "$bow$matchWeb\\.$topic$eow";
                if ($sot) {

                    # match spaced out in squabs only
                    $re .= "|$squabo$matchWeb\\.$sot$squabc";
                }
            }
            else {

                # Optional web specifier - but *only* if the topic name
                # is a wikiword
                if ( $topic =~ /$Foswiki::regex{wikiWordRegex}/ ) {

                    # Bit of jigger-pokery at the front to avoid matching
                    # subweb specifiers
                    $re = "(($back\[^./])|^)$bow($matchWeb\\.)?$topic$eow";
                    if ($sot) {

                        # match spaced out in squabs only
                        $re .= "|$squabo($matchWeb\\.)?$sot$squabc";
                    }
                }
                else {

                    # Non-wikiword; require web specifier or squabs
                    $re = "(($back\[^./])|^)$bow$matchWeb\\.$topic$eow";
                    $re .= "|$squabo$topic$squabc";
                }
            }
        }
        else {

            # Searching for a web
            if ( $options{interweb} ) {

                # web name used to refer to a topic
                $re =
                    $bow
                  . $matchWeb
                  . "(\.[$Foswiki::regex{mixedAlphaNum}]+)"
                  . $eow;
            }
            else {

                # most general search for a reference to a topic or subweb
                # note that Foswiki::UI::Rename::_replaceWebReferences()
                # uses $1 from this regex
                $re =
                    $bow
                  . $matchWeb
                  . "(([\/\.][$Foswiki::regex{upperAlpha}][$Foswiki::regex{mixedAlphaNum}_]*)*"
                  . "\.[$Foswiki::regex{mixedAlphaNum}]+)"
                  . $eow;
            }
        }
    }
    return $re;
}

=begin TML

---++ StaticMethod breakName( $text, $args) -> $text

   * =$text= - text to "break"
   * =$args= - string of format (\d+)([,\s*]\.\.\.)?)
Hyphenates $text every $1 characters, or if $2 is "..." then shortens to
$1 characters and appends "..." (making the final string $1+3 characters
long)

_Moved from Search.pm because it was obviously unhappy there,
as it is a rendering function_

=cut

sub breakName {
    my ( $text, $args ) = @_;

    my @params = split( /[\,\s]+/, $args, 2 );
    if (@params) {
        my $len = $params[0] || 1;
        $len = 1 if ( $len < 1 );
        my $sep = '- ';
        $sep = $params[1] if ( @params > 1 );
        if ( $sep =~ /^\.\.\./i ) {

            # make name shorter like 'ThisIsALongTop...'
            $text =~ s/(.{$len})(.+)/$1.../s;

        }
        else {

            # split and hyphenate the topic like 'ThisIsALo- ngTopic'
            $text =~ s/(.{$len})/$1$sep/gs;
            $text =~ s/$sep$//;
        }
    }
    return $text;
}

=begin TML

---++ StaticMethod protectFormFieldValue($value, $attrs) -> $html

Given the value of a form field, and a set of attributes that control how
to display that value, protect the value from further processing.

The protected value is determined from the value of the field after:
   * newlines are replaced with &lt;br> or the value of $attrs->{newline}
   * processing through breakName if $attrs->{break} is defined
   * escaping of $vars if $attrs->{protectdollar} is defined
   * | is replaced with &amp;#124; or the value of $attrs->{bar} if defined

=cut

sub protectFormFieldValue {
    my ( $value, $attrs ) = @_;

    $value = '' unless defined($value);

    if ( $attrs && $attrs->{break} ) {
        $value =~ s/^\s*(.*?)\s*$/$1/g;
        $value = breakName( $value, $attrs->{break} );
    }

    # Item3489, Item2837. Prevent $vars in formfields from
    # being expanded in formatted searches.
    if ( $attrs && $attrs->{protectdollar} ) {
        $value =~ s/\$(n|nop|quot|percnt|dollar)/\$<nop>$1/g;
    }

    # change newlines
    my $newline = '<br />';
    if ( $attrs && defined $attrs->{newline} ) {
        $newline = $attrs->{newline};
        $newline =~ s/\$n/\n/gs;
    }
    $value =~ s/\r?\n/$newline/gs;

    # change vbars
    my $bar = '&#124;';
    if ( $attrs && $attrs->{bar} ) {
        $bar = $attrs->{bar};
    }
    $value =~ s/\|/$bar/g;

    return $value;
}

=begin TML

---++ ObjectMethod renderTOC( $text, $topicObject, $args ) -> $text

Extract headings from $text and render them as a TOC table.
   * =$text= - the text to extract the TOC from.
   * =$topicObject= - the topic that is the context we are going to place the TOC in
   * =$args= - Foswiki::Attrs of args to the %TOC tag (see System.VarTOC2)

SMELL: this is _not_ a tag handler in the sense of other builtin tags,
because it requires far more context information (the text of the topic)
than any handler.

SMELL: as a tag handler that also semi-renders the topic to extract the
headings, this handler would be much better as a preRenderingHandler in
a plugin (where head and script sections are already protected)

=cut

sub renderTOC {
    my ( $this, $text, $topicObject, $params, $isSameTopic ) = @_;
    ASSERT( UNIVERSAL::isa( $topicObject, 'Foswiki::Meta' ) )  if DEBUG;
    ASSERT( UNIVERSAL::isa( $params,      'Foswiki::Attrs' ) ) if DEBUG;
    my $session = $this->{session};

    my ( $defaultWeb, $defaultTopic ) =
      ( $topicObject->web, $topicObject->topic );

    my $topic = $params->{_DEFAULT} || $defaultTopic;
    $defaultWeb =~ s#/#.#g;
    my $web = $params->{web} || $defaultWeb;

    # throw away <verbatim> and <pre> blocks
    my %junk;
    $text = $this->takeOutBlocks( $text, 'verbatim', \%junk );
    $text = $this->takeOutBlocks( $text, 'pre',      \%junk );

    my $maxDepth = $params->{depth};
    $maxDepth ||= $session->{prefs}->getPreference('TOC_MAX_DEPTH')
      || 6;
    my $minDepth = $session->{prefs}->getPreference('TOC_MIN_DEPTH')
      || 1;

    # get the title attribute
    my $title =
         $params->{title}
      || $session->{prefs}->getPreference('TOC_TITLE')
      || '';
    $title = CGI::span( { class => 'foswikiTocTitle' }, $title ) if ($title);

    my $highest  = 99;
    my $result   = '';
    my $verbatim = {};
    $text = $this->takeOutBlocks( $text, 'verbatim', $verbatim );
    $text = $this->takeOutBlocks( $text, 'pre',      $verbatim );

    # Find URL parameters
    my $query   = $session->{request};
    my @qparams = ();
    foreach my $name ( $query->param ) {
        next if ( $name eq 'keywords' );
        next if ( $name eq 'topic' );
        next if ( $name eq 'text' );
        push @qparams, $name => $query->param($name);
    }

    # Extract anchor targets. This has to generate *identical* anchor
    # targets to normal rendering.


    # clear the set of unique anchornames in order to inhibit
    # the 'relabeling' of anchor names if the same topic is processed
    # more than once, cf. explanation in expandMacros()
    $this->_clearAnchorNames( $topicObject );

    # NB: While we're processing $text line by line here,
    # getRendereredVersion() 'allocates' unique anchor
    # names by first replacing regex{headerPatternHt} followed by
    # regex{headerPatternDa}. We have to adhere to this
    # order here as well.
    my @regexps = (
        $Foswiki::regex{headerPatternHt},
        $Foswiki::regex{headerPatternDa}
    );
    my @lines    = split( /\r?\n/, $text );
    my @targets;
    my $lineno = 0;
  LINE: foreach my $line (@lines) {
        $lineno++;
        for my $i ( 0 .. $#regexps ) {
            if ( $line =~ m/$regexps[$i]/ ) {
                # c.f. _makeAnchorHeading
                my ( $level, $text ) = ( $1, $2 );
                $text =~ s/^\s*(.*?)\s*$/$1/;

                my $atext = $text;
                $text =~ s/\s*$Foswiki::regex{headerPatternNoTOC}.*//o;
                # Ignore empty headings
                next unless $text;

                # $i == 1 is $Foswiki::regex{headerPatternDa}
                $level = length( $level ) if ( $i == 1 );
                if ( ( $level >= $minDepth ) && ( $level <= $maxDepth ) ) {
                    my $anchor = $this->_makeAnchorNameUnique(
                        $topicObject, $this->_makeAnchorName( $atext ));
                    my $target = {
                        anchor => $anchor,
                        text   => $text,
                        level  => $level,
                    };
                    push(@targets, $target);

                    next LINE;
                }
            }
        }
    }

    foreach my $a ( @targets ) {
        my $text = $a->{text};
        $highest = $a->{level} if ( $a->{level} < $highest );
        my $tabs = "\t" x $a->{level};

        # Remove *bold*, _italic_ and =fixed= formatting
        $text =~
s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
        $text =~
s/(^|[\s\(])_+([^\s]+?|[^\s].*?[^\s])_+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
        $text =~
s/(^|[\s\(])=+([^\s]+?|[^\s].*?[^\s])=+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;

        # Prevent WikiLinks
        $text =~ s/\[\[.*?\]\[(.*?)\]\]/$1/g;    # '[[...][...]]'
        $text =~ s/\[\[(.*?)\]\]/$1/ge;          # '[[...]]'
        $text =~
s/([\s\(])($Foswiki::regex{webNameRegex})\.($Foswiki::regex{wikiWordRegex})/$1<nop>$3/go
          ;                                      # 'Web.TopicName'
        $text =~
          s/([\s\(])($Foswiki::regex{wikiWordRegex})/$1<nop>$2/go; # 'TopicName'
        $text =~ s/([\s\(])($Foswiki::regex{abbrevRegex})/$1<nop>$2/go;  # 'TLA'
        $text =~
          s/([\s\-\*\(])([$Foswiki::regex{mixedAlphaNum}]+\:)/$1<nop>$2/go
          ;    # 'Site:page' Interwiki link
               # Prevent manual links
        $text =~ s/<[\/]?a\b[^>]*>//gi;

        # create linked bullet item, using a relative link to anchor
        my $target =
          $isSameTopic
          ? Foswiki::_make_params( 0, '#' => $a->{anchor}, @qparams )
          : $this->{session}->getScriptUrl(
            0, 'view', $topicObject->web, $topicObject->topic,
            '#' => $a->{anchor},
            @qparams
          );
        $text = $tabs . '* ' . CGI::a( { href => $target }, $text );
        $result .= "\n" . $text;
    }

    if ($result) {
        if ( $highest > 1 ) {

            # left shift TOC
            $highest--;
            $result =~ s/^\t{$highest}//gm;
        }

        # add a anchor to be able to jump to the toc and add a outer div
        return CGI::a( { name => 'foswikiTOC' }, '' )
          . CGI::div( { class => 'foswikiToc' }, "$title$result\n" );

    }
    else {
        return '';
    }
}

# Clear anchor names in the given topic. This is so that the same anchor
# names can be generated for each time the same topic is %INCLUDEd (the
# same anchor target will be generated for each time the topic is included.
# C'est la vie.
sub _clearAnchorNames {
    my ($this, $topicObject) = @_;
    $this->{_anchorNames}{$topicObject->getPath()} = ();
}

# Generate a unique name for an anchor in the given topic
#
# Note that anchor names generated this way are unique since the last call
# to clearAnchorNames for the given topic. The anchor names are cleared
# (1) whenever a new session is started and (2) whenever a new %TOC macro
# is rendered.
sub _makeAnchorNameUnique {
    my ($this, $topicObject, $anchorName) = @_;
    my $cnt    = 1;
    my $suffix = '';
    my $context = $topicObject->getPath();
    $this->{_anchorNames}{$context} ||= ();
    while ( exists $this->{_anchorNames}{$context}{$anchorName.$suffix} ) {

        # $anchorName.$suffix must _always_ be 'compatible', or things
        # would get complicated (whatever that means)
        $suffix = '_AN' . $cnt++;

        # limit resulting name to 32 chars
        $anchorName = substr( $anchorName, 0, 32 - length($suffix) );

        # this is only needed because '__' would not be 'compatible'
        $anchorName =~ s/_+$//g;
    }
    $anchorName .= $suffix;
    $this->{_anchorNames}{$context}{$anchorName} = 1;
    return $anchorName;
}

=begin TML

---++ ObjectMethod renderIconImage($url [, $alt]) -> $html
Generate the output for representing an 16x16 icon image. The source of
the image is taken from =$url=. The optional =$alt= specifies an alt string.

=cut

sub renderIconImage {
    my ( $this, $url, $alt ) = @_;

    my %params = (
        src    => $url,
        width  => 16,
        height => 16,
        align  => 'top',
        border => 0
    );
    $params{alt} = $alt if defined $alt;

    return CGI::img( \%params );
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved.
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
