# See bottom of file for license and copyright information

package Foswiki;

=begin TML

This is a configure overlay for processing the main interactive screens.
It probably should be broken up further, but for now at least it is not
loaded for resource or feedback requests.

=cut

use strict;
use Assert;

use Foswiki::Configure (); #(qw/:auth :config/);
use Foswiki::Configure::VerifyCfg ();
use Foswiki::Configure::UI ();

# ######################################################################
# Main screen for configure
# ######################################################################

sub _authenticateConfigure {

    establishSession( $_[1], $_[2] );
    my ( $action, $session, $cookie ) = @_;

    _loadSiteConfig();

    if ( loggedIn($session) || $Foswiki::Configure::badLSC || $Foswiki::Configure::query->auth_type ) {
        $Foswiki::Configure::messageType = $Foswiki::Configure::UI::MESSAGE_TYPE->{OK};
        refreshLoggedIn($session);
        refreshSaveAuthorized($session)
          if ( $Foswiki::Configure::query->param('password') || $Foswiki::Configure::badLSC );
        return;
    }

    # Not logged-in and not using browser authentication
    #
    # Password is required if set, advised on main screen if not.

    # Messages:
    #  0: Password set, must be entered
    #     Reminds how to reset
    #  1: Password not set, advise allow login
    #     N.B. Not set with browser auth doesn't require login (see above)

    my $passwordProblem =
      ( Foswiki::Configure::UI::passwordState() eq 'OK' ) ? 0 : 1;

    require Foswiki::Configure::ModalTemplates;

    my ( $template, $templateArgs ) = Foswiki::Configure::ModalTemplates->new;

    $template->addArgs( passwordProblem => $passwordProblem, logoutdata(), );

    my $html =
        Foswiki::Configure::UI::getTemplateParser()->readTemplate('pagebegin')
      . $template->extractArgs('login')
      . Foswiki::Configure::UI::getTemplateParser()->readTemplate('pageend');

    if ($passwordProblem) {
        $template->renderButton( 'loginButton', 'Login' );
    }
    else {
        $template->renderAutoActivator( 'loginButton', 'Login', 1 );
    }
    $template->renderFeedbackWindow( 'loginFeedback', 'Login' );

    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    htmlResponse($html);

    # does not return
}

sub _actionConfigure {
    my ( $action, $session, $cookie ) = @_;

    my $html;
    if ( $Foswiki::Configure::insane || $Foswiki::Configure::query->param('abort') ) {
        $html =
          $Foswiki::Configure::sanityStatement; #Set abort to view sanity statement even when "sane"
    }
    else {
        $html = ( $Foswiki::Configure::sanityStatement || '' ) . ( redirectResults() || '' );
        $html = configureScreen($html);
    }

    htmlResponse($html);
}

# ######################################################################
# Find more extensions
# ######################################################################

sub _authenticateFindMoreExtensions {

    establishSession( $_[1], $_[2] );
    my ( $action, $session, $cookie ) = @_;

    _loadSiteConfig();

    if ( loggedIn($session) ) {
        $Foswiki::Configure::messageType = $Foswiki::Configure::UI::MESSAGE_TYPE->{OK};
        refreshLoggedIn($session);
        refreshSaveAuthorized($session) if ( $Foswiki::Configure::query->param('cfgAccess') );
        return;
    }

    lscRequired( $action, $session, $cookie );

    ( my $authorised, $Foswiki::Configure::messageType ) =
      Foswiki::Configure::UI::authorised($Foswiki::Configure::query);

    if ($authorised) {
        refreshLoggedIn($session);
        refreshSaveAuthorized($session) if ( $Foswiki::Configure::query->param('cfgAccess') );
        return;
    }

    htmlResponse( _screenAuthorize( $action, $Foswiki::Configure::messageType, 0 ) );

    # does not return
}

sub _actionFindMoreExtensions {
    my ( $action, $session, $cookie ) = @_;

    my $root = new Foswiki::Configure::Root();

    my $ui = _checkLoadUI( 'EXTENSIONS', $root );

    my ( $consultedLocations, $table, $errors, $installedCount, $allCount ) =
      $ui->getExtensions();

    my $contentTemplate =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('extensions');
    $contentTemplate = Foswiki::Configure::UI::getTemplateParser()->parse(
        $contentTemplate,
        {
            'formAction'         => $Foswiki::Configure::scriptName,
            'table'              => $table,
            'errors'             => $errors,
            'consultedLocations' => $consultedLocations,
            'installedCount'     => $installedCount,
            'allCount'           => $allCount,
        }
    );

    my $html =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pagebegin');
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, { time => $Foswiki::Configure::time, logoutdata() } );
    $html .= $contentTemplate;
    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pageend');

    $html = Foswiki::Configure::UI::getTemplateParser()->parse(
        $html,
        {
            'time' => $Foswiki::Configure::time,    # use time to make sure we never allow cacheing
            logoutdata(),
            'formAction' => $Foswiki::Configure::scriptName,
        }
    );

    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    htmlResponse($html);
}

# ######################################################################
# Manage Extensions
# ######################################################################

# POST

sub _authenticateManageExtensions {

    establishSession( $_[1], $_[2] );
    my ( $action, $session, $cookie ) = @_;

    _loadSiteConfig();

    lscRequired( $action, $session, $cookie );

    if ( saveAuthorized($session) ) {
        $Foswiki::Configure::messageType = $Foswiki::Configure::UI::MESSAGE_TYPE->{
            $Foswiki::cfg{Password}
            ? 'OK'
            : 'PASSWORD_NOT_SET'
        };
        refreshLoggedIn($session);
        refreshSaveAuthorized($session);
        return;
    }

    ( my $authorised, $Foswiki::Configure::messageType ) =
      Foswiki::Configure::UI::authorised($Foswiki::Configure::query);

    if ($authorised) {
        refreshLoggedIn($session);
        refreshSaveAuthorized($session);
        return;
    }

    htmlResponse( _screenAuthorize( $action, $Foswiki::Configure::messageType, 0 ) );

    # does not return
}

sub _actionManageExtensions {
    my ( $action, $session, $cookie ) = @_;

    if ( $Foswiki::Configure::query->param('confirmChanges') ) {
        $Foswiki::Configure::query->delete('confirmChanges');

        # Here from a POST, we redirect to an internal GET
        # Collect the required parameters
        my %arg;
        foreach my $arg (qw/time processExt useCache add remove/) {
            $arg{$arg} = [ $Foswiki::Configure::query->param($arg) ];
            $Foswiki::Configure::query->delete($arg);
        }
        htmlRedirect( 'ManageExtensionsResponse', \%arg );
    }
    else {
        ## $Foswiki::Configure::query->param( 'action', $action );
        htmlResponse( _screenAuthorize( $action, $Foswiki::Configure::messageType, 1 ), )
          ;    #NO_REDIRECT );
    }
}

# GET (does the action because it wants to do real-time feedback)

sub _authenticateManageExtensionsResponse {

    establishSession( $_[1], $_[2] );
    my ( $action, $session, $cookie ) = @_;

    _loadSiteConfig();

    lscRequired( $action, $session, $cookie );

    return if ( saveAuthorized($session) );

    invalidRequest( "Sesson expired", 400 );
}

sub _actionManageExtensionsResponse {
    my ( $action, $session, $cookie ) = @_;

    my $args = redirectResults();
    $args && ref($args) eq 'HASH' or invalidRequest( "Invalid Redirect", 400 );

    foreach my $arg ( keys %$args ) {
        $Foswiki::Configure::query->delete($arg);
        $Foswiki::Configure::query->param( $arg, @{ $args->{$arg} } );
    }

    my $root = new Foswiki::Configure::Root();
    my $ui;

    # Reload the configuration - expanding variables
    delete $Foswiki::cfg{ConfigurationFinished};
    Foswiki::Configure::Load::readConfig();

    my $html =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pagebegin');
    $html = Foswiki::Configure::UI::getTemplateParser()->parse(
        $html,
        {
            'time' => $Foswiki::Configure::time,    # use time to make sure we never allow cacheing
            logoutdata()
        }
    );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    htmlResponse( $html, Foswiki::Configure::MORE_OUTPUT );

    $ui = _checkLoadUI( 'EXTEND', $root );

    # Warning: the 'install' method uses print for rapid feedback
    print $ui->install();

    $html =
        "<div class='section'>"
      . Foswiki::Configure::UI::getTemplateParser()->readTemplate('installed')
      . "</div>";
    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pageend');
    my $frontpageUrl =
"$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}/";
    $html = Foswiki::Configure::UI::getTemplateParser()->parse(
        $html,
        {
            'frontpageUrl' => $frontpageUrl,
            'configureUrl' => $Foswiki::Configure::url,
        }
    );

    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);
    print $html;
    exit;
}

# ######################################################################
# Screen that prompts for a password
# ######################################################################

sub _screenAuthorize {
    my ( $transact, $messageType, $confirm ) = @_;
    my $contents = '';

    #print STDERR
    #  "_screenAuthorize entered  $transact,  $messageType, $confirm \n";

    # create the root of the UI
    my $root = new Foswiki::Configure::Root();
    my $ui;
    my @items       = ();
    my $params      = '';
    my $hasPassword = ( $Foswiki::cfg{Password} ne '' ) || 0;

    $ui = _checkLoadUI( 'AUTH', $root );

    $Foswiki::Configure::query->delete( 'time', 'cfgAccess', 'formAction' );

    $Foswiki::Configure::query->param( 'action', $transact );

    $params = join( "\n", $ui->params() );

    my $contentTemplate = Foswiki::Configure::UI::getTemplateParser()
      ->readTemplate( $confirm ? 'confirm' : 'authorize' );

    my $changePassword = $Foswiki::Configure::query->param('changePassword') || undef;

    my ( $errors, $warnings ) = (0) x 2;
    for my $param ( $Foswiki::Configure::query->param ) {
        next unless ( $param =~ /^\{.*\}errors$/ );
        my $value = $Foswiki::Configure::query->param($param);
        if ( $value =~ /^(\d+) (\d+)$/ ) {
            $errors   += $1;
            $warnings += $2;
        }
    }

# Used in form templates to control content:
# displayStatus  - 1 = No Changes,  2 = Changes,  4 = No Extensions, 8 = Extensions, 16 = (Free), 32 = Login

    my %args = (
        'time'           => $Foswiki::Configure::time,
        'main'           => $contents,
        'hasPassword'    => $hasPassword,
        'formAction'     => $Foswiki::Configure::scriptName,
        'scriptName'     => $Foswiki::Configure::scriptName,
        'params'         => $params,
        'messageType'    => $messageType,
        'configureUrl'   => $Foswiki::Configure::url,
        'changePassword' => $changePassword,
        'changesList'    => [],
        'modifiedCount'  => 0,
        'items'          => [],
        'extAction'      => $Foswiki::Configure::action,
        'extAddCount'    => 0,
        'extRemoveCount' => 0,
        'extAddItems'    => [],
        'extRemoveItems' => [],
        'totalErrors'    => $errors,
        'totalWarnings'  => $warnings,
        'someProblems'   => $errors + $warnings,
    );
    dispatch( '_screenAuth', $transact, \&invalidDispatch, \%args );

    $contentTemplate = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $contentTemplate, \%args );

    my $html =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pagebegin');
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, { time => $Foswiki::Configure::time, logoutdata() } );
    $html .= $contentTemplate;
    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pageend');
    $html = Foswiki::Configure::UI::getTemplateParser()->parse(
        $html,
        {
            'time' => $Foswiki::Configure::time,
            logoutdata(),
            'formAction'     => $Foswiki::Configure::scriptName,
            'extAddCount'    => 0,
            'extRemoveCount' => 0,
        }
    );

    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);
    return $html;
}

# Helper to set arguments into a (defaulted) hash

sub _setArgs {
    my $args = shift;

    while ( @_ >= 2 ) {
        my $key   = shift;
        my $value = shift;

        $args->{$key} = $value;
    }
    die "Bad arg count for _setArgs\n" if (@_);
}

# Content generation for ManageExtensions authorization screen

sub _screenAuthManageExtensions {
    my $transact = shift;
    my $args     = shift;

    my $processExt = $Foswiki::Configure::query->param('processExt') || 'all';
    my @remove;
    my @add;

    foreach my $ext ( $Foswiki::Configure::query->param('remove') ) {
        $ext =~ m,^(?:([\w._-]+)/([\w._-]+))$, or next;
        my ( $repo, $extn ) = ( $1, $2 );
        push( @remove, "<td>$extn</td>" );
    }

    foreach my $ext ( $Foswiki::Configure::query->param('add') ) {
        $ext =~ m,^(?:([\w._-]+)/([\w._-]+))$, or next;
        my ( $repo, $extn ) = ( $1, $2 );
        push( @add, "<td>$extn</td><td>from $repo</td>" );
    }

    # These intermediate variables prevent a taint error.
    my $addCount      = scalar @add;
    my $removeCount   = scalar @remove;
    my $displayStatus = ( $addCount || $removeCount ) ? 8 : 4;

    _setArgs(
        $args,
        'extAction' => (
              $processExt eq 'dep'   ? 'run a dependency report'
            : $processExt eq 'sim'   ? 'simulate the following actions'
            : $processExt eq 'nodep' ? 'install without dependencies'
            : $processExt eq 'all'   ? 'perform the following actions'
            : $processExt
        ),
        'extAddCount'    => $addCount,
        'extRemoveCount' => $removeCount,
        'extAddItems'    => \@add,
        'extRemoveItems' => \@remove,
        'displayStatus'  => $displayStatus,
    );

    return;
}

# Content generation for Configure authorization screen

sub _screenAuthConfigure {
    my $transact = shift;
    my $args     = shift;

    _setArgs( $args, 'displayStatus' => 32, );
    return;

}
*_screenAuthFindMoreExtensions = \&_screenAuthConfigure;

# ######################################################################
# Generate the default screen
# ######################################################################

sub configureScreen {

    my $messages;

    # If coming from the save action, or insane, pick up the messages
    if ($Foswiki::Configure::insane) {
        $messages =
"<h2 class='foswikiAlert' style='margin-top:0px;'>Internal error - proceed with caution</h2>";
    }
    $messages .= shift;

    my $contents    = '';
    my $isFirstTime = $Foswiki::Configure::badLSC;

    #allow debugging of checker's guesses by showing the entire UI
    $isFirstTime = 0 if ( $Foswiki::Configure::query->param('DEBUG') );

    Foswiki::Configure::UI::reset($isFirstTime);
    my $valuer = new Foswiki::Configure::Valuer( \%Foswiki::cfg );

    # If there's already a notice, don't use the cart
    # E.g. MakeMoreChanges...

    unless ( $Foswiki::Configure::unsavedChangesNotice || $Foswiki::Configure::badLSC ) {
        require Foswiki::Configure::Feedback::Cart;

        my ( $cart, $cartValid ) =
          Foswiki::Configure::Feedback::Cart->get($Foswiki::Configure::session);

        my $timeSaved = $cart->loadQuery($Foswiki::Configure::query);
        my %updated;
        if ( defined $timeSaved ) {
            $valuer->loadCGIParams( $Foswiki::Configure::query, \%updated );
            $cart->removeParams($Foswiki::Configure::query);
        }

        $Foswiki::Configure::unsavedChangesNotice =
          unsavedChangesNotice( \%updated, $Foswiki::Configure::newLogin && $cartValid,
            $timeSaved );
    }

    # This is the root of the model
    my $root = new Foswiki::Configure::Root();

    # Load special sections used as placeholders

    my $intro = 'Foswiki::Configure::FeedbackCheckers::'
      . ( $isFirstTime ? 'Welcome' : 'Introduction' );
    eval "require $intro";
    Carp::confess $@ if $@;

    my $intro_checker = $intro->new($root);
    $root->addChild($intro_checker);

    my $oscfg = $Config::Config{osname};
    if ($oscfg) {

        # See if this platform has special detection or checking requirements
        my $osospecial = "Foswiki::Configure::Checkers::$oscfg";
        eval "require $osospecial";
        unless ($@) {
            my $os_checker = $osospecial->new($root);
            $root->addChild($os_checker) if $os_checker;
        }
    }

    # Load the config structures.
    # If $isFirstTime is true, only Foswiki.spec will be loaded
    # (extension Config.spec files will *not* be loaded) and
    # only the first section of Foswiki.spec will be processed
    # i.e. all other sections will be skipped.
    $Foswiki::Configure::LoadSpec::FIRST_SECTION_ONLY = 1 if $isFirstTime;
    Foswiki::Configure::LoadSpec::readSpec($root);

    my $good;
    die "VERY BAD"
      unless $good = $root->getValueObject('{Plugins}{CommentPlugin}{Enabled}');
    die "BAD $good $good->{typename}" if $good->{typename} ne 'BOOLEAN';

    Foswiki::Configure::VerifyCfg::verify( $root, !$isFirstTime );

    # Reload the environment so we pickup the OS after Foswiki.spec
    # possibly stepped on it.

    _getEnvironmentInfo();

    # Now generate the UI

    # Load the UI for the root; this UI is simply a visitor over
    # the model
    my $ui = _checkLoadUI( 'Root', $root );

    my $uiMessages = ( !$isFirstTime && $messages ) ? $messages : undef;

    if ( defined $uiMessages && ref $uiMessages ) {

        # DEBUG:
        require Data::Dumper;
        $Data::Dumper::Sortkeys = 1;
        $uiMessages =
          "Unexpected message:<pre>" . Dumper($uiMessages) . "</pre>";
    }

    # Visit the model and generate
    $ui->{controls} = new Foswiki::Configure::GlobalControls();
    $contents .= $ui->createUI( $root, $valuer );

    my $showSecurityStatement =
      ( !$isFirstTime && !loggedIn($Foswiki::Configure::session) && !$Foswiki::Configure::query->auth_type() )
      ? 1
      : undef;

    require Foswiki::Configure::ModalTemplates;

    my $template = Foswiki::Configure::ModalTemplates->new(
        $ui,
        'time' => $Foswiki::Configure::time,    # use time to make sure we never allow cacheing
        logoutdata(),
        'formAction'           => $Foswiki::Configure::scriptName,
        'messages'             => $uiMessages,
        'style'                => ( $Foswiki::Configure::badLSC || $Foswiki::Configure::insane ) ? 'Bad' : 'Good',
        'hasMainActionButtons' => 1,
        'firstTime' => $isFirstTime ? 1 : undef,
        'unsavedNotice' => $Foswiki::Configure::unsavedChangesNotice,
    );

    my $html =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pagebegin');

    if ($showSecurityStatement) {
        $html .=
          Foswiki::Configure::UI::getTemplateParser()->readTemplate('sanity');
    }
    $html .= $contents;
    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pageend');

    $template->renderActivationButton(    # buttonID => ModalModule
        passwordButton => 'ChangePassword'
    );
    $template->renderActivationButton( discardButton => 'DiscardChanges' );
    $template->renderActivationButton( saveButton    => 'SaveChanges' );
    $template->renderActivationButton( errorsButton  => 'DisplayErrors', 1 );
    $template->renderActivationButton(
        warningsButton => 'DisplayErrors',
        1
    );
    $template->renderFeedbackWindow( statusBarFeedback => 'SaveChanges' );

    # parsed twice for MODAL.pm
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $template->getArgs );
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $template->getArgs );

    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);
    return $html;
}

# ######################################################################
# Data for logout link
# ######################################################################

sub logoutdata {
    return (
        scriptName => $Foswiki::Configure::scriptName,
        loggedin   => 1,
    ) if ( loggedIn($Foswiki::Configure::session) );

    return ();
}

# ######################################################################
# Logout
# ######################################################################

sub _authenticateLogout {

    establishSession( $_[1], $_[2] );
    my ( $action, $session, $cookie ) = @_;

    _loadSiteConfig();

    return;
}

sub _actionLogout {
    my ( $action, $session, $cookie ) = @_;

    closeSession( $session, $cookie );

    my $frontpageUrl =
"$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}/";

    rawRedirect($frontpageUrl);
}

# ######################################################################
# Require valid LocalSite.cfg
# ######################################################################

sub lscRequired {
    my ( $action, $session, $cookie ) = @_;

    return unless ($Foswiki::Configure::badLSC);

    invalidRequest( "Not available until LocalSite.cfg has been repaired",
        200 );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
