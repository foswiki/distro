# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Register::NeedApproval;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ($this, $reporter) = @_;

    return '' unless $Foswiki::cfg{Register}{NeedApproval};

    unless ( $Foswiki::cfg{EnableEmail} ) {
        $reporter->ERROR(
'Approval is required, but email is disabled. No approval request emails can be sent. Either disable this option or enable email.'
        );
    }
    unless ( $Foswiki::cfg{Register}{Approvers}
        || $Foswiki::cfg{AdminUserWikiName} )
    {
        $reporter->ERROR(
'Approval is required, but {Register}{Approvers} is empty and {AdminUserWikiName} is not a valid wikiname. One of these must be set for approval to work.'
        );
    }
    unless ( $Foswiki::cfg{Register}{Approvers}
        || $Foswiki::cfg{WebMasterEmail} )
    {
        $reporter->WARN(
'Approval is required, but {Register}{Approvers} is empty and {WebMasterEmail} has not been set. Approval is unlikely to work.'
        );
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors
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
