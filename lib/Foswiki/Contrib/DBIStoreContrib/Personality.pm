# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality;

use strict;
use warnings;
use Assert;

use Foswiki::Contrib::DBIStoreContrib ();

# We try to use the ANSI SQL standard as far as possible, for the most
# part different SQL DB implementations support it fairly well. However
# they all have nuances, and there are areas where the support is not
# consistent - most notably in regex support. To that end we have to
# have a database personality module, which provides these custom
# operations in a consistent way.

=begin TML

{true_value} and {true_type} For DB's that
don't support a true BOOLEAN type, the true_type can be PSEUDO_BOOL,
in which case boolean operations on the data will always be preceded
by =1.

{text_type} the name of the TEXT type, used to store variable-length
strings.

{requires_COMMIT} is 1 if the DB requires a COMMIT at the end of the
initial transaction.
The default is TRUE which works for SQLite, MySQL and Postgresql.

=cut

sub new {
    my ($class) = @_;
    my $this = bless(
        {
            dbh => undef,    # Set in startup

            # If the DB is running *without* auto-commit enabled, then this
            # is required.
            requires_COMMIT => 0,

            # A DB with native BOOLEAN can use a simple boolean expression
            # here. Without BOOLEAN support a more convoluted route is
            # required.
            true_value => '1=1',

            # If the DB has a native BOOLEAN type this is BOOLEAN. If it
            # has to use a BIT value, this will be PSEUDO_BOOL.
            true_type => Foswiki::Contrib::DBIStoreContrib::BOOLEAN,

            # Numeric shadow columns? If true, generate a FLOAT column
            # for each META: column, and do a perl data conversion of
            # the text data into it when saving.
            use_shadows => 0,
        },
        $class
    );

    # SQL reserved words. The following words are reserved in all of
    # PostgresSQL, MySQL, SQLite and T-SQL so provide a good
    # working basis. Personality modules should extend this list.
    $this->reserve(
        qw(
          ADD ALL ALTER AND AS ASC BETWEEN BY CASCADE CASE CHECK COLLATE COLUMN
          CONSTRAINT CREATE CROSS CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP
          DEFAULT DELETE DESC DISTINCT DROP ELSE EXISTS FOR FOREIGN FROM GROUP
          HAVING IN INDEX INNER INSERT INTO IS JOIN KEY LEFT LIKE NOT NULL ON OR
          ORDER OUTER PRIMARY REFERENCES RESTRICT RIGHT SELECT SET TABLE THEN TO
          UNION UNIQUE UPDATE VALUES WHEN WHERE WITH
          )
    );
    return $this;
}

# Protected - for use by subclasses only
# Register reserved words
sub reserve {
    my $this = shift;
    foreach (@_) {
        $this->{reserved}->{$_} = 1;
    }
}

=begin TML

---++ startup($dbh)
Execute any SQL commands required to start the DB in ANSI mode.
Subclasses must call superclass.

=cut

sub startup {
    my ( $this, $dbh ) = @_;
    ASSERT($dbh) if DEBUG;
    $this->{dbh} = $dbh;
}

=begin TML

---+ table_exists(table_name [, table_name]*) -> boolean
Determine if a table exists. All tables named in parameters
must exist.

=cut

sub table_exists {
    my $this = shift;
    my $tables = join( ',', map { "'$_'" } @_ );
    ASSERT( $this->{dbh} ) if DEBUG;

    # MySQL, Postgresql, MS SQL Server
    my $sql = <<SQL;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_NAME IN ($tables)
SQL
    my $rows = $this->{dbh}->selectall_arrayref($sql);
    return scalar(@$rows) == scalar(@_);
}

=begin TML

---+ column_exists(table_name, column_name) -> boolean
Determine if a column exists

=cut

sub column_exists {
    my ( $this, $table, $column ) = @_;
    ASSERT( $this->{dbh} ) if DEBUG;

    # MySQL, Postgresql, MS SQL Server
    my $sql = <<SQL;
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
 WHERE TABLE_NAME = '$table' AND COLUMN_NAME = '$column'
SQL
    return $this->{dbh}->selectrow_arrayref($sql);
}

=begin TML

---+ get_columns(table_name) -> @list
Get a list of column names for the given table

=cut

sub get_columns {
    my ( $this, $table ) = @_;
    ASSERT( $this->{dbh} ) if DEBUG;

    # MySQL, Postgresql, MS SQL Server
    my $sql = <<SQL;
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
 WHERE TABLE_NAME = '$table'
SQL
    return @{ $this->{dbh}->selectcol_arrayref($sql) };
}

=begin TML

---++ regexp($lhs, $rhs) -> $sql
Construct an SQL expression to execute the given regular expression
match.
  * =$rhs= - right hand side of the match
  * =$lhs= - the regular expression (perl syntax)
be different :-(

=cut

sub regexp {
    my ( $this, $lhs, $rhs ) = @_;

    return "$lhs REGEXP $rhs";
}

=begin TML

---++ wildcard($lhs, $rhs) -> $sql
Construct an SQL expression that will match a Foswiki wildcard
name match.

Default is ANSI standard.
ANSI wildcards in LIKE are:
 _ (underscore)
 Any one character. For example, a_ matches ab and ac, but not a.
 % (percent)
 Any string of zero or more characters. For example, bl% matches
 bl and bla.
 []
 Any single character in the specified range or set. For example,
 T[oi]m matches Tom or Tim.
 [^]
 Any single character not in the specified range or set. For
 example, M[^c] matches Mb and Md, but not Mc.
Foswiki uses * wildcards, and separates alternatives with comma, so this
is easy to do.

The default implementation uses the regexp function to match.

Note: the string input to this function must have single quotes already
doubled up.

=cut

sub wildcard {
    my ( $this, $lhs, $rhs ) = @_;
    my @exprs;
    if ( $rhs =~ s/^'(.*)'$/$1/ ) {
        foreach my $spec ( split( /(?:,\s*|\|)/, $rhs ) ) {
            my $like   = 0;
            my $escape = '';
            if ( $spec =~ s/([%_])/\0$1/g ) {
                $spec =~ s/!/!!/g;
                $spec =~ s/\0/!/g;
                $like   = 1;
                $escape = ' ESCAPE \'!\'';
            }
            $like = 1 if $spec =~ s/\*/%/g;
            $like = 1 if $spec =~ s/\?/_/g;

            if ($like) {
                my $res = "$lhs LIKE '$spec'$escape";
                push( @exprs, $res );
            }
            else {
                push( @exprs, "$lhs='$spec'" );
            }
        }
    }
    return join( ' OR ', @exprs );
}

=begin TML

---++ d2n($timestring) -> $isosecs
Convert a Foswiki time string to a number.
This implementation is for SQLite - there is no support in ANSI.

=cut

sub d2n {
    my ( $this, $arg ) = @_;

    return "CAST(strftime(\"%s\", $arg) AS FLOAT)";
}

=begin

Calculate the character length of a string

=cut

sub length {
    my ( $this, $s ) = @_;
    return "LENGTH($s)";
}

=begin TML

---++ safe_id($id) -> $safeid
Make sure the ID is safe to use in this dialect of SQL.
Unsafe IDs should be quoted using the dialect's identifier
quoting rule. The default is to double-quote all identifiers.

=cut

sub safe_id {
    my ( $this, $id ) = @_;
    $id =~ s/[^A-Za-z0-9_]//gs;    # protect against bad data
    $id = "\"$id\"";
    return $id;
}

=begin TML

---++ cast_to_numeric($sql) -> $sql
Cast a datum to a numeric type for comparison

=cut

sub cast_to_numeric {
    my ( $this, $d ) = @_;
    return "CAST(($d) AS NUMERIC)";
}

=begin TML

---++ cast_to_string($sql) -> $sql
Cast a datum to a character string type for comparison

=cut

sub cast_to_text {
    my ( $this, $d ) = @_;
    return
        "CAST(($d) AS "
      . $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{_DEFAULT}{type}
      . ')';
}

=begin TML

---++ make_comment() -> $comment_string
Make a comment string

=cut

sub make_comment {
    my $this = shift;
    return '/*' . join( ' ', @_ ) . '*/';
}

=begin TML

---++ strcat($str1 [$str2 [, ... strN]) -> $concatenated
Use the SQL string concatenation operator to concatente strings.

=cut

sub strcat {
    my $this = shift;
    return join( '||', @_ );
}

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2013-2014 Foswiki Contributors. All Rights Reserved.
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
