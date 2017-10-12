# See bottom of file for license and copyright information

package Foswiki::Class;
use v5.14;

use strict;
use warnings;

=begin TML

---+ Package Foswiki::Class

This wrapper package for Moo intended to be used as a replacement and a shortcut
for a bunch of code like:

<verbatim>
use v5.14;
use Moo;
use namespace::clean;
extends qw<Foswiki::Object>;
with qw<Foswiki::AppObject>;
</verbatim>

The above could be replaced with a single line of:

<verbatim>
use Foswiki::Class qw(app);
extends qw<Foswiki::Object>;
</verbatim>

---++ Usage

The basic functionality of this module is to:

   1. Apply =:5.14= feature set (as if =use v5.14;= clause is used)
   1. Apply =strict= and =warnings= features.
   1. Clean name space with =[[CPAN:namespace::clean][namespace::clean]]=
   1. Apply =[[CPAN:Moo][Moo]]=.

Every class built with this module help can have a set of modifiers applied.
Each modifier has some specific effect upon the class by either changing its
properties or exporting features. Modifiers are declared by passing parameter
keywords to the module's =init()= method with =use= clause. In the example above
a class is requesting =app= modifier to be applied.

In particular, a modifier might do one or few of the following:

   * Apply a role to the class
   * Export one or more public method ("keywords") to the class namespace (similar to =[[https://metacpan.org/pod/Moo#PUBLIC-METHODS][Moo public methods]]=)
   * Define active feature set (see below)

There is a special modifier beginning with a colon and followed with version
string which declares what feature set the class wants to be used. By default
=:5.14= is charge (see
[[http://perldoc.perl.org/feature.html#FEATURE-BUNDLES][feature bundles]]).

---++ Terminology

*Public method* or *keyword* – a prototyped subroutine exported into class'
namespace. Usually it looks and acts as a Perl keyword:

<verbatim>
pluggable someMethod => sub {
    ...  
};
</verbatim>

Read about =extensible= modifier to find out what =pluggable= keyword does.

---++ Modifiers

The following modifiers are support by this module:

| *Parameter* | *Description* |
| =app= | Class will have =Foswiki::AppObject= role applied. |
| =callbacks= | Provide support for callbacks |
| =extension= | Declares class to be an extension. See =Foswiki::Extenion::Empty= for more information. |
| =extensible= | Makes class an extensible. |
| =:5.XX= | A string prefixed with colon is treated as a feature bundle name and passed over to the =feature= module as is. This allows to override the ':5.14' default. |

See below for more details on each modifier.

A class may have few modifiers applied at once:

<verbatim>
use Foswiki::Class qw(app extensible);
</verbatim>

---+++ app

See =Foswiki::AppObject= role which is applied to class with this modifier. 

---+++ callbacks

A class with this modifier wants to get callbacks support. This is done by:

   1. applying =Foswiki::Util::Callbacks= role
   1. exporting =callback_names= public method.

a subroutine =callback_names= is exported into a class' namespace and
=Foswiki::Util::Callbacks= role gets applied. =callback_names= accepts a list
and registers names from the list as callbacks supported by the class.

For example:

<verbatim>
package Foswiki::SomeClass;

use Foswiki::Class qw(app callbacks);

callback_names qw(callback1 callback2);

sub someMethod {
    my $this = shift;
    
    $this->callback('callback1', $cbParams);
}
</verbatim>

Here we get two callbacks registered: =Foswiki::SomeClass::callback1= and
=Foswiki::SomeClass::callback2=.

See =Foswiki::Util::Callbacks=.

---+++ extension

Extension support is provided by exporting subroutines =callbackHandler,
extBefore, extAfter, extClass, plugBefore, plugAround, plugAfter, tagHandler=.

See more in =Foswiki::Extension::Empty=.

---+++ extensible

A core class called extensible if it allows overriding one or more of it's
methods by extensions. This is a lightweight version of subclassing through
reimplementing or extending only key method(s).

See more in =Foswiki::Extension::Empty=.

---++ Standard helpers

Standard helpers are installed automatically and provide some commonly used
functionality in an attempt to simplify routine operations.

---+++ stubMethods @methodList

This helper installs empty methods named after elements of it's parameters. A
stub method is a sub which does nothing; in other words, the following:

<verbatim>
sub method1 {}
sub method2 {}
sub method3 {}
</verbatim>

could be replaced with:

<verbatim>
stubMethods qw(method1 method2 method3);
</verbatim>

---++ Implementation notes

---+++ Modifiers

Modifiers are implemented with =_install_&lt;modifier&gt;= methods and are
called automatically depending on what a class has requested.

If a modifier installer assigns a role to the calling class then it must preload
the role module with =Foswiki::load_package()=.

---+++ Public methods (keywords)

Keywords are implemented by =_handler_&lt;keyword&gt;= methods of this module.
Though there is no automated mapping between a handler and a keyword by now it
might be implemented in future and thus anybody extending this modulue is highly
encouradged to follow this convention.

---+++ Recording of class attributes

When =FOSWIKI_ASSERTS= environment variable is set to true =Foswiki::Class=
records attributes declared with Moo's =has= directive. Subroutine
=getClassAttributes()= can be used to retrieve a list of declared attributes for
a specific class. Attributes of class' parent classes and all applied roles are
included into the list.

*%X% NOTE:* Although any possible measures were taken to catch all class'
parents and roles it is still possible that some exotic method of declaring them
has been overlooked. For this reason if =Foswiki::Object= debug code reports an
undeclared attribute then the first thing to check would be if there is a
run-away parent or role declaring it.

---+++ Applying roles

Roles are being applied to a class in a simple transactional manner. First
a list of roles is built for a class using assignments (see =_assign_role()=).
Then the list is used to actually apply roles to the class at once with
=_apply_roles()= method after class code compilation is done.

=cut

# Naming conventions for this module:
# _install_something – functions that install feature `something' into the target module;
# _handler_someword - function which implements exported keyword `someword'

use Carp;
use Class::Method::Modifiers qw(install_modifier);

require Foswiki;
require Moo::Role;
require Moo;
require namespace::clean;

use constant DEFAULT_FEATURESET => ':5.14';

our @ISA = qw(Moo);

my %_classData;

# **BEGIN Install wrappers for Moo's has/with/extends to record basic object
# information. Works only when $ENV{FOSWIKI_ASSERTS} is true.

# Mapping of wrapped sub into wrapping handler. The handlers must have names
# starting with _fw_
my %_codeWrapper = (
    extends => '_fw_extends',    # Wrap always.
);

sub _fw_has {
    my $target = shift;
    my ($attr) = @_;

    #say STDERR "Registering attr `$attr' on $target";

    push @{ $_classData{$target}{registeredAttrs}{list} },
      { attr => $attr, options => [ @_[ 1 .. $#_ ] ] };
}

sub _fw_with {
    my $target = shift;

    #say STDERR "$target WITH ", join( ", ", @_ );
    push @{ $_classData{$target}{WITH} }, @_;
}

sub _fw_extends {
    my $target = shift;

    #say STDERR "*** $target EXTENDS ", join( ", ", @_ );
    push @{ $_classData{$target}{ISA} }, @_;

    #say STDERR "+++ $target ", ( $target->isa($_) ? "is a" : "isn't a" ),
    #  " $_ descendant"
    #  foreach qw (Moo::Object Foswiki::Object);
    # SMELL Replace this if() with support of build_required flag of a modifier.
    #if (   $_classData{$target}{options}{callbacks}{use}
    #    || $_classData{$target}{options}{extensible}{use} )
    #{
    #
    #    my $trg_ns = Foswiki::getNS($target);
    #
    #    # Install BUILD method if a feature requiring it requested.
    #    # Otherwise feature implementation role will fail to apply cleanly.
    #    unless ( defined $trg_ns->{BUILD}
    #        && defined *{ $trg_ns->{BUILD} }{CODE} )
    #    {
    #        #say STDERR "Installing BUILD for $target";
    #        install_modifier( $target, fresh => BUILD => sub { } );
    #    }
    #}

    #say STDERR "Applying roles to $target";
    __PACKAGE__->_apply_roles($target);
}

if ( $ENV{FOSWIKI_ASSERTS} ) {
    @_codeWrapper{qw(has with)} = qw(_fw_has _fw_with);
}

# Moo doesn't provide a clean way to get all object's attributes. The only
# really good way to distinguish between a key on object's hash and an
# attribute is to record what is passed to Moo's sub 'has'. Since Moo
# generates it for each class separately (as well as other 'keywords') and
# since Moo::Role does it on its own too then the only correct approach to
# intercept everything is to tap into Moo's guts. And the best way to do so
# is to intercept calls to _install_tracked() as this sub is used to
# register every single Moo-generated code ref. Though this is a hacky way
# on its own but the rest approaches seem to be even more hacky and no doubt
# unreliable.
#
# Additionally, interception is used to tap into processing of Moo::extends in
# order to apply modifiers to the target classes. This is the only known way to
# get around a problem with failed to compile modules. The problem is about
# applying roles to them. This is causing a fatal exception which masks the
# actual compilation error.
foreach my $module (qw(Moo Moo::Role)) {
    my $ns               = Foswiki::getNS($module);
    my $_install_tracked = *{ $ns->{'_install_tracked'} }{CODE};
    _inject_code(
        $module,
        '_install_tracked',
        sub {
            my $ovCode;
            my $target    = $_[0];
            my $codeName  = $_[1];
            my $ovSubName = $_codeWrapper{$codeName};
            $ovCode = __PACKAGE__->can($ovSubName) if $ovSubName;
            if ($ovCode) {

                #say STDERR "Installing wrapper $codeName on $target";
                my $origCode = $_[2];
                $_[2] = sub {

                    #say STDERR "Orig ${target}::$codeName code first.";
                    &$origCode(@_);

                    #say STDERR "Extension ${target}::$codeName code next.";
                    $ovCode->( $target, @_ );
                };
            }
            goto &$_install_tracked;
        }
    );
}

# **END of has/with/extends wrappers.

=begin TML

---++ Methods

=cut

sub import {
    my ($class) = shift;
    my $target = caller;

    #say STDERR "--- Foswiki::Class($class, $target)";

    local $SIG{__DIE__} = sub { Carp::confess(@_) }
      if $ENV{FOSWIKI_ASSERTS};

    # Define modifiers we would provide for classes.
    # 'Options' is the initial term for modifiers.
    my %options = (
        callbacks => { use => 0, build_required => 1, },
        app       => { use => 0, },
        extension => {
            use => 0,
            keywords =>
              [qw(extClass extAfter extBefore plugBefore plugAfter plugAround)],
        },
        extensible => {
            use            => 0,
            keywords       => [qw(pluggable)],
            build_required => 1,
        },
    );

    $_classData{$target}{options} = \%options;

    my @p;
    my @noNsClean  = qw(meta);
    my $featureSet = DEFAULT_FEATURESET;
    while (@_) {
        my $param = shift;
        if ( $param =~ /^:/ ) {
            $featureSet = $param;
            next;
        }
        if ( exists $options{$param} ) {
            my $opt = $options{$param};
            $opt->{use} = 1;
        }
        else {
            push @p, $param;
        }
    }

    foreach my $option ( grep { $options{$_}{use} } keys %options ) {

        #say STDERR "Installing option $option";
        my $installer = __PACKAGE__->can("_install_$option");
        die "INTERNAL:There is no support for option $option"
          unless defined $installer;
        $installer->( $class, $target );
    }

    require feature;
    feature->import($featureSet);

    namespace::clean->import(
        -cleanee => $target,
        -except  => \@noNsClean,
    );

    # Install some common helpers.
    _inject_code( $target, 'stubMethods', \&_handler_stubMethods );

    @_ = ( $class, @p );
    goto &Moo::import;
}

sub _getAllAttrs {
    foreach my $class (@_) {
        my @classAttrs;
        if ( defined $_classData{$class}{registeredAttrs} ) {
            if ( defined $_classData{$class}{registeredAttrs}{cached} ) {

                # Skip the class if already cached.
                next;
            }
            if ( defined $_classData{$class}{registeredAttrs}{list} ) {
                push @classAttrs,
                  map { $_->{attr} }
                  @{ $_classData{$class}{registeredAttrs}{list} };
            }
        }
        if ( defined $_classData{$class}{ISA} ) {
            push @classAttrs, _getAllAttrs( @{ $_classData{$class}{ISA} } );
        }
        if ( defined $_classData{$class}{WITH} ) {
            push @classAttrs, _getAllAttrs( @{ $_classData{$class}{WITH} } );
        }
        my @base = eval "\@$class\::ISA";
        push @classAttrs, _getAllAttrs(@base) if @base;

        # Leave uniq only attrs.
        @classAttrs = keys %{ { map { $_ => 1 } @classAttrs } };
        $_classData{$class}{registeredAttrs}{cached} = \@classAttrs;
    }
    return map { @{ $_classData{$_}{registeredAttrs}{cached} } } @_;
}

=begin TML

---+++ StaticMethod getClassAttributes( $class ) -> \@attrList

Returns list of attributes declared with =CPAN:Moo='s =has= for =$class=.

=cut

sub getClassAttributes {
    my $class = shift;

    #require Data::Dumper;

    #say STDERR Data::Dumper->Dump(
    #    [ \%_registeredAttrs, \%_ISA, \%_WITH ],
    #    [qw(%_registeredAttrs %_ISA %_WITH)]
    #);

    return _getAllAttrs($class);
}

=begin TML

---+++ StaticMethod _inject_code( $target, $name, $code )

Installs a sub =$code= into module =$target= namespace under the name =$name=.

*%X% NOTE:* In a way this method duplicates =Moo::_install_coderef=
functionality. But as long as the latter remains a private =Moo= sub it's better
be avoided.

=cut

sub _inject_code {
    my ( $target, $name, $code ) = @_;

    no warnings qw(redefine);
    Foswiki::getNS($target)->{$name} = $code;
    use warnings qw(redefine);
}

=begin TML

---+++ StaticMethod _apply_roles( $class [, @classes] )

%X% Strictly for internal =Foswiki::Class= use only.

This method applies previosly assigned roles to a =$class=. If =@classes= is
non-zero length then roles are applied to the specified classes only. Otherwise
all assigned classes are processed.

=cut

sub _apply_roles {
    my $class = shift;

    my @targets =
      grep { defined $_classData{$_}{assignedRoles} }
      ( scalar(@_) ? @_ : keys %_classData );

    foreach my $target (@targets) {

       #say STDERR "Applying roles ",
       #  join( ", ", @{ $_classData{$target}{assignedRoles} } ), " to $target";

        push @{ $_classData{$target}{WITH} },
          @{ $_classData{$target}{assignedRoles} };

        #say STDERR "Applying {",
        #  join( ",", @{ $_classData{$target}{assignedRoles} } ),
        #  "} to $target";
        Moo::Role->apply_roles_to_package( $target,
            @{ $_classData{$target}{assignedRoles} } );
        $class->_maybe_reset_handlemoose($target);
        delete $_classData{$target}{assignedRoles};
    }
}

=begin TML

---+++ StaticMethod _assign_role( $class, $role )

Assigns a =$role= to a =$class=. Doesn't actually apply it, see =_apply_roles()=
method.

=cut

sub _assign_role {
    my ( $class, $role ) = @_;
    push @{ $_classData{$class}{assignedRoles} }, $role;
}

sub _handler_stubMethods (@) {
    my $target = caller;
    my $stubCode = sub { };
    foreach my $methodName (@_) {
        _inject_code( $target, $methodName, $stubCode );
    }
}

sub _handler_callback_names {
    my $target = caller;
    Foswiki::Util::Callbacks::registerCallbackNames( $target, @_ );
}

sub _install_callbacks {
    my ( $class, $target ) = @_;

    Foswiki::load_package('Foswiki::Util::Callbacks');
    _assign_role( $target, 'Foswiki::Util::Callbacks' );
    _inject_code( $target, "callback_names", *_handler_callback_names );
}

sub _install_app {
    my ( $class, $target ) = @_;
    Foswiki::load_package('Foswiki::AppObject');

    #say STDERR "Assigning Foswiki::AppObject to $target";
    _assign_role( $target, 'Foswiki::AppObject' );
}

sub _handler_plugBefore ($&) {
    my $target = caller;
    my ( $plug, $code ) = @_;
    Foswiki::ExtManager::registerPlugMethod( $target, 'before', $plug, $code );
}

sub _handler_plugAround ($&) {
    my $target = caller;
    my ( $plug, $code ) = @_;
    Foswiki::ExtManager::registerPlugMethod( $target, 'around', $plug, $code );
}

sub _handler_plugAfter ($&) {
    my $target = caller;
    my ( $plug, $code ) = @_;
    Foswiki::ExtManager::registerPlugMethod( $target, 'after', $plug, $code );
}

sub _handler_extClass ($$) {
    my ( $class, $subClass ) = @_;
    my $target = caller;

    Foswiki::ExtManager::registerSubClass( $target, $class, $subClass );
}

sub _handler_extAfter (@) {
    my $target = caller;

    Foswiki::ExtManager::registerDeps( $target, @_ );
}

sub _handler_extBefore (@) {
    my $target = caller;

    Foswiki::ExtManager::registerDeps( $_, $target ) foreach @_;
}

sub _handler_tagHandler ($;$) {
    my $target = caller;

    # Handler could be a class name doing Foswiki::Macro role or a sub to be
    # installed as target's hadnling method.
    my ( $tagName, $tagHandler ) = @_;

    if ( ref($tagHandler) eq 'CODE' ) {

        # If second argument is a code ref then we install method with the same
        # name as macro name.
        _inject_code( $target, $tagName, $tagHandler );
        Foswiki::ExtManager::registerExtTagHandler( $target, $tagName );
    }
    else {
        Foswiki::ExtManager::registerExtTagHandler( $target, $tagName,
            $tagHandler );
    }
}

sub _handler_callbackHandler ($&) {
    my $target = caller;

    Foswiki::ExtManager::registerExtCallback( $target, @_ );
}

sub _install_extension {
    my ( $class, $target ) = @_;

    _inject_code( $target, 'plugBefore',      \&_handler_plugBefore );
    _inject_code( $target, 'plugAround',      \&_handler_plugAround );
    _inject_code( $target, 'plugAfter',       \&_handler_plugAfter );
    _inject_code( $target, 'extClass',        \&_handler_extClass );
    _inject_code( $target, 'extAfter',        \&_handler_extAfter );
    _inject_code( $target, 'extBefore',       \&_handler_extBefore );
    _inject_code( $target, 'tagHandler',      \&_handler_tagHandler );
    _inject_code( $target, 'callbackHandler', \&_handler_callbackHandler );
}

sub _handler_pluggable ($&) {
    my $target = caller;
    my ( $method, $code ) = @_;

    Foswiki::ExtManager::registerPluggable( $target, $method, $code );
}

sub _install_extensible {
    my ( $class, $target ) = @_;

    #say STDERR "--- INSTALLING extensible ON $target";

    _assign_role( $target, 'Foswiki::Util::_ExtensibleRole' );
    _inject_code( $target, 'pluggable', \&_handler_pluggable );
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
