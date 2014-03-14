# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Infix::Error

Class of errors used with Foswiki::Infix::Parser

=cut

package Foswiki::Infix::Error;

use strict;
use warnings;

use Error ();
our @ISA = ('Error');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my ( $class, $message, $expr, $at ) = @_;
    if ( defined $expr && length($expr) ) {
        $message .= " in '$expr'";
    }
    if ( defined $at && length($at) ) {
        $message .= " at '$at'";
    }
    return $class->SUPER::new(
        -text => $message,
        -file => 'dummy',
        -line => 'dummy'
    );
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
