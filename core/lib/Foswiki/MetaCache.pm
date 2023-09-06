# See bottom of file for license and copyright information
package Foswiki::MetaCache;
use strict;
use warnings;

=begin TML

---+ package Foswiki::MetaCache

A cache of Meta objects - initially used to speed up searching and sorting, but by foswiki 2.0 hopefully this 
will be used for all readonly accesses to the store.

Replaces the mishmash of the Search InfoCache Support package; cache of topic info. 
When information about search hits is
compiled for output, this cache is used to avoid recovering the same info
about the same topic more than once.

=cut

use Assert;
use Scalar::Util qw(blessed);
use Foswiki::Func                   ();
use Foswiki::Meta                   ();
use Foswiki::Users::BaseUserMapping ();

#use Monitor ();
#Monitor::MonitorMethod('Foswiki::MetaCache', 'getTopicListIterator');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new($session)

=cut

sub new {
    my ( $class, $session ) = @_;

    #my $this = $class->SUPER::new([]);
    my $this = bless(
        {
            session => $session,
            cache   => {},
        },
        $class
    );

    return $this;
}

#need to delete from cache if the store saves / updates it :/
#otherwise the Meta::load thing is busted.

=begin TML

---++ ObjectMethod finish()
Break circular references.

 Note to developers; please undef *all* fields in the object explicitly,
 whether they are references or not. That way this method is "golden
 documentation" of the live fields in the object.

=cut

sub finish {
    my $this = shift;

    #must clear cache every request until the cache is hooked up to Store's save
    foreach my $web ( keys( %{ $this->{cache} } ) ) {
        foreach my $topic ( keys( %{ $this->{cache}{$web} } ) ) {
            my $meta = $this->{cache}{$web}{$topic}{tom};
            undef $this->{cache}{$web}{$topic};
            $meta->finish();
        }
        undef $this->{cache}{$web};
    }

    undef $this->{session};
    undef $this->{cache};
}

=begin TML

---++ ObjectMethod isCached($webtopic) -> boolean

returns true if the topic is already in the cache.

=cut

sub isCached {
    my ( $this, $web, $topic ) = @_;
    ASSERT( defined($topic) ) if DEBUG;
    return unless defined $topic;

    return exists $this->{cache}{$web}{$topic};
}

=begin TML

---++ ObjectMethod removeMeta($web, $topic)

removes but does not finish the meta object from cache

=cut

sub removeMeta {
    my ( $this, $web, $topic ) = @_;

    if ( defined($topic) ) {
        delete $this->{cache}{$web}{$topic};
    }
    elsif ( defined $web ) {
        foreach my $topic ( keys( %{ $this->{cache}{$web} } ) ) {
            delete $this->{cache}{$web}{$topic};
        }
        delete $this->{cache}{$web};
    }

    return;
}

=begin TML

---++ ObjectMethod addMeta($web, $topic, $meta) -> $meta

adds a Foswiki::Meta object to the cache. 

returns the cached object or undef if the meta is not cacheable, i.e. it is not a loaded version, or 
it failed to load at all

=cut

sub addMeta {
    my ( $this, $web, $topic, $meta ) = @_;

    $meta //= Foswiki::Meta->load( $this->{session}, $web, $topic );

    my $rev = $meta->getLoadedRev;
    return unless $rev && $rev > 0;

    $this->{cache}{$web} //= {};
    $this->{cache}{$web}{$topic} //= {};
    $this->{cache}{$web}{$topic}->{tom} = $meta;

    return $meta;
}

sub getMeta {
    my ( $this, $web, $topic ) = @_;

    return unless exists $this->{cache}{$web}{$topic};
    return $this->{cache}{$web}{$topic}->{tom};
}

=begin TML

---++ ObjectMethod get($web, $topic, $meta) -> a cache obj (sorry, needs to be refactored out to return a Foswiki::Meta obj only

get a requested meta object - web or topic typically, might work for attachments too

optionally the $meta parameter can be used to add that to the cache - useful if you've already loaded and parsed the topic.


TODO: the non-meta SEARCH render specific bits need to be moved elsewhere
and then, the MetaCache can only return Meta objects that actually exist

=cut

sub get {
    my ( $this, $web, $topic, $meta ) = @_;
    ASSERT( $meta->isa('Foswiki::Meta') ) if ( defined($meta) and DEBUG );

#sadly, Search.pm actually beleives that it can send out for info on Meta objects that do not exist
#ASSERT( defined($meta->getLoadedRev) ) if ( defined($meta) and DEBUG );

    if ( !defined($topic) ) {

#there are some instances - like the result set sorting, where we need to quickly pass "$web.$topic"
        ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( '', $web );
    }

    my $m = $this->addMeta( $web, $topic, $meta );
    $meta = $m if ( defined($m) );
    ASSERT( defined($meta) ) if DEBUG;

    my $info = $this->{cache}{$web}{$topic} // { tom => $meta };

    if ( not defined( $info->{editby} ) ) {

        #TODO: extract this to the Meta Class, or remove entirely
        # Extract sort fields
        my $ri = $info->{tom}->getRevisionInfo();

        # Rename fields to match sorting criteria
        $info->{editby}   = $ri->{author} || '';
        $info->{modified} = $ri->{date};
        $info->{revNum}   = $ri->{version};
    }

    return $info;
}

1;
__END__
Author: Sven Dowideit

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
