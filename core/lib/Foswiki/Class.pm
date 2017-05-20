# See bottom of file for license and copyright information

package Foswiki::Class;
use v5.14;

use strict;
use warnings;

=begin TML

---+!! Module Foswiki::Class

This is a wrapper package for Moo and intended to be used as a replacement and
a shortcut for a bunch lines of code like:

<verbatim>
use v5.14;
use Moo;
use namespace::clean;
with qw(Foswiki::AppObject);
</verbatim>

The above could be replaced with a single line of:

<verbatim>
use Foswiki::Class qw(app);
</verbatim>

---++ Usage

A set of features is exported to the calling module is defined by =use=
parameter keywords. If no parameters defined then all it does is applies
=[[CPAN:Moo][Moo]]=, ':5.14'
[[http://perldoc.perl.org/feature.html#FEATURE-BUNDLES][feature]] bundle, and
cleans namespace with =[[CPAN:namespace::clean][namespace::clean]]=.

---++ Parameters

The following parameters are support by this module:

| *Parameter* | *Description* |
| =app= | Class being created will have =Foswiki::AppObject= role applied. |
| =callbacks= | Provide support for callbacks |
| =extension= | Declares class to be an extension. See =Foswiki::Extenion::Empty= for more information. |
| =extensible= | Makes class an extensible. |
| =:5.XX= | A string prefixed with colon is treated as a feature bundle name and passed over to the =feature= module as is. This allows to override the ':5.14' default. |

---++ Standard helpers

Standard helpers are installed automatically and provide some commonly used
functionality in an attempt to simplify routine operations.

---+++ stubMethods @methodList

This helper installs empty methods named after elements of it's parameters. A stub method
is a sub which does nothing; in other words, instead of having a number of lines like:

<verbatim>
sub method1 {}
sub method2 {}
sub method3 {}
</verbatim>

One could simply do:

<verbatim>
stubMethods qw(method1 method2 method3);
</verbatim>

---++ Callbacks

When =callbacks= parameter is used:

<verbatim>
use Foswiki::Class qw(callbacks);
</verbatim>

a subroutine =callback_names= is exported into a class' namespace and
=Foswiki::Aux::Callbacks= role gets applied. =callback_names= accepts a list
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

See =Foswiki::Aux::Callbacks=.

---++ Extensions

Extension support is provided by exporting subroutines =callbackHandler,
extBefore, extAfter, extClass, plugBefore, plugAround, plugAfter, tagHandler=.

See more in =Foswiki::Extension::Empty=.

---++ Extensible

A core class called extensible if it allows overriding one or more of it's
methods by extensions. This is a lightweight version of subclassing through
reimplementing or extending only key method(s).

See more in =Foswiki::Extension::Empty=.

---++ Class attributes recording

When =FOSWIKI_ASSERTS= environment variable is set to true =Foswiki::Class=
records attributes declared with Moo's =has= directive. Subroutine
=getClassAttributes()= can be used to retrieve a list of declared attributes for
a specific class. Attributes of class' parent classes and all applied roles are
included.

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

# BEGIN Install wrappers for Moo's has/with/extends to record basic object information. Works only when $ENV{FOSWIKI_ASSERTS} is true.

my %_codeWrapper = (
    extends => '_fw_extends',    # Wrap always.
);

sub _fw_has {
    my $target = shift;
    my ($attr) = @_;

    #say STDERR "Registering attr $attr on $target";

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
    if (   $_classData{$target}{options}{callbacks}{use}
        || $_classData{$target}{options}{extensible}{use} )
    {

        my $trg_ns = Foswiki::getNS($target);

        # Install BUILD method if a feature requiring it requested.
        # Otherwise feature implementation role will fail to apply cleanly.
        unless ( defined $trg_ns->{BUILD}
            && defined *{ $trg_ns->{BUILD} }{CODE} )
        {
            #say STDERR "Installing BUILD for $target";
            install_modifier( $target, fresh => BUILD => sub { } );
        }
    }
    __PACKAGE__->_apply_roles;
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
                    $ovCode->( $target, @_ );
                    goto &$origCode;
                };
            }
            goto &$_install_tracked;
        }
    );
}

# END of has/with/extends wrappers.

sub import {
    my ($class) = shift;
    my $target = caller;

    #say STDERR "Foswiki::Class($class, $target)";

    $SIG{__DIE__} = sub { Carp::confess(@_) };

    # Define options we would provide for classes.
    my %options = (
        callbacks => { use => 0, },
        app       => { use => 0, },
        extension => {
            use => 0,
            keywords =>
              [qw(extClass extAfter extBefore plugBefore plugAfter plugAround)],
        },
        extensible => {
            use      => 0,
            keywords => [qw(pluggable)],
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

sub getClassAttributes {
    my $class = shift;

    #require Data::Dumper;

    #say STDERR Data::Dumper->Dump(
    #    [ \%_registeredAttrs, \%_ISA, \%_WITH ],
    #    [qw(%_registeredAttrs %_ISA %_WITH)]
    #);

    return _getAllAttrs($class);
}

# Actually we're duplicating Moo::_install_coderef here in a way. But we better
# avoid using a module's internalls.
sub _inject_code {
    my ( $target, $name, $code ) = @_;

    no warnings qw(redefine);
    Foswiki::getNS($target)->{$name} = $code;
    use warnings qw(redefine);
}

sub _apply_roles {
    my $class = shift;
    foreach my $target (
        grep { defined $_classData{$_}{assignedRoles} }
        keys %_classData
      )
    {

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
    Foswiki::Aux::Callbacks::registerCallbackNames( $target, @_ );
}

sub _install_callbacks {
    my ( $class, $target ) = @_;

    Foswiki::load_package('Foswiki::Aux::Callbacks');
    _assign_role( $target, 'Foswiki::Aux::Callbacks' );
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

    _assign_role( $target, 'Foswiki::Aux::_ExtensibleRole' );
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
