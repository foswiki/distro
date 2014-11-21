# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Serialise::Json

serialise from and to JSON

=cut

package Foswiki::Serialise::Json;

use strict;
use warnings;
use JSON::Any;

=begin TML

---++ ClassMethod new( $class,  ) -> $cereal

=cut

sub new {
    my $class = shift;
    my $this = bless( {}, $class );
    return $this;
}

#The JSON serialisation uses JSON::Any to select the 'best' available JSON implementation - JSON::XS being much faster.

#TODO: should really use encode_json / decode_json as those will use utf8,
#but er, that'll cause other issues - as QUERY will blast the json into a topic..
sub write {
    my $module = shift;
    my ($result) = @_;

    return '' if ( not( defined($result) ) );
    my $j = JSON::Any->new( allow_nonref => 1 );
    return $j->to_json( $result, { allow_nonref => 1 } );
}

#TODO: should really use encode_json / decode_json as those will use utf8,
#but er, that'll cause other issues - as QUERY will blast the json into a topic..
sub read {
    my $module = shift;
    my ($result) = @_;

    return if ( $result eq '' );

    my $j = JSON::Any->new( allow_nonref => 1 );
    return $j->from_json($result);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2011 Foswiki Contributors. Foswiki Contributors
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
