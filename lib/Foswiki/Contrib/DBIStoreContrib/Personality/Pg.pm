# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality::Pg;

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
    $this->{store}->{handle}->do("SET client_min_messages = 'warning'");
}

sub _char {
    my $hex = 0 + shift;
    return quotemeta( chr($hex) );
}

sub regexp {
    my ( $this, $lhs, $op, $rhs ) = @_;
    $rhs =~ s/\\x([0-9a-f]{2})/_char("0x$1")/gei;
    $rhs =~ s/\\x{([0-9a-f]+)}/_char("0x$1")/gei;
    return $this->SUPER::regexp( $lhs, $op, $rhs ) if ( $op eq '~' );

    # Postgresql supports full POSIX regexes. Just need to escape
    # single quote.
    $rhs =~ s/'/\\'/g;
    return "$lhs ~ '$rhs'";
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
