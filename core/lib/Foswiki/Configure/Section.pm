# See bottom of file for license and copyright information
package Foswiki::Configure::Section;
use v5.14;

=begin TML

---+ package Foswiki::Configure::Section

A collection node in a configuration item tree; a collection
of configuration items and subsections.

IMPORTANT: there are some naming conventions for fields that apply to
all subclasses of this class. See Foswiki::Configure::Item for details.

=cut

use Moo;
use namespace::clean;
extends qw(Foswiki::Configure::Item);

# Attributes legal on a section header
use constant ATTRSPEC => {
    EXPERT => {},
    SORTED => {}
};

=begin TML

---++ ClassMethod new(@opts)
   * =@opts= - array of key-value options, e.g. headline => 'Security Settings'

Constructor.

=cut

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;

    $params{children} //= [];
    $params{headline} //= 'UNKNOWN';
    $params{typename} //= 'SECTION';

    return $orig->( $class, %params );
};

=begin TML

---++ ObjectMethod addChild($child)
Add a child node under this node.

=cut

sub addChild {
    my ( $this, $child ) = @_;
    foreach my $kid ( @{ $this->attrs->{children} } ) {
        die "Subnode already present; cannot add again" if $child eq $kid;
    }
    $child->attrs->{_parent} = $this;
    $child->attrs->{depth}   = $this->attrs->{depth} + 1;

    push( @{ $this->attrs->{children} }, $child );

    $this->_addToVobCache($child);
}

# The _vobCache provides fast access to value items
sub _addToVobCache {
    my ( $this, $child ) = @_;

    if ( $child->isa('Foswiki::Configure::Section') ) {
        while ( my ( $k, $v ) = each %{ $child->attrs->{_vobCache} } ) {
            $this->attrs->{_vobCache}->{$k} = $v;
        }
    }
    else {
        $this->attrs->{_vobCache}->{ $child->attrs->{keys} } = $child;
    }
    $this->attrs->{_parent}->_addToVobCache($child) if $this->attrs->{_parent};
}

# See Foswiki::Configure::Item
sub hasDeep {
    my ( $this, $attrname ) = @_;
    return 1 if $this->attrs->{$attrname};
    foreach my $kid ( @{ $this->attrs->{children} } ) {
        return 1 if $kid->hasDeep($attrname);
    }
    return 0;
}

# See Foswiki::Configure::Item
sub unparent {
    my $this = shift;

    if ( $this->attrs->{children} ) {
        foreach my $c ( @{ $this->attrs->{children} } ) {
            $c->unparent();
        }
    }
    $this->SUPER::unparent();
}

# See Foswiki::Configure::Item
sub prune {
    my ( $this, $depth ) = @_;

    if ( $depth == 0 ) {
        delete $this->attrs->{children};
    }
    elsif ( $this->attrs->{children} ) {
        foreach my $c ( @{ $this->attrs->{children} } ) {
            $c->prune( $depth - 1 );
        }
    }
}

# See Foswiki::Configure::Item
# Visit each of the children of this node in turn.
sub visit {
    my ( $this, $visitor ) = @_;
    my %visited;
    return 0 unless $visitor->startVisit($this);
    foreach my $child ( @{ $this->attrs->{children} } ) {
        if ( $visited{$child} ) {
            die join( ' ', @{ $this->attrs->{children} } );
        }
        $visited{$child} = 1;
        return 0 unless $child->visit($visitor);

    }
    return 0 unless $visitor->endVisit($this);
    return 1;
}

# See Foswiki::Configure::Item
sub getSectionObject {
    my ( $this, $head, $depth ) = @_;
    if ( $this->attrs->{headline} eq $head
        && ( !defined $depth || $this->attrs->{depth} == $depth ) )
    {
        return $this;
    }
    foreach my $child ( @{ $this->attrs->{children} } ) {
        my $cvo = $child->getSectionObject( $head, $depth );
        return $cvo if $cvo;
    }
    return undef;
}

# Implements Foswiki::Configure::Item
# Keys are only present on leaf items, so recursively query until we
# find the appropriate leaf Value.
sub getValueObject {
    my ( $this, $keys ) = @_;
    return $this->attrs->{_vobCache}->{$keys};
}

# Implements Foswiki::Configure::Item
sub getAllValueKeys {
    my $this = shift;
    return keys %{ $this->attrs->{_vobCache} };
}

# Implements Foswiki::Configure::Item
sub promoteSetting {
    my ( $this, $setting ) = @_;
    my $on_me = 1;

    foreach my $child ( @{ $this->attrs->{children} } ) {
        $on_me = 0 unless $child->promoteSetting($setting);
    }

    if ($on_me) {
        $this->attrs->{$setting} = 1;
    }
    else {
        delete $this->attrs->{$setting};
    }

    return $this->attrs->{$setting};
}

# Implements Foswiki::Configure::Item
sub getPath {
    my $this = shift;

    my @path;
    @path = $this->attrs->{_parent}->getPath() if ( $this->attrs->{_parent} );
    push( @path, $this->attrs->{headline} ) if $this->attrs->{headline};

    return @path;
}

# Implements Foswiki::Configure::Item
sub search {
    my ( $this, $re ) = @_;

    my @result = ();
    push( @result, $this ) if $this->attrs->{headline} =~ m/$re/i;
    foreach my $child ( @{ $this->attrs->{children} } ) {
        push( @result, $child->search($re) );
    }
    return @result;
}

# Implements Foswiki::Configure::Item
sub find {
    my $this   = shift;
    my %search = @_;

    my $match = $this->_matches(%search);

    # Return without searching the subtree if this node matches
    if ($match) {
        return ($this);
    }

    return () unless $this->attrs->{children};

    # Search children
    my @result = ();
    foreach my $child ( @{ $this->attrs->{children} } ) {
        push( @result, $child->find(@_) );
    }

    return @result;
}

# Implements Foswiki::Configure::Item
sub find_also_dependencies {
    my ( $this, $root ) = @_;

    $root ||= $this;

    foreach my $kid ( @{ $this->attrs->{children} } ) {
        $kid->find_also_dependencies($root);
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
