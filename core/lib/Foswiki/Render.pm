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

use Foswiki::Time            ();
use Foswiki::Sandbox         ();
use Foswiki::Render::Anchors ();

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

# Characters that need to be %XX escaped in mailto URIs.
our %ESCAPED = (
    '<'  => '%3C',
    '>'  => '%3E',
    '#'  => '%23',
    '"'  => '%22',
    '%'  => '%25',
    "'"  => '%27',
    '{'  => '%7B',
    '}'  => '%7D',
    '|'  => '%7C',
    '\\' => '%5C',
    '^'  => '%5E',
    '~'  => '%7E',
    '`'  => '%60',
    '?'  => '%3F',
    '&'  => '%26',
    '='  => '%3D',
);

# Default format for a link to a non-existant topic
use constant DEFAULT_NEWLINKFORMAT => <<'NLF';
<span class="foswikiNewLink">$text<a href="%SCRIPTURLPATH{"edit"}%/$web/$topic?topicparent=%WEB%.%TOPIC%" rel="nofollow" title="%MAKETEXT{"Create this topic"}%">?</a></span>
NLF

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
          || DEFAULT_NEWLINKFORMAT;
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

        if ( !$depth or $currentDepth == $depth ) {
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
    my $text   = '';
    my $moved  = $topicObject->get('TOPICMOVED');
    my $prefix = $params->{prefix} || '';
    my $suffix = $params->{suffix} || '';

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
                        0, 'rename', $topicObject->web, $topicObject->topic
                    ),
                    rel => 'nofollow'
                },
                $this->{session}->i18n->maketext('Put it back...')
              );
        }
        $text = $this->{session}->i18n->maketext(
            "[_1] was renamed or moved from [_2] on [_3] by [_4]",
            "<nop>$toWeb.<nop>$toTopic", "<nop>$fromWeb.<nop>$fromTopic",
            $date, $by
        ) . $putBack;
    }
    $text = "$prefix$text$suffix" if $text;
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
    $lines->[$i++] = CGI::start_table(
        {
            class       => 'foswikiTable',
            border      => 1,
            cellspacing => 0,
            cellpadding => 0
        }
    );

    if ($headLines) {
        splice( @$lines, $i++, 0, '<thead>' );
        splice( @$lines, $i + $headLines, 0, '</thead>' );
	$i += $headLines + 1;
    }

    if ($footLines) {
	# Extract the foot and stick it in the table after the head (if any)
	# WRC says browsers prefer this
        my $firstFoot = scalar(@$lines) - $footLines;
        my @foot = splice( @$lines, $firstFoot, $footLines );
	unshift(@foot, '<tfoot>');
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
        if (s/colspan$REMARKER([0-9]+)//o) {
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
            $cells .= CGI::th( \%attr, CGI::strong( {}, " $1 " ) ) . "\n";
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
    $text = CGI->b($text) if $embolden;
    return CGI->code($text);
}

# Build an HTML &lt;Hn> element with suitable anchor for linking
# from %<nop>TOC%
sub _makeAnchorHeading {
    my ( $this, $text, $level, $anchors ) = @_;

    # - Build '<nop><h1><a name='atext'></a> heading </h1>' markup
    # - Initial '<nop>' is needed to prevent subsequent matches.
    # filter '!!', '%NOTOC%'
    $text =~ s/$Foswiki::regex{headerPatternNoTOC}//o;

    my $html =
        '<nop><h' 
      . $level . '>'
      . $anchors->makeHTMLTarget($text) . ' '
      . $text . ' </h'
      . $level . '>';

    return $html;
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

    # These are safe to untaint blindly because this method is only
    # called when a regex matches a valid wikiword
    $web   = Foswiki::Sandbox::untaintUnchecked($web);
    $topic = Foswiki::Sandbox::untaintUnchecked($topic);

    # FIXME: This is slow, it can be improved by caching topic rev
    # info and summary
    my $users = $this->{session}->{users};

    my $topicObject = Foswiki::Meta->new( $this->{session}, $web, $topic );
    my $info        = $topicObject->getRevisionInfo();
    my $tooltip     = $this->{LINKTOOLTIPINFO};
    $tooltip =~ s/\$web/<nop>$web/g;
    $tooltip =~ s/\$topic/<nop>$topic/g;
    $tooltip =~ s/\$rev/1.$info->{version}/g;
    $tooltip =~ s/\$date/Foswiki::Time::formatTime( $info->{date} )/ge;
    $tooltip =~ s/\$username/
      $users->getLoginName($info->{author}) || $info->{author}/ge;
    $tooltip =~ s/\$wikiname/
      $users->getWikiName($info->{author}) || $info->{author}/ge;
    $tooltip =~ s/\$wikiusername/
      $users->webDotWikiName($info->{author}) || $info->{author}/ge;

    if ( $tooltip =~ /\$summary/ ) {
        my $summary;
        if ( $topicObject->haveAccess('VIEW') ) {
            $summary = $topicObject->text || '';
        }
        else {
            $summary =
              $this->{session}
              ->inlineAlert( 'alerts', 'access_denied', "$web.$topic" );
        }
        $summary = $topicObject->summariseText();
        $summary =~
          s/[\"\']//g;    # remove quotes (not allowed in title attribute)
        $tooltip =~ s/\$summary/$summary/g;
    }
    return $tooltip;
}

=begin TML

---++ ObjectMethod internalLink ( $web, $topic, $linkText, $anchor, $linkIfAbsent, $keepWebPrefix, $hasExplicitLinkLabel ) -> $html

Generate a link.

Note: Topic names may be spaced out. Spaced out names are converted
to <nop>WikWords, for example, "spaced topic name" points to "SpacedTopicName".
   * =$web= - the web containing the topic
   * =$topic= - the topic to be link
   * =$linkText= - text to use for the link
   * =$anchor= - the link anchor, if any
   * =$linkIfAbsent= - boolean: false means suppress link for
     non-existing pages
   * =$keepWebPrefix= - boolean: true to keep web prefix (for
     non existing Web.TOPIC)
   * =$hasExplicitLinkLabel= - boolean: true if
     [[link][explicit link label]]

Called from outside the package by Func::internalLink

Calls _renderWikiWord, which in turn will use Plurals.pm to match fold
plurals to equivalency with their singular form

SMELL: why is this available to Func?

=cut

sub internalLink {
    my ( $this, $web, $topic, $linkText, $anchor, $linkIfAbsent, $keepWebPrefix,
        $hasExplicitLinkLabel, $params )
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
    $topic = ucfirst($topic);
    $topic =~ s/\s([$Foswiki::regex{mixedAlphaNum}])/\U$1/go;

    # If locales are in effect, the above conversions will taint the topic
    # name (Foswiki:Tasks:Item2091)
    $topic = Foswiki::Sandbox::untaintUnchecked($topic);

    # Add <nop> before WikiWord inside link text to prevent double links
    $linkText =~ s/(?<=[\s\(])([$Foswiki::regex{upperAlpha}])/<nop>$1/go;
    return _renderWikiWord( $this, $web, $topic, $linkText, $anchor,
        $linkIfAbsent, $keepWebPrefix, $params );
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
        $this->{session}->{cache}->addDependency( $web, $topic )
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
        $this->{session}->{cache}->addDependency( $web, $topic )
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
    my $tooltip = _linkToolTipInfo( $this, $web, $topic );
    $attrs{title} = $tooltip if $tooltip;

    my $link = CGI::a( \%attrs, $text );

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
      (      $topic =~ /^$Foswiki::regex{abbrevRegex}$/o
          && $web ne $this->{session}->{webName} );

    # false means suppress link for non-existing pages
    $linkIfAbsent = ( $topic !~ /^$Foswiki::regex{abbrevRegex}$/o );

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
                   )/<nop>$1/gox;

        # Explicit links
        $text =~ s/($Foswiki::regex{linkProtocolPattern}):(?=\S)/$1<nop>:/go;
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
        $text                 = _escapeAutoLinks($text);
    }

    if ( $link =~ m#^($Foswiki::regex{linkProtocolPattern}:|/)# ) {

        # Explicit external [[http://$link]] or [[http://$link][$text]]
        # or explicit absolute [[/$link]] or [[/$link][$text]]
        if ( !defined($text) && $link =~ /^(\S+)\s+(.*)$/ ) {

            my $candidateLink = $1;
            my $candidateText = $2;

            # If the URL portion contains a ? indicating query parameters then
            # the spaces are possibly embedded in the query string, so don't
            # use the legacy format.
            if ( $candidateLink !~ m/\?/ ) {

                # Legacy case of '[[URL anchor display text]]' link
                # implicit untaint is OK as we are just recycling topic content
                $link = $candidateLink;
                $text = _escapeAutoLinks($candidateText);
            }
        }
        return _externalLink( $this, $link, $text );
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
    $link =~ s/\&[a-z]+\;//gi;

    # filter out &#123; entities (legacy)
    $link =~ s/\&\#[0-9]+\;//g;

    # Filter junk
    $link =~ s/$Foswiki::cfg{NameFilter}+/ /g;

    ASSERT( UNTAINTED($link) ) if DEBUG;

    # Capitalise first word
    $link = ucfirst($link);

    # Collapse spaces and capitalise following letter
    $link =~ s/\s([$Foswiki::regex{mixedAlphaNum}])/\U$1/go;

    # Get rid of remaining spaces, i.e. spaces in front of -'s and ('s
    $link =~ s/\s//go;

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
            $url =~ s/&(\w+);/$REMARKER$1$REEND/g;                  # "&abc;"
            $url =~ s/&(#x?[0-9a-f]+);/$REMARKER$1$REEND/gi;        # "&#123;"
            $url =~ s/([^\w$REMARKER$REEND])/'&#'.ord($1).';'/ge;
            $url =~ s/$REMARKER(#x?[0-9a-f]+)$REEND/&$1;/goi;
            $url =~ s/$REMARKER(\w+)$REEND/&$1;/go;
            if ($text) {
                $text =~ s/\@/'&#'.ord('@').';'/ge;
            }
        }
    }
    else {
        $opt = ' target="_top"';
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
    return $text if $url =~ /^(?:!|\<nop\>)/;

#use Email::Valid             ();
#my $tmpEmail = $url;
#$tmpEmail =~ s/^mailto://;
#my $errtxt = '';
#$errtxt =  "<b>INVALID</b> $tmpEmail " unless (Email::Valid->address($tmpEmail));

    # Any special characters in the user portion must be %hex escaped.
    $url =~ s/^((?:mailto\:)?)?(.*?)(@.*?)$/'mailto:'._escape( $2 ).$3/msiex;
    my $lenLeft  = length($2);
    my $lenRight = length($3);

# Per RFC 3696 Errata,  length restricted to 254 overall per RFC 2821 RCPT limits
    return $text
      if ( $lenLeft > 64 || $lenRight > 254 || $lenLeft + $lenRight > 254 );

    $url = 'mailto:' . $url unless $url =~ /^mailto:/i;
    return _externalLink( $this, $url, $text );
}

sub _escape {
    my $txt = shift;

    my $chars = join( '', keys(%ESCAPED) );
    $txt =~ s/([$chars])/$ESCAPED{$1}/g;
    $txt =~ s/[\s]/%20/g;                  # Any folding white space
    return $txt;
}

=begin TML

---++ ObjectMethod renderFORMFIELD ( %params, $topic, $web ) -> $html

Returns the fully rendered expansion of a %FORMFIELD{}% tag.

=cut

sub renderFORMFIELD {
    my ( $this, $params, $topicObject ) = @_;

    my $formField = $params->{_DEFAULT};
    return '' unless defined $formField;
    my $altText = $params->{alttext};
    my $default = $params->{default};
    my $rev     = $params->{rev} || '';
    my $format  = $params->{format};

    $altText = '' unless defined $altText;
    $default = '' unless defined $default;

    unless ( defined $format ) {
        $format = '$value';
    }

    # SMELL: this local creation of a cache looks very suspicious. Suspect
    # this may have been a one-off optimisation.
    my $formTopicObject = $this->{ffCache}{ $topicObject->getPath() . $rev };
    unless ($formTopicObject) {
        $formTopicObject =
          Foswiki::Meta->load( $this->{session}, $topicObject->web,
            $topicObject->topic, $rev );
        unless ( $formTopicObject->haveAccess('VIEW') ) {

            # Access violation, create dummy meta with empty text, so
            # it looks like it was already loaded.
            $formTopicObject =
              Foswiki::Meta->new( $this->{session}, $topicObject->web,
                $topicObject->topic, '' );
        }
        $this->{ffCache}{ $formTopicObject->getPath() . $rev } =
          $formTopicObject;
    }

    my $text   = $format;
    my $found  = 0;
    my $title  = '';
    my @fields = $formTopicObject->find('FIELD');
    foreach my $field (@fields) {
        my $name = $field->{name};
        $title = $field->{title} || $name;
        if ( $title eq $formField || $name eq $formField ) {
            $found = 1;
            my $value = $field->{value};
            $text = $default if !length($value);
            $text =~ s/\$title/$title/go;
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

    $text = Foswiki::expandStandardEscapes($text);

    # render nop exclamation marks before words as <nop>
    $text =~ s/!(\w+)/<nop>$1/gs;

    return $text;
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

    # whitespace before <! tag (if it is the first thing) is illegal
    $text =~ s/^\s+(<![a-z])/$1/i;

    # clutch to enforce correct rendering at end of doc
    $text =~ s/\n?$/\n<nop>\n/s;

    # Maps of placeholders to tag parameters and text
    my $removed = {};

    # verbatim before literal - see Item3431
    $text = Foswiki::takeOutBlocks( $text, 'verbatim',  $removed );
    $text = Foswiki::takeOutBlocks( $text, 'literal',   $removed );
    $text = Foswiki::takeOutBlocks( $text, 'dirtyarea', $removed )
      if $Foswiki::cfg{Cache}{Enabled};

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
    $text =~ s/^>(.*?)$/'&gt;'.CGI::cite( {}, $1 ).CGI::br()/gem;

    # locate isolated < and > and translate to entities
    # Protect isolated <!-- and -->
    $text =~ s/<!--/{$REMARKER!--/g;
    $text =~ s/-->/--}$REMARKER/g;

    # SMELL: this next fragment does not handle the case where HTML tags
    # are embedded in the values provided to other tags. The only way to
    # do this correctly is to parse the HTML (bleagh!). So we just assume
    # they have been escaped.
    $text =~ s/<(\/?\w+(:\w+)?)>/{$REMARKER$1}$REMARKER/g;
    $text =~ s/<(\w+(:\w+)?(\s+.*?|\/)?)>/{$REMARKER$1}$REMARKER/g;

    # XML processing instruction only valid at start of text
    $text =~ s/^<(\?\w.*?\?)>/{$REMARKER$1}$REMARKER/g;

    # entitify lone < and >, praying that we haven't screwed up :-(
    # Item1985: CDATA sections are not lone < and >
    $text =~ s/<(?!\!\[CDATA\[)/&lt\;/g;
    $text =~ s/(?<!\]\])>/&gt\;/g;
    $text =~ s/{$REMARKER/</go;
    $text =~ s/}$REMARKER/>/go;

    # other entities
    $text =~ s/&(\w+);/$REMARKER$1;/g;              # "&abc;"
    $text =~ s/&(#x?[0-9a-f]+);/$REMARKER$1;/gi;    # "&#123;"
    $text =~ s/&/&amp;/g;                           # escape standalone "&"
    $text =~ s/$REMARKER(#x?[0-9a-f]+;)/&$1/goi;
    $text =~ s/$REMARKER(\w+;)/&$1/go;

    # clear the set of unique anchornames in order to inhibit
    # the 'relabeling' of anchor names if the same topic is processed
    # more than once, cf. explanation in expandMacros()
    my $anchors = $this->getAnchorNames($topicObject);
    $anchors->clear();

    # '#WikiName' anchors. Don't attempt to make these unique; renaming
    # user-defined anchors is not sensible.
    $text =~ s/^(\#$Foswiki::regex{wikiWordRegex})/
      CGI::a({
          name => $anchors->add( $1 )
         }, '')/geom;

    # Headings
    # '<h6>...</h6>' HTML rule
    $text =~ s/$Foswiki::regex{headerPatternHt}/
      _makeAnchorHeading($this, $2, $1, $anchors)/geo;

    # '----+++++++' rule
    $text =~ s/$Foswiki::regex{headerPatternDa}/
      _makeAnchorHeading($this, $2, length($1), $anchors)/geo;

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

            if ($isList) {

                # Table start should terminate previous list
                _addListItem( $this, \@result, '', '', '' );
                $isList = 0;
            }

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

    Foswiki::putBackBlocks( \$text, $removed, 'pre' );

    # DEPRECATED plugins hook after PRE re-inserted
    $plugins->dispatch( 'endRenderingHandler', $text );

    # replace verbatim with pre in the final output
    Foswiki::putBackBlocks( \$text, $removed, 'verbatim', 'pre',
        \&verbatimCallBack );
    $text =~ s|\n?<nop>\n$||o;    # clean up clutch

    $this->_putBackProtected( \$text, 'script', $removed, \&_filterScript );
    Foswiki::putBackBlocks( \$text, $removed, 'literal', '', \&_filterLiteral );
    $this->_putBackProtected( \$text, 'literal', $removed );
    Foswiki::putBackBlocks( \$text, $removed, 'dirtyarea' )
      if $Foswiki::cfg{Cache}{Enabled};
    $this->_putBackProtected( \$text, 'comment',  $removed );
    $this->_putBackProtected( \$text, 'head',     $removed );
    $this->_putBackProtected( \$text, 'textarea', $removed );

    $this->{session}->getLoginManager()->endRenderingHandler($text);

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
    return CGI::comment(
'<literal> is not allowed on this site - denied by deprecated {AllowInlineScript} setting'
    );
}

sub _filterScript {
    my $val = shift;
    return $val if ( $Foswiki::cfg{AllowInlineScript} );
    return CGI::comment(
'<script> is not allowed on this site - denied by deprecated {AllowInlineScript} setting'
    );
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
    $text =~ s/$STARTWW(
                   (mailto\:)?
                   [a-zA-Z0-9-_.+]+@[a-zA-Z0-9-_.]+\.[a-zA-Z0-9-_]+
                   )$ENDWW
              /_mailLink( $this, $1 )/gemx;
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

    foreach my $placeholder ( keys %$map ) {
        next unless $placeholder =~ /^$id\d+$/;
        my $val = $map->{$placeholder}{text};
        $val = &$callback($val) if ( defined($callback) );
        $$text =~ s/<!--$REMARKER$placeholder$REMARKER-->/$val/;
        delete( $map->{$placeholder} );
    }
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

    # nop if there are no format tokens
    return $value
      unless $value =~
/\$(year|ye|wikiusername|wikiname|week|web|wday|username|tz|topic|time|seconds|sec|rev|rcs|month|mo|minutes|min|longdate|isotz|iso|http|hours|hou|epoch|email|dow|day|date)/x;

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
/\$(year|ye|week|web|wday|username|tz|seconds|sec|rcs|month|mo|minutes|min|longdate|hours|hou|epoch|dow|day)/
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
      * =nosot= - If true, do not generate "Spaced out text" match
      * =template= - If true, match for template setting in Set/Local statement
      * =in_noautolink= - Only match explicit (squabbed) WikiWords.   Used in <noautolink> blocks
      * =inMeta= - Re should match exact string. No delimiters needed.
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

    # Convert . and / to [./] (subweb separators) and quote
    # special characters
    $matchWeb =~ s#[./]#$REMARKER#g;
    $matchWeb = quotemeta($matchWeb);

# SMELL: Item10176 -  Adding doublequote as a WikiWord delimiter.   This causes non-linking quoted
# WikiWords in tml to be incorrectly renamed.   But does handle quoted topic names inside macro parameters.
# But this doesn't really fully fix the issue - $quotWikiWord for example.
    my $reSTARTWW = qr/^|(?<=[\s"\*=_\(])/m;
    my $reENDWW   = qr/$|(?=[\s"\*#=_,.;:!?)])/m;

    # $REMARKER is escaped by quotemeta so we need to match the escape
    $matchWeb =~ s#\\$REMARKER#[./]#go;

    # Item1468/5791 - Quote special characters
    $topic = quotemeta($topic) if defined $topic;

    # Note use of \b to match the empty string at the
    # edges of a word.
    my ( $bow, $eow, $forward, $back ) = ( '\b_?', '_?\b', '?=', '?<=' );
    if ( $options{grep} ) {
        $bow     = '\b_?';
        $eow     = '_?\b';
        $forward = '';
        $back    = '';
    }
    my $squabo = "($back\\[\\[)";
    my $squabc = "($forward(?:#.*?)?\\][][])";

    my $re = '';

    if ( $options{url} ) {

        # URL fragment. Assume / separator (while . is legal, it's
        # undocumented and is not common usage)
        $re = "/$web/";
        $re .= $topic . $eow if $topic;
    }
    else {
        if ( defined($topic) ) {

            my $sot;
            unless ( $options{nosot} ) {

                # Work out spaced-out version (allows lc first chars on words)
                $sot = Foswiki::spaceOutWikiWord( $topic, ' *' );
                if ( $sot ne $topic ) {
                    $sot =~ s/\b([a-zA-Z])/'['.uc($1).lc($1).']'/ge;
                }
                else {
                    $sot = undef;
                }
            }

            if ( $options{interweb} ) {

                # Require web specifier
                if ( $options{grep} ) {
                    $re = "$bow$matchWeb\\.$topic$eow";
                }
                elsif ( $options{template} ) {

# $1 is used in replace.  Can't use lookbehind because of variable length restriction
                    $re = '('
                      . $Foswiki::regex{setRegex}
                      . '(?:VIEW|EDIT)_TEMPLATE\s*=\s*)('
                      . $matchWeb . '\\.'
                      . $topic . ')\s*$';
                }
                elsif ( $options{in_noautolink} ) {
                    $re = "$squabo$matchWeb\\.$topic$squabc";
                }
                else {
                    $re = "$reSTARTWW$matchWeb\\.$topic$reENDWW";
                }

                # Matching of spaced out topic names.
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
                    if ( $options{grep} ) {
                        $re = "(($back\[^./])|^)$bow($matchWeb\\.)?$topic$eow";
                    }
                    elsif ( $options{template} ) {

# $1 is used in replace.  Can't use lookbehind because of variable length restriction
                        $re = '('
                          . $Foswiki::regex{setRegex}
                          . '(?:VIEW|EDIT)_TEMPLATE\s*=\s*)'
                          . "($matchWeb\\.)?$topic" . '\s*$';
                    }
                    elsif ( $options{in_noautolink} ) {
                        $re = "$squabo($matchWeb\\.)?$topic$squabc";
                    }
                    else {
                        $re = "$reSTARTWW($matchWeb\\.)?$topic$reENDWW";
                    }

                    if ($sot) {

                        # match spaced out in squabs only
                        $re .= "|$squabo($matchWeb\\.)?$sot$squabc";
                    }
                }
                else {
                    if ( $options{inMeta} ) {
                        $re = "^($matchWeb\\.)?$topic\$"
                          ;  # Updating a META item,  Exact match, no delimiters
                    }
                    else {

                        # Non-wikiword; require web specifier or squabs
                        $re = "$squabo$topic$squabc";    # Squabbed topic
                        $re .= "|\"($matchWeb\\.)?$topic\""
                          ;    # Quoted string in Meta and Macros
                        $re .= "|(($back\[^./])|^)$bow$matchWeb\\.$topic$eow"
                          unless ( $options{in_noautolink} )
                          ;    # Web qualified topic outside of autolink blocks.
                    }
                }
            }
        }
        else {

            # Searching for a web
            # SMELL:  Does this web search also need to allow for quoted
            # "Web.Topic" strings found in macros and META usage?

            if ( $options{interweb} ) {

                if ( $options{in_noautolink} ) {

                    # web name used to refer to a topic
                    $re =
                        $squabo
                      . $matchWeb
                      . "(\.[$Foswiki::regex{mixedAlphaNum}]+)"
                      . $squabc;
                }
                else {
                    $re =
                        $bow
                      . $matchWeb
                      . "(\.[$Foswiki::regex{mixedAlphaNum}]+)"
                      . $eow;
                }
            }
            else {

                # most general search for a reference to a topic or subweb
                # note that Foswiki::UI::Rename::_replaceWebReferences()
                # uses $1 from this regex
                if ( $options{in_noautolink} ) {
                    $re =
                        $squabo
                      . $matchWeb
                      . "(([\/\.][$Foswiki::regex{upperAlpha}]"
                      . "[$Foswiki::regex{mixedAlphaNum}_]*)+"
                      . "\.[$Foswiki::regex{mixedAlphaNum}]*)"
                      . $squabc;
                }
                else {
                    $re =
                        $bow
                      . $matchWeb
                      . "(([\/\.][$Foswiki::regex{upperAlpha}]"
                      . "[$Foswiki::regex{mixedAlphaNum}_]*)+"
                      . "\.[$Foswiki::regex{mixedAlphaNum}]*)"
                      . $eow;
                }
            }
        }
    }

#my $optsx = '';
#$optsx .= "NOSOT=$options{nosot} " if ($options{nosot});
#$optsx .= "GREP=$options{grep} " if ($options{grep});
#$optsx .= "URL=$options{url} " if ($options{url});
#$optsx .= "INNOAUTOLINK=$options{in_noautolink} " if ($options{in_noautolink});
#$optsx .= "INTERWEB=$options{interweb} " if ($options{interweb});
#print STDERR "ReferenceRE returns $re $optsx  \n";
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

---++ ObjectMethod getAnchors( $topicObject ) -> $set

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

=begin TML

---++ ObjectMethod renderIconImage($url [, $alt]) -> $html
Generate the output for representing an 16x16 icon image. The source of
the image is taken from =$url=. The optional =$alt= specifies an alt string.

re-written using TMPL:DEF{icon:image} in Foswiki.tmpl
%TMPL:DEF{"icon:image"}%<span class='foswikiIcon'><img src="%URL%" width="%WIDTH%" height="%HEIGHT%" alt="%ALT%" /></span>%TMPL:END%
see System.SkinTemplates:base.css for the default of .foswikiIcon img

TODO: Sven's not sure this code belongs here - its only use appears to be the ICON macro

=cut

sub renderIconImage {
    my ( $this, $url, $alt ) = @_;

    if ( !defined($alt) ) {

        #yes, you really should have a useful alt text.
        $alt = $url;
    }

    my $html = $this->{session}->templates->expandTemplate("icon:image");
    $html =~ s/%URL%/$url/ge;
    $html =~ s/%WIDTH%/16/g;
    $html =~ s/%HEIGHT%/16/g;
    $html =~ s/%ALT%/$alt/ge;

    return $html;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
