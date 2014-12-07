# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::STRING;

# Default checker for STRING items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    min: length
#    max: length
#    accept: regexp,regexp
#            If present, must match one
#    filter: regexp, regexp
#            If present, any match fails
# Use this checker if possible; otherwise subclass the
# item-specific checker from it.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $value = $this->{item}->getExpandedValue();
    if ( !defined $value ) {
        my $check = $this->{item}->{CHECK}->[0];
        unless ( $check && $check->{nullok}[0] ) {
            $reporter->ERROR("Must be non-empty");
        }
        return;
    }
    $value = $this->{item}->getExpandedValue();

    my $len = length($value);

    my $check = $this->{item}->{CHECK}->[0] || {};
    return unless ($check);

    my $min = $check->{min}[0];
    my $max = $check->{max}[0];

    my $accept = $check->{accept};
    my $filter = $check->{filter};

    if ( defined $min && $len < $min ) {
        $reporter->ERROR("Length must be at least $min");
    }
    elsif ( defined $max && $len > $max ) {
        $reporter->ERROR("Length must be no greater than $max");
    }
    else {
        my $ok = 1;
        if ( defined $accept ) {
            $ok = 0;
            foreach my $are (@$accept) {
                if ( $value =~ $are ) {
                    $ok = 1;
                    last;
                }
            }
        }
        if ( $ok && defined $filter ) {
            foreach my $fre (@$filter) {
                if ( $value =~ $fre ) {
                    $ok = 0;
                    last;
                }
            }
        }
        $reporter->ERROR("This value is not acceptable")
          unless ($ok);
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
