# See bottom of file for license and copyright information

#
# ======================================================================
# Abstract base class of all configuration components. A configuration
# component may be a collection item (a ConfigSection) or an individual Value.
#
# Objects of this class are intended to form a tree with references in
# both directions, circular references ahead.  But configure isn't
# supposed to be run in a persistent environment anyway.
package Foswiki::Configure::Item;

use strict;

sub new {
    my $class = shift;

    my $this = bless( {}, $class );
    $this->{parent}   = undef;
    $this->{desc}     = '';
    $this->{errors}   = 0;
    $this->{warnings} = 0;

    return $this;
}

sub getDepth {
    my $depth = 0;
    my $mum   = shift;

    while ($mum) {
        $depth++;
        $mum = $mum->{parent};
    }
    return $depth;
}

sub addToDesc {
    my ( $this, $desc ) = @_;

    $this->{desc} .= "$desc\n";
}

sub isExpertsOnly {
    return 0;
}

sub haveSettingFor {
    die "Implementation required";
}

# Purpose
#     Accept an attribute setting for this item (e.g. a key name).
#     Sort of a generic write accessor.
sub set {
    my ( $this, %params ) = @_;
    foreach my $k ( keys %params ) {
        $this->{$k} = $params{$k};
    }
}

# Purpose
#     Increase a numeric value, recursing up to a parentless item
# Assumptions
#     All item levels have $key defined and initialized
#     (intended for use with 'warnings' and 'errors')
#     Parents of items are items (or precisely: can inc())
sub inc {
    my ( $this, $key ) = @_;

    $this->{$key}++;
    $this->{parent}->inc($key) if $this->{parent};
}

sub getSectionObject {
    return undef;
}

sub getValueObject {
    return undef;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
