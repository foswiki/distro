# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor;

# Base class of editor plugins

use strict;
use Assert;

use Foswiki::Func;

# Subclasses only
sub new {
    my ($class, $editableType) = @_;
    return bless({ type => $editableType || 'text' }, $class);
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
	if ( $colDef->{type} eq 'checkbox' ) {
	    $attrs{$option}{class} = 'foswikiCheckBox editRowPluginInput';
	}
	else {
	    $attrs{$option}{class} =
		'foswikiRadioButton editRowPluginInput';
	}
	
	if ( $expandedValue =~ /,\s*$expandedOption\s*,/ ) {
	    $attrs{$option}{checked} = 'checked';
	    push( @defaults, $option );
	}
    }
    return (\%attrs, \@defaults, \@options);
}

=begin TML

---++ ObjectMethod editor($cell, $colDef, $inRow, $unexpandedValue)
Generate an HTML editor for the cell

=cut

sub htmlEditor {
    my ( $this, $cell, $colDef, $inRow, $unexpandedValue ) = @_;
    return CGI::textfield(
	{
	    class => 'editRowPluginInput',
	    name  => $cell->getCellName(),
	    size  => $colDef->{size} || 10,
	    value => $unexpandedValue
	});
    return '';
}

=begin TML

---++ ObjectMethod metadata($cell, $colDef)
Generate JQuery metadata for the cell

=cut

sub jQueryMetadata {
    my ( $this, $cell, $colDef, $text ) = @_;
    my $data = {};
    $data->{type} = $this->{type};
    $data->{name} = "CELLDATA"; #$cell->getCellName();
    $data->{size} = $colDef->{size} if defined $colDef->{size};
    # By default we respond to an internally-raised edit event, which is raised
    # when the cell edit icon is clicked
    $data->{event} = "erp_edit";
    # Silence the noisy "Click to edit" placeholder
    $data->{placeholder} = '<div class="erp_empty_cell"></div>';
    $data->{tooltip} = '';
    return $data;
}

sub _addSaveButton {
    my ($this, $data) = @_;
    my $purl = Foswiki::Func::getPubUrlPath();
    $data->{submit} =
	"<button type'submit'><img src='$purl/System/EditRowPlugin/save.png' /></button>";
}

sub _addCancelButton {
    my ($this, $data) = @_;
    my $purl = Foswiki::Func::getPubUrlPath();
    $data->{cancel} =
	"<button type'submit'><img src='$purl/System/EditRowPlugin/stop.png' /></button>";
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
