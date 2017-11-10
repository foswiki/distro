# See bottom of file for license and copyright information

=begin TML

---+!! Class Foswiki::Config::Node

Class defining config spec node.

---++ SYNOPSIS

<verbatim>
my $value = $node->getValue;
</verbatim>

---++ DESCRIPTION

A node can be in one of two states: a _branch_ or a _leaf_. A _branch_ node has
or may have subnodes. A _leaf_ node stores a configuration value.

Depending on the =value= attribute a node could be in either initialized or
unitialized state. When node is initialized it means that the attribute has
something assigned to it. This state is indicated by a _true_ value returned
by =has_value()= method. Actual data stored in the attribute is irrelevant
and can be anything, even *undef*.

In uninitialized state =has_value()= returns _false_. In this case =getValue()=
method will return data defined in =default= option as returned by
%PERLDOC{"Foswiki::Config::ItemRole"  method="getOpt"}% method.

See: %PERLDOC{"Foswiki::Config"}%

=cut

package Foswiki::Config::Node;

use Assert;
use Foswiki::Exception;
use Foswiki::Exception::Config;
use Try::Tiny;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);
with qw(Foswiki::Config::ItemRole);

=begin TML

---++ CONSTANTS

=cut

# These are internal use constants, not documenting
use constant DATAHASH_CLASS => 'Foswiki::Config::DataHash';
use constant ROLE_NAMESPACE => 'Foswiki::Config::Role::Node::';

=begin TML

---+++ Note Leaf States

   $ LEAF: Node is a leaf
   $ BRANCH: Node is a branch
   $ NOSTATE: State is not determined/set yet

=cut

# Leaf states
use constant LEAF    => 1;
use constant BRANCH  => 0;
use constant NOSTATE => undef;

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute value

Node's assigned value.

=cut

# Value could be anything.
has value => (
    is        => 'rw',
    predicate => 1,
    lazy      => 1,
    clearer   => 1,
    builder   => 'prepareValue',
    trigger   => 1,
);

=begin TML

---+++ ObjectAttribute section

Config section this node belongs to.

=cut

has section => (
    is       => 'rw',
    weak_ref => 1,
    builder  => 'prepareSection',
    isa => Foswiki::Object::isaCLASS( 'section', 'Foswiki::Config::Section', ),
);

=begin TML

---+++ ObjectAttribute leafState -> bool

Defines if this node is a leaf, or a branch, or type of this node is undefined
yet (if attribute's value is undef).

See Node Leaf States section above.

This is a lazy attribute. Its initializer method =prepareLeafState()= would try
to guess node's valid state by checking if there is a leaf-only option set for
the object.

=cut

has leafState => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    clearer   => 1,
    builder   => 'prepareLeafState',
);

=begin TML

---+++ ObjectAttribute fullPath -> arrayref

List of keys forming full path to this node. For example, if this node keypath
is _Email.Transport.Port_ then this attribute will contain:
<verbatim>[qw<Email Transport Port>]</verbatim>

=cut

has fullPath => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareFullPath',
);

=begin TML

---+++ ObjectAttribute fullName -> string

Full keypath of this node.

=cut

has fullName => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareFullName',
);

=begin TML

---+++ ObjectAttribute _leafOnlyOpts

Hash of =option => 1= pairs of options valid for leaf nodes only.

=cut

has _leafOnlyOpts => (
    is      => 'ro',
    clearer => 1,
    lazy    => 1,
    isa     => Foswiki::Object::isaHASH( '_leafOnlyOpts', noUndef => 1, ),
    builder => '_prepareLeafOnlyOpts',
);

=begin TML

---+++ ObjectAttribute _dualModeOpts

Hash of =option => 1= pairs of options valid for both node states.

=cut

has _dualModeOpts => (
    is      => 'ro',
    clearer => 1,
    lazy    => 1,
    isa     => Foswiki::Object::isaHASH( '_dualModeOpts', noUndef => 1, ),
    builder => '_prepareDualModeOpts',
);

=begin TML

---+++ METHODS

=cut

my %optMaps;
my %types = (
    STRING       => { roles => ['Size'], },
    NUMBER       => { roles => ['Size'], },
    URL          => { roles => ['Size'], },
    URLPATH      => { roles => ['Size'], },
    REGEX        => { roles => ['Size'], },
    COMMAND      => { roles => ['Size'], },
    PASSWORD     => { roles => ['Size'], },
    PATH         => { roles => ['Size'], },
    PERL         => { roles => ['Size'], },
    EMAILADDRESS => { roles => ['Size'], },

    SELECT      => { roles => ['Select'], },
    SELECTCLASS => { roles => ['Select'], },
    BOOLGROUP   => { roles => ['Select'], },

    BOOLEAN  => {},
    LANGUAGE => {},
    OCTAL    => {},
    DATE     => {},
    URILIST  => {},
    VOID     => {},
);

# Resets only if leafState is undef. This will enforce re-check for the
# attribute.
sub _recheck_leafState {
    my $this = shift;
    $this->clear_leafState
      unless $this->has_leafState && defined $this->leafState;
}

=begin TML

---+++ ObjectMethod setLeafState( $state )

Set node's leaf state to =$state=. 

Throws =Foswiki::Exception::Fatal= if the state has been previously set to a
different value than =$state=.

If =$state= is _undef_ then recheck of of node's state will be enforced by 
clearing the =leafState= attribute.

=cut

# Set leafState manually.
sub setLeafState {
    my $this = shift;
    my ($state) = @_;

    Foswiki::Exception::Fatal->throw( text => "Node "
          . $this->fullName
          . " leaf state is already defined and cannot be changed" )
      if $this->has_leafState
      && defined $this->leafState
      && $this->leafState != $state;

    if ( defined $state ) {
        $this->leafState( $state ? LEAF : BRANCH );
    }
    else {
        $this->_recheck_leafState;
    }
}

=begin TML

---+++ ObjectMethod isLeaf => bool

Returns true if node is a leaf.

=cut

sub isLeaf {
    my $this = shift;
    $this->_recheck_leafState;
    return defined $this->leafState && $this->leafState == LEAF;
}

=begin TML

---+++ ObjectMethod isBranch => bool

Returns true if node is a branch.

=cut

sub isBranch {
    my $this = shift;
    $this->_recheck_leafState;
    return defined $this->leafState && $this->leafState == BRANCH;
}

=begin TML

---+++ ObjectMethod isVague => bool

Returns true if node type is yet undetermined. Note that if this method returns
_true_ then =isLeaf= and =isBranch= both would return _false_.

=cut

sub isVague {
    my $this = shift;
    return !( $this->has_leafState && defined $this->leafState );
}

=begin TML

---+++ ObjectMethod getValue

A wrapper for =value= and =default= attributes. Returns either =value= if
assigned or =default= otherwise.

=cut

sub getValue {
    my $this = shift;

    return $this->has_value ? $this->value : $this->getOpt('default');
}

=begin TML

---+++ ObjectMethod setOpt_type( $opt, $val ) -> boolean

Validate *-type* option. Throws =Foswiki::Exception::Config::BadSpecData=
if =$val= is _undef_ or if change of *-type* is being attempted.

See =Foswiki::Config::ItemRole= =setOpt()= method.

=cut

sub setOpt_type {
    my $this = shift;
    my ( $opt, $val ) = @_;

    Foswiki::Exception::Config::BadSpecData->throw(
        text       => "Node type can not be undefined",
        nodeObject => $this,
    ) unless defined $val;

    my $opts = $this->options;

    if ( defined $opts->{$opt} ) {
        return if $opts->{$opt} eq $val;

        Foswiki::Exception::Config::BadSpecData->throw(
            text => "Node type change from "
              . $opts->{$opt} . " to "
              . $val
              . " is not allowed",
            nodeObject => $this,
        );
    }

    return 1;
}

=begin TML

---+++ ObjectMethod defaultOpt_type -> 'STRING'

See =Foswiki::Config::ItemRole= =getOpt()= method.

=cut

sub defaultOpt_type {
    return 'STRING';
}

around setOpt => sub {
    my $orig = shift;
    my $this = shift;
    my @args = @_;

    try {
        $orig->( $this, @args );
    }
    catch {
        $this->_completeException($_);
    };
};

around validateOpt => sub {
    my $orig  = shift;
    my $this  = shift;
    my @args  = @_;
    my ($opt) = $args[0];

    try {
        $orig->( $this, @args );
    }
    catch {
        $this->_completeException($_);
    };

    if (   $this->_leafOnlyOpts->{$opt}
        && $this->isBranch )
    {
        Foswiki::Exception::Config::BadSpecData->throw(
            text => "Leaf-only option '"
              . $opt
              . "' cannot be used with a non-leaf key",
            nodeObject => $this,
        );
    }
};

# Just a shortcut for a commonly used option.
sub default {
    my $this = shift;
    return $this->getOpt('default');
}

=begin TML

---+++ ClassMethod invalidSpecAttr(@attrList) -> $attrName [, $attrName [, ...] ]

Depending on call context (scalar or list) returns only first or all invalid
spec attributes found in the list. Undef or empty list returned otherwise.

This method is dual: it is class and object method at the same time.

=cut

sub invalidSpecOpts {
    my $this = shift;

    if (wantarray) {
        return grep { !$this->isValidOpt($_) } @_;
    }

    foreach my $opt (@_) {
        return $opt unless $this->isValidOpt($opt);
    }

    return;
}

=begin TML

---+++ ClassMethod preloadTypes()

This method attepts to pre-load type class modules (for example, for type STRING
it tries to load Foswiki::Config::Node::STRING). If a type has roles to apply
then a new class with the roles applied is created. A type can be preloaded once
only. If a type has been added dynamically over the application lifetime and
this method is called afterwards then only this type would be preloaded when the
method is called next time (and it HAS to be called after dynamic type
registration).

=cut

sub preloadTypes {
    my $class = shift;

    foreach my $type ( keys %types ) {
        next if defined $types{$type}{_class};

        my $baseClass = __PACKAGE__ . "::" . $type;

        my $modLoaded;

        try {
            Foswiki::load_class($baseClass);
            $modLoaded = 1;
        }
        catch {
            $modLoaded = 0;
        };

        my $class = $modLoaded ? $baseClass : __PACKAGE__;
        if ( $types{$type}{roles} ) {

            # Cache of short role -> role class name mapping.
            state $roleMap;

            my @roles =
              map { $roleMap->{$_} || ( $roleMap->{$_} = ROLE_NAMESPACE . $_ ) }
              @{ $types{$type}{roles} };

            $class = Moo::Role->create_class_with_roles( $class, @roles );
        }

        $types{$type}{_class} = $class;
    }
}

=begin TML

---+++ ClassMethod getAllTypes -> @types

Returns list of all known node types (option *-type*).

=cut

sub getAllTypes {
    my $class = shift;

    $class->preloadTypes;

    return keys %types;
}

=begin TML

---+++ ClassMethod knownType( $type ) -> boolean

Returns _true_ if type =$type= is a known node type.

=cut

sub knownType {
    my $class = shift;
    my $type  = shift;

    return defined $types{$type};
}

=begin TML

---+++ ClassMethod type2class( $type ) -> $class

Returns a class name to create a node object with type =$type=.

=cut

sub type2class {
    my $class = shift;
    my ($type) = shift;

    return undef unless defined $type && exists $types{$type};

    $class->preloadTypes unless defined $types{$type}{_class};

    my $typeClass = $types{$type}{_class};

    return $typeClass;
}

=begin TML

---+++ ObjectMethod _trigger_value

Trigger method of =value= attribute.

=cut

sub _trigger_value {
    my $this = shift;
    my $val  = shift;

    unless ( $this->isVague ) {

        my $tiedVal =
          ref($val) eq 'HASH' && UNIVERSAL::isa( tied(%$val), DATAHASH_CLASS );

        # SMELL Replace with more appropriate exception, similar to
        # Foswiki::Exception::Config::BadSpecData.
        Foswiki::Exception::Config::BadSpecValue->throw(
            text => "Only hashes tied to "
              . DATAHASH_CLASS
              . " can be assigned to branch keys",
            specObject => $this,
        ) if $this->isBranch && !$tiedVal;

        Foswiki::Exception::Config::BadSpecValue->throw(
            text => "Attempt to assign hash tied to "
              . DATAHASH_CLASS
              . " to a leaf key",
            specObject => $this,
        ) if $this->isLeaf && $tiedVal;
    }
}

=begin TML

---+++ ObjectMethod leafOnlyOptions -> @options

Returns a list of options valid for leaf nodes only.

=cut

sub leafOnlyOptions {
    my $this    = shift;
    my $optDefs = $this->optDefs;
    return grep { $optDefs->{$_}{leaf} } keys %$optDefs;
}

=begin TML

---+++ ObjectMethod dualModeOptions -> @options

Returns a list of options valid for both leaf and branch nodes.

=cut

sub dualModeOptions {
    my $this    = shift;
    my $optDefs = $this->optDefs;
    return grep { $optDefs->{$_}{dual} } keys %$optDefs;
}

around optionDefinitions => sub {
    my $orig  = shift;
    my $class = shift;

    return (
        $orig->( $class, @_ ),
        check           => { arity => 1, leaf => 1, },
        checker         => { arity => 1, leaf => 1, },
        check_on_change => { arity => 1, leaf => 1, },
        default         => { arity => 1, leaf => 1, },
        display_if      => { arity => 1, leaf => 1, },
        enhance         => { arity => 0, leaf => 1, },
        expert          => { arity => 0, leaf => 1, }, # TODO: Move to ItemRole?
        feedback        => { arity => 1, leaf => 1, },
        hidden          => { arity => 0, leaf => 1, },
        label           => { arity => 1, dual => 1, },
        onsave          => { arity => 1, leaf => 1, },
        optional        => { arity => 0, leaf => 1, },
        source          => { arity => 1, dual => 1, },
        sources         => { arity => 1, dual => 1, },
        spellcheck      => { arity => 0, dual => 1, },
        type            => { arity => 1, leaf => 1, },
        wizard          => { arity => 1, leaf => 1, },
    );
};

# The Foswiki::Config::ItemRole::setOpt throws raw BadSpecData exception because
# it generaly knows nothing about the object it's ran against. We shall complete
# the exception information to provide user with more details about the problem.
sub _completeException {
    my $this = shift;
    my $e = Foswiki::Exception::Fatal->transmute( $_[0], 0 );

    if ( $e->isa('Foswiki::Exception::Config::BadSpec') ) {
        $e->nodeObject($this);
    }

    $e->rethrow;
}

=begin TML

---+++ ObjectMethod prepareFullPath

Initializer of =fullPath= attribute.

=cut

sub prepareFullPath {
    my $this = shift;

    return [ ( $this->has_parent ? @{ $this->parent->fullPath } : () ),
        $this->name ];
}

=begin TML

---+++ ObjectMethod prepareFullName

Initializer of =fullName= attribute.

=cut

sub prepareFullName {
    my $this = shift;

    return $this->parent->cfg->normalizeKeyPath( $this->fullPath );
}

=begin TML

---+++ ObjectMethod prepareLeafState

Initializer of =leafState= attribute.

=cut

sub prepareLeafState {
    my $this = shift;

    foreach my $opt ( keys %{ $this->options } ) {
        return LEAF if $this->_leafOnlyOpts->{$opt};
    }

    return undef;
}

=begin TML

---+++ ObjectMethod prepareParent

Initializer for =Foswiki::Config::ItemRole= =parent= attribute.

=cut

# Cannot use =stubMethods= for prepareParent because role is being applied before
# =stubMethods= gets called.
sub prepareParent { }

sub _prepareLeafOnlyOpts {
    my $this = shift;

    $optMaps{leafOnly} = { map { $_ => 1 } $this->leafOnlyOptions }
      unless $optMaps{leafOnly};

    return $optMaps{leafOnly};
}

sub _prepareDualModeOpts {
    my $this = shift;

    $optMaps{dualMode} = { map { $_ => 1 } $this->dualModeOptions }
      unless $optMaps{dualMode};

    return $optMaps{dualMode};
}

=begin TML

---+++ Empty prepare methods

The following methods are empty initializers of their respective attributes:

   * prepareSection
   * prepareValue
   
These methods do nothing but could be overriden by subclasses.

=cut

stubMethods qw( prepareSection prepareValue );

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
