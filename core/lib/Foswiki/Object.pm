
package Foswiki::Object;

=begin TML

---+ package Foswiki::Object

*NOTE:* This document is in draft status and may change as a result of
a discussion, raised concerns or reasonable proposals.

This is the base object for all Foswiki classes. It defines the default
behaviour and general policies for all descendants.

---++ Behavior

=Foswiki::Object= main goals are to create and destroy objects properly and
to unify some very basic object interfaces like property management, for
instance.

---+++ Syntax sugar

Unlike any OO toolkit =Foswiki::Object= is not introducing special
constructs only to make it look good and behave like "in that other
language". It's not a big deal to stick to ye olde good Perl 5 way. Though
if something would make life easier without big performance penalty then
why resisting to implement it?

This is why after considering that:

   a. to be correctly managed and cleaned properties have to be somehow
      registered
   a. they have never be accessed directly but by calling a correspoding
      object method only

it was decided that implementing a semi-keyword =has= would be rather for
good than for bad. No typification, no other hidden magic staff. Simple
support for read/write modificator and default value:

<verbatim>
package Foswiki;
use Foswiki::Object;
our @ISA=qw( Foswiki::Object );
has session => 'ro';
has somePropery => rw => 'Default';
</verbatim>

Possible extension by means of additional key/value attribute pairs is
considered.  Could be used to define a validator. For example:

<verbatim>
has wikiName => rw => 'DefaultUser', validate => \&_validateWikiName;
has count => rw => 0, validate => qr/^\d+$/;
</verbatim>

What =has= does is it generates 2 or 3 object methods:

   * public method =someProperty()=
   * private methods =_getSomeProperty()= and =_setSomeProperty()= unless
     they're predefined by class module.
   * records information about the property in =%Class::_CLASS= hash.

By predefining the =_get= and/or =_set= methods a class can have full
control over a property management and even create fully virtual
properties.

Overriding of the public method is considered senseless and is not
recommended though not prohibited either. 

---+++ Initialization

None of deriving classes shall have method =new()=. It's the prerogative of
=Foswiki::Object= to have it. There is no reason to override it. Seriously.
If there is one to do so – think twice and find a way to get around. If no
ideas come out then something has to be changed in =Foswiki::Object= code.

What =new()= does is:

   * blessing a hash in object class
   * preparing object parameters
   * initializing the new object with these parameters

---++++ Validating and adjusting object parameters.

Upon blessing a new-born object the =new()= method initiates a process of
sanitizing of parameters passed to the object before they actually end up
in corresponding properties, or influence the object initialization
process, or in any other way have impact over the object's life.

As a part of unification efforts the [[#InitMethod][=_init()=]] object
method receives it's parameters in =key => value= pairs. But for backward
compatibility and for other developers convenience some of =new()= methods
are allowed to get their parameters in positional form. Mapping of latter
into former is done by =_mapObjectParameters()= method or automatically by
=Foswiki::Object= itself if the list of parameter names has been passed
over in =use= arguments:

<verbatim>
use Foswiki::Object qw( postionalParameter1 positionalParameter2 theLastOne );
</verbatim>

The resulting parameters hash is been passed over to
=_checkObjectParameters()= method which in turn must do preliminary
validation of parameter values and set those missing to their default
values. Presetting to defaults would mostly be done by =Foswiki::Object=
itself and shall not be of descendant business unless there is some
specific about a particular parameter. Yet, if the property validators are
to be considered as the way to go then =Foswiki::Object= might take care of
this task too.

---++++ Initializing object

The resulting hash of parameters then gets passed over to object method
=_init()=. This is where descendant code would do most of its job of
preparing the new object. Though the task of setting properties values
could still be done by =Foswiki::Object= if no special care needs to be
taken about them and calling corresponding =_set= method is enough.

---+++ Destruction

When object finishes it's life cycle =Foswiki::Object= takes care of
cleaning it up. First of all, =_finish()= or =finish()= methods are called.
Actually it is uncertain if this method has any value as a public one. More
like it's better be kept private. But this is to be considered. What is
more important is not to forget to call =SUPER::_finish()=.

Then all properties not wiped out by descendat's =_finish()= method are
deleted.

To be considered another keyword which would enumerate additional object
keys/properties to be taken care of by the destructor. For example, it may
look like this:

<verbatim>
cleanup qw( web topic remoteUser context etc );
</verbatim>

It won't add much except making it easier to locate and check this list.

---+++ Internal magic notes.

As syntax sugar functionality relies upon =import()= sub being run during
early module load it's better to avoid any use of this sub in a descendant
class module. Instead =Foswiki::Object= would call =_class_import()= sub
for you.

=cut

use strict;
use warnings;
use Assert;

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors
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
