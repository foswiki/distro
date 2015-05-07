# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Serialise::Json

serialise from and to JSON

=cut

package Foswiki::Serialise::Json;

use strict;
use warnings;
use JSON;

=begin TML

---++ ClassMethod new( $class,  ) -> $cereal

=cut

sub new {
    my $class = shift;
    my $this = bless( {}, $class );
    return $this;
}

sub write {
    my $module = shift;
    my ($result) = @_;

    return '' if ( not( defined($result) ) );
    my $j = JSON->new->allow_nonref(1);
    return $j->encode($result);
}

sub read {
    my $module = shift;
    my ($result) = @_;

    return if ( $result eq '' );

    my $j = JSON->new->allow_nonref(1);
    return $j->decode($result);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2015 Foswiki Contributors. Foswiki Contributors
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
