# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::SMTP::MAILHOST;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $e = '';

    if ( $Foswiki::cfg{EnableEmail} ) {
        my $host   = $Foswiki::cfg{SMTP}{MAILHOST}    || '';
        my $method = $Foswiki::cfg{Email}{MailMethod} || 'Net::SMTP';
        if ( $method =~ /^Net::SMTP/ ) {
            if ( $host = $Foswiki::cfg{SMTP}{MAILHOST} ) {
                if ( $host =~ m/^([^:]+)(?::([0-9]{2,5}))?$/ ) {
                    ( $host, my $port ) = ( $1, $2 );
                    my ( undef, undef, undef, undef, @addrs ) =
                      gethostbyname($host);
                    unless (@addrs) {
                        $e .= $this->ERROR(
                            "$host is invalid: server has no IP address");
                    }
                }
                else {
                    $e .= $this->ERROR(
"Syntax error: must be hostname with optional : numeric port"
                    );
                }
            }
            else {
                $e .= $this->ERROR("Hostname or address required for $method.");
            }
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
