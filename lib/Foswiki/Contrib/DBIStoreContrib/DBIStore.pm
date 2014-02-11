# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::DBIStore;

=begin TML

---+ package Foswiki::Contrib::DBIStoreContrib::DBIStore;
Implements a Foswiki::Store shim to add to Store.

For Foswiki 1.2.0 and later, it's a partial implementation of the Store class
that will be inserted into the object hierarchy at object creation time.

For Foswiki <1.2.0 (which does not support recordChange) it is simply a
set of functions used by the DBIStoreContribPlugin to maintain the DB.

Object that listens to low level store events, and maintains an SQL
database (on the other side of DBI).

=cut

use strict;
use warnings;

use DBI;
use Foswiki::Meta;
use Error ':try';
use Assert;
use Encode;

use constant MONITOR => Foswiki::Contrib::DBIStoreContrib::MONITOR;

# TODO: SMELL: convert to using $session->{store} perhaps?
our $db;             # singleton instance of this class
our $personality;    # personality module for the selected DSN
our ( $CQ, $TEXT );

our @TABLES = keys(%Foswiki::Meta::VALIDATE);    # META: types

# @ISA not used, as its set by magic, and we don't want to import more functions
# our @ISA = ('Foswiki::Store::Store');
# SMELL: I don't understand this. Sven changed the code, and
# now I'm lost :-(

# Construct singleton object, just used as a handle
sub new {
    my $class = shift;

    return $db if $db;

    $db = $class->SUPER::new(@_) unless defined($db);

    return $db;
}

# Used by plugin instead of new() until I can work out what Sven did.
# Mutually exclusive with new()
sub createShim {
    my $class = shift;

    return $db if $db;

    $db = bless( {}, $class ) unless $db;

    return $db;
}

sub DESTROY {
    my $this = shift;
    if ( defined $this->{handle} ) {
        $this->{handle}->disconnect();    # SMELL: keep around in FCGI?
        $this->{handle} = undef;
    }
}

# Connect on demand - PRIVATE
sub _connect {
    my ( $this, $session, $hard_reset ) = @_;

    return 1 if $this->{handle} && !$hard_reset;

    if ($Foswiki::inUnitTestMode) {

        # Change the DSN to a SQLite test db, which is held in the data
        # area; that way it will be ripped down by -clean
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN} =
          "dbi:SQLite:dbname=$Foswiki::cfg{DataDir}/TemporarySQLiteCache";
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{Username} = '';
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{Password} = '';
    }

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

    print STDERR "CONNECT $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN}...\n"
      if MONITOR;

    $this->{handle} = DBI->connect(
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN},
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{Username},
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{Password},
        { RaiseError => 1, AutoCommit => 0 }
    ) or die $DBI::errstr;

    print STDERR "Connected\n" if MONITOR;

    # Custom code to put DB's into ANSI mode and clean up error reporting
    personality()->startup();
    $CQ   = personality()->string_quote();
    $TEXT = personality()->text_type();

    # Check if the DB is initialised with a quick sniff of the tables
    # to see if all the ones we expect are there
    if ( personality()->table_exists( 'metatypes', 'topic' ) ) {
        return 1 unless ($hard_reset);
        print STDERR "HARD RESET\n" if MONITOR;

        # Hard reset; strip down all existing tables
        my $tables = $this->{handle}->selectcol_arrayref( <<SQL );
SELECT name FROM metatypes
SQL
        push( @$tables, 'topic' );
        push( @$tables, 'metatypes' );
        foreach my $table (@$tables) {
            $this->{handle}->do("DROP TABLE \"$table\"")
              if personality()->table_exists($table);
        }
    }

    # No tables, or we've had a hard reset
    print STDERR "Loading DB schema\n" if MONITOR;
    $this->_createTables();
    unless ($Foswiki::inUnitTestMode) {
        print STDERR "Schema loaded; preloading content\n" if MONITOR;
        $this->_preload($session);
        print STDERR "DB preloaded\n" if MONITOR;
    }

    return 1;
}

# Create the table for the given META - PRIVATE
sub _createTableForMETA {
    my ( $this, $t ) = @_;
    my $cols =
      join( ",\n", map { " \"$_\" $TEXT" } keys %{ $this->{schema}->{$t} } );
    $this->{handle}->do(<<SQL);
CREATE TABLE "$t" (
 tid INT,
$cols
)
SQL

    # Add the table to the table of tables
    $this->{handle}->do("INSERT INTO metatypes (name) VALUES ( '$t' )");

    # If it's not a default table, add it to the list of tables
    # (unless it's already there).
    push( @TABLES, $t ) unless grep { $t } @TABLES;
}

# Create all the base tables in the DB (including all default META: tables) - PRIVATE
sub _createTables {
    my $this = shift;

    # Create the topic table. This links the web name, topic name,
    # topic text and raw text of the topic.
    $this->{handle}->do(<<SQL);
CREATE TABLE topic (
 tid  INT PRIMARY KEY,
 web  $TEXT,
 name $TEXT,
 text $TEXT,
 raw  $TEXT,
 UNIQUE (tid)
)
SQL

    # Now create the meta-table of known META: tables
    $this->{handle}->do(<<SQL);
CREATE TABLE metatypes (
 name $TEXT
)
SQL

    # Create the tables for each known META: type
    foreach my $t (@TABLES) {
        print STDERR "Creating table for $t\n" if MONITOR;
        $this->_createTableForMETA($t);
    }
    $this->{handle}->do('COMMIT') if personality()->requires_COMMIT();
}

# Load all existing webs and topics into the cache DB (expensive)
sub _preload {
    my ( $this, $session ) = @_;
    my $root = Foswiki::Meta->new($session);
    my $wit  = $root->eachWeb();
    while ( $wit->hasNext() ) {
        my $web = $wit->next();
        $this->_preloadWeb( $web, $session );
    }
    $this->{handle}->do('COMMIT') if personality()->requires_COMMIT();
}

# Preload a single web - PRIVATE
sub _preloadWeb {
    my ( $this, $w, $session ) = @_;
    my $web = Foswiki::Meta->new( $session, $w );
    my $tit = $web->eachTopic();
    while ( $tit->hasNext() ) {
        my $t = $tit->next();
        my $topic = Foswiki::Meta->load( $session, $w, $t );
        print STDERR "Preloading topic $w/$t\n" if MONITOR;
        $this->insert($topic);
    }

    my $wit = $web->eachWeb();
    while ( $wit->hasNext() ) {
        $this->_preloadWeb( $w . '/' . $wit->next(), $session );
    }
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

    # doing it first to make sure the record is chained
    $this->SUPER::recordChange(%args);

    # TODO: I'm not doing attachments yet
    return if ( defined( $args{newattachment} ) );
    return if ( defined( $args{oldattachment} ) );

    writeDebug( $args{verb} . join( ',', keys(%args) ) ) if MONITOR;

    if ( $args{verb} eq 'remove' ) {
        $this->remove( $args{oldmeta} );
    }
    elsif ( $args{verb} eq 'insert' ) {
        $this->insert( $args{newmeta} );
    }
    elsif ( $args{verb} eq 'update' ) {
        $this->_update( $args{oldmeta}, $args{newmeta} );
    }
    else {

        # WTF?
    }
}

# Update a topic by removing the $old and ringing in the $new - or operations to
# that effect.
sub update {
    my ( $this, $old, $new ) = @_;

    # SMELL: there's got to be a better way
    eval {
        $this->_inner_remove($old);
        $this->_inner_insert( $new || $old );
        $this->{handle}->do('COMMIT');
    };
    if ($@) {
        print STDERR "$@\n" if MONITOR;
        die $@;
    }
}

sub _convertToUTF8 {
    my $text = shift;
    $text = Encode::decode( $Foswiki::cfg{Site}{CharSet}, $text );
    $text = Encode::encode( 'utf-8', $text );
    return $text;
}

sub _inner_insert {
    my ( $this, $mo ) = @_;
    return unless defined $mo->topic();

    $this->_connect( $mo->session() );
    my $tid = $this->{handle}->selectrow_array('SELECT MAX(tid) FROM topic;')
      || 0;
    $tid++;
    print STDERR "\tInsert $tid\n" if MONITOR;
    my $text = _convertToUTF8( $mo->text() );
    my $esf  = _convertToUTF8( $mo->getEmbeddedStoreForm() );
    $this->{handle}
      ->do( 'INSERT INTO topic (tid,web,name,text,raw) VALUES (?,?,?,?,?)',
        {}, $tid, $mo->web(), $mo->topic(), $text, $esf );

    foreach my $type ( keys %$mo ) {

        # Make sure it's registered.
        next unless ( defined $Foswiki::Meta::VALIDATE{$type} );

        # If it's not default, we may have to create the table
        $this->_createTableForMETA($type)
          unless personality()->table_exists($type);

        # Insert this row
        my $data = $mo->{$type};
        foreach my $item (@$data) {

            # Filter attrs by those legal in the schema
            my @kn = grep { $this->{schema}->{$type}->{$_} } keys(%$item);
            my @kl = ( 'tid', @kn );
            my $sql =
                "INSERT INTO \"$type\" ("
              . join( ',', map { "\"$_\"" } @kl )
              . ") VALUES ("
              . join( ',', map { '?' } @kl ) . ")";
            $this->{handle}
              ->do( $sql, {}, $tid, map { _convertToUTF8( $item->{$_} ) } @kn );
        }
    }
}

# Insert a topic into the topics table - PUBLIC
sub insert {
    my ( $this, $mo ) = @_;

    eval {
        $this->_inner_insert($mo);
        $this->{handle}->do('COMMIT');
    };
    if ($@) {
        print STDERR "$@\n" if MONITOR;
        die $@;
    }
}

sub _inner_remove {
    my ( $this, $mo ) = @_;
    $this->_connect( $mo->session() );
    my $sql = "SELECT tid FROM topic WHERE topic.web='" . $mo->web() . "'";
    $sql .= " AND topic.name='" . $mo->topic() . "'" if defined $mo->topic();
    my $tids = $this->{handle}->selectcol_arrayref($sql);
    return unless scalar(@$tids);

    my $tid = $tids->[0];
    print STDERR "\tRemove $tid\n" if MONITOR;
    foreach my $table ( 'topic', @TABLES ) {
        $this->{handle}->do("DELETE FROM \"$table\" WHERE tid = '$tid'");
    }
}

# Delete a topic identified by a Meta object from the table of topics
sub remove {
    my ( $this, $mo ) = @_;

    eval {
        $this->_inner_remove($mo);
        $this->{handle}->do('COMMIT');
    };
    if ($@) {
        print STDERR "$@\n" if MONITOR;
        die $@;
    }
}

# STATIC method invoked by Foswiki::Store::QueryAlgorithms::DBIStoreContrib
# to perform the actual database query.
sub DBI_query {
    my ( $session, $sql ) = @_;

    ASSERT( $db, "Fatal error: queried before DBIStore shim is ready" )
      if DEBUG;
    my @names;
    eval {
        $db->_connect($session);
        my $sth = $db->{handle}->prepare($sql);
        $sth->execute();
        while ( my @row = $sth->fetchrow_array() ) {
            push( @names, "$row[0]/$row[1]" );
        }
        print STDERR "HITS: "
          . scalar(@names) . "\n"
          . join( "\n", map { "\t$_" } @names ) . "\n"
          if MONITOR;
    };
    if ($@) {
        print STDERR "$@\n" if MONITOR;
        die $@;
    }
    return \@names;
}

# Static access to the database personaility module; used to get access to
# the regexp composition.
sub personality {
    ASSERT( $db,
        "Fatal error: trying to use personality before DBIStore is ready" )
      if DEBUG;

    unless ($personality) {
        $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN} =~ /^dbi:(.*?):/i;
        my $module = 'Foswiki::Contrib::DBIStoreContrib::Personality::' . $1;

        eval "require $module";
        if ($@) {
            print STDERR $@;
            die "Failed to load personality module $module";
        }
        $personality = $module->new($db);
    }
    return $personality;
}

# Reset the DB by dropping existing tables (if they exist) and preloading.
sub reset {
    my ( $this, $session ) = @_;

    # Connect with hard reset
    eval { $this->_connect( $session, 1 ); };
    if ($@) {
        print STDERR "$@\n" if MONITOR;
        die $@;
    }
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

