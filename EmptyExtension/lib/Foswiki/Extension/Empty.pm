# See bottom of file for license and copyright information

package Foswiki::Extension::Empty;

=begin TML

---+!! Class Foswiki::Extension::Empty

This is a template module demostrating basic functionality provided by %WIKITOOLNAME%
extensions framework.

%X% *NOTE:* This document is incomplete for the moment and only focuses on
details directly influencing a new extension development.

=cut

use Foswiki::FeatureSet;

use Foswiki::Class qw(extension);
extends qw(Foswiki::Extension);

=begin TML

---++ The Ecosystem

Extensions exist as a list of objects managed by
=%PERLDOC{"Foswiki::App" attr="extMgr"}%= attribute which is an instance of
=%PERLDOC{Foswiki::ExtManager}%= class. The latter provides API for extension
manipulation routines like loading and registering an extension; registering
extension's components; find an extenion object by name; etc.

An extension should be registered in =Foswiki::Extension::= namespace. I.e. if
we create a =Sample= extension then its full name would be
=Foswiki::Extension::Sample=. Though this rule is not strictly imposed but it
comes in handy when one wants to refer to an extension by its short name. The
manager uses string stored in its
=%PERLDOC{"Foswiki::ExtManager" attr="extPrefix" text="extPrefix"}%= read only
attribute to form an extension's full name; by default the attribute is
initialized with _'Foswiki::Extension'_ string and there is no legal way to
change it in a course of application's life cycle.

It is also mandatory for an extension class to subclass =Foswiki::Extension=.
The manager would refuse registration if this rule is broken.

#SingleExtSet
At any given moment of time there is only one active set of extensions
accessible via an application's =extMgr= attribute. It means that if the
=Sample= extension is registered then whenever we query for its object it is
guaranteed that there is no more than signle active one exists per application.
This rule is important for some of
[[?%QUERYSTRING%#ExportedSubs][exported subroutines]].

=Foswiki::ExtManager= module has its own =$VERSION= global var. It represents
%WIKITOOLNAME% API version and is used to check for extension compatibility.

---++ Loading

Upon startup the extension manager scans a directory (usually it is
_$ENV{FOSWIKI_HOME}/lib/Foswiki/Extension_ (additional subdirs can be defined -
see %PERLDOC{Foswiki::ExtManager}%) for =.pm= files and tries to load them all
in the order as returned by Perl =readdir()= function.

More information could be found in =Foswiki::ExtManager= documentation.

---++ Starting a new extension module

Choose a name for an extension. Check if it's not alredy used. Start the module
with the following lines:

<verbatim>
package Foswiki::Extension::<your chosen name>;

use Foswiki::Class qw(extension);
extends qw(Foswiki::Extension);

use version 0.77; our $VERSION = version->declare(0.0.1);
our $API_VERSION = version->declare("2.99.0");
our @FS_REQUIRED = qw<MOO UNICODE OOSPECS>;
</verbatim>

Even though =$API_VERSION= in the example won't be used becuase of
=@FS_REQUIRED= (see =%PERLDOC{"Foswiki::ExtManager" section="API
Compatibility"}%=), but it would be courteous to provide it for the code
readers.

=cut

use version 0.77; our $VERSION = version->declare(0.0.1);
our $API_VERSION = version->declare("2.99.0");
our $NAME        = "Empty";

features_provided
  -namespace      => "Ext::Empty",
  EXAMPLE_FEATURE => [
    2.99, undef, undef,
    -desc => "Example of a feature declaration by an extension",
    -doc  => "%PERLDOC{\"Foswiki::Extension::Empty\"}%",
  ],
  ;

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

These define a directed graph of extensions. When all extensions are
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
=Foswiki::Util::Callbacks=.

%X% *NOTE:* The method arguments are different from common callback handler as
described in =%PERLDOC{Foswiki::Util::Callbacks}%= because there is no point of
passing the =data= key of arguments hash. Instead extension callback method can
rely on object's internals whenever needed.
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
=Foswiki::Util::_ExtensibleRole= role to the class and export =pluggable=
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

---++++ Implementation Details

Method overriding can only work within properly initialized %WIKITOOLNAME%
application environment. I.e. it requires initialized extensions on application
object. On the other hand not only classes with =%PERLDOC{Foswiki::AppObject}%=
role applied can use this feature. This is because
=Foswiki::Util::_ExtensibleRole= implicitly adds =__appObj= attribute to the
class it is applied to. In distinction to =%PERLDOC{"Foswiki::AppObject"
attr="app"}%= attribute =__appObj= is not required and can remain undefined.

For a non =Foswiki::AppObject= class to get the feature enabled it is mandatory
to have objects of the class created with =%PERLDOC{"Foswiki::App"
method="create"}%= or =%PERLDOC{"Foswiki::AppObject" method="create"}%= methods.
For example (consider the above sample and assume that the code below belongs
to a class with =Foswiki::AppObject= role):

<verbatim>
plugBefore "Foswiki::CoreClass::someMethod" => sub {
    my $this = shift;
    my ($params) = @_;
    my $num = $params->{args}->[0];
    
    say "This is obj", $num;
};

...

sub testPlugBefore {
    my $this = shift;
    
    my $obj1 = $this->app->create("Foswiki::CoreClass");
    my $obj2 = $this->create("Foswiki::CoreClass");
    my $obj3 = Foswiki::CoreClass->new;
    
    $obj1->someMethod(1);
    $obj2->someMethod(2);
    $obj3->someMethod(3);
}
</verbatim>

This would output:

<verbatim>
This is obj1
This is obj2
</verbatim>

because =$obj3= knowns nothing about the application and correspondingly about
the extensions.

---++++ plugBefore, plugAround, plugAfter

In terms of =CPAN:Moo= these subroutines are modifiers. All registered =plug*=
modifiers are guaranteed to be executed unless the
[[ChainedExecutionFlow][execution flow]] gets interrupted.

When a pluggable method is called the extensions framework first executes all
_before_ methods; then _around_ ones and then possibly the original method; then
_after_. Within each group methods are called using the order defined by
=%PERLDOC{"Foswiki::ExtManager" attr="orderedList"}%= attribute (see the
[[#ExtDeps][dependecies section]]).

%X% *NOTE:* It is commonplace for _after_ methods to be called in reverse order.
But =plugAfter= order is straight, same as for =plugBefore= and =plugAround=.
This is a subject for discussion and is very likely to change in the future.

Contrary to =Moo= modifiers, methods registered with =plug*= modifiers are all
executed as _extenion object_ methods, not as methods of the object to which the
pluggable method belongs. I.e. their first argument =$this= points to the
extension object. The pluggable method's object is passed as key =object= of
parameters hashref in the second argument.

Keys of the parameters hash are:

| *Key* | *Type* | *Description* |
| =object= | blessed ref | The object the pluggable method is being called upon. |
| =class= | string | The class which has registered the pluggable method. \
   Might be different from the object's class if it was created with a \
   subclass. |
| =method= | string | Name of the pluggable method registered by the class \
   above. Could be useful for cases when same extension method is used to \
   handle few different pluggable methods. |
| =stage= | string | _before_, _around_, or _after_. |
| =args= | array ref | Reference to arguments array =@_= passed to the \
   pluggable method. The array content can be changed by extension methods but \
   the ref itself has to be left intact. If a method changes it the \
   extensions framework will restore the original reference discarding any \
   changes done by the modifier. Because the key points to =@_= then \
   modification of its =$n'th= element has the same effect as modification of \
   =$_[$n]=. |
| =wantarray= | scalar | =wantarray= for the pluggable method. |
| =rc= | anything | Pluggable method's return value. The original pluggable \
   method won't be executed if any of the _around_ modifiers sets this key to \
   whatever (including =undef=) value. It's not allowed to be set by a \
   _before_ method; if set then the framework would clean it up. |

Methods can use the parameters hashref to communicate to each other by storing
necessary information in it using unique key names. Generally it is recommended
for an extension to take measures as to avoid clashing with other extensions.
Though not being the most handy but the most reliable method would be to use
extension's name as the key where all extension-specific data is stored:

<verbatim>
plugAround 'Foswiki::CoreClass::someMethod' => sub {
    my $this = shift;
    my ($params) = @_;
    
    $params->{'Ext::MyExtension'}{sayIt} = "Hi from around!";
};

plugAfter 'Foswiki::CoreClass::someMethod' => sub {
    my $this = shift;
    my ($params) = @_;
    
    say "Around sent me this: ", $params->{'Ext::CoreClass'}{sayIt}
        if defined $params->{'Ext::CoreClass'}{sayIt};
};
</verbatim>

Note that it is ok to use same naming convention as for
%PERLDOC{"Foswiki::FeatureSet" section="Namespaces"}% namespaces.

---++++ Execution flow control

Read about general info about [[ChainedExecutionFlow][chained calls]] first.

A method can have influence over the execution flow by raising
=Foswiki::Exception::Ext::Last= or =Foswiki::Exception::Ext::Restart=
exceptions.

=Last= stops the current group execution and pass the control over to the
next group. I.e. if raised for _before_ chain then _around_ will be started; for
_around_ it'd be _after_. And for _after_ it will return to the calling code.
If the exception raised with =rc= parameter:

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
extClass 'Foswiki::Config' => 'Foswiki::Extension::Empty::Config';
</verbatim>

Every time =%PERLDOC{"Foswiki::App" method="create"}%= method is requested to
create an object of some class it first consults the extensions framework if
there is a subclass registered for it. And if there is one it is used instead of
the original.

Subclasses are created by the framework using the registrations from extensions.
Read more on how it works in
%PERLDOC{"Foswiki::ExtManager" section="Subclassing"}%. The only thing to
mention is that a registered =extClass= must be a [[CPAN:Moo::Role][role]]:

<verbatim>
package Foswiki::Extension::Empty::Config;

use Moo::Role;

around readConfig => sub {
    my $this = shift;
    
    say STDERR "Hey, this method must not be used anymore!";
    
    Foswiki::Exception::Ext::Last->throw(
        rc => 0, # Indicate that LSC cannot be loaded.    
    );
};

1;
</verbatim>

The sample class would intercept calls to deprecated
%PERLDOC{"Foswiki::Config" method="readConfig"}% method and make them fail by
returning _false_ value to the calling code making it think that config read
has failed.

What could be done using this feature is limited by once imagination only.
Imagine a =Foswiki::Store= implementation with database support - it would be
one more step closer to scalable %WIKITOOLNAME% run on multiple servers. And
this could be done without rewriting the core, just by installing an extension!

Check out
=UnitTestContrib/test/unit/TestExtensions/Foswiki/Extension/Sample/Config.pm=
for an example of subclassing. Or =test_subClassing= in =ExtensionsTests= test
suite.

=cut

#extClass 'Foswiki::Config' => 'Foswiki::Extension::Empty::DBConfig';

=begin TML


---++ Related

=%PERLDOC{Foswiki::ExtManager}%=, =%PERLDOC{Foswiki::Extension}%=,
=%PERLDOC{Foswiki::Class}%=, =ExtensionsTests= test suite.

Check out [[Foswiki:Development.OONewPluginModel][Foswiki proposal topic]] too.

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
