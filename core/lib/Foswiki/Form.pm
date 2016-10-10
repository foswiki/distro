# See bottom of file for license and copyright information

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
use v5.14;

use Assert;

use Foswiki qw(expandStandardEscapes);
use Foswiki::Sandbox                   ();
use Foswiki::Form::FieldDefinition     ();
use Foswiki::Form::ListFieldDefinition ();
use Foswiki::AccessControlException    ();
use Foswiki::OopsException             ();
use Foswiki::Func                      ();
use Try::Tiny;

use Foswiki::Class;
extends qw( Foswiki::Meta );

# The following are reserved as URL parameters to scripts and may not be
# used as field names in forms.
my %reservedFieldNames = map { $_ => 1 }
  qw( action breaklock contenttype cover dontnotify editaction
  forcenewrevision formtemplate onlynewtopic onlywikiname
  originalrev skin templatetopic text topic topicparent user );

my @default_columns = qw/name type size value description attributes default/;
my %valid_columns = map { $_ => 1 } @default_columns;

#our @_newParameters = qw(app web form def);

has def => (
    is        => 'ro',
    lazy      => 1,
    predicate => 1,
);
has fields => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    isa       => Foswiki::Object::isaARRAY( 'fields', noUndef => 1, ),
);
has mandatoryFieldsPresent => (
    is      => 'rw',
    lazy    => 1,
    default => 0,
);

=begin TML

---++ ClassMethod load ( $app, $web, $topic, \@def )

Looks up a form in the app object or, if it hasn't been read yet,
reads it from the form definition topic on disc.
   * =$web= - default web to recover form from, if =$form= doesn't
     specify a web
   * =$topic= - name of the topic that contains the form definition
   * =\@def= - optional. A reference to a list of field definitions.
     If present, these definitions will be used, rather than any read from
     the form definition topic.

May throw Foswiki::OopsException if the web and form are not valid for use as a
form name, or if \@def is not given and the form does not exist in the
database. May throw Foswiki::AccessControlException if the form schema
in the database is protected against view.

=cut

sub _validateWebTopic {
    my ( $app, $web, $form ) = @_;

    my $req = $app->request;
    my ( $vweb, $vtopic ) = $req->normalizeWebTopicName( $web, $form );

    # Validating web/topic before usage.
    $vweb =
      Foswiki::Sandbox::untaint( $vweb, \&Foswiki::Sandbox::validateWebName );
    $vtopic = Foswiki::Sandbox::untaint( $vtopic,
        \&Foswiki::Sandbox::validateTopicName );

    unless ( $vweb && $vtopic ) {
        Foswiki::OopsException->throw(
            app      => $app,
            template => 'attention',
            def      => 'invalid_form_name',
            web      => $req->web,
            topic    => $req->topic,
            params   => [ $web, $form ]
        );
    }

    return ( $vweb, $vtopic );
}

# XXX vrurg ClassMethod loadCached() is supposed to replace the old new() method
# and become a new constructor. Required to stay in compliance with Moo
# architecture and avoid replacing of the standard new() method.
sub loadCached {
    my ( $class, $app, $web, $form, $def ) = @_;

    my ( $vweb, $vtopic ) = _validateWebTopic( $app, $web, $form );

    my $this;
    if ( defined( $this = $app->forms->{"$vweb.$vtopic"} ) ) {
        unless ( $this->isa('Foswiki::Form') ) {

            #recast if we have to - allowing the cache to work its magic
            $this = bless $this, $class;
        }
    }

    return $this if defined $this;
    return $app->create(
        $class,
        web       => $vweb,
        form      => $vtopic,
        _indirect => 1,
        ( defined $def ? ( def => $def ) : () ),
    );
}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $params = $orig->( $class, @_ );

    my $app = $params->{app};
    my $req = $app->request;
    my ( $vweb, $vtopic ) =
      _validateWebTopic( $app, $params->{web}, $params->{form} );

    # Cast form into topic to as our base Foswiki::Meta knows it.
    $params->{topic} = $vtopic;

    # Avoid direct calls to $class::new().
    ASSERT( $params->{_indirect},
"${class}::new() has been used directly. Use ${class}->loadCached() instead."
    );

    # No more need to pollute properties with this key.
    delete $params->{_indirect};

    # Got to have either a def or a topic
    unless ( $params->{def} || $app->store->topicExists( $vweb, $vtopic ) ) {
        Foswiki::OopsException->throw(
            app      => $app,
            template => 'attention',
            def      => 'no_form_def',
            web      => $req->web,
            topic    => $req->topic,
            params   => [ $vweb, $vtopic ]
        );
    }

    return $params;
};

sub BUILD {
    my $this = shift;

    my $app   = $this->app;
    my $web   = $this->web;
    my $topic = $this->topic;

    unless ( $this->has_def || $this->haveAccess('VIEW') ) {
        Foswiki::AccessControlException->throw( 'VIEW', $app->user,
            $web, $topic, $Foswiki::Meta::reason );
    }

    # cache the object before we've parsed it to prevent recursion
    #when there are SEARCH / INCLUDE macros in the form definition
    $app->forms->{"$web.$topic"} = $this;

    unless ( $this->has_def ) {
        $this->fields( $this->_parseFormDefinition() );
    }
    elsif ( ref( $this->def ) eq 'ARRAY' ) {
        $this->fields( $this->def );
    }
    else {

        # Foswiki::Meta object
        $this->fields( $this->_extractPseudoFieldDefs( $this->def ) );
    }

    ASSERT( $this->has_fields,     "No fields arg cpecified" );
    ASSERT( defined $this->fields, "No fields defined" );
}

=begin TML

---++ StaticMethod getAvailableForms( $metaObject ) -> @forms

Get a list of the names of forms that are available for use in the
given topic. $metaObject can be a topic or a web.

=cut

sub getAvailableForms {
    my $contextObject = shift;
    my $legalForms;
    my $metaObject;

    # SMELL: Item11527, why aren't we using Foswiki::Func::getPreferencesValue?
    # AKA: Why can't we inherit WEBFORMS from parent webs?
    if ( defined $contextObject->topic ) {
        $metaObject =
          $contextObject->create( 'Foswiki::Meta', web => $contextObject->web );
        $legalForms = $metaObject->getPreference('WEBFORMS') || '';
        $legalForms =
          Foswiki::Func::expandCommonVariables( $legalForms,
            $contextObject->topic(), $contextObject->web(), $contextObject );
    }
    else {
        $legalForms = $contextObject->getPreference('WEBFORMS') || '';
    }
    $legalForms =~ s/^\s+//;
    $legalForms =~ s/\s+$//;
    my @forms = split( /[,\s]+/, $legalForms );

    # This is where we could %SEARCH for *Form topics
    return @forms;
}

=begin TML

---++ StaticMethod fieldTitle2FieldName($title) -> $name
Chop out all except \w. from a field name to create a
valid "name" for storing in meta-data

=cut

sub fieldTitle2FieldName {
    my ($text) = @_;
    return '' unless defined($text);
    $text =~ s/!//g;
    $text =~ s/<nop>//g;     # support <nop> character in title
    $text =~ s/[^\w\.]//g;
    return $text;
}

# Get definition from supplied topic text
# Returns array of arrays
#   1st - list fields
#   2nd - name, title, type, size, vals, description, attributes
#   Possible attributes are "M" (mandatory field) and "H" (hidden)
sub _parseFormDefinition {
    my $this = shift;

    require Foswiki::Tables::Parser;
    ASSERT( !$@ ) if DEBUG;

    my @fields = ();
    my $text   = $this->text();
    $text = '' unless defined $text;

    # Valid column titles, in default order.
    my @columns   = @default_columns;
    my $col       = 0;
    my $have_head = 0;
    my $seen_head = 0;

    #    my @field     = ();
    my %field = ();

    my $handler = sub {
        my $event = shift;
        if ( $event eq 'th' ) {
            if ($have_head) {

                # A header on any row but the first is treated as data
                $event = 'td';
                $_[1] = "*$_[1]*";

                # Drop-through to 'td'
            }
            else {
                # Header row declaring column titles.

                # This could re-order the columns based on the title,
                # but is disabled due to compatibility issues.
                #my ( $pre, $data, $post ) = @_;
                #$data = lc($data);
                #$data =~ s/[\s:]//g;
                #$data =~ s/s$//g; # singularise
                #$data = 'description' if $data =~ m/^tooltip(message)?$/;
                #$columns[ $col ] = $data if $valid_columns{$data};

                $col++;
                $seen_head = 1;
                return;
            }
        }

        if ( $event eq 'td' ) {
            my ( $pre, $data, $post ) = @_;

            $data = '' unless defined $data;

            $field{ $columns[$col] } = $data if $columns[$col];
            $col++;
            return;
        }

        if ( $event eq 'close_table' ) {

            # Abort the parse after the first table has been read
            Foswiki::Form::ParseFinished->throw;
        }

        if ( $event eq 'close_tr' ) {
            $col = 0;
            if ( !$have_head && $seen_head ) {

                # Closing the header row
                $have_head = 1;
                return;

                # if !$seen_head it's a conventional data row
            }
            $have_head = 1;    # Subsequent th cells treated as data

            if ( $field{type} ) {
                $field{type} = lc( $field{type} );
            }
            else {
                $field{type} = 'text';
            }

            my $vals = $field{value} || '';
            if ( $vals =~ m/%/ ) {
                $vals = $this->expandMacros($vals);
            }
            $vals =~ s/<\/?(!|nop|noautolink)\/?>//g;

            # Trim again in case macro expansion has added spaces
            $vals =~ s/^\s+//g;
            $vals =~ s/\s+$//g;
            $field{value} = $vals;

            #repeat same again with {default}
            if ( exists( $field{default} ) ) {
                my $vals = $field{default} || '';
                if ( $vals =~ m/%/ ) {
                    $vals = $this->expandMacros($vals);
                }
                $vals =~ s/<\/?(!|nop|noautolink)\/?>//g;

                # Trim again in case macro expansion has added spaces
                $vals =~ s/^\s+//g;
                $vals =~ s/\s+$//g;
                $field{default} = $vals;
            }

            $field{attributes} =~ s/\s*//g if ( exists( $field{attributes} ) );

            $field{title}         = $field{name};
            $field{definingTopic} = '';
            if ( $field{title} =~ m/\[\[(.+)\]\[(.+)\]\]/ ) {

                # use common defining topics with different field titles
                $field{definingTopic} =
                  fieldTitle2FieldName(
                    Foswiki::Func::expandCommonVariables($1) );
                $field{title} = $2;
            }

            $field{name} = fieldTitle2FieldName( $field{title} );

            # Rename fields with reserved names
            if ( $reservedFieldNames{ $field{name} } ) {
                $field{name} .= '_';
            }
            my $fieldDef = $this->createField(
                $field{type},
                web   => $this->web(),
                topic => $this->topic(),
                %field
            );

            push( @fields, $fieldDef );
            %field = ();

            $this->mandatoryFieldsPresent( $this->mandatoryFieldsPresent
                  || $fieldDef->isMandatory() );
        }
    };

    try {
        Foswiki::Tables::Parser::parse( $text, $handler );
    }
    catch {

        if ( $_->isa('Foswiki::Form::ParseFinished') ) {

            # clean exit, fired when first table has been parsed
        }
        else {
            Foswiki::Exception->rethrow($_);
        }

    };

    return \@fields;
}

# PROTECTED
# Create a field object. Done like this so that this method can be
# overridden by subclasses to extend the range of field types.
sub createField {
    my $this = shift;
    my $type = shift;

    # The untaint is required for the validation *and* the ucfirst, which
    # retaints when use locale is in force (hence we do the validation *after*
    # the ucfirst)
    my $class = Foswiki::Sandbox::untaint(
        $type,
        sub {
            my $class = ucfirst(shift);
            $class =~ m/^([a-zA-Z0-9_]*)/;    # cut off +buttons etc
            return "Foswiki::Form::$1";
        }
    );
    try {
        Foswiki::load_package($class);
    }
    catch {
        $this->app->logger->log( 'error', "error compiling class $class: $@" );

        # Type not available; use base type
        $class = 'Foswiki::Form::FieldDefinition';
    };
    return $this->create( $class, type => $type, @_ );
}

# Generate a link to the given topic, so we can bring up details in a
# separate window.
sub _link {
    my ( $this, $string, $tooltip, $topic ) = @_;

    $string =~ s/[\[\]]//g;

    $topic ||= $string;
    my $defaultToolTip =
      $this->app->i18n->maketext('Details in separate window');
    $tooltip ||= $defaultToolTip;

    ( my $web, $topic ) =
      $this->app->request->normalizeWebTopicName( $this->web(), $topic );

    $web =
      Foswiki::Sandbox::untaint( $web, \&Foswiki::Sandbox::validateWebName );

    $web ||= $this->web();

    $topic = Foswiki::Sandbox::untaint( $topic,
        \&Foswiki::Sandbox::validateTopicName );

    my $link;

    if ( $this->app->store->topicExists( $web, $topic ) ) {
        $link = CGI::a(
            {
                target => $topic,
                title  => $tooltip,
                href =>
                  $this->app->cfg->getScriptUrl( 0, 'view', $web, $topic ),
                rel => 'nofollow'
            },
            $string
        );
    }
    else {
        my $that = $this->create(
            'Foswiki::Meta',
            web   => $web,
            topic => $topic || $Foswiki::cfg{HomeTopicName}
        );
        my $expanded = $that->expandMacros($string);
        if ( $tooltip ne $defaultToolTip ) {
            $link = CGI::span( { title => $tooltip }, $expanded );
        }
        else {
            $link = $expanded;
        }
    }

    return $link;
}

sub stringify {
    my $this = shift;
    my $fs   = "| *Name* | *Type* | *Size* | *Attributes* |\n";
    foreach my $fieldDef ( @{ $this->fields } ) {
        $fs .= $fieldDef->stringify();
    }
    return $fs;
}

=begin TML

---++ ObjectMethod renderForEdit( $topicObject ) -> $html

   * =$topicObject= the topic being rendered

Render the form fields for entry during an edit session, using data values
from $meta

=cut

sub renderForEdit {
    my ( $this, $topicObject ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    require CGI;
    my $app = $this->app;

    if ( $this->mandatoryFieldsPresent ) {
        $app->enterContext('mandatoryfields');
    }
    my $tmpl = $app->templates->readTemplate('form');
    $tmpl = $topicObject->expandMacros($tmpl);

    $tmpl =~ s/%FORMTITLE%/$this->_link( $this->web.'.'.$this->topic )/ge;
    my ( $text, $repeatTitledText, $repeatUntitledText, $afterText ) =
      split( /%REPEAT%/, $tmpl );

    foreach my $fieldDef ( @{ $this->fields } ) {

        my $value;
        my $tooltip       = $fieldDef->{description};
        my $definingTopic = $fieldDef->{definingTopic};
        my $title         = $fieldDef->{title};
        my $tmp           = '';
        if ( !$title && !$fieldDef->isEditable() ) {

            # Special handling for untitled labels.
            # SMELL: Assumes that uneditable fields are not multi-valued
            $tmp = $repeatUntitledText;
            $value =
              $topicObject->renderTML(
                $topicObject->expandMacros( $fieldDef->{value} ) );
        }
        else {
            $tmp = $repeatTitledText;

            if ( defined( $fieldDef->{name} ) ) {
                my $field = $topicObject->get( 'FIELD', $fieldDef->{name} );
                $value = $field->{value};
            }
            my $extra = '';    # extras on col 0

            unless ( defined($value) ) {

                my $dv = $fieldDef->getDefaultValue($value);
                if ( defined($dv) ) {
                    $dv    = $topicObject->expandMacros($dv);
                    $value = expandStandardEscapes($dv);        # Item2837
                }
            }

            # Give plugin field types a chance first (but no chance to add to
            # col 0 :-(
            # SMELL: assumes that the field value is a string
            my $output = $app->plugins->dispatch(
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
                  $fieldDef->renderForEdit( $topicObject, $value );
            }

            if ( $fieldDef->isMandatory() ) {
                $extra .= CGI::span( { class => 'foswikiAlert' }, ' *' );
            }

            $tmp =~ s/%ROWTITLE%/
              $this->_link( $title, $tooltip, $definingTopic )/ge;
            $tmp =~ s/%ROWEXTRA%/$extra/g;
        }
        $tmp =~ s/%ROWVALUE%/$value/g;
        $text .= $tmp;
    }

    $text .= $afterText;
    return $text;
}

=begin TML

---++ ObjectMethod renderHidden( $topicObject ) -> $html

Render form fields found in the meta as hidden inputs, so they pass
through edits untouched.

=cut

sub renderHidden {
    my ( $this, $topicObject ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;

    my $text = '';

    foreach my $field ( @{ $this->fields } ) {
        $text .= $field->renderHidden($topicObject);
    }

    return $text;
}

=begin TML

---++ ObjectMethod getFieldValuesFromQuery($query, $topicObject) -> ( $seen, \@missing )

Extract new values for form fields from a query.

   * =$query= - the query
   * =$topicObject= - the meta object that is storing the form values

For each field, if there is a value in the query, use it.
Otherwise if there is already entry for the field in the meta, keep it.

Returns the number of fields which had values provided by the query,
and a references to an array of the names of mandatory fields that were
missing from the query.

=cut

sub getFieldValuesFromQuery {
    my ( $this, $query, $topicObject ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    my @missing;
    my $seen = 0;

    # Remove the old defs so we apply the
    # order in the form definition, and not the
    # order in the previous meta object. See Item1982.
    my @old = $topicObject->find('FIELD');
    $topicObject->remove('FIELD');
    foreach my $fieldDef ( @{ $this->fields } ) {
        my ( $set, $present ) =
          $fieldDef->populateMetaFromQueryData( $query, $topicObject, \@old );
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
    if ( $this->has_fields ) {
        foreach my $fieldDef ( @{ $this->fields } ) {
            return $fieldDef if ( $fieldDef->name && $fieldDef->name eq $name );
        }
    }
    return;
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
    return $this->fields;
}

sub renderForDisplay {
    my ( $this, $topicObject ) = @_;

    my $templates = $this->app->templates;
    $templates->readTemplate('formtables');

    my $text = $templates->expandTemplate('FORM:display:header');
    $text =~ s/\$title/$this->getPath()/ge;

    my $rowTemplate        = $templates->expandTemplate('FORM:display:row');
    my $hasAllFieldsHidden = 1;
    foreach my $fieldDef ( @{ $this->fields } ) {
        my $fm = $topicObject->get( 'FIELD', $fieldDef->{name} );
        next unless $fm;
        my $fa = $fieldDef->{attributes} || '';
        unless ( $fa =~ m/H/ ) {
            $hasAllFieldsHidden = 0;
            my $row = $rowTemplate;

            # Legacy; handle special macros
            $row =~ s/%A_TITLE%/\$title/g;
            $row =~ s/%A_VALUE%/\$value(display)/g;    # Legacy

            $text .= $fieldDef->renderForDisplay( $row, $fm->{value} );
        }
    }
    return '' if $hasAllFieldsHidden;

    my $footer = $templates->expandTemplate('FORM:display:footer');
    $footer =~ s/\$title/$this->getPath()/ge;
    $text .= $footer;

    # Legacy: substitute remaining placeholders in header and footer
    $text =~ s/%A_TITLE%/$this->getPath()/ge;

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
    foreach my $field (@fields) {

        # Fields are name, value, title, but there is no other type
        # information so we have to treat them all as "text" :-(
        my $fieldDef = $this->create(
            'Foswiki::Form::FieldDefinition',
            name  => $field->{name},
            title => $field->{title} || $field->{name}
        );
        push( @fieldDefs, $fieldDef );
    }
    return \@fieldDefs;
}

1;

package Foswiki::Form::ParseFinished;
use Moo;
extends qw( Foswiki::Exception );
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
