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

use constant TRACE => 0;

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
            session                 => $session,
            cache                   => {},
            new_count               => 0,
            get_count               => 0,
            undef_count             => 0,
            meta_cache_session_user => $session->{user},
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
    undef $this->{session};

    #must clear cache every request until the cache is hooked up to Store's save
    foreach my $cuid ( keys( %{ $this->{cache} } ) ) {
        foreach my $web ( keys( %{ $this->{cache}->{$cuid} } ) ) {
            foreach my $topic ( keys( %{ $this->{cache}->{$cuid}->{$web} } ) ) {
                undef $this->{cache}->{$cuid}{$web}{$topic};
                $this->{undef_count}++;
            }
            undef $this->{cache}->{$cuid}{$web};
        }
        undef $this->{cache}->{$cuid};
    }
    undef $this->{cache};

    if (TRACE) {
        print STDERR
"MetaCache: new: $this->{new_count} get: $this->{get_count} undef: $this->{undef_count} \n";
    }

    return;
}

=begin TML

---++ ObjectMethod hasCached($webtopic) -> boolean

returns true if the topic is already int he cache.

=cut

sub hasCached {
    my ( $this, $web, $topic ) = @_;
    ASSERT( defined($topic) ) if DEBUG;
    return unless ( defined($topic) );

    return ( $this->{session}->{user}
          and
          defined( $this->{cache}->{ $this->current_user() }{$web}{$topic} ) );
}

sub removeMeta {
    my ( $this, $web, $topic ) = @_;
    my $user = $this->current_user();

    if ( defined($topic) ) {
        my $cached_userwebtopic = $this->{cache}->{$user}{$web}{$topic};

        if ($cached_userwebtopic) {
            $cached_userwebtopic->finish() if blessed($cached_userwebtopic);
            delete $this->{cache}->{$user}{$web}{$topic};
        }
    }
    elsif ( defined $web ) {
        foreach my $topic ( keys( %{ $this->{cache}->{$user}{$web} } ) ) {
            $this->removeMeta( $web, $topic );
        }
        delete $this->{cache}->{$user}{$web};
    }

    return;
}

#returns undef if the meta is not the latestRev, or if it failed to load
#else returns the $meta
sub addMeta {
    my ( $this, $web, $topic, $meta ) = @_;

    my $user = $this->current_user();

    # If the cache is already populated, return it, don't add it again
    if ( $this->hasCached( $web, $topic ) ) {
        print STDERR "Cache hit for $web.$topic for $user\n" if (TRACE);
        return $this->{cache}->{$user}{$web}{$topic}->{tom};
    }

    if ( not defined($meta) ) {
        $meta = Foswiki::Meta->load( $this->{session}, $web, $topic );
    }
    if (    ( defined($meta) and $meta ne '' )
        and defined( $meta->latestIsLoaded )
        and defined( $meta->getLoadedRev )
        and ( $meta->getLoadedRev > 0 ) )
    {
        ASSERT( $meta->latestIsLoaded ) if DEBUG;
        ASSERT( defined( $meta->getLoadedRev ) and ( $meta->getLoadedRev > 0 ) )
          if DEBUG;
    }
    else {
        return;
    }

    unless ( $this->{cache}->{$user}{$web} ) {
        $this->{cache}->{$user}{$web} = {};
    }
    unless ( $this->{cache}->{$user}{$web}{$topic} ) {
        $this->{cache}->{$user}{$web}{$topic} = {};
    }
    unless ( defined( $this->{cache}->{$user}{$web}{$topic}->{tom} ) ) {
        $this->{cache}->{$user}{$web}{$topic}->{tom} = $meta;
        $this->{new_count}++;
    }
    return $meta;
}

sub getMeta {
    my ( $this, $web, $topic, $meta ) = @_;
    my $user = $this->current_user();

    return unless ( defined( $this->{cache}->{$user}{$web} ) );
    return unless ( defined( $this->{cache}->{$user}{$web}{$topic} ) );
    return $this->{cache}->{$user}{$web}{$topic}->{tom};
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

    $this->{get_count}++;

    my $info = { tom => $meta };
    my $user = $this->current_user();

    ASSERT( defined $user ) if DEBUG;
    $info = $this->{cache}->{$user}{$web}{$topic}
      if defined( $this->{cache}->{$user}{$web}{$topic} );
    if ( not defined( $info->{editby} ) ) {

        #TODO: extract this to the Meta Class, or remove entirely
        # Extract sort fields
        my $ri = $info->{tom}->getRevisionInfo();

        # Rename fields to match sorting criteria
        $info->{editby}   = $ri->{author} || '';
        $info->{modified} = $ri->{date};
        $info->{revNum}   = $ri->{version};

#TODO: this is _not_ actually sufficient.. as there are other things that appear to be evaluated in turn
#Ideally, the Store2::Meta object will _not_ contain any session info, and anything that is session / user oriented gets stored in another object that links to the 'database' object.
#it'll probably be better to make the MetaCache know what
#Item10097: make the cache multi-user safe by storing the haveAccess on a per user basis
        if ( not defined( $info->{ $this->{session}->{user} } ) ) {
            $info->{ $this->{session}->{user} } = ();
        }
        if ( not defined( $info->{ $this->{session}->{user} }{allowView} ) ) {
            $info->{ $this->{session}->{user} }{allowView} =
              $info->{tom}->haveAccess('VIEW');
        }

        #use the cached permission
        $info->{allowView} = $info->{ $this->{session}->{user} }{allowView};
    }

    return $info;
}

sub current_user {
    my $self = shift;

    ASSERT( defined $self->{session} ) if DEBUG;
    my $user = $self->{session}->{user};
    if ( not defined $user ) {
        $user = $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;
    }

    return $user;
}

##########################################
# this used to try to use the never-released listener API to flush the cache on changes.
# Sven is not entirely sure it really worked, but the replacement for the listeners makes more
# sense - it would move the MetaCache into the Store itself, allowing us to cache loaded topics
# before ACL's are evaluated. however, I suspect this will require adding the readonly hash support
# to Meta, which requires the Data::Foswiki work (post 2.0)

sub DISABLED_insert {
    my ( $self, %args ) = @_;

    $self->removeMeta( $args{newmeta}->web, $args{newmeta}->topic );

    return;
}

sub DISABLED_update {
    my ( $self, %args ) = @_;

    $self->removeMeta( $args{oldmeta}->web, $args{oldmeta}->topic )
      if ( defined( $args{oldmeta} ) );
    $self->removeMeta( $args{newmeta}->web, $args{newmeta}->topic );

    return;
}

sub DISABLED_remove {
    my ( $self, %args ) = @_;

    ASSERT( $args{oldmeta} ) if DEBUG;

    $self->removeMeta( $args{oldmeta}->web, $args{oldmeta}->topic )
      if ( defined( $args{oldmeta} ) );

    return;
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
