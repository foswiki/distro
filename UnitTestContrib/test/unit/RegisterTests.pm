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

# Note that the TWikiFnTestCase needs to use the registration code to work,
# so this is a bit arse before tit. However we need some pre-registered users
# for this to work sensibly, so we just have to bite the bullet.
use base qw(TWikiFnTestCase);

use strict;
use diagnostics;
use TWiki::UI::Register;
use Data::Dumper;
use FileHandle;
use Error qw( :try );
use File::Copy;
use File::Path;
use Carp;
use Cwd;

my $systemWeb = "TemporaryRegisterTestsSystemWeb";

sub new {
    my $this = shift()->SUPER::new('Registration', @_);
    # your state for fixture here
    return $this;
}

my $session;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $this->{new_user_login} = 'sqwauk';
    $this->{new_user_fname} = 'Walter';
    $this->{new_user_sname} = 'Pigeon';
    $this->{new_user_email} = 'kakapo@ground.dwelling.parrot.net';
    $this->{new_user_wikiname} =
      "$this->{new_user_fname}$this->{new_user_sname}";
     $this->{new_user_fullname} =
      "$this->{new_user_fname} $this->{new_user_sname}";

    try {
        $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},
                                     $this->{users_web},
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
        # Make the test current user an admin; we will only use
        # them where necessary (e.g. for bulk registration)
        $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},
                                     $this->{users_web},
                                     $TWiki::cfg{SuperAdminGroup}, <<EOF);
   * Set GROUP = $this->{test_user_wikiname}
EOF

        $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},
                                     $this->{users_web},
                                     'UserForm', <<'EOF');
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* |
| <nop>FirstName | text | 40 | | |
| <nop>LastName | text | 40 | | |
| Email | text | 40 | | H |
| Name | text | 40 | | H |
| Comment | textarea | 50x6 | | |
EOF

        $this->{twiki}->{store}->createWeb($this->{twiki}->{user},
                                     $systemWeb,
                                     $TWiki::cfg{SystemWebName});
        $TWiki::cfg{SystemWebName} = $systemWeb;
        $TWiki::cfg{EnableEmail} = 1;

    } catch TWiki::AccessControlException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    };

    $Error::Debug = 1;

    @TWikiFnTestCase::mails = ();
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture($this->{twiki}, $systemWeb);
    $this->SUPER::tear_down();
}

# fixture
sub registerAccount {
    my $this = shift;

    $this->registerVerifyOk();

    my $query = new Unit::Request(
        {
            'code' => [
                $this->{twiki}->{DebugVerificationCode}
               ],
            'action' => [
                'verify'
               ]
           });

    try {
        TWiki::UI::Register::complete( $this->{twiki} );
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template},
                                 $e->stringify());
        $this->assert_str_equals("thanks", $e->{def}, $e->stringify());
        $this->assert_equals(2, scalar(@TWikiFnTestCase::mails));
        my $done = '';
        foreach my $mail ( @TWikiFnTestCase::mails ) {
            if( $mail =~ /^Subject:.*Registration for/m ) {
                if( $mail =~ /^To: .*\b$this->{new_user_email}\b/m ) {
                    $this->assert(!$done, $done."\n---------\n".$mail);
                    $done = $mail;
                } else {
                    $this->assert_matches(qr/To: $TWiki::cfg{WebMasterName} <$TWiki::cfg{WebMasterEmail}>/, $mail );
                }
            } else {
                $this->assert(0, $mail);
            }
        }
        $this->assert($done);
        @TWikiFnTestCase::mails = ();
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert($this->{twiki}->{store}->topicExists($TWiki::cfg{UsersWebName}, $this->{new_user_wikiname}));
}
###################################
#verify tests

sub AllowLoginName {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 1;
}
sub DontAllowLoginName {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 0;
    $this->{new_user_login}  = $this->{new_user_wikiname};
    #$this->{test_user_login} = $this->{test_user_wikiname};
}

sub TemplateLoginManager {
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::TemplateLogin';
}

sub ApacheLoginManager {
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::ApacheLogin';
}

sub NoLoginManager {
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager';
}

sub HtPasswdManager {
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
}
sub NonePasswdManager {
    $TWiki::cfg{PasswordManager} = 'none';
}


sub BaseUserMapping {
    my $this = shift;
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::BaseUserMapping';
    $this->set_up_for_verify();
}

sub TWikiUserMapping {
    my $this = shift;
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::TWikiUserMapping';
    $this->set_up_for_verify();
}

# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {
    return (
        [
            'TemplateLoginManager',
            'ApacheLoginManager',
            'NoLoginManager',
           ],
        [
            'AllowLoginName',
            'DontAllowLoginName',
           ],
        [
            'HtPasswdManager',
            #'NonePasswdManager',
           ],
        [
            'TWikiUserMapping',
            #'BaseUserMapping',
           ]
       );
}

#delay the calling of set_up til after the cfg's are set by above closure
sub set_up_for_verify {
    my $this = shift;
    
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $TWiki::Plugins::SESSION = $this->{twiki};

    @TWikiFntestCase::mails = ();
}

###################################
sub verify_userTopicWithPMWithoutForm {
    my $this = shift;
    $this->assert(!$this->{twiki}->{store}->topicExists($TWiki::cfg{UsersWebName},
                                    $this->{new_user_wikiname}),
                                    "cannot re-register user who's topic exists");
    $this->registerAccount();
    my( $meta, $text ) = $this->{twiki}->{store}->readTopic(
        undef, $TWiki::cfg{UsersWebName}, $this->{new_user_wikiname});
    $this->assert($text !~ /Ignore this%/, $text);
    $this->assert($text =~ s/But not this//,$text);
    $this->assert($text =~ s/^\s*\* First Name: $this->{new_user_fname}$//m,$text);
    $this->assert($text =~ s/^\s*\* Last Name: $this->{new_user_sname}$//m,$text);
    $this->assert($text =~ s/^\s*\* Comment:\s*$//m,$text);
    $this->assert($text =~ s/^\s*\* Name: $this->{new_user_fullname}$//m,$text);
    $this->assert($text =~ s/$TWiki::cfg{UsersWebName}\.$this->{new_user_wikiname}//,$text);
    $this->assert($text =~ s/$this->{new_user_wikiname}//,$text);
    $this->assert_matches(qr/\s*AFTER\s*/, $text);
}

sub verify_userTopicWithoutPMWithoutForm {
    my $this = shift;
    # Switch off the password manager to force email to be written to user
    # topic
    $TWiki::cfg{PasswordManager} = 'none';
    $this->assert(!$this->{twiki}->{store}->topicExists($TWiki::cfg{UsersWebName},
                                    $this->{new_user_wikiname}),
                                    "cannot re-register user who's topic exists");
    $this->registerAccount();
    my( $meta, $text ) = $this->{twiki}->{store}->readTopic(
        undef, $TWiki::cfg{UsersWebName}, $this->{new_user_wikiname});
    $this->assert($text !~ /Ignore this%/, $text);
    $this->assert($text =~ s/But not this//,$text);
    $this->assert($text =~ s/^\s*\* First Name: $this->{new_user_fname}$//m,$text);
    $this->assert($text =~ s/^\s*\* Last Name: $this->{new_user_sname}$//m,$text);
    $this->assert($text =~ s/^\s*\* Comment:\s*$//m,$text);
    $this->assert($text =~ s/^\s*\* Name: $this->{new_user_fullname}$//m,$text);
    $this->assert($text =~ s/^\s*\* Email: $this->{new_user_email}$//m,$text);
    $this->assert($text =~ s/$TWiki::cfg{UsersWebName}\.$this->{new_user_wikiname}//,$text);
    $this->assert($text =~ s/$this->{new_user_wikiname}//,$text);
    $this->assert_matches(qr/\s*AFTER\s*/, $text);
}

sub verify_userTopicWithoutPMWithForm {
    my $this = shift;
    # Switch off the password manager to force email to be written to user
    # topic
    $TWiki::cfg{PasswordManager} = 'none';

    # Change the new user topic to include the form
    my $m = new TWiki::Meta($this->{twiki}, $this->{users_web},
                            'NewUserTemplate' );
    $m->put('FORM', { name => "$this->{users_web}.UserForm" });
    $m->putKeyed('FIELD', {
                              name => 'FirstName',
                              title => '<nop>FirstName',
                              attributes => '',
                              value => '',
                          } );
    $m->putKeyed('FIELD', {
                              name => 'LastName',
                              title => '<nop>LastName',
                              attributes => '',
                              value => '',
                          } );
    $m->putKeyed('FIELD', {
                              name => 'Email',
                              title => 'Email',
                              attributes => '',
                              value => '',
                          } );
    $m->putKeyed('FIELD', {
                              name => 'Name',
                              title => 'Name',
                              attributes => '',
                              value => '',
                          } );
    $m->putKeyed('FIELD', {
                              name => 'Comment',
                              title => 'Comment',
                              attributes => '',
                              value => '',
                          } );
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},
                                       $this->{users_web},
                                       'NewUserTemplate', <<'EOF', $m );
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
EOF

    $this->registerAccount();
    
    my( $meta, $text ) = $this->{twiki}->{store}->readTopic(
        undef, $TWiki::cfg{UsersWebName}, $this->{new_user_wikiname});

    $this->assert_str_equals(
        $this->{new_user_fname},
        $meta->get('FIELD', 'FirstName')->{value});
    $this->assert_str_equals(
        $this->{new_user_sname},
        $meta->get('FIELD', 'LastName')->{value});
    $this->assert_str_equals('', $meta->get('FIELD', 'Comment')->{value});
    if($meta->get('FIELD', 'Email')) {
        $this->assert_str_equals($this->{new_user_email},
                                 $meta->get('FIELD', 'Email')->{value});
    }
    $this->assert_matches(qr/^\s*$/s, $text);
}

sub verify_userTopicWithPMWithForm {
    my $this = shift;

    # Change the new user topic to include the form
    my $m = new TWiki::Meta($this->{twiki}, $this->{users_web}, 'NewUserTemplate' );
    $m->put('FORM', { name => "$this->{users_web}.UserForm" });
    $m->putKeyed('FIELD', {
                              name => 'FirstName',
                              title => '<nop>FirstName',
                              attributes => '',
                              value => '',
                          } );
    $m->putKeyed('FIELD', {
                              name => 'LastName',
                              title => '<nop>LastName',
                              attributes => '',
                              value => '',
                          } );
    $m->putKeyed('FIELD', {
                              name => 'Email',
                              title => 'Email',
                              attributes => '',
                              value => '',
                          } );
    $m->putKeyed('FIELD', {
                              name => 'Name',
                              title => 'Name',
                              attributes => '',
                              value => '',
                          } );
    $m->putKeyed('FIELD', {
                              name => 'Comment',
                              title => 'Comment',
                              attributes => '',
                              value => '',
                          } );
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user}, $this->{users_web},
                                 'NewUserTemplate', <<'EOF', $m);
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
EOF

    $this->registerAccount();
    my( $meta, $text ) = $this->{twiki}->{store}->readTopic(
        undef, $TWiki::cfg{UsersWebName}, $this->{new_user_wikiname});
	$this->assert_not_null($meta->get('FORM'));
    $this->assert_str_equals("$this->{users_web}.UserForm", $meta->get('FORM')->{name});
    $this->assert_str_equals(
        $this->{new_user_fname}, $meta->get('FIELD', 'FirstName')->{value});
    $this->assert_str_equals(
        $this->{new_user_sname}, $meta->get('FIELD', 'LastName')->{value});
    $this->assert_str_equals('', $meta->get('FIELD', 'Comment')->{value});
    $this->assert_str_equals('', $meta->get('FIELD', 'Email')->{value});
    $this->assert_matches(qr/^\s*$/s, $text);
}


#Register a user, and then verify it
#Assumes the verification code is $this->{twiki}->{DebugVerificationCode}
sub registerVerifyOk {
    my $this = shift;
    $TWiki::cfg{Register}{NeedVerification}  =  1;
    my $query = new Unit::Request ({
                          'TopicName' => [
                                          'TWikiRegistration'
                                         ],
                          'Twk1Email' => [
                                          $this->{new_user_email}
                                         ],
                          'Twk1WikiName' => [
                                             $this->{new_user_wikiname}
                                            ],
                          'Twk1Name' => [
                                         $this->{new_user_fullname}
                                        ],
                          'Twk0Comment' => [
                                            ''
                                           ],
                          'Twk1LoginName' => [
                                              $this->{new_user_login}
                                             ],
                          'Twk1FirstName' => [
                                              $this->{new_user_fname}
                                             ],
                          'Twk1LastName' => [
                                              $this->{new_user_sname}
                                            ],
                          'action' => [
                                       'register'
                                      ]
                         });

    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template},$e->stringify());
        $this->assert_str_equals("confirm", $e->{def}, $e->stringify());
        my $encodedTestUserEmail =
          TWiki::entityEncode($this->{new_user_email});
        $this->assert_matches(qr/$encodedTestUserEmail/, $e->stringify());
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };

    my $code = shift || $this->{twiki}->{DebugVerificationCode};
    $query = new Unit::Request ({
                       'code' => [
                                  $code
                                 ],
                       'action' => [
                                    'verify'
                                   ]
                      });
    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin},$query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::verifyEmailAddress($this->{twiki});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    };
    $this->assert_equals(1, scalar(@TWikiFnTestCase::mails));
    my $done = '';
    foreach my $mail ( @TWikiFnTestCase::mails ) {
        if( $mail =~ /Your verification code is /m ) {
            $this->assert(!$done, $done."\n---------\n".$mail);
            $done = $mail;
        } else {
            $this->assert(0, $mail);
        }
    }
    $this->assert($done);
    @TWikiFnTestCase::mails = ();
}

#Register a user, then give a bad verification code. It should barf.
sub verify_registerBadVerify {
    my $this = shift;
    $TWiki::cfg{Register}{NeedVerification}  =  1;
    my $query = new Unit::Request ({
                          'TopicName' => [
                                          'TWikiRegistration'
                                         ],
                          'Twk1Email' => [
                                          $this->{new_user_email}
                                         ],
                          'Twk1WikiName' => [
                                             $this->{new_user_wikiname}
                                            ],
                          'Twk1Name' => [
                                         $this->{new_user_fullname}
                                        ],
                          'Twk0Comment' => [
                                            ''
                                           ],
                          'Twk1LoginName' => [
                                              $this->{new_user_login}
                                             ],
                          'Twk1FirstName' => [
                                              $this->{new_user_fname}
                                             ],
                          'Twk1LastName' => [
                                             $this->{new_user_sname}
                                            ],
                          'action' => [
                                       'register'
                                      ]
                         });
    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);
    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        my $encodedTestUserEmail =
          TWiki::entityEncode($this->{new_user_email});
        $this->assert_matches(qr/$encodedTestUserEmail/, $e->stringify());
        $this->assert_str_equals("attention", $e->{template});
        $this->assert_str_equals("confirm", $e->{def});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());

    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };

    my $code = $this->{twiki}->{DebugVerificationCode};
    $query = new Unit::Request ({
        'code' => [
            $code
           ],
        'action' => [
            'verify'
           ]
    });
    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::verifyEmailAddress($this->{twiki});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention",$e->{template}, $e->stringify());
        $this->assert_str_equals("bad_ver_code",$e->{def}, $e->stringify());
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "Expected a redirect" );
    };
    $this->assert_equals(1, scalar(@TWikiFnTestCase::mails));
    my $mess = $TWikiFnTestCase::mails[0];
    $this->assert_matches(qr/From: $TWiki::cfg{WebMasterName} <$TWiki::cfg{WebMasterEmail}>/,$mess);
    $this->assert_matches(qr/To: .*\b$this->{new_user_email}\b/,$mess);
    # check the verification code
    $this->assert_matches(qr/'$this->{twiki}->{DebugVerificationCode}'/,$mess);
}


# Register a user with verification explicitly switched off
# (SUPER's tear_down will take care for re-installing %TWiki::cfg)
sub verify_registerNoVerifyOk {
    my $this = shift;
    $TWiki::cfg{Register}{NeedVerification}  =  0;
    my $query = new Unit::Request ({
                          'TopicName' => [
                                          'TWikiRegistration'
                                         ],
                          'Twk1Email' => [
                                          $this->{new_user_email}
                                         ],
                          'Twk1WikiName' => [
                                             $this->{new_user_wikiname}
                                            ],
                          'Twk1Name' => [
                                         $this->{new_user_fullname}
                                        ],
                          'Twk0Comment' => [
                                            ''
                                           ],
                          'Twk1LoginName' => [
                                              $this->{new_user_login}
                                             ],
                          'Twk1FirstName' => [
                                              $this->{new_user_fname}
                                             ],
                          'Twk1LastName' => [
                                             $this->{new_user_sname}
                                            ],
                          'action' => [
                                       'register'
                                      ]
                         });

    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template},
                                 $e->stringify());
        $this->assert_str_equals("thanks", $e->{def}, $e->stringify());
        $this->assert_equals(2, scalar(@TWikiFnTestCase::mails));
        my $done = '';
        foreach my $mail ( @TWikiFnTestCase::mails ) {
            if( $mail =~ /^Subject:.*Registration for/m ) {
                if( $mail =~ /^To: .*\b$this->{new_user_email}\b/m ) {
                    $this->assert(!$done, $done."\n---------\n".$mail);
                    $done = $mail;
                } else {
                    $this->assert_matches(qr/To: $TWiki::cfg{WebMasterName} <$TWiki::cfg{WebMasterEmail}>/, $mail );
                }
            } else {
                $this->assert(0, $mail);
            }
        }
        $this->assert($done);
        @TWikiFnTestCase::mails = ();
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
}


# Register a user with a password which is too short - must be rejected
sub verify_rejectShortPassword {
    my $this = shift;
    $TWiki::cfg{Register}{NeedVerification}  =  0;
    $TWiki::cfg{MinPasswordLength}           =  6;
    $TWiki::cfg{PasswordManager}             =  'TWiki::Users::HtPasswdUser';
    $TWiki::cfg{Register}{AllowLoginName}    =  0;
    my $query = new Unit::Request ({
                          'TopicName'     => ['TWikiRegistration'],
                          'Twk1Email'     => [$this->{new_user_email}],
                          'Twk1WikiName'  => [$this->{new_user_wikiname}],
                          'Twk1Name'      => [$this->{new_user_fullname}],
                          'Twk0Comment'   => [''],
#                         'Twk1LoginName' => [$this->{new_user_login}],
                          'Twk1FirstName' => [$this->{new_user_fname}],
                          'Twk1LastName'  => [$this->{new_user_sname}],
                          'Twk1Password'  => ['12345'],
                          'Twk1Confirm'   => ['12345'],
                          'action'        => ['register'],
                         });

    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("bad_password", $e->{def}, $e->stringify());
        $this->assert_equals(0, scalar(@TWikiFnTestCase::mails));
        @TWikiFnTestCase::mails = ();
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
}

# Register a user with a password which is too short
sub verify_shortPassword {
    my $this = shift;
    $TWiki::cfg{Register}{NeedVerification}  =  0;
    $TWiki::cfg{MinPasswordLength}           =  6;
    $TWiki::cfg{PasswordManager}             =  'TWiki::Users::HtPasswdUser';
    $TWiki::cfg{Register}{AllowLoginName}    =  1;
    my $query = new Unit::Request(
        {
            'TopicName'     => ['TWikiRegistration'],
            'Twk1Email'     => [$this->{new_user_email}],
            'Twk1WikiName'  => [$this->{new_user_wikiname}],
            'Twk1Name'      => [$this->{new_user_fullname}],
            'Twk0Comment'   => [''],
            'Twk1LoginName' => [$this->{new_user_login}],
            'Twk1FirstName' => [$this->{new_user_fname}],
            'Twk1LastName'  => [$this->{new_user_sname}],
            'Twk1Password'  => ['12345'],
            'Twk1Confirm'   => ['12345'],
            'action'        => ['register'],
        });

    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
        my $cUID = $this->{twiki}->{users}->getCanonicalUserID($this->{new_user_login});
        $this->assert($this->{twiki}->{users}->userExists($cUID), "new user created");
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("bad_password", $e->{def}, $e->stringify());
        $this->assert_equals(0, scalar(@TWikiFnTestCase::mails));
        # don't check the TWikiFnTestCase::mails in this test case - this is done elsewhere
        @TWikiFnTestCase::mails = ();
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
}


# Purpose:  Test behaviour of duplicate activation (Item3105)
# Verifies: Most of the things which are verified during normal
#           registration with Verification, plus Oops for
#           duplicate verification
sub verify_duplicateActivation {
    my $this = shift;

    # Start similar to registration with verification
    $TWiki::cfg{Register}{NeedVerification}  =  1;
    my $query = new Unit::Request ({'TopicName'     => ['TWikiRegistration'],
                          'Twk1Email'     => [$this->{new_user_email}],
                          'Twk1WikiName'  => [$this->{new_user_wikiname}],
                          'Twk1Name'      => [$this->{new_user_fullname}],
                          'Twk1LoginName' => [$this->{new_user_login}],
                          'Twk1FirstName' => [$this->{new_user_fname}],
                          'Twk1LastName'  => [$this->{new_user_sname}],
                          'action'        => ['register'],
                      });
    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki} = TWiki->new($TWiki::cfg{DefaultUserName}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);
    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template},$e->stringify());
        $this->assert_str_equals("confirm", $e->{def}, $e->stringify());
        my $encodedTestUserEmail =
          TWiki::entityEncode($this->{new_user_email});
        $this->assert_matches(qr/$encodedTestUserEmail/, $e->stringify());
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->{twiki}->finish();

    # For verification process everything including finish(), so don't just
    # call verifyEmails
    my $code = shift || $this->{twiki}->{DebugVerificationCode};
    $query = new Unit::Request ({'code'   => [$code],
                        'action' => ['verify'],
                    });
    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki} = TWiki->new($TWiki::cfg{DefaultUserName},$query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);
    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("thanks", $e->{def}, $e->stringify());
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->{twiki}->finish();

    # and now for something completely different: Do it all over again
    @TWikiFnTestCase::mails = ();
    $query = new Unit::Request ({'code'   => [$code],
                        'action' => ['verify'],
                    });
    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki} = TWiki->new($TWiki::cfg{DefaultUserName},$query);
    $this->{twiki}->net->setMailHandler(\&sentMail);
    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("duplicate_activation", $e->{def}, $e->stringify());
        $this->assert_equals(0, scalar(@TWikiFnTestCase::mails));
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    @TWikiFnTestCase::mails = ();
}


################################################################################
################################ RESET PASSWORD TESTS ##########################

sub verify_resetPasswordOkay {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $this->registerAccount();
    my $cUID = $this->{twiki}->{users}->getCanonicalUserID($this->{new_user_login});
    $this->assert($this->{twiki}->{users}->userExists($cUID), " $cUID does not exist?");
    my $newPassU = '12345';
    my $oldPassU = 1;   #force set
    $this->assert($this->{twiki}->{users}->setPassword( $cUID, $newPassU, $oldPassU ));
    $this->assert($this->{twiki}->{users}->checkPassword( $this->{new_user_login}, $newPassU ));
    my @emails = $this->{twiki}->{users}->getEmails($cUID);
    $this->assert_str_equals($this->{new_user_email}, $emails[0]);

    my $query = new Unit::Request (
                         {
                          'LoginName' => [
                                          $this->{new_user_login}
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    $query->path_info( '/'.$this->{users_web}.'/WebHome' );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::resetPassword($this->{twiki});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("reset_ok", $e->{def}, $e->stringify());
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(1, scalar(@TWikiFnTestCase::mails));
    my $mess = $TWikiFnTestCase::mails[0];
    $this->assert_matches(qr/From: $TWiki::cfg{WebMasterName} <$TWiki::cfg{WebMasterEmail}>/,$mess);
    $this->assert_matches(qr/To: .*\b$this->{new_user_email}/,$mess);

    #lets make sure the password actually was reset
    $this->assert(!$this->{twiki}->{users}->checkPassword( $cUID, $newPassU ));
    my @post_emails = $this->{twiki}->{users}->getEmails($cUID);
    $this->assert_str_equals($this->{new_user_email}, $post_emails[0]);

}

sub verify_resetPasswordNoSuchUser {
    my $this = shift;
    # This time we don't set up the testWikiName, so it should fail.

    my $query = new Unit::Request (
                         {
                          'LoginName' => [
                                          $this->{new_user_wikiname}
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    $query->path_info( '/.'.$this->{users_web}.'/WebHome' );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::resetPassword($this->{twiki});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("reset_bad", $e->{def}, $e->stringify());
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(0, scalar(@TWikiFnTestCase::mails));
}


sub verify_resetPasswordNeedPrivilegeForMultipleReset {
    my $this = shift;
    # This time we don't set up the testWikiName, so it should fail.

    my $query = new Unit::Request (
                         {
                          'LoginName' => [
                                          $this->{test_user_wikiname},
                                          $this->{new_user_wikiname}
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    $query->path_info( '/.'.$this->{users_web}.'/WebHome' );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::resetPassword($this->{twiki});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_matches(qr/$TWiki::cfg{SuperAdminGroup}/,
                              $e->stringify());
        $this->assert_str_equals('accessdenied', $e->{template});
        $this->assert_str_equals('only_group', $e->{def});
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(0, scalar(@TWikiFnTestCase::mails));
}

# This test make sure that the system can't reset passwords
# for a user currently absent from .htpasswd
sub verify_resetPasswordNoPassword {
    my $this = shift;

    $this->registerAccount();

    my $query = new Unit::Request (
                         {
                          'LoginName' => [
                                          $this->{new_user_wikiname}
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    $query->path_info( '/'.$this->{users_web}.'/WebHome' );
    unlink $TWiki::cfg{Htpasswd}{FileName};

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::resetPassword($this->{twiki});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("reset_bad", $e->{def}, $e->stringify());
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    # If the user is not in htpasswd, there's can't be an email
    $this->assert_equals(0, scalar(@TWikiFnTestCase::mails));
    @TWikiFnTestCase::mails = ();
}

=pod

Create an incomplete registration, and try to finish it off.
Once complete, try again - the second attempt at completion should fail.

=cut

sub verify_UnregisteredUser {
    my $this = shift;

    my $regSave = {
                doh => "homer",
                VerificationCode => "GitWit.0",
                WikiName => "GitWit"
               };

    my $file = TWiki::UI::Register::_codeFile( $regSave->{VerificationCode} );
    $this->assert(open( F, ">$file" ));
    print F Data::Dumper->Dump( [ $regSave, undef ], [ 'data', 'form' ] );
    close F;

    my $result2 = TWiki::UI::Register::_loadPendingRegistration($session, "GitWit.0");
    $this->assert_deep_equals($result2, $regSave);

    try {
        # this is a deliberate attempt to reload an already used token.
        # this should fail!
        TWiki::UI::Register::_clearPendingRegistrationsForUser("GitWit.0");
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_matches(qr/has no file/, $e->stringify());
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    };
    # $this->assert_null( UnregisteredUser::reloadUserContext($code));
    $this->assert_equals(0, scalar(@TWikiFnTestCase::mails));
}

sub verify_missingElements {
    my $this = shift;
    my @present = ("one","two","three");
    my @required = ("one","two","six");


    $this->assert_deep_equals([TWiki::UI::Register::_missingElements(\@present, \@required)], ["six"]);
    $this->assert_deep_equals( [TWiki::UI::Register::_missingElements(\@present, \@present)], []);
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
    my $file = $TWiki::cfg{DataDir}.'/'.$this->{test_web}.'/'.$regTopic.'.txt';
    my $fh = new FileHandle;
    
    die "Can't write $file" unless ($fh->open(">$file"));
    print $fh $testReg;
    $fh->close;

    my $query = new Unit::Request ({
                          'LogTopic' => [
                                         $logTopic
                                        ],
                          'EmailUsersWithDetails' => [
                                                      '0'
                                                     ],
                          'OverwriteHomeTopics' => [
                                                    '1'
                                                   ],
                         });

    $query->path_info( "/$this->{test_web}/$regTopic" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{SuperAdminGroup}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);
    $this->{twiki}->{topicName} = $regTopic;
    $this->{twiki}->{webName} = $this->{test_web};
    try {
        $this->capture( \&TWiki::UI::Register::bulkRegister, $this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert(0, $e->stringify()." UNEXPECTED");

    } catch Error::Simple with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(0, scalar(@TWikiFnTestCase::mails));
}

sub verify_buildRegistrationEmail {
    my ($this) = shift;

    my %data = (
                'CompanyName' => '',
                'Country' => 'Saudi Arabia',
                'Password' => 'mypassword',
                'form' => [
                           {
                            'value' => $this->{new_user_fullname},
                            'required' => '1',
                            'name' => 'Name'
                           },
                           {
                            'value' => $this->{new_user_email},
                            'required' => '1',
                            'name' => 'Email'
                           },
                           {
                            'value' => '',
                            'required' => '0',
                            'name' => 'CompanyName'
                           },
                           {
                            'value' => '',
                            'required' => '0',
                            'name' => 'CompanyURL'
                           },
                           {
                            'value' => 'Saudi Arabia',
                            'required' => '1',
                            'name' => 'Country'
                           },
                           {
                            'value' => '',
                            'required' => '0',
                            'name' => 'Comment'
                           },
                           {
                            'value' => 'mypassword',
                            'name' => 'Password',
                           }
                          ],
                'VerificationCode' => $this->{twiki}->{DebugVerificationCode},
                'Name' => $this->{new_user_fullname},
                'webName' => $this->{users_web},
                'WikiName' => $this->{new_user_wikiname},
                'Comment' => '',
                'CompanyURL' => '',
                'passwordA' => 'mypassword',
                'passwordB' => 'mypassword',
                'Email' => $this->{new_user_email},
                'debug' => 1,
                'Confirm' => 'mypassword'
               );

    my $expected = <<EOM;
$this->{new_user_fullname} - $this->{new_user_wikiname} - $this->{new_user_email}

   * Name: $this->{new_user_fullname}
   * Email: $this->{new_user_email}
   * CompanyName: 
   * CompanyURL: 
   * Country: Saudi Arabia
   * Comment: 
   * Password: mypassword
   * LoginName: 
EOM

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin});
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    my $actual = TWiki::UI::Register::_buildConfirmationEmail
       ($this->{twiki},
        \%data,
        "%FIRSTLASTNAME% - %WIKINAME% - %EMAILADDRESS%\n\n%FORMDATA%",0);
    $expected =~ s/\s+//g;
    $actual =~ s/\s+//g;
    $this->assert_equals( $expected, $actual );
    $this->assert_equals(0, scalar(@TWikiFnTestCase::mails));
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
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 0;
    $TWiki::cfg{Register}{NeedVerification}  =  0;
    my $query = new Unit::Request ({
                          'TopicName' => [
                                          'TWikiRegistration'
                                         ],
                          'Twk1Email' => [
                                          $this->{new_user_email}
                                         ],
                          'Twk1WikiName' => [
                                             $this->{new_user_wikiname}
                                            ],
                          'Twk1Name' => [
                                         $this->{new_user_fullname}
                                        ],
                          'Twk0Comment' => [
                                            ''
                                           ],
                          'Twk1LoginName' => [
                                              $this->{new_user_login}
                                             ],
                          'Twk1FirstName' => [
                                              $this->{new_user_fname}
                                             ],
                          'Twk1LastName' => [
                                             $this->{new_user_sname}
                                            ],
                          'action' => [
                                       'register'
                                      ]
                         });

    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::register_cgi($this->{twiki});    
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template},
                                 $e->stringify());
        $this->assert_str_equals("registration_disabled", $e->{def}, $e->stringify());
    } catch Error::Simple with {
        my $e = shift;
        $this->assert(0,$e->stringify());
    } otherwise {
        my $e = shift;
        $this->assert(0, "expected registration_disabled, got ".$e->stringify().' {'.$e->{template}.'}  {'.$e->{def}.'} '.ref($e));
    }
}

# "All I want to do for this installation is register with my wiki name
# and use that as my login name, so I can log in using the template login."
# {Register}{AllowLoginName} = 0
# {Register}{NeedVerification} = 0
# {Register}{EnableNewUserRegistration} = 1
# {LoginManager} = 'TWiki::LoginManager::TemplateLogin'
# {PasswordManager} = 'TWiki::Users::HtPasswdUser'
sub test_3951 {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 0;
    $TWiki::cfg{Register}{NeedVerification} = 0;
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::TemplateLogin';
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
    my $query = new Unit::Request ({
                          'TopicName' => [
                                          'TWikiRegistration'
                                         ],
                          'Twk1Email' => [
                                          $this->{new_user_email}
                                         ],
                          'Twk1WikiName' => [
                                             $this->{new_user_wikiname}
                                            ],
                          'Twk1Name' => [
                                         $this->{new_user_fullname}
                                        ],
                          'Twk0Comment' => [
                                            ''
                                           ],
                          'Twk1FirstName' => [
                                              $this->{new_user_fname}
                                             ],
                          'Twk1LastName' => [
                                             $this->{new_user_sname}
                                            ],
                          'action' => [
                                       'register'
                                      ]
                         });

    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template},$e->stringify());
        $this->assert_str_equals("thanks", $e->{def}, $e->stringify());
        my $encodedTestUserEmail =
          TWiki::entityEncode($this->{new_user_email});
        $this->assert_matches(qr/$encodedTestUserEmail/, $e->stringify());
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
}

# "User gets added to password system, despite a failure adding
#  them to the mapping"
sub test_4061 {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 0;
    $TWiki::cfg{Register}{NeedVerification} = 0;
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::TemplateLogin';
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
    my $query = new Unit::Request ({
                          'TopicName' => [
                                          'TWikiRegistration'
                                         ],
                          'Twk1Email' => [
                                          $this->{new_user_email}
                                         ],
                          'Twk1WikiName' => [
                                             $this->{new_user_wikiname}
                                            ],
                          'Twk1Name' => [
                                         $this->{new_user_fullname}
                                        ],
                          'Twk0Comment' => [
                                            ''
                                           ],
                          'Twk1FirstName' => [
                                              $this->{new_user_fname}
                                             ],
                          'Twk1LastName' => [
                                             $this->{new_user_sname}
                                            ],
                          'action' => [
                                       'register'
                                      ]
                         });

    # Make TWikiUsers read-only
    chmod(0444, "$TWiki::cfg{DataDir}/$this->{users_web}/TWikiUsers.txt");

    $query->path_info( "/$this->{users_web}/TWikiRegistration" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    $this->assert(open(F, "<", $TWiki::cfg{Htpasswd}{FileName}));
    local $/;
    my $before = <F>;
    close(F);

    try {
        TWiki::UI::Register::register_cgi($this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template},$e->stringify());
        $this->assert_str_equals("problem_adding", $e->{def}, $e->stringify());

        # Verify that they have not been added to .htpasswd
        $this->assert(open(F, "<", $TWiki::cfg{Htpasswd}{FileName}));
        local $/;
        my $stuff = <F>;
        close(F);
        $this->assert_str_equals($before, $stuff);

        # Verify they have no user topic
        $this->assert(!TWiki::Func::topicExists(
            $this->{users_web}, $this->{new_user_wikiname}));

    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    } finally {
        chmod(0777, "$TWiki::cfg{DataDir}/$this->{users_web}/TWikiUsers.txt");
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

    my $cUID = $this->{twiki}->{users}->getCanonicalUserID($this->{new_user_login});
    $this->assert($this->{twiki}->{users}->userExists($cUID), "new user created");
    my $newPassU = '12345';
    my $oldPassU = 1;   #force set
    $this->assert($this->{twiki}->{users}->setPassword( $cUID, $newPassU, $oldPassU ));
    my $newEmail =  'UnitEmail@home.org.au';

    my $query = new Unit::Request (
                         {
                          'LoginName' => [
                                          $this->{new_user_login}
                                         ],
                          'TopicName' => [
                                          'ChangeEmailAddress'
                                         ],
                          'username' => [
                                         $this->{new_user_login}
                                         ],
                          'oldpassword' => [
                                         '12345'
                                         ],
                          'email' => [
                                         $newEmail
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    $query->path_info( '/'.$this->{users_web}.'/WebHome' );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki($this->{new_user_login}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);
    try {
        TWiki::UI::Register::changePassword($this->{twiki});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("email_changed", $e->{def}, $e->stringify());
        $this->assert_str_equals($newEmail, ${$e->{params}}[0], ${$e->{params}}[0]);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };

    my @emails = $this->{twiki}->{users}->getEmails($cUID);
    $this->assert_str_equals($newEmail, $emails[0]);
}

#test for http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/Item3400
sub verify_resetPassword_NoTWikiUsersEntry {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $this->registerAccount();
    
    #Remove the TWikiUsers entry - by deleting it :)
    $this->{twiki}->{store}->moveTopic(
        $TWiki::cfg{UsersWebName}, $TWiki::cfg{UsersTopicName}, 
        $TWiki::cfg{UsersWebName}, $TWiki::cfg{UsersTopicName}.'DELETED',
        TWiki::Func::getCanonicalUserID($TWiki::cfg{AdminUserLogin}) );
    #force a reload to unload existing user caches, and then restart as guest
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $TWiki::Plugins::SESSION = $this->{twiki}; 
    
    $this->assert(!TWiki::Func::topicExists($TWiki::cfg{UsersWebName}, $TWiki::cfg{UsersTopicName}));   
    
    my $cUID = $this->{twiki}->{users}->getCanonicalUserID($this->{new_user_login});
    $this->assert($this->{twiki}->{users}->userExists($cUID), " $cUID does not exist?");
    my $newPassU = '12345';
    my $oldPassU = 1;   #force set
    $this->assert($this->{twiki}->{users}->setPassword( $cUID, $newPassU, $oldPassU ));
    $this->assert($this->{twiki}->{users}->checkPassword(
        $this->{new_user_login}, $newPassU ));
    my @emails = $this->{twiki}->{users}->getEmails($cUID);
    $this->assert_str_equals($this->{new_user_email}, $emails[0]);

    my $query = new Unit::Request (
                         {
                          'LoginName' => [
                                          $this->{new_user_login}
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    $query->path_info( '/'.$this->{users_web}.'/WebHome' );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserLogin}, $query);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    try {
        TWiki::UI::Register::resetPassword($this->{twiki});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("reset_ok", $e->{def}, $e->stringify());
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(1, scalar(@TWikiFnTestCase::mails));
    my $mess = $TWikiFnTestCase::mails[0];
    $this->assert_matches(qr/From: $TWiki::cfg{WebMasterName} <$TWiki::cfg{WebMasterEmail}>/,$mess);
    $this->assert_matches(qr/To: .*\b$this->{new_user_email}/,$mess);

    #lets make sure the password actually was reset
    $this->assert(!$this->{twiki}->{users}->checkPassword( $cUID, $newPassU ));
    my @post_emails = $this->{twiki}->{users}->getEmails($cUID);
    $this->assert_str_equals($this->{new_user_email}, $post_emails[0]);

}


1;
