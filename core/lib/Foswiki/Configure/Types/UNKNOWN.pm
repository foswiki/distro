# See bottom of file for license and copyright information

#
# Value type for objects of unknown type, such as uncommented
# config settings from LocalSite.cfg
package Foswiki::Configure::Types::UNKNOWN;

use strict;
use warnings;

use Foswiki::Configure::Type ();
our @ISA = ('Foswiki::Configure::Type');

sub new {
    my $class = shift;

    return bless( { name => 'UNKNOWN' }, $class );
}

sub prompt {
    my $this = shift;
    return
        $this->SUPER::prompt(@_)
      . '<br /><span class="foswikiAlert"> .spec ERROR! TYPE '
      . ( $this->{failinfo} || 'UNKNOWN' )
      . '</span>';
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
