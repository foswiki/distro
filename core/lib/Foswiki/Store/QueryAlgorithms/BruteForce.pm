# See the bottom of this file for license and copyright information

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

=cut

package Foswiki::Store::QueryAlgorithms::BruteForce;
use strict;
#@ISA = ( 'Foswiki::Query::QueryAlgorithms' ); # interface

use Foswiki::Search::Node ();
use Foswiki::Meta         ();
use Foswiki::Search::InfoCache;

# See Foswiki::Store::QueryAlgorithms.pm for details
sub query {
    my ( $query, $web, $inputTopicSet, $store, $options ) = @_;

    my $topicSet = $inputTopicSet;

    #TODO: howto ask iterator for list length?
    #    if ( scalar(@$topics) > 6 ) {
    require Foswiki::Query::HoistREs;
    my @filter = Foswiki::Query::HoistREs::hoist($query);
    if ( scalar(@filter) ) {
        my $searchOptions = {
            type                => 'regex',
            casesensitive       => 1,
            files_without_match => 1,
        };
        my $searchQuery =
          new Foswiki::Search::Node( $query->toString(), \@filter,
            $searchOptions );
        $topicSet =
          $store->searchInWebMetaData( $searchQuery, $web, $topicSet,
            $searchOptions );
    }
    else {

        #print STDERR "WARNING: couldn't hoistREs on ".$query->toString();
    }

    #    }

    my %matches;
    local $/;
    while ( $topicSet->hasNext() ) {
        my $topic = $topicSet->next();
        my $meta =
          Foswiki::Meta->new( $store->{session}, $web, $topic );
        # this 'lazy load' will become useful when @$topics becomes
        # an infoCache
        $meta->reload() unless ( $meta->getLoadedRev() );
        next unless ( $meta->getLoadedRev() );
        print STDERR "Processing $topic\n" if Foswiki::Query::Node::MONITOR_EVAL();
        my $match = $query->evaluate( tom => $meta, data => $meta );
        if ($match) {
            $matches{$topic} = $match;
        }
    }

    my @topics = keys(%matches);
    my $resultTopicSet =
      new Foswiki::Search::InfoCache( $Foswiki::Plugins::SESSION, $web,
        \@topics );
    return $resultTopicSet;
}

# See Foswiki::Store::QueryAlgorithms.pm for details
sub getField {
    my ( $class, $node, $data, $field ) = @_;

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
        else {

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
    my ($class, $relativeTo, $w, $t) = @_;
    return Foswiki::Meta->load( $relativeTo->session, $w, $t );
}

1;
__END__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# Author: Crawford Currie
