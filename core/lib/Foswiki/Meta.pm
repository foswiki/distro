# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Meta

All topics have *data* (text) and *meta-data* (information about the
topic). Meta-data includes information such as file attachments, form fields,
topic parentage etc. When Foswiki loads a topic from the store, it represents
the meta-data in the topic using an object of this class.

A meta-data object is a hash of different types of meta-data (keyed on
the type, such as 'FIELD' and 'TOPICINFO').

Each entry in the hash is an array, where each entry in the array
contains another hash of the key=value pairs, corresponding to a
single meta-datum.

If there may be multiple entries of the same top-level type (i.e. for FIELD
and FILEATTACHMENT) then the array has multiple entries. These types
are referred to as "keyed" types. The array entries are keyed with the
attribute 'name' which must be in each entry in the array.

For unkeyed types, the array has only one entry.

Pictorially,
   * TOPICINFO
      * author => '...'
      * date => '...'
      * ...
   * FILEATTACHMENT
      * [0] -> { name => '...' ... }
      * [1] -> { name => '...' ... }
   * FIELD
      * [0] -> { name => '...' ... }
      * [1] -> { name => '...' ... }

As well as the meta-data, the object also stores the web name, topic
name and topic text.

API version $Date$ (revision $Rev$)

*Since* _date_ indicates where functions or parameters have been added since
the baseline of the API (TWiki release 4.2.3). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

=cut

package Foswiki::Meta;

use strict;
use Error qw(:try);
use Assert;

our $VERSION = '$Rev$';

=begin TML

---++ ClassMethod new($session, $web, $topic)
   * =$session= - a Foswiki object (e.g. =$Foswiki::Plugins::SESSION=)
   * =$web=, =$topic= - the topic that the metadata relates to
Construct a new, empty object to contain meta-data for the given topic.

=cut

sub new {
    my ( $class, $session, $web, $topic, $text ) = @_;

    # $text - optional raw text to convert to meta-data form
    my $this = bless( { _session => $session }, $class );

    # Note: internal fields are prepended with _. All uppercase
    # fields will be assumed to be meta-data.

    ASSERT($web)   if DEBUG;
    ASSERT($topic) if DEBUG;

    $this->{_web}   = $web;
    $this->{_topic} = $topic;
    $this->{_text}  = '';

    $this->{FILEATTACHMENT} = [];

    if ( defined $text ) {
        $session->{store}->extractMetaData( $this, $text );
    }

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Clean up the object, releasing any memory stored in it.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{_web};
    undef $this->{_topic};
    undef $this->{_text};
    undef $this->{_session};
}

=begin TML

---++ ObjectMethod session()

Get the session associated with the object when it was created.

=cut

sub session {
    return $_[0]->{_session};
}

=begin TML

---++ ObjectMethod web([$name])
   * =$name= - optional, change the web name in the object
      * *Since* 28 Nov 2008
Get/set the web name associated with the object.

=cut

sub web {
    my ( $this, $web ) = @_;
    $this->{_web} = $web if defined $web;
    return $_[0]->{_web};
}

=begin TML

---++ ObjectMethod topic([$name])
   * =$name= - optional, change the topic name in the object
      * *Since* 28 Nov 2008
Get/set the topic name associated with the object.

=cut

sub topic {
    my ( $this, $topic ) = @_;
    $this->{_topic} = $topic if defined $topic;
    return $this->{_topic};
}

=begin TML

---++ ObjectMethod text([$text]) -> $text

Get/set the topic body text. If $text is undef, gets the value, if it is
defined, sets the value to that and returns the new text.

=cut

sub text {
    my ( $this, $val ) = @_;
    if ( defined($val) ) {
        $this->{_text} = $val;
    }
    return $this->{_text};
}

=begin TML

---++ ObjectMethod put($type, \%args)

Put a hash of key=value pairs into the given type set in this meta. This
will *not* replace another value with the same name (for that see =putKeyed=)

For example, 
<verbatim>
$meta->put( 'FIELD', { name => 'MaxAge', title => 'Max Age', value =>'103' } );
</verbatim>

=cut

sub put {
    my ( $this, $type, $args ) = @_;

    my $data = $this->{$type};
    if ($data) {

        # overwrite old single value
        $data->[0] = $args;
    }
    else {
        push( @{ $this->{$type} }, $args );
    }
}

=begin TML

---++ ObjectMethod putKeyed($type, \%args)

Put a hash of key=value pairs into the given type set in this meta, replacing
any existing value with the same key.

For example,
<verbatim>
$meta->putKeyed( 'FIELD', { name => 'MaxAge', title => 'Max Age', value =>'103' } );
</verbatim>

=cut

# Note: Array is used instead of a hash to preserve sequence

sub putKeyed {
    my ( $this, $type, $args ) = @_;

    my $data = $this->{$type};
    if ($data) {
        my $keyName = $args->{name};
        ASSERT($keyName) if DEBUG;
        my $i = scalar(@$data);
        while ( $keyName && $i-- ) {
            if ( defined $data->[$i]->{name}
                   && $data->[$i]->{name} eq $keyName ) {
                $data->[$i] = $args;
                return;
            }
        }
        push @$data, $args;
    }
    else {
        push( @{ $this->{$type} }, $args );
    }
}

=begin TML

---++ ObjectMethod putAll

Replaces all the items of a given key with a new array.

For example,
<verbatim>
$meta->putAll( 'FIELD',
     { name => 'MinAge', title => 'Min Age', value =>'50' },
     { name => 'MaxAge', title => 'Max Age', value =>'103' },
     { name => 'HairColour', title => 'Hair Colour', value =>'white' }
 );
</verbatim>

=cut

sub putAll {
    my ( $this, $type, @array ) = @_;

    $this->{$type} = \@array;
}

=begin TML

---++ ObjectMethod get( $type, $key ) -> \%hash

Find the value of a meta-datum in the map. If the type is
keyed (idenitifed by a =name=), the =$key= parameter is required
to say _which_ entry you want. Otherwise you will just get the first value.

If you want all the keys of a given type use the 'find' method.

The result is a reference to the hash for the item.

For example,
<verbatim>
my $ma = $meta->get( 'FIELD', 'MinAge' );
my $topicinfo = $meta->get( 'TOPICINFO' ); # get the TOPICINFO hash
</verbatim>

=cut

sub get {
    my ( $this, $type, $keyValue ) = @_;

    my $data = $this->{$type};
    if ($data) {
        if ( defined $keyValue ) {
            foreach my $item (@$data) {
                return $item if ($item->{name} and ( $item->{name} eq $keyValue ));
            }
        }
        else {
            return $data->[0];
        }
    }

    return undef;
}

=begin TML

---++ ObjectMethod find (  $type  ) -> @values

Get all meta data for a specific type.
Returns the array stored for the type. This will be zero length
if there are no entries.

For example,
<verbatim>
my $attachments = $meta->find( 'FILEATTACHMENT' );
</verbatim>

=cut

sub find {
    my ( $this, $type ) = @_;

    my $itemsr = $this->{$type};
    my @items  = ();

    if ($itemsr) {
        @items = @$itemsr;
    }

    return @items;
}

=begin TML

---++ ObjectMethod remove($type, $key)

With no type, will remove all the contents of the object.

With a $type but no $key, will remove _all_ items of that type (so for example if $type were FILEATTACHMENT it would remove all of them)

With a $type and a $key it will remove only the specific item.

=cut

sub remove {
    my ( $this, $type, $keyValue ) = @_;

    if ($keyValue) {
        my $data    = $this->{$type};
        my @newData = ();
        foreach my $item (@$data) {
            if ( $item->{name} ne $keyValue ) {
                push @newData, $item;
            }
        }
        $this->{$type} = \@newData;
    }
    elsif ($type) {
        delete $this->{$type};
    }
    else {
        foreach my $entry ( keys %$this ) {
            unless ( $entry =~ /^_/ ) {
                $this->remove($entry);
            }
        }
    }
}

=begin TML

---++ ObjectMethod copyFrom( $otherMeta, $type, $nameFilter )

Copy all entries of a type from another meta data set. This
will destroy the old values for that type, unless the
copied object doesn't contain entries for that type, in which
case it will retain the old values.

If $type is undef, will copy ALL TYPES.

If $nameFilter is defined (a perl refular expression), it will copy
only data where ={name}= matches $nameFilter.

Does *not* copy web, topic or text.

=cut

sub copyFrom {
    my ( $this, $otherMeta, $type, $filter ) = @_;
    ASSERT( $otherMeta->isa('Foswiki::Meta') ) if DEBUG;

    if ($type) {
        foreach my $item ( @{ $otherMeta->{$type} } ) {
            if ( !$filter || ( $item->{name} && $item->{name} =~ /$filter/ ) ) {
                my %data = map { $_ => $item->{$_} } keys %$item;
                push( @{ $this->{$type} }, \%data );
            }
        }
    }
    else {
        foreach my $k ( keys %$otherMeta ) {

            # Don't copy the web and topic fields, this may be a new topic
            unless ( $k =~ /^_/ ) {
                $this->copyFrom( $otherMeta, $k );
            }
        }
    }
}

=begin TML

---++ ObjectMethod count($type) -> $integer

Return the number of entries of the given type

=cut

sub count {
    my ( $this, $type ) = @_;
    my $data = $this->{$type};

    return scalar @$data if ( defined($data) );

    return 0;
}

=begin TML

---++ ObjectMethod getRevisionInfo($fromrev) -> ( $date, $author, $rev, $comment )

Try and get revision info from the meta information, or, if it is not
present, kick down to the Store module for the same information.

Returns ( $revDate, $author, $rev, $comment )

$rev is an integer revision number.

=cut

sub getRevisionInfo {
    my ( $this, $fromrev ) = @_;
    my $store = $this->{_session}->{store};

    my $topicinfo = $this->get('TOPICINFO');

    my ( $date, $author, $rev, $comment );
    if ($topicinfo) {
        $date   = $topicinfo->{date};
        $author = $topicinfo->{author};
        $rev    = $topicinfo->{version};
        $rev =~ s/^\$Rev(:\s*\d+)?\s*\$$/0/;    # parse out SVN keywords in doc
        $rev =~ s/^\d+\.//;
        $comment = '';
        if ( !$fromrev || $rev eq $fromrev ) {
            return ( $date, $author, $rev, $comment );
        }
    }

    # Different rev, or no topic info, delegate to Store
    ( $date, $author, $rev, $comment ) =
      $store->getRevisionInfo( $this->{_web}, $this->{_topic}, $fromrev );
    return ( $date, $author, $rev, $comment );
}

=begin TML

---++ ObjectMethod merge( $otherMeta, $formDef )

   * =$otherMeta= - a block of meta-data to merge with $this
   * =$formDef= reference to a Foswiki::Form that gives the types of the fields in $this

Merge the data in the other meta block.
   * File attachments that only appear in one set are preserved.
   * Form fields that only appear in one set are preserved.
   * Form field values that are different in each set are text-merged
   * We don't merge for field attributes or title
   * Topic info is not touched
   * The =mergeable= method on the form def is used to determine if that fields is mergeable. if it isn't, the value currently in meta will _not_ be changed.

=cut

sub merge {
    my ( $this, $other, $formDef ) = @_;

    my $data = $other->{FIELD};
    if ($data) {
        foreach my $otherD (@$data) {
            my $thisD = $this->get( 'FIELD', $otherD->{name} );
            if ( $thisD && $thisD->{value} ne $otherD->{value} ) {
                if ( $formDef->isTextMergeable( $thisD->{name} ) ) {
                    require Foswiki::Merge;
                    my $merged = Foswiki::Merge::merge2(
                        'A',
                        $otherD->{value},
                        'B',
                        $thisD->{value},
                        '.*?\s+',
                        $this->{_session},
                        $formDef->getField( $thisD->{name} )
                    );

                    # SMELL: we don't merge attributes or title
                    $thisD->{value} = $merged;
                }
            }
            elsif ( !$thisD ) {
                $this->putKeyed( 'FIELD', $otherD );
            }
        }
    }

    $data = $other->{FILEATTACHMENT};
    if ($data) {
        foreach my $otherD (@$data) {
            my $thisD = $this->get( 'FILEATTACHMENT', $otherD->{name} );
            if ( !$thisD ) {
                $this->putKeyed( 'FILEATTACHMENT', $otherD );
            }
        }
    }
}

=begin TML

---++ ObjectMethod stringify( $types ) -> $string

Return a string version of the meta object. Uses \n to separate lines.
If =$types= is specified, return only types
that match it. Types should be a perl regular expression.

=cut

sub stringify {
    my ( $this, $types ) = @_;
    my $s = '';
    $types ||= qr/^[A-Z]+$/;

    foreach my $type ( grep { /$types/ } keys %$this ) {
        foreach my $item ( @{ $this->{$type} } ) {

            #remove the internal 'info.rev'
            my $topicRev = $item->{'rev'};
            if ( $type eq 'TOPICINFO' ) {
                undef $item->{'rev'};
            }
            my @itemKeys = sort keys %$item;
            $s .= "$type: "
              . join( ' ',
                map { "$_='" . ( $item->{$_} || '' ) . "'" } @itemKeys )
              . "\n";
            if ( $type eq 'TOPICINFO' && defined($topicRev) ) {
                $item->{'rev'} = $topicRev;
            }
        }
    }
    return $s;
}

=begin TML

---++ ObjectMethod forEachSelectedValue( $types, $keys, \&fn, \%options )

Iterate over the values selected by the regular expressions in $types and
$keys.
   * =$types= - regular expression matching the names of fields to be processed. Will default to qr/^[A-Z]+$/ if undef.
   * =$keys= - regular expression matching the names of keys to be processed.  Will default to qr/^[a-z]+$/ if undef.

Iterates over each value, calling =\&fn= on each, and replacing the value
with the result of \&fn.

\%options will be passed on to $fn, with the following additions:
   * =_type= => the type name (e.g. "FILEATTACHMENT")
   * =_key= => the key name (e.g. "user")

=cut

sub forEachSelectedValue {
    my ( $this, $types, $keys, $fn, $options ) = @_;

    $types ||= qr/^[A-Z]+$/;
    $keys  ||= qr/^[a-z]+$/;

    foreach my $type ( grep { /$types/ } keys %$this ) {
        $options->{_type} = $type;
        my $data = $this->{$type};
        next unless $data;
        foreach my $datum (@$data) {
            foreach my $key ( grep { /$keys/ } keys %$datum ) {
                $options->{_key} = $key;
                $datum->{$key} = &$fn( $datum->{$key}, $options );
            }
        }
    }
}

=begin TML

---++ ObjectMethod getParent() -> $parent

Gets the TOPICPARENT name.

=cut

sub getParent {
    my ($this) = @_;

    my $value  = '';
    my $parent = $this->get('TOPICPARENT');
    $value = $parent->{name} if ($parent);

    # Return empty string (not undef), if TOPICPARENT meta is broken
    $value = '' if ( !defined $value );
    return $value;
}

=begin TML

---++ ObjectMethod getFormName() -> $formname

Returns the name of the FORM, or '' if none.

=cut

sub getFormName {
    my ($this) = @_;

    my $aForm = $this->get('FORM');
    if ($aForm) {
        return $aForm->{name};
    }
    return '';
}

=begin TML

---++ ObjectMethod renderFormForDisplay( $templates ) -> $html

Render the form contained in the meta for display.

=cut

sub renderFormForDisplay {
    my ( $this, $templates ) = @_;

    # NOTE: param $templates is not used

    my $fname = $this->getFormName();

    require Foswiki::Form;
    return '' unless $fname;

    my $form = new Foswiki::Form( $this->{_session}, $this->{_web}, $fname );

    if ($form) {
        return $form->renderForDisplay($this);
    }
    else {

        # Make pseudo-form from field data
        $form =
          new Foswiki::Form( $this->{_session}, $this->{_web}, $fname, $this );
        my $mess = CGI::span(
            { class => 'foswikiAlert' },
            "%MAKETEXT{\"Form definition '[_1]' not found\" args=\"$fname\"}%"
           );
        $mess .= $form->renderForDisplay($this) if $form;
        return $mess;
    }
}

=begin TML

---++ ObjectMethod renderFormFieldForDisplay($name, $format, $attrs) -> $text

Render a single formfield, using the $format. See
Foswiki::Form::FormField::renderForDisplay for a description of how the value
is rendered.

=cut

sub renderFormFieldForDisplay {
    my ( $this, $name, $format, $attrs ) = @_;

    my $value;
    my $mf = $this->get( 'FIELD', $name );
    unless ($mf) {

        # Not a valid field name, maybe it's a title.
        require Foswiki::Form;
        $name = Foswiki::Form::fieldTitle2FieldName($name);
        $mf = $this->get( 'FIELD', $name );
    }
    return '' unless $mf;    # field not found

    $value = $mf->{value};

    my $fname = $this->getFormName();
    if ($fname) {
        require Foswiki::Form;
        my $form =
          new Foswiki::Form( $this->{_session}, $this->{_web}, $fname );
        if ($form) {
            my $field = $form->getField($name);
            if ($field) {
                return $field->renderForDisplay( $format, $value, $attrs );
            }
        }
    }

    # Form or field wasn't found, do your best!
    my $f = $this->get( 'FIELD', $name );
    if ($f) {
        $format =~ s/\$title/$f->{title}/;
        require Foswiki::Render;
        $value = Foswiki::Render::protectFormFieldValue( $value, $attrs );
        $format =~ s/\$value/$value/;
    }
    return $format;
}

=begin TML

---++ ObjectMethod getEmbeddedStoreForm() -> $text

Generate the embedded store form of the topic. The embedded store
form has meta-data values embedded using %META: lines. The text
stored in the meta is taken as the topic text.

=cut

sub getEmbeddedStoreForm {
    my $this = shift;
    $this->{_text} ||= '';

    require Foswiki::Store;

    my $start = $this->_writeTypes(qw/TOPICINFO TOPICPARENT/);
    my $end   = $this->_writeTypes(qw/FORM FIELD FILEATTACHMENT TOPICMOVED/);

    # append remaining meta data
    $end .= $this->_writeTypes(
        qw/not TOPICINFO TOPICPARENT FORM FIELD FILEATTACHMENT TOPICMOVED/);
    my $text = $start . $this->{_text};
    $end = "\n" . $end if $end;
    $text .= $end;
    return $text;
}

# STATIC Write a meta-data key=value pair
# The encoding is reversed in _readKeyValues
sub _writeKeyValue {
    my ( $key, $value ) = @_;

    if ( defined($value) ) {
        $value = Foswiki::Store::dataEncode($value);
    }
    else {
        $value = '';
    }

    return $key . '="' . $value . '"';
}

# STATIC: Write all the key=value pairs for the types listed
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
        my $data = $this->{$type};
        foreach my $item (@$data) {
            my $sep = '';
            $text .= '%META:' . $type . '{';
            my $name = $item->{name};
            if ($name) {

      # If there's a name field, put first to make regexp based searching easier
                $text .= _writeKeyValue( 'name', $item->{name} );
                $sep = ' ';
            }
            foreach my $key ( sort keys %$item ) {

                #don't store the rev created in addTOPICINFO
                next if ( $type eq 'TOPICINFO' && $key eq 'rev' );
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

# Note: not published as part of the interface; private to Foswiki
# Add TOPICINFO type data to the object, as specified by the parameters.
#    * =$rev= - the revision number
#    * =$time= - the time stamp
#    * =$user= - the user id
#    * =$repRev= - is the save in progress a repRev
# SMELL: Duplicate rev control info in the topic
sub addTOPICINFO {
    my ( $this, $rev, $time, $user, $repRev, $format ) = @_;
    $rev = 1 if $rev < 1;
    my $users = $this->{_session}->{users};

    my %options = (

        # compatibility; older versions of the code use
        # RCS rev numbers save with them so old code can
        # read these topics
        version => '1.' . $rev,
        rev     => $rev,
        date    => $time,
        author  => $user,
        format  => $format,
    );

    # if this is a reprev, then store the revision that was affected.
    # Required so we can tell when a merge is based on something that
    # is *not* the original rev where another users' edit started.
    # See Bugs:Item1897.
    $options{reprev} = '1.' . $rev if $repRev;

    $this->put( 'TOPICINFO', \%options );
}

# This method will load (or otherwise fetch) the meta-data for a named
# web/topic.
# The request might be satisfied by a read from the store, or it might be
# satisfied from a cache. The caller doesn't care.
#
# This is an object method rather than a static method because it depends on
# the implementation of Meta - it might be this base class, or it might be a
# caching subclass, for example.

sub getMetaFor {
    my ( $this, $web, $topic ) = @_;

    my ( $m, $t ) = $this->session->{store}->readTopic( undef, $web, $topic );
    return $m;    # $t is already in $m->text()
}

1;

__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
