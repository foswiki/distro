package Fn_PARENTTOPIC;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
use Foswiki::Configure::Dependency;
use Assert;

my $post11;

sub new {
    my $self = shift()->SUPER::new( 'SEARCH', @_ );

    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki",
        version => ">=2.2"
    );
    ( $post11, my $message ) = $dep->checkDependency();

    return $self;
}

sub test_PARENTTOPIC_empty {
    my $this = shift;

    # word

    my $result = $this->{test_topicObject}->expandMacros('%PARENTTOPIC%');

    $this->assert_str_equals( "", $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        '%PARENTTOPIC{prefix="a" suffix="b" separator="c" recurse="on"}%');

    $this->assert_str_equals( "", $result );
}

sub test_PARENTTOPIC_recurse {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}
      ->expandMacros('%PARENTTOPIC{topic="%SYSTEMWEB%.VarPARENTTOPIC"}%');

    $this->assert_str_equals( "[[$Foswiki::cfg{SystemWebName}.Macros][Macros]]",
        $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        '%PARENTTOPIC{topic="%SYSTEMWEB%.VarPARENTTOPIC" recurse="yes"}%');

    $this->assert_str_equals(
"[[$Foswiki::cfg{SystemWebName}.Category][Category]] &gt; [[$Foswiki::cfg{SystemWebName}.UserDocumentationCategory][UserDocumentationCategory]] &gt; [[$Foswiki::cfg{SystemWebName}.Macros][Macros]]",
        $result
    );

}

sub test_PARENTTOPIC_depth {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%PARENTTOPIC{topic="%SYSTEMWEB%.VarPARENTTOPIC" depth="1" recurse="yes"}%'
      );

    $this->assert_str_equals( "[[$Foswiki::cfg{SystemWebName}.Macros][Macros]]",
        $result );

    $result =
      $this->{test_topicObject}->expandMacros(
'%PARENTTOPIC{topic="%SYSTEMWEB%.VarPARENTTOPIC" depth="2" recurse="on"}%'
      );

    $this->assert_str_equals(
"[[$Foswiki::cfg{SystemWebName}.UserDocumentationCategory][UserDocumentationCategory]]",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros(
'%PARENTTOPIC{topic="%SYSTEMWEB%.VarPARENTTOPIC" depth="2" recurse="off"}%'
      );

    # depth is ignored if recurse is off. Returns immediate parent.
    $this->assert_str_equals( "[[$Foswiki::cfg{SystemWebName}.Macros][Macros]]",
        $result );

}

sub test_PARENTTOPIC_pfx_suffix {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%PARENTTOPIC{topic="%SYSTEMWEB%.VarPARENTTOPIC" depth="1" recurse="yes" prefix="YABA" suffix="DABA"}%'
      );

    $this->assert_str_equals(
        "YABA[[$Foswiki::cfg{SystemWebName}.Macros][Macros]]DABA", $result );

    $result =
      $this->{test_topicObject}->expandMacros(
'%PARENTTOPIC{topic="%SYSTEMWEB%.VarPARENTTOPIC" prefix="$n   * " suffix="$n--- " separator="$n   * " recurse="on"}%'
      );

    $this->assert_str_equals( "
   * [[$Foswiki::cfg{SystemWebName}.Category][Category]]
   * [[$Foswiki::cfg{SystemWebName}.UserDocumentationCategory][UserDocumentationCategory]]
   * [[$Foswiki::cfg{SystemWebName}.Macros][Macros]]
--- ", $result );

}

sub test_PARENTTOPIC_format {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%PARENTTOPIC{topic="%SYSTEMWEB%.VarPARENTTOPIC" prefix="$n" suffix="$n--- " separator="$n" format="   * [[$web.$topic]] " recurse="on"}%'
      );

    $this->assert_str_equals( "
   * [[$Foswiki::cfg{SystemWebName}.Category]] 
   * [[$Foswiki::cfg{SystemWebName}.UserDocumentationCategory]] 
   * [[$Foswiki::cfg{SystemWebName}.Macros]] 
--- ", $result );

}

1;
