# See bottom of file for license and copyright information
package Foswiki::Store::QueryAlgorithms::BruteForce;

=begin TML

---+ package Foswiki::Store::QueryAlgorithms::BruteForce
Implements Foswiki::Store::Interfaces::QueryAlgorithm

Default brute-force query algorithm. Works by hoisting regular expressions
out of the query tree to narrow down the set of topics to be tested. Then
uses the query 'evaluate' method on each topic in turn to fully evaluate
the remaining query.

Not sure exactly where the breakpoint is between the
costs of hoisting and the advantages of hoisting. Benchmarks suggest
that it's around 6 topics, though this may vary depending on disk
speed and memory size. It also depends on the complexity of the query.

=cut

# TODO: There is an additional opportunity for optimisation; if we assume
# the grep is solid, we can cut those parts of the query out for the full
# evaluation path. Not done yet, because CDot strongly suspects it won't make
# much difference.

use strict;
use warnings;

use Foswiki::Store::Interfaces::QueryAlgorithm ();
our @ISA = ('Foswiki::Store::Interfaces::QueryAlgorithm');

use Foswiki::Store::Interfaces::SearchAlgorithm ();
use Foswiki::Search::Node                       ();
use Foswiki::Search::InfoCache                  ();
use Foswiki::Search::ResultSet                  ();
use Foswiki();
use Foswiki::Func();
use Foswiki::Meta            ();
use Foswiki::MetaCache       ();
use Foswiki::Query::Node     ();
use Foswiki::Query::HoistREs ();
use Foswiki::ListIterator();
use Foswiki::Iterator::FilterIterator();
use Foswiki::Iterator::ProcessIterator();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

use constant MONITOR => 0;

=begin TML

---++ ClassMethod new( $class,  ) -> $cereal

=cut

sub new {
    my $self = shift()->SUPER::new( 'SEARCH', @_ );
    return $self;
}

# Query over a single web
sub _webQuery {
    my ( $this, $query, $web, $inputTopicSet, $session, $options ) = @_;

    my $resultTopicSet =
      Foswiki::Search::InfoCache->new( $Foswiki::Plugins::SESSION, $web );

    # see if this query can be fasttracked.
    # TODO: is this simplification call appropriate here, or should it
    # go in Search.pm
    # TODO: what about simplify to constant in _this_ web?
    my $queryIsAConstantFastpath;    # undefined if this is a 'real' query'
    my $context = Foswiki::Meta->new( $session, $session->{webName} );
    $query->simplify( tom => $context, data => $context );

    if ( $query->evaluatesToConstant() ) {
        print STDERR "-- constant?\n" if MONITOR;

        # SMELL: use any old topic
        my $cache = $Foswiki::Plugins::SESSION->search->metacache->get( $web,
            'WebPreferences' );
        my $meta = $cache->{tom};
        $queryIsAConstantFastpath =
          $query->evaluate( tom => $meta, data => $meta );
    }

    if ( defined($queryIsAConstantFastpath) ) {
        if ( not $queryIsAConstantFastpath ) {
            print STDERR "-- no results\n" if MONITOR;

            #CONSTANT _and_ FALSE - return no results
            return $resultTopicSet;
        }
    }
    else {
        print STDERR "-- not constant\n" if MONITOR;

        # from here on, FALSE means its not a constant, TRUE
        # means is is a constant and evals to TRUE
        $queryIsAConstantFastpath = 0;
    }

    # Try and hoist regular expressions out of the query that we
    # can use to refine the topic set

    my $hoistedREs = Foswiki::Query::HoistREs::hoist($query);
    print STDERR "-- hoisted " . Data::Dumper->Dump( [$hoistedREs] ) . "\n"
      if MONITOR;

    # Reduce the input topic set by matching simple topic names hoisted
    # from the query.

    if (    ( !defined( $options->{topic} ) )
        and ( $hoistedREs->{name} )
        and ( scalar( @{ $hoistedREs->{name} } ) == 1 ) )
    {

        # only do this if the 'name' query is simple
        # (ie, has only one element)
        my @filter = @{ $hoistedREs->{name_source} };

        #set the 'includetopic' matcher..
        $options->{topic} = $filter[0];
    }

    # Reduce the input topic set by matching the hoisted REs against
    # the topics in it.

    my $topicSet = $inputTopicSet;
    if ( !defined($topicSet) ) {
        print STDERR "-- new topic Set from $web\n" if MONITOR;

        # then we start with the whole web?
        # TODO: i'm sure that is a flawed assumption
        my $webObject = Foswiki::Meta->new( $session, $web );
        $topicSet =
          Foswiki::Search::InfoCache::getTopicListIterator( $webObject,
            $options );
    }

    # TODO: how to ask iterator for list length?
    # TODO: once the inputTopicSet isa ResultSet we might have an idea
    # TODO: I presume $hoisetedRE's is undefined for constant queries..
    #    if (() and ( scalar(@$topics) > 6 )) {
    if ( defined( $hoistedREs->{text} ) ) {
        my $searchOptions = {
            type                => 'regex',
            casesensitive       => 1,
            files_without_match => 1,
            web                 => $web,
        };
        my @filter = @{ $hoistedREs->{text} };
        my $searchQuery =
          Foswiki::Search::Node->new( $query->toString(), \@filter,
            $searchOptions );

        #use Data::Dumper;
        #print STDERR "--- hoisted: ".Dumper($hoistedREs)."\n" if MONITOR;

        $topicSet->reset();
        $topicSet =
          $session->{store}
          ->query( $searchQuery, $topicSet, $session, $searchOptions );
    }
    else {

        # TODO: clearly _this_ can be re-written as a FilterIterator,
        # and if we are able to use the sorting hints (ie DB Store)
        # can propogate all the way to FORMAT

        print STDERR "WARNING: couldn't hoistREs on " . $query->toString()
          if MONITOR;
    }

    local $/;
    $topicSet->reset();
    while ( $topicSet->hasNext() ) {
        my $webtopic = $topicSet->next();
        my ( $Iweb, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $webtopic );
        print STDERR "--  $Iweb, $topic\n" if MONITOR;

        if ($queryIsAConstantFastpath) {
            print STDERR "-- add $Iweb, $topic\n" if MONITOR;
            if ( defined( $options->{date} ) ) {

                # TODO: preload the meta cache if we're doing date
                # based filtering - else the wrong filedate will be used
                $Foswiki::Plugins::SESSION->search->metacache->get( $Iweb,
                    $topic );
            }

            # TODO: frustratingly, there is no way to evaluate a
            # filterIterator without actually iterating over it..
            $resultTopicSet->addTopics( $Iweb, $topic );
        }
        else {
            my $meta =
              $Foswiki::Plugins::SESSION->search->metacache->addMeta( $Iweb,
                $topic );
            print STDERR "-- evaluate $Iweb, $topic\n" if MONITOR;
            next unless ( defined($meta) );    #not a valid or loadable topic

            # this 'lazy load' will become useful when @$topics becomes
            # an infoCache
            $meta = $meta->load() unless ( $meta->latestIsLoaded() );
            print STDERR "Processing $topic\n"
              if Foswiki::Query::Node::MONITOR_EVAL;
            my $match = $query->evaluate( tom => $meta, data => $meta );
            if ($match) {
                $resultTopicSet->addTopic($meta);
            }
        }
    }

    return $resultTopicSet;
}

1;
__END__
Authors: Crawford Currie http://c-dot.co.uk, Sven Dowideit http://fosiki.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
