# See bottom of file for license and copyright information

=begin TML

---+ Role Foswiki::Role::Parent

Implements parent role in parent/child object relationships.

=cut

package Foswiki::Role::Parent;
use v5.14;

use Assert;
use Scalar::Util qw(refaddr);

use Foswiki::Role -types;
roleInit;

=begin TML

---++ ObjectAttribute children

=cut

has children => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    assert    => Maybe [ ArrayRef [ ConsumerOf ['Foswiki::Role::Child'] ], ],
    default => sub { [] },
);
has _childIndex => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
    assert  => ArrayRef [ ConsumerOf ['Foswiki::Role::Child'] ],
);

=begin TML

---++ ObjectMethod createChild(%params) => $newObject

Creates a new child object and adds it to the children list. If role is applied
to a class which implements =create()= method then the latter is used instead of
=new()=.

=cut

sub createChild {
    my $this  = shift;
    my $class = shift;

    my $child;
    if ( $this->can('create') ) {
        $child = $this->create( $class, parent => $this, @_ );
    }
    else {
        $child = $class->new( parent => $this, @_ );
    }

    $this->addChild($child);

    return $child;
}

=begin TML

---++ ObjectMethod addChild($childObject) => \$index

Adds a new child to the list.

Returns it's index in the children list.

*Note* This index may change later as a side effect of execution of this class
methods.

=cut

sub addChild {
    my $this = shift;
    my ($child) = @_;

    $this->_validateChildObject($child);

    my $idx = $this->getChildIdx($child);
    unless ( defined $idx ) {
        $idx = push( @{ $this->children }, $child ) - 1;
        $child->parent($this);
    }
    return $idx;
}

=begin TML

---++ ObjectMethod delChild($child) => \$childObject

Deletes a child defined by =$child= which could either be a child object ref or
child index in the children list. Be careful with the latter as index is not
guaranteed to remain the same over the child object lifetime.

=cut

sub delChild {
    my $this = shift;
    my ($child) = @_;

    ASSERT( defined $child, "Child parameter is undef" );

    my $idx;
    if ( ref($child) ) {
        $this->_validateChildObject($child);
        $idx = $this->getChildIdx($child);
    }
    else {
        $idx = int($child);
        $this->_validateIdx($idx);
    }

    my $childObj = splice @{ $this->children }, $idx, 1;
    $childObj->clear_parent;
    return $childObj;
}

sub getChildIdx {
    my $this = shift;
    my ($child) = @_;

    ASSERT(
        defined($child)
          && ref($child)
          && UNIVERSAL::DOES( $child, 'Foswiki::Role::Child' ),
        "Child parameter is invalid"
    ) if DEBUG;

    my $refAddr = refaddr($child);
    return $this->_childIndex->{$refAddr} // undef;
}

sub _validateIdx {
    my $this = shift;
    my ($idx) = @_;

    # SMELL These expections better be replaced with more specific classes.
    Foswiki::Exception::Fatal->throw( text => "Child index parameter is undef" )
      unless defined $idx;
    Foswiki::Exception::Fatal->throw( text => "Child index is out of range" )
      unless $idx >= 0 && $idx <= $#{ $this->children };

    return $idx;
}

sub _validateChildObject {
    my $this = shift;
    my ($child) = @_;

    Foswiki::Exception::Fatal->throw(
        text => "Child object parameter is undef" )
      unless defined $child;
    Foswiki::Exception::Fatal->throw(
        text => "Child object doesn't do Foswiki::Role::Child role" )
      unless UNIVERSAL::DOES( $child, 'Foswiki::Role::Child' );
    Foswiki::Exception::Fatal->throw(
        text => "This object is not a child of me" )
      unless defined $this->_childIndex->{ refaddr($child) };
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
