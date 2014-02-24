# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality::ODBC;

# Personality module for MS SQL Server

use strict;
use warnings;

use Foswiki::Contrib::DBIStoreContrib::Personality ();
our @ISA = ('Foswiki::Contrib::DBIStoreContrib::Personality');

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
    $this->{text_type}       = 'VARCHAR(MAX)';
    $this->{true_value}      = 'CAST(1 AS BIT)';
    $this->{true_type}       = Foswiki::Contrib::DBIStoreContrib::PSEUDO_BOOL;
    $this->{requires_COMMIT} = 0;

    return $this;
}

sub startup {
    my $this = shift;

    $this->{store}->{handle}->do('set QUOTED_IDENTIFIER ON');

    # There's no way in T-SQL to conditionally create a function
    # without using dynamic SQL, so we have to do this the hard way.
    my $exists = $this->{store}->{handle}->do(<<'SQL');
SELECT 1 WHERE OBJECT_ID('dbo.foswiki_CONVERT') IS NOT NULL
SQL
    if ( $exists == 0 ) {

        # make_number derived from is_numeric by Dmitri Golovan of Micralyne.
        $this->{store}->{handle}->do(<<'SQL');
CREATE FUNCTION foswiki_CONVERT( @value VARCHAR(MAX) ) RETURNS FLOAT AS
BEGIN
  RETURN (
    CASE
      WHEN @value NOT LIKE '%[^-0-9.+]%'
           AND (
             CHARINDEX('.', @value) = 0
             OR
             CHARINDEX('.', @value) > 0 AND LEN(@value) > 1
             AND LEN(@value) - LEN(REPLACE(@value, '.', '')) = 1
           ) 
           AND (
             CHARINDEX('-', @value)=0
             OR
             CHARINDEX('-', @value) = 1 AND LEN(@value) > 1
             AND CHARINDEX('-', @value, 2) = 0
           )
      THEN CONVERT(FLOAT, @value)
      ELSE 0
    END
  )
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
    $rhs =~ s/'/\\'/g;
    $rhs =~ s/\\/\\/g;

    # SMELL:
    return "dbo.fn_RegExIsMatch($lhs,'$rhs',1)=1";
}

sub length {
    return "LEN($_[1])";
}

sub strcat {
    my $this = shift;
    return join( '+', @_ );
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

