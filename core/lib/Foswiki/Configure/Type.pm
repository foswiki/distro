# See bottom of file for license and copyright information

# Base class of all types. Types are involved *only* in the presentation
# of values in the configure interface. They do not play any part in
# loading, saving or checking configuration values.
#
package Foswiki::Configure::Type;

use strict;
use Assert;

use CGI qw( :any );

use vars qw( %knownTypes );

sub new {
    my ( $class, $id ) = @_;

    return bless( { name => $id }, $class );
}

# Static factory
sub load {
    my $id    = shift;
    my $typer = $knownTypes{$id};
    unless ($typer) {
        my $typeClass = 'Foswiki::Configure::Types::' . $id;
        $typer =
          eval 'use ' . $typeClass . '; new ' . $typeClass . '("' . $id . '")';
        ASSERT(!$@, "Failed to load type $id: $@") if DEBUG;
        # unknown type - give it default string behaviours
        $typer = new Foswiki::Configure::Type($id) unless $typer;
        $knownTypes{$id} = $typer;
    }
    return $typer;
}

# Generates a suitable HTML prompt for the type. Default behaviour
# is a string 55% of the width of the display area.
sub prompt {
    my ( $this, $id, $opts, $value ) = @_;

    my $size = '55%';
    if ( $opts =~ /\b(\d+)\b/ ) {
        $size = $1;

        # These numbers are somewhat arbitrary..
        if ( $size > 25 ) {
            $size = '55%';
        }
    }
    return CGI::textfield(
        -name    => $id,
        -size    => $size,
        -default => $value,
        -class   => 'foswikiInputField'
    );
}

# Generates a hidden input for a value
sub hiddenInput {
    my ( $this, $id, $value ) = @_;
    return CGI::hidden($id, $value);
}

# Test to determine if two values of this type are equal.
sub equals {
    my ( $this, $val, $def ) = @_;

    if ( !defined $val ) {
        return 0 if defined $def;
        return 1;
    }
    elsif ( !defined $def ) {
        return 0;
    }
    return $val eq $def;
}

# Used to process input values from CGI. Values taken from the query
# are run through this method before being saved in the value store.
# It should *not* be used to do validation - use a Checker to do that, or
# JavaScript invoked from the prompt.
sub string2value {
    my ( $this, $val ) = @_;
    return $val;
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
#
