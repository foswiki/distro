# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Michael Daum http://michaeldaumconsulting.com
#
# All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package Foswiki::Cache::BDB

Implementation of a Foswiki::Cache using BerkeleyDB

=cut

package Foswiki::Cache::BDB;

use strict;
use BerkeleyDB;
use Storable;
use Foswiki::Cache;

@Foswiki::Cache::BDB::ISA = ( 'Foswiki::Cache' );

=pod 

---++ ClassMethod new( $session ) -> $object

Construct a new cache object. 

=cut

sub new {
  my ($class, $session) = @_;

  return bless($class->SUPER::new($session), $class);
}

=pod 

---++ ObjectMethod init($session)

this is called after creating a cache object and when reusing it
on a second call

=cut

sub init {
  my ($this, $session) = @_;

  $this->SUPER::init($session);
  unless($this->{handler}) {
    my $cache_root = $Foswiki::cfg{Cache}{RootDir} || '/tmp/foswiki_cache';
    unless (-d $cache_root) {
      unless (mkdir $cache_root) {
        die "Could not create $cache_root for Foswiki::Cache::BDB";
      }
    }

    my $env = BerkeleyDB::Env->new(
      -Home => $cache_root,
      -Flags => (DB_CREATE | DB_INIT_LOCK | DB_INIT_LOG | DB_INIT_MPOOL | DB_INIT_TXN), # DB_DIRECT_DB,
      -SetFlags => DB_TXN_NOSYNC,
      -ErrPrefix => 'Foswiki::Cache:BDB',
      -Cachesize => 32*1024*1024,
      -ErrFile => *STDERR,
      #-Verbose => 1,
    ) or die "Foswiki::Cache:BDB: Unable to create env: $BerkeleyDB::Error";

    my $fname =  $this->{namespace}.'.db';
    $fname =~ s/[\/\\:_]//go;

    my $db = BerkeleyDB::Btree->new(
      -Env => $env,
      -Subname => $this->{namespace},
      -Filename => $fname,
      -Pagesize => 32*1024,
      -Flags => DB_CREATE,
    ) or die "Foswiki::Cache:BDB: Unable to open db: $BerkeleyDB::Error";

    $db->filter_store_value( sub { $_ = Storable::freeze($_) });
    $db->filter_fetch_value( sub { $_ = Storable::thaw($_) });

    $this->{handler} = $db;
    $this->{env} = $env;
  }
}

=pod 

finish up internal structures

=cut

sub finish {
  my $this = shift;


  if ($this->{handler} && $this->{env}) {

    my $doTxn = ($this->{writeBuffer} || $this->{delBuffer})?1:0;
    my $txn;

    $txn = $this->{env}->txn_begin() if $doTxn;

    if ($this->{delBuffer}) {
      foreach my $key (keys %{$this->{delBuffer}}) {
        next unless $this->{delBuffer}{$key};
        $this->{handler}->db_del($key);
        #Foswiki::Cache::writeDebug("deleting $key");
      }
    }

    if ($this->{writeBuffer}) {
      foreach my $key (keys %{$this->{writeBuffer}}) {
        my $obj = $this->{writeBuffer}{$key};
        next unless $obj;
        $this->{handler}->db_put($key, $obj);
        #Foswiki::Cache::writeDebug("flushing $key");
      }
    }

    $txn->txn_commit() if $doTxn;

    #$this->{handler}->db_close();
    undef $this->{env};
    undef $this->{handler};
  }

  $this->SUPER::finish();
} 

=pod 

---++ ObjectMethod get($key) -> $object

retrieve a cached object, returns undef if it does not exist

=cut

sub get {
  my ($this, $key) = @_;

  return 0 unless $this->{handler};

  my $pageKey = $this->genKey($key);
  if ($this->{delBuffer}) {
    return undef if $this->{delBuffer}{$pageKey};
  }

  my $obj = $this->{readBuffer}{$pageKey};
  return $obj if $obj;

  $this->{handler}->db_get($pageKey, $obj);
  $this->{readBuffer}{$pageKey} = $obj;

  return $obj;
}

=pod 

---++ ObjectMethod clear()

removes all objects from the cache.

=cut

sub clear {
  my $this = shift;

  return unless $this->{handler};

  my $count = 0;
  $this->{handler}->truncate($count);
  $this->{handler}->compact(undef, undef, undef, DB_FREE_SPACE, undef);

  undef $this->{writeBuffer};
  undef $this->{delBuffer};
  undef $this->{readBuffer};
}


1;

