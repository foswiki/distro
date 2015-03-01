# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DATE;

# Default checker for DATE items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    zone: utc or local - default timezone
#    raw   Return raw user input (don't normalize to ISO format)
#    undefok
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Time qw/-nofoswiki/;

use Foswiki::Configure::Checker ();
our @ISA = qw/Foswiki::Configure::Checker/;

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $value = $this->checkExpandedValue($reporter);
    return unless defined $value;

    my $zone = $this->{item}->CHECK_option('zone') || 'utc';
    my $normalize = !$this->{item}->CHECK_option('raw');

    if ( $value =~ m/\S/ ) {
        my $binval = Foswiki::Time::parseTime( $value, $zone eq 'local' );
        if ( defined $binval ) {
            if ($normalize) {    # undef uses configured display format
                my $normval = Foswiki::Time::formatTime( $binval,
                    '$year-$mo-$dayT$hour:$min:$sec$isotz', undef );
                $reporter->NOTE("$value is not in ISO8601 format $normval")
                  if ( $normval ne $value );
            }
        }
        else {
            $reporter->ERROR("Unrecognized format for date");
        }
    }
    elsif ( !$this->{item}->CHECK_option('emptyok') ) {
        $reporter->ERROR('A date/time must be provided for this item');
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
