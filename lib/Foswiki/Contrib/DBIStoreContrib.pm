# See bottom of file for license and copyright information.
package Foswiki::Contrib::DBIStoreContrib;

=begin TML

---+ package Foswiki::Contrib::DBIStoreContrib

Base functionality of the DBIStoreContrib. The methods here are common
to both the cache and the pure store usages of the contrib. They are
responsible for the construction and management of the database.

No other module in DBIStoreContrib need know anything about DBI (except
for the nature of a statement handle).

=cut

use strict;
use warnings;
use Assert;
use Foswiki       ();
use Foswiki::Func ();
use DBI           ();

our $VERSION = '1.0';          # plugin version is also locked to this
our $RELEASE = '8 May 2014';

# Very verbose debugging. Used by all modules in the suite.
use constant MONITOR => 0;

our $SHORTDESCRIPTION = 'Use DBI to implement a store using an SQL database.';

# Type identifiers.
# FIRST 3 MUST BE KEPT IN LOCKSTEP WITH Foswiki::Infix::Node
# Declared again here because the constants are not defined
# in Foswiki 1.1 and earlier
use constant {
    NAME   => 1,
    NUMBER => 2,
    STRING => 3,
};

# Additional types local to this module - must not overlap known
# types
use constant {
    UNKNOWN => 0,

    # Gap for 1.2 types HASH and META

    BOOLEAN  => 10,
    SELECTOR => 11,    # Temporary, synonymous with UNKNOWN

    VALUE => 12,
    TABLE => 13,

    # An integer type used during hoisting where DB doesn't support
    # a BOOLEAN type
    PSEUDO_BOOL => 14,
};

our $personality;    # personality module for the selected DSN
our $dbh;            # DBI handle

sub personality {
    unless ($personality) {

        # Custom code to put DB's into ANSI mode and clean up error reporting
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN} =~ /^dbi:(.*?):/i;
        my $module = "Foswiki::Contrib::DBIStoreContrib::Personality::$1";

        eval "require $module";
        if ($@) {
            _say $@ if MONITOR;
            die "Failed to load personality module $module";
        }
        $personality = $module->new();
    }
    return $personality;
}

sub _say {
    Foswiki::Func::writeDebug( join( "\n", @_ ) );
}

# Connect on demand - PRIVATE
# If $session is defined, do a hard reset
sub _connect {
    my ($session) = @_;

    return 1 if $dbh && !$session;

    unless ($dbh) {

        if ($Foswiki::inUnitTestMode) {

            # Change the DSN to a SQLite test db, which is held in the data
            # area; that way it will be ripped down by -clean
            $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN} =
"dbi:SQLite:dbname=$Foswiki::cfg{WorkingDir}/TemporarySQLiteCache";
            $Foswiki::cfg{Extensions}{DBIStoreContrib}{Username} = '';
            $Foswiki::cfg{Extensions}{DBIStoreContrib}{Password} = '';
        }

        _say "CONNECT $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN}..."
          if MONITOR;

        $dbh = DBI->connect(
            $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN},
            $Foswiki::cfg{Extensions}{DBIStoreContrib}{Username},
            $Foswiki::cfg{Extensions}{DBIStoreContrib}{Password},
            { RaiseError => 1, AutoCommit => 1 }
        ) or die $DBI::errstr;

        _say "Connected" if MONITOR;

        personality()->startup($dbh);
    }

    # Check if the DB is initialised with a quick sniff of the tables
    # to see if all the ones we expect are there
    if ( $personality->table_exists( 'metatypes', 'topic' ) ) {
        if (MONITOR) {

            # Check metatypes integrity
            my $tables = $dbh->selectcol_arrayref('SELECT name FROM metatypes');
            foreach my $table (@$tables) {
                unless ( $personality->table_exists($table) ) {
                    _say "$table is in metatypes but does not exist";
                }
            }
        }
        return 1 unless ($session);
        _say "HARD RESET" if MONITOR;
    }
    elsif (MONITOR) {
        _say "Base tables don't exist";
        ASSERT(0);
    }

    # Hard reset; strip down all existing tables

    # The metatypes table is how we know which tables are ours. Add
    # this to the schema.
    my @tables = keys %{ $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema} };
    if ( $personality->table_exists('metatypes') ) {
        my $mts = $dbh->selectcol_arrayref('SELECT name FROM metatypes');
        foreach my $t (@$mts) {
            unless ( grep( /^$t$/, @tables ) ) {
                push( @tables, $t );
            }
        }
    }

    foreach my $table (@tables) {
        if ( $personality->table_exists($table) ) {
            $dbh->do( 'DROP TABLE ' . $personality->safe_id($table) );
            _say "Dropped $table" if MONITOR;
        }
    }

    # No topic table, or we've had a hard reset
    _say "Loading DB schema" if MONITOR;
    _createTables();

    # We only preload after a hard reset
    if ( $session && !$Foswiki::inUnitTestMode ) {
        _say "Schema loaded; preloading content" if MONITOR;
        _preload($session);
        _say "DB preloaded" if MONITOR;
    }
    return 1;
}

# Create the table for the given META - PRIVATE
sub _createTableForMETA {
    my ($t) = @_;
    my $schema = $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{$t};

    # Create table
    my $cols = join( ',',
        map { $personality->safe_id($_) . ' ' . _column( $t, $_ )->{type} }
        grep( !/^_/, keys %$schema ) );
    my $sn  = $personality->safe_id($t);
    my $sql = "CREATE TABLE $sn ( $cols )";
    _say $sql if MONITOR;
    $dbh->do($sql);

    # Add the table to the table of tables
    $dbh->do("INSERT INTO metatypes (name) VALUES ( '$t' )");

    # Create indexes
    while ( my ( $col, $v ) = each %$schema ) {
        $v = $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{$v}
          unless ( ref($v) );
        if ( $v->{index} ) {
            my $sql =
                'CREATE INDEX '
              . $personality->safe_id("IX_${t}_${col}") . ' ON '
              . $personality->safe_id($t) . '('
              . $personality->safe_id($col) . ')';
            _say $sql if MONITOR;
            $dbh->do($sql);
        }
    }
}

# Create all the base tables in the DB (including all
# default META: tables) - PRIVATE
sub _createTables {

    # Create the topic table. This links the web name, topic name,
    # topic text and raw text of the topic.
    my @cols;

    foreach my $type (
        keys( %{ $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema} } ) )
    {
        next unless defined $type->{_level};

        if ( $type->{_level} == 0 ) {
            my $uniq = '';
            foreach my $c ( keys %$type ) {
                my $col = _column( 'topic', $c );
                my $s = $personality->safe_id($c) . ' ' . $col->{type};
                if ( $col->{primary} ) {
                    $uniq = ",UNIQUE " . $personality->safe_id($c);
                    $s .= ' PRIMARY KEY';
                }
                push( @cols, $s );
            }
            my $colst = join( ',', @cols );
            $dbh->do("CREATE TABLE $type ($colst$uniq)");
        }
        else {
            # Create the tables for each registered META: type

            my $t = $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{$type};
            unless ( $t =~ /^_/ ) {
                _say "Creating table for $type" if MONITOR;
                _createTableForMETA($type);
            }
        }
    }
    $dbh->do('COMMIT') if $personality->{requires_COMMIT};
}

# Load all existing webs and topics into the DB (expensive)
sub _preload {
    my ($session) = @_;
    my $root      = Foswiki::Meta->new($session);
    my $wit       = $root->eachWeb();
    while ( $wit->hasNext() ) {
        my $web = $wit->next();
        _preloadWeb( $web, $session );
    }
    $dbh->do('COMMIT') if $personality->{requires_COMMIT};
}

# Preload a single web - PRIVATE
sub _preloadWeb {
    my ( $w, $session ) = @_;
    my $web = Foswiki::Meta->new( $session, $w );
    insert($web);
    my $tit = $web->eachTopic();
    while ( $tit->hasNext() ) {
        my $t = $tit->next();
        my $topic = Foswiki::Meta->load( $session, $w, $t );
        _say "Preloading topic $w/$t" if MONITOR;
        insert($topic);
      TODO: load attachments;
    }

    my $wit = $web->eachWeb();
    while ( $wit->hasNext() ) {
        _preloadWeb( $w . '/' . $wit->next(), $session );
    }
}

sub _convertToUTF8 {
    my $text = shift;
    $text = Encode::decode( $Foswiki::cfg{Site}{CharSet}, $text );
    $text = Encode::encode( 'utf-8', $text );
    return $text;
}

sub _truncate {
    my ( $data, $size ) = @_;
    return $data unless defined($size) && length($data) > $size;
    Foswiki::Func::writeWarning( 'Truncating ' . length($data) . " to $size" )
      if MONITOR;
    return substr( $data, 0, $size - 3 ) . '...';
}

# Get the column schema for the given column.
sub _column {
    my ( $table, $column ) = @_;

    my $l = $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{$table};
    $l = $l->{$column} if $l;
    if ( defined $l ) {

        # If the type name starts with an underscore, map to a default
        # type name
        if ( $l =~ /^_/ ) {
            $l = $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{$l};
            ASSERT($l) if DEBUG;
        }
        return $l;
    }
    Foswiki::Func::writeWarning(
        "DBIStoreContrib: Could not determine a type for $table.$column")
      if DEBUG;
    return $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{_DEFAULT};
}

sub start {

    # Start a transaction
}

sub commit {

    # Commit a transaction
    $dbh->do('COMMIT') if $personality->{requires_COMMIT};
}

# PACKAGE PRIVATE support forced disconnection when a store shim is decoupled.
sub disconnect {
    if ($dbh) {
        $dbh->disconnect();    # SMELL: keep around in FCGI?
        undef $dbh;
    }
}

=begin TML

---++ StaticMethod insert($meta [, $attachment, $data])
Insert an object into the database

May throw an execption if SQL failed.

=cut

sub insert {
    my ( $mo, $attachment, $data ) = @_;

    _connect();

    if ( defined $attachment ) {
        ASSERT( $mo->web )   if DEBUG;
        ASSERT( $mo->topic ) if DEBUG;

        # Note that we DO NOT explicitly add the META:FILEATTACHMENT
        # entry table here.
        # That is done at a much higher level in Foswiki::Meta when the
        # referring topic has it's meta-data rewritten.
        # Here we simply clear down the raw data stored for the attachment.
        # TODO: get the attachment data
        my $tid =
          $dbh->selectrow_array( 'SELECT tid FROM topic '
              . "WHERE web='"
              . $mo->web
              . " AND name='"
              . $mo->topic
              . "'" );
        ASSERT($tid) if DEBUG;
        $dbh->do( "UPDATE FILEATTACHMENT "
              . " SET raw='$data'"
              . " WHERE tid='$tid' AND name='$attachment'" );
    }
    elsif ( defined $mo->topic() ) {

        my $tid = $dbh->selectrow_array('SELECT MAX(tid) FROM topic')
          || 0;
        $tid++;
        _say "\tInsert $tid" if MONITOR;
        my $text = _convertToUTF8( $mo->text() );
        my $esf  = _convertToUTF8( $mo->getEmbeddedStoreForm() );
        $dbh->do(
            'INSERT INTO topic (tid,web,name,text,raw) VALUES (?,?,?,?,?)',
            {}, $tid, $mo->web(), $mo->topic(), $text, $esf );

        foreach my $type ( keys %$mo ) {

            # Make sure it's registered.
            next
              unless (
                defined $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}
                {$type}
                || $Foswiki::cfg{Extensions}{DBIStoreContrib}
                {AutoloadUnknownMETA} && $type =~ /^[A-Z][A-Z0-9_]+$/ );

            # Make sure the table exists
            my $schema =
              $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{$type};

            unless ($schema) {

                # The table is not in the schema. Is it in the DB?
                if ( $personality->table_exists($type) ) {

                    # Pull the column names from the DB
                    $schema =
                      { map { $_ => '_DEFAULT' }
                          $personality->get_columns($type) };
                    $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}{$type} =
                      $schema;
                }
                else {
                    # The table is not in the DB either. Try deduce the schema
                    # from the data.
                    $schema = {};

                    # Check the entries to ensure we have picked up all the
                    # columns. We read *all* entries so we get all columns.
                    foreach my $item ( $mo->find($type) ) {
                        foreach my $col ( keys(%$item) ) {
                            $schema->{$col} ||= '_DEFAULT';
                        }
                    }
                    _say "Creating fly table for $type" if MONITOR;
                    $Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema}->{$type}
                      = $schema;
                    _createTableForMETA($type);
                }
            }

            # The table might be in the schema but not in the database
            # if it is deleted from the database while we are not looking.
            # Table deletion is very rare, and admin only, so this is an
            # acceptable risk.

            # Insert this row
            my $data = $mo->{$type};

            foreach my $item (@$data) {
                my @kns = keys(%$item);

                # Check that the table is configured to accept this data
                foreach my $kn (@kns) {
                    unless ( $schema->{$kn} ) {

                        # The column is not in the schema
                        unless ( $personality->column_exists( $type, $kn ) ) {

                            # The column might be in the DB but not in
                            # the schema. This is unlikely, but possible.

                            # _column will give us the default if the column
                            # name isn't matched
                            $schema->{$kn} = _column( $type, $kn );

                            $dbh->do( 'ALTER TABLE '
                                  . $personality->safe_id($type) . ' ADD '
                                  . $personality->safe_id($kn) . ' '
                                  . $schema->{$kn}->{type} );
                        }
                    }

                    # The column might be in the schema but not in the DB
                    # if there was a race condition and someone deleted the
                    # table under us. Table deletion is very rare, and admin
                    # only, so this is an acceptable risk.
                }

                unshift( @kns, 'tid' );
                my $sql =
                    'INSERT INTO '
                  . $personality->safe_id($type) . ' ('
                  . join( ',', map { $personality->safe_id($_) } @kns )
                  . ") VALUES ("
                  . join( ',', map { '?' } @kns ) . ")";
                shift(@kns);

                _say "$sql [tid,"
                  . join( ',', map { _truncate( $item->{$_}, 80 ) } @kns ) . ']'
                  if MONITOR;

                $dbh->do(
                    $sql,
                    {},
                    $tid,
                    map {
                        _truncate(
                            _convertToUTF8( $item->{$_} ),
                            _column( $type, $_ )->{truncate_to}
                          )
                    } @kns
                );
            }
        }
    }
    else {
        # Currently no way to add a web. Webs are identified by
        # a unique search over the topics table.
    }
}

=begin TML

---++ StaticMethod remove($meta [, $attachment])

Delete a FW object from the database.

May throw an execption if SQL failed.

=cut

sub remove {
    my ( $mo, $attachment ) = @_;

    _connect();
    my $sql = "SELECT tid FROM topic WHERE topic.web='" . $mo->web() . "'";
    $sql .= " AND topic.name='" . $mo->topic() . "'" if defined $mo->topic();
    my $tids = $dbh->selectcol_arrayref($sql);
    return unless scalar(@$tids);

    if ( defined $attachment ) {

        ASSERT( scalar(@$tids) == 1 ) if DEBUG;

        # Note that we DO NOT explicitly remove the META:FILEATTACHMENT
        # entry table here.
        # That is done at a much higher level in Foswiki::Meta when the
        # referring topic has it's meta-data rewritten.
        # Here we simply clear down the raw data stored for the attachment.
        my $tid =
          $dbh->selectrow_array( 'SELECT tid FROM topic '
              . "WHERE web='"
              . $mo->web
              . " AND name='"
              . $mo->topic
              . "'" );
        ASSERT($tid) if DEBUG;
        $dbh->do( "UPDATE FILEATTACHMENT "
              . " SET raw=''"
              . " WHERE tid='$tid' AND name='$attachment'" );
    }
    else {

        foreach my $tid (@$tids) {
            _say "\tRemove $tid" if MONITOR;
            my $tables = $dbh->selectcol_arrayref('SELECT name FROM metatypes');
            foreach my $table ( 'topic', @$tables ) {
                if ( $personality->table_exists($table) ) {
                    my $tn = $personality->safe_id($table);
                    $dbh->do("DELETE FROM $tn WHERE tid='$tid'");
                }
            }
        }
    }
}

=begin TML

---++ StaticMethod query($sql) -> $sth

Perform an SQL query on the database, returning the statement handle.

May throw an exception if there is an error in the SQL.

=cut

sub query {
    my $sql = shift;

    _connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    return $sth;
}

=begin TML

---++ ObjectMethod reset($session)
Reset the DB by dropping existing tables (if they exist) and preloading.

=cut

sub reset {
    my ($session) = @_;

    # Connect with hard reset
    eval { _connect($session); };
    if ($@) {
        _say $@ if MONITOR;
        die $@;
    }
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
