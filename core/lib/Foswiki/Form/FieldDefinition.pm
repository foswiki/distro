# See bottom of file for license and copyright information
# base class for all form field types

=begin TML

---+ package Foswiki::Form::FieldDefinition

Base class of all field definition classes.

Type-specific classes are derived from this class to define specific
per-type behaviours. This class also provides default behaviours for when
a specific type cannot be loaded.

=cut

package Foswiki::Form::FieldDefinition;

use strict;
use warnings;
use Assert;
use CGI ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new(%...)

Construct a new FieldDefinition. Parameters are passed in a hash. See
Form.pm for how it is called. Subclasses should pass @_ on to this class.

=cut

sub new {
    my $class = shift;
    my %attrs = @_;
    ASSERT( $attrs{session} ) if DEBUG;

    $attrs{name}        ||= '';
    $attrs{attributes}  ||= '';
    $attrs{description} ||= '';
    $attrs{type}        ||= '';    # default
    $attrs{size}        ||= '';
    $attrs{size} =~ s/^\s*//;
    $attrs{size} =~ s/\s*$//;
    $attrs{validModifiers} ||= [];

    return bless( \%attrs, $class );
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

    undef $this->{name};
    undef $this->{type};
    undef $this->{size};
    undef $this->{value};
    undef $this->{description};
    undef $this->{attributes};
    undef $this->{default};

    undef $this->{session};
}

=begin TML

---++ isEditable() -> $boolean

Is the field type editable? Labels aren't, for example. Subclasses may need
to redefine this.

=cut

sub isEditable { 1 }

=begin TML

---++ isMultiValued() -> $boolean

Is the field type multi-valued (i.e. does it store multiple values)?
Subclasses may need to redefine this.

=cut

sub isMultiValued { 0 }

=begin TML

---++ isTextMergeable() -> $boolean

Is this field type mergeable using a conventional text merge?

=cut

# can't merge multi-valued fields (select+multi, checkbox)
sub isTextMergeable { return !shift->isMultiValued() }

=begin TML

---++ isMandatory() -> $boolean

Is this field mandatory (required)?

=cut

sub isMandatory { return shift->{attributes} =~ m/M/ }

=begin TML

---++ renderForEdit( $topicObject, $value ) -> ($col0html, $col1html)
   =$topicObject= - the topic being edited
Render the field for editing. Returns two chunks of HTML; the
=$col0html= is appended to the HTML for the first column in the
form table, and the =$col1html= is used as the content of the second column.

=cut

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;

    # Treat like text, make it reasonably long, add a warning
    return (
        '<br /><span class="foswikiAlert">MISSING TYPE '
          . $this->{type}
          . '</span>',
        CGI::textfield(
            -class    => $this->cssClasses('foswikiAlert foswikiInputField'),
            -name     => $this->{name},
            -size     => 80,
            -override => 1,
            -value    => $value,
        )
    );
}

=begin TML

---++ cssClasses(@classes) -> $classes
Construct a list of the CSS classes for the form field. Adds additional
class specifiers related to the attributes of the field e.g mandatory.
Pass it a list of the other classnames you want on the field.

=cut

sub cssClasses {
    my $this = shift;
    if ( $this->isMandatory() ) {
        push( @_, 'foswikiMandatory' );
    }
    return join( ' ', @_ );
}

=begin TML

---++ getDefaultValue() -> $value
Try and get a sensible default value for the field from the
values stored in the form definition. The result should be
a value string.

Some subclasses may not support the definition of defaults in
the form definition. In that case this method should return =undef=.

=cut

sub getDefaultValue {
    my $this = shift;

    my $value =
      ( exists( $this->{default} ) ? $this->{default} : $this->{value} );
    $value = '' unless defined $value;    # allow 0 values

    return $value;
}

=begin TML

---++ renderHidden($meta) -> $html
Render the form in =$meta= as a set of hidden fields.

=cut

sub renderHidden {
    my ( $this, $meta ) = @_;

    my $value;
    if ( $this->{name} ) {
        my $field = $meta->get( 'FIELD', $this->{name} );
        $value = $field->{value};
    }

    my @values;

    if ( defined($value) ) {
        if ( $this->isMultiValued() ) {
            push( @values, split( /\s*,\s*/, $value ) );
        }
        else {
            push( @values, $value );
        }
    }
    else {
        $value = $this->getDefaultValue();
        push( @values, $this->getDefaultValue() ) if $value;
    }

    return '' unless scalar(@values);

    return CGI::hidden( -name => $this->{name}, -default => \@values );
}

=begin TML

---++ ObjectMethod populateMetaDataFromQuery( $query, $meta, $old ) -> ($bValid, $bPresent)

Given a CGI =$query=, a =$meta= object, and an array of =$old= field entries,
then populate the $meta with a row for this field definition, taking the
content from the query if it's there, otherwise from $old or failing that,
from the default defined for the type. Refuses to update mandatory fields
that have an empty value.

Return $bValid true if the value in $meta was updated (either from the
query or from a default in the form.
Return $bPresent true if a value was present in the query (even it was undef)

=cut

sub populateMetaFromQueryData {
    my ( $this, $query, $meta, $old ) = @_;
    my $value;
    my $bPresent = 0;

    return unless $this->{name};

    my %names = map { $_ => 1 } $query->multi_param;

    if ( $names{ $this->{name} } ) {

        # Field is present in the request
        $bPresent = 1;
        if ( $this->isMultiValued() ) {
            my @values = $query->multi_param( $this->{name} );

            if ( scalar(@values) == 1 && defined $values[0] ) {
                @values = split( /,|%2C/, $values[0] );
            }
            my %vset = ();
            foreach my $val (@values) {
                $val ||= '';
                $val =~ s/^\s*//;
                $val =~ s/\s*$//;

                # skip empty values
                $vset{$val} = ( defined $val && $val =~ m/\S/ );
            }
            $value = '';
            my $isValues = ( $this->{type} =~ m/\+values/ );

            foreach my $option ( @{ $this->getOptions() } ) {
                $option =~ s/^.*?[^\\]=(.*)$/$1/ if $isValues;

                # Maintain order of definition
                if ( $vset{$option} ) {
                    $value .= ', ' if length($value);
                    $value .= $option;
                }
            }
        }
        else {

            # Default the value to the empty string (undef would result
            # in the old value being restored)
            # Note: we test for 'defined' because value can also be 0 (zero)
            $value = $query->param( $this->{name} );
            $value = '' unless defined $value;
            if ( $this->{session}->inContext('edit') ) {
                $value = Foswiki::expandStandardEscapes($value);
            }
        }
    }

    # Find the old value of this field
    my $preDef;
    foreach my $item (@$old) {
        if ( $item->{name} eq $this->{name} ) {
            $preDef = $item;
            last;
        }
    }
    my $def;

    if ( defined($value) ) {

        # mandatory fields must have length > 0
        if ( $this->isMandatory() && length($value) == 0 ) {
            return ( 0, $bPresent );
        }

        # NOTE: title and name are stored in the topic so that it can be
        # viewed without reading in the form definition
        my $title = $this->{title};
        if ( $this->{definingTopic} ) {
            $title = '[[' . $this->{definingTopic} . '][' . $title . ']]';
        }
        $def = $this->createMetaKeyValues(
            $query, $meta,
            {
                name  => $this->{name},
                title => $title,
                value => $value
            }
        );
    }
    elsif ($preDef) {
        $def = $preDef;
    }
    else {
        return ( 0, $bPresent );
    }

    $meta->putKeyed( 'FIELD', $def ) if $def;

    return ( 1, $bPresent );
}

=begin TML

---++ ObjectMethod createMetaKeyValues( $query, $meta, $keyvalues ) -> $keyvalues

Create meta key/value pairs hash, to be overridden by subclasses.
Default implementation passes all inputs unchanged.

=cut

sub createMetaKeyValues {

    #my ( $this, $query, $meta, $keyvalues ) = @_;

    return $_[3];
}

=begin TML

---++ ObjectMethod renderForDisplay($format, $value, $attrs) -> $html

Render the field for display, under the control of $attrs.

(protected) means the resulting string is run through
Foswiki::Render::protectFormFieldValue.

   * =format= - the format to be expanded. The following tokens are available:
      * =$title= - title of the form field. if this is not available
        from the value, then the default title is taken from the form
        field definition.
      * =$value= - expanded to the (protected) value of the form field
        *before mapping*
      * =$value(display) - expanded to the (protected) value of the form
        field *after* mapping
      * =$attributes= - from the field definition
      * =$type= - from the field definition
      * =$size= - from the field definition
      * =$definingTopic= - topic in which the field is defined
   * =$value= - the scalar value of the field
   * =$attrs= - attributes. Fields used are:
      * =showhidden= - set to override H attribute
      * =newline= - replace newlines with this (default &lt;br>)
      * =bar= - replace vbar with this (default &amp;#124)
      * =break= - boolean, set to hyphenate
      * =protectdollar= - set to escape $
      * =usetitle= - if set, use this for the title rather than the title
        from the form definition

=cut

sub renderForDisplay {
    my ( $this, $format, $value, $attrs ) = @_;

    if ( !$attrs->{showhidden} ) {
        my $fa = $this->{attributes} || '';
        if ( $fa =~ m/H/ ) {
            return '';
        }
    }

    my $title = $this->{title};    # default
    $title = $attrs->{usetitle} if defined $attrs->{usetitle};

    require Foswiki::Render;

    $format =~ s/\$title/$title/g;
    if ( $format =~ m/\$value\(display\)/ ) {
        my $vd = Foswiki::Render::protectFormFieldValue(
            $this->getDisplayValue($value), $attrs );
        $format =~ s/\$value\(display\)/$vd/g;
    }
    if ( $format =~ m/\$value/ ) {
        my $v = Foswiki::Render::protectFormFieldValue( $value, $attrs );
        $format =~ s/\$value/$v/g;
    }
    $format =~ s/\$name/$this->{name}/g;
    $format =~ s/\$attributes/$this->{attributes}/g;
    $format =~ s/\$type/$this->{type}/g;
    $format =~ s/\$size/$this->{size}/g;
    my $definingTopic = $this->{definingTopic} || 'FIELD';
    $format =~ s/\$definingTopic/$definingTopic/g;

    # remove nop exclamation marks from form field value before it is put
    # inside a format like [[$topic][$formfield()]] that prevents it being
    # detected
    $format =~ s/!($Foswiki::regex{wikiWordRegex})/<nop>$1/gs;

    return $format;
}

=begin TML

---++ ObjectMethod getDisplayValue($value) -> $html

Given a value for this form field, return the *mapped* value suitable for
display. This is used when a form field must be displayed using a different
format to the way the value is stored.

The default does nothing.

=cut

sub getDisplayValue {
    my ( $this, $value ) = @_;

    return $value;
}

# Debug
sub stringify {
    my $this = shift;
    my $s    = '| '
      . $this->{name} . ' | '
      . $this->{type} . ' | '
      . $this->{size} . ' | '
      . $this->{attributes} . " |\n";
    return $s;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
