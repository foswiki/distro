# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::DBIStore;

=begin TML

---+ package Foswiki::Contrib::DBIStoreContrib::DBIStore;
Implements a Foswiki::Store shim to add to Store.

For Foswiki 1.2.0 and later, it's a partial implementation of the Store class
that will be inserted into the object hierarchy at object creation time.

For Foswiki <1.2.0 (which does not support recordChange in the form
necessary to invoke the handler here) it is simply a set of functions
used by the DBIStorePlugin to maintain the DB.

Object that listens to low level store events, and maintains an SQL
database (on the other side of DBI).

=cut

use strict;
use warnings;

use Assert;
use Encode;
use DBI;

use Foswiki::Meta                     ();
use Foswiki::Contrib::DBIStoreContrib ();

use constant MONITOR => Foswiki::Contrib::DBIStoreContrib::MONITOR;

# TODO: SMELL: convert to using $session->{store} perhaps?
our $db;             # singleton instance of this class
our $personality;    # personality module for the selected DSN
our ( $CQ, $TEXT );

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

sub _say {
    print STDERR join( "\n", @_ ) . "\n";
}

# Connect on demand - PRIVATE
sub _connect {
    my ( $this, $session, $hard_reset ) = @_;

    return 1 if $this->{handle} && !$hard_reset;

    $this->{schema} ||= {};

    unless ( $this->{handle} ) {

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

        $this->{handle} = DBI->connect(
            $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN},
            $Foswiki::cfg{Extensions}{DBIStoreContrib}{Username},
            $Foswiki::cfg{Extensions}{DBIStoreContrib}{Password},
            { RaiseError => 1, AutoCommit => 1 }
        ) or die $DBI::errstr;

        _say "Connected" if MONITOR;

        # Custom code to put DB's into ANSI mode and clean up error reporting
        personality()->startup();

        $CQ   = personality()->{string_quote};
        $TEXT = personality()->{text_type};
    }

    # Check if the DB is initialised with a quick sniff of the tables
    # to see if all the ones we expect are there
    if ( personality()->table_exists( 'metatypes', 'topic' ) ) {
        return 1 unless ($hard_reset);
        _say "HARD RESET" if MONITOR;

        # Hard reset; strip down all existing tables

        # The metatypes table is how we know which tables are ours.
        my $tables =
          $this->{handle}->selectcol_arrayref('SELECT name FROM metatypes');

        foreach my $table ( @$tables, 'topic', 'metatypes' ) {
            if ( personality()->table_exists($table) ) {
                $this->{handle}
                  ->do( 'DROP TABLE ' . personality()->safe_id($table) );
            }
        }
    }

    # No topic table, or we've had a hard reset
    _say "Loading DB schema" if MONITOR;
    $this->_createTables();

    # We only preload after a hard reset
    if ( $hard_reset && !$Foswiki::inUnitTestMode ) {
        _say "Schema loaded; preloading content" if MONITOR;
        $this->_preload($session);
        _say "DB preloaded" if MONITOR;
    }
    return 1;
}

# Create the table for the given META - PRIVATE
sub _createTableForMETA {
    my ( $this, $t, @colnames ) = @_;
    my $cols = join( ',',
        'tid INT', map { personality()->safe_id($_) . " $TEXT" } @colnames );
    my $sn  = personality()->safe_id($t);
    my $sql = "CREATE TABLE $sn ( $cols )";
    _say $sql if MONITOR;
    $this->{handle}->do($sql);
    $this->{schema}->{$t} = { map { $_ => 1 } @colnames };

    # Add the table to the table of tables
    $this->{handle}->do("INSERT INTO metatypes (name) VALUES ( $CQ$t$CQ )");
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

    # Create the tables for each registered META: type
    $this->{schema} = {};
    foreach my $type ( keys(%Foswiki::Meta::VALIDATE) ) {
        _say "Creating VALIDATE table for $type" if MONITOR;
        my @attrs;
        my $t = $Foswiki::Meta::VALIDATE{$type};
        if ($t) {

            # Get the col names from VALIDATE
            foreach my $g (qw(require allow other)) {
                if ( defined $t->{$g} ) {

                    # The if is critical; without it, we change the schema
                    foreach ( @{ $t->{$g} } ) {
                        push( @attrs, $_ );
                    }
                }
            }
        }
        $this->_createTableForMETA( $type, @attrs );
    }
    $this->{handle}->do('COMMIT') if personality()->{requires_COMMIT};
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
    $this->{handle}->do('COMMIT') if personality()->{requires_COMMIT};
}

# Preload a single web - PRIVATE
sub _preloadWeb {
    my ( $this, $w, $session ) = @_;
    my $web = Foswiki::Meta->new( $session, $w );
    my $tit = $web->eachTopic();
    while ( $tit->hasNext() ) {
        my $t = $tit->next();
        my $topic = Foswiki::Meta->load( $session, $w, $t );
        _say "Preloading topic $w/$t" if MONITOR;
        $this->_inner_insert($topic);
    }

    my $wit = $web->eachWeb();
    while ( $wit->hasNext() ) {
        $this->_preloadWeb( $w . '/' . $wit->next(), $session );
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
    _say "\tInsert $tid" if MONITOR;
    my $text = _convertToUTF8( $mo->text() );
    my $esf  = _convertToUTF8( $mo->getEmbeddedStoreForm() );
    $this->{handle}
      ->do( 'INSERT INTO topic (tid,web,name,text,raw) VALUES (?,?,?,?,?)',
        {}, $tid, $mo->web(), $mo->topic(), $text, $esf );

    foreach my $type ( keys %$mo ) {

        # Make sure it's registered.
        next
          unless ( defined $Foswiki::Meta::VALIDATE{$type}
            || $Foswiki::cfg{Extensions}{DBIStoreContrib}{AutoloadUnknownMETA}
            && $type =~ /^[A-Z][A-Z0-9_]+$/ );

        # Make sure the table exists
        unless ( $this->{schema}->{$type} ) {

            # The table is not in the schema
            if ( personality()->table_exists($type) ) {

                # Pull the column names from the DB
                $this->{schema}->{$type} =
                  { map { $_ => 1 } personality()->get_columns($type) };
            }
            else {
                # The table is not in the DB either
                my %attrs;
                my $t = $Foswiki::Meta::VALIDATE{$type};
                if ($t) {

                    # Get the col names from VALIDATE
                    foreach my $g (qw(require allow other)) {
                        if ( defined $t->{$g} ) {
                            foreach ( @{ $t->{$g} } ) {
                                $attrs{$_} = 1;
                            }
                        }
                    }
                }

                # Check the entries to ensure we have picked up all the
                # columns. We read *all* entries so we get all columns.
                foreach my $item ( $mo->find($type) ) {
                    foreach ( keys(%$item) ) {
                        $attrs{$_} = 1;
                    }
                }
                _say "Creating fly table for $type" if MONITOR;
                $this->_createTableForMETA( $type, keys %attrs );
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
                unless ( $this->{schema}->{$type}->{$kn} ) {

                    # The column is not in the schema
                    unless ( personality()->column_exists( $type, $kn ) ) {

                        # The column might be in the DB but not in
                        # the schema. This is unlikely, but possible.
                        $this->{handle}->do( 'ALTER TABLE '
                              . personality()->safe_id($type) . ' ADD '
                              . personality()->safe_id($kn)
                              . " $TEXT" );
                    }
                    $this->{schema}->{$type} =
                      { map { $_ => 1 } personality()->get_columns($type) };
                }

                # The column might be in the schema but not in the DB
                # if there was a race condition and someone deleted the
                # table under us. Table deletion is very rare, and admin
                # only, so this is an acceptable risk.
            }

            unshift( @kns, 'tid' );
            my $sql =
                'INSERT INTO '
              . personality()->safe_id($type) . ' ('
              . join( ',', map { personality()->safe_id($_) } @kns )
              . ") VALUES ("
              . join( ',', map { '?' } @kns ) . ")";
            shift(@kns);

            _say "$sql [tid," . join( ',', map { $item->{$_} } @kns ) . ']'
              if MONITOR;

            #_say "$sql tid,"
            #    . join(';', map { (defined $item->{$_}?$item->{$_}:"") } @kns)
            #    if MONITOR;
            $this->{handle}->do( $sql, {},
                $tid, map { _convertToUTF8( $item->{$_} ) } @kns );
        }
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
    _say "\tRemove $tid" if MONITOR;
    my $tables =
      $this->{handle}->selectcol_arrayref('SELECT name FROM metatypes');
    foreach my $table ( 'topic', @$tables ) {
        if ( personality()->table_exists($table) ) {
            my $tn = personality()->safe_id($table);
            $this->{handle}->do("DELETE FROM $tn WHERE tid=$CQ$tid$CQ");
        }
    }
}

=begin TML

---++ StaticMethod personality() -> $personality
Static access to the database personaility module; used to get access to
the regexp composition etc.

=cut

sub personality {

    unless ($personality) {
        ASSERT( $db,
            "Fatal error: trying to use personality before DBIStore is ready" )
          if DEBUG;

        $Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN} =~ /^dbi:(.*?):/i;
        my $module = "Foswiki::Contrib::DBIStoreContrib::Personality::$1";

        eval "require $module";
        if ($@) {
            _say $@ if MONITOR;
            die "Failed to load personality module $module";
        }
        $personality = $module->new($db);
    }
    return $personality;
}

=begin TML

---++ ObjectMethod reset($session)
Reset the DB by dropping existing tables (if they exist) and preloading.

=cut

sub reset {
    my ( $this, $session ) = @_;

    # Connect with hard reset
    eval { $this->_connect( $session, 1 ); };
    if ($@) {
        _say $@ if MONITOR;
        die $@;
    }
}

=begin TML

---++ ObjectMethod recordChange(%args)
Record that the store item changed, and who changed it

Only called in Foswiki 1.2 and later. Prior to that, the plugin handlers
are used to trigger updates.

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
        $this->update( $args{oldmeta}, $args{newmeta} );
    }
    else {

        # WTF?
    }
}

=begin TML

---++ ObjectMethod update($old, $new)
Update a topic by removing the $old and ringing in the $new - or operations to
that effect.

=cut

sub update {
    my ( $this, $old, $new ) = @_;

    personality();

    # SMELL: there's got to be a better way
    eval {
        $this->_inner_remove($old);
        $this->_inner_insert( $new || $old );
        $this->{handle}->do('COMMIT') if personality()->{requires_COMMIT};
    };
    if ($@) {
        _say $@ if MONITOR;
        die $@;
    }
}

=begin TML

---++ ObjectMethod insert($meta)
Insert a topic into the topics table - PUBLIC

=cut

sub insert {
    my ( $this, $mo ) = @_;

    personality();

    eval {
        $this->_inner_insert($mo);
        $this->{handle}->do('COMMIT') if personality()->{requires_COMMIT};
    };
    if ($@) {
        _say $@ if MONITOR;
        die $@;
    }
}

=begin TML

---++ ObjectMethod remove($meta)

Delete a topic identified by a Meta object from the table of topics

=cut

sub remove {
    my ( $this, $mo ) = @_;

    personality();

    eval {
        $this->_inner_remove($mo);
        $this->{handle}->do('COMMIT') if personality()->{requires_COMMIT};
    };
    if ($@) {
        _say $@ if MONITOR;
        die $@;
    }
}

=begin TML

---++ StaticMethod DBI_query( $sessio, $sql )
STATIC method invoked by Foswiki::Store::QueryAlgorithms::DBIStoreContrib
to perform the actual database query.

=cut

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
        _say 'HITS: ' . scalar(@names), map { "\t$_" } @names if MONITOR;
    };
    if ($@) {
        _say "$@\n" if MONITOR;
        die $@;
    }
    return \@names;
}

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2010-2014 Foswiki Contributors. All Rights Reserved.
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

