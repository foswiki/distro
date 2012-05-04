# See bottom of file for copyright and license details

=begin TML

---+ package Foswiki::Contrib::DBIStoreContrib::HoistSQL

Static functions to extract SQL expressions from queries. The SQL can
be used to pre-filter topics cached in an SQL DB for more efficient
query matching.

=cut

package Foswiki::Contrib::DBIStoreContrib::HoistSQL;

use strict;

use Foswiki::Infix::Node ();
use Foswiki::Query::Node ();

# Try to optimise a query by hoisting SQL searches
# out of the query.
#
# patterns we need to look for:
#
# top level is defined by a sequence of AND and OR conjunctions
# second level, operator that can be mapped to SQL
# second level LHS is a field access
# second level RHS is a static string or number
# So, say I have:
# number=99 AND string='String' AND (moved.by='AlbertCamus'
#    OR moved.by ~ '*bert*')
# This can be fully hoisted, to
# SELECT topic.name FROM topic,FIELD,MOVED
# WHERE
#  EXISTS(
#   SELECT tid FROM FIELD
#    WHERE FIELD.tid=topic.tid AND FIELD.name='number' AND FIELD.value=99)
# AND
#  EXISTS(
#   SELECT tid FROM FIELD
#    WHERE FIELD.tid=topic.tid AND FIELD.name='string'
#          AND FIELD.string='String')
# AND (
#   EXISTS(
#    SELECT tid FROM FIELD
#     WHERE MOVED.tid=topic.tid AND MOVED.by='AlbertCamus')
#  OR
#   EXISTS(
#    SELECT tid FROM FIELD
#     WHERE MOVED.tid=topic.tid AND MOVED.by LIKE '%bert%')
# )

use constant MONITOR => 0;

# MUST BE KEPT IN LOCKSTEP WITH Foswiki::Infix::Node
# Declared again here because the constants are not defined
# in Foswiki 1.1 and earlier
use constant {
    NAME   => 1,
    NUMBER => 2,
    STRING => 3,
};

BEGIN {

    # Foswiki 1.1 doesn't have makeConstant; monkey-patch it
    unless ( defined &Foswiki::Infix::Node::makeConstant ) {
        *Foswiki::Infix::Node::makeConstant = sub {
            my ( $this, $type, $val ) = @_;
            $this->{op}     = $type;
            $this->{params} = [$val];
          }
    }
}

=begin TML

---++ ObjectMethod hoist($query) -> $sql_statement

Hoisting consists of assembly of a WHERE clause. There may be a
point where the expression can't be converted to SQL, because some operator
(for example, a date operator) can't be done in SQL. But in most cases
the hoisting allows us to extract a set of criteria that can be AND and
ORed together in an SQL statement sufficient to narrow down and isolate
that subset of topics that might match the query.

The result is a string SQL query, and the $query is modified to replace
the hoisted expressions with constants.

=cut

sub hoist {
    my ( $node, $indent ) = @_;

    return undef unless ref( $node->{op} );

    $indent ||= '';

    if ( $node->{op}->{name} eq '(' ) {
        return hoist( $node->{params}[0], "$indent(" );
    }

    print STDERR "${indent}hoist ", $node->stringify(), "\n" if MONITOR;
    if ( $node->{op}->{name} eq 'and' ) {
        my $lhs = hoist( $node->{params}[0], "${indent}l" );
        my $rhs = _hoistB( $node->{params}[1], "${indent}r" );
        if ( $lhs && $rhs ) {
            $node->makeConstant( NUMBER, 1 );
            print STDERR "${indent}L&R\n" if MONITOR;
            return "($lhs) AND ($rhs)";
        }
        elsif ($lhs) {
            $node->{params}[0]->makeConstant( NUMBER, 1 );
            print STDERR "${indent}L\n" if MONITOR;
            return $lhs;
        }
        elsif ($rhs) {
            $node->{params}[1]->makeConstant( NUMBER, 1 );
            print STDERR "${indent}R\n" if MONITOR;
            return $rhs;
        }
    }
    else {
        my $or = _hoistB( $node, "${indent}|" );
        if ($or) {
            $node->makeConstant( NUMBER, 1 );
            return $or;
        }
    }

    print STDERR "\tFAILED\n" if MONITOR;
    return undef;
}

sub _hoistB {
    my ( $node, $indent ) = @_;

    return unless ref( $node->{op} );

    if ( $node->{op}->{name} eq '(' ) {
        return _hoistB( $node->{params}[0], "${indent}(" );
    }

    print STDERR "${indent}OR ", $node->stringify(), "\n" if MONITOR;

    if ( $node->{op}->{name} eq 'or' ) {
        my $lhs = _hoistB( $node->{params}[0], "${indent}l" );
        my $rhs = _hoistC( $node->{params}[1], "${indent}r", 0 );
        if ( $lhs && $rhs ) {
            print STDERR "${indent}L&R\n" if MONITOR;
            return "(($lhs) OR ($rhs))";
        }
    }
    else {
        return _hoistC( $node, "${indent}|", 0 );
    }

    return undef;
}

sub _hoistC {
    my ( $node, $indent, $negated ) = @_;

    return undef unless ref( $node->{op} );

    my $op = $node->{op}->{name};
    if ( $op eq '(' ) {
        return _hoistC( $node->{params}[0], "${indent}(", $negated );
    }

    print STDERR "${indent}EQ ", $node->stringify(), "\n" if MONITOR;
    my ( $lhs, $rhs, $table, $test );

    if ( $op eq 'not' ) {
        return _hoistC( $node->{params}[0], "${indent}(", !$negated );
    }
    elsif ( $op eq '=' || $op eq '!=' ) {
        ( $lhs, $table ) = _hoistValue( $node->{params}[0], "${indent}l" );
        $rhs = _hoistConstant( $node->{params}[1] );
        if ( !$lhs || !$rhs ) {

            # = and != are symmetric, so try the other order
            ( $lhs, $table ) = _hoistValue( $node->{params}[1], "${indent}r" );
            $rhs = _hoistConstant( $node->{params}[0] );
        }
        if ( $lhs && $rhs ) {
            print STDERR "${indent}R=L\n" if MONITOR;
            $test = "$lhs$op'$rhs'";
            $test = "NOT($test)" if $negated;
        }
    }
    elsif ( $op eq '~' ) {
        ( $lhs, $table ) = _hoistValue( $node->{params}[0], "${indent}l" );
        $rhs = _hoistConstant( $node->{params}[1] );
        if ( $lhs && $rhs ) {
            my $escape = '';
            $rhs = quotemeta($rhs);
            if ( $rhs =~ /'/ ) {
                $rhs =~ s/([s'])/s$1/g;
                $escape = " ESCAPE 's'";
            }
            $rhs =~ s/\\\?/./g;
            $rhs =~ s/\\\*/.*/g;
            print STDERR "${indent}L~R\n" if MONITOR;
            $test = "$lhs REGEXP '^(?s:$rhs)\$'$escape";
            $test = "NOT($test)" if $negated;
        }
    }
    elsif ( $op eq '=~' ) {
        ( $lhs, $table ) = _hoistValue( $node->{params}[0], "${indent}l" );
        $rhs = _hoistConstant( $node->{params}[1] );
        if ( $lhs && $rhs ) {
            my $escape = '';
            if ( $rhs =~ /'/ ) {
                $rhs =~ s/([s'])/s$1/g;
                $escape = " ESCAPE 's'";
            }
            print STDERR "${indent}L=~R\n" if MONITOR;
            $test = "$lhs REGEXP '$rhs'$escape";
            $test = "NOT($test)" if $negated;
        }
    }
    if ( $table && $test ) {
        if ( $table ne 'topic' ) {

            # Have to use an EXISTS if the sub-test refers to another table
            return <<SQL;
EXISTS(SELECT * FROM $table WHERE $table.tid=topic.tid AND $test)
SQL
        }
        else {
            return $test;
        }
    }

    return undef;
}

# Expecting a (root level) field access expression. This must be of the form
# <name>
# or
# <rootfield>.<name>
# <rootfield> may be aliased
# Returns a partial SQL statement that can be followed by a condition for
# testing the value.
# A limited set of functions - UPPER, LOWER,
sub _hoistValue {
    my ( $node, $indent ) = @_;
    my $op = ref( $node->{op} ) ? $node->{op}->{name} : '';

    print STDERR "${indent}V ", $node->stringify(), "\n" if MONITOR;

    if ( $op eq '(' ) {
        return _hoistValue( $node->{params}[0] );
    }

    if ( $op eq 'lc' ) {
        my ( $lhs, $table ) = _hoistValue( $node->{params}[0], "${indent}$op" );
        return ( "LOWER($lhs)", $table ) if $lhs;
    }
    elsif ( $op eq 'uc' ) {
        my ( $lhs, $table ) = _hoistValue( $node->{params}[0], "${indent}$op" );
        return ( "UPPER($lhs)", $table ) if $lhs;
    }
    elsif ( $op eq 'length' ) {

        # This is slightly risky, because 'length' also works on array
        # values, but SQL LEN only works on text values.
        my ( $lhs, $table ) = _hoistValue( $node->{params}[0], "${indent}$op" );
        return ( "LENGTH($lhs)", $table ) if $lhs;
    }
    elsif ( $op eq '.' ) {
        my $lhs = $node->{params}[0];
        my $rhs = $node->{params}[1];
        if (   !ref( $lhs->{op} )
            && !ref( $rhs->{op} )
            && $lhs->{op} == NAME
            && $rhs->{op} == NAME )
        {
            $lhs = $lhs->{params}[0];
            $rhs = $rhs->{params}[0];
            if ( $Foswiki::Query::Node::aliases{$lhs} ) {
                $lhs = $Foswiki::Query::Node::aliases{$lhs};
            }
            if ( $lhs =~ /^META:(\w+)/ ) {

                return ( "$1.$rhs", $1 );
            }

            if ( $rhs eq 'text' ) {

                # Special case for the text body
                return ( 'topic.text', 'topic' );
            }

            if ( $rhs eq 'raw' ) {

                # Special case for the text body
                return ( 'topic.raw', 'topic' );
            }

            # Otherwise assume the term before the dot is the form name
            return (
"EXISTS(SELECT * FROM FORM WHERE FORM.tid=topic.tid AND FORM.name='$lhs') AND FIELD.name='$rhs' AND FIELD.value",
                "FIELD"
            );
        }
    }
    elsif ( !ref( $node->{op} ) && $node->{op} == NAME ) {

        # A simple name
        if ( $node->{params}[0] =~ /^(name|web|text|raw)$/ ) {

            # Special case for the topic name, web or text body
            return ( "topic.$1", 'topic' );
        }
        else {
            return ( "FIELD.name='$node->{params}[0]' AND FIELD.value",
                'FIELD' );
        }
    }

    print STDERR "\tFAILED\n" if MONITOR;
    return ( undef, undef );
}

# Expecting a constant
sub _hoistConstant {
    my $node = shift;

    if (
        !ref( $node->{op} )
        && (   $node->{op} == STRING
            || $node->{op} == NUMBER )
      )
    {
        return $node->{params}[0];
    }
    return;
}

1;
__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
