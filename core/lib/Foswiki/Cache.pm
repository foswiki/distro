# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Cache

Virtual base class for cache implementations. A cache implementation is
used by Foswiki::PageCache to store cached data (both page data and meta-data
about the cached pages).

=cut

package Foswiki::Cache;

use strict;
use warnings;

=begin TML 

---++ ClassMethod new( $session ) -> $object

Construct a new cache delegator. 

=cut

sub new {
    my ( $class, $session ) = @_;

    my $this = {};
    bless( $this, $class );
    $this->init($session);

    return $this;
}

=begin TML 

---++ ObjectMethod init($session)

Initializes a cache object to be used for the current request. this
object might be _shared_ on multiple requests when Foswiki is accelerated
using mod_perl or speedy-cgi and using the Foswiki::Cache::MemoryCache 
handler.

Subclasses should call up to this method at the start of overriding
implementations.

=cut

sub init {
    my ( $this, $session ) = @_;

    $this->{session} = $session;
    my $nameSpace = $Foswiki::cfg{Cache}{NameSpace}
      || $Foswiki::cfg{DefaultUrlHost};
    $nameSpace =~ s/^https?:\/\///go;
    $nameSpace =~ s/[\s\/]+/_/go;
    $this->{namespace} = $nameSpace;
}

=begin TML 

---++ ObjectMethod DESTROY()

Explicit destructor to break cyclic links.

=cut

sub DESTROY {
    my $this = shift;
    $this->finish();
}

=begin TML 

---++ ObjectMethod finish()

Clean up internal structures

=cut

sub finish {
    my $this = shift;

    # this is where individual backends to their real work
    # by implementing the write action
    if ( $this->{handler} ) {

        # begin transaction

        if ( $this->{delBuffer} ) {
            foreach my $key ( keys %{ $this->{delBuffer} } ) {
                next unless $this->{delBuffer}{$key};
                $this->{handler}->remove($key);
            }
        }

        if ( $this->{writeBuffer} ) {
            foreach my $key ( keys %{ $this->{writeBuffer} } ) {
                my $obj = $this->{writeBuffer}{$key};
                next unless $obj;
                $this->{handler}->set( $key, $obj );
            }
        }

        # commit transaction

        undef $this->{handler};
    }

    undef $this->{session};
    undef $this->{readBuffer};
    undef $this->{writeBuffer};
    undef $this->{delBuffer};
}

=begin TML

---++ ObjectMethod genkey($string, $key) -> $key

Generate a key for the current cache.

Some cache implementations don't have a namespace feature.  Those
which do are only able to serve objects from within one namespace
per cache object. 

So by default we encode the namespace into the key here, even when this is
redundant, given that you specify the namespace for Cache::Cache
implementations during the constructor already.

=cut

sub genKey {
    my ( $this, $key ) = @_;
    my $pageKey = $this->{namespace};
    $pageKey .= ':' . $key if $key;
    $pageKey =~ s/[\s\/]+/_/go;
    return $pageKey;
}

=begin TML

---++ ObjectMethod set($key, $object ... ) -> $boolean

Cache an $object under the given $key. Note that the
object won't be flushed to disk until we called finish().

Returns true if it was stored sucessfully

=cut

sub set {
    my ( $this, $key, $obj ) = @_;

    return 0 unless $this->{handler};
    return 0 unless defined($key) && defined($obj);

    my $pageKey = $this->genKey($key);

    $this->{writeBuffer}{$pageKey} = $obj;
    $this->{readBuffer}{$pageKey}  = $obj;

    if ( $this->{delBuffer} ) {
        delete $this->{delBuffer}{$pageKey};
    }

    return 1;
}

=begin TML 

---++ ObjectMethod get($key) -> $object

Retrieve a cached object, returns undef if it does not exist

=cut

sub get {
    my ( $this, $key ) = @_;

    return 0 unless $this->{handler};

    my $pageKey = $this->genKey($key);
    if ( $this->{delBuffer} ) {
        return undef if $this->{delBuffer}{$pageKey};
    }

    my $obj = $this->{readBuffer}{$pageKey};
    return $obj if $obj;

    $obj = $this->{handler}->get($pageKey);
    $this->{readBuffer}{$pageKey} = $obj;

    return $obj;
}

=begin TML 

---++ ObjectMethod delete($key) -> $boolean

Delete an entry for a given $key

Returns true if the key was found and deleted, and false otherwise

=cut

sub delete {
    my ( $this, $key ) = @_;

    #print STDERR "called Cache::delete($key)\n";

    return 0 unless $this->{handler};

    my $pageKey = $this->genKey($key);

    delete $this->{writeBuffer}{$pageKey};
    delete $this->{readBuffer}{$pageKey};
    $this->{delBuffer}{$pageKey} = 1;

    return 1;
}

=begin TML 

---++ ObjectMethod clear()

Removes all objects from the cache.

=cut

sub clear {
    my $this = shift;

    $this->{handler}->clear() if $this->{handler};
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

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
