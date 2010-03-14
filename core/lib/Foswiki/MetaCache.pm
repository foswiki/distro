# See bottom of file for license and copyright information
package Foswiki::MetaCache;
use strict;

use Foswiki::ListIterator ();
our @ISA = ('Foswiki::ListIterator');

=begin TML

---+ package Foswiki::MetaCache

Support package; cache of topic info. When information about search hits is
compiled for output, this cache is used to avoid recovering the same info
about the same topic more than once.

TODO: this is going to transform from an ugly duckling into the ResultSet Iterator

I have the feeling that we should make result sets immutable

=cut

use Assert;
use Foswiki::Func ();
use Foswiki::Meta ();
use Foswiki::Iterator::FilterIterator ();

#use Monitor ();
#Monitor::MonitorMethod('Foswiki::MetaCache', 'getTopicListIterator');

=pod
---++ Foswiki::MetaCache::new($session)
initialise a new list of topics, allowing their data to be lazy loaded if and when needed.

$defaultWeb is used to qualify topics that do not have a web specifier - should expect it to be the same as BASEWEB in most cases.

because this 'Iterator can be created and filled dynamically, once the Iterator hasNext() and next() methods are called, it is immutable.

TODO: duplicates??, what about topicExists?
TODO: remove the iterator code from this __container__ and make a $this->getIterator() which can then be used.
TODO: replace the Iterator->reset() function with a lightweight Iterator->copyConstructor?
TODO: or..... make reset() make the object muttable again, so we can change the elements in the list, but re-use the meta cache??
CONSIDER: convert the internals to a hash[tomAddress] = {matches->[list of resultint text bits], othermeta...} - except this does not give us order :/

=cut

sub new {
    my ( $class, $session) = @_;
    
    my $this = $class->SUPER::new([]);
    $this->{_session}    = $session;

    return $this;
}

sub get {
    my ( $this, $webtopic, $meta ) = @_;
    
    my ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $this->{_defaultWeb}, $webtopic );

    unless ($this->{$webtopic}) {
        $this->{$webtopic} = {};
        $this->{$webtopic}->{tom} = $meta || 
          Foswiki::Meta->load( $this->{_session}, $web, $topic );
        # SMELL: why do this here? Smells of a hack, as AFAICT it is done
        # anyway during output processing. Disable it, and see what happens....
        #my $text = $topicObject->text();
        #$text =~ s/%WEB%/$web/gs;
        #$text =~ s/%TOPIC%/$topic/gs;
        #$topicObject->text($text);

        # Extract sort fields
        my $ri = $this->{$webtopic}->{tom}->getRevisionInfo();

        # Rename fields to match sorting criteria
        $this->{$webtopic}->{editby}   = $ri->{author} || '';
        $this->{$webtopic}->{modified} = $ri->{date};
        $this->{$webtopic}->{revNum}   = $ri->{version};

        $this->{$webtopic}->{allowView} = $this->{$webtopic}->{tom}->haveAccess('VIEW');
    }

    return $this->{$webtopic};
}

1;
__END__

Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some of the code in this file, as follows

Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
Copyright (C) 2000-2008 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
