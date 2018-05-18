# See bottom of file for license and copyright information

package Foswiki::Config::Section;

=begin TML

---+!! Class Foswiki::Config::Section

Class defining config specs section

---++ DESCRIPTION

This class is generated from _-section_ option in specs data. A section is a
group of configuration values united by a common property. For example, a
_File System_ section would contain all configuration specs related to file
system settings like directory locations, permissions, etc.

The configuration UI would then split sections in whatever it considers good
for a system administrator: into tabs, pages, chapters, or anything else we
can't think of right now.

=cut

use Try::Tiny;

use Foswiki::Class -app, -types;
extends qw(Foswiki::Object);
with qw(Foswiki::Config::ItemRole);

use overload '""' => 'to_str';

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute sections

List of subsections: child (in other words: lower level) sections of this
section.

=cut

has sections => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    clearer   => 1,
    builder   => 'prepareSections',
);

=begin TML

---+++ ObjectAttribute nodes

List of spec nodes (items representing configuration keys) belonging to this
section.

=cut

has nodes => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareNodes',
);

=begin TML

---+++ ObjectAttribute level

Level number of this section. The root section level is 0, top-level sections
visible to the user are starting at level 1.

=cut

has level => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareLevel',
);

=begin TML

---+++ ObjectAttribute _secIndex

Hash of subsections defined by their names and pointing to their related
objects.

=cut

has _secIndex => (
    is      => 'rw',
    lazy    => 1,
    builder => '_prepareSecIndex',
    assert  => HashRef,
);

=begin TML

---++ METHODS

=cut

=begin TML

---+++ ObjectMethod subSection( $name [, %profile ] ) -> $sectionObject

Creates a new child section with =$name= or returns an existing one. If a new
one is created then =@profile= is passed into the constructor.

<verbatim>
$section->subSection('Extensions', text => 'Description',);
</verbatim>

A newly created section object is recorded in =_secIndex= attribute. For this
reason manual section creation is not recommended.

If =%profile= contains =text= key and it is not _undef_ then the text will be
appended to the =text= option of the pre-existing section.

=cut

sub subSection {
    my $this = shift;
    my $name = shift;

    my $secObj;
    if ( $this->_secIndex->{$name} ) {
        my %profile = @_;

        $secObj = $this->_secIndex->{$name};

        if ( defined $profile{text} ) {
            $secObj->addText( $profile{text} );
        }
    }
    else {

        $secObj = $this->create(
            'Foswiki::Config::Section',
            name   => $name,
            parent => $this,
            @_
        );

        push @{ $this->sections }, $secObj;
        $this->_secIndex->{$name} = $secObj;
    }
    return $secObj;
}

=begin TML

---+++ ObjectMethod find( $name [, $level] ) -> $sectionObject

Finds a section with =$name=. If =$level= is defined then only sections at that
level are matched. If there is no section with such =$name= (at the =$level=
perhaps) then _undef_ is returned.

=cut

sub find {
    my $this = shift;
    my ( $name, $level ) = @_;

    my $secIdx = $this->_secIndex;

    if ( defined $level ) {
        my $myLevel = $this->level;

        return undef if $myLevel > $level;
        return $this if ( $myLevel == $level ) && $name eq $this->name;

        # Check against children if they're at requested level.
        return $secIdx->{$name} if ( $myLevel + 1 ) == $level;
    }
    else {
        return $this if $name eq $this->name;
    }

    # If we've got at this point then it's up to our children to find the
    # suspect.
    foreach my $child ( @{ $this->sections } ) {
        my $suspect = $child->find(@_);
        return $suspect if defined $suspect;
    }

    # Section not found at this branch.
    return undef;
}

around to_str => sub {
    my $orig = shift;
    my $this = shift;
    return $this->name;
};

around setOpt => sub {
    my $orig = shift;
    my $this = shift;
    my @args = @_;

    try {
        $orig->( $this, @args );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

        # The Foswiki::Config::ItemRole::setOpt throws raw BadSpecData exception
        # because it generaly knows nothing about the object it's ran against.
        # We shall complete the exception information to provide user with more
        # details about the problem.
        if (   $e->isa('Foswiki::Exception::Config::BadSpec')
            && $this->parent
            && $this->parent->level > 0 )
        {
            $e->section( $this->parent );
        }

        $e->rethrow;
    };
};

# TODO Document the options.
around optionDefinitions => sub {
    my $orig = shift;
    return (
        $orig->(@_),
        expert => { arity => 0, }
        ,    # TODO Combine with node's same name option and move to ItemRole?
        modprefix  => { arity => 1, },
        expandable => { arity => 1, },
        section    => { arity => 2, },
    );
};

=begin TML

---+++ ObjectMethod prepareLevel()

Initializer for =level= attribute.

=cut

sub prepareLevel {
    my $this = shift;

    if ( $this->parent ) {
        return $this->parent->level + 1;
    }

    return 0;
}

=begin TML

---+++ ObjectMethod prepareSections()

Initializer for =sections= attribute.

=cut

sub prepareSections {
    return [];
}

=begin TML

---+++ ObjectMethod prepareNodes()

Initializer for =nodes= attribute.

=cut

sub prepareNodes {
    return [];
}

=begin TML

---+++ ObjectMethod prepareParent

Initializer for =Foswiki::Config::ItemRole= =parent= attribute.

=cut

# Cannot use =stubMethods= for prepareParent because a role is being applied
# before =stubMethods= gets called.
sub prepareParent {
    return undef;
}

=begin TML

---+++ ObjectMethod _prepareSecIndex()

Initializer for =_secIndex= attribute.

=cut

sub _prepareSecIndex {
    return {};
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
