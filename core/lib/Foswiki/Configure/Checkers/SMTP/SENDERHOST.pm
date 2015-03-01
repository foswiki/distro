# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::SMTP::SENDERHOST;

use strict;
use warnings;

use Foswiki::IP qw/:info/;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    return
      unless ( $Foswiki::cfg{EnableEmail}
        && $Foswiki::cfg{Email}{MailMethod} =~ m/^Net::SMTP/ );

    my $value = $this->checkExpandedValue($reporter);
    return unless defined $value;

    my $hi = hostInfo($value);
    if ( $hi->{error} ) {
        $reporter->ERROR( $hi->{error} );
    }
    else {
        if ( $hi->{ipaddr} ) {
            my $ai = addrInfo( $hi->{name} );
            if ( $ai->{names} ) {
                my @names = @{ $ai->{names} };
                $reporter->NOTE( "$hi->{name} has the hostname"
                      . ( @names != 1 ? 's ' : ' ' )
                      . join( ', ', @names )
                      . ".  Use of a hostname is preferred." );
            }
        }
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
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
