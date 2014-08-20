# Foswiki off-line task management framework addon for Foswiki
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

package Foswiki::Configure::Checkers::Certificate::ClientChecker;

use Foswiki::Configure::Checkers::Certificate ();
our @ISA = ( 'Foswiki::Configure::Checkers::Certificate' );

sub check_current_value {
    my ($this, $reporter) = @_;
    $this->checkUsage( $this->{item}->{keys}, 'client', $reporter );
}

1;

__END__

This is an original work by Timothe Litt.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html
