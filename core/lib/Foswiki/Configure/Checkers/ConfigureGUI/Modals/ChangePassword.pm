# See bottom of file for license and copyright information

use strict;
use warnings;

package Foswiki::Configure::Checkers::ConfigureGUI::Modals::ChangePassword;

# Modal action checker for Change Password.

use Foswiki::Configure(qw/:auth/);

require Foswiki::Configure::ModalTemplates;

require Foswiki::Configure::Checkers::ConfigureGUI::MODAL;
our @ISA = ('Foswiki::Configure::Checkers::ConfigureGUI::MODAL');

# Called to change password
#

sub generateForm {
    my $this = shift;
    my ( $keys, $query, $session, $template ) = @_;

    $template->renderButton;
    $template->renderFeedbackWindow;

    my $templateArgs = $template->getArgs;

    $template->addArgs(
        removePermitted => (
            $query->auth_type()
              && Foswiki::Configure::UI::passwordState() eq 'OK'
        ) ? 1 : 01
    );

    # Template is parsed twice intentionally.  See MODAL.pm for why.

    my $html = $template->extractArgs('changepassword');
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
          $template->passwordRequiredForm( $query, 'changepassword' );

        return $e unless ($ok);
    }
    refreshLoggedIn($session);
    refreshSaveAuthorized($session);

# Allow removing password with evidence of other security (browser authentication)

    if (   $query->auth_type()
        && Foswiki::Configure::UI::passwordState() eq 'OK'
        && $query->param('removePassword') )
    {
        if ( ( my $error = Foswiki::Configure::UI::removePassword() ) ) {
            $e .= $this->ERROR("Unable to remove password: $error")
              ;    # E.g. Store issues?
        }
        else {
            $e .= $this->NOTE(
"Password has been removed.  We recommend that you take other steps to protect your wiki."
            );
        }
    }
    elsif ( $query->param('removePassword') ) {
        $e .= $this->ERROR(
"Password may not be removed unless browser authentication is enabled"
        );
    }
    else {
        my ( $ok, $detail ) = Foswiki::Configure::UI::setPassword(
            ( $query->param('{WorkingDir}') || '' ),
            ( $query->param('newPassword')  || '' ),
            ( $query->param('newPassword2') || '' ),
            ( $query->remote_user()         || '' ),
            ( $query->remote_addr()         || '' ),
        );

        if ($ok) {
            $e .= $this->NOTE("Password change accepted.  Save required.");
            require Foswiki::Configure::Feedback::Cart;
            my $cart = Foswiki::Configure::Feedback::Cart->get($session);

            $cart->param( '{Password}', 'STRING', $Foswiki::cfg{Password} );
            $cart->save($session);
        }
        elsif ( $detail eq 'PASSWORD_EMPTY' ) {
            $e .= $this->ERROR("Password must not be empty");
        }
        elsif ( $detail eq 'PASSWORD_CONFIRM_NO_MATCH' ) {
            $e .= $this->ERROR("New password and verification do not match");
        }
        else {
            $e .= $this->ERROR("Password change failed: $detail");
        }
    }

    $query->delete(qw/password newpassword newpassword2 removePassword/);

    return $e;
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
