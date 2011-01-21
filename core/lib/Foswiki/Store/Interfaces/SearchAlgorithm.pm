# See bottom of file for license and copyright information
package Foswiki::Store::Interfaces::SearchAlgorithm;

use strict;
use warnings;
use Assert;

use Foswiki            ();
use Foswiki::Plugins   ();
use Foswiki::Sandbox   ();
use Foswiki::WebFilter ();
use Foswiki::Meta      ();

=begin TML

---+ package Foswiki::Store::Interfaces::SearchAlgorithm

Interface to search algorithms.
Implementations of this interface are found in Foswiki/Store/SearchAlgorithms.

---++ StaticMethod query( $query, $webs, $inputTopicSet, $session, $options ) -> $infoCache
   * =$query= - A Foswiki::Search::Node object. The tokens() method of
     this object returns the list of search tokens.
   * =$web= - name of the web being searched, or may be an array reference
              to a set of webs to search
   * =$inputTopicSet= - iterator over names of topics in that web to search
   * =$session= - reference to the store object
   * =$options= - hash of requested options
This is the top-level interface to a search algorithm.

Return a Foswiki::Search::ResultSet.

=cut

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
            $web =~ s#\.#/#go;

            # the web processing loop filters for valid web names,
            # so don't do it here.
            if ( $web =~ s/^-// ) {
                $excludeWeb{$web} = 1;
            }
            else {
                if (   $web =~ /^(all|on)$/i
                    || $Foswiki::cfg{EnableHierarchicalWebs}
                    && Foswiki::isTrue($recurse) )
                {
                    my $webObject;
                    my $prefix = "$web/";
                    if ( $web =~ /^(all|on)$/i ) {
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
                          unless $Foswiki::WebFilter::user_allowed->ok(
                            $session, $w );
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
                  unless $Foswiki::WebFilter::user_allowed->ok( $session, $w );
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

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
