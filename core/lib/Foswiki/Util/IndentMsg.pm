# See bottom of file for license and copyright information

package Foswiki::Util::IndentMsg;

=begin TML

---+!! Class Foswiki::Util::IndentMsg



---++ SYNOPSIS

---++ DESCRIPTION

=cut

use Foswiki::Class;
extends qw<Foswiki::Object>;
with qw<Foswiki::Util::Localize>;

=begin TML

---++ ATTRIBUTES

=cut

has indentLevel => (
    is      => 'rw',
    default => 0,
);

has indentStr => (
    is      => 'rw',
    default => "    ",
);

around setLocalizeFlags => sub {
    return clearAttributes => 0;
};

=begin TML

---++ METHODS

=cut

sub incLevel {
    my $this   = shift;
    my $holder = $this->localize;
    $this->indentLevel( $this->indentLevel + 1 );
    return $holder;
}

sub indent {
    my $this   = shift;
    my $prefix = $this->indentStr x $this->indentLevel;
    return join( "", map { $prefix . $_ } split /\n/, join( "", @_ ) );
}

around restore => sub {
    my $orig = shift;
    my $this = shift;

    return $orig->( $this, @_ );
};

sub setLocalizableAttributes {
    return qw<indentLevel>;
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
