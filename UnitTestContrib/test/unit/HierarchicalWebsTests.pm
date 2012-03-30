package HierarchicalWebsTests;
use strict;
use warnings;

use FoswikiStoreTestCase();
our @ISA = qw( FoswikiStoreTestCase );

use Foswiki();
use Error qw( :try );

sub set_up {
    my $this = shift;

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    $this->SUPER::set_up();
    $this->{sub_web} = "Subweb";
    $this->{sub_web_path} = "$this->{test_web}/$this->{sub_web}";
    my $webObject = $this->populateNewWeb( $this->{sub_web_path} );
    $webObject->finish();
}

sub set_up_for_verify {
    my $this = shift;
    $this->createNewFoswikiSession();
}

sub verify_createSubSubWeb {
    my $this = shift;

    $this->createNewFoswikiSession();
    my $webTest   = 'Item0';
    my $webObject = $this->populateNewWeb("$this->{sub_web_path}/$webTest");
    $webObject->finish();
    $this->assert( $this->{session}->webExists("$this->{sub_web_path}/$webTest") );

    $webTest   = 'Item0_';
    $webObject = $this->populateNewWeb("$this->{sub_web_path}/$webTest");
    $webObject->finish();
    $this->assert( $this->{session}->webExists("$this->{sub_web_path}/$webTest") );

    return;
}

sub verify_createSubWebTopic {
    my $this = shift;

    $this->createNewFoswikiSession();
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{sub_web_path}, $this->{test_topic} );
    $topicObject->text("page stuff\n");
    $topicObject->save();
    $topicObject->finish();
    $this->assert(
        $this->{session}->topicExists( $this->{sub_web_path}, $this->{test_topic} ) );

    return;
}

sub verify_include_subweb_non_wikiword_topic {
    my $this = shift;
    $this->createNewFoswikiSession();
    my $user = $this->{session}->{user};

    my $baseTopic    = "Include$this->{sub_web}NonWikiWordTopic";
    my $includeTopic = 'Topic';
    my $testText     = 'TEXT';

    # create the (including) page
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{sub_web_path}, $baseTopic );
    $topicObject->text( <<"TOPIC" );
%INCLUDE{ "$this->{sub_web_path}/$includeTopic" }%
TOPIC
    $topicObject->save();
    $topicObject->finish();
    $this->assert(
        $this->{session}->topicExists( $this->{sub_web_path}, $baseTopic ) );

    # create the (included) page
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{sub_web_path}, $includeTopic );
    $topicObject->text($testText);
    $topicObject->save();
    $topicObject->finish();
    $this->assert(
        $this->{session}->topicExists( $this->{sub_web_path}, $includeTopic ) );

    # verify included page's text
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{sub_web_path}, $includeTopic );
    $this->assert_matches( qr/$testText\s*$/, $topicObject->text );
    $topicObject->finish();

    # base page should evaluate (more or less) to the included page's text
    ($topicObject) = Foswiki::Func::readTopic( $this->{sub_web_path}, $baseTopic );
    my $text = $topicObject->text;
    $text = $topicObject->expandMacros($text);
    $this->assert_matches( qr/$testText\s*$/, $text );
    $topicObject->finish();

    return;
}

sub verify_create_subweb_with_same_name_as_a_topic {
    my $this = shift;
    $this->createNewFoswikiSession();
    my $user = $this->{session}->{user};

    $this->{test_topic} = $this->{sub_web};
    my $testText  = 'TOPIC';

    # create the page
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{sub_web_path}, $this->{test_topic} );
    $topicObject->text($testText);
    $topicObject->save();
    $this->assert(
        $this->{session}->topicExists( $this->{sub_web_path}, $this->{test_topic} ) );

    my ($meta) = Foswiki::Func::readTopic( $this->{sub_web_path}, $this->{test_topic} );
    $this->assert_matches( qr/$testText\s*$/, $topicObject->text );
    $topicObject->finish();
    $meta->finish();

    # create the subweb with the same name as the page
    my $webObject = $this->populateNewWeb("$this->{sub_web_path}/$this->{test_topic}");
    $this->assert(
        $this->{session}->webExists("$this->{sub_web_path}/$this->{test_topic}") );

    ($topicObject) = Foswiki::Func::readTopic( $this->{sub_web_path}, $this->{test_topic} );
    $this->assert_matches( qr/$testText\s*$/, $topicObject->text );
    $topicObject->finish();

    $webObject->removeFromStore();
    $webObject->finish();

    $this->assert(
        !$this->{session}->webExists("$this->{sub_web_path}/$this->{test_topic}") );

    return;
}

sub verify_create_sub_web_missingParent {
    my $this = shift;
    require Foswiki::AccessControlException;

    $this->createNewFoswikiSession();
    my $user = $this->{session}->{user};

    my $webObject = $this->getWebObject("Missingweb/$this->{sub_web}");

    try {
        $webObject->populateNewWeb();
        $this->assert('No error thrown from populateNewWe() ');
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert_matches( qr/^Parent web Missingweb does not exist.*/,
            $e, "Unexpected error $e" );
    };
    $webObject->finish();
    $this->assert( !$this->{session}->webExists("Missingweb/$this->{sub_web}") );
    $this->assert( !$this->{session}->webExists("Missingweb") );

    return;
}

sub verify_createWeb_InvalidBase {
    my $this = shift;
    require Foswiki::AccessControlException;

    $this->createNewFoswikiSession();

    my $user = $this->{session}->{user};

    my $webTest   = 'Item0';
    my $webObject = $this->getWebObject("$this->{sub_web_path}/$webTest");

    try {
        $webObject->populateNewWeb("Missingbase");
        $this->assert('No error thrown from populateNewWe() ');
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert_matches( qr/^Template web Missingbase does not exist.*/,
            $e, "Unexpected error $e" );
    };
    $webObject->finish();
    $this->assert(
        !$this->{session}->webExists("$this->{sub_web_path}/$webTest") );

    return;
}

sub verify_createWeb_hierarchyDisabled {
    my $this = shift;
    require Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 0;

    $this->createNewFoswikiSession();

    my $user = $this->{session}->{user};

    my $webTest   = 'Item0';
    my $webObject = $this->getWebObject( "$this->{sub_web_path}/$webTest" . 'x' );

    try {
        $webObject->populateNewWeb();
        $this->assert('No error thrown from populateNewWe() ');
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert_matches(
            qr/^Unable to create .* Hierarchical webs are disabled.*/,
            $e, "Unexpected error '$e'" );
    };
    $webObject->finish();
    $this->assert(
        !$this->{session}->webExists( "$this->{sub_web_path}/$webTest" . 'x' ) );

    return;
}

sub verify_url_parameters {
    my $this = shift;
    $this->createNewFoswikiSession();
    my $user = $this->{session}->{user};

    # Now query the subweb path. We should get the webhome of the subweb.
    my $topicquery = Unit::Request->new(
        {
            action => 'view',
            topic  => "$this->{sub_web_path}",
        }
    );

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName},
        $topicquery );

    # Item3243:  PTh and haj suggested to change the spec
    $this->assert_str_equals( $this->{test_web},       $this->{session}->{webName} );
    $this->assert_str_equals( "$this->{sub_web}", $this->{session}->{topicName} );

    # make a topic with the same name as the subweb. Now the previous
    # query should hit that topic
    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, "$this->{sub_web}" );
    $topicObject->text("nowt");
    $topicObject->save();
    $topicObject->finish();

    $topicquery = Unit::Request->new(
        {
            action => 'view',
            topic  => "$this->{sub_web_path}",
        }
    );

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName},
        $topicquery );

    $this->assert_str_equals( $this->{test_web},       $this->{session}->{webName} );
    $this->assert_str_equals( "$this->{sub_web}", $this->{session}->{topicName} );

    # try a query with a non-existant topic in the subweb.
    $topicquery = Unit::Request->new(
        {
            action => 'view',
            topic  => "$this->{sub_web_path}/NonExistant",
        }
    );

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName},
        $topicquery );

    $this->assert_str_equals( $this->{sub_web_path}, $this->{session}->{webName} );
    $this->assert_str_equals( 'NonExistant', $this->{session}->{topicName} );

    # Note that this implictly tests %TOPIC% and %WEB% expansions, because
    # they come directly from {webName}

    return;
}

# Check expansion of [[TestWeb]] in TestWeb/NonExistant
# It should expand to creation of topic TestWeb
sub test_squab_simple {
    my $this = shift;

    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/NonExistant");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );

    my $text = "[[$this->{test_web}]]";
    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NonExistant' );
    $text = $topicObject->renderTML($text);
    $topicObject->finish();
    $this->assert_matches(
qr!<span class="foswikiNewLink">$this->{test_web}<a href=".*?/$this->{test_web}/$this->{test_web}\?topicparent=$this->{test_web}\.NonExistant!,
        $text
    );

    return;
}

# Check expansion of [[$this->{sub_web}]] in TestWeb/NonExistant.
# It should expand to a create link to the TestWeb/$this->{sub_web} topic with
# TestWeb.WebHome as the parent
sub test_squab_subweb {
    my $this = shift;

    # Make a query that should set topic=$test$this->{sub_web}
    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/NonExistant");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );

    my $text = "[[$this->{sub_web}]]";
    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NonExistant' );
    $text = $topicObject->renderTML($text);
    $topicObject->finish();
    $this->assert_matches(
qr!<span class="foswikiNewLink">Subweb<a href=".*?/$this->{sub_web_path}\?topicparent=$this->{test_web}.NonExistant!,
        $text
    );

    return;
}

# Check expansion of [[TestWeb.$this->{sub_web}]] in TestWeb/NonExistant.
# It should expand to create topic TestWeb/$this->{sub_web}
sub test_squab_subweb_full_path {
    my $this = shift;

    # Make a query that should set topic=$test$this->{sub_web}
    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/NonExistant");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );

    my $text = "[[$this->{test_web}.$this->{sub_web}]]";
    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NonExistant' );
    $text = $topicObject->renderTML($text);
    $topicObject->finish();
    $this->assert_matches(
qr!<span class="foswikiNewLink">$this->{test_web}.$this->{sub_web}<a href=".*?/$this->{sub_web_path}\?topicparent=$this->{test_web}.NonExistant!,
        $text
    );

    return;
}

# Check expansion of [[$this->{sub_web}]] in TestWeb/NonExistant.
# It should expand to TestWeb/$this->{sub_web}
sub test_squab_subweb_wih_topic {
    my $this = shift;

    # Make a query that should set topic=$test$this->{sub_web}
    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/NonExistant");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );

    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{sub_web} );
    $topicObject->text('');
    $topicObject->save();
    $topicObject->finish();
    $this->assert( $this->{session}->topicExists( $this->{test_web}, $this->{sub_web} ) );

    my $text = "[[$this->{sub_web}]]";
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NonExistant' );
    $text = $topicObject->renderTML($text);
    $topicObject->finish();
    my $scripturl =
      $this->{session}->getScriptUrl( 0, 'view' ) . "/$this->{test_web}/$this->{sub_web}";
    $this->assert_matches( qr!<a href="$scripturl">$this->{sub_web}</a>!, $text );

    return;
}

# Check expansion of [[TestWeb.$this->{sub_web}]] in TestWeb/NonExistant.
# It should expand to TestWeb/$this->{sub_web}
sub test_squab_full_path_with_topic {
    my $this = shift;

    # Make a query that should set topic=$test$this->{sub_web}
    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/NonExistant");

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );

# SMELL:   If this call to getScriptUrl occurs before the finish() call
# It decides it is in $this->inContext('command_line') and returns
# absolute URLs.   Moving it here after the finish() and it returns relative URLs.
    my $scripturl =
      $this->{session}->getScriptUrl( 0, 'view' ) . "/$this->{test_web}/$this->{sub_web}";

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );

    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{sub_web} );
    $topicObject->text('');
    $topicObject->save();
    $topicObject->finish();
    $this->assert( $this->{session}->topicExists( $this->{test_web}, $this->{sub_web} ) );

    my $text = "[[$this->{test_web}.$this->{sub_web}]]";
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NonExistant' );
    $text = $topicObject->renderTML($text);
    $topicObject->finish();

    $this->assert_matches( qr!<a href="$scripturl">$this->{test_web}.$this->{sub_web}</a>!,
        $text );

    return;
}

# Check expansion of [[TestWeb.$this->{sub_web}.WebHome]] in TestWeb/NonExistant.
# It should expand to TestWeb/$this->{sub_web}/WebHome
sub test_squab_path_to_topic_in_subweb {
    my $this = shift;

    # Make a query that should set topic=$test$this->{sub_web}
    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/NonExistant");
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserName}, $query );

    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{sub_web} );
    $topicObject->text('');
    $topicObject->save();
    $topicObject->finish();
    $this->assert( $this->{session}->topicExists( $this->{test_web}, $this->{sub_web} ) );

    my $text = "[[$this->{test_web}.$this->{sub_web}.WebHome]]";
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NonExistant' );
    $text = $topicObject->renderTML($text);
    $topicObject->finish();

    my $scripturl = Foswiki::Func::getScriptUrl( "$this->{test_web}/$this->{sub_web}",
        "$Foswiki::cfg{HomeTopicName}", 'view' );
    ($scripturl) = $scripturl =~ m/https?:\/\/[^\/]+(\/.*)/;

    $this->assert_matches(
qr!<span class=.foswikiNewLink.>$this->{test_web}\.$this->{sub_web}\.WebHome<a href=.*?/$this->{test_web}/$this->{sub_web}/WebHome\?topicparent=$this->{test_web}\.NonExistant!,
        $text
    );

    return;
}

=pod

---++ Pre nested web linking 

twiki used to remove /'s without replacement, and 

=cut

sub verify_PreNestedWebsLinking {
    my $this = shift;
    
    Foswiki::Func::saveTopic( $this->{test_web}, '6to4enronet', undef, "Some text" );
    Foswiki::Func::saveTopic( $this->{test_web}, 'Aou1aplpnet', undef, "Some text" );
    Foswiki::Func::saveTopic( $this->{test_web}, 'MemberFinance', undef, "Some text" );
    Foswiki::Func::saveTopic( $this->{test_web}, 'MyNNABugsfeatureRequests', undef, "Some text" );
    Foswiki::Func::saveTopic( $this->{test_web}, 'Transfermergerrestructure', undef, "Some text" );
    Foswiki::Func::saveTopic( $this->{test_web}, 'ArthsChecklist', undef, "Some text" );


    my $source = <<END_SOURCE;
SiteChanges
[[6to4.nro.net]]
[[Member/Finance]]
[[MyNNA bugs/feature requests]]
[[Transfer/merger/restructure]]
[[Arth's checklist]]
[[WebHome]]
[[WebPreferences]]
END_SOURCE

    my $expected = <<"END_EXPECTED";
[[System.SiteChanges][SiteChanges]]
[[6to4.nro.net]]
[[Member/Finance]]
[[MyNNA bugs/feature requests]]
[[Transfer/merger/restructure]]
[[Arth's checklist]]
[[System.WebHome][WebHome]]
[[WebPreferences]]
END_EXPECTED

    _trimSpaces($source);
    _trimSpaces($expected);

    $source = Foswiki::Func::expandCommonVariables($source);
    $source = Foswiki::Func::expandCommonVariables($source);
    $source = Foswiki::Func::renderText($source, $this->{test_web}, "TestTopic");
    #print " RENDERED = $source \n";
    $this->assert_str_not_equals( $expected, $source );

#DO it without find elsewhere..
#turned off.
#turn off nested webs and add / into NameFilter
$Foswiki::cfg{FindElsewherePlugin}{CairoLegacyLinking} = 0;
$Foswiki::cfg{EnableHierarchicalWebs} = 0;
$Foswiki::cfg{NameFilter} = $Foswiki::cfg{NameFilter} = '[\/\\s\\*?~^\\$@%`"\'&;|<>\\[\\]#\\x00-\\x1f]';
    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/TestTopic");
    $this->createNewFoswikiSession( undef, $query );

    $source = <<END_SOURCE;
SiteChanges
[[6to4.enro.net]]
[[aou1.aplp.net]]
[[Member/Finance]]
[[MyNNA bugs/feature requests]]
[[Transfer/merger/restructure]]
[[Arth's checklist]]
[[WebHome]]
[[WebPreferences]]
[[does.not.exist]]
END_SOURCE

    $expected = <<"END_EXPECTED";
[[System.SiteChanges][SiteChanges]]
[[6to4enronet][6to4.enro.net]]
[[Aou1aplpnet][aou1.aplp.net]]
[[MemberFinance][Member/Finance]]
[[MyNNABugsfeatureRequests][MyNNA bugs/feature requests]]
[[Transfermergerrestructure][Transfer/merger/restructure]]
[[ArthsChecklist][Arth's checklist]]
[[System.WebHome][WebHome]]
[[WebPreferences]]
[[does.not.exist]]
END_EXPECTED

    _trimSpaces($source);
    _trimSpaces($expected);

    $source = Foswiki::Func::expandCommonVariables($source);
    $source = Foswiki::Func::expandCommonVariables($source);
    $source = Foswiki::Func::renderText($source, $this->{test_web}, "TestTopic");
    #print " RENDERED = $source \n";
    $this->assert_str_not_equals( $expected, $source );

}

sub _trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

1;
