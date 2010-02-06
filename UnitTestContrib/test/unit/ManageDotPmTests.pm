

#TODO: permission tests
#TODO: non-existant user test

use strict;
use warnings;
use diagnostics;

package ManageDotPmTests;

use base qw(FoswikiFnTestCase);
use Error qw(:try);
use Foswiki;
use Foswiki::UI::Manage;
use Foswiki::UI::Save;

#my $systemWeb = "TemporaryManageTestsSystemWeb";


# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    
#    my $webObject = Foswiki::Meta->new( $this->{session}, $systemWeb );
#    $webObject->populateNewWeb( $Foswiki::cfg{SystemWebName} );
#    $Foswiki::cfg{SystemWebName} = $systemWeb;
#    $Foswiki::cfg{EnableEmail}   = 1;
    
#    $Error::Debug = 1;

    @FoswikiFnTestCase::mails = ();

}
sub tear_down {
    my $this = shift;

#    $this->removeWebFixture( $this->{session}, $systemWeb );
    $this->SUPER::tear_down();
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
        no strict 'refs';
        $this->captureWithKey( register => $this->getUIFn('register'), $fatwilly );
        no strict 'refs';
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


1;
