# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Plugins::WysiwygPlugin::HTML2TML;

Convertor for translating HTML into TML (Topic Meta Language)

The conversion is done by parsing the HTML and generating a parse
tree, and then converting that parse tree into TML.

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

package Foswiki::Plugins::WysiwygPlugin::HTML2TML;
use HTML::Parser;
our @ISA = qw( HTML::Parser );

use strict;
use warnings;

use Assert;
use Encode;
use HTML::Parser;
use HTML::Entities;

use Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node;
use Foswiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;

=pod

---++ ClassMethod new()

Constructs a new HTML to TML convertor.

You *must* provide parseWikiUrl and convertImage if you want URLs
translated back to wikinames. See WysiwygPlugin.pm for an example
of how to call it.

=cut

sub new {
    my ($class) = @_;

    #use handler method names to allow of subclassing of HTML2TML
    my $this = new HTML::Parser(
        start_h          => [ '_openTag',  'self,tagname,attr' ],
        end_h            => [ '_closeTag', 'self,tagname' ],
        text_h           => [ '_text',     'self,text' ],
        comment_h        => [ '_comment',  'self,text' ],
        declaration_h    => [ '_ignore',   'self' ],
        start_document_h => [ '_ignore',   'self' ],
        end_document_h   => [ '_ignore',   'self' ],
        default_h        => [ '_default',  'self,event,text' ]
    );

    $this = bless( $this, $class );

    $this->xml_mode(1);
    if ( $this->can('empty_element_tags') ) {

        # protected because not there in some HTML::Parser versions
        $this->empty_element_tags(1);
    }
    $this->unbroken_text(1);

    return $this;
}

sub _resetStack {
    my $this = shift;

    $this->{stackTop} =
      new Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node( $this->{opts}, '' );
    $this->{stack} = ();
}

=pod

---++ ObjectMethod convert( $html, \%options ) -> $tml

Convert a block of HTML text into TML.

Options:
   * expandVarsInURL
   * xmltag

IMPORTANT: $html is a perl internal string, *NOT* octets

=cut

my @protectedByAttr;
my @ignoreAttr;

sub convert {
    my ( $this, $text, $options ) = @_;

    $this->{opts} = $options;

    my $opts = 0;
    $opts = WC::VERY_CLEAN
      if ( $options->{very_clean} );

    # See the WysiwygPluginSettings for information on stickybits
    my $pref = $options->{stickybits};
    $pref = <<'DEFAULT' unless defined $pref;
(?!img).*=id,lang,title,dir,on.*;
a=accesskey,coords,shape,target;
bdo=dir;
br=clear;
col=char,charoff,span,valign,width;
colgroup=align,char,charoff,span,valign,width;
dir=compact;
div=align,style;
dl=compact;
font=size,face;
h\d=align;
hr=align,noshade,size,width;
legend=accesskey,align;
li=value;
ol=compact,start,type;
p=align;
param=name,type,value,valuetype;
pre=width;
q=cite;
table=align,bgcolor,.*?background-color:.*,frame,rules,summary,width;
tbody=align,char,charoff,valign;
td=abbr,align,axis,bgcolor,.*?background-color:.*,.*?border-color:.*,char,charoff,headers,height,nowrap,rowspan,scope,valign,width;
tfoot=align,char,charoff,valign;
th=abbr,align,axis,bgcolor,.*?background-color:.*,char,charoff,height,nowrap,rowspan,scope,valign,width,headers;
thead=align,char,charoff,valign;
tr=bgcolor,.*?background-color:.*,char,charoff,valign;
ul=compact,type;
DEFAULT

    foreach my $def ( split( /;\s*/s, $pref ) ) {
        my ( $re, $ats ) = split( /\s*=\s*/s, $def, 2 );
        push(
            @protectedByAttr,
            {
                tag   => qr/$re/i,
                attrs => join( '|', split( /\s*,\s*/, $ats ) )
            }
        );
    }

    $pref = $options->{ignoreattrs};

    if ( defined $pref ) {
        foreach my $def ( split( /;\s*/s, $pref ) ) {
            my ( $re, $ats ) = split( /\s*=\s*/s, $def, 2 );
            push(
                @ignoreAttr,
                {
                    tag   => qr/$re/i,
                    attrs => join( '|', split( /\s*,\s*/, $ats ) )
                }
            );
        }
    }

    #print STDERR "input     [". WC::encode_specials($text). "]\n\n";

    # Convert (safe) named entities back to the
    # site charset. Numeric entities are mapped straight to the
    # corresponding code point unless their value overflow.
    # HTML::Entities::_decode_entities converts numeric entities
    # to Unicode codepoints, so first convert the text to Unicode
    # characters

    # Make sure that & < > ' and " remain encoded, because the parser depends
    # on it. The safe-entities does not include the corresponding named
    # entities, so convert numeric entities for these characters to the named
    # entity.
    $text =~ s/\&\#38;/\&amp;/go;
    $text =~ s/\&\#x26;/\&amp;/goi;
    $text =~ s/\&\#60;/\&lt;/go;
    $text =~ s/\&\#x3c;/\&lt;/goi;
    $text =~ s/\&\#62;/\&gt;/go;
    $text =~ s/\&\#x3e;/\&gt;/goi;
    $text =~ s/\&\#39;/\&apos;/go;
    $text =~ s/\&\#x27;/\&apos;/goi;
    $text =~ s/\&\#34;/\&quot;/go;
    $text =~ s/\&\#x22;/\&quot;/goi;
    $text =~ s/\&\#160;/\&nbsp;/goi;

    # SMELL: Item11912 These are left behind by TMCE as zero width characters
    # surrounding italics and bold inserted by Ctrl-i and Ctrl-b
    # We really ought to have a better solution.  TMCE is supposed
    # to handle this it the cleanup routine, but it doesn't happen,
    # and cleanup routine has been deprecated.
    $text =~ s/&#xFEFF;//g;    # TMCE 3.5.x
    $text =~ s/&#x200B;//g;    # TMCE pre 3.5

    HTML::Entities::_decode_entities( $text, WC::safeEntities() );

    # get rid of nasties
    $text =~ s/\r//g;
    $text =~ s.(</[uo]l>)\s*.$1.gis;    # Item5664

    $this->_resetStack();

    $this->parse($text);
    $this->eof();

    #print STDERR "Finished\n";
    $this->_apply(undef);
    $text = $this->{stackTop}->rootGenerate($opts);

    $text =~ s/\s+$/\n/s;

    return $text;
}

# Autoclose tags without waiting for a /tag
my %autoClose = map { $_ => 1 }
  qw( area base basefont br col embed frame hr input link meta param img );

# Support auto-close of the tags that are most typically incorrectly
# nested. Autoclose triggers when a second tag of the same type is
# seen without the first tag being closed.
my %closeOnRepeat = map { $_ => 1 } qw( li td th tr );

sub _openTag {
    my ( $this, $tag, $attrs ) = @_;

    $tag = lc($tag);

    if (   $closeOnRepeat{$tag}
        && $this->{stackTop}
        && $this->{stackTop}->{tag} eq $tag )
    {

        #print STDERR "Close on repeat $tag\n";
        $this->_apply($tag);
    }

    push( @{ $this->{stack} }, $this->{stackTop} ) if $this->{stackTop};
    $this->{stackTop} =
      new Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node( $this->{opts}, $tag,
        $attrs );

    if ( $autoClose{$tag} ) {

        #print STDERR "Autoclose $tag\n";
        $this->_apply($tag);
    }
}

sub _closeTag {
    my ( $this, $tag ) = @_;

    $tag = lc($tag);

    while ($this->{stackTop}
        && $this->{stackTop}->{tag} ne $tag
        && $autoClose{ $this->{stackTop}->{tag} } )
    {

        #print STDERR "Close mismatched $this->{stackTop}->{tag}\n";
        $this->_apply( $this->{stackTop}->{tag} );
    }
    if (   $this->{stackTop}
        && $this->{stackTop}->{tag} eq $tag )
    {

        #print STDERR "Closing $tag\n";
        $this->_apply($tag);
    }
}

# Determine if sticky attributes prevent a tag being converted to
# TML when this attribute is present.

sub protectedByAttr {
    my ( $tag, $attr ) = @_;

    foreach my $row (@protectedByAttr) {
        if ( $tag =~ /^$row->{tag}$/i ) {

            if ( $attr =~ /^($row->{attrs})$/i ) {
                return 1;
            }
        }
    }
    return 0;
}

# Determine if an attribute is to be ignored when deciding whether
# to keep a tag as HTML or not.

sub ignoreAttr {
    my ( $tag, $attr ) = @_;

    foreach my $row (@ignoreAttr) {
        if ( $tag =~ /^$row->{tag}$/i ) {

            if ( $attr =~ /^($row->{attrs})$/i ) {
                return 1;
            }
        }
    }
    return 0;
}

sub _text {
    my ( $this, $text ) = @_;
    my $l = new Foswiki::Plugins::WysiwygPlugin::HTML2TML::Leaf($text);
    $this->{stackTop}->addChild($l);
}

sub _comment {
    my ( $this, $text ) = @_;
    my $l = new Foswiki::Plugins::WysiwygPlugin::HTML2TML::Leaf($text);
    $this->{stackTop}->addChild($l);
}

sub _ignore {
}

sub _default {
    my ( $this, $event, $text ) = @_;

    # Unexpected $event event from HTML::Parser; text contains '$text'
    #
    # Foswiki:Main.PaulHarvey triggered this assert with some crusty
    # HTML containing an '<?i?>' tag. Says CDot: "it means an unrecognised
    # construction was used; check the doc of HTML::Parser"
    ASSERT(0);
}

sub _apply {
    my ( $this, $tag ) = @_;

    while ( $this->{stack} && scalar( @{ $this->{stack} } ) ) {
        my $top = $this->{stackTop};

        #print STDERR "Pop $top->{tag}\n";
        $this->{stackTop} = pop( @{ $this->{stack} } );
        die unless $this->{stackTop};
        $this->{stackTop}->addChild($top);
        last if ( $tag && $top->{tag} eq $tag );
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
