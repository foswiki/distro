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

#SingleExtSet
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
subroutines to simplify and improve readibility of some of extensions
functionality. As such, their use is similar to =CPAN:Moo=
[[https://metacpan.org/pod/Moo#IMPORTED-SUBROUTINES][subroutines]].

---+++ Extension dependencies

An extension can claim to be located before or after another one in the list of
extension objects (=extensions= attribute of =Foswiki::Extensions= class). This defines
inheritance and callback execution order. I.e., if =Ext2= goes after =Ext1= and
both register a callback handler for =Foswiki::App::postConfig= then =Ext1= handler
will be called first.

This doesn't apply to registered macros because there could only be single handler for
a macro.

The following subs implement this functionality:

| *Sub name* | *Description* |
| =extBefore @nameList= | Extension must be placed before extensions in =@nameList= |
| =extAfter @nameList= | Extension must be placed after extensions in =@nameList= |

What these do is define a directed graph of extensions. When all extensions are
loaded and registered the graph gets sorted using topoligical sort.

The final order of extensions is not guaranteed. For example, =Ext2= could
require to be placed before =Ext1= but it doesn't mean that it will directly
preceed it in the list as other extensions could be inserted between them. A
typical example of such behaviour would be =Ext1= requiring to be placed after
=Ext3=. Besides, nothing is guaranteed about single extensions not requiring any
specific order. They can be inserted anywhere in the list. Same apply to two or
more subsets of extensions not bound to each other with directional relations.

If the graph happens not to be acyclic and we find a circular dependency then
all extensions involved into the chain are getting disabled. For example, if the
chain looks like the following example:

Ext1 %M% Ext2 %M% Ext3 %M% Ext4 %M% Ext5 %M% Ext3

then not only =Ext[3,4,5]= are disabled but =Ext1= and =Ext2= too.

This behaviour is considered questionable and may change later.

=cut

#extBefore qw(Ext1 Ext2);
#extAfter qw(Foswiki::Extension::Ext3);

=begin TML

---+++ Custom macros

Custom macros are declared using =tagHandler= subroutine. It accepts two parameters:
the first is the macro name; the second is either a coderef or a class name. For coderef
a method named after the macro is generated for extension's class. I.e.:

<verbatim>
package Foswiki::Extension::Ext;

...

tagHandler MYMACRO => sub {
    my $this = shift;
    my ($attrs, $topicObject, @macroArgs) = @_;
    ...
};
</verbatim>

would generate a method named =MYMACRO= in =Foswiki::Extension::Ext= class.

For cases when the second parameter is a class name:

<verbatim>
...

tagHandler MYMACRO => 'Foswiki::Extension::Macro::MYMACRO';
</verbatim>

it is expected that the class would does =Foswiki::Macro= role. An object of
this class will be created on demand by =Foswiki::Macros=. It won't get any
reference to the extension object. Would the object be needed to expand the
macro then =Foswiki::Extensions= =extObject()= method *must* be used to obtain
the reference.

=cut

tagHandler EMPTYMACRO => sub {
    my $this = shfit;
    return __PACKAGE__ . " version is " . $VERSION;
};

=begin TML

---+++ Callbacks

Callbacks are here to replace the old *Handler mechanism. They're developed as
more powerful, flexible, and OO-friendly replacement.

Extension can install a callback handler using =callbackHandler= subroutine. It
receives two parameters: a callback name and a coderef:

<verbatim>
callbackHandler postConfig => sub {
    my $this = shift;
    my ($obj, $params) = @_;
    
    ...
};
</verbatim>

The coderef acts as an extension's method. The method gets reference to the
object which actually initiated this callback; and reference to a hash with
parameters supplied by the object – see =params= key of callback arguments in
=Foswiki::Aux::Callbacks=.

__NOTE:__ The method arguments are different from common callback handler as
described in =Foswiki::Aux::Callbacks= because there is no point of passing the
=data= key of arguments hash. Instead extension callback method can rely on
object's internals whenever needed.

See =Foswiki::Aux::Callbacks=

=cut

callbackHandler postConfig => sub {
    my $this = shift;
    my ($app) =
      @_;    # Foswiki::App::postConfig callback doesn't supply any params.
};

callbackHandler 'Foswiki::App::handleRequestException' => sub {
    my $this = shift;
    my ( $app, $params ) = @_;

    if ( $params->{exception}->isa('Foswiki::Exception::DoesntExists') ) {

        # Do something about this class of exceptions.
    }
};

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
