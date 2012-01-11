# See bottom of file for license and copyright
package Unit::Response;
use strict;
use warnings;

=begin TML

---+ package Unit::Request

=cut

# SMELL: this package should not be in Unit; it is a Foswiki class and
# should be in test/unit

use Foswiki::Response();
our @ISA = qw( Foswiki::Response );

my $response;    # for proper finalization

BEGIN {
    require Foswiki;
    require CGI;
    my $_new = \&Foswiki::new;
    no warnings 'redefine';
    *Foswiki::new = sub {
        my $t = $_new->(@_);
        $response = $t->{response};
        return $t;
    };
    my $_finish = \&Foswiki::finish;
    *Foswiki::finish = sub {
        $_finish->(@_);
        undef $response;
    };
    use warnings 'redefine';
}

sub new {
    die "You must call Unit::Response::new() *after* Foswiki::new()\n"
      unless defined $response;
    bless( $response, __PACKAGE__ ) unless $response->isa(__PACKAGE__);
    return $response;
}

sub DESTROY {
    my $this = shift;
    undef $response;
    bless( $this, $Unit::Response::ISA[0] );
}

1;

__DATA__

Author: Gilmar Santos Jr

Copyright (C) 2008-2010 Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
