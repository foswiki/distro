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

---+ package Foswiki::Cache::DB_File;

Implementation of a Foswiki::Cache using DB_File;

=cut

package Foswiki::Cache::DB_File;

use strict;
use DB_File;
use Storable ();
use Foswiki::Cache;
use Fcntl qw( :flock O_RDONLY O_RDWR O_CREAT );

use constant F_STORABLE => 1;

@Foswiki::Cache::DB_File::ISA = ( 'Foswiki::Cache' );

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
    my $filename = $Foswiki::cfg{Cache}{DBFile} || '/tmp/foswiki_db';

    $this->{handler} = tie %{$this->{tie}}, 
      'DB_File',
      $filename,
      O_CREAT|O_RDWR, 
      0664, 
      $DB_HASH
      or die "Cannot open file $filename: $!";
    $this->{fd} = $this->{handler}->fd;
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
  if ($obj) {
    return undef if $obj eq '_UNKNOWN_';
    return $obj; 
  }

  $obj = '_UNKNOWN_';

  my $value = $this->{tie}->{$pageKey};
  if ($value) {
    if ($value =~ /^(\d+)::(.*)$/) {
      my $flags = $1;
      $obj = $2;
      if ($flags & F_STORABLE) {
	#Foswiki::Func::writeWarning("reading $pageKey is a storable image");
	eval {
	  $obj = Storable::thaw($obj);
          $obj = ${$obj} if $obj;
	};
	if ($@) {
	  print STDERR "WARNING: found a corrupt storable image for pageKey='$pageKey' ... deleting\n";
	  delete $this->{tie}->{$pageKey}; # corrupt storable image
          $obj = '_UNKNOWN_';
	}
      } else {
	#Foswiki::Func::writeWarning("reading $pageKey is a scalar");
      }
    } else {
      Foswiki::Func::writeWarning("WARNING: reading $pageKey does not match format: $value");
    }
  }

  $this->{readBuffer}{$pageKey} = $obj;

  return undef if $obj eq '_UNKNOWN_';

  return $obj;
}

=pod 

finish up internal structures

=cut

sub finish {
  my $this = shift;

  if ($this->{handler}) {


    if ($this->{delBuffer} || $this->{writeBuffer}) {

      # aquire lock
      my $fh = do { local *FH; *FH; };

      open $fh, '<&=' . $this->{fd}
        or die "can't dup file descriptor: $!";

      flock ($fh, LOCK_EX) 
        or die "can't lock cache db: $!";

      if ($this->{delBuffer}) {
        foreach my $key (keys %{$this->{delBuffer}}) {
          next unless $this->{delBuffer}{$key};
          delete $this->{tie}->{$key};
        }
      }

      if ($this->{writeBuffer}) {
        foreach my $key (keys %{$this->{writeBuffer}}) {
          my $obj = $this->{writeBuffer}{$key};
	  my $value;
	  my $flags = 0;
	  if (ref $obj) {
	    $flags |= F_STORABLE;
	    $value = sprintf("%03d::", $flags).Storable::freeze($obj);
	    #Foswiki::Func::writeWarning("writing $key as a storable image");
	  } else {
	    $value = sprintf("%03d::", $flags).$obj;
	    #Foswiki::Func::writeWarning("writing $key is a scalar");
	  }
          $this->{tie}->{$key} = $value;
        }
      }

      # release lock
      flock( $fh, LOCK_UN )
        or die "unable to unlock: $!";
      undef $this->{handler};
      untie %{$this->{tie}};
      close $fh;
    } else {
      undef $this->{handler};
      untie %{$this->{tie}};
    }
  }

  $this->SUPER::finish();
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
