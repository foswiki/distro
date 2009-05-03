# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Prefs::TopicRAM

This is a preference backend used to get preferences defined in a topic.

=cut

package Foswiki::Prefs::TopicRAM;

use Foswiki::Prefs::BaseBackend ();
@ISA = qw(Foswiki::Prefs::BaseBackend);

use strict;

use Foswiki::Prefs::Parser ();

sub new {
    my ( $proto, $metaObject ) = @_;

    my $this = $proto->SUPER::new();
    $this->{values} = {};
    $this->{local}  = {};

    if ( $metaObject->exists() ) {
        Foswiki::Prefs::Parser::parse( $metaObject, $this );
    }

    return $this;
}

sub finish {
    my $this = shift;
    undef $this->{values};
    undef $this->{local};
}

sub prefs {
    my $this = shift;
    return keys %{ $this->{values} };
}

sub get {
    my ( $this, $key ) = @_;
    return $this->{values}{$key};
}

sub getLocal {
    my ( $this, $key ) = @_;
    return $this->{local}{$key};
}

sub insert {
    my ( $this, $type, $key, $value ) = @_;

    $this->cleanupInsertValue(\$value);

    my $index = $type eq 'Set' ? 'values' : 'local';
    $this->{$index}{$key} = $value;
    return 1;
}

sub stringify {
    my ( $this, $html ) = @_;
    my $s = '';
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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
