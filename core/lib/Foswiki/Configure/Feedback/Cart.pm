# See bottom of file for license and copyright information

package Foswiki::Configure::Feedback::Cart;

=begin TML

"Shopping cart" holding unsaved changes.

Holds changes across sessions (esp. timeouts).

=cut

use constant majorVersion => '2';
use constant minorVersion => '0';

# ######################################################################
# get - Get cart from the session
# ######################################################################

sub get {
    my $class = shift;
    my ($session) = @_;

    my $cart = $session->param('pending');
    my @r = $cart = $class->verify($cart);

    return wantarray ? @r : $r[0];
}

# ######################################################################
# save - Save a cart in the session
# ######################################################################

sub save {
    my $cart = shift;
    my ($session) = @_;

    $session->param( 'pending', $cart );

    $session->flush;
}

# ######################################################################
# verify - instantiate/validate a cart retrieved from storage
# ######################################################################

sub verify {
    my $class = shift;
    my ($cart) = @_;

    if (   $cart
        && $cart->isa(__PACKAGE__)
        && $cart->{version}
        && $cart->{version} =~ /^(\d+)\.(\d+)$/
        && $1 == majorVersion )
    {
        return wantarray ? ( $cart, 1 ) : $cart;
    }

    $cart = {
        version => sprintf( "%d.%d", majorVersion, minorVersion ),
        time    => time,
        param   => {},
        items   => {},
    };
    bless $cart, $class;

    return wantarray ? ( $cart, 0 ) : $cart;
}

# ######################################################################
# empty - empty a session's cart
# ######################################################################

sub empty {
    my $class = shift;
    my ($session) = @_;

    my $cart = $class->verify(undef);
    $cart->save($session);

    return $cart;
}

# ######################################################################
# update - update a cart from %updated keys and $query values
# ######################################################################

sub update {
    my $cart = shift;
    my ( $query, $updated ) = @_;

    $cart->{time}  = time;
    $cart->{items} = {};

    # Items are updated implicity
    # params are stored explicity, and take priority (but should be disjoint)
    # params are used for 'Hidden" items (in spec, but not sent to GUI).

    foreach my $keys ( keys %$updated ) {
        next if ( $keys =~ /^\{ConfigureGUI\}/ );
        next if ( exists $cart->{params}{$keys} );

        my $typeof = $query->param("TYPEOF:$keys") || 'UNKNOWN';
        $cart->{items}{$keys} = [ $typeof, $query->param($keys) ];
    }
    return $cart;
}

# ######################################################################
# param - stored item accessor
# ######################################################################

sub items {
    my $cart = shift;

    return ( keys %{ $cart->{items} } );
}

sub param {
    my $cart = shift;
    my ($name) = @_;

    # param() - return known params

    return ( keys %{ $cart->{param} } )
      unless (@_);

    return unless ( defined $name );

    # param(name, Type, value(s)) - store value

    if ( @_ > 2 ) {
        shift;
        my $type = shift || 'UNKNOWN';
        $cart->{param}{$name} = [ $type, @_ ];
        delete $cart->{items}{$name};
    }
    elsif ( @_ == 2 ) {

        # param(name, undef) - delete value

        die "Arg 2 must be undef\n" if ( defined $_[1] );
        delete $cart->{items}{$name};
        delete $cart->{param}{$name};
        return;
    }

    # param( name ) - return (type, value) or (first) value

    my $value = $cart->{param}{$name};
    defined $value or $value = $cart->{items}{$name};

    return unless ($value);

    my @value = @$value;
    return wantarray ? @value : $value[1];
}

# ######################################################################
# loadQuery  - update $query with all pending changes from $cart
# loadParams - update $query with just parameters from $cart
# ######################################################################

sub loadQuery {
    my $cart = shift or return undef;

    #    my ($query) = @_;

    return $cart->_load( 'items,param', @_ );
}

sub loadParams {
    my $cart = shift or return undef;

    #    my ($query) = @_;

    return $cart->_load( 'param', @_ );
}

sub _load {
    my $cart = shift;
    my ( $what, $query ) = @_;

    foreach my $ptype ( split( ',', $what ) ) {
        foreach my $item ( keys %{ $cart->{$ptype} } ) {
            my @value  = @{ $cart->{$ptype}{$item} };
            my $typeof = "TYPEOF:$item";
            my $type   = shift(@value) || 'UNKNOWN';
            $query->param( $item,   @value );
            $query->param( $typeof, $type );
        }
    }

    return $cart->timeSaved;
}

# ######################################################################
# delete - delete a param (or list) from cart
# ######################################################################

sub delete {
    my $cart = shift;
    my (@names) = @_;

    my @result;

    foreach my $name (@names) {
        my $value = $cart->{param}{$name};
        defined $value or $value = $cart->{items}{$name};

        next unless ($value);

        my @value = @$value;
        push @result, @value;

        delete $cart->{param}{$name};
        delete $cart->{items}{$name};
    }

    return wantarray ? @result : $result[1];
}

# ######################################################################
# removeParams - remove params from $query
# ######################################################################

sub removeParams {
    my $cart = shift;
    my ($query) = @_;

    # Used after loadCGIParams has extracted all the values and any checker
    # runs to prevent the params from being sent to the GUI.

    foreach my $param ( keys %{ $cart->{param} } ) {
        $query->delete( $param, "TYPEOF:$param" );
    }
    return;
}

# ######################################################################
# timeSaved - return time cart was saved
# ######################################################################

sub timeSaved {
    my $cart = shift;

    return $cart->{time};
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

