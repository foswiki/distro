# See bottom of file for license and copyright information

package Foswiki::Configure::TypeUIs::SCRIPTHASH;

# The SCRIPTHASH pluggable generates SCRIPTHASH type values

use strict;
use warnings;

require Foswiki::Configure::TypeUIs::URLPATH;
our @ISA = ('Foswiki::Configure::TypeUIs::URLPATH');

use Foswiki::Configure::Checkers::ScriptUrlPaths ();

sub new {
    my $class = shift;

    return bless( { name => 'SCRIPTHASH' }, $class );
}

sub string2value {
    my ( $this, $qval ) = @_;
    return eval $this->{item}->{default} unless defined $qval;
    return $this->SUPER::string2value($qval);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
