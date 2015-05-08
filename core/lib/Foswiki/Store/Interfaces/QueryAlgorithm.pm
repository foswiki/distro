# See bottom of file for license and copyright information
package Foswiki::Store::Interfaces::QueryAlgorithm;

use strict;
use warnings;
use Assert;

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
use Foswiki::Iterator::PagerIterator();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

use constant MONITOR => 0;

=begin TML

---+ package Foswiki::Store::Interfaces::QueryAlgorithm

Interface to query algorithms.
Implementations of this interface are found in Foswiki/Store/*Algorithms.

The contract with query algorithms is specified by this interface description,
plus the 'query' unit tests in Fn_SEARCH.
The interface provides a default implementation of the 'getField' method,
but all other methods are pure virtual and must be provided by subclasses.
Note that if a subclass re-implements getField, then there is no direct
need to inherit from this class (as long as all the methods are implemented).

=cut

=begin TML

---++ ClassMethod new( $class,  ) -> $cereal

=cut

sub new {
    my $class = shift;
    my $this = bless( {}, $class );
    return $this;
}

=begin TML

---++ ObjectMethod query( $query, $webs, $inputTopicSet, $session, $options ) -> $infoCache
   * =$query= - A Foswiki::Query::Node object
   * =$web= - name of the web being searched, or may be an array reference
              to a set of webs to search
   * =$inputTopicSet= - iterator over names of topics in that web to search
   * =$session= - reference to the store object
   * =$options= - hash of requested options
This is the top-level interface to a query algorithm. A store module can call
this method to start the 'hard work' query process. That process will call
back to the =getField= method in this module to evaluate leaf data in the
store.

To monitor the hoisting and evaluation processes, use the MONITOR_EVAL
setting in Foswiki::Query::Node

this is a default implementation of the query() sub that uses the specific algorithms' _webQuery member function.

=cut

sub query {
    my ( $this, $query, $inputTopicSet, $session, $options ) = @_;

    if ( $query->isEmpty() )
    {    #TODO: does this do anything in a type=query context?
         #Note: Must return an empty results set, including pager, to avoid crash. Item13383
        my $resultset =
          new Foswiki::Search::ResultSet( [], $options->{groupby},
            $options->{order}, Foswiki::isTrue( $options->{reverse} ) );
        return $this->addPager( $resultset, $options );
    }

    my $date = $options->{'date'} || '';

    # Fold constants
    my $context = Foswiki::Meta->new( $session, $session->{webName} );
    print STDERR "--- before: " . $query->stringify() . "\n" if MONITOR;
    $query->simplify( tom => $context, data => $context );
    print STDERR "--- simplified: " . $query->stringify() . "\n" if MONITOR;

    my $webItr = $this->getWebIterator( $session, $options );

    #do the search
    my $queryItr = Foswiki::Iterator::ProcessIterator->new(
        $webItr,
        sub {
            my $web    = shift;
            my $params = shift;

            my $infoCache =
              $this->_webQuery( $params->{query}, $web, $params->{inputset},
                $params->{session}, $params->{options} );

            if ($date) {
                $infoCache->filterByDate($date);
            }

            return $infoCache;
        },
        {
            query    => $query,
            inputset => $inputTopicSet,
            session  => $session,
            options  => $options
        }
    );

#sadly, the resultSet currently wants a real array, rather than an unevaluated web iterator
    my @resultCacheList = $queryItr->all();

#and thus if the ResultSet could be created using an unevaluated process itr, which would somehow rely on........ eeeeek
    my $resultset =
      new Foswiki::Search::ResultSet( \@resultCacheList, $options->{groupby},
        $options->{order}, Foswiki::isTrue( $options->{reverse} ) );

    #add permissions check
    $resultset = $this->addACLFilter( $resultset, $options );

    #sort as late as possible
    $resultset->sortResults($options);

    #add paging if applicable.
    $this->addPager( $resultset, $options );
}

sub addPager {
    my $this      = shift;
    my $resultset = shift;
    my $options   = shift;

    if ( $options->{paging_on} ) {
        $resultset =
          new Foswiki::Iterator::PagerIterator( $resultset,
            $options->{pagesize}, $options->{showpage} );
    }

    return $resultset;
}

sub addACLFilter {
    my $this      = shift;
    my $resultset = shift;
    my $options   = shift;

    #add filtering for ACL test - probably should make it a seperate filter
    $resultset = new Foswiki::Iterator::FilterIterator(
        $resultset,
        sub {
            my $listItem = shift;
            my $params   = shift;

            #ACL test
            my ( $web, $topic ) =
              Foswiki::Func::normalizeWebTopicName( '', $listItem );

            my $topicMeta =
              $Foswiki::Plugins::SESSION->search->metacache->addMeta( $web,
                $topic );
            if ( not defined($topicMeta) ) {

#TODO: OMG! Search.pm relies on Meta::load (in the metacache) returning a meta object even when the topic does not exist.
#lets change that
                $topicMeta =
                  new Foswiki::Meta( $Foswiki::Plugins::SESSION, $web, $topic );
            }
            my $info =
              $Foswiki::Plugins::SESSION->search->metacache->get( $web, $topic,
                $topicMeta );
            ##ASSERT( defined( $info->{tom} ) ) if DEBUG;

# Check security (don't show topics the current user does not have permission to view)
            return 0 unless ( $info->{allowView} );
            return 1;
        },
        $options
    );
}

sub getWebIterator {
    my $this    = shift;
    my $session = shift;
    my $options = shift;

    my $webNames = $options->{web}       || '';
    my $recurse  = $options->{'recurse'} || '';
    my $isAdmin  = $session->{users}->isAdmin( $session->{user} );

    #get a complete list of webs to search
    my $searchAllFlag = ( $webNames =~ m/(^|[\,\s])(all|on)([\,\s]|$)/i );
    my @webs =
      Foswiki::Store::Interfaces::QueryAlgorithm::getListOfWebs( $webNames,
        $recurse, $searchAllFlag );
    my $rawWebIter = new Foswiki::ListIterator( \@webs );
    my $webItr     = new Foswiki::Iterator::FilterIterator(
        $rawWebIter,
        sub {
            my $web    = shift;
            my $params = shift;

            # can't process what ain't thar
            return 0 unless $session->webExists($web);

            my $webObject = Foswiki::Meta->new( $session, $web );
            my $thisWebNoSearchAll =
              Foswiki::isTrue( $webObject->getPreference('NOSEARCHALL') );

            # make sure we can report this web on an 'all' search
            # DON'T filter out unless it's part of an 'all' search.
            return 0
              if ( $searchAllFlag
                && !$isAdmin
                && ( $thisWebNoSearchAll || $web =~ m/^[\.\_]/ )
                && $web ne $session->{webName} );
            return 1;
        },
        {}
    );
}

=begin TML

---++ StaticMethod getField($class, $node, $data, $field ) -> $result
   * =$class= is this package
   * =$node= is the query node
   * =$data= is the indexed object
   * =$field= is the scalar being used to index the object
=getField= is used by the query evaluation code in Foswiki::Query::Node to get
information about a leaf node, or 'field'. A field can be a name, or a literal,
and the information it refers to can be a scalar, a reference to a hash, or
a reference to an array. The exact interpretation of fields is
context-dependant, according to reasonably complex rules best documented by
the Fn_SEARCH unit test and System.QuerySearch.

The function must map the query schema to whatever the underlying
store uses to store a topic. See System.QuerySearch for more information
on the query schema.

=cut

# Implements Foswiki::Store::Interfaces::QueryAlgorithm
sub getField {

    # The getField function allows for Store specific optimisations
    # such as direct database lookups. The default implementation
    # works with the Foswiki::Meta object.
    my ( $this, $node, $data, $field ) = @_;

    my $result;
    ASSERT( UNIVERSAL::isa( $data, 'Foswiki::Meta' ) ) if DEBUG;

    print STDERR "\n----- getField($field)\n" if MONITOR;

    if ( $field eq 'META:VERSIONS' ) {

        # Disallow reloading versions for an object loaded here
        # SMELL: violates Foswiki::Meta encapsulation
        return [] if $data->{_loadedByQueryAlgorithm};

        # Oooh, this is inefficient.
        my $it = $data->getRevisionHistory();
        my @revs;
        while ( $it->hasNext() ) {
            my $n = $it->next();
            my $t =
              $this->getRefTopic( $data, $data->web(), $data->topic(), $n );
            $t->{_loadedByQueryAlgorithm} = 1;
            push( @revs, $t );
        }
        return \@revs;
    }

    if ( $field =~ s/^META:// ) {
        if ( $field eq 'TOPICINFO' ) {

            # Ensure the revision info is populated from the store
            $data->getRevisionInfo();
        }

        if ( $Foswiki::Query::Node::isArrayType{$field} ) {

            # Array type, have to use find
            my @e = $data->find($field);
            return \@e;
        }
        return $data->get($field);
    }

    if ( $field eq 'name' ) {

        # Special accessor to compensate for lack of a topic
        # name anywhere in the saved fields of meta
        return $data->topic();
    }

    if ( $field eq 'text' ) {

        # Special accessor to compensate for lack of the topic text
        # name anywhere in the saved fields of meta
        return $data->text();
    }

    if ( $field eq 'web' ) {

        # Special accessor to compensate for lack of a web
        # name anywhere in the saved fields of meta
        return $data->web();
    }

    if ( $field eq ':topic_meta:' ) {

        #TODO: Sven expects this to be replaced with a fast call to
        # versions[0] - atm, thats needlessly slow
        # return the meta obj itself
        # actually should do this the way the versions feature is
        # supposed to return a particular one..
        # SMELL: CDot can't work out what this is for....
        return $data;
    }

    return undef unless $data->topic();

    if (MONITOR) {
        print STDERR "----- getField(FIELD value $field)\n";
        use Data::Dumper;
        print STDERR Dumper($data) . "\n";
    }

    # SHORTCUT; not a predefined name; assume it's a field
    # 'name' instead.
    $result = $data->get( 'FIELD', $field );
    $result = $result->{value} if $result;
    return $result;
}

=begin TML

---++ StaticMethod getForm($class, $node, $data, $field ) -> $result
   * =$class= is this package
   * =$node= is the query node
   * =$data= is the indexed object (must be Foswiki::Meta)
   * =$formname= is the required form name

=cut

sub getForm {
    my ( $this, $node, $data, $formname ) = @_;
    return undef unless $data->topic();

    my $form = $data->get('FORM');
    return undef unless $form && $formname eq $form->{name};
    print STDERR "----- getForm($formname)\n" if MONITOR;

    # TODO: This is where multiple form support needs to reside.
    # Return the array of FIELD for further indexing.
    my @e = $data->find('FIELD');
    return \@e;
}

=begin TML

---++ StaticMethod getRefTopic($class, $relativeTo, $web, $topic, $rev) -> $topic
   * =$class= is this package
   * =$relativeTo= is a pointer into the data structure of this module where
     the ref is relative to; for example, in the expression
     "other/'Web.Topic'" then =$relativeTo= is =other=.
   * =$web= the web; =Web= in the above example
   * =$topic= the topic; =Topic= in the above example
   * =$rev= optional revision to load
This method supports the =Foswiki::Query::OP_ref= and =Foswiki::Query::OP_at=
operators by abstracting the loading of a topic referred to in a string.

=cut

# Default implements gets a new Foswiki::Meta
sub getRefTopic {

    # Get a referenced topic
    my ( $this, $relativeTo, $w, $t, $rev ) = @_;
    my $meta = Foswiki::Meta->load( $relativeTo->session, $w, $t, $rev );
    print STDERR "----- getRefTopic($w, $t) -> "
      . ( $meta->getLoadedRev() ) . "\n"
      if MONITOR;
    return $meta;
}

=begin TML

---++ StaticMethod getRev1Info($meta) -> %info

Return revision info for the first revision in %info with at least:
   * ={date}= in epochSec
   * ={author}= canonical user ID
   * ={version}= the revision number

=cut

# Default implements gets a new Foswiki::Meta
sub getRev1Info {
    my $this = shift;
    my $meta = shift;

    my $wikiname = $meta->getRev1Info('createwikiname');
    return $meta->{_getRev1Info}->{rev1info};
}

=begin TML

---+ getListOfWebs($webnames, $recurse, $serachAllFlag) -> @webs

Convert a comma separated list of webs into the list we'll process
TODO: this is part of the Store now, and so should not need to reference
Meta - it rather uses the store.

=cut

sub getListOfWebs {
    my ( $webName, $recurse, $searchAllFlag ) = @_;
    my $session = $Foswiki::Plugins::SESSION;

    my %excludeWeb;
    my @tmpWebs;

  #$web = Foswiki::Sandbox::untaint( $web,\&Foswiki::Sandbox::validateWebName );

    if ($webName) {
        foreach my $web ( split( /[\,\s]+/, $webName ) ) {
            $web =~ s#\.#/#g;

            # the web processing loop filters for valid web names,
            # so don't do it here.
            if ( $web =~ s/^-// ) {
                $excludeWeb{$web} = 1;
            }
            else {
                if (   $web =~ m/^(all|on)$/i
                    || $Foswiki::cfg{EnableHierarchicalWebs}
                    && Foswiki::isTrue($recurse) )
                {
                    my $webObject;
                    my $prefix = "$web/";
                    if ( $web =~ m/^(all|on)$/i ) {
                        $webObject = Foswiki::Meta->new($session);
                        $prefix    = '';
                    }
                    else {
                        $web = Foswiki::Sandbox::untaint( $web,
                            \&Foswiki::Sandbox::validateWebName );
                        ASSERT($web) if DEBUG;
                        push( @tmpWebs, $web );
                        $webObject = Foswiki::Meta->new( $session, $web );
                    }
                    my $it = $webObject->eachWeb(1);
                    while ( $it->hasNext() ) {
                        my $w = $prefix . $it->next();
                        next
                          unless Foswiki::WebFilter->user_allowed()
                          ->ok( $session, $w );
                        $w = Foswiki::Sandbox::untaint( $w,
                            \&Foswiki::Sandbox::validateWebName );
                        ASSERT($web) if DEBUG;
                        push( @tmpWebs, $w );
                    }
                }
                else {
                    $web = Foswiki::Sandbox::untaint( $web,
                        \&Foswiki::Sandbox::validateWebName );
                    push( @tmpWebs, $web );
                }
            }
        }

    }
    else {

        # default to current web
        my $web =
          Foswiki::Sandbox::untaint( $session->{webName},
            \&Foswiki::Sandbox::validateWebName );
        push( @tmpWebs, $web );
        if ( Foswiki::isTrue($recurse) ) {
            require Foswiki::Meta;
            my $webObject = Foswiki::Meta->new( $session, $session->{webName} );
            my $it =
              $webObject->eachWeb( $Foswiki::cfg{EnableHierarchicalWebs} );
            while ( $it->hasNext() ) {
                my $w = $session->{webName} . '/' . $it->next();
                next
                  unless Foswiki::WebFilter->user_allowed()->ok( $session, $w );
                $w = Foswiki::Sandbox::untaint( $w,
                    \&Foswiki::Sandbox::validateWebName );
                push( @tmpWebs, $w );
            }
        }
    }

    my @webs;
    foreach my $web (@tmpWebs) {
        next unless defined $web;
        push( @webs, $web ) unless $excludeWeb{$web};
        $excludeWeb{$web} = 1;    # eliminate duplicates
    }

    # Default to alphanumeric sort order
    return sort @webs;
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

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
