# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor::label;

use strict;
use Assert;

use Foswiki::Plugins::EditRowPlugin::Editor ();

our @ISA = ('Foswiki::Plugins::EditRowPlugin::Editor');

sub new {
    my $class = shift;
    return $class->SUPER::new('label');
}

sub htmlEditor {
    my ( $this, $cell, $colDef, $inRow, $unexpandedValue ) = @_;

    # Labels are not editable.
    return $unexpandedValue;
}

sub jQueryMetadata {
    return { uneditable => 1 };
}

# Called when a value is being loaded into the internal table from url
# params; gives an opportunity for the type to override the value
sub forceValue {
    my ( $this, $colDef, $cell, $row ) = @_;

    # Label cells are uneditable, so we have to keep any existing
    # value for them. If there is no value in the cell, restore
    # the initial value.
    return ( defined $cell->{text} ? $cell->{text} : $colDef->{initial_value} );
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
