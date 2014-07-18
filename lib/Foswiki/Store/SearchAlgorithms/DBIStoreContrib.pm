# See bottom of file for license and copyright information
package Foswiki::Store::SearchAlgorithms::DBIStoreContrib;

=begin TML

---+ package Foswiki::Store::SearchAlgorithms::DBIStoreContrib
Implements Foswiki::Store::Interfaces::SearchAlgorithm

DBI implementation of search.

=cut

use strict;
use Assert;
use Foswiki::Search::InfoCache                       ();
use Foswiki::Query::Parser                           ();
use Foswiki::Store::QueryAlgorithms::DBIStoreContrib ();
use Foswiki::Func                                    ();
our @ISA;

BEGIN {
    eval 'require Foswiki::Store::Interfaces::SearchAlgorithm';
    unless ($@) {
        @ISA = ('Foswiki::Store::Interfaces::SearchAlgorithm');
    }
}

=begin TML

---++ ClassMethod new( $class,  ) -> $cereal

=cut

sub new {
    my $self = shift()->SUPER::new( 'SEARCH', @_ );
    return $self;
}

# Analyse the requirements of the search, and redirect to the query
# algorithm. This is kinda like the reverse of hoisting regexes :-)
# Implements Foswiki::Store::Interfaces::SearchAlgorithm
sub query {
    my ( $this, $query, $inputTopicSet, $session, $options ) = @_;
    my $tokens;

    if ( UNIVERSAL::isa( $this, __PACKAGE__ ) ) {
        $tokens = $query->tokens();
    }
    else {
        ( $query, $inputTopicSet, $session, $options ) = @_;
        $tokens = $query->{tokens};
    }

    if ( scalar( @{$tokens} ) == 0 ) {
        return new Foswiki::Search::InfoCache( $session, '' );
    }

    # Convert the search to a query
    # AND search - search once for each token, ANDing result together
    my @ands;
    my @ors;
    foreach my $token ( @{$tokens} ) {

        my $tokenCopy = $token;

        # flag for AND NOT search
        my $invert = ( $tokenCopy =~ s/^\!// ) ? 'NOT ' : '';

        # scope can be 'topic', 'text' or "all"
        # scope='topic', e.g. Perl search on topic name:
        $options->{scope} = 'text' unless defined $options->{'scope'};
        $options->{type}          ||= 'literal';
        $options->{casesensitive} ||= 0;

        $tokenCopy = "\\b$tokenCopy\\b" if $options->{wordboundaries};

        if ( $options->{scope} ne 'text' ) {    # topic or all
            my $expr = $tokenCopy;

            $expr = quotemeta($expr) unless ( $options->{type} eq 'regex' );
            $expr = "(?i:$expr)" unless $options->{casesensitive};
            push( @ors, "${invert}name =~ '$expr'" );
        }

        # scope='text', e.g. grep search on topic text:
        if ( $options->{scope} ne 'topic' ) {    # text or all
            my $expr = $tokenCopy;

            $expr = quotemeta($expr) unless ( $options->{type} eq 'regex' );
            $expr = "(?i:$expr)" unless $options->{casesensitive};

            push( @ors, "${invert}raw =~ '$expr'" );
        }
        push( @ands, '(' . join( $invert ? ' AND ' : ' OR ', @ors ) . ')' );
    }

    my $queryParser = Foswiki::Query::Parser->new();
    my $search = join( ' AND ', @ands );
    Foswiki::Func::writeDebug("Search generated query $search")
      if Foswiki::Store::QueryAlgorithms::DBIStoreContrib::MONITOR;

    $query = $queryParser->parse($search);

    return Foswiki::Store::QueryAlgorithms::DBIStoreContrib::query( $query,
        $inputTopicSet, $session, $options );
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
