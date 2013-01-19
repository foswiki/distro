# See bottom of file for license and copyright information

package Foswiki::Configure::Types::SELECT;

use strict;
use warnings;

use Foswiki::Configure::Type ();
our @ISA = ('Foswiki::Configure::Type');

# Require query when input is from CGI

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    $this->{NeedsQuery} = 1;
    return $this;
}

# !mult in options enables select-multiple
# !mult:n sets size (number of lines displayed, default = 5, min = 2)
#
# For compatibility, the value of a multiple select is scalar unless
# more than one item is actually selected, when it becomes an arrayref.
#
# Consumers of !mult items must handle both cases.

sub prompt {
    my ( $this, $id, $opts, $value, $class ) = @_;

    my $mult = $opts =~ s/\s*!mult(?::(\d+))?\b//;
    my $size = ( $1 && $1 > 2 ) ? $1 : $mult ? 5 : 1;

    $opts =~ s/^\s+//;
    $opts =~ s/\s+$//;
    my $sopts = '';

    my %sel =
      ref $value ? map { $_ => 1 }
      @$value : defined $value ? ( $value => 1 ) : ();

    foreach my $opt ( split( /,\s*/, $opts ) ) {
        if ( $sel{$opt} ) {
            $sopts .= '<option selected="selected">' . $opt . '</option>';
        }
        else {
            $sopts .= '<option>' . $opt . '</option>';
        }
    }
    my @mult;
    @mult = ( multiple => 'multiple' ) if ($mult);

    return CGI::Select(
        {
            name     => $id,
            size     => $size,
            class    => "foswikiSelect $class",
            onchange => 'valueChanged(this)',
            @mult,
        },
        $sopts
    );
}

# Item save:
#
# Convert ref to log value when multiple items are selected

sub value2string {
    my $this = shift;
    my ( $keys, $value, $log ) = @_;

    if ( ref $value && defined $log ) {
        $_[2] = join( ',', sort @$value );
    }
    return $this->SUPER::value2string(@_);
}

# Convert CGI value for %cfg
#
# Compatibility requires that single no no select be stored as a
# scalar.  Only multiple selects are stored as refs.

sub string2value {
    my $this = shift;
    my ( $query, $keys ) = @_;

    my @values = $query->param($keys);

    if ( @values <= 1 ) {
        return $values[0];
    }
    return [@values];
}

# Compare two values for equality

sub equals {
    my $this = shift;
    my ( $val, $def ) = @_;

    if ( !defined $val ) {
        return 0 if defined $def;
        return 1;
    }
    elsif ( !defined $def ) {
        return 0;
    }

    # Convert all values to multiple style

    $val = [$val] unless ( ref $val );
    $def = [$def] unless ( ref $def );
    $val = join( ',', sort @$val );
    $def = join( ',', sort @$def );

    return $val eq $def;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
