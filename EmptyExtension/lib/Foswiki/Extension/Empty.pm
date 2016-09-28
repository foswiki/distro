# See bottom of file for license and copyright information

package Foswiki::Extension::Empty;

=begin TML

---+ Class Foswiki::Extension::Empty

This is a template module demostrating basic functionality provided by %WIKITOOLNAME%
extensions framework.

__NOTE:__ This documention is yet incomplete for now and only focused on
documenting key parts of the new Extensions model.

=cut

use Foswiki::Class qw(extension);
extends qw(Foswiki::Extension);

=begin TML

---++ The Ecosystem

Extensions exists as a list of objects managed by =Foswiki::App= =extensions=
attribute which is actually an object of =Foswiki::Extensions= class. The latter
provides API for extension manipulation routines like loading and registering an
extension; registering extension's components like overriding methods or
classes; find an extenion object by name; etc.

An extension should be registered in =Foswiki::Extension= namespace. I.e. if we
create a =Sample= extension then its full name would be
=Foswiki::Extension::Sample=. Though this rule is not strictly imposed but it
comes in handy when one wants to refer to an extension by its short name. The
extension manager uses string stored in its =extPrefix= read only attribute to
form an extension full name; by default the attribute is initialized with
=Foswiki::Extension= string and there is no legal way to change it during
application's life cycle.

It is also mandatory for an extension class to subclass =Foswiki::Extension=.
The manager would reject a class registration if this rule is broken.

At any given moment of time there is only one active set of extensions
accessible via the application's =extensions= attribute. It means that if there
is a registered =Sample= extension then whenever we a ask for the extension's
object then we can be sure that there is no more than signle active one exists.
This is an important rule for some of [[#ExportedSubs][exported subroutines]].

=Foswiki::Extensions= module has its own =$VERSION= global var. It represents
%WIKITOOLNAME% API version and is used to check an extension compatibility.

---++ Starting a new extension module

Choose a name for an extension. Check if it's not alredy used. Start the module
with the following lines:

<verbatim>
package Foswiki::Extension::<your chosen name>;

use Foswiki::Class qw(extension);
extends qw(Foswiki::Extension);

use version 0.77; our $VERSION = version->declare(0.0.1);
our $API_VERSION = version->declare("2.99.0");
</verbatim>

=$API_VERSION= declares the minimal version of =Foswiki::Extensions= module
required.

=cut

use version 0.77; our $VERSION = version->declare(0.0.1);
our $API_VERSION = version->declare("2.99.0");

=begin TML

#ExportedSubs
---++ Foswiki::Class exported subroutines

Being used with =extension= parameter =Foswiki::Class= exports a set of
subroutines 

=cut

=begin TML

---++ SEE ALSO

=Foswiki::Extensions=, =Foswiki::Extension=, =Foswiki::Class=.

=cut

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
