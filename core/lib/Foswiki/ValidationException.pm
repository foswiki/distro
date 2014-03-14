# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::ValidationException

Exception used raise a validation error. See also Foswiki::Validation.

=cut

package Foswiki::ValidationException;
use strict;
use warnings;
use Error ();
our @ISA = ('Error');    # base class

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new( $action )
Constructor

=cut

sub new {
    my ( $class, $action ) = @_;
    return bless( { action => $action }, $class );
}

=begin TML

---++ ObjectMethod stringify() -> $string

Generate a summary string. This is mainly for debugging.

=cut

sub stringify {
    my $this = shift;
    return
      "ValidationException ($this->{action}): Key is invalid or has expired";
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
