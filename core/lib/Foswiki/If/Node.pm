# See bottom of file for copyright and license details

=begin TML

---+ package Foswiki::If::Node

Node class for the result of an If statement parse

=cut

package Foswiki::If::Node;
use base 'Foswiki::Query::Node';

use strict;

require Foswiki::Infix::Node;

sub newLeaf {
    my ( $class, $val, $type ) = @_;
    if ( $type == $Foswiki::Infix::Node::NAME && $val =~ /^({\w+})+$/ ) {
        eval '$val = $Foswiki::cfg' . $val;
        return $class->SUPER::newLeaf( $val, $Foswiki::Infix::Node::STRING );
    }
    else {
        return $class->SUPER::newLeaf( $val, $type );
    }
}

# Used wherever a plain string is expected, this method suppresses automatic
# lookup of names in meta-data
sub _evaluate {
    my $this = shift;
    my $result;

    if ( !ref( $this->{op} ) ) {
        return $this->{params}[0];
    }
    else {
        return $this->evaluate(@_);
    }
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
# Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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

Author: Crawford Currie http://c-dot.co.uk
