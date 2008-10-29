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

# The generator works by expanding and HTML parse tree to "decorated"
# text, where the decorators are non-printable characters. These characters
# act to express format requirements - for example, the need to have a
# newline before some text, or the need for a space. Whitespace is then
# collapsed down to the minimum that satisfies the format requirements.

=pod

---+ package TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;

Object for storing a parsed HTML tag, and processing it
to generate TML from the parse tree.

See also TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf

=cut

package TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;
use base 'TWiki::Plugins::WysiwygPlugin::HTML2TML::Base';

use strict;

use TWiki::Func; # needed for regular expressions
use Assert;

use vars qw( $reww );

require TWiki::Plugins::WysiwygPlugin::Constants;
require TWiki::Plugins::WysiwygPlugin::HTML2TML::WC;

=pod

---++ ObjectMethod new( $context, $tag, \%attrs )

Construct a new HTML tag node using the given tag name
and attribute hash.

=cut

sub new {
    my( $class, $context, $tag, $attrs ) = @_;

    my $this = {};

    $this->{context} = $context;
    $this->{tag} = $tag;
    $this->{nodeType} = 2;
    $this->{attrs} = {};
    if( $attrs ) {
        foreach my $attr ( keys %$attrs ) {
            $this->{attrs}->{lc($attr)} = $attrs->{$attr};
        }
    }
    $this->{head} = $this->{tail} = undef;

    return bless( $this, $class );
}

# debug
sub stringify {
    my( $this, $shallow ) = @_;
    my $r = '';
    if( $this->{tag} ) {
        $r .= '<'.$this->{tag};
        foreach my $attr ( keys %{$this->{attrs}} ) {
            $r .= " ".$attr."='".$this->{attrs}->{$attr}."'";
        }
        $r .= '>';
    }
    if( $shallow ) {
        $r .= '...';
    } else {
        my $kid = $this->{head};
        while ($kid) {
            $r .= $kid->stringify();
            $kid = $kid->{next};
        }
    }
    if( $this->{tag} ) {
        $r .= '</'.$this->{tag}.'>';
    }
    return $r;
}

=pod

---++ ObjectMethod addChild( $node )

Add a child node to the ordered list of children of this node

=cut

sub addChild {
    my( $this, $node ) = @_;

    ASSERT($node != $this) if DEBUG;

    $node->{next} = undef;
    $node->{parent} = $this;
    my $kid = $this->{tail};
    if ($kid) {
        $kid->{next} = $node;
        $node->{prev} = $kid;
    } else {
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
    $s =~ s/^[ \t\n$WC::CHECKw$WC::CHECKs]+/$WC::CHECKw/o;
    $s =~ s/[ \t\n$WC::CHECKw]+$/$WC::CHECKw/o;
    return $s;
}

# Both object method and static method
sub hasClass {
    my ($this, $class) = @_;
    return 0 unless $this;
    if (UNIVERSAL::isa($this, 'TWiki::Plugins::WysiwygPlugin::HTML2TML::Node')) {
        return hasClass($this->{attrs}, $class);
    }
    return 0 unless defined $this->{class};
    return $this->{class} =~ /\b$class\b/ ? 1 : 0;
}

# Both object method and static method
sub _removeClass {
    my ($this, $class) = @_;
    return 0 unless $this;
    if (UNIVERSAL::isa($this, 'TWiki::Plugins::WysiwygPlugin::HTML2TML::Node')) {
        return _removeClass($this->{attrs}, $class);
    }
    return 0 unless hasClass($this, $class);
    $this->{class} =~ s/\b$class\b//;
    $this->{class} =~ s/\s+/ /g;
    $this->{class} =~ s/^\s+//;
    $this->{class} =~ s/\s+$//;
    if (!$this->{class}) {
        delete $this->{class};
    }
    return 1;
}

# Both object method and static method
sub _addClass {
    my ($this, $class) = @_;
    if (UNIVERSAL::isa($this, 'TWiki::Plugins::WysiwygPlugin::HTML2TML::Node')) {
        _addClass($this->{attrs}, $class);
        return;
    }
    _removeClass($this, $class); # avoid duplication
    if ($this->{class}) {
        $this->{class} .= ' '.$class;
    } else {
        $this->{class} = $class;
    }
}

# Move the content of $node into $this
sub _eat {
    my ($this, $node) = @_;
    my $kid = $this->{tail};
    if ($kid) {
        $kid->{next} = $node->{head};
        if ($node->{head}) {
            $node->{head}->{prev} = $kid;
        }
    } else {
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

$opts is a bitset. $WC::VERY_CLEAN will cause the generator
to drop unrecognised HTML (e.g. divs and spans that don't
generate TML)

=cut

sub rootGenerate {
    my( $this, $opts ) = @_;

    $this->cleanParseTree();

    # Perform some transformations on the parse tree
    $this->_collapse();

    my( $f, $text ) = $this->generate($opts);

    # Debug support
    #print STDERR "Converted ",WC::debugEncode($text),"\n";

    # Move leading \n out of protected region. Delicate hack fix required to
    # maintain TWiki variables at the start of lines.
    $text =~ s/$WC::PON$WC::NBBR/$WC::CHECKn$WC::PON/g;

    # isolate whitespace checks and convert to $NBSP
    $text =~ s/$WC::CHECKw$WC::CHECKw+/$WC::CHECKw/go;
    $text =~ s/([$WC::CHECKn$WC::CHECKs$WC::NBSP $WC::TAB$WC::NBBR]($WC::PON|$WC::POFF)?)$WC::CHECKw/$1/go;
    $text =~ s/$WC::CHECKw(($WC::PON|$WC::POFF)?[$WC::CHECKn$WC::CHECKs$WC::NBSP $WC::NBBR])/$1/go;
    $text =~ s/^($WC::CHECKw)+//gos;
    $text =~ s/($WC::CHECKw)+$//gos;
    $text =~ s/($WC::CHECKw)+/$WC::NBSP/go;

    # isolate $CHECKs and convert to $NBSP
    $text =~ s/$WC::CHECKs$WC::CHECKs+/$WC::CHECKs/go;
    $text =~ s/([ $WC::NBSP$WC::TAB])$WC::CHECKs/$1/go;
    $text =~ s/$WC::CHECKs( |$WC::NBSP)/$1/go;
    $text =~ s/($WC::CHECKs)+/$WC::NBSP/go;

    $text =~ s/<br( \/)?>$WC::NBBR/$WC::NBBR/g; # Remove BR before P

    #die "Converted ",WC::debugEncode($text),"\n";

    my @regions = split(/([$WC::PON$WC::POFF])/o, $text);
    my $protect = 0;
    $text = '';
    foreach my $tml (@regions) {
        if ($tml eq $WC::PON) {
            $protect++;
            next;
        } elsif ($tml eq $WC::POFF) {
            $protect--;
            next;
        }

        # isolate $NBBR and convert to \n.
        unless ($protect) {
            $tml =~ s/\n$WC::NBBR/$WC::NBBR$WC::NBBR/go;
            $tml =~ s/$WC::NBBR\n/$WC::NBBR$WC::NBBR/go;
            $tml =~ s/$WC::NBBR( |$WC::NBSP)+$WC::NBBR/$WC::NBBR$WC::NBBR/go;
            $tml =~ s/ +$WC::NBBR/$WC::NBBR/go;
            $tml =~ s/$WC::NBBR +/$WC::NBBR/go;
            $tml =~ s/$WC::NBBR$WC::NBBR+/$WC::NBBR$WC::NBBR/go;

            # Now convert adjacent NBBRs to recreate empty lines
            # 1 NBBR  -> 1 newline
            # 2 NBBRs -> <p /> - 1 blank line - 2 newlines
            # 3 NBBRs -> 3 newlines
            # 4 NBBRs -> <p /><p /> - 3 newlines
            # 5 NBBRs -> 4 newlines
            # 6 NBBRs -> <p /><p /><p /> - 3 blank lines - 4 newlines
            # 7 NBBRs -> 5 newlines
            # 8 NBBRs -> <p /><p /><p /><p /> - 4 blank lines - 5 newlines
            $tml =~ s.($WC::NBBR$WC::NBBR$WC::NBBR$WC::NBBR+).
              "\n" x ((length($1) + 1) / 2 + 1)
                .geo;
        }
        # isolate $CHECKn and convert to $NBBR
        $tml =~ s/$WC::CHECKn([$WC::NBSP $WC::TAB])*$WC::CHECKn/$WC::CHECKn/go;
        $tml =~ s/$WC::CHECKn$WC::CHECKn+/$WC::CHECKn/go;
        $tml =~ s/(?<=$WC::NBBR)$WC::CHECKn//gom;
        $tml =~ s/$WC::CHECKn(?=$WC::NBBR)//gom;
        $tml =~ s/$WC::CHECKn+/$WC::NBBR/gos;

        $tml =~ s/$WC::NBBR/\n/gos;

        # Convert tabs to NBSP
        $tml =~ s/$WC::TAB/$WC::NBSP$WC::NBSP$WC::NBSP/go;

        # isolate $NBSP and convert to space
        unless ($protect) {
            $tml =~ s/ +$WC::NBSP/$WC::NBSP/go;
            $tml =~ s/$WC::NBSP +/$WC::NBSP/go;
        }
        $tml =~ s/$WC::NBSP/ /go;

        $tml =~ s/$WC::CHECK1$WC::CHECK1+/$WC::CHECK1/go;
        $tml =~ s/$WC::CHECK2$WC::CHECK2+/$WC::CHECK2/go;
        $tml =~ s/$WC::CHECK2$WC::CHECK1/$WC::CHECK2/go;

        $tml =~ s/(^|[\s\(])$WC::CHECK1/$1/gso;
        $tml =~ s/$WC::CHECK2($|[\s\,\.\;\:\!\?\)\*])/$1/gso;

        $tml =~ s/$WC::CHECK1(\s|$)/$1/gso;
        $tml =~ s/(^|\s)$WC::CHECK2/$1/gso;

        $tml =~ s/$WC::CHECK1/ /go;
        $tml =~ s/$WC::CHECK2/ /go;
        #print STDERR WC::debugEncode($before);
        #print STDERR " -> '",WC::debugEncode($tml),"'\n";
        $text .= $tml;
    }
    # Collapse adjacent tags
    foreach my $tag qw(noautolink verbatim literal) {
        $text =~ s#</$tag>(\s*)<$tag>#$1#gs;
    }
    # Top and tail, and terminate with a single newline
    $text =~ s/^\n*//s;
    $text =~ s/\s*$/\n/s;

    # Item5127: Remove BR just before EOLs
    $text =~ s/<br( \/)?>\n/\n/g;

    return $text;
}

# Collapse adjacent VERBATIM nodes together
# Collapse a <p> than contains only a protected span into a protected P
# Collapse em in em
# Collapse adjacent text nodes
sub _collapse {
    my $this = shift;

    my @jobs = ( $this );
    while (scalar(@jobs)) {
        my $node = shift(@jobs);
        if (defined($node->{tag}) && $node->hasClass('TMLverbatim')) {
            my $next = $node->{next};
            my @edible;
            my $collapsible;
            while ($next &&
                     ((!$next->{tag} && $next->{text} =~ /^\s*$/) ||
                          ($node->{tag} eq $next->{tag} &&
                             $next->hasClass('TMLverbatim')))) {
                push(@edible, $next);
                $collapsible ||= $next->hasClass('TMLverbatim');
                $next = $next->{next};
            }
            if ($collapsible) {
                foreach my $meal (@edible) {
                    $meal->_remove();
                    if ($meal->{tag}) {
                        require TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;
                        $node->addChild(new TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf($WC::NBBR));
                        $node->_eat($meal);
                    }
                }
            }
        }
        if ($node->{tag} eq 'p' &&
              $node->{head} && $node->{head} == $node->{tail}) {
            my $kid = $node->{head};
            if ($kid->{tag} eq 'SPAN' &&
                  $kid->hasClass('WYSIWYG_PROTECTED')) {
                $kid->_remove();
                $node->_eat($kid);
                $node->_addClass('WYSIWYG_PROTECTED');
            }
        }

        # If this is an emphasis (b, i, code, tt, strong) then
        # flatten out any child nodes that express the same emphasis.
        # This has to be done because TWiki emphases are single level.
        if ($WC::EMPHTAG{$node->{tag}}) {
            my $kid = $node->{head};
            while ($kid) {
                if ($WC::EMPHTAG{$kid->{tag}} &&
                      $WC::EMPHTAG{$kid->{tag}} eq
                        $WC::EMPHTAG{$node->{tag}}) {
                    $kid = $kid->_inline();
                } else {
                    $kid = $kid->{next};
                }
            }
        }
        $node->_combineLeaves();

        my $kid = $node->{head};
        while ($kid) {
            push(@jobs, $kid);
            $kid = $kid->{next};
        }
    }
}

# the actual generate function. rootGenerate is only applied to the root node.
sub generate {
    my( $this, $options ) = @_;
    my $fn;
    my $flags;
    my $text;

     if ($this->_isProtectedByAttrs()) {
         return $this->_defaultTag($options);
     }

    my $tag = $this->{tag};

    if ($this->hasClass('WYSIWYG_LITERAL')) {
        if ($tag eq 'div' || $tag eq 'p' || $tag eq 'span') {
            $text = '';
            my $kid = $this->{head};
            while ($kid) {
                $text .= $kid->stringify();
                $kid = $kid->{next};
            }
        } else {
            $this->_removeClass('WYSIWYG_LITERAL');
            $text = $this->stringify();
        }
        return ( 0, '<literal>'.$text.'</literal>' );
    }

    if( $options & $WC::NO_HTML ) {
        # NO_HTML implies NO_TML
        my $brats = $this->_flatten( $options );
        return ( 0, $brats );
    }

    if( $options & $WC::NO_TML ) {
        return ( 0, $this->stringify() );
    }

    # make the names of the function versions
    $tag =~ s/!//; # DOCTYPE
    my $tmlFn = '_handle'.uc($tag);

    # See if we have a TML translation function for this tag
    # the translation functions will work out the rendering
    # of their own children.
    if( $this->{tag} && defined( &$tmlFn ) ) {
        no strict 'refs';
        ( $flags, $text ) = &$tmlFn( $this, $options );
        use strict 'refs';
        # if the function returns undef, drop through
        return ( $flags, $text ) if defined $text;
    }

    # No translation, so we need the text of the children
    ( $flags, $text ) = $this->_flatten( $options );

    # just return the text if there is no tag name
    return ( $flags, $text ) unless $this->{tag};

    return $this->_defaultTag( $options );
}

# Return the children flattened out subject to the options
sub _flatten {
    my( $this, $options ) = @_;
    my $text = '';
    my $flags = 0;

    my $protected = ($options & $WC::PROTECTED) ||
      $this->hasClass('WYSIWYG_PROTECTED') ||
        $this->hasClass('WYSIWYG_STICKY') || 0;

    if ($protected) {
        # Expand brs, which are used in the protected encoding in place of
        # newlines, and protect whitespace
        $options |= $WC::BR2NL | $WC::KEEP_WS;
    }

    my $kid = $this->{head};
    while ($kid) {
        my( $f, $t ) = $kid->generate( $options );
        if (!($options & $WC::KEEP_WS)
              && $text && $text =~ /\w$/ && $t =~ /^\w/) {
            # if the last child ends in a \w and this child
            # starts in a \w, we need to insert a space
            $text .= ' ';
        }
        $text .= $t;
        $flags |= $f;
        $kid = $kid->{next};
    }
    if ($protected) {
        $text =~ s/[$WC::PON$WC::POFF]//g;

        unless ($options & $WC::KEEP_ENTITIES) {
            require HTML::Entities;
            $text = HTML::Entities::decode_entities($text);
            # &nbsp; decodes to \240, which we want to make a space.
            $text =~ s/\240/$WC::NBSP/g;
        }
        $text =~ s/ /$WC::NBSP/g;
        $text =~ s/\n/$WC::NBBR/g;
        $text = $WC::PON.$text.$WC::POFF;
    }

    $text = _trim($text) unless ($options & $WC::KEEP_WS);

    return ( $flags, $text );
}

# $cutClasses is an RE matching class names to cut
sub _htmlParams {
    my ( $attrs, $options ) = @_;
    my @params;

    while (my ($k, $v) = each %$attrs ) {
        next unless $k;
        if( $k eq 'class' ) {
            # if cleaning aggressively, remove class attributes completely
            next if ($options & $WC::VERY_CLEAN);
            foreach my $c qw(WYSIWYG_PROTECTED WYSIWYG_STICKY TMLverbatim WYSIWYG_LINK) {
                $v =~ s/\b$c\b//;
            }
            $v =~ s/\s+/ /;
            $v =~ s/^\s*(.*?)\s*$/$1/;
            next unless $v;
        }
        my $q = $v =~ /"/ ? "'" : '"';
        push( @params, $k.'='.$q.$v.$q );
    }
    my $p = join( ' ', @params );
    return '' unless $p;
    return ' '.$p;
}

# generate the default representation of an HTML tag
sub _defaultTag {
    my( $this, $options ) = @_;
    my( $flags, $text ) = $this->_flatten( $options );
    my $tag = $this->{tag};
    my $p = _htmlParams( $this->{attrs}, $options );

    if( $text =~ /^\s*$/ && $WC::SELFCLOSING{$tag}) {
        return ( $flags, '<'.$tag.$p.' />' );
    } else {
        return ( $flags, '<'.$tag.$p.'>'.$text.'</'.$tag.'>' );
    }
}

# Check to see if the HTML tag is protected by the presence of
# specific attributes that block conversion to TML. The conversion
# table is defined in 
sub _isProtectedByAttrs {
    my $this = shift;

    require TWiki::Plugins::WysiwygPlugin;
    foreach my $attr (keys %{$this->{attrs}}) {
        next unless length($this->{attrs}->{$attr}); # ignore nulls
        return $attr if TWiki::Plugins::WysiwygPlugin::protectedByAttr(
            $this->{tag}, $attr);
    }
    return 0;
}

# perform conversion on a list type
sub _convertList {
    my( $this, $indent ) = @_;
    my $basebullet;
    my $isdl = ( $this->{tag} eq 'dl' );

    if( $isdl ) {
        $basebullet = '';
    } elsif( $this->{tag} eq 'ol' ) {
        $basebullet = '1';
    } else {
        $basebullet = '*';
    }

    my $f;
    my $text = '';
    my $pendingDT = 0;
    my $kid = $this->{head};
    while ($kid) {
        # be tolerant of dl, ol and ul with no li
        if( $kid->{tag} =~ m/^[dou]l$/i ) {
            $text .= $kid->_convertList( $indent.$WC::TAB );
            $kid = $kid->{next};
            next;
        }
        unless ($kid->{tag} =~ m/^(dt|dd|li)$/i) {
            $kid = $kid->{next};
            next;
        }
        if( $isdl && ( $kid->{tag} eq 'dt' )) {
            # DT, set the bullet type for subsequent DT
            $basebullet = $kid->_flatten( $WC::NO_BLOCK_TML );
            $basebullet =~ s/[\s$WC::CHECKw$WC::CHECKs]+$//;
            $basebullet .= ':';
            $basebullet =~ s/$WC::CHECKn/ /g;
            $basebullet =~ s/^\s+//;
            $basebullet = '$ '.$basebullet;
            $pendingDT = 1; # remember in case there is no DD
            $kid = $kid->{next};
            next;
        }
        my $bullet = $basebullet;
        if( $basebullet eq '1' && $kid->{attrs}->{type} ) {
            $bullet = $kid->{attrs}->{type}.'.';
        }
        my $spawn = '';
        my $t;
        my $grandkid = $kid->{head};
        # IE generates spurious empty divs inside LIs. Detect and skip
        # them.
        if( $grandkid->{tag} =~ /^div$/i
              && $grandkid == $kid->{tail}
                && scalar(keys %{$this->{attrs}}) == 0 ) {
            $grandkid = $grandkid->{head};
        }
        while ($grandkid) {
            if( $grandkid->{tag} =~ /^[dou]l$/i ) {
                #$spawn = _trim( $spawn );
                $t = $grandkid->_convertList( $indent.$WC::TAB );
            } else {
                ( $f, $t ) = $grandkid->generate( $WC::NO_BLOCK_TML );
                $t =~ s/$WC::CHECKn/ /g;
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
        #$spawn = _trim($spawn);
        $text .= $WC::CHECKn.$indent.$bullet.$WC::CHECKs.$spawn.$WC::CHECKn;
        $pendingDT = 0;
        $basebullet = '' if $isdl;
        $kid = $kid->{next};
    }
    if( $pendingDT ) {
        # DT with no corresponding DD
        $text .= $WC::CHECKn.$indent.$basebullet.$WC::CHECKn;
    }
    return $text;
}

# probe down into a list type to determine if it
# can be converted to TML.
sub _isConvertableList {
    my( $this, $options ) = @_;

    return 0 if ($this->_isProtectedByAttrs());

    my $kid = $this->{head};
    while ($kid) {
        # check for malformed list. We can still handle it,
        # by simply ignoring illegal text.
        # be tolerant of dl, ol and ul with no li
        if( $kid->{tag} =~ m/^[dou]l$/i ) {
            return 0 unless $kid->_isConvertableList( $options );
        } elsif( $kid->{tag} =~ m/^(dt|dd|li)$/i ) {
            unless( $kid->_isConvertableListItem( $options, $this )) {
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
    my( $this, $options, $parent ) = @_;
    my( $flags, $text );

    return 0 if ($this->_isProtectedByAttrs());

    if( $parent->{tag} eq 'dl' ) {
        return 0 unless( $this->{tag} =~ /^d[td]$/i );
    } else {
        return 0 unless( $this->{tag} eq 'li' );
    }

    my $kid = $this->{head};
    while ($kid) {
        if( $kid->{tag} =~ /^[oud]l$/i ) {
            unless( $kid->_isConvertableList( $options )) {
                return 0;
            }
        } else {
            ( $flags, $text ) = $kid->generate( $options );
            if( $flags & $WC::BLOCK_TML ) {
                return 0;
            }
        }
        $kid = $kid->{next};
    }
    return 1;
}

# probe down into a list type to determine if it
# can be converted to TML.
sub _isConvertableTable {
    my( $this, $options, $table ) = @_;

    if ($this->_isProtectedByAttrs()) {
        return 0;
    }

    my $kid = $this->{head};
    while ($kid) {
        if( $kid->{tag} =~ /^(colgroup|thead|tbody|tfoot|col)$/ ) {
            unless ($kid->_isConvertableTable( $options, $table )) {
                return 0;
            }
        } elsif( $kid->{tag} ) {
            unless ($kid->{tag} eq 'tr') {
                return 0;
            }
            my $row = $kid->_isConvertableTableRow( $options );
            unless ($row) {
                return 0;
            }
            push( @$table, $row );
        }
        $kid = $kid->{next};
    }
    return 1;
}

# Tidy up whitespace on the sides of a table cell, and also strip trailing
# BRs, as added by some table editors.
sub _TDtrim {
    my $td = shift;
    $td =~ s/^($WC::NBSP|$WC::NBBR|$WC::CHECKn|$WC::CHECKs|$WC::CHECKw|$WC::CHECK1|$WC::CHECK2|$WC::TAB|\s)+//so;
    $td =~ s/(<br \/>|<br>|$WC::NBSP|$WC::NBBR|$WC::CHECKn|$WC::CHECKs|$WC::CHECKw|$WC::CHECK1|$WC::CHECK2|$WC::TAB|\s)+$//so;
    return $td;
}

# probe down into a list item to determine if the
# containing table can be converted to TML.
sub _isConvertableTableRow {
    my( $this, $options ) = @_;

    return 0 if ($this->_isProtectedByAttrs());

    my( $flags, $text );
    my @row;
    my $ignoreCols = 0;
    my $kid = $this->{head};
    while ($kid) {
        if ($kid->{tag} eq 'th') {
            ( $flags, $text ) = $kid->_flatten( $options );
            $text = _TDtrim( $text );
            $text = "*$text*" if length($text);
        } elsif ($kid->{tag} eq 'td' ) {
            ( $flags, $text ) = $kid->_flatten( $options );
            $text = _TDtrim( $text );
        } elsif( !$kid->{tag} ) {
            $kid = $kid->{next};
            next;
        } else {
            # some other sort of (unexpected) tag
            return 0;
        }
        return 0 if( $flags & $WC::BLOCK_TML );

        if( $kid->{attrs} ) {
            my $a = _deduceAlignment( $kid );
            if( $text && $a eq 'right' ) {
                $text = $WC::NBSP.$text;
            } elsif( $text && $a eq 'center' ) {
                $text = $WC::NBSP.$text.$WC::NBSP;
            } elsif( $text && $a eq 'left' ) {
                $text .= $WC::NBSP;
            }
            if( $kid->{attrs}->{rowspan} && $kid->{attrs}->{rowspan} > 1 ) {
                return 0;
            }
        }
        $text =~ s/&nbsp;/$WC::NBSP/g;
        #if (--$ignoreCols > 0) {
        #    # colspanned
        #    $text = '';
        #} els
        if ($text =~ /^$WC::NBSP*$/) {
            $text = $WC::NBSP;
        } else {
            $text = $WC::NBSP.$text.$WC::NBSP;
        }
        if( $kid->{attrs} && $kid->{attrs}->{colspan} &&
              $kid->{attrs}->{colspan} > 1 ) {
            $ignoreCols = $kid->{attrs}->{colspan};
        }
        # Pad to allow wikiwords to work
        push( @row, $text );
        while ($ignoreCols > 1) {
            push( @row, '' );
            $ignoreCols--;
        }
        $kid = $kid->{next};
    }
    return \@row;
}

# Work out the alignment of a table cell from the style and/or class
sub _deduceAlignment {
    my $td = shift;

    if( $td->{attrs}->{align} ) {
        return lc( $td->{attrs}->{align} );
    } else {
        if( $td->{attrs}->{style} &&
              $td->{attrs}->{style} =~ /text-align\s*:\s*(left|right|center)/ ) {
            return $1;
        }
        if ($td->hasClass(qr/align-(left|right|center)/)) {
            return $1;
        }
    }
    return '';
}

# convert a heading tag
sub _H {
    my( $this, $options, $depth ) = @_;
    my( $flags, $contents ) = $this->_flatten( $options );
    return ( 0, undef ) if( $flags & $WC::BLOCK_TML );
    my $notoc = '';
    if( $this->hasClass( 'notoc' )) {
        $notoc = '!!';
    }
    my $indicator = '+';
    if( $this->hasClass( 'numbered' )) {
        $indicator = '#';
    }
    $contents =~ s/^\s+/ /;
    $contents =~ s/\s+$//;
    my $res = $WC::CHECKn.'---'.($indicator x $depth).$notoc.
      $WC::CHECKs.$contents.$WC::CHECKn;
    return ( $flags | $WC::BLOCK_TML, $res );
}

# generate an emphasis
sub _emphasis {
    my( $this, $options, $ch ) = @_;
    my( $flags, $contents ) = $this->_flatten( $options | $WC::NO_BLOCK_TML );
    return ( 0, undef ) if( !defined( $contents ) || ( $flags & $WC::BLOCK_TML ));

    # Remove whitespace from either side of the contents, retaining the
    # whitespace
    $contents =~ s/&nbsp;/$WC::NBSP/go;
    $contents =~ /^($WC::WS)(.*?)($WC::WS)$/;
    my ($pre, $post) = ($1, $3);
    $contents = $2;
    return (0, undef) if( $contents =~ /^</ || $contents =~ />$/ );
    return (0, '') unless( $contents =~ /\S/ );

    # Now see if we can collapse the emphases
    if ($ch eq '_' && $contents =~ s/^\*(.*)\*$/$1/ ||
          $ch eq '*' && $contents =~ s/^_(?!_)(.*)(?<!_)_$/$1/) {
        $ch = '__';
    } elsif ($ch eq '=' && $contents =~ s/^\*(.*)\*$/$1/ ||
          $ch eq '*' && $contents =~ s/^=(?!=)(.*)(?<!=)=$/$1/) {
        $ch = '==';
    } elsif ($contents =~ /^([*_=]).*\1$/) {
        return (0, undef);
    }

    my $be = $this->_checkBeforeEmphasis();
    my $ae = $this->_checkAfterEmphasis();
    return ( 0, undef ) unless $ae && $be;

    return ( $flags, $pre.$WC::CHECKw.$ch.$contents.$ch.$WC::CHECK2.$post );
}

sub isBlockNode {
    my $node = shift;
    return ($node->{tag} && $node->{tag} =~ /^(ADDRESS|BLOCKQUOTE|CENTER|DIR|DIV|DL|FIELDSET|FORM|H\d|HR|ISINDEX|MENU|NOFRAMES|NOSCRIPT|OL|P|PRE|TABLE|UL)$/i);
}

sub previousLeaf {
    my $node = shift;
    if (!$node) {
        return undef;
    }
    do {
        while (!$node->{prev}) {
            if (!$node->{parent}) {
                return undef; # can't go any further back
            }
            $node = $node->{parent};
        }
        $node = $node->{prev};
        while (!$node->isTextNode()) {
            $node = $node->{tail};
        }
    } while (!$node->isTextNode());
    return $node;
}

# Test for /^|(?<=[\s\(])/ at the end of the leaf node before.
sub _checkBeforeEmphasis {
    my ($this) = @_;
    my $tb = $this->previousLeaf();
    return 1 unless $tb;
    return 1 if ($tb->isBlockNode());
    return 1 if ($tb->{nodeType} == 3 && $tb->{text} =~ /[\s(*_=]$/);
    return 0;
}

sub nextLeaf {
    my $node = shift;
    if (!$node) {
        return undef;
    }
    do {
        while (!$node->{next}) {
            if (!$node->{parent}) {
                return; # end of the road
            }
            $node = $node->{parent};
            if ($node->isBlockNode()) {
                # leaving this $node
                return $node;
            }
        }
        $node = $node->{next};
        while (!$node->isTextNode()) {
            $node = $node->{head};
        }
    } while (!$node->isTextNode());
    return $node;
}

# Test for /$|(?=[\s,.;:!?)])/ at the start of the leaf node after.
sub _checkAfterEmphasis {
    my ($this) = @_;
    my $tb = $this->nextLeaf();
    return 1 unless $tb;
    return 1 if ($tb->isBlockNode());
    return 1 if ($tb->{nodeType} == 3 && $tb->{text} =~ /^[\s,.;:!?)*_=]/);
    return 0;
}

# generate verbatim for P, SPAN or PRE
sub _verbatim {
    my ($this, $tag, $options) = @_;

    $options |= $WC::PROTECTED|$WC::KEEP_ENTITIES|$WC::BR2NL | $WC::KEEP_WS;
    my( $flags, $text ) = $this->_flatten($options);
    # decode once, and once only
    require HTML::Entities;
    $text = HTML::Entities::decode_entities($text);
    # &nbsp; decodes to \240, which we want to make a space.
    $text =~ s/\240/$WC::NBSP/g;
    my $p = _htmlParams($this->{attrs}, $options);
    return ($flags, "<$tag$p>$text</$tag>");
}

# pseudo-tags that may leak through in TWikiVariables
# We have to handle this to avoid a matching close tag </nop>
sub _handleNOP {
    my( $this, $options ) = @_;
    my( $flags, $text ) = $this->_flatten( $options );
    return ($flags, '<nop>'.$text);
}

sub _handleNOPRESULT {
    my( $this, $options ) = @_;
    my( $flags, $text ) = $this->_flatten( $options );
    return ($flags, '<nop>'.$text);
}

# tags we ignore completely (contents as well)
sub _handleDOCTYPE { return ( 0, '' ); }

sub _LIST {
    my( $this, $options ) = @_;
    if( ( $options & $WC::NO_BLOCK_TML ) ||
        !$this->_isConvertableList( $options | $WC::NO_BLOCK_TML )) {
        return ( 0, undef );
    }
    return ( $WC::BLOCK_TML, $this->_convertList( $WC::TAB ));
}

# Performs initial cleanup of the parse tree before generation. Walks the
# tree, making parent links and removing attributes that don't add value.
# This simplifies determining whether a node is to be kept, or flattened
# out.
# $opts may include $WC::VERY_CLEAN
sub cleanNode {
    my( $this, $opts ) = @_;
    my $a;

    # Always delete these attrs
    foreach $a qw( lang _moz_dirty ) {
        delete $this->{attrs}->{$a}
          if( defined( $this->{attrs}->{$a} ));
    }

    # Delete these attrs if their value is empty
    foreach $a qw( class style ) {
        if( defined( $this->{attrs}->{$a} ) &&
              $this->{attrs}->{$a} !~ /\S/ ) {
            delete $this->{attrs}->{$a};
        }
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
    my( $this, $options ) = @_;

    my( $flags, $text ) = $this->_flatten( $options | $WC::NO_BLOCK_TML );
    if( $text && $text =~ /\S/ && $this->{attrs}->{href}) {
        # there's text and an href
        my $href = $this->{attrs}->{href};
        # decode URL params in the href
        $href =~ s/%([0-9A-F]{2})/chr(hex($1))/gei;
        if( $this->{context} && $this->{context}->{rewriteURL} ) {
            $href = $this->{context}->{rewriteURL}->(
                $href, $this->{context} );
        }
        $reww = TWiki::Func::getRegularExpression('wikiWordRegex')
          unless $reww;
        my $nop = ($options & $WC::NOP_ALL) ? '<nop>' : '';
        if( $href =~ /^(\w+\.)?($reww)(#\w+)?$/ ) {
            my $web = $1 || '';
            my $topic = $2;
            my $anchor = $3 || '';
            my $cleantext = $text;
            $cleantext =~ s/<nop>//g;
            $cleantext =~ s/^$this->{context}->{web}\.//;

            # if the clean text is the known topic we can ignore it
            if( ($cleantext eq $href || $href =~ /\.$cleantext$/)) {
                return (0, $WC::CHECK1.$nop.$web.$topic.$anchor.$WC::CHECK2);
            }
        }

        if( $href =~ /${WC::PROTOCOL}[^?]*$/ && $text eq $href ) {
            return (0, $WC::CHECK1.$nop.$text.$WC::CHECK2);
        }
        if( $text eq $href ) {
            return (0, $WC::CHECKw.'['.$nop.'['.$href.']]' );
        }
        return (0, $WC::CHECKw.'['.$nop.'['.$href.']['.$text.
                  ']]' );
    } elsif( $this->{attrs}->{name} ) {
        # allow anchors to be expanded normally. This won't generate
        # wiki anchors, but it's a small price to pay - it would
        # be too complex to generate wiki anchors, given their
        # line-oriented nature.
        return (0, undef);
    }
    # Otherwise generate nothing
    return (0, '');
}

sub _handleABBR { return _flatten( @_ ); };
sub _handleACRONYM { return _flatten( @_ ); };
sub _handleADDRESS { return _flatten( @_ ); };

sub _handleB { return _emphasis( @_, '*' ); }
sub _handleBASE { return ( 0, '' ); }
sub _handleBASEFONT { return ( 0, '' ); }

sub _handleBIG { return( 0, '' ); };
# BLOCKQUOTE
sub _handleBODY { return _flatten( @_ ); }
# BUTTON

sub _handleBR {
    my( $this, $options ) = @_;
    my($f, $kids ) = $this->_flatten( $options );
    # Test conditions for keeping a <br>. These are:
    # 1. We haven't explicitly been told to convert to \n (by BR2NL)
    # 2. We have been told that block TML is illegal
    # 3. The previous node is an inline element node or text node
    # 4. The next node is an inline element or text node
    my $sep = "\n";
    if ($options & $WC::BR2NL) {
    } elsif ($options & $WC::NO_BLOCK_TML) {
        $sep = '<br />';
    } elsif ($this->prevIsInline()) {
        if ($this->isInline()) {
            # Both <br> and </br> cause a NL
            # if this is empty, look at next
            if ($kids !~ /^[\000-\037]*$/ &&
                  $kids !~ /^[\000-\037]*$WC::NBBR/ ||
                    $this->nextIsInline()) {
                $sep = '<br />';
            }
        }
    }
    return ($f, $sep.$kids);
}

sub _handleCAPTION { return (0, '' ); }
# CENTER
# CITE

sub _handleCODE { return _emphasis( @_, '=' ); }

sub _handleCOL { return _flatten( @_ ); };
sub _handleCOLGROUP { return _flatten( @_ ); };
sub _handleDD { return _flatten( @_ ); };
sub _handleDEL { return _flatten( @_ ); };
sub _handleDFN { return _flatten( @_ ); };
# DIR

sub _handleDIV { return _handleP(@_); }

sub _handleDL { return _LIST( @_ ); }
sub _handleDT { return _flatten( @_ ); };

sub _handleEM { return _emphasis( @_, '_' ); }

sub _handleFIELDSET { return _flatten( @_ ); };

sub _handleFONT {
    my( $this, $options ) = @_;

    my %atts = %{$this->{attrs}};
    # Try to convert font tags into %COLOUR%..%ENDCOLOR%
    # First extract the colour
    my $colour;
    if ($atts{style}) {
        my $style = $atts{style};
        if ($style =~ s/(^|\s|;)color\s*:\s*([^\s;]+);?//i) {
            $colour = $2;
            delete $atts{style} if $style =~ /^[\s;]*$/;
        }
    }
    if ($atts{color}) {
        $colour = $atts{color};
        delete $atts{color};
    }
    # The presence of the class forces it to be converted to a
    # TWiki variable
    if (!_removeClass(\%atts, 'WYSIWYG_COLOUR')) {
        delete $atts{class};
        if (scalar(keys %atts) > 0 || !$colour || $colour !~ /^([a-z]+|#[0-9A-Fa-f]{6})$/i) {
            return ( 0, undef );
        }
    }
    # OK, just the colour
    $colour = $WC::KNOWN_COLOUR{uc($colour)};
    if (!$colour) {
        # Not a recognised colour
        return ( 0, undef );
    }
    my( $f, $kids ) = $this->_flatten( $options );
    return ($f, '%'.uc($colour).'%'.$kids.'%ENDCOLOR%');
};

# FORM
sub _handleFRAME    { return _flatten( @_ ); };
sub _handleFRAMESET { return _flatten( @_ ); };
sub _handleHEAD     { return ( 0, '' ); }

sub _handleHR {
    my( $this, $options ) = @_;

    my( $f, $kids ) = $this->_flatten( $options );
    return ($f, '<hr />'.$kids) if( $options & $WC::NO_BLOCK_TML );
    return ( $f | $WC::BLOCK_TML, $WC::CHECKn.'---'.$WC::CHECKn.$kids);
}

sub _handleHTML   { return _flatten( @_ ); }
sub _handleH1     { return _H( @_, 1 ); }
sub _handleH2     { return _H( @_, 2 ); }
sub _handleH3     { return _H( @_, 3 ); }
sub _handleH4     { return _H( @_, 4 ); }
sub _handleH5     { return _H( @_, 5 ); }
sub _handleH6     { return _H( @_, 6 ); }
sub _handleI      { return _emphasis( @_, '_' ); }

sub _handleIMG {
    my( $this, $options ) = @_;

    # Hack out mce_src, which is TinyMCE-specific and causes indigestion
    # when the topic is reloaded
    delete $this->{attrs}->{mce_src} if defined $this->{attrs}->{mce_src};
    if( $this->{context} && $this->{context}->{rewriteURL} ) {
        my $href = $this->{attrs}->{src};
        # decode URL params in the href
        $href =~ s/%([0-9A-F]{2})/chr(hex($1))/gei;
        $href = &{$this->{context}->{rewriteURL}}(
            $href, $this->{context} );
        $this->{attrs}->{src} = $href;
    }

    return (0, undef) unless $this->{context} &&
      defined $this->{context}->{convertImage};

    my $alt = &{$this->{context}->{convertImage}}(
        $this->{attrs}->{src},
        $this->{context} );
    if( $alt ) {
        return (0, $alt);
    }
    return ( 0, undef );
}

# INPUT
# INS
# ISINDEX
sub _handleKBD      { return _handleTT( @_ ); }
# LABEL
# LI
sub _handleLINK     { return( 0, '' ); };
# MAP
# MENU
sub _handleMETA     { return ( 0, '' ); }
sub _handleNOFRAMES { return ( 0, '' ); }
sub _handleNOSCRIPT { return ( 0, '' ); }
sub _handleOL       { return _LIST( @_ ); }
# OPTGROUP
# OPTION

sub _handleP {
    my( $this, $options ) = @_;

    if ($this->hasClass('TMLverbatim')) {
        return $this->_verbatim('verbatim', $options);
    }
    if ($this->hasClass('WYSIWYG_STICKY')) {
        return $this->_verbatim('sticky', $options);
    }

    my( $f, $kids ) = $this->_flatten( $options );
    return ($f, '<p>'.$kids.'</p>') if( $options & $WC::NO_BLOCK_TML );
    my $pre = '';
    if ($this->prevIsInline()) {
        $pre = $WC::NBBR;
    }
    return ($f | $WC::BLOCK_TML, $pre.$WC::NBBR.$kids.$WC::NBBR);
}

# PARAM

sub _handlePRE {
    my( $this, $options ) = @_;

    my $tag = 'pre';
    if( $this->hasClass('TMLverbatim')) {
        return $this->_verbatim('verbatim', $options);
    }
    if ($this->hasClass('WYSIWYG_STICKY')) {
        return $this->_verbatim('sticky', $options);
    }
    unless( $options & $WC::NO_BLOCK_TML ) {
        my( $flags, $text ) = $this->_flatten(
            $options | $WC::NO_BLOCK_TML | $WC::BR2NL | $WC::KEEP_WS );
        my $p = _htmlParams( $this->{attrs}, $options);
        return ($WC::BLOCK_TML, "<$tag$p>$text</$tag>");
    }
    return ( 0, undef );
}

sub _handleQ    { return _flatten( @_ ); };
# S
sub _handleSAMP { return _handleTT( @_ ); };
# SCRIPT
# SELECT
# SMALL

sub _handleSPAN {
    my( $this, $options ) = @_;

    my %atts = %{$this->{attrs}};
    if (_removeClass(\%atts, 'TMLverbatim')) {
        return $this->_verbatim('verbatim', $options);
    }
    if (_removeClass(\%atts, 'WYSIWYG_STICKY')) {
        return $this->_verbatim('sticky', $options);
    }

    if( _removeClass(\%atts, 'WYSIWYG_LINK')) {
        $options |= $WC::NO_BLOCK_TML;
    }

    if( _removeClass(\%atts, 'WYSIWYG_TT')) {
        return _emphasis( @_, '=' );
    }

    # Remove all other classes
    delete $atts{class};

    if( $options & $WC::VERY_CLEAN ) {
        # remove style attribute if cleaning aggressively. Have to do this
        # because TWiki generates these.
        delete $atts{style} if defined $atts{style}
    }

    # ignore the span tag if there are no other attrs
    if( scalar(keys %atts) == 0 ) {
        return $this->_flatten( $options );
    }

    # otherwise use the default generator.
    return (0, undef);
}

# STRIKE

sub _handleSTRONG { return _emphasis( @_, '*' ); }

sub _handleSTYLE { return ( 0, '' ); }
# SUB
# SUP

sub _handleTABLE {
    my( $this, $options ) = @_;
    return ( 0, undef) if( $options & $WC::NO_BLOCK_TML );

    # Should really look at the table attrs, but to heck with it

    return ( 0, undef ) if( $options & $WC::NO_BLOCK_TML );

    my @table;
    return ( 0, undef ) unless
      $this->_isConvertableTable( $options | $WC::NO_BLOCK_TML, \@table );

    my $maxrow = 0;
    my $row;
    foreach $row ( @table ) {
        my $rw = scalar( @$row );
        $maxrow = $rw if( $rw > $maxrow );
    }
    foreach $row ( @table ) {
        while( scalar( @$row ) < $maxrow) {
            push( @$row, '' );
        }
    }
    my $text = $WC::CHECKn;
    foreach $row ( @table ) {
        # isConvertableTableRow has already formatted the cell
        $text .= $WC::CHECKn.'|'.join('|', @$row).'|'.$WC::CHECKn;
    }

    return ( $WC::BLOCK_TML, $text );
}

# TBODY
# TD

# TEXTAREA {
# TFOOT
# TH
# THEAD
sub _handleTITLE { return (0, '' ); }
# TR
sub _handleTT    { return _handleCODE( @_ ); }
# U
sub _handleUL    { return _LIST( @_ ); }
sub _handleVAR   { return ( 0, '' ); }

1;
