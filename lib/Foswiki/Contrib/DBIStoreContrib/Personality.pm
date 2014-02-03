# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality;

use strict;
use warnings;
use Assert;

# We try to use the ANSI SQL standard as far as possible, for the most
# part different SQL DB implementations support it fairly well. However
# they all have nuances, and there are areas where the support is not
# consistent - most notably in regex support. To that end we have to
# have a database personality module, which provides these custom
# operations in a consistent way.

sub new {
    my ( $class, $dbistore ) = @_;
    my $this = bless( { store => $dbistore }, $class );

    # SQL reserved words. The following words are reserved in all of
    # PostgresSQL, ANSI SQL, MySQL and SQLite so provide a good
    # working basis. Personality modules should extend this list.
    $this->reserve(
        qw(
          ALL ALTER AND AS ASC BETWEEN BY CASCADE CASE CHECK COLLATE COLUMN
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
    map { $this->{reserved}->{$_} = 1 } @_;
}

# Execute any SQL commands required to start the DB in ANSI mode.
# The default is no specific setup.
sub startup {
}

sub table_exists {
    my $this = shift;
    my $tables = join( ',', map { "'$_'" } @_ );

    # MySQL, Postgresql, MS SQL Server
    my $sql = <<SQL;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME IN ($tables)
SQL
    my @rows = $this->{store}->{handle}->selectrow_array($sql);

    #print STDERR scalar(@rows)." tables exist of ".scalar(@_)."\n";
    return scalar(@rows);
}

=begin TML

Construct an SQL expression to execute the given regular expression
match.
  * =$rhs= - right hand side of the match
  * =$op= - forwiki operation, either '~' (LIKE) or '=~' (REGEXP/RLIKE)
  * $lhs - the regular expression (foswiki syntax)
be different :-(

=cut

sub regexp {
    my ( $this, $lhs, $op, $rhs ) = @_;
    my $escape = '';
    if ( $op eq '=~' ) {
        $op = "SIMILAR TO";
    }
    else {
        $op = "LIKE";
    }

    if ( $rhs =~ s/^\"(.*)\"/$1/ ) {

        # String constant
        if ( $op eq 'SIMILAR TO' ) {

            # ANSI
            # | denotes alternation (either of two alternatives).
            # * denotes repetition of the previous item zero or
            # more times.
            # + denotes repetition of the previous item one or
            # more times.
            # Parentheses () can be used to group items into a
            # single logical item.
            # A bracket expression [...] specifies a character
            # class, just as in POSIX regular expressions.
            # Notice that bounded repetition (? and {...}) are
            # not provided.
            # Dot (.) is not a metacharacter.
            # As with LIKE, a backslash disables the special meaning
            # of any of these metacharacters; or a different escape
            # character can be specified with ESCAPE.
            # % and _ are zero or more or one char respectively.
            $rhs =~ s/(?<=[^\\])(\(.*\)|\[.*?\]|\\.|.)\?/($1|)/g;    # ?
            $rhs =~ s/(?<=[^\\])\\n/\n/g;
            $rhs =~ s/(?<=[^\\])\\r/\r/g;
            $rhs =~ s/(?<=[^\\])\\t/\t/g;
            $rhs =~ s/(?<=[^\\])\\d/[0-9]/g;
            $rhs =~ s/(?<=[^\\])\\D/[^0-9]/g;
            $rhs =~ s/(?<=[^\\])\\w/[a-zA-Z_]/g;
            $rhs =~ s/(?<=[^\\])\\W/[^a-zA-Z_]/g;
            $rhs =~ s/(?<=[^\\])\\b//g;               # not supported
            $rhs =~ s/(?<=[^\\])\{\d+(,\d*)?\}//g;    # not supported
            $rhs =~ s/(?<=[^\\])\./_/g;               # . -> _
            $rhs =~ s/'/\\'/g;
        }
        else {

            # wildcard match ('*' will match any number of characters,
            # '?' will match any single character
            if ( $rhs =~ /['_%\[\]]/ ) {    # quotemeta ANSI LIKE
                $rhs =~ s/([s'_%\[\]])/s$1/g;
                $escape = "s";
            }
            $rhs =~ s/\*/%/g;
            $rhs =~ s/\?/_/g;
        }
        $rhs = "\"$rhs\"";
    }
    return "$lhs $op $rhs" . ( $escape ? " ESCAPE '$escape'" : '' );
}

=begin TML

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

=cut

sub wildcard {
    my ( $this, $lhs, $rhs ) = @_;
    my @exprs;
    if ( $rhs =~ s/^\"(.*)\"$/$1/ ) {
        foreach my $spec ( split( /(?:,\s*|\|)/, $rhs ) ) {
            $spec =~ s/(['.])/\\$1/g;
            my $like = 0;
            $like = 1 if $spec =~ s/\*/.*/g;
            $like = 1 if $spec =~ s/\?/./g;

            if ($like) {
                $spec = "^$spec\$";
                push( @exprs, $this->regexp( $lhs, '=~', "\"$spec\"" ) );
            }
            else {
                push( @exprs, "$lhs='$spec'" );
            }
        }
    }
    return join( ' OR ', @exprs );
}

=begin TML

Convert a Foswiki time string to a number.
This implementation is for SQLite - there is no support in ANSI.

=cut

sub d2n {
    my ( $this, $arg ) = @_;

    return "CAST(strftime(\"%s\", $arg) AS FLOAT)";
}

=begin TML

Make sure the ID is safe to use in this dialect of SQL.
Unsafe IDs should be quoted using the dialect's identifier
quoting rule. The default is to double-quote it.

=cut

sub safe_id {
    my ( $this, $id ) = @_;
    if ( $this->{reserved}->{$id} ) {
        $id = "\"$id\"";
    }
    return $id;
}

=begin TML

Quote character for character strings - default is '

=cut

sub string_quote {
    return "'";
}

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2013 Foswiki Contributors. All Rights Reserved.
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
