# See bottom of file for license and copyright information

=begin TML

---+ Class Foswiki::Config::Node

A class defining config spec node.

---++ SYNOPSIS

<verbatim>
my $value = $node->getValue;
</verbatim>

---++ DESCRIPTION

Nodes can be of two types: a branch or a leaf. A branch is a node which has or
may have subnodes. A leaf is a node storing a configuration value. Both types of
nodes can have properties defined by object attributes.

A Node can be either in uninitialized or initialized state when it has a value
assigned. The value could be anything – including *undef*. The difference between
modes is defined by =$node-&gt;has_value=. If there is no value then it's defined
by =default= attribute.

=cut

package Foswiki::Config::Node;

use Assert;
use Foswiki::Exception;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);

use constant DATAHASH_CLASS => 'Foswiki::Config::DataHash';

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

---+++ ObjectAttribute parent

Parent container object of class =Foswiki::Config::DataHash=. 

=cut

has parent => (
    is       => 'rw',
    weak_ref => 1,
    builer   => 'prepareParent',
    (
        DEBUG
        ? ( isa => Foswiki::Object::isaCLASS( 'parent', DATAHASH_CLASS ) )
        : ()
    ),
    handles => [qw(fullPath fullName)],
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

---+++ ObjectAttribute isLeaf => bool

Defines if this is a leaf node, or branch, or type of this node is undefined yet
(if attribute's value is undef). 

=cut

has isLeaf => ( is => 'rw', builder => 'prepareIsLeaf', );

=begin TML

---++ Spec option attributes

The following object attributes are valid spec options.

=cut

=begin TML

---+++ ObjectAttribute default

Node's default value as defined by spec.

=cut

has default => (
    is        => 'rw',
    predicate => 1,
    builder   => 'prepareDefault',
);

=begin TML

---+++ ObjectAttribute type

Key data type like _NUMBER_ or _TEXT_.

=cut

has type => ( is => 'rw', predicate => 1, builder => 'prepareType', );

=begin TML

---+++ ObjectAttribute label

Text label attached to the config key.

=cut

has label => ( is => 'rw', predicate => 1, builder => 'prepareLabel', );

=begin TML

---+++ Empty prepare methods

The following methods are empty initializers of their respective attributes:

   * prepareParent
   * prepareSection
   * prepareValue
   * prepareDefault
   * prepareIsLeaf
   * prepareLabel
   
These methods do nothing but could be overriden by subclasses.

=cut

stubMethods qw(prepareParent prepareSection prepareValue prepareDefault
  prepareIsLeaf prepareLabel);

my @validSpecAttrs = qw(
  default type label isLeaf
);

=begin TML

---+++ ObjectMethod isBranch => bool

Returns true if node is a branch.

=cut

sub isBranch {
    my $this = shift;
    return defined $this->isLeaf && !$this->isLeaf;
}

=begin TML

---+++ ObjectMethod isVague => bool

Returns true if node type is yet undetermined.

=cut

sub isVague {
    my $this = shift;
    return !defined $this->isLeaf;
}

=begin TML

---+++ ObjectMethod getValue

A wrapper for =value= and =default= attributes. Returns either =value= if
assigned or =default= otherwise.

=cut

sub getValue {
    my $this = shift;

    return $this->has_value
      ? $this->value
      : ( $this->has_default ? $this->default : undef );
}

=begin TML

---+++ ClassMethod invalidSpecAttr(@attrList) -> $attrName

Returns first invalid spec attribute found in the list. Returns undef otherwise.

This method is dual: it is class and object method at the same time.

=cut

my $attrRx = '(?:' . join( '|', @validSpecAttrs ) . ')';

sub invalidSpecAttr {
    my $class = shift;

    foreach my $attr (@_) {
        return $attr unless $attr =~ /^$attrRx$/;
    }

    return;
}

=begin TML

---+++ ObjectMethod prepareType -> 'TEXT'

Initializer of =type= attribute.

=cut

sub prepareType {
    return 'TEXT';
}

=begin TML

---+++ ObjectMethod _trigger_value

Trigger method of =value= attribute.

=cut

sub _trigger_value {
    my $this = shift;
    my $val  = shift;

    if ( defined $this->isLeaf ) {

        my $tiedVal =
          ref($val) eq 'HASH' && UNIVERSAL::isa( tied(%$val), DATAHASH_CLASS );

        # SMELL Replace with more appropriate exception, similar to
        # Foswiki::Exception::Config::BadSpecData.
        Foswiki::Exception::Config::BadSpecValue->throw(
            text => "Only hashes tied to "
              . DATAHASH_CLASS
              . " can be assigned to non-leaf keys",
            specObject => $this,
        ) if !$this->isLeaf && !$tiedVal;

        Foswiki::Exception::Config::BadSpecValue->throw(
            text => "Attempt to assign hash tied to "
              . DATAHASH_CLASS
              . " to a leaf key",
            specObject => $this,
        ) if $this->isLeaf && $tiedVal;
    }
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
