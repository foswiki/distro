# See bottom of file for license and copyright information

package Foswiki::AppObject;
use v5.14;

=begin TML

---+ Role Foswiki::AppObject;

This role is for all classes which cannot be instantiated without active
=Foswiki::App= object.

---++ ObjectMethod create($className, @args) => $object

Method create() is imported from Foswiki::App class.

=cut

use Assert;

require Foswiki::Object;

use Moo::Role;

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute app

Modifies %PERLDOC{"Foswiki::Object" attr="app"} attribute, makes it required.

=cut

has app => (
    is        => 'rwp',
    predicate => 1,
    weak_ref  => 1,
    isa => Foswiki::Object::isaCLASS( 'app', 'Foswiki::App', noUndef => 1, ),
    clearer => 1,
);

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
