# See bottom of file for license and copyright information
package Foswiki::Render;

=begin TML

---+ package Foswiki::Render

This module provides most of the actual HTML rendering code in Foswiki.

=cut

use strict;
use warnings;
use Assert;
use Error qw(:try);
use CGI ();

use Foswiki                  ();
use Foswiki::Time            ();
use Foswiki::Sandbox         ();
use Foswiki::Render::Anchors ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Counter used to generate unique placeholders for when we lift blocks
# (such as <verbatim> out of the text during rendering.
our $placeholderMarker = 0;

# Limiting lookbehind and lookahead for wikiwords and emphasis.
# use like \b
our $STARTWW = qr/^|(?<=[\s\(])/m;
our $ENDWW   = qr/$|(?=[\s,.;:!?)])/m;

# Note: the following marker sequences are used in text to mark things that
# have been hoisted or need to be marked for further processing. The strings
# are carefully chosen so that they (1) are not normally present in written
# text and (2) they do not combine with other characters to form valid
# wide-byte characters. A subset of the 7-bit control characters is used
# (codepoint < 0x07). Warning: the RENDERZONE_MARKER in Foswiki.pm uses \3

# Marker used to indicate the start of a table
our $TABLEMARKER = "\0\1\2TABLE\2\1\0";

# Marker used to indicate table rows that are valid header/footer rows
our $TRMARK = "is\1all\1th";

# General purpose marker used to mark escapes inthe text; for example, we
# use it to mark hoisted blocks, such as verbatim blocks.
our $REMARKER = "\0";

# Optional End marker for escapes where the default end character ; also
# must be removed.  Used for email anti-spam encoding.
our $REEND = "\1";

# Temporary marker for <nop> and <literal> tags. They are used as follows:
#  - Remove all <nop> and <literal>
#  - Take out <input ..> tags
#  - Restore all <nop> and <literal>
#  - ... do other rendering
#  - Put back all <input ...> tags
#  - Remove any extraneous markers.
our $NOPMARK = "\2";

# Default format for a link to a non-existant topic
use constant DEFAULT_NEWLINKFORMAT => <<'NLF';
<span class="foswikiNewLink">$text<a href="%SCRIPTURLPATH{"edit"}%/$web/$topic?topicparent=%WEB%.%TOPIC%" rel="nofollow" title="%MAKETEXT{"Create this topic"}%">?</a></span>
NLF

my %list_types = (
    A => 'upper-alpha',
    a => 'lower-alpha',
    i => 'lower-roman',
    I => 'upper-roman'
);

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
    undef $this->{session};
}

=begin TML

---++ ObjectMethod internalLink ( $web, $topic, $linkText, $anchor, $linkIfAbsent, $keepWebPrefix, $hasExplicitLinkLabel ) -> $html

Generate a link.

Note: Topic names may be spaced out. Spaced out names are converted
to <nop>WikWords, for example, "spaced topic name" points to "SpacedTopicName".
   * =$web= - the web containing the topic to be linked
   * =$topic= - the topic to be linked
   * =$linkText= - text to use for the link
   * =$anchor= - the link anchor, if any
   * =$linkIfAbsent= - boolean: false means suppress link for
     non-existing pages
   * =$keepWebPrefix= - boolean: true to keep web prefix (for
     non existing Web.TOPIC)
   * =$hasExplicitLinkLabel= - boolean: true if
     [[link][explicit link label]]

Called from outside the package by Func::internalLink.

This is the only way to get a =renderWikiWordHandler= called. When the handler
is called it has an opportunity to modify the link text, but nothing else, and
the output is pumped through the rest of the rendering process, which is a
mistake. This is a recognised shortcoming of the handler.

=cut

# SMELL: this is callable from Func, and is used by the ImportExportPlugin
# (but nothing else AFAICT) - C.
# Calls _renderWikiWord, which in turn will use Plurals.pm to match fold
# plurals to equivalency with their singular form

sub internalLink {
    my ( $this, $web, $topic, $linkText, $anchor, $linkIfAbsent, $keepWebPrefix,
        $hasExplicitLinkLabel, $params )
      = @_;

    # Webname/Subweb/ -> Webname/Subweb
    $web =~ s/\/\Z//;

    if ( $linkText eq $web ) {
        $linkText =~ s/\//\./g;
    }

    #WebHome links to tother webs render as the WebName
    if (   ( $linkText eq $Foswiki::cfg{HomeTopicName} )
        && ( $web ne $this->{session}->{webName} ) )
    {
        $linkText = $web;
    }

    # Get rid of leading/trailing spaces in topic name
    $topic =~ s/^\s*//;
    $topic =~ s/\s*$//;

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
    $topic = ucfirst($topic);
    $topic =~ s/\s([[:alnum:]])/\U$1/g;

    # If locales are in effect, the above conversions will taint the topic
    # name (Foswiki:Tasks:Item2091)
    $topic = Foswiki::Sandbox::untaintUnchecked($topic);

    # Add <nop> before WikiWord inside link text to prevent double links
    $linkText =~ s/(?<=[\s\(])([[:upper:]])/<nop>$1/g;
    return _renderWikiWord( $this, $web, $topic, $linkText, $anchor,
        $linkIfAbsent, $keepWebPrefix, $params );
}

=begin TML

---++ ObjectMethod getRenderedVersion ( $text, $topicObject ) -> $html

The main rendering function.

=cut

sub getRenderedVersion {
    my ( $this, $text, $topicObject ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;

    return '' unless defined $text;    # nothing to do

    my $session = $this->{session};
    my $plugins = $session->{plugins};
    my $prefs   = $session->{prefs};

    @{ $this->{LIST} } = ();

    # Initial cleanup
    $text =~ s/\r//g;
    $text =~ s/[\{\}]$REMARKER//g;

    # whitespace before <! tag (if it is the first thing) is illegal
    $text =~ s/^\s+(<![A-Za-z])/$1/;

    # clutch to enforce correct rendering at end of doc
    $text =~ s/\n?$/\n<nop>\n/s;

    # Maps of placeholders to tag parameters and text
    my $removed = {};

    # verbatim before literal - see Item3431
    $text = Foswiki::takeOutBlocks( $text, 'verbatim',  $removed );
    $text = Foswiki::takeOutBlocks( $text, 'literal',   $removed );
    $text = Foswiki::takeOutBlocks( $text, 'dirtyarea', $removed )
      if $topicObject->isCacheable();

    $text =
      $this->_takeOutProtected( $text, qr/<\?([^?]*)\?>/s, 'comment',
        $removed );
    $text =
      $this->_takeOutProtected( $text,
        qr/<![Dd][Oo][Cc][Tt][Yy][Pp][Ee]([^<>]*)>?/m,
        'comment', $removed );
    $text =
      $this->_takeOutProtected( $text,
        qr/<[Hh][Ee][Aa][Dd].*?<\/[Hh][Ee][Aa][Dd]>/s,
        'head', $removed );
    $text = $this->_takeOutProtected(
        $text,
qr/<[Tt][Ee][Xx][Tt][Aa][Rr][Ee][Aa]\b.*?<\/[Tt][Ee][Xx][Tt][Aa][Rr][Ee][Aa]>/s,
        'textarea',
        $removed
    );
    $text =
      $this->_takeOutProtected( $text,
        qr/<[Ss][Cc][Rr][Ii][Pp][Tt]\b.*?<\/[Ss][Cc][Rr][Ii][Pp][Tt]>/s,
        'script', $removed );
    $text =
      $this->_takeOutProtected( $text,
        qr/<[Ss][Tt][Yy][Ll][Ee]\b.*?<\/[Ss][Tt][Yy][Ll][Ee]>/s,
        'style', $removed );

    # Remove the sticky tags (used in WysiwygPlugin's TML2HTML conversion)
    # since they could potentially break a browser.
    # They are removed here and not in the plugin because the plugin might
    # not be installed but the sticky tags are standard markup.
    $text =~ s#</?sticky>##g;

    # DEPRECATED startRenderingHandler before PRE removed
    # SMELL: could parse more efficiently if this wasn't
    # here.
    $plugins->dispatch( 'startRenderingHandler', $text, $topicObject->web,
        $topicObject->topic );

    $text = Foswiki::takeOutBlocks( $text, 'pre', $removed );

    # Join lines ending in '\' (don't need \r?, it was removed already)
    $text =~ s/\\\n//gs;

    $plugins->dispatch( 'preRenderingHandler', $text, $removed );

    if ( $plugins->haveHandlerFor('insidePREHandler') ) {
        foreach my $region ( sort keys %$removed ) {
            next unless ( $region =~ m/^pre\d+$/i );
            my @lines = split( /\r?\n/, $removed->{$region}{text} );
            my $rt = '';
            while ( scalar(@lines) ) {
                my $line = shift(@lines);
                $plugins->dispatch( 'insidePREHandler', $line );
                if ( $line =~ m/\n/ ) {
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
            if ( $line =~ m/\n/ ) {
                unshift( @lines, split( /\r?\n/, $line ) );
                next;
            }
            $rt .= $line . "\n";
        }

        $text = $rt;
    }

    # Remove input fields: Item11480
    $text =~ s/<nop>/N$NOPMARK/g;
    $text = $this->_takeOutProtected( $text, qr/<[Ii][Nn][Pp][Uu][Tt]\b.*?>/s,
        'input', $removed );
    $text =~ s/N$NOPMARK/<nop>/g;

    # Escape rendering: Change ' !AnyWord' to ' <nop>AnyWord',
    # for final ' AnyWord' output
    $text =~ s/$STARTWW\!(?=[\w\*\=])/<nop>/gm;

    # Blockquoted email (indented with '> ')
    # Could be used to provide different colours for different numbers of '>'
    $text =~ s/^>(.*?)$/'&gt;<cite>$1<\/cite><br \/>/gm;

    # locate isolated < and > and translate to entities
    # Protect isolated <!-- and -->
    $text =~ s/<!--/{$REMARKER!--/g;
    $text =~ s/-->/--}$REMARKER/g;

    # SMELL: this next fragment does not handle the case where HTML tags
    # are embedded in the values provided to other tags. The only way to
    # do this correctly is to parse the HTML (bleagh!). So we just assume
    # they have been escaped.
    $text =~ s/<(\/?[\w\-]+(:[\w\-]+)?)>/{$REMARKER$1}$REMARKER/g;
    $text =~ s/<([\w\-]+(:[\w\-]+)?(\s+.*?|\/)?)>/{$REMARKER$1}$REMARKER/g;

    # XML processing instruction only valid at start of text
    $text =~ s/^<(\?\w.*?\?)>/{$REMARKER$1}$REMARKER/g;

    # entitify lone < and >, praying that we haven't screwed up :-(
    # Item1985: CDATA sections are not lone < and >
    $text =~ s/<(?!\!\[CDATA\[)/&lt\;/g;
    $text =~ s/(?<!\]\])>/&gt\;/g;
    $text =~ s/\{$REMARKER/</g;
    $text =~ s/\}$REMARKER/>/g;

    # other entities
    # Negative look-ahead assertion for non-named entity and numeric entity
    $text =~ s/&        # Entity, or just an ampersand
        (?!                  # Negative lookahead assertion
           (?:\w+;)          # named entity
         | (?:\#[Xx]?[0-9a-fA-F]+;) # numeric entity
        )
        /&amp;/gx;

    # clear the set of unique anchornames in order to inhibit
    # the 'relabeling' of anchor names if the same topic is processed
    # more than once, cf. explanation in expandMacros()
    my $anchors = $this->getAnchorNames($topicObject);
    $anchors->clear();

    # '#WikiName' anchors. Don't attempt to make these unique; renaming
    # user-defined anchors is not sensible.
    $text =~ s{^(\#$Foswiki::regex{wikiWordRegex})}
    {'<span id="'.$anchors->add( $1 ).'"></span>'}gem;

    # Headings
    # '<h6>...</h6>' HTML rule
    $text =~ s/$Foswiki::regex{headerPatternHt}/
      _makeAnchorHeading($this, $2, $1, $anchors)/ge;

    # '----+++++++' rule
    $text =~ s/$Foswiki::regex{headerPatternDa}/
      _makeAnchorHeading($this, $2, length($1), $anchors)/ge;

    # Horizontal rule
    $text =~ s/^---+/<hr \/>/gm;

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
                $line = '<p></p>';
            }
            $isList = 0;
        }
        elsif ( $line =~ m/^\S/ ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^(\t| {3})+\S/ ) {
            if ( index( $line, '$' ) >= 0
                && $line =~
                s/^((?:\t| {3})+)\$\s*([^:]+):\s+/<dt> $2 <\/dt><dd> / )
            {

                # Definition list
                _addListItem( $this, \@result, 'dl', 'dd', '', $1 );
                $isList = 1;
            }
            elsif ( $line =~ s/^((?:\t| {3})+)(\S+?):\s+/<dt> $2 <\/dt><dd> / )
            {

                # Definition list (deprecated)
                _addListItem( $this, \@result, 'dl', 'dd', '', $1 );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+)\* /<li> / ) {

                # Unnumbered list
                _addListItem( $this, \@result, 'ul', 'li', '', $1 );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+): /<div class='foswikiIndent'> / ) {

                # Indent pseudo-list
                $line .= '&nbsp;'
                  if ( length($line) eq 28 )
                  ;    # empty divs are not rendered, so make it non-empty.
                _addListItem( $this, \@result, '', 'div', 'foswikiIndent', $1 );
                $isList = 1;
            }
            elsif ( $line =~ m/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/ ) {

                # Numbered list
                my $ot = $3;
                $ot =~ s/^(.).*/$1/;
                if ( $ot !~ /^\d$/ ) {

                    # Use style="list-type-type:"
                    $ot = ' style="list-style-type:' . $list_types{$ot} . '"';
                }
                else {
                    $ot = '';
                }
                $line =~ s/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/<li$ot> /;
                _addListItem( $this, \@result, 'ol', 'li', '', $1 );
                $isList = 1;
            }
            elsif ( $isList && $line =~ m/^(\t|   )+\s*\S/ ) {

                # indented line extending prior list item
                push( @result, $line );
                next;
            }
            else {
                $isList = 0;
            }
        }
        elsif ( $isList && $line =~ m/^(\t|   )+\s*\S/ ) {

            # indented line extending prior list item; case where indent
            # starts with is at least 3 spaces or a tab, but may not be a
            # multiple of 3.
            push( @result, $line );
            next;
        }

        # Finish the list
        unless ( $isList || $isFirst ) {
            _addListItem( $this, \@result, '', '', '', '' );
        }

        push( @result, $line );
        $isFirst = 0;
    }

    if ($tableRow) {
        _addTHEADandTFOOT( \@result );
        push( @result, '</table>' );
    }
    _addListItem( $this, \@result, '', '', '', '' );

    $text = join( '', @result );

    # SMELL: use of $STARTWW and $ENDWW really limit the number of places
    # emphasis can happen. But it's a tradeoff between that and excessive
    # greed.

    $text =~ s/${STARTWW}==(\S+?|\S[^\n]*?\S)==$ENDWW/_fixedFontText($1,1)/gem;
    $text =~ s/${STARTWW}__(\S+?|\S[^\n]*?\S)
               __$ENDWW/<strong><em>$1<\/em><\/strong>/gmx;
    $text =~ s/${STARTWW}\*(\S+?|\S[^\n]*?\S)\*$ENDWW/<strong>$1<\/strong>/gm;
    $text =~ s/${STARTWW}\_(\S+?|\S[^\n]*?\S)\_$ENDWW/<em>$1<\/em>/gm;
    $text =~ s/${STARTWW}\=(\S+?|\S[^\n]*?\S)\=$ENDWW/_fixedFontText($1,0)/gem;

    # Handle [[][] and [[]] links
    # Change ' ![[...' to ' [<nop>[...' to protect from further rendering
    $text =~ s/(^|\s)\!\[\[/$1\[<nop>\[/gm;

    # Spaced-out Wiki words with alternative link text
    # i.e. [[$1][$3]]
    $text =~ s(\[\[([^\]\[\n]+)\](\[([^\]\n]+)\])?\])
        (_handleSquareBracketedLink( $this,$topicObject,$1,$3))ge;

    # URI - don't apply if the URI is surrounded by url() to avoid naffing
    # CSS
    $text =~ s/(^|(?<!url)[-*\s(|])
               ($Foswiki::regex{linkProtocolPattern}:
                   ([^\s<>"]+[^\s*.,!?;:)<|]))/
                     $1._externalLink( $this,$2)/geox;

    # Normal mailto:foo@example.com ('mailto:' part optional)
    $text =~ s/$STARTWW((mailto\:)?
                   $Foswiki::regex{emailAddrRegex})$ENDWW/
                     _mailLink( $this, $1 )/gemx;

    unless ( Foswiki::isTrue( $prefs->getPreference('NOAUTOLINK') ) ) {

        # Handle WikiWords
        $text = Foswiki::takeOutBlocks( $text, 'noautolink', $removed );
        $text =~ s($STARTWW
            (?:($Foswiki::regex{webNameRegex})\.)?
            ($Foswiki::regex{wikiWordRegex}|
                $Foswiki::regex{abbrevRegex})
            ($Foswiki::regex{anchorRegex})?)
           (_handleWikiWord( $this, $topicObject, $1, $2, $3))gexom;
        Foswiki::putBackBlocks( \$text, $removed, 'noautolink' );
    }

    # Restore input fields before calling the end/post handlers
    $this->_putBackProtected( \$text, 'input', $removed );
    $text =~ s/N$NOPMARK//g;

    Foswiki::putBackBlocks( \$text, $removed, 'pre' );

    # DEPRECATED plugins hook after PRE re-inserted
    $plugins->dispatch( 'endRenderingHandler', $text );

    # replace verbatim with pre in the final output
    Foswiki::putBackBlocks( \$text, $removed, 'verbatim', 'pre',
        \&verbatimCallBack );
    $text =~ s|\n?<nop>\n$||;    # clean up clutch

    $this->_putBackProtected( \$text, 'style',  $removed );
    $this->_putBackProtected( \$text, 'script', $removed );
    Foswiki::putBackBlocks( \$text, $removed, 'literal', '' );
    $this->_putBackProtected( \$text, 'literal', $removed );
    Foswiki::putBackBlocks( \$text, $removed, 'dirtyarea' )
      if $topicObject->isCacheable();
    $this->_putBackProtected( \$text, 'comment',  $removed );
    $this->_putBackProtected( \$text, 'head',     $removed );
    $this->_putBackProtected( \$text, 'textarea', $removed );

    $text = _adjustH($text);

    $this->{session}->getLoginManager()->endRenderingHandler($text);

    $plugins->dispatch( 'postRenderingHandler', $text );
    return $text;
}

=begin TML

---++ StaticMethod html($tag, $attrs, $content) -> $html

Generates HTML for the given HTML tag name, plus an optional map of attributes
and optional content. Attribute values will be safely encoded for use in HTML.
However TML is *not* escaped.

Can be used to replace many of the CGI::* html generation methods.

Use it like this:

   * Foswiki::Render::html('a', { href => $url, name => 'blah' }, 'jump');
   * Foswiki::Render::html('br');
   * Foswiki::Render::html('p', undef, 'Now is the time');

=cut

sub html {
    my ( $tag, $attrs, $innerHTML ) = @_;
    my $html = "<$tag";
    if ($attrs) {
        my @keys = keys %$attrs;
        @keys = sort @keys if (DEBUG);
        foreach my $k (@keys) {
            my $v = $attrs->{$k};

            # This is what CGI encodes, so....
            $v =~ s/([&<>\x8b\x9b'])/'&#'.ord($1).';'/ge;
            $html .= " $k='$v'";
        }
    }
    $innerHTML = '' unless defined $innerHTML;
    return "$html>$innerHTML</$tag>";
}

=begin TML

---++ StaticMethod verbatimCallBack

Callback for use with putBackBlocks that replaces &lt; and >
by their HTML entities &amp;lt; and &amp;gt;

=cut

sub verbatimCallBack {
    my $val = shift;

    # SMELL: A shame to do this, but in Foswiki.org have converted
    # 3 spaces to tabs since day 1
    $val =~ s/\t/   /g;

    return Foswiki::entityEncode($val);
}

=begin TML

---++ ObjectMethod TML2PlainText( $text, $topicObject, $opts ) -> $plainText

Strip TML markup from text for display as plain text without
pushing it through the full rendering pipeline. Intended for 
generation of topic and change summaries. Adds nop tags to 
prevent subsequent rendering; nops get removed at the very end.

$opts:
   * showvar - shows !%VAR% names if not expanded
   * expandvar - expands !%VARS%
   * nohead - strips ---+ headings at the top of the text
   * showmeta - does not filter meta-data

=cut

sub TML2PlainText {
    my ( $this, $text, $topicObject, $opts ) = @_;
    $opts ||= '';

    return '' unless defined $text;

    $text =~ s/\r//g;    # SMELL, what about OS10?

    if ( $opts =~ m/showmeta/ ) {
        $text =~ s/%META:/%<nop>META:/g;
    }
    else {
        $text =~ s/%META:[A-Z].*?\}%//g;
    }

    if ( $opts =~ m/expandvar/ ) {
        $text =~ s/(\%)(SEARCH)\{/$1<nop>$2/g;    # prevent recursion
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
        if ( $opts =~ m/showvar/ ) {
            $text =~ s/%(\w+(\{.*?\}))%/$1/g;     # defuse
        }
        else {
            $text =~ s/%$Foswiki::regex{tagNameRegex}(\{.*?\})?%//g;    # remove
        }
    }

    # Format e-mail to add spam padding (HTML tags removed later)
    $text =~ s/$STARTWW(
                   (mailto\:)?
                   [a-zA-Z0-9-_.+]+@[a-zA-Z0-9-_.]+\.[a-zA-Z0-9-_]+
                   )$ENDWW
              /_mailLink( $this, $1 )/gemx;
    $text =~ s/<!--.*?-->//gs;       # remove all HTML comments
    $text =~ s/<(?!nop)[^>]*>//g;    # remove all HTML tags except <nop>
    $text =~ s/\&[a-z]+;/ /g;        # remove entities
    if ( $opts =~ m/nohead/ ) {

        # skip headings on top
        while ( $text =~ s/^\s*\-\-\-+\+[^\n\r]*// ) { };    # remove heading
    }

    #keep only test portion of [[][]] links
    $text =~ s/\[\[([^\]]*\]\[)(.*?)\]\]/$2/g;

    # SMELL: can't do this, it removes these characters even when they're
    # not for formatting
    #$text =~ s/[\[\]\*\|=_\&\<\>]/ /g;

    $text =~ s/${STARTWW}==(\S+?|\S[^\n]*?\S)==$ENDWW/$1/gem;
    $text =~ s/${STARTWW}__(\S+?|\S[^\n]*?\S)__$ENDWW/$1/gm;
    $text =~ s/${STARTWW}\*(\S+?|\S[^\n]*?\S)\*$ENDWW/$1/gm;
    $text =~ s/${STARTWW}\_(\S+?|\S[^\n]*?\S)\_$ENDWW/$1/gm;
    $text =~ s/${STARTWW}\=(\S+?|\S[^\n]*?\S)\=$ENDWW/$1/gem;

    #SMELL: need to correct these too
    $text =~ s/[\[\]\|\&]/ /g;    # remove remaining Wiki formatting chars

    $text =~ s/^\-\-\-+\+*\s*\!*/ /gm;    # remove heading formatting and hbar
    $text =~ s/[\+\-]+/ /g;               # remove special chars
    $text =~ s/^\s+//;                    # remove leading whitespace
    $text =~ s/\s+$//;                    # remove trailing whitespace
    $text =~ s/!(\w+)/$1/gs;    # remove all nop exclamation marks before words
    $text =~ s/[\r\n]+/\n/s;
    $text =~ s/[ \t]+/ /s;

    # defuse "Web." prefix in "Web.TopicName" link
    $text =~ s{$STARTWW
               (($Foswiki::regex{webNameRegex})\.
                   ($Foswiki::regex{wikiWordRegex}
                   | $Foswiki::regex{abbrevRegex}))}
              {$2.<nop>$3}gx;
    $text =~ s/\<nop\>//g;      # remove any remaining nops
    $text =~ s/[\<\>]/ /g;      # remove any remaining formatting

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
    $text =~ s/((($Foswiki::regex{webNameRegex})\.)?
                   ($Foswiki::regex{wikiWordRegex}
                   |$Foswiki::regex{abbrevRegex}))/<nop>$1/gx;

    $text =~ s/([@%])/<nop>$1<nop>/g;    # email address, macro

    return $text;
}

# DEPRECATED: retained for compatibility with various hack-job extensions
sub makeTopicSummary {
    my ( $this, $text, $topic, $web, $flags ) = @_;
    my $topicObject = Foswiki::Meta->new( $this->{session}, $web, $topic );
    return $topicObject->summariseText( '', $text );
}

=begin TML

---++ ObjectMethod renderRevisionInfo($topicObject, $rev, $format) -> $string

Obtain and render revision info for a topic.
   * =$topicObject= - the topic
   * =$rev= - the rev number, defaults to latest rev
   * =$format= - the render format, defaults to
     =$rev - $time - $wikiusername=. =$format= can contain
     the following keys for expansion:
   | =$web= | the web name |
   | =$topic= | the topic name |
   | =$rev= | the rev number |
   | =$username= | the login of the saving user |
   | =$wikiname= | the wikiname of the saving user |
   | =$wikiusername= | the web.wikiname of the saving user |
   | =$date= | the date of the rev (no time) |
   | =$time= | the time of the rev |
   | =$min=, =$sec=, etc. | Same date format qualifiers as GMTIME |

=cut

sub renderRevisionInfo {
    my ( $this, $topicObject, $rrev, $format ) = @_;
    my $value = $format || 'r$rev - $date - $time - $wikiusername';
    $value = Foswiki::expandStandardEscapes($value);

    # nop if there are no format tokens
    return $value
      unless $value =~
m/\$(?:year|ye|wikiusername|wikiname|week|we|web|wday|username|tz|topic|time|seconds|sec|rev|rcs|month|mo|minutes|min|longdate|isotz|iso|http|hours|hou|epoch|email|dow|day|date)/x;

    my $users = $this->{session}->{users};
    if ($rrev) {
        my $loadedRev = $topicObject->getLoadedRev() || 0;
        unless ( $rrev == $loadedRev ) {
            $topicObject = Foswiki::Meta->new($topicObject);
            $topicObject = $topicObject->load($rrev);
        }
    }
    my $info = $topicObject->getRevisionInfo();

    my $wun = '';
    my $wn  = '';
    my $un  = '';
    if ( $info->{author} ) {
        my $cUID = $users->getCanonicalUserID( $info->{author} );

#pre-set cuid if author is the unknown user from the basemapper (ie, default value) to avoid further guesswork
        $cUID = $info->{author}
          if ( $info->{author} eq
            $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID );
        if ( !$cUID ) {
            my $ln = $users->getLoginName( $info->{author} );
            $cUID = $info->{author}
              if ( defined($ln) and ( $ln ne 'unknown' ) );
        }
        if ($cUID) {
            $wun = $users->webDotWikiName($cUID);
            $wn  = $users->getWikiName($cUID);
            $un  = $users->getLoginName($cUID);
        }

        #only do the legwork if we really have to
        if ( not( defined($wun) and defined($wn) and defined($un) )
            or ( ( $wun eq '' ) or ( $wn eq '' ) or ( $un eq '' ) ) )
        {
            my $user = $info->{author};

            # If we are still unsure, then use whatever is saved in the meta.
            # But obscure it if the RenderLoggedInButUnknownUsers is enabled.
            if ( $Foswiki::cfg{RenderLoggedInButUnknownUsers} ) {
                $user = $info->{author} = 'unknown';
            }
            else {

                #cUID's are forced to ascii by escaping other chars..
                #$cUID =~ s/([^a-zA-Z0-9])/'_'.sprintf('%02x', ord($1))/ge;

#remove any SomeMapping_ prefix from the cuid - as that initial '_' is not escaped.
                $user =~ s/^[A-Z][A-Za-z]+Mapping_//;

                #and then xform any escaped chars.
                use bytes;
                $user =~ s/_([0-9a-f][0-9a-f])/chr(hex($1))/ge;
                no bytes;
            }
            $wun ||= $user;
            $wn  ||= $user;
            $un  ||= $user;
        }
    }

    $value =~ s/\$web/$topicObject->web() || ''/ge;
    $value =~ s/\$topic\(([^\)]*)\)/
      Foswiki::Render::breakName( $topicObject->topic(), $1 )/ge;
    $value =~ s/\$topic/$topicObject->topic() || ''/ge;
    $value =~ s/\$rev/$info->{version}/g;
    $value =~ s/\$time/
      Foswiki::Time::formatTime($info->{date}, '$hour:$min:$sec')/ge;
    $value =~ s/\$date/
      Foswiki::Time::formatTime(
          $info->{date}, $Foswiki::cfg{DefaultDateFormat} )/ge;
    $value =~ s/(\$(rcs|longdate|isotz|iso|http|email|))/
      Foswiki::Time::formatTime($info->{date}, $1 )/ge;

    if ( $value =~
m/\$(?:year|ye|week|we|web|wday|username|tz|seconds|sec|rcs|month|mo|minutes|min|longdate|hours|hou|epoch|dow|day)/
      )
    {
        $value = Foswiki::Time::formatTime( $info->{date}, $value );
    }
    $value =~ s/\$username/$un/g;
    $value =~ s/\$wikiname/$wn/g;
    $value =~ s/\$wikiusername/$wun/g;

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

    return '' unless defined $text;

    $options->{in_pre}        = 0;
    $options->{in_pre}        = 0;
    $options->{in_verbatim}   = 0;
    $options->{in_literal}    = 0;
    $options->{in_noautolink} = 0;
    my $newText = '';
    foreach my $line ( split( /([\r\n]+)/, $text ) ) {
        if ( $line =~ m/[\r\n]/ ) {
            $newText .= $line;
            next;
        }
        $options->{in_verbatim}++
          if ( $line =~ m|^\s*<[Vv][Ee][Rr][Bb][Aa][Tt][Ii][Mm]\b[^>]*>\s*$| );
        $options->{in_verbatim}--
          if ( $line =~ m|^\s*</[Vv][Ee][Rr][Bb][Aa][Tt][Ii][Mm]>\s*$| );
        $options->{in_literal}++
          if ( $line =~ m|^\s*<[Ll][Ii][Tt][Ee][Rr][Aa][Ll]\b[^>]*>\s*$| );
        $options->{in_literal}--
          if ( $line =~ m|^\s*</[Ll][Ii][Tt][Ee][Rr][Aa][Ll]>\s*$| );
        unless ( ( $options->{in_verbatim} > 0 )
            || ( ( $options->{in_literal} > 0 ) ) )
        {
            $options->{in_pre}++ if ( $line =~ m|<[Pp][Rr][Ee]\b| );
            $options->{in_pre}-- if ( $line =~ m|</[Pp][Rr][Ee]>| );
            $options->{in_noautolink}++
              if ( $line =~
                m|^\s*<[Nn][Oo][Aa][Uu][Tt][Oo][Ll][Ii][Nn][Kk]\b[^>]*>\s*$| );
            $options->{in_noautolink}--
              if ( $line =~
                m|^\s*</[Nn][Oo][Aa][Uu][Tt][Oo][Ll][Ii][Nn][Kk]>\s*| );
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
        if ( $sep =~ m/^\.\.\./ ) {

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

---++ ObjectMethod getAnchorNames( $topicObject ) -> $set

Get the anchor name set generated for the given topic. This is so that the
same anchor names can be generated for each time the same topic is
%INCLUDEd (the same anchor target will be generated for each time the
topic is included.

Note that anchor names generated this way are unique since the last time the
anchor set is cleared, which happens (1) whenever a new session is started
and (2) whenever a new %TOC macro is rendered (see Foswiki/Macros/TOC).

Returns an object of type Foswiki::Render::Anchors.

=cut

sub getAnchorNames {
    my ( $this, $topicObject ) = @_;
    my $id = $topicObject->getPath();
    my $a  = $this->{_anchorNames}{$id};
    unless ($a) {
        $a = new Foswiki::Render::Anchors();
        $this->{_anchorNames}{$id} = $a;
    }
    return $a;
}

# Get the template for a "new topic" link
sub _newLinkFormat {
    my $this = shift;
    unless ( $this->{NEWLINKFORMAT} ) {
        $this->{NEWLINKFORMAT} =
          $this->{session}->{prefs}->getPreference('NEWLINKFORMAT')
          || DEFAULT_NEWLINKFORMAT;
    }
    return $this->{NEWLINKFORMAT};
}

# Add a list item, of the given type and indent depth. The list item may
# cause the opening or closing of lists currently being handled.
sub _addListItem {
    my ( $this, $result, $type, $element, $css, $indent ) = @_;

    $indent =~ s/   /\t/g;
    my $depth = length($indent);

    my $size = scalar( @{ $this->{LIST} } );

    # The whitespaces either side of the tags are required for the
    # emphasis REs to work.
    if ( $size < $depth ) {
        my $firstTime = 1;
        while ( $size < $depth ) {
            push( @{ $this->{LIST} }, { type => $type, element => $element } );
            push( @$result,
                " <$element" . ( $css ? " class='$css'" : "" ) . ">\n" )
              unless ($firstTime);
            push( @$result, ' <' . $type . ">\n" ) if $type;
            $firstTime = 0;
            $size++;
        }
    }
    else {
        while ( $size > $depth ) {
            my $tags = pop( @{ $this->{LIST} } );
            my $r    = "\n</" . $tags->{element} . '>';
            $r .= '</' . $tags->{type} . '> ' if $tags->{type};
            push( @$result, $r );
            $size--;
        }
        if ($size) {
            push( @$result,
                "\n</" . $this->{LIST}->[ $size - 1 ]->{element} . '> ' );
        }
        else {
            push( @$result, "\n" );
        }
    }

    if ($size) {
        my $oldt = $this->{LIST}->[ $size - 1 ];
        if ( $oldt->{type} ne $type ) {
            my $r = '';
            $r .= ' </' . $oldt->{type} . '>' if $oldt->{type};
            $r .= '<' . $type . ">\n" if $type;
            push( @$result, $r ) if $r;
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
        if ( $lines->[$i] =~ m/^\s*$/ ) {

            # Remove blank lines in tables; they generate spurious <p>'s
            splice( @$lines, $i, 1 );
        }
        elsif ( $lines->[$i] =~ s/$TRMARK=(["'])(.*?)\1// ) {
            if ($2) {

                # In head or foot
                if ($inFoot) {

                    #print STDERR "FOOT: $lines->[$i]\n";
                    $footLines++;
                }
                else {

                    #print STDERR "HEAD: $lines->[$i]\n";
                    $headLines++;
                }
            }
            else {

                # In body
                #print STDERR "BODY: $lines->[$i]\n";
                $inFoot    = 0;
                $headLines = 0;
            }
        }
        $i--;
    }
    $lines->[ $i++ ] = " <table class='foswikiTable'>";

    if ($headLines) {
        splice( @$lines, $i++,            0, '<thead>' );
        splice( @$lines, $i + $headLines, 0, '</thead>' );
        $i += $headLines + 1;
    }

    if ($footLines) {

        # Extract the foot and stick it in the table after the head (if any)
        # WRC says browsers prefer this
        my $firstFoot = scalar(@$lines) - $footLines;
        my @foot = splice( @$lines, $firstFoot, $footLines );
        unshift( @foot, '<tfoot>' );
        push( @foot, '</tfoot>' );
        splice( @$lines, $i, 0, @foot );
        $i += scalar(@foot);
    }
    splice( @$lines, $i, 0, '<tbody>' );
    push( @$lines, '</tbody>' );
}

sub _emitTR {
    my ( $this, $row ) = @_;

    $row =~ s/\t/   /g;    # change tabs to space
    $row =~ s/\s*$//;      # remove trailing spaces
                           # calc COLSPAN
    $row =~ s/(\|\|+)/
      'colspan'.$REMARKER.length($1).'|'/ge;
    my $cells = '';
    my $containsTableHeader;
    my $isAllTH = 1;
    foreach ( split( /\|/, $row ) ) {
        my %attr;

        # Avoid matching single columns
        if (s/colspan$REMARKER([0-9]+)//) {
            $attr{colspan} = $1;
        }
        s/^\s+$/ &nbsp; /;
        my ( $l1, $l2 ) = ( 0, 0 );
        if (/^(\s*).*?(\s*)$/) {
            $l1 = length($1);
            $l2 = length($2);
        }
        if ( $l1 >= 2 ) {
            if ( $l2 <= 1 ) {
                $attr{align} = 'right';
            }
            else {
                $attr{align} = 'center';
            }
        }

        # implicit untaint is OK, because we are just taking topic data
        # and rendering it; no security step is bypassed.
        if (/^\s*\*(.*)\*\s*$/) {
            $cells .= CGI::th( \%attr, "<strong> $1 </strong>" ) . "\n";
        }
        else {
            $cells .= CGI::td( \%attr, " $_ " ) . "\n";
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
    $text = '<b>' . $text . '</b>' if $embolden;
    return '<code>' . $text . '</code>';
}

# Build an HTML &lt;Hn> element with suitable anchor for linking
# from %<nop>TOC%
sub _makeAnchorHeading {
    my ( $this, $text, $level, $anchors ) = @_;

    # - Build '<nop><h1><a name='atext'></a> heading </h1>' markup
    # - Initial '<nop>' is needed to prevent subsequent matches.
    # filter '!!', '%NOTOC%'
    $text =~ s/$Foswiki::regex{headerPatternNoTOC}//;

    my $html =
        '<nop><h'
      . $level . ' ' . 'id="'
      . $anchors->makeHTMLTarget($text) . '"> '
      . $text . ' </h'
      . $level . '>';

    return $html;
}

# TODO: this should be overridable by plugins.
sub _renderWikiWord {
    my ( $this, $web, $topic, $linkText, $anchor, $linkIfAbsent, $keepWebPrefix,
        $params )
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

        # add a dependency so that the page gets invalidated as soon as the
        # topic is deleted
        $this->{session}->{cache}->addDependencyForLink( $web, $topic )
          if $Foswiki::cfg{Cache}{Enabled};

        return _renderExistingWikiWord( $this, $web, $topic, $linkText, $anchor,
            $params );
    }
    if ($linkIfAbsent) {

        # CDot: disabled until SuggestSingularNotPlural is resolved
        # if ($singular && $singular ne $topic) {
        #     #unshift( @topics, $singular);
        # }

        # add a dependency so that the page gets invalidated as soon as the
        # WikiWord comes into existance
        # Note we *ignore* the params if the target topic does not exist
        $this->{session}->{cache}->addDependencyForLink( $web, $topic )
          if $Foswiki::cfg{Cache}{Enabled};

        return _renderNonExistingWikiWord( $this, $web, $topic, $linkText );
    }
    if ($keepWebPrefix) {
        return $web . '.' . $linkText;
    }

    return $linkText;
}

sub _renderExistingWikiWord {
    my ( $this, $web, $topic, $text, $anchor, $params ) = @_;

    my @cssClasses;
    push( @cssClasses, 'foswikiCurrentWebHomeLink' )
      if ( ( $web eq $this->{session}->{webName} )
        && ( $topic eq $Foswiki::cfg{HomeTopicName} ) );

    my $inCurrentTopic = 0;

    if (   ( $web eq $this->{session}->{webName} )
        && ( $topic eq $this->{session}->{topicName} ) )
    {
        push( @cssClasses, 'foswikiCurrentTopicLink' );
        $inCurrentTopic = 1;
    }

    my %attrs;
    my $href = $this->{session}->getScriptUrl( 0, 'view', $web, $topic );
    if ($params) {
        $href .= $params;
    }

    if ($anchor) {
        $anchor = Foswiki::Render::Anchors::make($anchor);
        $anchor = Foswiki::urlEncode($anchor);

        # No point in trying to make it unique; just aim at the first
        # occurrence
        # Item8556 - drop path if same topic
        $href = $inCurrentTopic ? "#$anchor" : "$href#$anchor";
    }
    $attrs{class} = join( ' ', @cssClasses ) if ( $#cssClasses >= 0 );
    $attrs{href} = $href;

    # Add a tooltip, if it's enabled
    unless ( defined( $this->{LINKTOOLTIPINFO} ) ) {
        $this->{LINKTOOLTIPINFO} =
          $this->{session}->{prefs}->getPreference('LINKTOOLTIPINFO')
          || '';
        if ( $this->{LINKTOOLTIPINFO} =~ m/^[Oo][Nn]$/ ) {
            $this->{LINKTOOLTIPINFO} = '$username - $date - r$rev: $summary';
        }
        elsif ( $this->{LINKTOOLTIPINFO} =~ m/^([Oo][Ff][Ff])?$/ ) {
            $this->{LINKTOOLTIPINFO} = '';
        }
    }
    if (   $this->{LINKTOOLTIPINFO} ne ''
        && $this->{session}->inContext('view') )
    {
        require Foswiki::Render::ToolTip;
        my $tooltip =
          Foswiki::Render::ToolTip::render( $this->{session}, $web, $topic,
            $this->{LINKTOOLTIPINFO} );
        $attrs{title} = $tooltip if $tooltip;
    }

    my $aFlag = CGI::autoEscape(0);
    my $link = CGI::a( \%attrs, $text );
    CGI::autoEscape($aFlag);

    # When we pass the tooltip text to CGI::a it may contain
    # <nop>s, and CGI::a will convert the < to &lt;. This is a
    # basic problem with <nop>.
    #$link =~ s/&lt;nop&gt;/<nop>/g;
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

    # For some strange reason, $web doesn't get untainted by the regex
    # that invokes this function. We can untaint it safely, because it's
    # validated by the RE.
    $web = Foswiki::Sandbox::untaintUnchecked($web);

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
      (      $topic =~ m/^$Foswiki::regex{abbrevRegex}$/
          && $web ne $this->{session}->{webName} );

    # false means suppress link for non-existing pages
    $linkIfAbsent = ( $topic !~ /^$Foswiki::regex{abbrevRegex}$/ );

    return $this->internalLink( $web, $topic, $text, $anchor, $linkIfAbsent,
        $keepWeb, undef );
}

# Protect WikiWords, TLAs and URLs from further rendering with <nop>
sub _escapeAutoLinks {
    my $text = shift;

    if ($text) {

        # WikiWords, TLAs, and email addresses
        $text =~ s/(?<=[\s\(])
                   (
                       (?:
                           (?:($Foswiki::regex{webNameRegex})\.)?
                           (?: $Foswiki::regex{wikiWordRegex}
                           | $Foswiki::regex{abbrevRegex} )
                       )
                   | $Foswiki::regex{emailAddrRegex}
                   )/<nop>$1/gx;

        # Explicit links
        $text =~ s/($Foswiki::regex{linkProtocolPattern}):(?=\S)/$1<nop>:/g;
    }
    return $text;
}

# Handle SquareBracketed links mentioned on page $web.$topic
# format: [[$link]]
# format: [[$link][$text]]
sub _handleSquareBracketedLink {
    my ( $this, $topicObject, $link, $text ) = @_;

    # Strip leading/trailing spaces
    $link =~ s/^\s+//;
    $link =~ s/\s+$//;

    my $hasExplicitLinkLabel = 0;

    if ( defined($text) ) {

        # [[$link][$text]]
        $hasExplicitLinkLabel = 1;
        if ( my $img = $this->_isImageLink($text) ) {
            $text = $img;
        }
        else {
            $text = _escapeAutoLinks($text);
        }
    }

    if ( $link =~ m#^($Foswiki::regex{linkProtocolPattern}:|/)# ) {
        return $this->_externalLink( $link, $text );
    }

    # Extract '?params'
    # $link =~ s/(\?.*?)(?>#|$)//;
    my $params = '';
    if ( $link =~ s/(\?.*$)// ) {
        $params = $1;
    }

    $text = _escapeAutoLinks($link) unless defined $text;
    $text =~ s/${STARTWW}==(\S+?|\S[^\n]*?\S)==$ENDWW/_fixedFontText($1,1)/gem;
    $text =~ s/${STARTWW}__(\S+?|\S[^\n]*?\S)
               __$ENDWW/<strong><em>$1<\/em><\/strong>/gmx;
    $text =~ s/${STARTWW}\*(\S+?|\S[^\n]*?\S)\*$ENDWW/<strong>$1<\/strong>/gm;
    $text =~ s/${STARTWW}\_(\S+?|\S[^\n]*?\S)\_$ENDWW/<em>$1<\/em>/gm;
    $text =~ s/${STARTWW}\=(\S+?|\S[^\n]*?\S)\=$ENDWW/_fixedFontText($1,0)/gem;

    # Extract '#anchor'
    # $link =~ s/(\#[a-zA-Z_0-9\-]*$)//;
    my $anchor = '';
    if ( $link =~ s/($Foswiki::regex{anchorRegex}$)// ) {
        $anchor = $1;

        #$text =~ s/#$anchor//;
    }

    # filter out &any; entities (legacy)
    $link =~ s/\&[a-zA-Z]+\;//g;

    # filter out &#123; entities (legacy)
    $link =~ s/\&\#[0-9]+\;//g;

    # Filter junk
    $link =~ s/$Foswiki::cfg{NameFilter}+/ /g;

    ASSERT( UNTAINTED($link) ) if DEBUG;

    # Capitalise first word
    $link = ucfirst($link);

    # Collapse spaces and capitalise following letter
    $link =~ s/\s([[:alnum:]])/\U$1/g;

    # Get rid of remaining spaces, i.e. spaces in front of -'s and ('s
    $link =~ s/\s//g;

    # The link is used in the topic name, and if locales are in effect,
    # the above conversions will taint the name (Foswiki:Tasks:Item2091)
    $link = Foswiki::Sandbox::untaintUnchecked($link);

    $link ||= $topicObject->topic;

    # Topic defaults to the current topic
    my ( $web, $topic ) =
      $this->{session}->normalizeWebTopicName( $topicObject->web, $link );

    return $this->internalLink( $web, $topic, $text, $anchor, 1, undef,
        $hasExplicitLinkLabel, $params );
}

# Check if text is an image # (as indicated by the file type)
# return an img tag, otherwise nothing
sub _isImageLink {
    my ( $this, $url ) = @_;

    return if $url =~ m/<nop>/;
    $url =~ s/^\s+//;
    $url =~ s/\s+$//;
    if ( $url =~ m#^https?://[^?]*\.(?:gif|jpg|jpeg|png)$#i ) {
        my $filename = $url;
        $filename =~ s@.*/@@;
        return CGI::img( { src => $url, alt => $filename } );
    }
    return;
}

# Handle an external link typed directly into text. If it's an image
# and no text is specified, then use an img tag, otherwise generate a link.
sub _externalLink {
    my ( $this, $url, $text ) = @_;

    if ( !$text && ( my $img = $this->_isImageLink($url) ) ) {
        return $img;
    }
    my $opt = '';
    if ( $url =~ m/^mailto:/i ) {
        if ( $Foswiki::cfg{AntiSpam}{EmailPadding} ) {
            $url =~ s/(\@[\w\_\-\+]+)(\.)
                     /$1$Foswiki::cfg{AntiSpam}{EmailPadding}$2/x;
            if ($text) {
                $text =~ s/(\@[\w\_\-\+]+)(\.)
                          /$1$Foswiki::cfg{AntiSpam}{EmailPadding}$2/x;
            }
        }
        if ( $Foswiki::cfg{AntiSpam}{EntityEncode} ) {

          # Much harder obfuscation scheme. For link text we only encode '@'
          # See also http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/Item2928
          # and http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/Item3430
          # before touching this
          # Note:  & is already encoded,  so don't encode any entities
          # See http://foswiki.org/Tasks/Item10905
            $url =~ s/&(\w+);/$REMARKER$1$REEND/g;                   # "&abc;"
            $url =~ s/&(#[Xx]?[0-9a-fA-F]+);/$REMARKER$1$REEND/g;    # "&#123;"
            $url =~ s/([^\w$REMARKER$REEND])/'&#'.ord($1).';'/ge;
            $url =~ s/$REMARKER(#[Xx]?[0-9a-fA-F]+)$REEND/&$1;/g;
            $url =~ s/$REMARKER(\w+)$REEND/&$1;/g;
            if ($text) {
                $text =~ s/\@/'&#'.ord('@').';'/ge;
            }
        }
    }
    $text ||= $url;

    # Item5787: if a URL has spaces, escape them so the URL has less
    # chance of being broken by later rendering.
    $url =~ s/ /%20/g;

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
    return $text if $url =~ m/^(?:!|\<nop\>)/;

#use Email::Valid             ();
#my $tmpEmail = $url;
#$tmpEmail =~ s/^mailto://;
#my $errtxt = '';
#$errtxt =  "<b>INVALID</b> $tmpEmail " unless (Email::Valid->address($tmpEmail));

    # Any special characters in the user portion must be %hex escaped.
    $url =~
s/^((?:mailto\:)?)?(.*?)(@.*?)$/'mailto:'._escapeMailAddress( $2 ).$3/msie;
    my $lenLeft  = length($2);
    my $lenRight = length($3);

    # Per RFC 3696 Errata, length restricted to 254 overall
    # per RFC 2821 RCPT limits
    return $text
      if ( $lenLeft > 64 || $lenRight > 254 || $lenLeft + $lenRight > 254 );

    $url = 'mailto:' . $url unless $url =~ m/^mailto:/i;
    return _externalLink( $this, $url, $text );
}

sub _escapeMailAddress {
    my $txt = shift;
    $txt =~ s/([<>#"%'{}\|\\\^~`\?&=]|\s)/sprintf('%%%02x', ord($1))/ge;
    return $txt;
}

# Adjust heading levels
# <h off="1"> will increase the indent level by 1
# <h off="-1"> will decrease the indent level by 1
sub _adjustH {
    my ($text) = @_;

    my @blocks = split( /(<ho(?:\s+off="(?:[-+]?\d+)")?\s*\/?>)/i, $text );

    return $text unless scalar(@blocks) > 1;

    sub _cap {
        return 1 if ( $_[0] < 1 );
        return 6 if ( $_[0] > 6 );
        return $_[0];
    }

    my $off = 0;
    my $out = '';
    while ( scalar(@blocks) ) {
        my $i = shift(@blocks);
        if ( $i =~ m/^<ho(?:\s+off="([-+]?\d+)")?\s*\/?>$/i && $1 ) {
            $off += $1;
        }
        else {
            $i =~ s/(<\/?h)(\d)((\s+.*?)?>)/$1 . _cap($2 + $off) . $3/gesi
              if ($off);
            $out .= $i;
        }
    }
    return $out;
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

    return '<!--' . $REMARKER . $id . $placeholder . $REMARKER . '-->';
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
    my $otext = $$text;

    my $pos   = 0;
    my $ntext = '';
    while ( ( $pos = index( $otext, "<!--${REMARKER}$id", $pos ) ) >= 0 ) {

        # Grab the text ahead of the marker
        $ntext .= substr( $otext, 0, $pos );

        # Length of the marker prefix
        my $pfxlen = length("<!--${REMARKER}$id");

        # Ending marker position
        my $epos = index( $otext, "${REMARKER}-->", $pos );

        # Tag instance
        my $placeholder =
          $id . substr( $otext, $pos + $pfxlen, $epos - $pos - $pfxlen );

  # Not all calls to putBack use a common map, so skip over any missing entries.
        unless ( exists $map->{$placeholder} ) {
            $ntext .= substr( $otext, $pos, $epos - $pos + 4 );
            $otext = substr( $otext, $epos + 4 );
            $pos = 0;
            next;
        }

        # Get replacement value
        my $val = $map->{$placeholder}{text};
        $val = &$callback($val) if ( defined($callback) );

        # Append the new data and remove leading text + marker from original
        $ntext .= $val if defined($val);
        $otext = substr( $otext, $epos + 4 );

        # Reset position for next pass
        $pos = 0;

        delete( $map->{$placeholder} );
    }

    $ntext .= $otext;    # Append any remaining text.
    $$text = $ntext;     # Replace the entire text

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
