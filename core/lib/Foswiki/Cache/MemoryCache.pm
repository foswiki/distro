# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Cache::MemoryCache

Implementation of a Foswiki::Cache using Cache::MemoryCache.
See Foswiki::Cache for details of the methods implemented by this class.

=cut

package Foswiki::Cache::MemoryCache;

use strict;
use warnings;
use Cache::MemoryCache;
use Foswiki::Cache;

@Foswiki::Cache::MemoryCache::ISA = ('Foswiki::Cache');

sub new {
    my ( $class, $session ) = @_;

    return bless( $class->SUPER::new($session), $class );
}

sub init {
    my ( $this, $session ) = @_;

    $this->SUPER::init($session);
    unless ( $this->{handler} ) {
        $this->{handler} = new Cache::MemoryCache(
            {
                'namespace' => $this->{namespace}
                ,  # also encoded into object keys, see Foswiki::Cache::genKey()
                'auto_purge_on_set' => 1,
            }
        );
    }
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
