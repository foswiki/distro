# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Register

User registration handling.

=cut

package Foswiki::UI::Register;
use v5.14;

use Assert;
use Try::Tiny;

use Foswiki                ();
use Foswiki::Form          ();
use Foswiki::LoginManager  ();
use Foswiki::OopsException ();
use Foswiki::Sandbox       ();

use Moo;
use namespace::clean;
extends qw(Foswiki::UI);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Keys from the user data that should *not* be included in
# the user topic.
my %SKIPKEYS = (
    'Photo'         => 1,
    'WikiName'      => 1,
    'LoginName'     => 1,
    'Password'      => 1,
    'Confirm'       => 1,
    'Email'         => 1,
    'AddToGroups'   => 1,
    'templatetopic' => 1,
);

my @requiredFields = qw(WikiName FirstName LastName Email);

=begin TML

---++ ObjectMethod register_cgi

=register= command handler.
This method is designed to be
invoked via the =UI::run= method.

=cut

sub register_cgi {
    my $this = shift;
    my $app  = $this->app;
    my $req  = $app->request;

    # Register -> Verify -> Approve -> Finish

    my $action = $req->param('action') || '';

    # Dispatch the registration action
    # CAUTION:  Only routines intended to be called directly using the
    # action parameter should be named _action_...
    my $handler = "_action_$action";
    if ( my $handlerSub = $this->can($handler) ) {

        # absolute URL context for email generation
        $app->enterContext('absolute_urls');

        $handlerSub->($this);
        $app->leaveContext('absolute_urls');
    }
    else {
        Foswiki::OopsException->throw(
            template => 'attention',
            web      => $req->web,
            topic    => $req->topic,
            def      => 'unrecognized_action'
        );
    }
}

# Handler for 'register' action
sub _action_register {
    my $this = shift;
    my $app  = $this->app;

    # Check that the method was POST
    my $req = $app->request;
    if (   $req
        && $req->method
        && uc( $req->method ) ne 'POST' )
    {
        Foswiki::OopsException->throw(
            template => 'attention',
            web      => $req->web,
            topic    => $req->topic,
            def      => 'post_method_only',
            params   => ['register']
        );
    }

    if ( !$app->inContext('registration_supported') ) {
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $req->web,
            topic    => $req->topic,
            def      => 'registration_not_supported'
        );
    }
    if ( !$app->cfg->data->{Register}{EnableNewUserRegistration} ) {
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $req->web,
            topic    => $req->topic,
            def      => 'registration_disabled'
        );
    }
    $this->checkValidationKey($app);

    $this->_innerRegister;

    if ( $Foswiki::cfg{Register}{NeedVerification} ) {
        my $data = $this->_getDataFromQuery;

  # Add some extra fields for compatibility with older registerconfirm templates
        $data->{FirstLastName} = $data->{Name};
        $this->_requireConfirmation( $data, 'Verification', 'confirm',
            $data->{Email} );
    }
    else {

        # No need for confirmation
        $this->_complete( undef, 1 );
    }
}

# Handler for 'verify' action
sub _action_verify {
    my $this = shift;

    my $app = $this->app;

    my $code = $app->request->param('code');

    unless ($code) {
        Foswiki::Exception->throw(
            text => 'verification failed: no verification code!' );
    }
    my $data = $this->_loadPendingRegistration($code);

    if ( !exists $data->{Email} ) {
        Foswiki::OopsException->throw(
            template => 'register',
            status   => 200,
            web      => $Foswiki::cfg{UsersWebName},
            topic    => $data->{WikiName},
            def      => 'rego_not_found',
            params   => [$code]
        );
    }

    Foswiki::OopsException->throw(
        template => 'register',
        def      => 'bad_ver_code',
        params   => [ $code, 'Invalid verification code ' ]
    ) unless $data->{VerificationCode} eq $code;
    delete $data->{VerificationCode};
    _clearPendingRegistrationsForUser($code);

    if ( $Foswiki::cfg{Register}{NeedApproval} ) {
        my $approvers = $Foswiki::cfg{Register}{Approvers}
          || $Foswiki::cfg{AdminUserWikiName};
        $this->_requireConfirmation( $data, 'Approval', 'approve', $approvers );
    }
    else {

        # No need for approval
        $this->_complete( $data, 1 );
    }
}

# Handle approval denial
sub _action_disapprove {
    my $this = shift;
    my $app  = $this->app;
    my $data = $this->_checkApproval(0);
    $app->logger->log( 'warning',
"Registration denied: registration for $data->{WikiName} <$data->{Email}> was denied by $data->{Referee}"
    );

    # Display the form to optionally gather feedback and email the rejectee
    Foswiki::OopsException->throw(
        template => 'register',
        status   => 200,
        web      => $Foswiki::cfg{UsersWebName},
        topic    => $data->{WikiName},
        def      => 'rego_denied',
        params   => [ $data->{WikiName}, $data->{Email}, $data->{Referee} ]
    );
}

# Handle approval confirmation
sub _action_approve {
    my $this = shift;
    my $app  = $this->app;
    my $data = $this->_checkApproval(1);
    my $code = $app->request->param('code');

    Foswiki::OopsException->throw(
        template => 'register',
        def      => 'bad_ver_code',
        params   => [ $code, 'Invalid approval code ' ]
    ) unless $data->{ApprovalCode} eq $code;
    delete $data->{ApprovalCode};

    # SMELL: verify that someone is logged in, and they are allowed
    # to approve this registration!

    $this->_complete( $data, 0 );

    Foswiki::OopsException->throw(
        template => 'register',
        status   => 200,
        web      => $Foswiki::cfg{UsersWebName},
        topic    => $data->{WikiName},
        topic    => $data->{WikiName},
        def      => 'rego_approved',
        params   => [ $data->{WikiName} ]
    );
}

# Handle approver action; either approve or deny
sub _checkApproval {
    my $this = shift;
    my ($approve) = @_;

    my $app   = $this->app;
    my $req   = $app->request;
    my $users = $app->users;
    my $code  = $app->request->param('code');
    unless ($code) {
        Foswiki::Exception::Fatal->throw(
            text => 'approval failed: no approval code!' );
    }
    if ( $code eq 'DENIED' ) {

        # The registration has been denied; serve up denial feedback
        my $data = {
            EmailAddress => scalar( $req->param('email') ),
            Referee      => scalar( $req->param('referee') ),
            WikiName     => Foswiki::Sandbox::untaint(
                scalar( $req->param('wikiname') ) || 'UnknownUser',
                \&Foswiki::Sandbox::validateTopicName
            ),
            Feedback => scalar( $req->param('feedback') )
        };
        my $err = $this->_sendEmail( 'registerdenied', $data );
        if ($err) {
            $app->logger->log( 'warning',
"Registration rejected: registration_mail_failed - Email: $data->{EmailAddress}, Error $err"
            );
            Foswiki::OopsException->throw(
                template => 'register',
                def      => 'registration_mail_failed',
                web      => $Foswiki::cfg{UsersWebName},
                topic    => $data->{WikiName},
                params   => [ $data->{EmailAddress}, $err ]
            );
        }
        Foswiki::OopsException->throw(
            template => 'register',
            status   => 200,
            web      => $Foswiki::cfg{UsersWebName},
            topic    => $data->{WikiName},
            def      => 'rego_denial',
            params   => [ $data->{WikiName}, $data->{EmailAddress} ]
        );
    }

    # Must be logged in to approve
    Foswiki::AccessControlException->throw(
        mode   => 'APPROVE',
        user   => $app->user,
        web    => $req->web,
        topic  => $req->topic,
        reason => 'Not logged in'
    ) unless $app->inContext('authenticated');

    my $data = $this->_loadPendingRegistration($code);
    _clearPendingRegistrationsForUser($code);

    if ( !exists $data->{Email} ) {
        Foswiki::OopsException->throw(
            template => 'register',
            status   => 200,
            web      => $Foswiki::cfg{UsersWebName},
            topic    => $data->{WikiName},
            def      => 'rego_not_found',
            params   => [$code]
        );
    }

    # check if the user is already registered; if so, their registration
    # must have been approved
    my $cUID = $users->getCanonicalUserID( $data->{WikiName} );
    if ( $cUID && $users->userExists($cUID) ) {
        Foswiki::OopsException->throw(
            template => 'register',
            status   => 200,
            web      => $Foswiki::cfg{UsersWebName},
            topic    => $data->{WikiName},
            def      => 'duplicate_activation',
            params   => [ $data->{WikiName} ]
        );
    }

    # Record who is doing the approving
    $data->{Referee} = $users->getWikiName( $app->user );

    return $data;
}

# Handle password reset;
# SMELL: is this used any more? It should be going through =manage=.
sub _resetPassword {
    my $this = shift;

    my $app = $this->app;
    my $req = $app->request;
    if ( !$app->inContext('passwords_modifyable') ) {
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $req->web,
            topic    => $req->topic,
            def      => 'passwords_disabled'
        );
    }

    # resetpasswd calls checkValidationKey - don't check it here
    my $passwords = $this->create('Foswiki::UI::Passwords');
    $passwords->resetpasswd;

    # unaffected user, accessible by username.$verificationCode
}

my $b1 = "\t* ";
my $b2 = "\t$b1";

=begin TML

---++ ObjectMethod bulkRegister

Called by ManageCgiScript::bulkRegister (requires authentication) with
topic = the page with the entries on it.

NB. bulkRegister is invoked from ManageCgiScript. Why? Who knows.

Query parameters applying to all registrations:
   * =LogTopic=: Name of the topic that is created / replaced with the results.
   * =redirectto=: Topic displayed after registration is complete.  (Defaults to !LogTopic).
   * =templatetopic=: Default New user topic template name, defaults to NewUserTemplate.  This topic name must exist either in %USERSWEB% or %SYSTEMWEB%

Note that the templatetopic can be set per user, but because the template topic is likely to have different fields
in it's respective form definition, and would require different table columns.
=cut

sub bulkRegister {
    my $this = shift;

    my $app       = $this->app;
    my $req       = $app->request;
    my $users     = $app->users;
    my $templates = $app->templates;
    my $user      = $app->user;
    my $topic     = $req->topic;
    my $web       = $req->web;
    my $userweb   = $app->cfg->data->{UsersWebName};

    # absolute URL context for email generation
    $app->enterContext('absolute_urls');

    my $settings = {};

    unless ( $users->isAdmin($user) ) {
        Foswiki::OopsException->throw(
            template => 'accessdenied',
            status   => 403,
            def      => 'only_group',
            web      => $web,
            topic    => $topic,
            params   => [ $Foswiki::cfg{SuperAdminGroup} ]
        );
    }

    # Validate
    $this->checkValidationKey;

    my $templateTopic = $req->param('templatetopic');
    if ($templateTopic) {
        $templateTopic = $this->_validateTemplateTopic($templateTopic);
    }

    #-- Read the topic containing the table of people to be registered
    my $meta = Foswiki::Meta->load( $app, $web, $topic );

    my @fields;
    my @data;
    my $gotHdr = 0;
    foreach my $line ( split( /\r?\n/, $meta->text ) ) {

        # unchecked implicit untaint OK - this function is for admins only
        if ( $line =~ m/^\s*\|\s*(.*?)\s*\|\s*$/ ) {
            if ($gotHdr) {
                my $i = 0;
                my %row = map { $fields[ $i++ ] => $_ } split( /\s*\|\s*/, $1 );
                $row{templatetopic} = $templateTopic
                  unless ( $row{templatetopic} );
                push( @data, \%row );
            }
            else {
                foreach my $field ( split( /\s*\|\s*/, $1 ) ) {
                    $field =~ s/^[\s*]*(.*?)[\s*]*$/$1/;
                    $field =~ s/<.*?>//g;    #strip any html markup from heading
                    $field = Foswiki::Form::fieldTitle2FieldName($field);
                    push( @fields, $field );
                }
                $gotHdr = 1;
            }
        }
    }

    my $log = "---+ Report for Bulk Register\n%TOC%\n";

    # TODO: should check that the header row actually contains the
    # required fields.
    # TODO: and consider using MAKETEXT to enable translated tables.

    my $genReset;    # Flag set if any rows don't have a password
                     #-- Process each row, generate a log as we go
    for ( my $n = 0 ; $n < scalar(@data) ; $n++ ) {
        my $row = $data[$n];

        $row->{errors}  = '';
        $row->{webName} = $userweb;

        unless ( $row->{WikiName} ) {
            $row->{errors} .= " Not registered: WikiName not entered.";
            $row->{FAIL} = 1;
            $log .= "---++ Failed to register user on row $n: no !WikiName\n";
            next;
        }

  # If password column is empty, just delete them to avoid errors in validation.
  # Passwords are generally sent as a bulk reset after registration.
        unless ( defined $row->{Password} && length( $row->{Password} ) > 0 ) {
            delete $row->{Password};
            delete $row->{Confirm};
        }

   # If a password is provided but no Confirm column, just
   # set Confirm to the password.   Confirmation really doesn't make sense here,
        unless ( exists $row->{Password} && exists $row->{Confirm} ) {
            if ( exists $row->{Password} ) {
                $row->{Confirm} = $row->{Password};
            }
        }

        #$row->{LoginName} = $row->{WikiName} unless $row->{LoginName};

        $log .= $this->_registerSingleBulkUser( \@fields, $row, $settings );
        $genReset = 1 unless ( $row->{Password} || $row->{FAIL} );
    }

    my $tmpl = $templates->readTemplate('registermessages');
    $log .= $templates->expandTemplate('bulkreg_summary');

    # If no passwords require reset, then don't generate the reset form.
    if ($genReset) {
        $log .= $templates->expandTemplate('bulkreg_pwreset_form');
    }

    $log .= $templates->expandTemplate('bulkreg_summary_head');

    my $rowtmpl = $templates->expandTemplate('bulkreg_summary_row');

    foreach my $row (@data) {
        my $ifield = $rowtmpl;
        my $icon =
          ( $row->{FAIL} ? '%X%' : ( $row->{WARN} ? '%ICON{alert}%' : '%Y%' ) );
        my $state =
          ( $row->{FAIL} ) ? 'disabled' : ( $row->{Password} ) ? '' : 'checked';
        $ifield =~ s/\$state/$state/;
        $ifield =~ s/\$flag/$icon/;
        $ifield =~ s/\$wikiname/$row->{WikiName}/g;
        $ifield =~ s/\$errors/$row->{errors}/;
        $log .= $ifield;
    }
    $log .= $templates->expandTemplate('bulkreg_summary_foot');

    my $logWeb;
    my $logTopic = Foswiki::Sandbox::untaint(
        scalar( $req->param('LogTopic') ),
        \&Foswiki::Sandbox::validateTopicName
    ) || $topic . 'Result';
    ( $logWeb, $logTopic ) = $req->normalizeWebTopicName( '', $logTopic );

    #-- Save the LogFile as designated, link back to the source topic
    my $lmeta = $this->create(
        'Foswiki::Meta',
        web   => $logWeb,
        topic => $logTopic,
        text  => $log
    );
    unless ( $lmeta->haveAccess('CHANGE') ) {
        Foswiki::AccessControlException->throw(
            mode   => 'CHANGE',
            user   => $app->user,
            web    => $logWeb,
            topic  => $logTopic,
            reason => $Foswiki::Meta::reason
        );
    }
    $lmeta->put( 'TOPICPARENT', { name => $web . '.' . $topic } );
    $lmeta->save();

    $app->leaveContext('absolute_urls');

    # Use Foswiki::redirectto to validate redirectto req param
    # and fall back to the $logTopic if the param is not provided.
    my $redirecturl = $app->redirectto($logTopic);
    $app->redirect($redirecturl);
}

# Register a single user during a bulk registration process
sub _registerSingleBulkUser {
    my $this = shift;
    my ( $fieldNames, $row, $settings ) = @_;
    ASSERT($row) if DEBUG;

    my $app = $this->app;

    my $log = "---++ Registering $row->{WikiName}\n";

    #-- Ensure every required field exists
    # NB. LoginName is OPTIONAL
    if ( _missingElements( $fieldNames, \@requiredFields ) ) {
        $row->{errors} .= " Rejected: missing fields: "
          . join( ' ', map { $_ . ' : ' . $row->{$_} } @$fieldNames );
        $row->{FAIL} = 1;
        $log .=
            $b1
          . join( ' ', map { $_ . ' : ' . $row->{$_} } @$fieldNames )
          . ' does not contain the full set of required fields '
          . join( ' ', @requiredFields ) . "\n";
        return ( undef, $log );
    }

    my $tryError = '';
    try {

  #SMELL: Field Validations
  # foreach my $field ( %$row ) {
  #  - validate with Users::validateRegistrationField( $field, $row->{$field} );
  #  - catch any errors to log
  # Note, do this HERE and not in _validateRegistration.
  # CGI registration validates earlier in _getDataFromQuery()

        $this->_validateRegistration( $row, 0 );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $row->{errors} .= "Validation failed: " . $e->{def};
            $row->{FAIL} = 1;
            $log .= '<blockquote>' . $e->stringify($app) . "</blockquote>\n";
            $tryError = "$b1 Registration failed\n";
        }

    };

    return $log . $tryError if ($tryError);

    #-- Generation of the page is done from the {form} subhash,
    # so align the two
    $row->{form} = _makeFormFieldOrderMatch( $fieldNames, $row );

    my $users = $app->users;
    my $store = $app->store;
    my $cUID;

    try {

        # Add the user to the user management system. May throw an exception
        $cUID = $users->addUser(
            $row->{LoginName},
            $row->{WikiName},
            $app->inContext("passwords_modifyable")
            ? $row->{Password}
            : undef,
            $row->{Email}
        );
        $log .=
"$b1 $row->{WikiName} has been added to the password and user mapping managers\n";

        if ( !$store->topicExists( $row->{webName}, $row->{WikiName} ) ) {
            $log .= $this->_createUserTopic($row);
        }
        else {
            $log .= "$b1 Not writing user topic $row->{WikiName}\n";
            $row->{errors} .= " User topic not written!";
            $row->{WARN} = 1;
        }
        $users->setEmails( $cUID, $row->{Email} );

        my $loginName = '';
        $loginName = ' (' . $row->{LoginName} . ')'
          if ( $Foswiki::cfg{Register}{AllowLoginName} );

        $app->logger->log(
            {
                level    => 'info',
                action   => 'bulkregister',
                webTopic => $row->{webName} . '.' . $row->{WikiName},
                extra    => $row->{Email} . $loginName,
                user     => $row->{WikiName}
            }
        );
    }
    catch {
        $row->{errors} = " Failed to create user topic! " . $_->{def};
        $row->{FAIL}   = 1;
        $log .= "$b1 Failed to add user: " . $_->stringify() . "\n";
    };

    if ( $cUID && $row->{AddToGroups} ) {
        my @addedTo;
        foreach my $groupName ( split( /\s*,\s*/, $row->{AddToGroups} ) ) {
            try {
                $users->addUserToGroup( $cUID, $groupName );
                push @addedTo, $groupName;
            }
            catch {
                my $e   = $_;
                my $err = Foswiki::Exception::errorStr($e);
                $app->logger->log( 'warning',
"Registration: Failure adding $cUID to $groupName in BulkRegister"
                );
                $log .= "   * Failed to add $cUID to $groupName: $err\n";
                $row->{errors} .= " Failed to add $cUID to $groupName: $err";
                $row->{WARN} = 1;
            };
        }

        if ( scalar @addedTo ) {
            $log .= "   * $row->{WikiName} added to groups: "
              . join( ', ', @addedTo ) . "\n";
        }
    }

    #if ($Foswiki::cfg{EmailUserDetails}) {
    # If you want it, write it.
    # _sendEmail($app, 'registernotifybulk', $data );
    #    $log .= $b1.' Password email disabled\n';
    #}

    return $log;
}

# ensures all named fields exist in hash
# returns array containing any that are missing
sub _missingElements {
    my ( $presentArrRef, $requiredArrRef ) = @_;
    my %present;
    my @missing;

    $present{$_} = 1 for @$presentArrRef;
    foreach my $required (@$requiredArrRef) {
        if ( !$present{$required} ) {
            push @missing, $required;
        }
    }
    return @missing;
}

# rearranges the fields in $data so that they match settings
# returns a new ordered form
sub _makeFormFieldOrderMatch {
    my ( $fieldNames, $data ) = @_;
    my @form = ();
    foreach my $field (@$fieldNames) {
        push @form, { name => $field, value => $data->{$field} };
    }
    return \@form;
}

# Get registration data from the CGI query and validate it
sub _innerRegister {
    my $this = shift;

    my $app  = $this->app;
    my $req  = $app->request;
    my $data = $this->_getDataFromQuery;

    $data->{webName} = $req->web;

    my $oldName = $data->{WikiName};
    $oldName = 'undef' unless defined $oldName;
    $data->{WikiName} =
      Foswiki::Sandbox::untaint( $data->{WikiName},
        \&Foswiki::Sandbox::validateTopicName );
    unless ( $data->{WikiName} ) {
        $app->logger->log( 'warning',
            "Registration rejected: validateTopicName failed for $oldName" );
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'bad_wikiname',
            web      => $data->{webName},
            topic    => $req->topic,
            params   => [$oldName]
        );
    }

    $this->_validateRegistration( $data, 1 );
}

# Send email requesting confirmation. Supports verification and approval.
# The recipient of the mail is passed $approvers, which is then written to
# {EmailAddress} for each recipient. $approvers can be one or more email
# addresses and/or wikinames.
sub _requireConfirmation {
    my $this = shift;
    my ( $data, $type, $template, $approvers ) = @_;

    my $app = $this->app;
    my $req = $app->request;

    my $web   = $req->web;
    my $topic = $req->topic;

    my $oldName = $data->{WikiName};

    $data->{WikiName} =
      Foswiki::Sandbox::untaint( $data->{WikiName},
        \&Foswiki::Sandbox::validateTopicName );

    unless ( $data->{WikiName} ) {
        $app->logger->log( 'warning',
            "$type rejected: validateTopicName failed for $oldName" );
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'bad_wikiname',
            web      => $data->{webName},
            topic    => $req->topic,
            params   => [$oldName]
        );
    }
    $data->{LoginName} ||= $data->{WikiName};
    $data->{webName} = $web;

    $data->{"${type}Code"} = $data->{WikiName} . '.' . int( rand(99999999) );

    # SMELL: used for Register unit tests
    $app->heap->{DebugVerificationCode} = $data->{"${type}Code"};

    my $file = _codeFile( $data->{"${type}Code"} );
    my $F;
    open( $F, '>', $file )
      or
      Foswiki::Exception::Fatal->throw( text => 'Failed to open file: ' . $! );
    print $F "# $type code\n";

    # SMELL: wierd jiggery-pokery required, otherwise Data::Dumper screws
    # up the form fields when it saves. Perl bug? Probably to do with
    # chucking around arrays, instead of references to them.
    my $form = $data->{form};
    $data->{form} = undef;
    print $F Data::Dumper->Dump( [ $data, $form ], [ 'data', 'form' ] );
    $data->{form} = $form;
    close($F);

    $app->logger->log(
        {
            level    => 'info',
            action   => 'regstart',
            webTopic => $Foswiki::cfg{UsersWebName} . '.' . $data->{WikiName},
            extra    => $data->{Email},
            user     => $data->{WikiName},
        }
    );

    if ( $Foswiki::cfg{EnableEmail} ) {

        my @referees = split( /,\s*/, $approvers );
        my $app;
        $data->{EmailAddress} = '';
        while ( $app = pop @referees ) {
            unless ( $app =~ m/\@/ ) {
                $data->{Referee} = $app;
                my $cUID = $app->users->getCanonicalUserID($app);
                if ($cUID) {
                    push( @referees,
                        map { "$app <$_>" } $app->users->getEmails($cUID) );
                }
                next;
            }

            $data->{EmailAddress} = $app;    # recipient
            my $err = $this->_sendEmail( "register$template", $data );

            if ($err) {
                $app->logger->log( 'warning',
"Registration rejected: registration_mail_failed - Email: $data->{EmailAddress}, Error $err"
                );
                Foswiki::OopsException->throw(
                    template => 'register',
                    def      => 'registration_mail_failed',
                    web      => $data->{webName},
                    topic    => $topic,
                    params   => [ $data->{EmailAddress}, $err ]
                );
            }
        }
    }
    else {
        my $err = $app->i18n->maketext(
'Registration cannot be completed: Email has been disabled for this Foswiki installation'
        );

        Foswiki::OopsException->throw(
            template => 'attention',
            def      => 'send_mail_error',
            web      => $data->{webName},
            topic    => $topic,
            params   => [ 'all', $err ]
        );
    }

    Foswiki::OopsException->throw(
        template => 'register',
        status   => 200,
        def      => $template,                  # confirm or approve
        web      => $data->{webName},
        topic    => $topic,
        params   => [ $data->{EmailAddress} ]
    );
}

=begin TML

---++ ObjectMethod deleteUser
CGI function that deletes the current user
Renames the *current* user's topic (with renaming all links) and
removes user entry from passwords.

NB. deleteUser is invoked from the =manage= script.

=cut

sub deleteUser {
    my $this = shift;

    my $app         = $this->app;
    my $req         = $app->request;
    my $webName     = $req->web;
    my $topic       = $req->topic;
    my $cUID        = $app->user;
    my $user        = $req->param('user');
    my $topicPrefix = $req->param('topicPrefix');

    # Check that the method was POST
    if (   $req
        && $req->method
        && uc( $req->method ) ne 'POST' )
    {
        Foswiki::OopsException->throw(
            template => 'attention',
            web      => $webName,
            topic    => $topic,
            def      => 'post_method_only',
            params   => ['remove']
        );
    }

    unless ( $req->param('user') ) {
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $webName,
            topic    => $topic,
            def      => 'user_param_required',
        );
    }
    my $users        = $app->users;
    my $myWikiName   = $users->getWikiName($cUID);
    my $userWikiName = $users->getWikiName($user);

    $this->checkValidationKey;

    # Default behavior is to leave the user topic in place. Checkbox parameters
    # are not submitted unless checked.
    my $removeTopic =
      ( defined $req->param('removeTopic') )
      ? $req->param('removeTopic')
      : 0;

    # This is the old behavior - remove the current logged in user.  For safety
    # Make sure the requested user = current user.
    unless ( Foswiki::Func::isAnAdmin() ) {

        if ( ( $user ne $cUID ) && ( $myWikiName ne $userWikiName ) ) {
            Foswiki::OopsException->throw(
                template => 'register',
                web      => $webName,
                topic    => $topic,
                def      => 'not_self',
                params   => [$userWikiName]
            );
        }

        # check if user entry exists
        if ( !$users->userExists($cUID) ) {
            Foswiki::OopsException->throw(
                template => 'register',
                web      => $webName,
                topic    => $topic,
                def      => 'not_a_user',
                params   => [$userWikiName]
            );
        }

        my $password = $req->param('password');
        unless (
            $users->checkPassword( $users->getLoginName($cUID), $password ) )
        {
            Foswiki::OopsException->throw(
                template => 'register',
                web      => $webName,
                topic    => $topic,
                def      => 'wrong_password'
            );
        }
    }

    if ( $removeTopic && $req->param('topicPrefix') ) {
        $topicPrefix = Foswiki::Sandbox::untaint(
            scalar( $req->param('topicPrefix') ),
            \&Foswiki::Sandbox::validateTopicName
        );
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $webName,
            topic    => $topic,
            def      => 'bad_prefix'
        ) unless ($topicPrefix);
    }

    $topicPrefix ||= 'DeletedUser';

    my ( $m, $lm ) =
      _processDeleteUser(
        { cuid => $user, removeTopic => $removeTopic, prefix => $topicPrefix }
      );

    Foswiki::Func::writeWarning("$cUID: $lm");

    Foswiki::OopsException->throw(
        template => 'register',
        status   => 200,
        def      => 'remove_user_done',
        web      => $webName,
        topic    => $topic,
        params   => [ $userWikiName, $m ]
    );
}

=begin TML

---++ ObjectMethod addUserToGroup
adds users to a group
   * groupname parameter must a a single groupname (group does not
     have to exist)
   * username can be a single login/wikiname/(!cuid?), a URLParam
     list, or a comma separated list.

NB. Invoked from the =manage= script

=cut

sub addUserToGroup {
    my $this = shift;

    my $app   = $this->app;
    my $req   = $app->request;
    my $topic = $req->topic;
    my $web   = $req->web;
    my $user  = $app->user;
    my $users = $app->users;

    my @userNames = $req->multi_param('username');

    my $groupName = $req->param('groupname');
    my $create = Foswiki::isTrue( scalar( $req->param('create') ), 0 );
    if ( !$groupName or $groupName eq '' ) {
        my $userNames = scalar(@userNames) ? join( ',', @userNames ) : '';
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'no_group_specified_for_add_to_group',
            web      => $web,
            topic    => $topic,
            params   => [$userNames]
        );
    }

    $this->checkValidationKey;

    if (   ( $#userNames < 0 )
        or ( $userNames[0] eq '' ) )
    {

        # if $create is set, and there are no users in the
        # list, and the group exists
        # then we're trying to upgrade the user topic.
        # I'm not sure what other mappers might make of this..
        if ( $create and Foswiki::Func::isGroup($groupName) ) {
            try {
                $users->addUserToGroup( undef, $groupName, $create );
            }
            catch {

                # Log the error
                $app->logger->log( 'warning',
                    "catch: Failed to upgrade $groupName " . $_->stringify() );
            };

            Foswiki::OopsException->throw(
                template => 'register',
                status   => 200,
                def      => 'group_upgraded',
                web      => $web,
                topic    => $topic,
                params   => [$groupName]
            );
        }
    }

    if (   !Foswiki::Func::isGroup($groupName)
        && !$create )
    {
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'no_group_and_no_create',
            web      => $web,
            topic    => $topic,
        );
    }
    if ( $#userNames == 0 ) {
        @userNames = split( /,\s*/, $userNames[0] );
    }

    # If a users create a new group, make sure he is in the group
    # Otherwise he will not be able to touch the group after the
    # first user is added because this code saves once per user - and the
    # group will be restricted to that group. It is also good to prevent the
    # user from shooting himself in the foot.
    # He can afterwards remove himself if needed
    # We make an exception if you are an admin as they can always edit anything

    if (    !Foswiki::Func::isGroup($groupName)
        and !$users->isAdmin($user)
        and $create )
    {
        unshift( @userNames, $users->getLoginName($user) );
    }

    my @failed;
    my @succeeded;
    push @userNames, '<none>' if ( scalar(@userNames) == 0 );
    foreach my $u (@userNames) {
        $u =~ s/^\s+//;
        $u =~ s/\s+$//;

        # We strip off any usersweb prefix
        $u =~ s/^($Foswiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//;

        #next if ( $u eq '' );
        $u = '' if ( $u eq '<none>' );

        next
          if ( Foswiki::Func::isGroup($groupName)
            && Foswiki::Func::isGroupMember( $groupName, $u, { expand => 0 } )
          );

        try {
            $u = $users->validateRegistrationField( 'username', $u );
            $users->addUserToGroup( $u, $groupName, $create );
            push( @succeeded, $u );
        }
        catch {
            my $e    = $_;
            my $mess = $e->stringify();
            $mess =~ s/ at .*$//s;

            push( @failed, "$u : $mess" );

            # Log the error
            $app->logger->log( 'warning', $e->stringify() );
        };
    }
    if ( @failed || !@succeeded ) {
        $app->logger->log( 'warning',
            "failed: " . scalar(@failed) . " Succeeded " . scalar(@succeeded) );
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $web,
            topic    => $topic,
            def      => 'problem_adding_to_group',
            params   => [ join( ', ', @failed ), $groupName ]
        );
    }

    my $url = $app->redirectto();
    unless ($url) {
        Foswiki::OopsException->throw(
            template => 'register',
            status   => 200,
            def      => 'added_users_to_group',
            web      => $web,
            topic    => $topic,
            params   => [ join( ', ', @succeeded ), $groupName ]
        );
    }
    else {
        $app->redirect($url);
    }
}

=begin TML

---++ ObjectMethod removeUserFromGroup
Removes users from a group
   * groupname parameter must a a single groupname (group does not have
     to exist)
   * username can be a single login/wikiname/(cuid?), a URLParam list,
     or a comma separated list.

NB. Invoked from the =manage= script

=cut

sub removeUserFromGroup {
    my $this = shift;

    my $app   = $this->app;
    my $req   = $app->request;
    my $topic = $req->topic;
    my $web   = $req->web;
    my $user  = $app->user;

    my @userNames = $req->multi_param('username');
    my $groupName = $req->param('groupname');
    if (   ( $#userNames < 0 )
        or ( $userNames[0] eq '' ) )
    {
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'no_users_to_remove_from_group'
        );
    }
    if ( $#userNames == 0 ) {
        @userNames = split( /,\s+/, $userNames[0] );
    }
    if ( !$groupName or $groupName eq '' ) {
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'no_group_specified_for_remove_from_group'
        );
    }
    unless ( Foswiki::Func::isGroup($groupName) ) {
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'problem_removing_from_group'
        );
    }

    # Validate
    $this->checkValidationKey;

    my @failed;
    my @succeeded;
    foreach my $u (@userNames) {
        $u =~ s/^\s+//;
        $u =~ s/\s+$//;

        next if ( $u eq '' );
        try {
            Foswiki::Func::removeUserFromGroup( $u, $groupName );
            push( @succeeded, $u );
        }
        catch {
            my $e    = $_;
            my $mess = $e->stringify();
            $mess =~ s/ at .*$//s;

            push( @failed, "$u: $mess" );

            # Log the error
            $app->logger->log( 'warning', $e->stringify() );
        };
    }
    if (@failed) {
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $web,
            topic    => $topic,
            def      => 'problem_removing_from_group',
            params   => [ join( ', ', @failed ), $groupName ]
        );
    }

    my $url = $app->redirectto();
    unless ($url) {
        Foswiki::OopsException->throw(
            template => 'register',
            status   => 200,
            def      => 'removed_users_from_group',
            web      => $web,
            topic    => $topic,
            params   => [ join( ', ', @succeeded ), $groupName ]
        );
    }
    else {
        $app->redirect($url);
    }
}

# Complete a registration (commit it to the DB)
sub _complete {
    my $this = shift;
    my ( $data, $thanks ) = @_;

    my $app = $this->app;
    my $req = $app->request;

    my $topic = $req->topic;
    my $web   = $req->web;

    $data ||= $this->_getDataFromQuery;
    $data->{webName} = $web;
    $data->{WikiName} =
      Foswiki::Sandbox::untaint( $data->{WikiName},
        \&Foswiki::Sandbox::validateTopicName );

    if ( !exists $data->{LoginName} ) {
        if ( $Foswiki::cfg{Register}{AllowLoginName} ) {

            # This should have been populated
            Foswiki::Exception::Fatal->throw(
                text => 'no LoginName after reload' );
        }
        $data->{LoginName} ||= $data->{WikiName};
    }

    my $users = $app->users;
    try {
        unless ( !$app->inContext("passwords_modifyable")
            || defined( $data->{Password} ) )
        {

            # SMELL: should give consideration to disabling
            # $Foswiki::cfg{Register}{HidePasswd} though that may
            # reduce the conf options an admin has..
            # OR, a better option would be that the rego email would
            # thus point the user to the resetPasswd url.
            $data->{Password} = Foswiki::Users::randomPassword();

            #add data to the form so it can go out in the registration emails.
            push(
                @{ $data->{form} },
                { name => 'Password', value => $data->{Password} }
            );
        }

        my $cUID = $users->addUser(
            $data->{LoginName},
            $data->{WikiName},
            $app->inContext("passwords_modifyable")
            ? $data->{Password}
            : undef,
            $data->{Email}
        );
        my $log = $this->_createUserTopic($data);
        $users->setEmails( $cUID, $data->{Email} );

        # convert to rego agent user copied from
        # _writeRegistrationDetailsToTopic
        my $safe             = $app->user;
        my $regoAgent        = $app->user;
        my $enableAddToGroup = 1;

        if ( Foswiki::Func::isGuest($regoAgent) ) {
            $app->user(
                $app->users->getCanonicalUserID(
                    $Foswiki::cfg{Register}{RegistrationAgentWikiName}
                )
            );
            $regoAgent = $app->user;

            # SECURITY ISSUE:
            # When upgrading an existing Wiki, the RegistrationUser is
            # in the AdminGroup. Thus newly registering users would be
            # able to join the AdminGroup. So disable the
            # AddUserToGroupOnRegistration if the agent is still admin :(
            $enableAddToGroup = !$app->users->isAdmin($regoAgent);
            if ( !$enableAddToGroup ) {

                # TODO: should really tell the user too?
                $app->logger->log( 'warning',
                        'Registration failed: can\'t add user to groups ('
                      . $data->{AddToGroups}
                      . ' because '
                      . $Foswiki::cfg{Register}{RegistrationAgentWikiName}
                      . 'is in the '
                      . $Foswiki::cfg{SuperAdminGroup} );
            }
        }

        my @addedTo;

        if ( ($enableAddToGroup) and ( $data->{AddToGroups} ) ) {
            foreach my $groupName ( split( /,/, $data->{AddToGroups} ) ) {
                $app->user($regoAgent);
                try {
                    $users->addUserToGroup( $cUID, $groupName );
                    push @addedTo, $groupName;
                }
                catch {
                    my $e = shift;
                    $app->logger->log( 'warning',
                        "Registration: Failure adding $cUID to $groupName" );
                }
                finally {
                    $app->user($safe);
                    if (@_) {
                        $_[0]->throw;
                    }

                };
            }
        }

        $data->{AddToGroups} = join( ',', @addedTo );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $users->removeUser( $data->{LoginName}, $data->{WikiName} )
              if ( $users->userExists( $data->{WikiName} ) );
            $e->rethrow;

            #Foswiki::OopsException->throw ( @_ ); # Propagate
        }
        else {

            if ( !ref($e) ) {
                Foswiki::Exception->rethrow($e);
            }

            $users->removeUser( $data->{LoginName}, $data->{WikiName} )
              if ( $users->userExists( $data->{WikiName} ) );

            # Log the error
            $app->logger->log( 'warning',
                'Registration failed: ' . $e->stringify() );
            Foswiki::OopsException->throw(
                template => 'register',
                web      => $data->{webName},
                topic    => $topic,
                def      => 'problem_adding',
                params   => [ $data->{WikiName}, $e->stringify() ]
            );
        }
    };

    # Plugin to do some other post processing of the user.
    # for legacy, (callback to set cookies - now should use LoginHandler)
    # DEPRECATED HANDLER. DO NOT USE!
    $app->plugins->dispatch( 'registrationHandler', $req->web,
        $data->{WikiName}, $data->{LoginName}, $data );

    my $status;
    my $safe2login = 1;

    if ( $Foswiki::cfg{EnableEmail} ) {

        # inform user and admin about the registration.
        $status = $this->_emailRegistrationConfirmations($data);

        my $loginName = '';
        $loginName = ' (' . $data->{LoginName} . ')'
          if ( $Foswiki::cfg{Register}{AllowLoginName} );

        $app->logger->log(
            {
                level    => 'info',
                action   => 'register',
                webTopic => $Foswiki::cfg{UsersWebName} . '.'
                  . $data->{WikiName},
                extra => $data->{Email} . $loginName,
                user  => $data->{WikiName},
            }
        );

        if ($status) {
            $status =
              $app->i18n->maketext('Warning: Could not send confirmation email')
              . "\n\n$status";
            $safe2login = 0;
        }
        else {
            $status = $app->i18n->maketext(
                'A confirmation e-mail has been sent to [_1]',
                $data->{Email} );
        }
    }
    else {
        $status = $app->i18n->maketext(
'Warning: Could not send confirmation email, email has been disabled'
        );
    }

    # Only change the session's identity _if_ the registration was done by
    # WikiGuest or the RegistrationAgent, and an email was correctly sent.
    # SECURITY ISSUE:
    # When upgrading an existing Wiki, the RegistrationUser is
    # in the AdminGroup. So disable the automatic login if the agent is
    # still admin.
    my $guestUID =
      $app->users->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );
    my $regUID =
      $app->users->getCanonicalUserID(
        $Foswiki::cfg{Register}{RegistrationAgentWikiName} );
    if (
        $safe2login
        && (   $app->user eq $guestUID
            || $app->user eq $regUID && !$app->users->isAdmin($regUID) )
      )
    {

        # let the client session know that we're logged in. (This probably
        # eliminates the need for the registrationHandler call above,
        # but we'll leave them both in here for now.)
        $users->{loginManager}
          ->userLoggedIn( $data->{LoginName}, $data->{WikiName} );
    }

    if ($thanks) {

        # and finally display thank you page
        Foswiki::OopsException->throw(
            template => 'register',
            status   => 200,
            web      => $Foswiki::cfg{UsersWebName},
            topic    => $data->{WikiName},
            def      => 'thanks',
            params   => [ $status, $data->{WikiName} ]
        );
    }
}

# Given a template and a hash, creates a new topic for a user
sub _createUserTopic {
    my $this     = shift;
    my ($row)    = @_;
    my $app      = $this->app;
    my $template = $row->{templatetopic} || 'NewUserTemplate';
    my $fromWeb  = $Foswiki::cfg{UsersWebName};

# This is safe because the $template name is fully validated in _validateRegistration()
    ($template) = $template =~ m/^(.*)$/;

    ( $fromWeb, $template ) =
      Foswiki::Func::normalizeWebTopicName( $fromWeb, $template );

    if ( !$app->store->topicExists( $fromWeb, $template ) ) {

        # Use the default version
        $fromWeb = $Foswiki::cfg{SystemWebName};
    }

    my $tobj = Foswiki::Meta->load( $app, $fromWeb, $template );

    my $log =
        $b1
      . ' Writing topic '
      . $Foswiki::cfg{UsersWebName} . '.'
      . $row->{WikiName} . "\n"
      . "$b1 !RegistrationHandler:\n"
      . $this->_writeRegistrationDetailsToTopic( $row, $tobj );
    return $log;
}

# Writes the registration details passed as a hash to either BulletFields
# or FormFields on the user's topic.
#
sub _writeRegistrationDetailsToTopic {
    my $this = shift;
    my ( $data, $templateTopicObject ) = @_;

    my $app = $this->app;

    ASSERT( $data->{WikiName} ) if DEBUG;

    my ( $before, $repeat, $after );
    ( $before, $repeat, $after ) =
      split( /%SPLIT%/, $templateTopicObject->text() || '', 3 )
      if $templateTopicObject;
    $before = '' unless defined($before);
    $after  = '' unless defined($after);

    my $user = $data->{WikiName};

    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $Foswiki::cfg{UsersWebName},
        topic => $user
    );
    my $log;
    my $addText;

    $topicObject->copyFrom($templateTopicObject);

    my $form = $templateTopicObject->get('FORM');

    if ($form) {
        ( $topicObject, $addText ) =
          $this->_populateUserTopicForm( $form->{name}, $topicObject, $data );
        $log = "$b2 Using Form Fields\n";
    }
    else {
        $addText = _getRegFormAsTopicContent($data);
        $log     = "$b2 Using Bullet Fields\n";
    }
    my $text = $before . $addText . $after;

    # Note: it may look dangerous to override the user this way, but
    # it's actually quite safe, because only a subset of tags are
    # expanded during topic creation. If the set of tags expanded is
    # extended, then the impact has to be considered.
    my $safe = $app->user;
    $app->user($user);
    try {
        $topicObject->text($text);
        $topicObject->expandNewTopic();
        my $agent = $Foswiki::cfg{Register}{RegistrationAgentWikiName};
        $app->user( $app->users->getCanonicalUserID($agent) );
        $topicObject->put( 'TOPICPARENT',
            { name => $Foswiki::cfg{UsersTopicName} } );

        unless ( $topicObject->haveAccess('CHANGE') ) {
            Foswiki::AccessControlException->throw(
                mode   => 'CHANGE',
                user   => $agent,
                web    => $topicObject->web,
                topic  => $topicObject->topic,
                reason => $Foswiki::Meta::reason
            );
        }
        $topicObject->save();
    }
    finally {
        $app->user($safe);
        if (@_) {
            $_[0]->throw;
        }

    };
    return $log;
}

# Puts form fields into the topic form
sub _populateUserTopicForm {
    my $this = shift;
    my ( $formName, $meta, $data ) = @_;

    my $app = $this->app;

    my %inform;
    require Foswiki::Form;

    my $form =
      Foswiki::Form->loadCached( $app, $Foswiki::cfg{UsersWebName}, $formName );

    return ( $meta, '' ) unless $form;

    foreach my $field ( @{ $form->getFields() } ) {
        foreach my $fd ( sort { $a->{name} cmp $b->{name} } @{ $data->{form} } )
        {
            next unless $fd->{name} eq $field->{name};
            next if $SKIPKEYS{ $fd->{name} };
            my $item = $meta->get( 'FIELD', $fd->{name} );
            if ($item) {
                $item->{value} = $fd->{value};
            }
            else {

                # Field missing from the new user template - create
                # from scratch
                $item = {
                    name  => $fd->{name},
                    value => $fd->{value},
                };
            }
            $meta->putKeyed( 'FIELD', $item );
            $inform{ $fd->{name} } = 1;
            last;
        }
    }
    my $leftoverText = '';
    foreach my $fd ( sort { $a->{name} cmp $b->{name} } @{ $data->{form} } ) {
        unless ( $inform{ $fd->{name} } || $SKIPKEYS{ $fd->{name} } ) {
            $leftoverText .= "   * $fd->{name}: $fd->{value}\n";
        }
    }
    return ( $meta, $leftoverText );
}

# Registers a user using the old bullet field code
sub _getRegFormAsTopicContent {
    my $data = shift;

    my $text;
    foreach my $fd ( sort { $a->{name} cmp $b->{name} } @{ $data->{form} } ) {
        next if $SKIPKEYS{ $fd->{name} };
        my $title = $fd->{name};
        $title =~ s/([a-z0-9])([A-Z0-9])/$1 $2/g;    # Spaced
        my $value = $fd->{value};
        $value =~ s/[\n\r]//g;
        $text .= "   * $title\: $value\n";
    }
    return $text;
}

# Sends to both the WIKIWEBMASTER and the USER notice of the registration
# emails both the admin 'registernotifyadmin' and the user 'registernotify',
# in separate emails so they both get targeted information (and no
# password to the admin).
sub _emailRegistrationConfirmations {
    my $this = shift;
    my ($data) = @_;

    my $app = $this->app;

    my $template = $app->templates->readTemplate('registernotify');
    my $email =
      $this->_buildConfirmationEmail( $data, $template,
        $Foswiki::cfg{Register}{HidePasswd} );

    my $warnings = $app->net->sendEmail($email);

    if ($warnings) {

        # Email address doesn't work, likely fraudulent registration
        try {
            my $users = $app->users;
            my $cUID  = $users->getCanonicalUserID( $data->{LoginName} );

            $template =
              $app->templates->readTemplate('registerfailednotremoved');
        }
        catch {

            # Most Mapping Managers don't support removeUser, unfortunately
            $template =
              $app->templates->readTemplate('registerfailednotremoved');
        };
    }
    else {
        $template = $app->templates->readTemplate('registernotifyadmin');
    }

    $email = $this->_buildConfirmationEmail( $data, $template, 1 );

    my $err = $app->net->sendEmail($email);
    if ($err) {

        # don't tell the user about this one
        $app->logger->log( 'warning',
            'Could not confirm registration: ' . $err );
    }

    return $warnings;
}

#The template dictates the to: field
sub _buildConfirmationEmail {
    my $this = shift;
    my ( $data, $templateText, $hidePassword ) = @_;

    my $app = $this->app;

    $data->{Name} ||= $data->{WikiName};
    $data->{LoginName} = '' unless defined $data->{LoginName};

    $templateText =~ s/%FIRSTLASTNAME%/$data->{Name}/g;
    $templateText =~ s/%WIKINAME%/$data->{WikiName}/g;
    $templateText =~ s/%EMAILADDRESS%/$data->{Email}/g;
    $templateText =~ s/%TEMPLATETOPIC%/$data->{templatetopic}/g;

    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $Foswiki::cfg{UsersWebName},
        topic => $data->{WikiName}
    );
    $templateText = $topicObject->expandMacros($templateText);

    #add LoginName to make it clear to new users
    my $loginName = $b1 . ' LoginName: ' . $data->{LoginName} . "\n";

    # SMELL: this means we fail hard if there are 2 FORMDATA vars -
    #       like in multi-part mime - txt & html
    my ( $before, $after ) = split( /%FORMDATA%/, $templateText );
    $before .= $loginName;
    foreach my $fd ( sort { $a->{name} cmp $b->{name} } @{ $data->{form} } ) {
        my $name  = $fd->{name};
        my $value = $fd->{value};

        # Override value - Group list might have changed
        $value = $data->{AddToGroups} if ( $name eq 'AddToGroups' );

        if ( ( $name eq 'Password' ) && ($hidePassword) ) {
            $value = '*******';
        }
        if (    ( $name ne 'Confirm' )
            and ( $name ne 'LoginName' ) )
        {    #skip LoginName - we've put it on top.
            $before .= $b1 . ' ' . $name . ': ' . $value . "\n";
        }
    }
    $templateText = $before . ( $after || '' );
    $templateText =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gis;

    # remove <nop> and <noautolink> tags
    return $templateText;
}

# Throws an Oops exception if there is a problem.
sub _validateRegistration {
    my $this = shift;
    my ( $data, $requireForm ) = @_;

    my $app = $this->app;
    my $req = $app->request;

    # Set the registration timeout. If it's not configured
    # Use the session timeout, and if that's not configure
    # then default to 10 hours.
    my $exp =
      ( defined $Foswiki::cfg{Register}{ExpireAfter} )
      ? $Foswiki::cfg{Register}{ExpireAfter}
      : ( defined $Foswiki::cfg{Sessions}{ExpireAfter} )
      ? $Foswiki::cfg{Sessions}{ExpireAfter}
      : 36000;    # 10 hours

    # Expire stale registrations, but if email addresses are being
    # checked for duplicate registrations, then let that code
    # read all the pending registration files. Don't do it twice.
    # Also don't do it if ExpireAfter is negative.  Use tick_foswiki instead.
    unless ( $Foswiki::cfg{Register}{UniqueEmail} ) {
        if ( $exp > 1 ) {
            _checkPendingRegistrations( undef, $exp );
        }
    }

    unless ( defined( $data->{LoginName} ) && $data->{LoginName} ) {
        if ( $Foswiki::cfg{Register}{AllowLoginName} ) {

            # Login name is required, barf
            Foswiki::OopsException->throw(
                template => 'register',
                web      => $data->{webName},
                topic    => $req->topic,
                def      => 'miss_loginname',
                params   => ['undefined']
            );
        }
        else {
            $data->{LoginName} = $data->{WikiName};
        }
    }
    else {
        if (  !$Foswiki::cfg{Register}{AllowLoginName}
            && $data->{LoginName} ne $data->{WikiName} )
        {
            # Login name is not allowed, barf
            Foswiki::OopsException->throw(
                template => 'register',
                web      => $data->{webName},
                topic    => $req->topic,
                def      => 'unsupport_loginname',
                params   => [ $data->{LoginName} ]
            );
        }
    }

    # Check if login name matches expectations
    unless (
        $app->users->getLoginManager()->isValidLoginName( $data->{LoginName} ) )
    {
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $data->{webName},
            topic    => $app->topicName,
            def      => 'bad_loginname',
            params   => [ $data->{LoginName} ]
        );
    }

    # Check if the login name is already registered
    # luckily, we're only considering TopicUserMapping cfg's
    # there are several possible interpretations of 'already registered'
    # --- For setups with a PasswordManager...
    # on foswiki.org, (allowloginname=off) means that if the user has an
    #      entry in the htpasswd file, they are already registered.
    # onmost systems using (allowloginname=off) already registered could mean
    #      user topic exists, or, Main.UserList mapping exists
    # on any system using (allowloginname=on) already registered could mean
    #      user topic exists, or, Main.UserList mapping exists
    #NOTE: it is important that _any_ user can register any random third party
    #      this is not only how WikiGuest registers as someone else, but often
    #      how users pre-register others.
    my $users    = $app->users;
    my $user     = $users->getCanonicalUserID( $data->{LoginName} );
    my $wikiname = $users->getWikiName($user);

    if (
        $user
        &&

        #in the pwd system
        # OR already logged in (shortcircuit to reduce perf impact)
        # returns undef if passwordmgr=none
        ( ( $users->userExists($user) ) )
        &&

        # user has an entry in the mapping system
        # (if AllowLoginName == off, then entry is automatic)
        (
            ( !$Foswiki::cfg{Register}{AllowLoginName} )
            || $app->store->topicExists( $Foswiki::cfg{UsersWebName},
                $wikiname )    #mapping from new login exists
        )
      )
    {
        $app->logger->log( 'warning',
"Registration rejected:  LoginName $data->{LoginName} or WikiName $wikiname already known to Mapper"
        );
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $data->{webName},
            topic    => $req->topic,
            def      => 'already_exists',
            params   => [ $data->{LoginName} ]
        );
    }

    #new user's topic already exists
    if (
        $app->store->topicExists(
            $Foswiki::cfg{UsersWebName},
            $data->{WikiName}
        )
      )
    {
        $app->logger->log( 'warning',
"Registration rejected: Topic $Foswiki::cfg{UsersWebName}.$data->{WikiName}  already exists."
        );
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $data->{webName},
            topic    => $req->topic,
            def      => 'already_exists',
            params   => [ $data->{WikiName} ]
        );
    }

    # Check if WikiName is a WikiName
    if ( !Foswiki::isValidWikiWord( $data->{WikiName} ) ) {
        $app->logger->log( 'warning',
            "Registration rejected:  $data->{WikiName} is not a valid WikiWord."
        );
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $data->{webName},
            topic    => $req->topic,
            def      => 'bad_wikiname',
            params   => [ $data->{WikiName} ]
        );
    }

    if ( exists $data->{Password} ) {

        # check password length
        my $doCheckPasswordLength =
          (      $Foswiki::cfg{PasswordManager} ne 'none'
              && $Foswiki::cfg{MinPasswordLength} );

        if ( $doCheckPasswordLength
            && length( $data->{Password} ) < $Foswiki::cfg{MinPasswordLength} )
        {
            $app->logger->log( 'warning',
"Registration rejected for $data->{WikiName}: requested password is too short."
            );
            Foswiki::OopsException->throw(
                template => 'register',
                web      => $data->{webName},
                topic    => $req->topic,
                def      => 'bad_password',
                params   => [ $Foswiki::cfg{MinPasswordLength} ]
            );
        }

        # check if passwords are identical
        if (  !$Foswiki::cfg{Register}{DisablePasswordConfirmation}
            && $data->{Password} ne $data->{Confirm} )
        {
            $app->logger->log( 'warning',
"Registration rejected for $data->{WikiName}: passwords do not match."
            );
            Foswiki::OopsException->throw(
                template => 'register',
                web      => $data->{webName},
                topic    => $req->topic,
                def      => 'password_mismatch'
            );
        }
    }

    # check valid email address
    if ( !defined $data->{Email}
        || $data->{Email} !~ $Foswiki::regex{emailAddrRegex} )
    {
        $data->{Email} ||= '';
        $app->logger->log( 'warning',
"Registration rejected: $data->{Email} failed the system email regex check."
        );
        Foswiki::OopsException->throw(
            template => 'register',
            web      => $data->{webName},
            topic    => $req->topic,
            def      => 'bad_email',
            params   => [ $data->{Email} ]
        );
    }

    # Optional check email against filter
    # Case insensitive, and ignore whitespace.
    my $emailFilter;
    $emailFilter = qr/$Foswiki::cfg{Register}{EmailFilter}/ix
      if ( length( $Foswiki::cfg{Register}{EmailFilter} ) );
    if ( defined $emailFilter
        && $data->{Email} =~ $emailFilter )
    {
        $app->logger->log( 'warning',
"Registration rejected: $data->{Email} rejected by the {Register}{EmailFilter}."
        );
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'rej_email',
            web      => $data->{webName},
            topic    => $req->topic,
            params   => [ $data->{Email} ]
        );
    }

    # Optional check if email address is already registered
    if ( $Foswiki::cfg{Register}{UniqueEmail} ) {
        my @existingNames = Foswiki::Func::emailToWikiNames( $data->{Email} );
        if ( $Foswiki::cfg{Register}{NeedVerification} ) {
            my @pending = _checkPendingRegistrations( $data->{Email}, $exp );
            push @existingNames, @pending if scalar(@pending);
        }
        if ( scalar(@existingNames) ) {
            $app->logger->log( 'warning',
                "Registration rejected: $data->{Email} already registered by: "
                  . join( ', ', @existingNames ) );
            Foswiki::OopsException->throw(
                template => 'register',
                web      => $data->{webName},
                topic    => $req->topic,
                def      => 'dup_email',
                params   => [ $data->{Email} ]
            );
        }
    }

    if ( $data->{templatetopic} ) {

        # Validate and untaint
        $data->{templatetopic} =
          $this->_validateTemplateTopic( $data->{templatetopic} );
    }

    if ($requireForm) {

        # check if required fields are filled in
        unless ( $data->{form} && ( $#{ $data->{form} } > 1 ) ) {
            $app->logger->log( 'warning',
                'Registration rejected: The submitted form was empty' );
            Foswiki::OopsException->throw(
                template => 'attention',
                web      => $data->{webName},
                topic    => $req->topic,
                def      => 'missing_fields',
                params   => ['form']
            );
        }
        my @missing = ();
        foreach my $fd ( sort { $a->{name} cmp $b->{name} } @{ $data->{form} } )
        {
            if ( ( $fd->{required} ) && ( !$fd->{value} ) ) {
                push( @missing, $fd->{name} );
            }
        }

        if ( scalar(@missing) ) {
            $app->logger->log( 'warning',
                'Registration rejected: missing required fields: '
                  . join( ',', @missing ) );
            Foswiki::OopsException->throw(
                template => 'attention',
                web      => $data->{webName},
                topic    => $req->topic,
                def      => 'missing_fields',
                params   => [ join( ', ', @missing ) ]
            );
        }
    }

    try {

        # NOTE: calling the handler here allows the plugin to
        # modify the fields in a way that may not pass the
        # validation checks above. On the flip side, there will
        # be no further validation of the plugins' work, so it
        # better get it right!
        $app->plugins->dispatch( 'validateRegistrationHandler', $data );
    }
    catch {
        my $e = $_;
        Foswiki::OopsException->rethrowAs(
            $_,
            template => 'register',
            web      => $data->{webName},
            topic    => $req->topic,
            def      => 'registration_invalid',
            params   => [ $e->stringify ]
        );
    };
}

sub _validateTemplateTopic {
    my $this = shift;

    my $app = $this->app;
    my $req = $app->request;

    my ( $templateWeb, $templateTopic ) =
      Foswiki::Func::normalizeWebTopicName( $Foswiki::cfg{UserWebName},
        $_[0] || 'NewUserTemplate' );

    $templateTopic = Foswiki::Sandbox::untaint(
        $templateTopic,
        sub {
            my $template = shift;
            return $template if Foswiki::isValidTopicName($template);
            $app->logger->log( 'warning',
                'Registration rejected: invalid templatetopic requested: '
                  . $template );
            throw Foswiki::OopsException(
                'register',
                web   => $req->web,
                topic => $req->topic,
                def   => 'bad_templatetopic',
            );
        }
    );

    $templateWeb = Foswiki::Sandbox::untaint(
        $templateWeb,
        sub {
            my $web = shift;
            return $web if Foswiki::isValidWebName($web);
            $app->logger->log( 'warning',
'Registration rejected: invalid templatetopic webname requested: '
                  . $web );
            throw Foswiki::OopsException(
                'register',
                web   => $req->web,
                topic => $req->topic,
                def   => 'bad_templatetopic',
            );
        }
    );

    my $store = $app->store;

    if (   !$store->topicExists( $templateWeb, $templateTopic )
        && !$store->topicExists( $Foswiki::cfg{SystemWebName}, $templateTopic )
      )
    {
        $app->logger->log( 'warning',
            'Registration rejected: requested templatetopic does not exist: '
              . $templateWeb . "."
              . $templateTopic );
        throw Foswiki::OopsException(
            'register',
            uweb  => $Foswiki::cfg{UsersWebName},
            tmpl  => $templateTopic,
            web   => $req->web,
            topic => $req->topic,
            def   => 'bad_templatetopic',
        );
    }
    return "$templateWeb.$templateTopic";
}

# sends $p->{template} to $p->{Email} with substitutions from $data
sub _sendEmail {
    my $this = shift;
    my ( $template, $data ) = @_;

    my $app = $this->app;

    my $text = $app->templates->readTemplate($template);
    $data->{Introduction} ||= '';
    $data->{Name} ||= $data->{WikiName};
    my @unexpanded;
    foreach my $field ( keys %$data ) {
        my $f = uc($field);
        unless ( $text =~ s/\%$f\%/$data->{$field}/g ) {
            unless ( $field =~ m/^Password|form|webName/
                || !defined( $data->{$field} )
                || $data->{$field} !~ /\W/ )
            {
                push( @unexpanded, "$field: $data->{$field}" );
            }
        }
    }
    $text =~ s/%REGISTRATION_DATA%/join("\n", map {"\t* $_" } @unexpanded)/ge;

    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $Foswiki::cfg{UsersWebName},
        topic => $data->{WikiName}
    );
    $text = $topicObject->expandMacros($text);

    return $app->net->sendEmail($text);
}

sub _codeFile {
    my ($code) = @_;
    ASSERT($code) if DEBUG;
    Foswiki::Exception->throw( text => "bad code" )
      unless $code =~ m/^(\w+)\.(\d+)$/;
    return "$Foswiki::cfg{WorkingDir}/registration_approvals/$1.$2";
}

sub _codeWikiName {
    my ($code) = @_;
    ASSERT($code) if DEBUG;
    $code =~ s/\.\d+$//;
    return $code;
}

sub _clearPendingRegistrationsForUser {
    my $code = shift;
    my $file = _codeFile($code);

    # Remove the integer code to leave just the wikiname
    $file =~ s/\.\d+$//;
    foreach my $f (<$file.*>) {

        # Read from disc, implictly validated
        unlink( Foswiki::Sandbox::untaintUnchecked($f) );
    }
}

use vars qw( $data $form );

# Redirects user and dies if cannot load.
# Dies if loads and does not match.
# Returns the users data hash if succeeded.
# Returns () if not found.
# Assumptions: In error handling we assume that the verification code
#              starts with the wikiname under consideration, and that the
#              random code does not contain a '.'.
sub _loadPendingRegistration {
    my $this = shift;
    my ($code) = @_;

    my $app = $this->app;

    ASSERT($code) if DEBUG;

    my $file;
    try {
        $file = _codeFile($code);
    }
    catch {
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'bad_ver_code',
            params   => [ $code, 'Invalid code' ],
        );
    };

    unless ( -f $file ) {
        my $wikiName = _codeWikiName($code);
        my $users    = $app->users->findUserByWikiName($wikiName);
        if ( scalar( @{$users} )
            && $app->users->userExists( $users->[0] ) )
        {
            Foswiki::OopsException->throw(
                template => 'register',
                def      => 'duplicate_activation',
                params   => [$wikiName],
            );
        }
        Foswiki::OopsException->throw(
            template => 'register',
            def      => 'bad_ver_code',
            params   => [ $code, 'Code is not recognised' ],
        );
    }

    $data = undef;
    $form = undef;
    do $file;
    $data->{form} = $form if $form;
    Foswiki::OopsException->throw(
        template => 'register',
        def      => 'bad_ver_code',
        params   => [ $code, 'Bad activation code' ]
    ) if $!;

    return $data;
}

sub _getDataFromQuery {
    my $this = shift;

    my $app   = $this->app;
    my $req   = $app->request;
    my $users = $app->users;

    # get all parameters from the form
    my $data = {};
    foreach my $key ( $req->multi_param() ) {
        if ( $key =~ m/^((?:Twk|Fwk)([0-9])(.*))/
            and ( defined( $req->param($key) ) ) )
        {
   #next if ($key =~ m/LoginName$/ && !$Foswiki::cfg{Register}{AllowLoginName});
            my @values   = $req->multi_param($key);
            my $required = $2;
            my $name     = $3;

            # deal with multivalue fields like checkboxen
            my $value = join( ',', @values );

            try {
                $data->{$name} =
                  $users->validateRegistrationField( $name, $value );
            }
            catch {
                Foswiki::OopsException->throw(
                    template => 'register',
                    def      => 'invalid_field',
                    params   => [$name]
                );
            };
            push(
                @{ $data->{form} },
                {
                    required => $required,
                    name     => $name,
                    value    => $value,
                }
            );
        }
    }

    # This is validated later, okay to accept as is.
    if ( my $tmpl = $req->param('templatetopic') ) {
        $data->{templatetopic} = $tmpl;
    }

    if (   !$data->{Name}
        && defined $data->{FirstName}
        && defined $data->{LastName} )
    {
        $data->{Name} = $data->{FirstName} . ' ' . $data->{LastName};
    }
    return $data;
}

# We delete only the field in the {form} array - this leaves
# the original value still there should  we want it i.e. it must
# still be available via $row->{$key} even though $row-{form}[]
# does not contain it
sub _deleteKey {
    my ( $row, $key ) = @_;
    my @formArray = @{ $row->{form} };

    foreach my $index ( 0 .. $#formArray ) {
        my $a     = $formArray[$index];
        my $name  = $a->{name};
        my $value = $a->{value};
        if ( $name eq $key ) {
            splice( @{ $row->{form} }, $index, 1 );
            last;
        }
    }
}

# Check pending registrations for duplicate email, or expiration
sub _checkPendingRegistrations {
    my $check = shift;
    my $exp   = shift;

    my $time;
    if ( defined $exp && $exp > 1 ) {
        $time = time();
        $time = $time - $exp;
    }

    my $dir     = "$Foswiki::cfg{WorkingDir}/registration_approvals/";
    my @pending = ();

    if ( defined $time || $check ) {
        if ( opendir( my $d, "$dir" ) ) {
            foreach my $f ( grep { /^.*\.[0-9]{1,8}$/ } readdir $d ) {
                my $regFile = Foswiki::Sandbox::untaintUnchecked("$dir$f");

                if ( defined $time ) {
                    if ( ( stat($regFile) )[9] < $time ) {
                        unlink $regFile;
                        next;
                    }
                }
                if ($check) {
                    local $data;
                    local $form;
                    eval 'do $regFile';
                    next unless defined $data;
                    push @pending, $data->{WikiName} . '(pending)'
                      if ( $check eq $data->{Email} );
                }
            }
            closedir($d);
        }
    }
    return @pending;
}

=begin TML

---++ StaticMethod expirePendingRegistrations()

This routine expires registration files.  This is called by
tick_foswiki to expire stale registrations.

=cut

sub expirePendingRegistrations {
    my $exp =
      ( defined $Foswiki::cfg{Register}{ExpireAfter} )
      ? $Foswiki::cfg{Register}{ExpireAfter}
      : ( defined $Foswiki::cfg{Sessions}{ExpireAfter} )
      ? $Foswiki::cfg{Sessions}{ExpireAfter}
      : 36000;    # 10 hours

    $exp = -$exp if $exp < 0;
    _checkPendingRegistrations( undef, $exp );
}

=begin TML

---++ _processDeleteUser()

Removes the user from the installation.

=cut

sub _processDeleteUser {
    my $paramHash = shift;

    my $user = $paramHash->{cuid};

    # Obtain all the user info before removing things.   If there is no mapping
    # for the user, then assume the entered username will be removed.
    my $cUID     = Foswiki::Func::getCanonicalUserID($user);
    my $wikiname = ($cUID) ? Foswiki::Func::getWikiName($cUID) : $user;
    my $email    = join( ',', Foswiki::Func::wikinameToEmails($wikiname) );

    my ( $message, $logMessage ) =
      ( "Processing $wikiname($email)\n", "Processing $wikiname($email) " );

    if ( $cUID && $cUID =~ m/^BaseUserMapping_/ ) {
        $message    = "Cannot remove $user: $cUID \n";
        $logMessage = "Cannot remove $user: $cUID";
        return ( $message, $logMessage );
    }

    # Remove the user from the mapping manager
    if ( $cUID && $Foswiki::Plugins::SESSION->users->userExists($cUID) ) {
        $Foswiki::Plugins::SESSION->users->removeUser($cUID);
        $message    .= " - user removed from Mapping Manager \n";
        $logMessage .= "Mapping removed, ";
    }
    else {
        $message    .= " - User not known to the Mapping Manager \n";
        $logMessage .= "unknown to Mapping, ";
    }

    # Kill any user sessions by removing the session files
    my $uid = $cUID || $wikiname;
    my $uSess = Foswiki::LoginManager::removeUserSessions($uid);
    if ($uSess) {
        $message    .= " - removed $uSess \n";
        $logMessage .= "removed: $uSess, ";
    }

    # If a group topic has been entered, don't remove it.
    if ( Foswiki::Func::isGroup($wikiname) ) {
        $message    .= " Cannot remove group $wikiname \n";
        $logMessage .= "Cannot remove group $wikiname, ";
        return ( $message, $logMessage );
    }

    # Remove the user from any groups.
    my $it = Foswiki::Func::eachGroup();
    $logMessage .= "Removed from groups: ";
    while ( $it->hasNext() ) {
        my $group = $it->next();

        #$message .= "Checking $group for ($wikiname)\n";
        if (
            Foswiki::Func::isGroupMember( $group, $wikiname, { expand => 0 } ) )
        {
            $message    .= "user removed from $group \n";
            $logMessage .= "$group, ";
            Foswiki::Func::removeUserFromGroup( $wikiname, $group );
        }
    }

    if ( $paramHash->{removeTopic} ) {

        # Remove the users topic, moving it to trash web
        ( my $web, $wikiname ) =
          Foswiki::Func::normalizeWebTopicName( $Foswiki::cfg{UsersWebName},
            $wikiname );
        if ( Foswiki::Func::topicExists( $web, $wikiname ) ) {

            # Spoof the user so we can delete their topic. Don't need to
            # do this for the REST handler, but we do for the registration
            # abort.
            my $safe = $Foswiki::Plugins::SESSION->user;

            my $newTopic = "$paramHash->{prefix}$wikiname" . time;
            try {
                Foswiki::Func::moveTopic( $web, $wikiname,
                    $Foswiki::cfg{TrashWebName}, $newTopic );
                $message .=
" - user topic moved to $Foswiki::cfg{TrashWebName}.$newTopic \n";
                $logMessage .=
                  "User topic moved to $Foswiki::cfg{TrashWebName}.$newTopic, ";
            }
            finally {
                # Restore the original user
                $Foswiki::Plugins::SESSION->user($safe);
                if (@_) {
                    $_[0]->throw;
                }

            };
        }
        else {
            $message    .= " - user topic not found \n";
            $logMessage .= " User topic not found, ";
        }
    }
    else {
        $message    .= " - User topic not removed \n";
        $logMessage .= " User topic not removed, ";
    }
    return ( $message, $logMessage );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
(c) 1999-2007 TWiki Contributors
(c) 1999-2007 Peter Thoeny, peter@thoeny.com
(c) 2001 Kevin Atkinson, kevin twiki at atkinson dhs org
(c) 2003-2008 SvenDowideit, SvenDowideit@home.org.au
(c) 2003 Graeme Pyle graeme@raspberry dot co dot za
(c) 2004 Martin Cleaver, Martin.Cleaver@BCS.org.uk
(c) 2004 Gilles-Eric Descamps twiki at descamps.org
(c) 2004-2007 Crawford Currie c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
