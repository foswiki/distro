# See bottom of file for license and copyright information
use strict;
use warnings;

#
# Tests the TopicUserMappingContrib, including dealing with legacy login
# names and wiki names stored in topics, in TOPICINFO and FILEATTACHMENT
# meta-data.
#
# Only works with the RCS store.
#
package TopicUserMappingContribTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Unit::Request;
use Unit::Response;
use Foswiki;
use Error qw( :try );

my $TopicTemplate = <<'THIS';
some text that is there.

%META:FILEATTACHMENT{name="home.org.au.png" attachment="home.org.au.png" attr="" comment="" date="1180648704" path="home.org.au.png" size="4170" stream="home.org.au.png" user="UUUUUUUUUU" version="1"}%
THIS

sub new {
    my $self = shift()->SUPER::new( 'TopicUserMappingContribTests', @_ );
    return $self;
}

sub fixture_groups {
    return ( [ 'NormalTopicUserMapping', 'NamedTopicUserMapping', ] );
}

sub NormalTopicUserMapping {
    my $this = shift;
    $Foswiki::Users::TopicUserMapping::FOSWIKI_USER_MAPPING_ID = '';
    $this->set_up_for_verify();
}

sub NamedTopicUserMapping {
    my $this = shift;

    # Set a mapping ID for purposes of testing named mappings
    $Foswiki::Users::TopicUserMapping::FOSWIKI_USER_MAPPING_ID = 'TestMapping_';
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

    $this->assert( $Foswiki::cfg{Store}{Implementation} =~ /Rcs(Lite|Wrap)/,
        "Test does not run with non-RCS store" );

    #default settings
    $Foswiki::cfg{LoginManager}       = 'Foswiki::LoginManager::TemplateLogin';
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::TopicUserMapping';
    $Foswiki::cfg{UseClientSessions}  = 1;
    $Foswiki::cfg{PasswordManager}    = "Foswiki::Users::HtPasswdUser";
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{Register}{AllowLoginName}            = 0;
    $Foswiki::cfg{DisplayTimeValues}                   = 'gmtime';
}

sub setup_new_session() {
    my $this = shift;

    my ( $query, $text );
    $query = new Unit::Request( {} );
    $query->path_info("/Main/WebHome");
    $ENV{SCRIPT_NAME} = "view";

    # close this Foswiki session - its using the wrong mapper and login
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $query );
    $this->{test_topicObject} =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
}

sub set_up_user {
    my $this = shift;

    my $userLogin;
    my $userWikiName;
    my $user_id;

    if ( $this->{session}->{users}->supportsRegistration() ) {
        $userWikiName = 'JoeDoe';
        $userLogin    = $userWikiName;
        $userLogin    = 'joe' if ( $Foswiki::cfg{Register}{AllowLoginName} );
        $user_id =
          $this->{session}->{users}
          ->addUser( $userLogin, $userWikiName, 'secrect_password',
            'email@home.org.au' );
        $this->annotate(
"create $userLogin user - cUID = $user_id , login $userLogin , wikiname: $userWikiName\n"
        );
    }
    else {
        $userLogin = $Foswiki::cfg{AdminUserLogin};
        $user_id   = $this->{session}->{users}->getCanonicalUserID($userLogin);
        $userWikiName = $this->{session}->{users}->getWikiName($user_id);
        $this->annotate("no rego support (using admin)\n");
    }
    $this->{userLogin}    = $userLogin;
    $this->{userWikiName} = $userWikiName;
    $this->{user_id}      = $user_id;
}

#TODO: add tests for when you're not using TopicUserMapping at all...
#New 4.2 cUID based topics
sub verify_WikiNameTopicUserMapping {
    my $this = shift;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{user_id},
        $this->{session}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_LoginNameTopicUserMapping {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{user_id},
        $this->{session}->{users}->webDotWikiName( $this->{user_id} ) );
}

#legacy topic forms
sub verify_valid_login_no_Mapper_in_cUID {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{userLogin},
        $this->{session}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_valid_wikiname_no_Mapper_in_cUID {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{userWikiName},
        $this->{session}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_web_and_wikiname_no_Mapper_in_cUID {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests(
        $this->{session}->{users}->webDotWikiName( $this->{user_id} ),
        $this->{session}->{users}->webDotWikiName( $this->{user_id} )
    );
}

sub verify_valid_login_no_Mapper_in_cUID_NOAllowLoginName {
    my $this = shift;

    #$Foswiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{userLogin},
        $this->{session}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_valid_wikiname_no_Mapper_in_cUID_NOAllowLoginName {
    my $this = shift;

    #$Foswiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests( $this->{userWikiName},
        $this->{session}->{users}->webDotWikiName( $this->{user_id} ) );
}

sub verify_web_and_wikiname_no_Mapper_in_cUID_NOAllowLoginName {
    my $this = shift;

    #$Foswiki::cfg{Register}{AllowLoginName} = 1;
    $this->setup_new_session();
    $this->set_up_user();
    $this->std_tests(
        $this->{session}->{users}->webDotWikiName( $this->{user_id} ),
        $this->{session}->{users}->webDotWikiName( $this->{user_id} )
    );
}

#error and fallback tests
sub TODOtest_non_existantIser {
    my $this = shift;

    #$Foswiki::cfg{Register}{AllowLoginName} = 1;
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

    $this->assert_not_null( $this->{session}->{user} );
    Foswiki::Func::saveTopic( $this->{test_web}, 'CuidWithMappers', undef,
        $CuidWithMappers );

    #test that all 4 raw internal values are ok cUIDs
    my $nob =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'CuidWithMappers' );
    my $info = $nob->getRevisionInfo();
    $this->assert_not_null( $info->{author} );

    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'CuidWithMappers' );

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
      $this->{session}
      ->attach->renderMetaData( $meta, { template => 'attachtables.tmpl' } );
    $this->assert_not_null($renderedMeta);

    #TODO: redo this with custom tmpl and check each username
    my $output = <<'THIS';
%TMPL:P{"settmltablesummary" 
   SUMMARY="%MAKETEXT{"Attachments"}%"
}%<div class="foswikiAttachments">
| *I* | *%MAKETEXT{"Attachment"}%* | *%MAKETEXT{"Action"}%* | *%MAKETEXT{"Size"}%* | *%MAKETEXT{"Date"}%* | *%MAKETEXT{"Who"}%* | *%MAKETEXT{"Comment"}%* |
| %ICON{"home.org.au.png" default="else"}%<span class="foswikiHidden">png</span> | <a href="%ATTACHURLPATH%/%ENCODE{home.org.au.png}%"><noautolink>home.org.au.png</noautolink></a> | <a href="%SCRIPTURLPATH{"attach"}%/%WEB%/%TOPIC%?filename=%ENCODE{"home.org.au.png"}%;revInfo=1" title="%MAKETEXT{"change, update, previous revisions, move, delete..."}%" rel="nofollow">%MAKETEXT{"manage"}%</a> |  4 K|<span class="foswikiNoBreak">31 May 2007 - 21:58</span> |TemporaryTopicUserMappingContribTestsUsersWeb.JoeDoe  |  |
</div>
THIS
    $output =~ s/UUUUUUUUUU/$displayedName/e;
    $output =~ s/%PUBURLPATH%/$Foswiki::cfg{PubUrlPath}/e;
    $output =~ s/%EXPANDEDPUBURL%/$Foswiki::cfg{PubUrlPath}/e;
    $this->assert_str_equals( $output, $renderedMeta . "\n" );

    #see if leases and locks have similar issues
}

###########################################
sub verify_BaseMapping_handleUser {
    my $this        = shift;
    my $basemapping = $this->{session}->{users}->{basemapping};

    #ObjectMethod handlesUser ( $cUID, $login, $wikiname)
    $this->assert( !$basemapping->handlesUser() );

    $this->assert(
        $basemapping->handlesUser( undef, $Foswiki::cfg{AdminUserLogin} ) );
    $this->assert(
        $basemapping->handlesUser( undef, $Foswiki::cfg{DefaultUserLogin} ) );
    $this->assert( $basemapping->handlesUser( undef, 'unknown' ) );
    $this->assert( $basemapping->handlesUser( undef, 'ProjectContributor' ) );
    $this->assert(
        $basemapping->handlesUser(
            undef, $Foswiki::cfg{Register}{RegistrationAgentWikiName}
        )
    );

    $this->assert(
        $basemapping->handlesUser(
            undef, undef, $Foswiki::cfg{AdminUserWikiName}
        )
    );
    $this->assert(
        $basemapping->handlesUser(
            undef, undef, $Foswiki::cfg{DefaultUserWikiName}
        )
    );
    $this->assert( $basemapping->handlesUser( undef, undef, 'UnknownUser' ) );
    $this->assert(
        $basemapping->handlesUser( undef, undef, 'ProjectContributor' ) );
    $this->assert(
        $basemapping->handlesUser(
            undef, undef,
            $Foswiki::cfg{Register}{RegistrationAgentWikiName}
        )
    );

    $this->assert(
        $basemapping->handlesUser(
            undef, $Foswiki::cfg{AdminUserLogin},
            $Foswiki::cfg{AdminUserWikiName}
        )
    );
    $this->assert(
        $basemapping->handlesUser(
            undef,
            $Foswiki::cfg{DefaultUserLogin},
            $Foswiki::cfg{DefaultUserWikiName}
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
            undef,
            $Foswiki::cfg{Register}{RegistrationAgentWikiName},
            $Foswiki::cfg{Register}{RegistrationAgentWikiName}
        )
    );

    #TODO: work out what we'd like to have happen with bad combinations

    #TODO: users not in any mapping, and ones in the main mapping
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
