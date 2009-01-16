# See bottom of file for license and copyright details
package Foswiki::Form::Radio;
use base 'Foswiki::Form::ListFieldDefinition';

use strict;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    $this->{size} ||= 0;
    $this->{size} =~ s/\D//g;
    $this->{size} ||= 0;
    $this->{size} = 4 if ( $this->{size} < 1 );

    return $this;
}

sub renderForEdit {
    my ( $this, $web, $topic, $value ) = @_;

    my $selected = '';
    my $session  = $this->{session};
    my %attrs;
    foreach my $item ( @{ $this->getOptions() } ) {
        $attrs{$item} = {
            class => $this->cssClasses(
                'foswikiRadioButton'
            ),
            label => $session->handleCommonTags( $item, $web, $topic )
        };

        $selected = $item if ( $item eq $value );
    }

    return (
        '',
        CGI::radio_group(
            -name       => $this->{name},
            -values     => $this->getOptions(),
            -default    => $selected,
            -columns    => $this->{size},
            -attributes => \%attrs
        )
    );
}

1;
__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

