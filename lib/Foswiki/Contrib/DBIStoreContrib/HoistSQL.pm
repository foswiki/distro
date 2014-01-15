# See bottom of file for copyright and license details

=begin TML

---+ package Foswiki::Contrib::DBIStoreContrib::HoistSQL

Static functions to extract SQL expressions from queries. The SQL can
be used to pre-filter topics cached in an SQL DB for more efficient
query matching.

=cut

=pod

For SQL, at any given point, we need to know the table that is being referenced,the WHERE condition, and the rows being selected from the table.

[ takes a table and a WHERE, and returns a table
. takes a table and a name, and returns a SELECT

>= takes a SELECT and a constant (or a constant and a select, or a select and a select, or a constant and a constant) and returns WHERE

AND takes a WHERE and a WHERE and returns a compound WHERE

Rewriting based on precedence
Adjust precedence before the parse?

=cut

package Foswiki::Contrib::DBIStoreContrib::HoistSQL;

use strict;
use Assert;

use Foswiki::Contrib::DBIStoreContrib ();
use Foswiki::Infix::Node              ();
use Foswiki::Query::Node              ();
use Foswiki::Query::Parser            ();

# A Foswiki query parser
our $parser;

use constant MONITOR =>
  Foswiki::Store::QueryAlgorithms::DBIStoreContrib::MONITOR;

# FIRST 3 MUST BE KEPT IN LOCKSTEP WITH Foswiki::Infix::Node
# Declared again here because the constants are not defined
# in Foswiki 1.1 and earlier
use constant {
    NAME   => 1,
    NUMBER => 2,
    STRING => 3,

    TABLE_NAME => 4,
    SELECTOR   => 5
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

This top-level method hoists SQL from a query. The return value
is a valid, stand-alone SQL query. The query is modified on-the-fly
to replace any hoisted parts with unconditional true/false values.

=cut

my %bop_map = (
    and  => 'AND',
    or   => 'OR',
    '='  => '=',
    '!=' => '!=',
    '<'  => '<',
    '>'  => '>',
);

my %uop_map = (
    not    => 'NOT',
    lc     => 'LOWER',
    uc     => 'UPPER',
    length => 'LENGTH'
);

use constant {
    EXPR  => 1,
    TABLE => 2
};

my $tempTable = 0;

sub hoist {
    my ( $node, $control, $type ) = @_;
    $type ||= EXPR;    # query algorithm wants a table

    my $op = $node->{op}->{name} if ref( $node->{op} );

    my $res;
    if ( !ref( $node->{op} ) ) {
        $res = _constant( $node, 1, $control );
        if ( $type == EXPR ) {
        }
        else {
        }
    }
    elsif ( $bop_map{$op} ) {
        my $lhs = hoist( $node->{params}[0], $control, EXPR );
        my $rhs = hoist( $node->{params}[1], $control, EXPR );
        $lhs = "($lhs)" if ref( $node->{params}[0]->{op} );
        $rhs = "($rhs)" if ref( $node->{params}[1]->{op} );
        $res = "$lhs $bop_map{$op} $rhs";
        ASSERT( $type == EXPR, $node->stringify() );
    }
    elsif ( $uop_map{$op} ) {
        my $child = hoist( $node->{params}[0], $control );
        $res = "$uop_map{$op}($child)";
        ASSERT( $type == EXPR, $node->stringify() );
    }
    elsif ( $op eq '[' ) {
        my $lhs = hoist( $node->{params}[0], $control, TABLE );
        my $t1;
        if ( $lhs =~ /^\w+$/ ) {    # simple table name
            $t1 = $lhs;
        }
        else {

            # Use temporary table
            $t1 = 't' . ( $tempTable++ );
            $lhs = "($lhs) AS $t1";
        }
        my %sc = %$control;
        $sc{table} = $t1;
        my $where = hoist( $node->{params}[1], \%sc, EXPR );
        $res =
          "SELECT * from $lhs WHERE $t1.tid=$control->{table}.tid AND $where";
        $res = "EXISTS($res)" if ( $type == EXPR );
    }
    elsif ( $op eq '.' ) {
        my $lhs = hoist( $node->{params}[0], $control, TABLE );
        my $t1;
        if ( $lhs =~ /^\w+$/ ) {    # simple table name
            $t1 = $lhs;
        }
        else {

            # Use temporary table
            $t1 = 't' . ( $tempTable++ );
            $lhs = "($lhs) AS $t1";
        }
        my %sc = %$control;
        $sc{table} = $t1;
        my $where = hoist( $node->{params}[1], \%sc, EXPR );
        $res =
          "SELECT * FROM $lhs WHERE $t1.tid=$control->{table}.tid AND $where";
        $res = "EXISTS($res)" if ( $type == EXPR );
    }
    elsif ( $op eq '/' ) {

        # A lookup in another topic
        my $sc = {
            table   => $control->{table},
            iwebs   => $control->{iweb},
            itopics => [ _constant( $node->{params}[0], 0 ) ]
        };
        $res = hoist( $node->{params}[1], $sc, EXPR );
    }
    else {
        ASSERT( 0, "Don't know how to hoist $op" . recreate($node) );
    }
    print STDERR "HOISTED " . recreate($node) . " ->\n$res\n" if MONITOR;
    return $res;
}

# All tables have a tid, so we can collect the tables used and make sure they
# all have the same tid.

sub _constant {
    my ( $node, $quote, $control ) = @_;
    ASSERT( !ref( $node->{op} ) ) if DEBUG;
    if ( $node->{op} eq STRING ) {
        return $quote ? "\"$node->{params}[0]\"" : $node->{params}[0];
    }
    elsif ( $node->{op} == NAME ) {

        # A simple name
        my $name = $node->{params}[0];
        if ( $name =~ /^META:(\w+)/ ) {

            # Name of a table
            return $quote ? "'$1'" : $1;
        }
        else {

            # Name of a field
            return "$control->{table}.$name";
        }
    }
    else {
        return $node->{params}[0];
    }
}

# Expand web and topic limits to SQL expressions
sub _expand_controls {
    my $control = shift;
    my @exprs;
    if ( $control->{iwebs} ) {
        push( @exprs, _expand_relist( $control->{iwebs}, 'web', 0 ) );
    }
    if ( $control->{ewebs} ) {
        push( @exprs, _expand_relist( $control->{ewebs}, 'web', 1 ) );
    }
    if ( $control->{itopics} ) {
        push( @exprs, _expand_relist( $control->{itopics}, 'name', 0 ) );
    }
    if ( $control->{etopics} ) {
        push( @exprs, _expand_relist( $control->{etopics}, 'name', 0 ) );
    }
    my $controls = join( ' AND ', @exprs );
    return '' unless $controls;
    return "(tid IN (SELECT tid FROM topic WHERE $controls))";
}

# Expand a literal or regex list, used for matching topic and web names, to
# an SQL expression
sub _expand_relist {
    my ( $list, $column, $negate ) = @_;

    my @exprs;
    my @in;
    foreach my $s (@$list) {
        ASSERT( defined $s ) if DEBUG;
        my $q = quotemeta($s);
        if ( $q ne $s ) {
            push(
                @exprs,
                Foswiki::Contrib::DBIStoreContrib::DBIStore::personality
                  ->wildcard(
                    $column, $s
                  )
            );
        }
        else {
            push( @in, $s );
        }
    }
    if ( scalar(@in) ) {
        push( @exprs,
            "$column IN ( " . join( ',', map { "\"$_\"" } @in ) . ')' );
    }
    return ( $negate ? 'NOT' : '' ) . '(' . join( ' AND ', @exprs ) . ')';
}

=begin TML

Rewrite a Foswiki query parse tree to eliminate certain types
of subexpression, and so simplify subsequent SQL extraction.

   * X -> fields[name='X'].value
   * info.Y -> META:TOPICINFO.Y
   * formname.Y -> Y -> fields[name='X'].value
   * X.Y => fields[name='X'].Y
   * fields[name='X'].Y -> META:FIELD[name='X'].Y
   * X[N] -> X[ROW_INDEX='N']

=cut

# SMELL: must clone the query
sub rewrite {
    my ( $node, $context ) = @_;

    $context ||= 'ROOT';

    my $before;
    $before = recreate($node) if MONITOR;
    my $rewrote = 0;

    unless ( ref( $node->{op} ) ) {
        if ( $node->{op} == NAME ) {
            if ( $context eq 'ROOT' ) {

                # A name floating around in an expression.
                $parser ||= new Foswiki::Query::Parser();
                $node =
                  $parser->parse("META:FIELD[name='$node->{params}[0]'].value");
                $rewrote = 1;
            }
        }
    }
    else {

        my $op = $node->{op}->{name};
        if ( $op eq '(' ) {

            # Can simply eliminate this
            $node    = $node->{params}[0];
            $rewrote = 1;
        }
        elsif ( $op eq '.' ) {

            # The legacy of the . operator means it really requires context
            # information to determine how it should be parsed. We don't have
            # all that context here, so we have to do the best we can with what
            # we have, and rewrite it as a []
            my $lhs = rewrite( $node->{params}[0], 'TABLE' );
            my $rhs = rewrite( $node->{params}[1], 'SELECTOR' );

            # RHS must be a key.
            die "Illegal RHS of . " . recreate($rhs)
              unless !ref( $rhs->{op} ) && $rhs->{op} == NAME;

            if ( !ref( $lhs->{op} ) && $lhs->{op} == NAME ) {

                # Simple name on the LHS. Either a form name or a
                # table name.
                $parser ||= new Foswiki::Query::Parser();
                my $select_from = $lhs->{params}[0];

                if ( $Foswiki::Query::Node::aliases{$select_from} ) {
                    $select_from = $Foswiki::Query::Node::aliases{$select_from};
                }
                if ( $select_from =~ /^META:(\w+)/ ) {

                    # It's a table name. Rewrite name as META:
                    $lhs->{params}[0] = $select_from;

          #                    $node = $parser->parse(
          #                        "META:${1}[name='$rhs->{params}[0]'].value");
          #                    $rewrote = 1;
                }
                else {

                  # Otherwise the LHS must be a form name. Since we only support
                  # one form per topic, we can rewrite this as a field select,
                  # and add a constraint on the topic using the META:FORM table.
                  # Constraint is "META:FORM.name='$lhs->{params}[0]'"
                    $parser ||= new Foswiki::Query::Parser();
                    $node = $parser->parse(
                        "META:FIELD[name='$rhs->{params}[0]'].value");
                    $rewrote = 1;
                }
            }
        }
        elsif ( $op eq '[' ) {

            # Convert a row number constant into a condition
            my $lhs = $node->{params}[0] =
              rewrite( $node->{params}[0], 'TABLE' );
            my $rhs = $node->{params}[1] =
              rewrite( $node->{params}[1], 'WHERE' );
            if ( !ref( $lhs->{op} ) && $lhs->{op} == NUMBER ) {
                my $n = $lhs->{params}[0];
                $node->{params}[1] = $parser->parse("ROW_INDEX=$n");
                $rewrote = 1;
            }
            elsif ( !ref( $lhs->{op} ) && $lhs->{op} == NAME ) {

                # Simple name on the LHS. Must be a table name.
                my $select_from = $lhs->{params}[0];

                if ( $Foswiki::Query::Node::aliases{$select_from} ) {
                    $select_from = $Foswiki::Query::Node::aliases{$select_from};
                }
                if ( $select_from =~ /^META:(\w+)/ ) {

                    # It's a table name. Rewrite name as META:
                    $lhs->{params}[0] = $select_from;
                    $rewrote = 1;

                    # name type is TABLE
                }
                else {
                    ASSERT(0) if DEBUG;
                }
            }
        }
        else {
            for ( my $i = 0 ; $i < $node->{op}->{arity} ; $i++ ) {
                $node->{params}[$i] = rewrite( $node->{params}[$i], $context );
            }
        }
    }
    print STDERR "Rewrote $before as " . recreate($node) . "\n"
      if MONITOR && $rewrote;
    return $node;
}

=begin TML

Reorder parse tree based on modified precedence rules,
to make SQL extraction easier. For example,

OR{<{.{/{'AnT',info},version},1.1},n/a}
          OR
         /  \
        <   n/a
       / \
      .  '1.1'
     / \
   '/'  version
  /   \
'AnT'  info

OR{/{'AnT',<{.{info,version},1.1}},n/a}
      OR
     /   \
   '/'   n/a
  /   \
'AnT'  <  
      / \
     .    1.1
    / \
info   version

=cut

my %reorder = (

    # prec gives the new precedence of the operator.
    # child gives the index of the subnode that has the
    # selector (the RHS for / and . operators).
    '/' => { prec => 275, child => 1 },
    '.' => { prec => 250, child => 1 }
);

sub reorder {
    my ( $node, $root, @parents ) = @_;

    return unless ref( $node->{op} );
    my $op = $node->{op}->{name};
    my $ro = $reorder{$op};
    my $branch;
    if (   defined $ro
        && scalar(@parents)
        && _prec( $parents[0]->{op} ) > $ro->{prec} )
    {
        print STDERR "Reorder "
          . recreate($node)
          . " because "
          . "prec($op) <= prec($parents[0]->{op}->{name})" . "\n"
          if MONITOR;

        my $prec  = $ro->{prec};
        my $child = $ro->{child};
        my $i     = 0;
        while ( $i < scalar(@parents) && _prec( $parents[$i]->{op} ) > $prec ) {
            $i++;
        }
        if ($i) {
            my $current_parent = $parents[0];

            # Find which branch of the current parent the $node
            # is on
            $branch = _find_child( $current_parent, $node );
            $current_parent->{params}[$branch] = $node->{params}[1];

            if ( $i < scalar(@parents) ) {
                my $new_parent = $parents[$i];

                # Find the branch that the next parent is on
                $branch = _find_child( $new_parent, $parents[ $i - 1 ] );
                $node->{params}[$child]        = $new_parent->{params}[$branch];
                $new_parent->{params}[$branch] = $node;
                splice( @parents, 0, $i );
            }
            else {
                $node->{params}[$child] = $$root;
                $$root                  = $node;
                @parents                = ();
            }
            print STDERR "After reordering " . recreate($$root) . "\n"
              if MONITOR;
        }
    }
    for ( $branch = 0 ; $branch < $node->{op}->{arity} ; $branch++ ) {
        reorder( $node->{params}[$branch], $root, $node, @parents );
    }
}

sub _prec {
    my $op = shift;
    return $reorder{ $op->{name} }->{prec} if defined $reorder{ $op->{name} };
    return $op->{prec};
}

sub _find_child {
    my ( $node, $child ) = @_;
    my $branch = 0;
    while ($branch < $node->{op}->{arity}
        && $node->{params}[$branch] != $child )
    {
        $branch++;
    }
    ASSERT( $branch >= 0 && $branch < $node->{op}->{arity} )
      if DEBUG;
    return $branch;
}

# Regenerate a Foswiki query expression from a parse tree
sub recreate {
    my ( $node, $pprec ) = @_;
    $pprec ||= 0;
    my $s;

    if ( ref( $node->{op} ) ) {
        my @oa;
        for ( my $i = 0 ; $i < $node->{op}->{arity} ; $i++ ) {
            my $nprec = $node->{op}->{prec};
            $nprec++ if $i == 0;
            $nprec = 0 if $node->{op}->{close};
            push( @oa, recreate( $node->{params}[$i], $nprec ) );
        }
        my $nop = $node->{op}->{name};
        if ( scalar(@oa) == 1 ) {
            $nop = "$nop " if $nop =~ /\w$/ && $oa[0] =~ /^\w/;
            $s = "$nop$oa[0]";
        }
        elsif ( scalar(@oa) == 2 ) {
            if ( $node->{op}->{close} ) {
                $s = "$oa[0]$node->{op}->{name}$oa[1]$node->{op}->{close}";
            }
            else {
                $nop = " $nop" if ( $nop =~ /^\w/ && $oa[0] =~ /\w$/ );
                $nop = "$nop " if ( $nop =~ /\w$/ && $oa[1] =~ /^\w/ );
                $s = "$oa[0]$nop$oa[1]";
            }
        }
        else {
            $s = join( " $nop ", @oa );
        }
        $s = "($s)" if ( $node->{op}->{prec} < $pprec );
    }
    elsif ( $node->{op} == STRING ) {
        $s = "\"$node->{params}[0]\"";
    }
    else {
        $s = $node->{params}[0];
    }
    return $s;
}

1;
__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2014 Foswiki Contributors. All Rights Reserved.
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
