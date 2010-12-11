# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::Parser

Parser for queries

=cut

package Foswiki::Query::Parser;

use strict;
use warnings;
use Assert;

use Foswiki::Infix::Parser ();
our @ISA = ('Foswiki::Infix::Parser');

use Foswiki::Query::Node ();

#             operator name           precedence
use Foswiki::Query::OP_or ();      #  100

use Foswiki::Query::OP_and ();     #  200

use Foswiki::Query::OP_not ();     #  300

use Foswiki::Query::OP_comma ();   #  400

use Foswiki::Query::OP_lte ();     #  500
use Foswiki::Query::OP_gt ();      #  500
use Foswiki::Query::OP_gte ();     #  500
use Foswiki::Query::OP_lt ();      #  500
use Foswiki::Query::OP_match ();   #  500
use Foswiki::Query::OP_eq ();      #  500
use Foswiki::Query::OP_like ();    #  500
use Foswiki::Query::OP_ne ();      #  500
use Foswiki::Query::OP_in ();      #  500

use Foswiki::Query::OP_plus ();    #  600
use Foswiki::Query::OP_minus ();   #  600

use Foswiki::Query::OP_times ();   #  700
use Foswiki::Query::OP_div ();     #  700

use Foswiki::Query::OP_ref ();     #  800
use Foswiki::Query::OP_dot ();     #  800

use Foswiki::Query::OP_where ();   #  900

use Foswiki::Query::OP_lc ();      # 1000
use Foswiki::Query::OP_uc ();      # 1000
use Foswiki::Query::OP_d2n ();     # 1000
use Foswiki::Query::OP_length ();  # 1000
use Foswiki::Query::OP_neg ();     # 1000
use Foswiki::Query::OP_int ();     # 1000

use Foswiki::Query::OP_ob ();      # 1100

=begin TML
Query Language BNF
<verbatim>
expr ::= and_expr 'or' expr | and_expr;
and_expr ::= not_expr 'and' and_expr | not_expr;
not_expr ::= 'not' comma_expr | comma_expr;
comma_expr ::= cmp_expr ',' comma_expr | cmp_expr;
cmp_expr ::= add_expr cmp_op cm_expr | add_expr;
cmp_op ::= '<=' | '>=' | '<' | '>' | '=' | '=~' | '~' | '!=' | 'in';
add_expr ::= mul_expr add_op add_expr | mul_expr;
mul_expr ::= ref_expr mul_op mul_expr | ref_expr;
mul_op ::= '*' | 'div';
ref_expr ::= u_expr ref_op ref_expr | u_expr;
ref_op ::= '/' | '.';
u_expr ::= value uop u_expr | value;
uop ::= 'lc' | 'uc' | 'd2n' | 'length' | '-' | 'int' | '@';
value ::= <name> | <string> | <number>;
</verbatim>
=cut

# Operators
#
# In the following, the standard InfixParser node structure is extended by
# one field, 'exec'.
#
# exec is the name of a member function of the 'Query' class that evaluates
# the node. It is called on the node and is passed a $domain. The $domain
# is a reference to a hash that contains the data being operated on, and a
# reference to the meta-data of the topic being worked on (this is
# effectively the "topic object"). The data being operated on can be a
# Meta object, a reference to an array (such as attachments), a reference
# to a hash (such as TOPICINFO) or a scalar. Arrays can contain other arrays
# and hashes.

# List of operators permitted in structured search queries.
# Each operator is implemented by a class in Foswiki::Query. Note that
# OP_empty is *not* included here; it is a pseudo-operator and does
# not participate in parsing.
use constant OPS => qw (match and eq lc lte not ref d2n gte length lt ob
                        uc dot gt like ne or where comma plus minus
                        neg times div in int );
sub new {
    my ( $class, $options ) = @_;

    $options->{words}     ||= qr/([A-Z:][A-Z0-9_:]*|({[A-Z][A-Z0-9_]*})+)/i;
    $options->{nodeClass} ||= 'Foswiki::Query::Node';
    my $this = $class->SUPER::new($options);
    foreach my $op ( OPS() ) {
	my $on = 'Foswiki::Query::OP_'.$op;
        $this->addOperator( $on->new() );
    }
    return $this;
}

# Ensure there is at least one operand on the opstack when closing
# a subexpression.
sub onCloseExpr {
    my ($this, $opands) = @_;
    if (!scalar(@$opands)) {
	require Foswiki::Query::OP_empty;
	push( @$opands, $this->{client_class}->emptyExpression() );
    }
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
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
