# See bottom of file for license and copyright information

# The generator works by expanding an HTML parse tree to "decorated"
# text, where the decorators are non-printable characters. These characters
# act to express format requirements - for example, the need to have a
# newline before some text, or the need for a space. Whitespace is then
# collapsed down to the minimum that satisfies the format requirements.
#
# 10,000 foot overview:
# _handleTAG functions are called on the Node object, passing
# in an options bitmask and receiving back a bitmask of flags
# and some TML text. The expansion is recursive, so the
# TML returned is the expansion of the entire DOM tree
# under the node. If the TML test is undef, that is taken as a
# signal that the node cannot be converted to TML, in which
# case _defaultTag is used to expand it as HTML. _defaultTag
# is itself recursive, so sub-nodes may well be expanded as
# TML. The options flags, and the flags returned from the
# _handle function, are used to steer the expansion. As well
# as the flags, there are special characters dropped into the
# TML, for example for non-breaking space, or space that can
# be collapsed etc.

# VERY IMPORTANT: ALL STRINGS STORED IN NODES ARE UNICODE
# (perl character strings)

=pod

---+ package Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node;

Object for storing a parsed HTML tag, and processing it
to generate TML from the parse tree.

See also Foswiki::Plugins::WysiwygPlugin::HTML2TML::Leaf

=cut

package Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node;
use Foswiki::Plugins::WysiwygPlugin::HTML2TML::Base;
our @ISA = qw( Foswiki::Plugins::WysiwygPlugin::HTML2TML::Base );

use strict;
use warnings;

use Foswiki::Func;    # needed for regular expressions
use Assert;
use HTML::Entities ();

use Foswiki::Plugins::WysiwygPlugin::Constants;
use Foswiki::Plugins::WysiwygPlugin::HTML2TML::Constants;

our $reww;

my %jqueryChiliClass = map { $_ => 1 }
  qw( cplusplus csharp css bash delphi html java js
  lotusscript php-f php sql tml );

my %tml2htmlClass = map { $_ => 1 }
  qw( WYSIWYG_PROTECTED WYSIWYG_STICKY TMLverbatim WYSIWYG_LINK
  TMLhtml WYSIWYG_HIDDENWHITESPACE );

=pod

---++ ObjectMethod new( $context, $tag, \%attrs )

Construct a new HTML tag node using the given tag name
and attribute hash.

=cut

sub new {
    my ( $class, $context, $tag, $attrs ) = @_;

    my $this = {};

    $this->{context}  = $context;
    $this->{tag}      = $tag;
    $this->{nodeType} = 2;
    $this->{attrs}    = {};
    if ($attrs) {
        foreach my $attr ( keys %$attrs ) {
            $this->{attrs}->{ lc($attr) } = $attrs->{$attr};
        }
    }
    $this->{head} = $this->{tail} = undef;

    return bless( $this, $class );
}

# debug

sub stringify {
    my ( $this, $shallow ) = @_;
    my $r = '';
    if ( $this->{tag} ) {
        $r .= '<' . $this->{tag};
        foreach my $attr ( sort keys %{ $this->{attrs} } ) {
            $r .= " " . $attr . "='" . $this->{attrs}->{$attr} . "'";
        }
        $r .= ' /' if $SELF_CLOSING{ $this->{tag} };
        $r .= '>';
    }
    if ($shallow) {
        $r .= '...';
    }
    else {
        my $kid = $this->{head};
        while ($kid) {
            $r .= $kid->stringify();
            $kid = $kid->{next};
        }
    }
    if ( $this->{tag} and not $SELF_CLOSING{ $this->{tag} } ) {
        $r .= '</' . $this->{tag} . '>';
    }
    return $r;
}

=pod

---++ ObjectMethod addChild( $node )

Add a child node to the ordered list of children of this node

=cut

sub addChild {
    my ( $this, $node ) = @_;

    ASSERT( $node != $this ) if DEBUG;

    $node->{next}   = undef;
    $node->{parent} = $this;
    my $kid = $this->{tail};
    if ($kid) {
        $kid->{next}  = $node;
        $node->{prev} = $kid;
    }
    else {
        $node->{prev} = undef;
        $this->{head} = $node;
    }
    $this->{tail} = $node;
}

# top and tail a string
sub _trim {
    my $s = shift;

    # Item5076: removed CHECKn from the following exprs, because loss of it
    # breaks line-sensitive TML content inside flattened content.
    $s =~ s/^[ \t\n$CHECKw$CHECKs]+/$CHECKw/o;
    $s =~ s/[ \t\n$CHECKw]+$/$CHECKw/o;
    return $s;
}

# Both object method and static method
sub hasClass {
    my ( $this, $class ) = @_;
    return 0 unless $this;
    if (
        UNIVERSAL::isa(
            $this, 'Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node'
        )
      )
    {
        return hasClass( $this->{attrs}, $class );
    }
    return 0 unless defined $this->{class};

    return $this->{class} =~ /\b$class\b/ ? 1 : 0;
}

# Both object method and static method
sub _removeClass {
    my ( $this, $class ) = @_;
    return 0 unless $this;
    if (
        UNIVERSAL::isa(
            $this, 'Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node'
        )
      )
    {
        return _removeClass( $this->{attrs}, $class );
    }
    return 0 unless hasClass( $this, $class );

    $this->{class} =~ s/\b$class\b//;
    $this->{class} =~ s/\s+/ /g;
    $this->{class} =~ s/^\s+//;
    $this->{class} =~ s/\s+$//;
    if ( !$this->{class} ) {
        delete $this->{class};
    }
    return 1;
}

# Both object method and static method
sub _addClass {
    my ( $this, $class ) = @_;
    if (
        UNIVERSAL::isa(
            $this, 'Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node'
        )
      )
    {
        _addClass( $this->{attrs}, $class );
        return;
    }
    _removeClass( $this, $class );    # avoid duplication
    if ( $this->{class} ) {
        $this->{class} .= ' ' . $class;
    }
    else {
        $this->{class} = $class;
    }
}

# Move the content of $node into $this
sub _eat {
    my ( $this, $node ) = @_;
    my $kid = $this->{tail};
    if ($kid) {
        $kid->{next} = $node->{head};
        if ( $node->{head} ) {
            $node->{head}->{prev} = $kid;
        }
    }
    else {
        $this->{head} = $node->{head};
    }
    $this->{tail} = $node->{tail};
    $kid = $node->{head};
    while ($kid) {
        $kid->{parent} = $this;
        $kid = $kid->{next};
    }
    $node->{head} = $node->{tail} = undef;
}

=pod

---++ ObjectMethod rootGenerate($opts) -> $text

Generates TML from this HTML node. The generation is done
top down and bottom up, so that higher level nodes can make
decisions on whether to allow TML conversion in lower nodes,
and lower level nodes can constrain conversion in higher level
nodes.

$opts is a bitset. VERY_CLEAN will cause the generator
to drop unrecognised HTML (e.g. divs and spans that don't
generate TML)

=cut

sub rootGenerate {
    my ( $this, $opts ) = @_;

    #print STDERR "Raw       [", encode_specials($this->stringify()), "]\n\n";
    $this->cleanParseTree();

    #print STDERR "Cleaned   [", encode_specials($this->stringify()), "]\n\n";
    # Perform some transformations on the parse tree
    $this->_collapse();

    #print STDERR "Collapsed [", encode_specials($this->stringify()), "]\n\n";

    my ( $f, $text ) = $this->generate($opts);

    # Debug support
    #print STDERR "Converted [",encode_specials($text),"]\n";

    # Move leading \n out of protected region. Delicate hack fix required to
    # maintain Foswiki variables at the start of lines.
    $text =~ s/$PON$NBBR/$CHECKn$PON/g;

    # isolate whitespace checks and convert to $NBSP
    $text =~ s/$CHECKw$CHECKw+/$CHECKw/go;
    $text =~ s/([$CHECKn$CHECKs$NBSP $TAB$NBBR]($PON|$POFF)?)$CHECKw/$1/go;
    $text =~ s/$CHECKw(($PON|$POFF)?[$CHECKn$CHECKs$NBSP $NBBR])/$1/go;
    $text =~ s/^($CHECKw)+//gos;
    $text =~ s/($CHECKw)+$//gos;
    $text =~ s/($CHECKw)+/$NBSP/go;

    # isolate $CHECKs and convert to $NBSP
    $text =~ s/$CHECKs$CHECKs+/$CHECKs/go;
    $text =~ s/([ $NBSP$TAB])$CHECKs/$1/go;
    $text =~ s/$CHECKs( |$NBSP)/$1/go;
    $text =~ s/($CHECKs)+/$NBSP/go;

    # SMELL:   Removed per Item11859.   This was done because TMCE used to
    # insert a <br /> before <p>  ...   It doesn't do that in 3.4.9
    #$text =~ s/<br( \/)?>$NBBR/$NBBR/g;    # Remove BR before P

    #die "Converted ",encode_specials($text),"\n";
    #print STDERR "Conv2     [",encode_specials($text),"]\n";

    my @regions = split( /([$PON$POFF])/o, $text );
    my $protect = 0;
    $text = '';
    foreach my $tml (@regions) {
        if ( $tml eq $PON ) {
            $protect++;
            next;
        }
        elsif ( $tml eq $POFF ) {
            $protect--;
            next;
        }

        # isolate $NBBR and convert to \n.
        unless ($protect) {

            $tml =~ s/\n$NBBR/$NBBR$NBBR/go;
            $tml =~ s/$NBBR\n/$NBBR$NBBR/go;
            $tml =~ s/$NBBR( |$NBSP)+$NBBR/$NBBR$NBBR/go;
            $tml =~ s/ +$NBBR/$NBBR/go;
            $tml =~ s/$NBBR +/$NBBR/go;
            $tml =~ s/$NBBR$NBBR+/$NBBR$NBBR/go;

            # Now convert adjacent NBBRs to recreate empty lines
            # 1 NBBR  -> 1 newline
            # 2 NBBRs -> <p /> - 1 blank line - 2 newlines
            # 3 NBBRs -> 3 newlines
            # 4 NBBRs -> <p /><p /> - 3 newlines
            # 5 NBBRs -> 4 newlines
            # 6 NBBRs -> <p /><p /><p /> - 3 blank lines - 4 newlines
            # 7 NBBRs -> 5 newlines
            # 8 NBBRs -> <p /><p /><p /><p /> - 4 blank lines - 5 newlines
            $tml =~ s.($NBBR$NBBR$NBBR$NBBR+).
              "\n" x ((length($1) + 1) / 2 + 1)
                .geo;

        }

        # isolate $CHECKn and convert to $NBBR
        $tml =~ s/$CHECKn([$NBSP $TAB])*$CHECKn/$CHECKn/go;
        $tml =~ s/$CHECKn$CHECKn+/$CHECKn/go;
        $tml =~ s/(?<=$NBBR)$CHECKn//gom;
        $tml =~ s/$CHECKn(?=$NBBR)//gom;
        $tml =~ s/$CHECKn+/$NBBR/gos;

        $tml =~ s/$NBBR/\n/gos;

        # Convert tabs to NBSP
        $tml =~ s/$TAB/$NBSP$NBSP$NBSP/go;

        # isolate $NBSP and convert to space
        unless ($protect) {
            $tml =~ s/ +$NBSP/$NBSP/go;
            $tml =~ s/$NBSP +/$NBSP/go;
        }
        $tml =~ s/$NBSP/ /go;

        $tml =~ s/$CHECK1$CHECK1+/$CHECK1/go;
        $tml =~ s/$CHECK2$CHECK2+/$CHECK2/go;
        $tml =~ s/$CHECK2$CHECK1/$CHECK2/go;

        $tml =~ s/(^|[\s\(])$CHECK1/$1/gso;
        $tml =~ s/$CHECK2($|[\s\,\.\;\:\!\?\)\*])/$1/gso;

        $tml =~ s/$CHECK1(\s|$)/$1/gso;
        $tml =~ s/(^|\s)$CHECK2/$1/gso;

        $tml =~ s/$CHECK1/ /go;
        $tml =~ s/$CHECK2/ /go;

        # SMELL:   Removed per Item11859.   This was done because TMCE used to
        # insert a <br /> before <p>  ...   It doesn't do that in 3.4.9
        # Item5127: Remove BR just before EOLs
        #unless ($protect) {
        #    $tml =~ s/<br( \/)?>\n/\n/g;
        #}

        #print STDERR " -> [",encode_specials($tml),"]\n";
        $text .= $tml;
    }

    # Collapse adjacent tags
    # SMELL:  Can't collapse verbatim based upon simple close/open compare
    # because the previous opening verbatim tag might have different
    # class from the next one.
    foreach my $tag (qw(noautolink literal)) {
        $text =~ s#</$tag>(\s*)<$tag>#$1#gs;
    }

    # Top and tail, and terminate with a single newline
    $text =~ s/^\n*//s;
    $text =~ s/\s*$/\n/s;

    #print STDERR "TML       [",encode_specials($text),"]\n";

    return $text;
}

sub _compareClass {
    my ( $node1, $node2 ) = @_;

    my $n1Class = $node1->{attrs}->{class} || '';
    my $n1Sort = join( ' ', sort( split( / /, $n1Class ) ) );
    my $n2Class = $node2->{attrs}->{class} || '';
    my $n2Sort = join( ' ', sort( split( / /, $n2Class ) ) );

    return ( $n1Sort eq $n2Sort );
}

# collapse adjacent nodes together, if they share the same class
sub _collapseOneClass {
    my $node  = shift;
    my $class = shift;
    if ( defined( $node->{tag} ) && $node->hasClass($class) ) {
        my $next = $node->{next};
        my @edible;
        my $collapsible;
        while (
            $next
            && (
                ( !$next->{tag} && $next->{text} =~ /^\s*$/ )
                || (   $node->{tag} eq $next->{tag}
                    && $next->hasClass($class)
                    && ( _compareClass( $node, $next ) ) )
            )
          )
        {
            push( @edible, $next );

            $collapsible ||= $next->hasClass($class);
            $next = $next->{next};
        }
        if ($collapsible) {
            foreach my $meal (@edible) {
                $meal->_remove();
                if ( $meal->{tag} ) {
                    require Foswiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;
                    $node->addChild(
                        new Foswiki::Plugins::WysiwygPlugin::HTML2TML::Leaf(
                            $NBBR)
                    );
                    $node->_eat($meal);
                }
            }
        }
    }
}

# Collapse adjacent VERBATIM nodes together
# Collapse adjacent STICKY nodes together
# Collapse a <p> that contains only a protected span into a protected P
# Collapse em in em
# Collapse adjacent text nodes
sub _collapse {
    my $this = shift;

    my @jobs = ($this);
    while ( scalar(@jobs) ) {
        my $node = shift(@jobs);

     # SMELL: Not sure if we really still have to collapse consecutive verbatim.
     # Extra whitespace to separate verbatim blocks is removed, and they will
     # still eventually be merged.
        _collapseOneClass( $node, 'TMLverbatim' );
        _collapseOneClass( $node, 'WYSIWYG_STICKY' );
        if (   $node->{tag} eq 'p'
            && $node->{head}
            && $node->{head} == $node->{tail} )
        {
            my $kid = $node->{head};
            if (   $kid->{tag} eq 'span'
                && $kid->hasClass('WYSIWYG_PROTECTED') )
            {
                $kid->_remove();
                $node->_eat($kid);
                $node->_addClass('WYSIWYG_PROTECTED');
            }
        }

        # Pressing return in a "foswikiDeleteMe" paragraph will cause
        # the paragraph to be split into a 2nd paragraph with the same
        # class. We only want to clean the first one in the blockquote,
        # and preserve the rest without the class.
        if (   $node->{tag} eq 'p'
            && $node->hasClass('foswikiDeleteMe')
            && $node->{parent}
            && $node->{parent}->{tag} eq 'blockquote' )
        {
            my $next = $node->{next};
            while ($next) {
                if (   $next
                    && $next->{tag} eq 'p'
                    && $next->hasClass('foswikiDeleteMe') )
                {
                    $next->_removeClass('foswikiDeleteMe');
                }
                $next = $next->{next};
            }
            $node->_inline();
        }

        # If this is an emphasis (b, i, code, tt, strong) then
        # flatten out any child nodes that express the same emphasis.
        # This has to be done because Foswiki emphases are single level.
        if ( $EMPH_TAG{ $node->{tag} } ) {
            my $kid = $node->{head};
            while ($kid) {
                if (   $EMPH_TAG{ $kid->{tag} }
                    && $EMPH_TAG{ $kid->{tag} } eq $EMPH_TAG{ $node->{tag} } )
                {
                    $kid = $kid->_inline();
                }
                else {
                    $kid = $kid->{next};
                }
            }
        }
        $node->_combineLeaves();

        my $kid = $node->{head};
        while ($kid) {
            push( @jobs, $kid );
            $kid = $kid->{next};
        }
    }
}

# If this node has the specified class, insert a new "span" node with that
# class between this node and all of this node's children.
sub _moveClassToSpan {
    my $this  = shift;
    my $class = shift;

    if (    $this->{tag}
        and $this->{tag} ne 'span'
        and $this->_removeClass($class) )
    {

        my %new_attrs = ( class => $class );
        $new_attrs{style} = $this->{attrs}->{style}
          if exists $this->{attrs}->{style};
        my $newspan =
          new Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node( $this->{context},
            'span', \%new_attrs );
        my $kid = $this->{head};
        while ($kid) {
            $newspan->addChild($kid);
            $kid = $kid->{next};
        }
        $this->{head} = $this->{tail} = $newspan;
    }
}

# the actual generate function. rootGenerate is only applied to the root node.
sub generate {
    my ( $this, $options ) = @_;
    my $fn;
    my $flags;
    my $text;

    if ( $this->_isProtectedByAttrs() ) {
        return $this->_defaultTag($options);
    }

    if ( $this->hasClass('TMLhtml') ) {
        return $this->_defaultTag( $options & ~VERY_CLEAN );
    }

    my $tag = $this->{tag};

    if ( $this->hasClass('WYSIWYG_LITERAL') ) {
        if ( $tag eq 'div' || $tag eq 'p' || $tag eq 'span' ) {
            $text = '';
            my $kid = $this->{head};
            while ($kid) {
                $text .= $kid->stringify();
                $kid = $kid->{next};
            }
        }
        else {
            $this->_removeClass('WYSIWYG_LITERAL');
            $text = $this->stringify();
        }
        return ( 0, '<literal>' . $text . '</literal>' );
    }

    if ( $options & NO_HTML ) {

        # NO_HTML implies NO_TML
        my $brats = $this->_flatten($options);
        return ( 0, $brats );
    }

    if ( $options & NO_TML ) {
        return ( 0, $this->stringify() );
    }

    # make the names of the function versions
    $tag =~ s/!//;    # DOCTYPE

    my $tmlFn = '_handle' . uc($tag);

    $this->_moveClassToSpan('WYSIWYG_TT');
    $this->_moveClassToSpan('WYSIWYG_COLOR')
      if $this->{tag} ne 'font';

    # See if we have a TML translation function for this tag
    # the translation functions will work out the rendering
    # of their own children.
    if ( $this->{tag} && defined(&$tmlFn) ) {
        no strict 'refs';
        ( $flags, $text ) = &$tmlFn( $this, $options );
        use strict 'refs';

        # if the function returns undef, drop through
        return ( $flags, $text ) if defined $text;
    }

    unless ( $this->{tag} ) {

        # No translation, so we need the text of the children
        ( $flags, $text ) = $this->_flatten($options);

        # just return the text if there is no tag name
        return ( $flags, $text );
    }

    return $this->_defaultTag($options);
}

# Return the children flattened out subject to the options
sub _flatten {
    my ( $this, $options ) = @_;
    my $text  = '';
    my $flags = 0;

    my $protected =
         ( $options & PROTECTED )
      || $this->hasClass('WYSIWYG_PROTECTED')
      || $this->hasClass('WYSIWYG_STICKY')
      || 0;

    if ($protected) {

        # Expand brs, which are used in the protected encoding in place of
        # newlines, and protect whitespace
        $options |= BR2NL | KEEP_WS;
    }

    my $kid = $this->{head};
    while ($kid) {
        my ( $f, $t ) = $kid->generate($options);
        if (   !( $options && KEEP_WS )
            && $text
            && $text =~ /\w$/
            && $t =~ /^\w/ )
        {

            # if the last child ends in a \w and this child
            # starts in a \w, we need to insert a space
            $text .= ' ';
        }
        $text .= $t;
        $flags |= $f;
        $kid = $kid->{next};
    }
    if ($protected) {
        $text =~ s/[$PON$POFF]//g;

        unless ( $options & KEEP_ENTITIES ) {

            # This will decode only those entities that
            # have a representation in the site charset.
            decodeRepresentableEntities($text);
        }
        $text =~ s/ /$NBSP/g;
        $text =~ s/\n/$NBBR/g;
        $text = $PON . $text . $POFF;
    }

    $text = _trim($text) unless ( $options & KEEP_WS );

    return ( $flags, $text );
}

# $cutClasses is an RE matching class names to cut
sub _htmlParams {
    my ( $attrs, $options ) = @_;
    my @params;

    # Sort the attributes when converting back to TML
    # so that the conversion is deterministic
  ATTR: for my $k ( sort keys %$attrs ) {
        next ATTR unless $k;
        my $v = $attrs->{$k};
        if ( $k eq 'class' ) {
            my @classes;
            $v =~ s/^\s*(.*?)\s*$/$1/;
          CLASS: for my $class ( split /\s+/, $v ) {

                next CLASS unless $class =~ /\S/;

                next CLASS if $tml2htmlClass{$class};

                # if cleaning aggressively, remove class attributes
                # except for the JQuery "Chili" classes
                next CLASS
                  if (  $options & VERY_CLEAN
                    and not $jqueryChiliClass{$class}
                    and not $class =~ /^foswiki/ );

                push @classes, $class;
            }
            next ATTR unless @classes;

            $v = join( ' ', @classes );
        }
        my $q = $v =~ /'/ ? '"' : "'";    # Default to single qutoes in html
        push( @params, $k . '=' . $q . $v . $q );
    }
    my $p = join( ' ', @params );
    return '' unless $p;
    return ' ' . $p;
}

# generate the default representation of an HTML tag
sub _defaultTag {
    my ( $this,  $options ) = @_;
    my ( $flags, $text )    = $this->_flatten($options);
    my $tag = $this->{tag};
    my $p = _htmlParams( $this->{attrs}, $options );

    if ( $text =~ /^\s*$/ && $SELF_CLOSING{$tag} ) {
        return ( $flags, '<' . $tag . $p . ' />' );
    }
    else {
        return ( $flags, '<' . $tag . $p . '>' . $text . '</' . $tag . '>' );
    }
}

# Check to see if the HTML tag is protected by the presence of
# specific attributes that block conversion to TML. The conversion
# table is defined in
sub _isProtectedByAttrs {
    my $this = shift;

    foreach my $attr ( keys %{ $this->{attrs} } ) {
        next unless length( $this->{attrs}->{$attr} );    # ignore nulls
        return $attr
          if Foswiki::Plugins::WysiwygPlugin::HTML2TML::protectedByAttr(
            $this->{tag}, $attr );
    }
    return 0;
}

# perform conversion on a list type
sub _convertList {
    my ( $this, $indent ) = @_;
    my $basebullet;
    my $isdl = ( $this->{tag} eq 'dl' );

    if ($isdl) {
        $basebullet = '';
    }
    elsif ( $this->{tag} eq 'ol' ) {
        if ( $this->hasClass('foswikiListStyleA') ) {
            $basebullet = 'A.';
        }
        elsif ( $this->hasClass('foswikiListStylea') ) {
            $basebullet = 'a.';
        }
        elsif ( $this->hasClass('foswikiListStyleI') ) {
            $basebullet = 'I.';
        }
        elsif ( $this->hasClass('foswikiListStylei') ) {
            $basebullet = 'i.';
        }
        else {
            $basebullet = '1.';
        }
    }
    else {    # ul
        if ( $this->hasClass('foswikiListStyleNone') ) {
            $basebullet = ':';
        }
        else {
            $basebullet = '*';
        }
    }

    my $f;
    my $text      = '';
    my $pendingDT = 0;
    my $kid       = $this->{head};
    while ($kid) {

        # be tolerant of dl, ol and ul with no li
        if ( $kid->{tag} =~ m/^[dou]l$/ ) {
            $text .= $kid->_convertList( $indent . $TAB );
            $kid = $kid->{next};
            next;
        }
        unless ( $kid->{tag} =~ m/^(dt|dd|li)$/ ) {
            $kid = $kid->{next};
            next;
        }
        if ( $isdl && ( $kid->{tag} eq 'dt' ) ) {

            # DT, set the bullet type for subsequent DT
            $basebullet = $kid->_flatten( NO_BLOCK_TML() );
            $basebullet =~ s/[\s$CHECKw$CHECKs]+$//;
            $basebullet .= ':';
            $basebullet =~ s/$CHECKn/ /g;
            $basebullet =~ s/^\s+//;
            $basebullet = '$ ' . $basebullet;
            $pendingDT  = 1;                   # remember in case there is no DD
            $kid        = $kid->{next};
            next;
        }
        my $bullet = $basebullet;
        my $spawn  = '';
        my $t;
        my $grandkid = $kid->{head};
        if ($grandkid) {

            # IE generates spurious empty divs inside LIs. Detect and skip
            # them.
            if (   $grandkid->{tag}
                && $grandkid->{tag} =~ /^div$/
                && $grandkid == $kid->{tail}
                && scalar( keys %{ $this->{attrs} } ) == 0 )
            {
                $grandkid = $grandkid->{head};
            }
            while ($grandkid) {
                if ( $grandkid->{tag} && $grandkid->{tag} =~ /^[dou]l$/ ) {

                    #$spawn = _trim( $spawn );
                    $t = $grandkid->_convertList( $indent . $TAB );
                }
                else {
                    ( $f, $t ) = $grandkid->generate( NO_BLOCK_TML() );
                    $t =~ s/$CHECKn/ /g;

                    # Item5257: If this is the last child of the LI, trim
                    # trailing spaces. Otherwise spaces generated by the
                    # editor before the </li> will be appended to the line.
                    # It is safe to remove them, as TML never depends on
                    # these spaces. If there are any intentional spaces at
                    # the end of protected content, these will have been
                    # converted to &nbsp; and protected that way.
                    $t =~ s/\s+$// unless $grandkid->{next};
                }
                $spawn .= $t;
                $grandkid = $grandkid->{next};
            }
        }

        #$spawn = _trim($spawn);
        $text .= $CHECKn . $indent . $bullet . $CHECKs . $spawn . $CHECKn;
        $pendingDT  = 0;
        $basebullet = '' if $isdl;
        $kid        = $kid->{next};
    }
    if ($pendingDT) {

        # DT with no corresponding DD
        $text .= $CHECKn . $indent . $basebullet . $CHECKn;
    }
    return $text;
}

# probe down into a list type to determine if it
# can be converted to TML.
sub _isConvertableList {
    my ( $this, $options ) = @_;

    return 0 if ( $this->_isProtectedByAttrs() );

    my $kid = $this->{head};
    while ($kid) {

        # check for malformed list. We can still handle it,
        # by simply ignoring illegal text.
        # be tolerant of dl, ol and ul with no li
        if ( $kid->{tag} =~ m/^[dou]l$/ ) {
            return 0 unless $kid->_isConvertableList($options);
        }
        elsif ( $kid->{tag} =~ m/^(dt|dd|li)$/ ) {
            unless ( $kid->_isConvertableListItem( $options, $this ) ) {
                return 0;
            }
        }
        $kid = $kid->{next};
    }
    return 1;
}

# probe down into a list item to determine if the
# containing list can be converted to TML.
sub _isConvertableListItem {
    my ( $this, $options, $parent ) = @_;
    my ( $flags, $text );

    return 0 if ( $this->_isProtectedByAttrs() );

    if ( $parent->{tag} eq 'dl' ) {
        return 0 unless ( $this->{tag} =~ /^d[td]$/ );
    }
    else {
        return 0 unless ( $this->{tag} eq 'li' );
    }

    my $kid = $this->{head};
    while ($kid) {
        if ( $kid->{tag} =~ /^[oud]l$/ ) {
            unless ( $kid->_isConvertableList($options) ) {
                return 0;
            }
        }
        else {
            ( $flags, $text ) = $kid->generate($options);
            if ( $flags & BLOCK_TML ) {
                return 0;
            }
        }
        $kid = $kid->{next};
    }
    return 1;
}

# probe down into a table to determine if it
# can be converted to TML.
sub _isConvertableTable {
    my ( $this, $options, $table ) = @_;

    #print STDERR "*** CHECK TABLE ***\n";
    return 0 if ( $this->_isProtectedByAttrs() );
    return 0
      if (
           defined $this->{attrs}->{style}
        && length $this->{attrs}->{style}
        && Foswiki::Plugins::WysiwygPlugin::HTML2TML::protectedByAttr(
            'style', $this->{attrs}
        )
      );

    #print STDERR "*** END CHECK TABLE ***\n";

    my $rowspan = undef;
    $rowspan = [] if Foswiki::Func::getContext()->{'TablePluginEnabled'};

    my $kid = $this->{head};
    while ($kid) {
        if ( $kid->{tag} =~ /^(colgroup|thead|tbody|tfoot|col)$/ ) {
            unless ( $kid->_isConvertableTable( $options, $table ) ) {
                return 0;
            }
        }
        elsif ( $kid->{tag} ) {
            unless ( $kid->{tag} eq 'tr' ) {
                return 0;
            }
            my $row = $kid->_isConvertableTableRow( $options, $rowspan );
            unless ($row) {
                return 0;
            }
            push( @$table, $row );
        }
        $kid = $kid->{next};
    }

    if ( $rowspan and grep { $_ } @$rowspan ) {

        # One or more cells span rows past the last row in the table.
        # This is a defect in the HTML table which TML cannot represent.
        return 0;
    }
    return 1;
}

# Tidy up whitespace on the sides of a table cell, and also strip trailing
# BRs, as added by some table editors.
sub _TDtrim {
    my $td = shift;
    $td =~
      s/^($NBSP|$NBBR|$CHECKn|$CHECKs|$CHECKw|$CHECK1|$CHECK2|$TAB|\s)+//so;
    $td =~
s/(<br \/>|<br>|$NBSP|$NBBR|$CHECKn|$CHECKs|$CHECKw|$CHECK1|$CHECK2|$TAB|\s)+$//so;
    return $td;
}

# probe down into a table row to determine if the
# containing table can be converted to TML.
sub _isConvertableTableRow {
    my ( $this, $options, $rowspan ) = @_;

    return 0 if ( $this->_isProtectedByAttrs() );

    my ( $flags, $text );
    my @row;
    my $ignoreCols = 0;
    my $kid        = $this->{head};
    my $colIdx     = 0;
    while ( $rowspan and $rowspan->[$colIdx] ) {
        push @row, $NBSP . '^' . $NBSP;
        $rowspan->[$colIdx]--;
        $colIdx++;
    }
    while ($kid) {
        if ( $kid->{tag} eq 'th' ) {
            $kid->_removePWrapper();
            $kid->_moveClassToSpan('WYSIWYG_TT');
            $kid->_moveClassToSpan('WYSIWYG_COLOR');
            ( $flags, $text ) = $kid->_flatten( $options | IN_TABLE );
            $text = _TDtrim($text);
            $text = "*$text*" if length($text);
        }
        elsif ( $kid->{tag} eq 'td' ) {
            $kid->_removePWrapper();
            $kid->_moveClassToSpan('WYSIWYG_TT');
            $kid->_moveClassToSpan('WYSIWYG_COLOR');
            ( $flags, $text ) = $kid->_flatten( $options | IN_TABLE );
            $text = _TDtrim($text);
        }
        elsif ( !$kid->{tag} ) {
            $kid = $kid->{next};
            next;
        }
        else {

            # some other sort of (unexpected) tag
            return 0;
        }
        return 0 if ( $flags & BLOCK_TML );

        if ( $kid->{attrs} ) {
            my $a = _deduceAlignment($kid);
            if ( length($text) && $a eq 'right' ) {
                $text = $NBSP . $text;
            }
            elsif ( length($text) && $a eq 'center' ) {
                $text = $NBSP . $text . $NBSP;
            }
            elsif ( $text && $a eq 'left' ) {
                $text .= $NBSP;
            }
            if ( $kid->{attrs}->{rowspan} && $kid->{attrs}->{rowspan} > 1 ) {
                return 0 unless $rowspan;
                $rowspan->[$colIdx] = $kid->{attrs}->{rowspan} - 1;
            }
            my %atts = %{ $kid->{attrs} };
            foreach my $key ( keys %atts ) {

  #print STDERR "Found Row/Cell Attr $key = $atts{$key} for tag $kid->{tag} \n";
                return 0

                  if (
                    $key eq 'style'
                    && Foswiki::Plugins::WysiwygPlugin::HTML2TML::protectedByAttr(
                        $kid->{tag}, $atts{$key}
                    )
                  );
            }

        }
        $text =~ s/&nbsp;/$NBSP/g;
        $text =~ s/&#160;/$NBSP/g;

        #if (--$ignoreCols > 0) {
        #    # colspanned
        #    $text = '';
        #} els
        if ( $text =~ /^$NBSP*$/ ) {
            $text = $NBSP;
        }
        else {
            $text = $NBSP . $text . $NBSP;
        }
        if (   $kid->{attrs}
            && $kid->{attrs}->{colspan}
            && $kid->{attrs}->{colspan} > 1 )
        {
            $ignoreCols = $kid->{attrs}->{colspan};
        }

        # Pad to allow wikiwords to work
        push( @row, $text );
        $colIdx++;
        while ( $ignoreCols > 1 ) {
            if ( $rowspan and $rowspan->[$colIdx] ) {

                # rowspan and colspan into the same cell
                return 0;
            }
            push( @row, '' );
            $ignoreCols--;
            $colIdx++;
        }
        while ( $rowspan and $rowspan->[$colIdx] ) {
            push @row, $NBSP . '^' . $NBSP;
            $rowspan->[$colIdx]--;
            $colIdx++;
        }
        $kid = $kid->{next};
    }
    return \@row;
}

# Remove the P tag from a table cell when it surrounds the whole content
# These "wrapper P tags" come from TMCE, when you press Enter
# in a table cell. They are impossible to remove in TMCE itself
# and they mess up the vertical alignment of table text.
sub _removePWrapper {
    my $this = shift;

    # Find the first kid that is a tag,
    # keeping track of any content before it
    my $kid            = $this->{head};
    my $leadingContent = '';
    while ( $kid->{next} and not $kid->{tag} ) {
        $leadingContent .= $kid->{text};
        $kid = $kid->{next};
    }

    # If there are no enclosed tags, then there is nothing further to do
    return unless $kid;
    return unless $kid->{tag};

    # If there is something (non-whitespace) before the first tag,
    # then there is nothing further to do
    return if $leadingContent =~ /\S/;

    # This is the first node (tag)
    my $firstNodeKid = $kid;

    # Find the last kid that is a tag,
    # keeping track of any content after it
    $kid = $this->{tail};
    my $trailingContent = '';
    while ( $kid->{prev} and not $kid->{tag} ) {
        $trailingContent .= $kid->{text};
        $kid = $kid->{prev};
    }

    # Note that there is at least one kid that is a node (tag)
    # so the checks here are for safety's sake
    ASSERT($kid) if DEBUG;
    ASSERT( $kid->{tag} ) if DEBUG;
    return unless $kid;
    return unless $kid->{tag};

    # If there is something (non-whitespace) after the last tag,
    # then there is nothing further to do
    return if $trailingContent =~ /\S/;

    # This is the last node (tag)
    my $lastNodeKid = $kid;

    # If there are multiple kids that are nodes (tags)
    # then there is no "wrapper" tag to be removed
    return unless $firstNodeKid eq $lastNodeKid;

    # There is only a problem if the surrounding tag is a <p> tag
    return unless uc( $firstNodeKid->{tag} ) eq 'P';

    $firstNodeKid->_remove();

    # Check if the tag has attributes
    if ( keys %{ $firstNodeKid->{attrs} } ) {

        # Replace the wrapper P tag with a span
        my $newspan =
          new Foswiki::Plugins::WysiwygPlugin::HTML2TML::Node( $this->{context},
            'span', $firstNodeKid->{attrs} );
        $newspan->_eat($firstNodeKid);
        $this->addChild($newspan);
    }
    else {

        # Remove the wrapper P tag
        $this->_eat($firstNodeKid);
    }
}

# Work out the alignment of a table cell from the style and/or class
sub _deduceAlignment {
    my $td = shift;

    if ( $td->{attrs}->{align} ) {
        return lc( $td->{attrs}->{align} );
    }
    else {
        if (   $td->{attrs}->{style}
            && $td->{attrs}->{style} =~ /text-align\s*:\s*(left|right|center)/ )
        {
            return $1;
        }
        if ( $td->hasClass(qr/align-(left|right|center)/) ) {
            return $1;
        }
    }
    return '';
}

# convert a heading tag
sub _H {
    my ( $this, $options, $depth ) = @_;
    my ( $flags, $contents ) = $this->_flatten($options);
    return ( 0, undef )
      if ( ( $flags & BLOCK_TML )
        || ( $flags & IN_TABLE ) );
    my $notoc = '';
    if ( $this->hasClass('notoc') ) {
        $notoc = '!!';
    }
    my $indicator = '+';
    if ( $this->hasClass('numbered') ) {
        $indicator = '#';
    }
    $contents =~ s/^\s+/ /;
    $contents =~ s/\s+$//;
    my $res =
        $CHECKn . '---'
      . ( $indicator x $depth )
      . $notoc
      . $CHECKs
      . $contents
      . $CHECKn;
    return ( $flags | BLOCK_TML, $res );
}

# generate an emphasis
sub _emphasis {
    my ( $this, $options, $ch ) = @_;
    my ( $flags, $contents ) = $this->_flatten( $options | NO_BLOCK_TML );
    return ( 0, undef )
      if ( !defined($contents) || ( $flags & BLOCK_TML ) );

    # Remove whitespace from either side of the contents, retaining the
    # whitespace
    $contents =~ s/&nbsp;/$NBSP/go;
    $contents =~ s/&#160;/$NBSP/go;
    $contents =~ /^($WS)(.*?)($WS)$/s;
    my ( $pre, $post ) = ( $1, $3 );
    $contents = $2;
    return ( 0, undef ) if ( $contents =~ /^</ || $contents =~ />$/ );
    return ( 0, '' ) unless ( $contents =~ /\S/ );

    # Now see if we can collapse the emphases
    if (   $ch eq '_' && $contents =~ s/^\*(.*)\*$/$1/
        || $ch eq '*' && $contents =~ s/^_(?!_)(.*)(?<!_)_$/$1/ )
    {
        $ch = '__';
    }
    elsif ($ch eq '=' && $contents =~ s/^\*(.*)\*$/$1/
        || $ch eq '*' && $contents =~ s/^=(?!=)(.*)(?<!=)=$/$1/ )
    {
        $ch = '==';
    }
    elsif ( $contents =~ /^([*_=]).*\1$/ ) {
        return ( 0, undef );
    }
    my $be = $this->_checkBeforeEmphasis();
    my $ae = $this->_checkAfterEmphasis();
    return ( 0, undef ) unless $ae && $be;

    return ( $flags, $pre . $CHECK1 . $ch . $contents . $ch . $CHECK2 . $post );
}

sub isBlockNode {
    my $node = shift;
    return ( $node->{tag}
          && $node->{tag} =~
/^(address|blockquote|center|dir|div|dl|fieldset|form|h\d|hr|isindex|menu|noframes|noscript|ol|p|pre|table|ul)$/
    );
}

sub previousLeaf {
    my $node = shift;
    if ( !$node ) {
        return;
    }
    do {
        while ( !$node->{prev} ) {
            if ( !$node->{parent} ) {
                return;    # can't go any further back
            }
            $node = $node->{parent};
        }
        $node = $node->{prev};
        while ( !$node->isTextNode() ) {
            $node = $node->{tail};
        }
    } while ( !$node->isTextNode() );
    return $node;
}

# Test for /^|(?<=[\s\(])/ at the end of the leaf node before.
sub _checkBeforeEmphasis {
    my ($this) = @_;
    my $tb = $this->previousLeaf();
    return 1 unless $tb;
    return 1 if ( $tb->isBlockNode() );
    return 1 if ( $tb->{nodeType} == 3 && $tb->{text} =~ /[\s(*_=]$/ );

    # Special case of a DT - Item13059 - DT terminates cleanly with :
    return 1 if ( $this->{parent} && $this->{parent}->{tag} eq 'dt' );
    return 0;
}

sub nextLeaf {
    my $node = shift;
    if ( !$node ) {
        return;
    }
    do {
        while ( !$node->{next} ) {
            if ( !$node->{parent} ) {
                return;    # end of the road
            }
            $node = $node->{parent};
            if ( $node->isBlockNode() ) {

                # leaving this $node
                return $node;
            }
        }
        $node = $node->{next};
        while ( !$node->isTextNode() ) {
            $node = $node->{head};
        }
    } while ( !$node->isTextNode() );
    return $node;
}

# Test for /$|(?=[\s,.;:!?)])/ at the start of the leaf node after.
sub _checkAfterEmphasis {
    my ($this) = @_;
    my $tb = $this->nextLeaf();
    return 1 unless $tb;
    return 1 if ( $tb->isBlockNode() );
    return 1 if ( $tb->{nodeType} == 3 && $tb->{text} =~ /^[\s,.;:!?)*_=]/ );

    # Special case of a DT - Item13059 - DT terminates cleanly with :
    return 1 if ( $this->{parent} && $this->{parent}->{tag} eq 'dt' );
    return 0;
}

# generate verbatim for P, SPAN or PRE
sub _verbatim {
    my ( $this, $tag, $options ) = @_;

    # KEEP_ENTITIES for literal and pre
    $options |= PROTECTED | KEEP_ENTITIES | BR2NL | KEEP_WS;
    my ( $flags, $text ) = $this->_flatten($options);

    # Don't do this for literal or sticky
    decodeRepresentableEntities($text);

    my $p = _htmlParams( $this->{attrs}, $options );

    return ( $flags, "<$tag$p>$text</$tag>" );
}

# pseudo-tags that may leak through in Macros
# We have to handle this to avoid a matching close tag </nop>
sub _handleNOP {
    my ( $this,  $options ) = @_;
    my ( $flags, $text )    = $this->_flatten($options);
    return ( $flags, '<nop>' . $text );
}

sub _handleNOPRESULT {
    my ( $this,  $options ) = @_;
    my ( $flags, $text )    = $this->_flatten($options);
    return ( $flags, '<nop>' . $text );
}

# tags we ignore completely (contents as well)
sub _handleDOCTYPE { return ( 0, '' ); }

sub _LIST {
    my ( $this, $options ) = @_;
    if ( ( $options & NO_BLOCK_TML )
        || !$this->_isConvertableList( $options | NO_BLOCK_TML ) )
    {
        return ( 0, undef );
    }
    return ( BLOCK_TML, $this->_convertList($TAB) );
}

# Performs initial cleanup of the parse tree before generation. Walks the
# tree, making parent links and removing attributes that don't add value.
# This simplifies determining whether a node is to be kept, or flattened
# out.
# $opts may include VERY_CLEAN
sub cleanNode {
    my ( $this, $opts ) = @_;
    my $a;

    # Always delete these attrs
    foreach $a (qw( lang _moz_dirty )) {
        delete $this->{attrs}->{$a}
          if ( defined( $this->{attrs}->{$a} ) );
    }

    # Delete these attrs if their value is empty
    foreach $a (qw( class style )) {
        if ( defined( $this->{attrs}->{$a} )
            && $this->{attrs}->{$a} !~ /\S/ )
        {
            delete $this->{attrs}->{$a};
        }
    }

    # Sometimes (rarely!) there's a <span id='__caret'> </span>, an artifact of
    # one of the strategies TinyMCE uses to recover lost cursor positioning,
    # see Item2618 where this can break TML tables. #SMELL: TMCE specific
    if (   ( $this->{tag} eq 'span' )
        && ( defined $this->{attrs}->{id} )
        && ( $this->{attrs}->{id} eq '__caret' ) )
    {
        $this->{tag}      = q{};
        $this->{attrs}    = {};
        $this->{nodeType} = 0;
    }
}

######################################################
# Handlers for different HTML tag types. Each handler returns
# a pair (flags,text) containing the result of the expansion.
#
# There are four ways of handling a tag:
# 1. Return (0,undef) which will cause the tag to be output
#    as HTML tags.
# 2. Return _flatten which will cause the tag to be ignored,
#    but the content expanded
# 3. Return (0, '') which will cause the tag not to be output
# 4. Something else more complex
#
# Note that tags like TFOOT and DT are handled inside the table
# and list processors.
# They only have handler methods in case the tag is seen outside
# the content of a table or list. In this case they are usually
# simply removed from the output.
#
sub _handleA {
    my ( $this, $options ) = @_;

    my ( $flags, $text ) = $this->_flatten( $options | NO_BLOCK_TML );
    if ( $text && $text =~ /\S/ && $this->{attrs}->{href} ) {

        # there's text and an href
        my $href = $this->{attrs}->{href};

        my $forceTML =
          (      $this->{attrs}->{class}
              && $this->{attrs}->{class} =~ m/\bTMLlink\b/ );

        my $origWikiword;
        if ( $this->{attrs}->{'data-wikiword'} ) {
            $origWikiword = $this->{attrs}->{'data-wikiword'};
        }

        if ( $this->{context} && $this->{context}->{rewriteURL} ) {
            $href = $this->{context}->{rewriteURL}->( $href, $this->{context} );
        }

        $reww = Foswiki::Func::getRegularExpression('wikiWordRegex')
          unless $reww;
        my $nop = ( $options & NOP_ALL ) ? '<nop>' : '';

        my $cleantext = $text;
        $cleantext =~ s/<nop>//g;

# The original WikiWord for auto links as well as [[Squab]] links is stashed in a pseudo class
#  - class="TMLwikiword<TheWikiWord>"
# If the original WikiWord and the href match, and the text is a wikiword
# the replace the href with the new wikiword.
        if (   $origWikiword
            && $href eq $origWikiword
            && $cleantext =~ m/^(\w+\.)?($reww)(#\w+)?$/ )
        {
            $href = $text;

            #print STDERR "HREF $href updated\n";
        }

        if ( $href =~ /^(\w+\.)?($reww)(#\w+)?$/ ) {
            my $web    = $1 || '';
            my $topic  = $2;
            my $anchor = $3 || '';

            # if the clean text is the known topic we can ignore it
            if ( ( $cleantext eq $href || $href =~ /\.\Q$cleantext\E$/ )
                && !$forceTML )
            {
                return ( 0,
                    $CHECK1 . $nop . $web . $topic . $anchor . $CHECK2 );
            }
        }
        if (   $href =~ /${PROTOCOL}[^?]*$/
            && $text eq $href
            && !$forceTML )
        {
            return ( 0, $CHECK1 . $nop . $text . $CHECK2 );
        }

        #print STDERR "TEXT ($text) HREF ($href)\n";
        if ( $text eq $href ) {
            return ( 0, '[' . $nop . '[' . $href . ']]' );
        }

        # we must quote square brackets in [[...][...]] notation
        $text =~ s/[[]/&#91;/g;
        $text =~ s/[]]/&#93;/g;
        $href =~ s/[[]/%5B/g;
        $href =~ s/[]]/%5D/g;

        return ( 0, '[' . $nop . '[' . $href . '][' . $text . ']]' );
    }
    elsif ( $this->{attrs}->{name} ) {

        # allow anchors to be expanded normally. This won't generate
        # wiki anchors, but it's a small price to pay - it would
        # be too complex to generate wiki anchors, given their
        # line-oriented nature.
        return ( 0, undef );
    }

    # Otherwise generate nothing
    return ( 0, '' );
}

sub _handleABBR    { return _flatten(@_); }
sub _handleACRONYM { return _flatten(@_); }
sub _handleADDRESS { return _flatten(@_); }

sub _handleB        { return _handleSTRONG(@_); }
sub _handleBASE     { return ( 0, '' ); }
sub _handleBASEFONT { return ( 0, '' ); }

sub _handleBIG { return _flatten(@_); }

# BLOCKQUOTE
sub _handleBODY { return _flatten(@_); }

# BUTTON

sub _handleBR {
    my ( $this, $options ) = @_;
    my ( $f,    $kids )    = $this->_flatten($options);

    # Test conditions for keeping a <br>. These are:
    # 1. We haven't explicitly been told to convert to \n (by BR2NL)
    # 2. We have been told that block TML is illegal
    # 3. The previous node is an inline element node or text node
    # 4. The next node is an inline element or text node
    my $sep = "\n";
    if ( $options & BR2NL ) {
    }
    elsif ( $options & NO_BLOCK_TML ) {
        $sep = '<br />';
    }
    elsif ( $this->prevIsInline() ) {
        if ( $this->isInline() ) {

            # Both <br> and </br> cause a NL
            # if this is empty, look at next
            if (   $kids !~ /^[\000-\037]*$/ && $kids !~ /^[\000-\037]*$NBBR/
                || $this->nextIsInline() )
            {
                $sep = '<br />';
            }
        }
    }
    return ( $f, $sep . $kids );
}

sub _handleCAPTION { return ( 0, '' ); }

# CENTER
# CITE

sub _handleCODE { return _emphasis( @_, '=' ); }

sub _handleCOL      { return _flatten(@_); }
sub _handleCOLGROUP { return _flatten(@_); }
sub _handleDD       { return _flatten(@_); }
sub _handleDFN      { return _flatten(@_); }

# DIR

sub _handleDIV {
    my ( $this, $options ) = @_;
    return $this->_handleP($options);
}

sub _handleDL { return _LIST(@_); }
sub _handleDT { return _flatten(@_); }

sub _handleEM { return _emphasis( @_, '_' ); }

sub _handleFIELDSET { return _flatten(@_); }

sub _handleFONT {
    my ( $this, $options ) = @_;

    my %atts = %{ $this->{attrs} };

    # Try to convert font tags into %COLOUR%..%ENDCOLOR%

    # First extract the colour from a style= param, if we can.
    my $colour;
    if ( defined $atts{style}
        && $atts{style} =~ s/(^|\s|;)color\s*:\s*(#?\w+)\s*(;|$)// )
    {
        $colour = $2;
    }

    # override it with a color= param, if there is one.
    if ( defined $atts{color} ) {
        $colour = $atts{color};
    }

    # The presence of the WYSIWYG_COLOR class _forces_ the tag to be
    # converted to a Foswiki colour macro, as long as the colour is
    # recognised.
    if ( hasClass( \%atts, 'WYSIWYG_COLOR' ) ) {
        my $percentColour = $HTML2TML_COLOURMAP{ uc($colour) };
        if ( defined $percentColour ) {

            # All other font information will be lost.
            my ( $f, $kids ) = $this->_flatten($options);
            return ( $f, '%' . $percentColour . '%' . $kids . '%ENDCOLOR%' );
        }
    }

    # May still be able to convert if there is no other font information.
    delete $atts{class} if defined $atts{class} && $atts{class} =~ /^\s*$/;
    delete $atts{style} if defined $atts{style} && $atts{style} =~ /^[\s;]*$/;
    delete $atts{color} if defined $atts{color};
    if ( defined $colour && !scalar( keys(%atts) ) ) {
        my $percentColour = $HTML2TML_COLOURMAP{ uc($colour) };
        if ( defined $percentColour ) {
            my ( $f, $kids ) = $this->_flatten($options);
            return ( $f, '%' . $percentColour . '%' . $kids . '%ENDCOLOR%' );
        }
    }

    # Check if any of the attributes can be ignored
    foreach my $a ( keys %atts ) {
        delete $atts{$a}
          if Foswiki::Plugins::WysiwygPlugin::HTML2TML::ignoreAttr(
            $this->{tag}, $a );
    }

    if ( scalar( keys(%atts) ) ) {

        # Either the colour can't be mapped, or we can't do the conversion
        # without loss of attribute information
        return ( 0, undef );
    }

    # We can ignore this
    return $this->_flatten($options);
}

# FORM
sub _handleFRAME    { return _flatten(@_); }
sub _handleFRAMESET { return _flatten(@_); }
sub _handleHEAD     { return ( 0, '' ); }

sub _handleHR {
    my ( $this, $options ) = @_;

    my ( $f, $kids ) = $this->_flatten($options);
    return ( $f, '<hr />' . $kids ) if ( $options & NO_BLOCK_TML );

    my $dashes = 3;
    if (    $this->{attrs}->{style}
        and $this->{attrs}->{style} =~ s/\bnumdashes\s*:\s*(\d+)\b// )
    {
        $dashes = $1;
        $dashes = 3 if $dashes < 3;
        $dashes = 160 if $dashes > 160;    # Filter out probably-bad data
    }
    return ( $f | BLOCK_TML, $CHECKn . ( '-' x $dashes ) . $CHECKn . $kids );
}

sub _handleHTML { return _flatten(@_); }
sub _handleH1   { return _H( @_, 1 ); }
sub _handleH2   { return _H( @_, 2 ); }
sub _handleH3   { return _H( @_, 3 ); }
sub _handleH4   { return _H( @_, 4 ); }
sub _handleH5   { return _H( @_, 5 ); }
sub _handleH6   { return _H( @_, 6 ); }
sub _handleI    { return _handleEM(@_); }

sub _handleIMG {
    my ( $this, $options ) = @_;

    # Hack out mce_src, which is TinyMCE-specific and causes indigestion
    # when the topic is reloaded
    delete $this->{attrs}->{mce_src} if defined $this->{attrs}->{mce_src};

    return ( 0, undef )
      unless $this->{context}
      && defined $this->{context}->{convertImage};

    my $href = $this->{attrs}->{src};
    if ( $this->{context} && $this->{context}->{rewriteURL} ) {
        my $new =
          &{ $this->{context}->{rewriteURL} }( $href, $this->{context} );
        if ( $new && $new ne $href ) {
            $this->{attrs}->{src} = $href = $new;
        }
    }
    my $alt = &{ $this->{context}->{convertImage} }( $href, $this->{context} );
    if ($alt) {
        return ( 0, $alt );
    }

    return ( 0, undef );
}

# INPUT
# INS
# ISINDEX
sub _handleKBD { return _handleTT(@_); }

# LABEL
# LI
sub _handleLINK { return ( 0, '' ); }

# MAP
# MENU
sub _handleMETA     { return ( 0, '' ); }
sub _handleNOFRAMES { return ( 0, '' ); }
sub _handleNOSCRIPT { return ( 0, '' ); }
sub _handleOL       { return _LIST(@_); }

# OPTGROUP
# OPTION

sub _handleP {
    my ( $this, $options ) = @_;

    my $nbnl = $this->hasClass('WYSIWYG_NBNL');

    if ( $this->hasClass('WYSIWYG_WARNING') ) {
        return ( 0, '' );
    }

    if ( $this->hasClass('TMLverbatim') ) {
        return $this->_verbatim( 'verbatim', $options );
    }
    if ( $this->hasClass('WYSIWYG_STICKY') ) {
        return $this->_verbatim( 'sticky', $options );
    }
    my ( $f, $kids ) = $this->_flatten($options);
    return ( $f, '<p>' . $kids . '</p>' ) if ( $options & NO_BLOCK_TML );
    my $prevNode = $this->{prev};
    if ( $prevNode and not $prevNode->{tag} ) {
        $prevNode = $prevNode->{prev};
    }
    my $afterTable = ( $prevNode and uc( $prevNode->{tag} ) eq 'TABLE' );
    my $nextNode = $this->{next};
    if ( $nextNode and not $nextNode->{tag} ) {
        $nextNode = $nextNode->{next};
    }
    my $beforeTable = ( $nextNode and uc( $nextNode->{tag} ) eq 'TABLE' );
    my $pre;
    if ( $afterTable and not $beforeTable ) {
        $pre = '';
    }
    elsif ( $this->prevIsInline() ) {
        $pre = $NBBR . $NBBR;
    }
    else {
        $pre = $NBBR;
    }
    $pre = $NBBR . $pre if $nbnl;
    return ( $f | BLOCK_TML, $pre . $kids . $NBBR );
}

# PARAM

sub _handlePRE {
    my ( $this, $options ) = @_;

    my $tag = 'pre';
    if ( $this->hasClass('TMLverbatim') ) {
        return $this->_verbatim( 'verbatim', $options );
    }
    if ( $this->hasClass('WYSIWYG_STICKY') ) {
        return $this->_verbatim( 'sticky', $options );
    }
    unless ( $options & NO_BLOCK_TML ) {
        my ( $flags, $text ) =
          $this->_flatten( $options | NO_TML | BR2NL | KEEP_WS );
        my $p = _htmlParams( $this->{attrs}, $options );
        return ( BLOCK_TML, "<$tag$p>$text</$tag>" );
    }
    return ( 0, undef );
}

sub _handleQ { return _flatten(@_); }

# S
sub _handleSAMP { return _handleTT(@_); }

# SCRIPT
# SELECT
# SMALL

sub _handleSPAN {
    my ( $this, $options ) = @_;

    my %atts = %{ $this->{attrs} };
    if ( _removeClass( \%atts, 'TMLverbatim' ) ) {
        return $this->_verbatim( 'verbatim', $options );
    }
    if ( _removeClass( \%atts, 'WYSIWYG_STICKY' ) ) {
        return $this->_verbatim( 'sticky', $options );
    }

    if ( _removeClass( \%atts, 'WYSIWYG_LINK' ) ) {
        $options |= NO_BLOCK_TML;
    }

    if ( _removeClass( \%atts, 'WYSIWYG_TT' ) ) {
        return $this->_emphasis( $options, '=' );
    }

    # If we have WYSIWYG_COLOR and the colour can be mapped, then convert
    # to a macro.
    if ( _removeClass( \%atts, 'WYSIWYG_COLOR' ) ) {
        my $colour;
        if ( $atts{style} ) {
            my $style = $atts{style};
            if ( $style =~ s/(^|\s|;)color\s*:\s*(#?\w+)\s*(;|$)// ) {
                $colour = $2;
            }
        }
        my $percentColour = $HTML2TML_COLOURMAP{ uc($colour) };
        if ( defined $percentColour ) {
            my ( $f, $kids ) = $this->_flatten($options);
            return ( $f, '%' . $percentColour . '%' . $kids . '%ENDCOLOR%' );
        }
    }

    if ( _removeClass( \%atts, 'WYSIWYG_HIDDENWHITESPACE' ) ) {

# This regular expression ensures the encoded whitespace is valid.
# The limit on the number of digits will ensure that the numbers are reasonable.
        if (    $atts{style}
            and $atts{style} =~
            s/\bencoded\s*:\s*(['"])((?:b|n|t\d{1,2}|s\d{1,3})+)\1;?// )
        {
            my $whitespace = $2;

            #print STDERR "'$whitespace' -> ";
            $whitespace =~ s/b/\\/g;
            $whitespace =~ s/n/$NBBR/g;
            $whitespace =~ s/t(\d+)/'\t' x $1/ge;
            $whitespace =~ s/s(\d+)/$NBSP x $1/ge;

            #print STDERR "'$whitespace'\n";
            #require Data::Dumper;
            my ( $f, $kids ) =
              $this->_flatten( $options | KEEP_WS | KEEP_ENTITIES );

            #die Data::Dumper::Dumper($kids);
            if ( $kids eq '&nbsp;' ) {

                # The space was not changed
                # So restore the encoded whitespace
                return ( $f, $whitespace );
            }
            elsif ( length($kids) == 0 ) {

                # The user deleted the space
                # So return blank
                return ( 0, '' );
            }

            #else {die "'".ord($kids)."'";}if(1){}
            elsif ( 0
                and
                ( $kids eq '&nbsp;' or $kids eq '&#160;' or $kids eq chr(160) )
              )
            {    # SMELL: Firefox-specific
                 # This was probably inserted by Firefox after the user deleted the space.
                 # So return blank
                return ( 0, '' );
            }
            else {

             # The user entered some new text
             # Return the combination.
             # Assume that a leading space corresponds to the encoded whitespace
                $kids =~ s/^ //;
                return ( $f, $whitespace . $kids );
            }
        }
    }

    # Remove all other (non foswiki) classes
    if ( defined $atts{class} && $atts{class} !~ /foswiki/ ) {
        delete $atts{class};
    }

    #    if ( $options & VERY_CLEAN ) {
    # remove style attribute if cleaning aggressively.
    #        delete $atts{style} if defined $atts{style};
    #    }

    # Check if any of the attributes can be ignored
    foreach my $a ( keys %atts ) {
        delete $atts{$a}
          if Foswiki::Plugins::WysiwygPlugin::HTML2TML::ignoreAttr(
            $this->{tag}, $a );
    }

    if ( scalar( keys(%atts) ) ) {

        # Either the colour can't be mapped, or we can't do the conversion
        # without loss of attribute information
        return ( 0, undef );
    }

    # We can ignore this
    return $this->_flatten($options);
}

# STRIKE

sub _handleSTRONG {
    my ( $this, $options ) = @_;

    if ( $options & IN_TABLE ) {
        if (
            $this->{parent}
            && (   $this->{parent}->{tag} eq 'td'
                || $this->{parent}->{tag} eq 'th' )
          )
        {
            # Item9651: Don't convert bold/strong in a table cell into stars
            # if the TML would be interpreted as a heading
            my $left  = $this->{prev} ? $this->{prev}->stringify() : '';
            my $right = $this->{next} ? $this->{next}->stringify() : '';
            if ( "$left$right" =~ /^\s*$/ ) {

                # Have to exclude ==this case== and __that case__ as
                # they look awfully similar but don't generate table
                # headings
                my ( $foo, $t ) = _emphasis( @_, '*' );
                if ( $t && $t !~ /.*?$CHECK1(==|__).*\1$CHECK2/ ) {
                    return ( 0, undef );
                }
                else {
                    return ( $foo, $t );
                }
            }
        }
    }
    return _emphasis( @_, '*' );
}

sub _handleSTYLE { return ( 0, '' ); }

# SUB
# SUP

sub _handleTABLE {
    my ( $this, $options ) = @_;
    return ( 0, undef ) if ( $options & NO_BLOCK_TML );

    # Should really look at the table attrs, but to heck with it

    return ( 0, undef ) if ( $options & NO_BLOCK_TML );

    my %atts = %{ $this->{attrs} };

    #   foreach my $key ( keys %atts ) {
    #       print STDERR "Found TABLE Attr $key = $atts{$key} \n";
    #       }

    # Preserve HTML if non-default options are requested for
    # padding, spacing, border.
    return ( 0, undef )
      if (
           defined $atts{cellpadding}
        && $atts{cellpadding} ne '0'
        && !Foswiki::Plugins::WysiwygPlugin::HTML2TML::ignoreAttr(
            $this->{tag}, 'cellpadding'
        )
      );
    return ( 0, undef )
      if (
           defined $atts{cellspacing}
        && $atts{cellspacing} ne '1'
        && !Foswiki::Plugins::WysiwygPlugin::HTML2TML::ignoreAttr(
            $this->{tag}, 'cellspacing'
        )
      );
    return ( 0, undef )
      if (
           defined $atts{border}
        && $atts{border} ne '1'
        && !Foswiki::Plugins::WysiwygPlugin::HTML2TML::ignoreAttr(
            $this->{tag}, 'border'
        )
      );

    #use Data::Dumper;
    #print STDERR Data::Dumper::Dumper( \%atts);

    return 0
      if (
        defined $atts{style}
        && Foswiki::Plugins::WysiwygPlugin::HTML2TML::protectedByAttr(
            'table', $atts{style}
        )
      );

    my @table;
    return ( 0, undef )
      unless $this->_isConvertableTable( $options | NO_BLOCK_TML, \@table );

    my $text = $CHECKn;
    foreach my $row (@table) {

        # isConvertableTableRow has already formatted the cell
        $text .= $CHECKn . '|' . join( '|', @$row ) . '|' . $CHECKn;
    }

    return ( BLOCK_TML, $text );
}

# TBODY
# TD

# TEXTAREA {
# TFOOT
# TH
# THEAD
sub _handleTITLE { return ( 0, '' ); }

# TR
sub _handleTT { return _handleCODE(@_); }

# U
sub _handleUL { return _LIST(@_); }

sub _handleVAR { return _flatten(@_); }

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: Crawford Currie http://c-dot.co.uk

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
