# See bottom of file for license and copyright information
package Foswiki::Form::Radio;

use strict;
use warnings;

use Foswiki::Form::ListFieldDefinition ();
our @ISA = ('Foswiki::Form::ListFieldDefinition');

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    $this->{size} ||= 0;
    $this->{size} =~ s/\D//g;
    $this->{size} ||= 0;

    # SMELL: Non-zero -columns attribute forces CGI::radio_group() to use
    #        HTML3 tables for layout
    $this->{size} = 4 if ( $this->{size} < 1 );

    return $this;
}

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;

    my $selected = '';
    my $session  = $this->{session};
    my %attrs;
    foreach my $item ( @{ $this->getOptions() } ) {
        $attrs{$item} = {
            class => $this->cssClasses('foswikiRadioButton'),
            title => $topicObject->expandMacros($item)
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
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
