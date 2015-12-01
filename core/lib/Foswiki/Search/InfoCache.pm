# See bottom of file for license and copyright information
package Foswiki::Search::InfoCache;
use strict;
use warnings;

use Foswiki::ListIterator ();
our @ISA = ('Foswiki::ListIterator');

use Unicode::Normalize;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---+ package Foswiki::Search::InfoCache

Support package; cache of topic info. When information about search hits is
compiled for output, this cache is used to avoid recovering the same info
about the same topic more than once.

=cut

# TODO: this is going to transform from an ugly duckling into the
# ResultSet Iterator
# Sven has the feeling that we should make result sets immutable

use Assert;
use Foswiki::Func                     ();
use Foswiki::Meta                     ();
use Foswiki::Iterator::FilterIterator ();

#use Monitor ();
#Monitor::MonitorMethod('Foswiki::Search::InfoCache', 'getTopicListIterator');

=begin TML

---++ ClassMethod new($session, $defaultWeb, \@topicList)
Initialise a new list of topics, allowing their data to be lazy loaded
if and when needed.

$defaultWeb is used to qualify topics that do not have a web
specifier - should expect it to be the same as BASEWEB in most cases.

Because this Iterator can be created and filled dynamically, once the Iterator hasNext() and next() methods are called, it is immutable.

=cut

#TODO: duplicates??, what about topicExists?
#TODO: remove the iterator code from this __container__ and make a $this->getIterator() which can then be used.
#TODO: replace the Iterator->reset() function with a lightweight Iterator->copyConstructor?
#TODO: or..... make reset() make the object mutable again, so we can change the elements in the list, but re-use the meta cache??
#CONSIDER: convert the internals to a hash[tomAddress] = {matches->[list of resultint text bits], othermeta...} - except this does not give us order :/

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
        $this->{_session}->search->metacache->addMeta( $web, $topic, $meta );
    }
    undef $this->{sorted};
}

sub numberOfTopics {
    my $this = shift;

    #can't use this, as it lies once its gone through the 'sortResults' hack
    #and lies more because the filterByDate is evaluated later.
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
    if ( $limit =~ m/(^\d+$)/ ) {

        # only digits, all else is the same as
        # an empty string.  "+10" won't work.
        $limit = $1;
    }
    else {

        # change 'all' to 0, then to big number
        $limit = 0;
    }
    $limit = 32000 unless ($limit);

    # TODO: this is really an ugly hack to get around the rather
    # horrible limit 'performance' hack
    if ( defined( $params->{showpage} )
        and $params->{showpage} > 1 )
    {
        $limit = ( 2 + $params->{showpage} ) * $params->{pagesize};
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
        $sortOrder =~ m/^creat/ ||    # topic creation time
        $sortOrder eq 'editby' ||     # author
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

This function adds a filter evaluator to the infocache that is evaluated 
as you iterate through the collection

<verbatim>
$infoCache->filterByDate( $date );
</verbatim>

=cut

sub filterByDate {
    my ( $this, $date ) = @_;
    ASSERT( !defined( $this->{filter} ) ) if DEBUG;

    my $session = $Foswiki::Plugins::SESSION;

    require Foswiki::Time;
    my @ends = Foswiki::Time::parseInterval($date);

    $this->{filter} = sub {
        my $webtopic = shift;

        # if date falls out of interval: exclude topic from result
        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $this->{_defaultWeb},
            $webtopic );
        my $topicdate = $session->getApproxRevTime( $web, $topic );

        return !( $topicdate < $ends[0] || $topicdate > $ends[1] );

    };

    return;
}

######OLD methods

# Sort a topic list using cached info
sub sortTopics {
    my ( $listRef, $sortfield, $revSort ) = @_;
    ASSERT($sortfield) if DEBUG;

    # don't spend time doing stuff to an empty list (or a list of one!)
    return if ( scalar(@$listRef) < 2 );

    if ( $sortfield eq 'topic' ) {

        # simple sort
        # note no extraction of topic info here, as not needed
        # for the sort. Instead it will be read lazily, later on.
        # TODO: need to remove the web portion
        # mmm, need to profile if there is even a point to this -
        # as all topics still need to be parsed to find permissions
        if ($revSort) {
            @{$listRef} = map { $_->[1] }
              sort { NFKD( $a->[0] ) cmp NFKD( $b->[0] ) }
              map { $_ =~ m/^(.*?)([^.]+)$/; [ $2, $_ ] } #quickhack to remove web
              @{$listRef};
        }
        else {
            @{$listRef} = map { $_->[1] }
              sort { NFKD( $b->[0] ) cmp NFKD( $a->[0] ) }
              map { $_ =~ m/^(.*?)([^.]+)$/; [ $2, $_ ] } #quickhack to remove web
              @{$listRef};
        }
        ASSERT( $listRef->[0] ) if DEBUG;
        return;
    }

    my $metacache = $Foswiki::Plugins::SESSION->search->metacache;

    # populate the cache for each topic
    foreach my $webtopic ( @{$listRef} ) {

        my $info = $metacache->get($webtopic);

        if ( $sortfield =~ m/^creat/ ) {

            # The act of getting the info will cache it
            #$metacache->getRev1Info( $webtopic, $sortfield );
            $info->{$sortfield} = $info->{tom}->getRev1Info($sortfield);
        }
        else {

            # SMELL: SD duplicated from above - I'd rather do it only here,
            # but i'm not sure if i can.
            $sortfield =~ s/^formfield\((.*)\)$/$1/;    # form field

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
        $info->{editby} =
          $info->{tom}->session->{users}->getWikiName( $info->{editby} );
    }
    @{$listRef} = map { $_->[1] }
      sort { _compare( $b, $a, $revSort ) }
      map { [ $metacache->get($_)->{$sortfield}, $_ ] } @{$listRef};
}

# RE for a full-spec floating-point number
our $NUMBER = qr/^[-+]?[0-9]+(\.[0-9]*)?([Ee][-+]?[0-9]+)?$/s;

sub _compare {
    my ( $a, $b, $reverse ) = @_;
    my ( $x, $y );
    if ($reverse) {
        $x = $a->[0];
        $y = $b->[0];
    }
    else {
        $x = $b->[0];
        $y = $a->[0];
    }

    ASSERT( defined($x) ) if DEBUG;
    ASSERT( defined($y) ) if DEBUG;

    my $comparison;
    if ( $x =~ m/$NUMBER/ && $y =~ m/$NUMBER/ ) {

        # when sorting numbers do it largest first; this is just because
        # this is what date comparisons need.
        $comparison = $y <=> $x;
    }
    else {

        my $datex = undef;
        my $datey = undef;

        # parseTime can error if you give it a date out of range so we skip
        # testing if pure number
        # We skip testing for dates the first character is not a digit
        # as all formats we recognise as dates are
        if (   $x =~ m/^\d/
            && $x !~ /$NUMBER/
            && $y =~ m/^\d/
            && $y !~ /$NUMBER/ )
        {
            $datex = Foswiki::Time::parseTime($x);
            $datey = Foswiki::Time::parseTime($y) if $datex;
        }

        if ( $datex && $datey ) {
            $comparison = $datey <=> $datex;
        }
        else {
            $comparison = NFKD($y) cmp NFKD($x);
        }
    }

    # tie breaker if keys are equal
    # reverse order will not apply to the secondary search key
    if ( $comparison == 0 ) {
        $comparison = NFKD( $b->[1] ) cmp NFKD( $a->[1] );
    }

    return $comparison;
}

=begin TML

---++ StaticMethod getOptionFilter(\%options) -> $code

Analyse the options given in \%options and return a function that
filters based on those options. \%options may include:
   * =includeTopics= - a comma-separated wildcard list of topic names
   * =excludeTopics= - do
   * =casesensitive= - boolean

=cut

sub getOptionFilter {
    my ($options) = @_;

    my $casesensitive =
      defined( $options->{casesensitive} ) ? $options->{casesensitive} : 1;

    # E.g. "Web*, FooBar" ==> "^(Web.*|FooBar)$"
    my $includeTopics;
    my $topicFilter;
    my $excludeTopics;
    $excludeTopics = convertTopicPatternToRegex( $options->{excludeTopics} )
      if ( $options->{excludeTopics} );

    if ( $options->{includeTopics} ) {

        # E.g. "Bug*, *Patch" ==> "^(Bug.*|.*Patch)$"
        $includeTopics =
          convertTopicPatternToRegex( $options->{includeTopics} );

        if ($casesensitive) {
            $topicFilter = qr/$includeTopics/;
        }
        else {
            $topicFilter = qr/$includeTopics/i;
        }
    }

    return sub {
        my $item = shift;
        return 0 unless !$topicFilter || $item =~ m/$topicFilter/;
        if ( defined $excludeTopics ) {
            return 0 if $item =~ m/$excludeTopics/;
            return 0 if !$casesensitive && $item =~ m/$excludeTopics/i;
        }
        return 1;
      }
}

#########################################
# TODO: this is _now_ a default utility method that can be used by
# search&query algo's to brute force file a list of topics to search.
# if you can avoid it, you should - as it needs to do an opendir on the
# web, and if you have alot of topics, life gets slow
# get a list of topics to search in the web, filtered by the $topic
# spec
sub getTopicListIterator {
    my ( $webObject, $options ) = @_;

    my $casesensitive =
      defined( $options->{casesensitive} ) ? $options->{casesensitive} : 1;

    # See if there's a list of topics to avoid having to do a web list
    my $it;
    if (   $casesensitive
        && $options->{includeTopics}
        && $options->{includeTopics} =~ m/^([[:alnum:]]+(,\s*|\|))+$/ )
    {

        # topic list without wildcards
        # convert pattern into a topic list
        my @list = grep {
            $Foswiki::Plugins::SESSION->topicExists( $webObject->web, $_ )
        } split( /,\s*|\|/, $options->{includeTopics} );
        $it = new Foswiki::ListIterator( \@list );
    }
    else {
        $it = $webObject->eachTopic();
    }

    return Foswiki::Iterator::FilterIterator->new( $it,
        getOptionFilter($options) );
}

sub convertTopicPatternToRegex {
    my ($topic) = @_;
    return '' unless ($topic);

    # 'Web*, FooBar' ==> ( 'Web*', 'FooBar' ) ==> ( 'Web.*', "FooBar" )
    my @arr =
      map { $_ = quotemeta($_); s/(^|(?<!\\))\\\*/\.\*/g; $_ }
      split( /(?:,\s*|\|)/, $topic );

    return '' unless (@arr);

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
