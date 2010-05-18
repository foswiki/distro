# See bottom of file for license and copyright information

package Foswiki::Configure::Value;

use strict;
use warnings;

use Foswiki::Configure::Item ();
our @ISA = ('Foswiki::Configure::Item');

use Foswiki::Configure::Type ();

our $VALUE_TYPE = {
    CURRENT => ( 1 << 0 ),    # 1
    DEFAULT => ( 1 << 1 ),    # 2
};

# The opts are additional parameters, and by convention may
# be a number (for a string length), a comma separated list of values
# (for a select) and may also have an M for mandatory, or a H for hidden.
sub new {
    my $class = shift;

    my $this =
      bless( $class->SUPER::new('Foswiki::Configure::UIs::Value'), $class );

    $this->{keys}        = '';
    $this->{opts}        = '';
    $this->{expertsOnly} = 0;
    $this->set(@_);

    if ( defined $this->{opts} ) {
        $this->{mandatory} = ( $this->{opts} =~ /(\b|^)M(\b|$)/ );
        $this->{hidden}    = ( $this->{opts} =~ /(\b|^)H(\b|$)/ );
        $this->{expertsOnly} = 1
          if ( $this->{opts} =~ s/\bEXPERT\b// );
    }

    return $this;
}

sub isExpertsOnly {
    my $this = shift;
    return $this->{expertsOnly};
}

sub getKeys {
    my $this = shift;
    return $this->{keys};
}

sub getType {
    my $this = shift;
    unless ( $this->{type} ) {
        $this->{type} =
          Foswiki::Configure::Type::load( $this->{typename} || 'UNKNOWN' );
    }
    return $this->{type};
}

sub visit {
    my ( $this, $visitor ) = @_;
    return 0 unless $visitor->startVisit($this);
    return 0 unless $visitor->endVisit($this);
    return 1;
}

sub getValueObject {
    my ( $this, $keys ) = @_;

    return $this if ( $this->{keys} && $keys eq $this->{keys} );
    return;
}

# See if this value is changed from the default. The comparison
# is done according to the rules for the type of the value.
sub needsSaving {
    my ( $this, $valuer ) = @_;

    my $currentValue = $valuer->currentValue($this);
    my $defaultValue = $valuer->defaultValue($this);

    my $isEqual = $this->getType()->equals( $currentValue, $defaultValue );

#print STDERR "TEST $this->{keys} D'",($defaultValue||'undef'),"' C'",($currentValue||'undef'),"'\n";

    return !$isEqual;
}

=pod

asString( $valuer, $valueType) -> $value

- $valueType: (int) value of VALUE_TYPE, either 'CURRENT' or 'DEFAULT'

=cut

sub asString {
    my ( $this, $valuer, $type ) = @_;

    $type = $VALUE_TYPE->{CURRENT} if !defined $type;
    my $value;
    $value = $valuer->currentValue($this) if $type == $VALUE_TYPE->{CURRENT};
    $value = $valuer->defaultValue($this) if $type == $VALUE_TYPE->{DEFAULT};

    $value ||= '';

    return $value if !defined $this->{typename};

    if (   $this->{typename} eq 'PERL'
        || $this->{typename} eq 'HASH'
        || $this->{typename} eq 'ARRAY' )
    {
        use Data::Dumper;
        my $setting = $Data::Dumper::Terse;
        $Data::Dumper::Terse = 1;
        $value               = Dumper($value);
        $Data::Dumper::Terse = $setting;
    }
    return $value;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
