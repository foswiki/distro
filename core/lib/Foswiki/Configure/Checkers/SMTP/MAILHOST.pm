# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::SMTP::MAILHOST;

use strict;
use warnings;

use Foswiki::IP qw/$IPv6Avail :regexp :info/;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $e = '';

    my $host   = $Foswiki::cfg{SMTP}{MAILHOST}    || '';
    my $method = $Foswiki::cfg{Email}{MailMethod} || 'Net::SMTP';
    if ( $method =~ /^Net::SMTP/ ) {
        if ( $host && $host !~ /^ ---/ ) {
            my $hi = hostInfo( $host, {} );
            if ( $hi->{error} ) {
                $e .= $this->ERROR( $hi->{error} );
            }
            unless ($e) {
                if ( !$IPv6Avail && @{ $hi->{v6addrs} } ) {
                    $e .= $this->WARN(
"$host has an IPv6 address, but IO::Socket::IP is not installed.  IPv6 can not be used."
                    );
                }
                unless ( @{ $hi->{addrs} } ) {
                    $e .= $this->ERROR(
                        "$host is invalid: server has no IP address");
                }
            }
        }
        elsif ( $Foswiki::cfg{EnableEmail} ) {
            $e .= $this->ERROR(
"Mail server specification required: [IPv6]:port, IPv4:port, or hostname:port"
            );
        }
    }

    if ( !$this->{item}->feedback && !$this->{FeedbackProvided} ) {

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

    my $keys = $valobj->getKeys;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    delete $this->{FeedbackProvided};

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
