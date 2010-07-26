package ZoneTests;

use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my ($this) = @_;

    $this->SUPER::set_up();

    # Disable JQueryPlugin, which adds noise to body zone
    $Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled} = 0;
    $this->{session}->finish();
    $this->{session} = Foswiki::new('Foswiki');

    return;
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
      $this->{session}->_renderZone( "test", { format => '$item $id' } );
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

    my $tml    = '%ADDTOZONE{zone="test" id="id" text="item"}%';
    my $expect = "item=item id=id";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result =
      $this->{session}
      ->_renderZone( "test", { format => 'item=$item id=$id' } );
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
%ADDTOZONE{zone="test" id="id1" text="text1"}%
%ADDTOZONE{zone="test" id="id1" text="text2"}%';
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
%ADDTOZONE{zone="test" id="id1" text="text1"}%
%ADDTOZONE{zone="test" id="id2" text="text2"}%
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
%ADDTOZONE{zone="test" id="id1" text="text1"}%
%ADDTOZONE{zone="test" id="id2" text="text2"}%
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
%ADDTOZONE{zone="test" id="id1" text="text1" requires="id2"}%
%ADDTOZONE{zone="test" id="id2" text="text2"}%
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
%ADDTOZONE{zone="test" id="id2" text="text2"}%
%ADDTOZONE{zone="test" id="id3" text="text3" requires="id2"}%
%ADDTOZONE{zone="test" id="id1" text="text1" requires="id2,id3"}%
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
%ADDTOZONE{zone="test" id="id1" text="text1" requires="id2"}%
HERE
    my $expect = "item=text1 id=id1";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result =
      $this->{session}
      ->_renderZone( "test", { format => 'item=$item id=$id' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_12 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOZONE{zone="test" id="id1" text="text1" requires="id1"}%
HERE
    my $expect = "item=text1 id=id1";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result =
      $this->{session}
      ->_renderZone( "test", { format => 'item=$item id=$id' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_13 {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml    = '%ADDTOZONE{zone="test" text="text" id="id"}%';
    my $expect = "text <!-- id -->";

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
%ADDTOZONE{zone="head" id="id1" text="text1" requires="id2"}%
%ADDTOHEAD{"id2" text="text2"}%
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
%ADDTOHEAD{"id1" text="text1" requires="id2"}%
%ADDTOZONE{zone="head" id="id2" text="text2"}%
HERE
    my $expect = "text2\ntext1";

    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = $this->{session}->_renderZone( "head", { format => '$item' } );
    $this->assert_equals( $expect, $result );

    return;
}

sub _setOptimizePageLayout {
    my ( $this, $optimized ) = @_;

    $Foswiki::cfg{OptimizePageLayout} = $optimized;

    return;
}

sub test_Unoptimized_HEAD_merged_with_BODY {
    my $this = shift;
    $this->_setOptimizePageLayout(0);

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOHEAD{               "head1" text="text1" requires="head2"}%
%ADDTOZONE{zone="head" id="head2" text="this-text-will-be-ignored"}%
%ADDTOZONE{zone="head" id="head2" text="text2"}%
%ADDTOZONE{"body"      id="body3" text="text3" requires="body4"}%
%ADDTOZONE{zone="body" id="body4" text="text4" requires="head2"}%
%ADDTOHEAD{               "head5" text="text5" requires="body4,body3,body6"}%
%ADDTOZONE{zone="body" id="body6" text="text6" requires="head2,something-missing"}%
%ADDTOZONE{zone="head" id="misc7" text="head::misc7"}%
%ADDTOZONE{zone="body" id="misc7" text="body::misc7"}%
HERE
    my $expect = <<'HERE';
HEAD:
head::misc7 <!-- misc7 -->
text2 <!-- head2 -->
text1 <!-- head1 -->
text4 <!-- body4 -->
text3 <!-- body3 -->
text6 <!-- body6 required id(s) that were missing from body zone: something-missing -->
text5 <!-- head5 -->
body::misc7 <!-- misc7 -->
BODY:
HERE
    chomp($expect);
    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = "HEAD:\n"
      . $this->{session}->_renderZone( "head", );
    $result =
        $result
      . "\nBODY:"
      . $this->{session}->_renderZone( "body", );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_Optimized_HEAD_split_from_BODY {
    my $this = shift;
    $this->_setOptimizePageLayout(1);

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $tml = <<'HERE';
%ADDTOHEAD{               "head1" text="text1" requires="head2"}%
%ADDTOZONE{zone="head" id="head2" text="this-text-will-be-ignored"}%
%ADDTOZONE{zone="head" id="head2" text="text2"}%
%ADDTOZONE{"body"      id="body3" text="text3" requires="body4"}%
%ADDTOZONE{zone="body" id="body4" text="text4" requires="head2"}%
%ADDTOHEAD{               "head5" text="text5" requires="body4,body3,body6"}%
%ADDTOZONE{zone="body" id="body6" text="text6" requires="head2,something-missing"}%
%ADDTOZONE{zone="head" id="misc7" text="head::misc7"}%
%ADDTOZONE{zone="body" id="misc7" text="body::misc7"}%
HERE
    my $expect = <<'HERE';
HEAD:
head::misc7 <!-- misc7 -->
text2 <!-- head2 -->
text1 <!-- head1 -->
text5 <!-- head5 required id(s) that were missing from head zone: body4, body3, body6 -->
BODY:
body::misc7 <!-- misc7 -->
text4 <!-- body4 required id(s) that were missing from body zone: head2 -->
text3 <!-- body3 -->
text6 <!-- body6 required id(s) that were missing from body zone: head2, something-missing -->
HERE
    chomp($expect);
    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = "HEAD:\n"
      . $this->{session}->_renderZone( "head" );
    $result =
        $result
      . "\nBODY:\n"
      . $this->{session}->_renderZone( "body" );
    $this->assert_equals( $expect, $result );

    return;
}

sub test_legacy_tag_param_compatibility {
    my $this = shift;
    $this->_setOptimizePageLayout(1);
    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $tml = <<'HERE';
%ADDTOHEAD{                "head1" text="text1" requires="head2"}%
%ADDTOZONE{zone="head" id="head2" text="this-text-will-be-ignored"}%
%ADDTOZONE{zone="head" tag="head2" text="text2"}%
%ADDTOZONE{"body"      tag="body3" text="text3" requires="body4"}%
%ADDTOZONE{zone="body" tag="body4" text="text4" requires="head2"}%
%ADDTOHEAD{                "head5" text="text5" requires="body4"}%
%ADDTOZONE{zone="head" id="misc7" text="head::misc7"}%
%ADDTOZONE{zone="body" id="misc7" text="body::misc7"}%
HERE
    my $expect = <<'HERE';
HEAD:
head::misc7 <!-- misc7 -->
text2 <!-- head2 -->
text1 <!-- head1 -->
text5 <!-- head5 required id(s) that were missing from head zone: body4 -->
BODY:
body::misc7 <!-- misc7 -->
text4 <!-- body4 required id(s) that were missing from body zone: head2 -->
text3 <!-- body3 -->
HERE
    chomp($expect);
    Foswiki::Func::expandCommonVariables( $tml, $topicName, $webName );
    my $result = "HEAD:\n"
      . $this->{session}->_renderZone( "head" );
    $result =
        $result
      . "\nBODY:\n"
      . $this->{session}->_renderZone( "body" );
    $this->assert_equals( $expect, $result );

    return;
}

1;
