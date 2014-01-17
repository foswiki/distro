# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::QueryAlgorithms::DBIStoreContrib
Implements Foswiki::Store::Interfaces::QueryAlgorithm

=cut

package Foswiki::Store::QueryAlgorithms::DBIStoreContrib;

use strict;
use warnings;

our @ISA;

use Assert;
use Foswiki::Search::Node                       ();
use Foswiki::Meta                               ();
use Foswiki::Search::InfoCache                  ();
use Foswiki::Search::ResultSet                  ();
use Foswiki::MetaCache                          ();
use Foswiki::Query::Node                        ();
use Foswiki::Contrib::DBIStoreContrib::DBIStore ();

# Debug prints
use constant MONITOR => 1;

BEGIN {
    eval 'require Foswiki::Store::Interfaces::QueryAlgorithm';
    if ($@) {
        print STDERR "Compatibility mode\n" if MONITOR;
        undef $@;

        # Foswiki 1.1 or earlier
        #require Foswiki::Query::QueryAlgorithms; # empty class
        #@ISA = ('Foswiki::Query::QueryAlgorithms');

        require Foswiki::Search::InfoCache;
        *getListOfWebs   = \&Foswiki::Search::InfoCache::_getListOfWebs;
        *getOptionFilter = sub {
            my ($options) = @_;

            my $casesensitive =
              defined( $options->{casesensitive} )
              ? $options->{casesensitive}
              : 1;

            # E.g. "Web*, FooBar" ==> "^(Web.*|FooBar)$"
            my $includeTopics;
            my $topicFilter;
            my $excludeTopics;
            $excludeTopics =
              Foswiki::Search::InfoCache::convertTopicPatternToRegex(
                $options->{excludeTopics} )
              if ( $options->{excludeTopics} );

            if ( $options->{includeTopics} ) {

                # E.g. "Bug*, *Patch" ==> "^(Bug.*|.*Patch)$"
                $includeTopics =
                  Foswiki::Search::InfoCache::convertTopicPatternToRegex(
                    $options->{includeTopics} );

                if ($casesensitive) {
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
    }
    else {

        # Foswiki > 1.1

        @ISA = ('Foswiki::Store::Interfaces::QueryAlgorithm');

        *getListOfWebs =
          \&Foswiki::Store::Interfaces::QueryAlgorithm::getListOfWebs;
        *getOptionFilter = \&Foswiki::Search::InfoCache::getOptionFilter;
    }
}

=begin TML

---++ ClassMethod new( $class,  ) -> $cereal

=cut

sub new {
    my $self = shift()->SUPER::new( 'SEARCH', @_ );
    return $self;
}

# See Foswiki::Query::QueryAlgorithms.pm for details
sub query {
    my ( $this, $query, $topics, $session, $options ) = @_;
    unless (
        UNIVERSAL::isa(
            $this, 'Foswiki::Store::QueryAlgorithms::DBIStoreContrib'
        )
      )
    {

        # Sven changed the API to OO based to allow re-use of
        # boilerplate version of query sub(). In the process he broke
        # it for 1.1 :-( This is the repair.
        $this = undef;
        ( $query, $topics, $session, $options ) = @_;
    }

    print STDERR "Initial query: " . $query->stringify() . "\n" if MONITOR;

    # Fold constants
    my $context = Foswiki::Meta->new( $session, $session->{webName} );

    #    $query->simplify( tom => $context, data => $context );
    #    print STDERR "Simplified to: " . $query->stringify() . "\n" if MONITOR;

    my $isAdmin = $session->{users}->isAdmin( $session->{user} );

    # First make a list of interesting webs
    my $webNames = $options->{web}       || '';
    my $recurse  = $options->{'recurse'} || '';
    my $searchAllFlag = ( $webNames =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );
    my @webs = getListOfWebs( $webNames, $recurse, $searchAllFlag );

    my %hoist_control;

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
            push( @{ $hoist_control{iwebs} }, $web );
        }
    }

    # Got to be something worth searching for
    return [] unless scalar( @{ $hoist_control{iwebs} } );

    if ($topics) {

        # Deprecated
        if ( $topics->hasNext() ) {
            $hoist_control{itopics} = [ $topics->all() ];
        }
    }
    elsif ( $options->{includeTopics} ) {
        $hoist_control{itopics} = $options->{includeTopics};
    }

    if ( $options->{excludeTopics} ) {
        $hoist_control{etopics} = $options->{excludeTopics};
    }
    $hoist_control{table} = 'topic';

    # Try and hoist regular expressions out of the query that we
    # can use to refine the topic set

    require Foswiki::Contrib::DBIStoreContrib::HoistSQL;
    $query = Foswiki::Contrib::DBIStoreContrib::HoistSQL::rewrite($query);
    Foswiki::Contrib::DBIStoreContrib::HoistSQL::reorder( $query, \$query );
    print STDERR "Rewritten "
      . Foswiki::Contrib::DBIStoreContrib::HoistSQL::recreate($query) . "\n"
      if MONITOR;
    my $sql = 'SELECT web,name FROM topic WHERE '
      . Foswiki::Contrib::DBIStoreContrib::HoistSQL::hoist( $query,
        \%hoist_control )
      . ' ORDER BY web,name';

    $query = undef;    # not needed any more
    print STDERR "Generated SQL: $sql\n" if MONITOR;

    my $topicSet =
      Foswiki::Contrib::DBIStoreContrib::DBIStore::DBI_query( $session, $sql );
    my $filter = getOptionFilter($options);

    # Collate results into one-per-web result sets to mimic the old
    # per-web search behaviour.
    my %results;
    foreach my $webtopic (@$topicSet) {
        my ( $Iweb, $topic ) =
          $Foswiki::Plugins::SESSION->normalizeWebTopicName( undef, $webtopic );

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
    my $resultset = new Foswiki::Search::ResultSet(
        [ map { $results{$_} } sort( keys(%results) ) ],
        $options->{groupby}, $options->{order},
        Foswiki::isTrue( $options->{reverse} ) );

    #TODO: $options should become redundant
    $resultset->sortResults($options);

    return $resultset unless ($this);    # Foswiki 1.1

    # Foswiki 1.2 and later....
    # Add permissions check
    $resultset = $this->addACLFilter( $resultset, $options );

    # Add paging if applicable.
    return $this->addPager( $resultset, $options );
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

Copyright (C) 2010-2014 Foswiki Contributors. Foswiki Contributors
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
