# Please see the bottom of this file for license and copyright information

=begin TML

---+ package Foswiki::Store::QueryAlgorithms::DBCache

Query algorithm that uses a DBCacheContrib database.
Part of QueryAcceleratorPlugin.

=cut

package Foswiki::Store::QueryAlgorithms::DBCache;
use strict;

#@ISA = ( 'Foswiki::Query::QueryAlgorithms' ); # interface

use Assert;
use Error (':try');

use Foswiki::Query::Node ();

# 1 for debug
sub MONITOR_EVAL { Foswiki::Query::Node::MONITOR_EVAL() }

# See Foswiki::Query::QueryAlgorithms in Foswiki 1.1 or later for details
sub query {
    my ( $query, $web, $topics, $store, $options ) = @_;

    my $db = Foswiki::Plugins::QueryAcceleratorPlugin::getDB($web);
    ASSERT($db) if DEBUG;

    my $is10 = ( ref($topics) eq 'ARRAY' );    # 1.0.x
    my @monkeys;

    if ($is10) {

        # Monkey-patch
        @monkeys = (
            \&Foswiki::Query::Node::evaluate,
            \&Foswiki::Query::OP_ref::evaluate
        );
        no warnings 'redefine';
        *Foswiki::Query::Node::evaluate   = \&_nodeEvaluate;
        *Foswiki::Query::OP_ref::evaluate = \&_op_refEvaluate;
        use warnings 'redefine';
    }

    my %matches;
    if ($is10) {
        foreach my $topic (@$topics) {
            my $meta = $db->fastget($topic);
            next unless $meta;
            print STDERR "Processing $topic\n" if MONITOR_EVAL;
            my $match = $query->evaluate( tom => $meta, data => $meta );
            if ($match) {
                $matches{$topic} = $match;
            }
        }
    }
    else {

        # 1.1 and later
        while ( $topics->hasNext() ) {
            my $topic = $topics->next();
            my $meta  = $db->fastget($topic);
            next unless $meta;
            print STDERR "Processing $topic\n" if MONITOR_EVAL;
            my $match = $query->evaluate( tom => $meta, data => $meta );
            if ($match) {
                $matches{$topic} = $match;
            }
        }
    }

    if ($is10) {

        # Remove the monkey patches
        no warnings 'redefine';
        *Foswiki::Query::Node::evaluate   = $monkeys[0];
        *Foswiki::Query::OP_ref::evaluate = $monkeys[1];
        use warnings 'redefine';

        # 1.0.x and earlier
        return \%matches;
    }
    else {
        require Foswiki::Search::InfoCache;

        my @topics = keys(%matches);
        my $resultTopicSet =
          new Foswiki::Search::InfoCache( $Foswiki::Plugins::SESSION, $web,
            \@topics );
        return $resultTopicSet;
    }
}

# See Foswiki::Query::QueryAlgorithms in Foswiki 1.1 or later for details
sub getField {
    my ( $class, $node, $data, $field ) = @_;

    my $result = undef;

    # The query evaluation process can return either DBCacheContrib maps
    # and arrays (when data in the store is matched) and also standard
    # perl arrays and hashes (when data is filtered, for example). To simplify
    # the following code, we map them all to perl objects, using the fact that
    # DBCacheContrib objects are designed to be tied to.
    if ( UNIVERSAL::isa( $data, 'Foswiki::Contrib::DBCacheContrib::Map' ) ) {
        my %hash;
        tie( %hash, ref($data), existing => $data );
        $data = \%hash;
    }
    elsif ( UNIVERSAL::isa( $data, 'Foswiki::Contrib::DBCacheContrib::Array' ) )
    {
        my @arr;
        tie( @arr, ref($data), existing => $data );
        $data = \@arr;
    }

    if ( ref($data) eq 'ARRAY' ) {

        # Indexing an array object. The index will be one of:
        # 1. An integer, which is an implicit index='x' query
        # 2. A name, which is an implicit name='x' query
        if ( $field =~ /^\d+$/ ) {

            # Integer index
            $result = $data->[$field];
        }
        else {

            # String index
            my @res;

            # Get all array entries that match the field
            for ( my $i = 0 ; $i < scalar(@$data) ; $i++ ) {
                my $f = $data->[$i];
                my $val = getField( undef, $node, $f, $field );
                push( @res, $val ) if defined($val);
            }
            if ( scalar(@res) ) {
                $result = \@res;
            }
            else {

                # The field name wasn't explicitly seen in any of the records.
                # Try again, this time matching 'name' and returning 'value'
                for ( my $i = 0 ; $i < scalar(@$data) ; $i++ ) {
                    my $f = $data->[$i];
                    next
                      unless UNIVERSAL::isa( $f,
                        'Foswiki::Contrib::DBCacheContrib::Map' );
                    my $v;
                    if ( ( $f->FETCH('name') || '' ) eq $field
                        && defined( $v = $f->FETCH('value') ) )
                    {
                        push( @res, $v );
                    }
                }
                if ( scalar(@res) ) {
                    $result = \@res;
                }
            }
        }
    }
    elsif ( ref($data) eq 'HASH' ) {
        my $field     = $node->{params}[0];
        my $realField = $field;

        # Use the presence of the .form_name field to spot a topic
        my $form = $data->{'.form_name'};
        if ( defined $form ) {

            # it's a topic-level map; try mapping the field name
            if ( $form =~ /(^|\.)$field$/ ) {

                # The requested field is the name of the form
                # index the fields array instead of the META:FORM hash.
                $realField = 'META:FIELD';
            }
            elsif ( $Foswiki::Query::Node::aliases{$field} ) {

                # e.g. form -> META:FORM
                $realField = $Foswiki::Query::Node::aliases{$field};
            }
            else {

                # SHORTCUT; assume it's a field 'name'
                my $fields = $data->{'.fields'};
                $result = $fields->FETCH($field);
                if ($result) {
                    $result = $result->FETCH('value');

                    # We know this can't be a structure, so it's safe to
                    # throw back.
                    return $result if defined $result;
                }
            }
        }
        $result = $data->{$realField};

        if (
            UNIVERSAL::isa( $result, 'Foswiki::Contrib::DBCacheContrib::Map' ) )
        {
            my %hash;
            tie( %hash, ref($result), existing => $result );
            $result = \%hash;
        }
        elsif (
            UNIVERSAL::isa(
                $result, 'Foswiki::Contrib::DBCacheContrib::Array'
            )
          )
        {
            my @arr;
            tie( @arr, ref($result), existing => $result );
            $result = \@arr;
        }
    }
    else {
        $result = $node->{params}[0];
    }

    return $result;
}

# See Foswiki::Query::QueryAlgorithms in Foswiki 1.1 or later for details
sub getRefTopic {
    my ( $class, $relativeTo, $w, $t ) = @_;
    return Foswiki::Plugins::QueryAcceleratorPlugin::getDB($w)->fastget($t);
}

###########################################################################
# The following monkey-patching functions are only required for Foswiki 1.0
# Later versions do not need them as the core functions have been generalised
# to the versions given here
###########################################################################

my $ind = 0;

# This should be identical to Foswiki::Query::Node::evaluate in
# Foswiki 1.1. It is provided here for use in monkey-patching Foswiki 1.0.
sub _nodeEvaluate {
    my $node = shift;
    ASSERT( scalar(@_) % 2 == 0 ) if DEBUG;
    my $result;

    print STDERR ( '-' x $ind ) . $node->stringify() if MONITOR_EVAL;

    if ( !ref( $node->{op} ) ) {
        my %domain = @_;
        if ( $node->{op} == $Foswiki::Infix::Node::NAME
            && defined $domain{data} )
        {

            # a name; look it up in $domain{data}
            $result =
              $Foswiki::cfg{RCS}{QueryAlgorithm}
              ->getField( $node, $domain{data}, $node->{params}[0] );
        }
        else {
            $result = $node->{params}[0];
        }
    }
    else {
        print STDERR " {\n" if MONITOR_EVAL;
        $ind++ if MONITOR_EVAL;
        $result = $node->{op}->evaluate( $node, @_ );
        $ind-- if MONITOR_EVAL;
        print STDERR ( '-' x $ind ) . '}' . $node->{op}->{name} if MONITOR_EVAL;
    }
    print STDERR ' -> ' . ( defined $result ? $result : 'undef' ) . "\n"
      if MONITOR_EVAL;

    return $result;
}

# This should be identical to Foswiki::Query::OP_ref::evaluate in
# Foswiki 1.1. It is provided here for use in monkey-patching Foswiki 1.0.
sub _op_refEvaluate {
    my $this   = shift;
    my $pnode  = shift;
    my %domain = @_;

    my $a    = $pnode->{params}[0];
    my $node = $a->evaluate(@_);
    return undef unless defined $node;
    if ( ref($node) eq 'HASH' ) {
        return undef;
    }
    if ( !( ref($node) eq 'ARRAY' ) ) {
        $node = [$node];
    }
    my @result;
    foreach my $v (@$node) {

        # Has to be relative to the web of the topic we are querying
        my ( $w, $t ) =
          $Foswiki::Plugins::SESSION->normalizeWebTopicName(
            $Foswiki::Plugins::SESSION->{webName}, $v );
        my $result = undef;
        try {
            my $submeta =
              $Foswiki::cfg{RCS}{QueryAlgorithm}
              ->getRefTopic( $domain{tom}, $w, $t );
            my $b = $pnode->{params}[1];
            my $res = $b->evaluate( tom => $submeta, data => $submeta );
            if ( ref($res) eq 'ARRAY' ) {
                push( @result, @$res );
            }
            else {
                push( @result, $res );
            }
        }
        catch Error::Simple with {};
    }
    return undef unless scalar(@result);
    return $result[0] if scalar(@result) == 1;
    return \@result;
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
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
# Author: Crawford Currie
