# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::OP_or
N-ary OR function. Given an expression like a OR b OR c, this operator
will build a single node that has 3 parameters, a, b, and c.

=cut

package Foswiki::Query::OP_or;

use strict;
use warnings;

use Foswiki::Query::OP ();
our @ISA = ('Foswiki::Query::OP');

sub new {
    my $class = shift;

    # Treated as arity 2 for parsing, but folds to n-ary
    return $class->SUPER::new(
        arity   => 2,
        canfold => 1,
        name    => 'or',
        prec    => 100
    );
}

sub evaluate {
    my $this = shift;
    my $node = shift;
    foreach my $i ( @{ $node->{params} } ) {
        return 1 if $i->evaluate(@_);
    }
    return 0;
}

sub evaluatesToConstant {
    my $this      = shift;
    my $node      = shift;
    my $all_const = 1;
    foreach my $i ( @{ $node->{params} } ) {
        my $ac = $i->evaluatesToConstant(@_);
        return 1 if $ac && $i->evaluate(@_);
        $all_const = 0 unless $ac;
    }
    return $all_const;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
