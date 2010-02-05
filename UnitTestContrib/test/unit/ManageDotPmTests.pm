

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
    $this->assert(Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ));
}

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

1;
