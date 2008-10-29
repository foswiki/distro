package FuncUsersTests;

use strict;
use warnings;


# Some basic tests for adding/removing users in the TWiki users topic,
# and finding them again.

use base qw(TWikiFnTestCase);

use TWiki;
use TWiki::Func;
use TWiki::UI::Register;
use Error qw( :try );
use Data::Dumper;

my %loginname;

sub new {
    my $self = shift()->SUPER::new('FuncUsers', @_);
    return $self;
}

sub AllowLoginName {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 1;
    $loginname{UserA} = 'usera';
    $loginname{UserA86} = 'usera86';
    $loginname{User86A} = 'user86a';
    $loginname{UserB} = 'userb';
    $loginname{UserC} = 'userc';
    $loginname{NonExistantuser} = 'nonexistantuser';
    $loginname{ScumBag} = 'scum';
    $loginname{UserZ} = 'userz';
}
sub DontAllowLoginName {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 0;
    $loginname{UserA} = 'UserA';
    $loginname{UserA86} = 'UserA86';
    $loginname{User86A} = 'User86A';
    $loginname{UserB} = 'UserB';
    $loginname{UserC} = 'UserC';
    $loginname{NonExistantuser} = 'NonExistantuser';
    $loginname{ScumBag} = 'scum';   #the scum user was registered _before_ these options in the base class
    $loginname{UserZ} = 'UserZ';
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

sub NonePasswordManager {
    $TWiki::cfg{PasswordManager} = 'none';
}

sub HtPasswordPasswordManager {
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
}


# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {
    return (
        [ 'NoLoginManager', 'ApacheLoginManager', 'TemplateLoginManager' ],
        [ 'AllowLoginName', 'DontAllowLoginName'],
        [ 'TWikiUserMapping' ],
        [ 'NonePasswordManager', 'HtPasswordPasswordManager' ]);

=pod

    return (
        [ 'TemplateLoginManager', 'ApacheLoginManager', 'NoLoginManager' ],
        [ 'AllowLoginName', 'DontAllowLoginName'],
#        [ 'TWikiUserMapping', 'BaseUserMapping' ] );
        [ 'TWikiUserMapping' ] );

=cut

}

#delay the calling of set_up til after the cfg's are set by above closure
sub set_up_for_verify {
    my $this = shift;

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki($TWiki::cfg{AdminUserLogin});

    if ($this->{twiki}->inContext('registration_supported') && $this->{twiki}->inContext('registration_enabled'))  {
        try {
            $this->registerUser($loginname{UserA}, 'User', 'A', 'user@example.com');
            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
            #TODO: 
            #this should fail... as its the same as the one above
            #$this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
            #this one does fail..
            #$this->registerUser('86usera', '86User', 'A', 'user86a@example.com');
            $this->registerUser($loginname{UserB}, 'User', 'B', 'user@example.com');
            $this->registerUser($loginname{UserC}, 'User', 'C', 'userc@example.com;userd@example.com');

            $this->registerUser($loginname{UserZ}, 'User', 'Z', 'userZ@example.com');


            $this->{twiki}->{store}->saveTopic(
                $this->{twiki}->{user},
                $this->{users_web}, 'AandBGroup',
                "   * Set GROUP = UserA, UserB, $TWiki::cfg{AdminUserWikiName}");
            $this->{twiki}->{store}->saveTopic(
                $this->{twiki}->{user},
                $this->{users_web}, 'AandCGroup',
                "   * Set GROUP = UserA, UserC");
            $this->{twiki}->{store}->saveTopic(
                $this->{twiki}->{user},
                $this->{users_web}, 'BandCGroup',
                "   * Set GROUP = UserC, UserB");
            $this->{twiki}->{store}->saveTopic(
                $this->{twiki}->{user},
                $this->{users_web}, 'ScumGroup',
                "   * Set GROUP = UserA, $TWiki::cfg{DefaultUserWikiName}, $loginname{UserZ}");
            $this->{twiki}->{store}->saveTopic(
                $this->{twiki}->{user},
                $this->{users_web}, $TWiki::cfg{SuperAdminGroup},
                "   * Set GROUP = UserA, $TWiki::cfg{AdminUserWikiName}");
        } catch TWiki::AccessControlException with {
            my $e = shift;
            $this->assert(0,$e->stringify());
        } catch Error::Simple with {
            $this->assert(0,shift->stringify()||'');
        };
        # Force a re-read
        $this->{twiki}->finish();
        $this->{twiki} = new TWiki();
        $TWiki::Plugins::SESSION = $this->{twiki};
    }
    @TWikiFntestCase::mails = ();
}

sub verify_emailToWikiNames {
    my $this = shift;
    my @users = TWiki::Func::emailToWikiNames('userc@example.com', 1);
    $this->assert_str_equals("UserC", join(',', @users));
    @users = TWiki::Func::emailToWikiNames('userd@example.com', 0);
    $this->assert_str_equals("$this->{users_web}.UserC", join(',', @users));
    @users = TWiki::Func::emailToWikiNames('user@example.com', 1);
    $this->assert_str_equals("UserA,UserB", join(',', sort @users));
}

sub verify_wikiNameToEmails {
    my $this = shift;
    my @emails = TWiki::Func::wikinameToEmails('UserA');
    $this->assert_str_equals("user\@example.com", join(',', @emails));
    @emails = TWiki::Func::wikinameToEmails('UserB');
    $this->assert_str_equals("user\@example.com", join(',', @emails));
    @emails = TWiki::Func::wikinameToEmails('UserC');
    $this->assert_str_equals("userd\@example.com,userc\@example.com",
                             join(',', reverse sort @emails));
    @emails = TWiki::Func::wikinameToEmails('AandCGroup');
    $this->assert_str_equals("userd\@example.com,userc\@example.com,user\@example.com",
                             join(',', reverse sort @emails));
}

sub verify_eachUser {
    my $this = shift;
    @TWikiFntestCase::mails = ();

    my @list;
    my $ite = TWiki::Func::eachUser();
    while ($ite->hasNext()) {
        my $u = $ite->next();
        push(@list, $u);
    }
    my $ulist = join(',', sort @list);

    my @correctList;
    if ($TWiki::cfg{UserMappingManager} eq 'TWiki::Users::BaseUserMapping') {
         @correctList = qw/TWikiContributor TWikiGuest TWikiRegistrationAgent UnknownUser/;
    } else {
         @correctList = qw/TWikiContributor TWikiGuest TWikiRegistrationAgent UnknownUser User86A UserA UserA86 UserB UserC UserZ/;
         if ($TWiki::cfg{Register}{AllowLoginName} == 1) {
             push @correctList, 'ScumBag';      # this user is created in the base class with the assumption of AllowLoginName 
         } else {
             push @correctList, 'scum';         # 
         }
    }
    push @correctList, $TWiki::cfg{AdminUserWikiName};
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}

sub verify_eachGroupTraditional {
    my $this = shift;
    my @list;

    $TWiki::cfg{SuperAdminGroup} = 'TWikiAdminGroup';
    # Force a re-read
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $TWiki::Plugins::SESSION = $this->{twiki};
    @TWikiFntestCase::mails = ();

    my $ite = TWiki::Func::eachGroup();
    while ($ite->hasNext()) {
        my $u = $ite->next();
        push(@list, $u);
    }
    my $ulist = join(',', sort @list);
    my @correctList;
    if ($TWiki::cfg{UserMappingManager} eq 'TWiki::Users::BaseUserMapping') {
         @correctList = qw/TWikiAdminGroup TWikiBaseGroup/;
    } else {
         @correctList = qw/AdminGroup AandBGroup AandCGroup BandCGroup ScumGroup TWikiAdminGroup TWikiBaseGroup/;
    }
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}

sub verify_eachGroupCustomAdmin {
    my $this = shift;
    my @list;

    $TWiki::cfg{SuperAdminGroup} = 'Super Admin';
    # Force a re-read
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $TWiki::Plugins::SESSION = $this->{twiki};
    @TWikiFntestCase::mails = ();

    my $ite = TWiki::Func::eachGroup();
    while ($ite->hasNext()) {
        my $u = $ite->next();
        push(@list, $u);
    }
    my $ulist = join(',', sort @list);
    my @correctList;
    if ($TWiki::cfg{UserMappingManager} eq 'TWiki::Users::BaseUserMapping') {
         @correctList = qw/TWikiBaseGroup/;
    } else {
         @correctList = qw/AdminGroup AandBGroup AandCGroup BandCGroup ScumGroup TWikiBaseGroup/; 
    }
    push @correctList, $TWiki::cfg{SuperAdminGroup};
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}


# SMELL: nothing tests if we are an admin!
sub verify_isAnAdmin {
    my $this = shift;
    my $iterator = TWiki::Func::eachUser();
    while ($iterator->hasNext()) {
        my $u = $iterator->next();
        $u =~ /.*\.(.*)/;
        $TWiki::Plugins::SESSION->{user} = $u;
        my $sadmin = TWiki::Func::isAnAdmin($u);
        if ($u eq $TWiki::cfg{AdminUserWikiName} || $u eq 'UserA') {
	        $this->assert($sadmin, $u);
        } else {
	        $this->assert(!$sadmin, $u);
        }
    }
}

sub verify_isGroupMember {
    my $this = shift;
    $TWiki::Plugins::SESSION->{user} =
      $TWiki::Plugins::SESSION->{users}->getCanonicalUserID($loginname{UserA});
    $this->assert(TWiki::Func::isGroupMember('AandBGroup'));
    $this->assert(TWiki::Func::isGroupMember('AandCGroup'));
    $this->assert(!TWiki::Func::isGroupMember('BandCGroup'));
    $this->assert(TWiki::Func::isGroupMember('BandCGroup', 'UserB'));
    $this->assert(TWiki::Func::isGroupMember('BandCGroup', 'UserC'));
    $this->assert(TWiki::Func::isGroupMember('ScumGroup', $TWiki::cfg{DefaultUserWikiName}));

    $this->assert(TWiki::Func::isGroupMember('ScumGroup', 'UserZ'));
    $this->assert(TWiki::Func::isGroupMember('ScumGroup', $loginname{UserZ}));

}

sub verify_eachMembership {
    my $this = shift;

    my @list;
    my $it = TWiki::Func::eachMembership('UserA');
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('AandBGroup,AandCGroup,AdminGroup,ScumGroup', join(',', sort @list));
    $it = TWiki::Func::eachMembership('UserB');
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('AandBGroup,BandCGroup', join(',', sort @list));
    
    $it = TWiki::Func::eachMembership('UserC');
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('AandCGroup,BandCGroup', sort join(',', @list));
    
    $it = TWiki::Func::eachMembership('TWikiGuest');
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('TWikiBaseGroup,ScumGroup', sort join(',', @list));

    $it = TWiki::Func::eachMembership($loginname{UserZ});
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('ScumGroup', sort join(',', @list));
    
    $it = TWiki::Func::eachMembership('UserZ');
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('ScumGroup', sort join(',', @list));

}

sub verify_eachMembershipDefault {
    my $this = shift;
    my $it = TWiki::Func::eachMembership();
    my @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
	$this->annotate($TWiki::Plugins::SESSION->{user}." is member of...\n");
    $this->assert_str_equals('TWikiBaseGroup,ScumGroup', sort join(',', @list));
}

sub verify_eachGroupMember {
    my $this = shift;
    my $it = TWiki::Func::eachGroupMember('AandBGroup');
    my @list;
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals("UserA,UserB,$TWiki::cfg{AdminUserWikiName}", sort join(',', @list));
    
    $it = TWiki::Func::eachGroupMember('ScumGroup');
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals("UserA,$TWiki::cfg{DefaultUserWikiName},UserZ", sort join(',', @list));    
    
}

sub verify_isGroup {
    my $this = shift;
    $this->assert(TWiki::Func::isGroup('AandBGroup'));
    $this->assert(!TWiki::Func::isGroup('UserA'));


    $this->assert(TWiki::Func::isGroup($TWiki::cfg{SuperAdminGroup}));
    $this->assert(TWiki::Func::isGroup('TWikiBaseGroup'));

    
    #Item5540
    $this->assert(!TWiki::Func::isGroup('S'));
    $this->assert(!TWiki::Func::isGroup('1'));
    $this->assert(!TWiki::Func::isGroup('AS'));
    $this->assert(!TWiki::Func::isGroup(''));
    $this->assert(!TWiki::Func::isGroup('#'));
}

sub verify_getCanonicalUserID_extended {
	my $this = shift;
    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});

    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID());

    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{DefaultUserLogin}));
    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID($guest_cUID));
    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{DefaultUserWikiName}));
    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($admin_cUID));
    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA});
    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID($usera_cUID));
    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID($loginname{UserA}));
    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID('UserA'));
    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'UserA'));


#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA86});
    $this->assert_str_equals($usera86_cUID, TWiki::Func::getCanonicalUserID($usera86_cUID));
    $this->assert_str_equals($usera86_cUID, TWiki::Func::getCanonicalUserID($loginname{UserA86}));
    $this->assert_str_equals($usera86_cUID, TWiki::Func::getCanonicalUserID('UserA86'));
    $this->assert_str_equals($usera86_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'UserA86'));
#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{User86A});
    $this->assert_str_equals($user86a_cUID, TWiki::Func::getCanonicalUserID($user86a_cUID));
    $this->assert_str_equals($user86a_cUID, TWiki::Func::getCanonicalUserID($loginname{User86A}));
    $this->assert_str_equals($user86a_cUID, TWiki::Func::getCanonicalUserID('User86A'));
    $this->assert_str_equals($user86a_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'User86A'));
#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

    #TODO: consider how to render unkown user's
    $this->assert_null($this->{twiki}->{users}->getCanonicalUserID($loginname{NonExistantuser}));
    my $cUID = TWiki::Func::getCanonicalUserID($loginname{NonExistantuser});
    $this->assert_null($cUID, $cUID);
    $this->assert_null(TWiki::Func::getCanonicalUserID('NonExistantUser'));
    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));
    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser86'));

    #TODO: consider what to return for GROUPs
#    $this->assert_null($this->{twiki}->{users}->getCanonicalUserID('AandBGroup'));
#    $this->assert_null(TWiki::Func::getCanonicalUserID('AandBGroup'));
#    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));

    #TODO: consider what to return for GROUPs
#    $this->assert_null($this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{SuperAdminGroup}));
#    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{SuperAdminGroup}));
#    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{SuperAdminGroup}));
}

sub verify_getWikiName_extended {
	my $this = shift;
	
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName());

    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{DefaultUserLogin}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($guest_cUID));
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{DefaultUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));

    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->annotate($admin_cUID.' => '.$TWiki::cfg{AdminUserLogin}.' => '.$TWiki::cfg{AdminUserWikiName});
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($admin_cUID));
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA});
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName($usera_cUID));
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName($loginname{UserA}));
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName('UserA'));
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'UserA'));
    
#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA86});
    $this->assert_str_equals('UserA86', TWiki::Func::getWikiName($usera86_cUID));
    $this->assert_str_equals('UserA86', TWiki::Func::getWikiName($loginname{UserA86}));
    $this->assert_str_equals('UserA86', TWiki::Func::getWikiName('UserA86'));
    $this->assert_str_equals('UserA86', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'UserA86'));
#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{User86A});
    $this->assert_str_equals('User86A', TWiki::Func::getWikiName($user86a_cUID));
    $this->assert_str_equals('User86A', TWiki::Func::getWikiName($loginname{User86A}));
    $this->assert_str_equals('User86A', TWiki::Func::getWikiName('User86A'));
    $this->assert_str_equals('User86A', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'User86A'));
#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

    #TODO: consider how to render unkown user's
    #$TWiki::cfg{RenderLoggedInButUnknownUsers} is false, or undefined

    $this->assert_str_equals('TWikiUserMapping_NonExistantUser', TWiki::Func::getWikiName('TWikiUserMapping_NonExistantUser'));
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{NonExistantuser});
    $this->annotate($nonexistantuser_cUID);      #returns guest
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($nonexistantuser_cUID));
    $this->assert_str_equals($loginname{NonExistantuser}, TWiki::Func::getWikiName($loginname{NonExistantuser}));
    $this->assert_str_equals('NonExistantUser', TWiki::Func::getWikiName('NonExistantUser'));
    $this->assert_str_equals('NonExistantUser', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));
    $this->assert_str_equals('NonExistantUser86', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser86'));

    #TODO: consider how to render unkown user's
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName($AandBGroup_cUID));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName('AandBGroup'));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName('AandBGroup'));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_getWikiUserName_extended {
	my $this = shift;
	
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName());

    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{DefaultUserLogin}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($guest_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{DefaultUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($admin_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA});
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName($usera_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName($loginname{UserA}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName('UserA'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'UserA'));

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA86});
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA86', TWiki::Func::getWikiUserName($usera86_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA86', TWiki::Func::getWikiUserName($loginname{UserA86}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA86', TWiki::Func::getWikiUserName('UserA86'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA86', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'UserA86'));
#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{User86A});
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'User86A', TWiki::Func::getWikiUserName($user86a_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'User86A', TWiki::Func::getWikiUserName($loginname{User86A}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'User86A', TWiki::Func::getWikiUserName('User86A'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'User86A', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'User86A'));
#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');


    #TODO: consider how to render unkown user's
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf', TWiki::Func::getWikiUserName('NonExistantUserAsdf'));
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuserasdf');
    $this->annotate($nonexistantuser_cUID);     #returns guest
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($nonexistantuser_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'nonexistantuserasdf', TWiki::Func::getWikiUserName('nonexistantuserasdf'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'nonexistantuserasdfqwer', TWiki::Func::getWikiUserName('nonexistantuserasdfqwer'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf', TWiki::Func::getWikiUserName('NonExistantUserAsdf'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf86', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf86'));

    #TODO: consider how to render unkown user's
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName($AandBGroup_cUID));
    #$this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName('AandBGroup'));
    #$this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName('AandBGroup'));
    #$this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_wikiToUserName_extended {
	my $this = shift;
	
#TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($guest_cUID));
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{DefaultUserLogin}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{DefaultUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($admin_cUID));
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA});
    $this->assert_str_equals($loginname{UserA}, TWiki::Func::wikiToUserName($usera_cUID));
    $this->assert_str_equals($loginname{UserA}, TWiki::Func::wikiToUserName($loginname{UserA}));
    $this->assert_str_equals($loginname{UserA}, TWiki::Func::wikiToUserName('UserA'));
    $this->assert_str_equals($loginname{UserA}, TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'UserA'));

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA86});
    $this->assert_str_equals($loginname{UserA86}, TWiki::Func::wikiToUserName($usera86_cUID));
    $this->assert_str_equals($loginname{UserA86}, TWiki::Func::wikiToUserName($loginname{UserA86}));
    $this->assert_str_equals($loginname{UserA86}, TWiki::Func::wikiToUserName('UserA86'));
    $this->assert_str_equals($loginname{UserA86}, TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'UserA86'));
#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{User86A});
    $this->assert_str_equals($loginname{User86A}, TWiki::Func::wikiToUserName($user86a_cUID));
    $this->assert_str_equals($loginname{User86A}, TWiki::Func::wikiToUserName($loginname{User86A}));
    $this->assert_str_equals($loginname{User86A}, TWiki::Func::wikiToUserName('User86A'));
    $this->assert_str_equals($loginname{User86A}, TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'User86A'));
#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

    #TODO: consider how to render unkown user's
    $this->assert_null(TWiki::Func::wikiToUserName('TWikiUserMapping_NonExistantUser'));
    $this->assert_null(TWiki::Func::wikiToUserName($loginname{NonExistantuser}));
    $this->assert_null(TWiki::Func::wikiToUserName('NonExistantUser'));
    $this->assert_null(TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));
    $this->assert_null(TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser86'));

    #TODO: consider how to render unkown user's
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName($AandBGroup_cUID));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName('AandBGroup'));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName('AandBGroup'));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_isAnAdmin_extended {
	my $this = shift;
	
#TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{DefaultUserLogin}));
    $this->assert(!TWiki::Func::isAnAdmin($guest_cUID));
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{DefaultUserWikiName}));
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert(TWiki::Func::isAnAdmin($admin_cUID));
    $this->assert(TWiki::Func::isAnAdmin($TWiki::cfg{AdminUserLogin}));
    $this->assert(TWiki::Func::isAnAdmin($TWiki::cfg{AdminUserWikiName}));
    $this->assert(TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA});
    $this->assert(TWiki::Func::isAnAdmin($usera_cUID));
    $this->assert(TWiki::Func::isAnAdmin($loginname{UserA}));
    $this->assert(TWiki::Func::isAnAdmin('UserA'));
    $this->assert(TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'UserA'));

    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'UserB'));
    my $userb_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserB});
    $this->assert(!TWiki::Func::isAnAdmin($userb_cUID));
    $this->assert(!TWiki::Func::isAnAdmin($loginname{UserB}));
    $this->assert(!TWiki::Func::isAnAdmin('UserB'));


    #TODO: consider how to render unkown user's
    $this->assert(!TWiki::Func::isAnAdmin('TWikiUserMapping_NonExistantUser'));
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{NonExistantuser});
    $this->annotate($nonexistantuser_cUID);
    $this->assert(!TWiki::Func::isAnAdmin($nonexistantuser_cUID));
    $this->assert(!TWiki::Func::isAnAdmin($loginname{NonExistantuser}));
    $this->assert(!TWiki::Func::isAnAdmin('NonExistantUser'));
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));

    #TODO: consider how to render unkown user's
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert(!TWiki::Func::isAnAdmin($AandBGroup_cUID));
    #$this->assert(!TWiki::Func::isAnAdmin('AandBGroup'));
    #$this->assert(!TWiki::Func::isAnAdmin('AandBGroup'));
    #$this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}


sub verify_isGroupMember_extended {
	my $this = shift;
	
#TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{DefaultUserLogin}));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $guest_cUID));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{DefaultUserWikiName}));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $admin_cUID));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{AdminUserLogin}));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{AdminUserWikiName}));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    $this->assert(!TWiki::Func::isGroupMember('AandCGroup', $admin_cUID));
    $this->assert(!TWiki::Func::isGroupMember('AandCGroup', $TWiki::cfg{AdminUserLogin}));
    $this->assert(!TWiki::Func::isGroupMember('AandCGroup', $TWiki::cfg{AdminUserWikiName}));
    $this->assert(!TWiki::Func::isGroupMember('AandCGroup', $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));


    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserA});
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $usera_cUID));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $loginname{UserA}));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', 'UserA'));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.'UserA'));

    #TODO: consider how to render unkown user's
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{NonExistantuser});
    $this->annotate($nonexistantuser_cUID);
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $nonexistantuser_cUID));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $loginname{NonExistantuser}));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', 'NonExistantUser'));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));

    #TODO: consider how to render unkown user's
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert(!TWiki::Func::isGroupMember('AandBGroup', $AandBGroup_cUID));
    #$this->assert(!TWiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
    #$this->assert(!TWiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
    #$this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));

#baseusermapping group
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{DefaultUserLogin}));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $guest_cUID));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{DefaultUserWikiName}));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $admin_cUID));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{AdminUserLogin}));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{AdminUserWikiName}));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $usera_cUID));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $loginname{UserA}));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, 'UserA'));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.'UserA'));

    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $loginname{UserB}));
    my $userb_cUID = $this->{twiki}->{users}->getCanonicalUserID($loginname{UserB});
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $userb_cUID));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, 'UserB'));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.'UserB'));

}

1;
