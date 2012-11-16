# See bottom of file for license and copyright information

use strict;
use warnings;

package Foswiki::Configure::Checkers::ConfigureGUI::Modals::DiscardChanges;

# Modal action checker for Discard Changes.

use Foswiki::Configure(qw/:auth :cgi :feedback/);

require Foswiki::Configure::ModalTemplates;

require Foswiki::Configure::Checkers::ConfigureGUI::MODAL;
our @ISA = ('Foswiki::Configure::Checkers::ConfigureGUI::MODAL');

# Called to discard changes
#

sub generateForm {
    my $this = shift;
    my ( $keys, $query, $session, $template ) = @_;

    $template->renderButton;
    $template->renderFeedbackWindow;

    my $templateArgs = $template->getArgs;

    $template->addArgs( pendingCount => $pendingChanges );

    # Template is parsed twice intentionally.  See MODAL.pm for why.

    my $html = $template->extractArgs('discardchanges');
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

    unless ( saveAuthorized($session) || $badLSC ) {
        ( my $ok, $e ) =
          $template->passwordRequiredForm( $query, 'discardchanges' );
        return $e unless ($ok);
    }
    refreshLoggedIn($session);
    refreshSaveAuthorized($session);

    require Foswiki::Configure::Feedback::Cart;
    Foswiki::Configure::Feedback::Cart->empty($session);

    $changesDiscarded = 1;

# Force a screen refresh because the form is holding the "discarded" values, and it's
# way too much work to figure out how to reset them one at a time.

    return $e
      . $this->NOTE(
"Pending changes have been discarded.  Please wait for the screen to refresh."
      ) . $this->FB_MODAL( 'u', $scriptName );
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
