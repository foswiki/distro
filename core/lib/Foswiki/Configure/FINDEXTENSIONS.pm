#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2006 Foswiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# Plug-in module for finding and handling plugins
package Foswiki::Configure::FINDEXTENSIONS;
use base 'Foswiki::Configure::Pluggable';

use strict;

use Foswiki::Configure::Pluggable;
use Foswiki::Configure::Type;
use Foswiki::Configure::Value;

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new('Find New Extensions');

    return $this;
}

1;
