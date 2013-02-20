# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Register

User registration handling.

=cut

package Foswiki::UI::Register;

use strict;
use warnings;
use Assert;
use Error qw( :try );

use Foswiki                ();
use Foswiki::OopsException ();
use Foswiki::Sandbox       ();
use Foswiki::UI            ();

# Keys from the user data that should *not* be included in
# the user topic.
my %SKIPKEYS = (
    'Photo'       => 1,
    'WikiName'    => 1,
    'LoginName'   => 1,
    'Password'    => 1,
    'Confirm'     => 1,
    'Email'       => 1,
    'AddToGroups' => 1
);
my @requiredFields = qw(WikiName FirstName LastName Email);

=begin TML

---++ StaticMethod register_cgi( $session )

=register= command handler.
This method is designed to be
invoked via the =UI::run= method.

=cut

sub register_cgi {
    my $session = shift;

    # absolute URL context for email generation
    $session->enterContext('absolute_urls');

    my $needApproval = 0;

    # Register -> Verify -> Approve -> Finish

    # NB. bulkRegister invoked from ManageCgiScript.

    my $query = $session->{request};
    my $action = $query->param('action') || '';

    if (   $action ne 'verify'
        && $query
        && $query->method()
        && uc( $query->method() ) ne 'POST' )
    {
        throw Foswiki::OopsException(
            'attention',
            web    => $session->{webName},
            topic  => $session->{topicName},
            def    => 'post_method_only',
            params => ['register']
        );
    }

    if ( $action eq 'register' ) {
        if ( !$session->inContext('registration_supported') ) {
            throw Foswiki::OopsException(
                'attention',
                web   => $session->{webName},
                topic => $session->{topicName},
                def   => 'registration_not_supported'
            );
        }
        if ( !$Foswiki::cfg{Register}{EnableNewUserRegistration} ) {
            throw Foswiki::OopsException(
                'attention',
                web   => $session->{webName},
                topic => $session->{topicName},
                def   => 'registration_disabled'
            );
        }
        Foswiki::UI::checkValidationKey($session);
        registerAndNext($session);
    }
    elsif ( $action eq 'verify' ) {
        verifyEmailAddress($session);
        if ($needApproval) {
            throw Error::Simple('Approval code has not been written!');
        }
        _complete($session);
    }
    elsif ( $action eq 'resetPassword' ) {

        if ( !$session->inContext("passwords_modifyable") ) {
            throw Foswiki::OopsException(
                'attention',
                web   => $session->{webName},
                topic => $session->{topicName},
                def   => 'passwords_disabled'
            );
        }

        # resetpasswd calls checkValidationKey - don't check it here
        require Foswiki::UI::Passwords;
        Foswiki::UI::Passwords::resetpasswd($session);
    }
    elsif ( $action eq 'approve' ) {
        _complete($session);
    }
    else {
        throw Foswiki::OopsException(
            'attention',
            web   => $session->{webName},
            topic => $session->{topicName},
            def   => 'unrecognized_action'
        );
    }

    $session->leaveContext('absolute_urls');

    # Output of register:
    #    UnsavedUser, accessible by username.$verificationCode

    # Output of reset password:
    #    unaffected user, accessible by username.$verificationCode

    # Output of verify:
    #    UnsavedUser, accessible by username.$approvalCode (only sent
    #    to administrator)

    # Output of approve:
    #    RegisteredUser, all related UnsavedUsers deleted
}

my $b1 = "\t* ";
my $b2 = "\t$b1";

=begin TML

---++ StaticMethod bulkRegister($session)

Called by ManageCgiScript::bulkRegister (requires authentication) with
topic = the page with the entries on it.

=cut

sub bulkRegister {
    my $session = shift;

    my $user    = $session->{user};
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $userweb = $Foswiki::cfg{UsersWebName};
    my $query   = $session->{request};

    # absolute URL context for email generation
    $session->enterContext('absolute_urls');

    my $settings = {};

    # This gets set from the value in the BulkRegistrations topic
    $settings->{doOverwriteTopics} = $query->param('OverwriteHomeTopics') || 0;

    unless ( $session->{users}->isAdmin($user) ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 403,
            def    => 'only_group',
            web    => $web,
            topic  => $topic,
            params => [ $Foswiki::cfg{SuperAdminGroup} ]
        );
    }

    # Validate
    Foswiki::UI::checkValidationKey($session);

    #-- Read the topic containing the table of people to be registered
    my $meta = Foswiki::Meta->load( $session, $web, $topic );

    my @fields;
    my @data;
    my $gotHdr = 0;
    foreach my $line ( split( /\r?\n/, $meta->text ) ) {

        # unchecked implicit untaint OK - this function is for admins only
        if ( $line =~ /^\s*\|\s*(.*?)\s*\|\s*$/ ) {
            if ($gotHdr) {
                my $i = 0;
                my %row = map { $fields[ $i++ ] => $_ } split( /\s*\|\s*/, $1 );
                push( @data, \%row );
            }
            else {
                foreach my $field ( split( /\s*\|\s*/, $1 ) ) {
                    $field =~ s/^[\s*]*(.*?)[\s*]*$/$1/;
                    push( @fields, $field );
                }
                $gotHdr = 1;
            }
        }
    }

    my $log = "---+ Report for Bulk Register\n";

    # TODO: should check that the header row actually contains the
    # required fields.
    # TODO: and consider using MAKETEXT to enable translated tables.

    #-- Process each row, generate a log as we go
    for ( my $n = 0 ; $n < scalar(@data) ; $n++ ) {
        my $row = $data[$n];

        $row->{webName} = $userweb;

        unless ( $row->{WikiName} ) {
            $log .= "---++ Failed to register user on row $n: no !WikiName\n";
            next;
        }
        $row->{LoginName} = $row->{WikiName} unless $row->{LoginName};

        $log .= _registerSingleBulkUser( $session, \@fields, $row, $settings );
    }

    $log .= "----\n";

    my $logWeb;
    my $logTopic = Foswiki::Sandbox::untaint( $query->param('LogTopic'),
        \&Foswiki::Sandbox::validateTopicName )
      || $topic . 'Result';
    ( $logWeb, $logTopic ) = $session->normalizeWebTopicName( '', $logTopic );

    #-- Save the LogFile as designated, link back to the source topic
    $meta = Foswiki::Meta->new( $session, $logWeb, $logTopic, $log );
    unless ( $meta->haveAccess('CHANGE') ) {
        throw Foswiki::AccessControlException( 'CHANGE', $session->{user},
            $logWeb, $logTopic, $Foswiki::Meta::reason );
    }
    $meta->put( 'TOPICPARENT', { name => $web . '.' . $topic } );
    $meta->save();

    $session->leaveContext('absolute_urls');

    my $nurl = $session->getScriptUrl( 1, 'view', $web, $logTopic );
    $session->redirect($nurl);
}

# Register a single user during a bulk registration process
sub _registerSingleBulkUser {
    my ( $session, $fieldNames, $row, $settings ) = @_;
    ASSERT($row) if DEBUG;

    my $doOverwriteTopics = defined $settings->{doOverwriteTopics}
      || throw Error::Simple('No doOverwriteTopics');

    my $log = "---++ Registering $row->{WikiName}\n";

    #-- call to the registrationHandler (to amend fields) should
    # really happen in here.

    #-- Ensure every required field exists
    # NB. LoginName is OPTIONAL
    if ( _missingElements( $fieldNames, \@requiredFields ) ) {
        $log .=
            $b1
          . join( ' ', map { $_ . ' : ' . $row->{$_} } @$fieldNames )
          . ' does not contain the full set of required fields '
          . join( ' ', @requiredFields ) . "\n";
        return ( undef, $log );
    }

    try {

  #SMELL: Field Validations
  # foreach my $field ( %$row ) {
  #  - validate with Users::validateRegistrationField( $field, $row->{$field} );
  #  - catch any errors to log
  # Note, do this HERE and not in _validateRegistration.
  # CGI registration validates earlier in _getDataFromQuery()

        _validateRegistration( $session, $row, 0 );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $log .= '<blockquote>' . $e->stringify($session) . "</blockquote>\n";
        return $log . "$b1 Registration failed\n";
    };

    #-- Generation of the page is done from the {form} subhash,
    # so align the two
    $row->{form} = _makeFormFieldOrderMatch( $fieldNames, $row );

    my $users = $session->{users};

    try {

        # Add the user to the user management system. May throw an exception
        my $cUID = $users->addUser(
            $row->{LoginName},
            $row->{WikiName},
            $session->inContext("passwords_modifyable")
            ? $row->{Password}
            : undef,
            $row->{Email}
        );
        $log .=
"$b1 $row->{WikiName} has been added to the password and user mapping managers\n";

        if ( $settings->{doOverwriteTopics}
            || !$session->topicExists( $row->{webName}, $row->{WikiName} ) )
        {
            $log .= _createUserTopic( $session, $row );
        }
        else {
            $log .= "$b1 Not writing user topic $row->{WikiName}\n";
        }
        $users->setEmails( $cUID, $row->{Email} );

        $session->logEvent( 'bulkregister',
            $row->{webName} . '.' . $row->{WikiName},
            $row->{Email}, $row->{WikiName} );
    }
    catch Error::Simple with {
        my $e = shift;
        $log .= "$b1 Failed to add user: " . $e->stringify() . "\n";
    };

    #if ($Foswiki::cfg{EmailUserDetails}) {
    # If you want it, write it.
    # sendEmail($session, 'registernotifybulk', $data );
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

=begin TML

---++ StaticMethod registerAndNext($session)

This is called when action = register. It either completes the registration,
or redirects to verification, depending on the configuration.

=cut

sub registerAndNext {
    my ($session) = @_;
    _innerRegister($session);
    if ( $Foswiki::cfg{Register}{NeedVerification} ) {
        _requireVerification($session);
    }
    else {
        _complete($session);
    }
}

# Get registration data from the CGI query and validate it
sub _innerRegister {
    my ($session) = @_;

    my $query = $session->{request};
    my $data = _getDataFromQuery( $session->{users}, $query, $query->param() );

    $data->{webName} = $session->{webName};

    my $oldName = $data->{WikiName};
    $data->{WikiName} =
      Foswiki::Sandbox::untaint( $data->{WikiName},
        \&Foswiki::Sandbox::validateTopicName );
    unless ( $data->{WikiName} ) {
        $session->logger->log( 'warning',
            "Registration rejected: validateTopicName failed for $oldName" );
        throw Foswiki::OopsException(
            'attention',
            def    => 'bad_wikiname',
            web    => $data->{webName},
            topic  => $session->{topicName},
            params => [$oldName]
        );
    }

    _validateRegistration( $session, $data, 1 );
}

# Generate a registration record, and mail the registrant with the code.
# Redirects the browser to the confirmation screen.
sub _requireVerification {
    my ($session) = @_;

    my $query = $session->{request};
    my $topic = $session->{topicName};
    my $web   = $session->{webName};

    my $data = _getDataFromQuery( $session->{users}, $query, $query->param() );
    my $oldName = $data->{WikiName};
    $data->{WikiName} =
      Foswiki::Sandbox::untaint( $data->{WikiName},
        \&Foswiki::Sandbox::validateTopicName );
    unless ( $data->{WikiName} ) {
        $session->logger->log( 'warning',
            "Verification rejected: validateTopicName failed for $oldName" );
        throw Foswiki::OopsException(
            'attention',
            def    => 'bad_wikiname',
            web    => $data->{webName},
            topic  => $session->{topicName},
            params => [$oldName]
        );
    }
    $data->{LoginName} ||= $data->{WikiName};
    $data->{webName} = $web;

    $data->{VerificationCode} = $data->{WikiName} . '.' . int( rand(99999999) );

    #SMELL: used for Register unit tests
    $session->{DebugVerificationCode} = $data->{VerificationCode};

    require Data::Dumper;

    my $file = _codeFile( $data->{VerificationCode} );
    my $F;
    open( $F, '>', $file )
      or throw Error::Simple( 'Failed to open file: ' . $! );
    print $F '# Verification code', "\n";

    # SMELL: wierd jiggery-pokery required, otherwise Data::Dumper screws
    # up the form fields when it saves. Perl bug? Probably to do with
    # chucking around arrays, instead of references to them.
    my $form = $data->{form};
    $data->{form} = undef;
    print $F Data::Dumper->Dump( [ $data, $form ], [ 'data', 'form' ] );
    $data->{form} = $form;
    close($F);

    $session->logEvent( 'regstart',
        $Foswiki::cfg{UsersWebName} . '.' . $data->{WikiName},
        $data->{Email}, $data->{WikiName} );

    my $em = $data->{Email};

    if ( $Foswiki::cfg{EnableEmail} ) {
        my $err = sendEmail( $session, 'registerconfirm', $data );

        if ($err) {
            $session->logger->log( 'warning',
"Registration rejected: registration_mail_failed - Email: $em, Error $err"
            );
            throw Foswiki::OopsException(
                'attention',
                def    => 'registration_mail_failed',
                web    => $data->{webName},
                topic  => $topic,
                params => [ $em, $err ]
            );
        }
    }
    else {
        my $err = $session->i18n->maketext(
            'Email has been disabled for this Foswiki installation');

        throw Foswiki::OopsException(
            'attention',
            def    => 'send_mail_error',
            web    => $data->{webName},
            topic  => $topic,
            params => [ $em, $err ]
        );
    }

    throw Foswiki::OopsException(
        'attention',
        status => 200,
        def    => 'confirm',
        web    => $data->{webName},
        topic  => $topic,
        params => [$em]
    );
}

=begin TML

---++ StaticMethod verifyEmailAddress($session)

This is invoked on receipt of the activation password. It reloads a
pending registration, and verifies the email address in it.

=cut

sub verifyEmailAddress {
    my ($session) = @_;

    my $code = $session->{request}->param('code');
    unless ($code) {
        throw Error::Simple('verifyEmailAddress: no verification code!');
    }
    my $data = _loadPendingRegistration( $session, $code );

    if ( !exists $data->{Email} ) {
        throw Error::Simple('verifyEmailAddress: no email address!');
    }
}

=begin TML

---++ StaticMethod deleteUser($session)
CGI function that deletes the current user
Renames the *current* user's topic (with renaming all links) and
removes user entry from passwords.

=cut

sub deleteUser {
    my $session = shift;

    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $query   = $session->{request};
    my $cUID    = $session->{user};

    my $password = $query->param('password');

    # check if user entry exists
    my $users = $session->{users};
    if ( !$users->userExists($cUID) ) {
        throw Foswiki::OopsException(
            'attention',
            web    => $webName,
            topic  => $topic,
            def    => 'not_a_user',
            params => [ $session->{users}->getWikiName($cUID) ]
        );
    }

    #check to see it the user we are trying to remove is a member of a group.
    #initially we refuse to delete the user
    #in a later implementation we will remove the from the group
    #(if Access.pm implements it..)
    my $git = $users->eachMembership($cUID);
    if ( $git->hasNext() ) {
        my $list = '';
        while ( $git->hasNext() ) {
            $list .= ' ' . $git->next();
        }
        throw Foswiki::OopsException(
            'attention',
            web    => $webName,
            topic  => $topic,
            def    => 'in_a_group',
            params => [ $session->{users}->getWikiName($cUID), $list ]
        );
    }

    # Check the validation key
    Foswiki::UI::checkValidationKey($session);

    unless (
        $users->checkPassword(
            $session->{users}->getLoginName($cUID), $password
        )
      )
    {
        throw Foswiki::OopsException(
            'attention',
            web   => $webName,
            topic => $topic,
            def   => 'wrong_password'
        );
    }

    $users->removeUser($cUID);

    throw Foswiki::OopsException(
        'attention',
        status => 200,
        def    => 'remove_user_done',
        web    => $webName,
        topic  => $topic,
        params => [ $users->getWikiName($cUID) ]
    );
}

=begin TML

---++ StaticMethod addUserToGroup($session)
adds users to a group
   * groupname parameter must a a single groupname (group does not
     have to exist)
   * username can be a single login/wikiname/(!cuid?), a URLParam
     list, or a comma separated list.

=cut

sub addUserToGroup {
    my $session = shift;
    my $query   = $session->{request};
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $user    = $session->{user};

    my @userNames = $query->param('username');

    my $groupName = $query->param('groupname');
    my $create = Foswiki::isTrue( $query->param('create'), 0 );
    if ( !$groupName or $groupName eq '' ) {
        my $userNames = scalar @userNames ? join( ',', @userNames ) : '';
        throw Foswiki::OopsException(
            'attention',
            def    => 'no_group_specified_for_add_to_group',
            web    => $web,
            topic  => $topic,
            params => [$userNames]
        );
    }

    Foswiki::UI::checkValidationKey($session);

    if (   ( $#userNames < 0 )
        or ( $userNames[0] eq '' ) )
    {

   # if $create is set, and there are no users in the list, and the group exists
   # then we're trying to upgrade the user topic.
   # I'm not sure what other mappers might make of this..
        if ( $create and Foswiki::Func::isGroup($groupName) ) {
            try {
                $session->{users}->addUserToGroup( undef, $groupName, $create );
            }
            catch Error::Simple with {
                my $e = shift;

                # Log the error
                $session->logger->log( 'warning',
                    "catch: Failed to upgrade $groupName " . $e->stringify() );
            };

            throw Foswiki::OopsException(
                'attention',
                status => 200,
                def    => 'group_upgraded',
                web    => $web,
                topic  => $topic,
                params => [$groupName]
            );
        }
    }

    if (   !Foswiki::Func::isGroup($groupName)
        && !$create )
    {
        throw Foswiki::OopsException(
            'attention',
            def   => 'no_group_and_no_create',
            web   => $web,
            topic => $topic,
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
        and !$session->{users}->isAdmin($user)
        and $create )
    {
        unshift( @userNames, $session->{users}->getLoginName($user) );
    }

    my @failed;
    my @succeeded;
    push @userNames, '<none>' if ( scalar @userNames == 0 );
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
            $u = $session->{users}->validateRegistrationField( 'username', $u );
            $session->{users}->addUserToGroup( $u, $groupName, $create );
            push( @succeeded, $u );
        }
        catch Error::Simple with {
            my $e    = shift;
            my $mess = $e->stringify();
            $mess =~ s/ at .*$//s;

            push( @failed, "$u : $mess" );

            # Log the error
            $session->logger->log( 'warning', $e->stringify() );
        };
    }
    if ( @failed || !@succeeded ) {
        $session->logger->log( 'warning',
            "failed: " . scalar @failed . " Succeeded " . scalar @succeeded );
        throw Foswiki::OopsException(
            'attention',
            web    => $web,
            topic  => $topic,
            def    => 'problem_adding_to_group',
            params => [ join( ', ', @failed ), $groupName ]
        );
    }

    my $url = $session->redirectto();
    unless ($url) {
        throw Foswiki::OopsException(
            'attention',
            status => 200,
            def    => 'added_users_to_group',
            web    => $web,
            topic  => $topic,
            params => [ join( ', ', @succeeded ), $groupName ]
        );
    }
    else {
        $session->redirect($url);
    }
}

=begin TML

---++ StaticMethod removeUserFromGroup($session)
Removes users from a group
   * groupname parameter must a a single groupname (group does not have
     to exist)
   * username can be a single login/wikiname/(cuid?), a URLParam list,
     or a comma separated list.

=cut

sub removeUserFromGroup {
    my $session = shift;
    my $query   = $session->{request};
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $user    = $session->{user};

    my @userNames = $query->param('username');
    my $groupName = $query->param('groupname');
    if (   ( $#userNames < 0 )
        or ( $userNames[0] eq '' ) )
    {
        throw Foswiki::OopsException( 'attention',
            def => 'no_users_to_remove_from_group' );
    }
    if ( $#userNames == 0 ) {
        @userNames = split( /,\s+/, $userNames[0] );
    }
    if ( !$groupName or $groupName eq '' ) {
        throw Foswiki::OopsException( 'attention',
            def => 'no_group_specified_for_remove_from_group' );
    }
    unless ( Foswiki::Func::isGroup($groupName) ) {
        throw Foswiki::OopsException( 'attention',
            def => 'problem_removing_from_group' );
    }

    # Validate
    Foswiki::UI::checkValidationKey($session);

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
        catch Error::Simple with {
            my $e    = shift;
            my $mess = $e->stringify();
            $mess =~ s/ at .*$//s;

            push( @failed, "$u: $mess" );

            # Log the error
            $session->logger->log( 'warning', $e->stringify() );
        };
    }
    if (@failed) {
        throw Foswiki::OopsException(
            'attention',
            web    => $web,
            topic  => $topic,
            def    => 'problem_removing_from_group',
            params => [ join( ', ', @failed ), $groupName ]
        );
    }

    my $url = $session->redirectto();
    unless ($url) {
        throw Foswiki::OopsException(
            'attention',
            status => 200,
            def    => 'removed_users_from_group',
            web    => $web,
            topic  => $topic,
            params => [ join( ', ', @succeeded ), $groupName ]
        );
    }
    else {
        $session->redirect($url);
    }
}

# Complete a registration (commit it to the DB)
sub _complete {
    my ($session) = @_;

    my $topic = $session->{topicName};
    my $web   = $session->{webName};
    my $query = $session->{request};
    my $code  = $query->param('code');

    my $data;
    if ( $Foswiki::cfg{Register}{NeedVerification} ) {
        $data = _loadPendingRegistration( $session, $code );
        _clearPendingRegistrationsForUser($code);
    }
    else {
        $data = _getDataFromQuery( $session->{users}, $query, $query->param() );
        $data->{webName} = $web;
    }

    $data->{WikiName} =
      Foswiki::Sandbox::untaint( $data->{WikiName},
        \&Foswiki::Sandbox::validateTopicName );
    throw Error::Simple('Bad WikiName') unless $data->{WikiName};

    if ( !exists $data->{LoginName} ) {
        if ( $Foswiki::cfg{Register}{AllowLoginName} ) {

            # This should have been populated
            throw Error::Simple('no LoginName after reload');
        }
        $data->{LoginName} ||= $data->{WikiName};
    }

    my $users = $session->{users};
    try {
        unless ( !$session->inContext("passwords_modifyable")
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
            $session->inContext("passwords_modifyable")
            ? $data->{Password}
            : undef,
            $data->{Email}
        );
        my $log = _createUserTopic( $session, $data );
        $users->setEmails( $cUID, $data->{Email} );

        # convert to rego agent user copied from
        # _writeRegistrationDetailsToTopic
        my $safe             = $session->{user};
        my $regoAgent        = $session->{user};
        my $enableAddToGroup = 1;

        if ( Foswiki::Func::isGuest($regoAgent) ) {
            $session->{user} =
              $session->{users}->getCanonicalUserID(
                $Foswiki::cfg{Register}{RegistrationAgentWikiName} );
            $regoAgent = $session->{user};

            # SECURITY ISSUE:
            # When upgrading an existing Wiki, the RegistrationUser is
            # in the AdminGroup. Thus newly registering users would be
            # able to join the AdminGroup. So disable the
            # AddUserToGroupOnRegistration if the agent is still admin :(
            $enableAddToGroup = !$session->{users}->isAdmin($regoAgent);
            if ( !$enableAddToGroup ) {

                # TODO: should really tell the user too?
                $session->logger->log( 'warning',
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
                $session->{user} = $regoAgent;
                try {
                    $users->addUserToGroup( $cUID, $groupName );
                    push @addedTo, $groupName;
                }
                catch Error::Simple with {
                    my $e = shift;
                    $session->logger->log( 'warning',
                        "Registration: Failure adding $cUID to $groupName" );
                }
                finally {
                    $session->{user} = $safe;
                };
            }
        }

        $data->{AddToGroups} = join( ',', @addedTo );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $users->removeUser( $data->{LoginName}, $data->{WikiName} )
          if ( $users->userExists( $data->{WikiName} ) );
        $e->throw();

        #throw Foswiki::OopsException ( @_ ); # Propagate
    }
    catch Error::Simple with {
        my $e = shift;

        $users->removeUser( $data->{LoginName}, $data->{WikiName} )
          if ( $users->userExists( $data->{WikiName} ) );

        # Log the error
        $session->logger->log( 'warning',
            'Registration failed: ' . $e->stringify() );
        throw Foswiki::OopsException(
            'attention',
            web    => $data->{webName},
            topic  => $topic,
            def    => 'problem_adding',
            params => [ $data->{WikiName}, $e->stringify() ]
        );
    };

    # Plugin to do some other post processing of the user.
    # for legacy, (callback to set cookies - now should use LoginHandler)
    $session->{plugins}
      ->dispatch( 'registrationHandler', $session->{webName}, $data->{WikiName},
        $data->{LoginName}, $data );

    my $status;
    my $safe2login = 1;

    if ( $Foswiki::cfg{EnableEmail} ) {

        # inform user and admin about the registration.
        $status = _emailRegistrationConfirmations( $session, $data );

        $session->logEvent( 'register',
            $Foswiki::cfg{UsersWebName} . '.' . $data->{WikiName},
            $data->{Email}, $data->{WikiName} );

        if ($status) {
            $status = $session->i18n->maketext(
                'Warning: Could not send confirmation email')
              . "\n\n$status";
            $safe2login = 0;
        }
        else {
            $status = $session->i18n->maketext(
                'A confirmation e-mail has been sent to [_1]',
                $data->{Email} );
        }
    }
    else {
        $status = $session->i18n->maketext(
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
      $session->{users}->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );
    my $regUID =
      $session->{users}->getCanonicalUserID(
        $Foswiki::cfg{Register}{RegistrationAgentWikiName} );
    if (
        $safe2login
        && (   $session->{user} eq $guestUID
            || $session->{user} eq $regUID
            && !$session->{users}->isAdmin($regUID) )
      )
    {

        # let the client session know that we're logged in. (This probably
        # eliminates the need for the registrationHandler call above,
        # but we'll leave them both in here for now.)
        $users->{loginManager}
          ->userLoggedIn( $data->{LoginName}, $data->{WikiName} );
    }

    # and finally display thank you page
    throw Foswiki::OopsException(
        'attention',
        status => 200,
        web    => $Foswiki::cfg{UsersWebName},
        topic  => $data->{WikiName},
        def    => 'thanks',
        params => [ $status, $data->{WikiName} ]
    );
}

# Given a template and a hash, creates a new topic for a user
sub _createUserTopic {
    my ( $session, $row ) = @_;
    my $template = 'NewUserTemplate';
    my $fromWeb  = $Foswiki::cfg{UsersWebName};

    if ( !$session->topicExists( $fromWeb, $template ) ) {

        # Use the default version
        $fromWeb = $Foswiki::cfg{SystemWebName};
    }
    my $tobj = Foswiki::Meta->load( $session, $fromWeb, $template );

    my $log =
        $b1
      . ' Writing topic '
      . $Foswiki::cfg{UsersWebName} . '.'
      . $row->{WikiName} . "\n"
      . "$b1 !RegistrationHandler:\n"
      . _writeRegistrationDetailsToTopic( $session, $row, $tobj );
    return $log;
}

# Writes the registration details passed as a hash to either BulletFields
# or FormFields on the user's topic.
#
sub _writeRegistrationDetailsToTopic {
    my ( $session, $data, $templateTopicObject ) = @_;

    ASSERT( $data->{WikiName} ) if DEBUG;

    my ( $before, $repeat, $after );
    ( $before, $repeat, $after ) =
      split( /%SPLIT%/, $templateTopicObject->text() || '', 3 )
      if $templateTopicObject;
    $before = '' unless defined($before);
    $after  = '' unless defined($after);

    my $user = $data->{WikiName};

    my $topicObject =
      Foswiki::Meta->new( $session, $Foswiki::cfg{UsersWebName}, $user );
    my $log;
    my $addText;

    $topicObject->copyFrom($templateTopicObject);

    my $form = $templateTopicObject->get('FORM');
    if ($form) {
        ( $topicObject, $addText ) =
          _populateUserTopicForm( $session, $form->{name}, $topicObject,
            $data );
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
    my $safe = $session->{user};
    $session->{user} = $user;
    try {
        $topicObject->text($text);
        $topicObject->expandNewTopic();
        my $agent = $Foswiki::cfg{Register}{RegistrationAgentWikiName};
        $session->{user} = $session->{users}->getCanonicalUserID($agent);
        $topicObject->put( 'TOPICPARENT',
            { name => $Foswiki::cfg{UsersTopicName} } );

        unless ( $topicObject->haveAccess('CHANGE') ) {
            throw Foswiki::AccessControlException( 'CHANGE', $agent,
                $topicObject->web, $topicObject->topic,
                $Foswiki::Meta::reason );
        }
        $topicObject->save();
    }
    finally {
        $session->{user} = $safe;
    };
    return $log;
}

# Puts form fields into the topic form
sub _populateUserTopicForm {
    my ( $session, $formName, $meta, $data ) = @_;

    my %inform;
    require Foswiki::Form;

    my $form =
      new Foswiki::Form( $session, $Foswiki::cfg{UsersWebName}, $formName );

    return ( $meta, '' ) unless $form;

    foreach my $field ( @{ $form->getFields() } ) {
        foreach my $fd ( @{ $data->{form} } ) {
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
    foreach my $fd ( @{ $data->{form} } ) {
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
    foreach my $fd ( @{ $data->{form} } ) {
        next if $SKIPKEYS{ $fd->{name} };
        my $title = $fd->{name};
        $title =~ s/([a-z0-9])([A-Z0-9])/$1 $2/go;    # Spaced
        my $value = $fd->{value};
        $value =~ s/[\n\r]//go;
        $text .= "   * $title\: $value\n";
    }
    return $text;
}

# Sends to both the WIKIWEBMASTER and the USER notice of the registration
# emails both the admin 'registernotifyadmin' and the user 'registernotify',
# in separate emails so they both get targeted information (and no
# password to the admin).
sub _emailRegistrationConfirmations {
    my ( $session, $data ) = @_;

    my $template = $session->templates->readTemplate('registernotify');
    my $email =
      _buildConfirmationEmail( $session, $data, $template,
        $Foswiki::cfg{Register}{HidePasswd} );

    my $warnings = $session->net->sendEmail($email);

    if ($warnings) {

        # Email address doesn't work, likely fraudulent registration
        try {
            my $users = $session->{users};
            my $cUID  = $users->getCanonicalUserID( $data->{LoginName} );

            $template =
              $session->templates->readTemplate('registerfailednotremoved');
        }
        catch Error::Simple with {

            # Most Mapping Managers don't support removeUser, unfortunately
            $template =
              $session->templates->readTemplate('registerfailednotremoved');
        };
    }
    else {
        $template = $session->templates->readTemplate('registernotifyadmin');
    }

    $email = _buildConfirmationEmail( $session, $data, $template, 1 );

    my $err = $session->net->sendEmail($email);
    if ($err) {

        # don't tell the user about this one
        $session->logger->log( 'warning',
            'Could not confirm registration: ' . $err );
    }

    return $warnings;
}

#The template dictates the to: field
sub _buildConfirmationEmail {
    my ( $session, $data, $templateText, $hidePassword ) = @_;

    $data->{Name} ||= $data->{WikiName};
    $data->{LoginName} = '' unless defined $data->{LoginName};

    $templateText =~ s/%FIRSTLASTNAME%/$data->{Name}/go;
    $templateText =~ s/%WIKINAME%/$data->{WikiName}/go;
    $templateText =~ s/%EMAILADDRESS%/$data->{Email}/go;

    my $topicObject = Foswiki::Meta->new( $session, $Foswiki::cfg{UsersWebName},
        $data->{WikiName} );
    $templateText = $topicObject->expandMacros($templateText);

    #add LoginName to make it clear to new users
    my $loginName = $b1 . ' LoginName: ' . $data->{LoginName} . "\n";

    # SMELL: this means we fail hard if there are 2 FORMDATA vars -
    #       like in multi-part mime - txt & html
    my ( $before, $after ) = split( /%FORMDATA%/, $templateText );
    $before .= $loginName;
    foreach my $fd ( @{ $data->{form} } ) {
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
    $templateText =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

    # remove <nop> and <noautolink> tags

    return $templateText;
}

# Throws an Oops exception if there is a problem.
sub _validateRegistration {
    my ( $session, $data, $requireForm ) = @_;

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

    if ( !defined( $data->{LoginName} ) ) {
        if ( $Foswiki::cfg{Register}{AllowLoginName} ) {

            # Login name is required, barf
            throw Foswiki::OopsException(
                'attention',
                web    => $data->{webName},
                topic  => $session->{topicName},
                def    => 'bad_loginname',
                params => ['undefined']
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
            throw Foswiki::OopsException(
                'attention',
                web    => $data->{webName},
                topic  => $session->{topicName},
                def    => 'bad_loginname',
                params => ['not allowed']
            );
        }
    }

    # Check if login name matches expectations
    unless ( $session->{users}->getLoginManager()
        ->isValidLoginName( $data->{LoginName} ) )
    {
        throw Foswiki::OopsException(
            'attention',
            web    => $data->{webName},
            topic  => $session->{topicName},
            def    => 'bad_loginname',
            params => [ $data->{LoginName} ]
        );
    }

    # Check if the login name is already registered
    # luckily, we're only considering TopicUserMapping cfg's
    # there are several possible interpretations of 'already registered'
    # --- For setups with a PasswordManager...
    # on twiki.org, (allowloginname=off) means that if the user has an
    #      entry in the htpasswd file, they are already registered.
    # onmost systems using (allowloginname=off) already registered could mean
    #      user topic exists, or, Main.UserList mapping exists
    # on any system using (allowloginname=on) already registered could mean
    #      user topic exists, or, Main.UserList mapping exists
    #NOTE: it is important that _any_ user can register any random third party
    #      this is not only how WikiGuest registers as someone else, but often
    #      how users pre-register others.
    my $users    = $session->{users};
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
            || $session->topicExists( $Foswiki::cfg{UsersWebName},
                $wikiname )    #mapping from new login exists
        )
      )
    {
        $session->logger->log( 'warning',
"Registration rejected:  LoginName $data->{LoginName} or WikiName $wikiname already known to Mapper"
        );
        throw Foswiki::OopsException(
            'attention',
            web    => $data->{webName},
            topic  => $session->{topicName},
            def    => 'already_exists',
            params => [ $data->{LoginName} ]
        );
    }

    #new user's topic already exists
    if ( $session->topicExists( $Foswiki::cfg{UsersWebName}, $data->{WikiName} )
      )
    {
        $session->logger->log( 'warning',
"Registration rejected: Topic $Foswiki::cfg{UsersWebName}.$data->{WikiName}  already exists."
        );
        throw Foswiki::OopsException(
            'attention',
            web    => $data->{webName},
            topic  => $session->{topicName},
            def    => 'already_exists',
            params => [ $data->{WikiName} ]
        );
    }

    # Check if WikiName is a WikiName
    if ( !Foswiki::isValidWikiWord( $data->{WikiName} ) ) {
        $session->logger->log( 'warning',
            "Registration rejected:  $data->{WikiName} is not a valid WikiWord."
        );
        throw Foswiki::OopsException(
            'attention',
            web    => $data->{webName},
            topic  => $session->{topicName},
            def    => 'bad_wikiname',
            params => [ $data->{WikiName} ]
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
            $session->logger->log( 'warning',
"Registration rejected for $data->{WikiName}: requested password is too short."
            );
            throw Foswiki::OopsException(
                'attention',
                web    => $data->{webName},
                topic  => $session->{topicName},
                def    => 'bad_password',
                params => [ $Foswiki::cfg{MinPasswordLength} ]
            );
        }

        # check if passwords are identical
        if (  !$Foswiki::cfg{Register}{DisablePasswordConfirmation}
            && $data->{Password} ne $data->{Confirm} )
        {
            $session->logger->log( 'warning',
"Registration rejected for $data->{WikiName}: passwords do not match."
            );
            throw Foswiki::OopsException(
                'attention',
                web   => $data->{webName},
                topic => $session->{topicName},
                def   => 'password_mismatch'
            );
        }
    }

    # check valid email address
    if ( $data->{Email} !~ $Foswiki::regex{emailAddrRegex} ) {
        $session->logger->log( 'warning',
"Registration rejected: $data->{Email} failed the system email regex check."
        );
        throw Foswiki::OopsException(
            'attention',
            web    => $data->{webName},
            topic  => $session->{topicName},
            def    => 'bad_email',
            params => [ $data->{Email} ]
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
        $session->logger->log( 'warning',
"Registration rejected: $data->{Email} rejected by the {Register}{EmailFilter}."
        );
        throw Foswiki::OopsException(
            'attention',
            def    => 'rej_email',
            web    => $data->{webName},
            topic  => $session->{topicName},
            params => [ $data->{Email} ]
        );
    }

    # Optional check if email address is already registered
    if ( $Foswiki::cfg{Register}{UniqueEmail} ) {
        my @existingNames = Foswiki::Func::emailToWikiNames( $data->{Email} );
        if ( $Foswiki::cfg{Register}{NeedVerification} ) {
            my @pending = _checkPendingRegistrations( $data->{Email}, $exp );
            push @existingNames, @pending if scalar @pending;
        }
        if ( scalar(@existingNames) ) {
            $session->logger->log( 'warning',
                "Registration rejected: $data->{Email} already registered by: "
                  . join( ', ', @existingNames ) );
            throw Foswiki::OopsException(
                'attention',
                web    => $data->{webName},
                topic  => $session->{topicName},
                def    => 'dup_email',
                params => [ $data->{Email} ]
            );
        }
    }

    return unless $requireForm;

    # check if required fields are filled in
    unless ( $data->{form} && ( $#{ $data->{form} } > 1 ) ) {
        $session->logger->log( 'warning',
            'Registration rejected: The submitted form was empty' );
        throw Foswiki::OopsException(
            'attention',
            web    => $data->{webName},
            topic  => $session->{topicName},
            def    => 'missing_fields',
            params => ['form']
        );
    }
    my @missing = ();
    foreach my $fd ( @{ $data->{form} } ) {
        if ( ( $fd->{required} ) && ( !$fd->{value} ) ) {
            push( @missing, $fd->{name} );
        }
    }

    if ( scalar(@missing) ) {
        $session->logger->log( 'warning',
            'Registration rejected: missing required fields: '
              . join( ',', @missing ) );
        throw Foswiki::OopsException(
            'attention',
            web    => $data->{webName},
            topic  => $session->{topicName},
            def    => 'missing_fields',
            params => [ join( ', ', @missing ) ]
        );
    }
}

# Package private
# sends $p->{template} to $p->{Email} with a bunch of substitutions.
sub sendEmail {
    my ( $session, $template, $p ) = @_;

    my $text = $session->templates->readTemplate($template);
    $p->{Introduction} ||= '';
    $p->{Name} ||= $p->{WikiName};
    $text =~ s/%LOGINNAME%/$p->{LoginName}/geo;
    $text =~ s/%FIRSTLASTNAME%/$p->{Name}/go;
    $text =~ s/%WIKINAME%/$p->{WikiName}/geo;
    $text =~ s/%EMAILADDRESS%/$p->{Email}/go;
    $text =~ s/%INTRODUCTION%/$p->{Introduction}/go;
    $text =~ s/%VERIFICATIONCODE%/$p->{VerificationCode}/go;
    $text =~ s/%PASSWORD%/$p->{PasswordA}/go;
    my $topicObject = Foswiki::Meta->new( $session, $Foswiki::cfg{UsersWebName},
        $p->{WikiName} );
    $text = $topicObject->expandMacros($text);

    return $session->net->sendEmail($text);
}

sub _codeFile {
    my ($code) = @_;
    ASSERT($code) if DEBUG;
    throw Error::Simple("bad code") unless $code =~ /^(\w+)\.(\d+)$/;
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
    my ( $session, $code ) = @_;

    ASSERT($code) if DEBUG;

    my $file;
    try {
        $file = _codeFile($code);
    }
    catch Error::Simple with {
        throw Foswiki::OopsException(
            'attention',
            def    => 'bad_ver_code',
            params => [ $code, 'Invalid code' ],
        );
    };

    unless ( -f $file ) {
        my $wikiName = _codeWikiName($code);
        my $users    = $session->{users}->findUserByWikiName($wikiName);
        if ( scalar( @{$users} )
            && $session->{users}->userExists( $users->[0] ) )
        {
            throw Foswiki::OopsException(
                'attention',
                def    => 'duplicate_activation',
                params => [$wikiName],
            );
        }
        throw Foswiki::OopsException(
            'attention',
            def    => 'bad_ver_code',
            params => [ $code, 'Code is not recognised' ],
        );
    }

    $data = undef;
    $form = undef;
    do $file;
    $data->{form} = $form if $form;
    throw Foswiki::OopsException(
        'attention',
        def    => 'bad_ver_code',
        params => [ $code, 'Bad activation code' ]
    ) if $!;
    throw Foswiki::OopsException(
        'attention',
        def    => 'bad_ver_code',
        params => [ $code, 'Invalid activation code ' ]
    ) unless $data->{VerificationCode} eq $code;

    return $data;
}

sub _getDataFromQuery {
    my $users = shift;
    my $query = shift;

    # get all parameters from the form
    my $data = {};
    foreach my $key ( $query->param() ) {
        if ( $key =~ /^((?:Twk|Fwk)([0-9])(.*))/
            and ( defined( $query->param($key) ) ) )
        {
            my @values   = $query->param($key);
            my $required = $2;
            my $name     = $3;

            # deal with multivalue fields like checkboxen
            my $value = join( ',', @values );

            try {
                $data->{$name} =
                  $users->validateRegistrationField( $name, $value );
            }
            catch Error::Simple with {
                my $e = shift;
                throw Foswiki::OopsException(
                    'attention',
                    def    => 'invalid_field',
                    params => [$name]
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
