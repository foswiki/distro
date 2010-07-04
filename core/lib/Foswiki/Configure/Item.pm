# See bottom of file for license and copyright information

=begin TML

---++ package Foswiki::Configure::Item

Abstract base class of all configuration components. A configuration
component may be a collection item (a ConfigSection), an individual Value,
or a checker associated with a value (or a node in a checker tree).

Objects of this class are intended to form a tree with references in
both directions, circular references ahead.  But configure isn't
supposed to be run in a persistent environment anyway.

=cut

package Foswiki::Configure::Item;

use strict;
use warnings;
use Carp;

sub new {
    my $class = shift;

    my $this = bless( {}, $class );
    $this->{parent}   = undef;
    $this->{desc}     = '';
    $this->{errors}   = 0;
    $this->{warnings} = 0;

    return $this;
}

=begin TML

---++ ObjectMethod getDepth() -> $integer

Get the depth of the item in the item tree, where the root is at depth 0,
it's children at depth 1, etc.

=cut

sub getDepth {
    my $depth = 0;
    my $mum   = shift;

    while ($mum) {
        $depth++;
        $mum = $mum->{parent};
    }
    return $depth;
}

=begin TML

---++ ObjectMethod addToDesc($str)

Concatenate $str to the description of this item.

=cut

sub addToDesc {
    my ( $this, $desc ) = @_;

    $this->{desc} .= "$desc\n";
}

=begin TML

---++ ObjectMethod isExpertsOnly() -> $boolean

Is the item tagged EXPERT?

By default, no node is expert.

=cut

sub isExpertsOnly {
    return 0;
}

=begin TML

---++ ObjectMethod set(%params)

Accept an attribute setting for this item (e.g. a key name).
Sort of a generic write accessor.

=cut

sub set {
    my ( $this, %params ) = @_;
    foreach my $k ( keys %params ) {
        $this->{$k} = $params{$k};
    }
}

=begin TML

---++ ObjectMethod inc($key)

Increment a numeric value identified by $key, recursing up the tree to the
root.

Assumptions
   * All item levels have $key defined and initialized
   * Parents of items are items (or more precisely: can inc())

This is used for counting the numbers of warnings, errors etc found in
subtrees of the configuration structure.

=cut

sub inc {
    my ( $this, $key ) = @_;

    $this->{$key}++;
    $this->{parent}->inc($key) if $this->{parent};
}

=begin TML

---++ ObjectMethod getSectionObject($head, $depth) -> $item

This gets the section object that has the heading $head and
getDepth() == $depth below this item.

Subclasses must provide an implementation.

=cut

sub getSectionObject {
    Carp::confess 'Subclasses must define this method';
}

=begin TML

---++ ObjectMethod getValueObject($keys) -> $value
Get the first Value object associated with this item. The default
implementation is the tree node implementation; it just queries
children. Keys are only present on leaf items.

Subclasses must define this method.

=cut

sub getValueObject {
    Carp::confess 'Subclasses must define this method';
}

=begin TML

---++ ObjectMethod needsSaving() -> $integer
Return the number of items in this subtree that need saving.

The default implementation always returns 0

=cut

sub needsSaving {
    return 0;
}

=begin TML

---++ ObjectMethod visit($visitor) -> $boolean
Start a visit over this item.
   * $visitor - an object that implements Foswiki::Configure::Visitor

The default implementation just visits this item, and returns 1 if
both the startVisit and the endVisit returned true.

=cut

sub visit {
    my ( $this, $visitor ) = @_;
    return 0 unless $visitor->startVisit($this);
    return 0 unless $visitor->endVisit($this);
    return 1;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
