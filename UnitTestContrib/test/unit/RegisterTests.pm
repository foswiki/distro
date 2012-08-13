#require 5.008;

package RegisterTests;
use strict;
use warnings;
use diagnostics;

# Tests not implemented:
#notest_registerTwiceWikiName
#notest_registerIllegitimateBypassApprove
#notest_registerVerifyAndFinish
#test_DoubleRegistration (loginname already used)

#Uncomment to isolate
#our @TESTS = qw(notest_registerVerifyOk); #notest_UnregisteredUser);

# Note that the FoswikiFnTestCase needs to use the registration code to work,
# so this is a bit arse before tit. However we need some pre-registered users
# for this to work sensibly, so we just have to bite the bullet.
use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki::UI::Register();
use Data::Dumper;
use FileHandle();
use File::Copy();
use File::Path();
use Carp();
use Cwd();
use Error qw( :try );

my $systemWeb = "TemporaryRegisterTestsSystemWeb";

sub new {
    my ( $class, @args ) = @_;
    my $this = $class->SUPER::new( 'Registration', @args );

    # your state for fixture here
    return $this;
}

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
        my ($topicObject) =
          Foswiki::Func::readTopic( $this->{users_web}, 'NewUserTemplate' );
        $topicObject->text(<<'EOF');
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
        $topicObject->finish();
        ($topicObject) =
          Foswiki::Func::readTopic( $this->{users_web},
            $Foswiki::cfg{SuperAdminGroup} );
        $topicObject->text(<<"EOF");
   * Set GROUP = $this->{test_user_wikiname}
EOF
        $topicObject->save();

        $topicObject->finish();
        ($topicObject) =
          Foswiki::Func::readTopic( $this->{users_web}, 'UserForm' );
        $topicObject->text(<<'EOF');
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* |
| <nop>FirstName | text | 40 | | |
| <nop>LastName | text | 40 | | |
| Email | text | 40 | | H |
| Name | text | 40 | | H |
| Comment | textarea | 50x6 | | |
EOF
        $topicObject->save();
        $topicObject->finish();

        my $webObject =
          $this->populateNewWeb( $systemWeb, $Foswiki::cfg{SystemWebName} );
        $webObject->finish();
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

    return;
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig(@_);

    $Foswiki::cfg{Register}{UniqueEmail}      = 0;
    $Foswiki::cfg{Register}{EmailFilter}      = '';
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    $Foswiki::cfg{Register}{NeedApproval}     = 0;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $systemWeb );
    $this->SUPER::tear_down();

    return;
}

# fixture
sub registerAccount {
    my $this = shift;

    $this->registerVerifyOk();

    my $query = Unit::Request->new(
        {
            'code'   => [ $this->{session}->{DebugVerificationCode} ],
            'action' => ['verify']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::UI::Register::_verify( $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "thanks",   $e->{def},      $e->stringify() );
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

    return;
}
###################################
#verify tests

sub AllowLoginName {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 1;

    return;
}

sub DontAllowLoginName {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 0;
    $this->{new_user_login} = $this->{new_user_wikiname};

    #$this->{test_user_login} = $this->{test_user_wikiname};

    return;
}

sub TemplateLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::TemplateLogin';

    return;
}

sub ApacheLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::ApacheLogin';

    return;
}

sub NoLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager';

    return;
}

sub HtPasswdManager {
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

    return;
}

sub NonePasswdManager {
    $Foswiki::cfg{PasswordManager} = 'none';

    return;
}

sub BaseUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::BaseUserMapping';
    $this->set_up_for_verify();

    return;
}

sub TopicUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::TopicUserMapping';
    $this->set_up_for_verify();

    return;
}

# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {
    return (
        ['TemplateLoginManager'], ['AllowLoginName'],
        ['HtPasswdManager'], ['TopicUserMapping']
    );
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

    $this->createNewFoswikiSession();

    @FoswikiFntestCase::mails = ();

    return;
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
    my ($meta) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $this->{new_user_wikiname} );
    my $text = $meta->text;
    $meta->finish();
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

    return;
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
    my ($meta) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $this->{new_user_wikiname} );
    my $text = $meta->text;
    $meta->finish();
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

    return;
}

sub verify_userTopicWithoutPMWithForm {
    my $this = shift;

    # Switch off the password manager to force email to be written to user
    # topic
    $Foswiki::cfg{PasswordManager} = 'none';

    # Change the new user topic to include the form
    my ($m) = Foswiki::Func::readTopic( $this->{users_web}, 'NewUserTemplate' );
    $m->text(<<"BODY" );
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
    $m->finish();

    $this->registerAccount();

    my ($meta) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $this->{new_user_wikiname} );
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
    $meta->finish();
    if ($field) {
        $this->assert_str_equals( $this->{new_user_email}, $field->{value} );
    }
    $this->assert_matches( qr/^\s*$/s, $text );

    return;
}

sub verify_userTopicWithPMWithForm {
    my $this = shift;

    # Change the new user topic to include the form
    my ($m) = Foswiki::Func::readTopic( $this->{users_web}, 'NewUserTemplate' );
    $m->text(<<"BODY" );
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
    $m->finish();

    $this->registerAccount();
    my ($meta) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $this->{new_user_wikiname} );
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
    $meta->finish();
    $this->assert_matches( qr/^\s*$/s, $text );

    return;
}

#Register a user, and then verify it
#Assumes the verification code is $this->{session}->{DebugVerificationCode}
#Uses mixed Fwk and Twk prefixes
sub registerVerifyOk {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 1;
    $Foswiki::cfg{Register}{NeedApproval}     = 0;
    my $query = Unit::Request->new(
        {
            'TopicName'     => ['UserRegistration'],
            'Fwk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Fwk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Fwk1LoginName' => [ $this->{new_user_login} ],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Fwk1LastName'  => [ $this->{new_user_sname} ],
            'action'        => ['register']
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "confirm",  $e->{def},      $e->stringify() );
        $this->assert_matches(
            $this->{new_user_email},
            $e->{params}->[0],
            $e->stringify()
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
    };

    my $code = shift || $this->{session}->{DebugVerificationCode};
    $query = Unit::Request->new(
        {
            'code'   => [$code],
            'action' => ['verify']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->{DebugVerificationCode} = $code;
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $code = $this->{session}->{request}->param('code');
    my $data =
      Foswiki::UI::Register::_loadPendingRegistration( $this->{session},
        $code );

    $this->assert_equals( $data->{VerificationCode}, $code );
    $this->assert( $data->{Email} );

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

    # We're sitting with a valid verification code waiting for the next step
    # i.e. need to _verify
    return;
}

#Register a user using Fwk prefix, then give a bad verification code. It should barf.
sub verify_registerBadVerify_Fwk {
    my ( $this, @args ) = @_;
    $this->_registerBadVerify( 'Fwk', @args );

    return;
}

#Register a user using Twk prefix, then give a bad verification code. It should barf.
sub verify_registerBadVerify_Twk {
    my ( $this, @args ) = @_;
    $this->_registerBadVerify( 'Twk', @args );

    return;
}

#Register a user, then give a bad verification code. It should barf.
sub _registerBadVerify {
    my $this = shift;
    my $pfx  = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 1;
    my $query = Unit::Request->new(
        {
            'TopicName'        => ['UserRegistration'],
            "${pfx}1Email"     => [ $this->{new_user_email} ],
            "${pfx}1WikiName"  => [ $this->{new_user_wikiname} ],
            "${pfx}1Name"      => [ $this->{new_user_fullname} ],
            "${pfx}0Comment"   => [''],
            "${pfx}1LoginName" => [ $this->{new_user_login} ],
            "${pfx}1FirstName" => [ $this->{new_user_fname} ],
            "${pfx}1LastName"  => [ $this->{new_user_sname} ],
            'action'           => ['register']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_matches(
            $this->{new_user_email},
            $e->{params}->[0],
            $e->stringify()
        );
        $this->assert_str_equals( "register", $e->{template} );
        $this->assert_str_equals( "confirm",  $e->{def} );
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
    $query = Unit::Request->new(
        {
            'code'   => ["BadCode"],
            'action' => ['verify']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::UI::Register::_verify( $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
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

    return;
}

# Register a user with verification explicitly switched off
# (SUPER's tear_down will take care for re-installing %Foswiki::cfg)
sub verify_registerNoVerifyOk_Twk {
    my ( $this, @args ) = @_;
    $this->_registerNoVerifyOk( 'Twk', @args );

    return;
}

# Register a user with verification explicitly switched off
# (SUPER's tear_down will take care for re-installing %Foswiki::cfg)
sub verify_registerNoVerifyOk_Fwk {
    my ( $this, @args ) = @_;
    $this->_registerNoVerifyOk( 'Fwk', @args );

    return;
}

# Register a user with verification explicitly switched off
# (SUPER's tear_down will take care for re-installing %Foswiki::cfg)
sub _registerNoVerifyOk {
    my $this = shift;
    my $pfx  = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    my $query = Unit::Request->new(
        {
            'TopicName'        => ['UserRegistration'],
            "${pfx}1Email"     => [ $this->{new_user_email} ],
            "${pfx}1WikiName"  => [ $this->{new_user_wikiname} ],
            "${pfx}1Name"      => [ $this->{new_user_fullname} ],
            "${pfx}0Comment"   => [''],
            "${pfx}1LoginName" => [ $this->{new_user_login} ],
            "${pfx}1FirstName" => [ $this->{new_user_fname} ],
            "${pfx}1LastName"  => [ $this->{new_user_sname} ],
            'action'           => ['register']
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "thanks",   $e->{def},      $e->stringify() );
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

    return;
}

# Register a user with a password which is too short - must be rejected
sub verify_rejectShortPassword {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    $Foswiki::cfg{MinPasswordLength}          = 6;
    $Foswiki::cfg{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $Foswiki::cfg{Register}{AllowLoginName}   = 0;
    my $query = Unit::Request->new(
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
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
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

    return;
}

# Register a user with an email which is already in use.
sub verify_rejectDuplicateEmail {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    $Foswiki::cfg{Register}{UniqueEmail}      = 1;

    #$Foswiki::cfg{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $Foswiki::cfg{Register}{AllowLoginName} = 0;
    my $query = Unit::Request->new(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => ['joe@gooddomain.net'],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'Twk1Password'  => ['12345'],
            'Twk1Confirm'   => ['12345'],
            'action'        => ['register'],
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "thanks",   $e->{def},      $e->stringify() );
        $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
        my $done = '';
        foreach my $mail (@FoswikiFnTestCase::mails) {
            if ( $mail =~ /^Subject:.*Registration for/m ) {
                if ( $mail =~ /^To: .*\bjoe\@gooddomain.net\b/m ) {
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

    #  Verify that The 2nd registration is stopped.
    $query = Unit::Request->new(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => ['joe@gooddomain.net'],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} . '2' ],
            'Twk1Name'      => [ $this->{new_user_fullname} . '2' ],
            'Twk0Comment'   => [''],
            'Twk1FirstName' => [ $this->{new_user_fname} . '2' ],
            'Twk1LastName'  => [ $this->{new_user_sname} . '2' ],
            'Twk1Password'  => ['12345678'],
            'Twk1Confirm'   => ['12345678'],
            'action'        => ['register'],
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "dup_email", $e->{def}, $e->stringify() );
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

    return;
}

# preRegister a user with an email which is already in use.
sub verify_rejectDuplicatePendingEmail {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 1;
    $Foswiki::cfg{Register}{UniqueEmail}      = 1;
    $Foswiki::cfg{Sessions}{ExpireAfter}      = '-23600';

    #$Foswiki::cfg{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $Foswiki::cfg{Register}{AllowLoginName} = 0;

    my $query = Unit::Request->new(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => ['joe@dupdomain.net'],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'Twk1Password'  => ['12345'],
            'Twk1Confirm'   => ['12345'],
            'action'        => ['register'],
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "confirm",  $e->{def},      $e->stringify() );
        $this->assert_matches( 'joe@dupdomain.net', $e->{params}->[0],
            $e->stringify() );
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

    #  Verify that The 2nd registration is stopped.
    $query = Unit::Request->new(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => ['joe@dupdomain.net'],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} . '2' ],
            'Twk1Name'      => [ $this->{new_user_fullname} . '2' ],
            'Twk0Comment'   => [''],
            'Twk1FirstName' => [ $this->{new_user_fname} . '2' ],
            'Twk1LastName'  => [ $this->{new_user_sname} . '2' ],
            'Twk1Password'  => ['12345678'],
            'Twk1Confirm'   => ['12345678'],
            'action'        => ['register'],
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");

    #$this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $Foswiki::cfg{Register}{NeedVerification} = 1;
    $Foswiki::cfg{Register}{UniqueEmail}      = 1;
    $Foswiki::cfg{Sessions}{ExpireAfter}      = '-23600';

    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "dup_email", $e->{def}, $e->stringify() );
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

    return;
}

# Register a user with an email which is filtered by EmailFilter
sub verify_rejectFilteredEmail {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    $Foswiki::cfg{Register}{UniqueEmail}      = 0;

    # Include a trailing and other whitespace - a common config error
    $Foswiki::cfg{Register}{EmailFilter} =
      '@(?!( gooddomain\.com | gooddomain\.net )$) ';
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';
    $Foswiki::cfg{Register}{AllowLoginName} = 0;
    my $query = Unit::Request->new(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => [ $this->{new_user_email} ],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'Twk1Password'  => ['12345'],
            'Twk1Confirm'   => ['12345'],
            'action'        => ['register'],
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "rej_email", $e->{def}, $e->stringify() );
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

    #  Also verify that a good domain makes it through
    $query = Unit::Request->new(
        {
            'TopicName'     => ['UserRegistration'],
            'Twk1Email'     => ['joe@gooddomain.net'],
            'Twk1WikiName'  => [ $this->{new_user_wikiname} ],
            'Twk1Name'      => [ $this->{new_user_fullname} ],
            'Twk0Comment'   => [''],
            'Twk1FirstName' => [ $this->{new_user_fname} ],
            'Twk1LastName'  => [ $this->{new_user_sname} ],
            'Twk1Password'  => ['12345678'],
            'Twk1Confirm'   => ['12345678'],
            'action'        => ['register'],
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "thanks",   $e->{def},      $e->stringify() );
        $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
        my $done = '';
        foreach my $mail (@FoswikiFnTestCase::mails) {
            if ( $mail =~ /^Subject:.*Registration for/m ) {
                if ( $mail =~ /^To: .*\bjoe\@gooddomain.net\b/m ) {
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

    return;
}

# Register a user with invalid characters in a field - like < html
sub verify_rejectEvilContent {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    $Foswiki::cfg{MinPasswordLength}          = 6;
    $Foswiki::cfg{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $Foswiki::cfg{Register}{AllowLoginName}   = 0;
    my $query = Unit::Request->new(
        {
            'TopicName'        => ['UserRegistration'],
            'Twk1Email'        => [ $this->{new_user_email} ],
            'Twk1WikiName'     => [ $this->{new_user_wikiname} ],
            'Twk1Name'         => [ $this->{new_user_fullname} ],
            'Twk0Comment'      => ['<blah>'],
            'Twk1FirstName'    => [ $this->{new_user_fname} ],
            'Twk1LastName'     => [ $this->{new_user_sname} ],
            'Twk1Password'     => ['123<><>aaa'],
            'Twk1Confirm'      => ['123<><>aaa'],
            'Twk0Organization' => ['<script>Bad stuff</script>'],
            'action'           => ['register'],
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "200", $e->{status}, $e->stringify() );
        $this->assert_matches(
qr/.*Comment: &#60;blah&#62;.*Organization: &#60;script&#62;Bad stuff&#60;\/script&#62;/ms,
            $FoswikiFnTestCase::mails[0]
        );

        my ($meta) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
            $this->{new_user_wikiname} );
        my $text = $meta->text;
        $meta->finish();
        $this->assert_matches(
qr/.*Comment: &#60;blah&#62;.*Organization: &#60;script&#62;Bad stuff&#60;\/script&#62;/ms,
            $text
        );

        return;

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

    return;
}

# Register a user with a password which is too short
sub verify_shortPassword {
    my $this = shift;
    $Foswiki::cfg{Register}{NeedVerification} = 0;
    $Foswiki::cfg{MinPasswordLength}          = 6;
    $Foswiki::cfg{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $Foswiki::cfg{Register}{AllowLoginName}   = 1;
    my $query = Unit::Request->new(
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
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';

        my $cUID =
          $this->{session}->{users}
          ->getCanonicalUserID( $this->{new_user_login} );
        $this->assert( $this->{session}->{users}->userExists($cUID),
            "new user created" );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
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

    return;
}

# Purpose:  Test behaviour of duplicate activation (Item3105)
# Verifies: Most of the things which are verified during normal
#           registration with Verification, plus Oops for
#           duplicate verification
sub verify_duplicateActivation {
    my $this = shift;

    # Start similar to registration with verification
    $Foswiki::cfg{Register}{NeedVerification} = 1;
    my $query = Unit::Request->new(
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
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "confirm",  $e->{def},      $e->stringify() );
        $this->assert_matches(
            $this->{new_user_email},
            $e->{params}->[0],
            $e->stringify()
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
    };

    # Read the verification code before finish()'ing the session
    my $debugVerificationCode = $this->{session}->{DebugVerificationCode};

    # For verification process everything including finish(), so don't just
    # call verifyEmails
    my $code = shift || $debugVerificationCode;
    $query = Unit::Request->new(
        {
            'code'   => [$code],
            'action' => ['verify'],
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "thanks",   $e->{def},      $e->stringify() );
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

    # and now for something completely different: Do it all over again
    @FoswikiFnTestCase::mails = ();
    $query                    = Unit::Request->new(
        {
            'code'   => [$code],
            'action' => ['verify'],
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );
    $this->{session}->net->setMailHandler( \&sentMail );
    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
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

    return;
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

    my $query = Unit::Request->new(
        {
            'LoginName' => [ $this->{new_user_login} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/WebHome' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $RP_UI_FN, $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "reset_ok", $e->{def},      $e->stringify() );
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

    return;
}

sub verify_resetPasswordNoSuchUser {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = Unit::Request->new(
        {
            'LoginName' => [ $this->{new_user_wikiname} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/.' . $this->{users_web} . '/WebHome' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $RP_UI_FN, $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "reset_bad", $e->{def}, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    return;
}

sub verify_resetPasswordNeedPrivilegeForMultipleReset {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = Unit::Request->new(
        {
            'LoginName' =>
              [ $this->{test_user_wikiname}, $this->{new_user_wikiname} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/.' . $this->{users_web} . '/WebHome' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $RP_UI_FN, $this->{session} );
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

    return;
}

# This test make sure that the system can't reset passwords
# for a user currently absent from .htpasswd
sub verify_resetPasswordNoPassword {
    my $this = shift;

    $this->registerAccount();

    my $query = Unit::Request->new(
        {
            'LoginName' => [ $this->{new_user_wikiname} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/WebHome' );
    my $fh;
    open( $fh, ">", $Foswiki::cfg{Htpasswd}{FileName} ) || die $!;
    close($fh) || die $!;

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $RP_UI_FN, $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
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

    return;
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
    $this->assert( open( my $F, '>', $file ) );
    print $F Data::Dumper->Dump( [ $regSave, undef ], [ 'data', 'form' ] );
    $this->assert( close $F );

    my $result2 =
      Foswiki::UI::Register::_loadPendingRegistration( $this->{session},
        "GitWit.0" );
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

    return;
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

    return;
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

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin} );
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

    return;
}

=pod

  call this if you want to make spaces and \ns visible

=cut

sub visible {
    my ($a) = @_;
    return $a;

    # PH commented this dead code Item11431
    #$a =~ s/\n/NL/g;
    #$a =~ s/\r/CR/g;
    #$a =~ s/ /SP/g;
    #
    #return $a;
}

sub verify_disabled_registration {
    my $this = shift;
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 0;
    $Foswiki::cfg{Register}{NeedVerification}          = 0;
    my $query = Unit::Request->new(
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
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
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

    return;
}

sub test_PendingRegistrationManualCleanup {
    my $this = shift;

    $Foswiki::cfg{Register}{AllowLoginName}            = 0;
    $Foswiki::cfg{Register}{NeedVerification}          = 1;
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{Register}{UniqueEmail}               = 0;
    $Foswiki::cfg{Sessions}{ExpireAfter}               = '-600';
    $Foswiki::cfg{LoginManager}    = 'Foswiki::LoginManager::TemplateLogin';
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';
    my $query = Unit::Request->new(
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
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "confirm",  $e->{def},      $e->stringify() );
        $this->assert_matches(
            $this->{new_user_email},
            $e->{params}->[0],
            $e->stringify()
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
    };

    my $code = shift || $this->{session}->{DebugVerificationCode};

    my $file  = "$Foswiki::cfg{WorkingDir}/registration_approvals/$code";
    my $mtime = ( time() - 610 );

    utime( $mtime, $mtime, $file )
      || $this->assert( 0, "couldn't touch $file: $!" );

    Foswiki::UI::Register::expirePendingRegistrations();
    $this->assert( !( -f $file ), 'expired registration file not removed' );
}

sub test_PendingRegistrationAutoCleanup {
    my $this = shift;

    $Foswiki::cfg{Register}{AllowLoginName}            = 0;
    $Foswiki::cfg{Register}{NeedVerification}          = 1;
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{Register}{UniqueEmail}               = 0;
    $Foswiki::cfg{Sessions}{ExpireAfter}               = 600;
    $Foswiki::cfg{LoginManager}    = 'Foswiki::LoginManager::TemplateLogin';
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';
    my $query = Unit::Request->new(
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
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "confirm",  $e->{def},      $e->stringify() );
        $this->assert_matches(
            $this->{new_user_email},
            $e->{params}->[0],
            $e->stringify()
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
    };

    my $code = shift || $this->{session}->{DebugVerificationCode};

    my $file  = "$Foswiki::cfg{WorkingDir}/registration_approvals/$code";
    my $mtime = ( time() - 611 );

    utime( $mtime, $mtime, $file )
      || $this->assert( 0, "couldn't touch $file: $!" );

    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "confirm",  $e->{def},      $e->stringify() );
        $this->assert_matches(
            $this->{new_user_email},
            $e->{params}->[0],
            $e->stringify()
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
    };

    $this->assert( !( -f $file ), 'expired registration file not removed' );
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
    $Foswiki::cfg{Register}{NeedApproval}              = 0;
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{LoginManager}    = 'Foswiki::LoginManager::TemplateLogin';
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';
    my $query = Unit::Request->new(
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
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "thanks",   $e->{def},      $e->stringify() );
        $this->assert_matches(
            $this->{new_user_email},
            $e->{params}->[0],
            $e->stringify()
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
    };

    return;
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
    my $query = Unit::Request->new(
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
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $this->assert( open( my $fh, "<", $Foswiki::cfg{Htpasswd}{FileName} ) );
    my ( $before, $stuff );
    {
        local $/ = undef;
        $before = <$fh>;
    }
    $this->assert( close($fh) );
    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        use strict 'refs';
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "problem_adding", $e->{def},
            $e->stringify() );

        # Verify that they have not been added to .htpasswd
        $this->assert( open( $fh, "<", $Foswiki::cfg{Htpasswd}{FileName} ) );
        {
            local $/ = undef;
            $stuff = <$fh>;
        }
        $this->assert( close($fh) );
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

    return;
}

################################################################################
################################ RESET EMAIL TESTS ##########################

#test for TWikibug:Item3400
sub verify_resetPassword_NoWikiUsersEntry {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $this->registerAccount();

    #Remove the WikiUsers entry - by deleting it :)
    my ($from) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{UsersTopicName} );
    my ($to) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{UsersTopicName} . 'DELETED' );
    $from->move($to);
    $from->finish();
    $to->finish();

    #force a reload to unload existing user caches, and then restart as guest
    $this->createNewFoswikiSession();

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

    my $query = Unit::Request->new(
        {
            'LoginName' => [ $this->{new_user_login} ],
            'TopicName' => ['ResetPassword'],
            'action'    => ['resetPassword']
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/WebHome' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey( register => $RP_UI_FN, $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "reset_ok", $e->{def},      $e->stringify() );
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

    return;
}

sub registerUserException {
    my ( $this, $loginname, $forename, $surname, $email ) = @_;

    my $query = Unit::Request->new(
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

    $this->createNewFoswikiSession( undef, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    my $exception;
    try {
        no strict 'refs';
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
        no strict 'refs';
    }
    catch Foswiki::OopsException with {
        $exception = shift;
        if (   ( "register" eq $exception->{template} )
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
        $exception->{template} = "died";
    }
    otherwise {
        $exception = new Error::Simple();
        $exception->{template} = "OK";
    };

    # Reload caches
    my $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );
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
    $this->assert_equals( 'register', $ret->{template},
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
    $this->assert_equals( 'register', $ret->{template},
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
    $this->assert_equals( 'register', $ret->{template},
        "question logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->{def},
        "question logon should fail" );
    $this->assert_equals(
        'question?',
        ${ $ret->{params} }[0],
        "question logon should fail"
    );

    return;
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
    $this->assert_equals( 'register', $ret->{template},
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
    $this->assert_equals( 'register', $ret->{template},
        "question logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->{def},
        "question logon should fail" );
    $this->assert_equals(
        'question?',
        ${ $ret->{params} }[0],
        "question logon should fail"
    );

    $Foswiki::cfg{LoginNameFilterIn} = $oldCfg;

    return;
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

    return;
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
    $this->assert_not_null( $ret, "@ in wikiname should fail" );
    $this->assert_equals( 'register', $ret->{template},
        "@ in wikiname should oops: " . $ret->stringify );
    $this->assert_equals( 'bad_wikiname', $ret->{def},
        "@ in wikiname should fail" );
    $this->assert_equals(
        'Asdf@Poiu',
        ${ $ret->{params} }[0],
        "@ in wikiname should fail"
    );

    $ret = $this->registerUserException( 'asdf3', 'Mac Asdf', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "space in name should fail" );
    $this->assert_equals( 'register', $ret->{template},
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
    $this->assert_equals( 'register', $ret->{template},
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
    $this->assert_equals( 'register', $ret->{template},
        "question logon should fail" );
    $this->assert_equals( 'bad_wikiname', $ret->{def},
        "question logon should fail" );
    $this->assert_equals(
        'Asdf2Po?iu',
        ${ $ret->{params} }[0],
        "question logon should fail"
    );

    return;
}

sub verify_registerVerifyOKApproved {
    my $this = shift;

    $Foswiki::cfg{Register}{NeedVerification} = 1;

    $this->registerVerifyOk();

    # We're sitting with a valid registration code waiting for the next step
    # need to verify that we issue an approval.
    my $query = Unit::Request->new(
        {
            'code'   => [ $this->{session}->{request}->param('code') ],
            'action' => ['verify']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $Foswiki::cfg{Register}{NeedApproval} = 1;
    $Foswiki::cfg{Register}{Approvers}    = 'ScumBag';
    try {
        Foswiki::UI::Register::_verify( $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "approve", $e->{def} );
        $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
        foreach my $mail (@FoswikiFnTestCase::mails) {
            $this->assert_matches(
                qr/^Subject: .* registration approval required/m, $mail );
            $this->assert_matches( qr/^To: ScumBag <scumbag\@example.com>/m,
                $mail );
            $this->assert_matches( qr/^\s*\* Name: Walter Pigeon/m, $mail );
            $this->assert_matches(
                qr/^\s*\* Email: kakapo\@ground.dwelling.parrot.net/m, $mail );
            $this->assert(
                $mail =~
                  /http:.*register\?action=approve;code=(.*?);referee=(\w*)$/m,
                $mail
            );
            $this->assert_equals( $this->{session}->{DebugVerificationCode},
                $1 );
        }
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

    $query = Unit::Request->new(
        {
            'code'   => [ $this->{session}->{DebugVerificationCode} ],
            'action' => ['approve']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );

    # Make sure we get bounced unless we are logged in
    try {
        Foswiki::UI::Register::_approve( $this->{session} );
    }
    catch Foswiki::AccessControlException with {} otherwise {
        $this->assert(0);
    };

    $this->createNewFoswikiSession( 'scumbag', $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::UI::Register::_approve( $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;

        # verify that we are sending mail to the registrant
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "rego_approved", $e->{def} );

       # Make sure the confirmations are sent; one to the user, one to the admin
        $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
        foreach my $mail (@FoswikiFnTestCase::mails) {
            if ( $mail =~ /^To: Wiki/m ) {
                $this->assert_matches( qr/^To: Wiki Administrator/m, $mail );
            }
            else {
                $this->assert_matches( qr/^To: Walter Pigeon/m, $mail );
            }
            $this->assert_matches(
                qr/^Subject: .* Registration for WalterPigeon/m, $mail );
        }
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

    return;
}

sub verify_registerVerifyOKDisapproved {
    my $this = shift;

    $Foswiki::cfg{Register}{NeedVerification} = 1;

    $this->registerVerifyOk();

    # We're sitting with a valid registration code waiting for the next step
    # need to verify that we issue an approval.
    my $query = Unit::Request->new(
        {
            'code'   => [ $this->{session}->{request}->param('code') ],
            'action' => ['verify']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $Foswiki::cfg{Register}{NeedApproval} = 1;
    $Foswiki::cfg{Register}{Approvers}    = 'ScumBag';
    try {
        Foswiki::UI::Register::_verify( $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "approve", $e->{def} );
        $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
        foreach my $mail (@FoswikiFnTestCase::mails) {
            $this->assert_matches(
                qr/^Subject: .* registration approval required/m, $mail );
            $this->assert_matches( qr/^To: ScumBag <scumbag\@example.com>/m,
                $mail );
            $this->assert_matches( qr/^\s*\* Name: Walter Pigeon/m, $mail );
            $this->assert_matches(
                qr/^\s*\* Email: kakapo\@ground.dwelling.parrot.net/m, $mail );
            $this->assert(
                $mail =~
                  /http:.*register\?action=approve;code=(.*?);referee=(\w*)$/m,
                $mail
            );
            $this->assert_equals( $this->{session}->{DebugVerificationCode},
                $1 );
        }
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

    $query = Unit::Request->new(
        {
            'code'    => [ $this->{session}->{DebugVerificationCode} ],
            'action'  => ['disapprove'],
            'referee' => ['TheBoss']
        }
    );
    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( 'scumbag', $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::UI::Register::_disapprove( $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;

        # verify that we are sending mail to the registrant
        $this->assert_str_equals( "register", $e->{template}, $e->stringify() );
        $this->assert_str_equals( "rego_denied", $e->{def} );

        # Make sure no mails are sent (yet)
        $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
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
        !$this->{session}->topicExists(
            $Foswiki::cfg{UsersWebName},
            $this->{new_user_wikiname}
        )
    );

    return;
}

1;
