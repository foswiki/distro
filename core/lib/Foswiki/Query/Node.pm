# See bottom of file for copyright and license details

=begin TML

---+ package Foswiki::Query

A Query object is a representation of a query over the Foswiki database.

Fields are given by name, and values by strings or numbers. Strings should always be surrounded by 'single-quotes'. Numbers can be signed integers or decimals. Single quotes in values may be escaped using backslash (\).

See %SYSTEMWEB%.QuerySearch for details of the query language. At the time of writing
only a subset of the entire query language is supported, for use in searching.

A query object implements the =evaluate= method as its general
contract with the rest of the world. This method does a "hard work" evaluation
of the parser tree. Of course, smarter Store implementations should be
able to do it better....

=cut

package Foswiki::Query::Node;
use base 'Foswiki::Infix::Node';

use Assert;
use Error qw( :try );

# 1 for debug
sub MONITOR_EVAL { 0 }

=begin TML

---++ PUBLIC $aliases
A hash mapping short aliases for META: entry names. For example, this hash
maps 'form' to 'META:FORM'. Published so extensions can extend the range
of supported types.

---++ PUBLIC %isArrayType
Maps META: entry type names to true if the type is an array type (such as
FIELD, ATTACHMENT or PREFERENCE). Published so extensions can extend the range
or supported types. The type name should be given without the leading 'META:'

=cut

use vars qw ( %aliases %isArrayType );

%aliases = (
    attachments => 'META:FILEATTACHMENT',
    fields      => 'META:FIELD',
    form        => 'META:FORM',
    info        => 'META:TOPICINFO',
    moved       => 'META:TOPICMOVED',
    parent      => 'META:TOPICPARENT',
    preferences => 'META:PREFERENCE',
);

%isArrayType =
  map { $_ => 1 } qw( FILEATTACHMENT FIELD PREFERENCE );

# $data is the indexed object
# $field is the scalar being used to index the object
sub _getField {
    my ( $this, $data, $field ) = @_;

    my $result;
    if ( UNIVERSAL::isa( $data, 'Foswiki::Meta' ) ) {

        # The object being indexed is a Foswiki::Meta object, so
        # we have to use a different approach to treating it
        # as an associative array. The first thing to do is to
        # apply our "alias" shortcuts.
        my $realField = $field;
        if ( $aliases{$field} ) {
            $realField = $aliases{$field};
        }
        if ( $realField =~ s/^META:// ) {
            if ( $isArrayType{$realField} ) {

                # Array type, have to use find
                my @e = $data->find($realField);
                $result = \@e;
            }
            else {
                $result = $data->get($realField);
            }
        }
        elsif ( $realField eq 'name' ) {

            # Special accessor to compensate for lack of a topic
            # name anywhere in the saved fields of meta
            return $data->topic();
        }
        elsif ( $realField eq 'text' ) {

            # Special accessor to compensate for lack of the topic text
            # name anywhere in the saved fields of meta
            return $data->text();
        }
        elsif ( $realField eq 'web' ) {

            # Special accessor to compensate for lack of a web
            # name anywhere in the saved fields of meta
            return $data->web();
        }
        else {

            # The field name isn't an alias, check to see if it's
            # the form name
            my $form = $data->get('FORM');
            if ( $form && $field eq $form->{name} ) {

                # SHORTCUT;it's the form name, so give me the fields
                # as if the 'field' keyword had been used.
                # TODO: This is where multiple form support needs to reside.
                # Return the array of FIELD for further indexing.
                my @e = $data->find('FIELD');
                return \@e;
            }
            else {

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
            foreach my $f (@$data) {
                my $val = $this->_getField( $f, $field );
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
        $result = $data->{ $this->{params}[0] };
    }
    else {
        $result = $this->{params}[0];
    }
    return $result;
}

# <DEBUG SUPPORT>
sub toString {
    my ($a) = @_;
    return 'undef' unless defined($a);
    if ( ref($a) eq 'ARRAY' ) {
        return '[' . join( ',', map { toString($_) } @$a ) . ']';
    }
    elsif ( UNIVERSAL::isa( $a, 'Foswiki::Meta' ) ) {
        return $a->stringify();
    }
    elsif ( ref($a) eq 'HASH' ) {
        return
          '{'
          . join( ',', map { "$_=>" . toString( $a->{$_} ) } keys %$a ) . '}';
    }
    else {
        return $a;
    }
}

my $ind = 0;

# </DEBUG SUPPORT>

# Evalute this node by invoking the operator function named in the 'exec'
# field of the operator. The return result is either an array ref (for many
# results) or a scalar (for a single result)
sub evaluate {
    my $this = shift;
    ASSERT( scalar(@_) % 2 == 0 );
    my $result;

    print STDERR ( '-' x $ind ) . $this->stringify() if MONITOR_EVAL;

    if ( !ref( $this->{op} ) ) {
        my %domain = @_;
        if ( $this->{op} == $Foswiki::Infix::Node::NAME
            && defined $domain{data} )
        {

            # a name; look it up in clientData
            $result = $this->_getField( $domain{data}, $this->{params}[0] );
        }
        else {
            $result = $this->{params}[0];
        }
    }
    else {
        print STDERR " {\n" if MONITOR_EVAL;
        $ind++ if MONITOR_EVAL;
        $result = $this->{op}->evaluate( $this, @_ );
        $ind-- if MONITOR_EVAL;
        print STDERR ( '-' x $ind ) . '}' if MONITOR_EVAL;
    }
    print STDERR ' -> ', toString($result), "\n" if MONITOR_EVAL;

    return $result;
}

1;
__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
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
