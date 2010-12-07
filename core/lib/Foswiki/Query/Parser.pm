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

use Foswiki::Query::OP_match ();
use Foswiki::Query::OP_and ();
use Foswiki::Query::OP_eq ();
use Foswiki::Query::OP_lc ();
use Foswiki::Query::OP_lte ();
use Foswiki::Query::OP_not ();
use Foswiki::Query::OP_ref ();
use Foswiki::Query::OP_d2n ();
use Foswiki::Query::OP_gte ();
use Foswiki::Query::OP_length ();
use Foswiki::Query::OP_lt ();
use Foswiki::Query::OP_ob ();
use Foswiki::Query::OP_uc ();
use Foswiki::Query::OP_dot ();
use Foswiki::Query::OP_gt ();
use Foswiki::Query::OP_like ();
use Foswiki::Query::OP_ne ();
use Foswiki::Query::OP_or ();
use Foswiki::Query::OP_where ();
use Foswiki::Query::OP_at ();
use Foswiki::Query::OP_comma ();
use Foswiki::Query::OP_plus ();
use Foswiki::Query::OP_minus ();
use Foswiki::Query::OP_neg ();
use Foswiki::Query::OP_unaryat ();
use Foswiki::Query::OP_times ();
use Foswiki::Query::OP_div ();
use Foswiki::Query::OP_in ();
use Foswiki::Query::OP_int ();

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
                        uc dot gt like ne or where at comma plus minus
                        neg unaryat times div in int );
sub new {
    my ( $class, $options ) = @_;

    $options->{words}     ||= qr/([A-Z][A-Z0-9_:]*|({[A-Z][A-Z0-9_]*})+)/i;
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
