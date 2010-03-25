# See bottom of file for copyright and license details
package Foswiki::Query::BinaryOP;

use strict;

use Foswiki::Query::OP;
our @ISA = ( 'Foswiki::Query::OP' );

use Foswiki::Query::SQLResult ();

sub new {
    my $class = shift;
    return $class->SUPER::new(arity => 2, @_);
}

# Determine if a string represents a valid number
sub _isNumber {
    return shift =~ m/^[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?$/;
}

# Static function to apply a comparison function to two data, tolerant
#  of whether they are numeric or not
sub compare {
    my ( $a, $b, $sub ) = @_;
    if ( _isNumber($a) && _isNumber($b) ) {
        return &$sub( $a <=> $b );
    }
    else {
        return &$sub( $a cmp $b );
    }
}

# Evaluate a node using the comparison function passed in. Extra parameters
# are passed on to the comparison function.
sub evalTest {
    my $this       = shift;
    my $node       = shift;
    my $clientData = shift;
    my $sub        = shift;
    my $a          = $node->{params}[0];
    my $b          = $node->{params}[1];
    my $ea         = $a->evaluate( @{$clientData} );
    my $eb         = $b->evaluate( @{$clientData} );
    $ea            = '' unless defined $ea;
    $eb            = '' unless defined $eb;
    if ( ref($ea) eq 'ARRAY' ) {
        my @res;
        foreach my $lhs (@$ea) {
            push( @res, $lhs ) if &$sub( $lhs, $eb, @_ );
        }
        if ( scalar(@res) == 0 ) {
            return;
        }
        elsif ( scalar(@res) == 1 ) {
            return $res[0];
        }
        return \@res;
    }
    else {
        return &$sub( $ea, $eb, @_ );
    }
}

sub xpath {
    my $this = shift;
    my $node = shift;
    my $a = $node->{params}[0];
    my $b = $node->{params}[1];
    return '('.$a->xpath().' '.($this->{xpath_op} || $this->{name})
              .' '.$b->xpath(@_).')';
}

1;
__END__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2009 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
