# See bottom of file for license and copyright information
package Foswiki::Form::Select;
use strict;
use warnings;

use Foswiki::Form::ListFieldDefinition ();
our @ISA = ('Foswiki::Form::ListFieldDefinition');

use Assert;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    # Parse the size to get min and max
    $this->{size} ||= 1;
    if ( $this->{size} =~ /^\s*(\d+)\.\.(\d+)\s*$/ ) {
        $this->{minSize} = $1;
        $this->{maxSize} = $2;
    }
    else {
        $this->{minSize} = $this->{size};
        $this->{minSize} =~ s/[^\d]//g;
        $this->{minSize} ||= 1;
        $this->{maxSize} = $this->{minSize};
    }

    return $this;
}

=begin TML

---++ getDefaultValue() -> $value
The default for a select is always the empty string, as there is no way in
Foswiki form definitions to indicate selected values. This defers the decision
on a value to the browser.

=cut

sub getDefaultValue {
    return '';
}

sub getOptions {
    my $this = shift;

    return $this->{_options} if $this->{_options};

    my $vals = $this->SUPER::getOptions(@_);
    if ( $this->{type} =~ /\+values/ ) {

        # create a values map

        $this->{valueMap} = ();
        $this->{_options} = ();
        my $str;
        foreach my $val (@$vals) {
            if ( $val =~ /^(.*[^\\])*=(.*)$/ ) {
                $str = TAINT( $1 || '' );
                $val = $2;
                $str =~ s/\\=/=/g;
            }
            else {
                $str = $val;
            }
            $this->{valueMap}{$val} = Foswiki::urlDecode($str);
            push @{ $this->{_options} }, $val;
        }
    }

    return $vals;
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
    $this->SUPER::finish();
    undef $this->{minSize};
    undef $this->{maxSize};
    undef $this->{valueMap};

    return;
}

sub isMultiValued { return shift->{type} =~ /\+multi/; }

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;

    my $choices = '';

    my %isSelected = map { $_ => 1 } split( /\s*,\s*/, $value );
    foreach my $option ( @{ $this->getOptions() } ) {
        my %params = ( class => 'foswikiOption', );
        $params{selected} = 'selected' if $isSelected{$option};
        if ( defined( $this->{valueMap}{$option} ) ) {
            $params{value} = $option;
            $option = $this->{valueMap}{$option};
        }
        $option =~ s/<nop/&lt\;nop/go;
        $choices .= CGI::option( \%params, $option );
    }
    my $size = scalar( @{ $this->getOptions() } );
    if ( $size > $this->{maxSize} ) {
        $size = $this->{maxSize};
    }
    elsif ( $size < $this->{minSize} ) {
        $size = $this->{minSize};
    }
    my $params = {
        class => $this->cssClasses('foswikiSelect'),
        name  => $this->{name},
        size  => $this->{size},
    };
    if ( $this->isMultiValued() ) {
        $params->{'multiple'} = 'multiple';
        $value = CGI::Select( $params, $choices );

        # Item2410: We need a dummy control to detect the case where
        #           all checkboxes have been deliberately unchecked
        # Item3061:
        # Don't use CGI, it will insert the value from the query
        # once again and we need an empt field here.
        $value .=
          '<input type="hidden" name="' . $this->{name} . '" value="" />';
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
