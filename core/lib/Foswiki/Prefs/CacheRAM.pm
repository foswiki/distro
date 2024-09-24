# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Prefs::CacheRAM

This is a preference backend used to get preferences defined in a topic
and cache them in memory.

=cut

package Foswiki::Prefs::CacheRAM;

use strict;
use warnings;

use Foswiki::Prefs::Parser   ();
use Foswiki::Prefs::TopicRAM ();
our @ISA = ('Foswiki::Prefs::TopicRAM');

use constant TRACE => 0;
my %cache     = ();
my $cacheHits = 0;

=begin TML

---++ ClassMethod new(@_)

Creates a preferences backend object.

=cut

sub new {
    my ( $class, $topicObject ) = @_;

    my $this = bless(
        {
            topicObject => $topicObject,
            path        => $topicObject->getPath(),
            values      => {},
            local       => {}
        },
        $class
    );

    $this->{path} =~ s/\./\//g;

    my $entry = $this->getEntry();
    my $mtime = $entry ? $this->getModificationTime() : 0;

    if ( defined $entry && $mtime && $mtime <= $entry->{time} ) {

        $cacheHits++;
        print STDERR "found prefs in cache for $this->{path}\n" if TRACE;

        %{ $this->{values} } = %{ $entry->{values} };
        %{ $this->{local} }  = %{ $entry->{local} };
        return $this;
    }

    print STDERR "adding prefs to cache for $this->{path}\n" if TRACE;

    Foswiki::Prefs::Parser::parse( $topicObject, $this )
      if $topicObject->existsInStore();

    $this->setEntry();

    return $this;
}

=begin TML

---++ ObjectMethod finish()

Break circular references.

=cut

sub finish {
    my $this = shift;

    return unless defined $this->{topicObject};

    undef $this->{path};
    undef $this->{values};
    undef $this->{local};
    undef $this->{topicObject};
}

=begin TML

---++ ObjectMethod cacheHits() -> $int

returns the number of hits to the memory cache 

=cut

sub cacheHits {
    return $cacheHits;
}

=begin TML

---++ ObjectMethod getEntry() -> \%entry

returns a cache entry for the given topic object

=cut

sub getEntry {
    my $this = shift;

    return $cache{ $this->getCacheKey };
}

=begin TML

---++ ObjectMethod setEntry() -> \%entry

stores the private values into the global cache.

=cut

sub setEntry {
    my $this = shift;

    my %values = %{ $this->{values} };
    my %local  = %{ $this->{local} };

    my $entry = $cache{ $this->getCacheKey } = {
        time   => time(),
        values => \%values,
        local  => \%local,
    };

    return $entry;
}

=begin TML

---++ ObjectMethod getModificationTime() -> $timestamp

returns the file modification time of the topic object 

SMELL: breaks storage abstraction, should be part of the storage api

=cut

sub getModificationTime {
    my $this = shift;

    my $path = $Foswiki::cfg{DataDir} . "/$this->{path}.txt";
    my @stat = stat($path);

    return $stat[9] || $stat[10] || 0;
}

=begin TML

---++ ObjectMethod invalidate($metaOrPath) 

this method can be called as an object as well as a class method.
If called as a class method the $metaOrPath parameter is mandatory

=cut

sub invalidate {
    my ( $this, $metaOrPath ) = @_;

    my $key = $this->getCacheKey($metaOrPath);
    delete $cache{$key} if defined $key;
}

=begin TML

---++ ObjectMethod getCacheKey($metaOrPath) -> $string

this method is an object as well as class method, similar to invalidate().
it returns the key for the current object to cache its preferences for.

=cut

sub getCacheKey {
    my ( $this, $metaOrPath ) = @_;

    my $path = ref($this) ? $this->{path} : undef;

    if ( !defined($path) && defined($metaOrPath) ) {
        if ( ref($metaOrPath) ) {
            $path = $metaOrPath->getPath();
        }
        else {
            $path = $metaOrPath;
        }
        $path =~ s/\./\//g;
    }

    return unless defined $path;
    return $Foswiki::cfg{DefaultUrlHost} . "::" . $path;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2024 Foswiki Contributors. Foswiki Contributors
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
