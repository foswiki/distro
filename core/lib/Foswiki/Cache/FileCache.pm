# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Cache::FileCache

Implementation of a Foswiki::Cache using Cache::FileCache. See Foswiki::Cache
for details of the methods implemented by this class.

=cut

package Foswiki::Cache::FileCache;

use strict;
use warnings;
use Cache::FileCache;
use Foswiki::Cache;

@Foswiki::Cache::FileCache::ISA = ('Foswiki::Cache');

sub init {
    my ( $this, $session ) = @_;

    $this->SUPER::init($session);
    unless ( $this->{handler} ) {
        $this->{handler} = new Cache::FileCache(
            {

                # also encoded into object keys, see
                # Foswiki::Cache::genVariationKey()
                'namespace'  => $this->{namespace},
                'cache_root' => $Foswiki::cfg{Cache}{RootDir}
                  || $Foswiki::cfg{WorkingDir} . '/cache/',
                'cache_depth'     => $Foswiki::cfg{Cache}{SubDirs} || 3,
                'directory_umask' => $Foswiki::cfg{Cache}{Umask}   || 077,
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
