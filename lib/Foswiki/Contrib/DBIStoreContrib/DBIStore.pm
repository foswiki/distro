# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::DBIStore;

=begin TML

---+ package Foswiki::Contrib::DBIStoreContrib::DBIStore;
Implements a Foswiki::Store shim to add to Store.

Its a partial implementation of the class that will be inserted into the object hierarchy at object creation

Object that listens to low level store events, and maintains an SQL
database (on the other side of DBI).

=cut

use strict;
use warnings;

use DBI;
use Foswiki::Meta;
use Error ':try';
use Assert;

use constant MONITOR => 0;

#mmm, i don't know what happens if you store something in the middle of the class heirarchy
#TODO: SMELL: convert to using $session->{store} perhaps?
our $db;    # singleton instance of this class
our @TABLES = keys(%Foswiki::Meta::VALIDATE);    # META: types

# @ISA not used, as its set by magic, and we don't want to import more functions
#our @ISA = ('Foswiki::Store::Store');

# Construct object, just used as a handle
sub new {
    my $class = shift;

    $db = $class->SUPER::new(@_) unless defined($db);

    return $db;
}

# Connect on demand
sub _connect {
    my ( $this, $session ) = @_;

    return 1 if $this->{handle};

    if ($Foswiki::inUnitTestMode) {

        # Change the DSN to a SQLite test db, which is held in the data
        # area; that way it will be ripped down by -clean
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN} =
          $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN} =
          "dbi:SQLite:dbname=$Foswiki::cfg{DataDir}/TemporarySQLiteCache";
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{Username} = '';
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{Password} = '';
    }

    print STDERR "CONNECT $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN}..."
      if MONITOR;

    # $this->{schema} re-expresses the schema declared in Meta::VALIDATE by
    # organising it as a hash keyed on table name e.g. 'FILEATTACHMENT'
    # and sub-keyed on attribute name e.g. 'name'
    $this->{schema} = {};
    foreach my $type (@TABLES) {
        my @keys;
        foreach my $g (qw(require allow other)) {
            if ( defined $Foswiki::Meta::VALIDATE{$type}->{$g} ) {
                push( @keys, @{ $Foswiki::Meta::VALIDATE{$type}->{$g} } );
            }
        }
        foreach my $key (@keys) {
            $this->{schema}->{$type}->{$key} = 1;
        }
    }

    $this->{handle} = DBI->connect(
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN},
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{Username},
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{Password},
        { RaiseError => 1 }
    );

    # Check if the DB is initialised with a quick sniff of the metatypes
    eval { $this->{handle}->selectrow_array('SELECT * from metatypes'); };
    if ($@) {
        if ( $@ =~ /no such table/ ) {
            print STDERR "Loading DB schema\n" if MONITOR;
            $this->{handle}->do('BEGIN;');
            $this->_createTables();
            print STDERR "DB schema loaded; preloading content\n" if MONITOR;
            $this->_preload($session);
            $this->{handle}->do('COMMIT;');
            print STDERR "DB preloaded\n" if MONITOR;
        }
        else {
            die $@;
        }
    }

    print STDERR "connected $this->{handle}\n" if MONITOR;
    return 1;
}

# Does the table exist in the DB?
sub _tableExists {
    my ( $this, $type ) = @_;
    return 1 if grep { $type } @TABLES;
    my $check = $this->{handle}->selectcol_arrayref( <<SQL, {}, $type );
SELECT name FROM 'metatypes' WHERE name=?
SQL
    return SCALAR(@$check);
}

# Create the table for the given META:
sub _createTableForMETA {
    my ( $this, $t ) = @_;
    my $cols =
      join( ",\n", map { " '$_' TEXT" } keys %{ $this->{schema}->{$t} } );
    $this->{handle}->do(<<SQL);
CREATE TABLE '$t' (
 'tid' TEXT,
$cols
);
SQL

    # Add the table to the table of tables
    $this->{handle}->do( <<SQL, {}, $t );
INSERT INTO 'metatypes' (name) VALUES (?);
SQL

# If it's not a default table, add it to the list of tables (unless it's already
# there).
    push( @TABLES, $t ) unless grep { $t } @TABLES;
}

# Create all the base tables in the DB (including all default META: tables)
sub _createTables {
    my $this = shift;

    # Create the topic table. This links the web name, topic name,
    # topic text and raw text of the topic.
    $this->{handle}->do(<<SQL);
CREATE TABLE 'topic' (
 'tid'  TEXT,
 'web'  TEXT,
 'name' TEXT,
 'text' TEXT,
 'raw'  TEXT,
 UNIQUE (tid)
);
SQL

    # Now create the meta-table of known META: tables
    $this->{handle}->do(<<SQL);
CREATE TABLE 'metatypes' (
 'name' TEXT,
 UNIQUE (name)
);
SQL

    # Create the tables for each known META: type
    print STDERR join( ', ', @TABLES ) . "\n";
    foreach my $t (@TABLES) {
        print STDERR "Creating table for $t\n" if MONITOR;
        $this->_createTableForMETA($t);
    }
}

# Load all existing webs and topics into the cache DB (expensive)
sub _preload {
    my ( $this, $session ) = @_;
    my $root = Foswiki::Meta->new($session);
    my $wit  = $root->eachWeb();
    while ( $wit->hasNext() ) {
        $this->_preloadWeb( $wit->next(), $session );
    }
}

sub _preloadWeb {
    my ( $this, $w, $session ) = @_;
    print STDERR "PRELOAD $w\n" if MONITOR;
    my $web = Foswiki::Meta->new( $session, $w );
    my $tit = $web->eachTopic();
    while ( $tit->hasNext() ) {
        my $t = $tit->next();
        my $topic = Foswiki::Meta->load( $session, $w, $t );
        $this->insert($topic);
    }
    my $wit = $web->eachWeb();
    while ( $wit->hasNext() ) {
        $this->_preloadWeb( $w . '/' . $wit->next(), $session );
    }
}

sub _makeTID {
    my $tob = shift;
    return $tob->web() . '/' . $tob->topic();
}

=begin TML

---++ ObjectMethod recordChange(%args)
Record that the store item changed, and who changed it

This is a private method to be called only from the store internals, but it can be used by 
$Foswiki::Cfg{Store}{ImplementationClasses} to chain in to eveavesdrop on Store events

        cuid          => $cUID,
        revision      => $rev,
        verb          => $verb,
        newmeta       => $topicObject,
        newattachment => $name

=cut

sub recordChange {
    my ( $this, %args ) = @_;

    #doing it first to make sure the recod is chained
    $this->SUPER::recordChange(%args);

    #TODO: I'm not doing attachments yet
    return if ( defined( $args{newattachment} ) );
    return if ( defined( $args{oldattachment} ) );

    writeDebug( $args{verb} . join( ',', keys(%args) ) ) if MONITOR;

    if ( $args{verb} = 'remove' ) {
        $this->_remove( $args{oldmeta} );
    }
    elsif ( $args{verb} = 'insert' ) {
        $this->_insert( $args{newmeta} );
    }
    elsif ( $args{verb} = 'update' ) {
        $this->_update( $args{oldmeta}, $args{newmeta} );
    }
    else {

    }
}

sub _insert {
    my ( $this, $mo ) = @_;

    if ( defined $mo->topic() ) {
        my $tid = _makeTID($mo);

        #print STDERR "\tInsert $tid\n" if MONITOR;
        $this->_connect( $mo->session() );
        $this->{handle}->do(
            'INSERT INTO topic (tid,web,name,text,raw) VALUES (?,?,?,?,?);',
            {},
            $tid,
            $mo->web(),
            $mo->topic(),
            $mo->text(),
            $mo->getEmbeddedStoreForm()
        );

        foreach my $type ( keys %$mo ) {

            # Make sure it's registered.
            next unless ( defined $Foswiki::Meta::VALIDATE{$type} );

            # If it's not default, we may have to create the table
            $this->_createTableForMETA($type)
              unless $this->_tableExists($type);

            # Insert this row
            my $data = $mo->{$type};
            foreach my $item (@$data) {

                # Filter attrs by those legal in the schema
                my @kn = grep { $this->{schema}->{$type}->{$_} } keys(%$item);
                my @kl = ( 'tid', @kn );
                my $sql =
                    "INSERT INTO $type ("
                  . join( ',', map { "'$_'" } @kl )
                  . ") VALUES ("
                  . join( ',', map { '?' } @kl ) . ");";
                $this->{handle}->do( $sql, {}, $tid, map { $item->{$_} } @kn );
            }
        }
    }
}

sub _update {
    my ( $this, $old, $new ) = @_;

    # SMELL: there's got to be a better way
    $this->_remove($old);
    $this->_insert( $new || $old );
}

sub _remove {
    my ( $this, $mo ) = @_;

    my $tids;
    $this->_connect( $mo->session() );
    if ( defined $mo->topic() ) {
        push( @$tids, _makeTID($mo) );
    }
    else {
        $tids = $this->{handle}->selectcol_arrayref( <<SQL, {}, $mo->web() );
SELECT tid FROM topic WHERE web=?;
SQL
    }
    my $ph = join( ',', map { '?' } @$tids );

    #print STDERR "\tRemove ".join(',',@$tids)."\n" if MONITOR;

    foreach my $table ( 'topic', @TABLES ) {
        $this->{handle}->do( <<SQL, {}, @$tids );
DELETE FROM $table WHERE tid IN ($ph);
SQL
    }
}

# STATIC method invoked by Foswiki::Store::QueryAlgorithms::DBIStoreContrib
# to perform the actual database query.
sub DBI_query {
    my ( $session, $sql ) = @_;

    ASSERT( $db, "Fatal error: queried before DBIStore shim is ready" )
      if DEBUG;

    $db->_connect($session);
    print STDERR "$sql\n" if MONITOR;
    my $names = $db->{handle}->selectcol_arrayref($sql);
    print STDERR "HITS: " . scalar(@$names) . "\n" if MONITOR;
    return $names;
}

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2010 Foswiki Contributors. All Rights Reserved.
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

