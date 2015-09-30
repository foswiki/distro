# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor;

# Base class of editor plugins

use strict;
use Assert;

use Foswiki::Func ();

# Subclasses only
sub new {
    my ( $class, $editableType ) = @_;
    return bless( { type => $editableType || 'text' }, $class );
}

# Shared code used by radio buttons and checkboxes
sub _tickbox {
    my ( $this, $cell, $colDef, $unexpandedValue ) = @_;
    my $expandedValue = Foswiki::Func::expandCommonVariables($unexpandedValue);
    $expandedValue =~ s/^\s*(.*?)\s*$/$1/;

    my %attrs;
    my @defaults;
    my @options;
    $expandedValue = ",$expandedValue,";

    my $i = 0;
    foreach my $option ( @{ $colDef->{values} } ) {
        push( @options, $option );
        my $expandedOption = Foswiki::Func::expandCommonVariables($option);
        $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
        $expandedOption =~ s/(\W)/\\$1/g;
        $attrs{$option}{label} = $expandedOption;
        $attrs{$option}{class} = "$this->{css_class} erpJS_input";
        if ( $expandedValue =~ /,\s*$expandedOption\s*,/ ) {
            $attrs{$option}{checked} = 'checked';
            push( @defaults, $option );
        }
    }
    return ( \%attrs, \@defaults, \@options );
}

=begin TML

---++ ObjectMethod editor($cell, $colDef, $inRow, $unexpandedValue)
Generate an HTML editor for the cell

=cut

sub htmlEditor {
    my ( $this, $cell, $colDef, $inRow, $unexpandedValue ) = @_;
    return Foswiki::Render::html(
        'input',
        {
            type  => 'text',
            class => 'erpJS_input',
            name  => $cell->getElementName(),
            size  => $colDef->{size} || 10,
            value => $unexpandedValue
        }
    );
}

=begin TML

---++ ObjectMethod metadata($cell, $colDef)
Generate JQuery metadata for the cell

=cut

sub jQueryMetadata {
    my ( $this, $cell, $colDef, $text ) = @_;
    my $data = {};
    $data->{type} = $this->{type};
    $data->{name} = "CELLDATA";      #$cell->getID();
    if ( defined $colDef->{size} ) {
        $data->{size} = $colDef->{size};
    }
    return $data;
}

# Used by subclasses
sub _addSaveButton {
    my ( $this, $data ) = @_;

    $data->{submit} = Foswiki::Render::html(
        'button',
        {
            type  => 'submit',
            class => 'ui-icon ui-icon-disk erp-button'
        }
    );
}

# Used by subclasses
sub _addCancelButton {
    my ( $this, $data ) = @_;

    $data->{cancel} = Foswiki::Render::html(
        'button',
        {
            type  => 'submit',
            class => 'ui-icon erp-button ui-icon-cancel'
        }
    );
}

=begin TML

---++ ObjectMethod forceValue()
Called when a value is being loaded into the internal table from url
params; gives an opportunity for the type to override the value (e.g. for
a generated value, or for a label)

=cut

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
