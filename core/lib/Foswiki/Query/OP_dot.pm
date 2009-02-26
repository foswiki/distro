# See bottom of file for copyright and license details

=begin TML

---+ package Foswiki::Query::OP_dot

=cut

package Foswiki::Query::OP_dot;
use base 'Foswiki::Query::BinaryOP';

use strict;

sub new {
    my $class = shift;
    return $class->SUPER::new( name => '.', prec => 800 );
}

sub evaluate {
    my $this   = shift;
    my $node   = shift;
    my %domain = @_;
    my $a      = $node->{params}[0];
    my $lval   = $a->evaluate(@_);
    return undef unless ( defined $lval );
    my $b = $node->{params}[1];
    my $res = $b->evaluate( data => $lval, tom => $domain{tom} );
    if ( ref($res) eq 'ARRAY' && scalar(@$res) == 1 ) {
        return $res->[0];
    }
    return $res;
}

1;

__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
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
