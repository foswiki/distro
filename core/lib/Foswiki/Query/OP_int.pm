# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::OP_int

=cut

package Foswiki::Query::OP_int;

use strict;
use warnings;

use Foswiki::Query::UnaryOP ();
our @ISA = ('Foswiki::Query::UnaryOP');

sub new {
    my $class = shift;
    return $class->SUPER::new( name => 'int', prec => 1000 );
}

sub evaluate {
    my $this = shift;
    my $node = shift;

    my $a = $node->{params}[0]->evaluate(@_);
    return $this->collect(
        $a,
        sub {
            defined $_[0]
              ? Foswiki::Query::OP::isNumber( $_[0] )
                  ? int( $_[0] )
                  : 0
              : undef;
        }
    );
}

sub evaluatesToConstant {
    my $this = shift;
    my $node = shift;
    return $node->{params}[0]->evaluatesToConstant(@_);
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
