# See bottom of file for license and copyright information
package Foswiki::Store::Interfaces::QueryAlgorithm;

use constant MONITOR => 0;

=begin TML

---+ package Foswiki::Store::Interfaces::QueryAlgorithm

Interface to query algorithms.
Implementations of this interface are found in Foswiki/Store/QueryAlgorithms.

The contract with query algorithms is specified by this interface description,
plus the 'query' unit tests in Fn_SEARCH.
The interface provides a default implementation of the 'getField' method,
but all other methods are pure virtual and must be provided by subclasses.
Note that if a subclass re-implements getField, then there is no direct
need to inherit from this class (as long as all the methods are implemented).

---++ StaticMethod query( $query, $webs, $inputTopicSet, $session, $options ) -> $infoCache
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
    if ( UNIVERSAL::isa( $data, 'Foswiki::Meta' ) ) {

        # The object being indexed is a Foswiki::Meta object, so
        # we have to use a different approach to treating it
        # as an associative array. The first thing to do is to
        # apply our "alias" shortcuts.
        my $realField = $field;
        if ( $Foswiki::Query::Node::aliases{$field} ) {
            $realField = $Foswiki::Query::Node::aliases{$field};
        }
        if ( $realField eq 'META:TOPICINFO' ) {

            # Ensure the revision info is populated from the store
            $data->getRevisionInfo();
        }
        if ( $realField =~ s/^META:// ) {
            if ( $Foswiki::Query::Node::isArrayType{$realField} ) {

                # Array type, have to use find
                my @e = $data->find($realField);
                $result = \@e;
            }
            else {
                $result = $data->get($realField);
            }
        }
        elsif ( $realField eq 'versions' ) {
print STDERR "----- getField(versions)\n" if MONITOR;
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
        elsif ( $realField eq 'name' ) {
print STDERR "----- getField(name)\n" if MONITOR;

            # Special accessor to compensate for lack of a topic
            # name anywhere in the saved fields of meta
            return $data->topic();
        }
        elsif ( $realField eq 'text' ) {
print STDERR "----- getField(text)\n" if MONITOR;

            # Special accessor to compensate for lack of the topic text
            # name anywhere in the saved fields of meta
            return $data->text();
        }
        elsif ( $realField eq 'web' ) {
print STDERR "----- getField(web)\n" if MONITOR;

            # Special accessor to compensate for lack of a web
            # name anywhere in the saved fields of meta
            return $data->web();
        }
        elsif ( $realField eq ':topic_meta:' ) {
print STDERR "----- getField(:topic_meta:)\n" if MONITOR;

            #TODO: Sven expects this to be replaced with a fast call to verions[0] - atm, thats needlessly slow
            # return the meta obj itself
            #actually should do this the way the versions feature is supposed to return a particular one..
            return $data;
        }
        elsif ( $data->topic() ) {

            # The field name isn't an alias, check to see if it's
            # the form name
            my $form = $data->get('FORM');
            if ( $form && $field eq $form->{name} ) {
print STDERR "----- getField(FORM: $field)\n" if MONITOR;

                # SHORTCUT;it's the form name, so give me the fields
                # as if the 'field' keyword had been used.
                # TODO: This is where multiple form support needs to reside.
                # Return the array of FIELD for further indexing.
                my @e = $data->find('FIELD');
                return \@e;
            }
            else {
 if (MONITOR) {
    print STDERR "----- getField(FIELD value $field)\n" if MONITOR;
    use Data::Dumper;
    print STDERR Dumper($data)."\n";
 
 }

                # SHORTCUT; not a predefined name; assume it's a field
                # 'name' instead.
                # SMELL: Needs to error out if there are multiple forms -
                # or perhaps have a heuristic that gives access to the
                # uniquely named field.
                $result = $data->get( 'FIELD', $field );
                $result = $result->{value} if $result;
            }
        }
    }
    elsif ( ref($data) eq 'ARRAY' ) {

        # Array objects are returned during evaluation, e.g. when
        # a subset of an array is matched for further processing.

        # Indexing an array object. The index will be one of:
        # 1. An integer, which is an implicit index='x' query
        # 2. A name, which is an implicit name='x' query
        if ( $field =~ /^\d+$/ ) {
print STDERR "----- getField(index $field)\n" if MONITOR;

            # Integer index
            $result = $data->[$field];
        }
        else {

            # String index
            my @res;

            # Get all array entries that match the field
            foreach my $f (@$data) {
                my $val = $this->getField( $node, $f, $field );
                push( @res, $val ) if defined($val);
            }
            if ( scalar(@res) ) {
                $result = \@res;
            }
            else {

                # The field name wasn't explicitly seen in any of the records.
                # Try again, this time matching 'name' and returning 'value'
                foreach my $f (@$data) {
                    next unless ref($f) eq 'HASH';
                    if (   $f->{name}
                        && $f->{name} eq $field
                        && defined $f->{value} )
                    {
                        push( @res, $f->{value} );
                    }
                }
                if ( scalar(@res) ) {
                    $result = \@res;
                }
            }
        }
    }
    elsif ( ref($data) eq 'HASH' ) {
print STDERR "----- getField(HASH ".$node->{params}[0].")\n" if MONITOR;

        # A hash object may be returned when a sub-object of a Foswiki::Meta
        # object has been matched.
        $result = $data->{ $node->{params}[0] };
    }
    else {
print STDERR "----- getField(value ".$node->{params}[0].")\n" if MONITOR;
    
        $result = $node->{params}[0];
    }
    return $result;
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
print STDERR "----- getRefTopic($w, $t) -> ".($meta->getLoadedRev())."\n" if MONITOR;
    return $meta;
}

1;
__END__

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
