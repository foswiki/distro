# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor::date;
use v5.14;

use Assert;
use Foswiki::Contrib::JSCalendarContrib ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Plugins::EditRowPlugin::Editor);

around BUILDARGS => sub {
    my $orig = shift;
    Foswiki::Contrib::JSCalendarContrib::addHEAD();
    return $orig->( @_, type => 'datepicker' );
};

around jQueryMetadata => sub {
    my $orig = shift;
    my ( $this, $cell, $colDef, $text ) = @_;
    my $data = $orig->( $this, $cell, $colDef, $text );
    my $format =
         $colDef->{values}->[0]
      || Foswiki::Func::getPreferencesValue('JSCALENDARCONTRIB_FORMAT')
      || $Foswiki::cfg{JSCalendarContrib}{format}
      || '%e %b %Y';
    $data->format($format);
    return $data;
};

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
