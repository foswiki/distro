# See bottom of file for license and copyright information

package Foswiki::Exception::Config::InvalidKeyName;

=begin TML

---+!! Class Foswiki::Exception::Config::InvalidKeyName

Reports about an attempt to use a key name which doesn't conform to the
standards.

=cut

use Foswiki::Class;
extends qw<Foswiki::Exception::Config>;
with qw<Foswiki::Exception::Deadly>;

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute keyName

The key which caused the exception.

=cut

has keyName => ( is => 'rw', required => 1, );

=begin TML

---++ METHODS

=cut

=begin TML

---+++ ObjectMethod stringifyText

Overrides base class method. Appends information about the problematic key.

=cut

around stringifyText => sub {
    my $orig   = shift;
    my $this   = shift;
    my ($text) = @_;

    my $errMsg = $orig->( $this, @_ );
    my $key = $this->keyName;

    $errMsg .= " (the key is:"
      . ( defined $key ? ( ref($key) || $key ) : '*undef*' ) . ")";

    return $errMsg;
};

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
