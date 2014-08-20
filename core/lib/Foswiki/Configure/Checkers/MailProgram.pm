# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::MailProgram;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ($this, $reporter) = @_;

    return unless $Foswiki::cfg{EnableEmail};

    if ( $Foswiki::cfg{Email}{MailMethod} eq 'MailProgram' ) {
        my $val = $Foswiki::cfg{MailProgram} || '';
        $val =~ s/\s.*$//g;
        if ( !( -x $val ) ) {
            $reporter->ERROR(
"=$val= was not found (but is required). Check the path, or configure one of the =Net::SMTP= methods.."
            );
        }
    }
    else {
        $reporter->NOTE(
"MailProgram is not used for the configued Email method: =$Foswiki::cfg{Email}{MailMethod}="
        );
    }

    if (
        ( $Foswiki::cfg{Email}{MailMethod} eq 'MailProgram' )
        && (   $Foswiki::cfg{SMTP}{MAILHOST}
            || $Foswiki::cfg{SMTP}{SENDERHOST}
            || $Foswiki::cfg{SMTP}{Username}
            || $Foswiki::cfg{SMTP}{Password} )
      )
    {
        $reporter->NOTE(
"None of the below parameters are used by the configured Email method $Foswiki::cfg{Email}{MailMethod}"
        );
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
