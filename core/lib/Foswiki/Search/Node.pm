# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Search

Foswiki::Search::Node is a refactoring mid-step that contains the legacy SEARCH tokens

If if becomes useful, it will become a set of Nodes as for Foswiki::Query

=cut

package Foswiki::Search::Node;

use strict;
use warnings;

use Assert;
use Error qw( :try );

use Foswiki::Infix::Node ();
our @ISA = ('Foswiki::Infix::Node');

=begin TML

---++ ClassMethod new($search, $tokens, $options)

Construct a Legacy Search token container (its not yet a proper Node)

=cut

sub new {
    my ( $class, $search, $tokens, $options ) = @_;
    my $this =
      bless( { tokens => $tokens, search => $search, options => $options },
        $class );
    return $this;
}

1;
__END__
Author: Sven Dowideit - http://fosiki.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
