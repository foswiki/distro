# See bottom of file for license and copyright information
package TopicUserMappingTests;
use strict;
use warnings;

# Some basic tests for Foswiki::Users::TopicUserMapping
#
# The tests are performed using the APIs published by the facade class,
# Foswiki:Users, not the actual Foswiki::Users::TopicUserMapping

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Foswiki();
use Foswiki::Func();
use Foswiki::Users();
use Foswiki::Users::TopicUserMapping();
use Error qw( :try );

my $testSysWeb    = 'TemporaryTopicUserMappingTestsSystemWeb';
my $testNormalWeb = "TemporaryTopicUserMappingTestsNormalWeb";
my $testUsersWeb  = "TemporaryTopicUserMappingTestsUsersWeb";
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

    # Reduced runtimes from ~17s down to ~3s elapsed on my machine
    $Foswiki::cfg{Store}{Implementation} = "Foswiki::Store::RcsLite";

    try {
        $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
        Foswiki::Func::createWeb($testUsersWeb);

        # the group is recursive to force a recursion block
        Foswiki::Func::saveTopic( $testUsersWeb, $Foswiki::cfg{SuperAdminGroup},
            undef, "   * Set GROUP = $Foswiki::cfg{SuperAdminGroup}\n" );

        Foswiki::Func::createWeb( $testSysWeb,    $original );
        Foswiki::Func::createWeb( $testNormalWeb, '_default' );

        my ($oprefs) =
          Foswiki::Func::readTopic( $testSysWeb,
            $Foswiki::cfg{SitePrefsTopicName} );
        my ($nprefs) =
          Foswiki::Func::readTopic( $testSysWeb,
            $Foswiki::cfg{SitePrefsTopicName} );
        $nprefs->text( $oprefs->text() );
        $nprefs->copyFrom($oprefs);
        $nprefs->save();
        $nprefs->finish();
        $oprefs->finish();

        $testUser = $this->createFakeUser( $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
    $this->{ttpath} =
"$Foswiki::cfg{DataDir}/$Foswiki::cfg{UsersWebName}/$Foswiki::cfg{UsersTopicName}.txt";

    return;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $testUsersWeb );
    $this->removeWebFixture( $this->{session}, $testSysWeb );
    $this->removeWebFixture( $this->{session}, $testNormalWeb );
    unlink $Foswiki::cfg{Htpasswd}{FileName};
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
    my ( $this, $fatwilly, $text, $name ) = @_;
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
    my ($meta) =
      Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName}, $base . $i );
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
    $meta->finish();
    return $base . $i;
}

sub verify_AddUsers {
    my $this = shift;
    my $me   = $Foswiki::cfg{Register}{RegistrationAgentWikiName};

    $this->assert( open( my $F, '>', $this->{ttpath} ),
        "open $this->{ttpath} failed" );
    print $F $initial;
    $this->assert( close($F) );
    chmod( 0777, $this->{ttpath} );
    $this->{session}->{users}->{mapping}->addUser( "guser", "GeorgeUser", $me );
    $this->assert( open( $F, '<', $this->{ttpath} ) );
    local $/ = undef;
    my $text = <$F>;
    $this->assert( close($F) );
    $this->assert_matches(
        qr/\n\s+\* GeorgeUser - guser - \d\d \w\w\w \d\d\d\d\n/s, $text );
    $this->{session}->{users}->{mapping}->addUser( "auser", "AaronUser", $me );
    $this->assert( open( $F, '<', $this->{ttpath} ) );
    local $/ = undef;
    $text = <$F>;
    $this->assert( close($F) );
    $this->assert_matches( qr/AaronUser.*GeorgeUser/s, $text );
    $this->{session}->{users}->{mapping}
      ->addUser( "zuser", "ZebediahUser", $me );
    $this->assert( open( $F, '<', $this->{ttpath} ) );
    local $/ = undef;
    $text = <$F>;
    $this->assert( close($F) );
    $this->assert_matches( qr/Aaron.*George.*Zebediah/s, $text );

    return;
}

sub verify_RemoveUsers {
    my $this = shift;
    my $me   = $Foswiki::cfg{Register}{RegistrationAgentWikiName};

    $this->assert( open( my $F, '>', $this->{ttpath} ),
        "open $this->{ttpath} failed" );
    print $F $initial;
    $this->assert( close($F) );
    chmod( 0777, $this->{ttpath} );

    #my ( $this, $login, $wikiname, $password, $emails ) = @_;
    $this->{session}->{users}->{mapping}->addUser( "guser", "GeorgeUser", $me );
    $this->{session}->{users}->{mapping}->addUser( "auser", "AaronUser",  $me );
    $this->{session}->{users}->{mapping}->addUser( "xuser", "XenonUser",  $me );
    $this->{session}->{users}->{mapping}
      ->addUser( "zuser", "ZebediahUser", $me );

    $this->assert( open( $F, '<', $this->{ttpath} ) );
    local $/ = undef;
    my $text = <$F>;
    $this->assert( close($F) );
    $this->assert_matches(
        qr/\n\s+\* GeorgeUser - guser - \d\d \w\w\w \d\d\d\d\n/s, $text );
    $this->assert_matches( qr/Aaron.*George.*Xenon.*Zebediah/s, $text );

    $this->{session}->{users}->{mapping}->removeUser(
        $this->{session}->{users}->getCanonicalUserID("AaronUser") );
    $this->{session}->{users}->{mapping}
      ->removeUser( $this->{session}->{users}->getCanonicalUserID("zuser") );

    $this->assert( open( $F, '<', $this->{ttpath} ) );
    local $/ = undef;
    $text = <$F>;
    $this->assert( close($F) );
    $this->assert_matches( qr/George.*Xenon/s, $text );
    $this->assert_does_not_match( qr/AaronUser/, $text );
    $this->assert_does_not_match( qr/zuser/,     $text );

    return;
}

sub verify_Load {
    my $this = shift;

    my $me = $Foswiki::cfg{Register}{RegistrationAgentWikiName};

    $this->assert( open( my $F, '>', $this->{ttpath} ),
        "open $this->{ttpath} failed" );
    print $F $initial;
    $this->assert( close($F) );

    my $zuser_id =
      $this->{session}->{users}->{mapping}
      ->addUser( "zuser", "ZebediahUser", $me );
    my $auser_id =
      $this->{session}->{users}->{mapping}
      ->addUser( "auser", "AaronUser", $me );
    my $guser_id =
      $this->{session}->{users}->{mapping}
      ->addUser( "guser", "GeorgeUser", $me );

    # deliberate repeat
    $this->{session}->{users}->{mapping}
      ->addUser( "zuser", "ZebediahUser", $me );

    # find a nonexistent user to force a cache read
    $this->createNewFoswikiSession();
    my $n = $this->{session}->{users}->{mapping}->login2cUID("auser");
    $this->assert_str_equals( $n, $auser_id );
    $this->assert_str_equals( "AaronUser",
        $this->{session}->{users}->getWikiName($n) );
    $this->assert_str_equals( "auser",
        $this->{session}->{users}->getLoginName($n) );

    my $i = $this->{session}->{users}->eachUser();
    my @l = ();
    while ( $i->hasNext() ) {
        push( @l, $i->next() );
    }
    my $k =
      join( ",", sort map { $this->{session}->{users}->getWikiName($_) } @l );
    $this->assert( $k =~ s/^AaronUser,//,          $k );
    $this->assert( $k =~ s/^AdminUser,//,          $k );
    $this->assert( $k =~ s/^AttilaTheHun,//,       $k );
    $this->assert( $k =~ s/^BungditDin,//,         $k );
    $this->assert( $k =~ s/^GeorgeUser,//,         $k );
    $this->assert( $k =~ s/^GungaDin,//,           $k );
    $this->assert( $k =~ s/^ProjectContributor,//, $k );
    $this->assert( $k =~ s/^RegistrationAgent,//,  $k );
    $this->assert( $k =~ s/^SadOldMan,//,          $k );
    $this->assert( $k =~ s/^SorryOldMan,//,        $k );
    $this->assert( $k =~ s/^StupidOldMan,//,       $k );
    $this->assert( $k =~ s/^UnknownUser,//,        $k );
    $this->assert( $k =~ s/^WikiGuest,//,          $k );
    $this->assert( $k =~ s/^ZebediahUser//,        $k );
    $this->assert_str_equals( "", $k );

    return;
}

sub groupFix {
    my $this = shift;
    my $me   = $Foswiki::cfg{Register}{RegistrationAgentWikiName};
    $this->{session}->{users}->{mapping}->addUser( "auser", "AaronUser",  $me );
    $this->{session}->{users}->{mapping}->addUser( "guser", "GeorgeUser", $me );
    $this->{session}->{users}->{mapping}
      ->addUser( "zuser", "ZebediahUser", $me );
    $this->{session}->{users}->{mapping}->addUser( "auser", "AaronUser",  $me );
    $this->{session}->{users}->{mapping}->addUser( "guser", "GeorgeUser", $me );
    $this->{session}->{users}->{mapping}
      ->addUser( "zuser", "ZebediahUser", $me );
    $this->{session}->{users}->{mapping}->addUser( "scum", "ScumUser", $me );
    Foswiki::Func::saveTopic( $testUsersWeb, 'AmishGroup', undef,
        "   * Set GROUP = AaronUser,%MAINWEB%.GeorgeUser, scum\n" );
    Foswiki::Func::saveTopic( $testUsersWeb, 'BaptistGroup', undef,
        "   * Set GROUP = GeorgeUser,$testUsersWeb.ZebediahUser\n" );
    Foswiki::Func::saveTopic( $testUsersWeb, 'MultiLineGroup', undef,
"   * Set GROUP = GeorgeUser,$testUsersWeb.ZebediahUser\n   AaronUser, scum\n"
    );

    return;
}

sub verify_getListOfGroups {
    my $this = shift;
    $this->groupFix();
    my $i = $this->{session}->{users}->eachGroup();
    my @l = ();
    while ( $i->hasNext() ) { push( @l, $i->next() ) }
    my $k = join( ',', sort @l );
    $this->assert_str_equals(
        "AdminGroup,AmishGroup,BaptistGroup,BaseGroup,MultiLineGroup", $k );

    return;
}

sub verify_groupMembers {
    my $this = shift;
    $this->groupFix();
    my $g = "AmishGroup";
    $this->assert( $this->{session}->{users}->isGroup($g) );
    my $i = $this->{session}->{users}->eachGroupMember($g);
    my @l = ();
    while ( $i->hasNext() ) { push( @l, $i->next() ) }
    my $k =
      join( ',', map { $this->{session}->{users}->getLoginName($_) } sort @l );
    $this->assert_str_equals( "auser,guser,scum", $k );

    $g = "BaptistGroup";
    $this->assert( $this->{session}->{users}->isGroup($g) );
    $i = $this->{session}->{users}->eachGroupMember($g);
    @l = ();
    while ( $i->hasNext() ) { push( @l, $i->next() ) }
    $k =
      join( ',', map { $this->{session}->{users}->getLoginName($_) } sort @l );
    $this->assert_str_equals( "guser,zuser", $k );

    $g = "MultiLineGroup";
    $this->assert( $this->{session}->{users}->isGroup($g) );
    $i = $this->{session}->{users}->eachGroupMember($g);
    @l = ();
    while ( $i->hasNext() ) { push( @l, $i->next() ) }
    $k =
      join( ',', map { $this->{session}->{users}->getLoginName($_) } sort @l );
    $this->assert_str_equals( "auser,guser,scum,zuser", $k );

    return;
}

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
