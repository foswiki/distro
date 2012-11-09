# See bottom of file for license and copyright information

package Foswiki::Configure::Feedback::Cart;

=begin TML

"Shopping cart" holding unsaved changes.

Holds changes across sessions (esp. timeouts).

=cut

# ######################################################################
# new - create a new cart from %updated keys and $query values
# ######################################################################

sub new {
    my $class = shift;
    my ( $query, $updated ) = @_;

    my $cart = { time => time };

    foreach my $keys ( keys %$updated ) {
        next if ( $keys =~ /^\{ConfigureGUI\}/ );

        $cart->{param}{$keys} = [ $query->param($keys) ];
        my $typeof = "TYPEOF:$keys";
        $cart->{param}{$typeof} = [ $query->param($typeof) ];
    }

    bless $cart, $class;
}

# ######################################################################
# param - item accessor
# ######################################################################

sub param {
    my $cart = shift;
    my ($name) = @_;

    return keys %{ $cart->{param} } unless (@_);

    my $value = $cart->{param}{$name};
    return unless ( defined $name && $value );

    my @value = @$value;
    return wantarray ? @result : $result[0];
}

# ######################################################################
# loadQuery - update $query with pending changes from $cart
# ######################################################################

sub loadQuery {
    my $cart = shift;
    my ($query) = @_;

    foreach my $param ( keys %{ $cart->{param} } ) {
        $query->param( $param, @{ $cart->{param}{$param} } );
    }

    return $cart->timeSaved;
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

