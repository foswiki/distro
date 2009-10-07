#require 5.008;

package RegisterTests;

# Tests not implemented:
#notest_registerTwiceWikiName
#notest_registerTwiceEmailAddress
#notest_bulkResetPassword
#notest_registerIllegitimateBypassApprove
#notest_registerVerifyAndFinish
#test_DoubleRegistration (loginname already used)

#Uncomment to isolate
#our @TESTS = qw(notest_registerVerifyOk); #notest_UnregisteredUser);

# Note that the FoswikiFnTestCase needs to use the registration code to work,
# so this is a bit arse before tit. However we need some pre-registered users
# for this to work sensibly, so we just have to bite the bullet.
use base qw(FoswikiFnTestCase);

use strict;
use diagnostics;
use Foswiki::UI::Register;
use Data::Dumper;
use FileHandle;
use Error qw( :try );
use File::Copy;
use File::Path;
use Carp;
use Cwd;

my $systemWeb = "TemporaryRegisterTestsSystemWeb";

sub new {
    my $this = shift()->SUPER::new( 'Registration', @_ );

    # your state for fixture here
    return $this;
}

my $session;
my $REG_UI_FN;
my $RP_UI_FN;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $REG_UI_FN ||= $this->getUIFn('register');
    $RP_UI_FN  ||= $this->getUIFn('resetpasswd');

    $this->{new_user_login} = 'sqwauk';
    $this->{new_user_fname} = 'Walter';
    $this->{new_user_sname} = 'Pigeon';
    $this->{new_user_email} = 'kakapo@ground.dwelling.parrot.net';
    $this->{new_user_wikiname} =
      "$this->{new_user_fname}$this->{new_user_sname}";
    $this->{new_user_fullname} =
      "$this->{new_user_fname} $this->{new_user_sname}";

    try {
        my $topicObject = Foswiki::Meta->new(
            $this->{session},  $this->{users_web},
            'NewUserTemplate', <<'EOF');
%NOP{Ignore this}%
But not this
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
%WIKIUSERNAME%
%WIKINAME%
%USERNAME%
AFTER
EOF
        $topicObject->save();

        # Make the test current user an admin; we will only use
        # them where necessary (e.g. for bulk registration)
        $topicObject =
          Foswiki::Meta->new( $this->{session}, $this->{users_web},
            $Foswiki::cfg{SuperAdminGroup}, <<EOF);
   * Set GROUP = $this->{test_user_wikiname}
EOF
        $topicObject->save();

        $topicObject =
          Foswiki::Meta->new( $this->{session}, $this->{users_web}, 'UserForm',
            <<'EOF');
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* |
| <nop>FirstName | text | 40 | | |
| <nop>LastName | text | 40 | | |
| Email | text | 40 | | H |
| Name | text | 40 | | H |
| Comment | textarea | 50x6 | | |
EOF
        $topicObject->save();

        my $webObject = Foswiki::Meta->new( $this->{session}, $systemWeb );
        $webObject->populateNewWeb( $Foswiki::cfg{SystemWebName} );
        $Foswiki::cfg{SystemWebName} = $systemWeb;
        $Foswiki::cfg{EnableEmail}   = 1;

    }
    catch Foswiki::AccessControlException with {
        $this->assert( 0, shift->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    };

    $Error::Debug = 1;

    @FoswikiFnTestCase::mails = ();
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $systemWeb );
    $this->SUPER::tear_down();
}

# fixture
sub registerAccount {
    my $this = shift;

    $this->registerVerifyOk();

    my $query = new Unit::Request(
        {
            'code'   => [ $this->{session}->{DebugVerificationCode} ],
            'action' => ['verify']
        }
    );

    try {
        Foswiki::UI::Register::_complete( $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "thanks", $e->{def}, $e->stringify() );
        $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
        my $done = '';
        foreach my $mail (@FoswikiFnTestCase::mails) {
            if ( $mail =~ /^Subject:.*Registration for/m ) {
                if ( $mail =~ /^To: .*\b$this->{new_user_email}\b/m ) {
                    $this->assert( !$done, $done . "\n---------\n" . $mail );
                    $done = $mail;
                }
                else {
                    $this->assert_matches(
qr/To: $Foswiki::cfg{WebMasterName} <$Foswiki::cfg{WebMasterEmail}>/,
                        $mail
                    );
                }
            }
            else {
                $this->assert( 0, $mail );
            }
        }
        $this->assert($done);
        @FoswikiFnTestCase::mails = ();
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert(
        $this->{session}->topicExists(
            $Foswiki::cfg{UsersWebName},
            $this->{new_user_wikiname}
        )
    );
}
###################################
#verify tests

sub AllowLoginName {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
}

sub DontAllowLoginName {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 0;
    $this->{new_user_login} = $this->{new_user_wikiname};

    #$this->{test_user_login} = $this->{test_user_wikiname};
}

sub TemplateLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::TemplateLogin';
}

sub ApacheLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::ApacheLogin';
}

sub NoLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager';
}

sub HtPasswdManager {
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';
}

sub NonePasswdManager {
    $Foswiki::cfg{PasswordManager} = 'none';
}

sub BaseUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::BaseUserMapping';
    $this->set_up_for_verify();
}

sub TopicUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::TopicUserMapping';
    $this->set_up_for_verify();
}

# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {
    return (
        [ 'TemplateLoginManager', 'ApacheLoginManager', 'NoLoginManager', ],
        [ 'AllowLoginName',       'DontAllowLoginName', ],
        [
            'HtPasswdManager',

            #'NonePasswdManager',
        ],
        [
            'TopicUserMapping',

            #'BaseUserMapping',
        ]
    );
}

#delay the calling of set_up til after the cfg's are set by above closure
sub set_up_for_verify {
    my $this = shift;

    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};

    @FoswikiFntestCase::mails = ();
}

###################################
sub verify_userTopicWithPMWithoutForm {
    my $this = shift;
    $this->assert(
        !$this->{session}->topicExists(
            $Foswiki::cfg{UsersWebName},
            $this->{new_user_wikiname}
        ),
        "cannot re-register user who's topic exists"
    );
    $this->registerAccount();
    my $meta = Foswiki::Meta->load(
        $this->{session},
        $Foswiki::cfg{UsersWebName},
        $this->{new_user_wikiname}
    );
    my $text = $meta->text;
    $this->assert( $text !~ /Ignore this%/, $text );
    $this->assert( $text =~ s/But not this//, $text );
    $this->assert( $text =~ s/^\s*\* First Name: $this->{new_user_fname}$//m,
        $text );
    $this->assert( $text =~ s/^\s*\* Last Name: $this->{new_user_sname}$//m,
        $text );
    $this->assert( $text =~ s/^\s*\* Comment:\s*$//m, $text );
    $this->assert( $text =~ s/^\s*\* Name: $this->{new_user_fullname}$//m,
        $text );
    $this->assert(
        $text =~ s/$Foswiki::cfg{UsersWebName}\.$this->{new_user_wikiname}//,
        $text );
    $this->assert( $text =~ s/$this->{new_user_wikiname}//, $text );
    $this->assert_matches( qr/\s*AFTER\s*/, $text );
}

sub verify_userTopicWithoutPMWithoutForm {
    my $this = shift;

    # Switch off the password manager to force email to be written to user
    # topic
    $Foswiki::cfg{PasswordManager} = 'none';
    $this->assert(
        !$this->{session}->topicExists(
            $Foswiki::cfg{UsersWebName},
            $this->{new_user_wikiname}
        ),
        "cannot re-register user who's topic exists"
    );
    $this->registerAccount();
    my $meta = Foswiki::Meta->load(
        $this->{session},
        $Foswiki::cfg{UsersWebName},
        $this->{new_user_wikiname}
    );
    my $text = $meta->text;
    $this->assert( $text !~ /Ignore this%/, $text );
    $this->assert( $text =~ s/But not this//, $text );
    $this->assert( $text =~ s/^\s*\* First Name: $this->{new_user_fname}$//m,
        $text );
    $this->assert( $text =~ s/^\s*\* Last Name: $this->{new_user_sname}$//m,
        $text );
    $this->assert( $text =~ s/^\s*\* Comment:\s*$//m, $text );
    $this->assert( $text =~ s/^\s*\* Name: $this->{new_user_fullname}$//m,
        $text );
    $this->assert( $text =~ s/^\s*\* Email: $this->{new_user_email}$//m,
        $text );
    $this->assert(
        $text =~ s/$Foswiki::cfg{UsersWebName}\.$this->{new_user_wikiname}//,
        $text );
    $this->assert( $text =~ s/$this->{new_user_wikiname}//, $text );
    $this->assert_matches( qr/\s*AFTER\s*/, $text );
}

sub verify_userTopicWithoutPMWithForm {
    my $this = shift;

    # Switch off the password manager to force email to be written to user
    # topic
    $Foswiki::cfg{PasswordManager} = 'none';

    # Change the new user topic to include the form
    my $m =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        'NewUserTemplate', <<BODY );
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
BODY
    $m->put( 'FORM', { name => "$this->{users_web}.UserForm" } );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'FirstName',
            title      => '<nop>FirstName',
            attributes => '',
            value      => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'LastName',
            title      => '<nop>LastName',
            attributes => '',
            value      => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'Email',
            title      => 'Email',
            attributes => '',
            value      => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'Name',
            title      => 'Name',
            attributes => '',
            value      => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'Comment',
            title      => 'Comment',
            attributes => '',
            value      => '',
        }
    );

    $m->save();

    $this->registerAccount();

    my $meta = Foswiki::Meta->load(
        $this->{session},
        $Foswiki::cfg{UsersWebName},
        $this->{new_user_wikiname}
    );
    my $text = $meta->text;

    my $field = $meta->get( 'FIELD', 'FirstName' );
    $this->assert($field);
    $this->assert_str_equals( $this->{new_user_fname}, $field->{value} );

    $field = $meta->get( 'FIELD', 'LastName' );
    $this->assert($field);
    $this->assert_str_equals( $this->{new_user_sname}, $field->{value} );

    $field = $meta->get( 'FIELD', 'Comment' );
    $this->assert($field);
    $this->assert_str_equals( '', $field->{value} );

    $field = $meta->get( 'FIELD', 'Email' );
    if ($field) {
        $this->assert_str_equals( $this->{new_user_email}, $field->{value} );
    }
    $this->assert_matches( qr/^\s*$/s, $text );
}

sub verify_userTopicWithPMWithForm {
    my $this = shift;

    # Change the new user topic to include the form
    my $m =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        'NewUserTemplate', <<BODY );
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
BODY
    $m->put( 'FORM', { name => "$this->{users_web}.UserForm" } );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'FirstName',
            title      => '<nop>FirstName',
            attributes => '',
            value      => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'LastName',
            title      => '<nop>LastName',
            attributes => '',
            value      => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'Email',
            title      => 'Email',
            attributes => '',
            value      => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'Name',
            title      => 'Name',
            attributes => '',
            value      => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name       => 'Comment',
            title      => 'Comment',
            attributes => '',
            value      => '',
        }
    );
    $m->save();

    $this->registerAccount();
    my $meta = Foswiki::Meta->load(
        $this->{session},
        $Foswiki::cfg{UsersWebName},
        $this->{new_user_wikiname}
    );
    my $text = $meta->text;
    $this->assert_not_null( $meta->get('FORM') );
    $this->assert_str_equals( "$this->{users_web}.UserForm",
        $meta->get('FORM')->{name} );
    $this->assert_str_equals( $this->{new_user_fname},
        $meta->get( 'FIELD', 'FirstName' )->{value} );
    $this->assert_str_equals( $this->{new_user_sname},
        $meta->get( 'FIELD', 'LastName' )->{value} );
    $this->assert_str_equals( '', $meta->get( 'FIELD', 'Comment' )->{value} );
    $this->assert_str_equals( '', $meta->get( 'FIELD', 'Email' )->{value} );
    $this->assert_matches( qr/^\s*$/s, $text );
}

#Register a user, and then verify it
#Assumes the verification code is $this->{session}->{DebugVerificationCode}
sub registerVerifyOk {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 1;
    my $query = new Unit::Request(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1LoginName' => [ $this->{new_user_login} ],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'action'        => ['register']
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        &$REG_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "confirm", $e->{def}, $e->stringify() );
        my $encodedTestUserEmail =
          Foswiki::entityEncode( $this->{new_user_email} );
        $this->assert_matches( $this->{new_user_email}, $e->{params}->[0], $e->stringify() );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    my $code = shift || $this->{session}->{DebugVerificationCode};
    $query = new Unit::Request(
        {
            'code'   => [$code],
            'action' => ['verify']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::UI::Register::verifyEmailAddress( $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    };
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $done = '';
    foreach my $mail (@FoswikiFnTestCase::mails) {
        if ( $mail =~ /Your verification code is /m ) {
            $this->assert( !$done, $done . "\n---------\n" . $mail );
            $done = $mail;
        }
        else {
            $this->assert( 0, $mail );
        }
    }
    $this->assert($done);
    @FoswikiFnTestCase::mails = ();
}

#Register a user, then give a bad verification code. It should barf.
sub verify_registerBadVerify {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 1;
    my $query = new Unit::Request(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1LoginName' => [ $this->{new_user_login} ],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'action'        => ['register']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        no strict 'refs';
        &$REG_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        my $encodedTestUserEmail =
          Foswiki::entityEncode( $this->{new_user_email} );
        $this->assert_matches( $this->{new_user_email}, $e->{params}->[0], $e->stringify() );
        $this->assert_str_equals( "attention", $e->{template} );
        $this->assert_str_equals( "confirm",   $e->{def} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );

    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    my $code = $this->{session}->{DebugVerificationCode};
    $query = new Unit::Request(
        {
            'code'   => [$code],
            'action' => ['verify']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::UI::Register::verifyEmailAddress( $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "bad_ver_code", $e->{def}, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "Expected a redirect" );
    };
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $mess = $FoswikiFnTestCase::mails[0];
    $this->assert_matches(
        qr/From: $Foswiki::cfg{WebMasterName} <$Foswiki::cfg{WebMasterEmail}>/,
        $mess
    );
    $this->assert_matches( qr/To: .*\b$this->{new_user_email}\b/, $mess );

    # check the verification code
    $this->assert_matches( qr/'$code'/, $mess );
}

# Register a user with verification explicitly switched off
# (SUPER's tear_down will take care for re-installing %Foswiki::cfg)
sub verify_registerNoVerifyOk {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    my $query = new Unit::Request(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1LoginName' => [ $this->{new_user_login} ],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'action'        => ['register']
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        &$REG_UI_FN( $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "thanks", $e->{def}, $e->stringify() );
        $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
        my $done = '';
        foreach my $mail (@FoswikiFnTestCase::mails) {
            if ( $mail =~ /^Subject:.*Registration for/m ) {
                if ( $mail =~ /^To: .*\b$this->{new_user_email}\b/m ) {
                    $this->assert( !$done, $done . "\n---------\n" . $mail );
                    $done = $mail;
                }
                else {
                    $this->assert_matches(
qr/To: $Foswiki::cfg{WebMasterName} <$Foswiki::cfg{WebMasterEmail}>/,
                        $mail
                    );
                }
            }
            else {
                $this->assert( 0, $mail );
            }
        }
        $this->assert($done);
        @FoswikiFnTestCase::mails = ();
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
}

# Register a user with a password which is too short - must be rejected
sub verify_rejectShortPassword {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    $Foswiki::cfg{MinPasswordLength}          = 6;
    $Foswiki::cfg{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $Foswiki::cfg{Register}{AllowLoginName}   = 0;
    my $query = new Unit::Request(
        {
            'TopicName'    => ['UserRegistration'],
            'Twk1Email'    => [ $this->{new_user_email} ],
            'Twk1WikiName' => [ $this->{new_user_wikiname} ],
            'Twk1Name'     => [ $this->{new_user_fullname} ],
            'Twk0Comment'  => [''],

         #                         'Twk1LoginName' => [$this->{new_user_login}],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'Twk1Password'  => ['12345'],
            'Twk1Confirm'   => ['12345'],
            'action'        => ['register'],
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        &$REG_UI_FN( $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "bad_password", $e->{def}, $e->stringify() );
        $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
        @FoswikiFnTestCase::mails = ();
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
}

# Register a user with a password which is too short
sub verify_shortPassword {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    $Foswiki::cfg{MinPasswordLength}          = 6;
    $Foswiki::cfg{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $Foswiki::cfg{Register}{AllowLoginName}   = 1;
    my $query = new Unit::Request(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1LoginName' => [ $this->{new_user_login} ],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'Twk1Password'  => ['12345'],
            'Twk1Confirm'   => ['12345'],
            'action'        => ['register'],
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        &$REG_UI_FN( $this->{session} );
        use strict 'refs';

        my $cUID =
          $this->{session}->{users}
          ->getCanonicalUserID( $this->{new_user_login} );
        $this->assert( $this->{session}->{users}->userExists($cUID),
            "new user created" );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "bad_password", $e->{def}, $e->stringify() );
        $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

# don't check the FoswikiFnTestCase::mails in this test case - this is done elsewhere
        @FoswikiFnTestCase::mails = ();
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
}

# Purpose:  Test behaviour of duplicate activation (Item3105)
# Verifies: Most of the things which are verified during normal
#           registration with Verification, plus Oops for
#           duplicate verification
sub verify_duplicateActivation {
    my $this = shift;

    # Start similar to registration with verification
    $Foswiki::cfg{Register}{NeedVerification} = 1;
    my $query = new Unit::Request(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk1LoginName' => [ $this->{new_user_login} ],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'action'        => ['register'],
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session} = Foswiki->new( $Foswiki::cfg{DefaultUserName}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        no strict 'refs';
        &$REG_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "confirm", $e->{def}, $e->stringify() );
        my $encodedTestUserEmail =
          Foswiki::entityEncode( $this->{new_user_email} );
        $this->assert_matches( $this->{new_user_email}, $e->{params}->[0], $e->stringify() );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->{session}->finish();

    # For verification process everything including finish(), so don't just
    # call verifyEmails
    my $code = shift || $this->{session}->{DebugVerificationCode};
    $query = new Unit::Request(
        {
            'code'   => [$code],
            'action' => ['verify'],
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session} = Foswiki->new( $Foswiki::cfg{DefaultUserName}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        no strict 'refs';
        &$REG_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "thanks", $e->{def}, $e->stringify() );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->{session}->finish();

    # and now for something completely different: Do it all over again
    @FoswikiFnTestCase::mails = ();
    $query                    = new Unit::Request(
        {
            'code'   => [$code],
            'action' => ['verify'],
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session} = Foswiki->new( $Foswiki::cfg{DefaultUserName}, $query );
    $this->{session}->net->setMailHandler( \&sentMail );
    try {
        no strict 'refs';
        &$REG_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "duplicate_activation", $e->{def},
            $e->stringify() );
        $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    @FoswikiFnTestCase::mails = ();
}

################################################################################
################################ RESET PASSWORD TESTS ##########################

sub verify_resetPasswordOkay {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $this->registerAccount();
    my $cUID =
      $this->{session}->{users}->getCanonicalUserID( $this->{new_user_login} );
    $this->assert( $this->{session}->{users}->userExists($cUID),
        " $cUID does not exist?" );
    my $newPassU = '12345';
    my $oldPassU = 1;         #force set
    $this->assert(
        $this->{session}->{users}->setPassword( $cUID, $newPassU, $oldPassU ) );
    $this->assert( $this->{session}->{users}
          ->checkPassword( $this->{new_user_login}, $newPassU ) );
    my @emails = $this->{session}->{users}->getEmails($cUID);
    $this->assert_str_equals( $this->{new_user_email}, $emails[0] );

    my $query = new Unit::Request(
        {
            'LoginName' => [ $this->{new_user_login} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/WebHome' );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        &$RP_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "reset_ok", $e->{def}, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $mess = $FoswikiFnTestCase::mails[0];
    $this->assert_matches(
        qr/From: $Foswiki::cfg{WebMasterName} <$Foswiki::cfg{WebMasterEmail}>/,
        $mess
    );
    $this->assert_matches( qr/To: .*\b$this->{new_user_email}/, $mess );

    #lets make sure the password actually was reset
    $this->assert(
        !$this->{session}->{users}->checkPassword( $cUID, $newPassU ) );
    my @post_emails = $this->{session}->{users}->getEmails($cUID);
    $this->assert_str_equals( $this->{new_user_email}, $post_emails[0] );

}

sub verify_resetPasswordNoSuchUser {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = new Unit::Request(
        {
            'LoginName' => [ $this->{new_user_wikiname} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/.' . $this->{users_web} . '/WebHome' );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        &$RP_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "reset_bad", $e->{def}, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
}

sub verify_resetPasswordNeedPrivilegeForMultipleReset {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = new Unit::Request(
        {
            'LoginName' =>
              [ $this->{test_user_wikiname}, $this->{new_user_wikiname} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/.' . $this->{users_web} . '/WebHome' );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        &$RP_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_matches( qr/$Foswiki::cfg{SuperAdminGroup}/,
            $e->stringify() );
        $this->assert_str_equals( 'accessdenied', $e->{template} );
        $this->assert_str_equals( 'only_group',   $e->{def} );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
}

# This test make sure that the system can't reset passwords
# for a user currently absent from .htpasswd
sub verify_resetPasswordNoPassword {
    my $this = shift;

    $this->registerAccount();

    my $query = new Unit::Request(
        {
            'LoginName' => [ $this->{new_user_wikiname} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/WebHome' );
    unlink $Foswiki::cfg{Htpasswd}{FileName};

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        &$RP_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "reset_bad", $e->{def}, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    # If the user is not in htpasswd, there's can't be an email
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
    @FoswikiFnTestCase::mails = ();
}

=pod

Create an incomplete registration, and try to finish it off.
Once complete, try again - the second attempt at completion should fail.

=cut

sub verify_UnregisteredUser {
    my $this = shift;

    my $regSave = {
        doh              => "homer",
        VerificationCode => "GitWit.0",
        WikiName         => "GitWit"
    };

    my $file = Foswiki::UI::Register::_codeFile( $regSave->{VerificationCode} );
    $this->assert( open( F, ">$file" ) );
    print F Data::Dumper->Dump( [ $regSave, undef ], [ 'data', 'form' ] );
    close F;

    my $result2 =
      Foswiki::UI::Register::_loadPendingRegistration( $session, "GitWit.0" );
    $this->assert_deep_equals( $result2, $regSave );

    try {

        # this is a deliberate attempt to reload an already used token.
        # this should fail!
        Foswiki::UI::Register::_clearPendingRegistrationsForUser("GitWit.0");
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_matches( qr/has no file/, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    };

    # $this->assert_null( UnregisteredUser::reloadUserContext($code));
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
}

sub verify_missingElements {
    my $this     = shift;
    my @present  = ( "one", "two", "three" );
    my @required = ( "one", "two", "six" );

    $this->assert_deep_equals(
        [ Foswiki::UI::Register::_missingElements( \@present, \@required ) ],
        ["six"] );
    $this->assert_deep_equals(
        [ Foswiki::UI::Register::_missingElements( \@present, \@present ) ],
        [] );
}

sub verify_bulkRegister {
    my $this = shift;

    my $testReg = <<'EOM';
| FirstName | LastName | Email | WikiName | LoginName | CustomFieldThis | SomeOtherRandomField | WhateverYouLike |
| Test | User | Martin.Cleaver@BCS.org.uk |  TestBulkUser1 | a | A | B | C |
| Test | User2 | Martin.Cleaver@BCS.org.uk | TestBulkUser2 | b | A | B | C |
| Test | User3 | Martin.Cleaver@BCS.org.uk | TestBulkUser3 | c | A | B | C |
EOM

    my $regTopic = 'UnprocessedRegistrations2';

    my $logTopic = 'UnprocessedRegistrations2Log';
    my $file =
        $Foswiki::cfg{DataDir} . '/'
      . $this->{test_web} . '/'
      . $regTopic . '.txt';
    my $fh = new FileHandle;

    die "Can't write $file" unless ( $fh->open(">$file") );
    print $fh $testReg;
    $fh->close;

    my $query = new Unit::Request(
        {
            'LogTopic'              => [$logTopic],
            'EmailUsersWithDetails' => ['0'],
            'OverwriteHomeTopics'   => ['1'],
        }
    );

    $query->path_info("/$this->{test_web}/$regTopic");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{SuperAdminGroup}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = $regTopic;
    $this->{session}->{webName}   = $this->{test_web};
    try {
        $this->capture( \&Foswiki::UI::Register::bulkRegister,
            $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert( 0, $e->stringify() . " UNEXPECTED" );

    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
}

sub verify_buildRegistrationEmail {
    my ($this) = shift;

    my %data = (
        'CompanyName' => '',
        'Country'     => 'Saudi Arabia',
        'Password'    => 'mypassword',
        'form'        => [
            {
                'value'    => $this->{new_user_fullname},
                'required' => '1',
                'name'     => 'Name'
            },
            {
                'value'    => $this->{new_user_email},
                'required' => '1',
                'name'     => 'Email'
            },
            {
                'value'    => '',
                'required' => '0',
                'name'     => 'CompanyName'
            },
            {
                'value'    => '',
                'required' => '0',
                'name'     => 'CompanyURL'
            },
            {
                'value'    => 'Saudi Arabia',
                'required' => '1',
                'name'     => 'Country'
            },
            {
                'value'    => '',
                'required' => '0',
                'name'     => 'Comment'
            },
            {
                'value' => 'mypassword',
                'name'  => 'Password',
            }
        ],
        'VerificationCode' => $this->{session}->{DebugVerificationCode},
        'Name'             => $this->{new_user_fullname},
        'webName'          => $this->{users_web},
        'WikiName'         => $this->{new_user_wikiname},
        'Comment'          => '',
        'CompanyURL'       => '',
        'passwordA'        => 'mypassword',
        'passwordB'        => 'mypassword',
        'Email'            => $this->{new_user_email},
        'debug'            => 1,
        'Confirm'          => 'mypassword'
    );

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin} );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    my $actual =
      Foswiki::UI::Register::_buildConfirmationEmail( $this->{session}, \%data,
        "%FIRSTLASTNAME% - %WIKINAME% - %EMAILADDRESS%\n\n%FORMDATA%", 0 );

    $this->assert(
        $actual =~
s/$this->{new_user_fullname} - $this->{new_user_wikiname} - $this->{new_user_email}\s*//s,
        $actual
    );

    $this->assert( $actual =~ /^\s*\*\s*Email:\s*$this->{new_user_email}$/,
        $actual );
    $this->assert( $actual =~ /^\s*\*\s*CompanyName:\s*$/,         $actual );
    $this->assert( $actual =~ /^\s*\*\s*CompanyURL:\s*$/,          $actual );
    $this->assert( $actual =~ /^\s*\*\s*Country:\s*Saudi Arabia$/, $actual );
    $this->assert( $actual =~ /^\s*\*\s*Comment:\s*$/,             $actual );
    $this->assert( $actual =~ /^\s*\*\s*Password:\s*mypassword$/,  $actual );
    $this->assert( $actual =~ /^\s*\*\s*LoginName:\s*$/,           $actual );
    $this->assert( $actual =~ /^\s*\*\s*Name:\s*$this->{new_user_fullname}$/,
        $actual );

    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
}

=pod

  call this if you want to make spaces and \ns visible

=cut

sub visible {
    return $_[0];
    my ($a) = @_;
    $a =~ s/\n/NL/g;
    $a =~ s/\r/CR/g;
    $a =~ s/ /SP/g;
    $a;
}

sub verify_disabled_registration {
    my $this = shift;
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 0;
    $Foswiki::cfg{Register}{NeedVerification}          = 0;
    my $query = new Unit::Request(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1LoginName' => [ $this->{new_user_login} ],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'action'        => ['register']
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        &$REG_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "registration_disabled", $e->{def},
            $e->stringify() );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify() );
    }
    otherwise {
        my $e = shift;
        $this->assert( 0,
                "expected registration_disabled, got "
              . $e->stringify() . ' {'
              . $e->{template} . '}  {'
              . $e->{def} . '} '
              . ref($e) );
    }
}

# "All I want to do for this installation is register with my wiki name
# and use that as my login name, so I can log in using the template login."
# {Register}{AllowLoginName} = 0
# {Register}{NeedVerification} = 0
# {Register}{EnableNewUserRegistration} = 1
# {LoginManager} = 'Foswiki::LoginManager::TemplateLogin'
# {PasswordManager} = 'Foswiki::Users::HtPasswdUser'
sub test_3951 {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName}            = 0;
    $Foswiki::cfg{Register}{NeedVerification}          = 0;
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{LoginManager}    = 'Foswiki::LoginManager::TemplateLogin';
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';
    my $query = new Unit::Request(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'action'        => ['register']
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        &$REG_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "thanks", $e->{def}, $e->stringify() );
        my $encodedTestUserEmail =
          Foswiki::entityEncode( $this->{new_user_email} );
        $this->assert_matches( $this->{new_user_email}, $e->{params}->[0], $e->stringify() );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
}

# "User gets added to password system, despite a failure adding
#  them to the mapping"
sub test_4061 {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName}            = 0;
    $Foswiki::cfg{Register}{NeedVerification}          = 0;
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{LoginManager}    = 'Foswiki::LoginManager::TemplateLogin';
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';
    my $query = new Unit::Request(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'action'        => ['register']
        }
    );

    # Make WikiUsers read-only
    chmod( 0444,
"$Foswiki::cfg{DataDir}/$Foswiki::cfg{UsersWebName}/$Foswiki::cfg{UsersTopicName}.txt"
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $this->assert( open( F, "<", $Foswiki::cfg{Htpasswd}{FileName} ) );
    local $/;
    my $before = <F>;
    close(F);
    try {
        no strict 'refs';
        &$REG_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "problem_adding", $e->{def},
            $e->stringify() );

        # Verify that they have not been added to .htpasswd
        $this->assert( open( F, "<", $Foswiki::cfg{Htpasswd}{FileName} ) );
        local $/;
        my $stuff = <F>;
        close(F);
        $this->assert_str_equals( $before, $stuff );

        # Verify they have no user topic
        $this->assert(
            !Foswiki::Func::topicExists(
                $this->{users_web}, $this->{new_user_wikiname}
            )
        );

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    }
    finally {
        chmod( 0777,
"$Foswiki::cfg{DataDir}/$this->{users_web}/$Foswiki::cfg{UsersTopicName}.txt"
        );
    };
}

################################################################################
################################ RESET EMAIL TESTS ##########################

sub verify_resetEmailOkay {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)
    ### need to know the password too
    $this->registerAccount();

    my $cUID =
      $this->{session}->{users}->getCanonicalUserID( $this->{new_user_login} );
    $this->assert( $this->{session}->{users}->userExists($cUID),
        "new user created" );
    my $newPassU = '12345';
    my $oldPassU = 1;         #force set
    $this->assert(
        $this->{session}->{users}->setPassword( $cUID, $newPassU, $oldPassU ) );
    my $newEmail = 'UnitEmail@home.org.au';

    my $query = new Unit::Request(
        {
            'LoginName'   => [ $this->{new_user_login} ],
            'TopicName'   => ['ChangeEmailAddress'],
            'username'    => [ $this->{new_user_login} ],
            'oldpassword' => ['12345'],
            'email'       => [$newEmail],
            'action'      => ['resetPassword']
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/WebHome' );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{new_user_login}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        require Foswiki::UI::Passwords;
        Foswiki::UI::Passwords::changePassword( $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "email_changed", $e->{def}, $e->stringify() );
        $this->assert_str_equals(
            $newEmail,
            ${ $e->{params} }[0],
            ${ $e->{params} }[0]
        );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    my @emails = $this->{session}->{users}->getEmails($cUID);
    $this->assert_str_equals( $newEmail, $emails[0] );
}

#test for TWikibug:Item3400
sub verify_resetPassword_NoWikiUsersEntry {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $this->registerAccount();

    #Remove the WikiUsers entry - by deleting it :)
    Foswiki::Func::moveTopic(
        $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{UsersTopicName},
        $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{UsersTopicName} . 'DELETED'
    );

    #force a reload to unload existing user caches, and then restart as guest
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};

    $this->assert(
        !Foswiki::Func::topicExists(
            $Foswiki::cfg{UsersWebName},
            $Foswiki::cfg{UsersTopicName}
        )
    );

    my $cUID =
      $this->{session}->{users}->getCanonicalUserID( $this->{new_user_login} );
    $this->assert( $this->{session}->{users}->userExists($cUID),
        " $cUID does not exist?" );
    my $newPassU = '12345';
    my $oldPassU = 1;         #force set
    $this->assert(
        $this->{session}->{users}->setPassword( $cUID, $newPassU, $oldPassU ) );
    $this->assert( $this->{session}->{users}
          ->checkPassword( $this->{new_user_login}, $newPassU ) );
    my @emails = $this->{session}->{users}->getEmails($cUID);
    $this->assert_str_equals( $this->{new_user_email}, $emails[0] );

    my $query = new Unit::Request(
        {
            'LoginName' => [ $this->{new_user_login} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/WebHome' );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        &$RP_UI_FN( $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "reset_ok", $e->{def}, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $mess = $FoswikiFnTestCase::mails[0];
    $this->assert_matches(
        qr/From: $Foswiki::cfg{WebMasterName} <$Foswiki::cfg{WebMasterEmail}>/,
        $mess
    );
    $this->assert_matches( qr/To: .*\b$this->{new_user_email}/, $mess );

    #lets make sure the password actually was reset
    $this->assert(
        !$this->{session}->{users}->checkPassword( $cUID, $newPassU ) );
    my @post_emails = $this->{session}->{users}->getEmails($cUID);
    $this->assert_str_equals( $this->{new_user_email}, $post_emails[0] );

}

sub registerUserException {
    my ( $this, $loginname, $forename, $surname, $email ) = @_;

    my $query = new Unit::Request(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [$email],
            'Twk1WikiName'  => ["$forename$surname"],
            'Twk1Name'      => ["$forename $surname"],
            'Twk0Comment'   => [''],
            'Twk1LoginName' => [$loginname],
            'Twk1FirstName' => [$forename],
            'Twk1LastName'  => [$surname],
            'action'        => ['register']
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");

    my $fatwilly = new Foswiki( undef, $query );
    $fatwilly->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    my $exception;
    try {
        no strict 'refs';
        &$REG_UI_FN($fatwilly);
        no strict 'refs';
    }
    catch Foswiki::OopsException with {
        $exception = shift;
        if (   ( "attention" eq $exception->{template} )
            && ( "thanks" eq $exception->{def} ) )
        {

            #print STDERR "---------".$exception->stringify()."\n";
            $exception = undef;    #the only correct answer
        }
    }
    catch Foswiki::AccessControlException with {
        $exception = shift;
    }
    catch Error::Simple with {
        $exception = shift;
    }
    otherwise {
        $exception = new Error::Simple();
    };
    $fatwilly->finish();

    # Reload caches
    my $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    return $exception;
}

#$Foswiki::cfg{NameFilter} = qr/[\s\*?~^\$@%`"'&;|<>\[\]\x00-\x1f]/;
#$Foswiki::cfg{LoginNameFilterIn} = qr/^[^\s\*?~^\$@%`"'&;|<>\x00-\x1f]+$/;
sub verify_Default_LoginNameFilterIn {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->registerUserException( 'asdf@example.com', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_not_null( $ret, "email as log should fail" );

 #TODO: test response to undef'd login.. (and similarly for other params undef'd

    $ret = $this->registerUserException( 'asdf2@example.com', 'Asdf2', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "email as logon should fail" );
    $this->assert_equals( 'attention', $ret->{template},
        "email as logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->{def},
        "email as logon should fail" );
    $this->assert_equals(
        'asdf2@example.com',
        ${ $ret->{params} }[0],
        "email as logon should fail"
    );

    $ret = $this->registerUserException( 'some space', 'Asdf2', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "space logon should fail" );
    $this->assert_equals( 'attention', $ret->{template},
        "space logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->{def},
        "space logon should fail" );
    $this->assert_equals(
        'some space',
        ${ $ret->{params} }[0],
        "space logon should fail"
    );

    $ret = $this->registerUserException( 'question?', 'Asdf2', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "question?logon should fail" );
    $this->assert_equals( 'attention', $ret->{template},
        "question logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->{def},
        "question logon should fail" );
    $this->assert_equals(
        'question?',
        ${ $ret->{params} }[0],
        "question logon should fail"
    );

}

sub verify_Modified_LoginNameFilterIn_At {
    my $this = shift;
    my $ret;

    my $oldCfg = $Foswiki::cfg{LoginNameFilterIn};
    $Foswiki::cfg{LoginNameFilterIn} = qr/^[^\s\*?~^\$%`"'&;|<>\x00-\x1f]+$/;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->registerUserException( 'asdf2@example.com', 'Asdf3', 'Poiu',
        'asdf2@example.com' );
    $this->assert_null( $ret, "email as logon should succed" );

    $ret = $this->registerUserException( 'some space', 'Asdf4', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "space logon should fail" );
    $this->assert_equals( 'attention', $ret->{template},
        "space logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->{def},
        "space logon should fail" );
    $this->assert_equals(
        'some space',
        ${ $ret->{params} }[0],
        "space logon should fail"
    );

    $ret = $this->registerUserException( 'question?', 'Asdf5', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "question?logon should fail" );
    $this->assert_equals( 'attention', $ret->{template},
        "question logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->{def},
        "question logon should fail" );
    $this->assert_equals(
        'question?',
        ${ $ret->{params} }[0],
        "question logon should fail"
    );

    $Foswiki::cfg{LoginNameFilterIn} = $oldCfg;
}

sub verify_Modified_LoginNameFilterIn_Liberal {
    my $this = shift;
    my $ret;

    my $oldCfg = $Foswiki::cfg{LoginNameFilterIn};
    $Foswiki::cfg{LoginNameFilterIn} = qr/^.*$/;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->registerUserException( 'asdf@example.com', 'Asdf2', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "email as log should succed" );

    $ret = $this->registerUserException( 'asdf2@example.com', 'Asdf3', 'Poiu',
        'asdf2@example.com' );
    $this->assert_null( $ret, "email as logon should succed" );

    $ret = $this->registerUserException( 'some space', 'Asdf4', 'Poiu',
        'asdf2@example.com' );
    $this->assert_null( $ret, "space logon should succed" );

    $ret = $this->registerUserException( 'question?', 'Asdf5', 'Poiu',
        'asdf2@example.com' );
    $this->assert_null( $ret, "question?logon should succed" );

    $Foswiki::cfg{LoginNameFilterIn} = $oldCfg;
}

#$Foswiki::cfg{NameFilter} = qr/[\s\*?~^\$@%`"'&;|<>\[\]\x00-\x1f]/;
#this regex is only used later in the mapper - during rego, we actually use the isWikiWord test
sub verify_Default_NameFilter {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->registerUserException( 'asdf2', 'Asdf@', 'Poiu',
        'asdf@example.com' );
    $this->assert_not_null( $ret, "at in wikiname should fail" );
    $this->assert_equals( 'attention', $ret->{template},
        "at in name should fail" );
    $this->assert_equals( 'bad_wikiname', $ret->{def},
        "at in name should fail" );
    $this->assert_equals(
        'Asdf@Poiu',
        ${ $ret->{params} }[0],
        "at in name should fail"
    );

    $ret = $this->registerUserException( 'asdf3', 'Mac Asdf', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "space in name should fail" );
    $this->assert_equals( 'attention', $ret->{template},
        "space in name should fail" );
    $this->assert_equals( 'bad_wikiname', $ret->{def},
        "space in name should fail" );
    $this->assert_equals(
        'Mac AsdfPoiu',
        ${ $ret->{params} }[0],
        "space in name should fail"
    );

    $ret = $this->registerUserException( 'asdf4', 'Asd`f2', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "` name should fail" );
    $this->assert_equals( 'attention', $ret->{template},
        "space logon should fail" );
    $this->assert_equals( 'bad_wikiname', $ret->{def},
        "space logon should fail" );
    $this->assert_equals(
        'Asd`f2Poiu',
        ${ $ret->{params} }[0],
        "space logon should fail"
    );

    $ret = $this->registerUserException( 'asdf5', 'Asdf2', 'Po?iu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "question?logon should fail" );
    $this->assert_equals( 'attention', $ret->{template},
        "question logon should fail" );
    $this->assert_equals( 'bad_wikiname', $ret->{def},
        "question logon should fail" );
    $this->assert_equals(
        'Asdf2Po?iu',
        ${ $ret->{params} }[0],
        "question logon should fail"
    );

}

#in which a user correctly points out that the error checking is a bit minimal
sub verify_bulkRegister_Item2191 {
    my $this = shift;

    my $testReg = <<'EOM';
| Vorname  |	 Nachname  |	 Mailadresse  | WikiName | LoginName | CustomFieldThis | SomeOtherRandomField | WhateverYouLike |
| Test | User | Martin.Cleaver@BCS.org.uk |  TestBulkUser1 | a | A | B | C |
| Test | User2 | Martin.Cleaver@BCS.org.uk | TestBulkUser2 | b | A | B | C |
| Test | User3 | Martin.Cleaver@BCS.org.uk | TestBulkUser3 | c | A | B | C |
EOM

    my $regTopic = 'UnprocessedRegistrations2';

    my $logTopic = 'UnprocessedRegistrations2Log';
    my $file =
        $Foswiki::cfg{DataDir} . '/'
      . $this->{test_web} . '/'
      . $regTopic . '.txt';
    my $fh = new FileHandle;

    die "Can't write $file" unless ( $fh->open(">$file") );
    print $fh $testReg;
    $fh->close;

    my $query = new Unit::Request(
        {
            'LogTopic'              => [$logTopic],
            'EmailUsersWithDetails' => ['0'],
            'OverwriteHomeTopics'   => ['1'],
        }
    );

    $query->path_info("/$this->{test_web}/$regTopic");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{SuperAdminGroup}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = $regTopic;
    $this->{session}->{webName}   = $this->{test_web};
    try {
        my ($text) = $this->capture( \&Foswiki::UI::Register::bulkRegister,
            $this->{session} );
         
        #TODO: um, really need to test what the output was, and 
        #TODO: test if a user was registered..   
        #$this->assert( '', $text);
        #my $readMeta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'TemporaryRegistrationTestWebRegistration/UnprocessedRegistrations2Log' );
        #$this->assert( '', $readMeta->text());
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert( 0, $e->stringify() . " UNEXPECTED" );

    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
}

1;
