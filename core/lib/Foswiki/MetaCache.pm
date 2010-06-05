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
use Foswiki::Func ();
use Foswiki::Meta ();

#use Monitor ();
#Monitor::MonitorMethod('Foswiki::MetaCache', 'getTopicListIterator');

use constant TRACE => 0;

=begin TML

---++ ClassMethod new($session)

=cut

sub new {
    my ( $class, $session ) = @_;

    #my $this = $class->SUPER::new([]);
    my $this = bless(
        {
            session     => $session,
            cache       => {},
            new_count   => 0,
            get_count   => 0,
            undef_count => 0,
        },
        $class
    );

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

    foreach my $web ( keys( %{ $this->{cache} } ) ) {
        foreach my $topic ( keys( %{ $this->{cache}->{$web} } ) ) {
            undef $this->{cache}->{$web}{$topic};
            $this->{undef_count}++;
        }
        undef $this->{cache}->{$web};
    }
    undef $this->{cache};

    if (TRACE) {
        print STDERR
"MetaCache: new: $this->{new_count} get: $this->{get_count} undef: $this->{undef_count} \n";
    }

}

=begin TML

---++ ObjectMethod hasCached($webtopic) -> boolean

returns true if the topic is already int he cache.

=cut

sub hasCached {
    my ( $this, $web, $topic ) = @_;
    ASSERT( defined($topic) ) if DEBUG;

    return ( defined( $this->{cache}->{$web}{$topic} ) );
}

=begin TML

---++ ObjectMethod get($webtopic, $meta) -> a cache obj (sorry, needs to be refactored out to return a Foswiki::Meta obj only

get a requested meta object - web or topic typically, might work for attachments too

optionally the $meta parameter can be used to add that to the cache - useful if you've already loaded and parsed the topic.

=cut

sub get {
    my ( $this, $web, $topic, $meta ) = @_;
    ASSERT( $meta->isa('Foswiki::Meta') ) if ( defined($meta) and DEBUG );

    if ( !defined($topic) ) {

#there are some instances - like the result set sorting, where we need to quickly pass "$web.$topic"
        ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( '', $web );
    }

    $this->{get_count}++;

    unless ( $this->{cache}->{$web} ) {
        $this->{cache}->{$web} = {};
    }
    unless ( $this->{cache}->{$web}{$topic} ) {
        $this->{cache}->{$web}{$topic} = {};
        if ( defined($meta) ) {
            $this->{cache}->{$web}{$topic}->{tom} = $meta;
        }
        else {
            $this->{cache}->{$web}{$topic}->{tom} =
              Foswiki::Meta->load( $this->{session}, $web, $topic );
        }
        return
          if ( !defined( $this->{cache}->{$web}{$topic}->{tom} )
            or $this->{cache}->{$web}{$topic}->{tom} eq '' );

        $this->{new_count}++;

        #TODO: extract this to the Meta Class, or remove entirely
        # Extract sort fields
        my $ri = $this->{cache}->{$web}{$topic}->{tom}->getRevisionInfo();

        # Rename fields to match sorting criteria
        $this->{cache}->{$web}{$topic}->{editby}   = $ri->{author} || '';
        $this->{cache}->{$web}{$topic}->{modified} = $ri->{date};
        $this->{cache}->{$web}{$topic}->{revNum}   = $ri->{version};

        $this->{cache}->{$web}{$topic}->{allowView} =
          $this->{cache}->{$web}{$topic}->{tom}->haveAccess('VIEW');
    }

    ASSERT( $this->{cache}->{$web}{$topic}->{tom}->isa('Foswiki::Meta') )
      if DEBUG;

    return $this->{cache}->{$web}{$topic};
}

1;
__END__
Author: Sven Dowideit

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
