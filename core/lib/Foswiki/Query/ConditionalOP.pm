# See bottom of file for license and copyright information
package Foswiki::Query::ConditionalOP;

=begin TML

---+ package Foswiki::Query::ConditionalOP
Base class for binary conditional operators.

=cut

use strict;
use warnings;
use Foswiki::Query::OP;
our @ISA = ('Foswiki::Query::OP');

sub new {
    my $class = shift;
    return $class->SUPER::new( arity => 2, @_ );
}

=begin TML

---++ StaticMethod compare($a, $b, \&fn) -> $boolean

Apply a binary comparison function to two data, tolerant
of whether they are numeric or not. =\&fn= takes a single parameter,
which is the result of a =<=>= comparison on =$a= and =$b=. The result
of applying =\&fn= is returned.

=cut

sub compare {
    my ( $a, $b, $sub ) = @_;
    if ( !defined($a) ) {
        return &$sub(0) unless defined($b);
        return -&$sub(1);
    }
    elsif ( !defined($b) ) {
        return &$sub(1);
    }
    if (   Foswiki::Query::OP::isNumber($a)
        && Foswiki::Query::OP::isNumber($b) )
    {
        return &$sub( $a <=> $b );
    }
    else {
        return &$sub( $a cmp $b );
    }
}

=begin TML

---++ ObjectMethod evalTest($node, $clientData, \&fn) -> $result
Evaluate a node using the comparison function passed in. Extra parameters
are passed on to the comparison function. If the LHS of the node
evaluates to an array, the result will be an array made by
applying =\&fn= to each member of the LHS array. The RHS is passed on
untouched to \&fn. Thus =(1,-1) > 1= will yield (1,0)

=cut

sub evalTest {
    my $this       = shift;
    my $node       = shift;
    my $clientData = shift;
    my $sub        = shift;
    my $a          = $node->{params}[0];
    my $b          = $node->{params}[1];
    my $ea         = $a->evaluate( @{$clientData} );
    my $eb         = $b->evaluate( @{$clientData} );
    $ea = '' unless defined $ea;
    $eb = '' unless defined $eb;

    if ( ref($ea) eq 'ARRAY' ) {
        my @res;
        foreach my $lhs (@$ea) {
            push( @res, $lhs ) if &$sub( $lhs, $eb, @_ );
        }
        if ( scalar(@res) == 0 ) {
            return;
        }
        elsif ( scalar(@res) == 1 ) {
            return $res[0];
        }
        return \@res;
    }
    else {
        return &$sub( $ea, $eb, @_ );
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
