# See bottom of file for license and copyright information
package Foswiki::Form::Checkbox;

use strict;
use warnings;

use Foswiki::Form::ListFieldDefinition ();
our @ISA = ('Foswiki::Form::ListFieldDefinition');

sub new {
    my ( $class, @args ) = @_;
    my $this = $class->SUPER::new(@args);
    $this->{size} ||= 0;
    $this->{size} =~ s/\D//g;
    $this->{size} ||= 0;
    $this->{size} = 4 if ( $this->{size} < 1 );

    return $this;
}

# Checkboxes can't provide a default from the form spec
sub getDefaultValue { return; }

# Checkbox store multiple values
sub isMultiValued { return 1; }

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;

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
    foreach my $item ( @{ $this->getOptions() } ) {

        # NOTE: Does not expand $item in title
        $attrs{$item} = {
            class => $this->cssClasses('foswikiCheckbox'),
            title => $topicObject->expandMacros($item),
        };

        if ( $isSelected{$item} ) {
            $attrs{$item}{checked} = 'checked';
        }
    }
    $value = CGI::checkbox_group(
        -name       => $this->{name},
        -values     => $this->getOptions(),
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
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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
