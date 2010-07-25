package ZoneTests;

use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub test_1 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml    = '%ADDTOZONE{zone="test" text=""}%';
    my $expect = "";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone( "test", { format => '$item' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_2 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml    = '%ADDTOZONE{zone="test" text=""}%';
    my $expect = "";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result =
      $this->{session}->_renderZone( "test", { format => '$item $tag' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_3 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml    = '%ADDTOZONE{zone="test" text="text"}%';
    my $expect = "text";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone( "test", { format => '$item' } );
    $this->assert_equals( $expect, $result );

    $result = $this->{session}->_renderZone( "test", { format => '$item' } );
    $this->assert_equals( '', $result );

    return;
}

sub test_4 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml    = '%ADDTOZONE{zone="test" tag="tag" text="item"}%';
    my $expect = "item=item tag=tag";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result =
      $this->{session}
      ->_renderZone( "test", { format => 'item=$item tag=$tag' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_5 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml    = '%ADDTOZONE{zone="test1,test2" text="text"}%';
    my $expect = "text";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );

    my $result = $this->{session}->_renderZone( "test", { format => '$item' } );
    $this->assert_equals( '', $result );

    my $result1 =
      $this->{session}->_renderZone( "test1", { format => '$item' } );
    $this->assert_equals( $expect, $result1 );

    my $result2 =
      $this->{session}->_renderZone( "test2", { format => '$item' } );
    $this->assert_equals( $expect, $result2 );

    $this->assert_equals( $result1, $result2 );

    return;
}

sub test_6 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOZONE{zone="test" tag="tag1" text="text1"}%
%ADDTOZONE{zone="test" tag="tag1" text="text2"}%';
HERE
    my $expect = "text2";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone( "test", { format => '$item' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_7 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOZONE{zone="test" tag="tag1" text="text1"}%
%ADDTOZONE{zone="test" tag="tag2" text="text2"}%
HERE
    my $expect = "text1\ntext2";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone( "test", { format => '$item' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_8 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOZONE{zone="test" tag="tag1" text="text1"}%
%ADDTOZONE{zone="test" tag="tag2" text="text2"}%
HERE
    my $expect = "text1text2";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result =
      $this->{session}
      ->_renderZone( "test", { format => '$item', separator => "" } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_9 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOZONE{zone="test" tag="tag1" text="text1" requires="tag2"}%
%ADDTOZONE{zone="test" tag="tag2" text="text2"}%
HERE
    my $expect = "text2\ntext1";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone( "test", { format => '$item' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_10 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOZONE{zone="test" tag="tag2" text="text2"}%
%ADDTOZONE{zone="test" tag="tag3" text="text3" requires="tag2"}%
%ADDTOZONE{zone="test" tag="tag1" text="text1" requires="tag2,tag3"}%
HERE
    my $expect = "text2\ntext3\ntext1";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone( "test", { format => '$item' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_11 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOZONE{zone="test" tag="tag1" text="text1" requires="tag2"}%
HERE
    my $expect = "item=text1 tag=tag1";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result =
      $this->{session}
      ->_renderZone( "test", { format => 'item=$item tag=$tag' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_12 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOZONE{zone="test" tag="tag1" text="text1" requires="tag1"}%
HERE
    my $expect = "item=text1 tag=tag1";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result =
      $this->{session}
      ->_renderZone( "test", { format => 'item=$item tag=$tag' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_13 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml    = '%ADDTOZONE{zone="test" text="text" tag="tag"}%';
    my $expect = "text <!-- tag -->";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone("test");
    $this->assert_equals( $expect, $result );

    return;
}

sub test_addToHEAD_compatibility_1 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOZONE{zone="head" tag="tag1" text="text1" requires="tag2"}%
%ADDTOHEAD{"tag2" text="text2"}%
HERE
    my $expect = "text2\ntext1";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone( "head", { format => '$item' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_addToHEAD_compatibility_2 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOHEAD{"tag1" text="text1" requires="tag2"}%
%ADDTOZONE{zone="head" tag="tag2" text="text2"}%
HERE
    my $expect = "text2\ntext1";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone( "head", { format => '$item' } );
    $this->assert_equals( $expect, $result );

    return;
}

1;
