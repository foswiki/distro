# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Email::MailMethod;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Dependency ();

sub check_current_value {
    my ($this, $reporter) = @_;
    my $n    = '';

    return unless $Foswiki::cfg{EnableEmail};

    # Not set - need to guess it.
    if ( !$Foswiki::cfg{Email}{MailMethod} ) {
        my $val = $Foswiki::cfg{MailProgram} || '';
        $val =~ s/\s.*$//g;
        if ( $Foswiki::cfg{SMTP}{MAILHOST} ) {
            $reporter->NOTE(
"MailMethod was not configured - MAILHOST is provided - I guessed =Net::SMTP="
            );
            $Foswiki::cfg{Email}{MailMethod} = 'Net::SMTP';
            $reporter->WARN(Foswiki::Configure::Checker::GUESSED_MESSAGE);
        }
        elsif ( !( -x $val ) ) {

            # MailProgram is not executable,  need Net::SMTP
            $Foswiki::cfg{Email}{MailMethod} = 'Net::SMTP';
            $reporter->NOTE(
"MailMethod was not configured. No MAILHOST configured but MailProgram is not executable - I guessed =Net::SMTP= anyway, please configure MAILHOST."
            );
            $reporter->WARN(Foswiki::Configure::Checker::GUESSED_MESSAGE);
        }
        else {
            $reporter->NOTE(
"MailMethod was not configured. No MAILHOST and MailProgram is available. - I guessed =MailProgram="
            );
            $Foswiki::cfg{Email}{MailMethod} = 'MailProgram';
            $reporter->WARN(Foswiki::Configure::Checker::GUESSED_MESSAGE);
        }

        $reporter->WARN( <<HERE );
*Compatibility Note:* Previous version of Foswiki guessed the MailMethod at
runtime based upon the configuration setting of {SMTP}{MAILHOST}, and could be overridden 
by a setting of SMTPMAILHOST in SitePreferences.  If neither were set, it would try the
MailProgram.  Once you save this configuration, 
   * if MailMethod is set to MailProgram, the external mail method will always be used.
   * If MailMethod is set to Net::SMTP, then the MAILHOST settings from the configuration as overridden by SitePreferences will be used.
   * if Neither {SMTP}{MAILHOST} nor SMTPMAILHOST are set, then the MailProgram will be tried.
It is recommended to delete the SMTPMAILHOST setting if you are using a SitePreferences topic from a previous release of Foswiki.
HERE
    }

    if ( $Foswiki::cfg{Email}{MailMethod} ne 'MailProgram' ) {
        my %mod = (
            name => 'Net::SMTP',
            usage => 'Required for SMTP Support',
            minimumVersion => 2.00
            );
        Foswiki::Configure::Dependency::checkPerlModules( \%mod );
        if (!$mod{ok}) {
            $reporter->ERROR($mod{check_result});
        } else {
            $reporter->NOTE($mod{check_result});
        }
    }

    #SMELL:  Not sure what the mimimum recommended versions of these modules are
    if ( $Foswiki::cfg{Email}{MailMethod} =~ m/SSL|TLS/ ) {
        my @mods = (
            {
                name => 'Net::SSLeay',
                usage => 'Required for Secure SMTP Support',
                minimumVersion => 1.40
            },
            {
                name => 'IO::Socket::SSL',
                usage => 'Required for Secure SMTP Support',
                minimumVersion => 1.40
            });
        Foswiki::Configure::Dependency::checkPerlModules( @mods );
        foreach my $mod (@mods) {
            if (!$mod->{ok}) {
                $reporter->ERROR($mod->{check_result});
            } else {
                $reporter->NOTE($mod->{check_result});
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
