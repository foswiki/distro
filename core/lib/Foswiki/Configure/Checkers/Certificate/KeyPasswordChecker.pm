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
use Assert;

sub check {
    ASSERT( 0, "Subclasses must implement this" ) if DEBUG;
}

sub checkEnabled {
    my ( $this, $enabled, $reporter ) = @_;

    my $keys = $this->{item}->{keys};

    my $value = $this->{item}->getExpandedValue();

    # Unused passwords should not be hanging around.

    unless ($enabled) {
        return $reporter->WARN(
            "This password field is unused, but not empty.  Please clear it")
          if ( defined $value && length $value );
        return;
    }

    if ( defined $value ) {
        my $filter = $this->{item}->CHECK_option('filter');
        $reporter->ERROR("Password contains illegal characters")
          if ( defined $filter && $value =~ qr{$filter} );

        my $min = $this->{item}->CHECK_option('min');
        $reporter->ERROR("Password must be at least $min characters long")
          if ( defined $min && length($value) < $min );
    }
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
