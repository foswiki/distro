# See bottom of file for copyright and license details

=begin TML

---+ package Foswiki::Contrib::DBIStoreContrib::HoistSQL

Static functions to extract SQL expressions from queries. The SQL is
used to pre-filter topics cached in an SQL DB for more efficient
query matching.

=cut

package Foswiki::Contrib::DBIStoreContrib::HoistSQL;

use strict;
use Assert;

use Foswiki::Contrib::DBIStoreContrib                ();
use Foswiki::Infix::Node                             ();
use Foswiki::Query::Node                             ();
use Foswiki::Query::Parser                           ();
use Foswiki::Store::QueryAlgorithms::DBIStoreContrib ();
use Foswiki::Func                                    ();

# A Foswiki query parser
our $parser;

use constant MONITOR => Foswiki::Contrib::DBIStoreContrib::MONITOR;

our $table_name_RE = qr/^\w+$/;

# Pseudo-constants, from the Personality
our $TRUE;
our $TRUE_TYPE;

# Copy constants for shorthand
use constant {
    NAME        => Foswiki::Contrib::DBIStoreContrib::NAME,
    NUMBER      => Foswiki::Contrib::DBIStoreContrib::NUMBER,
    STRING      => Foswiki::Contrib::DBIStoreContrib::STRING,
    UNKNOWN     => Foswiki::Contrib::DBIStoreContrib::UNKNOWN,
    BOOLEAN     => Foswiki::Contrib::DBIStoreContrib::BOOLEAN,
    SELECTOR    => Foswiki::Contrib::DBIStoreContrib::SELECTOR,
    VALUE       => Foswiki::Contrib::DBIStoreContrib::VALUE,
    TABLE       => Foswiki::Contrib::DBIStoreContrib::TABLE,
    PSEUDO_BOOL => Foswiki::Contrib::DBIStoreContrib::PSEUDO_BOOL,
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

# Coverage; add _COVER(__LINE__) where you want a visit recorded.
use constant COVER => 0;
our %covered;

BEGIN {
    if (COVER) {
        open( F, '<', __FILE__ );
        local $/ = "\n";
        my $lno = 0;
        while ( my $l = <F> ) {
            $lno++;
            if ( $l =~ /_COVER\(__LINE__\)/ ) {
                $covered{$lno} = 0;
            }
        }
        close(F);
    }
}

sub _COVER {
    $covered{ $_[0] }++;
}

END {
    if (COVER) {
        open( F, '>', "coverage" );
        print F join( "\n", map { "$_ $covered{$_}" } sort keys %covered )
          . "\n";
        close(F);
    }
}

# Frequently used SQL constructs

# Generate SQL SELECT statement.
# _SELECT(__LINE__, pick, FROM =>, WHERE => etc )
# Keys are ignored if their value is undef
sub _SELECT {
    my (%opts) = @_;
    my $info = '';
    if ( MONITOR && defined $opts{monitor} ) {
        $info = _personality()->make_comment( $opts{monitor} );
    }
    my $pick = $opts{select};
    if ( ref($pick) ) {
        $pick = join( ',', @$pick );
    }
    my $sql = "SELECT$info $pick";
    while ( my ( $opt, $val ) = each %opts ) {
        next unless ( $opt && $opt =~ /^[A-Z]/ && defined $val );
        $val = [$val] unless ( ref($val) );

        # Bracket subqueries for FROM etc
        $sql .=
          " $opt " . join( ',', map { $_ =~ /^SELECT/ ? "($_)" : $_ } @$val );
    }
    return $sql;
}

# Generate AS statement
# _AS(thing => alias)
sub _AS {
    my %args = @_;
    my @terms;
    while ( my ( $what, $alias ) = each %args ) {
        if ( defined $alias ) {
            $what = "($what)"
              if $what !~ /^[\w`]+$/
              && $what !~ /^(["']).*\1$/
              && $what !~ /^\([^()]*\)$/;
            push( @terms, "$what AS $alias" );
        }
        else {
            push( @terms, $what );
        }
    }
    return join( ',', @terms );
}

# Generate UNION statement
sub _UNION {
    my ( $a, $b ) = @_;
    return "$a UNION $b";
}

sub _abort {
    throw Error::Simple(
        join( ' ', 'SQL generator:', map { ref($_) ? recreate($_) : $_ } @_ ) );
}

# Mapping operators to SQL. Functions accept the arguments and their
# inferred types.
sub _simple_uop {

    # Simple unary operator
    my ( $opn, $type, $arg, $atype ) = @_;
    $arg = _cast( $arg, $atype, $type );
    return ( "$opn($arg)", $type );
}

sub _boolean_uop {
    my ( $opn, $arg, $atype ) = @_;
    return _simple_uop( $opn, BOOLEAN, $arg, $atype );
}

my %uop_map = (
    not => sub { _boolean_uop( 'NOT', @_ ) },
    lc     => sub { _simple_uop( 'LOWER', STRING, @_ ) },
    uc     => sub { _simple_uop( 'UPPER', STRING, @_ ) },
    length => sub {
        my ( $arg, $atype ) = @_;
        if ( $atype != STRING && $atype != UNKNOWN ) {
            $arg = _cast( $arg, $atype, STRING );
        }
        return ( _personality()->length($arg), NUMBER );
    },
    d2n => sub {
        my ( $arg, $atype ) = @_;
        if ( $atype != NUMBER ) {
            $arg = _personality()->d2n($arg);
        }
        return ( $arg, NUMBER );
    },
    int => sub { },                                  # handled in rewrite
    '-' => sub { _simple_uop( '-', NUMBER, @_ ) },
    '+' => sub { _simple_uop( '+', NUMBER, @_ ) },
);

# A bop returning a number
sub _numeric_bop {
    my ( $opn, $lhs, $lhs_type, $rhs, $rhs_type ) = @_;
    $lhs = _cast( $lhs, $lhs_type, NUMBER );
    $rhs = _cast( $rhs, $rhs_type, NUMBER );
    return ( "($lhs)$opn($rhs)", NUMBER );
}

# A bop returning a number or a string
sub _flexi_bop {
    my ( $opn, $lhs, $lhs_type, $rhs, $rhs_type ) = @_;
    my $ot = NUMBER;
    if ( $lhs_type == STRING || $rhs_type == STRING ) {
        $ot = STRING;
    }
    $lhs = _cast( $lhs, $lhs_type, $ot );
    $rhs = _cast( $rhs, $rhs_type, $ot );
    return ( "($lhs)$opn($rhs)", $ot );
}

# A bop returning a boolean
sub _boolean_bop {
    my ( $opn, $lhs, $lhs_type, $rhs, $rhs_type ) = @_;
    if ( $lhs_type == NUMBER || $rhs_type == NUMBER ) {
        $lhs = _cast( $lhs, $lhs_type, NUMBER );
        $rhs = _cast( $rhs, $rhs_type, NUMBER );
    }
    elsif ( $lhs_type == STRING || $rhs_type == STRING ) {
        $lhs = _cast( $lhs, $lhs_type, STRING );
        $rhs = _cast( $rhs, $rhs_type, STRING );
    }
    else {
        $lhs = _cast( $lhs, $lhs_type, BOOLEAN );
        $rhs = _cast( $rhs, $rhs_type, BOOLEAN );
    }
    return ( "($lhs)$opn($rhs)", BOOLEAN );
}

my %bop_map = (
    and  => sub { _boolean_bop( 'AND', @_ ) },
    or   => sub { _boolean_bop( 'OR',  @_ ) },
    ','  => sub { _abort("Unsupported ',' operator"); },
    'in' => sub { _abort("Unsupported 'in' operator"); },
    '-'  => sub { _flexi_bop( '-',     @_ ) },
    '+'  => sub { _flexi_bop( '+',     @_ ) },
    '*'  => sub { _numeric_bop( '*',   @_ ) },
    '/'  => sub { _numeric_bop( '/',   @_ ) },
    '='  => sub {
        my ( $lhs, $lhs_type, $rhs, $rhs_type ) = @_;

        # Special case
        if ( $lhs eq 'NULL' ) {
            if ( $rhs eq 'NULL' ) {
                return ( $TRUE, $TRUE_TYPE );
            }

            # Need EXISTS condition
            return ( "($rhs) IS NULL", BOOLEAN );
        }
        elsif ( $rhs eq 'NULL' ) {

            # Need EXISTS condition
            return ( "($lhs) IS NULL", BOOLEAN );
        }
        return _boolean_bop( '=', @_ );
    },
    '!=' => sub { _boolean_bop( '!=', @_ ) },
    '<'  => sub { _boolean_bop( '<',  @_ ) },
    '>'  => sub { _boolean_bop( '>',  @_ ) },
    '<=' => sub { _boolean_bop( '<=', @_ ) },
    '>=' => sub { _boolean_bop( '>=', @_ ) },
    '~'  => sub {
        my ( $lhs, $lhst, $rhs, $rhst ) = @_;
        my $expr = _personality()->wildcard( $lhs, $rhs );
        return ( $expr, BOOLEAN );
    },
    '=~' => sub {
        my ( $lhs, $lhst, $rhs, $rhst ) = @_;
        my $expr = _personality()->regexp( $lhs, $rhs );
        return ( $expr, BOOLEAN );
    },

);

# Generate a unique alias for a table or column
my $temp_id = 0;

sub _alias {
    my $line = shift;
    my $tid = 't' . ( $temp_id++ );
    $tid .= "_$line" if MONITOR;
    return $tid;
}

# Get the personalty module
sub _personality {
    return Foswiki::Contrib::DBIStoreContrib::personality;
}

=begin TML

---++ ObjectMethod hoist($query) -> $sql_statement

The main method in this module generates SQL from a query. The return value
is a valid, stand-alone SQL query. This is a complete mapping of a
Foswiki query to SQL.

Will die with a message if there is a diagnosable problem.

=cut

sub hoist {
    my ($query) = @_;

    unless ( defined $TRUE ) {
        $TRUE      = _personality()->{true_value};
        $TRUE_TYPE = _personality()->{true_type};
    }

    Foswiki::Func::writeDebug( "HOISTING " . recreate($query) ) if MONITOR;

    # Simplify the parse tree, work out type information.
    $query = _rewrite( $query, UNKNOWN );
    Foswiki::Func::writeDebug( "Rewritten " . recreate($query) ) if MONITOR;

    my %h = _hoist( $query, 'topic' );
    my $alias = _alias(__LINE__);    # SQL server requires this!
    if ( $h{is_table_name} ) {
        $h{sql} = "topic.tid IN (SELECT tid FROM ($h{sql}) AS $alias)";
    }
    elsif ( $h{is_select} ) {

        # It's a table; test if the selector is a true value
        my $where = '';
        if ( $h{sel} ) {
            if ( $h{type} == NUMBER || $h{type} == PSEUDO_BOOL ) {
                $where = '!=0';
            }
            elsif ( $h{type} == STRING ) {
                $where = "!=''";
            }
            else {
                $where = '';    # BOOLEAN
            }
            $where = " WHERE $h{sel}$where";
        }
        my $a2 = _alias(__LINE__);    # SQL server requires this!
             # This rather clumsy construction is required because SQL server
             # can't use an aliased column in the WHERE condition of the same
             # SELECT.
        $h{sql} =
"topic.tid IN (SELECT tid FROM (SELECT * FROM ($h{sql}) AS $a2 $where) AS $alias)";
    }
    elsif ( $h{type} == NUMBER || $h{type} == PSEUDO_BOOL ) {
        $h{sql} = "($h{sql})!=0";
    }
    elsif ( $h{type} == STRING ) {
        $h{sql} = "($h{sql})!=''";
    }
    return $h{sql};
}

# The function that does the actual work
# Params: ($node, $in_table)
# $node - the node being processed
# $in_table - the table in which lookup is being performed. A simple ID.
#
# Return: %result with keys:
# sql - the generated SQL
# type - type of the subexpression
# is_table_name - true if the statement yields a table (even if not a SELECT)
# selector - optional selector indicating the single column name chosen
# in the subquery
# ignore_tid - set true if the tids in the result come from a subquery
# over an unrelated topic. Such tids are not propagated up through
# boolean operations.
#
# Any sub-expression generates a query that yields a table. That table
# has an associated column (or columns). So,
# TOPICINFO yields (SELECT * FROM TOPICINFO) if it's used raw
# TOPICINFO.blah yields (SELECT blah FROM TOPICINFO)
# fields[name="blah"] yields (SELECT * FROM FIELD WHERE name="blah")
# 'Topic'/fields[name='blah'].value yields (SELECT value FROM (SELECT * FROM topic,(SELECT * FROM FIELD WHERE name="blah") AS t1 WHERE topic.tid=t1.tid AND topic.name="Topic")
# tname/sexpr ->
# (SELECT * FROM topic,sexpr AS t1 WHERE topic.tid=t1.tid AND topic.name=tname
#                                                             [ $lhs_where   ]

sub _hoist {
    my ( $node, $in_table ) = @_;

    # The default context table is 'topic'. As soon as we go into a
    # SELECT, the context table may change. In a /, the context table
    # is still 'topic'

    my $op    = $node->{op}->{name}  if ref( $node->{op} );
    my $arity = $node->{op}->{arity} if ref( $node->{op} );

    my %result;
    $result{type} = UNKNOWN;

    if ( !ref( $node->{op} ) ) {
        if ( $node->{op} == STRING ) {

            # Convert to an escaped SQL string
            my $s = $node->{params}[0];
            $s =~ s/\\/\\\\/g;

            # Escape single quote by doubling it (SQL standard)
            $s =~ s/'/''/gs;
            $result{sql}  = "'$s'";
            $result{type} = STRING;
        }
        elsif ( $node->{op} == NAME ) {

            # A simple name
            my $name = $node->{params}[0];
            if ( $name =~ /^META:(\w+)$/ ) {

                # Name of a table
                $result{sql}           = _personality()->safe_id($1);
                $result{is_table_name} = 1;
                $result{type}          = STRING;
            }
            elsif ( $name eq 'undefined' ) {
                $result{sql}  = 'NULL';
                $result{type} = UNKNOWN;
            }
            else {

                # Name of a field
                $name = _personality()->safe_id($name);
                $result{sql} = $in_table ? "$in_table.$name" : $name;
                $result{type} = STRING;
            }
        }
        else {
            $result{sql}  = $node->{params}[0];
            $result{type} = $node->{op};
        }
    }
    elsif ( $op eq '[' ) {
        my %lhs = _hoist( $node->{params}[0], $in_table );

        my $from_alias;
        my $tid_constraint = '';
        if ( $lhs{is_table_name} || $lhs{is_select} ) {

            $from_alias = _alias(__LINE__);
            $lhs{sql} = _AS( $lhs{sql} => $from_alias );

            if ( $lhs{is_table_name} && $in_table ) {

  #-MySQL                $tid_constraint = " AND $from_alias.tid=$in_table.tid";
            }
        }
        else {
            _abort( "Expected a table on the LHS of '[':", $node );
        }

        my %where = _hoist( $node->{params}[1], $from_alias );

        if ( $where{is_select} ) {
            $where{sql} = "EXISTS($where{sql})";
        }
        elsif ( $where{is_table_name} ) {

            # Hum. TABLE[TABLE_NAME]
            _abort( "Cannot use a table name here:",
                $node, $node->{params}[1] );
        }
        elsif ( $where{type} == STRING ) {

            # A simple non-table expression
            $where{sql} = "($where{sql})!=''";
        }
        elsif ( $where{type} == NUMBER ) {
            $where{sql} = "($where{sql})!=0";
        }
        elsif ( $where{type} == PSEUDO_BOOL ) {
            $where{sql} = "($where{sql})!=0";
        }

        my $where = "$where{sql}$tid_constraint";

        $result{sql} = _SELECT(
            select  => '*',
            FROM    => $lhs{sql},
            WHERE   => $where,
            monitor => __LINE__
        );
        $result{is_select}  = 1;
        $result{has_where}  = length($where);
        $result{type}       = STRING;
        $result{ignore_tid} = $lhs{ignore_tid};

        # No . here, so no selector
    }
    elsif ( $op eq '.' ) {
        my %lhs = _hoist( $node->{params}[0], $in_table );

        # SMELL: ought to be able to support an expression generating
        # a selector name on the RHS. But that's just too hard in SQL.
        my $rhs = $node->{params}[1];
        if ( ref( $rhs->{op} ) || $rhs->{op} != NAME ) {
            _abort( "Expected a selector name on the RHS of '.':", $node );
        }
        $result{sel} = $rhs->{params}[0];

        my $alias   = _alias(__LINE__);
        my @selects = ("$alias.tid");
        if ( $lhs{is_select} ) {
            push( @selects, $result{sel} );
        }
        elsif ( $lhs{is_table_name} ) {
            push( @selects,
                "$alias." . _personality()->safe_id( $result{sel} ) );
        }
        else {
            _abort( "Expected a table on the LHS of '.':", $node );
        }
        $result{sql} = _SELECT(
            select  => \@selects,
            FROM    => _AS( $lhs{sql} => $alias ),
            monitor => __LINE__
        );
        $result{is_select}  = 1;
        $result{type}       = STRING;
        $result{ignore_tid} = $lhs{ignore_tid};

    }
    elsif ( $op eq '/' ) {

        # A lookup in another topic

        my $topic_alias = _alias(__LINE__);

        # Expect a condition that yields a topic name on the LHS
        my $lhs = $node->{params}[0];
        my %lhs = _hoist( $node->{params}[0], undef );
        my $lhs_where;
        my @selects;
        my $wtn = _personality()
          ->strcat( "$topic_alias.web", "'.'", "$topic_alias.name" );
        if ( $lhs{is_select} ) {
            my $tnames = _alias(__LINE__);
            push( @selects, _AS( $lhs{sql} => $tnames ) );
            my $tname_sel = $tnames;
            $tname_sel = "$tnames." . _personality()->safe_id( $lhs{sel} )
              if $lhs{sel};
            $lhs_where = "($topic_alias.name=$tname_sel OR ($wtn)=$tname_sel)";
        }
        elsif ( $lhs{is_table_name} ) {

            # Table name with no select. Useless.
            _abort( "Table name cannot be used here:", $node, $lhs );
        }
        else {

            # Not a selector or simple table name, must be a simple
            # expression yielding a selector
            $lhs_where = "($lhs{sql}) IN ($topic_alias.name,$wtn)";
        }

        # Expand the RHS *without* a constraint on the topic table
        my %rhs = _hoist( $node->{params}[1], undef );
        unless ( $rhs{is_select} || $rhs{is_table_name} ) {

            # We *could* handle this without an error, but it would
            # be pretty meaningless e.g. 'Topic'/1
            _abort( "Expected a table expression on the RHS of '/':", $node );
        }
        $result{sel} = $rhs{sel};

        my $sexpr_alias = _alias(__LINE__);

        my $tid_constraint = "$sexpr_alias.tid IN ("
          . _SELECT(
            select  => 'tid',
            FROM    => _AS( 'topic' => $topic_alias ),
            WHERE   => $lhs_where,
            monitor => __LINE__
          ) . ")";

        push( @selects, _AS( $rhs{sql} => $sexpr_alias ) );
        $result{sql} = _SELECT(

            # select all columns (which will include tid)
            select  => "$sexpr_alias.*",
            FROM    => \@selects,
            WHERE   => $tid_constraint,
            monitor => __LINE__
        );

        $result{is_select}  = 1;
        $result{has_where}  = 1;
        $result{type}       = $rhs{type};
        $result{ignore_tid} = 1;
    }
    elsif ( $arity == 2 && defined $bop_map{$op} ) {

        my $lhs = $node->{params}[0];
        my %lhs = _hoist( $lhs, $in_table );

        my $rhs = $node->{params}[1];
        my %rhs = _hoist( $rhs, $in_table );

        my $opfn = $bop_map{$op};

        if (   ( $lhs{is_select} || $lhs{is_table_name} )
            && ( $rhs{is_select} || $rhs{is_table_name} ) )
        {

            # TABLE - TABLE

            my $lhs_alias = _alias(__LINE__);
            my $rhs_alias = _alias(__LINE__);

            $result{sel} = _alias(__LINE__);
            if ( $op eq 'or' ) {

                # Special case for OR, because the OR operator
                # doesn't work the way the other operators do when
                # it's used on two tables. Not sure why, it ought
                # to work AFAICT from RTFM, but it doesn't.
                my $union_alias = _alias(__LINE__);
                my ( $lhs_sql, $rhs_sql );

                if ( $lhs{ignore_tid} ) {

                    # Don't propagate tids from the LHS
                    $lhs_sql = _SELECT(
                        select  => _AS( 'tid', $lhs_alias ),
                        FROM    => 'topic',
                        WHERE   => 'EXISTS(' . $lhs{sql} . ')',
                        monitor => __LINE__
                    );
                }
                else {
                    $lhs_sql = _SELECT(
                        select  => 'tid',
                        FROM    => _AS( $lhs{sql}, $lhs_alias ),
                        monitor => __LINE__
                    );
                }

                if ( $rhs{ignore_tid} ) {

                    # Don't propagate tids from the RHS
                    $rhs_sql = _SELECT(
                        select  => _AS( 'tid', $rhs_alias ),
                        FROM    => 'topic',
                        WHERE   => 'EXISTS(' . $rhs{sql} . ')',
                        monitor => __LINE__
                    );
                }
                else {
                    $rhs_sql = _SELECT(
                        select  => 'tid',
                        FROM    => _AS( $rhs{sql}, $rhs_alias ),
                        monitor => __LINE__
                    );
                }

                my $union_sql = _UNION( $lhs_sql, $rhs_sql );

                $result{sql} = _SELECT(
                    select =>
                      [ 'DISTINCT ' . _AS( $TRUE => $result{sel} ), 'tid' ],
                    FROM    => _AS( $union_sql, $union_alias ),
                    monitor => __LINE__
                );
                $result{is_select}  = 1;
                $result{type}       = $TRUE_TYPE;
                $result{ignore_tid} = 0;
            }
            else {
                # All other non-OR table-table operators
                if ( defined $rhs{sel} ) {
                    $lhs{sel} = $rhs{sel} unless defined $lhs{sel};
                }
                elsif ( defined $lhs{sel} ) {
                    $rhs{sel} = $lhs{sel};
                }
                else {
                    _abort(
"Cannot '$op' two tables without at least one selector:",
                        $node
                    );
                }
                my $l_sel =
                  "$lhs_alias." . _personality()->safe_id( $lhs{sel} );
                my $r_sel =
                  "$rhs_alias." . _personality()->safe_id( $rhs{sel} );

                my ( $expr, $optype ) = &$opfn(
                    $l_sel => $lhs{type},
                    $r_sel => $rhs{type}
                );
                my $where = "($lhs_alias.tid=$rhs_alias.tid)";
                if ( $optype == BOOLEAN ) {
                    #$where .= " AND ($expr)";
                    $expr   = $TRUE;
                    $optype = $TRUE_TYPE;
                }

                my $ret_tid   = "$lhs_alias.tid";
                my $tid_table = '';
                if ( $rhs{ignore_tid} || $lhs{ignore_tid} ) {
                    $ret_tid   = 'topic.tid';
                    $tid_table = 'topic,';
                }
                $result{sql} = _SELECT(
                    select =>
                      [ 'DISTINCT ' . _AS( $expr => $result{sel} ), $ret_tid ],
                    FROM => $tid_table
                      . _AS(
                        $lhs{sql} => $lhs_alias,
                        $rhs{sql} => $rhs_alias
                      ),
                    WHERE   => $where,
                    monitor => __LINE__
                );
                $result{is_select} = 1;
                $result{has_where} = length($where);
                $result{type}      = $optype;
            }
        }
        elsif ( $lhs{is_select} || $lhs{is_table_name} ) {

            # TABLE - CONSTANT
            my $operate = sub {
                my $sel = shift;
                return &$opfn(
                    $sel      => $lhs{type},
                    $rhs{sql} => $rhs{type}
                );
            };
            _genSingleTableSELECT( \%lhs, $operate, \%result,
                __LINE__ . " $op" );
        }
        elsif ( $rhs{is_select} ) {

            # CONSTANT - TABLE
            my $operate = sub {
                my $sel = shift;
                return &$opfn(
                    $lhs{sql} => $lhs{type},
                    $sel      => $rhs{type}
                );
            };
            _genSingleTableSELECT( \%rhs, $operate, \%result,
                __LINE__ . " $op" );
        }
        else {

            # CONSTANT - CONSTANT
            ( $result{sql}, $result{type} ) = &$opfn(
                $lhs{sql} => $lhs{type},
                $rhs{sql} => $rhs{type}
            );
        }
    }
    elsif ( $arity == 1 && defined $uop_map{$op} ) {
        my $opfn = $uop_map{$op};
        my %kid = _hoist( $node->{params}[0], $in_table );
        if ( $kid{is_select} || $kid{is_table_name} ) {
            my $operate = sub {
                my $sel = shift;
                return &$opfn( $sel => UNKNOWN );
            };
            _genSingleTableSELECT( \%kid, $operate, \%result,
                __LINE__ . " $op" );

        }
        else {
            ( $result{sql}, $result{type} ) = &$opfn( $kid{sql}, $kid{type} );
        }
        $result{ignore_tid} = $kid{ignore_tid};
    }
    else {
        _abort( "Don't know how to hoist '$op':", $node );
    }

#    if (MONITOR) {
#        Foswiki::Func::writeDebug( "Hoist " . recreate($node) . " ->");
#        Foswiki::Func::writeDebug( "select $result{sel} from") if $result{sel};
#        Foswiki::Func::writeDebug( "table name")               if $result{is_table_name};
#        Foswiki::Func::writeDebug( _format_SQL( $result{sql} ) . "");
#    }
    return %result;
}

sub _genSingleTableSELECT {
    my ( $table, $operate, $result, $monitor ) = @_;

    my $alias = _alias(__LINE__);
    my $sel   = $alias;
    $sel = "$alias." . _personality()->safe_id( $table->{sel} )
      if $table->{sel};

    $result->{sel}        = _alias(__LINE__);
    $result->{ignore_tid} = 0;
    my ( $expr, $optype ) = &$operate($sel);

    my $where;
    if ( $optype == BOOLEAN ) {
        $where  = $expr;
        $expr   = $TRUE;
        $optype = $TRUE_TYPE;
    }

    my $ret_tid = "$alias.tid";
    my @froms = ( _AS( $table->{sql} => $alias ) );
    if ( $table->{ignore_tid} ) {

        # ignore tid coming from the subexpression
        $ret_tid = 'topic.tid';
        unshift( @froms, 'topic' );
    }

    $result->{sql} = _SELECT(
        select  => [ _AS( $expr => $result->{sel} ), $ret_tid ],
        FROM    => \@froms,
        WHERE   => $where,
        monitor => $monitor
    );
    $result->{is_select} = 1;
    $result->{has_where} = length($where);
    $result->{type}      = $optype;
}

# Generate a cast statement, if necessary.
# from a child node type.
# $arg - the SQL being cast
# $type - the current type of the $arg (may be UNKNOWN)
# $tgt_type - the target type of the cast (may be UNKNOWN)
sub _cast {
    my ( $arg, $type, $tgt_type ) = @_;
    return $arg if $tgt_type == UNKNOWN || $type == $tgt_type;
    if ( $tgt_type == BOOLEAN ) {
        if ( $type == NUMBER ) {
            $arg = "$arg!=0";
        }
        elsif ( $type == PSEUDO_BOOL ) {
            return "$arg=" . $TRUE;
        }
        else {
            $arg = "$arg!=''";
        }
    }
    elsif ( $tgt_type == NUMBER ) {
        $arg = _personality()->cast_to_numeric($arg);
    }
    elsif ( $type != UNKNOWN ) {
        $arg = _personality()->cast_to_text($arg);
    }
    return $arg;
}

# _rewrite( $node, $context ) -> $node
# Rewrite a Foswiki query parse tree to prepare it for SQL hoisting.
# $context is one of:
#    * UNKNOWN - the node being processed is in the context of the topic table
#    * VALUE - context of a WHERE
#    * TABLE - context of a table expression e.g. LHS of a [
# Analysis of the parse tree to determine the semantics of names, and
# the rewriting of shorthand expressions to their full form.
sub _rewrite {
    my ( $node, $context ) = @_;

    my $before;
    $before = recreate($node) if MONITOR;
    my $rewrote = 0;

    my $op = $node->{op};

    if ( !ref($op) ) {
        if ( $op == NAME ) {
            my $name = $node->{params}[0];
            my $tname = $Foswiki::Query::Node::aliases{$name} || $name;

            if ( $context == UNKNOWN ) {

                # A name floating around loose in an expression is
                # implicitly a column in the topic table.
                $parser ||= new Foswiki::Query::Parser();
                if ( $name =~ /^(name|web|text|raw)$/ ) {

                    $node =
                      _rewrite( $parser->parse("META:topic.$name"), $context );
                    $rewrote = __LINE__;
                }
                elsif ( $name ne 'undefined' ) {

                    # A table on it's own in the root doesn't make
                    # a lot of sense. Deal with it anyway.
                    if ( $tname =~ /^META:\w+$/ ) {
                        $node->{params}[0] = $tname;
                        $node->{is_table}  = 1;
                        $rewrote           = __LINE__;
                    }
                    else {
                        $node = _rewrite(
                            $parser->parse(
                                "META:FORM[name='$node->{params}[0]']"),
                            $context
                        );
                        $rewrote = __LINE__;
                    }
                }
            }
            elsif ( $context == TABLE ) {

                if ( $tname =~ /^META:\w+$/ ) {
                    $node->{params}[0] = $tname;
                    $node->{is_table}  = 1;
                    $rewrote           = __LINE__;
                }
                else {

                    # An unknown name where a table is expected?
                    # It may be a form name?
                    $rewrote = __LINE__;
                }
            }
            else {    # $context = VALUE

                if ( $tname =~ /^META:\w+$/ ) {

                    # This is going to end badly
                    $node->{params}[0] = $tname;
                    $node->{is_table}  = 1;
                    $rewrote           = __LINE__;
                }
                else {

                    # Name used as a selector
                    $node->{is_selector} = 1;
                    $rewrote = __LINE__;
                }
            }
        }
        else {

            # STRING or NUMBER
            $rewrote = __LINE__;
        }
    }
    elsif ( $op->{name} eq '(' ) {

        # Can simply eliminate this
        $node = _rewrite( $node->{params}[0], $context );
        $rewrote = __LINE__;
    }
    elsif ( $op->{name} eq 'int' ) {

        $node = _rewrite( $node->{params}[0], $context );
        $rewrote = __LINE__;
    }
    elsif ( $op->{name} eq '.' ) {

        # The legacy of the . operator means it really requires context
        # information to determine how it should be parsed. We don't have
        # all that context here, so we have to do the best we can with what
        # we have, and rewrite it as a []
        my $lhs = _rewrite( $node->{params}[0], TABLE );
        my $rhs = _rewrite( $node->{params}[1], VALUE );

        unless ( $lhs->{is_table} ) {
            Foswiki::Func::writeDebug(
                __LINE__ . " lhs may not be a table." . recreate($lhs) )
              if MONITOR;
        }

        # RHS must be a key.
        _abort( "Illegal RHS of '.':", $rhs ) unless $rhs->{is_selector};

        if ( !$lhs->{is_table} && !ref( $lhs->{op} ) ) {

            # The LHS must be a form name. Since we only support
            # one form per topic, we can rewrite this as a field select,
            # and add a constraint on the topic using the META:FORM table.
            # Constraint is "META:FORM.name='$lhs->{params}[0]'"
            $parser ||= new Foswiki::Query::Parser();

            # Must rewrite to infer types
            $node = _rewrite(
                $parser->parse("META:FIELD[name='$rhs->{params}[0]'].value"),
                $context );
            $rewrote = __LINE__;
        }
        else {

            # The result of the subquery might be a table or a single
            # value, but either way we have to treat it as a table.
            $node->{is_table} = 1;
            $rewrote = __LINE__;
        }
    }
    elsif ( $op->{name} eq '[' ) {

        my $lhs = _rewrite( $node->{params}[0], TABLE );
        my $rhs = _rewrite( $node->{params}[1], VALUE );

        $node->{is_table} = 1;
    }
    else {
        for ( my $i = 0 ; $i < $op->{arity} ; $i++ ) {
            my $nn = _rewrite( $node->{params}[$i], $context );
            $node->{params}[$i] = $nn;
        }
        my $nop = $op->{name};
    }

    Foswiki::Func::writeDebug(
        "$rewrote: Rewrote $before as " . recreate($node) )
      if MONITOR;
    return $node;
}

# Simple SQL formatter for the type of expression generated by this module
sub _format_SQL {
    my ($sql) = @_;

    # Assumes balanced brackets - won't work if \( or \) present
    my @ss = ();

    # Replace escaped quotes
    $sql =~ s/('')/push(@ss,$1); "![$#ss]!"/ges;

    # Replace quoted strings
    $sql =~ s/('([^'])*')/push(@ss,$1); "![$#ss]!"/ges;

    # Replace bracketed subexpressions
    my $n = 0;
    while ( $sql =~ s/\(([^\(\)]*?)\)/<$n:$1:$n>/s ) {
        $n++;
    }

    # Find and format the first region
    $sql = _format_region( $sql, '' );

    # Break remaining long lines on AND and OR
    my @lines = split( /\n/, $sql );
    my @nlines = ();
    foreach my $line (@lines) {
        my $ind = '';
        if ( $line =~ /^(\s+)/ ) {
            $ind = $1;
        }
        $ind = " $ind";
        while ( $line =~ /[^\n]{80}/ ) {
            last unless ( $line =~ s/(.{5}.*?\S +)(AND|OR|ORDER)/$ind$2/s );
            push( @nlines, $1 );
        }
        push( @nlines, $line ) if $line =~ /\S/;
    }
    $sql = join( "\n", @nlines );

    # Replace strings
    while ( $sql =~ s/!\[(\d+)\]!/$ss[$1]/gs ) {
    }
    return $sql;
}

sub _format_region {
    my ( $sql, $indent ) = @_;
    if ( $sql =~ /^(.*?)<(\d+):(.*):\2>(.*)$/s ) {
        my ( $before, $subexpr, $after ) = ( $1, $3, $4 );
        $before =~ s/(?<=\S) +(FROM|WHERE|UNION|SELECT)\b/\n$indent$1/gs;
        my $abrack    = '';
        my $subindent = $indent;
        if ( $subexpr =~ /^SELECT/ ) {
            $before    .= "\n$indent";
            $subindent .= " ";
            $abrack = "\n$indent";
        }
        $sql =
            "$before("
          . _format_region( $subexpr, $subindent )
          . "$abrack)"
          . _format_region( $after, $indent );
    }
    else {
        $sql =~ s/(?<=\S) +(FROM|WHERE|UNION|SELECT)\b/\n$indent$1/gs;
    }
    return $sql;
}

=begin TML

---++ StaticMethod recreate( $node ) -> $string

Unparse a Foswiki query expression from a parse tree. Should be
part of the Foswiki::Query::Node class, but isn't :-(

=cut

sub recreate {
    my ( $node, $pprec ) = @_;
    $pprec ||= 0;
    my $s;

    if ( ref( $node->{op} ) ) {
        my @oa;
        for ( my $i = 0 ; $i < $node->{op}->{arity} ; $i++ ) {
            my $nprec = $node->{op}->{prec};
            $nprec++ if $i > 0;
            $nprec = 0 if $node->{op}->{close};
            push( @oa, recreate( $node->{params}[$i], $nprec ) );
        }
        my $nop = $node->{op}->{name};
        if ( scalar(@oa) == 1 ) {
            if ( $node->{op}->{close} ) {
                $s = "$node->{op}->{name}$oa[0]$node->{op}->{close}";
            }
            else {
                $nop = "$nop " if $nop =~ /\w$/ && $oa[0] =~ /^\w/;
                $s = "$nop$oa[0]";
            }
        }
        elsif ( scalar(@oa) == 2 ) {
            if ( $node->{op}->{close} ) {
                $s = "$oa[0]$node->{op}->{name}$oa[1]$node->{op}->{close}";
            }
            else {
                $nop = " $nop" if ( $nop =~ /^\w/ && $oa[0] =~ /[\w)]$/ );
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
        $s = $node->{params}[0];
        $s =~ s/\\/\\\\/g;
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
