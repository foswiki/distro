# See bottom of file for license and copyright information

package Foswiki::Config::Node;

use Assert;
use Foswiki::Exception;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);

use constant DATAHASH_CLASS => 'Foswiki::Config::DataHash';

# Value could be anything.
has value => (
    is        => 'rw',
    predicate => 1,
    lazy      => 1,
    clearer   => 1,
    builder   => 'prepareValue',
    trigger   => 1,
);

has parent => (
    is       => 'rw',
    weak_ref => 1,
    builer   => 'prepareParent',
    (
        DEBUG
        ? ( isa => Foswiki::Object::isaCLASS( 'parent', DATAHASH_CLASS ) )
        : ()
    ),
    handles => [qw(fullPath fullName)],
);

has section => (
    is       => 'rw',
    weak_ref => 1,
    builder  => 'prepareSection',
    isa => Foswiki::Object::isaCLASS( 'section', 'Foswiki::Config::Section', ),
);

# Defines if node is temrinal.
has isLeaf => ( is => 'rw', );

stubMethods qw(prepareParent prepareSection prepareValue);

sub isBranch {
    my $this = shift;
    return defined $this->isLeaf && !$this->isLeaf;
}

sub isVague {
    my $this = shift;
    return !defined $this->isLeaf;
}

sub _trigger_value {
    my $this = shift;
    my $val  = shift;

    if ( defined $this->isLeaf ) {

        my $tiedVal =
          ref($val) eq 'HASH' && UNIVERSAL::isa( tied(%$val), DATAHASH_CLASS );

        # SMELL Replace with more appropriate exception, similar to
        # Foswiki::Exception::Config::BadSpecData.
        Foswiki::Exception::Config::BadSpecValue->throw(
            text => "Only hashes tied to "
              . DATAHASH_CLASS
              . " can be assigned to non-leaf keys",
            specObject => $this,
        ) if !$this->isLeaf && !$tiedVal;

        Foswiki::Exception::Config::BadSpecValue->throw(
            text => "Attempt to assign hash tied to "
              . DATAHASH_CLASS
              . " to a leaf key",
            specObject => $this,
        ) if $this->isLeaf && $tiedVal;
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
