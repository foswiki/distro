# See bottom of file for license and copyright information

package Foswiki::Types;

use Foswiki;
use Type::Library -base, -declare => qw<AllOf AnyOf>;
use Type::Utils -all;
require Error::TypeTiny;
require Type::Tiny::Intersection;
require Type::Tiny::Union;
BEGIN { extends "Types::Standard"; }

=begin TML

---+!! Package Foswiki::Types



---++ SYNOPSIS

---++ DESCRIPTION

=cut

declare AllOf, where { 1 }, constraint_generator => sub {
    my @cParams = @_;
    Error::TypeTiny->throw(
        message => "AllOf[`a] requires at least one parameter" )
      unless @cParams > 1;
    foreach my $validator (@cParams) {
             $validator->isa("Type::Tiny::Class")
          || $validator->isa("Type::Tiny::Role")
          || $validator->isa("Type::Tiny::Duck")
          || Error::TypeTiny->throw( message =>
"Parameter to AllOf[`a] expected to be InstanceOf[`a], ConsumerOf[`a], and HasMethods[`a]"
          );
    }

    return Type::Tiny::Intersection->new(
        type_constraints => \@cParams,
        display_name     => sprintf( 'AllOf[%s]', join( ",", @cParams ) ),
    );
};

declare AnyOf, where { 1 }, constraint_generator => sub {
    my @cParams = @_;
    Error::TypeTiny->throw(
        message => "AnyOf[`a] requires at least one parameter" )
      unless @cParams > 1;

    return Type::Tiny::Union->new(
        type_constraints => \@cParams,
        display_name     => sprintf( 'AnyOf[%s]', join( ",", @cParams ) ),
    );
};

# Helper types

declare FatalException,    as InstanceOf ['Foswiki::Exception::Fatal'];
declare DeadlyException,   as ConsumerOf ['Foswiki::Exception::Deadly'];
declare HarmlessException, as ConsumerOf ['Foswiki::Exception::Harmless'];
declare TypeException,     as InstanceOf ['Error::TypeTiny'];

=begin TML

---++ METHODS

=cut

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2018 Foswiki Contributors. Foswiki Contributors
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
