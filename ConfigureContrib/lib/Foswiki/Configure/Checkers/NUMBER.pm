# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::NUMBER;

# Default checker for NUMBER items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    radix: (2-36), specified in decimal.
#    min: value in specified radix
#    max: value in specified radix
#    nullok
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

# Parse an arbitrary radix string and convert to binary
# String has been checked by a regexp, and $valid has
# the legal digits in the proper order.

sub _pnum {
    my $string = shift;
    my $radix  = shift;
    my $valid  = shift;

    return undef unless ( defined $string );

    my $sign = 1;
    $sign = -1 if ( $string =~ s/^([+-])// && $1 eq '-' );

    my $value = 0;
    foreach my $digit ( split( //, lc $string ) ) {
        $value *= $radix;
        $value += index( $valid, $digit );
    }
    return $value * $sign;
}

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = $valobj->{keys};

    my $e = '';

    my @optionList = $this->parseOptions();

    $optionList[0] = {} unless (@optionList);

    $e .= $this->ERROR(".SPEC error: multiple CHECK options for NUMBER $keys")
      if ( @optionList > 1 );

    my $radix = $optionList[0]->{radix}[0] || 10;
    $e .= $this->ERROR(".SPEC error: radix $radix invalid")
      if ( $radix < 2 || $radix > 36 );
    my $valid = join( '', ( 0 .. 9, 'a' .. 'z' )[ 0 .. ( $radix - 1 ) ] );
    my $min = _pnum( $optionList[0]->{min}[0], $radix, $valid );
    my $max = _pnum( $optionList[0]->{max}[0], $radix, $valid );

    my $value;
    if ( exists $this->{forcedValue} ) {
        $value = $this->{forcedValue};
    }
    else {
        $value = $this->getCfg($keys);
    }
    my $validRE = "^(?:[+-]?[$valid]+)";
    $validRE .= ( $optionList[0]->{nullok}[0] ? '?' : '' ) . '$';

    $e .= $this->ERROR(
        "Not a valid "
          . (
            $radix != 10
            ? (
                {
                    2  => 'binary',
                    8  => 'octal',
                    16 => 'hexadecimal'
                }->{$radix}
                  || "base $radix"
              )
              . ' '
            : ""
          )
          . "number"
    ) unless ( defined $value && $value =~ /$validRE/i );
    unless ($e) {
        $value = _pnum( $value, $radix, $valid );
        $e .= $this->ERROR("Value must be at least $optionList[0]->{min}[0]")
          if ( defined $min && $value < $min );
        $e .= $this->ERROR(
            "Value must be no greater than  $optionList[0]->{max}[0]")
          if ( defined $max && $value > $max );
    }

    $value = $this->getItemCurrentValue();
    $e     = $this->showExpandedValue($value) . $e;

    if ( !$this->{item}->{FEEDBACK} && !$this->{FeedbackProvided} ) {

        # There is no feedback configured for this item, so do any
        # specified tests in the checker (not a good thing).

        $e .= $this->provideFeedback( $valobj, 0, 'No Feedback' );
    }

    return $e;
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    #    my $keys = $valobj->{keys};

    delete $this->{FeedbackProvided};

    # check() does all that's necessary
    # We simply re-do if a button (usually autocheck) is provided.

    return wantarray ? ( $e, 0 ) : $e;
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
