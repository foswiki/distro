# See bottom of file for license and copyright information

package Foswiki::Configure::Auth;

use Foswiki::Func;
use Foswiki::AccessControlException;
use Foswiki::Contrib::JsonRpcContrib::Error;

=begin TML

---+ package Foswiki::Configure::Auth

Implements authorization checking for access to configure.

=cut

use strict;
use warnings;

=begin TML

---++ StaticMethod checkAccess( $session, $die )

Throws an AccessControlException  if access is denied. 

=cut

sub checkAccess {
    my $session = shift;
    my $json    = shift;    # JSON needs throw JSON errors.

    return
      if ( defined $Foswiki::cfg{LoginManager}
        && $Foswiki::cfg{LoginManager} eq 'none' );

    my $wikiname = Foswiki::Func::getWikiName( $session->{user} );

    return
      if ( defined $Foswiki::cfg{AdminUserWikiName}
        && $Foswiki::cfg{AdminUserWikiName} eq $wikiname );

    if ( defined $Foswiki::cfg{FeatureAccess}{Configure}
        && length( $Foswiki::cfg{FeatureAccess}{Configure} ) )
    {
        my $authorized = '';
        foreach my $authuser (
            split( /[,\s]/, $Foswiki::cfg{FeatureAccess}{Configure} ) )
        {
            if ( $wikiname eq $authuser ) {
                $authorized = 1;
                last;
            }
        }
        unless ($authorized) {
            if ($json) {
                throw Foswiki::Contrib::JsonRpcContrib::Error( -32600,
'Access to configure denied by {FeatureAccess}{Configure} Setting'
                );
            }
            else {
                throw Foswiki::AccessControlException( 'VIEW',
                    $session->{user}, 'System', 'Configuration',
                    'Denied by {FeatureAccess}{Configure} Setting' );
            }
        }
    }
    else {
        unless ( Foswiki::Func::isAnAdmin() ) {
            if ($json) {
                throw Foswiki::Contrib::JsonRpcContrib::Error( -32600,
                    'Access to configure denied for non-admin users' );
            }
            else {
                throw Foswiki::AccessControlException( 'VIEW',
                    $session->{user}, 'System', 'Configuration',
                    'Not an admin' );
            }
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
