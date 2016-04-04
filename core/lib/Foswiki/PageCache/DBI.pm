# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::PageCache::DBI

Implements a Foswiki::PageCache using a DBI compatible backend.

=cut

package Foswiki::PageCache::DBI;

use strict;
use warnings;

use Foswiki::PageCache ();
use DBI                ();
use Error qw(:try);
use Foswiki::Sandbox ();
use Foswiki::Plugins ();

@Foswiki::PageCache::DBI::ISA = ('Foswiki::PageCache');

# Enable output
use constant TRACE => 0;

sub writeDebug {
    print STDERR "$_[0]\n" if TRACE;
}

=begin TML

---++ ClassMethod new( ) -> $object

Construct a new page cache and makes sure the database is ready

=cut

sub new {
    my $class = shift;

    my $tablePrefix = $Foswiki::cfg{Cache}{DBI}{TablePrefix} || 'foswiki_cache';

    my $this = {
        cacheDir => $Foswiki::cfg{Cache}{RootDir}
          || $Foswiki::cfg{WorkingDir} . '/cache',

        dsn      => $Foswiki::cfg{Cache}{DBI}{DSN},
        username => $Foswiki::cfg{Cache}{DBI}{Username},
        password => $Foswiki::cfg{Cache}{DBI}{Password},

        pagesTable     => $tablePrefix . '_pages',
        pagesIndex     => $tablePrefix . '_pages_index',
        depsTable      => $tablePrefix . '_deps',
        depsIndex      => $tablePrefix . '_deps_index',
        depsTopicIndex => $tablePrefix . '_deps_topics_index',

        @_
    };

    return bless( $this, $class );
}

=begin TML

---++ ObjectMethod init()

Initializes and connects to the database

=cut

sub init {
    my $this = shift;

    return if $this->{_doneInit};
    $this->{_doneInit} = 1;

    my $error;

    try {
        $this->connect;
    }
    catch Error with {
        $error = shift;
        my $msg;
        if ( defined $DBI::errstr ) {
            $msg =
                "ERROR: unable to create tables in Foswiki::PageCache::DBI: "
              . $DBI::errstr . "\n"
              . $error;
        }
        else {
            $msg =
"ERROR: unable to use configured DBI in Foswiki::PageCache::DBI: \n"
              . $error;
        }

        print STDERR $msg . "\n";
        $Foswiki::cfg{Cache}{Enabled} = 0;
    };
    return if $error;

    try {
        $this->createTables;
    }
    catch Error with {
        $error = shift;

        my $msg =
            "ERROR: unable to create tables in Foswiki::PageCache::DBI: "
          . $DBI::errstr . "\n"
          . $error;

        print STDERR $msg . "\n";
        $Foswiki::cfg{Cache}{Enabled} = 0;
        $this->{dbh}->rollback;
        $this->{dbh}->disconnect;
    };
    return if $error;

    mkdir $this->{cacheDir} unless -d $this->{cacheDir};

    return $this;
}

=begin TML

---++ ObjectMethod setPageVariation($web, $topici, $variationKey, $variation)

stores a page and its meta data  

=cut

sub setPageVariation {
    my ( $this, $web, $topic, $variationKey, $variation ) = @_;

    my $webTopic = $web . '.' . $topic;

    $variation->{md5} =
      Digest::MD5::md5_hex(
        Foswiki::encode_utf8( $web . $topic . $variationKey ) )
      unless defined $variation->{md5};

    #writeDebug("INSERT topic $webTopic, variation=$variationKey");

    my $error;
    try {
        $this->{dbh}->begin_work;

        unless ( defined $this->{_insert_page} ) {
            $this->{_insert_page} = $this->{dbh}->prepare(<<HERE);
            insert into $this->{pagesTable} 
              (topic, variation, contenttype, lastmodified, etag, status, location, expire, isdirty, md5) values 
              (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
HERE
        }

      #     if (TRACE) {
      #         writeDebug( "   contenttype=" . $variation->{contenttype} );
      #         writeDebug( "   lastmodified=" . $variation->{lastmodified} );
      #         writeDebug( "   etag=" . $variation->{etag} );
      #         writeDebug( "   status=" . $variation->{status} );
      #         writeDebug( "   location=" . ( $variation->{location} || '' ) );
      #         writeDebug( "   expire=" .   ( $variation->{expire}   || '' ) );
      #         writeDebug( "   isdirty=" . $variation->{isdirty} );
      #         writeDebug( "   md5=" . $variation->{md5} );
      #     }

        $this->{_insert_page}->execute(
            $webTopic,                 $variationKey,
            $variation->{contenttype}, $variation->{lastmodified},
            $variation->{etag},        $variation->{status},
            $variation->{location},    $variation->{expire},
            $variation->{isdirty},     $variation->{md5}
          )
          or die( "Can't execute statement: " . $this->{_insert_page}->errstr );

        $this->{dbh}->commit;
    }
    catch Error with {
        local $this->{dbh}->{RaiseError} = 0;
        $this->{dbh}->rollback;
        $error = 1;
        writeDebug("transaction error at setPageVariation");
    };
    return 0 if $error;

    my $FILE;
    my $fileName = Foswiki::Sandbox::normalizeFileName(
        $this->{cacheDir} . '/' . $variation->{md5} );

    #writeDebug("saving data of $webTopic into $fileName");
    open( $FILE, '>:encoding(utf-8)', $fileName )
      or die "Can't create file $fileName - $!\n";
    print $FILE $variation->{data};
    close($FILE);

    return 1;    # success
}

=begin TML

---++ ObjectMethod getPageVariation($web, $topic, $variationKey)

retrievs a cache entry; returns undef if there is none.

=cut

sub getPageVariation {
    my ( $this, $web, $topic, $variationKey ) = @_;

    my $webTopic = $web;
    $webTopic .= '.' . $topic if $topic;

    #writeDebug("getPageVariation($webTopic, $variationKey)");

    my $sth = $this->{dbh}->prepare(<<HERE);
      select contenttype, lastmodified, etag, status, expire, isdirty, md5 from $this->{pagesTable} 
        where topic = ? and variation = ?
HERE

    $sth->execute( $webTopic, $variationKey )
      or die( "Can't execute statement: " . $sth->errstr );

    my $variation = $sth->fetchrow_hashref();

    $sth->finish;

    if ( defined $variation ) {
        my $FILE;
        my $fileName = $this->{cacheDir} . '/' . $variation->{md5};
        open( $FILE, '<:encoding(utf-8)', $fileName ) or return;
        local $/ = undef;
        $variation->{data} = <$FILE>;
        close($FILE);
        $variation->{data} = '' unless defined $variation->{data};
    }

    return $variation;
}

=begin TML

---++ ObjectMethod deleteAll()

drops all data and rebuilts the database

=cut

sub deleteAll {
    my $this = shift;

    $this->rebuild();

    opendir( my $dh, $this->{cacheDir} );
    my @files = map {
        Foswiki::Sandbox::normalizeFileName( $this->{cacheDir} . '/' . $_ )
    } grep { !/^\./ } readdir $dh;
    closedir $dh;

    #writeDebug("cleaning up @files");
    unlink @files;
}

=begin TML

---++ ObjectMethod deletePage($web, $topic, $variation)

See Foswiki::PageCache::deletePage() for more information.

=cut

sub deletePage {
    my ( $this, $web, $topic, $variationKey ) = @_;

    #writeDebug("called deletePage($web, $topic)");

    $web =~ s/\//./g;

    my $webTopic = $web;
    $webTopic .= '.' . $topic if $topic;

    try {
        $this->{dbh}->begin_work;

        # delete page
        if ( defined $variationKey ) {

            #writeDebug( "DELETE page $webTopic variation=" . $variationKey );
            my $md5 =
              Digest::MD5::md5_hex(
                Foswiki::encode_utf8( $web . $topic . $variationKey ) );
            my $fileName =
              Foswiki::Sandbox::normalizeFileName(
                $this->{cacheDir} . '/' . $md5 );

            #writeDebug("deleting $fileName for $webTopic");
            unlink $fileName;

            $this->{dbh}->do(
"delete from $this->{pagesTable} where topic = ? and variation = ?",
                undef, $webTopic, $variationKey
            );
        }
        else {

            # get all filenames and delete them
            unless ( defined $this->{_select_md5} ) {
                $this->{_select_md5} = $this->{dbh}->prepare(<<HERE);
                select md5 from $this->{pagesTable} where topic = ? and variation = ?
HERE
            }
            $this->{_select_md5}->execute( $webTopic, $variationKey );
            while ( my ($md5) = $this->{_select_md5}->fetchrow_array() ) {
                my $fileName = $this->{cacheDir} . '/' . $md5;

                #writeDebug("deleting $fileName for $webTopic");
                unlink $fileName;
            }

            #writeDebug("DELETE page $webTopic");
            $this->{dbh}->do( "delete from $this->{pagesTable} where topic = ?",
                undef, $webTopic );
        }

        $this->deleteDependencies( $web, $topic, $variationKey );

        $this->{dbh}->commit;
    }
    catch Error with {
        local $this->{dbh}->{RaiseError} = 0;
        $this->{dbh}->rollback;
        writeDebug("transaction error at deletePage");
    };
}

=begin TML

---++ ObjectMethod deleteDependencies($web, $topic, $variation)

Remove a dependency from the graph

=cut

sub deleteDependencies {
    my ( $this, $web, $topic, $variationKey ) = @_;

    my $webTopic = $web;
    $webTopic .= '.' . $topic if $topic;

   #writeDebug("called deleteDependencies($webTopic, ".($variationKey||'').")");

    # delete page and all dependencies
    if ( defined $variationKey ) {

       #writeDebug("DELETE dependencies of $webTopic variation=".$variationKey);
        $this->{dbh}->do(
"delete from $this->{depsTable} where from_topic = ? and variation = ?",
            undef, $webTopic, $variationKey
        );
    }
    else {

        #writeDebug("DELETE dependencies of $webTopic");
        $this->{dbh}->do( "delete from $this->{depsTable} where from_topic = ?",
            undef, $webTopic );
    }
}

=begin TML

---++ ObjectMethod setDependencies($web, $topic, $variation, @topics)

See Foswiki::PageCache::setDependencies() for more information

=cut

sub setDependencies {
    my ( $this, $web, $topic, $variationKey, @topicDeps ) = @_;

    @topicDeps = keys %{ $this->{deps} } unless @topicDeps;

    my $fromWebTopic = $web . '.' . $topic;

    try {
        $this->{dbh}->begin_work;

        unless ( defined $this->{_insert_dep} ) {
            $this->{_insert_dep} = $this->{dbh}->prepare(<<HERE);
            insert into $this->{depsTable} (from_topic, variation, to_topic) values (?, ?, ?)
HERE
        }

        foreach my $toWebTopic (@topicDeps) {
            next if $toWebTopic eq $fromWebTopic;

    #writeDebug( "INSERT dependency $fromWebTopic, $variationKey, $toWebTopic");
            $this->{_insert_dep}
              ->execute( $fromWebTopic, $variationKey, $toWebTopic )
              or
              die( "Can't execute statement: " . $this->{_insert_dep}->errstr );
        }

        $this->{dbh}->commit;
    }
    catch Error with {
        local $this->{dbh}->{RaiseError} = 0;
        $this->{dbh}->rollback;
        writeDebug("transaction error at setDependencies");
    };
}

=begin TML

---++ ObjectMethod getDependencies($web, $topic, $variation)

Returns the list of topics being used to render the given web.topic.
This method is mainly used for testing and debugging purposes.

=cut

sub getDependencies {
    my ( $this, $web, $topic, $variationKey ) = @_;

    my $sth;

    my $webTopic = $web . '.' . $topic;

    if ( defined $variationKey ) {
        $sth = $this->{dbh}->prepare(<<HERE);
          select distinct to_topic $this->{depsTable} where from_topic = ? and variation = ?
HERE
        $sth->execute( $webTopic, $variationKey )
          or die( "Can't execute statement: " . $sth->errstr );
    }
    else {
        $sth = $this->{dbh}->prepare(<<HERE);
          select distinct to_topic $this->{depsTable} where from_topic = ?
HERE
        $sth->execute($webTopic)
          or die( "Can't execute statement: " . $sth->errstr );
    }

    my @result = ();

    while ( my ($data) = $sth->fetchrow_array() ) {
        push @result, $data;
    }

    $sth->finish;

    return \@result;
}

=begin TML

---++ ObjectMethod fireDependency($web, $topic)

Deletes all cache entries that point here.

See Foswiki::PageCache::fireDependency() for more.

=cut

sub fireDependency {
    my ( $this, $web, $topic ) = @_;

    $web =~ s/\//./g;
    my $webTopic = $web . '.' . $topic;

    if (TRACE) {
        my ( $package, $file, $line ) = caller(1);

        #writeDebug("FIRING $webTopic ... called from $package, line $line");
    }

    my $error;
    try {
        $this->{dbh}->begin_work;

        # (1) get all md5s and unline the files holding the blob
        unless ( $this->{_select_rev_md5} ) {
            $this->{_select_rev_md5} = $this->{dbh}->prepare(<<HERE);
            select md5 from $this->{pagesTable} as pages join $this->{depsTable} as deps on 
              deps.from_topic = pages.topic and 
              deps.variation = pages.variation where
              deps.to_topic = ?
HERE
        }

        $this->{_select_rev_md5}->execute($webTopic);
        while ( my ($md5) = $this->{_select_rev_md5}->fetchrow_array ) {
            my $fileName = $this->{cacheDir} . '/' . $md5;

            #writeDebug("deleting $fileName for $webTopic");
            unlink $fileName;
        }

        # (2) delete the page entries that used $web.$topic
        $this->{dbh}->do(<<HERE);
        delete from $this->{pagesTable} where ( 
          select count(*) > 0 from $this->{depsTable} as deps 
            where deps.from_topic = $this->{pagesTable}.topic and 
                  deps.variation = $this->{pagesTable}.variation and 
                  deps.to_topic = '$webTopic' 
        )
HERE

# (3) delete the deps of topics that we just removed
# SMELL: yes, I know cascaded deletes would have been better, but that
# doesn't seem to work on mysql and sqlite. postgresql is fine, but the rest is ...
        $this->{dbh}->do(<<HERE);
        delete from $this->{depsTable} where 
          from_topic not in ( select distinct topic from $this->{pagesTable} )
HERE
        $this->{dbh}->commit;
    }
    catch Error with {
        local $this->{dbh}->{RaiseError} = 0;
        $this->{dbh}->rollback;
        $error = 1;
        writeDebug("transaction error at fireDependency");
    };
    return if $error;

    # (4) delete all pages in WEBDEPENDENCIES
    foreach my $dep ( @{ $this->getWebDependencies($web) } ) {
        $this->deletePage($dep);
    }

    # (5) delete this page
    $this->deletePage($webTopic);
}

=begin TML

---++ ObjectMethod connect()

connects to the database

=cut

sub connect {
    my $this = shift;

    unless ( defined $this->{dbh} ) {

        $this->{dbh} = DBI->connect(
            $this->{dsn},
            $this->{username},
            $this->{password},
            {
                PrintError         => 0,
                RaiseError         => 1,
                AutoCommit         => 1,
                ShowErrorStatement => 1,
            }
        );

        throw Error::Simple(
            "Can't open database $this->{dsn}: " . $DBI::errstr )
          unless defined $this->{dbh};
    }

    return $this->{dbh};
}

=begin TML

---++ ObjectMethod createTables()

creates the database tables if not existing yet

=cut

sub createTables {
    my $this = shift;

    # test whether the table exists
    eval { $this->{dbh}->do("select topic from $this->{pagesTable} limit 1"); };

    if ($@) {
        writeDebug("test result: $@");
    }
    else {

        # when this doesn't error out, the tables are there
        return;
    }

    #writeDebug("building new database");

    $this->_createPagesTable;
    $this->_createDepsTable;
}

sub _createPagesTable {
    my $this = shift;

    $this->{dbh}->do(<<HERE);
      create table $this->{pagesTable} (
        topic varchar(255),
        variation varchar(1024),
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
          from_topic varchar(255),
          variation varchar(1024),
          to_topic varchar(255)
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

=begin TML

---++ ObjectMethod _rebuild()

drops all tables and creates new ones. 

=cut

sub rebuild {
    my $this = shift;

    #writeDebug("rebuild database");

    eval {
        $this->{dbh}->do("drop table $this->{pagesTable}");
        $this->{dbh}->do("drop table $this->{depsTable}");
    };

    if ($@) {
        print STDERR "ERROR when dropping tables: $@\n";
    }

    $this->createTables;
}

=begin TML

---++ ObjectMethod finish()

cleans up the mess we left behind

=cut

sub finish {
    my $this = shift;

    #writeDebug("called finish");

    if ( $this->{_insert_page} ) {
        $this->{_insert_page}->finish;
        undef $this->{_insert_page};
    }

    if ( $this->{_insert_dep} ) {
        $this->{_insert_dep}->finish;
        undef $this->{_insert_dep};
    }

    if ( $this->{_select_md5} ) {
        $this->{_select_md5}->finish;
        undef $this->{_select_md5};
    }

    if ( $this->{_select_rev_md5} ) {
        $this->{_select_rev_md5}->finish;
        undef $this->{_select_rev_md5};
    }

    if ( $this->{dbh} ) {
        $this->{dbh}->disconnect;
        undef $this->{dbh};
    }

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
