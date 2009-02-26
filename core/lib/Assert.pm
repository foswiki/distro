package Assert;
use base 'Exporter';
require 5.006;

# Derived from Carp::Assert
# Copyright 2004 Crawford Currie
# Copyright 2002 by Michael G Schwern <schwern@pobox.com
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
# add ENV{FOSWIKI_ASSERTS} = 1; to you bin/setlib.cfg or bin/LocalLib.cfg

use strict;

use vars qw(@ISA $VERSION %EXPORT_TAGS $DIRTY);

BEGIN {
    $VERSION = '0.01';
    $DIRTY = $ENV{PATH}; # Used in TAINT

    $EXPORT_TAGS{NDEBUG} = ['ASSERT', 'UNTAINTED', 'TAINT', 'DEBUG'];
    $EXPORT_TAGS{DEBUG}  = $EXPORT_TAGS{NDEBUG};
    Exporter::export_tags(qw(NDEBUG DEBUG));
}

# constant.pm, alas, adds too much load time (yes, I benchmarked it)
sub ASSERTS_ON  { 1 }    # CONSTANT
sub ASSERTS_OFF { 0 }    # CONSTANT

sub noop { return $_[0] }

# Export the proper DEBUG flag if FOSWIKI_ASSERTS is set,
# otherwise export noop versions of our routines
sub import {
    no warnings 'redefine';
    no strict 'refs';
    if ( $ENV{FOSWIKI_ASSERTS} || $ENV{TWIKI_ASSERTS} ) {
        *DEBUG = *ASSERTS_ON;
        Assert->export_to_level( 1, @_ );
    }
    else {
        my $caller = caller;
        *{ $caller . '::ASSERT' }    = \&noop;
        *{ $caller . '::TAINT' }     = \&noop;
        *{ $caller . '::DEBUG' }     = \&ASSERTS_OFF;
    }
    use strict 'refs';
    use warnings 'redefine';
}

sub ASSERT ($;$) {
    unless ( $_[0] ) {
        require Carp;
        my $msg = 'Assertion';
        $msg .= " ($_[1])" if defined $_[1];
        $msg .= " failed!\n";
        Carp::confess($msg);
    }
    return undef;
}

# Test if a value is untainted
sub UNTAINTED($) {
    local ( @_, $@, $^W ) = @_;
    my $x;
    return eval { $x = $_[0], kill 0; 1 };
}

# Taint the datum passed and return the tainted value
sub TAINT($) {
    return substr($_[0].$DIRTY, 0, length($_[0]));
}

1;
