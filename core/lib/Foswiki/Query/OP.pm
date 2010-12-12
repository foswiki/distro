# See bottom of file for license and copyright information
package Foswiki::Query::OP;

use strict;
use warnings;

# Does not need to subclass, but is a subclass of...
#use Foswiki::Infix::OP ();
#our @ISA = ( 'Foswiki::Infix::OP' );

sub new {
    my ( $class, %opts ) = @_;
    return bless( \%opts, $class );
}

# Does this operator evaluate to a constant?
# See Foswiki::Query::Node::evaluatesToConstant
sub evaluatesToConstant {
    return 0;
}

# Determine if a string represents a valid number
sub isNumber {
    return shift =~ m/^[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?$/;
}

=begin TML

---++ collect($a, $fn)

Invokes $fn once for each element of $a.

=cut

sub collect {
    my ($this, $a, $fn) = @_;
    if (ref($a) eq 'ARRAY') {
	my @b = map { $this->collect($_, $fn) } @$a;
	return \@b;
    } elsif (ref($a) eq 'HASH') {
	die "Can't collect on a hash";
    } else {
	return &$fn($a);
    }
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

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
