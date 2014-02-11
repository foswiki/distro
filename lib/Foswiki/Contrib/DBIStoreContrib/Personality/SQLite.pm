# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality::SQLite;

use strict;
use warnings;

use Foswiki::Contrib::DBIStoreContrib::Personality ();
our @ISA = ('Foswiki::Contrib::DBIStoreContrib::Personality');

sub new {
    my ( $class, $dbistore ) = @_;
    my $this = $class->SUPER::new($dbistore);
    $this->reserve(
        qw(
          ABORT ACTION ADD AFTER ALL ALTER ANALYZE AND AS ASC ATTACH
          AUTOINCREMENT BEFORE BEGIN BETWEEN BY CASCADE CASE CAST CHECK COLLATE
          COLUMN COMMIT CONFLICT CONSTRAINT COVERING CREATE CROSS CURRENT_DATE
          CURRENT_TIME CURRENT_TIMESTAMP DATABASE DEFAULT DEFERRABLE DEFERRED
          DELETE DESC DETACH DISTINCT DROP EACH ELSE END ESCAPE EXCEPT EXCLUSIVE
          EXISTS EXPLAIN FAIL FOR FOREIGN FROM FULL GLOB GROUP HAVING IF IGNORE
          IMMEDIATE IN INDEX INDEXED INITIALLY INNER INSERT INSTEAD INTERSECT
          INTO IS ISNULL JOIN KEY LEFT LIKE LIMIT MATCH NATURAL NO NOT NOTNULL
          NULL OF OFFSET ON OR ORDER OUTER PLAN PRAGMA PRIMARY QUERY RAISE
          REFERENCES REGEXP REINDEX RELEASE RENAME REPLACE RESTRICT RIGHT
          ROLLBACK ROW SAVEPOINT SELECT SET TABLE TEMP TEMPORARY THEN TO
          TRANSACTION TRIGGER UNION UNIQUE UPDATE USING VACUUM VALUES VIEW
          VIRTUAL WHEN WHERE WITH WITHOUT
          )
    );
    return $this;
}

sub startup {
    my $this = shift;

    # Load PCRE, required for regexes
    $this->{store}->{handle}->sqlite_enable_load_extension( my $_enabled = 1 );
    $this->{store}->{handle}->prepare(
"SELECT load_extension('$Foswiki::cfg{Extensions}{DBIStoreContrib}{SQLite}{PCRE}')"
    );
}

sub table_exists {
    my $this   = shift;
    my $tables = join( ',', map { "'$_'" } @_ );
    my $sql    = <<SQL;
SELECT name FROM sqlite_master
    WHERE type='table' AND name IN ($tables)
SQL
    my @rows = $this->{store}->{handle}->selectrow_array($sql);

    #print STDERR scalar(@rows)." tables exist of ".scalar(@_)."\n";
    return scalar(@rows);
}

sub regexp {
    my ( $this, $lhs, $rhs ) = @_;

    unless ( $rhs =~ s/^'(.*)'$/$1/s ) {

        # Somewhat risky....
        return "$lhs REGEXP $rhs";
    }

    # The macro parser does horrible things with \, causing \\
    # to become \\\. Force it back to \\
    $rhs =~ s/\\{3}/\\\\/g;

    # SQLite uses PCRE, which supports all of Perl except hex
    # char codes
    $rhs =~ s/\\x([0-9a-f]{2})/_char("0x$1")/gei;
    $rhs =~ s/\\x{([0-9a-f]+)}/_char("0x$1")/gei;

    # Escape '
    $rhs =~ s/'/\\'/g;

    return "$lhs REGEXP '$rhs'";
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
