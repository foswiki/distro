# See bottom of file for license and copyright information

package Foswiki::Class;
use v5.14;

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

<verbatim>
use Foswiki::Class;
</verbatim>

---++ Parameters

The following parameters are support by this module:

| *Parameter* | *Description* |
| =callbacks= | Provide support for callbacks |

---++ Callbacks support.

When =callbacks= parameter is used:

<verbatim>
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

# Naming conventions for this module:
# _install_something – functions that install feature `something' into the target module;
# _handler_someword - function which implements exported keyword `someword'

use Carp;

require Foswiki;
require Moo::Role;
require Moo;
require namespace::clean;
use B::Hooks::EndOfScope 'on_scope_end';

use constant DEFAULT_FEATURESET => ':5.14';

our @ISA = qw(Moo);

my %_assignedRoles;

sub import {
    my ($class) = shift;
    my $target = caller;

    # Define options we would provide for classes.
    my %options = (
        callbacks => {
            use => 0,

            # Keywords exported with this option.
            keywords => [qw(callback_names)],
        },
        app => { use => 0, },
    );

    my @p;
    my @noNsClean  = qw(meta);
    my $featureSet = DEFAULT_FEATURESET;
    while (@_) {
        my $param = shift;
        if ( $param =~ /^:/ ) {
            $featureSet = $param;
            next;
        }
        if ( exists $options{$param} ) {
            my $opt = $options{$param};
            $opt->{use} = 1;
            push @noNsClean, @{ $opt->{keywords} } if defined $opt->{keywords};
        }
        else {
            push @p, $param;
        }
    }

    foreach my $option ( grep { $options{$_}{use} } keys %options ) {
        my $installer = __PACKAGE__->can("_install_$option");
        die "INTERNAL:There is no installer for option $option"
          unless defined $installer;
        $installer->( $class, $target );
    }

    on_scope_end {
        $class->_apply_roles;
    };

    feature->import($featureSet);

    namespace::clean->import(
        -cleanee => $target,
        -except  => \@noNsClean,
    );

    @_ = ( $class, @p );
    goto &Moo::import;
}

# Actually we're duplicating Moo::_install_coderef here in a way. But we better
# avoid using a module's internalls.
sub _inject_code {
    my ( $target, $name, $code ) = @_;

    Foswiki::getNS($target)->{$name} = $code;
}

sub _apply_roles {
    my $class = shift;
    foreach my $target ( keys %_assignedRoles ) {
        Moo::Role->apply_roles_to_package( $target,
            @{ $_assignedRoles{$target} } );
        $class->_maybe_reset_handlemoose($target);
        delete $_assignedRoles{$target};
    }
}

sub _assign_role {
    my ( $class, $role ) = @_;
    push @{ $_assignedRoles{$class} }, $role;
}

sub _install_callbacks {
    my ( $class, $target ) = @_;

    Foswiki::load_package('Foswiki::Aux::Callbacks');
    _assign_role( $target, 'Foswiki::Aux::Callbacks' );
    _inject_code( $target, "callback_names", \&_handler_callbacks );
}

sub _handler_callbacks (@) {
    my $target = caller;
    Foswiki::Aux::Callbacks::registerCallbackNames( $target, @_ );
}

sub _install_app {
    my ( $class, $target ) = @_;
    Foswiki::load_package('Foswiki::AppObject');
    _assign_role( $target, 'Foswiki::AppObject' );
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
