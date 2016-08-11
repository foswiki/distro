# See bottom of file for license and copyright information

=begin TML

---+!! Module Foswiki::Class

This is a wrapper package for Moo/Moose. It is intended for automatic applying
of some functionality to a class and for simplifying switching from Moo to any
other compatible OO framework would this decision ever be made.

---++ Usage

To use this module it is sufficient to replace any occurence of

<verbatim>
use Moo;
</verbatim>

with

<verbtaim>
use Foswiki::Class;
</verbatim>

---++ Parameters

The following parameters are support by this module:

| =callbacks= | Provide support for callbacks |

---++ Callbacks support.

When =callbacks= parameter is used:

<verbtaim>
use Foswiki::Class qw(callbacks);
</verbatim>

a subroutine =callback_names= is exported into a class' namespace and
=Foswiki::Aux::Callbacks= role gets applied. For example:

<verbatim>
package Foswiki::SomeClass;

use Foswiki::Class qw(callbacks);
use namespace::clean;
extends qw(Foswiki::AppObject);

callback_names qw(callback1 callback2);

sub someMethod {
    my $this = shift;
    
    $this->callback('callback1', $cbParams);
}
</verbatim>

Here we get two callbacks registered: =Foswiki::SomeClass::callback1= and
=Foswiki::SomeClass::callback2=.

See =Foswiki::Aux::Callbacks=.

*NOTE* Applying a role by =Foswiki::Class= has a side effect of polluting a
class namespace with =Moo='s subroutimes like =extends=, =with=, =has=, etc.
By polluting it is meant that these subs are visible to the outside world as
object methods. If this is undesirable behaviour than role must be applied
manually by the class using =with=.

=cut

package Foswiki::Class;
use v5.14;

use Carp;

require Moo;
our @ISA = qw(Moo);

sub import {
    my ($class) = shift;
    my $target = caller;

    # Define options we would provide for classes.
    my %options = ( callbacks => 0, );

    my @p;
    while (@_) {
        my $param = shift;
        if ( exists $options{$param} ) {
            $options{$param} = 1;
        }
        else {
            push @p, $param;
        }
    }

    foreach my $option ( keys %options ) {
        my $installer = __PACKAGE__->can("_install_$option");
        $installer->( $class, $target );
    }

    @_ = ( $class, @p );
    goto &Moo::import;
}

# Actually we're duplicating Moo::_install_coderef here in way. But we better
# avoid using a module's internalls.
sub _inject_code {
    my ( $name, $code ) = @_;

    no strict "refs";
    *{$name} = $code;
    use strict "refs";
}

sub _assign_role {
    my ( $target, $role ) = @_;
    unless ( $target->does($role) ) {
        eval "package $target; use Moo; with qw($role); 1;";
        Carp::confess "Cannot assign role $role to $target: $@" if $@;
    }
}

sub _install_callbacks {
    my ( $class, $target ) = @_;

    _inject_code( "${target}::callback_names", \&_handler_callbacks );
}

sub _handler_callbacks {
    my $target = caller;
    _assign_role( $target, 'Foswiki::Aux::Callbacks' );
    Foswiki::Aux::Callbacks::registerCallbackNames( $target, @_ );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
