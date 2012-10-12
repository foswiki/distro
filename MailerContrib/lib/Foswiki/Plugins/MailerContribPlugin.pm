# See bottom of file for license and copyright information
package Foswiki::Plugins::MailerContribPlugin;

use strict;
use warnings;

our $VERSION           = '$Rev: 5752 $';
our $RELEASE           = '9 Jul 2010';
our $SHORTDESCRIPTION  = 'Supports e-mail notification of changes';
our $NO_PREFS_IN_TOPIC = 1;

# Plugin init method, used to initialise handlers
sub initPlugin {
    Foswiki::Func::registerRESTHandler( 'notify', \&_restNotify );
    return 1;
}

# Run mailnotify using a rest handler
sub _restNotify {
    my ( $session, $plugin, $verb, $response ) = @_;

    if ( !Foswiki::Func::isAnAdmin() ) {
        $response->header( -status => 403, -type => 'text/plain' );
        $response->print("Only administrators can do that");
    }
    else {

        # Don't use the $response; we want to see things happening
        local $| = 1;    # autoflush on
        require CGI;
        print CGI::header( -status => 200, -type => 'text/plain' );
        my $query     = Foswiki::Func::getCgiQuery();
        my $nonews    = $query->param('nonews');
        my $nochanges = $query->param('nochanges');
        my @exwebs    = split( ',', $query->param('excludewebs') || '' );
        my @webs      = split( ',', $query->param('webs') || '' );
        require Foswiki::Contrib::MailerContrib;
        Foswiki::Contrib::MailerContrib::mailNotify( \@webs, 1, \@exwebs,
            $nonews, $nochanges );
    }
    return undef;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
