# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
#
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
---+ package Foswiki::Cache

Base class for Foswiki::Cache implementations

=cut

package Foswiki::Cache;

use strict;

# static poor man's debugging tools
sub writeDebug {
  print STDERR "Foswiki::Cache - $_[0]\n" if $Foswiki::cfg{Cache}{Debug};
}

=pod 

---++ ClassMethod new( $session ) -> $object

Construct a new cache delegator. 

=cut

sub new {
  my ($class, $session) = @_;

  my $this = {};
  bless($this, $class);
  $this->init($session);

  return $this;
}

=pod 

---++ ObjectMethod init($session)

initializes a cache object to be used for the current request. this
object might be _shared_ on multiple requests when Foswiki is accelerated
using mod_perl or speedy-cgi and using the Foswiki::Cache::MemoryCache 
handler.

=cut

sub init {
  my ($this, $session) = @_;

  $this->{session} = $session;
  my $nameSpace = $Foswiki::cfg{Cache}{NameSpace} || $Foswiki::cfg{DefaultUrlHost};
  $nameSpace =~ s/^https?:\/\///go;
  $nameSpace =~ s/[\s\/]+/_/go;
  $this->{namespace} = $nameSpace;
}

=pod 

explicite destructor to break cyclic links

=cut

sub DESTROY {
  my $this = shift;
  $this->finish();
}

=pod 

finish up internal structures

=cut

sub finish {
  my $this = shift;

  # this is where individual backends to their real work
  # by implementing the write action
  if ($this->{handler}) {

    # begin transaction / aquire lock

    if ($this->{delBuffer}) {
      foreach my $key (keys %{$this->{delBuffer}}) {
        next unless $this->{delBuffer}{$key};
        $this->{handler}->remove($key);
      }
    }

    if ($this->{writeBuffer}) {
      foreach my $key (keys %{$this->{writeBuffer}}) {
        my $obj = $this->{writeBuffer}{$key};
        next unless $obj;
        $this->{handler}->set($key, $obj);
      }
    }

    # commit transaction / release lock

    undef $this->{handler};
  }

  undef $this->{session};
  undef $this->{readBuffer};
  undef $this->{writeBuffer};
  undef $this->{delBuffer};
}



=pod

---++ ObjectMethod genkey($string, $key) -> $key

Static function to generate a key for the current cache.

Some cache implementations don't have a namespace feature.  Those which do, are
only able to serve objects from within one namespace per cache object. 

So by default we encode the namespace into the key here, even when this is
redundant, given that you specify the namespace for Cache::Cache
implementations during the constructor already.

=cut

sub genKey {
  my ($this, $key) = @_;
  my $pageKey = $this->{namespace};
  $pageKey .= '::'.$key if $key;
  $pageKey =~ s/[\s\/]+/_/go;
  return $key;
}

=pod

---++ ObjectMetohd set($key, $object ... ) -> $boolean

cache an $object under the given $key. note, that the
object won't be flushed to disk until we called finish().

returns true if it was stored sucessfully

=cut

sub set {
  my $this = shift;
  my $key = shift;
  my $obj = shift;

  return 0 unless $this->{handler};

  my $pageKey = $this->genKey($key);
  $this->{writeBuffer}{$pageKey} = $obj;
  $this->{readBuffer}{$pageKey} = $obj;

  if ($this->{delBuffer}) {
    undef $this->{delBuffer}{$pageKey} 
  }

  return 1;
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

  $obj = $this->{handler}->get($pageKey);
  $this->{readBuffer}{$pageKey} = $obj;

  return $obj;
}

=pod 

---++ ObjectMethod delete($key)

delete an entry for a given $key

returns true if the key was found and deleted, and false otherwise

=cut

sub delete {
  my ($this, $key) = @_;

  return 0 unless $this->{handler};

  my $pageKey = $this->genKey($key);
  
  undef $this->{writeBuffer}{$pageKey};
  undef $this->{readBuffer}{$pageKey};
  $this->{delBuffer}{$pageKey} = 1;

  return 1;
}


=pod 

---++ ObjectMethod clear()

removes all objects from the cache.

=cut

sub clear {
  my $this = shift;

  $this->{handler}->clear() if $this->{handler};
  undef $this->{writeBuffer};
  undef $this->{delBuffer};
  undef $this->{readBuffer};
}

1;
