# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Cache::Memcached

implementation of a Foswiki::Cache using memcached

=cut

package Foswiki::Cache::Memcached;

use strict;
use Cache::Memcached;
use Foswiki::Cache;

@Foswiki::Cache::Memcached::ISA = ('Foswiki::Cache');

=pod 

---++ ClassMethod new( $session ) -> $object

Construct a new cache connecting to a memcached server pool. 

=cut

sub new {
    my ( $class, $session ) = @_;

    return bless( $class->SUPER::new($session), $class );
}

=pod

---++ ObjectMethod init($session)

connect to the memcached if we didn't already

=cut

sub init {
    my ( $this, $session ) = @_;

    $this->SUPER::init($session);
    unless ( $this->{handler} ) {
        $this->{servers} = $Foswiki::cfg{Cache}{Servers} || '127.0.0.1:11211';

        my @servers = split( /,\s/, $this->{servers} );

        # connect to new cache
        $this->{handler} = new Cache::Memcached {
            'servers' => [@servers],

            #'debug'=> $Foswiki::cfg{Cache}{Debug},
            'compress_enable' => 0,    # no effect
        };
    }
    $this->{handler}->{compress_enable} = 0;
}

=pod 

finish up internal structures

=cut

sub finish {
    my $this = shift;

    # this is where individual backends to their real work
    # by implementing the write action
    if ( $this->{handler} ) {

        # begin transaction / aquire lock

        if ( $this->{delBuffer} ) {
            foreach my $key ( keys %{ $this->{delBuffer} } ) {
                next unless $this->{delBuffer}{$key};
                $this->{handler}->delete($key);

                #Foswiki::Cache::writeDebug("deleting $key");
            }
        }

        if ( $this->{writeBuffer} ) {
            foreach my $key ( keys %{ $this->{writeBuffer} } ) {
                my $obj = $this->{writeBuffer}{$key};
                next unless $obj;
                $this->{handler}->set( $key, $obj );

                #Foswiki::Cache::writeDebug("flushing $key");
            }
        }

        # commit transaction / release lock

        #$this->{handler}->disconnect_all();
        undef $this->{handler};
    }

    $this->SUPER::finish();
}

=pod 

---++ ObjectMethod clear()

removes all objects from the cache. 

=cut

sub clear {
    my $this = shift;

    #$this->{handler}->flush_all;
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
Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
