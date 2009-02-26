# See bottom of file for license and copyright information

package Foswiki::Configure::Value;

use strict;

use base 'Foswiki::Configure::Item';

use Foswiki::Configure::Type;

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
    return undef;
}

# See if this value is changed from the default. The comparison
# is done according to the rules for the type of the value.
sub needsSaving {
    my ( $this, $valuer ) = @_;

    my $curval = $valuer->currentValue($this);
    my $defval = $valuer->defaultValue($this);

    return 0 if $this->getType()->equals( $curval, $defval );

#print STDERR "TEST $this->{keys} D'",($defval||'undef'),"' C'",($curval||'undef'),"'\n";
    return 1;
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
