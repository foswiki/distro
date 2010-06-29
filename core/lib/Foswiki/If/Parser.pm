# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::If::Parser

Support for the conditions in %IF{} statements.

=cut

package Foswiki::If::Parser;

use strict;
use warnings;

use Foswiki::Query::Parser ();
our @ISA = ('Foswiki::Query::Parser');

use Assert;
use Foswiki::If::Node ();

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new(
        {
            nodeClass => 'Foswiki::If::Node',
        }
    );
    die "{Operators}{If} is undefined; re-run configure"
      unless defined( $Foswiki::cfg{Operators}{If} );
    foreach my $op ( @{ $Foswiki::cfg{Operators}{If} } ) {
        eval "require $op";
        ASSERT( !$@ ) if DEBUG;
        $this->addOperator( $op->new() );
    }

    return $this;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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
