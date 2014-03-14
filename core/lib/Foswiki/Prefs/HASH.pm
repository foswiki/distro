# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Prefs::HASH

This is a simple preferences backend that keeps keys and values as an in-memory
hash.

=cut

# See documentation on Foswiki::Prefs::BaseBackend to get details about the
# methods.

package Foswiki::Prefs::HASH;

use strict;
use warnings;

use Foswiki::Prefs::BaseBackend ();
our @ISA = qw(Foswiki::Prefs::BaseBackend);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my ( $proto, $values ) = @_;

    my $this = $proto->SUPER::new();
    while ( my ( $key, $value ) = each %$values ) {
        $this->insert( 'Set', $key, $value );
    }

    return $this;
}

sub finish { }

sub prefs {
    my $this = shift;
    return keys %$this;
}

sub localPrefs {
    return ();
}

sub get {
    my ( $this, $key ) = @_;
    return $this->{$key};
}

sub getLocal {
    return;
}

sub insert {
    my ( $this, $type, $key, $value ) = @_;

    $this->cleanupInsertValue( \$value );
    $this->{$key} = $value;
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
