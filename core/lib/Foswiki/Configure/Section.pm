# See bottom of file for license and copyright information
package Foswiki::Configure::Section;

=begin TML

---+ package Foswiki::Configure::Section

A collection node in a configuration item tree; a collection
of configuration items and subsections.

IMPORTANT: there are some naming conventions for fields that apply to
all subclasses of this class. See Foswiki::Configure::Item for details.

=cut

use strict;
use warnings;

use Foswiki::Configure::Item ();
our @ISA = ('Foswiki::Configure::Item');

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

sub new {
    my ( $class, @opts ) = @_;

    my $this = $class->SUPER::new(
        children  => [],
        headline  => 'UNKNOWN',
        typename  => 'SECTION',
        _vobCache => {},          # Do not serialise
        @opts
    );

    return $this;
}

=begin TML

---++ ObjectMethod addChild($child)
Add a child node under this node.

=cut

sub addChild {
    my ( $this, $child ) = @_;
    foreach my $kid ( @{ $this->{children} } ) {
        die "Subnode already present; cannot add again" if $child eq $kid;
    }
    $child->{_parent} = $this;
    $child->{depth}   = $this->{depth} + 1;

    push( @{ $this->{children} }, $child );

    $this->_addToVobCache($child);
}

# The _vobCache provides fast access to value items
sub _addToVobCache {
    my ( $this, $child ) = @_;

    if ( $child->isa('Foswiki::Configure::Section') ) {
        while ( my ( $k, $v ) = each %{ $child->{_vobCache} } ) {
            $this->{_vobCache}->{$k} = $v;
        }
    }
    else {
        $this->{_vobCache}->{ $child->{keys} } = $child;
    }
    $this->{_parent}->_addToVobCache($child) if $this->{_parent};
}

# See Foswiki::Configure::Item
sub hasDeep {
    my ( $this, $attrname ) = @_;
    return 1 if $this->{$attrname};
    foreach my $kid ( @{ $this->{children} } ) {
        return 1 if $kid->hasDeep($attrname);
    }
    return 0;
}

# See Foswiki::Configure::Item
sub unparent {
    my $this = shift;

    if ( $this->{children} ) {
        foreach my $c ( @{ $this->{children} } ) {
            $c->unparent();
        }
    }
    $this->SUPER::unparent();
}

# See Foswiki::Configure::Item
sub prune {
    my ( $this, $depth ) = @_;

    if ( $depth == 0 ) {
        delete $this->{children};
    }
    elsif ( $this->{children} ) {
        foreach my $c ( @{ $this->{children} } ) {
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
    foreach my $child ( @{ $this->{children} } ) {
        if ( $visited{$child} ) {
            die join( ' ', @{ $this->{children} } );
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
    if ( $this->{headline} eq $head
        && ( !defined $depth || $this->{depth} == $depth ) )
    {
        return $this;
    }
    foreach my $child ( @{ $this->{children} } ) {
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
    return $this->{_vobCache}->{$keys};
}

# Implements Foswiki::Configure::Item
sub getAllValueKeys {
    my $this = shift;
    return keys %{ $this->{_vobCache} };
}

# Implements Foswiki::Configure::Item
sub promoteSetting {
    my ( $this, $setting ) = @_;
    my $on_me = 1;

    foreach my $child ( @{ $this->{children} } ) {
        $on_me = 0 unless $child->promoteSetting($setting);
    }

    if ($on_me) {
        $this->{$setting} = 1;
    }
    else {
        delete $this->{$setting};
    }

    return $this->{$setting};
}

# Implements Foswiki::Configure::Item
sub getPath {
    my $this = shift;

    my @path;
    @path = $this->{_parent}->getPath() if ( $this->{_parent} );
    push( @path, $this->{headline} ) if $this->{headline};

    return @path;
}

# Implements Foswiki::Configure::Item
sub search {
    my ( $this, $re ) = @_;

    my @result = ();
    push( @result, $this ) if $this->{headline} =~ m/$re/i;
    foreach my $child ( @{ $this->{children} } ) {
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

    return () unless $this->{children};

    # Search children
    my @result = ();
    foreach my $child ( @{ $this->{children} } ) {
        push( @result, $child->find(@_) );
    }

    return @result;
}

# Implements Foswiki::Configure::Item
sub find_also_dependencies {
    my ( $this, $root ) = @_;

    $root ||= $this;

    foreach my $kid ( @{ $this->{children} } ) {
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
