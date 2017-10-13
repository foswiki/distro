# See bottom of file for license and copyright information

package Foswiki::Exception::Ext::Load;

=begin TML

---+!! Class Foswiki::Exception::Ext::Load

Raised when extension fails to load.

=cut

use Foswiki::Class;
extends qw(Foswiki::Exception::Ext);

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute reason -> string

Error string explaining why loading failed.

=cut

has reason => (
    is       => 'rw',
    required => 1,
);

=begin TML

---++ METHODS

=cut

=begin TML

---+++ ObjectMethod prepareText

Overrides base class method.

=cut

around prepareText => sub {
    my $orig = shift;
    my $this = shift;

    return
        "Failed to load extension '"
      . $this->extension . "': "
      . $this->reason;
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
