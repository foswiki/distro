# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality::ODBC;

# Personality module for MS SQL Server / Transact-SQL

use strict;
use warnings;

use Foswiki::Contrib::DBIStoreContrib::Personality ();
our @ISA = ('Foswiki::Contrib::DBIStoreContrib::Personality');

# Use the database version this has been tested with
our $VERSION = 'Microsoft SQL Server 2005 - 9.00.4035.00 Standard Edition';

sub new {
    my ( $class, $dbistore ) = @_;
    my $this = $class->SUPER::new($dbistore);
    $this->reserve(
        qw/
          ANY AUTHORIZATION BACKUP BEGIN BREAK BROWSE BULK CHECKPOINT CLOSE
          CLUSTERED COALESCE COMMIT COMPUTE CONTAINS CONTAINSTABLE CONTINUE
          CONVERT CURRENT CURRENT_USER CURSOR DATABASE DBCC DEALLOCATE DECLARE
          DENY DISK DISTRIBUTED DOUBLE DUMP END ERRLVL ESCAPE EXCEPT EXEC
          EXECUTE EXIT EXTERNAL FETCH FILE FILLFACTOR FREETEXT FREETEXTTABLE
          FULL FUNCTION GOTO GRANT HOLDLOCK IDENTITY IDENTITY_INSERT IDENTITYCOL
          IF INTERSECT KILL LINENO LOAD MERGE NATIONAL NOCHECK NONCLUSTERED
          NULLIF OF OFF OFFSETS OPEN OPENDATASOURCE OPENQUERY OPENROWSET OPENXML
          OPTION OVER PERCENT PIVOT PLAN PRECISION PRINT PROC PROCEDURE PUBLIC
          RAISERROR READ READTEXT RECONFIGURE REPLICATION RESTORE RETURN REVERT
          REVOKE ROLLBACK ROWCOUNT ROWGUIDCOL RULE SAVE SCHEMA SECURITYAUDIT
          SEMANTICKEYPHRASETABLE SEMANTICSIMILARITYDETAILSTABLE
          SEMANTICSIMILARITYTABLE SESSION_USER SETUSER SHUTDOWN SOME STATISTICS
          SYSTEM_USER TABLESAMPLE TEXTSIZE TOP TRAN TRANSACTION TRIGGER TRUNCATE
          TRY_CONVERT TSEQUAL UNPIVOT UPDATETEXT USE USER VARYING VIEW WAITFOR
          WHILE WITHIN GROUP WRITETEXT/
    );

    # Override the default type in the schema
    $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{_DEFAULT}{type} =
      'VARCHAR(MAX)';
    $this->{true_value}      = 'CAST(1 AS BIT)';
    $this->{true_type}       = Foswiki::Contrib::DBIStoreContrib::PSEUDO_BOOL;
    $this->{requires_COMMIT} = 0;

    return $this;
}

sub startup {
    my ( $this, $dbh ) = @_;
    $this->SUPER::startup($dbh);

    $this->{dbh}->do('set QUOTED_IDENTIFIER ON');

    # There's no way in T-SQL to conditionally create a function
    # without using dynamic SQL, so we have to do this the hard way.
    my $exists = $this->{dbh}->do(<<'SQL');
SELECT 1 WHERE OBJECT_ID('dbo.foswiki_CONVERT') IS NOT NULL
SQL
    if ( $exists == 0 ) {

        # Error-tolerant number conversion. Works like perl.
        $this->{dbh}->do(<<'SQL');
CREATE FUNCTION foswiki_CONVERT( @value VARCHAR(MAX) ) RETURNS FLOAT AS
 BEGIN
  IF @value LIKE '%[^-+0-9eE]%' RETURN 0
  IF NOT ( @value LIKE '[0-9]%' OR @value LIKE '[-+][0-9]%') RETURN 0
  -- definitely have a number; just need to find the end
  DECLARE @s INT
  DECLARE @ss VARCHAR(2)
  SET @s = 1
  IF @value LIKE '[-+]%' SET @s = 2
  SET @ss = SUBSTRING(@value, @s, 2)
  WHILE @ss LIKE '[0-9]%'
   BEGIN
    SET @s = @s + 1
    SET @ss = SUBSTRING(@value, @s, 2);
   END
  IF @ss LIKE '.[0-9eE]'
   BEGIN -- fractional part
    SET @s = @s + 1;
    WHILE SUBSTRING(@value, @s, 1) LIKE '[0-9]' SET @s = @s + 1
    SET @ss = SUBSTRING(@value, @s, 2);
   END
  IF @ss LIKE '[eE][-+0-9]'
   BEGIN --- exponent
    SET @s = @s + 2; -- skip e and sign or first digit
    WHILE SUBSTRING(@value, @s, 1) LIKE '[0-9]' SET @s = @s + 1
   END
  IF @s <= DATALENGTH(@value) RETURN 0
  RETURN CONVERT(FLOAT, @value)
 END
SQL
    }
}

sub cast_to_numeric {
    my ( $this, $d ) = @_;
    return "dbo.foswiki_CONVERT($d)";
}

sub regexp {
    my ( $this, $lhs, $rhs ) = @_;

    unless ( $rhs =~ s/^'(.*)'$/$1/s ) {
        return "dbo.fn_RegExIsMatch($lhs,$rhs,1)=1";    # risky!
    }
    $rhs =~ s/\\/\\\\/g;

    return "dbo.fn_RegExIsMatch($lhs,'$rhs',1)=1";
}

sub length {
    return "LEN($_[1])";
}

sub strcat {
    my $this = shift;
    return join( '+', @_ );
}

sub d2n {
    my ( $this, $arg ) = @_;

    # Convert date string to number
    # 22088800 = number of seconds from 1900-01-01 to start of epoch
    # 86400 = number of seconds in a day
    return "(CAST(CONVERT(datetime, $arg) AS FLOAT) * 86400 - 22088800)";
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

