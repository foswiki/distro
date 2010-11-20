# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::QueryAlgorithms::DBIStoreContrib
Implements Foswiki::Store::Interfaces::QueryAlgorithm

=cut

package Foswiki::Store::QueryAlgorithms::DBIStoreContrib;

use strict;
use warnings;

#use Foswiki::Store::Interfaces::QueryAlgorithm ();
#use Foswiki::Store::Interfaces::SearchAlgorithm ();
#@ISA = ( 'Foswiki::Store::Interfaces::QueryAlgorithm' );

use Foswiki::Search::Node      ();
use Foswiki::Meta              ();
use Foswiki::Search::InfoCache ();
use Foswiki::Search::ResultSet ();
use Foswiki::MetaCache         ();
use Foswiki::Query::Node       ();
use Foswiki::Contrib::DBIStoreContrib::Listener ();

BEGIN {
    eval 'require  Foswiki::Store::Interfaces::SearchAlgorithm';
    if ($@) {
	# Foswiki 1,1 or earlier
	require Foswiki::Search::InfoCache;
	*getListOfWebs = \&Foswiki::Search::InfoCache::_getListOfWebs;
	*getOptionFilter = sub {
	    my ($options) = @_;

	    my $casesensitive =
		defined( $options->{casesensitive} ) ? $options->{casesensitive} : 1;

	    # E.g. "Web*, FooBar" ==> "^(Web.*|FooBar)$"
	    my $includeTopics;
	    my $topicFilter;
	    my $excludeTopics;
	    $excludeTopics =
		Foswiki::Search::InfoCache::convertTopicPatternToRegex( $options->{excludeTopics} )
		if ( $options->{excludeTopics} );

	    if ( $options->{includeTopics} ) {
		# E.g. "Bug*, *Patch" ==> "^(Bug.*|.*Patch)$"
		$includeTopics =
		    Foswiki::Search::InfoCache::convertTopicPatternToRegex( $options->{includeTopics} );

		if ( $casesensitive ) {
		    $topicFilter = qr/$includeTopics/;
		}
		else {
		    $topicFilter = qr/$includeTopics/i;
		}
	    }

	    return sub {
		my $item = shift;
		return 0 unless !$topicFilter || $item =~ /$topicFilter/;
		if ( defined $excludeTopics ) {
		    return 0 if $item =~ /$excludeTopics/;
		    return 0 if !$casesensitive && $item =~ /$excludeTopics/i;
		}
		return 1;
	    }
	}
    } else {
	# Foswiki > 1.1
	*getListOfWebs = \&Foswiki::Store::Interfaces::SearchAlgorithm::getListOfWebs;
	*getOptionFilter = \&Foswiki::Search::InfoCache::getOptionFilter;
    }
}

# Debug prints
use constant MONITOR => 0;

# See Foswiki::Query::QueryAlgorithms.pm for details
sub query {
    my ( $query, $interestingTopics, $session, $options ) = @_;

    print STDERR "Initial query: ".$query->stringify()."\n" if MONITOR;
    # Fold constants
    my $context = Foswiki::Meta->new( $session, $session->{webName} );
    $query->simplify( tom => $context, data => $context );
    print STDERR "Simplified to: ". $query->stringify() . "\n" if MONITOR;

    my $isAdmin = $session->{users}->isAdmin( $session->{user} );

    # First make a list of interesting webs
    my $webNames = $options->{web}       || '';
    my $recurse  = $options->{'recurse'} || '';
    my $searchAllFlag = ( $webNames =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );
    my @webs = getListOfWebs( $webNames, $recurse, $searchAllFlag );

    my @interestingWebs;
    foreach my $web (@webs) {

        # can't process what ain't thar
        next unless $session->webExists($web);

        my $webObject = Foswiki::Meta->new( $session, $web );
        my $thisWebNoSearchAll =
          Foswiki::isTrue( $webObject->getPreference('NOSEARCHALL') );

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        unless ( $searchAllFlag
            && !$isAdmin
            && ( $thisWebNoSearchAll || $web =~ /^[\.\_]/ )
            && $web ne $session->{webName} )
        {
            push( @interestingWebs, $web );
        }
    }

    # Got to be something worth searching for
    return [] unless scalar(@interestingWebs);

    # Try and hoist regular expressions out of the query that we
    # can use to refine the topic set

    require Foswiki::Contrib::DBIStoreContrib::HoistSQL;
    my $hoistedSQL = Foswiki::Contrib::DBIStoreContrib::HoistSQL::hoist(
        $query) || 1;

    if ($hoistedSQL) {
        print STDERR "Hoisted '$hoistedSQL', remaining query: "
          . $query->stringify . "\n" if MONITOR;

        # Did hoisting eliminate the dynamic query?
        if ($query->evaluatesToConstant()) {
            print STDERR "\t...eliminated static query\n" if MONITOR;
            $query = undef;
        }
    }
    my $sql =
        'SELECT tid FROM topic WHERE '
      . ( $hoistedSQL ? "$hoistedSQL AND " : '' )
      . "topic.web IN ("
      . join( ',', map { "'$_'" } @interestingWebs ) . ')';

    if ( $interestingTopics && $interestingTopics->hasNext() ) {
        $sql .= " AND topic.name IN ("
          . join( ',', map { "'$_'" } $interestingTopics->all() ) . ')';
    } # otherwise there is no topic name filter

    $sql .= ' ORDER BY web,name';

    print STDERR "Generated SQL: $sql\n" if MONITOR;

    my $topicSet = Foswiki::Contrib::DBIStoreContrib::Listener::query(
        $session, $sql );
    my $filter = getOptionFilter($options);

    # Collate results into one-per-web result sets to mimic the old
    # per-web search behaviour.
    my %results;
    foreach my $webtopic (@$topicSet) {
        my ( $Iweb, $topic ) =
          $Foswiki::Plugins::SESSION->normalizeWebTopicName(
              undef, $webtopic );

        my $cache =
          $Foswiki::Plugins::SESSION->search->metacache->get( $Iweb, $topic );
        my $meta = $cache->{tom};

        # Note that we filter the non-web topic name
        next unless &$filter($topic);

        $results{$Iweb} ||=
          new Foswiki::Search::InfoCache($Foswiki::Plugins::SESSION);

        if ($query) {
            print STDERR "Evaluating " . $meta->getPath() . "\n" if MONITOR;

            # this 'lazy load' will become useful when @$topics becomes
            # an infoCache
            $meta = $meta->load() unless ( $meta->latestIsLoaded() );
            my $match = $query->evaluate( tom => $meta, data => $meta );
            if ($match) {
                $results{$Iweb}->addTopic($meta);
            }
            else {
                print STDERR "NO MATCH for " . $query->stringify . "\n"
                  if MONITOR;
            }
        }
        else {
            $results{$Iweb}->addTopic($meta);
        }
    }

    # We have to pre-sort the result sets by web name to mimic the
    # behaviour of default search.
    my $resultset =
      new Foswiki::Search::ResultSet(
          [ map { $results{$_} } sort( keys( %results )) ],
          $options->{groupby},
          $options->{order},
          Foswiki::isTrue( $options->{reverse} ) );

    #TODO: $options should become redundant
    $resultset->sortResults($options);
    return $resultset;
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
        elsif ( $realField eq 'raw' ) {

            return $data->getEmbeddedStoreForm();
        }
        elsif ( $realField eq 'web' ) {

            # Special accessor to compensate for lack of a web
            # name anywhere in the saved fields of meta
            return $data->web();
        }
        elsif ( $data->topic() ) {

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
# See Foswiki::Store::Interfaces::QueryAlgorithms.pm for details
sub getRefTopic {
    my ( $this, $relativeTo, $w, $t ) = @_;
    return Foswiki::Meta->load( $relativeTo->session, $w, $t );
}

1;
__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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

Author: Crawford Currie http://c-dot.co.uk
