# See bottom of file for license and copyright information
package Foswiki::Search::InfoCache;
use strict;

use Foswiki::ListIterator ();
our @ISA = ('Foswiki::ListIterator');

=begin TML

---+ package Foswiki::Search::InfoCache

Support package; cache of topic info. When information about search hits is
compiled for output, this cache is used to avoid recovering the same info
about the same topic more than once.

TODO: this is going to transform from an ugly duckling into the ResultSet Iterator

I have the feeling that we should make result sets immutable

=cut

use Assert;
use Foswiki::Meta ();

=pod
---++ Foswiki::Search::InfoCache::new($session, $defaultWeb, \@topicList)
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
    my ( $class, $session, $defaultWeb, $topicList ) = @_;
    my $this = $class->SUPER::new($topicList);
    $this->{_session}    = $session;
    $this->{_defaultWeb} = $defaultWeb;

    return $this;
}

sub isImmutable {
    my $this = shift;
    return ( $this->{index} != 0 );
}

sub addTopics {
    my ( $this, $defaultWeb, @list ) = @_;
    ASSERT( !$this->isImmutable() )
      ;    #cannot modify list once its being used as an iterator.

    if ( defined($defaultWeb) && ( $defaultWeb ne $this->{_defaultWeb} ) ) {
        foreach my $t (@list) {
            my ( $web, $topic ) =
              Foswiki::Func::normalizeTopic( $defaultWeb, $t );
            push( @{ $this->{list} }, "$web.$topic" );
        }
    }
    else {

        #TODO: what if the list is an arrayref?
        push( @{ $this->{list} }, @list );
    }
}

=begin TML
---++ sortResults

the implementation of %SORT{"" limit="" order="" reverse="" date=""}%

it should be possible for the search engine to pre-sort, making this a nop, or to
delay evaluated, partially evaluated, or even delegated to the DB/SQL 

=cut

sub sortResults {
    my ( $infoCache, $web, %params ) = @_;
    my $session = $infoCache->{_session};

    my $sortOrder = $params{order} || '';
    my $revSort   = Foswiki::isTrue( $params{reverse} );
    my $date      = $params{date} || '';
    my $limit     = $params{limit} || '';

    #SMELL: duplicated code - removeme
    # Limit search results
    if ( $limit =~ /(^\d+$)/o ) {

        # only digits, all else is the same as
        # an empty string.  "+10" won't work.
        $limit = $1;
    }
    else {

        # change 'all' to 0, then to big number
        $limit = 0;
    }
    $limit = 32000 unless ($limit);

    # sort the topic list by date, author or topic name, and cache the
    # info extracted to do the sorting
    if ( $sortOrder eq 'modified' ) {

        # For performance:
        #   * sort by approx time (to get a rough list)
        #   * shorten list to the limit + some slack
        #   * sort by rev date on shortened list to get the accurate list
        # SMELL: Cairo had efficient two stage handling of modified sort.
        # SMELL: In Dakar this seems to be pointless since latest rev
        # time is taken from topic instead of dir list.
        my $slack = 10;
        if ( $limit + 2 * $slack < scalar( @{ $infoCache->{list} } ) ) {

            # sort by approx latest rev time
            my @tmpList =
              map  { $_->[1] }
              sort { $a->[0] <=> $b->[0] }
              map  { [ $session->getApproxRevTime( $web, $_ ), $_ ] }
              @{ $infoCache->{list} };
            @tmpList = reverse(@tmpList) if ($revSort);

            # then shorten list and build the hashes for date and author
            my $idx = $limit + $slack;
            @{ $infoCache->{list} } = ();
            foreach (@tmpList) {
                push( @{ $infoCache->{list} }, $_ );
                $idx -= 1;
                last if $idx <= 0;
            }
        }

        $infoCache->sortTopics( $sortOrder, !$revSort );
    }
    elsif (
        $sortOrder =~ /^creat/ ||    # topic creation time
        $sortOrder eq 'editby' ||    # author
        $sortOrder =~ s/^formfield\((.*)\)$/$1/    # form field
      )
    {
        $infoCache->sortTopics( $sortOrder, !$revSort );
    }
    else {

        # simple sort, see Codev.SchwartzianTransformMisused
        # note no extraction of topic info here, as not needed
        # for the sort. Instead it will be read lazily, later on.
        if ($revSort) {
            @{ $infoCache->{list} } =
              sort { $b cmp $a } @{ $infoCache->{list} };
        }
        else {
            @{ $infoCache->{list} } =
              sort { $a cmp $b } @{ $infoCache->{list} };
        }
    }

    if ($date) {
        require Foswiki::Time;
        my @ends       = Foswiki::Time::parseInterval($date);
        my @resultList = ();
        foreach my $topic ( @{ $infoCache->{list} } ) {

            # if date falls out of interval: exclude topic from result
            my $topicdate = $session->getApproxRevTime( $web, $topic );
            push( @resultList, $topic )
              unless ( $topicdate < $ends[0] || $topicdate > $ends[1] );
        }
        @{ $infoCache->{list} } = @resultList;
    }
}


######OLD methods
sub get {
    my ( $this, $topic ) = @_;

    my $info = $this->{$topic};

    unless ($info) {
        $this->{$topic} = $info = {};

        $info->{tom} =
          Foswiki::Meta->load( $this->{_session}, $this->{_defaultWeb},
            $topic );

        # SMELL: why do this here? Smells of a hack, as AFAICT it is done
        # anyway during output processing. Disable it, and see what happens....
        #my $text = $topicObject->text();
        #$text =~ s/%WEB%/$web/gs;
        #$text =~ s/%TOPIC%/$topic/gs;
        #$topicObject->text($text);

        # Extract sort fields
        my $ri = $info->{tom}->getRevisionInfo();

        # Rename fields to match sorting criteria
        $info->{editby}   = $ri->{author} || '';
        $info->{modified} = $ri->{date};
        $info->{revNum}   = $ri->{version};

        $info->{allowView} = $info->{tom}->haveAccess('VIEW');
    }

    return $info;
}

# Determins, and caches, the topic revision info of the base version,
sub getRev1Info {
    my ( $this, $topic, $attr ) = @_;

    my $info = $this->get($topic);
    unless ( defined $info->{$attr} ) {
        my $ri = $info->{rev1info};
        unless ($ri) {
            my $tmp =
              Foswiki::Meta->load( $this->{_session}, $this->{_defaultWeb},
                $topic, 1 );
            $info->{rev1info} = $ri = $tmp->getRevisionInfo();
        }

        if ( $attr eq 'createusername' ) {
            $info->{createusername} =
              $this->{_session}->{users}->getLoginName( $ri->{author} );
        }
        elsif ( $attr eq 'createwikiname' ) {
            $info->{createwikiname} =
              $this->{_session}->{users}->getWikiName( $ri->{author} );
        }
        elsif ( $attr eq 'createwikiusername' ) {
            $info->{createwikiusername} =
              $this->{_session}->{users}->webDotWikiName( $ri->{author} );
        }
        elsif ( $attr =~ /^created/ ) {
            $info->{created} = $ri->{date};
            require Foswiki::Time;
            $info->{createdate} = Foswiki::Time::formatTime( $ri->{date} );
        }
    }
    return $info->{$attr};
}

# Sort a topic list using cached info
sub sortTopics {
    my ( $this, $sortfield, $revSort ) = @_;
    ASSERT($sortfield);

    ASSERT( !$this->isImmutable() )
      ;    #cannot modify list once its being used as an iterator.

    # populate the cache for each topic
    foreach my $topic ( @{ $this->{list} } ) {
        if ( $sortfield =~ /^creat/ ) {

            # The act of getting the info will cache it
            $this->getRev1Info( $topic, $sortfield );
        }
        else {
            my $info = $this->get($topic);
            if ( !defined( $info->{$sortfield} ) ) {
                $info->{$sortfield} =
                  Foswiki::Search::displayFormField( $info->{tom}, $sortfield );
            }
        }

        # SMELL: CDot isn't clear why this is needed, but it is otherwise
        # we end up with the users all being identified as "undef"
        my $info = $this->get($topic);
        $info->{editby} =
          $info->{tom}->session->{users}->getWikiName( $info->{editby} );
    }
    if ($revSort) {
        @{ $this->{list} } = map { $_->[1] }
          sort { _compare( $b->[0], $a->[0] ) }
          map { [ $this->{$_}->{$sortfield}, $_ ] } @{ $this->{list} };
    }
    else {
        @{ $this->{list} } = map { $_->[1] }
          sort { _compare( $a->[0], $b->[0] ) }
          map { [ $this->{$_}->{$sortfield}, $_ ] } @{ $this->{list} };
    }
}

# RE for a full-spec floating-point number
our ($NUMBER);
$NUMBER = qr/^[-+]?[0-9]+(\.[0-9]*)?([Ee][-+]?[0-9]+)?$/s;

sub _compare {
    my $x = shift;
    my $y = shift;
    if ( $x =~ /$NUMBER/o && $y =~ /$NUMBER/o ) {

        # when sorting numbers do it largest first; this is just because
        # this is what date comparisons need.
        return $y <=> $x;
    }
    else {
        return $y cmp $x;
    }
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
