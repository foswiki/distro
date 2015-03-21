# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Password;

use strict;
use warnings;
use Assert;
use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    # Checkers may be called in a script context, in which case
    # Foswiki::Func is not available. However in a script context
    # this option isn't interesting anyway.
    return
      unless defined $Foswiki::Plugins::SESSION
      && eval("require Foswiki::Func");
    my $it = Foswiki::Func::eachGroupMember( $Foswiki::cfg{SuperAdminGroup} );
    my @admins;

    while ( defined $it && $it->hasNext() ) {
        push @admins, Foswiki::Func::getCanonicalUserID( $it->next() );
    }

    $reporter->WARN(
"$Foswiki::cfg{SuperAdminGroup} contains no users except for the _internal admin_ $Foswiki::cfg{AdminUserWikiName} ($Foswiki::cfg{AdminUserLogin}) and the _internal admin_ password is not set ( =\$Foswiki::cfg{Password}= )"
      )
      if ( scalar(@admins) lt 2
        && !$Foswiki::cfg{Password}
        && !$Foswiki::cfg{FeatureAccess}{Configure} );

    if (
        $Foswiki::cfg{Password}
        && ( $Foswiki::cfg{Password} !~ m/^\$apr1\$/
            || length( $Foswiki::cfg{Password} ) ne 37 )
      )
    {
        $reporter->ERROR(
"This _internal admin_ password does not appear to be a valid password.  You will be unable to access the _internal admin_ $Foswiki::cfg{AdminUserWikiName} ($Foswiki::cfg{AdminUserLogin})
using the current configuration.  If you want to be able to use the _internal admin_ user, the password should be saved as an \"\$apr1:...\" encoded password.  Show the help for more details."
        );
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014-2015 Foswiki Contributors. Foswiki Contributors
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
