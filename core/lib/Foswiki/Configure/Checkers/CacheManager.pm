# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::CacheManager;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    return '' unless $Foswiki::cfg{Cache}{Enabled};
    if ( $Foswiki::cfg{CacheManager} eq 'Foswiki::Cache::BDB' ) {
        return $this->checkPerlModule( 'BerkeleyDB',
            'Use the Berkeley database engine' );
    }
    elsif ( $Foswiki::cfg{CacheManager} eq 'Foswiki::Cache::DB_File' ) {
        return $this->checkPerlModule( 'DB_File',
            'Use the file database engine' );
    }
    elsif ( $Foswiki::cfg{CacheManager} eq 'Foswiki::Cache::FileCache' ) {
        return $this->checkPerlModule( 'Cache::FileCache',
            'Use the Cache::FileCache database engine' );
    }
    elsif ( $Foswiki::cfg{CacheManager} eq 'Foswiki::Cache::Memcached' ) {
        return $this->checkPerlModule( 'Cache::Memcached',
            'Use the Cache::Memcached database engine' );
    }
    elsif ( $Foswiki::cfg{CacheManager} eq 'Foswiki::Cache::MemoryCached' ) {
        return $this->checkPerlModule( 'Cache::MemoryCached',
            'Use the Cache::MemoryCached database engine' );
    }
    elsif (
        $Foswiki::cfg{CacheManager} =~ /^Foswiki::Cache::Memory(?:Hash|LRU)$/ )
    {
        return '';
    }
    return $this->ERROR(
        "Unknown CacheManager implementation: $Foswiki::cfg{CacheManager}");
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
