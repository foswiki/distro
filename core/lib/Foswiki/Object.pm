
package Foswiki::Object;

=begin TML

---+ package Foswiki::Object

*NOTE:* This document is in draft status and may change as a result of
a discussion, raised concerns or reasonable proposals.

This is the base object for all Foswiki classes. It defines the default
behaviour and general policies for all descendants.

---++ Behavior

=Foswiki::Object= is a subclass of Moo and as such inherits all it's
features.

=cut

use strict;
use warnings;
use Assert;
use Moo;
use namespace::clean;

=begin TML

---++ ClassMethod BUILDARGS()

Converts positional constructor parameters to named ones. Tries to detect if constructor is already being called using named notation.

The =BUILDARGS()= uses array =@_newParameters= declared statically on a class to get information about the order of parameters.
For example, for =Foswiki::Class=:

<verbatim>
package Foswiki::Class;
use Moo;

our @_newParameters = qw( param1 param2 );
use namespace::clean;

has param1 => (is => 'rw');
has param2 => (is => 'ro');
has param3 => (is => 'rw');

1;
</verbatim>

the following notations are valid:

<verbtaim>
my $object1 = Foswiki::Class->new($param1, $param2);
my $object2 = Foswiki::Class->new($param2);
my $object3 = Foswiki::Class->new(param1 => 1, param2 => '2', param3 => 'additional');
</verbatim>

Note that for =$object2= the =BUILD()= method would be called with undefined param2.

=cut

sub BUILDARGS {
    my ( $class, @params ) = @_;

    # Skip processing if already have passed with a hash ref.
    return $params[0] if @params == 1 && ref( $params[0] ) eq 'HASH';

    my $paramHash;

    no strict 'refs';
    if ( defined *{ $class . '::_newParameters' }{ARRAY} ) {
        my @newParameters = @{ $class . '::_newParameters' };
        my $isHash        = 0;
        if ( ( @params % 2 ) == 0 ) {
            my $prop_re = '^(' . join( '|', @newParameters ) . ')$';
            my %params = @params;
            foreach my $prop ( keys %params ) {
                last if $isHash = ( $prop =~ $prop_re );
            }
        }
        unless ($isHash) {
            @{$paramHash}{@newParameters} = @params;
        }
    }

# If $paramHash is undef at this point then either @params is a key/value pairs array or no @_newParameters array defined.
# SMELL XXX Number of elements in @params has to be checked and an exception thrown if it's inappropriate.
    unless ( defined $paramHash ) {
        Carp::confess("Odd number of elements in parameters hash")
          if ( @params % 2 ) == 1;
        $paramHash = {@params};
    }

    use strict 'refs';

    return $paramHash;
}

sub DEMOLISH {
    my $self = shift;
    if ( $self->can('finish') ) {

     # SMELL every Foswiki::Object ancestor has to use DEMOLISH as the standard.
     # XXX We have to generate a warning if this condition is met.
        $self->finish;
    }

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors
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
