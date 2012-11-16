# See bottom of file for license and copyright information

use strict;
use warnings;

package Foswiki::Configure::Checkers::ConfigureGUI::MODAL;

# This is the base class for the pseudo-checkers that implement modal
# actions.  These look enough like real checkers to leverage the checker/
# feedback infrastructure, but they are only instantiated as feedback actions,
# typically in response to a button.

use Foswiki::Configure(qw/$query $session/);

require Foswiki::Configure::ModalTemplates;

require Foswiki::Configure::Checker;
our @ISA = (qw(Foswiki::Configure::Checker));

sub check {
    my $this = shift;
    my ($valobj) = @_;

    die "Modal action checker called from "
      . join( ' ', ( caller(1) )[ 0, 3, 1, 2 ] ) . "\n";
}

# Called to process action
#
# Button 1 generates form
# Button 2 processes change

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    my $keys = $valobj->getKeys();

    my $e = '';

    my $template = Foswiki::Configure::ModalTemplates->new($this);

    if ( $button == 1 ) {
        $e = $this->generateForm( $keys, $query, $session, $template );
        return wantarray ? ( $e, 0 ) : $e;
    }

    die "Unknown button $keys $button\n" unless ( $button == 2 );

    $e = $this->processForm( $keys, $query, $session, $template );

    return wantarray ? ( $e, 0 ) : $e;
}

sub generateForm {
    my $this = shift;
    my ( $keys, $query, $session, $templateArgs ) = @_;

    my $text = '<h1>No form was provided by '
      . join( '', ( caller(1) )[ 0, 3, 1, 2 ] ) . '</h1>';

    return $this->FB_MODAL( 'r,o', $text );
}

sub processForm {
    my $this = shift;
    my ( $keys, $query, $session, $templateArgs ) = @_;

    return $this->NOTE( "No form action was provided by "
          . join( '', ( caller(1) )[ 0, 3, 1, 2 ] )
          . '</h1>' );
}

1;

__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
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
