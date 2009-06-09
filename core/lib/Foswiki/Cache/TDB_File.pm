# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
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

---+ package Foswiki::Cache::TDB_File;

Implementation of a Foswiki::Cache using TDB_File;

=cut

package Foswiki::Cache::TDB_File;

use strict;
use TDB_File qw(:flags);
use Storable qw(freeze thaw);
use Foswiki::Cache;

@Foswiki::Cache::TDB_File::ISA = ( 'Foswiki::Cache' );

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
    my $filename = $Foswiki::cfg{Cache}{TDBFile} || '/tmp/foswiki_tdb';

    $this->{handler} = tie %{$this->{tie}}, 
      'TDB_File',
      $filename,
      TDB_DEFAULT,
      O_CREAT|O_RDWR, 
      0664
      or die "Cannot open file $filename: $!";
  }
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

  my $value = $this->{tie}->{$pageKey};
  if ($value) {
    $obj = thaw($value);
    $obj = ${$obj} if $obj;
  }

  $this->{readBuffer}{$pageKey} = $obj;

  return $obj;
}


=pod 

finish up internal structures

=cut

sub finish {
  my $this = shift;

  if ($this->{handler}) {
    if ($this->{delBuffer}) {
      foreach my $key (keys %{$this->{delBuffer}}) {
        next unless $this->{delBuffer}{$key};
        undef $this->{tie}->{$key};
      }
    }

    if ($this->{writeBuffer}) {
      foreach my $key (keys %{$this->{writeBuffer}}) {
        my $obj = $this->{writeBuffer}{$key};
        my $value = freeze(\$obj);
        $this->{tie}->{$key} = $value;
      }
    }
  }

  $this->SUPER::finish();
  untie %{$this->{tie}};

}

=pod 

---++ ObjectMethod clear()

removes all objects from the cache.

=cut

sub clear {
  my $this = shift;

  return unless $this->{handler};
  %{$this->{tie}} = ();

  undef $this->{writeBuffer};
  undef $this->{delBuffer};
  undef $this->{readBuffer};
}

1;
