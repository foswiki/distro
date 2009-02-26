# See bottom of file for license and copyright details
package Foswiki::Form::Checkbox;
use base 'Foswiki::Form::ListFieldDefinition';

use strict;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    $this->{size} ||= 0;
    $this->{size} =~ s/\D//g;
    $this->{size} ||= 0;
    $this->{size} = 4 if ( $this->{size} < 1 );

    return $this;
}

# Checkboxes can't provide a default from the form spec
sub getDefaultValue { undef }

# Checkbox store multiple values
sub isMultiValued { 1 }

sub renderForEdit {
    my ( $this, $web, $topic, $value ) = @_;

    my $session = $this->{session};
    my $extra   = '';
    if ( $this->{type} =~ m/\+buttons/ ) {
        my $boxes = scalar( @{ $this->getOptions() } );
        $extra = CGI::br();
        $extra .= CGI::button(
            -class   => 'foswikiCheckbox',
            -value   => $session->i18n->maketext('Set all'),
            -onClick => 'checkAll(this,2,' . $boxes . ',true)'
        );
        $extra .= '&nbsp;';
        $extra .= CGI::button(
            -class   => 'foswikiCheckbox',
            -value   => $session->i18n->maketext('Clear all'),
            -onClick => 'checkAll(this,1,' . $boxes . ',false)'
        );
    }
    $value = '' unless defined($value) && length($value);
    my %isSelected = map { $_ => 1 } split( /\s*,\s*/, $value );
    my %attrs;
    my @defaults;
    foreach my $item ( @{ $this->getOptions() } ) {

        # NOTE: Does not expand $item in label
        $attrs{$item} = {
            class => $this->cssClasses('foswikiCheckbox'),
            label => $session->handleCommonTags( $item, $web, $topic ),
        };

        if ( $isSelected{$item} ) {
            $attrs{$item}{checked} = 'checked';
            push( @defaults, $item );
        }
    }
    $value = CGI::checkbox_group(
        -name       => $this->{name},
        -values     => $this->getOptions(),
        -defaults   => \@defaults,
        -columns    => $this->{size},
        -attributes => \%attrs
    );

    # Item2410: We need a dummy control to detect the case where
    #           all checkboxes have been deliberately unchecked
    # Item3061:
    # Don't use CGI, it will insert the sticky value from the query
    # once again and we need an empty field here.
    $value .= '<input type="hidden" name="' . $this->{name} . '" value="" />';
    return ( $extra, $value );
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

