# tests for the correct expansion of TOPICLIST

package Fn_TOPICLIST;
use v5.14;

use Foswiki;
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

around BUILDARGS => sub {
    my $orig = shift;
    return $orig->( @_, testSuite => 'TOPICLIST' );
};

my @allTopics;
my @allTopicsH;
my @allSubwebTopics;

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $webObject = $this->populateNewWeb( $this->test_web . "/SubWeb" );
    $webObject->finish();

    my $webObjectH = $this->populateNewWeb( $this->test_web . "Hidden" );
    $webObjectH->finish();

    my ($webPrefsObj) = Foswiki::Func::readTopic( $this->test_web . "Hidden",
        $Foswiki::cfg{WebPrefsTopicName} );
    my $users_web = $this->users_web;
    $webPrefsObj->text(<<"THIS");
If ALLOW is set to a list of wikiname
   * people not in the list are DENIED access
   * Set ALLOWWEBVIEW = $users_web.AdminUser
THIS
    $webPrefsObj->save();
    $webPrefsObj->finish();

    Foswiki::Func::readTemplate('foswiki');

    @allTopics = Foswiki::Func::getTopicList( $this->test_web );
    @allSubwebTopics =
      Foswiki::Func::getTopicList( $this->test_web . "/SubWeb" );
    @allTopicsH = Foswiki::Func::getTopicList( $this->test_web . "Hidden" );
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;
    $this->removeWebFixture( $this->session, $this->test_web . "Hidden" )
      if ( $this->session->webExists( $this->test_web . "Hidden" ) );
    $orig->($this);
};

sub test_hidden_web_list {
    my $this = shift;

    # Item10690:   If the entire web is hidden, TOPICLIST should not reveal the
    # contents of the web.
    my $text =
      $this->test_topicObject->expandMacros(
        "%TOPICLIST{ web=\"" . $this->test_web . "Hidden\"}%" );
    $this->assert_str_equals( '', $text );
}

sub test_no_format_no_separator {
    my $this = shift;

    my $text = $this->test_topicObject->expandMacros('%TOPICLIST{}%');
    $this->assert_str_equals( join( "\n", @allTopics ), $text );
}

sub test_no_format_with_separator {
    my $this = shift;

    my $text =
      $this->test_topicObject->expandMacros('%TOPICLIST{separator=";"}%');
    $this->assert_str_equals( join( ';', @allTopics ), $text );
}

sub test_with_format_no_separator {
    my $this = shift;

    my $text = $this->test_topicObject->expandMacros('%TOPICLIST{"$topic"}%');
    $this->assert_str_equals( join( "\n", @allTopics ), $text );
}

sub test_with_format_with_separator {
    my $this = shift;

    my $text =
      $this->test_topicObject->expandMacros(
        '%TOPICLIST{"$topic" separator=";"}%');
    $this->assert_str_equals( join( ';', @allTopics ), $text );
}

sub test_otherWeb {
    my $this = shift;

    my $text =
      $this->test_topicObject->expandMacros(
        '%TOPICLIST{web="' . $this->test_web . '/SubWeb"}%' );
    $this->assert_str_equals( join( ';', @allSubwebTopics ), $text );
}

sub test_otherWeb_NOSEARCHALL {
    my $this = shift;

    my ($to) = Foswiki::Func::readTopic( $this->test_web . "/SubWeb",
        $Foswiki::cfg{WebPrefsTopicName} );
    $to->text( $to->text() . "\n   * Set NOSEARCHALL = on\n" );
    $to->save();
    $to->finish();

    my $text =
      $this->test_topicObject->expandMacros(
        '%TOPICLIST{web="' . $this->test_web . '/SubWeb"}%' );
    $this->assert_str_equals( join( ';', @allSubwebTopics ), $text );
}

# "format"  	 Format of one line, may include $web (name of web),
#                $topic (name of the topic)
# format="format" 	(Alternative to above)
sub test_format {
    my $this = shift;
    my $text =
      $this->test_topicObject->expandMacros('%TOPICLIST{"$web:$topic"}%');
    $this->assert_str_equals(
        join( "\n", map { $this->test_web . ":$_" } @allTopics ), $text );

    # format="format" 	(Alternative to above) Default: "$name"
    $text =
      $this->test_topicObject->expandMacros(
        '%TOPICLIST{format="$web:$topic"}%');
    $this->assert_str_equals(
        join( "\n", map { $this->test_web . ":$_" } @allTopics ), $text );
}

# marker="selected" Text for $marker if the item matches selection
#                   Default: "selected"
# selection="%WEB%" Current value to be selected in list Default: "%WEB%"
sub test_marker {
    my $this = shift;

    my $text =
      $this->test_topicObject->expandMacros( '%TOPICLIST{selection="'
          . $allTopics[1] . ","
          . $allTopics[-1]
          . '" format="$topic$marker"}%' );
    my @munged = @allTopics;
    $munged[1] = "$munged[1]selected=\"selected\"";
    $this->assert_str_equals( join( "\n", @munged ), $text );

    $text =
      $this->test_topicObject->expandMacros( '%TOPICLIST{selection="'
          . $allTopics[1] . ","
          . $allTopics[-1]
          . '" marker="sponge" format="$topic$marker"}%' );
    @munged = @allTopics;
    $munged[1] = "$munged[1]sponge";
    $this->assert_str_equals( join( "\n", @munged ), $text );
}

1;
