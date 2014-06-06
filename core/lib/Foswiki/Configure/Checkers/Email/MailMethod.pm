# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Email::MailMethod;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $n    = '';

    return '' if ( !$Foswiki::cfg{EnableEmail} );

    # Not set - need to guess it.
    if ( !$Foswiki::cfg{Email}{MailMethod} ) {
        my $val = $Foswiki::cfg{MailProgram} || '';
        $val =~ s/\s.*$//g;
        if ( $Foswiki::cfg{SMTP}{MAILHOST} ) {
            $n .= $this->NOTE(
"MailMethod was not configured - MAILHOST is provided - I guessed <code>Net::SMTP</code>"
            );
            $Foswiki::cfg{Email}{MailMethod} = 'Net::SMTP';
            $n .= $this->guessed(0);
        }
        elsif ( !( -x $val ) ) {

            # MailProgram is not executable,  need Net::SMTP
            $Foswiki::cfg{Email}{MailMethod} = 'Net::SMTP';
            $n .= $this->NOTE(
"MailMethod was not configured. No MAILHOST configured but MailProgram is not executable - I guessed <code>Net::SMTP</code> anyway, please configure MAILHOST."
            );
            $n .= $this->guessed(0);
        }
        else {
            $n .= $this->NOTE(
"MailMethod was not configured. No MAILHOST and MailProgram is available. - I guessed <code>MailProgram</code>"
            );
            $Foswiki::cfg{Email}{MailMethod} = 'MailProgram';
            $n .= $this->guessed(0);
        }

        $n .= $this->WARN( <<HERE );
<b>Compatibility Note:</b> Previous version of Foswiki guessed the MailMethod at
runtime based upon the configuration setting of {SMTP}{MAILHOST}, and could be overridden 
by a setting of SMTPMAILHOST in SitePreferences.  If neither were set, it would try the
MailProgram.  Once you save this configuration, 
<ul>
<li>if MailMethod is set to MailProgram, the external mail method will always be used.
<li>If MailMethod is set to Net::SMTP, then the MAILHOST settings from the configuration as overridden by SitePreferences will be used.
<li>if Neither {SMTP}{MAILHOST} nor SMTPMAILHOST are set, then the MailProgram will be tried.
</ul>
It is recommended to delete the SMTPMAILHOST setting if you are using a SitePreferences topic from a previous release of Foswiki.
HERE
    }

    my $e =
      $this->checkPerlModule( 'Net::SMTP', 'Required for SMTP Support', 2.00 );

    if (   $e =~ m/Not installed/
        && $Foswiki::cfg{Email}{MailMethod} ne 'MailProgram' )
    {
        $n .= $this->ERROR($e);
    }
    else {
        $n .= $this->NOTE($e);
    }

    #SMELL:  Not sure what the mimimum recommended versions of these modules are
    if ( $Foswiki::cfg{Email}{MailMethod} =~ m/SSL|TLS/ ) {
        $e =
          $this->checkPerlModule( 'Net::SSLeay',
            'Required for Secure SMTP Support', 1.40 );

        if ( $e =~ m/Not installed/ ) {
            $n .= $this->ERROR($e);
        }
        else {
            $n .= $this->NOTE($e);
        }

        $e =
          $this->checkPerlModule( 'IO::Socket::SSL',
            'Required for Secure SMTP Support', 1.40 );

        if ( $e =~ m/Not installed/ ) {
            $n .= $this->ERROR($e);
        }
        else {
            $n .= $this->NOTE($e);
        }
    }
    return $n;
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
