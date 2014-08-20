# See bottom of file for license and copyright information
package Foswiki::Configure::FeedbackCheckers::SMTP::MAILHOST;

use strict;
use warnings;

use Foswiki::IP qw/$IPv6Avail :regexp :info/;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

sub provideFeedback {
    my ( $this, $button, $label ) = @_;

    my $keys = $this->{item}->{keys};

    my $e = '';

    my $host   = $Foswiki::cfg{SMTP}{MAILHOST}    || '';
    my $method = $Foswiki::cfg{Email}{MailMethod} || 'Net::SMTP';

    if ( $method =~ /^Net::SMTP/ ) {
        unless ($host) {
            $host = ' ---- Enter e-mail server name to configure Net::SMTP ---';
            $e .=
              $this->FB_VALUE(
                $this->setItemValue( $host, '{SMTP}{MAILHOST}' ) );
        }
        $e .= $this->FB_ACTION( '{SMTP}{MAILHOST}', 's' )
          if ( $host =~ /^ ---/ );
    }
    return wantarray ? ( $e, 0 ) : $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
