# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::QueryAlgorithms::BruteForce

Default brute-force query algorithm

Has some basic optimisation: it hoists regular expressions out of the
query to use with grep, so we can narrow down the set of topics that we
have to evaluate the query on.

Not sure exactly where the breakpoint is between the
costs of hoisting and the advantages of hoisting. Benchmarks suggest
that it's around 6 topics, though this may vary depending on disk
speed and memory size. It also depends on the complexity of the query.

TODO: There is an additional opprotunity for optimisation; if we assume
the grep is solid, we can cut those parts of the query out for the full
evaluation path. Not done yet, because CDot strongly suspects it won't make
much difference.

=cut

package Foswiki::Store::QueryAlgorithms::BruteForce;
use strict;
use warnings;

#@ISA = ( 'Foswiki::Query::QueryAlgorithms' ); # interface

use Foswiki::Search::Node      ();
use Foswiki::Meta              ();
use Foswiki::Search::InfoCache ();
use Foswiki::Search::ResultSet ();
use Foswiki::MetaCache         ();
use Foswiki::Query::Node       ();
use Foswiki::Query::HoistREs   ();

# See Foswiki::Query::QueryAlgorithms.pm for details
sub query {
    my ( $query, $inputTopicSet, $session, $options ) = @_;

    # Fold constants
    my $context = Foswiki::Meta->new( $session, $session->{webName} );
    $query->simplify( tom => $context, data => $context );

    my $webNames = $options->{web}       || '';
    my $recurse  = $options->{'recurse'} || '';
    my $isAdmin  = $session->{users}->isAdmin( $session->{user} );

    my $searchAllFlag = ( $webNames =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );
    my @webs = Foswiki::Search::InfoCache::_getListOfWebs( $webNames, $recurse,
        $searchAllFlag );

    my @resultCacheList;
    foreach my $web (@webs) {

        # can't process what ain't thar
        next unless $session->webExists($web);

        my $webObject = Foswiki::Meta->new( $session, $web );
        my $thisWebNoSearchAll = Foswiki::isTrue(
            $webObject->getPreference('NOSEARCHALL') );

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        next
          if ( $searchAllFlag
            && !$isAdmin
            && ( $thisWebNoSearchAll || $web =~ /^[\.\_]/ )
            && $web ne $session->{webName} );

        #TODO: combine these into one great ResultSet
        my $infoCache =
          _webQuery( $query, $web, $inputTopicSet, $session, $options );
        push( @resultCacheList, $infoCache );
    }
    my $resultset =
      new Foswiki::Search::ResultSet( \@resultCacheList, $options->{groupby},
        $options->{order}, Foswiki::isTrue( $options->{reverse} ) );

    #TODO: $options should become redundant
    $resultset->sortResults($options);
    return $resultset;
}

# Query over a single web
sub _webQuery {
    my ( $query, $web, $inputTopicSet, $session, $options ) = @_;

    my $resultTopicSet =
      new Foswiki::Search::InfoCache( $Foswiki::Plugins::SESSION, $web );

    # see if this query can be fasttracked.
    # TODO: is this simplification call appropriate here, or should it
    # go in Search.pm
    # TODO: what about simplify to constant in _this_ web?
    my $queryIsAConstantFastpath;    # undefined if this is a 'real' query'
    $query->simplify();
    if ( $query->evaluatesToConstant() ) {

        # SMELL: use any old topic
        my $cache = $Foswiki::Plugins::SESSION->search->metacache->get(
            $web, 'WebPreferences' );
        my $meta = $cache->{tom};
        $queryIsAConstantFastpath =
          $query->evaluate( tom => $meta, data => $meta );
    }

    if ( defined($queryIsAConstantFastpath) ) {
        if ( not $queryIsAConstantFastpath ) {

            #CONSTANT _and_ FALSE - return no results
            return $resultTopicSet;
        }
    }
    else {

        # from here on, FALSE means its not a constant, TRUE
        # means is is a constant and evals to TRUE
        $queryIsAConstantFastpath = 0;
    }

    # Try and hoist regular expressions out of the query that we
    # can use to refine the topic set

    my $hoistedREs = Foswiki::Query::HoistREs::collatedHoist($query);

    # Reduce the input topic set by matching simple topic names hoisted
    # from the query.

    if (
            ( !defined( $options->{topic} ) )
        and ( $hoistedREs->{name} )
        and (
            scalar( @{ $hoistedREs->{name} } ) == 1
        )
      )
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
        };
        my @filter = @{ $hoistedREs->{text} };
        my $searchQuery =
          new Foswiki::Search::Node( $query->toString(), \@filter,
            $searchOptions );
        $topicSet->reset();
        $topicSet =
          $session->{store}
          ->searchInWebMetaData( $searchQuery, $web, $topicSet, $session,
            $searchOptions );
    }
    else {

        # TODO: clearly _this_ can be re-written as a FilterIterator,
        # and if we are able to use the sorting hints (ie DB Store)
        # can propogate all the way to FORMAT

        #print STDERR "WARNING: couldn't hoistREs on ".$query->toString();
    }

    local $/;
    $topicSet->reset();
    while ( $topicSet->hasNext() ) {
        my $webtopic = $topicSet->next();
        my ( $Iweb, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $webtopic );
        if ($queryIsAConstantFastpath) {
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
            my $cache =
              $Foswiki::Plugins::SESSION->search->metacache->get( $Iweb,
                $topic );
            my $meta = $cache->{tom};

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

# The getField function is here to allow for Store specific optimisations
# such as direct database lookups.
sub getField {
    my ( $this, $node, $data, $field ) = @_;

    my $result;
    if ( UNIVERSAL::isa( $data, 'Foswiki::Meta' ) ) {

        # The object being indexed is a Foswiki::Meta object, so
        # we have to use a different approach to treating it
        # as an associative array. The first thing to do is to
        # apply our "alias" shortcuts.
        my $realField = $field;
        if ( $Foswiki::Query::Node::aliases{$field} ) {
            $realField = $Foswiki::Query::Node::aliases{$field};
        }
        if ( $realField eq 'META:TOPICINFO' ) {

            # Ensure the revision info is populated from the store
            $data->getRevisionInfo();
        }
        if ( $realField =~ s/^META:// ) {
            if ( $Foswiki::Query::Node::isArrayType{$realField} ) {

                # Array type, have to use find
                my @e = $data->find($realField);
                $result = \@e;
            }
            else {
                $result = $data->get($realField);
            }
        }
        elsif ( $realField eq 'name' ) {

            # Special accessor to compensate for lack of a topic
            # name anywhere in the saved fields of meta
            return $data->topic();
        }
        elsif ( $realField eq 'text' ) {

            # Special accessor to compensate for lack of the topic text
            # name anywhere in the saved fields of meta
            return $data->text();
        }
        elsif ( $realField eq 'web' ) {

            # Special accessor to compensate for lack of a web
            # name anywhere in the saved fields of meta
            return $data->web();
        }
        elsif ($data->topic()) {

            # The field name isn't an alias, check to see if it's
            # the form name
            my $form = $data->get('FORM');
            if ( $form && $field eq $form->{name} ) {

                # SHORTCUT;it's the form name, so give me the fields
                # as if the 'field' keyword had been used.
                # TODO: This is where multiple form support needs to reside.
                # Return the array of FIELD for further indexing.
                my @e = $data->find('FIELD');
                return \@e;
            }
            else {

                # SHORTCUT; not a predefined name; assume it's a field
                # 'name' instead.
                # SMELL: Needs to error out if there are multiple forms -
                # or perhaps have a heuristic that gives access to the
                # uniquely named field.
                $result = $data->get( 'FIELD', $field );
                $result = $result->{value} if $result;
            }
        }
    }
    elsif ( ref($data) eq 'ARRAY' ) {

        # Array objects are returned during evaluation, e.g. when
        # a subset of an array is matched for further processing.

        # Indexing an array object. The index will be one of:
        # 1. An integer, which is an implicit index='x' query
        # 2. A name, which is an implicit name='x' query
        if ( $field =~ /^\d+$/ ) {

            # Integer index
            $result = $data->[$field];
        }
        else {

            # String index
            my @res;

            # Get all array entries that match the field
            foreach my $f (@$data) {
                my $val = getField( undef, $node, $f, $field );
                push( @res, $val ) if defined($val);
            }
            if ( scalar(@res) ) {
                $result = \@res;
            }
            else {

                # The field name wasn't explicitly seen in any of the records.
                # Try again, this time matching 'name' and returning 'value'
                foreach my $f (@$data) {
                    next unless ref($f) eq 'HASH';
                    if (   $f->{name}
                        && $f->{name} eq $field
                        && defined $f->{value} )
                    {
                        push( @res, $f->{value} );
                    }
                }
                if ( scalar(@res) ) {
                    $result = \@res;
                }
            }
        }
    }
    elsif ( ref($data) eq 'HASH' ) {

        # A hash object may be returned when a sub-object of a Foswiki::Meta
        # object has been matched.
        $result = $data->{ $node->{params}[0] };
    }
    else {
        $result = $node->{params}[0];
    }
    return $result;
}

# Get a referenced topic
# See Foswiki::Store::QueryAlgorithms.pm for details
sub getRefTopic {
    my ( $this, $relativeTo, $w, $t ) = @_;
    return Foswiki::Meta->load( $relativeTo->session, $w, $t );
}

1;
__END__
Authors: Crawford Currie http://c-dot.co.uk, Sven Dowideit http://fosiki.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
