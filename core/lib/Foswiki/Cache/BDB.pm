# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Cache::BDB

Implementation of a Foswiki::Cache using BerkeleyDB. See Foswiki::Cache
for details of the methods implemented by this class.

=cut

package Foswiki::Cache::BDB;

use strict;
use warnings;
use BerkeleyDB;
use Storable           ();
use Foswiki::Cache     ();
use Foswiki::PageCache ();

use constant F_STORABLE => 1;

@Foswiki::Cache::BDB::ISA = ('Foswiki::Cache');

# See Foswiki::Cache
sub new {
    my ( $class, $session ) = @_;

    return bless( $class->SUPER::new($session), $class );
}

# See Foswiki::Cache
sub init {
    my ( $this, $session ) = @_;

    $this->SUPER::init($session);
    unless ( $this->{handler} ) {
        my $cache_root = $Foswiki::cfg{Cache}{RootDir}
          || $Foswiki::cfg{WorkingDir} . '/foswiki_bdb';
        unless ( -d $cache_root ) {
            unless ( mkdir $cache_root ) {
                die "Could not create $cache_root for Foswiki::Cache::BDB";
            }
        }

        my $env = BerkeleyDB::Env->new(
            -Home  => $cache_root,
            -Flags => (
                DB_CREATE | DB_INIT_LOCK | DB_INIT_LOG | DB_INIT_MPOOL |
                  DB_INIT_TXN
            ),    # DB_DIRECT_DB,
            -SetFlags  => DB_TXN_NOSYNC,
            -ErrPrefix => 'Foswiki::Cache:BDB',
            -ErrFile   => *STDERR,

            #-Verbose => 1,
          )
          or die
"Foswiki::Cache:BDB: Unable to create env in $cache_root: $BerkeleyDB::Error";

        my $fname = $this->{namespace} . '.db';
        $fname =~ s/[\/\\:_]//go;

        my $db = BerkeleyDB::Btree->new(
            -Env      => $env,
            -Subname  => $this->{namespace},
            -Filename => $fname,
            -Flags    => DB_CREATE,
        ) or die "Foswiki::Cache:BDB: Unable to open db: $BerkeleyDB::Error";

        $this->{handler} = $db;
        $this->{env}     = $env;
    }
}

# See Foswiki::Cache
sub get {
    my ( $this, $key ) = @_;

    return 0 unless $this->{handler};

    my $pageKey = $this->genKey($key);

    if ( $this->{delBuffer} ) {
        return undef if $this->{delBuffer}{$pageKey};
    }

    my $obj = $this->{readBuffer}{$pageKey};
    if ($obj) {
        return undef if $obj eq '_UNKNOWN_';
        return $obj;
    }

    $obj = '_UNKNOWN_';

    my $value;
    if ( $this->{handler}->db_get( $pageKey, $value ) == 0 ) {
        my $flags = int( substr( $value, 0, 3 ) );
        $obj = substr( $value, 5 );
        if ( $flags & F_STORABLE ) {

           #Foswiki::Func::writeWarning("reading $pageKey is a storable image");
            eval { $obj = Storable::thaw($obj); };
            if ($@) {
                print STDERR
"WARNING: found a corrupt storable image for pageKey='$pageKey' ... deleting\n";
                print STDERR $@ . "\n";
                delete $this->{tie}->{$pageKey};    # corrupt storable image
                $obj = '_UNKNOWN_';
            }
        }
        else {

            #Foswiki::Func::writeWarning("reading $pageKey is a scalar");
        }
    }

    $this->{readBuffer}{$pageKey} = $obj;
    return undef if $obj eq '_UNKNOWN_';

    return $obj;
}

# See Foswiki::Cache
sub finish {
    my $this = shift;

    if ( $this->{handler} && $this->{env} ) {

        my $doTxn = ( $this->{writeBuffer} || $this->{delBuffer} ) ? 1 : 0;
        my $txn;

        $txn = $this->{env}->txn_begin() if $doTxn;

        if ( $this->{delBuffer} ) {
            foreach my $key ( keys %{ $this->{delBuffer} } ) {
                next unless $this->{delBuffer}{$key};
                $this->{handler}->db_del($key);

                Foswiki::PageCache::writeDebug("deleting $key")
                  if (Foswiki::PageCache::TRACE);
            }
        }

        if ( $this->{writeBuffer} ) {
            foreach my $key ( keys %{ $this->{writeBuffer} } ) {
                my $obj = $this->{writeBuffer}{$key};
                next unless $obj;

                Foswiki::PageCache::writeDebug("flushing $key")
                  if (Foswiki::PageCache::TRACE);
                my $value;
                my $flags = 0;
                if ( ref $obj ) {
                    $flags |= F_STORABLE;
                    $value =
                      sprintf( "%03d::", $flags ) . Storable::freeze($obj);

                    Foswiki::PageCache::writeDebug(
                        "writing $key as a storable image")
                      if (Foswiki::PageCache::TRACE);
                }
                else {
                    $value = sprintf( "%03d::", $flags ) . $obj;

                    Foswiki::PageCache::writeDebug("writing $key as a scalar")
                      if (Foswiki::PageCache::TRACE);
                }
                $this->{handler}->db_put( $key, $value );

           #my $test;
           #if ($this->{handler}->db_get($key, $test) != 0 || $value ne $test) {
           #  print STDERR "WARNING: key=$key - test does not match value\n";
           #  print STDERR "value=$value\n";
           #  print STDERR "test=$test\n";
           #} else {
           #  print STDERR "INFO: storing $key is okay\n";
           #}
            }
        }

        $txn->txn_commit() if $doTxn;

        $this->{handler}->db_close();
        undef $this->{env};
        undef $this->{handler};
    }

    $this->SUPER::finish();
}

# See Foswiki::Cache
sub clear {
    my $this = shift;

    return unless $this->{handler};

    my $count = 0;
    $this->{handler}->truncate($count);

    # disabled as not provided by older BerkeleyDB libraries
    #$this->{handler}->compact(undef, undef, undef, DB_FREE_SPACE, undef);

    undef $this->{writeBuffer};
    undef $this->{delBuffer};
    undef $this->{readBuffer};
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2008 Michael Daum http://michaeldaumconsulting.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
