# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality::Pg;

# DBIStoreContrib personality module for Postgresql

use strict;
use warnings;
use Assert;

use Foswiki::Contrib::DBIStoreContrib::Personality ();
our @ISA = ('Foswiki::Contrib::DBIStoreContrib::Personality');

# Use the database version this has been tested with
our $VERSION = '9.1.13';

sub new {
    my ( $class, $dbistore ) = @_;
    my $this = $class->SUPER::new($dbistore);
    $this->reserve(
        qw/
          ABORT ABSOLUTE ACCESS ACTION ADMIN AFTER AGGREGATE ALSO ALWAYS ANALYSE
          ANALYZE ANY ARRAY ASSERTION ASSIGNMENT ASYMMETRIC AT ATTRIBUTE
          AUTHORIZATION BACKWARD BEFORE BEGIN BIGINT BINARY BIT BOOLEAN BOTH
          CACHE CALLED CASCADED CAST CATALOG CHAIN CHAR CHARACTER
          CHARACTERISTICS CHECKPOINT CLASS CLOSE CLUSTER COALESCE COLLATION
          COMMENT COMMENTS COMMIT COMMITTED CONCURRENTLY CONFIGURATION
          CONNECTION CONSTRAINTS CONTENT CONTINUE CONVERSION COPY COST CSV
          CURRENT CURRENT_CATALOG CURRENT_ROLE CURRENT_SCHEMA CURRENT_USER
          CURSOR CYCLE DATA DATABASE DAY DEALLOCATE DEC DECIMAL DECLARE DEFAULTS
          DEFERRABLE DEFERRED DEFINER DELIMITER DELIMITERS DICTIONARY DISABLE
          DISCARD DO DOCUMENT DOMAIN DOUBLE EACH ENABLE ENCODING ENCRYPTED END
          ENUM ESCAPE EVENT EXCEPT EXCLUDE EXCLUDING EXCLUSIVE EXECUTE EXPLAIN
          EXTENSION EXTERNAL EXTRACT FALSE FAMILY FETCH FIRST FLOAT FOLLOWING
          FORCE FORWARD FREEZE FULL FUNCTION FUNCTIONS GLOBAL GRANT GRANTED
          GREATEST HANDLER HEADER HOLD HOUR IDENTITY IF ILIKE IMMEDIATE
          IMMUTABLE IMPLICIT INCLUDING INCREMENT INDEXES INHERIT INHERITS
          INITIALLY INLINE INOUT INPUT INSENSITIVE INSTEAD INT INTEGER INTERSECT
          INTERVAL INVOKER ISNULL ISOLATION LABEL LANGUAGE LARGE LAST LATERAL
          LC_COLLATE LC_CTYPE LEADING LEAKPROOF LEAST LEVEL LIMIT LISTEN LOAD
          LOCAL LOCALTIME LOCALTIMESTAMP LOCATION LOCK MAPPING MATCH
          MATERIALIZED MAXVALUE MINUTE MINVALUE MODE MONTH MOVE NAME NAMES
          NATIONAL NATURAL NCHAR NEXT NO NONE NOTHING NOTIFY NOTNULL NOWAIT
          NULLIF NULLS NUMERIC OBJECT OF OFF OFFSET OIDS ONLY OPERATOR OPTION
          OPTIONS OUT OVER OVERLAPS OVERLAY OWNED OWNER PARSER PARTIAL PARTITION
          PASSING PASSWORD PLACING PLANS POSITION PRECEDING PRECISION PREPARE
          PREPARED PRESERVE PRIOR PRIVILEGES PROCEDURAL PROCEDURE PROGRAM QUOTE
          RANGE READ REAL REASSIGN RECHECK RECURSIVE REF REFRESH REINDEX
          RELATIVE RELEASE RENAME REPEATABLE REPLACE REPLICA RESET RESTART
          RETURNING RETURNS REVOKE ROLE ROLLBACK ROW ROWS RULE SAVEPOINT SCHEMA
          SCROLL SEARCH SECOND SECURITY SEQUENCE SEQUENCES SERIALIZABLE SERVER
          SESSION SESSION_USER SETOF SHARE SHOW SIMILAR SIMPLE SMALLINT SNAPSHOT
          SOME STABLE STANDALONE START STATEMENT STATISTICS STDIN STDOUT STORAGE
          STRICT STRIP SUBSTRING SYMMETRIC SYSID SYSTEM TABLES TABLESPACE TEMP
          TEMPLATE TEMPORARY TEXT TIME TIMESTAMP TRAILING TRANSACTION TREAT
          TRIGGER TRIM TRUE TRUNCATE TRUSTED TYPE TYPES UNBOUNDED UNCOMMITTED
          UNENCRYPTED UNKNOWN UNLISTEN UNLOGGED UNTIL USER USING VACUUM VALID
          VALIDATE VALIDATOR VALUE VARCHAR VARIADIC VARYING VERBOSE VERSION VIEW
          VOLATILE WHITESPACE WINDOW WITHOUT WORK WRAPPER WRITE XML
          XMLATTRIBUTES XMLCONCAT XMLELEMENT XMLEXISTS XMLFOREST XMLPARSE XMLPI
          XMLROOT XMLSERIALIZE YEAR YES ZONE/
    );
    $this->{requires_COMMIT} = 0;    # AUTOCOMMIT is on

    return $this;
}

sub startup {
    my ( $this, $dbh ) = @_;

    $this->SUPER::startup($dbh);
    ASSERT( $this->{dbh} ) if DEBUG;
    $this->{dbh}->{AutoCommit} = 1;

    #    $this->{dbh}->do('\\set ON_ERROR_ROLLBACK true');
    $this->{dbh}->do("SET client_min_messages = 'warning'");
    $this->{dbh}->do(<<'DO');
CREATE OR REPLACE FUNCTION make_number(TEXT) RETURNS NUMERIC AS $$
DECLARE i NUMERIC;
BEGIN
    i := $1::NUMERIC;
    return i;
EXCEPTION WHEN invalid_text_representation THEN
    return 0;
END;
$$ LANGUAGE PLPGSQL IMMUTABLE STRICT;
DO
}

sub cast_to_numeric {
    my ( $this, $d ) = @_;
    return "make_number($d)";
}

sub _char {
    my $hex = 0 + shift;
    return quotemeta( chr($hex) );
}

sub regexp {
    my ( $this, $lhs, $rhs ) = @_;

    unless ( $rhs =~ s/^'(.*)'$/$1/s ) {
        return "$lhs ~ $rhs";    # risky!
    }

    my $i = ( $rhs =~ s/^\(\?i:(.*)\)$/$1/s ) ? '*' : '';

    $rhs =~ s/\\x([0-9a-f]{2})/_char("0x$1")/gei;
    $rhs =~ s/\\x{([0-9a-f]+)}/_char("0x$1")/gei;

    # Postgresql supports full POSIX regexes.

    return "$lhs ~$i '$rhs'";
}

sub length {
    return "char_length($_[1])";
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
