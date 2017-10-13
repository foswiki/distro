# See bottom of file for license and copyright information

package Foswiki::Exception::Config::BadSpec;

=begin TML

---+!! Class Foswiki::Exception::Config::BadSpec

Base class for reporting problems about config specs.

Must not be used directly!

=cut

use Foswiki::Class;
extends qw<Foswiki::Exception::Config>;
with qw<Foswiki::Exception::Deadly>;

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute section

%PERLDOC{"Foswiki::Config::Section"}% object.

=cut

has section => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    builder   => 'prepareSection',
);

=begin TML

---+++ ObjectAttribute key

Full key name of %PERLDOC{"Foswiki::Config::Node"}% object.

=cut

has key => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    builder   => 'prepareKey',
);

=begin TML

---+++ ObjectAttribute nodeObject

%PERLDOC{"Foswiki::Config::Node"}% object.

=cut

has nodeObject => (
    is        => 'rw',
    predicate => 1,
    trigger   => 1,
);

=begin TML

---++ METHODS

=cut

sub BUILD {
    my $this = shift;

    $this->_setFromNodeObject;
}

=begin TML

---+++ ObjectMethod stringify

Overrides base class method.

=cut

around stringify => sub {
    my $orig = shift;
    my $this = shift;

    my $nodeObject = $this->has_nodeObject ? $this->nodeObject : undef;

    # TODO Report sources too.
    my $keyInfo = $this->has_key
      || $nodeObject ? "key '" . $this->key . "' is " : "";

    my $sourceObject =
      defined $nodeObject
      ? $nodeObject
      : ( $this->has_section ? $this->section : undef );
    my $sourceInfo = '';
    if ( $sourceObject && @{ $sourceObject->sources } > 0 ) {
        $sourceInfo = " at "
          . join( ", ",
            map { $_->{file} . ( defined $_->{line} ? ":" . $_->{line} : "" ) }
              @{ $sourceObject->sources } );
    }

    my $sectionInfo =
      $this->has_section || $this->has_nodeObject
      ? " (${keyInfo}defined in section '"
      . $this->section . "'"
      . $sourceInfo . ")"
      : '';

    return $this->stringifyText . $sectionInfo . $this->stringifyPostfix;
};

=begin TML

---+++ ObjectMethod prepareSection

Method initializer of =section= attribute.

=cut

sub prepareSection {
    my $this = shift;

    if ( $this->has_nodeObject ) {
        return $this->nodeObject->section;
    }
}

=begin TML

---+++ ObjectMethod prepareKey

Method initializer of =key= attribute.

=cut

sub prepareKey {
    my $this = shift;

    if ( $this->has_nodeObject ) {
        return $this->nodeObject->fullName;
    }
}

# Sets key and section from nodeObject
sub _setFromNodeObject {
    my $this = shift;

    if ( $this->has_nodeObject ) {

        # Set section and key attrs manually if not set by user. This is to get
        # around a problem where exception is propagaded out of scope where
        # nodeObject's parent is defined making its fullName/fullPath methods
        # useless.
        unless ( $this->has_key ) {
            $this->key( $this->nodeObject->fullName );
        }
        unless ( $this->has_section ) {
            $this->section( $this->nodeObject->section );
        }
    }
}

sub _trigger_nodeObject {
    my $this = shift;

    $this->_setFromNodeObject;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2017 Foswiki Contributors. Foswiki Contributors
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
