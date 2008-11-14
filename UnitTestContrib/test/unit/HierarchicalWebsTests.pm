use strict;

package HierarchicalWebsTests;
use base qw( TWikiTestCase );

use TWiki;
use Error qw( :try );

# Make sure it's a wikiname so we can check squab handling
my $testWeb = 'HierarchicalWebsTestsTestWeb';
my $testWebSubWeb = 'SubWeb';
my $testWebSubWebPath = $testWeb.'/'.$testWebSubWeb;
my $testTopic = 'Topic';

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $TWiki::cfg{EnableHierarchicalWebs} = 1;
    $TWiki::cfg{Htpasswd}{FileName} = '$TWiki::cfg{TempfileDir}/junkpasswd';
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::TopicUserMapping';
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::TemplateLogin';   
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 1;

    try {
        $this->{twiki} = new TWiki('AdminUser');

        $this->{twiki}->{store}->createWeb( $this->{twiki}->{user}, $testWeb );
        $this->assert( $this->{twiki}->{store}->webExists( $testWeb ) );
        $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user},
                                    $testWeb,
                                    $TWiki::cfg{HomeTopicName},
                                    "SMELL" );
        $this->assert( $this->{twiki}->{store}->topicExists(
            $testWeb, $TWiki::cfg{HomeTopicName} ) );

        $this->{twiki}->{store}->createWeb( $this->{twiki}->{user}, $testWebSubWebPath );
        $this->assert( $this->{twiki}->{store}->webExists( $testWebSubWebPath ) );
        $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user},
                                    $testWebSubWebPath,
                                    $TWiki::cfg{HomeTopicName},
                                    "SMELL" );
        $this->assert( $this->{twiki}->{store}->topicExists(
            $testWebSubWebPath, $TWiki::cfg{HomeTopicName} ) );

    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
}

sub tear_down {
    my $this = shift;

    unlink $TWiki::cfg{Htpasswd}{FileName};
    $this->{twiki}->{store}->removeWeb(undef, $testWebSubWebPath);
    $this->{twiki}->{store}->removeWeb(undef, $testWeb);
    $this->{twiki}->finish();

    $this->SUPER::tear_down();
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub test_createSubSubWeb {
    my $this = shift;
    $this->{twiki}->finish();

    $this->{twiki} = new TWiki();
    my $user = $this->{twiki}->{user};

    my $webTest = 'Item0';
    $this->{twiki}->{store}->createWeb( $user,
                                "$testWebSubWebPath/$webTest" );
    $this->assert( $this->{twiki}->{store}->webExists(
        "$testWebSubWebPath/$webTest" ) );

    $webTest = 'Item0_';
    $this->{twiki}->{store}->createWeb( $user,
                                "$testWebSubWebPath/$webTest" );
    $this->assert( $this->{twiki}->{store}->webExists(
        "$testWebSubWebPath/$webTest" ) );
}

sub test_createSubWebTopic {
    my $this = shift;
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    my $user = $this->{twiki}->{user};

    $this->{twiki}->{store}->saveTopic(
			       $this->{twiki}->{user}, $testWebSubWebPath, $testTopic,
			       "page stuff\n"
			       );
    $this->assert( $this->{twiki}->{store}->topicExists(
        $testWebSubWebPath, $testTopic ) );
}

sub test_include_subweb_non_wikiword_topic {
    my $this = shift;
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    my $user = $this->{twiki}->{user};

    my $baseTopic = 'IncludeSubWebNonWikiWordTopic';
    my $includeTopic = 'Topic';
    my $testText = 'TEXT';

    # create the (including) page
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user},
                                $testWebSubWebPath, $baseTopic, <<__TOPIC__ );
%INCLUDE{ "$testWebSubWebPath/$includeTopic" }%
__TOPIC__
    $this->assert( $this->{twiki}->{store}->topicExists( $testWebSubWebPath,
                                                 $baseTopic ) );

    # create the (included) page
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $testWebSubWebPath,
                                $includeTopic, $testText );
    $this->assert( $this->{twiki}->{store}->topicExists( $testWebSubWebPath,
                                                 $includeTopic ) );

    # verify included page's text
    { my ( undef, $text ) = $this->{twiki}->{store}->readTopic(
        $user, $testWebSubWebPath, $includeTopic );
    $this->assert_matches( qr/$testText\s*$/, $text );
    }

    # base page should evaluate (more or less) to the included page's text
    { my ( undef, $text ) = $this->{twiki}->{store}->readTopic(
        $user, $testWebSubWebPath, $baseTopic );
    $text = $this->{twiki}->handleCommonTags( $text, $testWebSubWebPath, $baseTopic );
    $this->assert_matches( qr/$testText\s*$/, $text );
    }
}

sub test_create_subweb_with_same_name_as_a_topic {
    my $this = shift;
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    my $user = $this->{twiki}->{user};

    my $testTopic = 'SubWeb';
    my $testText = 'TOPIC';

    # create the page
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $testWebSubWebPath, $testTopic, $testText );
    $this->assert( $this->{twiki}->{store}->topicExists(
        $testWebSubWebPath, $testTopic ) );

    my ( undef, $text ) = $this->{twiki}->{store}->readTopic(
        $user, $testWebSubWebPath, $testTopic );
    $this->assert_matches( qr/$testText\s*$/, $text );

    # create the subweb with the same name as the page
    $this->{twiki}->{store}->createWeb(
        $user, "$testWebSubWebPath/$testTopic" );
    $this->assert( $this->{twiki}->{store}->webExists(
        "$testWebSubWebPath/$testTopic" ) );

    ( undef, $text ) = $this->{twiki}->{store}->readTopic(
        $user, $testWebSubWebPath, $testTopic );
    $this->assert_matches( qr/$testText\s*$/, $text );

    $this->{twiki}->{store}->removeWeb(
        $user, "$testWebSubWebPath/$testTopic" );
    $this->assert( ! $this->{twiki}->{store}->webExists(
        "$testWebSubWebPath/$testTopic" ) );
}

sub test_url_parameters {
    my $this = shift;
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    my $user = $this->{twiki}->{user};

    my $topicquery;

    # Now query the subweb path. We should get the webhome of the subweb.
    $topicquery = new Unit::Request( {
        action => 'view',
        topic => "$testWebSubWebPath",
	} );

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $topicquery );

    # Item3243:  PTh and haj suggested to change the spec
    $this->assert_str_equals($testWeb, $this->{twiki}->{webName});
    $this->assert_str_equals($testWebSubWeb, $this->{twiki}->{topicName});

    # make a topic with the same name as the subweb. Now the previous
    # query should hit that topic
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $testWeb, $testWebSubWeb, "nowt" );

    $topicquery = new Unit::Request( {
        action => 'view',
        topic => "$testWebSubWebPath",
	} );

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $topicquery );

    $this->assert_str_equals($testWeb, $this->{twiki}->{webName});
    $this->assert_str_equals($testWebSubWeb, $this->{twiki}->{topicName});

    # try a query with a non-existant topic in the subweb.
    $topicquery = new Unit::Request( {
        action => 'view',
        topic => "$testWebSubWebPath/NonExistant",
	} );

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $topicquery );

    $this->assert_str_equals($testWebSubWebPath, $this->{twiki}->{webName});
    $this->assert_str_equals('NonExistant', $this->{twiki}->{topicName});

    # Note that this implictly tests %TOPIC% and %WEB% expansions, because
    # they come directly from {webName}
}

# Check expansion of [[TestWeb]] in TestWeb/NonExistant
# It should expand to creation of topic TestWeb
sub test_squab_simple {
    my $this = shift;

    my $query = new Unit::Request("");
    $query->path_info("/$testWeb/NonExistant");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $query);

    my $text = "[[$testWeb]]";
    $text = $this->{twiki}->renderer->getRenderedVersion(
        $text, $testWeb, 'NonExistant');
    $this->assert_matches(qr!<span class="twikiNewLink">$testWeb<a.*href=".*edit$TWiki::cfg{ScriptSuffix}/$testWeb/$testWeb\?topicparent=$testWeb.NonExistant"!, $text);
}

# Check expansion of [[SubWeb]] in TestWeb/NonExistant.
# It should expand to a create link to the TestWeb/SubWeb topic with
# TestWeb.WebHome as the parent
sub test_squab_subweb {
    my $this = shift;

    # Make a query that should set topic=$testSubWeb
    my $query = new Unit::Request("");
    $query->path_info("/$testWeb/NonExistant");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $query);

    my $text = "[[$testWebSubWeb]]";
    $text = $this->{twiki}->renderer->getRenderedVersion(
        $text, $testWeb, 'NonExistant');
    $this->assert_matches(qr!<span class="twikiNewLink">$testWebSubWeb<a.*href=".*edit$TWiki::cfg{ScriptSuffix}/$testWeb/$testWebSubWeb\?topicparent=$testWeb.NonExistant"!, $text);
}

# Check expansion of [[TestWeb.SubWeb]] in TestWeb/NonExistant.
# It should expand to create topic TestWeb/SubWeb
sub test_squab_subweb_full_path {
    my $this = shift;

    # Make a query that should set topic=$testSubWeb
    my $query = new Unit::Request("");
    $query->path_info("/$testWeb/NonExistant");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $query);

    my $text = "[[$testWeb.$testWebSubWeb]]";
    $text = $this->{twiki}->renderer->getRenderedVersion(
        $text, $testWeb, 'NonExistant');
    $this->assert_matches(qr!<span class="twikiNewLink">$testWeb.$testWebSubWeb<a.*href=".*edit$TWiki::cfg{ScriptSuffix}/$testWeb/$testWebSubWeb\?topicparent=$testWeb.NonExistant"!, $text);
}

# Check expansion of [[SubWeb]] in TestWeb/NonExistant.
# It should expand to TestWeb/SubWeb
sub test_squab_subweb_wih_topic {
    my $this = shift;

    # Make a query that should set topic=$testSubWeb
    my $query = new Unit::Request("");
    $query->path_info("/$testWeb/NonExistant");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $query);

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user}, $testWeb, $testWebSubWeb, "");
    $this->assert($this->{twiki}->{store}->topicExists($testWeb, $testWebSubWeb));

    my $text = "[[$testWebSubWeb]]";
    $text = $this->{twiki}->renderer->getRenderedVersion(
        $text, $testWeb, 'NonExistant');
    $this->assert_matches(qr!<a href=".*view$TWiki::cfg{ScriptSuffix}/$testWeb/$testWebSubWeb" class="twikiLink">$testWebSubWeb</a>!, $text);
}

# Check expansion of [[TestWeb.SubWeb]] in TestWeb/NonExistant.
# It should expand to TestWeb/SubWeb
sub test_squab_full_path_with_topic {
    my $this = shift;

    # Make a query that should set topic=$testSubWeb
    my $query = new Unit::Request("");
    $query->path_info("/$testWeb/NonExistant");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $query);

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user}, $testWeb, $testWebSubWeb, "");
    $this->assert($this->{twiki}->{store}->topicExists($testWeb, $testWebSubWeb));

    my $text = "[[$testWeb.$testWebSubWeb]]";
    $text = $this->{twiki}->renderer->getRenderedVersion(
        $text, $testWeb, 'NonExistant');
    $this->assert_matches(qr!<a href=".*view$TWiki::cfg{ScriptSuffix}/$testWeb/$testWebSubWeb" class="twikiLink">$testWeb.$testWebSubWeb</a>!, $text);
}

# Check expansion of [[TestWeb.SubWeb.WebHome]] in TestWeb/NonExistant.
# It should expand to TestWeb/SubWeb/WebHome
sub test_squab_path_to_topic_in_subweb {
    my $this = shift;

    # Make a query that should set topic=$testSubWeb
    my $query = new Unit::Request("");
    $query->path_info("/$testWeb/NonExistant");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $query);

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user}, $testWeb, $testWebSubWeb, "");
    $this->assert($this->{twiki}->{store}->topicExists($testWeb, $testWebSubWeb));

    my $text = "[[$testWeb.$testWebSubWeb.WebHome]]";
    $text = $this->{twiki}->renderer->getRenderedVersion(
        $text, $testWeb, 'NonExistant');
    $this->assert_matches(qr!<a href=".*view$TWiki::cfg{ScriptSuffix}/$testWeb/$testWebSubWeb/$TWiki::cfg{HomeTopicName}" class="twikiLink">$testWeb.$testWebSubWeb.$TWiki::cfg{HomeTopicName}</a>!, $text);

}

#TODO: move these tests to a VarWEBLIST and add more
sub test_WEBLIST_all {
    my $this = shift;

    my $query = new Unit::Request("");
    $query->path_info("/$testWeb/WebHome");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $query);

    my $text = ' %WEBLIST{format="$name" separator=", "}% ';
    $text = $this->{twiki}->handleCommonTags($text, $testWeb, 'WebHome');
    foreach my $web ('HierarchicalWebsTestsTestWeb', 'HierarchicalWebsTestsTestWeb/SubWeb', 'Main', 'Sandbox', 'TWiki', 'TestCases') {
        $this->assert_matches(qr!\b$web\b!, $text);
    }
}

sub test_WEBLIST_relative {
    my $this = shift;

    my $query = new Unit::Request("");
    $query->path_info("/$testWeb/WebHome");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $query);

    my $text = ' %WEBLIST{format="$name" separator=", " subwebs="'.$testWeb.'"}% ';
    $text = $this->{twiki}->handleCommonTags($text, $testWeb, 'WebHome');
    $this->assert_matches(qr! $testWebSubWebPath !, $text);
}

sub test_WEBLIST_end {
    my $this = shift;

    my $query = new Unit::Request("");
    $query->path_info("/$testWeb/WebHome");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $TWiki::cfg{DefaultUserName}, $query);

    my $text = ' %WEBLIST{format="$name" separator=", " subwebs="'.$testWebSubWebPath.'"}% ';
    $text = $this->{twiki}->handleCommonTags($text, $testWeb, 'WebHome');
    $this->assert_matches(qr!  !, $text);
}

1;
