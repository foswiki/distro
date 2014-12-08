# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::FeatureAccess::Configure;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    # Checkers may be called in a script context, in which case
    # Foswiki::Func is not available. However in a script context
    # this option isn't interesting anyway.
    return
      unless defined $Foswiki::Plugins::SESSION
      && eval "require Foswiki::Func";

    my $it = Foswiki::Func::eachGroupMember( $Foswiki::cfg{SuperAdminGroup} );
    my @admins;

    while ( defined $it && $it->hasNext() ) {
        my $a = Foswiki::Func::getCanonicalUserID( $it->next() );

        # The group members come from a data topic, which might have been
        # populated even when running in bootstrap mode. In this case there
        # will be no mapping for the user and therefore no CUID.
        push( @admins, $a ) if $a;
    }
    $reporter->WARN(
"$Foswiki::cfg{SuperAdminGroup} contains no users except for the super admin $Foswiki::cfg{AdminUserWikiName} ($Foswiki::cfg{AdminUserLogin}) and the sudo admin password is not set ( =\$Foswiki::cfg{Password}= )"
    ) if ( scalar @admins lt 2 && !$Foswiki::cfg{Password} );

    my @Authorized = split( /[,\s]/, $Foswiki::cfg{FeatureAccess}{Configure} );
    my $passed = '';   # Set to true if current user is allowed to use configure

    unless ( $Foswiki::cfg{isBOOTSTRAPPING}
        || !$Foswiki::cfg{FeatureAccess}{Configure} )
    {
        foreach my $user (@Authorized) {
            if ( $user eq Foswiki::Func::getCanonicalUserID() ) {
                $passed = 1;
                last;
            }
        }
        $reporter->ERROR(
"Current user not in this list, and is locked out, If you save the configuration, you'll lose access to configure!"
        ) unless ($passed);
    }

    if (   !$passed
        && !$Foswiki::cfg{Password}
        && scalar @admins < 2 )
    {
        $reporter->WARN(
"You have not set an admin Pasword.  Your $Foswiki::cfg{SuperAdminGroup} contains no users, or this list eliminated all users in the $Foswiki::cfg{SuperAdminGroup}
and your current ID "
              . Foswiki::Func::getCanonicalUserID()
              . " is not included in this list: You *Must* have a usable ID in this list to access configure.  Do not save the configuration unless you are sure you have not locked yourself out of configure!"
        );
    }

    if (   $Foswiki::cfg{Password}
        && $Foswiki::cfg{FeatureAccess}{Configure}
        && $Foswiki::cfg{FeatureAccess}{Configure} !~
        /\bBaseUserMapping_333\b/ )
    {
        $reporter->WARN(
"You have set a superuser password, but this user is not permitted to use configure.  Add BaseUserMapping_333 to this list if you want the superuser to access configure"
        );
    }

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
