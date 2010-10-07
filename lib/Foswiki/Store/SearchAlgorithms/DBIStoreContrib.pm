# See bottom of file for license and copyright information
package Foswiki::Store::SearchAlgorithms::DBIStoreContrib;

use strict;
use Assert;
use Foswiki::Search::InfoCache ();
use Foswiki::Query::Parser ();

# Analyse the requirements of the search, and redirect to the query
# algorithm. This is kinda like the reverse of hoisting regexes :-)
sub query {
    my ( $query, $inputTopicSet, $session, $options ) = @_;

    if (( @{ $query->{tokens} } ) == 0) {
        return new Foswiki::Search::InfoCache($session, '');
    }

    # Convert the search to a query
    # AND search - search once for each token, ANDing result together
    my @ands;
    foreach my $token ( @{ $query->{tokens} } ) {

        my $tokenCopy = $token;
        
        # flag for AND NOT search
        my $invert = ( $tokenCopy =~ s/^\!//o ) ? 'NOT ' : '';

        # scope can be 'topic' (default), 'text' or "all"
        # scope='topic', e.g. Perl search on topic name:
        my %topicMatches;
        my @ors;
        if ( $options->{'scope'} =~ /^(topic|all)$/ ) {
            my $expr = $tokenCopy;

            $expr = quotemeta($expr) unless ( $options->{'type'} eq 'regex' );
            $expr = "(?i:$expr)" unless $options->{'casesensitive'};
            push(@ors, "${invert}name =~ '$expr'");
        }

        # scope='text', e.g. grep search on topic text:
        if ( $options->{'scope'} =~ /^(text|all)$/ ) {
            my $expr = $tokenCopy;

            $expr = quotemeta($expr) unless ( $options->{'type'} eq 'regex' );
            $expr = "(?i:$expr)" unless $options->{'casesensitive'};

            push(@ors, "${invert}raw =~ '$expr'");
        }
        push(@ands, '(' . join(' OR ', @ors) . ')');
        
    }
    my $queryParser = Foswiki::Query::Parser->new();
    $query = $queryParser->parse(join(' AND ', @ands));

    eval "require $Foswiki::cfg{Store}{QueryAlgorithm}";
    die $@ if $@;
    my $fn = $Foswiki::cfg{Store}{QueryAlgorithm}.'::query';
    no strict 'refs';
    return &$fn($query, $inputTopicSet, $session, $options);
    use strict 'refs';
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Copyright (C) 2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
