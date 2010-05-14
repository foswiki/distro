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

---+ package Foswiki::Cache::MemoryHash

Implementation of a Foswiki::Cache using an in-memory perl hash

=cut

package Foswiki::Cache::MemoryHash;

use strict;
use Foswiki::Cache;
use vars qw($sharedCache);

@Foswiki::Cache::MemoryHash::ISA = ('Foswiki::Cache');

=pod 

---++ ClassMethod new( $session ) -> $object

Construct a new cache object. 

=cut

sub new {
    my ( $class, $session ) = @_;

    unless ($sharedCache) {
        $sharedCache = bless( $class->SUPER::new($session), $class );
    }

    $sharedCache->init($session);

    return $sharedCache;
}

=pod

---++ ObjectMetohd set($key, $object) -> $boolean

cache an $object under the given $key

returns true if it was stored sucessfully

=cut

sub set {
    my ( $this, $key, $obj ) = @_;

    $this->{cache}{ $this->genKey($key) } = $obj;
    return $obj;
}

=pod 

---++ ObjectMethod get($key) -> $object

retrieve a cached object, returns undef if it does not exist

=cut

sub get {
    my ( $this, $key ) = @_;

    return $this->{cache}{ $this->genKey($key) };
}

=pod 

---++ ObjectMethod delete($key)

delete an entry for a given $key

returns true if the key was found and deleted, and false otherwise

=cut

sub delete {
    my ( $this, $key ) = @_;

    undef $this->{cache}{ $this->genKey($key) };
    return 1;
}

=pod 

---++ ObjectMethod clear()

removes all objects from the cache.

=cut

sub clear {
    my $this = shift;

    $this->{cache} = ();
}

=pod

---++ ObjectMet finis()

do nothing, keep all in memory

=cut

sub finish { }

1;
