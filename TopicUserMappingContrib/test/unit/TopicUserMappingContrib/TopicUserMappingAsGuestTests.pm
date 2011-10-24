# See bottom of file for license and copyright information
package TopicUserMappingAsGuestTests;

use strict;
use warnings;

# Some basic tests for Foswiki::Users::TopicUserMapping
#
# The tests are performed using the APIs published by the facade class,
# Foswiki:Users, not the actual Foswiki::Users::TopicUserMapping

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Foswiki;
use Foswiki::Users;
use Foswiki::Users::TopicUserMapping;
use Error qw( :try );

my $fatwilly;

my $testSysWeb    = 'TemporaryTopicUserMappingAsGuestTestsSystemWeb';
my $testNormalWeb = "TemporaryTopicUserMappingAsGuestTestsNormalWeb";
my $testUsersWeb  = "TemporaryTopicUserMappingAsGuestTestsUsersWeb";
my $testUser;

sub fixture_groups {
    return ( [ 'useHtpasswdMgr', 'noPasswdMgr' ],
        [ 'NormalTopicUserMapping', 'NamedTopicUserMapping', ] );
}

sub NormalTopicUserMapping {
    my $this = shift;
    $Foswiki::Users::TopicUserMapping::FOSWIKI_USER_MAPPING_ID = '';
    $this->set_up_for_verify();

    return;
}

sub NamedTopicUserMapping {
    my $this = shift;

    # Set a mapping ID for purposes of testing named mappings
    $Foswiki::Users::TopicUserMapping::FOSWIKI_USER_MAPPING_ID = 'TestMapping_';
    $this->set_up_for_verify();

    return;
}

sub useHtpasswdMgr {
    my $this = shift;

    $Foswiki::cfg{PasswordManager} = "Foswiki::Users::HtPasswdUser";

    return;
}

sub noPasswdMgr {
    my $this = shift;

    $Foswiki::cfg{PasswordManager} = "none";

    return;
}

# Override default set_up in base class; will call it after the mapping
#  id has been set
sub set_up {

    return;
}

# Delay the calling of set_up till after the cfg's are set by above closure
sub set_up_for_verify {
    my $this = shift;

    $this->SUPER::set_up();

    my $original = $Foswiki::cfg{SystemWebName};
    $Foswiki::cfg{Htpasswd}{FileName} =
      "$Foswiki::cfg{TempfileDir}/junkhtpasswd";
    $Foswiki::cfg{UsersWebName}         = $testUsersWeb;
    $Foswiki::cfg{SystemWebName}        = $testSysWeb;
    $Foswiki::cfg{LocalSitePreferences} = "$testUsersWeb.SitePreferences";
    $Foswiki::cfg{UserMappingManager}   = 'Foswiki::Users::TopicUserMapping';
    $Foswiki::cfg{Register}{AllowLoginName}            = 1;
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;

    try {
        $fatwilly = Foswiki->new( $Foswiki::cfg{DefaultUserWikiName} );
        Foswiki::Func::createWeb($testUsersWeb);

        # the group is recursive to force a recursion block
        Foswiki::Func::saveTopic( $testUsersWeb, $Foswiki::cfg{SuperAdminGroup},
            undef, "   * Set GROUP = $Foswiki::cfg{SuperAdminGroup}\n" );

        Foswiki::Func::createWeb( $testSysWeb,    $original );
        Foswiki::Func::createWeb( $testNormalWeb, '_default' );

        my $oprefs =
          Foswiki::Meta->load( $fatwilly, $testSysWeb,
            $Foswiki::cfg{SitePrefsTopicName} );
        my $nprefs =
          Foswiki::Meta->new( $fatwilly, $testSysWeb,
            $Foswiki::cfg{SitePrefsTopicName},
            $oprefs->text() );
        $nprefs->copyFrom($oprefs);
        $nprefs->save();

        $testUser = $this->createFakeUser($fatwilly);
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };

    return;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $fatwilly, $testUsersWeb );
    $this->removeWebFixture( $fatwilly, $testSysWeb );
    $this->removeWebFixture( $fatwilly, $testNormalWeb );
    unlink $Foswiki::cfg{Htpasswd}{FileName};
    $fatwilly->finish();
    $this->SUPER::tear_down();

    return;
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $initial = <<'THIS';
	* A - <a name="A">- - - -</a>
    * AttilaTheHun - 10 Jan 1601
	* B - <a name="B">- - - -</a>
	* BungditDin - 10 Jan 2004
	* C - <a name="C">- - - -</a>
	* D - <a name="D">- - - -</a>
	* E - <a name="E">- - - -</a>
	* F - <a name="F">- - - -</a>
	* G - <a name="G">- - - -</a>
	* GungaDin - 10 Jan 2004
	* H - <a name="H">- - - -</a>
	* I - <a name="I">- - - -</a>
	* J - <a name="J">- - - -</a>
	* K - <a name="K">- - - -</a>
	* L - <a name="L">- - - -</a>
	* M - <a name="M">- - - -</a>
	* N - <a name="N">- - - -</a>
	* O - <a name="O">- - - -</a>
	* P - <a name="P">- - - -</a>
	* Q - <a name="Q">- - - -</a>
	* R - <a name="R">- - - -</a>
	* S - <a name="S">- - - -</a>
	* SadOldMan - sad - 10 Jan 2004
	* SorryOldMan - 10 Jan 2004
	* StupidOldMan - 10 Jan 2004
	* T - <a name="T">- - - -</a>
	* U - <a name="U">- - - -</a>
	* V - <a name="V">- - - -</a>
	* W - <a name="W">- - - -</a>
	* X - <a name="X">- - - -</a>
	* Y - <a name="Y">- - - -</a>
	* Z - <a name="Z">- - - -</a>
THIS

sub createFakeUser {
    my ( $this, $session, $text, $name ) = @_;
    $this->assert( Foswiki::Func::webExists( $Foswiki::cfg{UsersWebName} ) );
    $name ||= '';
    my $base = "TemporaryTestUser" . $name;
    my $i    = 0;
    while (
        Foswiki::Func::topicExists( $Foswiki::cfg{UsersWebName}, $base . $i ) )
    {
        $i++;
    }
    $text ||= '';
    my $meta =
      Foswiki::Meta->new( $session, $Foswiki::cfg{UsersWebName}, $base . $i );
    $meta->put(
        "TOPICPARENT",
        {
            name => $Foswiki::cfg{UsersWebName} . '.'
              . $Foswiki::cfg{HomeTopicName}
        }
    );
    Foswiki::Func::saveTopic( $Foswiki::cfg{UsersWebName},
        $base . $i, undef, $text, $meta );
    push( @{ $this->{fake_users} }, $base . $i );
    return $base . $i;
}

sub groupFix {
    my $this = shift;
    my $me   = $Foswiki::cfg{Register}{RegistrationAgentWikiName};
    $fatwilly->{users}->{mapping}->addUser( "auser", "AaronUser",    $me );
    $fatwilly->{users}->{mapping}->addUser( "guser", "GeorgeUser",   $me );
    $fatwilly->{users}->{mapping}->addUser( "zuser", "ZebediahUser", $me );
    $fatwilly->{users}->{mapping}->addUser( "scum",  "ScumUser",     $me );
    Foswiki::Func::saveTopic( $testUsersWeb, 'AmishGroup', undef,
        "   * Set GROUP = AaronUser,%MAINWEB%.GeorgeUser, scum\n" );
    Foswiki::Func::saveTopic( $testUsersWeb, 'BaptistGroup', undef,
        "   * Set GROUP = GeorgeUser,$testUsersWeb.ZebediahUser\n" );
    Foswiki::Func::saveTopic( $testUsersWeb, 'MultiLineGroup', undef,
"   * Set GROUP = GeorgeUser,$testUsersWeb.ZebediahUser\n   AaronUser, scum\n"
    );

    # Item10097 - ensure view protected groups don't show up in SEARCHes
    Foswiki::Func::saveTopic(
        $testUsersWeb, 'SecretGroup', undef, <<"HERE"
   * Set GROUP = $Foswiki::cfg{AdminUserLogin}
   * Set ALLOWTOPICVIEW = $Foswiki::cfg{SuperAdminGroup}
HERE
    );
    Foswiki::Func::saveTopic(
        $testUsersWeb, 'AanotherSecretGroup', undef, <<"HERE"
   * Set GROUP = $Foswiki::cfg{AdminUserLogin}
   * Set ALLOWTOPICVIEW = $Foswiki::cfg{SuperAdminGroup}
HERE
    );
    Foswiki::Func::saveTopic(
        $testUsersWeb, 'AaanotherSecretGroup', undef, <<"HERE"
   * Set GROUP = $Foswiki::cfg{AdminUserLogin}
   * Set ALLOWTOPICVIEW = $Foswiki::cfg{SuperAdminGroup}
HERE
    );

    ###########################
    Foswiki::Func::saveTopic(
        $testUsersWeb, 'TopGroup', undef, <<"HERE"
   * Set GROUP = AaronUser, NextHiddenGroup
HERE
    );
    Foswiki::Func::saveTopic(
        $testUsersWeb, 'NextHiddenGroup', undef, <<"HERE"
   * Set GROUP = GeorgeUser, BottomGroup
   * Set ALLOWTOPICVIEW = NextHiddenGroup
   
HERE
    );
    Foswiki::Func::saveTopic(
        $testUsersWeb, 'BottomGroup', undef, <<"HERE"
   * Set GROUP = ZebediahUser
HERE
    );

    return;
}

sub verify_getListOfGroups {
    my $this = shift;
    $this->groupFix();
    my $i = $fatwilly->{users}->eachGroup();
    my @l = ();
    while ( $i->hasNext() ) { push( @l, $i->next() ) }
    my $k = join( ',', sort @l );

# SMELL: Tasks/Item10176 - Questions about should Func API expose hidden groups.  Concensus was yes.
#$this->expect_failure();
#$this->annotate("Internal API expected to reveal hidden groups  See Tasks/Item10176 ");
#  - Topic list that should be returned if hidden groups remain hidden to Func.
#"AdminGroup,AmishGroup,BaptistGroup,BaseGroup,BottomGroup,MultiLineGroup,TopGroup"

    $this->assert_str_equals(
"AaanotherSecretGroup,AanotherSecretGroup,AdminGroup,AmishGroup,BaptistGroup,BaseGroup,BottomGroup,MultiLineGroup,NextHiddenGroup,SecretGroup,TopGroup",
        $k
    );

    return;
}

#this is the test for Item9808
sub verify_eachGroupMember {
    my $this = shift;
    $this->groupFix();
    my $i = $fatwilly->{users}->eachGroupMember('TopGroup');
    my @l = ();
    while ( $i->hasNext() ) { push( @l, $i->next() ) }
    my $k = join( ',', sort @l );
    $this->assert_str_equals(
        $Foswiki::Users::TopicUserMapping::FOSWIKI_USER_MAPPING_ID 
          . 'auser,'
          . $Foswiki::Users::TopicUserMapping::FOSWIKI_USER_MAPPING_ID
          . 'guser,'
          . $Foswiki::Users::TopicUserMapping::FOSWIKI_USER_MAPPING_ID
          . 'zuser',
        $k
    );

    return;
}

sub verify_secretGroupIsHidden {
    my $this = shift;
    my $expected =
      'AdminGroup,AmishGroup,BaptistGroup,BottomGroup,MultiLineGroup,TopGroup';
    my $result;
    my $oldSession = $this->{session};

    $this->{session} = Foswiki->new( $Foswiki::cfg{DefaultUserLogin} );
    $this->groupFix();
    my $i = $this->{session}->{users}->eachGroup();

    $result = Foswiki::Func::expandCommonVariables(<<'HERE');
%SEARCH{
  "Group$"
  type="regex"
  scope="topic"
  web="%USERSWEB%"
  nonoise="on"
  format="$topic"
  separator=","
}%
HERE
    chomp($result);
    $this->assert_str_equals( $expected, $result );
    $this->{session}->finish();
    $this->{session} = $oldSession;

    return;
}

sub verify_secretGroupIsHiddenFromGROUPINFO {
    my $this = shift;
    my $expected =
'AdminGroup, BaseGroup, AmishGroup, BaptistGroup, BottomGroup, MultiLineGroup, TopGroup';
    my $result;
    my $oldSession = $this->{session};

    $this->{session} = Foswiki->new( $Foswiki::cfg{DefaultUserLogin} );
    $this->groupFix();
    my $i = $this->{session}->{users}->eachGroup();

    $result = Foswiki::Func::expandCommonVariables(<<'HERE');
%GROUPINFO{
}%
HERE
    chomp($result);
    $this->assert_str_equals( $expected, $result );
    $this->{session}->finish();
    $this->{session} = $oldSession;

    return;
}

#this is the test for Item9808
#however, Sven is a bit bothered by the fact that this expanded result reveals the Content of the hidden group :(
sub verify_eachGroupMemberGROUPINFO {
    my $this = shift;
    $this->groupFix();

    #my $i = $fatwilly->{users}->eachGroupMember('TopGroup');
    my $i = $fatwilly->{users}->eachGroup();    #prime the cache

    my $result = Foswiki::Func::expandCommonVariables(<<'HERE');
%GROUPINFO{"TopGroup"}%
HERE
    chomp($result);
    $this->assert_str_equals(
'TemporaryTopicUserMappingAsGuestTestsUsersWeb.AaronUser, TemporaryTopicUserMappingAsGuestTestsUsersWeb.GeorgeUser, TemporaryTopicUserMappingAsGuestTestsUsersWeb.ZebediahUser',
        $result
    );

    return;
}

#TODO: consider what happens if the user topic is hidden..

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
