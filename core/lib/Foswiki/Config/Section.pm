# See bottom of file for license and copyright information

package Foswiki::Config::Section;

use Try::Tiny;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);
with qw(Foswiki::Config::ItemRole);

use overload '""' => 'to_str';

has sections => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    clearer   => 1,
    builder   => 'prepareSubSections',
);

has nodes => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareNodes',
);

has level => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareLevel',
);

has _secIndex => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareSecIndex',
    isa     => Foswiki::Object::isaHASH( '_secIndex', noUndef => 1, ),
);

sub prepareSecIndex {
    return {};
}

sub prepareSubSections {
    return [];
}

sub prepareNodes {
    return [];
}

=begin TML

---+++ ObjectMethod prepareParent

Initializer for =Foswiki::Config::ItemRole= =parent= attribute.

=cut

# Cannot use =stubMethods= for prepareParent because role is being applied before
# =stubMethods= gets called.
sub prepareParent {
    return undef;
}

sub prepareLevel {
    my $this = shift;

    if ( $this->parent ) {
        return $this->parent->level + 1;
    }

    return 0;
}

# Creates a new child section or returns existing one
# $section->subSection('Extensions', text => 'Description',);
sub subSection {
    my $this = shift;
    my $name = shift;

    my $secObj;
    if ( $this->_secIndex->{$name} ) {
        my %profile = @_;

        $secObj = $this->_secIndex->{$name};

        if ( $profile{text} ) {
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

# Returns section object with name $name. If $level defined then it must match
# object's level too.
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

around optionDefinitions => sub {
    my $orig = shift;
    return (
        $orig->(@_),
        expert    => { arity => 0, },
        modprefix => { arity => 1, },
        pluggable => { arity => 1, },
        section   => { arity => 2, },
    );
};

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
