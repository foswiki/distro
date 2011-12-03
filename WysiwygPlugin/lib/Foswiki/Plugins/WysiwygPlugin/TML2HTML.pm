# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Plugins::WysiwygPlugin::TML2HTML

Convertor class for translating TML (Topic Meta Language) into
HTML

The convertor does _not_ use the Foswiki rendering, as that is a
lossy conversion, and would make symmetric translation back to TML
an impossibility.

The design goal was to support round-trip conversion from well-formed
TML to XHTML1.0 and back to identical TML. Notes that some deprecated
TML syntax is not supported.

=cut

package Foswiki::Plugins::WysiwygPlugin::TML2HTML;

use CGI qw( -any );
use Error qw( :try );

use Foswiki;
use Foswiki::Plugins::WysiwygPlugin::Constants;
use Foswiki::Plugins::WysiwygPlugin::Handlers;

use strict;
use warnings;

my $TT0 = chr(0);
my $TT1 = chr(1);
my $TT2 = chr(2);

# HTML elements that are palatable to editors. Other HTML tags will be
# rendered in 'protected' regions to prevent the WYSIWYG editor mussing
# them up. Note that A is specifically excluded from this list because it
# is common for href attributes to contain macros. Users should
# be encouraged to use square bracket formulations for links instead.
my @PALATABLE_TAGS = qw(
  ABBR ACRONYM ADDRESS B BDO BIG BLOCKQUOTE BR CAPTION CITE CODE COL
  COLGROUP DD DEL DFN DIR DIV DL DT EM FONT H1 H2 H3 H4 H5 H6 HR HTML I IMG INS
  ISINDEX KBD LABEL LEGEND LI OL P PRE Q S SAMP SMALL SPAN STRONG SUB SUP TABLE
  TBODY TD TFOOT TH THEAD TITLE TR TT U UL STICKY
);

my $PALATABLE_HTML = '(' . join( '|', @PALATABLE_TAGS ) . ')';

# There are several tags that could come before a table tag
my @tagsBeforeTable = (
    '<div class="foswikiTableAndMacros">',
    '<p>\s*<div class="WYSIWYG_LITERAL">',    #SMELL - not valid HTML
    '<p>',    # from HTML tables not in sticky or literal blocks
);
my $tagsBeforeFirstTablePattern =
  '^\\s*(?:' . join( '|', map { $_ . '\\s*' } @tagsBeforeTable ) . ')?<table';

=pod

---++ ClassMethod new()

Construct a new TML to HTML convertor.

=cut

sub new {
    my $class = shift;
    my $this  = {};
    return bless( $this, $class );
}

=pod

---++ ObjectMethod convert( $tml, \%options ) -> $tml

Convert a block of TML text into HTML.
Options:
   * getViewUrl is a reference to a method:<br>
     getViewUrl($web,$topic) -> $url (where $topic may include an anchor)
   * expandVarsInURL is a reference to a static method:<br>
     expandVarsInURL($url, \%options) -> $url<br>
     that expands selected variables in URLs so that, for example,
     <img> tags appear as pictures in the wysiwyg editor.
   * xmltag is a reference to a hash. The keys are names of XML-like
     tags. The values are references to a function to determine if the
     content of the tag must be protected:<br>
     fn($markup) -> $bool<br>
     The $markup appears between the <tag></tag> delimiters.
     The functions may modify the markup.
   * dieOnError makes convert throw an exception if a conversion fails.
     The default behaviour is to encode the whole topic as verbatim text.

=cut

sub convert {
    my ( $this, $content, $options ) = @_;

    $this->{opts} = $options;

    return '' unless $content;

    my $disabled =
      Foswiki::Plugins::WysiwygPlugin::wysiwygEditingDisabledForThisContent(
        $content);
    if ($disabled) {

      # encode the content verbatim-style, so that the user has uncorrupted HTML
        $content =~ s/[$TT0$TT1$TT2]/?/go;
        $content = CGI::div(
            { class => 'WYSIWYG_WARNING foswikiBroadcastMessage' },
            Foswiki::Func::renderText(
                Foswiki::Func::expandCommonVariables( <<"WARNING" ) ) )
*%MAKETEXT{"Conversion to HTML for WYSIWYG editing is disabled because of the topic content."}%*

%MAKETEXT{"This is why the conversion is disabled:"}% $disabled

%MAKETEXT{"(This message will be removed automatically)"}%
WARNING
          . CGI::div( { class => 'WYSIWYG_PROTECTED' },
            _protectVerbatimChars($content) );
    }
    else {
        my $tagsToProtect = Foswiki::Func::getPreferencesValue(
            'WYSIWYGPLUGIN_PROTECT_EXISTING_TAGS')
          || 'div,span';
        for my $tag ( split /[,\s]+/, $tagsToProtect ) {
            next unless $tag =~ /^\w+$/;
            $this->{protectExistingTags}->{$tag} = 1;
        }

        # Convert TML to HTML for wysiwyg editing

        $content =~ s/[$TT0$TT1$TT2]/?/go;

        # Render TML constructs to tagged HTML
        $content = $this->_getRenderedVersion($content);

        my $fail = '';
        $fail .= "TT0:[$1|TT0|$2]" if $content =~ /(.{0,10})[$TT0](.{0,10})/o;
        $fail .= "TT1:[$1|TT1|$2]" if $content =~ /(.{0,10})[$TT1](.{0,10})/o;
        $fail .= "TT2:[$1|TT2|$2]" if $content =~ /(.{0,10})[$TT2](.{0,10})/o;
        if ($fail) {

            # There should never be any of these in the text at this point.
            # If there are, then the conversion failed.
            die("Invalid characters in HTML after conversion: $fail")
              if $options->{dieOnError};

            # Encode the original TML as verbatim-style HTML,
            # so that the user has uncorrupted TML, at least.
            my $originalContent = $_[1];
            $originalContent =~ s/[$TT0$TT1$TT2]/?/go;
            $originalContent = _protectVerbatimChars($originalContent);
            $content =
              CGI::div( { class => 'WYSIWYG_PROTECTED' }, $originalContent );
        }
    }

    # DEBUG
    #print STDERR "TML2HTML = '$content'\n";

    # This should really use a template, but what the heck...
    return $content;
}

sub _liftOut {
    my ( $this, $text, $type ) = @_;
    my %options;
    if ( $type and $type =~ /^(?:PROTECTED|STICKY|VERBATIM)$/ ) {
        $options{protect} = 1;
    }
    $options{class} = 'WYSIWYG_' . $type;
    return $this->_liftOutGeneral( $text, \%options );
}

sub _liftOutGeneral {
    my ( $this, $text, $options ) = @_;

    #$text = $this->_unLift($text);

    $options = {} unless ref($options);

    my $n = scalar( @{ $this->{refs} } );
    push(
        @{ $this->{refs} },
        {
            tag => $options->{tag} || 'span',
            text    => $text,
            tmltag  => $options->{tmltag},
            params  => $options->{params},
            class   => $options->{class},
            protect => $options->{protect},
        }
    );

    return $TT1 . $n . $TT2;
}

sub _unLift {
    my ( $this, $text ) = @_;

    # Restore everything that was lifted out
    while ( $text =~ s#$TT1([0-9]+)$TT2#$this->{refs}->[$1]->{text}#g ) {
    }
    return $text;
}

sub _dropBack {
    my ( $this, $text, $protecting ) = @_;

    # Restore everything that was lifted out
    while ( $text =~ s#$TT1([0-9]+)$TT2#$this->_dropIn($1, $protecting)#ge ) {
    }
    return $text;
}

sub _dropIn {
    my ( $this, $n, $protecting ) = @_;
    my $thing = $this->{refs}->[$n];

    my $text = $thing->{text};

    # Drop back recursively
    $text = $this->_dropBack( $text, $protecting || $thing->{protect} );

    # Only protect at the outer-most level applicable
    $text = _protectVerbatimChars($text)
      if $thing->{protect} and not $protecting;

    if ($protecting) {
        if ( $thing->{tmltag} ) {
            return
"<$thing->{tmltag}$thing->{params}>$thing->{text}</$thing->{tmltag}>";
        }
        else {
            return $thing->{text};
        }
    }
    return $thing->{text} if $thing->{tag} eq 'NONE';

    my $method = 'CGI::' . $thing->{tag};

    $thing->{params} ||= {};
    $thing->{params} = _parseParams( $thing->{params} )
      if not ref $thing->{params};
    _addClass( $thing->{params}->{class}, $thing->{class} ) if $thing->{class};

    no strict 'refs';
    return &$method( $thing->{params}, $text );
    use strict 'refs';
}

# Parse and convert macros. If we are not using span markers
# for macros, we have to change the percent signs into entities
# to prevent internal tags being expanded by Foswiki during rendering.
# It's assumed that the editor will have the common sense to convert
# them back to characters when editing.
sub _processTags {
    my ( $this, $text ) = @_;

    return '' unless defined($text);

    # Macros at the start of a line must *stay* at the start of a line.
    # The newline preceding the mcro must be preserved.
    # This is important for macros like %SEARCH that can emit
    # line-oriented TML.
    #
    # This split captures the preceding newline along with the %,
    # if present, as that is a convenient way to include the newline
    # in the protected span.
    #
    # The result is something like this:
    # <span class="WYSIWYG_PROTECTED"><br />%TABLESEP%</span>
    my @queue = split( /(\n?%)/s, $text );
    my @stack;
    my $stackTop = '';

    while ( scalar(@queue) ) {
        my $token = shift(@queue);
        if ( $token =~ /^\n?%$/s ) {
            if ( $token eq '%' && $stackTop =~ /}$/ ) {
                while ( scalar(@stack)
                    && $stackTop !~
                    /^\n?%($Foswiki::regex{tagNameRegex}){.*}$/os )
                {
                    $stackTop = pop(@stack) . $stackTop;
                }
            }
            if (   $token eq '%'
                && $stackTop =~
                m/^(\n?)%($Foswiki::regex{tagNameRegex})({.*})?$/os )
            {
                my $nl = $1;
                my $tag = $2 . ( $3 || '' );
                $tag = "$nl%$tag%";

              # The commented out lines disable PROTECTED for %SIMPLE% vars. See
              # Bugs: Item4828 for the sort of problem this would help to avert.
              #                if ($tag =~ /^\n?%\w+{.*}%/) {
                $stackTop =
                  pop(@stack) . $nl . $this->_liftOut( $tag, 'PROTECTED' );

                #                } else {
                #                    $stackTop = pop( @stack ).$tag;
                #                }
            }
            else {
                push( @stack, $stackTop );
                $stackTop = $token;    # push a new context
            }
        }
        else {
            $stackTop .= $token;
        }
    }

    # Run out of input. Gather up everything in the stack.
    while ( scalar(@stack) ) {
        $stackTop = pop(@stack) . $stackTop;
    }

    return $stackTop;
}

sub _expandURL {
    my ( $this, $url ) = @_;

    return $url unless ( $this->{opts}->{expandVarsInURL} );
    return $this->{opts}->{expandVarsInURL}->( $url, $this->{opts} );
}

# Lifted straight out of DevelopBranch Render.pm
# Then modified to include TablePlugin's approach to table rendering
sub _getRenderedVersion {
    my ( $this, $text, $refs ) = @_;

    return '' unless $text;    # nothing to do

    @{ $this->{LIST} } = ();
    $this->{refs} = [];

    # Initial cleanup
    $text =~ s/\r//g;
    $text =~ s/^\n*//s;
    $text =~ s/\n*$//s;

    $this->{removed} = {};     # Map of placeholders to tag parameters and text

    # Do sticky first; it can't be ignored
    $text = $this->_liftOutBlocks(
        $text, 'sticky',
        {
            tag     => 'div',
            protect => 1,
            class   => 'WYSIWYG_STICKY'
        }
    );

    $text = $this->_liftOutBlocks(
        $text,
        'verbatim',
        {
            tag     => 'pre',
            protect => 1,
            class   => 'TMLverbatim'
        }
    );

    $text = $this->_liftOutBlocks(
        $text,
        'literal',
        {
            tag   => 'div',
            class => 'WYSIWYG_LITERAL'
        }
    );

    $text = $this->_takeOutSets($text);

    $text = $this->_takeOutCustomTags($text);

    $text =~ s/\t/   /g;
    $text =~ s/( +\\\n)/$this->_hideWhitespace($1)/ge;

    # Remove PRE to prevent TML interpretation of text inside it
    $text = $this->_liftOutBlocks( $text, 'pre', {} );

    # Protect comments
    $text =~ s/(<!--.*?-->)/$this->_liftOut($1, 'PROTECTED')/ges;

    # Handle inline IMG tags specially
    $text =~ s/(<img [^>]*>)/$this->_takeOutIMGTag($1)/gei;
    $text =~ s/<\/img>//gi;

    $text =~
s/<([A-Za-z]+[^>]*?)((?:\s+\/)?)>/"<" . $this->_appendClassToTag($1, 'TMLhtml') . $2 . ">"/ge;

    # Handle colour tags specially (hack, hack, hackity-HACK!)
    my $colourMatch = join( '|', grep( /^[A-Z]/, @WC::TML_COLOURS ) );
    $text =~ s#%($colourMatch)%(.*?)%ENDCOLOR%#
      _getNamedColour($1, $2)#oge;

    # Convert Foswiki tags to spans outside protected text
    $text = $this->_processTags($text);

    # protect some HTML tags.
    $text =~ s/(<\/?(?!(?i:$PALATABLE_HTML)\b)[A-Z]+(\s[^>]*)?>)/
      $this->_liftOut($1, 'PROTECTED')/gei;

# SMELL: This was just done, about 25 lines above! Commenting out to see what breaks...
#$text =~ s/\\\n//gs;    # Join lines ending in '\'

    # Blockquoted email (indented with '> ')
    # Could be used to provide different colours for different numbers of '>'
    $text =~
      s/^>(.*?)$/'&gt;'.CGI::cite( { class => 'TMLcite' }, $1 ).CGI::br()/gem;

    # locate isolated < and > and translate to entities
    # Protect isolated <!-- and -->
    $text =~ s/<!--/{$TT0!--/g;
    $text =~ s/-->/--}$TT0/g;

    # SMELL: this next fragment is a frightful hack, to handle the
    # case where simple HTML tags (i.e. without values) are embedded
    # in the values provided to other tags. The only way to do this
    # correctly (i.e. handle HTML tags with values as well) is to
    # parse the HTML (bleagh!)
    $text =~ s/<(\/[A-Za-z]+)>/{$TT0$1}$TT0/g;
    $text =~ s/<([A-Za-z]+(\s+\/)?)>/{$TT0$1}$TT0/g;
    $text =~ s/<(\S.*?)>/{$TT0$1}$TT0/g;

    # entitify lone < and >, praying that we haven't screwed up :-(
    $text =~ s/</&lt\;/g;
    $text =~ s/>/&gt\;/g;
    $text =~ s/{$TT0/</go;
    $text =~ s/}$TT0/>/go;

    # standard URI
    $text =~
s/((^|(?<=[-*\s(]))$Foswiki::regex{linkProtocolPattern}:[^\s<>"]+[^\s*.,!?;:)<])/$this->_liftOut($1, 'LINK')/geo;

    # other entities
    # SMELL - international characters are not allowed in entity names
    $text =~ s/&([$Foswiki::regex{mixedAlphaNum}]+;)/$TT0$1/g;    # "&abc;"
    $text =~ s/&(#[0-9]+;)/$TT0$1/g;                              # "&#123;"
         #$text =~ s/&/&amp;/g;             # escape standalone "&"
    $text =~ s/$TT0(#[0-9]+;)/&$1/go;
    $text =~ s/$TT0([$Foswiki::regex{mixedAlphaNum}]+;)/&$1/go;

    # Horizontal rule
    $text =~ s/^(---+)$/_encodeHr($1)/gme;

    # Wrap tables with macros before or after them in a <div>,
    # together with the macros,
    # so that TMCE may be used without the force_root_block option
    my @lines            = split( /\n/, $text );
    my $divableStartLine = undef;
    my $hasTable         = 0;
    my $hasMacro         = 0;
    my @divIndexes       = ();
    for my $lineNumber ( 0 .. $#lines ) {

        # Table: | cell | cell |
        # allow trailing white space after the last |
        if ( $lines[$lineNumber] =~ m/^\s*\|.*\|\s*$/ ) {
            $divableStartLine = $lineNumber
              if not defined $divableStartLine;
            $hasTable = 1;
        }

        # Macro, after it was lifted out by _processTags
        elsif ( $lines[$lineNumber] =~ m/$TT1(\d+)$TT2/
            and $this->{refs}->[$1]->{text} =~ /^\n?%/ )
        {
            $divableStartLine = $lineNumber
              if not defined $divableStartLine;
            $hasMacro = 1;
        }

        # Neither table line nor macro
        else {
            if ( defined $divableStartLine ) {
                if ( $hasMacro and $hasTable ) {
                    push @divIndexes,
                      { start => $divableStartLine, end => $lineNumber };
                }
                undef $divableStartLine;
                $hasMacro = 0;
                $hasTable = 0;
            }
        }
    }
    if ( defined $divableStartLine ) {
        if ( $hasMacro and $hasTable ) {
            push @divIndexes, { start => $divableStartLine, end => $#lines };
        }
    }
    my $tableAndMacrosDivStart = '<div class="foswikiTableAndMacros">';
    my $tableAndMacrosDivEnd   = '</div><!--foswikiTableAndMacros-->';
    while (@divIndexes) {

        # Work backwards from the end,
        # so that the indexes are correct as they are processed
        my $set = pop @divIndexes;
        splice @lines, $set->{end} + 1, 0, $tableAndMacrosDivEnd;
        splice @lines, $set->{start}, 0, $tableAndMacrosDivStart;
    }
    $text = join( "\n", @lines );

    # Now we really _do_ need a line loop, to process TML
    # line-oriented stuff.
    my $inList      = 0;    # True when within a list type
    my $inTable     = 0;    # True when within a table type
    my %table       = ();
    my $inParagraph = 0;    # True when within a P
    my $inDiv       = 0;    # True when within a foswikiTableAndMacros div
    my @result      = ();

    foreach my $line ( split( /\n/, $text ) ) {
        my $tableEnded = 0;

        # Table: | cell | cell |
        # allow trailing white space after the last |
        if ( $line =~ m/^(\s*\|.*\|\s*)$/ ) {
            push( @result, '</p>' ) if $inParagraph;
            $inParagraph = 0;
            $this->_addListItem( \@result, '', '', '', '' ) if $inList;
            $inList = 0;
            push( @result, _processTableRow( $1, $inTable, \%table ) );
            $inTable = 1;
            next;
        }

        if ($inTable) {
            push( @result, _emitTable( \%table ) );
            $inTable    = 0;
            $tableEnded = 1;
        }

        if ( $line =~ /$Foswiki::regex{headerPatternDa}/o ) {

            # Running head
            $this->_addListItem( \@result, '', '', '', '' ) if $inList;
            $inList = 0;
            push( @result, '</p>' ) if $inParagraph;
            $inParagraph = 0;
            my ( $indicator, $heading ) = ( $1, $2 );
            my $class = 'TML';
            if ( $heading =~ s/$Foswiki::regex{headerPatternNoTOC}//o ) {
                $class .= ' notoc';
            }
            if ( $indicator =~ /#/ ) {
                $class .= ' numbered';
            }
            my $attrs = { class => $class };
            my $fn = 'CGI::h' . length($indicator);
            no strict 'refs';
            $line = &$fn( $attrs, " $heading " );
            use strict 'refs';

        }
        elsif ( $line =~ /^\s*$/ ) {

            # Blank line
            my $class = '';
            if ( not $inParagraph ) {
                $class = 'WYSIWYG_NBNL';
            }
            $class = " class='$class'" if $class;

            push( @result, '</p>' ) if $inParagraph;
            $inParagraph = 0;

            $line = '<p' . $class . '>';

            $this->_addListItem( \@result, '', '', '', '' ) if $inList;
            $inList = 0;

            $inParagraph = 1;

        }
        elsif ( $line =~
            s/^((\t|   )+)\$\s(([^:]+|:[^\s]+)+?):\s/<dt> $3 <\/dt><dd> /o )
        {

            # Definition list
            push( @result, '</p>' ) if $inParagraph;
            $inParagraph = 0;
            $this->_addListItem( \@result, 'dl', 'dd', '', $1 );
            $inList = 1;

        }
        elsif ( $line =~ s/^((\t|   )+)(\S+?):\s/<dt> $3<\/dt><dd> /o ) {

            # Definition list
            push( @result, '</p>' ) if $inParagraph;
            $inParagraph = 0;
            $this->_addListItem( \@result, 'dl', 'dd', '', $1 );
            $inList = 1;

        }
        elsif ( $line =~ s/^((\t|   )+)\*(\s|$)/<li> /o ) {

            # Unnumbered list
            push( @result, '</p>' ) if $inParagraph;
            $inParagraph = 0;
            $this->_addListItem( \@result, 'ul', 'li', '', $1 );
            $inList = 1;

            # TinyMCE won't let the cursor go into an empty element
            # so make sure that the element isn't empty.
            $line =~ s/^(<li>)\s*$/$1&nbsp;/;

        }
	elsif ( $line =~ s/^((\t|   )+): /<div class='foswikiIndent'> /o ) {

	    # Indent pseudo-list
	    $this->_addListItem( \@result, '', 'div', 'class="foswikiIndent"', $1 );
	    $inList = 1;
	}
        elsif ( $line =~ m/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/ ) {

            # Numbered list
            push( @result, '</p>' ) if $inParagraph;
            $inParagraph = 0;
            my $ot = $3;
            $ot =~ s/^(.).*/$1/;
            if ( $ot !~ /^\d$/ ) {
                $ot = ' type="' . $ot . '"';
            }
            else {
                $ot = '';
            }
            $line =~ s/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/<li$ot> /;
            $this->_addListItem( \@result, 'ol', 'li', '', $1 );
            $inList = 1;

            # TinyMCE won't let the cursor go into an empty element
            # so make sure that the element isn't empty.
            $line =~ s/^(<li\Q$ot\E>)\s*$/$1&nbsp;/;

        }
        elsif ($inList
            && $line =~ s/^([ \t]+)/$this->_hideWhitespace("\n$1")/e )
        {

            # Extend text of previous list item by dropping through
            $result[-1] .= $line;
            $line = '';

        }
        elsif ( $line =~ /^<hr class="TMLhr"/ ) {
            push( @result, '</p>' ) if $inParagraph;
            $inParagraph = 0;
        }
        elsif ( $line eq $tableAndMacrosDivStart ) {
            push( @result, '</p>' ) if $inParagraph;
            $inParagraph = 0;
            $this->_addListItem( \@result, '', '', '' ) if $inList;
            $inList = 0;
            $inDiv  = 1;
        }
        elsif ( $line eq $tableAndMacrosDivEnd ) {
            $this->_addListItem( \@result, '', '', '' ) if $inList;
            $inList = 0;
            $inDiv  = 0;

            # The comment was only needed for this test,
            # and it must be removed to prevent it ending up in TML
            $line = '</div>';
        }
        else {

            # Other line
            $this->_addListItem( \@result, '', '', '' ) if $inList;
            $inList = 0;
            if (    $inParagraph
                and @result
                and $result[-1] !~ /<p(?: class='[^']+')?>$/ )
            {

                # This is the second (or later) line of a paragraph

                my $whitespace = "\n";
                if (    $line =~ m/^$TT1(\d+)$TT2/
                    and $this->{refs}->[$1]->{text} =~ /^\n?%/ )
                {

                    # The newline is already protected
                    $whitespace = "";
                }
                if ( $line =~ s/^(\s+)// ) {
                    $whitespace .= $1;
                }
                $line = $this->_hideWhitespace($whitespace) . $line
                  if length($whitespace);
            }
            unless ( $inParagraph or $inDiv ) {
                push( @result, '<p>' );
                $inParagraph = 1;
            }
            $line =~ s/(\s\s+)/$this->_hideWhitespace($1)/ge;
            $result[-1] .= $line;
            $line = '';
        }

        push( @result, $line ) if length($line) > 0;
    }

    if ($inTable) {
        push( @result, _emitTable( \%table ) );
    }
    elsif ($inList) {
        $this->_addListItem( \@result, '', '', '' );
    }
    elsif ($inParagraph) {
        push( @result, '</p>' );
    }
    elsif ($inDiv) {
        push( @result, '</div>' );
    }

    $text = join( "\n", @result );

    # Trim any extra Ps from the top and bottom.
    $text =~ s#^(\s*<p>\s*</p>)+##s;
    $text =~ s#(<p>\s*</p>\s*)+$##s;

    $text =~ s(${WC::STARTWW}==([^\s]+?|[^\s].*?[^\s])==$WC::ENDWW)
      (CGI::b(CGI::span({class => 'WYSIWYG_TT'}, $1)))gem;
    $text =~ s(${WC::STARTWW}__([^\s]+?|[^\s].*?[^\s])__$WC::ENDWW)
      (CGI::b(CGI::i($1)))gem;
    $text =~ s(${WC::STARTWW}\*([^\s]+?|[^\s].*?[^\s])\*$WC::ENDWW)
      (CGI::b($1))gem;

    $text =~ s(${WC::STARTWW}\_([^\s]+?|[^\s].*?[^\s])\_$WC::ENDWW)
      (CGI::i($1))gem;
    $text =~ s(${WC::STARTWW}\=([^\s]+?|[^\s].*?[^\s])\=$WC::ENDWW)
      (CGI::span({class => 'WYSIWYG_TT'}, $1))gem;

    # Handle [[][]] and [[]] links

    # We do _not_ support [[http://link text]] syntax

    # [[][]]
    $text =~ s/(\[\[[^\]]*\](\[[^\]]*\])?\])/$this->_liftOut($1, 'LINK')/ge;

    $text =~
s/$WC::STARTWW(($Foswiki::regex{webNameRegex}\.)?$Foswiki::regex{wikiWordRegex}($Foswiki::regex{anchorRegex})?)/$this->_liftOut($1, 'LINK')/geom;

    $text =~ s/(<nop>)/$this->_liftOut($1, 'PROTECTED')/ge;

    # Substitute back in protected elements
    $text = $this->_dropBack($text);

    # Item1417: Insert a paragraph at the start of the document if the first tag
    # is a table (possibly preceded one of several specific tags) so that it is
    # possible to place the cursor *above* the table.
    # The paragraph is removed automatically if it is empty, when converting
    # back to TML.
    if ( $text =~ /$tagsBeforeFirstTablePattern/o ) {
        $text = '<p class="foswikiDeleteMe">&nbsp;</p>' . $text;
    }

    return $text;
}

sub _encodeHr {
    my $dashes = shift;
    my $style  = '';
    if ( length($dashes) > 3 ) {
        $style = ' style="{numdashes:' . length($dashes) . '}"';
    }
    return '<hr class="TMLhr"' . $style . ' />';
}

sub _hideWhitespace {
    my $this       = shift;
    my $whitespace = shift;

    $whitespace =~ s/\\/b/g;
    $whitespace =~ s/\n/n/g;
    $whitespace =~ s/(\t+)/'t' . length($1)/ge;
    $whitespace =~ s/( +)/'s' . length($1)/ge;

    return $this->_liftOutGeneral(
        " ",
        {
            tag    => 'span',
            class  => "WYSIWYG_HIDDENWHITESPACE",
            params => "style=\"{encoded:'$whitespace'}\"",
        }
    );
}

sub _appendClassToTag {
    my $this         = shift;
    my $tagWithAttrs = shift;
    my $class        = shift;
    if ( $tagWithAttrs =~ /^\s*(\w+)/
        and exists $this->{protectExistingTags}->{$1} )
    {
        $tagWithAttrs =~ s/(\sclass=)(['"])([^'"]*)\2/$1$2$3 $class$2/
          or $tagWithAttrs .= " class='$class' ";
    }
    return $tagWithAttrs;
}

sub _processTableRow {

    my ( $row, $inTable, $state ) = @_;
    my @result;
    my $firstRow = 0;
    if ( !$inTable ) {

        %$state = ( curTable => [], rowspan => [] );
        $firstRow = 1;
    }

    $row =~ s/\t/   /go;     # change tabs to space
    $row =~ s/\s*$//o;       # remove trailing spaces
    $row =~ s/^(\s*)\|//;    # Remove leading junk
    my $pre = $1;

    $row =~
      s/(\|\|+)/'colspan'.$Foswiki::TranslationToken.length($1)."\|"/geo
      ;                         # calc COLSPAN
    my $colCount = 0;
    my @cols     = ();
    my $span     = 0;
    my $value    = '';

    my $rowspanEnabled = Foswiki::Func::getContext()->{'TablePluginEnabled'};

    foreach ( split( /\|/, $row ) ) {
        my $attr = {};
        $span = 1;
        if (s/colspan$Foswiki::TranslationToken([0-9]+)//) {
            $span = $1;
            $attr->{colspan} = $span;
        }
        s/^\s+$/ &nbsp; /o;
        my ( $left, $right ) = ( 0, 0 );
        if (/^(\s*)(.*?)(\s*)$/) {
            $left  = length($1);
            $_     = $2;
            $right = length($3);
        }
        if ( $left == 1 && $right < 2 ) {

            # Treat left=1 and right=0 like 1 and 1 - Item5220
        }
        elsif ( $left > $right ) {
            $attr->{class} = 'align-right';
            $attr->{style} = 'text-align: right';
        }
        elsif ( $left < $right ) {
            $attr->{class} = 'align-left';
            $attr->{style} = 'text-align: left';
        }
        elsif ( $left > 1 ) {
            $attr->{class} = 'align-center';
            $attr->{style} = 'text-align: center';
        }

        if (    $rowspanEnabled
            and !$firstRow
            and /^(\s|<[^>]*>)*\^(\s|<[^>]*>)*$/ )
        {    # row span above
            $state->{rowspan}->[$colCount]++;
            push( @cols, { text => $value, type => 'Y' } );
        }
        else {
            for ( my $col = $colCount ; $col < ( $colCount + $span ) ; $col++ )
            {
                if ( defined( $state->{rowspan}->[$col] )
                    && $state->{rowspan}->[$col] )
                {
                    my $nRows = scalar( @{ $state->{curTable} } );
                    my $rspan = $state->{rowspan}->[$col] + 1;
                    if ( $rspan > 1 ) {
                        $state->{curTable}->[ $nRows - $rspan ][$col]->{attrs}
                          ->{rowspan} = $rspan;
                    }
                    undef( $state->{rowspan}->[$col] );
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

            $value = ' ' . $value if $value =~ /^(?:\*|==?|__?)[^\s]/;
            $value = $value . ' ' if $value =~ /[^\s](?:\*|==?|__?)$/;

            push( @cols, { text => $value, attrs => $attr, type => $type } );
        }

        while ( $span > 1 ) {
            push( @cols, { text => $value, type => 'X' } );
            $colCount++;
            $span--;
        }
        $colCount++;
    }
    push @{ $state->{curTable} }, \@cols;
    push @{ $state->{pre} },      $pre;
    return;
}

sub _emitTable {
    my ($state) = @_;

    my @result;
    push( @result,
        CGI::start_table( { border => 1, cellpadding => 0, cellspacing => 1 } )
    );

    #Flush out any remaining rowspans
    for ( my $i = 0 ; $i < scalar( @{ $state->{rowspan} } ) ; $i++ ) {
        if ( defined( $state->{rowspan}->[$i] ) && $state->{rowspan}->[$i] ) {
            my $nRows = scalar( @{ $state->{curTable} } );
            my $rspan = $state->{rowspan}->[$i] + 1;
            my $r     = $nRows - $rspan;
            $state->{curTable}->[$r][$i]->{attrs} ||= {};
            if ( $rspan > 1 ) {
                $state->{curTable}->[$r][$i]->{attrs}->{rowspan} = $rspan;
            }
        }
    }

    my $rowCount     = 0;
    my $numberOfRows = scalar( @{ $state->{curTable} } );

    my @headerRowList = ();
    my @bodyRowList   = ();

    my $isPastHeaderRows = 0;

    foreach my $row ( @{ $state->{curTable} } ) {
        my $rowtext  = '';
        my $colCount = 0;

        # keep track of header cells: if all cells are header cells,
        # put the row in the thead section
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

            if ( $type eq 'th' ) {
                $headerCellCount++;
            }
            else {
                $type = 'td' unless $type eq 'Y';
            }      ###if( $type eq 'th' )

            $colCount++;
            next if ( $type eq 'Y' );
            my $fn = 'CGI::' . $type;
            no strict 'refs';
            $rowtext .= &$fn( $attr, " $cell " );
            use strict 'refs';
        }    # foreach my $fcell ( @$row )

        my $rowHTML = $state->{pre}->[$rowCount] . CGI::Tr($rowtext);

        my $isHeaderRow = ( $headerCellCount == $colCount );
        if ( !$isHeaderRow ) {

        # don't include non-adjacent header rows to the top block of header rows
            $isPastHeaderRows = 1;
        }

        if ( $isHeaderRow && !$isPastHeaderRows ) {
            push( @headerRowList, $rowHTML );
        }
        else {
            push @bodyRowList, $rowHTML;
        }

        $rowCount++;
    }    # foreach my $row ( @curTable )

    push @result, @headerRowList, @bodyRowList;

    push @result, CGI::end_table();
    return @result;
}

sub _getNamedColour {
    my ( $name, $t ) = @_;
    my $epr = Foswiki::Func::getPreferencesValue($name);

    # Match <font color="x" and style="color:x"
    if (
        defined $epr
        && (   $epr =~ /color=["'](#?\w+)['"]/
            || $epr =~ /color\s*:\s*(#?\w+)/ )
      )
    {
        return "<span class='WYSIWYG_COLOR' style='color:$1'>$t</span>";
    }

    # Can't map to a 'real' colour; leave the variables
    return '%' . $name . '%' . $t . '%ENDCOLOR%';
}

sub _addClass {
    if ( $_[0] ) {
        $_[0] = join( ' ', ( split( /\s+/, $_[0] ), $_[1] ) );
    }
    else {
        $_[0] = $_[1];
    }
}

# Encode special chars in verbatim as entities to prevent misinterpretation
sub _protectVerbatimChars {
    my $text = shift;

    # $TT0, $TT1 and $TT2 are chr(0), chr(1) and chr(2), respectively.
    # They are handled specially, elsewhere
    $text =~ s/([\003-\011\013-\037<&>'"])/'&#'.ord($1).';'/ges;
    $text =~ s/ /&nbsp;/g;
    $text =~ s/\n/<br \/>/gs;
    return $text;
}

sub _takeOutIMGTag {
    my ( $this, $text ) = @_;

    # Expand selected macros in IMG tags so that images appear in the
    # editor as images
    $text =~
      s/(<img [^>]*\bsrc=)(["'])(.*?)\2/$1.$2.$this->_expandURL($3).$2/gie;

    # Take out mce_src - it just causes problems.
    $text =~ s/(<img [^>]*)\bmce_src=(["'])(.*?)\2/$1/gie;
    $text =~ s:([^/])>$:$1 />:;    # close the tag XHTML style

    return $this->_liftOutGeneral( $text, { tag => 'NONE' } );
}

# Pull out Foswiki Set statements, to prevent unwanted munging
sub _takeOutSets {
    my $this = $_[0];
    my $setRegex =
qr/^((?:\t|   )+\*\s+(?:Set|Local)\s+(?:$Foswiki::regex{tagNameRegex})\s*=)(.*)$/o;

    my $lead;
    my $value;
    my @outtext;
    foreach ( split( /\r?\n/, $_[1] ) ) {
        if (m/$setRegex/s) {
            if ( defined $lead ) {
                push( @outtext,
                    $lead . $this->_liftOut( $value, 'PROTECTED' ) );
            }
            $lead = $1;
            $value = defined($2) ? $2 : '';
            next;
        }

        if ( defined $lead ) {
            if ( /^(   |\t)+ *[^\s]/ && !/$Foswiki::regex{bulletRegex}/o ) {

                # follow up line, extending value
                $value .= "\n" . $_;
                next;
            }
            push( @outtext, $lead . $this->_liftOut( $value, 'PROTECTED' ) );
            undef $lead;
        }
        push( @outtext, $_ );
    }
    if ( defined $lead ) {
        push( @outtext, $lead . $this->_liftOut( $value, 'PROTECTED' ) );
    }
    return join( "\n", @outtext );
}

sub _takeOutCustomTags {
    my ( $this, $text ) = @_;

    my $xmltags = $this->{opts}->{xmltag};

    # Take out custom XML tags
    sub _takeOutCustomXmlProcess {
        my ( $this, $state, $scoop ) = @_;
        my $params = $state->{tagParams};
        my $tag    = $state->{tag};
        my $markup = "<$tag$params>$scoop</$tag>";
        if ( $this->{opts}->{xmltag}->{$tag}->($markup) ) {
            return $this->_liftOut( $markup, 'PROTECTED' );
        }
        else {
            return $this->_liftOut( "<$tag$params>", 'PROTECTED' ) . $scoop
              . $this->_liftOut( "</$tag>", 'PROTECTED' );
        }
    }
    for my $tag ( sort keys %{ $this->{opts}->{xmltag} } ) {
        $text = _takeOutXml( $this, $text, $tag, \&_takeOutCustomXmlProcess );
    }

    # Take out other custom tags here

    return $text;
}

sub _liftOutBlocks {

    my ( $this, $intext, $tag, $commonOptions ) = @_;

    $commonOptions = {} unless ref($commonOptions);
    $commonOptions->{tag} ||= $tag;

    my %allBlocksOptions = ( tmltag => $tag );
    for my $option (qw/ tag class protect /) {
        $allBlocksOptions{$option} = $commonOptions->{$option}
          if $commonOptions->{$option};
    }

    my $liftOutBlocksProcess = sub {
        my ( $this, $state, $scoop ) = @_;

        my %oneBlockOptions = %allBlocksOptions;
        $oneBlockOptions{params} = $state->{tagParams};

        my $params = $state->{tagParams};
        return $this->_liftOutGeneral( $scoop, \%oneBlockOptions );
    };

    return _takeOutXml( $this, $intext, $tag, $liftOutBlocksProcess );
}

sub _takeOutXml {
    my ( $this, $intext, $tag, $fn ) = @_;
    die       unless $tag;
    die       unless $fn;
    return '' unless $intext;
    return $intext unless ( $intext =~ m/<$tag\b/ );

    my $openNoCapture    = qr/<$tag\b[^>]*>/i;
    my $openCaptureAttrs = qr/<$tag\b([^>]*)>/i;
    my $close            = qr/<\/$tag>/i;
    my $out              = '';
    my $depth            = 0;
    my $scoop;

    # &$fn may rely on the existence of these fields,
    # and may add more fields, if needed
    my %state = ( tag => $tag, n => 0, tagParams => undef );

    foreach my $chunk ( split /($openNoCapture|$close)/, $intext ) {
        next unless defined($chunk);
        if ( $chunk =~ m/$openCaptureAttrs/ ) {
            unless ( $depth++ ) {
                $state{tagParams} = $1;
                $scoop = '';
                next;
            }
        }
        elsif ( $depth && $chunk =~ m/$close/ ) {
            unless ( --$depth ) {
                $chunk = $fn->( $this, \%state, $scoop );
                $state{n}++;
            }
        }
        if ($depth) {
            $scoop .= $chunk;
        }
        else {
            $out .= $chunk;
        }
    }

    if ($depth) {

        # This would generate matching close tags
        # while ( $depth-- ) {
        #     $scoop .= "</$tag>\n";
        # }
        $out .= $fn->( $this, \%state, $scoop );
    }

    # Filter spurious tags without matching open/close
    $out =~ s/$openCaptureAttrs/&lt;$tag$1&gt;/g;
    $out =~ s/$close/&lt;\/$tag&gt;/g;
    $out =~ s/<($tag\s+\/)>/&lt;$1&gt;/g;

    return $out;
}

sub _parseParams {
    my $p      = shift;
    my $params = {};
    while ( $p =~ s/^\s*([$Foswiki::regex{mixedAlphaNum}]+)=(".*?"|'.*?')// ) {
        my $name = $1;
        my $val  = $2;
        $val =~ s/['"](.*)['"]/$1/;
        $params->{$name} = $val;
    }
    return $params;
}

# Lifted straight out of Render.pm
sub _addListItem {
    my ( $this, $result, $type, $element, $opts, $indent ) = @_;
    $indent ||= '';
    $indent =~ s/   /\t/g;
    my $depth = length($indent);

    my $size = scalar( @{ $this->{LIST} } );
    if ( $size < $depth ) {
        my $firstTime = 1;
        while ( $size < $depth ) {
            push( @{ $this->{LIST} }, { type => $type, element => $element } );
            push( @$result, "<$element" . ($opts ? " $opts" : "") .">" )
		unless ($firstTime);
            push( @$result, "<$type>" ) if $type;
            $firstTime = 0;
            $size++;
        }
    }
    else {
        while ( $size > $depth ) {
            my $tags = pop( @{ $this->{LIST} } );
            push( @$result, "</$tags->{element}>" );
            push( @$result, "</$tags->{type}>" ) if $tags->{type};
            $size--;
        }
        if ($size) {
            push( @$result, "</$this->{LIST}->[$size-1]->{element}>" );
        }
    }

    if ($size) {
        my $oldt = $this->{LIST}->[ $size - 1 ];
        if ( $oldt->{type} ne $type ) {
	    my $r = '';
 	    $r .= "</$oldt->{type}>" if $oldt->{type};
	    $r .= "<$type>" if $type;
            push( @$result, $r );
            pop( @{ $this->{LIST} } );
            push( @{ $this->{LIST} }, {
                type => $type, element => $element } );
        }
    }
}

sub _emitTR {
    my $row = shift;

    $row =~ s/\t/   /g;      # change tabs to space
    $row =~ s/^(\s*)\|//;    # Remove leading junk
    my $pre = $1;

    my @tr;
    while ( $row =~ s/^(.*?)\|// ) {
        my $cell = $1;
        my $attr = {};

        # make sure there's something there in empty cells. Otherwise
        # the editor may compress it to (visual) nothing.
        $cell =~ s/^\s+$/&nbsp;/g;

        my ( $left, $right ) = ( 0, 0 );
        if ( $cell =~ /^(\s*)(.*?)(\s*)$/ ) {
            $left  = length($1);
            $right = length($3);
            $cell  = $2;
        }

        if ( $left == 1 && $right < 2 ) {

            # Treat left=1 and right=0 like 1 and 1 - Item5220
        }
        elsif ( $left > $right ) {
            $attr->{class} = 'align-right';
            $attr->{style} = 'text-align: right';
        }
        elsif ( $left < $right ) {
            $attr->{class} = 'align-left';
            $attr->{style} = 'text-align: left';
        }
        elsif ( $left > 1 ) {
            $attr->{class} = 'align-center';
            $attr->{style} = 'text-align: center';
        }

        my $fn = "CGI::td";
        if ( $cell =~ s/^\*(.+)\*$/$1/ ) {
            $fn = "CGI::th";
        }

        $cell = ' ' . $cell if $cell =~ /^(?:\*|==?|__?)[^\s]/;
        $cell = $cell . ' ' if $cell =~ /[^\s](?:\*|==?|__?)$/;

        push( @tr, { fn => $fn, attr => $attr, text => $cell } );
    }

    # Work out colspans
    my $colspan = 0;
    my @row;
    for ( my $i = $#tr ; $i >= 0 ; $i-- ) {
        if ( $i && length( $tr[$i]->{text} ) == 0 ) {
            $colspan++;
            next;
        }
        elsif ($colspan) {
            $tr[$i]->{attr}->{colspan} = $colspan + 1;
            $colspan = 0;
        }
        unshift( @row, $tr[$i] );
    }
    no strict 'refs';
    return $pre
      . CGI::Tr(
        join( '', map { &{ $_->{fn} }( $_->{attr}, $_->{text} ) } @row ) );
    use strict 'refs';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005 ILOG http://www.ilog.fr

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
