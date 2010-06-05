# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::QueryAlgorithms

Interface to query algorithms (documentation only, this class does nothing).
Implementations of this interface are found in Foswiki/Store/QueryAlgorithms.

The contract with query algorithms is specified by this interface description,
plus the 'query' unit tests in Fn_SEARCH.

---++ StaticMethod query( $query, $web, $inputTopicSet, $session, $options ) -> $infoCache
   * =$query= - A Foswiki::Query::Node object
   * =$web= - name of the web being searched
   * =$inputTopicSet= - list of topics in that web to search
   * =$session= - reference to the store object
   * =$options= - hash of requested options
This is the top-level interface to a query algorithm. A store module can call
this method to start the 'hard work' query process. That process will call
back to the =getField= method in this module to evaluate leaf data in the
store.

To monitor the evaluation process, use the MONITOR_EVAL setting in
Foswiki::Query::Node

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

---++ StaticMethod getRefTopic($class, $relativeTo, $web, $topic) -> $topic
   * =$class= is this package
   * =$relativeTo= is a pointer into the data structure of this module where
     the ref is relative to; for example, in the expression
     "other/'Web.Topic'" then =$relativeTo= is =other=.
   * =$web= the web; =Web= in the above example
   * =$topic= the topic; =Topic= in the above example
This method supports the =Foswiki::Query::OP_ref= operator by abstracting the
loading of a topic referred to using the '/' operator. For more information
on the '/' operator, see System.QuerySearch.

=cut

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
