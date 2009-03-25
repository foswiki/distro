# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::RcsLite

Implementation of =Foswiki::Store= for stores that use the RCS version
control system to manage disk files. This class inherits most of its
functionality from =Foswiki::Store::VCStore=, which it shares with
=Foswiki::Store::RcsWrap=.

For readers who are familiar with Foswiki version 1.0, this class
has no equivalent in Foswiki 1.0. The equivalent of the old
=Foswiki::Store::RcsLite= is the new =Foswiki::Store::RcsLiteHandler=.

=cut

package Foswiki::Store::RcsLite;
use base 'Foswiki::Store::VCStore';

use strict;
use Assert;

# This constructor is required to hide the =Foswiki::Store::RcsLiteHandler=
# class during construction, so that the core can simply say "give me a new
# XXX store" without having to pass additional parameters.
sub new {
    my ( $class, $session ) = @_;
    return $class->SUPER::new( $session, 'Foswiki::Store::RcsLiteHandler' );
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
