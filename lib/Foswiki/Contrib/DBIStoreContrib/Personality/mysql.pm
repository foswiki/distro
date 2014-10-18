# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality::mysql;

# DBIStoreContrib personality module for MySQL

use strict;
use warnings;

use Foswiki::Contrib::DBIStoreContrib::Personality ();
our @ISA = ('Foswiki::Contrib::DBIStoreContrib::Personality');

# Use the database version this has been tested with
our $VERSION = '5.5.37';

sub new {
    my ( $class, $dbistore ) = @_;
    my $this = $class->SUPER::new($dbistore);
    $this->reserve(
        qw/
          ACCESSIBLE ANALYZE ASENSITIVE BEFORE BIGINT BINARY BLOB BOTH CALL
          CHANGE CHAR CHARACTER CONDITION CONTINUE CONVERT CURRENT_USER CURSOR
          DATABASE DATABASES DAY_HOUR DAY_MICROSECOND DAY_MINUTE DAY_SECOND DEC
          DECIMAL DECLARE DELAYED DESCRIBE DETERMINISTIC DISTINCTROW DIV DOUBLE
          DUAL EACH ELSEIF ENCLOSED ESCAPED EXIT EXPLAIN FALSE FETCH FLOAT
          FLOAT4 FLOAT8 FORCE FULLTEXT GET GRANT HIGH_PRIORITY HOUR_MICROSECOND
          HOUR_MINUTE HOUR_SECOND IF IGNORE INFILE INOUT INSENSITIVE INT INT1
          INT2 INT3 INT4 INT8 INTEGER INTERVAL IO_AFTER_GTIDS IO_BEFORE_GTIDS
          ITERATE KEYS KILL LEADING LEAVE LIMIT LINEAR LINES LOAD LOCALTIME
          LOCALTIMESTAMP LOCK LONG LONGBLOB LONGTEXT LOOP LOW_PRIORITY
          MASTER_BIND MASTER_SSL_VERIFY_SERVER_CERT MATCH MAXVALUE MEDIUMBLOB
          MEDIUMINT MEDIUMTEXT MIDDLEINT MINUTE_MICROSECOND MINUTE_SECOND MOD
          MODIFIES NATURAL NO_WRITE_TO_BINLOG NONBLOCKING NUMERIC OPTIMIZE
          OPTION OPTIONALLY OUT OUTFILE PARTITION PRECISION PROCEDURE PURGE
          RANGE READ READ_WRITE READS REAL REGEXP RELEASE RENAME REPEAT REPLACE
          REQUIRE RESIGNAL RETURN REVOKE RLIKE SCHEMA SCHEMAS SECOND_MICROSECOND
          SENSITIVE SEPARATOR SHOW SIGNAL SMALLINT SPATIAL SPECIFIC SQL
          SQL_BIG_RESULT SQL_CALC_FOUND_ROWS SQL_SMALL_RESULT SQLEXCEPTION
          SQLSTATE SQLWARNING SSL STARTING STRAIGHT_JOIN TERMINATED TINYBLOB
          TINYINT TINYTEXT TRAILING TRIGGER TRUE UNDO UNLOCK UNSIGNED USAGE USE
          USING UTC_DATE UTC_TIME UTC_TIMESTAMP VARBINARY VARCHAR VARCHARACTER
          VARYING WHILE WRITE XOR YEAR_MONTH ZEROFILL/
    );
    return $this;
}

sub startup {
    my ( $this, $dbh ) = @_;
    $this->SUPER::startup($dbh);

    # MySQL has to be kicked in the ANSIs
    $this->{dbh}->do("SET sql_mode='ANSI'");
    $this->{dbh}->do('SELECT @sql_mode');
}

sub regexp {
    my ( $this, $lhs, $rhs ) = @_;

    unless ( $rhs =~ s/^'(.*)'$/$1/s ) {

        # Somewhat risky....
        return "$lhs REGEXP $rhs";
    }

    # MySQL uses POSIX regular expressions.

    # POSIX has no support for (?i: etc
    $rhs =~ s/^\(\?[a-z]+:(.*)\)$/$1/;              # remove (?:i)
                                                    # Nor hex character codes
    $rhs =~ s/\\x([0-9a-f]{2})/_char("0x$1")/gei;
    $rhs =~ s/\\x{([0-9a-f]+)}/_char("0x$1")/gei;

    # Nor \d, \D
    $rhs =~ s/(^|(?<=[^\\]))\\d/[0-9]/g;
    $rhs =~ s/(^|(?<=[^\\]))\\D/[^0-9]/g;

    # Nor \s, \S, \w, \W
    $rhs =~ s/(^|(?<=[^\\]))\\s/[ \011\012\015]/g;
    $rhs =~ s/(^|(?<=[^\\]))\\S/[^ \011\012\015]/g;
    $rhs =~ s/(^|(?<=[^\\]))\\w/[a-zA-Z0-9_]/g;
    $rhs =~ s/(^|(?<=[^\\]))\\W/[^a-zA-Z0-9_]/g;

    # Convert X? to (X|)
    $rhs =~ s/(?<=[^\\])(\(.*\)|\[.*?\]|\\.|.)\?/($1|)/g;    # ?
         # Handle special characters
    $rhs =~ s/(?<=[^\\])\\n/\n/g;             # will this work?
    $rhs =~ s/(?<=[^\\])\\r/\r/g;
    $rhs =~ s/(?<=[^\\])\\t/\t/g;
    $rhs =~ s/(?<=[^\\])\\b//g;               # not supported
    $rhs =~ s/(?<=[^\\])\{\d+(,\d*)?\}//g;    # not supported
                                              # Escape '
    $rhs =~ s/\\/\\\\/g;

    return "$lhs REGEXP '$rhs'";
}

sub cast_to_numeric {
    my ( $this, $d ) = @_;
    return "CAST(($d) AS DECIMAL)";
}

sub cast_to_text {
    my ( $this, $d ) = @_;
    return "CAST(($d) AS CHAR)";
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
