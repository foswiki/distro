# See bottom of file for copyright and license details

=pod

---+ package TWiki::If::Parser

Support for the conditions in %IF{} statements.

=cut

package TWiki::If::Parser;
use base 'TWiki::Query::Parser';

use strict;
use Assert;
use TWiki::If::Node;

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new(
        {
            nodeClass => 'TWiki::If::Node',
            words     => qr/([A-Z][A-Z0-9_:]+|({[A-Z0-9_]+})+)/i
        }
    );
    die "{Operators}{If} is undefined; re-run configure"
      unless defined( $TWiki::cfg{Operators}{If} );
    foreach my $op ( @{ $TWiki::cfg{Operators}{If} } ) {
        eval "require $op";
        ASSERT( !$@ ) if DEBUG;
        $this->addOperator( $op->new() );
    }

    return $this;
}

1;

__DATA__

Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/, http://TWiki.org/

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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

Author: Crawford Currie http://c-dot.co.uk
