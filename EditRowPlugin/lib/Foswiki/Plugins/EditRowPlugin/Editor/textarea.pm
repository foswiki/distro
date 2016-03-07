# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor::textarea;

use strict;
use Assert;

use Foswiki::Plugins::EditRowPlugin::Editor::text ();

our @ISA = ('Foswiki::Plugins::EditRowPlugin::Editor::text');

sub new {
    my $class = shift;
    return $class->SUPER::new('textarea');
}

sub htmlEditor {
    my ( $this, $cell, $colDef, $inRow, $unexpandedValue ) = @_;

    my ( $rows, $cols ) = split( /x/i, $colDef->{size} );
    $rows =~ s/[^\d]//;
    $cols =~ s/[^\d]//;
    $rows = 3  if $rows < 1;
    $cols = 30 if $cols < 1;

    # replace BRs to display multiple lines nicely
    my $tmptext = $unexpandedValue;
    $tmptext =~ s#<br( /)?>#\r\n#gi;
    $tmptext =~ s/%BR%/\r\n/gi;

    return Foswiki::Render::html(
        'textarea',
        {
            class => 'erpJS_input',
            rows  => $rows,
            cols  => $cols,
            name  => $cell->getElementName()
        },
        $tmptext
    );
}

sub jQueryMetadata {
    my $this = shift;
    my ( $cell, $colDef, $text ) = @_;
    my $data = $this->SUPER::jQueryMetadata(@_);
    $data->{rows} = 3;
    $data->{cols} = 30;
    if ( $data->{size} =~ /^(\d+)[xX](\d+)$/ ) {
        $data->{rows} = $1 if $1 > 0;
        $data->{cols} = $2 if $2 > 0;
    }
    delete $data->{size};
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
