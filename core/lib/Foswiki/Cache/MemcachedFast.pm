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

---+ package Foswiki::Cache::MemcachedFast

implementation of a Foswiki::Cache using memcached

=cut

package Foswiki::Cache::MemcachedFast;

use strict;
use Cache::Memcached::Fast;
use Foswiki::Cache;

@Foswiki::Cache::MemcachedFast::ISA = ( 'Foswiki::Cache' );

=pod 

---++ ClassMethod new( $session ) -> $object

Construct a new cache connecting to a memcached server pool. 

=cut

sub new {
  my ($class, $session) = @_;

  return bless($class->SUPER::new($session), $class);
}

=pod

---++ ObjectMethod init($session)

connect to the memcached if we didn't already

=cut

sub init {
  my ($this, $session) = @_;

  $this->SUPER::init($session);
  unless ($this->{handler}) {
    $this->{servers} = $Foswiki::cfg{Cache}{Servers} || '127.0.0.1:11211';

    my @servers = split(/,\s/, $this->{servers});
    # connect to new cache
    $this->{handler} = new Cache::Memcached::Fast {
      servers=>[@servers],
      nowait=>1,
      compress_ratio=>0, # disable compression
    };
  }
}

=pod 

---++ ObjectMethod clear()

removes all objects from the cache. 

=cut

sub clear {
  my $this = shift;

  return unless $this->{handler};

  $this->{handler}->flush_all;
  undef $this->{writeBuffer};
  undef $this->{delBuffer};
  undef $this->{readBuffer};
}

1;
