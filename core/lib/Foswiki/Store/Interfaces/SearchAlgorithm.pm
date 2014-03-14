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

use Foswiki::Store::Interfaces::QueryAlgorithm ();
our @ISA = ('Foswiki::Store::Interfaces::QueryAlgorithm');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---+ package Foswiki::Store::Interfaces::SearchAlgorithm

DEPRECATED - all SearchAlgorithm and QueryAlgorithm use the same calling convention.

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
