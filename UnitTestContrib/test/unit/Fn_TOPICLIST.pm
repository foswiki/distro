# tests for the correct expansion of TOPICLIST

package Fn_TOPICLIST;
use base qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'TOPICLIST', @_ );
    return $self;
}

my @allTopics;
my @allSubwebTopics;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $webObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/SubWeb" );
    $webObject->populateNewWeb();
    Foswiki::Func::readTemplate('foswiki');

    @allTopics       = Foswiki::Func::getTopicList( $this->{test_web} );
    @allSubwebTopics = Foswiki::Func::getTopicList("$this->{test_web}/SubWeb");
}

# separator=", " 	line separator 	"$n" (new line)
sub test_separator {
    my $this = shift;

    my $text = $this->{test_topicObject}->expandMacros('%TOPICLIST%');
    $this->assert_str_equals( join( "\n", @allTopics ), $text );
    $text =
      $this->{test_topicObject}->expandMacros('%TOPICLIST{separator=";"}%');
    $this->assert_str_equals( join( ';', @allTopics ), $text );
}

sub test_otherWeb {
    my $this = shift;

    my $text =
      $this->{test_topicObject}
      ->expandMacros( '%TOPICLIST{web="' . $this->{test_web} . '/SubWeb"}%' );
    $this->assert_str_equals( join( ';', @allSubwebTopics ), $text );
}

# "format"  	 Format of one line, may include $web (name of web),
#                $topic (name of the topic)
# format="format" 	(Alternative to above)
sub test_format {
    my $this = shift;
    my $text =
      $this->{test_topicObject}->expandMacros('%TOPICLIST{"$web:$topic"}%');
    $this->assert_str_equals(
        join( "\n", map { "$this->{test_web}:$_" } @allTopics ), $text );

    # format="format" 	(Alternative to above) Default: "$name"
    $text =
      $this->{test_topicObject}
      ->expandMacros('%TOPICLIST{format="$web:$topic"}%');
    $this->assert_str_equals(
        join( "\n", map { "$this->{test_web}:$_" } @allTopics ), $text );
}

# marker="selected" Text for $marker if the item matches selection
#                   Default: "selected"
# selection="%WEB%" Current value to be selected in list Default: "%WEB%"
sub test_marker {
    my $this = shift;

    my $text =
      $this->{test_topicObject}->expandMacros( '%TOPICLIST{selection="'
          . $allTopics[1] . ","
          . $allTopics[-1]
          . '" format="$topic$marker"}%' );
    my @munged = @allTopics;
    $munged[1] = "$munged[1]selected=\"selected\"";
    $this->assert_str_equals( join( "\n", @munged ), $text );

    $text =
      $this->{test_topicObject}->expandMacros( '%TOPICLIST{selection="'
          . $allTopics[1] . ","
          . $allTopics[-1]
          . '" marker="sponge" format="$topic$marker"}%' );
    @munged = @allTopics;
    $munged[1] = "$munged[1]sponge";
    $this->assert_str_equals( join( "\n", @munged ), $text );
}

1;
