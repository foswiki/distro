# See bottom of file for license and copyright details

=begin TML

---+ package Foswiki::Form

Object representing a single form definition.

Form definitions are mainly used to control rendering of a form for
editing, though there is some application login there that handles
transferring values between edits and saves.

A form definition consists of a Foswiki::Form object, which has a list
of field definitions. Each field definition is an object of a type
derived from Foswiki::Form::FieldDefinition. These objects are responsible
for the actual syntax and semantics of the field type. Form definitions
are parsed from Foswiki tables, and the types are mapped by name to a
class declared in Foswiki::Form::* - for example, the =text= type is mapped
to =Foswiki::Form::Text= and the =checkbox= type to =Foswiki::Form::Checkbox=.

The =Foswiki::Form::FieldDefinition= class declares default behaviours for
types that accept a single value in their definitions. The
=Foswiki::Form::ListFieldDefinition= extends this for types that have lists
of possible values.

=cut

# The bulk of this object is a parser for form definitions. All the
# intelligence is in the individual field types.

package Foswiki::Form;

use strict;
use Assert;
use Error qw( :try );

# The following are reserved as URL parameters to scripts and may not be
# used as field names in forms.
my %reservedFieldNames = map { $_ => 1 }
  qw( action breaklock contenttype cover dontnotify editaction
  forcenewrevision formtemplate onlynewtopic onlywikiname
  originalrev skin templatetopic text topic topicparent user );

=begin TML

---++ ClassMethod new ( $session, $web, $form, \@def )

Looks up a form in the session object or, if it hasn't been read yet,
reads it from the form definition topic on disc.
   * =$web= - default web to recover form from, if =$form= doesn't
     specify a web
   * =$form= - name of the form
   * =\@def= - optional. A reference to a list of field definitions.
     If present, these definitions will be used, rather than any read from
     the form definition topic. Note that this array should not be modified
     again after being passed into this constructor (it is not copied).

If the form cannot be read, will return undef to allow the caller to take
appropriate action.

=cut

sub new {
    my ( $class, $session, $web, $form, $def ) = @_;

    ( $web, $form ) = $session->normalizeWebTopicName( $web, $form );

    # Validate
    $web =
      Foswiki::Sandbox::untaint( $web, \&Foswiki::Sandbox::validateWebName );
    $form =
      Foswiki::Sandbox::untaint( $form, \&Foswiki::Sandbox::validateTopicName );

    unless ( $web && $form ) {
        return undef;
    }

    my $this = $session->{forms}->{"$web.$form"};
    unless ($this) {

        $this = bless(
            {
                session => $session,
                web     => $web,
                topic   => $form,
            },
            $class
        );

        $session->{forms}->{"$web.$form"} = $this;

        unless ($def) {

            my $store = $session->{store};

            # Read topic that defines the form
            if ( $store->topicExists( $web, $form ) ) {
                my ( $meta, $text ) =
                  $store->readTopic( $session->{user}, $web, $form, undef );

                $this->{fields} = _parseFormDefinition( $this, $meta, $text );
            }
            else {
                delete $session->{forms}->{"$web.$form"};
                return undef;
            }
        }
        elsif ( ref($def) eq 'ARRAY' ) {
            $this->{fields} = $def;
        }
        else {

            # Foswiki::Meta object
            $this->{fields} = $this->_extractPseudoFieldDefs($def);
        }
    }

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{web};
    undef $this->{topic};
    foreach ( @{ $this->{fields} } ) {
        $_->finish();
    }
    undef $this->{fields};
    undef $this->{session};
}

=begin TML

---++ StaticMethod fieldTitle2FieldName($title) -> $name
Chop out all except A-Za-z0-9_. from a field name to create a
valid "name" for storing in meta-data

=cut

sub fieldTitle2FieldName {
    my ($text) = @_;
    return '' unless defined($text);
    $text =~ s/<nop>//g;             # support <nop> character in title
    $text =~ s/[^A-Za-z0-9_\.]//g;
    return $text;
}

# Get definition from supplied topic text
# Returns array of arrays
#   1st - list fields
#   2nd - name, title, type, size, vals, tooltip, attributes
#   Possible attributes are "M" (mandatory field)
sub _parseFormDefinition {
    my ( $this, $meta, $text ) = @_;

    my $store   = $this->{session}->{store};
    my @fields  = ();
    my $inBlock = 0;
    $text =~ s/\r//g;
    $text =~ s/\\\n//g;    # remove trailing '\' and join continuation lines

# | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* | *Attributes:* |
# Tooltip and attributes are optional
    foreach my $line ( split( /\n/, $text ) ) {
        if ( $line =~ /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/ ) {
            $inBlock = 1;
            next;
        }

       # Only insist on first field being present FIXME - use oops page instead?
        if ( $inBlock && $line =~ s/^\s*\|\s*// ) {
            $line =~ s/\\\|/\007/g;    # protect \| from split
            my ( $title, $type, $size, $vals, $tooltip, $attributes ) =
              map { s/\007/|/g; $_ } split( /\s*\|\s*/, $line );

            $title ||= '';

            $type ||= '';
            $type = lc($type);
            $type =~ s/^\s*//go;
            $type =~ s/\s*$//go;
            $type = 'text' if ( !$type );

            $size ||= '';

            $vals ||= '';
            $vals =
              $this->{session}
              ->handleCommonTags( $vals, $this->{web}, $this->{topic}, $meta );
            $vals =~ s/<\/?(nop|noautolink)\/?>//go;
            $vals =~ s/^\s+//g;
            $vals =~ s/\s+$//g;

            $tooltip ||= '';

            $attributes ||= '';
            $attributes =~ s/\s*//go;
            $attributes = '' if ( !$attributes );

            my $definingTopic = "";
            if ( $title =~ /\[\[(.+)\]\[(.+)\]\]/ ) {

                # use common defining topics with different field titles
                $definingTopic = fieldTitle2FieldName($1);
                $title         = $2;
            }

            my $name = fieldTitle2FieldName($title);

            # Rename fields with reserved names
            if ( $reservedFieldNames{$name} ) {
                $name .= '_';
            }

            my $fieldDef = $this->createField(
                $type,
                name          => $name,
                title         => $title,
                size          => $size,
                value         => $vals,
                tooltip       => $tooltip,
                attributes    => $attributes,
                definingTopic => $definingTopic,
                web           => $this->{web},
                topic         => $this->{topic}
            );
            push( @fields, $fieldDef );

            $this->{mandatoryFieldsPresent} ||= $fieldDef->isMandatory();
        }
        else {
            $inBlock = 0;
        }
    }

    return \@fields;
}

# PROTECTED
# Create a field object. Done like this so that this method can be
# overridden by subclasses to extend the range of field types.
sub createField {
    my $this = shift;
    my $type = shift;

    # The untaint is required for the validation *and* the ucfirst, which
    # retaints when use locale is in force
    my $class = Foswiki::Sandbox::untaint(
        $type,
        sub {
            my $class = shift;
            $class =~ /^(\w*)/;    # cut off +buttons etc
            return 'Foswiki::Form::' . ucfirst($1);
        }
    );

    eval 'require ' . $class;
    if ($@) {

        # Type not available; use base type
        require Foswiki::Form::FieldDefinition;
        $class = 'Foswiki::Form::FieldDefinition';
    }
    return $class->new( session => $this->{session}, type => $type, @_ );
}

# Generate a link to the given topic, so we can bring up details in a
# separate window.
sub _link {
    my ( $this, $meta, $string, $tooltip, $topic ) = @_;

    $string =~ s/[\[\]]//go;

    $topic ||= $string;
    my $defaultToolTip =
      $this->{session}->i18n->maketext('Details in separate window');
    $tooltip ||= $defaultToolTip;

    my $web;
    ( $web, $topic ) =
      $this->{session}->normalizeWebTopicName( $this->{web}, $topic );

    my $link;

    my $store = $this->{session}->{store};
    if ( $store->topicExists( $web, $topic ) ) {
        $link = CGI::a(
            {
                target => $topic,
                title  => $tooltip,
                href =>
                  $this->{session}->getScriptUrl( 0, 'view', $web, $topic ),
                rel => 'nofollow'
            },
            $string
        );
    }
    else {
        my $expanded =
          $this->{session}->handleCommonTags( $string, $web, $topic, $meta );
        if ( $tooltip ne $defaultToolTip ) {
            $link = CGI::span( { title => $tooltip }, $expanded );
        }
        else {
            $link = $expanded;
        }
    }

    return $link;
}

=begin TML

---++ ObjectMethod renderForEdit( $web, $topic, $meta ) -> $html

   * =$web= the web of the topic being rendered
   * =$topic= the topic being rendered
   * =$meta= the meta data for the form

Render the form fields for entry during an edit session, using data values
from $meta

=cut

sub renderForEdit {
    my ( $this, $web, $topic, $meta ) = @_;
    ASSERT( $meta->isa('Foswiki::Meta') ) if DEBUG;
    require CGI;
    my $session = $this->{session};

    if ( $this->{mandatoryFieldsPresent} ) {
        $session->enterContext('mandatoryfields');
    }
    my $tmpl = $session->templates->readTemplate("form");
    $tmpl = $session->handleCommonTags( $tmpl, $web, $topic, $meta );

    # Note: if WEBFORMS preference is not set, can only delete form.
    $tmpl =~ s/%FORMTITLE%/_link(
        $this, $meta, $this->{web}.'.'.$this->{topic})/ge;
    my ( $text, $repeatTitledText, $repeatUntitledText, $afterText ) =
      split( /%REPEAT%/, $tmpl );

    foreach my $fieldDef ( @{ $this->{fields} } ) {

        my $value;
        my $tooltip       = $fieldDef->{tooltip};
        my $definingTopic = $fieldDef->{definingTopic};
        my $title         = $fieldDef->{title};
        my $tmp           = '';
        if ( !$title && !$fieldDef->isEditable() ) {

            # Special handling for untitled labels.
            # SMELL: Assumes that uneditable fields are not multi-valued
            $tmp   = $repeatUntitledText;
            $value = $session->{renderer}->getRenderedVersion(
                $session->handleCommonTags(
                    $fieldDef->{value},
                    $web, $topic, $meta
                )
            );
        }
        else {
            $tmp = $repeatTitledText;

            if ( defined( $fieldDef->{name} ) ) {
                my $field = $meta->get( 'FIELD', $fieldDef->{name} );
                $value = $field->{value};
            }
            my $extra = '';    # extras on col 0

            unless ( defined($value) ) {
                my $dv = $fieldDef->getDefaultValue($value);
                if ( defined($dv) ) {
                    $dv =
                      $this->{session}
                      ->handleCommonTags( $dv, $web, $topic, $meta );
                    $value = Foswiki::expandStandardEscapes($dv);    # Item2837
                }
            }

            # Give plugin field types a chance first (but no chance to add to
            # col 0 :-(
            # SMELL: assumes that the field value is a string
            my $output = $session->{plugins}->dispatch(
                'renderFormFieldForEditHandler', $fieldDef->{name},
                $fieldDef->{type},               $fieldDef->{size},
                $value,                          $fieldDef->{attributes},
                $fieldDef->{value}
            );

            if ($output) {
                $value = $output;
            }
            else {
                ( $extra, $value ) =
                  $fieldDef->renderForEdit( $web, $topic, $value );
            }

            if ( $fieldDef->isMandatory() ) {
                $extra .= CGI::span( { class => 'foswikiAlert' }, ' *' );
            }

            $tmp =~ s/%ROWTITLE%/_link(
                $this, $meta, $title, $tooltip, $definingTopic )/ge;
            $tmp =~ s/%ROWEXTRA%/$extra/g;
        }
        $tmp =~ s/%ROWVALUE%/$value/g;
        $text .= $tmp;
    }

    $text .= $afterText;
    return $text;
}

=begin TML

---++ ObjectMethod renderHidden( $meta ) -> $html

Render form fields found in the meta as hidden inputs, so they pass
through edits untouched.

=cut

sub renderHidden {
    my ( $this, $meta ) = @_;
    ASSERT( $meta->isa('Foswiki::Meta') ) if DEBUG;

    my $text = '';

    foreach my $field ( @{ $this->{fields} } ) {
        $text .= $field->renderHidden($meta);
    }

    return $text;
}

=begin TML

---++ ObjectMethod getFieldValuesFromQuery($query, $metaObject) -> ( $seen, \@missing )

Extract new values for form fields from a query.

   * =$query= - the query
   * =$metaObject= - the meta object that is storing the form values

For each field, if there is a value in the query, use it.
Otherwise if there is already entry for the field in the meta, keep it.

Returns the number of fields which had values provided by the query,
and a references to an array of the names of mandatory fields that were
missing from the query.

=cut

sub getFieldValuesFromQuery {
    my ( $this, $query, $meta ) = @_;
    ASSERT( $meta->isa('Foswiki::Meta') ) if DEBUG;
    my @missing;
    my $seen = 0;

    # Remove the old defs so we apply the
    # order in the form definition, and not the
    # order in the previous meta object. See Item1982.
    my @old = $meta->find('FIELD');
    $meta->remove('FIELD');
    foreach my $fieldDef ( @{ $this->{fields} } ) {
        my ( $set, $present ) =
          $fieldDef->populateMetaFromQueryData( $query, $meta, \@old );
        if ($present) {
            $seen++;
        }
        if ( !$set && $fieldDef->isMandatory() ) {

            # Remember missing mandatory fields
            push( @missing, $fieldDef->{title} || "unnamed field" );
        }
    }
    return ( $seen, \@missing );
}

=begin TML

---++ ObjectMethod isTextMergeable( $name ) -> $boolean

   * =$name= - name of a form field (value of the =name= attribute)

Returns true if the type of the named field allows it to be text-merged.

If the form does not define the field, it is assumed to be mergeable.

=cut

sub isTextMergeable {
    my ( $this, $name ) = @_;

    my $fieldDef = $this->getField($name);
    if ($fieldDef) {
        return $fieldDef->isTextMergeable();
    }

    # Field not found - assume it is mergeable
    return 1;
}

=begin TML

---++ ObjectMethod getField( $name ) -> $fieldDefinition

   * =$name= - name of a form field (value of the =name= attribute)

Returns a =Foswiki::Form::FieldDefinition=, or undef if the form does not
define the field.

=cut

sub getField {
    my ( $this, $name ) = @_;
    foreach my $fieldDef ( @{ $this->{fields} } ) {
        return $fieldDef if ( $fieldDef->{name} && $fieldDef->{name} eq $name );
    }
    return undef;
}

=begin TML

---++ ObjectMethod getFields() -> \@fields

Return a list containing references to field name/value pairs.
Each entry in the list has a {name} field and a {value} field. It may
have other fields as well, which caller should ignore. The
returned list should be treated as *read only* (must not be written to).

=cut

sub getFields {
    my $this = shift;
    return $this->{fields};
}

sub renderForDisplay {
    my ( $this, $meta ) = @_;

    my $templates = $this->{session}->templates;
    $templates->readTemplate('formtables');

    my $text        = '';
    my $rowTemplate = $templates->expandTemplate('FORM:display:row');
    foreach my $fieldDef ( @{ $this->{fields} } ) {
        my $fm = $meta->get( 'FIELD', $fieldDef->{name} );
        next unless $fm;
        my $fa = $fm->{attributes} || '';
        unless ( $fa =~ /H/ ) {
            my $row = $rowTemplate;

            # Legacy; was %A_TITLE% before it was $title
            $row =~ s/%A_TITLE%/\$title/g;
            $row =~ s/%A_VALUE%/\$value/g;    # Legacy
            $text .= $fieldDef->renderForDisplay( $row, $fm->{value} );
        }
    }
    $text = $templates->expandTemplate('FORM:display:header') . $text;
    $text .= $templates->expandTemplate('FORM:display:footer');

    # substitute remaining placeholders in footer and header
    $text =~ s/%A_TITLE%/$this->{web}.$this->{topic}/g;

    return $text;
}

# extractPseudoFieldDefs( $meta ) -> $fieldDefs
# Examine the FIELDs in $meta and reverse-engineer a set of field
# definitions that can be used to construct a new "pseudo-form". This
# fake form can be used to support editing of topics that have an attached
# form that has no definition topic.
sub _extractPseudoFieldDefs {
    my ( $this, $meta ) = @_;
    my @fields = $meta->find('FIELD');
    my @fieldDefs;
    require Foswiki::Form::FieldDefinition;
    foreach my $field (@fields) {

        # Fields are name, value, title, but there is no other type
        # information so we have to treat them all as "text" :-(
        my $fieldDef = new Foswiki::Form::FieldDefinition(
            session    => $this->{session},
            name       => $field->{name},
            title      => $field->{title} || $field->{name},
            attributes => $field->{attributes} || ''
        );
        push( @fieldDefs, $fieldDef );
    }
    return \@fieldDefs;
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

