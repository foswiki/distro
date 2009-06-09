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

---+ package Foswiki::Cache::Mmap

Implementation of a Foswiki::Cache using Cache::Mmap

=cut

package Foswiki::Cache::Mmap;

use strict;
use Cache::Mmap;
use Foswiki::Cache;

@Foswiki::Cache::Mmap::ISA = ( 'Foswiki::Cache' );

=pod 

---++ ClassMethod new( $session ) -> $object

Construct a new cache object. 

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless($class->SUPER::new($session), $class);

  return $this;
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
    $this->{handler} = new Cache::Mmap(
        $Foswiki::cfg{Cache}{MmapFile} || '/tmp/foswiki_mmap',
        {
          bucketsize=>102400
        }
    );
  }
}

=pod 

finish up internal structures

=cut

sub finish {
  my $this = shift;

  $this->SUPER::finish(@_);

  # flush to disk
  if ($this->{writeBuffer}) {
    foreach my $key (keys %{$this->{writeBuffer}}) {
      $this->{handler}->write($key, $this->{writeBuffer}{$key});
    }
    undef $this->{interimCache};
  }
}

=pod 

---++ ObjectMethod clear()

removes all objects from the cache.

=cut

sub clear {
  my $this = shift;

  return unless $this->{handler};

  $this->{handler}->quick_clear();
  undef $this->{writeBuffer};
  undef $this->{delBuffer};
  undef $this->{readBuffer};
}

1;
