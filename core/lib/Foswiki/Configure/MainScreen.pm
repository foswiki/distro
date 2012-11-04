# See bottom of file for license and copyright information

package Foswiki;

=begin TML

This is a configure overlay for processing the main interactive screens.
It probably should be broken up further, but for now at least it is not
loaded for resource or feedback requests.

=cut

our $sanityStatement;

# ######################################################################
# Main screen for configure
# ######################################################################

sub _authenticateConfigure {

    establishSession( $_[1], $_[2] );
    my ( $action, $session, $cookie ) = @_;

    _loadSiteConfig();

    if ( loggedIn($session) || $badLSC || $query->auth_type ) {
        $messageType = $MESSAGE_TYPE->{OK};
        refreshLoggedIn($session);
        refreshSaveAuthorized($session)
          if ( $query->param('cfgAccess') || $badLSC );
        return;
    }

    ( my $authorised, $messageType ) =
      Foswiki::Configure::UI::authorised($query);

    if ($authorised) {
        refreshLoggedIn($session);
        refreshSaveAuthorized($session) if ( $query->param('cfgAccess') );
        return;
    }

    htmlResponse( _screenAuthorize( $action, $messageType, 0 ) );

    # does not return
}

sub _actionConfigure {
    my ( $action, $session, $cookie ) = @_;

    my $html;
    if ( $insane && $query->param('abort') ) {
        $html = $sanityStatement
          ;    #?? abort is never set, and $sanityStatement is just an error div
    }
    else {
        $html = ( $sanityStatement || '' ) . ( redirectResults() || '' );
        $html = configureScreen($html);
    }

    htmlResponse($html);
}

# ######################################################################
# Save changes
# ######################################################################

sub _authenticateSavechanges {

    establishSession( $_[1], $_[2] );
    my ( $action, $session, $cookie ) = @_;

    _loadSiteConfig();

    if ( saveAuthorized($session) || $badLSC ) {
        $messageType = $MESSAGE_TYPE->{
            $Foswiki::cfg{Password}
            ? 'OK'
            : 'PASSWORD_NOT_SET'
        };
        refreshLoggedIn($session);
        refreshSaveAuthorized($session);
        return;
    }

    ( my $authorised, $messageType ) =
      Foswiki::Configure::UI::authorised($query);

    if ($authorised) {
        refreshLoggedIn($session);
        refreshSaveAuthorized($session);
        return;
    }

    htmlResponse( _screenAuthorize( $action, $messageType, 0 ) );

    # does not return
}

# ######################################################################
# Action invoked by Confirm Changes button on the save authorization screen
# ######################################################################

sub _actionSavechanges {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->param('confirmChanges') ) {
        $query->delete('confirmChanges');

        # We can't compute the new main screen until the UI is rebuilt from
        # the changes.  So save the feedback and redirect to the main screen.

        htmlRedirect( 'Configure', _screenSaveChanges($messageType) );

        # Does not return
    }

    htmlResponse( _screenAuthorize( $action, $messageType, !$badLSC ) );

    # does not return
}

# ######################################################################
# Make more changes
# ######################################################################

sub _authenticateMakemorechanges {

    establishSession( $_[1], $_[2] );
    my ( $action, $session, $cookie ) = @_;

    _loadSiteConfig();

    if ( loggedIn($session) || $badLSC || $query->auth_type ) {
        $messageType = $MESSAGE_TYPE->{OK};
        refreshLoggedIn($session);
        refreshSaveAuthorized($session)
          if ( $query->param('cfgAccess') || $badLSC );
        return;
    }

    ( my $authorised, $messageType ) =
      Foswiki::Configure::UI::authorised($query);

    if ($authorised) {
        refreshLoggedIn($session);
        refreshSaveAuthorized($session);
        return;
    }

    htmlResponse( _screenAuthorize( $action, $messageType, 0 ) );

    # does not return
}

# ######################################################################
# Action invoked by Make more changes button on the save authorization screen
# ######################################################################

sub _actionMakemorechanges {
    my ( $action, $session, $cookie ) = @_;

    my $valuer =
      new Foswiki::Configure::Valuer( $Foswiki::defaultCfg, \%Foswiki::cfg );

    my %updated;
    $valuer->loadCGIParams( $Foswiki::query, \%updated );

    if ( keys %updated ) {
        $unsavedChangesNotice = unsavedChangesNotice( \%updated );
    }
    htmlResponse( configureScreen('') );

    # does not return
}

# ######################################################################
# Test Email
# ######################################################################

sub _authenticateTestEmail {

    establishSession( $_[1], $_[2] );
    my ( $action, $session, $cookie ) = @_;

    _loadSiteConfig();

    if ( loggedIn($session) ) {
        $messageType = $MESSAGE_TYPE->{OK};
        refreshLoggedIn($session);
        refreshSaveAuthorized($session) if ( $query->param('cfgAccess') );
        return;
    }

    lscRequired( $action, $session, $cookie );

    ( my $authorised, $messageType ) =
      Foswiki::Configure::UI::authorised($query);

    if ($authorised) {
        refreshLoggedIn($session);
        refreshSaveAuthorized($session) if ( $query->param('cfgAccess') );
        return;
    }

    htmlResponse( _screenAuthorize( $action, $messageType, 0 ) );

    # does not return
}

=pod

NOTE: the html markup should really be in a template!

=cut

sub _actionTestEmail {
    my ( $action, $session, $cookie ) = @_;

    my $root = new Foswiki::Configure::Root();
    my $ui;

    my $html =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pagebegin');
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, { time => $time, logoutdata() } );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    ::_loadBasicModule('Foswiki::Net');

    my $charset = $Foswiki::cfg{Site}{CharSet} || CGI::charset();

    Foswiki::Configure::Load::expandValue(
        $Foswiki::cfg{Email}{SmimeCertificateFile} );
    Foswiki::Configure::Load::expandValue( $Foswiki::cfg{Email}{SmimeKeyFile} );

    $html .= "<div class='section'>";

    my $msg = <<MAIL;
From: $Foswiki::cfg{WebMasterEmail}
To: $Foswiki::cfg{WebMasterEmail}
Subject: Test of Foswiki e-mail facility from configure
MIME-Version: 1.0
Content-Type: text/plain; charset=$charset
Content-Transfer-Encoding: 8bit

Test message from Foswiki.
MAIL

    if ( $Foswiki::cfg{WebMasterEmail} ) {
        unless ( $Foswiki::cfg{EnableEmail} ) {
            $html .=
"<div class='configureWarn'>Email is globally disabled - temporarily enabling email for this test</div>";
            $Foswiki::cfg{EnableEmail} = 1;
        }

        unless ( $Foswiki::cfg{Email}{MailMethod} ) {
            $Foswiki::cfg{Email}{MailMethod} =
              ( $Foswiki::cfg{SMTP}{MAILHOST} )
              ? 'Net::SMTP'
              : 'MailProgram';
            $html .=
"<div class='configureWarn'>Incomplete config - guessed MailMethod = <tt>$Foswiki::cfg{Email}{MailMethod}</tt></div>";
        }

        my $sendmethod =
          ( $Foswiki::cfg{Email}{MailMethod} eq 'MailProgram' )
          ? $Foswiki::cfg{MailProgram}
          : $Foswiki::cfg{Email}{MailMethod};

        # Warning: the 'install' method uses print for rapid feedback
        $html .=
"<h3>Attempting to send the following message using <tt>$sendmethod</tt></h3>\n";
        $html .= "<pre>$msg</pre>";

        $html .=
"<div class='configureInfo'>Please wait ... connecting to server ...</div>";

        $Foswiki::cfg{SMTP}{Debug} = 1;
        my $net    = Foswiki::Net->new();
        my $stderr = '';
        my $error  = '';
        eval {
            local *STDERR;
            open STDERR, '>', \$stderr;
            $error = $net->sendEmail("$msg");
            close STDERR;
        } or do {
            $error .= $@;
        };
        $html .= "<br /><h3>Results:</h3>\n";
        my $emsg =
          ($error)
          ? "<div class='configureError'>Net::sendEmail() returned the following error: <pre>$error</pre></div>"
          : "<div class='configureOK'>No errors returned</div>";
        $html .= $emsg;
        $html .=
"<div class='configureInfo'>Debug log messages: <pre>$stderr</pre></div>"
          if ($stderr);
    }
    else {
        $html .=
"<div class='configureError'>Impossible to send message: No WebMasterEmail address is configured.</div>";
    }

    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('installed');
    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pageend');
    my $frontpageUrl =
"$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}/";
    $html = Foswiki::Configure::UI::getTemplateParser()->parse(
        $html,
        {
            'frontpageUrl' => $frontpageUrl,
            'configureUrl' => $url,
        }
    );
    $html .= "</div>";
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);
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
        $messageType = $MESSAGE_TYPE->{OK};
        refreshLoggedIn($session);
        refreshSaveAuthorized($session) if ( $query->param('cfgAccess') );
        return;
    }

    lscRequired( $action, $session, $cookie );

    ( my $authorised, $messageType ) =
      Foswiki::Configure::UI::authorised($query);

    if ($authorised) {
        refreshLoggedIn($session);
        refreshSaveAuthorized($session) if ( $query->param('cfgAccess') );
        return;
    }

    htmlResponse( _screenAuthorize( $action, $messageType, 0 ) );

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
            'formAction'         => $scriptName,
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
      ->parse( $html, { time => $time, logoutdata() } );
    $html .= $contentTemplate;
    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pageend');

    $html = Foswiki::Configure::UI::getTemplateParser()->parse(
        $html,
        {
            'time' => $time,    # use time to make sure we never allow cacheing
            logoutdata(),
            'formAction' => $scriptName,
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
        $messageType = $MESSAGE_TYPE->{
            $Foswiki::cfg{Password}
            ? 'OK'
            : 'PASSWORD_NOT_SET'
        };
        refreshLoggedIn($session);
        refreshSaveAuthorized($session);
        return;
    }

    ( my $authorised, $messageType ) =
      Foswiki::Configure::UI::authorised($query);

    if ($authorised) {
        refreshLoggedIn($session);
        refreshSaveAuthorized($session);
        return;
    }

    htmlResponse( _screenAuthorize( $action, $messageType, 0 ) );

    # does not return
}

sub _actionManageExtensions {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->param('confirmChanges') ) {
        $query->delete('confirmChanges');

        # Here from a POST, we redirect to an internal GET
        # Collect the required parameters
        my %arg;
        foreach my $arg (qw/time processExt useCache add remove/) {
            $arg{$arg} = [ $query->param($arg) ];
            $query->delete($arg);
        }
        htmlRedirect( 'ManageExtensionsResponse', \%arg );
    }
    else {
        ## $query->param( 'action', $action );
        htmlResponse( _screenAuthorize( $action, $messageType, 1 ), )
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
        $query->delete($arg);
        $query->param( $arg, @{ $args->{$arg} } );
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
            'time' => $time,    # use time to make sure we never allow cacheing
            logoutdata()
        }
    );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    htmlResponse( $html, MORE_OUTPUT );

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
            'configureUrl' => $url,
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

    $query->delete( 'time', 'cfgAccess', 'formAction' );

    $query->param( 'action', $transact );

    $params = join( "\n", $ui->params() );

    my $contentTemplate = Foswiki::Configure::UI::getTemplateParser()
      ->readTemplate( $confirm ? 'confirm' : 'authorize' );

    my $changePassword = $Foswiki::query->param('changePassword') || undef;

# Used in form templates to control content:
# displayStatus  - 1 = No Changes,  2 = Changes,  4 = No Extensions, 8 = Extensions, 16 = Email Test, 32 = Login

    my %args = (
        'time'           => $time,
        'main'           => $contents,
        'hasPassword'    => $hasPassword,
        'formAction'     => $scriptName,
        'params'         => $params,
        'messageType'    => $messageType,
        'configureUrl'   => $url,
        'changePassword' => $changePassword,
        'changesList'    => [],
        'modifiedCount'  => 0,
        'items'          => [],
        'extAction'      => $action,
        'extAddCount'    => 0,
        'extRemoveCount' => 0,
        'extAddItems'    => [],
        'extRemoveItems' => [],
    );
    dispatch( '_screenAuth', $transact, \&invalidDispatch, \%args );

    $contentTemplate = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $contentTemplate, \%args );

    my $html =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pagebegin');
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, { time => $time, logoutdata() } );
    $html .= $contentTemplate;
    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pageend');
    $html = Foswiki::Configure::UI::getTemplateParser()->parse(
        $html,
        {
            'time' => $time,
            logoutdata(),
            'formAction'     => $scriptName,
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

# Content generation for Save changes authorization screen

sub _screenAuthSavechanges {
    my $transact = shift;
    my $args     = shift;

    my $valuer =
      new Foswiki::Configure::Valuer( $Foswiki::defaultCfg, \%Foswiki::cfg );
    my %updated;
    my $modified = $valuer->loadCGIParams( $Foswiki::query, \%updated );
    my $changesList = [];
    foreach my $key ( sort keys %updated ) {
        my $valueString = join( ',', $query->param($key) );
        push( @$changesList, { key => $key, value => $valueString } );
    }
    my @items = sort keys %updated if $modified;

    _setArgs(
        $args,
        'displayStatus' =>
          ( ( $modified || $Foswiki::query->param('changePassword') ) ? 2 : 1 ),
        'modifiedCount' => $modified,
        'items'         => \@items,
        'changesList'   => $changesList,
        'extAction'     => '',
    );
    return;
}

# Content generation for ManageExtensions authorization screen

sub _screenAuthManageExtensions {
    my $transact = shift;
    my $args     = shift;

    my $processExt = $query->param('processExt') || 'all';
    my @remove;
    my @add;

    foreach my $ext ( $query->param('remove') ) {
        $ext =~ m,^(?:([\w._-]+)/([\w._-]+))$, or next;
        my ( $repo, $extn ) = ( $1, $2 );
        push( @remove, "<td>$extn</td>" );
    }

    foreach my $ext ( $query->param('add') ) {
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

# Content generation for TestEmail authorization screen

sub _screenAuthTestEmail {
    my $transact = shift;
    my $args     = shift;

    _setArgs( $args, 'displayStatus' => 16, );
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
# After authentication, the screen that executes and shows the changes from save.
# ######################################################################

sub _screenSaveChanges {
    my ($messageType) = @_;

    my $valuer =
      new Foswiki::Configure::Valuer( $Foswiki::defaultCfg, \%Foswiki::cfg );
    my %updated;
    my $modified = $valuer->loadCGIParams( $Foswiki::query, \%updated );

    # create the root of the UI
    my $root = new Foswiki::Configure::Root();

    # Load the specs from the .spec files and generate the UI template
    Foswiki::Configure::FoswikiCfg::load( $root, 1 );

    my $ui = _checkLoadUI( 'UPDATE', $root );

    $ui->setInsane() if $insane;
    my $filesUpdated = $ui->commitChanges( $root, $valuer, \%updated );

    undef $ui;

    # Build list of hashes with each changed key and its value(s) for template

    my $changesList = [];
    foreach my $key ( sortHashkeyList( keys %updated ) ) {
        my $valueString = join( ',', $query->param($key) );
        push( @$changesList, { key => $key, value => $valueString } );
    }
    push @$changesList, { key => 'No configuration items changed', value => '' }
      unless (@$changesList);

    my $contentTemplate =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('feedback');
    $contentTemplate = Foswiki::Configure::UI::getTemplateParser()->parse(
        $contentTemplate,
        {
            'modifiedCount' => $modified,
            'changesList'   => $changesList,
            'formAction'    => $scriptName,
            'messageType'   => $messageType,
            'fileUpdates'   => $filesUpdated,
        }
    );

    Foswiki::Configure::UI::getTemplateParser()
      ->cleanupTemplateResidues($contentTemplate);

    return $contentTemplate;
}

# ######################################################################
# Generate the default screen
# ######################################################################

sub configureScreen {

    my $messages;

    # If coming from the save action, or insane, pick up the messages
    if ($insane) {
        $messages =
"<h2 class='foswikiAlert' style='margin-top:0px;'>Internal error - proceed with caution</h2>";
    }
    $messages .= shift;

    my $contents    = '';
    my $isFirstTime = $badLSC;

    #allow debugging of checker's guesses by showing the entire UI
    $isFirstTime = 0 if ( $query->param('DEBUG') );

    Foswiki::Configure::UI::reset($isFirstTime);

    my $valuer =
      new Foswiki::Configure::Valuer( $Foswiki::defaultCfg, \%Foswiki::cfg );

    # This is the root of the model
    my $root = new Foswiki::Configure::Root();

    # Load special sections used as placeholders

    my $intro = 'Foswiki::Configure::Checkers::'
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

    my $cgienv = 'Foswiki::Configure::CGISetup';
    eval "require $cgienv";
    Carp::confess $@ if $@;
    my $cgi_section = $cgienv->new($root);
    $cgi_section->{typename} = "CGIsetupSection";
    $root->addChild($cgi_section);

    # Load the config structures.
    # If $isFirstTime is true, only Foswiki.spec will be loaded
    # (extension Config.spec files will *not* be loaded) and
    # only the first section of Foswiki.spec will be processed
    # i.e. all other sections will be skipped.
    Foswiki::Configure::FoswikiCfg::load( $root, !$isFirstTime );

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
      ( !$isFirstTime && !loggedIn($session) && !$Foswiki::query->auth_type() )
      ? 1
      : undef;

    my $html =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pagebegin');

    if ($showSecurityStatement) {
        $html .=
          Foswiki::Configure::UI::getTemplateParser()->readTemplate('sanity');
    }
    $html .= $contents;
    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('pageend');
    $html = Foswiki::Configure::UI::getTemplateParser()->parse(
        $html,
        {
            'time' => $time,    # use time to make sure we never allow cacheing
            logoutdata(),
            'formAction' => $scriptName,
            'messages'   => $uiMessages,
            'style'      => ( $badLSC || $insane ) ? 'Bad' : 'Good',
        }
    );

    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);
    return $html;
}

# ######################################################################
# Data for logout link
# ######################################################################

sub logoutdata {
    return (
        scriptName => $scriptName,
        loggedin   => 1,
    ) if ( loggedIn($session) );

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

    return unless ($badLSC);

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
