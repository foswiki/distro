# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Set to true if user details should be cloaked.   Selected tokens will return an empty string.
my $USERINFO_cloak = 0;

my %USERINFO_tokens = (
    username => sub {
        my ( $this, $user ) = @_;
        return '' if ($USERINFO_cloak);

        my $username = $this->{users}->getLoginName($user);
        $username = 'unknown' unless defined $username;

        return $username;
    },

    # Item2466: There is some usage of this undocumented token in VariableTests
    cUID => sub {
        my ( $this, $user ) = @_;

        return '' if ($USERINFO_cloak);
        return $user;
    },
    wikiname => sub {
        my ( $this, $user ) = @_;
        my $wikiname = $this->{users}->getWikiName($user);

        $wikiname = 'UnknownUser' unless defined $wikiname;

        return $wikiname;
    },
    wikiusername => sub {
        my ( $this, $user ) = @_;
        my $wikiusername = $this->{users}->webDotWikiName($user);

        $wikiusername = "$Foswiki::cfg{UsersWebName}.UnknownUser"
          unless defined $wikiusername;

        return $wikiusername;
    },
    emails => sub {
        my ( $this, $user ) = @_;

        return '' if ($USERINFO_cloak);
        return join( ', ', $this->{users}->getEmails($user) );
    },
    groups => sub {
        my ( $this, $user ) = @_;
        my @groupNames;
        return '' if ($USERINFO_cloak);

        my $it = $this->{users}->eachMembership($user);

        while ( $it->hasNext() ) {
            my $group = $it->next();
            push( @groupNames, $group );
        }

        return join( ', ', @groupNames );
    },

   # Item2466: $admin was re-documented as $isadmin November 2011, do not remove
    admin => sub {
        my ( $this, $user ) = @_;

        return '' if ($USERINFO_cloak);
        return $this->{users}->isAdmin($user) ? 'true' : 'false';
    },

    # Item2466: $isadmin & $isgroup added November 2011
    isadmin => sub {
        my ( $this, $user ) = @_;

        return '' if ($USERINFO_cloak);
        return $this->{users}->isAdmin($user) ? 'true' : 'false';
    },
    isgroup => sub {
        my ( $this, $user ) = @_;

        return $this->{users}->isGroup($user) ? 'true' : 'false';
    }
);
my $USERINFO_tokenregex = join( '|', keys %USERINFO_tokens );

sub USERINFO {
    my ( $this, $params ) = @_;
    my $format = $params->{format} || '$username, $wikiusername, $emails';
    my $user   = $this->{user};
    my $info   = $format;

    if ( $params->{_DEFAULT} ) {
        $user = $params->{_DEFAULT};
        return '' if !$user;

        # map wikiname to a login name
        my $cuid = $this->{users}->getCanonicalUserID($user);
        if ( !$cuid ) {

            # Failed to get a cUID: if it's a group, leave $user alone
            if ( !$this->{users}->isGroup($user) ) {
                return '';
            }
        }
        else {
            $user = $cuid;
        }
        return '' unless $user;

        $USERINFO_cloak =
          (      $Foswiki::cfg{AntiSpam}{HideUserDetails}
              && !$this->{users}->isAdmin( $this->{user} )
              && $user ne $this->{user} );
    }
    else {
        $USERINFO_cloak = 0;
    }

    return '' unless $user;

    $info =~ s/\$($USERINFO_tokenregex)/$this->_USERINFO_token($1, $user)/ge;
    $info = Foswiki::expandStandardEscapes($info);

    return $info;
}

sub _USERINFO_token {
    my ( $this, $token, $user ) = @_;

    ASSERT($token) if DEBUG;
    ASSERT( ref( $USERINFO_tokens{$token} ) eq 'CODE',
        "No code for token '$token'" )
      if DEBUG;

    return $USERINFO_tokens{$token}->( $this, $user );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
