# See bottom of file for license and copyright information

package Foswiki::Configure::Checkers::Certificate::KeyPasswordChecker;

use strict;
use warnings;

# Generic Checker class for private key file passwords
#
# This checker can not be a Type-generic checker because
# it invokes checks on a related item (its file)

require Foswiki::Configure::Checker;
our @ISA = qw(Foswiki::Configure::Checker);

# This MUST be subclassed; item must provide related enable and file key values
# to check and provideFeedback methods.  See SmimeKeyPassword for an example.
#
# CHECK= items:
#    filter:'regexp' - Invalid characters
#    min:n - minimum length

sub check {
    my $this = shift;
    my ( $enabled, $valobj ) = @_;

    my $keys = $valobj->{keys};

    my $value = $this->getCfg($keys);

    my $e = '';

    # Unused passwords should not be hanging around.

    unless ($enabled) {
        return $this->WARN(
            "This password field is unused, but not empty.  Please clear it")
          if ( defined $value && length $value );
        return '';
    }

    my @optionList = $this->parseOptions();

    $optionList[0] = {} unless (@optionList);

    $e .=
      $this->ERROR(".SPEC error: multiple CHECK options for KeyPassword $keys")
      if ( @optionList > 1 );

    my $filter = $optionList[0]->{filter}[0];
    my $min    = $optionList[0]->{min}[0];

    if ( defined $value ) {
        $e .= $this->ERROR("Password contains illegal characters")
          if ( defined $filter && $value =~ qr{$filter} );

        $e .= $this->ERROR("Password must be at least $min characters long")
          if ( defined $min && length($value) < $min );
    }

    if ( !$this->{item}->{FEEDBACK} && !$this->{FeedbackProvided} ) {

        # There is no feedback configured for this item, so do any
        # specified tests in the checker (not a good thing).
        # Item will provide enabled, fileKeys

        $e .= $this->provideFeedback( $valobj, 0, 'No Feedback' );
    }

    return $e;
}

sub provideFeedback {
    my $this = shift;
    my ( $enabled, $fileKeys, $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.
    # Note that the call to check goes through the item

    my $e = $button ? $this->check($valobj) : '';

    my $keys = $valobj->{keys};

    delete $this->{FeedbackProvided};

    # No heavy checks for this type of item

    # If a feedback event, re-check password file, which verifies this password

    if ($button) {
        return wantarray ? ( $e, [$fileKeys] ) : $e;
    }

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
