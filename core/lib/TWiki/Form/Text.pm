# See bottom of file for license and copyright details
package TWiki::Form::Text;
use base 'TWiki::Form::FieldDefinition';

use strict;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    my $size  = $this->{size} || '';
    $size =~ s/\D//g;
    $size = 10 if ( !$size || $size < 1 );
    $this->{size} = $size;
    return $this;
}

sub renderForEdit {
    my ( $this, $web, $topic, $value ) = @_;

    return (
        '',
        CGI::textfield(
            -class =>
              $this->cssClasses( 'twikiInputField', 'twikiEditFormTextField' ),
            -name  => $this->{name},
            -size  => $this->{size},
            -value => $value
        )
    );
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

