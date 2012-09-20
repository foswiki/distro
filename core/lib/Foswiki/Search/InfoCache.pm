# See bottom of file for license and copyright information
package Foswiki::Search::InfoCache;
use strict;
use warnings;

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
use Foswiki::Func                     ();
use Foswiki::Meta                     ();
use Foswiki::Iterator::FilterIterator ();

#use Monitor ();
#Monitor::MonitorMethod('Foswiki::Search::InfoCache', 'getTopicListIterator');

=begin TML

---++ ClassMethod new($session, $defaultWeb, \@topicList)
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

    my $this = $class->SUPER::new( [] );
    $this->{_session}    = $session;
    $this->{_defaultWeb} = $defaultWeb;
    $this->{count}       = 0;
    if ( defined($topicList) ) {
        $this->addTopics( $defaultWeb, @$topicList );
    }

    return $this;
}

sub isImmutable {
    my $this = shift;

    return ( $this->{index} != 0 );
}

sub addTopics {
    my ( $this, $defaultWeb, @list ) = @_;

    ASSERT( !$this->isImmutable() )
      if DEBUG;    #cannot modify list once its being used as an iterator.
    ASSERT( defined($defaultWeb) ) if DEBUG;

    foreach my $t (@list) {
        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $defaultWeb, $t );
        push( @{ $this->{list} }, "$web.$topic" );
        $this->{count}++;
    }
    undef $this->{sorted};
}

#TODO: what if it isa Meta obj
#TODO: or an infoCache obj..
sub addTopic {
    my ( $this, $meta ) = @_;

    ASSERT( !$this->isImmutable() )
      if DEBUG;    #cannot modify list once its being used as an iterator.

    my $web   = $meta->web();
    my $topic = $meta->topic();

    my ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );
    my $webtopic = "$w.$t";
    push( @{ $this->{list} }, $webtopic );
    $this->{count}++;
    if ( defined($meta) ) {
        $this->{_session}->search->metacache->get( $web, $topic, $meta );
    }
    undef $this->{sorted};
}

sub numberOfTopics {
    my $this = shift;

    # can't use this, as it lies once its gone through the 'sortResults' hack
    #return scalar(@{ $this->{list} });
    # when fixed, the count update in filterByDate should be removed

    return $this->{count};
}

=begin TML

---++ ObjectMethod sortResults($params)

the implementation of %SORT{"" limit="" order="" reverse="" date=""}%

it should be possible for the search engine to pre-sort, making this a nop, or to
delay evaluated, partially evaluated, or even delegated to the DB/SQL 

can call repeatedly, the list will only be re-sorted if new elements are added.

=cut

sub sortResults {
    my ( $this, $params ) = @_;

    #TODO: for now assume we do not change the sort order later
    return if ( defined( $this->{sorted} ) );
    $this->{sorted} = 1;

    my $session = $this->{_session};

    my $sortOrder = $params->{order} || '';
    my $revSort   = Foswiki::isTrue( $params->{reverse} );
    my $limit     = $params->{limit} || '';

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

#TODO: this is really an ugly hack to get around the rather horrible limit 'performance' hack
    if ( defined( $params->{pager_show_results_to} )
        and $params->{pager_show_results_to} > 0 )
    {
        $limit =
          $params->{pager_skip_results_from} + $params->{pager_show_results_to};
    }

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
        if ( $limit + 2 * $slack < scalar( @{ $this->{list} } ) ) {

            # sort by approx latest rev time
            my @tmpList =
              map  { $_->[1] }
              sort { $a->[0] <=> $b->[0] }
              map {
                my ( $web, $topic ) =
                  Foswiki::Func::normalizeWebTopicName( $this->{_defaultWeb},
                    $_ );
                [ $session->getApproxRevTime( $web, $topic ), $_ ]
              } @{ $this->{list} };
            @tmpList = reverse(@tmpList) if ($revSort);

            # then shorten list and build the hashes for date and author
            my $idx = $limit + $slack;
            @{ $this->{list} } = ();
            foreach (@tmpList) {
                push( @{ $this->{list} }, $_ );
                $idx -= 1;
                last if $idx <= 0;
            }
        }

    }
    elsif (
        $sortOrder =~ /^creat/ ||    # topic creation time
        $sortOrder eq 'editby' ||    # author
        $sortOrder =~ s/^formfield\(([^\)]+)\)$/$1/    # form field
      )
    {
    }
    else {

        #default to topic sorting
        $sortOrder = 'topic';
    }
    sortTopics( $this->{list}, $sortOrder, !$revSort );
}

=begin TML

---++ filterByDate( $date )

Filter the list by date interval; see System.TimeSpecifications.

<verbatim>
$infoCache->filterByDate( $date );
</verbatim>

=cut

sub filterByDate {
    my ( $this, $date ) = @_;

    my $session = $Foswiki::Plugins::SESSION;

    require Foswiki::Time;
    my @ends       = Foswiki::Time::parseInterval($date);
    my @resultList = ();
    foreach my $webtopic ( @{ $this->{list} } ) {

        # if date falls out of interval: exclude topic from result
        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $this->{_defaultWeb},
            $webtopic );
        my $topicdate = $session->getApproxRevTime( $web, $topic );
        push( @resultList, $webtopic )
          unless ( $topicdate < $ends[0] || $topicdate > $ends[1] );
    }
    $this->{list} = \@resultList;

    # use this hack until numberOfTopics reads the length of list
    $this->{count} = scalar @{ $this->{list} };
}

######OLD methods

# Determins, and caches, the topic revision info of the base version,
sub getRev1Info {
    my ( $webtopic, $attr ) = @_;

    my $session   = $Foswiki::Plugins::SESSION;
    my $metacache = $session->search->metacache;

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( $Foswiki::cfg{UsersWebName},
        $webtopic );

    my $info = $metacache->get( $web, $topic );
    unless ( defined $info->{$attr} ) {
        my $ri = $info->{rev1info};
        unless ($ri) {
            my $tmp = Foswiki::Meta->load( $session, $web, $topic, 1 );
            $info->{rev1info} = $ri = $tmp->getRevisionInfo();
        }

        if ( $attr eq 'createusername' ) {
            $info->{createusername} =
              $session->{users}->getLoginName( $ri->{author} );
        }
        elsif ( $attr eq 'createwikiname' ) {
            $info->{createwikiname} =
              $session->{users}->getWikiName( $ri->{author} );
        }
        elsif ( $attr eq 'createwikiusername' ) {
            $info->{createwikiusername} =
              $session->{users}->webDotWikiName( $ri->{author} );
        }
        elsif ($attr eq 'createdate'
            or $attr eq 'createlongdate'
            or $attr eq 'created' )
        {
            $info->{created} = $ri->{date};
            require Foswiki::Time;
            $info->{createdate} = Foswiki::Time::formatTime( $ri->{date} );

            #TODO: wow thats disgusting.
            $info->{created} = $info->{createlongdate} = $info->{createdate};
        }
    }
    return $info->{$attr};
}

# Sort a topic list using cached info
sub sortTopics {
    my ( $listRef, $sortfield, $revSort ) = @_;
    ASSERT($sortfield);

   #seriously, don't spend time doing stuff to an empty list (or a list of one!)
    return if ( scalar(@$listRef) <= 0 );

    if ( $sortfield eq 'topic' ) {

# simple sort, see Codev.SchwartzianTransformMisused
# note no extraction of topic info here, as not needed
# for the sort. Instead it will be read lazily, later on.
#TODO: need to remove the web portion
#mmm, need to profile if there is even a point to this - as all topics still need to be parsed to find permissions
        if ($revSort) {
            @{$listRef} = map { $_->[1] }
              sort { $a->[0] cmp $b->[0] }
              map { $_ =~ /^(.*?)([^.]+)$/; [ $2, $_ ] } #quickhack to remove web
              @{$listRef};
        }
        else {
            @{$listRef} = map { $_->[1] }
              sort { $b->[0] cmp $a->[0] }
              map { $_ =~ /^(.*?)([^.]+)$/; [ $2, $_ ] } #quickhack to remove web
              @{$listRef};
        }
        ASSERT( $listRef->[0] ) if DEBUG;
        return;
    }

    my $metacache = $Foswiki::Plugins::SESSION->search->metacache;

    # populate the cache for each topic
    foreach my $webtopic ( @{$listRef} ) {
        if ( $sortfield =~ /^creat/ ) {

            # The act of getting the info will cache it
            getRev1Info( $webtopic, $sortfield );
        }
        else {

 #duplicated from above - I'd rather do it only here, but i'm not sure if i can.
            $sortfield =~ s/^formfield\((.*)\)$/$1/;    # form field

            my $info = $metacache->get($webtopic);
            if ( !defined( $info->{$sortfield} ) ) {

#under normal circumstances this code is not called, because the metacach has already filled it.
                if ( $sortfield eq 'modified' ) {
                    my $ri = $info->{tom}->getRevisionInfo();
                    $info->{$sortfield} = $ri->{date};
                }
                else {
                    $info->{$sortfield} =
                      Foswiki::Search::displayFormField( $info->{tom},
                        $sortfield );
                }
            }
        }

        # SMELL: CDot isn't clear why this is needed, but it is otherwise
        # we end up with the users all being identified as "undef"
        my $info = $metacache->get($webtopic);
        $info->{editby} =
          $info->{tom}->session->{users}->getWikiName( $info->{editby} );
    }
    if ($revSort) {
        @{$listRef} = map { $_->[1] }
          sort { _compare( $b->[0], $a->[0] ) }
          map { [ $metacache->get($_)->{$sortfield}, $_ ] } @{$listRef};
    }
    else {
        @{$listRef} = map { $_->[1] }
          sort { _compare( $a->[0], $b->[0] ) }
          map { [ $metacache->get($_)->{$sortfield}, $_ ] } @{$listRef};
    }
}

# RE for a full-spec floating-point number
our ($NUMBER);
$NUMBER = qr/^[-+]?[0-9]+(\.[0-9]*)?([Ee][-+]?[0-9]+)?$/s;

sub _compare {
    my $x = shift;
    my $y = shift;

    ASSERT( defined($x) ) if DEBUG;
    ASSERT( defined($y) ) if DEBUG;

    if ( $x =~ /$NUMBER/o && $y =~ /$NUMBER/o ) {

        # when sorting numbers do it largest first; this is just because
        # this is what date comparisons need.
        return $y <=> $x;
    }

    my $datex = undef;
    my $datey = undef;

    # parseTime can error if you give it a date out of range so we skip
    # testing if pure number
    # We skip testing for dates the first character is not a digit
    # as all formats we recognise as dates are
    if (   $x =~ /^\d/
        && $x !~ /$NUMBER/o
        && $y =~ /^\d/
        && $y !~ /$NUMBER/o )
    {
        $datex = Foswiki::Time::parseTime($x);
        $datey = Foswiki::Time::parseTime($y) if $datex;
    }

    if ( $datex && $datey ) {
        return $datey <=> $datex;
    }
    else {
        return $y cmp $x;
    }
}

#convert a comma separated list of webs into the list we'll process
#TODO: this is part of the Store now, and so should not need to reference Meta - it rather uses the store..
sub _getListOfWebs {
    my ( $webName, $recurse, $searchAllFlag ) = @_;
    my $session = $Foswiki::Plugins::SESSION;

    my %excludeWeb;
    my @tmpWebs;

  #$web = Foswiki::Sandbox::untaint( $web,\&Foswiki::Sandbox::validateWebName );

    if ($webName) {
        foreach my $web ( split( /[\,\s]+/, $webName ) ) {
            $web =~ s#\.#/#go;

            # the web processing loop filters for valid web names,
            # so don't do it here.
            if ( $web =~ s/^-// ) {
                $excludeWeb{$web} = 1;
            }
            else {
                if (   $web =~ /^(all|on)$/i
                    || $Foswiki::cfg{EnableHierarchicalWebs}
                    && Foswiki::isTrue($recurse) )
                {
                    require Foswiki::WebFilter;
                    my $webObject;
                    my $prefix = "$web/";
                    if ( $web =~ /^(all|on)$/i ) {
                        $webObject = Foswiki::Meta->new($session);
                        $prefix    = '';
                    }
                    else {
                        $web = Foswiki::Sandbox::untaint( $web,
                            \&Foswiki::Sandbox::validateWebName );
                        ASSERT($web);
                        push( @tmpWebs, $web );
                        $webObject = Foswiki::Meta->new( $session, $web );
                    }
                    my $it = $webObject->eachWeb(1);
                    while ( $it->hasNext() ) {
                        my $w = $prefix . $it->next();
                        next
                          unless $Foswiki::WebFilter::user_allowed->ok(
                            $session, $w );
                        $w = Foswiki::Sandbox::untaint( $w,
                            \&Foswiki::Sandbox::validateWebName );
                        ASSERT($web);
                        push( @tmpWebs, $w );
                    }
                }
                else {
                    $web = Foswiki::Sandbox::untaint( $web,
                        \&Foswiki::Sandbox::validateWebName );
                    push( @tmpWebs, $web );
                }
            }
        }

    }
    else {

        # default to current web
        my $web =
          Foswiki::Sandbox::untaint( $session->{webName},
            \&Foswiki::Sandbox::validateWebName );
        push( @tmpWebs, $web );
        if ( Foswiki::isTrue($recurse) ) {
            my $webObject = Foswiki::Meta->new( $session, $session->{webName} );
            my $it =
              $webObject->eachWeb( $Foswiki::cfg{EnableHierarchicalWebs} );
            while ( $it->hasNext() ) {
                my $w = $session->{webName} . '/' . $it->next();
                next
                  unless $Foswiki::WebFilter::user_allowed->ok( $session, $w );
                $w = Foswiki::Sandbox::untaint( $w,
                    \&Foswiki::Sandbox::validateWebName );
                push( @tmpWebs, $w );
            }
        }
    }

    my @webs;
    foreach my $web (@tmpWebs) {
        next unless defined $web;
        push( @webs, $web ) unless $excludeWeb{$web};
        $excludeWeb{$web} = 1;    # eliminate duplicates
    }

    return @webs;
}
#########################################
#TODO: this is _now_ a default utility method that can be used by search&query algo's to brute force file a list of topics to search.
#if you can avoid it, you should - as it needs to do an opendir on the web, and if you have alot of topics, life gets slow
# get a list of topics to search in the web, filtered by the $topic
# spec
sub getTopicListIterator {
    my ( $webObject, $options ) = @_;
    my $casesensitive =
      defined( $options->{casesensitive} ) ? $options->{casesensitive} : 1;

    # E.g. "Web*, FooBar" ==> "^(Web.*|FooBar)$"
    $options->{excludeTopics} =
      convertTopicPatternToRegex( $options->{excludeTopics} )
      if ( $options->{excludeTopics} );

    my $topicFilter;
    my $it;
    if ( $options->{includeTopics} ) {

        # E.g. "Bug*, *Patch" ==> "^(Bug.*|.*Patch)$"
        $options->{includeTopics} =
          convertTopicPatternToRegex( $options->{includeTopics} );

        # limit search to topic list
        if (    $casesensitive
            and $options->{includeTopics} =~
            /^\^\([\_\-\+$Foswiki::regex{mixedAlphaNum}\|]+\)\$$/ )
        {

            # topic list without wildcards
            # for speed, do not get all topics in web
            # but convert topic pattern into topic list
            my $topics = $options->{includeTopics};
            $topics =~ s/^\^\(//o;
            $topics =~ s/\)\$//o;

            # build list from topic pattern
            my @list = split( /\|/, $topics );
            $it = new Foswiki::ListIterator( \@list );
        }
        elsif ( !$casesensitive ) {
            $topicFilter = qr/$options->{includeTopics}/i;
        }
        else {
            $topicFilter = qr/$options->{includeTopics}/;
        }
    }

    $it = $webObject->eachTopic() unless ( defined($it) );

    my $filterIter = new Foswiki::Iterator::FilterIterator(
        $it,
        sub {
            my $item = shift;

            #my $data = shift;
            return unless !$topicFilter || $item =~ /$topicFilter/;

            # exclude topics, Codev.ExcludeWebTopicsFromSearch
            if ( !$casesensitive && $options->{excludeTopics} ) {
                return if $item =~ /$options->{excludeTopics}/i;
            }
            elsif ( $options->{excludeTopics} ) {
                return if $item =~ /$options->{excludeTopics}/;
            }
            return $Foswiki::Plugins::SESSION->topicExists( $webObject->web,
                $item );
        }
    );
    return $filterIter;
}

sub convertTopicPatternToRegex {
    my ($topic) = @_;
    return '' unless ($topic);

    # 'Web*, FooBar' ==> ( 'Web*', 'FooBar' ) ==> ( 'Web.*', "FooBar" )
    my @arr =
      map { s/[^\*\_\-\+$Foswiki::regex{mixedAlphaNum}]//go; s/\*/\.\*/go; $_ }
      split( /(?:,\s*|\|)/, $topic );
    return '' unless (@arr);

    # ( 'Web.*', 'FooBar' ) ==> "^(Web.*|FooBar)$"
    return '^(' . join( '|', @arr ) . ')$';
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
