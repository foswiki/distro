# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Prefs::HASH

This is a simple preferences backend that keeps keys and values as an in-memory
hash.

=cut

# See documentation on Foswiki::Prefs::BaseBackend to get details about the
# methods.

package Foswiki::Prefs::HASH;
use v5.14;

use Foswiki::Class -types;
extends qw(Foswiki::Object);
with qw( Foswiki::Prefs::BaseBackend );

#our @_newParameters = qw(values);

has _values => (
    is        => 'ro',
    predicate => 1,
    clearer   => 1,
    assert    => HashRef,
    init_arg  => 'values',
);
has _prefs => (
    is      => 'rw',
    clearer => 1,
    lazy    => 1,
    default => sub { {} },
    assert  => HashRef,
);

sub BUILD {
    my $this = shift;
    if ( $this->_has_values ) {
        while ( my ( $key, $value ) = each %{ $this->_values } ) {
            $this->insert( 'Set', $key, $value );
        }
    }

    # _values serve as intermidiate storage only until object constuction is
    # done. No need to waste extra memory on them.
    $this->_clear_values;
}

sub prefs {
    my $this = shift;
    return keys %{ $this->_prefs };
}

sub localPrefs {
    return ();
}

sub get {
    my ( $this, $key ) = @_;
    return $this->_prefs->{$key};
}

sub getLocal {
    return;
}

sub insert {
    my ( $this, $type, $key, $value ) = @_;

    $this->cleanupInsertValue( \$value );
    $this->_prefs->{$key} = $value;
    return 1;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
