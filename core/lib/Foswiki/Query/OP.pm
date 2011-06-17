# See bottom of file for license and copyright information
package Foswiki::Query::OP;

=begin TML

---+ package Foswiki::Query::OP
Base class of operators used in queries. Operators are singleton
objects that specify the parser behaviour and are attached to
nodes in the parse tree to provide semantics for the nodes.

See Foswiki::Infix::OP for details of the different options used
to define operator nodes.

=cut

use strict;
use warnings;

# Does not need to subclass, but is a subclass of...
#use Foswiki::Infix::OP ();
#our @ISA = ( 'Foswiki::Infix::OP' );

sub new {
    my ( $class, %opts ) = @_;
    return bless( \%opts, $class );
}

=begin TML

---++ ObjectMethod evaluate($node, %domain) -> $value

Pure virtual method that evaluates the operator in the give domain.
The domain is a reference to a hash that contains the
data being operated on, and a reference to the meta-data of the topic being worked on
(the "topic object"). The data being operated on can be a
Meta object, a reference to an array (such as attachments), a reference
to a hash or a scalar. Arrays can contain other arrays
and hashes.

See Foswiki::Query::Node::evaluate for more information.

=cut

sub evaluate {
    my $this = shift;
    die "Operator '$this->{name}' does not define evaluate()";
}

=begin TML

---++ ObjectMethod evaluatesToConstant() -> $boolean
Does this operator always evaluate to a constant?
See Foswiki::Query::Node::evaluatesToConstant

Used in hoisting/optimisation.

Default behaviour is to call evaluatesAsConstant on all
parameters and return true if they all return true.

=cut

sub evaluatesToConstant {
    my $this = shift;
    my $node = shift;
    foreach my $i ( @{ $node->{params} } ) {
        return 0 unless $i->evaluatesToConstant(@_);
    }
    return 1;
}

=begin TML

---++ StaticMethod isNumber($string) -> $boolean

Determine if a string represents a valid number (signed decimal)

Used in hoisting/optimisation.

=cut

sub isNumber {
    return shift =~ m/^[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?$/;
}

=begin TML

---++ StaticMethod collect($a, $fn) -> []

Invokes $fn once for each element of $a and return an array built from the results.

=cut

sub collect {
    my ( $this, $a, $fn ) = @_;
    if ( ref($a) eq 'ARRAY' ) {
        my @b = map { $this->collect( $_, $fn ) } @$a;
        return \@b;
    }
    elsif ( ref($a) eq 'HASH' ) {
        die "Can't collect on a hash";
    }
    else {
        return &$fn($a);
    }
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
