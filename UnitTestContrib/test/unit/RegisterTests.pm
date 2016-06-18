#
use v5.14;

package Foswiki::Exception::RTInfo;

use Moo;
extends qw(Foswiki::Exception);

has template => ( is => 'rw', );

package RegisterTests;
use diagnostics;

# Tests not implemented:
#notest_registerTwiceWikiName
#notest_registerIllegitimateBypassApprove
#notest_registerVerifyAndFinish
#test_DoubleRegistration (loginname already used)

#Uncomment to isolate
#our @TESTS = qw(notest_registerVerifyOk); #notest_UnregisteredUser);

use Foswiki::UI::Register();
use Data::Dumper;
use FileHandle();
use File::Copy();
use File::Path();
use Carp();
use Cwd();
use Try::Tiny;

# Note that the FoswikiFnTestCase needs to use the registration code to work,
# so this is a bit arse before tit. However we need some pre-registered users
# for this to work sensibly, so we just have to bite the bullet.
use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

has regUI => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub {
        return $_[0]->create('Foswiki::UI::Register');
    },
);

my $systemWeb = "TemporaryRegisterTestsSystemWeb";

around BUILDARGS => sub {
    my $orig = shift;
    return $orig->( @_, testSuite => 'Registration' );
};

my $REG_TMPL;

sub skip {
    my ( $this, $test ) = @_;

    my %skip_tests = (

'RegisterTests::verify_Default_LoginNameFilterIn_ApacheLoginManager_DontAllowLoginName_HtPasswdManager_TopicUserMapping'
          => 'LoginName Filtering not applicable if LoginName not allowed',
'RegisterTests::verify_Default_LoginNameFilterIn_NoLoginManager_DontAllowLoginName_HtPasswdManager_TopicUserMapping'
          => 'LoginName Filtering not applicable if LoginName not allowed',
'RegisterTests::verify_Default_LoginNameFilterIn_TemplateLoginManager_DontAllowLoginName_HtPasswdManager_TopicUserMapping'
          => 'LoginName Filtering not applicable if LoginName not allowed',
'RegisterTests::verify_Modified_LoginNameFilterIn_At_ApacheLoginManager_DontAllowLoginName_HtPasswdManager_TopicUserMapping'
          => 'LoginName Filtering not applicable if LoginName not allowed',
'RegisterTests::verify_Modified_LoginNameFilterIn_At_NoLoginManager_DontAllowLoginName_HtPasswdManager_TopicUserMapping'
          => 'LoginName Filtering not applicable if LoginName not allowed',
'RegisterTests::verify_Modified_LoginNameFilterIn_At_TemplateLoginManager_DontAllowLoginName_HtPasswdManager_TopicUserMapping'
          => 'LoginName Filtering not applicable if LoginName not allowed',

    );

    return $skip_tests{$test}
      if ( defined $test && defined $skip_tests{$test} );

    return $this->skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                'RegisterTests::test_PendingRegistrationManualCleanup' =>
                  'Registration cleanup is Foswiki 1.2+ only',
                'RegisterTests::test_PendingRegistrationAutoCleanup' =>
                  'Registration cleanup is Foswiki 1.2+ only',
                'RegisterTests::verify_registerVerifyOKApproved', =>
                  'Registration approval is Foswiki 1.2+ only',
                'RegisterTests::verify_registerVerifyOKDisapproved', =>
                  'Registration approval is Foswiki 1.2+ only',
            }
        }
    );
}

has new_user_login    => ( is => 'rw', );
has new_user_fname    => ( is => 'rw', );
has new_user_sname    => ( is => 'rw', );
has new_user_email    => ( is => 'rw', );
has new_user_wikiname => ( is => 'rw', );
has new_user_fullname => ( is => 'rw', );

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    my $cfgData = $this->app->cfg->data;

    $REG_TMPL =
      ( $this->check_dependency('Foswiki,<,1.2') ) ? 'attention' : 'register';

    $this->new_user_login('sqwauk');
    $this->new_user_fname('Walter');
    $this->new_user_sname('Pigeon');
    $this->new_user_email('kakapo@ground.dwelling.parrot.net');
    $this->new_user_wikiname( $this->new_user_fname . $this->new_user_sname );
    $this->new_user_fullname(
        $this->new_user_fname . " " . $this->new_user_sname );

    try {
        my ($topicObject) =
          Foswiki::Func::readTopic( $this->users_web, 'NewUserTemplate' );
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

        Foswiki::Func::saveTopic( $this->users_web, 'AltUserTemplate', undef,
            <<'EOF2' );
%NOP{Ignore this}%
Alternate user template
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
%WIKIUSERNAME%
%WIKINAME%
%USERNAME%
AFTER
EOF2

        # Make the test current user an admin; we will only use
        # them where necessary (e.g. for bulk registration)
        undef $topicObject;
        ($topicObject) =
          Foswiki::Func::readTopic( $this->users_web,
            $cfgData->{SuperAdminGroup} );
        my $test_user_wikiname = $this->test_user_wikiname;
        $topicObject->text(<<"EOF");
   * Set GROUP = $test_user_wikiname
EOF
        $topicObject->save();

        undef $topicObject;
        ($topicObject) =
          Foswiki::Func::readTopic( $this->users_web, 'UserForm' );
        $topicObject->text(<<'EOF');
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* |
| <nop>FirstName | text | 40 | | |
| <nop>LastName | text | 40 | | |
| Email | text | 40 | | H |
| Name | text | 40 | | H |
| Comment | textarea | 50x6 | | |
EOF
        $topicObject->save();
        undef $topicObject;

        my $webObject =
          $this->populateNewWeb( $systemWeb, $cfgData->{SystemWebName} );
        undef $webObject;
        $cfgData->{SystemWebName} = $systemWeb;
        $cfgData->{EnableEmail}   = 1;

    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    };

    @FoswikiFnTestCase::mails = ();

    return;
};

around loadExtraConfig => sub {
    my $orig = shift;
    my $this = shift;

    $this->clear_regUI;

    $orig->( $this, @_ );

    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{UniqueEmail}      = 0;
    $cfgData->{Register}{EmailFilter}      = '';
    $cfgData->{Register}{NeedVerification} = 0;
    $cfgData->{Register}{NeedApproval}     = 0;
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    $this->removeWebFixture($systemWeb);

    $orig->( $this, @_ );

    return;
};

around createNewFoswikiApp => sub {
    my $orig = shift;
    my $this = shift;

    my $newApp = $orig->( $this, @_ );

    $this->clear_regUI;

    return $newApp;
};

# Foswiki::App handleRequestException callback function.
sub _cbHRE {
    my $obj  = shift;
    my %args = @_;
    $args{params}{exception}->rethrow;
}

# fixture
sub registerAccount {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    $this->registerVerifyOk();

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'   => [ $this->app->heap->{DebugVerificationCode} ],
                'action' => ['verify']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                user      => $cfgData->{DefaultUserLogin},
            },
        },
    );
    $cfgData = $this->app->cfg->data;

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->regUI->_action_verify;
    }
    catch {
        my $e = $_;
        if ( ref($e) ) {
            if ( $e->isa('Foswiki::OopsException') ) {
                $this->assert_str_equals( $REG_TMPL, $e->template,
                    $e->stringify() );
                $this->assert_str_equals( "thanks", $e->def, $e->stringify() );
                $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
                my $done = '';
                foreach my $mail (@FoswikiFnTestCase::mails) {
                    if ( $mail->header('Subject') =~ m/Registration for/m ) {
                        my $new_user_email = $this->new_user_email;
                        if ( $mail->header('To') =~ m/\b$new_user_email\b/m ) {
                            $this->assert( !$done, $done . "\n---------\n" );
                            $done = $mail;
                        }
                        else {
                            $this->assert_matches(
qr/$cfgData->{WebMasterName} <$cfgData->{WebMasterEmail}>/,
                                $mail->header('To')
                            );
                        }
                    }
                    else {
                        $this->assert( 0, $mail->as_string() );
                    }
                }
                $this->assert($done);
                @FoswikiFnTestCase::mails = ();
            }
            else {
                $e->rethrow;
            }
        }
        else {
            Foswiki::Exception::Fatal->throw(
                text => "expected an oops redirect but received: " . $e );
        }
    };

    $this->assert(
        $this->app->store->topicExists(
            $cfgData->{UsersWebName},
            $this->new_user_wikiname
        )
    );

    return;
}
###################################
#verify tests

sub AllowLoginName {
    my $this = shift;
    $this->app->cfg->data->{Register}{AllowLoginName} = 1;

    return;
}

sub DontAllowLoginName {
    my $this = shift;
    $this->app->cfg->data->{Register}{AllowLoginName} = 0;
    $this->new_user_login( $this->new_user_wikiname );

    #$this->test_user_login( $this->test_user_wikiname );

    return;
}

sub TemplateLoginManager {
    my $this = shift;
    $this->app->cfg->data->{LoginManager} =
      'Foswiki::LoginManager::TemplateLogin';

    return;
}

sub ApacheLoginManager {
    my $this = shift;
    $this->app->cfg->data->{LoginManager} =
      'Foswiki::LoginManager::ApacheLogin';

    return;
}

sub NoLoginManager {
    my $this = shift;
    $this->app->cfg->data->{LoginManager} = 'Foswiki::LoginManager';

    return;
}

sub HtPasswdManager {
    my $this = shift;
    $this->app->cfg->data->{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

    return;
}

sub NonePasswdManager {
    my $this = shift;
    $this->app->cfg->data->{PasswordManager} = 'none';

    return;
}

sub BaseUserMapping {
    my $this = shift;
    $this->app->cfg->data->{UserMappingManager} =
      'Foswiki::Users::BaseUserMapping';
    $this->set_up_for_verify();

    return;
}

sub TopicUserMapping {
    my $this = shift;
    $this->app->cfg->data->{UserMappingManager} =
      'Foswiki::Users::TopicUserMapping';
    $this->set_up_for_verify();

    return;
}

# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {

    #    return (
    #        ['TemplateLoginManager'], ['AllowLoginName'],
    #        ['HtPasswdManager'], ['TopicUserMapping']
    #    );
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

    $this->createNewFoswikiApp;

    @FoswikiFntestCase::mails = ();

    return;
}

###################################
sub verify_userTopicWithPMWithoutForm {
    my $this    = shift;
    my $cfgData = $this->app->cfg->data;
    $this->assert(
        !$this->app->store->topicExists(
            $cfgData->{UsersWebName},
            $this->new_user_wikiname
        ),
        "cannot re-register user who's topic exists"
    );
    $this->registerAccount();
    my ($meta) = Foswiki::Func::readTopic( $cfgData->{UsersWebName},
        $this->new_user_wikiname );
    my $text = $meta->text;
    my (
        $new_user_fname,    $new_user_sname,
        $new_user_fullname, $new_user_wikiname
      )
      = (
        $this->new_user_fname,    $this->new_user_sname,
        $this->new_user_fullname, $this->new_user_wikiname
      );
    undef $meta;
    $this->assert( $text !~ /Ignore this%/, $text );
    $this->assert( $text =~ s/But not this//,                         $text );
    $this->assert( $text =~ s/^\s*\* First Name: $new_user_fname$//m, $text );
    $this->assert( $text =~ s/^\s*\* Last Name: $new_user_sname$//m,  $text );
    $this->assert( $text =~ s/^\s*\* Comment:\s*$//m,                 $text );
    $this->assert( $text =~ s/^\s*\* Name: $new_user_fullname$//m,    $text );
    $this->assert( $text =~ s/$cfgData->{UsersWebName}\.$new_user_wikiname//,
        $text );
    $this->assert( $text =~ s/$new_user_wikiname//, $text );
    $this->assert_matches( qr/\s*AFTER\s*/, $text );

    return;
}

sub verify_userTopicWithoutPMWithoutForm {
    my $this = shift;

    # Switch off the password manager to force email to be written to user
    # topic
    my $cfgData = $this->app->cfg->data;
    $cfgData->{PasswordManager} = 'none';
    $this->assert(
        !$this->app->store->topicExists(
            $cfgData->{UsersWebName},
            $this->new_user_wikiname
        ),
        "cannot re-register user who's topic exists"
    );
    $this->registerAccount();
    my ($meta) = Foswiki::Func::readTopic( $cfgData->{UsersWebName},
        $this->new_user_wikiname );
    my $text = $meta->text;
    undef $meta;
    my (
        $new_user_fname,    $new_user_sname, $new_user_fullname,
        $new_user_wikiname, $new_user_email
      )
      = (
        $this->new_user_fname,    $this->new_user_sname,
        $this->new_user_fullname, $this->new_user_wikiname,
        $this->new_user_email
      );
    $this->assert( $text !~ /Ignore this%/, $text );
    $this->assert( $text =~ s/But not this//,                         $text );
    $this->assert( $text =~ s/^\s*\* First Name: $new_user_fname$//m, $text );
    $this->assert( $text =~ s/^\s*\* Last Name: $new_user_sname$//m,  $text );
    $this->assert( $text =~ s/^\s*\* Comment:\s*$//m,                 $text );
    $this->assert( $text =~ s/^\s*\* Name: $new_user_fullname$//m,    $text );
    $this->assert( $text =~ s/^\s*\* Email: $new_user_email$//m,      $text );
    $this->assert( $text =~ s/$cfgData->{UsersWebName}\.$new_user_wikiname//,
        $text );
    $this->assert( $text =~ s/$new_user_wikiname//, $text );
    $this->assert_matches( qr/\s*AFTER\s*/, $text );

    return;
}

sub verify_userTopicWithoutPMWithForm {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    # Switch off the password manager to force email to be written to user
    # topic
    $cfgData->{PasswordManager} = 'none';

    # Change the new user topic to include the form
    my ($m) = Foswiki::Func::readTopic( $this->users_web, 'NewUserTemplate' );
    $m->text(<<"BODY" );
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
BODY
    $m->put( 'FORM', { name => $this->users_web . ".UserForm" } );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'FirstName',
            title => '<nop>FirstName',
            value => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'LastName',
            title => '<nop>LastName',
            value => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'Email',
            title => 'Email',
            value => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'Name',
            title => 'Name',
            value => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'Comment',
            title => 'Comment',
            value => '',
        }
    );

    $m->save();
    undef $m;

    $this->registerAccount();

    my ($meta) =
      Foswiki::Func::readTopic( $this->app->cfg->data->{UsersWebName},
        $this->new_user_wikiname );
    my $text = $meta->text;

    my $field = $meta->get( 'FIELD', 'FirstName' );
    $this->assert($field);
    $this->assert_str_equals( $this->new_user_fname, $field->{value} );

    $field = $meta->get( 'FIELD', 'LastName' );
    $this->assert($field);
    $this->assert_str_equals( $this->new_user_sname, $field->{value} );

    $field = $meta->get( 'FIELD', 'Comment' );
    $this->assert($field);
    $this->assert_str_equals( '', $field->{value} );

    $field = $meta->get( 'FIELD', 'Email' );
    undef $meta;
    if ($field) {
        $this->assert_str_equals( $this->new_user_email, $field->{value} );
    }
    $this->assert_matches( qr/^\s*$/s, $text );

    return;
}

sub verify_userTopicWithPMWithForm {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    # Change the new user topic to include the form
    my ($m) = Foswiki::Func::readTopic( $this->users_web, 'NewUserTemplate' );
    $m->text(<<"BODY" );
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
BODY
    $m->put( 'FORM', { name => $this->users_web . ".UserForm" } );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'FirstName',
            title => '<nop>FirstName',
            value => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'LastName',
            title => '<nop>LastName',
            value => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'Email',
            title => 'Email',
            value => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'Name',
            title => 'Name',
            value => '',
        }
    );
    $m->putKeyed(
        'FIELD',
        {
            name  => 'Comment',
            title => 'Comment',
            value => '',
        }
    );
    $m->save();
    undef $m;

    $this->registerAccount();
    my ($meta) = Foswiki::Func::readTopic( $cfgData->{UsersWebName},
        $this->new_user_wikiname );
    my $text = $meta->text;
    $this->assert_not_null( $meta->get('FORM') );
    $this->assert_str_equals( $this->users_web . ".UserForm",
        $meta->get('FORM')->{name} );
    $this->assert_str_equals( $this->new_user_fname,
        $meta->get( 'FIELD', 'FirstName' )->{value} );
    $this->assert_str_equals( $this->new_user_sname,
        $meta->get( 'FIELD', 'LastName' )->{value} );
    $this->assert_str_equals( '', $meta->get( 'FIELD', 'Comment' )->{value} );
    $this->assert_str_equals( '', $meta->get( 'FIELD', 'Email' )->{value} );
    undef $meta;
    $this->assert_matches( qr/^\s*$/s, $text );

    return;
}

#Register a user, and then verify it
#Assumes the verification code is $this->app->heap->{DebugVerificationCode}
#Uses mixed Fwk and Twk prefixes
sub registerVerifyOk {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{NeedVerification} = 1;
    $cfgData->{Register}{NeedApproval}     = 0;
    my $params = {
        'TopicName'     => ['UserRegistration'],
        'Fwk1Email'     => [ $this->new_user_email ],
        'Twk1WikiName'  => [ $this->new_user_wikiname ],
        'Fwk1Name'      => [ $this->new_user_fullname ],
        'Twk0Comment'   => [''],
        'Twk1FirstName' => [ $this->new_user_fname ],
        'Fwk1LastName'  => [ $this->new_user_sname ],
        'action'        => ['register']
    };

    if ( $cfgData->{Register}{AllowLoginName} ) {
        $params->{"Twk1LoginName"} = $this->new_user_login;
    }

    $this->createNewFoswikiApp(
        requestParams => { initializer => $params, },
        engineParams  => {
            initialAttributes => {
                user      => $cfgData->{DefaultUserLogin},
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $cfgData = $this->app->cfg->data;
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub {
                $this->app->handleRequest;
            },
        );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "confirm", $e->def, $e->stringify() );
            $this->assert_matches( $this->new_user_email, $e->params->[0],
                $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    my $code = shift || $this->app->heap->{DebugVerificationCode};

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'   => [$code],
                'action' => ['verify']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                user      => $cfgData->{DefaultUserLogin},
            },
        },
    );

    $cfgData = $this->app->cfg->data;
    $this->app->heap->{DebugVerificationCode} = $code;
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $code = $this->app->request->param('code');
    my $data = $this->regUI->_loadPendingRegistration($code);

    $this->assert_equals( $data->{VerificationCode}, $code );
    $this->assert( $data->{Email} );

    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $done = '';
    foreach my $mail (@FoswikiFnTestCase::mails) {
        my $body = $mail->body();
        if ( $body =~ m/Your verification code is /m ) {
            $this->assert( !$done, $done . "\n---------\n" . $body );
            $done = $body;
        }

        #else {
        #    $this->assert( 0, $mail );
        #}
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
    my $this    = shift;
    my $pfx     = shift;
    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{NeedVerification} = 1;
    my $params = {
        'TopicName'        => ['UserRegistration'],
        "${pfx}1Email"     => [ $this->new_user_email ],
        "${pfx}1WikiName"  => [ $this->new_user_wikiname ],
        "${pfx}1Name"      => [ $this->new_user_fullname ],
        "${pfx}0Comment"   => [''],
        "${pfx}1FirstName" => [ $this->new_user_fname ],
        "${pfx}1LastName"  => [ $this->new_user_sname ],
        'action'           => ['register']
    };

    if ( $cfgData->{Register}{AllowLoginName} ) {
        $params->{"Twk1LoginName"} = $this->new_user_login;
    }

    $this->createNewFoswikiApp(
        requestParams => { initializer => $params, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                user      => $cfgData->{DefaultUserLogin},
                action    => 'register',
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $cfgData = $this->app->cfg->data;

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_matches( $this->new_user_email, $e->params->[0],
                $e->stringify() );
            $this->assert_str_equals( $REG_TMPL, $e->template );
            $this->assert_str_equals( "confirm", $e->def );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }

    };

    my $code = $this->app->heap->{DebugVerificationCode};

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'   => ["BadCode"],
                'action' => ['verify']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                user      => $cfgData->{DefaultUserLogin},
            },
        },
    );

    $cfgData = $this->app->cfg->data;
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->regUI->_action_verify;
    }
    catch {
        my $e = $_;
        if ( ref($e) ) {
            if ( $e->isa('Foswiki::OopsException') ) {
                $this->assert_str_equals( $REG_TMPL, $e->template,
                    $e->stringify() );
                $this->assert_str_equals( "bad_ver_code", $e->def,
                    $e->stringify() );
            }
            else {
                $e->rethrow;
            }
        }
        else {
            Foswiki::Exception::Fatal->throw(
                text => "Expected a redirect but received: " . $e );
        }
    };
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $mess = $FoswikiFnTestCase::mails[0];
    $this->assert_matches(
        qr/$cfgData->{WebMasterName} <$cfgData->{WebMasterEmail}>/,
        $mess->header('From') );
    my $new_user_email = $this->new_user_email;
    $this->assert_matches( qr/.*\b$new_user_email\b/, $mess->header('To') );

    # check the verification code
    $this->assert_matches( qr/'$code'/, $mess->body() );

    return;
}

# Register a user with verification explicitly switched off
# (SUPER's tear_down will take care for re-installing $this->app->cfg)
sub verify_registerNoVerifyOk_Twk {
    my ( $this, @args ) = @_;
    $this->_registerNoVerifyOk( 'Twk', @args );

    return;
}

# Register a user with verification explicitly switched off
# (SUPER's tear_down will take care for re-installing $this->app->cfg)
sub verify_registerNoVerifyOk_Fwk {
    my ( $this, @args ) = @_;
    $this->_registerNoVerifyOk( 'Fwk', @args );

    return;
}

# Register a user with verification explicitly switched off
# (SUPER's tear_down will take care for re-installing $this->app->cfg)
sub _registerNoVerifyOk {
    my $this = shift;
    my $pfx  = shift;

    my $cfgData = $this->app->cfg->data;

    $cfgData->{Register}{NeedVerification} = 0;
    my $params = {
        'TopicName'        => ['UserRegistration'],
        "${pfx}1Email"     => [ $this->new_user_email ],
        "${pfx}1WikiName"  => [ $this->new_user_wikiname ],
        "${pfx}1Name"      => [ $this->new_user_fullname ],
        "${pfx}0Comment"   => [''],
        "${pfx}1FirstName" => [ $this->new_user_fname ],
        "${pfx}1LastName"  => [ $this->new_user_sname ],
        'action'           => ['register']
    };

    if ( $cfgData->{Register}{AllowLoginName} ) {
        $params->{"Twk1LoginName"} = $this->new_user_login;
    }

    $this->createNewFoswikiApp(
        requestParams => { initializer => $params, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "thanks", $e->def, $e->stringify() );
            $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
            my $done = '';
            foreach my $mail (@FoswikiFnTestCase::mails) {
                if ( $mail->header('Subject') =~ m/^.*Registration for/m ) {
                    my $new_user_email = $this->new_user_email;
                    if ( $mail->header('To') =~ m/^.*\b$new_user_email\b/m ) {
                        $this->assert( !$done,
                            $done . "\n---------\n" . $mail );
                        $done = $mail;
                    }
                    else {
                        $this->assert_matches(
qr/$cfgData->{WebMasterName} <$cfgData->{WebMasterEmail}>/,
                            $mail->header('To')
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
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    return;
}

# Register a user with a password which is too short - must be rejected
sub verify_rejectShortPassword {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    $cfgData->{Register}{NeedVerification} = 0;
    $cfgData->{MinPasswordLength}          = 6;
    $cfgData->{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $cfgData->{Register}{AllowLoginName}   = 0;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'    => ['UserRegistration'],
                'Twk1Email'    => [ $this->new_user_email ],
                'Twk1WikiName' => [ $this->new_user_wikiname ],
                'Twk1Name'     => [ $this->new_user_fullname ],
                'Twk0Comment'  => [''],

           #                         'Twk1LoginName' => [$this->new_user_login],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'Twk1Password'  => ['12345'],
                'Twk1Confirm'   => ['12345'],
                'action'        => ['register'],
            }
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "bad_password", $e->def,
                $e->stringify() );
            $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    }

    return;
}

# Register a user with an invalid template topic - must be rejected
sub verify_userTopictemplate {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    $cfgData->{Register}{NeedVerification} = 0;
    $cfgData->{MinPasswordLength}          = 4;
    $cfgData->{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $cfgData->{Register}{AllowLoginName}   = 0;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'    => ['UserRegistration'],
                'Twk1Email'    => [ $this->new_user_email ],
                'Twk1WikiName' => [ $this->new_user_wikiname ],
                'Twk1Name'     => [ $this->new_user_fullname ],
                'Twk0Comment'  => [''],

           #                         'Twk1LoginName' => [$this->new_user_login],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'Twk1Password'  => ['12345'],
                'Twk1Confirm'   => ['12345'],
                'templatetopic' => ['FooBar'],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "bad_templatetopic", $e->def,
                $e->stringify() );
            $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'    => ['UserRegistration'],
                'Twk1Email'    => [ $this->new_user_email ],
                'Twk1WikiName' => [ $this->new_user_wikiname ],
                'Twk1Name'     => [ $this->new_user_fullname ],
                'Twk0Comment'  => [''],

           #                         'Twk1LoginName' => [$this->new_user_login],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'Twk1Password'  => ['12345'],
                'Twk1Confirm'   => ['12345'],
                'templatetopic' => ['AltUserTemplate'],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "thanks", $e->def, $e->stringify() );
            $this->assert_matches( $this->new_user_email, $e->params->[0],
                $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    $this->assert(
        $this->app->store->topicExists(
            $cfgData->{UsersWebName},
            $this->new_user_wikiname
        )
    );

    $this->assert(
        Foswiki::Func::topicExists(
            $this->users_web, $this->new_user_wikiname
        ),
        "MISSING USER TOPIC: "
          . $this->users_web . "."
          . $this->new_user_wikiname
    );
    my $utext = Foswiki::Func::readTopicText( $cfgData->{UsersWebName},
        $this->new_user_wikiname );
    $this->assert_matches( qr/Alternate user template/, $utext );

    return;
}

# Register a user with an email which is already in use.
sub verify_rejectDuplicateEmail {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{NeedVerification} = 0;
    $cfgData->{Register}{UniqueEmail}      = 1;

    #$cfgData->{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $cfgData->{Register}{AllowLoginName} = 0;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => ['joe@gooddomain.net'],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'Twk1Password'  => ['12345'],
                'Twk1Confirm'   => ['12345'],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "thanks", $e->def, $e->stringify() );
            $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
            my $done = '';
            foreach my $mail (@FoswikiFnTestCase::mails) {
                if ( $mail->header('Subject') =~ m/^.*Registration for/m ) {
                    if ( $mail->header('To') =~ m/^.*\bjoe\@gooddomain.net\b/m )
                    {
                        $this->assert( !$done,
                            $done . "\n---------\n" . $mail );
                        $done = $mail;
                    }
                    else {
                        $this->assert_matches(
qr/$cfgData->{WebMasterName} <$cfgData->{WebMasterEmail}>/,
                            $mail->header('To')
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
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    #  Verify that The 2nd registration is stopped.

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => ['joe@gooddomain.net'],
                'Twk1WikiName'  => [ $this->new_user_wikiname . '2' ],
                'Twk1Name'      => [ $this->new_user_fullname . '2' ],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname . '2' ],
                'Twk1LastName'  => [ $this->new_user_sname . '2' ],
                'Twk1Password'  => ['12345678'],
                'Twk1Confirm'   => ['12345678'],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "dup_email", $e->def, $e->stringify() );
            $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    return;
}

# preRegister a user with an email which is already in use.
sub verify_rejectDuplicatePendingEmail {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    $cfgData->{Register}{NeedVerification} = 1;
    $cfgData->{Register}{UniqueEmail}      = 1;
    $cfgData->{Register}{ExpireAfter}      = '-23600';

    #$cfgData->{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $cfgData->{Register}{AllowLoginName} = 0;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => ['joe@dupdomain.net'],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'Twk1Password'  => ['12345'],
                'Twk1Confirm'   => ['12345'],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "confirm", $e->def, $e->stringify() );
            $this->assert_matches( 'joe@dupdomain.net', $e->params->[0],
                $e->stringify() );
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    #  Verify that The 2nd registration is stopped.
    #$query = Unit::Request->new(
    #    initializer => {
    #        'TopicName'     => ['UserRegistration'],
    #        'Twk1Email'     => ['joe@dupdomain.net'],
    #        'Twk1WikiName'  => [ $this->new_user_wikiname . '2' ],
    #        'Twk1Name'      => [ $this->new_user_fullname . '2' ],
    #        'Twk0Comment'   => [''],
    #        'Twk1FirstName' => [ $this->new_user_fname . '2' ],
    #        'Twk1LastName'  => [ $this->new_user_sname . '2' ],
    #        'Twk1Password'  => ['12345678'],
    #        'Twk1Confirm'   => ['12345678'],
    #        'action'        => ['register'],
    #    }
    #);
    #
    #$query->path_info( "/" . $this->users_web . "/UserRegistration" );
    #$this->createNewFoswikiSession( $cfgData->{DefaultUserLogin}, $query );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $cfgData->{Register}{NeedVerification} = 1;
    $cfgData->{Register}{UniqueEmail}      = 1;

    # Should use Sessions expiration if Registration is not defined.
    $cfgData->{Register}{ExpireAfter} = undef;
    $cfgData->{Sessions}{ExpireAfter} = '-23600';

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "dup_email", $e->def, $e->stringify() );
            $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    return;
}

# Register a user with an email which is filtered by EmailFilter
sub verify_rejectFilteredEmail {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    $cfgData->{Register}{NeedVerification} = 0;
    $cfgData->{Register}{UniqueEmail}      = 0;

    # Include a trailing and other whitespace - a common config error
    $cfgData->{Register}{EmailFilter} =
      '@(?!( gooddomain\.com | gooddomain\.net )$) ';
    $cfgData->{PasswordManager} = 'Foswiki::Users::HtPasswdUser';
    $cfgData->{Register}{AllowLoginName} = 0;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => [ $this->new_user_email ],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'Twk1Password'  => ['12345'],
                'Twk1Confirm'   => ['12345'],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "rej_email", $e->def, $e->stringify() );
            $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    #  Also verify that a good domain makes it through
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => ['joe@gooddomain.net'],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'Twk1Password'  => ['12345678'],
                'Twk1Confirm'   => ['12345678'],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "thanks", $e->def, $e->stringify() );
            $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
            my $done = '';
            foreach my $mail (@FoswikiFnTestCase::mails) {
                if ( $mail->header('Subject') =~ m/^.*Registration for/m ) {
                    if ( $mail->header('To') =~ m/^.*\bjoe\@gooddomain.net\b/m )
                    {
                        $this->assert( !$done,
                            $done . "\n---------\n" . $mail );
                        $done = $mail;
                    }
                    else {
                        $this->assert_matches(
qr/$cfgData->{WebMasterName} <$cfgData->{WebMasterEmail}>/,
                            $mail->header('To')
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
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    return;
}

# Register a user with invalid characters in a field - like < html
sub verify_rejectEvilContent {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    $cfgData->{Register}{NeedVerification} = 0;
    $cfgData->{MinPasswordLength}          = 6;
    $cfgData->{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $cfgData->{Register}{AllowLoginName}   = 0;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'        => ['UserRegistration'],
                'Twk1Email'        => [ $this->new_user_email ],
                'Twk1WikiName'     => [ $this->new_user_wikiname ],
                'Twk1Name'         => [ $this->new_user_fullname ],
                'Twk0Comment'      => ['<blah>'],
                'Twk1FirstName'    => [ $this->new_user_fname ],
                'Twk1LastName'     => [ $this->new_user_sname ],
                'Twk1Password'     => ['123<><>aaa'],
                'Twk1Confirm'      => ['123<><>aaa'],
                'Twk0Organization' => ['<script>Bad stuff</script>'],
                'action'           => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( "200", $e->status, $e->stringify() );

            $this->assert_matches(
qr/.*Comment: &#60;blah&#62;.*Organization: &#60;script&#62;Bad stuff&#60;\/script&#62;/ms,
                $FoswikiFnTestCase::mails[0]->body()
            );

            my ($meta) = Foswiki::Func::readTopic( $cfgData->{UsersWebName},
                $this->new_user_wikiname );
            my $text = $meta->text;
            undef $meta;
            $this->assert_matches(
qr/.*Comment: &#60;blah&#62;.*Organization: &#60;script&#62;Bad stuff&#60;\/script&#62;/ms,
                $text
            );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    return;
}

# Register a user with a password which is too short
sub verify_shortPassword {
    my $this    = shift;
    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{NeedVerification} = 0;
    $cfgData->{MinPasswordLength}          = 6;
    $cfgData->{PasswordManager}            = 'Foswiki::Users::HtPasswdUser';
    $cfgData->{Register}{AllowLoginName}   = 1;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => [ $this->new_user_email ],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0Comment'   => [''],
                'Twk1LoginName' => [ $this->new_user_login ],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'Twk1Password'  => ['12345'],
                'Twk1Confirm'   => ['12345'],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );

        my $cUID =
          $this->app->users->getCanonicalUserID( $this->new_user_login );
        $this->assert( $this->app->users->userExists($cUID),
            "new user created" );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "bad_password", $e->def,
                $e->stringify() );
            $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

# don't check the FoswikiFnTestCase::mails in this test case - this is done elsewhere
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
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
    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{NeedVerification} = 1;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => [ $this->new_user_email ],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk1LoginName' => [ $this->new_user_login ],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "confirm", $e->def, $e->stringify() );
            $this->assert_matches( $this->new_user_email, $e->params->[0],
                $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    # Read the verification code before finishing the app
    my $debugVerificationCode = $this->app->heap->{DebugVerificationCode};

    # For verification process everything including finish(), so don't just
    # call verifyEmails
    my $code = shift || $debugVerificationCode;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'   => [$code],
                'action' => ['verify'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "thanks", $e->def, $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    # and now for something completely different: Do it all over again
    @FoswikiFnTestCase::mails = ();

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'   => [$code],
                'action' => ['verify'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "duplicate_activation", $e->def,
                $e->stringify() );
            $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };
    @FoswikiFnTestCase::mails = ();

    return;
}

################################################################################
################################ RESET PASSWORD TESTS ##########################

sub verify_resetPasswordOkay {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;
    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $this->registerAccount();
    my $cUID = $this->app->users->getCanonicalUserID( $this->new_user_login );
    $this->assert( $this->app->users->userExists($cUID),
        " $cUID does not exist?" );
    my $newPassU = '12345';
    my $oldPassU = 1;         #force set
    $this->assert(
        $this->app->users->setPassword( $cUID, $newPassU, $oldPassU ) );
    $this->assert(
        $this->app->users->checkPassword( $this->new_user_login, $newPassU ) );
    my @emails = $this->app->users->getEmails($cUID);
    $this->assert_str_equals( $this->new_user_email, $emails[0] );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'LoginName' => [ $this->new_user_login ],
                'TopicName' => ['ResetPassword'],
                'action'    => ['resetPassword']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/WebHome",
                action    => 'resetpasswd',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "reset_ok", $e->def, $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $mess = $FoswikiFnTestCase::mails[0];
    $this->assert_matches(
        qr/$cfgData->{WebMasterName} <$cfgData->{WebMasterEmail}>/,
        $mess->header('From') );
    my $new_user_email = $this->new_user_email;
    $this->assert_matches( qr/.*\b$new_user_email/, $mess->header('To') );

    #lets make sure the password actually was reset
    $this->assert( !$this->app->users->checkPassword( $cUID, $newPassU ) );
    my @post_emails = $this->app->users->getEmails($cUID);
    $this->assert_str_equals( $this->new_user_email, $post_emails[0] );

    return;
}

sub verify_resetPasswordNoSuchUser {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    # This time we don't set up the testWikiName, so it should fail.

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'LoginName' => [ $this->new_user_wikiname ],
                'TopicName' => ['ResetPassword'],
                'action'    => ['resetPassword']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/WebHome",
                action    => 'resetpasswd',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "reset_bad", $e->def, $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    return;
}

sub verify_resetPasswordNeedPrivilegeForMultipleReset {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    # This time we don't set up the testWikiName, so it should fail.

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'LoginName' =>
                  [ $this->test_user_wikiname, $this->new_user_wikiname ],
                'TopicName' => ['ResetPassword'],
                'action'    => ['resetPassword']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/WebHome",
                action    => 'resetpasswd',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_matches( qr/$cfgData->{SuperAdminGroup}/,
                $e->stringify() );
            $this->assert_str_equals( 'accessdenied', $e->template );
            $this->assert_str_equals( 'only_group',   $e->def );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    return;
}

# This test make sure that the system can't reset passwords
# for a user currently absent from .htpasswd
sub verify_resetPasswordNoPassword {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    $this->registerAccount();

    my $fh;
    open( $fh, ">:encoding(utf-8)", $cfgData->{Htpasswd}{FileName} )
      || die $!;
    close($fh) || die $!;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'LoginName' => [ $this->new_user_wikiname ],
                'TopicName' => ['ResetPassword'],
                'action'    => ['resetPassword']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/WebHome",
                action    => 'resetpasswd',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "reset_bad", $e->def, $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
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

    my $file = $this->regUI->_codeFile( $regSave->{VerificationCode} );
    $this->assert( open( my $F, '>', $file ) );
    print $F Data::Dumper->Dump( [ $regSave, undef ], [ 'data', 'form' ] );
    $this->assert( close $F );

    my $result2 = $this->regUI->_loadPendingRegistration("GitWit.0");
    $this->assert_deep_equals( $result2, $regSave );

    try {

        # this is a deliberate attempt to reload an already used token.
        # this should fail!
        $this->regUI->_clearPendingRegistrationsForUser("GitWit.0");
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_matches( qr/has no file/, $e->stringify() );
        }
        else {
            $e->rethrow;
        }
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
        [ $this->regUI->_missingElements( \@present, \@required ) ], ["six"] );
    $this->assert_deep_equals(
        [ $this->regUI->_missingElements( \@present, \@present ) ], [] );

    return;
}

sub verify_buildRegistrationEmail {
    my ($this) = shift;

    my $cfgData = $this->app->cfg->data;
    my %data    = (
        'CompanyName' => '',
        'Country'     => 'Saudi Arabia',
        'Password'    => 'mypassword',
        'form'        => [
            {
                'value'    => $this->new_user_fullname,
                'required' => '1',
                'name'     => 'Name'
            },
            {
                'value'    => $this->new_user_email,
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
        'VerificationCode' => $this->app->heap->{DebugVerificationCode},
        'Name'             => $this->new_user_fullname,
        'webName'          => $this->users_web,
        'WikiName'         => $this->new_user_wikiname,
        'Comment'          => '',
        'CompanyURL'       => '',
        'passwordA'        => 'mypassword',
        'passwordB'        => 'mypassword',
        'Email'            => $this->new_user_email,
        'debug'            => 1,
        'Confirm'          => 'mypassword'
    );

    $this->createNewFoswikiApp( engineParams =>
          { initialAttributes => { user => $cfgData->{DefaultUserLogin}, }, } );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    my $actual =
      $this->regUI->_buildConfirmationEmail( \%data,
        "%FIRSTLASTNAME% - %WIKINAME% - %EMAILADDRESS%\n\n%FORMDATA%", 0 );

    my ( $new_user_fullname, $new_user_wikiname, $new_user_email ) = (
        $this->new_user_fullname, $this->new_user_wikiname,
        $this->new_user_email
    );
    $this->assert(
        $actual =~
          s/$new_user_fullname - $new_user_wikiname - $new_user_email\s*//s,
        $actual
    );

    $this->assert( $actual =~ m/^\s*\*\s*Email:\s*$new_user_email$/, $actual );
    $this->assert( $actual =~ m/^\s*\*\s*CompanyName:\s*$/,          $actual );
    $this->assert( $actual =~ m/^\s*\*\s*CompanyURL:\s*$/,           $actual );
    $this->assert( $actual =~ m/^\s*\*\s*Country:\s*Saudi Arabia$/,  $actual );
    $this->assert( $actual =~ m/^\s*\*\s*Comment:\s*$/,              $actual );
    $this->assert( $actual =~ m/^\s*\*\s*Password:\s*mypassword$/,   $actual );
    $this->assert( $actual =~ m/^\s*\*\s*LoginName:\s*$/,            $actual );
    $this->assert( $actual =~ m/^\s*\*\s*Name:\s*$new_user_fullname$/,
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
    my $this    = shift;
    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{EnableNewUserRegistration} = 0;
    $cfgData->{Register}{NeedVerification}          = 0;
    my $pfx    = 'Twk1';
    my $params = {
        'TopicName'        => ['UserRegistration'],
        "${pfx}1Email"     => [ $this->new_user_email ],
        "${pfx}1WikiName"  => [ $this->new_user_wikiname ],
        "${pfx}1Name"      => [ $this->new_user_fullname ],
        "${pfx}0Comment"   => [''],
        "${pfx}1FirstName" => [ $this->new_user_fname ],
        "${pfx}1LastName"  => [ $this->new_user_sname ],
        'action'           => ['register']
    };

    if ( $cfgData->{Register}{AllowLoginName} ) {
        $params->{"Twk1LoginName"} = $this->new_user_login;
    }

    $this->createNewFoswikiApp(
        requestParams => { initializer => $params, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "registration_disabled", $e->def,
                $e->stringify() );
        }
        else {
            $e->_set_text(
                "expected registration_disabled, got: " . $e->stringify );
            $e->rethrow;
        }
    };

    return;
}

sub test_PendingRegistrationManualCleanup {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{AllowLoginName}            = 0;
    $cfgData->{Register}{NeedVerification}          = 1;
    $cfgData->{Register}{EnableNewUserRegistration} = 1;
    $cfgData->{Register}{UniqueEmail}               = 0;
    $cfgData->{Register}{ExpireAfter}               = '-600';
    $cfgData->{LoginManager}    = 'Foswiki::LoginManager::TemplateLogin';
    $cfgData->{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => [ $this->new_user_email ],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'action'        => ['register']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "confirm", $e->def, $e->stringify() );
            $this->assert_matches( $this->new_user_email, $e->params->[0],
                $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    my $code = shift || $this->app->heap->{DebugVerificationCode};

    my $file  = "$cfgData->{WorkingDir}/registration_approvals/$code";
    my $mtime = ( time() - 610 );

    utime( $mtime, $mtime, $file )
      || $this->assert( 0, "couldn't touch $file: $!" );

    $this->regUI->expirePendingRegistrations();
    $this->assert( !( -f $file ), 'expired registration file not removed' );
}

sub test_PendingRegistrationAutoCleanup {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{AllowLoginName}            = 0;
    $cfgData->{Register}{NeedVerification}          = 1;
    $cfgData->{Register}{EnableNewUserRegistration} = 1;
    $cfgData->{Register}{UniqueEmail}               = 0;

    # Should use Sessions expiration if Registration is not defined.
    $cfgData->{Register}{ExpireAfter} = undef;
    $cfgData->{Sessions}{ExpireAfter} = 600;
    $cfgData->{LoginManager}          = 'Foswiki::LoginManager::TemplateLogin';
    $cfgData->{PasswordManager}       = 'Foswiki::Users::HtPasswdUser';

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => [ $this->new_user_email ],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'action'        => ['register'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $cfgData = $this->app->cfg->data;
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "confirm", $e->def, $e->stringify() );
            $this->assert_matches( $this->new_user_email, $e->params->[0],
                $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    my $code = shift || $this->app->heap->{DebugVerificationCode};

    my $file  = "$cfgData->{WorkingDir}/registration_approvals/$code";
    my $mtime = ( time() - 611 );

    utime( $mtime, $mtime, $file )
      || $this->assert( 0, "couldn't touch $file: $!" );

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        no strict 'refs';
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "confirm", $e->def, $e->stringify() );
            $this->assert_matches( $this->new_user_email, $e->params->[0],
                $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    $this->assert( !( -f $file ), 'expired registration file not removed' );
}

# "Make sure that if AllowLoginName is disabled, Registration doesn't use it.
sub test_Item12205 {
    my $this    = shift;
    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{AllowLoginName}            = 0;
    $cfgData->{Register}{NeedVerification}          = 0;
    $cfgData->{Register}{EnableNewUserRegistration} = 1;
    $cfgData->{LoginManager}    = 'Foswiki::LoginManager::TemplateLogin';
    $cfgData->{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => [ $this->new_user_email ],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0LoginName' => ['somename'],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'action'        => ['register']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            my $template =
              ( $this->check_dependency('Foswiki,<,1.2') )
              ? 'attention'
              : 'register';
            $this->assert_str_equals( $template, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "unsupport_loginname", $e->def,
                $e->stringify() );
            $this->assert_matches( 'somename', $e->params->[0],
                $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    return;
}

# "All I want to do for this installation is register with my wiki name
# and use that as my login name, so I can log in using the template login."
# {Register}{AllowLoginName} = 0
# {Register}{NeedVerification} = 0
# {Register}{EnableNewUserRegistration} = 1
# {LoginManager} = 'Foswiki::LoginManager::TemplateLogin'
# {PasswordManager} = 'Foswiki::Users::HtPasswdUser'
sub test_3951 {
    my $this    = shift;
    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{AllowLoginName}            = 0;
    $cfgData->{Register}{NeedVerification}          = 0;
    $cfgData->{Register}{NeedApproval}              = 0;
    $cfgData->{Register}{EnableNewUserRegistration} = 1;
    $cfgData->{LoginManager}    = 'Foswiki::LoginManager::TemplateLogin';
    $cfgData->{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => [ $this->new_user_email ],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'action'        => ['register']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "thanks", $e->def, $e->stringify() );
            $this->assert_matches( $this->new_user_email, $e->params->[0],
                $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    return;
}

# "User gets added to password system, despite a failure adding
#  them to the mapping"
sub test_4061 {
    my $this    = shift;
    my $cfgData = $this->app->cfg->data;
    $cfgData->{Register}{AllowLoginName}            = 0;
    $cfgData->{Register}{NeedVerification}          = 0;
    $cfgData->{Register}{EnableNewUserRegistration} = 1;
    $cfgData->{LoginManager}    = 'Foswiki::LoginManager::TemplateLogin';
    $cfgData->{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

    # Make WikiUsers read-only
    chmod( 0444,
"$cfgData->{DataDir}/$cfgData->{UsersWebName}/$cfgData->{UsersTopicName}.txt"
    );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'TopicName'     => ['UserRegistration'],
                'Twk1Email'     => [ $this->new_user_email ],
                'Twk1WikiName'  => [ $this->new_user_wikiname ],
                'Twk1Name'      => [ $this->new_user_fullname ],
                'Twk0Comment'   => [''],
                'Twk1FirstName' => [ $this->new_user_fname ],
                'Twk1LastName'  => [ $this->new_user_sname ],
                'action'        => ['register']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $this->assert(
        open( my $fh, "<:encoding(utf-8)", $cfgData->{Htpasswd}{FileName} ) );
    my ( $before, $stuff );
    {
        local $/ = undef;
        $before = <$fh>;
    }
    $this->assert( close($fh) );
    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "problem_adding", $e->def,
                $e->stringify() );

            # Verify that they have not been added to .htpasswd
            $this->assert(
                open(
                    $fh, "<:encoding(utf-8)", $cfgData->{Htpasswd}{FileName}
                )
            );
            {
                local $/ = undef;
                $stuff = <$fh>;
            }
            $this->assert( close($fh) );
            $this->assert_str_equals( $before, $stuff );

            # Verify they have no user topic
            $this->assert(
                !Foswiki::Func::topicExists(
                    $this->users_web, $this->new_user_wikiname
                )
            );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    }
    finally {
        chmod( 0777,
                "$cfgData->{DataDir}/"
              . $this->users_web
              . "/$cfgData->{UsersTopicName}.txt" );
    };

    return;
}

################################################################################
################################ RESET EMAIL TESTS ##########################

#test for TWikibug:Item3400
sub verify_resetPassword_NoWikiUsersEntry {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;
    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $this->registerAccount();

    #Remove the WikiUsers entry - by deleting it :)
    my ($from) = Foswiki::Func::readTopic( $cfgData->{UsersWebName},
        $cfgData->{UsersTopicName} );
    my ($to) = Foswiki::Func::readTopic( $cfgData->{UsersWebName},
        $cfgData->{UsersTopicName} . 'DELETED' );
    $from->move($to);
    undef $from;
    undef $to;

    #force a reload to unload existing user caches, and then restart as guest
    $this->createNewFoswikiApp;

    $this->assert(
        !Foswiki::Func::topicExists(
            $cfgData->{UsersWebName},
            $cfgData->{UsersTopicName}
        )
    );

    my $cUID = $this->app->users->getCanonicalUserID( $this->new_user_login );
    $this->assert( $this->app->users->userExists($cUID),
        " $cUID does not exist?" );
    my $newPassU = '12345';
    my $oldPassU = 1;         #force set
    $this->assert(
        $this->app->users->setPassword( $cUID, $newPassU, $oldPassU ) );
    $this->assert(
        $this->app->users->checkPassword( $this->new_user_login, $newPassU ) );
    my @emails = $this->app->users->getEmails($cUID);
    $this->assert_str_equals( $this->new_user_email, $emails[0] );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'LoginName' => [ $this->new_user_login ],
                'TopicName' => ['ResetPassword'],
                'action'    => ['resetPassword']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/WebHome",
                action    => 'resetpasswd',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "reset_ok", $e->def, $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $mess = $FoswikiFnTestCase::mails[0];
    $this->assert_matches(
        qr/$cfgData->{WebMasterName} <$cfgData->{WebMasterEmail}>/,
        $mess->header('From') );
    my $new_user_email = $this->new_user_email;
    $this->assert_matches( qr/.*\b$new_user_email/, $mess->header('To') );

    #lets make sure the password actually was reset
    $this->assert( !$this->app->users->checkPassword( $cUID, $newPassU ) );
    my @post_emails = $this->app->users->getEmails($cUID);
    $this->assert_str_equals( $this->new_user_email, $post_emails[0] );

    return;
}

sub registerUserException {
    my ( $this, $loginname, $forename, $surname, $email ) = @_;

    my $cfgData = $this->app->cfg->data;
    my $params  = {
        'TopicName'     => ['UserRegistration'],
        'Twk1Email'     => [$email],
        'Twk1WikiName'  => ["$forename$surname"],
        'Twk1Name'      => ["$forename $surname"],
        'Twk0Comment'   => [''],
        'Twk1FirstName' => [$forename],
        'Twk1LastName'  => [$surname],
        'action'        => ['register']
    };

    if ( $cfgData->{Register}{AllowLoginName} ) {
        $params->{"Twk1LoginName"} = $loginname;
    }

    $this->createNewFoswikiApp(
        requestParams => { initializer => $params, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    my $exception;
    try {
        $this->captureWithKey(
            register => sub { return $this->app->handleRequest; }, );
    }
    catch {
        # SMELL TODO This logic is highly dependant on what exceptions are
        # thrown when. Has to be carefully reviewed!
        $exception = $_;
        if ( ref($exception) && $exception->isa('Foswiki::Exception') ) {
            if ( $exception->isa('Foswiki::OopsException') ) {
                if (   ( $REG_TMPL eq $exception->template )
                    && ( "thanks" eq $exception->def ) )
                {

                    #print STDERR "---------".$exception->stringify()."\n";
                    $exception = undef;    #the only correct answer
                }
            }
            elsif ( $exception->isa('Foswiki::Exception::Fatal')
                || ref($exception) eq 'Foswiki::Exception' )
            {
                $exception = Foswiki::Exception::RTInfo->transmute($exception);
                $exception->template('died');
            }
        }
        else {
            $exception = Foswiki::Exception::RTInfo->transmute($exception);
            $exception->template("OK");
        }
    };

    # Reload caches
    $this->reCreateFoswikiApp;
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    return $exception;
}

#$cfgData->{NameFilter} = qr/[\s\*?~^\$@%`"'&;|<>\[\]\x00-\x1f]/;
#$cfgData->{LoginNameFilterIn} = qr/^[^\s\*?~^\$@%`"'&;|<>\x00-\x1f]+$/;
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
    $this->assert_equals( $REG_TMPL, $ret->template,
        "email as logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->def,
        "email as logon should fail" );
    $this->assert_equals(
        'asdf2@example.com',
        ${ $ret->params }[0],
        "email as logon should fail"
    );

    $ret = $this->registerUserException( 'some space', 'Asdf2', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "space logon should fail" );
    $this->assert_equals( $REG_TMPL, $ret->template,
        "space logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->def,
        "space logon should fail" );
    $this->assert_equals(
        'some space',
        ${ $ret->params }[0],
        "space logon should fail"
    );

    $ret = $this->registerUserException( 'question?', 'Asdf2', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "question?logon should fail" );
    $this->assert_equals( $REG_TMPL, $ret->template,
        "question logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->def,
        "question logon should fail" );
    $this->assert_equals(
        'question?',
        ${ $ret->params }[0],
        "question logon should fail"
    );

    return;
}

sub verify_Modified_LoginNameFilterIn_At {
    my $this = shift;
    my $ret;

    my $cfgData = $this->app->cfg->data;
    my $oldCfg  = $cfgData->{LoginNameFilterIn};
    $cfgData->{LoginNameFilterIn} = qr/^[^\s\*?~^\$%`"'&;|<>\x00-\x1f]+$/;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->registerUserException( 'asdf2@example.com', 'Asdf3', 'Poiu',
        'asdf2@example.com' );
    $this->assert_null( $ret, "email as logon should succed" );

    $ret = $this->registerUserException( 'some space', 'Asdf4', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "space logon should fail" );
    $this->assert_equals( $REG_TMPL, $ret->template,
        "space logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->def,
        "space logon should fail" );
    $this->assert_equals(
        'some space',
        ${ $ret->params }[0],
        "space logon should fail"
    );

    $ret = $this->registerUserException( 'question?', 'Asdf5', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "question?logon should fail" );
    $this->assert_equals( $REG_TMPL, $ret->template,
        "question logon should fail" );
    $this->assert_equals( 'bad_loginname', $ret->def,
        "question logon should fail" );
    $this->assert_equals(
        'question?',
        ${ $ret->params }[0],
        "question logon should fail"
    );

    $cfgData->{LoginNameFilterIn} = $oldCfg;

    return;
}

sub verify_Modified_LoginNameFilterIn_Liberal {
    my $this = shift;
    my $ret;

    my $cfgData = $this->app->cfg->data;
    my $oldCfg  = $cfgData->{LoginNameFilterIn};
    $cfgData->{LoginNameFilterIn} = qr/^.*$/;

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

    $cfgData->{LoginNameFilterIn} = $oldCfg;

    return;
}

#$cfgData->{NameFilter} = qr/[\s\*?~^\$@%`"'&;|<>\[\]\x00-\x1f]/;
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
    $this->assert_equals( $REG_TMPL, $ret->template,
        "@ in wikiname should oops: " . $ret->stringify );
    $this->assert_equals( 'bad_wikiname', $ret->def,
        "@ in wikiname should fail" );
    $this->assert_equals(
        'Asdf@Poiu',
        ${ $ret->params }[0],
        "@ in wikiname should fail"
    );

    $ret = $this->registerUserException( 'asdf3', 'Mac Asdf', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "space in name should fail" );
    $this->assert_equals( $REG_TMPL, $ret->template,
        "space in name should fail" );
    $this->assert_equals( 'bad_wikiname', $ret->def,
        "space in name should fail" );
    $this->assert_equals(
        'Mac AsdfPoiu',
        ${ $ret->params }[0],
        "space in name should fail"
    );

    $ret = $this->registerUserException( 'asdf4', 'Asd`f2', 'Poiu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "` name should fail" );
    $this->assert_equals( $REG_TMPL, $ret->template,
        "space logon should fail" );
    $this->assert_equals( 'bad_wikiname', $ret->def,
        "space logon should fail" );
    $this->assert_equals(
        'Asd`f2Poiu',
        ${ $ret->params }[0],
        "space logon should fail"
    );

    $ret = $this->registerUserException( 'asdf5', 'Asdf2', 'Po?iu',
        'asdf2@example.com' );
    $this->assert_not_null( $ret, "question?logon should fail" );
    $this->assert_equals( $REG_TMPL, $ret->template,
        "question logon should fail" );
    $this->assert_equals( 'bad_wikiname', $ret->def,
        "question logon should fail" );
    $this->assert_equals(
        'Asdf2Po?iu',
        ${ $ret->params }[0],
        "question logon should fail"
    );

    return;
}

sub verify_registerVerifyOKApproved {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    # We can't use the default ScumBag user for registration
    # approvals, because it was created before the AllowLoginName
    # setting was established, and will always have a LoginName
    $this->registerUserException( 'asdf', 'Rego', 'Approver',
        'approve@example.com' );
    @FoswikiFnTestCase::mails = ();

    $cfgData->{Register}{NeedVerification} = 1;

    $this->registerVerifyOk();

    # We're sitting with a valid registration code waiting for the next step
    # need to verify that we issue an approval.
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'   => [ scalar $this->app->request->param('code') ],
                'action' => ['verify']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $cfgData = $this->app->cfg->data;
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $cfgData->{Register}{NeedApproval} = 1;
    $cfgData->{Register}{Approvers}    = 'RegoApprover';
    try {
        $this->regUI->_action_verify;
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "approve", $e->def );
            $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
            foreach my $mail (@FoswikiFnTestCase::mails) {
                $this->assert_matches( qr/registration approval required/m,
                    $mail->header('Subject') );
                $this->assert_matches( qr/RegoApprover <approve\@example.com>/m,
                    $mail->header('To') );
                $this->assert_matches( qr/^\s*\* Name: Walter Pigeon/m,
                    $mail->body() );
                $this->assert_matches(
                    qr/^\s*\* Email: kakapo\@ground.dwelling.parrot.net/m,
                    $mail->body() );
                my $mailBody = $mail->body_str;
                $this->assert( $mailBody =~ m/action=approve;code=(.*?);/m,
                    $mailBody . "MISSING APPROVAL" );
                $this->assert_equals( $this->app->heap->{DebugVerificationCode},
                    $1 );
            }
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'   => [ $this->app->heap->{DebugVerificationCode} ],
                'action' => ['approve']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

        # Preserve the heap data.
        heap => $this->_cloneData( $this->app->heap, 'heap' ),
    );

    # Make sure we get bounced unless we are logged in
    try {
        $this->regUI->_action_approve;
    }
    catch {
        unless ( $_->isa('Foswiki::AccessControlException') ) {
            $_->rethrow;
        }
    };

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'   => [ $this->app->heap->{DebugVerificationCode} ],
                'action' => ['approve']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => 'scumbag',
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
        heap => $this->_cloneData( $this->app->heap, 'heap' ),
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->regUI->_action_approve;
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {

            # verify that we are sending mail to the registrant
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "rego_approved", $e->def );

       # Make sure the confirmations are sent; one to the user, one to the admin
            $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );
            foreach my $mail (@FoswikiFnTestCase::mails) {
                if ( $mail->header('To') =~ m/^Wiki/m ) {
                    $this->assert_matches( qr/^Wiki Administrator/m,
                        $mail->header('To') );
                }
                else {
                    $this->assert_matches( qr/^Walter Pigeon/m,
                        $mail->header('To') );
                }
                $this->assert_matches(
                    qr/^Foswiki - Registration for WalterPigeon/m,
                    $mail->header('Subject') );
            }
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    $this->assert(
        $this->app->store->topicExists(
            $cfgData->{UsersWebName},
            $this->new_user_wikiname
        )
    );

    return;
}

sub verify_registerVerifyOKDisapproved {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    # We can't use the default ScumBag user for registration
    # approvals, because it was created before the AllowLoginName
    # setting was established, and will always have a LoginName
    $this->registerUserException( 'asdf', 'Rego', 'Approver',
        'approve@example.com' );
    @FoswikiFnTestCase::mails = ();

    $cfgData->{Register}{NeedVerification} = 1;

    $this->registerVerifyOk();

    # We're sitting with a valid registration code waiting for the next step
    # need to verify that we issue an approval.
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'   => [ scalar $this->app->request->param('code') ],
                'action' => ['verify']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => $cfgData->{DefaultUserLogin},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },

    );
    $cfgData = $this->app->cfg->data;
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $cfgData->{Register}{NeedApproval} = 1;
    $cfgData->{Register}{Approvers}    = 'RegoApprover';
    try {
        $this->regUI->_action_verify;
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "approve", $e->def );
            $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
            foreach my $mail (@FoswikiFnTestCase::mails) {
                $this->assert_matches( qr/^.* registration approval required/m,
                    $mail->header('Subject') );
                $this->assert_matches(
                    qr/^RegoApprover <approve\@example.com>/m,
                    $mail->header('To') );
                $this->assert_matches( qr/^\s*\* Name: Walter Pigeon/m,
                    $mail->body() );
                $this->assert_matches(
                    qr/^\s*\* Email: kakapo\@ground.dwelling.parrot.net/m,
                    $mail->body() );
                my $mailBody = $mail->body_str;
                $this->assert( $mailBody =~ m/action=disapprove;code=(.*?);/m,
                    $mailBody . "MISSING DISAPPROVAL" );
                $this->assert_equals( $this->app->heap->{DebugVerificationCode},
                    $1 );
            }
            @FoswikiFnTestCase::mails = ();
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'code'    => [ $this->app->heap->{DebugVerificationCode} ],
                'action'  => ['disapprove'],
                'referee' => ['TheBoss']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
                user      => 'scumbag',
            },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->regUI->_action_disapprove;
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {

            # verify that we are sending mail to the registrant
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "rego_denied", $e->def );

            # Make sure no mails are sent (yet)
            $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );
        }
        else {
            $e->_set_text( "expected an oops redirect but received: "
                  . Foswiki::Exception::errorStr($e) );
            $e->rethrow;
        }
    };

    $this->assert(
        !$this->app->store->topicExists(
            $cfgData->{UsersWebName},
            $this->new_user_wikiname
        )
    );

    return;
}

1;
