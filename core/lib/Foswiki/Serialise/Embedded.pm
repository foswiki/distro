# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Serialise::Embedded

This is __the__ on disk format serialiser and deserialise for TWiki and Foswiki topics legacy .txt format.

__WARNING__ this is only for Foswiki::Meta objects.

=cut

package Foswiki::Serialise::Embedded;

use strict;
use warnings;
use Foswiki       ();
use Foswiki::Meta ();
use Assert;

=begin TML

---++ ClassMethod new( $class,  ) -> $cereal

=cut

sub new {
    my $class = shift;
    my $this = bless( {}, $class );
    return $this;
}

sub write {
    my $module = shift;
    my ( $session, $result ) = @_;

    ASSERT( $result->isa('Foswiki::Meta') ) if DEBUG;
    return getEmbeddedStoreForm($result);
}

#really awkward - setEmbeddedStoreForm interleaves reading from text and calling Meta calls to update cache information
#need to separate these out in a performant way.
sub read {
    die 'not implemented';
    my $module = shift;
    my ( $session, $result ) = @_;

    ASSERT( $result->isa('Foswiki::Meta') ) if DEBUG;
    return setEmbeddedStoreForm($result);
}

=begin TML

---++ ObjectMethod getEmbeddedStoreForm() -> $text

Generate the embedded store form of the topic. The embedded store
form has meta-data values embedded using %META: lines. The text
stored in the meta is taken as the topic text.

TODO: Soooo.... if we wanted to make a meta->setPreference('VARIABLE', 'Values...'); we would have to change this to
   1 see if that preference is set in the {_text} using the    * Set syntax, in which case, replace that
   2 or let the META::PREF.. work as it does now..
   
yay :/

TODO: can we move this code into Foswiki::Serialise ?

=cut

sub getEmbeddedStoreForm {
    my $this = shift;

    ASSERT( $this->{_web} && $this->{_topic}, 'this is not a topic object' )
      if DEBUG;
    $this->{_text} ||= '';

    require Foswiki::Store;    # for encoding

    my $ti = $this->get('TOPICINFO');
    delete $ti->{rev} if $ti;    # don't want this written

    my $text = _writeTypes( $this, 'TOPICINFO', 'TOPICPARENT' );
    $text .= $this->{_text};
    my $end =
      _writeTypes( $this, 'FORM', 'FIELD', 'FILEATTACHMENT', 'TOPICMOVED' )
      . _writeTypes( $this, 'not', 'TOPICINFO', 'TOPICPARENT', 'FORM', 'FIELD',
        'FILEATTACHMENT', 'TOPICMOVED' );
    $text .= "\n" if $end;

    $ti->{rev} = $ti->{version} if $ti;

    return $text . $end;
}

# PRIVATE STATIC Write a meta-data key=value pair
# The encoding is reversed in _readKeyValues
sub _writeKeyValue {
    my ( $key, $value ) = @_;

    if ( defined($value) ) {
        $value = dataEncode($value);
    }
    else {
        $value = '';
    }

    return $key . '="' . $value . '"';
}

# PRIVATE STATIC: Write all the key=value pairs for the types listed
sub _writeTypes {
    my ( $this, @types ) = @_;

    my $text = '';

    if ( $types[0] eq 'not' ) {

        # write all types that are not in the list
        my %seen;
        @seen{@types} = ();
        @types = ();    # empty "not in list"
        foreach my $key ( keys %$this ) {
            push( @types, $key )
              unless ( exists $seen{$key} || $key =~ /^_/ );
        }
    }

    foreach my $type (@types) {
        next if ( $type =~ /^_/ );
        my $data = $this->{$type};
        next if !defined $data;
        foreach my $item (@$data) {
            next if ( $item =~ /^_/ );
            my $sep = '';
            $text .= '%META:' . $type . '{';
            my $name = $item->{name};
            if ($name) {

                # If there's a name field, put first to make regexp
                # based searching easier
                $text .= _writeKeyValue( 'name', $item->{name} );
                $sep = ' ';
            }
            foreach my $key ( sort keys %$item ) {

                #next if ($key =~ /^_/ );
                if ( $key ne 'name' ) {
                    $text .= $sep;
                    $text .= _writeKeyValue( $key, $item->{$key} );
                    $sep = ' ';
                }
            }
            $text .= '}%' . "\n";
        }
    }

    return $text;
}

=begin TML

---++ StaticMethod dataEncode( $uncoded ) -> $coded

Encode meta-data field values, escaping out selected characters.
The encoding is chosen to avoid problems with parsing the attribute
values in embedded meta-data, while minimising the number of
characters encoded so searches can still work (fairly) sensibly.

The encoding has to be exported because Foswiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataEncode {
    my $datum = shift;

    $datum =~ s/([%"\r\n{}])/'%'.sprintf('%02x',ord($1))/ge;
    return $datum;
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
