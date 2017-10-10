# See bottom of file for license and copyright information

=begin TML
---+!! Class Foswiki::Exception::Ext

Base class for Foswiki::ExtManager-related exceptions.

Generic. Must not be used directly.

=cut

package Foswiki::Exception::Ext;

use Foswiki::Class;
extends qw<Foswiki::Exception>;

=begin TML

---+++ ObjectAttribute extension => string

Extension name.

=cut

has extension => (
    is        => 'ro',
    predicate => 1,

    # Coerce a ref into class name.
    coerce => sub { ref( $_[0] ) // $_[0] },
);

around prepareText => sub {
    my $orig = shift;
    my $this = shift;

    return $this->has_extension
      ? "Reported extension: " . $this->extension
      : "No reported extension";
};

# Preload exceptions
#use Foswiki::Exception::Ext::BadName;
#use Foswiki::Exception::Ext::Load;

END {
    use Foswiki;
    for my $m (qw<BadName Load Last Restart>) {
        Foswiki::load_class("Foswiki::Exception::Ext::$m");
    }
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
