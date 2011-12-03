# See bottom of file for license and copyright information
package Assert;

# Derived from Carp::Assert
# Slightly simplified derived version of Assert
# Differences are:
#  1. ASSERT instead of assert
#  2. has to be _explicitly enabled_ using the $ENV{ASSERT}
#  3. should and shouldnt have been removed
#  4. Added UNTAINTED and TAINT
#
# Usage is as for Carp::Assert except that you have to explicitly
# enable asserts using the environment variable ENV{FOSWIKI_ASSERTS}
# (or ENV{TWIKI_ASSERTS})
# add ENV{FOSWIKI_ASSERTS} = 1; to your bin/setlib.cfg or bin/LocalLib.cfg

use strict;

use locale;    # so result of lc() is tainted
use Exporter;
our @ISA = ('Exporter');

our %EXPORT_TAGS = (
    NDEBUG => [ 'ASSERT', 'UNTAINTED', 'TAINT', 'DEBUG' ],
    DEBUG  => [ 'ASSERT', 'UNTAINTED', 'TAINT', 'DEBUG' ],
);

our $VERSION = '$Rev$';
our $DIRTY   = lc('x');    # Used in TAINT

Exporter::export_tags(qw(NDEBUG DEBUG));

# constant.pm, alas, adds too much load time (yes, I benchmarked it)
sub ASSERTS_ON  { 1 }      # CONSTANT
sub ASSERTS_OFF { 0 }      # CONSTANT

# Provides the same return value and the same context
# for its parameters as the real TAINT and UNTAINTED
sub noop($) { return $_[0] }

our $soft = 0;

# Export the proper DEBUG flag if FOSWIKI_ASSERTS is set,
# otherwise export noop versions of our routines
sub import {
    no warnings 'redefine';
    no strict 'refs';
    if ( $ENV{FOSWIKI_ASSERTS} || $ENV{TWIKI_ASSERTS} ) {
        $soft = 1 if $ENV{FOSWIKI_ASSERTS} and $ENV{FOSWIKI_ASSERTS} eq 'soft';
        *DEBUG = *ASSERTS_ON;
        Assert->export_to_level( 1, @_ );
    }
    else {
        my $caller = caller;
        *{ $caller . '::ASSERT' }    = \&dummyASSERT;
        *{ $caller . '::TAINT' }     = \&noop;
        *{ $caller . '::UNTAINTED' } = \&noop;
        *{ $caller . '::DEBUG' }     = \&ASSERTS_OFF;
    }
    use strict 'refs';
    use warnings 'redefine';
}

# Provides the same return value and the same context
# for its parameters as the real ASSERT
sub dummyASSERT($;$) {
    return;
}

sub ASSERT ($;$) {
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

# Test if a value is untainted
sub UNTAINTED($) {
    local ( @_, $@, $^W ) = @_;
    my $x;
    return eval { $x = $_[0], kill 0; 1 };
}

# Taint the datum passed and return the tainted value
sub TAINT($) {
    return substr( $_[0] . $DIRTY, 0, length( $_[0] ) );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
Copyright 2002 by Michael G Schwern <schwern@pobox.com>
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
