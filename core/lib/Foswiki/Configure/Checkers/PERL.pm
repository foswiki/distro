# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PERL;

use strict;
use warnings;

use Assert;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $value = $this->{item}->getRawValue();
    if ( !defined $value ) {
        unless ( $this->{item}->CHECK_option('undefok') ) {
            $reporter->ERROR('May not be undefined');
        }
        return;
    }

    _check_for_null( $value, $reporter );
}

# Ensure undef expansions in perl structures won't cause problems
sub _check_for_null {
    my ( $value, $reporter ) = @_;

    if ( ref($value) eq 'HASH' ) {
        _check_for_null($_) foreach ( values %$value );
    }
    elsif ( ref($value) eq 'ARRAY' ) {
        _check_for_null($_) foreach (@$value);
    }
    $value =~
s/(\$Foswiki::cfg$Foswiki::Configure::Load::ITEMREGEX)/_check_null($1)/ges;
}

sub _check_null {
    my ( $str, $reporter ) = @_;
    my $val = eval($str);
    if ($@) {
        $reporter->ERROR( "Expansion of embedded $str failed: "
              . Foswiki::Configure::Reporter::stripStacktrace($@) );
    }
    elsif ( !defined $val ) {
        $reporter->ERROR("Embedded $str is undefined");
    }
    return $str;
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
