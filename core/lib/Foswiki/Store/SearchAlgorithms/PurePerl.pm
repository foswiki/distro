# See bottom of file for license and copyright information
package Foswiki::Store::SearchAlgorithms::PurePerl;

=begin TML

---+ package Foswiki::Store::SearchAlgorithms::PurePerl
Implements Foswiki::Store::Interfaces::SearchAlgorithm

Pure perl implementation of the flat file search in Forking.pm.

=cut

use strict;
use warnings;
use Assert;
use Encode;

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

# This is the 'old' interface, prior to Sven's massive search refactoring.
sub _search {
    my ( $searchString, $web, $inputTopicSet, $session, $options ) = @_;

    local $/ = "\n";
    my %seen;
    if ( $options->{type} && $options->{type} eq 'regex' ) {

        # Escape /, used as delimiter. This also blocks any attempt to use
        # the search string to execute programs on the server.
        $searchString =~ s!/!\/!g;
    }
    else {

        # Escape non-word chars in search string for plain text search
        $searchString =~ s/(\W)/\\$1/g;
    }

    # *Compatibility; this should no longer be required, as usage of
    # \< and \> has been removed in the core.
    # Convert GNU grep \< \> syntax to \b
    $searchString =~ s/(?<!\\)\\[<>]/\\b/g;

    $searchString =~ s/^(.*)$/\\b$1\\b/g if $options->{'wordboundaries'};
    my $doMatch;
    if ( $options->{casesensitive} ) {
        $doMatch = sub { $_[0] =~ m/$searchString/ };
    }
    else {
        $doMatch = sub { $_[0] =~ m/$searchString/i };
    }

    #SMELL, TODO, replace with Store call.
    my $sDir = $Foswiki::cfg{DataDir} . '/' . $web . '/';
    $inputTopicSet->reset();
  FILE:
    while ( $inputTopicSet->hasNext() ) {
        my $webtopic = $inputTopicSet->next();
        my ( $Iweb, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $webtopic );

#TODO: need to BM if this is faster than doing it via an object in the MetaCache.
        my $file;
        my $enc = $Foswiki::cfg{Store}{Encoding} || 'utf-8';
        if (
            open(
                $file, "<:encoding($enc)",
                Foswiki::Store::encode( "$sDir/$topic.txt", 1 )
            )
          )
        {
            while ( my $line = <$file> ) {
                if ( &$doMatch($line) ) {
                    chomp($line);
                    push( @{ $seen{$webtopic} }, $line );
                    if ( $options->{files_without_match} ) {
                        close($file);
                        next FILE;
                    }
                }
            }
            close($file);
        }
    }
    return \%seen;
}

#ok, for initial validation, naively call the code with a web.
sub _webQuery {
    my ( $this, $query, $web, $inputTopicSet, $session, $options ) = @_;
    ASSERT( !$query->isEmpty() ) if DEBUG;

    # default scope is 'text'
    $options->{'scope'} = 'text'
      unless ( defined( $options->{'scope'} )
        && $options->{'scope'} =~ m/^(topic|all)$/ );

    my $topicSet = $inputTopicSet;
    if ( !defined($topicSet) ) {

        #then we start with the whole web?
        #TODO: i'm sure that is a flawed assumption
        my $webObject = Foswiki::Meta->new( $session, $web );
        $topicSet =
          Foswiki::Search::InfoCache::getTopicListIterator( $webObject,
            $options );
    }
    ASSERT( UNIVERSAL::isa( $topicSet, 'Foswiki::Iterator' ) ) if DEBUG;

    #print STDERR "######## PurePerl search ($web) tokens "
    #.scalar(@{$query->tokens()})." : ".join(',', @{$query->tokens()})."\n";
    # AND search - search once for each token, ANDing result together
    foreach my $token ( @{ $query->tokens() } ) {

        my $tokenCopy = $token;

        # flag for AND NOT search
        my $invertSearch = 0;
        $invertSearch = ( $tokenCopy =~ s/^\!// );

        # scope can be 'topic' (default), 'text' or "all"
        # scope='topic', e.g. Perl search on topic name:
        my %topicMatches;
        unless ( $options->{'scope'} eq 'text' ) {
            my $qtoken = $tokenCopy;

            # FIXME I18N
            $qtoken = quotemeta($qtoken)
              if ( $options->{'type'} ne 'regex' );

            my @topicList;
            $topicSet->reset();
            while ( $topicSet->hasNext() ) {
                my $webtopic = $topicSet->next();
                my ( $Iweb, $topic ) =
                  Foswiki::Func::normalizeWebTopicName( $web, $webtopic );

                if ( $options->{'casesensitive'} ) {

                    # fix for Codev.SearchWithNoPipe
                    $topicMatches{$webtopic} = 1 if ( $topic =~ m/$qtoken/ );
                }
                else {
                    $topicMatches{$webtopic} = 1 if ( $topic =~ m/$qtoken/i );
                }
            }
        }

        # scope='text', e.g. grep search on topic text:
        my $textMatches;
        unless ( $options->{'scope'} eq 'topic' ) {
            $textMatches =
              _search( $tokenCopy, $web, $topicSet, $session->{store},
                $options );
        }

        #bring the text matches into the topicMatch hash
        if ($textMatches) {
            @topicMatches{ keys %$textMatches } = values %$textMatches;
        }

        my @scopeTextList = ();
        if ($invertSearch) {
            $topicSet->reset();
            while ( $topicSet->hasNext() ) {
                my $webtopic = $topicSet->next();

                if ( $topicMatches{$webtopic} ) {
                }
                else {
                    push( @scopeTextList, $webtopic );
                }
            }
        }
        else {

            #TODO: the sad thing about this is we lose info
            @scopeTextList = keys(%topicMatches);
        }

        $topicSet =
          Foswiki::Search::InfoCache->new( $Foswiki::Plugins::SESSION, $web,
            \@scopeTextList );
    }

    return $topicSet;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
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
