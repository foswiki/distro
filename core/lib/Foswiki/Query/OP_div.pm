# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::OP_div

=cut

package Foswiki::Query::OP_div;

use strict;
use warnings;

use Foswiki::Query::OP ();
our @ISA = ('Foswiki::Query::OP');

sub new {
    my $class = shift;
    return $class->SUPER::new( arity => 2, name => 'div', prec => 700 );
}

sub evaluate {
    my $this = shift;
    my $node = shift;

    # Item10889: The short-circuit || 0 is probably okay, '/' is numeric anyway
    my $a = $node->{params}[0]->evaluate(@_) || 0;
    my $b = $node->{params}[1]->evaluate(@_) || 0;

    return 0
      unless ( Foswiki::Query::OP::isNumber($a)
        && Foswiki::Query::OP::isNumber($b) );
    return $a / $b;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
