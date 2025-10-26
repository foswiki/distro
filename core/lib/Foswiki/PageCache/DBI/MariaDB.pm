# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::PageCache::DBI::MariaDB

Implements a Foswiki::PageCache::DBI using MariaDB

=cut

package Foswiki::PageCache::DBI::MariaDB;

use strict;
use warnings;

use Foswiki::PageCache::DBI ();
@Foswiki::PageCache::DBI::MariaDB::ISA = ('Foswiki::PageCache::DBI');

=begin TML

---++ ClassMethod new( ) -> $object

Construct a new page cache and makes sure the database is ready

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            database => $Foswiki::cfg{Cache}{DBI}{MariaDB}{Database}
              || 'foswiki',
            host => $Foswiki::cfg{Cache}{DBI}{MariaDB}{Host} || 'localhost',
            port => $Foswiki::cfg{Cache}{DBI}{MariaDB}{Port} || '',
            username => $Foswiki::cfg{Cache}{DBI}{MariaDB}{Username},
            password => $Foswiki::cfg{Cache}{DBI}{MariaDB}{Password},
            @_
        ),
        $class
    );

    $this->{dsn} = 'dbi:MariaDB:database=' . $this->{database};
    $this->{dsn} .= ';host=' . $this->{host};
    $this->{dsn} .= ';port=' . $this->{port} if $this->{port};
    $this->{params}{mariadb_auto_reconnect} = 1;

    return $this->init;
}

sub _createPagesTable {
    my $this = shift;

    $this->{dbh}->do(<<HERE);
      create table $this->{pagesTable} (
        topic varchar(255) COLLATE utf8mb4_bin,
        variation varchar(1024) COLLATE utf8mb4_bin,
        md5 char(32),
        contenttype varchar(255),
        lastmodified varchar(255),
        etag varchar(255),
        status int,
        location varchar(255),
        expire int,
        isdirty int
  )
HERE

    $this->{dbh}
      ->do("create index $this->{pagesIndex} on $this->{pagesTable} (topic)");
}

sub _createDepsTable {
    my $this = shift;

    $this->{dbh}->do(<<HERE);
        create table $this->{depsTable} (
          from_topic varchar(255) COLLATE utf8mb4_bin,
          variation varchar(1024) COLLATE utf8mb4_bin,
          to_topic varchar(255) COLLATE utf8mb4_bin
        )
HERE

    # SMELL: this would have been nice to auto-delete deps while deleting pages.
    # works fine in postgresql, not so in sqlite and mysql.
    # foreign key (from_topic) references pages (topic) on delete cascade

    $this->{dbh}->do(
"create index $this->{depsIndex} on $this->{depsTable} (from_topic, to_topic)"
    );

    $this->{dbh}->do(
        "create index $this->{depsTopicIndex} on $this->{depsTable} (to_topic)"
    );
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
