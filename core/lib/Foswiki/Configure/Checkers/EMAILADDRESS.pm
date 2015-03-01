# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::EMAILADDRESS;

# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    list:delim (default ',\\\\s*')
#    undefok
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $value = $this->checkExpandedValue($reporter);
    return unless defined $value;

    my $list = $this->{item}->CHECK_option('list');

    $reporter->ERROR("A valid e-mail address is required")
      unless ( $value
        || $this->{item}->CHECK_option('undefok')
        || $this->{item}->CHECK_option('emptyok') );

    my @addrs;
    @addrs = split( /,\s*/, $value ) if ( defined $list );
    push @addrs, $value unless ( defined $list );

    foreach my $addr (@addrs) {
        next unless $addr;
        $reporter->WARN("\"$addr\" does not appear to be an e-mail address")
          unless (
            $addr =~ m/^([a-z0-9!+$%&'*+-\/=?^_`{|}~.]+\@[a-z0-9\.\-]+)$/i );

        # unless( $addr =~ m/\s*[^@]+\@\S+\s*/ ); #'
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
