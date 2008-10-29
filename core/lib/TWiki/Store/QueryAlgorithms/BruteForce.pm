# Please see the bottom of this file for license and copyright information

=pod

---+ package TWiki::Store::QueryAlgorithms::BruteForce

Default brute-force query algorithm

Has some basic optimisation: it hoists regular expressions out of the
query to use with grep, so we can narrow down the set of topics that we
have to evaluate the query on.

Not sure exactly where the breakpoint is between the
costs of hoisting and the advantages of hoisting. Benchmarks suggest
that it's around 6 topics, though this may vary depending on disk
speed and memory size. It also depends on the complexity of the query.

=cut

package TWiki::Store::QueryAlgorithms::BruteForce;

use strict;

require TWiki::Meta;

sub query {
    my ($query, $web, $topics, $store) = @_;

    my $sDir = $TWiki::cfg{DataDir}.'/'.$web.'/';

    if (scalar(@$topics) > 6) {
        require TWiki::Query::HoistREs;
        my @filter = TWiki::Query::HoistREs::hoist( $query );
        foreach my $token (@filter) {
            my $m = $store->searchInWebContent(
                $token, $web, $topics,
                {
                    type => 'regex',
                    casesensitive => 1,
                    files_without_match => 1,
                });
            @$topics = keys %$m;
        }
    }

    my %matches;
    local $/;
    foreach my $topic ( @$topics ) {
        next unless open(FILE, "<$sDir/$topic.txt");
        my $meta = new TWiki::Meta($store->{session}, $web, $topic, <FILE>);
        close(FILE);
        my $match = $query->evaluate( tom => $meta, data => $meta );
        if( $match ) {
            $matches{$topic} = $match;
        }
    }
    return \%matches;
}

1;
__DATA__
# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution.
# NOTE: Please extend that file, not this notice.
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
