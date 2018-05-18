# See bottom of file for license and copyright information

=begin TML

---+ Role Foswiki::Role::Child

Implements child role in parent/child object relationships.

=cut

package Foswiki::Role::Child;

use Assert;

use Foswiki::Role -types;
roleInit;

=begin TML

---++ ObjectMethod parent

Contains a Foswiki::Object which is the parent of this object and does
Foswiki::Role::Parent role.

A callback method =_trigger_parent($newParent)= will be called when this
attribute is set to a new value. The default behaviour is to add this object to
the new parent's chlid list.

*Note* This attribute is a weak ref.

=cut 

has parent => (
    is        => 'rw',
    clearer   => 1,
    predicate => 1,
    weak_ref  => 1,
    assert    => AllOf [ InstanceOf ['Foswiki::Object'],
        ConsumerOf ['Foswiki::Role::Parent'] ],
    trigger => 1,
);

sub _trigger_parent {
    my $this = shift;
    my ($parent) = @_;

    # Check if we're already recorded on the parent to avoid redundant
    # processing.
    unless ( defined $parent->getChildIdx($this) ) {
        $parent->addChild($this);
    }
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
