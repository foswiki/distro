# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor::row;

use strict;
use Assert;

use Foswiki::Plugins::EditRowPlugin::Editor::label ();

our @ISA = ('Foswiki::Plugins::EditRowPlugin::Editor::label');

# Uneditable row index label
sub htmlEditor {
    my ( $this, $cell, $colDef, $inRow, $unexpandedValue ) = @_;
    return $inRow->isHeader ? '<nop>' : $cell->rowIndex($colDef);
}

sub getInitialValue {
    my ( $this, $colDef, $cell, $row ) = @_;
    return $row + $colDef->{size};
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
