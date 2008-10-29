# See bottom of file for license and copyright details
# This packages subclasses TWiki::Form::FieldDefinition to implement
# the =date= type

package TWiki::Form::Date;
use base 'TWiki::Form::FieldDefinition';

use strict;

use TWiki::Contrib::JSCalendarContrib;

sub new {
    my $class = shift;
    my $this = $class->SUPER::new( @_ );
    my $size = $this->{size} || '';
    $size =~ s/[^\d]//g;
    $size = 20 if( !$size || $size < 1 ); # length(31st September 2007)=19
    $this->{size} = $size;
    return $this;
}

sub renderForEdit {
    my( $this, $web, $topic, $value ) = @_;

    $value = CGI::textfield(
        { name => $this->{name},
          id => 'id'.$this->{name},
          size=> $this->{size},
          value => $value,
          class => $this->can('cssClasses') ?
            $this->cssClasses('twikiInputField', 'twikiEditFormDateField') :
              'twikiInputField twikiEditFormDateField'});
    my $ifFormat = $TWiki::cfg{JSCalendarContrib}{format} || '%e %b %Y';
    TWiki::Contrib::JSCalendarContrib::addHEAD( 'twiki' );
    my $button .= CGI::image_button(
        -name => 'calendar',
        -onclick =>
          "return showCalendar('id$this->{name}','$ifFormat')",
        -src=> $TWiki::cfg{PubUrlPath} . '/' .
          $TWiki::cfg{SystemWebName} .
            '/JSCalendarContrib/img.gif',
        -alt => 'Calendar',
        -class => 'twikiButton twikiEditFormCalendarButton' );
    $value .= CGI::span(
        { -class => 'twikiMakeVisible' },
        '&nbsp;' . $button
    );
    my $session = $this->{session};
    $value = $session->renderer->getRenderedVersion(
        $session->handleCommonTags( $value, $web, $topic ));

    return ( '', $value );
}

1;
__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

