# See bottom of file for license and copyright information
package Foswiki::MetaCache;
use strict;

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
use Foswiki::Func ();
use Foswiki::Meta ();

#use Monitor ();
#Monitor::MonitorMethod('Foswiki::MetaCache', 'getTopicListIterator');

sub TRACE {0;}


=pod
---++ Foswiki::MetaCache::new($session)


=cut

sub new {
    my ( $class, $session) = @_;
    
    #my $this = $class->SUPER::new([]);
    my $this = bless({
                session => $session, 
                cache => {},
                new_count=>0,
                get_count=>0,
                undef_count=>0,
            }, $class);

    return $this;
}

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
    
    foreach my $webtopic (keys(%{$this->{cache}})) {
        undef $this->{cache}->{$webtopic};
        $this->{undef_count}++;
    }
    undef $this->{cache};
    
    if (TRACE) {
        print STDERR "MetaCache: new: $this->{new_count} get: $this->{get_count} undef: $this->{undef_count} \n";
    }
    
}


=begin TML

---++ ObjectMethod hasCached($webtopic) -> boolean

returns true if the topic is already int he cache.

=cut

sub hasCached {
    my ( $this, $webtopic ) = @_;
    
    return (defined($this->{cache}->{$webtopic}));
}


=begin TML

---++ ObjectMethod get($webtopic, $meta) -> a cache obj (sorry, needs to be refactored out to return a Foswiki::Meta obj only

get a requested meta object - web or topic typically, might work for attachments too

optionally the $meta parameter can be used to add that to the cache - useful if you've already loaded and parsed the topic.

=cut

sub get {
    my ( $this, $webtopic, $meta ) = @_;
    ASSERT( $meta->isa('Foswiki::Meta') ) if (defined($meta) and DEBUG);

    $this->{get_count}++;
    
    unless ($this->{cache}->{$webtopic}) {
        $this->{cache}->{$webtopic} = {};
        if (defined($meta)) {
            $this->{cache}->{$webtopic}->{tom} = $meta;
        } else {
            my ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( undef, $webtopic );
            $this->{cache}->{$webtopic}->{tom} = 
                Foswiki::Meta->load( $this->{session}, $web, $topic );
        }
        return if (!defined($this->{cache}->{$webtopic}->{tom}) or $this->{cache}->{$webtopic}->{tom} eq '');

        $this->{new_count}++;

#TODO: extract this to the Meta Class, or remove entirely
        # Extract sort fields
        my $ri = $this->{cache}->{$webtopic}->{tom}->getRevisionInfo();

        # Rename fields to match sorting criteria
        $this->{cache}->{$webtopic}->{editby}   = $ri->{author} || '';
        $this->{cache}->{$webtopic}->{modified} = $ri->{date};
        $this->{cache}->{$webtopic}->{revNum}   = $ri->{version};

        $this->{cache}->{$webtopic}->{allowView} = $this->{cache}->{$webtopic}->{tom}->haveAccess('VIEW');
    }

    ASSERT( $this->{cache}->{$webtopic}->{tom}->isa('Foswiki::Meta') ) if DEBUG;

    return $this->{cache}->{$webtopic};
}

1;
__END__

Copyright (C) 2008-2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.


This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

author: Sven Dowideit