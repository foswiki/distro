# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::OP_where

=cut

package Foswiki::Query::OP_where;

use strict;
use warnings;

use Foswiki::Query::OP ();
our @ISA = ('Foswiki::Query::OP');

sub new {
    my $class = shift;
    return $class->SUPER::new(
        arity => 2,
        name  => '[',
        close => ']',
        prec  => 900
    );
}

sub evaluate {
    my $this   = shift;
    my $node   = shift;
    my %domain = @_;

    my $lhs_node = $node->{params}[0];

    # See Foswiki/Query/Node.pm for an explanation of restricted names
    my $lhs_values = $lhs_node->evaluate( restricted_name => 1, @_ );
    $lhs_values = [$lhs_values] unless ( ref($lhs_values) eq 'ARRAY' );

    my $rhs_node = $node->{params}[1];
    my @res;
    if ( ref( $rhs_node->{op} ) eq 'Foswiki::Query::OP_comma' ) {

        # We have an array on the RHS. We apply the op to each item
        # on the RHS, passing in the complete LHS. This way, the operation
        # [a,b,c] WHERE [1,3] -> [a,c]
        # This process permits duplication of entries in the result.
        foreach my $rhs_item ( @{ $rhs_node->{params} } ) {
            $this->_evaluate_for_RHS( $lhs_values, $rhs_item, \%domain, \@res );
        }
    }
    else {
        $this->_evaluate_for_RHS( $lhs_values, $rhs_node, \%domain, \@res );
    }
    return unless scalar(@res);
    return \@res;
}

# Give a set of values on the LHS of a where, and a single constraint
# on the RHS, create a set of results. The results are selected from the
# LHS, by index. For example, given [a,b,c] WHERE d then if d evaluates
# to a constant integer, then it is taken as an index into [a,b,c]. Otherwise
# it is evaluated and if it returns true, then the LHS entry at the
# corresponding position is returned. So:
# [a,b,c] WHERE 1 -> [b]
# [a,b,c] WHERE name!='b' -> [a,c]
sub _evaluate_for_RHS {
    my ( $this, $lhs_values, $rhs_node, $domain, $res ) = @_;

    # See if we have an index on the RHS
    my $rhs_constant = -1;
    if ( $rhs_node->evaluatesToConstant(%$domain) ) {
        $rhs_constant = $rhs_node->evaluate(%$domain);
        if ( Foswiki::Query::OP::isNumber($rhs_constant) ) {

            # Handle negative indices
            $rhs_constant += scalar(@$lhs_values) if ( $rhs_constant < 0 );

            # Trunc to integer
            $rhs_constant = int($rhs_constant);

            # Don't bother if integer index is out of range
            return
              unless $rhs_constant >= 0
              && $rhs_constant < scalar(@$lhs_values);
        }
        else {
            $rhs_constant = -1;    # unmatchable
        }
    }

    # For each item on the LHS
    my $i = 0;                     # LHS index
    foreach my $lhs_value (@$lhs_values) {
        if (   $rhs_constant < 0
            && $rhs_node->evaluate( data => $lhs_value, tom => $domain->{tom} )
          )
        {
            push( @$res, $lhs_value );
        }
        elsif ( $i == $rhs_constant ) {

            # Special case; integer index responds with array el at that index
            push( @$res, $lhs_value );
        }
        $i++;
    }
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
