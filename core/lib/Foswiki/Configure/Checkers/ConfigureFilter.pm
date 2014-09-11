# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ConfigureFilter;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $it = Foswiki::Func::eachGroupMember( $Foswiki::cfg{SuperAdminGroup} );
    my @admins;

    while ( defined $it && $it->hasNext() ) {
        push @admins, Foswiki::Func::getCanonicalUserID( $it->next() );
    }
    $reporter->WARN(
"AdminGroup contains no users except for the super admin $Foswiki::cfg{AdminUserWikiName} ($Foswiki::cfg{AdminUserLogin}), Click the [i] button for information on how to set this filter."
    ) if ( scalar @admins lt 2 );

    my @filtered = grep( /$Foswiki::cfg{ConfigureFilter}/, @admins );
    $reporter->WARN(
"AdminGroup as filtered by this filter contains no users, Click the [i] button to see how to set this filter."
    ) unless ( scalar @filtered );

    my $user = join( ' ', @filtered );
    $reporter->NOTE("AdminGroup Members with configure access: $user");
    $reporter->NOTE(
"Note that this filter matches against *all* users.  When this filter is set, users do not have to be in the $Foswiki::cfg{SuperAdminGroup} to access configure!"
    );

    unless ( $Foswiki::cfg{isBootstrapping} ) {
        if ( $Foswiki::cfg{ConfigureFilter}
            && Foswiki::Func::getCanonicalUserID() !~
            m/$Foswiki::cfg{ConfigureFilter}/ )
        {
            $reporter->ERROR(
"Current user is locked out by the configured filter, If you save the configuration, you'll lose access to configure!"
            );
        }
    }

    $reporter->WARN(
"You have not set a Pasword, your $Foswiki::cfg{SuperAdminGroup} contains no users, or your filter eliminated all users in the $Foswiki::cfg{SuperAdminGroup}.
You *Must* have a usable ID matching this filter to access configure.  Do not save the configuration unless you are sure you have not locked yourself out of configure!"
    ) unless ( $Foswiki::cfg{Password} || scalar @filtered );

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
