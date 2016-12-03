# See bottom of file for license and copyright information

package Foswiki::Config::Section;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);

use overload '""' => 'to_str';

has name => (
    is       => 'ro',
    required => 1,
);

has text => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    builder   => 'prepareText',
);

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

# Default prefix for checkers, wizards and similar modules.
has modprefix => (
    is        => 'rw',
    predicate => 1,
    clearer   => 1,
);

has _secIndex => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareSecIndex',
    isa     => Foswiki::Object::isaHASH( '_secIndex', noUndef => 1, ),
);

has parent => (
    is       => 'rw',
    lazy     => 1,
    weak_ref => 1,
    builder  => 'prepareParent',
    isa => Foswiki::Object::isaCLASS( 'parent', 'Foswiki::Config::Section' ),
);

stubMethods qw(prepareText prepareParent);

sub prepareSecIndex {
    return {};
}

sub prepareSubSections {
    return [];
}

sub prepareNodes {
    return [];
}

# Creates a new section or returns existing one
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

sub addText {
    my $this = shift;

    $this->text( join( "\n\n", $this->text, map { $_ // '' } @_ ) );
}

around to_str => sub {
    my $orig = shift;
    my $this = shift;
    return $this->name;
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
