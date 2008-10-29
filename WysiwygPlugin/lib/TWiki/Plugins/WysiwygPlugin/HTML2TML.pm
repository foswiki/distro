# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Plugins::WysiwygPlugin::HTML2TML;

Convertor for translating HTML into TML (TWiki Meta Language)

The conversion is done by parsing the HTML and generating a parse
tree, and then converting that parse treeinto TML.

The class is a subclass of HTML::Parser, run in XML mode, so it
should be tolerant to many syntax errors, and will also handle
XHTML syntax.

The translator tries hard to make good use of newlines in the
HTML, in order to maintain text level formating that isn't
reflected in the HTML. So the parser retains newlines and
spaces, rather than throwing them away, and uses various
heuristics to determine which to keep when generating
the final TML.

=cut

package TWiki::Plugins::WysiwygPlugin::HTML2TML;
use base 'HTML::Parser';

use strict;

require Encode;
require HTML::Parser;
require HTML::Entities;

require TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;
require TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;

=pod

---++ ClassMethod new()

Constructs a new HTML to TML convertor.

You *must* provide parseWikiUrl and convertImage if you want URLs
translated back to wikinames. See WysiwygPlugin.pm for an example
of how to call it.

=cut

sub new {
    my( $class ) = @_;

    my $this = new HTML::Parser( start_h => [\&_openTag, 'self,tagname,attr' ],
                                 end_h => [\&_closeTag, 'self,tagname'],
                                 declaration_h => [\&_ignore, 'self'],
                                 default_h => [\&_text, 'self,text'],
                                 comment_h => [\&_comment, 'self,text'] );

    $this = bless( $this, $class );

    $this->xml_mode( 1 );
    if ($this->can('empty_element_tags')) {
        # protected because not there in some HTML::Parser versions
        $this->empty_element_tags( 1 );
    };
    $this->unbroken_text( 1 );

    return $this;
}

sub _resetStack {
    my $this = shift;

    $this->{stackTop} =
      new TWiki::Plugins::WysiwygPlugin::HTML2TML::Node( $this->{opts}, '' );
    $this->{stack} = ();
}

=pod

---++ ObjectMethod convert( $html ) -> $tml

Convert a block of HTML text into TML.

=cut

sub convert {
    my( $this, $text, $options ) = @_;

    $this->{opts} = $options;

    my $opts = 0;
    $opts = $WC::VERY_CLEAN
      if ( $options->{very_clean} );

    # If the text is UTF8-encoded we have to decode it first, otherwise
    # the HTML parser will barf.
    if (WC::encoding() =~ /^utf-?8/) {
        $text = Encode::decode_utf8($text);
    }

    # get rid of nasties
    $text =~ s/\r//g;
    $text =~ s.(</[uo]l>)\s*.$1.gis; # Item5664

    $this->_resetStack();

    $this->parse( $text );
    $this->eof();
    #print STDERR "Finished\n";
    $this->_apply( undef );
    $text = $this->{stackTop}->rootGenerate( $opts );

    # If the site charset is UTF8, we need to recode
    if (WC::encoding() =~ /^utf-?8/) {
        $text = Encode::encode_utf8($text);
    }

    # Convert (safe) named entities back to the
    # site charset. Numeric entities are mapped straight to the
    # corresponding code point unless their value overflow.
    require HTML::Entities;
    HTML::Entities::_decode_entities($text,  WC::safeEntities());

    # After decoding entities, we have to map unicode characters
    # back to high bit
    WC::mapUnicode2HighBit($text);

    return $text;
}

# Autoclose tags without waiting for a /tag
my %autoClose = map { $_ => 1 } qw( area base basefont br col embed frame hr input link meta param );

# Support auto-close of the tags that are most typically incorrectly
# nested. Autoclose triggers when a second tag of the same type is
# seen without the first tag being closed.
my %closeOnRepeat = map { $_ => 1 } qw( li td th tr );

sub _openTag {
    my( $this, $tag, $attrs ) = @_;

    $tag = lc($tag);

    if ($closeOnRepeat{$tag} &&
          $this->{stackTop} &&
            $this->{stackTop}->{tag} eq $tag) {
        #print STDERR "Close on repeat $tag\n";
        $this->_apply($tag);
    }

    push( @{$this->{stack}}, $this->{stackTop} ) if $this->{stackTop};
    $this->{stackTop} =
      new TWiki::Plugins::WysiwygPlugin::HTML2TML::Node(
          $this->{opts}, $tag, $attrs );

    if ($autoClose{$tag}) {
        #print STDERR "Autoclose $tag\n";
        $this->_apply($tag);
    }
}

sub _closeTag {
    my( $this, $tag ) = @_;

    $tag = lc($tag);

    while ($this->{stackTop} &&
             $this->{stackTop}->{tag} ne $tag &&
               $autoClose{$this->{stackTop}->{tag}}) {
        #print STDERR "Close mismatched $this->{stackTop}->{tag}\n";
        $this->_apply($this->{stackTop}->{tag});
    }
    if ($this->{stackTop} &&
          $this->{stackTop}->{tag} eq $tag) {
        #print STDERR "Closing $tag\n";
        $this->_apply($tag);
    }
}

sub _text {
    my( $this, $text ) = @_;
    my $l = new TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf( $text );
    $this->{stackTop}->addChild( $l );
}

sub _comment {
    my( $this, $text ) = @_;
    my $l = new TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf( $text );
    $this->{stackTop}->addChild( $l );
}

sub _ignore {
}

sub _apply {
    my( $this, $tag ) = @_;

    while( $this->{stack} && scalar( @{$this->{stack}} )) {
        my $top = $this->{stackTop};
        #print STDERR "Pop $top->{tag}\n";
        $this->{stackTop} = pop( @{$this->{stack}} );
        die unless $this->{stackTop};
        $this->{stackTop}->addChild( $top );
        last if( $tag && $top->{tag} eq $tag );
    }
}

1;
