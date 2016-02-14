# See bottom of file for license and copyright information
package Foswiki::Form::Select;
use v5.14;

use Moo;
use namespace::clean;
extends qw(Foswiki::Form::ListFieldDefinition);

use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

has minSize => ( is => 'rw', );
has maxSize => ( is => 'rw', );

sub BUILD {
    my $this = shift;

    # Parse the size to get min and max
    my $size = $this->size || 1;
    if ( $size =~ m/^\s*(\d+)\.\.(\d+)\s*$/ ) {
        $this->minSize($1);
        $this->maxSize($2);
    }
    else {
        my $minSize = $size;
        $minSize =~ s/[^\d]//g;
        $minSize ||= 1;
        $this->minSize($minSize);
        $this->maxSize($minSize);
    }
    $this->size($size);

    #must list every valid combination.
    $this->validModifiers( [ '+multi', '+values', '+multi+values' ] );
}

=begin TML

---++ getDefaultValue() -> $value
The default for a select is always the empty string, as there is no way in
Foswiki form definitions to indicate selected values. This defers the decision
on a value to the browser.

=cut

sub getDefaultValue {
    my $this = shift;
    return ( $this->has_default ? $this->default : '' );
}

sub getDisplayValue {
    my ( $this, $value ) = @_;

    return $value unless $this->isValueMapped();

    $this->getOptions();

    my @vals = ();
    foreach my $val ( split( /\s*,\s*/, $value ) ) {
        if ( defined( $this->valueMap->{$val} ) ) {
            push @vals, $this->valueMap->{$val};
        }
        else {
            push @vals, $val;
        }
    }
    return join( ", ", @vals );
}

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;

    my $choices = '';

    $value = '' unless defined $value;
    my %isSelected = map { $_ => 1 } split( /\s*,\s*/, $value );
    foreach my $item ( @{ $this->getOptions() } ) {
        my $option = $item
          ; # Item9647: make a copy not to modify the original value in the array
        my %params = ( class => 'foswikiOption', );
        $params{selected} = 'selected' if $isSelected{$option};
        if ( $this->_descriptions->{$option} ) {
            $params{title} = $this->_descriptions->{$option};
        }
        if ( defined( $this->valueMap->{$option} ) ) {
            $params{value} = $option;
            $option = $this->valueMap->{$option};
        }
        $option =~ s/<nop/&lt\;nop/g;
        $choices .= CGI::option( \%params, $option );
    }
    my $size = scalar( @{ $this->getOptions() } );
    if ( $size > $this->maxSize ) {
        $size = $this->maxSize;
    }
    elsif ( $size < $this->minSize ) {
        $size = $this->minSize;
    }
    my $params = {
        class => $this->cssClasses('foswikiSelect'),
        name  => $this->name,
        size  => $this->size,
    };
    if ( $this->isMultiValued() ) {
        $params->{'multiple'} = 'multiple';
        $value = CGI::Select( $params, $choices );

        # Item2410: We need a dummy control to detect the case where
        #           all checkboxes have been deliberately unchecked
        # Item3061:
        # Don't use CGI, it will insert the value from the query
        # once again and we need an empt field here.
        $value .= '<input type="hidden" name="' . $this->name . '" value="" />';
    }
    else {
        $value = CGI::Select( $params, $choices );
    }
    return ( '', $value );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
