# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor::select;

use strict;
use Assert;

use Foswiki::Plugins::EditRowPlugin::Editor ();

our @ISA = ('Foswiki::Plugins::EditRowPlugin::Editor');

sub new {
    my $class = shift;
    return $class->SUPER::new('erpselect');
}

sub htmlEditor {
    my ( $this, $cell, $colDef, $inRow, $unexpandedValue ) = @_;

    my $expandedValue = Foswiki::Func::expandCommonVariables($unexpandedValue);
    $expandedValue =~ s/^\s*(.*?)\s*$/$1/;

    my $options;
    foreach my $option ( @{ $colDef->{values} } ) {
        my $expandedOption = Foswiki::Func::expandCommonVariables($option);
        $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
        my %opts;
        if ( $expandedOption eq $expandedValue ) {
            $opts{selected} = 'selected';
        }
        $options .= Foswiki::Render::html( 'option', \%opts, $option );
    }
    return Foswiki::Render::html(
        'select',
        {
            name  => $cell->getElementName(),
            size  => $colDef->{size},
            class => 'erpJS_input'
        },
        $options
    );
}

sub jQueryMetadata {
    my $this = shift;
    my ( $cell, $colDef, $text ) = @_;
    my $data = $this->SUPER::jQueryMetadata(@_);

    if ( $colDef->{values} && scalar( @{ $colDef->{values} } ) ) {

        # Format suitable for passing to an "erpselect" type
        my %d = (
            order    => [ @{ $colDef->{values} } ],
            selected => $cell->{text},
            keys     => {}
        );
        map {

# We can't pass the expanded value because it may contain things that can't be represented
# in a select (Item10770)
# $d{keys}->{$_} = Foswiki::Func::renderText(Foswiki::Func::expandCommonVariables($_));
            $d{keys}->{$_} = $_;    # unexpanded value, replete with %'s
        } @{ $colDef->{values} };
        $data->{data} = \%d;
    }
    $this->_addSaveButton($data);
    return $data;
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2011 Foswiki Contributors
All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this notice.
