package RenameTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::UI::Rename;
use Error ':try';
use File::Temp;

my $notawwtopic1 = "random";
my $notawwtopic2 = "Random";
my $notawwtopic3 = "ranDom";
my $debug        = 0;
my $UI_FN;

# Set up the test fixture. The idea behind the tests is to populate a
# set of strategically-selected topics with text that contains all the
# relevant reference syntaxes. Then after each different type of rename,
# we can check that those references have been redirected appropriately.
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $UI_FN ||= $this->getUIFn('rename');

    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login},
        new Unit::Request( { topic => "/$this->{test_web}/OldTopic" } ) );

    $this->{new_web} = $this->{test_web} . 'New';
    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{new_web} );
    $webObject->populateNewWeb();
    $Foswiki::Plugins::SESSION = $this->{session};

    # Topic text that contains all the different kinds of topic reference
    my $originaltext = <<THIS;
1 $this->{test_web}.OldTopic
$this->{test_web}.OldTopic 2
3 $this->{test_web}.OldTopic more
OldTopic 4
5 OldTopic
6 !OldTopic
6A <nop>OldTopic
6B <nop> OldTopic
6C ! OldTopic
7 (OldTopic)
8 [[$this->{test_web}.OldTopic]]
9 [[OldTopic]]
10 [[$this->{test_web}.OldTopic][the text]]
11 [[OldTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{test_web}/OldTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{test_web}.OldTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
rename [[OldTopic]]
rename [[$this->{test_web}.OldTopic]]
</noautolink>
22 %INCLUDE{"OldTopic"}%
23 %INCLUDE{"$this->{test_web}.OldTopic"}%
24 "OldTopic, OtherTopic"
25 =OldTopic Fixed link to OldTopic=
26 *OldTopic Bold link to OldTopic*
27 _OldTopic Italic link to OldTopic_
THIS

    # Strategically-selected set of identical topics in the test web
    foreach my $topic ( 'OldTopic', 'OtherTopic', 'random', 'Random', 'ranDom',
        'Tmp1' )
    {
        my $meta =
          Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic,
            $originaltext );
        $meta->putKeyed(
            'FIELD',
            {
                name  => $this->{test_web},
                value => $this->{test_web}
            }
        );
        $meta->putKeyed(
            'FIELD',
            {
                name  => "$this->{test_web}.OldTopic",
                value => "$this->{test_web}.OldTopic"
            }
        );
        $meta->putKeyed(
            'FIELD',
            {
                name  => 'OldTopic',
                value => 'OldTopic'
            }
        );
        $meta->putKeyed(
            'FIELD',
            {
                name  => "OLD",
                value => "$this->{test_web}.OldTopic"
            }
        );
        $meta->putKeyed(
            'FIELD',
            {
                name  => "NEW",
                value => "$this->{new_web}.NewTopic"
            }
        );
        $meta->put( "TOPICPARENT", { name => "$this->{test_web}.OldTopic" } );
        $meta->save();
    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, $topic ) );
    }


    # Topic in the new web
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'OtherTopic',
        $originaltext );
    $meta->putKeyed(
        'FIELD',
        {
            name  => $this->{test_web},
            value => $this->{test_web}
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name  => "$this->{test_web}.OldTopic",
            value => "$this->{test_web}.OldTopic"
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name  => 'OldTopic',
            value => 'OldTopic'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name  => "OLD",
            value => "$this->{test_web}.OldTopic"
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name  => "NEW",
            value => "$this->{new_web}.NewTopic"
        }
    );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.OldTopic" } );
    $meta->save();

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web},
        $Foswiki::cfg{HomeTopicName}, 'junk' );
    $topicObject->save();

    # Topic text for template rename tests that contains all references.
    my $origTemplateRefs = <<THIS;
 $this->{test_web}.OldView
 $this->{test_web}.OldViewTemplate
   * Set VIEW_TEMPLATE = OldView
   * Local VIEW_TEMPLATE = OldView
      * Set VIEW_TEMPLATE = OldViewTemplate
      * Local VIEW_TEMPLATE = OldViewTemplate
   * Set EDIT_TEMPLATE = OldView
      * Local EDIT_TEMPLATE = OldView
   * Set VIEW_TEMPLATE = $this->{test_web}.OldView
   * Local VIEW_TEMPLATE = $this->{test_web}.OldView
      * Set VIEW_TEMPLATE = $this->{test_web}.OldViewTemplate
      * Local VIEW_TEMPLATE = $this->{test_web}.OldViewTemplate
   * Set EDIT_TEMPLATE = $this->{test_web}.OldView
      * Local EDIT_TEMPLATE = $this->{test_web}.OldView
   * Set VIEW_TEMPLATE = $this->{new_web}.OldView
   * Set SOME_TEMPLATE = $this->{new_web}.OldView
   * Set SOME_TEMPLATE = $this->{new_web}.OldViewTemplate
THIS

    $meta = Foswiki::Meta->new(
        $this->{session}, $this->{test_web},
        'TmplRefTopic',   $origTemplateRefs
    );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => "VIEW_TEMPLATE",
            title => "VIEW_TEMPLATE",
            type  => "Set",
            value => "$this->{test_web}.OldView"
        }
    );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => "EDIT_TEMPLATE",
            title => "EDIT_TEMPLATE",
            type  => "Set",
            value => "OldView"
        }
    );
    $meta->save();
    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, 'TmplRefTopic' ) );

    $meta = Foswiki::Meta->new(
        $this->{session}, $this->{test_web},
        'TmplRefTopic2',  $origTemplateRefs
    );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => "VIEW_TEMPLATE",
            title => "VIEW_TEMPLATE",
            type  => "Set",
            value => "$this->{test_web}.OldViewTemplate"
        }
    );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => "EDIT_TEMPLATE",
            title => "EDIT_TEMPLATE",
            type  => "Set",
            value => "OldViewTemplate"
        }
    );
    $meta->save();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TmplRefMeta1',
        "Meta Only" );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => "VIEW_TEMPLATE",
            title => "VIEW_TEMPLATE",
            type  => "Set",
            value => "$this->{test_web}.OldViewTemplate"
        }
    );
    $meta->save();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TmplRefMeta2',
        "Meta Only" );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => "VIEW_TEMPLATE",
            title => "VIEW_TEMPLATE",
            type  => "Set",
            value => "OldView"
        }
    );
    $meta->save();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TmplRefMeta3',
        "Meta Only" );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => "EDIT_TEMPLATE",
            title => "EDIT_TEMPLATE",
            type  => "Set",
            value => "OldView"
        }
    );
    $meta->save();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'OldViewTemplate', "Template" );
    $meta->save();
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture( $this->{session}, $this->{new_web} );
    $this->removeWebFixture( $this->{session}, "Renamedweb$this->{test_web}" )
      if ( $this->{session}->webExists("Renamedweb$this->{test_web}") );
    $this->removeWebFixture( $this->{session}, "$this->{test_web}EdNet" )
      if ( $this->{session}->webExists("$this->{test_web}EdNet") );
    $this->removeWebFixture( $this->{session}, "$this->{test_web}RenamedEdNet" )
      if ( $this->{session}->webExists("$this->{test_web}RenamedEdNet") );
    $this->removeWebFixture( $this->{session}, "$this->{test_web}Root" )
      if ( $this->{session}->webExists("$this->{test_web}Root") );
    $this->SUPER::tear_down();
}

sub check {
    my ( $this, $web, $topic, $emeta, $expected, $num ) = @_;
    my $meta   = Foswiki::Meta->load( $this->{session}, $web, $topic );
    my $actual = $meta->text;
    my @old    = split( /\n+/, $expected );
    my @new    = split( /\n+/, $actual );

    while ( scalar(@old) ) {
        my $o = "$num: " . shift(@old);
        my $n = "$num: " . shift(@new);
        $this->assert_str_equals( $o, $n,
            "Expect $o\nActual $n\n" . join( ",", caller ) );
    }
}

# Check the results of _getReferringTopics. $all means all webs. $expected
# is an array of topic names that should be seen. $forgiving means that
# the actual set may contain other topics besides those expected.
sub checkReferringTopics {
    my ( $this, $web, $topic, $all, $expected, $forgiving ) = @_;

    my $m = Foswiki::Meta->new( $this->{session}, $web, $topic );
    my $refs =
      Foswiki::UI::Rename::_getReferringTopics( $this->{session}, $m, $all );

    $this->assert_str_equals( 'HASH', ref($refs) );
    if ($forgiving) {
        foreach my $k ( keys %$refs ) {
            unless ( $k =~ /^$this->{test_web}/ ) {
                delete( $refs->{$k} );
            }
        }
    }

    # Check that all expected topics were seen
    my %expected_but_unseen;
    my %e = map { $_ => 1 } @$expected;
    foreach my $r ( keys %e ) {
        unless ( $refs->{$r} ) {
            $expected_but_unseen{$r} = 1;
        }
    }

    # Check that no unexpected topics were seen
    my %not_expected;
    foreach my $r ( keys %$refs ) {
        $this->assert_not_null($r);
        unless ( $e{$r} ) {
            $not_expected{$r} = 1;
        }
    }

    $this->assert_equals(
        0,
        scalar( keys %not_expected ),
        'not expected: ' . join( ' ', keys %not_expected )
    );
    $this->assert_equals(
        0,
        scalar( keys %expected_but_unseen ),
        'expected but missing: ' . join( ' ', keys %expected_but_unseen )
    );

    my $i = scalar( keys %$refs );
    my @e = sort @$expected;
    my $j = scalar(@e);
    my @r = sort keys %$refs;
    while ( --$i >= 0 && scalar(@e) ) {
        my $e = $e[ --$j ];
        while ( $i >= 0 && $r[$i] ne $e ) {
            $i--;
        }
        $this->assert_str_equals( $e, $r[$i],
                "Mismatch expected\n"
              . join( ',', @e )
              . " got\n"
              . join( ',', @r ) );
    }
    $this->assert_equals( 0, $j );
}

# Test referemces to a template topic
sub test_referringTemplateThisWeb {
    my $this = shift;

    $this->checkReferringTopics(
        $this->{test_web},
        'OldViewTemplate',
        0,
        [
            "$this->{test_web}.TmplRefTopic",
            "$this->{test_web}.TmplRefTopic2",
            "$this->{test_web}.TmplRefMeta1",
            "$this->{test_web}.TmplRefMeta2",
            "$this->{test_web}.TmplRefMeta3"
        ]
    );
}

# Test referemces to a template topic
sub test_renameTemplateThisWeb {
    my $this = shift;

    my $query = new Unit::Request(
        {
            action           => ['rename'],
            newweb           => [ $this->{test_web} ],
            newtopic         => ['NewViewTemplate'],
            referring_topics => [
                "$this->{test_web}.TmplRefTopic",
                "$this->{test_web}.TmplRefTopic2",
                "$this->{test_web}.TmplRefMeta1",
                "$this->{test_web}.TmplRefMeta2",
                "$this->{test_web}.TmplRefMeta3"
            ],
            topic => 'OldViewTemplate'
        }
    );

    $this->{session}->finish();

    # The topic in the path should not matter
    $query->path_info("/$this->{test_web}/SanityCheck");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->captureWithKey( rename => $UI_FN, $this->{session} );

    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, 'NewViewTemplate' ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, 'OldViewTemplate' )
    );

    # All of the topics refer to the new template
    $this->checkReferringTopics(
        $this->{test_web},
        'NewViewTemplate',
        0,
        [
            "$this->{test_web}.TmplRefTopic",
            "$this->{test_web}.TmplRefTopic2",
            "$this->{test_web}.TmplRefMeta1",
            "$this->{test_web}.TmplRefMeta2",
            "$this->{test_web}.TmplRefMeta3"
        ]
    );

    # Nothing except the template itself refers to the old template
    $this->checkReferringTopics( $this->{test_web}, 'OldViewTemplate', 0,
        [ "$this->{test_web}.NewViewTemplate" ] );

    my $m =
      Foswiki::Meta->load( $this->{session}, "$this->{test_web}",
        'TmplRefTopic' );
    my @lines = split( /\n/, $m->text() );
    $this->assert_str_equals( " $this->{test_web}.OldView",         $lines[0] );
    $this->assert_str_equals( " $this->{test_web}.NewViewTemplate", $lines[1] );
    $this->assert_str_equals( "   * Set VIEW_TEMPLATE = NewView",   $lines[2] );
    $this->assert_str_equals( "   * Local VIEW_TEMPLATE = NewView", $lines[3] );
    $this->assert_str_equals( "      * Set VIEW_TEMPLATE = NewViewTemplate",
        $lines[4] );
    $this->assert_str_equals( "      * Local VIEW_TEMPLATE = NewViewTemplate",
        $lines[5] );
    $this->assert_str_equals( "   * Set EDIT_TEMPLATE = NewView", $lines[6] );
    $this->assert_str_equals( "      * Local EDIT_TEMPLATE = NewView",
        $lines[7] );
    $this->assert_str_equals( "   * Set VIEW_TEMPLATE = NewView",   $lines[8] );
    $this->assert_str_equals( "   * Local VIEW_TEMPLATE = NewView", $lines[9] );
    $this->assert_str_equals(
        "      * Set VIEW_TEMPLATE = $this->{test_web}.NewViewTemplate",
        $lines[10] );
    $this->assert_str_equals(
        "      * Local VIEW_TEMPLATE = $this->{test_web}.NewViewTemplate",
        $lines[11] );
    $this->assert_str_equals( "   * Set EDIT_TEMPLATE = NewView", $lines[12] );
    $this->assert_str_equals( "      * Local EDIT_TEMPLATE = NewView",
        $lines[13] );
    $this->assert_str_equals(
        "   * Set VIEW_TEMPLATE = $this->{new_web}.OldView",
        $lines[14] );
    $this->assert_str_equals(
        "   * Set SOME_TEMPLATE = $this->{new_web}.OldView",
        $lines[15] );
    $this->assert_str_equals(
        "   * Set SOME_TEMPLATE = $this->{new_web}.OldViewTemplate",
        $lines[16] );
}

# Test references to a topic in this web
sub test_referringTopicsThisWeb {
    my $this = shift;
    my $ott  = 'Old Topic';
    my $lott = lc($ott);
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeOne',
        <<THIS );
[[$ott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeTwo',
        <<THIS );
[[$lott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'MatchMeThree',
        <<THIS );
[[$this->{test_web}.$ott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'MatchMeFour',
        <<THIS );
[[$this->{test_web}.$lott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'NoMatch',
        <<THIS );
Refer to $ott and $lott
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'NoMatch',
        <<THIS );
Refer to $ott and $lott
THIS
    $topicObject->save();

    if ( $^O eq 'MSWin32' ) {
        $this->expect_failure();
        $this->annotate(
"this test fails on a non-case sensitive filesystem - OSX default, Windows.."
        );
    }

    # Just Web
    $this->checkReferringTopics(
        $this->{test_web},
        'OldTopic',
        0,
        [
            "$this->{test_web}.OtherTopic", "$this->{test_web}.MatchMeOne",
            "$this->{test_web}.MatchMeTwo", "$this->{test_web}.random",
            "$this->{test_web}.Random",     "$this->{test_web}.ranDom",
            "$this->{test_web}.Tmp1",
        ]
    );
}

# Test references to a topic in all webs
# Warning; this is a bit of a lottery, as you might have webs that refer
# to the topic outside the test set. For this reason the test is forgiving
# if a ref outside of the test webs is found.
sub test_renameTopic_find_referring_topics_in_all_webs {
    my $this = shift;
    my $ott  = 'Old Topic';
    my $lott = lc($ott);
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeOne',
        <<THIS );
[[$ott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeTwo',
        <<THIS );
[[$lott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'MatchMeThree',
        <<THIS );
[[$this->{test_web}.$ott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'MatchMeFour',
        <<THIS );
[[$this->{test_web}.$lott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'NoMatch',
        <<THIS );
Refer to $ott and $lott
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'NoMatch',
        <<THIS );
Refer to $ott and $lott
THIS
    $topicObject->save();

    # All webs
    $this->checkReferringTopics(
        $this->{test_web},
        'OldTopic',
        1,
        [
            "$this->{new_web}.OtherTopic", "$this->{new_web}.MatchMeThree",
            "$this->{new_web}.MatchMeFour",
        ],
        1
    );
}

# Test references to a topic in this web, where the topic is not a wikiword
sub test_renameTopic_find_referring_topics_when_renamed_topic_is_not_a_WikiWord
{
    my $this = shift;
    my $ott  = 'ranDom';
    my $lott = lc($ott);
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeOne',
        <<THIS );
random random random
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeTwo',
        <<THIS );
ranDom ranDom ranDom
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeThree',
        <<THIS );
Random Random Random
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeFour',
        <<THIS );
RanDom RanDom RanDom
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeFive',
        <<THIS );
[[random]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeSix',
        <<THIS );
[[ranDom]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeSeven',
        <<THIS );
[[Random]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeEight',
        <<THIS );
[[RanDom]]
THIS
    $topicObject->save();

    if ( $^O eq 'MSWin32' ) {
        $this->expect_failure();
        $this->annotate(
"this test fails on a non-case sensitive filesystem - OSX default, Windows.."
        );
    }

    $this->checkReferringTopics(
        $this->{test_web},
        'random', 0,
        [
            "$this->{test_web}.MatchMeFive", "$this->{test_web}.OldTopic",
            "$this->{test_web}.OtherTopic",  "$this->{test_web}.Random",
            "$this->{test_web}.ranDom",      "$this->{test_web}.Tmp1",
        ]
    );
    $this->checkReferringTopics(
        $this->{test_web},
        'ranDom', 0,
        [
            "$this->{test_web}.MatchMeSix", "$this->{test_web}.OldTopic",
            "$this->{test_web}.OtherTopic", "$this->{test_web}.Random",
            "$this->{test_web}.random",     "$this->{test_web}.Tmp1",
        ]
    );
    $this->checkReferringTopics(
        $this->{test_web},
        'Random', 0,
        [
            "$this->{test_web}.MatchMeSeven", "$this->{test_web}.OldTopic",
            "$this->{test_web}.OtherTopic",   "$this->{test_web}.random",
            "$this->{test_web}.ranDom",       "$this->{test_web}.Tmp1",
        ]
    );
}

# There's a reference in a topic in a web which doesn't allow
# read access for the current user [[Foswiki:Tasks.Item1879]]
sub test_rename_topic_reference_in_denied_web {
    my $this = shift;

    # Make sure the reference can't exist outside the text fixture
    my $fnord = "FnordMustNotBeFound" . time;

    # Create the referred-to topic that we're renaming
    my $m = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $fnord );
    $m->text("");
    $m->save();

    # Create a subweb
    $m = Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Swamp" );
    $m->populateNewWeb();

    # Create a topic in the subweb that refers to the topic we're renaming
    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Swamp",
        'TopSecret' );
    $m->text("[[$this->{test_web}.$fnord]]");
    $m->save();

    # Make sure the subweb is unprotected (readable)
    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Swamp",
        'WebPreferences' );
    $m->text("   * Set ALLOWWEBCHANGE = \n   * Set ALLOWWEBVIEW = \n");
    $m->save();

    # Have to restart to clear prefs cache
    $this->{session}->finish();
    $this->{session} =
      new Foswiki( $this->{test_user_login}, new Unit::Request() );

    $this->checkReferringTopics( $this->{test_web}, $fnord, 1,
        [ "$this->{test_web}/Swamp.TopSecret" ] );

    # Protect the web we made (deny view access)
    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Swamp",
        'WebPreferences' );
    $m->text("   * Set ALLOWWEBVIEW = PickMeOhPickMe");
    $m->save();

    # Have to restart to clear prefs cache
    $this->{session}->finish();
    $this->{session} =
      new Foswiki( $this->{test_user_login}, new Unit::Request() );

    $this->checkReferringTopics(
        $this->{test_web},
        $fnord, 1,
        [

            # Should be empty
        ]
    );

    # Protect the web we made (deny change access)
    # We need to be able to see these references.
    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Swamp",
        'WebPreferences' );
    $m->text("   * Set ALLOWWEBCHANGE = PickMeOhPickMe");
    $m->save();

    # Have to restart to clear prefs cache
    $this->{session}->finish();
    $this->{session} =
      new Foswiki( $this->{test_user_login}, new Unit::Request() );

    $this->checkReferringTopics( $this->{test_web}, $fnord, 1,
        [ "$this->{test_web}/Swamp.TopSecret" ] );
}

# Rename OldTopic to NewTopic within the same web
sub test_renameTopic_same_web_new_topic_name {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action           => ['rename'],
            newweb           => [ $this->{test_web} ],
            newtopic         => ['NewTopic'],
            referring_topics => [
                "$this->{test_web}.NewTopic", "$this->{test_web}.OtherTopic",
                "$this->{new_web}.OtherTopic"
            ],
            topic => 'OldTopic'
        }
    );

    $this->{session}->finish();

    # The topic in the path should not matter
    $query->path_info("/$this->{test_web}/SanityCheck");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->captureWithKey( rename => $UI_FN, $this->{session} );

    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, 'NewTopic' ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, 'OldTopic' ) );

# Verify NewTopic references in test_web.NewTopic are updated
#
# SMELL: Line 24 - a quoted topic name - should probably not be renamed.  But it is
# important to handle topic names referenced inside %MACRO{ statements.  It was decided
# that it is more important to rename those quoted topics than to be 100% correct
# and renaming only references that result in a link, and missing the references used on
# line 22 and 23.
    #
    $this->check( $this->{test_web}, 'NewTopic', undef, <<THIS, 1 );
1 $this->{test_web}.NewTopic
$this->{test_web}.NewTopic 2
3 $this->{test_web}.NewTopic more
NewTopic 4
5 NewTopic
6 !OldTopic
6A <nop>OldTopic
6B <nop> NewTopic
6C ! NewTopic
7 (NewTopic)
8 [[$this->{test_web}.NewTopic]]
9 [[NewTopic]]
10 [[$this->{test_web}.NewTopic][the text]]
11 [[NewTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{test_web}/NewTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{test_web}.NewTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
rename [[NewTopic]]
rename [[$this->{test_web}.NewTopic]]
</noautolink>
22 %INCLUDE{"NewTopic"}%
23 %INCLUDE{"$this->{test_web}.NewTopic"}%
24 "NewTopic, OtherTopic"
25 =NewTopic Fixed link to NewTopic=
26 *NewTopic Bold link to NewTopic*
27 _NewTopic Italic link to NewTopic_
THIS

    #
    # Verify NewTopic references in test_web.OtherTopic  are updated
    #
    $this->check( $this->{test_web}, 'OtherTopic', undef, <<THIS, 2 );
1 $this->{test_web}.NewTopic
$this->{test_web}.NewTopic 2
3 $this->{test_web}.NewTopic more
NewTopic 4
5 NewTopic
6 !OldTopic
6A <nop>OldTopic
6B <nop> NewTopic
6C ! NewTopic
7 (NewTopic)
8 [[$this->{test_web}.NewTopic]]
9 [[NewTopic]]
10 [[$this->{test_web}.NewTopic][the text]]
11 [[NewTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{test_web}/NewTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{test_web}.NewTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
rename [[NewTopic]]
rename [[$this->{test_web}.NewTopic]]
</noautolink>
22 %INCLUDE{"NewTopic"}%
23 %INCLUDE{"$this->{test_web}.NewTopic"}%
24 "NewTopic, OtherTopic"
25 =NewTopic Fixed link to NewTopic=
26 *NewTopic Bold link to NewTopic*
27 _NewTopic Italic link to NewTopic_
THIS

    #
    # Verify NewTopic references in new_web.OtherTopic  are updated
    #
    $this->check( $this->{new_web}, 'OtherTopic', undef, <<THIS, 3 );
1 $this->{test_web}.NewTopic
$this->{test_web}.NewTopic 2
3 $this->{test_web}.NewTopic more
$this->{test_web}.NewTopic 4
5 $this->{test_web}.NewTopic
6 !OldTopic
6A <nop>OldTopic
6B <nop> $this->{test_web}.NewTopic
6C ! $this->{test_web}.NewTopic
7 ($this->{test_web}.NewTopic)
8 [[$this->{test_web}.NewTopic]]
9 [[$this->{test_web}.NewTopic]]
10 [[$this->{test_web}.NewTopic][the text]]
11 [[$this->{test_web}.NewTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{test_web}/NewTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{test_web}.NewTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
rename [[$this->{test_web}.NewTopic]]
rename [[$this->{test_web}.NewTopic]]
</noautolink>
22 %INCLUDE{"$this->{test_web}.NewTopic"}%
23 %INCLUDE{"$this->{test_web}.NewTopic"}%
24 "$this->{test_web}.NewTopic, OtherTopic"
25 =$this->{test_web}.NewTopic Fixed link to $this->{test_web}.NewTopic=
26 *$this->{test_web}.NewTopic Bold link to $this->{test_web}.NewTopic*
27 _$this->{test_web}.NewTopic Italic link to $this->{test_web}.NewTopic_
THIS
}

# Rename OldTopic to a different web, keeping the same topic name
sub test_renameTopic_new_web_same_topic_name {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action           => ['rename'],
            newweb           => [ $this->{new_web} ],
            newtopic         => ['OldTopic'],
            referring_topics => [
                "$this->{test_web}.OtherTopic", "$this->{new_web}.OldTopic",
                "$this->{new_web}.OtherTopic"
            ],
            topic => 'OldTopic'
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->captureWithKey( rename => $UI_FN, $this->{session} );

    $this->assert(
        $this->{session}->topicExists( $this->{new_web}, 'OldTopic' ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, 'OldTopic' ) );

    $this->check( $this->{new_web}, 'OldTopic', undef, <<THIS, 4 );
1 $this->{new_web}.OldTopic
$this->{new_web}.OldTopic 2
3 $this->{new_web}.OldTopic more
OldTopic 4
5 OldTopic
6 !OldTopic
6A <nop>OldTopic
6B <nop> OldTopic
6C ! OldTopic
7 (OldTopic)
8 [[$this->{new_web}.OldTopic]]
9 [[OldTopic]]
10 [[$this->{new_web}.OldTopic][the text]]
11 [[OldTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 $this->{test_web}.OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{new_web}/OldTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{new_web}.OldTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
rename [[OldTopic]]
rename [[$this->{new_web}.OldTopic]]
</noautolink>
THIS
    $this->check( $this->{new_web}, 'OtherTopic', undef, <<THIS, 5 );
1 $this->{new_web}.OldTopic
$this->{new_web}.OldTopic 2
3 $this->{new_web}.OldTopic more
OldTopic 4
5 OldTopic
6 !OldTopic
6A <nop>OldTopic
6B <nop> OldTopic
6C ! OldTopic
7 (OldTopic)
8 [[$this->{new_web}.OldTopic]]
9 [[OldTopic]]
10 [[$this->{new_web}.OldTopic][the text]]
11 [[OldTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{new_web}/OldTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{new_web}.OldTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
rename [[OldTopic]]
rename [[$this->{new_web}.OldTopic]]
</noautolink>
THIS

    $this->check( $this->{test_web}, 'OtherTopic', undef, <<THIS, 6 );
1 $this->{new_web}.OldTopic
$this->{new_web}.OldTopic 2
3 $this->{new_web}.OldTopic more
$this->{new_web}.OldTopic 4
5 $this->{new_web}.OldTopic
6 !OldTopic
6A <nop>OldTopic
6B <nop> $this->{new_web}.OldTopic
6C ! $this->{new_web}.OldTopic
7 ($this->{new_web}.OldTopic)
8 [[$this->{new_web}.OldTopic]]
9 [[$this->{new_web}.OldTopic]]
10 [[$this->{new_web}.OldTopic][the text]]
11 [[$this->{new_web}.OldTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{new_web}/OldTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{new_web}.OldTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
rename [[$this->{new_web}.OldTopic]]
rename [[$this->{new_web}.OldTopic]]
</noautolink>
THIS
}

# Rename OldTopic to a different web no change access on target web
sub test_renameTopic_new_web_same_topic_name_no_access {
    my $this  = shift;

    my $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Targetweb" );
    $m->populateNewWeb();
    $this->assert( Foswiki::Func::webExists("$this->{test_web}/Targetweb") );

    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Targetweb",
        'WebPreferences' );
    $m->text("   * Set ALLOWWEBCHANGE = NotMe\n   * Set ALLOWWEBVIEW = \n");
    $m->save();

    my $query = new Unit::Request(
        {
            action           => ['rename'],
            newweb           => ["$this->{test_web}/Targetweb" ],
            newtopic         => ['OldTopic'],
            topic => 'OldTopic'
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};

    try {
        my ($text) =
          $this->captureWithKey( rename => $UI_FN, $this->{session} );
        $this->assert( 0, $text );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_equals( 'OldTopic',                    $e->{topic} );
        $this->assert_equals( 'CHANGE',                      $e->{mode} );
        $this->assert_equals( 'access not allowed on web',   $e->{reason} );
    }
    otherwise {
        $this->assert( 0, shift );
    };

    $this->assert( $this->{session}->topicExists( "$this->{test_web}", 'OldTopic' ) );
    $this->assert( !$this->{session}->topicExists( "$this->{test_web}/Targetweb", 'OldTopic' ) );

}

# Rename non-wikiword OldTopic to NewTopic within the same web
sub test_renameTopic_nonWikiWord_same_web_new_topic_name {
    my $this = shift;

    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'OldTopic' );
    $meta->put( "TOPICPARENT", { name => 'Tmp1' } );
    $meta->save();

    $this->checkReferringTopics( $this->{test_web}, 'Tmp1', 0,
        [ "$this->{test_web}.OldTopic", ] );

    my $query = new Unit::Request(
        {
            action           => ['rename'],
            newweb           => [ $this->{test_web} ],
            newtopic         => ['Tmp2'],
            nonwikiword      => '1',
            referring_topics => [ "$this->{test_web}.OldTopic", ],
            topic            => 'Tmp1'
        }
    );

    $this->{session}->finish();

    # The topic in the path should not matter
    $query->path_info("/$this->{test_web}/SanityCheck");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};

    #print STDERR "Doing Rename\n";
    my ( $stdout, $stderr, $result ) =
      $this->captureWithKey( rename => $UI_FN, $this->{session} );

#print STDERR "Rename STDOUT = ($this->{stdout})\n STDERR = ($this->{stderr})\n RESULT = ($result)\n" ;

    $this->assert( $this->{session}->topicExists( $this->{test_web}, 'Tmp2' ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, 'Tmp1' ) );

    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'OldTopic' );

    $this->assert_str_equals( 'Tmp2', $meta->getParent() );
}

# Purpose:  Rename a topic which starts with a lowercase letter
# Verifies:
#    * Return status is a redirect
#    * New script is view, not oops
#    * New topic name is changed
#    * In the new topic, the initial letter is changed to upper case
sub test_renameTopic_with_lowercase_first_letter {
    my $this = shift;

    if ( $^O eq 'MSWin32' ) {
        $this->expect_failure();
        $this->annotate(
"this test fails on a non-case sensitive filesystem - OSX default, Windows.."
        );
    }

    my $topictext = <<THIS;
One lowercase
Twolowercase
[[lowercase]]
THIS
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'lowercase',
        $topictext );
    $topicObject->save();
    my $query = new Unit::Request(
        {
            action           => 'rename',
            topic            => 'lowercase',
            newweb           => $this->{test_web},
            newtopic         => 'upperCase',
            referring_topics => ["$this->{test_web}.NewTopic"],
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    my $ext = $Foswiki::cfg{ScriptSuffix};
    $this->assert_matches( qr/^Status:\s+302/s, $text );

    my $ss = '/view' . $Foswiki::cfg{ScriptSuffix} . '/';
    $ss = $Foswiki::cfg{ScriptUrlPaths}{view} . '/'
      if ( defined $Foswiki::cfg{ScriptUrlPaths}{view} );
    $this->assert_matches( qr([lL]ocation:\s+$ss$this->{test_web}/UpperCase)s,
        $text );
    $this->check( $this->{test_web}, 'UpperCase', $topicObject, <<THIS, 100 );
One lowercase
Twolowercase
[[UpperCase]]
THIS
}

sub test_renameTopic_TOPICRENAME_access_denied {
    my $this      = shift;
    my $topictext = "   * Set ALLOWTOPICRENAME = GungaDin\n";
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OldTopic',
        $topictext );
    $topicObject->save();
    my $query = new Unit::Request(
        {
            action   => 'rename',
            topic    => 'OldTopic',
            newweb   => $this->{test_web},
            newtopic => 'NewTopic',
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    try {
        no strict 'refs';
        my ( $text, $result ) = &$UI_FN( $this->{session} );
        use strict 'refs';
        $this->assert(0);
    }
    catch Foswiki::AccessControlException with {
        $this->assert_str_equals(
            'AccessControlException: Access to RENAME '
              . $this->{test_web}
              . '.OldTopic for scum is denied. access not allowed on topic',
            shift->stringify()
        );
    }
}

sub test_renameTopic_WEBRENAME_access_denied {
    my $this      = shift;
    my $topictext = "   * Set ALLOWWEBRENAME = GungaDin\n";
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, $topictext );
    $topicObject->save();
    my $query = new Unit::Request(
        {
            action   => 'rename',
            topic    => 'OldTopic',
            newweb   => $this->{test_web},
            newtopic => 'NewTopic',
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    try {
        no strict 'refs';
        my ( $text, $result ) = &$UI_FN( $this->{session} );
        use strict 'refs';
        $this->assert(0);
    }
    catch Foswiki::AccessControlException with {
        $this->assert_str_equals(
            'AccessControlException: Access to RENAME '
              . $this->{test_web}
              . '.OldTopic for scum is denied. access not allowed on web',
            shift->stringify()
        );
    }
}

# Test rename does not corrupt history, see Foswikibug:2299
sub test_renameTopic_preserves_history {
    my $this      = shift;
    my $topicName = 'RenameWithHistory';
    my $time      = time();
    my @history   = qw( First Second Third );

    for my $depth ( 0 .. $#history ) {
        my $topicObject = Foswiki::Meta->new(
            $this->{session}, $this->{test_web},
            $topicName,       $history[$depth]
        );
        $topicObject->save( forcenewrevision => 1 );
        $topicObject->finish();
    }
    my $query = new Unit::Request(
        {
            action   => 'rename',
            topic    => $topicName,
            newweb   => $this->{test_web},
            newtopic => $topicName . 'Renamed',
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->captureWithKey( rename => $UI_FN, $this->{session} );
    my $m =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        $topicName . 'Renamed' );
    $this->assert_equals( $history[$#history], $m->text );
    my $info = $m->getRevisionInfo();
    $this->assert_equals( $#history + 1, $info->{version} )
      ;    # rename adds a revision

}

# Purpose: verify that leases are removed when a topic is renamed
sub test_renameTopic_ensure_leases_are_released {
    my $this = shift;

    # Grab a lease
    my $m =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OldTopic' );
    $m->setLease(1000);

    my $query = new Unit::Request(
        {
            action   => 'rename',
            topic    => 'OldTopic',
            newweb   => $this->{test_web},
            newtopic => 'NewTopic',
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $m = Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OldTopic' );
    my $lease = $m->getLease();
    $this->assert_null( $lease, $lease );
}

sub test_makeSafeTopicName {
    my $this = shift;

    {
        my $result   = Foswiki::UI::Rename::_safeTopicName('Abc/Def');
        my $expected = 'Abc_Def';
        print("result=$result.\n")     if $debug;
        print("expected=$expected.\n") if $debug;
        $this->assert( $result eq $expected );
    }
    {
        my $result   = Foswiki::UI::Rename::_safeTopicName('Abc.Def');
        my $expected = 'Abc_Def';
        print("result=$result.\n")     if $debug;
        print("expected=$expected.\n") if $debug;
        $this->assert( $result eq $expected );
    }
    {
        my $result   = Foswiki::UI::Rename::_safeTopicName('Abc Def');
        my $expected = 'AbcDef';
        print("result=$result.\n")     if $debug;
        print("expected=$expected.\n") if $debug;
        $this->assert( $result eq $expected );
    }
}

# Move a subweb, ensuring that static links to that subweb are re-pointed
sub test_renameWeb_1307a {
    my $this = shift;
    my $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Renamedweb" );
    $m->populateNewWeb();
    $m =
      Foswiki::Meta->new( $this->{session},
        "$this->{test_web}/Renamedweb/Subweb" );
    $m->populateNewWeb();
    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Notrenamedweb" );
    $m->populateNewWeb();
    my $vue =
"$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";
    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Notrenamedweb",
        'ReferringTopic', <<CONTENT );
$this->{test_web}.Renamedweb.Subweb
$this->{test_web}/Renamedweb/Subweb
$this->{test_web}.Notrenamedweb.Subweb
$this->{test_web}/Notrenamedweb/Subweb
$vue/$this->{test_web}/Renamedweb/WebHome
$vue/$this->{test_web}/Renamedweb/SubwebWebHome
<noautolink>
$this->{test_web}.Renamedweb.Subweb
[[$this->{test_web}.Renamedweb.Subweb]]
</noautolink>
CONTENT
    $m->save();

    my $query = new Unit::Request(
        {
            action           => 'renameweb',
            newparentweb     => "$this->{test_web}/Notrenamedweb",
            newsubweb        => "Renamedweb",
            referring_topics => [ $m->getPath() ],
        }
    );
    $query->path_info("/$this->{test_web}/Renamedweb/WebHome");

    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert(
        Foswiki::Func::webExists("$this->{test_web}/Notrenamedweb/Renamedweb")
    );
    $this->assert( !Foswiki::Func::webExists("$this->{test_web}/Renamedweb") );
    $m =
      Foswiki::Meta->load( $this->{session}, "$this->{test_web}/Notrenamedweb",
        'ReferringTopic' );
    my @lines = split( /\n/, $m->text() );
    $this->assert_str_equals(
        "$this->{test_web}/Notrenamedweb/Renamedweb.Subweb",
        $lines[0] );
    $this->assert_str_equals(
        "$this->{test_web}/Notrenamedweb/Renamedweb/Subweb",
        $lines[1] );
    $this->assert_str_equals( "$this->{test_web}.Notrenamedweb.Subweb",
        $lines[2] );
    $this->assert_str_equals( "$this->{test_web}/Notrenamedweb/Subweb",
        $lines[3] );
    $this->assert_str_equals(
        "$vue/$this->{test_web}/Notrenamedweb/Renamedweb/WebHome",
        $lines[4] );
    $this->assert_str_equals(
        "$vue/$this->{test_web}/Notrenamedweb/Renamedweb/SubwebWebHome",
        $lines[5] );
    $this->assert_str_equals( "$this->{test_web}.Renamedweb.Subweb",
        $lines[7] );
    $this->assert_str_equals(
        "[[$this->{test_web}/Notrenamedweb/Renamedweb.Subweb]]",
        $lines[8] );
}

# Move a root web, ensuring that static links are re-pointed
sub test_renameWeb_1307b {
    my $this = shift;
    my $m = Foswiki::Meta->new( $this->{session}, "Renamed$this->{test_web}" );
    $m->populateNewWeb();
    $m =
      Foswiki::Meta->new( $this->{session}, "Renamed$this->{test_web}/Subweb" );
    $m->populateNewWeb();
    $m = Foswiki::Meta->new( $this->{session}, "$this->{test_web}" );
    $m->populateNewWeb();
    my $vue =
"$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";
    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}",
        'ReferringTopic', <<CONTENT );
Renamed$this->{test_web}.Subweb
Renamed$this->{test_web}/Subweb
$this->{test_web}.Subweb
$this->{test_web}/Subweb
$vue/Renamed$this->{test_web}/WebHome
$vue/Renamed$this->{test_web}/SubwebWebHome
<noautolink>
Renamed$this->{test_web}.Subweb
[[Renamed$this->{test_web}.Subweb]]
</noautolink>
CONTENT
    $m->save();

    # need rename access on the root for this one, which is a bit of a
    # faff to set up, so we'll cheat a bit and add the user to the admin
    # group. Fortunately we have a private users web.
    my $grope =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        $Foswiki::cfg{SuperAdminGroup}, <<EOF);
   * Set GROUP = $this->{test_user_wikiname}
EOF
    $grope->save();

    my $query = new Unit::Request(
        {
            action           => 'renameweb',
            newparentweb     => $this->{test_web},
            newsubweb        => "Renamed$this->{test_web}",
            referring_topics => [ $m->getPath() ],
        }
    );
    $query->path_info("/Renamed$this->{test_web}/WebHome");

    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert(
        Foswiki::Func::webExists("$this->{test_web}/Renamed$this->{test_web}")
    );
    $this->assert( !Foswiki::Func::webExists("Renamed$this->{test_web}") );
    $m =
      Foswiki::Meta->load( $this->{session}, "$this->{test_web}",
        'ReferringTopic' );
    my @lines = split( /\n/, $m->text() );
    $this->assert_str_equals(
        "$this->{test_web}/Renamed$this->{test_web}.Subweb",
        $lines[0] );
    $this->assert_str_equals(
        "$this->{test_web}/Renamed$this->{test_web}/Subweb",
        $lines[1] );
    $this->assert_str_equals( "$this->{test_web}.Subweb", $lines[2] );
    $this->assert_str_equals( "$this->{test_web}/Subweb", $lines[3] );
    $this->assert_str_equals(
        "$vue/$this->{test_web}/Renamed$this->{test_web}/WebHome",
        $lines[4] );
    $this->assert_str_equals(
        "$vue/$this->{test_web}/Renamed$this->{test_web}/SubwebWebHome",
        $lines[5] );
    $this->assert_str_equals( "Renamed$this->{test_web}.Subweb", $lines[7] );
    $this->assert_str_equals(
        "[[$this->{test_web}/Renamed$this->{test_web}.Subweb]]",
        $lines[8] );
}

# Move a root web, ensuring that topics containing web in topic name are not updated.
sub test_renameWeb_10259 {
    my $this = shift;
    my $m = Foswiki::Meta->new( $this->{session}, "$this->{test_web}EdNet" );
    $m->populateNewWeb();

    my $vue =
"$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";

    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}EdNet",
        'ReferringTopic', <<CONTENT );
Otherweb.$this->{test_web}EdNetSomeTopic
$this->{test_web}EdNet.SomeTopic
$this->{test_web}EdNetTwo.SomeTopic
$this->{test_web}EdNet.SubWeb.SomeTopic
$this->{test_web}EdNet/SubWeb.SomeTopic
$this->{test_web}EdNet/EdNetSubWeb.EdNetSomeTopic
"$this->{test_web}EdNet.SomeTopic"
"$this->{test_web}EdNet.SomeTopic, Otherweb.$this->{test_web}EdNetSomeTopic"
CONTENT
    $m->save();

    # need rename access on the root for this one, which is a bit of a
    # faff to set up, so we'll cheat a bit and add the user to the admin
    # group. Fortunately we have a private users web.
    my $grope =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        $Foswiki::cfg{SuperAdminGroup}, <<EOF);
   * Set GROUP = $this->{test_user_wikiname}
EOF
    $grope->save();

    my $query = new Unit::Request(
        {
            action           => 'renameweb',
            newsubweb        => "$this->{test_web}RenamedEdNet",
            referring_topics => [ $m->getPath() ],
        }
    );
    $query->path_info("/$this->{test_web}EdNet/WebHome");

    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert( Foswiki::Func::webExists("$this->{test_web}RenamedEdNet") );
    $this->assert( !Foswiki::Func::webExists("$this->{test_web}EdNet") );
    $this->assert( Foswiki::Func::webExists("$this->{test_web}RenamedEdNet") );

    $m = Foswiki::Meta->load( $this->{session}, "$this->{test_web}RenamedEdNet",
        'ReferringTopic' );
    my @lines = split( /\n/, $m->text() );

    #foreach my $ln ( @lines ) {
    #    print "LINE ($ln)\n";
    #    }

# But a topic that contains the webname inside the topic name should not be modified.
    $this->assert_str_equals( "Otherweb.$this->{test_web}EdNetSomeTopic",
        $lines[0], "A topic containing the web name should not be renamed" );

    # A topic referencing the old web should be renamed
    $this->assert_str_equals( "$this->{test_web}RenamedEdNet.SomeTopic",
        $lines[1] );

    # A topic referencing a similar old web should not be renamed
    $this->assert_str_equals( "$this->{test_web}EdNetTwo.SomeTopic",
        $lines[2],
        "A webname containing the renamed webname should not be renamed." );

    # A subweb topic referencing the old web should be renamed
    $this->assert_str_equals( "$this->{test_web}RenamedEdNet.SubWeb.SomeTopic",
        $lines[3] );

    # A subweb topic referencing the old web should be renamed
    $this->assert_str_equals( "$this->{test_web}RenamedEdNet/SubWeb.SomeTopic",
        $lines[4] );

    # A subweb topic referencing the old web should be renamed
    $this->assert_str_equals(
        "$this->{test_web}RenamedEdNet/EdNetSubWeb.EdNetSomeTopic",
        $lines[5] );

    # A quoted topic referencing the old web should be renamed
    $this->assert_str_equals( "\"$this->{test_web}RenamedEdNet.SomeTopic\"",
        $lines[6] );

    # A quoted topic referencing the old web should be renamed
    $this->assert_str_equals(
"\"$this->{test_web}RenamedEdNet.SomeTopic, Otherweb.$this->{test_web}EdNetSomeTopic\"",
        $lines[7]
    );

}

# Move a sub web, ensuring that topics containing web in topic name are not updated.
sub test_renameSubWeb_10259 {
    my $this = shift;
    my $m = Foswiki::Meta->new( $this->{session}, "$this->{test_web}Root" );
    $m->populateNewWeb();

    $m = Foswiki::Meta->new( $this->{session}, "$this->{test_web}Root/EdNet" );
    $m->populateNewWeb();

    my $vue =
"$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";

    $m =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}Root/EdNet",
        'ReferringTopic', <<CONTENT );
Otherweb.$this->{test_web}EdNetSomeTopic
$this->{test_web}Root/EdNet.SomeTopic
$this->{test_web}Root/EdNetTwo.SomeTopic
$this->{test_web}Root/EdNet.SubWeb.SomeTopic
$this->{test_web}Root/EdNet/SubWeb.SomeTopic
$this->{test_web}Root/EdNet/EdNetSubWeb.EdNetSomeTopic
"$this->{test_web}Root/EdNet.SomeTopic"
"$this->{test_web}Root/EdNet.SomeTopic, Otherweb.$this->{test_web}EdNetSomeTopic"
CONTENT
    $m->save();

    # need rename access on the root for this one, which is a bit of a
    # faff to set up, so we'll cheat a bit and add the user to the admin
    # group. Fortunately we have a private users web.
    my $grope =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        $Foswiki::cfg{SuperAdminGroup}, <<EOF);
   * Set GROUP = $this->{test_user_wikiname}
EOF
    $grope->save();

    my $query = new Unit::Request(
        {
            action           => 'renameweb',
            newsubweb        => "$this->{test_web}Root/NewEdNet",
            referring_topics => [ $m->getPath() ],
        }
    );
    $query->path_info("/$this->{test_web}Root/EdNet/WebHome");

    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert( Foswiki::Func::webExists("$this->{test_web}Root/NewEdNet") );
    $this->assert( !Foswiki::Func::webExists("$this->{test_web}EdNet") );
    $this->assert( Foswiki::Func::webExists("$this->{test_web}Root/NewEdNet") );

    $m =
      Foswiki::Meta->load( $this->{session}, "$this->{test_web}Root/NewEdNet",
        'ReferringTopic' );
    my @lines = split( /\n/, $m->text() );

    #foreach my $ln ( @lines ) {
    #    print "LINE ($ln)\n";
    #    }

# But a topic that contains the webname inside the topic name should not be modified.
    $this->assert_str_equals( "Otherweb.$this->{test_web}EdNetSomeTopic",
        $lines[0], "A topic containing the web name should not be renamed" );

    # A topic referencing the old web should be renamed
    $this->assert_str_equals( "$this->{test_web}Root/NewEdNet.SomeTopic",
        $lines[1] );

    # A topic referencing a similar old web should not be renamed
    $this->assert_str_equals( "$this->{test_web}Root/EdNetTwo.SomeTopic",
        $lines[2],
        "A webname containing the renamed webname should not be renamed." );

    # A subweb topic referencing the old web should be renamed
    $this->assert_str_equals( "$this->{test_web}Root/NewEdNet.SubWeb.SomeTopic",
        $lines[3] );

    # A subweb topic referencing the old web should be renamed
    $this->assert_str_equals( "$this->{test_web}Root/NewEdNet/SubWeb.SomeTopic",
        $lines[4] );

    # A subweb topic referencing the old web should be renamed
    $this->assert_str_equals(
        "$this->{test_web}Root/NewEdNet/EdNetSubWeb.EdNetSomeTopic",
        $lines[5] );

    # A quoted topic referencing the old web should be renamed
    $this->assert_str_equals( "\"$this->{test_web}Root/NewEdNet.SomeTopic\"",
        $lines[6] );

    # A quoted topic referencing the old web should be renamed
    $this->assert_str_equals(
"\"$this->{test_web}Root/NewEdNet.SomeTopic, Otherweb.$this->{test_web}EdNetSomeTopic\"",
        $lines[7]
    );

}

sub test_rename_attachment {
    my $this = shift;

    my $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web}, 'NewTopic' );
    $to->text('Wibble');
    $to->save();

    # returns undef on OSX with 3.15 version of CGI module (works on 3.42)
    my $stream = new File::Temp( UNLINK => 0 );
    print $stream "Blah Blah";
    $stream->close();
    $stream->unlink_on_destroy(1);

    $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $to->attach( name => 'dis.dat', file => $stream->filename );

    $this->{session}->finish();

    my $query = new Unit::Request(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
        }
    );

    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert_matches( qr/Status: 302/,                 $text );
    $this->assert_matches( qr#/$this->{test_web}/NewTopic#, $text );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, 'dis.dat'
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, 'NewTopic', 'dis.dat'
        )
    );
}

# Item5464 - Rename of attachment requires change access, not rename access
sub test_rename_attachment_Rename_Denied_Change_Allowed {
    my $this = shift;

    my $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web}, 'NewTopic' );
    $to->text("Wibble\n   * Set ALLOWTOPICRENAME = NotMe\n");
    $to->save();

    # returns undef on OSX with 3.15 version of CGI module (works on 3.42)
    my $stream = new File::Temp( UNLINK => 0 );
    print $stream "Blah Blah";
    $stream->close();
    $stream->unlink_on_destroy(1);

    $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $to->attach( name => 'dis.dat', file => $stream->filename );

    $this->{session}->finish();

    my $query = new Unit::Request(
        {
            attachment    => ['dis.dat'],
            newattachment => ['doh.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
        }
    );

    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert_matches( qr/Status: 302/,                 $text );
    $this->assert_matches( qr#/$this->{test_web}/NewTopic#, $text );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, 'dis.dat'
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, 'NewTopic', 'doh.dat'
        )
    );
}

# Item5464 - Rename of attachment requires change access, not rename access
sub test_rename_attachment_Rename_Allowed_Change_Denied {
    my $this = shift;

    my $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web}, 'NewTopic' );
    $to->text("Wibble\n   * Set ALLOWTOPICCHANGE = NotMe\n");
    $to->save();

    # returns undef on OSX with 3.15 version of CGI module (works on 3.42)
    my $stream = new File::Temp( UNLINK => 0 );
    print $stream "Blah Blah";
    $stream->close();
    $stream->unlink_on_destroy(1);

    $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $to->attach( name => 'dis.dat', file => $stream->filename );

    $this->{session}->finish();

    my $query = new Unit::Request(
        {
            attachment    => ['dis.dat'],
            newattachment => ['doh.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
        }
    );

    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    try {
        my ($text) =
          $this->captureWithKey( rename => $UI_FN, $this->{session} );
        $this->assert( 0, $text );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_equals( 'NewTopic',                    $e->{topic} );
        $this->assert_equals( 'CHANGE',                      $e->{mode} );
        $this->assert_equals( 'access not allowed on topic', $e->{reason} );
    }
    otherwise {
        $this->assert( 0, shift );
    };

    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, 'dis.dat'
        )
    );
}

sub test_rename_attachment_not_in_meta {
    my $this = shift;

    my $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web}, 'NewTopic' );
    $to->text('Wibble');
    $to->save();

    $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    my $fh = $to->openAttachment( 'dis.dat', '>' );
    print $fh "Oh no not again";
    close($fh);

    $this->{session}->finish();

    my $query = new Unit::Request(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
        }
    );

    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert_matches( qr/Status: 302/,                 $text );
    $this->assert_matches( qr#/$this->{test_web}/NewTopic#, $text );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, 'dis.dat'
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, 'NewTopic', 'dis.dat'
        )
    );
}

sub test_rename_attachment_no_dest_topic {
    my $this = shift;

    my $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    my $fh = $to->openAttachment( 'dis.dat', '>' );
    print $fh "Oh no not again";
    close($fh);

    $this->{session}->finish();

    my $query = new Unit::Request(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
        }
    );

    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    try {
        my ($text) =
          $this->captureWithKey( rename => $UI_FN, $this->{session} );
        $this->assert( 0, $text );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_equals( 'no_such_topic', $e->{def} );
        $this->assert_equals( 'NewTopic',      $e->{topic} );
    }
    otherwise {
        $this->assert( 0, shift );
    };
}

# Check that an attachment in meta-data but not on the disc can be renamed
# Test disabled by CDot because of Item9352
sub do_not_test_rename_attachment_not_on_disc {
    my $this = shift;

    my $stream = new File::Temp( UNLINK => 0 );
    print $stream "Blah Blah";
    $stream->close();
    $stream->unlink_on_destroy(1);

    my $to =
      new Foswiki::Meta( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $to->attach( name => 'dis.dat', file => $stream->filename );

    unless (
        -e "$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/dis.dat"
      )
    {
        $this->expect_failure();
        $this->annotate("Attachment not on disc");
        $this->assert(0);
    }

    unlink(
        "$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/dis.dat");

    $to = new Foswiki::Meta( $this->{session}, $this->{test_web}, 'NewTopic' );
    $to->text('Wibble');
    $to->save();

    $this->{session}->finish();

    my $query = new Unit::Request(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
        }
    );

    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert_matches( qr/Status: 302/,                 $text );
    $this->assert_matches( qr#/$this->{test_web}/NewTopic#, $text );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, 'dis.dat'
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, 'NewTopic', 'dis.dat'
        )
    );
}

1;
