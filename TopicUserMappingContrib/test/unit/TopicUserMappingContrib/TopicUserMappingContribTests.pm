use strict;

#
# Tests the TWikiUserMappingContrib, including dealing with legacy login
# names and wiki names stored in topics, in TOPICINFO and FILEATTACHMENT
# meta-data.
#
# Only works with the RCS store.
#
package TWikiUserMappingContribTests;

use base qw( TWikiFnTestCase );

use Unit::Request;
use Unit::Response;
use TWiki;
use Error qw( :try );

my $TopicTemplate = <<'THIS';
some text that is there.

%META:FILEATTACHMENT{name="home.org.au.png" attachment="home.org.au.png" attr="" comment="" date="1180648704" path="home.org.au.png" size="4170" stream="home.org.au.png" user="UUUUUUUUUU" version="1"}%
THIS

sub new {
    my $self = shift()->SUPER::new( 'TWikiuserMappingContribTests', @_ );
    return $self;
}

sub fixture_groups {
    return ( [ 'NormalTWikiUserMapping', 'NamedTWikiUserMapping', ] );
}

sub NormalTWikiUserMapping {
    my $this = shift;
    $TWiki::Users::TWikiUserMapping::TWIKI_USER_MAPPING_ID = '';
    $this->set_up_for_verify();
}

sub NamedTWikiUserMapping {
    my $this = shift;

    # Set a mapping ID for purposes of testing named mappings
    $TWiki::Users::TWikiUserMapping::TWIKI_USER_MAPPING_ID = 'TestMapping_';
    $this->set_up_for_verify();
}

# Override default set_up in base class; will call it after the mapping
#  id has been set
sub set_up {
}

# Delay the calling of set_up till after the cfg's are set by above closure
sub set_up_for_verify {
    my $this = shift;

    $this->SUPER::set_up();

    $this->assert(
        $TWiki::cfg{StoreImpl} =~ /^Rcs/,
        "Test does not run with non-RCS store"
    );

    #default settings
    $TWiki::cfg{LoginManager}       = 'TWiki::LoginManager::TemplateLogin';
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::TWikiUserMapping';
    $TWiki::cfg{UseClientSessions}  = 1;
    $TWiki::cfg{PasswordManager}    = "TWiki::Users::HtPasswdUser";
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $TWiki::cfg{Register}{AllowLoginName}            = 0;
    $TWiki::cfg{DisplayTimeValues}                   = 'gmtime';
}

sub setup_new_session() {
    my $this = shift;

    my ( $query, $text );
    $query = new Unit::Request( {} );
    $query->path_info("/Main/WebHome");
    $ENV{SCRIPT_NAME} = "view";

    # close this TWiki session - its using the wrong mapper and login
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( undef, $query );
}

sub set_up_user {
    my $this = shift;

    my $agent = 'RegistrationAgent';
    my $userLogin;
    my $userWikiName;
    my $user_id;

    if ( $this->{twiki}->{users}->supportsRegistration() ) {
        $userWikiName = 'JoeDoe';
        $userLogin    = $userWikiName;
        $userLogin    = 'joe' if ( $TWiki::cfg{Register}{AllowLoginName} );
        $user_id =
          $this->{twiki}->{users}
          ->addUser( $userLogin, $userWikiName, 'secrect_password',
            'email@home.org.au' );
        $this->annotate(
"create $userLogin user - cUID = $user_id , login $userLogin , wikiname: $userWikiName\n"
        );
    }
    else {
        $userLogin    = $TWiki::cfg{AdminUserLogin};
        $user_id      = $this->{twiki}->{users}->getCanonicalUserID($userLogin);
        $userWikiName = $this->{twiki}->{users}->getWikiName($user_id);
        $this->annotate("no rego support (using admin)\n");
    }
    $this->{userLogin}    = $userLogin;
    $this->{userWikiName} = $userWikiName;
    $this->{user_id}      = $user_id;
}

#TODO: add tests for when you're not using TWikiUserMapping at all...
#New 4.2 cUID based topics
sub verify_WikiNameTWikiUserMapping {
    my $this = shift;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{user_id},
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_LoginNameTWikiUserMapping {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{user_id},
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} ) );
}

#legacy topic forms
sub verify_valid_login_no_Mapper_in_cUID {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{userLogin},
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_valid_wikiname_no_Mapper_in_cUID {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{userWikiName},
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_web_and_wikiname_no_Mapper_in_cUID {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests(
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} ),
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} )
    );
}

sub verify_valid_login_no_Mapper_in_cUID_NOAllowLoginName {
    my $this = shift;

    #$TWiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{userLogin},
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_valid_wikiname_no_Mapper_in_cUID_NOAllowLoginName {
    my $this = shift;

    #$TWiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{userWikiName},
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_web_and_wikiname_no_Mapper_in_cUID_NOAllowLoginName {
    my $this = shift;

    #$TWiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests(
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} ),
        $this->{twiki}->{users}->webDotWikiName( $this->{user_id} )
    );
}

#error and fallback tests
sub TODOtest_non_existantIser {
    my $this = shift;

    #$TWiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( 'nonexistantUser', $this->{users_web} . '.UnknownUser' );
}

sub std_tests {
    my ( $this, $serializedName, $displayedName ) = @_;
    $this->annotate(
        "topic contains: $serializedName, rendered : $displayedName\n");

    my $CuidWithMappers = $TopicTemplate;
    $CuidWithMappers =~ s/UUUUUUUUUU/$serializedName/e;

    $this->assert_not_null( $this->{twiki}->{user} );
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'CuidWithMappers',      $CuidWithMappers
    );

    #test that all 4 raw internal values are ok cUIDs
    my ( $date, $user, $rev, $comment ) =
      $this->{twiki}->{store}
      ->getRevisionInfo( $this->{test_web}, 'CuidWithMappers' );
    $this->assert_not_null($user);

    my ( $meta, $text ) =
      $this->{twiki}->{store}->readTopic( $this->{twiki}->{user},
        $this->{test_web}, 'CuidWithMappers' );

    my $topicinfo = $meta->get('TOPICINFO');
    $this->assert_not_null( $topicinfo->{author} );
    $this->assert_str_equals( 'BaseUserMapping_666', $topicinfo->{author} )
      ; #render the topic, make sure we're seeing NO cUIDs, and WikiNames for all known users
        #parse meta output
    $this->assert( $meta->count("FILEATTACHMENT") == 1, "Should be one item" );

    my $file1 = $meta->get('FILEATTACHMENT');
    $this->assert_not_null( $file1->{'user'} );
    $this->assert_str_equals( 'home.org.au.png', $file1->{'name'} );

    my @attachments = $meta->find('FILEATTACHMENT');
    foreach my $attachment (@attachments) {
        $this->annotate( "FILEATTACHMENT user = " . $attachment->{'user'} );
        $this->assert_not_null( $attachment->{'user'} );
    }

    #test func outputs

    #peek at old rev's to see what rcs tells us
    #render diff & history to make sure those are all wikiname

    #render attahcment tables, and rev history of attachment tables,
    #all must be wikiname
    my $renderedMeta =
      $this->{twiki}
      ->attach->renderMetaData( $this->{test_web}, 'CuidWithMappers', $meta,
        { template => 'attachtables.tmpl' } );
    $this->assert_not_null($renderedMeta);

    #TODO: redo this with custom tmpl and check each username
    my $output = <<'THIS';
<div class="twikiAttachments">
| *I* | *%MAKETEXT{"Attachment"}%* | *%MAKETEXT{"Action"}%* | *%MAKETEXT{"Size"}%* | *%MAKETEXT{"Date"}%* | *%MAKETEXT{"Who"}%* | *%MAKETEXT{"Comment"}%* |
| <img width="16" alt="png" align="top" src="%PUBURLPATH%/TWiki/DocumentGraphics/png.gif" height="16" border="0" /><span class="twikiHidden">png</span> | <a href="%ATTACHURLPATH%/%ENCODE{home.org.au.png}%">home.org.au.png</a> | <a href="%SCRIPTURLPATH{"attach"}%/%WEB%/%TOPIC%?filename=%ENCODE{"home.org.au.png"}%;revInfo=1" title="%MAKETEXT{"change, update, previous revisions, move, delete..."}%" rel="nofollow">%MAKETEXT{"manage"}%</a> |  4.1&nbsp;K|<span class="twikiNoBreak">31 May 2007 - 21:58</span> |TemporaryTWikiuserMappingContribTestsUsersWeb.JoeDoe  |&nbsp;  |
</div>
THIS
    $output =~ s/UUUUUUUUUU/$displayedName/e;
    $output =~ s/%PUBURLPATH%/$TWiki::cfg{PubUrlPath}/e;
    $output =~ s/%EXPANDEDPUBURL%/$TWiki::cfg{PubUrlPath}/e;
    $this->assert_str_equals( $output, $renderedMeta . "\n" );

    #see if leases and locks have similar issues
}

###########################################
sub verify_BaseMapping_handleUser {
    my $this        = shift;
    my $basemapping = $this->{twiki}->{users}->{basemapping};

    #ObjectMethod handlesUser ( $cUID, $login, $wikiname)
    $this->assert( !$basemapping->handlesUser() );

    $this->assert(
        $basemapping->handlesUser( undef, $TWiki::cfg{AdminUserLogin} ) );
    $this->assert(
        $basemapping->handlesUser( undef, $TWiki::cfg{DefaultUserLogin} ) );
    $this->assert( $basemapping->handlesUser( undef, 'unknown' ) );
    $this->assert( $basemapping->handlesUser( undef, 'ProjectContributor' ) );
    $this->assert( $basemapping->handlesUser( undef, 'RegistrationAgent' ) );

    $this->assert(
        $basemapping->handlesUser(
            undef, undef, $TWiki::cfg{AdminUserWikiName}
        )
    );
    $this->assert(
        $basemapping->handlesUser(
            undef, undef, $TWiki::cfg{DefaultUserWikiName}
        )
    );
    $this->assert( $basemapping->handlesUser( undef, undef, 'UnknownUser' ) );
    $this->assert(
        $basemapping->handlesUser( undef, undef, 'ProjectContributor' ) );
    $this->assert(
        $basemapping->handlesUser( undef, undef, 'RegistrationAgent' ) );

    $this->assert(
        $basemapping->handlesUser(
            undef, $TWiki::cfg{AdminUserLogin},
            $TWiki::cfg{AdminUserWikiName}
        )
    );
    $this->assert(
        $basemapping->handlesUser(
            undef, $TWiki::cfg{DefaultUserLogin},
            $TWiki::cfg{DefaultUserWikiName}
        )
    );
    $this->assert(
        $basemapping->handlesUser( undef, 'unknown', 'UnknownUser' ) );
    $this->assert(
        $basemapping->handlesUser(
            undef, 'ProjectContributor', 'ProjectContributor'
        )
    );
    $this->assert(
        $basemapping->handlesUser(
            undef, 'RegistrationAgent', 'RegistrationAgent'
        )
    );

    #TODO: work out what we'd like to have happen with bad combinations

    #TODO: users not in any mapping, and ones in the main mapping
}

1;
