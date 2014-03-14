# See bottom of file for license and copyright information
package Foswiki::Query::UnaryOP;

use strict;
use warnings;
use Foswiki::Query::OP;
our @ISA = ('Foswiki::Query::OP');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my $class = shift;
    return $class->SUPER::new( arity => 1, @_ );
}

sub evalUnary {
    my $this = shift;
    my $node = shift;
    my $sub  = shift;
    my $a    = $node->{params}[0]->evaluate(@_);
    return $this->collect( $a, $sub );
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
