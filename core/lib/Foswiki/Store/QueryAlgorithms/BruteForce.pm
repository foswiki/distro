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

use Foswiki::Search::Node;

use strict;

use Foswiki::Meta ();

sub query {
    my ( $query, $web, $topics, $store, $options ) = @_;

    if ( scalar(@$topics) > 6 ) {
        require Foswiki::Query::HoistREs;
        my @filter = Foswiki::Query::HoistREs::hoist($query);
        if (scalar(@filter)) {
            my $searchOptions = {
                        type                => 'regex',
                        casesensitive       => 1,
                        files_without_match => 1,
                    };
            my $searchQuery = new Foswiki::Search::Node($query->toString(), \@filter, $searchOptions);
            my $m = $store->searchInWebMetaData($searchQuery, $web, $topics, $searchOptions);
            @$topics = keys %$m;
        } else {
            #print STDERR "WARNING: couldn't hoistREs on ".$query->toString();
        }
    }

    my %matches;
    local $/;
    foreach my $topic (@$topics) {
        my $meta =
          Foswiki::Meta->new( $store->{session}, $web, $topic);#, <FILE> );
        #this 'lazy load will become useful when @$topics becomes an infoCache
        $meta->reload() unless ( $meta->getLoadedRev() > 0 );
        next unless ( $meta->getLoadedRev() > 0 );

        my $match = $query->evaluate( tom => $meta, data => $meta );
        if ($match) {
            $matches{$topic} = $match;
        }
    }
    return \%matches;
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
#
# Author: Crawford Currie
