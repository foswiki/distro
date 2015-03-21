# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Configure

UI delegate for configure function, used for editing the configuration.

=cut

package Foswiki::UI::Configure;

use strict;
use warnings;
use Assert;

use Foswiki                  ();
use Foswiki::Configure::Auth ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod configure($session)

=configure= command handler.

=cut

sub configure {
    my $session = shift;
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $query   = $session->{request};

    my $tmplData =
      $session->templates->readTemplate( 'configure', no_oops => 1 );

    $session->logger->log(
        {
            level    => 'info',
            action   => 'configure',
            webTopic => $web . '.' . $topic,
        }
    );

    Foswiki::Configure::Auth::checkAccess($session);

    unless ( $Foswiki::cfg{Plugins}{ConfigurePlugin}{Enabled} ) {
        $tmplData =
            CGI::start_html()
          . CGI::h1( {}, 'Error' )
          . <<MESSAGE . CGI::end_html();
ConfigurePlugin is not enabled (or may not be installed)
<p />
This system cannot be successfully configured via the web unless the
ConfigurePlugin is installed and enabled.
MESSAGE
    }
    elsif ( !defined($tmplData) ) {

        $tmplData =
            CGI::start_html()
          . CGI::h1( {}, 'Foswiki Installation Error' )
          . <<MESSAGE . CGI::end_html();
Template "configure" not found.
<p />
This system cannot be successfully configured via the web unless the
templates/ directory (containing configure.tmpl) is located
next to the bin/ directory (where the scripts are run from).
MESSAGE
    }

    my $meta = Foswiki::Meta->new(
        $session,
        $Foswiki::cfg{SystemWebName},
        $Foswiki::cfg{SitePrefsTopicName}
    );

    $tmplData = $meta->expandMacros($tmplData);

    # Expand JS bootsrap flag
    my $bs = $Foswiki::cfg{isBOOTSTRAPPING} ? 'true' : 'false';
    $tmplData =~ s/%BOOTSTRAPPED%/$bs/gs;

    $session->writeCompletePage($tmplData);
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
