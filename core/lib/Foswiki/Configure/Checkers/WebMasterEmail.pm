# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WebMasterEmail;

use strict;
use warnings;

use Foswiki::Configure::Checkers::EMAILADDRESS ();
our @ISA = ('Foswiki::Configure::Checkers::EMAILADDRESS');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $value = $this->checkExpandedValue($reporter);

    if ( !$value ) {
        if ( $Foswiki::cfg{EnableEmail} ) {
            $reporter->ERROR("A valid e-mail address is required");
        }
        else {
            $reporter->WARN(
"You must configure e-mail if you want Foswiki to provide topic change notifications and new user registration services."
            );
            $reporter->NOTE( <<DONE );
Supply a valid email address. If your non-Windows server is already configured to send email, press Auto-confgigure to proceed.

Otherwise, in the below fields, provide an email server name or address, and the optional user & password, and then run Auto-configure again."
DONE
        }
    }
    else {
        $reporter->WARN(
"E-mail is not enabled. You must configure e-mail if you want Foswiki to provide topic change notifications and new user registration services.  Run Auto-configure to complete your email setup."
        ) unless ( $Foswiki::cfg{EnableEmail} );

    }

    # Check Script URL Path against EMAILADDRESS
    $this->SUPER::check_current_value($reporter);

    my @mods = (
        {
            name           => 'Email::MIME',
            usage          => 'Required for Email Support',
            minimumVersion => 1.903
        },
    );
    Foswiki::Configure::Dependency::checkPerlModules(@mods);
    foreach my $mod (@mods) {
        if ( !$mod->{ok} ) {
            if ($value) {
                $reporter->ERROR( $mod->{check_result} );
            }
            else {
                $reporter->WARN( $mod->{check_result} );
            }
        }
        else {
            $reporter->NOTE( $mod->{check_result} );
        }
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
