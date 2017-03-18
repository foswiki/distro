# See bottom of file for license and copyright information
package Foswiki::Plugins::MailerContribPlugin;

use strict;
use warnings;

# Also change Version/Release in Contrib/MailerContrib.pm
our $VERSION           = '2.84';
our $RELEASE           = '2.84';
our $SHORTDESCRIPTION  = 'Supports e-mail notification of changes';
our $NO_PREFS_IN_TOPIC = 1;

# Plugin init method, used to initialise handlers
sub initPlugin {
    Foswiki::Func::registerRESTHandler(
        'notify', \&_restNotify,
        authenticate => 1,
        validate     => 1,
        http_allow   => 'POST',
        description =>
          'Allow administrators to run the mailNotify process from the web.',
    );
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
        print CGI::header(
            -status  => 200,
            -type    => 'text/plain',
            -charset => $Foswiki::cfg{Site}{CharSet},
        );

        my $query   = Foswiki::Func::getCgiQuery();
        my %options = (
            verbose => 1,
            news    => 1,
            changes => 1,
            reset   => 1,
            mail    => 1
        );

        if ( $query->param('q') ) {
            $options{verbose} = 0;
        }
        if ( $query->param('nonews') ) {
            $options{news} = 0;
        }
        if ( $query->param('nochanges') ) {
            $options{changes} = 0;
        }
        if ( $query->param('noreset') ) {
            $options{reset} = 0;
        }
        if ( $query->param('nomail') ) {
            $options{mail} = 0;
        }

        my @exwebs = split( ',', $query->param('excludewebs') || '' );
        my @webs   = split( ',', $query->param('webs')        || '' );

        require Foswiki::Contrib::MailerContrib;
        Foswiki::Contrib::MailerContrib::mailNotify( \@webs, \@exwebs,
            %options );
    }
    return undef;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2017 Foswiki Contributors. Foswiki Contributors
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
