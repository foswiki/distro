# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::EMAILADDRESS;

# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    list:delim (default ',\\\\s*')
#    nullok
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use constant NOREDIRECT => 0;

sub check_current_value {
    my ( $this, $reporter ) = @_;

    $this->showExpandedValue($reporter);

    my $check = $this->{item}->{CHECK}->[0] || {};

    my $nullok = $check->{nullok}[0] || 0;
    my $list = $check->{list}[0];

    my $value = $this->getCfg();

    if ( !defined $value ) {
        $reporter->ERROR("Not defined");
    }
    else {
        my @addrs;
        @addrs = split( /,\s*/, $value ) if ( defined $list );
        push @addrs, $value unless ( defined $list );

        $reporter->ERROR("An e-mail address is required")
          unless ( @addrs || $nullok );

        foreach my $addr (@addrs) {
            $reporter->WARN("\"$addr\" does not appear to be an e-mail address")
              unless (
                $addr =~ /^([a-z0-9!+$%&'*+-\/=?^_`{|}~.]+\@[a-z0-9\.\-]+)$/i );

            # unless( $addr =~ /\s*[^@]+\@\S+\s*/ ); #'
        }
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
