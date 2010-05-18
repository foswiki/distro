# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

sub USERINFO {
    my ( $this, $params ) = @_;
    my $format = $params->{format} || '$username, $wikiusername, $emails';

    my $user = $this->{user};

    if ( $params->{_DEFAULT} ) {
        $user = $params->{_DEFAULT};
        return '' if !$user;

        # map wikiname to a login name
        $user = $this->{users}->getCanonicalUserID($user);
        return '' unless $user;
        return ''
          if ( $Foswiki::cfg{AntiSpam}{HideUserDetails}
            && !$this->{users}->isAdmin( $this->{user} )
            && $user ne $this->{user} );
    }

    return '' unless $user;

    my $info = $format;

    if ( $info =~ /\$username/ ) {
        my $username = $this->{users}->getLoginName($user);
        $username = 'unknown' unless defined $username;
        $info =~ s/\$username/$username/g;
    }
    if ( $info =~ /\$wikiname/ ) {
        my $wikiname = $this->{users}->getWikiName($user);
        $wikiname = 'UnknownUser' unless defined $wikiname;
        $info =~ s/\$wikiname/$wikiname/g;
    }
    if ( $info =~ /\$wikiusername/ ) {
        my $wikiusername = $this->{users}->webDotWikiName($user);
        $wikiusername = "$Foswiki::cfg{UsersWebName}.UnknownUser"
          unless defined $wikiusername;
        $info =~ s/\$wikiusername/$wikiusername/g;
    }
    if ( $info =~ /\$emails/ ) {
        my $emails = join( ', ', $this->{users}->getEmails($user) );
        $info =~ s/\$emails/$emails/g;
    }
    if ( $info =~ /\$groups/ ) {
        my @groupNames;
        my $it = $this->{users}->eachMembership($user);
        while ( $it->hasNext() ) {
            my $group = $it->next();
            push( @groupNames, $group );
        }
        my $groups = join( ', ', @groupNames );
        $info =~ s/\$groups/$groups/g;
    }
    if ( $info =~ /\$cUID/ ) {
        my $cUID = $user;
        $info =~ s/\$cUID/$cUID/g;
    }
    if ( $info =~ /\$admin/ ) {
        my $admin = $this->{users}->isAdmin($user) ? 'true' : 'false';
        $info =~ s/\$admin/$admin/g;
    }

    return $info;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
