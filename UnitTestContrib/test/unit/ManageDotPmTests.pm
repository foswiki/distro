

#TODO: permission tests
#TODO: non-existant user test

use strict;
use warnings;
use diagnostics;

package ManageDotPmTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );
use Error qw(:try);
use Foswiki;
use Foswiki::UI::Manage;
use Foswiki::UI::Save;

our $REG_UI_FN;
our $MAN_UI_FN;

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    
    $REG_UI_FN ||= $this->getUIFn('register');
    $MAN_UI_FN ||= $this->getUIFn('manage');

    @FoswikiFnTestCase::mails = ();

}
sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();
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
#        [ 'TemplateLoginManager', 'ApacheLoginManager', 'NoLoginManager', ],
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

#to simplify registration
#SMELL: why are we not re-using code like this
#SMELL: or the verify code... this would benefit from reusing the mixing of mappers and other settings.
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
        $this->captureWithKey( register => $REG_UI_FN, $fatwilly );
    }
    catch Foswiki::OopsException with {
        $exception = shift;
        if (   ( "attention" eq $exception->{template} )
            && ( "thanks" eq $exception->{def} ) )
        {

            print STDERR "---------".$exception->stringify()."\n" if ($Error::Debug);
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

sub addUserToGroup {
    my $this = shift;
    #my $queryHash = shift;
    
    my $query = new Unit::Request(@_);

    $query->path_info("/$this->{users_web}/WikiGroups");
    my $fatwilly = new Foswiki( undef, $query );

    my $exception;
    try {
        no strict 'refs';
        $this->captureWithKey( manage => $this->getUIFn('manage'), $fatwilly );
        no strict 'refs';
    }
    catch Foswiki::OopsException with {
        $exception = shift;
        print STDERR "---------".$exception->stringify()."\n" if ($Error::Debug);
        if (   ( "attention" eq $exception->{template} )
            && ( "added_users_to_group" eq $exception->{def} ) )
        {
#TODO: confirm that that onle the expected group and user is created
            undef $exception;    #the only correct answer
        }
    }
    catch Foswiki::AccessControlException with {
        $exception = shift;
        print STDERR "---------2 ".$exception->stringify()."\n" if ($Error::Debug);
    }
    catch Error::Simple with {
        $exception = shift;
        print STDERR "---------3 ".$exception->stringify()."\n" if ($Error::Debug);
    }
    otherwise {
        print STDERR "--------- otherwise\n" if ($Error::Debug);
        $exception = new Error::Simple();
    };
    return $exception;
}

sub removeUserFromGroup {
    my $this = shift;
    #my $queryHash = shift;
    
    my $query = new Unit::Request(@_);

    $query->path_info("/$this->{users_web}/WikiGroups");
    my $fatwilly = new Foswiki( undef, $query );

    my $exception;
    try {
        no strict 'refs';
        $this->captureWithKey( manage => $this->getUIFn('manage'), $fatwilly );
        no strict 'refs';
    }
    catch Foswiki::OopsException with {
        $exception = shift;
        print STDERR "---------".$exception->stringify()."\n" if ($Error::Debug);
        if (   ( "attention" eq $exception->{template} )
            && ( "removed_users_from_group" eq $exception->{def} ) )
        {
#TODO: confirm that that onle the expected group and user is created
            undef $exception;    #the only correct answer
        }
    }
    catch Foswiki::AccessControlException with {
        $exception = shift;
        print STDERR "---------2 ".$exception->stringify()."\n" if ($Error::Debug);
    }
    catch Error::Simple with {
        $exception = shift;
        print STDERR "---------3 ".$exception->stringify()."\n" if ($Error::Debug);
    }
    otherwise {
        print STDERR "--------- otherwise\n" if ($Error::Debug);
        $exception = new Error::Simple();
    };
    return $exception;
}

sub test_SingleAddToNewGroupCreate {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu', 'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    
    $ret = $this->addUserToGroup(        {
            'username'      => ['AsdfPoiu'],
            'groupname'     => ['NewGroup'],
            'create'        => [1],
            'action'        => ['addUserToGroup']
        });
    $this->assert_null( $ret, "Simple add to new group" );
    
    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    
    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );

    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    #SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
}



sub test_DoubleAddToNewGroupCreate {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu', 'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserException( 'qwer', 'Qwer', 'Poiu', 'qwer@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserException( 'zxcv', 'Zxcv', 'Poiu', 'zxcv@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    
    $ret = $this->addUserToGroup(        {
            'username'      => ['AsdfPoiu','QwerPoiu'],
            'groupname'     => ['NewGroup'],
            'create'        => [1],
            'action'        => ['addUserToGroup']
        });
    $this->assert_null( $ret, "Simple add to new group" );
    
    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));
    
    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );

    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    #SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));
}

sub test_TwiceAddToNewGroupCreate {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu', 'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserException( 'qwer', 'Qwer', 'Poiu', 'qwer@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserException( 'zxcv', 'Zxcv', 'Poiu', 'zxcv@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserException( 'zxcv2', 'Zxcv', 'Poiu2', 'zxcv@2example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserException( 'zxcv3', 'Zxcv', 'Poiu3', 'zxcv3@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserException( 'zxcv4', 'Zxcv', 'Poiu4', 'zxcv4@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    
    $ret = $this->addUserToGroup(        {
            'username'      => [$this->{session}->{user}],
            'groupname'     => ['NewGroup'],
            'create'        => [1],
            'action'        => ['addUserToGroup']
        });
    $this->assert_null( $ret, "add myself" );
    
    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));
    
    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );

    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    #SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));

    $ret = $this->addUserToGroup(        {
            'username'      => ["AsdfPoiu"],
            'groupname'     => ['NewGroup'],
            'create'        => [],
            'action'        => ['addUserToGroup']
        });
    $this->assert_null( $ret, "second add user" );
    
    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));
    
    #need to reload to force Foswiki to reparse Groups :(
    $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );

    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    #SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));

    $ret = $this->addUserToGroup(        {
            'username'      => ["QwerPoiu", "ZxcvPoiu", "ZxcvPoiu2", "ZxcvPoiu3", "ZxcvPoiu4"],
            'groupname'     => ['NewGroup'],
            'create'        => [],
            'action'        => ['addUserToGroup']
        });
    $this->assert_null( $ret, "third add user" );
    
    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));
    
    #need to reload to force Foswiki to reparse Groups :(
    $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );

    $this->assert(Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    #SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu2" ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu3" ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu4" ));

    $ret = $this->removeUserFromGroup(        {
            'username'      => ["ZxcvPoiu4"],
            'groupname'     => ['NewGroup'],
            'action'        => ['removeUserFromGroup']
        });
    $this->assert_null( $ret, "remove one user" );
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu4" ));

    #need to reload to force Foswiki to reparse Groups :(
    $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu2" ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu3" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu4" ));

    $ret = $this->removeUserFromGroup(        {
            'username'      => ["ZxcvPoiu", "ZxcvPoiu2"],
            'groupname'     => ['NewGroup'],
            'action'        => ['removeUserFromGroup']
        });
    $this->assert_null( $ret, "remove two user" );
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));

    #need to reload to force Foswiki to reparse Groups :(
    $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu2" ));
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu3" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu4" ));

}


###########################################################################
#totoal failure type tests..
sub test_SingleAddToNewGroupNoCreate {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu', 'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    
    $ret = $this->addUserToGroup(        {
            'username'      => ['AsdfPoiu'],
            'groupname'     => ['AnotherNewGroup'],
            'create'        => [0],
            'action'        => ['addUserToGroup']
        });
    $this->assert_not_null( $ret, "can't add to new group without setting create" );
    
    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(!Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    
    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );

    $this->assert(!Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
}

sub test_NoUserAddToNewGroupCreate {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu', 'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserException( 'qwer', 'Qwer', 'Poiu', 'qwer@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserException( 'zxcv', 'Zxcv', 'Poiu', 'zxcv@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    
    $ret = $this->addUserToGroup(        {
            'username'      => [],
            'groupname'     => ['NewGroup'],
            'create'        => [1],
            'action'        => ['addUserToGroup']
        });
    $this->assert_not_null( $ret, "no users in list of users to add to group" );
    
    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(!Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));
    
    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );

    $this->assert(!Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ));
}

sub test_RemoveFromNonExistantGroup {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu', 'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    
    $ret = $this->removeUserFromGroup(        {
            'username'      => ['AsdfPoiu'],
            'groupname'     => ['AnotherNewGroup'],
            'action'        => ['removeUserFromGroup']
        });
    $this->assert_not_null( $ret, "there ain't any such group" );
    $this->assert_equals( $ret->{template}, "attention" );
    $this->assert_equals( $ret->{def}, "problem_removing_from_group" );
    
    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(!Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    
    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );

    $this->assert(!Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
}

sub test_RemoveNoUserFromExistantGroup {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserException( 'asdf', 'Asdf', 'Poiu', 'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    
    $ret = $this->removeUserFromGroup(        {
            'username'      => [],
            'groupname'     => ['AnotherNewGroup'],
            'action'        => ['removeUserFromGroup']
        });
    $this->assert_not_null( $ret, "no user.." );
    $this->assert_equals( $ret->{template}, "attention" );
    $this->assert_equals( $ret->{def}, "no_users_to_remove_from_group" );
    
    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(!Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
    
    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $q );

    $this->assert(!Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ));
    $this->assert(!Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
}

sub verify_resetEmailOkay {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)
    ### need to know the password too
    my $ret = $this->registerUserException(
        'brian', 'Brian', 'Griffin', 'brian@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    my $cUID =
      $this->{session}->{users}->getCanonicalUserID( 'brian' );
    $this->assert( $this->{session}->{users}->userExists($cUID),
        "new user created" );
    my $newPassU = '12345';
    my $oldPassU = 1;         #force set
    $this->assert(
        $this->{session}->{users}->setPassword( $cUID, $newPassU, $oldPassU ) );
    my $newEmail = 'brian@family.guy';

    my $query = new Unit::Request(
        {
            'LoginName'   => [ 'brian' ],
            'TopicName'   => ['ChangeEmailAddress'],
            'username'    => [ 'brian' ],
            'oldpassword' => ['12345'],
            'email'       => [$newEmail],
            'action'      => ['changePassword']
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/WebHome' );
    $this->{session}->finish();
    $this->{session} = new Foswiki( 'brian', $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
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
            'action'                => ['bulkRegister'],
        }
    );

    $query->path_info("/$this->{test_web}/$regTopic");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{SuperAdminGroup}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = $regTopic;
    $this->{session}->{webName}   = $this->{test_web};
    try {
        $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
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
            'action' => ['bulkRegister'],
        }
    );

    $query->path_info("/$this->{test_web}/$regTopic");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{SuperAdminGroup}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = $regTopic;
    $this->{session}->{webName}   = $this->{test_web};
    try {
        my ($text) = $this->captureWithKey( manage => $MAN_UI_FN,
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

sub verify_deleteUser {
    my $this = shift;
    my $ret = $this->registerUserException(
        'eric', 'Eric', 'Cartman', 'eric@example.com' );
    $this->assert_null( $ret, "Respect mah authoritah" );

    my $cUID =
      $this->{session}->{users}->getCanonicalUserID( 'eric' );
    my $newPassU = '12345';
    my $oldPassU = 1;         #force set
    $this->assert(
        $this->{session}->{users}->setPassword(
            $cUID, $newPassU, $oldPassU ) );

    my $query = new Unit::Request(
        {
            'password' => ['12345'],
            'action' => ['deleteUserAccount'],
        }
    );
    $query->path_info("/$this->{test_web}/Arbitrary");
    $this->{session}->finish();
    $this->{session} = new Foswiki( 'eric', $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = 'Arbitrary';
    $this->{session}->{webName}   = $this->{test_web};

    try {
        $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "remove_user_done", $e->{def}, $e->stringify() );
        my $johndoe = 'eric';
        if ($Foswiki::cfg{Register}{AllowLoginName}) {
            $johndoe = 'EricCartman';
        }
        $this->assert_str_equals(
            $johndoe,
            ${ $e->{params} }[0],
            ${ $e->{params} }[0]
        );
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
}

1;
