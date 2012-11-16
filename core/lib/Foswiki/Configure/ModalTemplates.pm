# See bottom of file for license and copyright information

use strict;
use warnings;

package Foswiki::Configure::ModalTemplates;

# This package provides support routines for invoking and using modal screens.

use Foswiki::Configure (qw/:auth :cgi/);

# $ui should be the triggering item - it can be a checker or any subclass of UI

sub new {
    my $class = shift;
    my $ui    = shift;

    unless ( ref $ui ) {
        my $keys = $ui;

        require Foswiki::Configure::UI;
        require Foswiki::Configure::Value;
        my $value = Foswiki::Configure::Value->new( 'UNKNOWN', keys => $keys );

        $ui = Foswiki::Configure::UI->new($value);
    }

    my $frontpageUrl =
"$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}/";
    my $self = {
        ui   => $ui,
        args => {
            time          => $time,
            formAction    => $scriptName,
            scriptName    => $scriptName,
            RESOURCEURI   => $resourceURI,
            configureUrl  => $url,
            frontpageUrl  => $frontpageUrl,
            displayStatus => 0,
            hasPassword   => (
                defined $Foswiki::cfg{Password}
                  && $Foswiki::cfg{Password} ne ''
              )
              || 0,
            authenticationNeeded =>
" <div id='configureAuthenticateForm' class='configureModalForm configureAuthenticateForm'></div>",
            @_,
        },
    };

    bless $self, $class;

    return ( $self, $self->getArgs ) if (wantarray);
    return $self;
}

# Provides an initialized argument list for a template that produces or
# calls a modal screen.

sub getArgs {
    my $this = shift;

    return $this->{args};
}

# Add to template argument list
# Does not invalidate any previous reference to list.

sub addArgs {
    my $this = shift;

    die "Odd arglist\n" if ( @_ % 2 );

    my $templateArgs = $this->getArgs;

    while (@_) {
        my ( $k, $v ) = splice( @_, 0, 2 );
        $templateArgs->{$k} = $v;
    }
    return $templateArgs;
}

# Provide rendering of a modal feedback button
# Updates template argument list with the necessary ugly infrastructure.
# $templateItem = item name for button (actionButton unless more than one)
#                 $templateItem . 'Label' will be used to expand the button
#                 label; the current template parser requires 2 passes for this.
# $actor - Module to invoke (e.g. Specials::Dance) - implicit
#          Foswiki::Configure::Checkers::ConfigureGUI::Modals
#          Defaults to caller's package.

# Activation buttons cause the modal window to be opened by trigering the
# generateForm method in the associated object.
#
# Internally, they are feedback button 1

sub renderActivationButton {
    my $this = shift;
    my ( $templateItem, $actor, $missing ) = @_;

    return $this->_renderButton( 1, @_ );
}

# Autoactivators will activate a modal on page load.  They may (or may not)
# have a real button as well.

sub renderAutoActivator {
    my $this = shift;
    my ( $templateItem, $actor, $withButton ) = @_;

    return $this->_renderButton( 1, $templateItem, $actor,
        $withButton ? 2 : 3 );
}

# Buttons are used on a modal window to initiate processing by triggering the
# processForm method in the associated object.
#
# Internally, they are feedback button 2

sub renderButton {
    my $this = shift;
    my ( $templateItem, $actor, $missing ) = @_;

    return $this->_renderButton( 2, @_ );
}

sub _renderButton {
    my $this = shift;
    my ( $type, $templateItem, $actor, $options ) = @_;

    $options ||= 0;

    my $templateArgs = $this->getArgs;

    $templateItem ||= 'actionButton';

    unless ($actor) {
        $actor = ( caller(1) )[0];
    }
    $actor =~ s/^Foswiki::Configure::Checkers::ConfigureGUI::Modals:://;

    # Default label: Template can override 2-pass substitution.
    # The javascript knows how to make a button and needs to stay in sync.

    my $label = $actor;
    $label =~ s/::/ /g;
    $label =~ s/([a-z])([A-Z])/$1 $2/g;

    $actor =~ s/::/}{/g;
    $actor = "{ConfigureGUI}{Modals}{$actor}";

    my $text = qq{<input type='hidden' name="TYPEOF:$actor" value="UNKNOWN">};
    $text .=
qq{<button type="button" value="$type" id="${actor}feedreq$type" class="foswikiButton" onclick="return doFeedback(this);">\${${templateItem}Label}</button>}
      unless ( $options & 1 );

    if ( $options & 2 ) {
        $text .= qq{<script type="text/javascript">
     \$(document).ready(function () {
        doFeedback( { id:'${actor}feedreq$type', value: 'Server request' } );
        return true;
    });</script>};
    }

    $templateArgs->{$templateItem} = $text;
    $templateArgs->{ $templateItem . 'Label' } = $label;

    return $this;
}

# Provide rendering for Feedback status area
# This matches the button, but can be placed
# elsewhere.  Contents are provided at runtime.

sub renderFeedbackWindow {
    my $this = shift;
    my ( $templateItem, $actor ) = @_;

    my $templateArgs = $this->getArgs;

    $templateItem ||= 'actionFeedback';

    unless ($actor) {
        $actor = (caller)[0];
    }
    $actor =~ s/^Foswiki::Configure::Checkers::ConfigureGUI::Modals:://;

    $actor =~ s/::/}{/g;
    $actor = "{ConfigureGUI}{Modals}{$actor}";

    my $text = qq{<div id="${actor}status" class="configureFeedback"></div>};

    $templateArgs->{$templateItem} = $text if ($templateArgs);

    return $this;
}

# Add "Password required" section to a form.

# ######################################################################
# Modal authentication
# ######################################################################

sub passwordRequiredForm {
    my $this = shift;
    my ( $query, $mainTemplate ) = @_;

    # If browser has authenticated, don't require a configure password
    # However, if one IS set, we must validate it.

    if ( $query->auth_type()
        && Foswiki::Configure::UI::passwordState eq 'PASSWORD_NOT_SET' )
    {
        refreshLoggedIn($session);
        refreshSaveAuthorized($session);

        return ( 'BROWSER_AUTHENTICATED',
            $this->{ui}->FB_MODAL( '#configureAuthenticateForm', '' ) );
    }

    my $templateArgs = $this->getArgs;

    # If password supplied & correct, return OK and code to remove form.
    # Supplied password means the session timers can be reset

    my $displayStatus = 0;
    if ( defined( my $password = $query->param('password') ) ) {
        $query->delete('password');
        my $status = Foswiki::Configure::UI::checkPassword($password);
        if ( $status eq 'OK' || $status eq 'PASSWORD_NOT_SET' ) {
            refreshLoggedIn($session);
            refreshSaveAuthorized($session);

            return ( $status,
                $this->{ui}->FB_MODAL( '#configureAuthenticateForm', '' ) );
        }
        $displayStatus = $MESSAGE_TYPE->{$status};
    }
    $this->addArgs( displayStatus => $displayStatus );

    return ( 0, '' ) unless ($mainTemplate);

    # Update argument list from main template (discard contents)

    $this->extractArgs($mainTemplate);

    my $html =
      Foswiki::Configure::UI::getTemplateParser()
      ->readTemplate('passwordrequired');
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    # Deliver form section to div

    $html = $this->{ui}->FB_MODAL( '#configureAuthenticateForm', $html );
    return ( 0, $html );
}

# ######################################################################
# Template extension - extract symbols from a(nother) template
# ######################################################################

# Removes symbol definitions of the form <$name>....</$name> from
# a template, and enters their values templateArgs.
# This allows symbols from one template to be used in another.  E.g.
# A main form defines a symbol (like a reason) needed by a second template
# that's optionally loaded later.  Returns the template with the definitions
# removed.  Can also be used as a 2-pass substitution mechanism in a
# a single template.  Does not do conditionals or anything fancy.
# Hopefully, the next generation template parser will make this unnecessary.

sub extractArgs {
    my $this = shift;
    my ($template) = @_;

    my $templateArgs = $this->getArgs;

    my $html =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate($template);
    $html =~ s,<\$([^>]*)>(.*?)</\$\1>,$templateArgs->{$1} = $2; '',egms;

    return $html;
}

sub getUI {
    my $this = shift;

    return $this->{ui};
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
