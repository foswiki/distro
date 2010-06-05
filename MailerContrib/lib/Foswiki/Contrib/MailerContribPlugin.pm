package Foswiki::Contrib::MailerContribPlugin;

use strict;
use warnings;
our $VERSION = '$Rev: 5752 $';
our $RELEASE = '18 Dec 2009';
our $SHORTDESCRIPTION = 'Supports e-mail notification of changes';
our $NO_PREFS_IN_TOPIC = 1;

# Plugin init method, used to initialise handlers
sub initPlugin {
    Foswiki::Func::registerRESTHandler('notify', \&_restNotify);
    return 1;
}

# Run mailnotify using a rest handler
sub _restNotify {
    my ( $session, $plugin, $verb, $response ) = @_;

    if (!Foswiki::Func::isAnAdmin()) {
        $response->header( -status  => 403, -type => 'text/plain' );
        $response->print("Only administrators can do that");
    } else {
        # Don't use the $response; we want to see things happening
        local $| = 1; # autoflush on
        require CGI;
        print CGI::header( -status => 200, -type => 'text/plain' );
        my $query = Foswiki::Func::getCgiQuery();
        my $nonews = $query->param('nonews');
        my $nochanges = $query->param('nochanges');
        my @exwebs = split(',', $query->param('excludewebs') || '');
        my @webs = split(',', $query->param('webs') || '');
        $verbose = 1; # watchen das blinken lights
        require Foswiki::Contrib::MailerContrib;
        Foswiki::Contrib::MailerContrib::mailNotify(
            \@webs, $verbose, \@exwebs, $nonews, $nochanges );
    }
    return undef;
}

1;
