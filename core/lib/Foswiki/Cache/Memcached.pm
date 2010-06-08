# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Cache::Memcached

implementation of a Foswiki::Cache using memcached. See Foswiki::Cache
for details of the methods implemented by this class.

=cut

package Foswiki::Cache::Memcached;

use strict;
use warnings;
use Cache::Memcached;
use Foswiki::Cache;

@Foswiki::Cache::Memcached::ISA = ('Foswiki::Cache');

sub new {
    my ( $class, $session ) = @_;

    return bless( $class->SUPER::new($session), $class );
}

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

                Foswiki::PageCache::writeDebug("deleting $key")
                  if (Foswiki::PageCache::TRACE);
            }
        }

        if ( $this->{writeBuffer} ) {
            foreach my $key ( keys %{ $this->{writeBuffer} } ) {
                my $obj = $this->{writeBuffer}{$key};
                next unless $obj;
                $this->{handler}->set( $key, $obj );

                Foswiki::PageCache::writeDebug("flushing $key")
                  if (Foswiki::PageCache::TRACE);
            }
        }

        # commit transaction / release lock

        #$this->{handler}->disconnect_all();
        undef $this->{handler};
    }

    $this->SUPER::finish();
}

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
