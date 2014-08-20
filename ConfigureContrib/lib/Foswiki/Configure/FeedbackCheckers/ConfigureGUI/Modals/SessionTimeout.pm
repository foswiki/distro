# See bottom of file for license and copyright information

use strict;
use warnings;

package Foswiki::Configure::FeedbackCheckers::ConfigureGUI::Modals::SessionTimeout;

use Foswiki::Configure ();#(qw/:auth :cgi/);

# Modal action checker for session timeout.

require Foswiki::Configure::ModalTemplates;

require Foswiki::Configure::FeedbackCheckers::ConfigureGUI::MODAL;
our @ISA = ('Foswiki::Configure::FeedbackCheckers::ConfigureGUI::MODAL');

# Called to allow re-login on a session timeout.
#

sub generateForm {
    my $this = shift;
    my ( $keys, $query, $session, $template ) = @_;

    $template->renderButton;
    $template->renderFeedbackWindow;

    my $templateArgs = $template->getArgs;

    # Template is parsed twice intentionally.  See MODAL.pm for why.

    my $html = $template->extractArgs('sessiontimeout');
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    $html = $this->FB_MODAL( 'r,o', $html );
    return $html;
}

sub processForm {
    my $this = shift;
    my ( $keys, $query, $session, $template ) = @_;

    my $e = '';

    unless ( Foswiki::loggedIn($session) || $badLSC ) {
        ( my $ok, $e ) =
          $template->passwordRequiredForm( $query, 'sessiontimeout' );
        return $e unless ($ok);
    }
    refreshLoggedIn($session);

    return $this->NOTE("Your session has been resumed.") . $e
      . $this->FB_MODAL( 'u', $scriptName );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
