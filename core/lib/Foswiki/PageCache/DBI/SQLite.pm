# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::PageCache::DBI::SQLite

Implements a Foswiki::PageCache::DBI using sqlite

=cut

package Foswiki::PageCache::DBI::SQLite;

use strict;
use warnings;

use Foswiki::PageCache::DBI ();
@Foswiki::PageCache::DBI::SQLite::ISA = ('Foswiki::PageCache::DBI');

=begin TML

---++ ClassMethod new( ) -> $object

Construct a new page cache and makes sure the database is ready

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            filename => $Foswiki::cfg{Cache}{DBI}{SQLite}{Filename},
            @_
        ),
        $class
    );

    $this->{filename} ||= $Foswiki::cfg{WorkingDir} . '/sqlite.db';
    $this->{dsn} = 'dbi:SQLite:dbname=' . $this->{filename};

    return $this->init;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
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
