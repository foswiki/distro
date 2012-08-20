# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor::date;

use strict;
use Assert;

use Foswiki::Plugins::EditRowPlugin::Editor ();

our @ISA = ('Foswiki::Plugins::EditRowPlugin::Editor');

use Foswiki::Contrib::JSCalendarContrib ();

sub new {
    my $class = shift;
    Foswiki::Contrib::JSCalendarContrib::addHEAD();
    return $class->SUPER::new('datepicker');
}

sub jQueryMetadata {
    my ( $this, $cell, $colDef, $text ) = @_;
    my $data = $this->SUPER::jQueryMetadata( $cell, $colDef, $text );
    my $format =
         $colDef->{values}->[0]
      || Foswiki::Func::getPreferencesValue('JSCALENDARCONTRIB_FORMAT')
      || $Foswiki::cfg{JSCalendarContrib}{format}
      || '%e %b %Y';
    $data->{format} = $format;
    return $data;
}

sub htmlEditor {
    my ( $this, $cell, $colDef, $inRow, $unexpandedValue ) = @_;

    # NOTE: old versions of JSCalendarContrib won't fire onchange
    return Foswiki::Contrib::JSCalendarContrib::renderDateForEdit(
        $cell->getElementName(), $unexpandedValue,
        $colDef->{values}->[0], { class => 'erpJS_input' }
    );
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
