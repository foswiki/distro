# See bottom of file for license and copyright information

# This file is required from Assert.pm when
# asserts are active; it loads the debug implementations.

use strict;
use locale;    # so result of lc() is tainted

our $DIRTY = lc('x');    # Used in TAINT
our $soft  = 0;

sub import {
    $soft = 1
      if defined( $ENV{FOSWIKI_ASSERTS} ) && $ENV{FOSWIKI_ASSERTS} eq 'soft';
    $SIG{'__WARN__'} = sub { die @_ }
      unless $soft;
    Assert->export_to_level( 1, @_ );
}

sub ASSERT($;$) {
    unless ( $_[0] ) {
        require Carp;
        my $msg = 'Assertion';
        $msg .= " ($_[1])" if defined $_[1];
        $msg .= " failed!\n";
        if ($soft) {
            Carp::cluck($msg);
        }
        else {
            Carp::confess($msg);
        }
    }
    return;
}

sub UNTAINTED($) {
    local ( @_, $@, $^W ) = @_;
    my $x;
    return eval { $x = $_[0], kill 0; 1 };
}

sub TAINT($) {
    return substr( $_[0] . $DIRTY, 0, length( $_[0] ) );
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
