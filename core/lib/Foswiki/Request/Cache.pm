# See bottom of file for license and copyright information
package Foswiki::Request::Cache;

=begin TML

---+ package Foswiki::Request::Cache

Class that implements a disk cache of Foswiki::Request objects.

There are a couple of cases where we need to cache request objects; over a
403 redirect (which is a GET and therefore has limited parameter capacity)
and over a confirmation, such as a strikeone validation. In these cases we 
need to cache not just the request parameters, but also any uploads
associated with the request. We also need the means to keep the cache tidy.

Note that the cache records the method() and path_info() of the original
request and restores them on reload.

=cut

use strict;
use warnings;
use Assert;

use File::Copy   ();
use Data::Dumper ();
use Digest::MD5  ();
use Fcntl;    # File control constants e.g. O_EXCL

use Foswiki::Request::Upload ();
use Foswiki::Sandbox         ();

use constant TRACE_CACHE => 0;

=begin TML

---++ ClassMethod new()

Construct a new request cache.

=cut

sub new {
    my ($class) = @_;
    my $this = bless( {}, $class );
    return $this;
}

sub finish {
}

=begin TML

---++ ObjectMethod save( $request ) -> $uid

$request is a Foswiki::Request object to be cached; the cache is
identifiable by the unique $uid,
which can be stored and passed to $cache->load(). A cache file will be kept
until it is loaded (which destroys the cache) or it is cleaned up.

=cut

sub save {
    my ( $this, $req ) = @_;

    # get a hex-encoded session-specific unguessable key for the cache
    my $digester = new Digest::MD5();
    $digester->add( $$, rand(time) );
    my $uid = $digester->hexdigest();

    # passthrough file is only written to once, so if it already exists,
    # suspect a security hack (O_EXCL)
    my $F;
    sysopen( $F, $this->_cacheFile($uid), O_RDWR | O_EXCL | O_CREAT, 0600 )
      || die 'Unable to open '
      . $this->_cacheFile($uid)
      . ' for write; check the setting of {WorkingDir} in configure,'
      . ' and check file permissions: '
      . $!;

    # Serialize some key info from the request
    foreach my $field (qw(method path_info action)) {
        print $F $field, '=', ( $req->$field() || '' ), "\n";
        print STDERR "CACHE $uid> $field(" . ( $req->$field() || '' ) . ")\n"
          if (TRACE_CACHE);
    }
    print $F "=\n";

    if (TRACE_CACHE) {
        foreach my $name ( $req->param ) {
            foreach my $value ( $req->multi_param($name) ) {
                $value = '' unless defined $value;
                print STDERR "CACHE $uid> $name=$value\n";
            }
        }
    }

    # Serialize the request parameters
    $req->save($F);

    # Serialize uploads, if there are any, and store the upload keys
    while ( my ( $k, $v ) = each %{ $req->{uploads} } ) {
        $k = Foswiki::urlEncode($k);
        print STDERR "CACHE $uid> upload $k\n" if (TRACE_CACHE);
        $this->_saveUpload( $this->_cacheFile($uid), $k, $v );
        print $F $k;
    }

    close($F);
    return $uid;
}

=begin TML

---++ ObjectMethod load( $uid, $request )

$uid is the id returned by =save()= which identifies the request cache.
$request must be a =Foswiki::Request= object that will be popluated
with the data from the cache. Loading a cache will destroy the cache on disk.

=cut

sub load {
    my ( $this, $uid, $req ) = @_;

    ASSERT($uid) if DEBUG;
    ASSERT( $uid =~ m/^[a-f0-9]{32}$/ ) if DEBUG;

    # Read cached post parameters
    my $F = new IO::File( $this->_cacheFile($uid), '<' );
    if ($F) {

        # Load request fields
        local $/ = "\n";
        while ( my $e = <$F> ) {
            chomp($e);
            last if $e eq '=';
            my ( $fn, $val ) = split( '=', $e, 2 );
            print STDERR "CACHE $uid< $fn($val)\n" if (TRACE_CACHE);
            $req->$fn($val);
        }

        if (TRACE_CACHE) {
            my $here = tell $F;
            while ( my $l = <$F> ) {
                last if $l =~ m/^=/;
                print STDERR "CACHE $uid< " . Foswiki::urlDecode($l);
            }
            seek( $F, $here, 0 );
        }

        # Load params
        $req->load($F);

        # Load uploads
        while ( my $key = <$F> ) {
            chomp($key);
            $key = Foswiki::Sandbox::untaintUnchecked($key);
            my $decodedKey = Foswiki::urlDecode($key);
            print STDERR "CACHE $uid< upload $decodedKey\n" if (TRACE_CACHE);
            $req->{uploads}->{$decodedKey} =
              $this->_loadUpload( $this->_cacheFile($uid), $key );
        }

        # Load uploads
        unlink( $this->_cacheFile($uid) );
        print STDERR "CACHE $uid< Loaded "
          . $this->_cacheFile($uid)
          . ", URL now "
          . $req->url() . "\n"
          if (TRACE_CACHE);

    }
    else {

        # SMELL: should this be an assert?
        print STDERR "CACHE $uid< Could not find ",
          $this->_cacheFile($uid) . "\n"
          if (TRACE_CACHE);
    }
}

=begin TML

---++ StaticMethod cleanup($timeout)

Clean up the cache by removing everything older than $timeout seconds.
If $timeout is 0 or undefined, it defaults to {Sessions}{ExpireAfter}.

=cut

sub cleanup {

    # Default timeout is 5 minutes
    my $timeout = shift || 5 * 60;
    my $deathtime = time() - $timeout;
    my $D;
    return unless opendir( $D, $Foswiki::cfg{WorkingDir} . '/tmp/' );
    foreach my $e ( readdir $D ) {
        next unless $e =~ m/^passthru_([a-f0-9]{32})/;
        my $f     = $Foswiki::cfg{WorkingDir} . '/tmp/' . $e;
        my @stat  = stat($f);
        my $mtime = $stat[9];
        if ( $mtime < $deathtime ) {
            $f = Foswiki::Sandbox::untaintUnchecked($f);
            unlink($f);
        }
    }
    closedir($D);
}

# PRIVATE. make the name of a cache file
sub _cacheFile {
    my ( $this, $uid ) = @_;

    # Validate and untaint in one step
    die "Illegal UID" unless $uid =~ m/^([0-9a-z]{32})$/i;
    return $Foswiki::cfg{WorkingDir} . '/tmp/passthru_' . $1;
}

# PRIVATE. Each upload is cached in two files,
# a serialisation of this object, and a copy of the uploaded data
sub _saveUpload {
    my ( $this, $root, $key, $upload ) = @_;

    require File::Copy;
    require Data::Dumper;

    my $ifn = "${root}_info_$key";
    my $dfn = "${root}_data_$key";
    my $F   = new IO::File( $ifn, '>' );
    ASSERT( $F, "Failed to open $ifn" ) if DEBUG;

    my $ser = Data::Dumper->new( [$upload], ['info'] );
    $ser->Indent(0);
    print $F $ser->Dump();

    $F->close();

    File::Copy::copy( $upload->{tmpname}, $dfn ) if ( -e $upload->{tmpname} );
}

# PRIVATE. restore upload from cached data
sub _loadUpload {
    my ( $this, $root, $key ) = @_;

    my $ifn = "${root}_info_$key";
    my $dfn = "${root}_data_$key";
    my $F   = new IO::File( $ifn, '<' );
    ASSERT( $F, "Failed to open $ifn" ) if DEBUG;
    ASSERT( -e $dfn, $dfn ) if DEBUG;

    # Load the object cache
    local $/;
    my $data = <$F>;
    $data = Foswiki::Sandbox::untaintUnchecked($data);
    my $info = undef;
    eval $data;
    $F->close();
    unlink($ifn);

    # Dodge file name collisions for the data file
    $info->{tmpname} .= '_' while ( -e $info->{tmpname} );

    # Construct the new object, and move the data file into place
    my $upload = new Foswiki::Request::Upload(%$info);
    File::Copy::move( $dfn, $upload->tmpFileName() ) if ( -e $dfn );

    return $upload;
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) 2009 Foswiki Contributors. Foswiki Contributors
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
