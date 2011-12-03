# See bottom of file for license and copyright information
# See bottom of file for license and copyright details
# This packages subclasses Foswiki::Form::FieldDefinition to implement
# the =date= type

package Foswiki::Form::Date;
use Foswiki::Form::FieldDefinition ();
@ISA = ('Foswiki::Form::FieldDefinition');

use strict;
use warnings;

use Foswiki::Contrib::JSCalendarContrib ();

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    my $size  = $this->{size} || '';
    $size =~ s/[^\d]//g;
    $size = 20 if ( !$size || $size < 1 );    # length(31st September 2007)=19
    $this->{size} = $size;
    return $this;
}

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;
    my ( $web, $topic );

    unless ( ref($topicObject) ) {

        # Pre 1.1
        ( $this, $web, $topic, $value ) = @_;
        undef $topicObject;
    }

    my $format =
         Foswiki::Func::getPreferencesValue('JSCALENDARCONTRIB_FORMAT')
      || $Foswiki::cfg{JSCalendarContrib}{format}
      || '%e %b %Y';

    $value = Foswiki::Contrib::JSCalendarContrib::formatDate( $value, $format );

    my $field = CGI::textfield(
        {
            name  => $this->{name},
            id    => 'id' . $this->{name},
            size  => $this->{size},
            value => $value,
            class => $this->can('cssClasses')
            ? $this->cssClasses( 'foswikiInputField',
                'foswikiEditFormDateField' )
            : 'foswikiInputField foswikiEditFormDateField'
        }
    );
    Foswiki::Contrib::JSCalendarContrib::addHEAD('foswiki');
    my $button .= CGI::image_button(
        -name    => 'calendar',
        -onclick => "return showCalendar('id$this->{name}','$format')",
        -src     => $Foswiki::cfg{PubUrlPath} . '/'
          . $Foswiki::cfg{SystemWebName}
          . '/JSCalendarContrib/img.gif',
        -alt   => 'Calendar',
        -class => 'foswikiButton foswikiEditFormCalendarButton'
    );
    $field .=
      CGI::span( { -class => 'foswikiMakeVisible' }, '&nbsp;' . $button );

    if ($topicObject) {
        $field = $topicObject->renderTML( $topicObject->expandMacros($field) );
    }
    else {

        # Pre 1.1
        my $session = $this->{session};
        $field =
          $session->renderer->getRenderedVersion(
            $session->handleCommonTags( $field, $web, $topic ) );
    }
    return ( '', $field );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
