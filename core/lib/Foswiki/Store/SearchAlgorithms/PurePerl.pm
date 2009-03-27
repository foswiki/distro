# See bottom of file for license and copyright information

package Foswiki::Store::SearchAlgorithms::PurePerl;

use strict;
use Assert;

=begin TML

---+ package Foswiki::Store::SearchAlgorithms::PurePerl

Pure perl implementation of the RCS cache search.

---++ search($searchString, $topics, $options, $sDir) -> \%seen
Search .txt files in $dir for $string. See RcsFile::searchInWebContent
for details.

=cut

sub search {
    my ( $searchString, $web, $topics, $store, $options ) = @_;

    local $/ = "\n";
    my %seen;
    if ( $options->{type} && $options->{type} eq 'regex' ) {

        # Escape /, used as delimiter. This also blocks any attempt to use
        # the search string to execute programs on the server.
        $searchString =~ s!/!\\/!g;
    }
    else {

        # Escape non-word chars in search string for plain text search
        $searchString =~ s/(\W)/\\$1/g;
    }

    # Convert GNU grep \< \> syntax to \b
    $searchString =~ s/(?<!\\)\\[<>]/\\b/g;
    $searchString =~ s/^(.*)$/\\b$1\\b/go if $options->{'wordboundaries'};
    my $doMatch;
    if ( $options->{casesensitive} ) {
        $doMatch = sub { $_[0] =~ m/$searchString/ };
    }
    else {
        $doMatch = sub { $_[0] =~ m/$searchString/i };
    }

    #SMELL, TODO, replace with Store call.
    my $sDir = $Foswiki::cfg{DataDir} . '/' . $web . '/';

  FILE:
    foreach my $file (@$topics) {
        next unless open( FILE, '<', "$sDir/$file.txt" );
        while ( my $line = <FILE> ) {
            if ( &$doMatch($line) ) {
                chomp($line);
                push( @{ $seen{$file} }, $line );
                if ( $options->{files_without_match} ) {
                    close(FILE);
                    next FILE;
                }
            }
        }
        close(FILE);
    }
    return \%seen;
}

=TML
this is the new way -
=cut
sub query {
    my ( $query, $web, $topics, $store, $options ) = @_;

# Run a search over a list of topics - @tokens is a list of
# search terms to be ANDed together
#SMELL: this code assumes that calling the search backend repeatedly is faster than
#telling the backend all the ANDed tokens and letting it do it - Sven thinks we
#should push this code into the search impl (and thus the @$tokens would be equiv to @query
#Similarly, both the topic&text scopes shoudl be delegated, as the combination may well be
#instant for more intellegent Store/Index systems
#sub _searchTopics {
#    my ( $this, $webObject, $options, $query, @topicList ) = @_;

    ASSERT(scalar(@{$query->{tokens}}) > 0) if DEBUG;

    # default scope is 'text'
    $options->{'scope'} = 'text' unless ( defined($options->{'scope'}) && $options->{'scope'} =~ /^(topic|all)$/ );

    my @topicList = @$topics;
#print STDERR "######## PurePerl search ($web) tokens ".scalar(@{$query->{tokens}})." : ".join(',', @{$query->{tokens}})."\n";

    # AND search - search once for each token, ANDing result together
    foreach my $token (@{$query->{tokens}}) {

        my $invertSearch = 0;

        $invertSearch = ( $token =~ s/^\!//o );

        # flag for AND NOT search
        my @scopeTextList  = ();
        my @scopeTopicList = ();

        # scope can be 'topic' (default), 'text' or "all"
        # scope='text', e.g. Perl search on topic name:
        unless ( $options->{'scope'} eq 'text' ) {
            my $qtoken = $token;

            # FIXME I18N
            $qtoken = quotemeta($qtoken) if ( $options->{'type'} ne 'regex' );
            if ( $options->{'casesensitive'} ) {

                # fix for Codev.SearchWithNoPipe
                @scopeTopicList = grep( /$qtoken/, @topicList );
            }
            else {
                @scopeTopicList = grep( /$qtoken/i, @topicList );
            }
        }

        # scope='text', e.g. grep search on topic text:
        unless ( $options->{'scope'} eq 'topic' ) {
            my $matches = search( $token, $web, $topics, $store, $options );

            @scopeTextList = keys %$matches;
        }

        if ( @scopeTextList && @scopeTopicList ) {

            # join 'topic' and 'text' lists
            push( @scopeTextList, @scopeTopicList );
            my %seen = ();

            # make topics unique
            @scopeTextList = sort grep { !$seen{$_}++ } @scopeTextList;
        }
        elsif (@scopeTopicList) {
            @scopeTextList = @scopeTopicList;
        }

        if ($invertSearch) {

            # do AND NOT search
            my %seen = ();
            foreach my $topic (@scopeTextList) {
                $seen{$topic} = 1;
            }
            @scopeTextList = ();
            foreach my $topic (@topicList) {
                push( @scopeTextList, $topic ) unless ( $seen{$topic} );
            }
        }

        # reduced topic list for next token
        @topicList = @scopeTextList;
    }

    #TODO: um, yeah :(
    my %hackMatch;
    foreach my $t (@topicList) {
        $hackMatch{$t} = 1;
    }

    return \%hackMatch;
}

1;
__DATA__
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
