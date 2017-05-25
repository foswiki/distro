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
attribute which is actually an object of =Foswiki::ExtManager= class. The latter
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

=Foswiki::ExtManager= module has its own =$VERSION= global var. It represents
%WIKITOOLNAME% API version and is used to check an extension compatibility.

---++ Extensions loading

Upon startup the extensions object created by the application scans a directory
(usually it is _$ENV{FOSWIKI_HOME}/lib/Foswiki/Extension_ but additional subdirs
can be defined by FOSWIKI_EXTLIBS environment variable) for =.pm= files and
tries to load them all in the order as returned by Perl =readdir()= function.

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

=$API_VERSION= declares the minimal version of =Foswiki::ExtManager= module
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

#ExtDeps
---+++ Extension dependencies

An extension can claim to be located before or after another one in the list of
extension objects (=extensions= attribute of =Foswiki::ExtManager= class). This defines
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
loaded and registered the graph gets sorted using topoligical sort. The resulting
order is stored in =Foswiki::ExtManager= =orderedList= attribute.

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

_NOTE:_ This behaviour is considered questionable and may change in the future.

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
macro then =Foswiki::ExtManager= =extObject()= method *must* be used to obtain
the reference.

=cut

tagHandler EMPTYMACRO => sub {
    my $this = shift;
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

callbackHandler 'Foswiki::App::handleRequestException', sub {
    my $this = shift;
    my ( $app, $params ) = @_;

    if ( $params->{exception}->isa('Foswiki::Exception::DoesntExists') ) {

        # Do something about this class of exceptions.
    }
};

=begin TML

#PluggableMethods
---+++ Method overriding

A core class may declare some of its methods as pluggable – i.e. let an
extension to have _before_, _around_, and _after_ handlers for the method –
similar (but not the same) to analogous functionality of [[CPAN:Moo][=Moo=]]
or [[CPAN:Moose][Moose]] but without subclassing of the core class. This feature
is provided by =plugBefore=, =plugAround=, and =plugAfter= subroutines
correspondingly.

To allow support for this feature by a core class it must add =extensible=
parameter to =use Foswiki::Class=. This will implicitly apply
=Foswiki::Aux::_ExtensibleRole= role to the class and export =pluggable=
subroutine to declare pluggable methods:

<verbatim>
package Foswiki::CoreClass;
use Foswiki::Class qw(extensible);
extends qw(Foswiki::Object);

...

pluggable someMethod => sub {
    my $this = shift;
    
    ...
};

1;
</verbatim>

---++++ Notes on implementation details

Method overriding can only work within properly initialized %WIKITOOLNAME%
application environment. I.e. it requires initialized extensions on application
object. On the other hand not only classes with =Foswiki::AppObject= role
applied can use this feature. This is because =Foswiki::Aux::_ExtensibleRole=
implicitly adds =__appObj= attribute to the class it is applied to. In
distinction of =Foswiki::AppObject= =app= attribute =__appObj= is not required
and can remain undefined.

For a non-<nop>=Foswiki::AppObject= class to allow the feature during runtime it
is mandatory to create objects of this class using =Foswiki::App= or
=Foswiki::AppObject= =create()= methods.

---++++ plugBefore, plugAround, plugAfter

In terms of =Moo= these subroutines are modifiers. But contrary to =Moo='s
implementation where, say, a _before_ modifier might not be called under cetain
conditions, all registered =plug*= modifiers are guaranteed to be executed
unless the execution flow gets interrupted by a modifier code. Those nuances
will be explained later in this documentation.

When a pluggable method is called the extensions framework first executes all
_before_ methods; then _around_ ones; then _after_. Within each group methods
are called using the order defined by =Foswiki::ExtManager= =orderedList=
attribute (see the [[#ExtDeps][dependecies section]]).

__NOTE:__ It is commonplace for _after_ methods to be called in reverse order.
But =plugAfter= order is straight, same as for =plugBefore= and =plugAround=.
This is a subject for discussion and is very likely to change in the future.

Contrary to =Moo='s modifiers, methods registered with =plug*= modifiers are all
executed as _extenion_ methods, not as methods of an object of a core class. The
object is passed as a key =object= of parameters hashref in the second argument.
All keys of the hashref are in the followin table:

| *Key* | *Type* | *Description* |
| =object= | blessed ref | The object the method is being called upon. |
| =class= | string | The class which has registered the pluggable method. Might be different from the above object's class if object was created using a subclass. |
| =method= | string | Name of the pluggable method registered by the class above. Could be useful for cases when same extension method is used to handle few different pluggable methods. |
| =stage= | string | _before_, _around_, or _after_. |
| =args= | array ref | Reference to arguments array =@_= passed to the pluggable method. The array content can be changed by extension methods but the ref itself has to be left untouched. If a method changes it the extensions framework will restore the original value discarding all changes done by the method. Because this key points to =@_= then modification of =$n='th element has the same effect as modification of =$_[$n]=. |
| =wantarray= | scalar | =wantarray= function value for the pluggable method. |
| =rc= | anything | Pluggable method's return value. The original pluggable method won't be executed if any of _around_ methods sets this key to whatever (including =undef=) value. It's not allowed to be set by a _before_ method; if set then the framework will clean it up. |

Methods can use the parameters hashref to communicate to each other by storing
necessary information in it using unique key names. Generally it is recommended
for an extension to take measures as to avoid clashing with other extensions.
Though not being the most handy but the most reliable method would be to use
extension's name as the key where all extension-specific data is stored.

---++++ Execution flow control

A method can have influence over the execution flow by raising
=Foswiki::Exception::Ext::Last= or =Foswiki::Exception::Ext::Restart=
exceptions.

=Last= will stop the current group execution and pass the control over to the
ext group. I.e. if raised for _before_ chain then _around_ will be started; for
_around_ it'll be _after_. And for _after_ it will return to the calling code.
If the exception was supplied with =rc= parameter:

<verbatim>
Foswiki::Exception::Ext::Last->throw( rc => 0, );
</verbatim>

the parameter will be used to set the =rc= key of method parameters hash. Same
rules about the _before_ methods and =rc= apply.

=Restart= exception signals the extensions framework to interrupt the current
flow and start it again. The method parameters hash is then left in the same
state it was on the moment when exception was raised. This feature must be used
with great care as it may have unpredictable side effects.

=cut

plugBefore 'Foswiki::CoreClass::someMethod' => sub {
    my $this = shift;
    my ($params) = @_;

    # Pass some information to other methods.
    $params->{__PACKAGE__}{myFlag} = rand() < 0.5 ? "don't!" : "do it!";
};

plugAround 'Foswiki::CoreClass::someMethod' => sub {
    my $this = shift;
    my ($params) = @_;

    if ( $params->{__PACKAGE__}{myFlag} =~ /do it/ ) {
        Foswiki::Exception::Ext::Last->throw(
            rc => 'Hello from extension Empty!', );
    }
    else {
        $params->{args}[0] = 'modified argument';
    }
};

plugAfter 'Foswiki::CoreClass::someMethod' => sub {
    my $this = shift;
    my ($params) = @_;

    if ( $params->{rc} =~ /Hello.*Empty/ ) {
        $params->{rc} = length( $params->{rc} );
    }
};

=begin TML

---+++ Subclassing

An extension can request to subclass a core class by using =extClass=
subroutine. This is perhaps the most powerful feature of the extensions
framework. Consider the following line of code:

<verbatim>
extClass 'Foswiki::Config' => 'Foswiki::Extension::Empty::DBConfig';
</verbatim>

Every time the =create()= method is request to create an object of some class it
first consults the extensions framework if there is a subclass registered for
it. And if there is one it is used instead of the original.

Subclasses are created by the framework using the registrations from extensions.
Because it is possible for more than one extension to register a subclass for
the same core class the order of inheritance cannot be determined at the moment
of registration. For this reason all extensions are first loaded into memory and
then the framework analyses them and builds subclasses for every extension
registered core class.

Due to the way =Moo= works a registered subclass module in fact must be a
=Moo::Role=. What the framework actually does then it creates a new class with
all registered subclasses being applied as roles in the order reverse to
=orderedList= attribute defined (think of the way inherited methods are called).
See
[[CPAN:Role::Tiny#create_class_with_roles][Role::Tiny::create_class_with_roles
method]]. The core class is used as the base.

What could be done using this feature is limited by once imagination only.
=Foswiki::Extension::Empty::DBConfig= is used as an example subclass to give an
idea of storing the =LocalSite.cfg= in a database of some kind. While rewriting
the core class might be much of a burden somebody can simple create an extension
and implement this functionality. All an administrator of a wiki would have to
do then is to install the extension. And - voilà! – his configuration can now be
shared across multpile installations or even help to clusterize the setup. If
same extensions creator would then decide to implement a =Foswiki::Store= with
database support then it's one more step close to scalable %WIKITOOLNAME%.

See =UnitTestContrib/test/unit/TestExtensions/Foswiki/Extension/Sample/Config.pm=
for an example of subclassing. Or test_subClassing= in =ExtensionsTests= test
suite.

=cut

#extClass 'Foswiki::Config' => 'Foswiki::Extension::Empty::DBConfig';

=begin TML


---++ SEE ALSO

=Foswiki::ExtManager=, =Foswiki::Extension=, =Foswiki::Class=, and
=ExtensionsTests= test suite.

Check out [[Foswiki:Development.OONewPluginModel][Foswiki topic]] where all this
once originated from.

=cut

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016-2017 Foswiki Contributors. Foswiki Contributors
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
