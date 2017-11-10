# See bottom of file for license and copyright information

package Foswiki::Config::CfgObject;

=begin TML

---+!! Role Foswiki::Config::CfgObject

This role is similar in nature to %PERLDOC{"Foswiki::AppObject"}%. But instead
of providing backlinking to the parent application object it backlinks to the
configuration object. The point is to support early stages of config life
cycle when application's =%PERLDOC{"Foswiki::App" attr="cfg" text="cfg"}%=
attribute is not set yet; or cases when a temporary/secondary config object
is needed which won't ever be stored in the application's attribute.

%X% *NOTE:* The case where the application's =cfg= attribute is not initialized
yet has to be carefully considered by a developer. Because it is a _lazy_ one
any attempt to read from it would cause a deep recursion case. So, if you by
any chance mangle with configuration or specs reading then remember to use
this role and =$this->cfg= notation.

---+++ Cloning

Upon cloning this role returns the value in =cfg= attribute as is.

=cut

require Foswiki::Object;

use Moo::Role;

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute cfg

Backlink to the parent configuration object.

=cut

has cfg => (
    is  => 'ro',
    isa => Foswiki::Object::isaCLASS( 'cfg', 'Foswiki::Config', noUndef => 1, ),
    weak_ref => 1,
    required => 1,
);

sub _clone_cfg {
    return $_[0]->cfg;
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
