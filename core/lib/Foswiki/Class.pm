# See bottom of file for license and copyright information

package Foswiki::Class;
use v5.14;

=begin TML

---+!! Module Foswiki::Class

This is a wrapper package for Moo and intended to be used as a replacement and
a shortcut for a bunch lines of code like:

<verbatim>
use v5.14;
use Moo;
use namespace::clean;
with qw(Foswiki::AppObject);
</verbatim>

The above could be replaced with a single line of:

<verbatim>
use Foswiki::Class qw(app);
</verbatim>

---++ Usage

A set of features is exported to the calling module is defined by =use=
parameter keywords. If no parameters defined then all it does is applies
=[[CPAN:Moo][Moo]]=, ':5.14'
[[http://perldoc.perl.org/feature.html#FEATURE-BUNDLES][feature]] bundle, and
cleans namespace with =[[CPAN:namespace::clean][namespace::clean]]=.

---++ Parameters

The following parameters are support by this module:

| *Parameter* | *Description* |
| =app= | Class being created will have =Foswiki::AppObject= role applied. |
| =callbacks= | Provide support for callbacks |
| =:5.XX= | A string prefixed with colon is treated as a feature bundle name and passed over to the =feature= module as is. This allows to override the ':5.14' default. |

---++ Callbacks support.

When =callbacks= parameter is used:

<verbatim>
use Foswiki::Class qw(callbacks);
</verbatim>

a subroutine =callback_names= is exported into a class' namespace and
=Foswiki::Aux::Callbacks= role gets applied. =callback_names= accepts a list
and registers names from the list as callbacks supported by the class.

For example:

<verbatim>
package Foswiki::SomeClass;

use Foswiki::Class qw(app callbacks);

callback_names qw(callback1 callback2);

sub someMethod {
    my $this = shift;
    
    $this->callback('callback1', $cbParams);
}
</verbatim>

Here we get two callbacks registered: =Foswiki::SomeClass::callback1= and
=Foswiki::SomeClass::callback2=.

See =Foswiki::Aux::Callbacks=.

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

my ( %_assignedRoles, %_registeredAttrs, %_ISA, %_WITH );

# BEGIN Install wrappers for Moo's has/with/extends to record basic object information. Works only when $ENV{FOSWIKI_ASSERTS} is true.
sub _fw_has {
    my $target = shift;
    my ($attr) = @_;

    #say STDERR "Registering attr $attr on $target";

    push @{ $_registeredAttrs{$target}{list} },
      { attr => $attr, options => [ @_[ 1 .. $#_ ] ] };
}

sub _fw_with {
    my $target = shift;

    #say STDERR "$target WITH ", join( ", ", @_ );
    push @{ $_WITH{$target} }, @_;
}

sub _fw_extends {
    my $target = shift;

    #say STDERR "$target EXTENDS ", join( ", ", @_ );
    push @{ $_ISA{$target} }, @_;
}

if ( $ENV{FOSWIKI_ASSERTS} ) {

    # Moo doesn't provide a clean way to get all object's attributes. The only
    # really clean way to distinguish between a key on object's hash and an
    # attribute is to record what is passed to Moo's sub 'has'. Since Moo
    # generates it for each class separately (as well as other 'keywords') and
    # since Moo::Role does it on its own too then the only really clean way to
    # catch everything is to tap into Moo's guts. And the best way to do so is
    # to intercept calls to _install_tracked() as this sub is used to register
    # every single Moo-generated code ref. Though this is a hacky way on its own
    # but the rest approaches seem to be even more hacky and no doubt
    # unreliable.
    foreach my $module (qw(Moo Moo::Role)) {
        my $ns               = Foswiki::getNS($module);
        my $_install_tracked = *{ $ns->{'_install_tracked'} }{CODE};
        _inject_code(
            $module,
            '_install_tracked',
            sub {
                my $ovCode;
                my $target    = $_[0];
                my $codeName  = $_[1];
                my $ovSubName = "_fw_" . $_[1];
                $ovCode = __PACKAGE__->can($ovSubName);
                if ($ovCode) {

                    #say STDERR "Installing wrapper $codeName on $target";
                    my $origCode = $_[2];
                    $_[2] = sub {
                        $ovCode->( $target, @_ );
                        goto &$origCode;
                    };
                }
                goto &$_install_tracked;
            }
        );
    }
}

# END of has/with/extends wrappers.

sub import {
    my ($class) = shift;
    my $target = caller;

    # Define options we would provide for classes.
    my %options = (
        callbacks => { use => 0, },
        app       => { use => 0, },
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

            #push @noNsClean, @{ $opt->{keywords} } if defined $opt->{keywords};
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

    require feature;
    feature->import($featureSet);

    namespace::clean->import(
        -cleanee => $target,
        -except  => \@noNsClean,
    );

    @_ = ( $class, @p );
    goto &Moo::import;
}

sub _getAllAttrs {
    foreach my $class (@_) {
        my @classAttrs;
        if ( defined $_registeredAttrs{$class} ) {
            if ( defined $_registeredAttrs{$class}{cached} ) {

                # Skip the class if already cached.
                next;
            }
            if ( defined $_registeredAttrs{$class}{list} ) {
                push @classAttrs,
                  map { $_->{attr} } @{ $_registeredAttrs{$class}{list} };
            }
        }
        if ( defined $_ISA{$class} ) {
            push @classAttrs, _getAllAttrs( @{ $_ISA{$class} } );
        }
        if ( defined $_WITH{$class} ) {
            push @classAttrs, _getAllAttrs( @{ $_WITH{$class} } );
        }
        $_registeredAttrs{$class}{cached} = \@classAttrs;
    }
    return map { @{ $_registeredAttrs{$_}{cached} } } @_;
}

sub getClassAttributes {
    my $class = shift;

    #require Data::Dumper;

    #say STDERR Data::Dumper->Dump(
    #    [ \%_registeredAttrs, \%_ISA, \%_WITH ],
    #    [qw(%_registeredAttrs %_ISA %_WITH)]
    #);

    return _getAllAttrs($class);
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

        #say STDERR "Applying roles ",
        #  join( ", ", @{ $_assignedRoles{$target} } ), " to $target";

        push @{ $_WITH{$target} }, @{ $_assignedRoles{$target} };

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

sub _handler_callback_names {
    my $target = caller;
    Foswiki::Aux::Callbacks::registerCallbackNames( $target, @_ );
}

sub _install_callbacks {
    my ( $class, $target ) = @_;

    Foswiki::load_package('Foswiki::Aux::Callbacks');
    _assign_role( $target, 'Foswiki::Aux::Callbacks' );
    _inject_code( $target, "callback_names", *_handler_callback_names );
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
