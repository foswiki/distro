# See bottom of file for license and copyright information

package Foswiki::Configure::Types::BOOLGROUP;

use strict;
use warnings;

use Foswiki::Configure::Type ();
our @ISA = ('Foswiki::Configure::Type');

sub new {
    my ( $class, $id ) = @_;

    # Make Valuer.pm call string2value with query and item keys
    # This allows retrieval of the multiple values.

    my $self = bless(
        {
            name       => $id,
            NeedsQuery => 1,
        },
        $class
    );

    return $self;
}

sub prompt {
    my ( $this, $id, $opts, $value, $class ) = @_;

    my @values;
    my @selected;

    $opts =~ s/^\s+//;
    $opts =~ s/\s+$//;

    if ( defined($value) ) {
        foreach my $sel ( split( /,\s*/, $value ) ) {
            push @selected, $sel;
        }
    }
    foreach my $opt ( split( /,\s*/, $opts ) ) {
        push @values, $opt;
    }

    return CGI::checkbox_group(
        -name     => $id,
        -values   => \@values,
        -default  => \@selected,
        -label    => '',
        -onchange => 'valueChanged(this)',
        -rows     => 1,
        -columns  => scalar @values,
    );
}

sub string2value {
    my ( $this, $query, $keys ) = @_;

    my @values = $query->param($keys);

    my $flat = join( ',', @values );
    return $flat;
}

sub equals {
    my ( $this, $val, $def ) = @_;
    return 1 if ( !defined $val && !defined $def );
    return 0 unless ( defined $val && defined $def );
    return ( $val eq $def );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
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
