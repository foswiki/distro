package RenameTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::UI::Rename();
use Error ':try';
use File::Temp();

my $notawwtopic1 = "random";
my $notawwtopic2 = "Random";
my $notawwtopic3 = "ranDom";
my $debug        = 0;
my $UI_FN;

sub _reset_session_with_cuid {
    my ( $this, $query_opts, $cuid ) = @_;
    my $query = Unit::Request->new($query_opts);

    $query->path_info( $query_opts->{path_info} ) if $query_opts->{path_info};
    $cuid ||= $this->{test_user_login};
    $this->createNewFoswikiSession( $cuid, $query );

    return;
}

sub _reset_session {
    my ( $this, $query_opts ) = @_;

    return $this->_reset_session_with_cuid($query_opts);
}

# Set up the test fixture. The idea behind the tests is to populate a
# set of strategically-selected topics with text that contains all the
# relevant reference syntaxes. Then after each different type of rename,
# we can check that those references have been redirected appropriately.
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $UI_FN ||= $this->getUIFn('rename');

    $this->{new_web} = $this->{test_web} . 'New';

    # Need priveleged user to create root webs with Foswiki::Func.
    $this->_reset_session_with_cuid( { topic => "/$this->{test_web}/OldTopic" },
        $Foswiki::cfg{AdminUserLogin} );
    Foswiki::Func::createWeb( $this->{new_web} );

    # Topic text that contains all the different kinds of topic reference
    my $originaltext = <<"THIS";
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
28 OldTopic#anchor
29 $this->{test_web}.OldTopic#anchor
30 [[$this->{test_web}.OldTopic#anchor]]
31 [[OldTopic#anchor]]
32 http://site/$this->{test_web}/OldTopic#anchor
33 https://site/$this->{test_web}/OldTopic#anchor
34 OldTopic#OldTopic
35 [[OldTopic#OldTopic]]
36 [[$this->{test_web}.OldTopic][Old Topic Text]]
37 [[$this->{test_web}/OldTopic][Old Topic Text]]
THIS

    # Strategically-selected set of identical topics in the test web
    foreach my $topic ( 'OldTopic', 'OtherTopic', 'random', 'Random', 'ranDom',
        'Tmp1' )
    {
        my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
        $meta->text($originaltext);
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
            Foswiki::Func::topicExists( $this->{test_web}, $topic ) );
    }

    # Topic in the new web
    my ($meta) = Foswiki::Func::readTopic( $this->{new_web}, 'OtherTopic' );
    $meta->text($originaltext);
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
    $meta->finish();

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{new_web},
        $Foswiki::cfg{HomeTopicName} );
    $topicObject->text('junk');
    $topicObject->save();
    $topicObject->finish();

    # Topic text for template rename tests that contains all references.
    my $origTemplateRefs = <<"THIS";
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

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'TmplRefTopic' );
    $meta->text($origTemplateRefs);
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
    $meta->finish();
    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, 'TmplRefTopic' ) );

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'TmplRefTopic2' );
    $meta->text($origTemplateRefs);
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
    $meta->finish();

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'TmplRefMeta1' );
    $meta->text("Meta Only");
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
    $meta->finish();

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'TmplRefMeta2' );
    $meta->text("Meta Only");
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
    $meta->finish();

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'TmplRefMeta3' );
    $meta->text("Meta Only");
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
    $meta->finish();

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'OldViewTemplate' );
    $meta->text("Template");
    $meta->save();
    $this->_reset_session( { topic => "/$this->{test_web}/OldTopic" } );

    return;
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture( $this->{session}, $this->{new_web} );
    $this->removeWebFixture( $this->{session}, "Renamedweb$this->{test_web}" )
      if ( Foswiki::Func::webExists("Renamedweb$this->{test_web}") );
    $this->removeWebFixture( $this->{session}, "$this->{test_web}EdNet" )
      if ( Foswiki::Func::webExists("$this->{test_web}EdNet") );
    $this->removeWebFixture( $this->{session}, "$this->{test_web}RenamedEdNet" )
      if ( Foswiki::Func::webExists("$this->{test_web}RenamedEdNet") );
    $this->removeWebFixture( $this->{session}, "$this->{test_web}Root" )
      if ( Foswiki::Func::webExists("$this->{test_web}Root") );
    $this->SUPER::tear_down();

    return;
}

sub check {
    my ( $this, $web, $topic, $emeta, $expected, $num ) = @_;
    my ( $meta, $actual ) = Foswiki::Func::readTopic( $web, $topic );
    my @old = split( /\n+/, $expected );
    my @new = split( /\n+/, $actual );

    $meta->finish();
    while ( scalar(@old) ) {
        my $o = "$num: " . shift(@old);
        my $n = "$num: " . shift(@new);
        $this->assert_str_equals( $o, $n,
            "Expect $o\nActual $n\n" . join( ",", caller ) );
    }

    return;
}

# Check the results of _getReferringTopics. $all means all webs. $expected
# is an array of topic names that should be seen. $forgiving means that
# the actual set may contain other topics besides those expected.
sub checkReferringTopics {
    my ( $this, $web, $topic, $all, $expected, $forgiving ) = @_;

    my ($m) = Foswiki::Func::readTopic( $web, $topic );
    my $refs =
      Foswiki::UI::Rename::_getReferringTopics( $this->{session}, $m, $all );
    $m->finish();

    $this->assert_str_equals( 'HASH', ref($refs) );
    if ($forgiving) {
        foreach my $k ( keys %{$refs} ) {
            unless ( $k =~ /^$this->{test_web}/ ) {
                delete( $refs->{$k} );
            }
        }
    }

    # Check that all expected topics were seen
    my %expected_but_unseen;
    my %e = map { $_ => 1 } @{$expected};
    foreach my $r ( keys %e ) {
        unless ( $refs->{$r} ) {
            $expected_but_unseen{$r} = 1;
        }
    }

    # Check that no unexpected topics were seen
    my %not_expected;
    foreach my $r ( keys %{$refs} ) {
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

    my $i = scalar( keys %{$refs} );
    my @e = sort @{$expected};
    my $j = scalar(@e);
    my @r = sort keys %{$refs};
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

    return;
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

    return;
}

# Test referemces to a template topic
sub test_renameTemplateThisWeb {
    my $this = shift;

    $this->_reset_session(
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
            topic => 'OldViewTemplate',

            # The topic in the path should not matter
            path_info => "/$this->{test_web}/SanityCheck"
        }
    );

    $this->captureWithKey( rename => $UI_FN, $this->{session} );

    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, 'NewViewTemplate' ) );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, 'OldViewTemplate' ) );

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
        ["$this->{test_web}.NewViewTemplate"] );

    my ($m) = Foswiki::Func::readTopic( $this->{test_web}, 'TmplRefTopic' );
    my @lines = split( /\n/, $m->text() );
    $m->finish();
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

    return;
}

# Test references to a topic in this web
sub test_referringTopicsThisWeb {
    my $this = shift;
    my $ott  = 'Old Topic';
    my $lott = lc($ott);
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeOne' );
    $topicObject->text( <<"THIS" );
[[$ott]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeTwo' );
    $topicObject->text( <<"THIS" );
[[$lott]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{new_web}, 'MatchMeThree' );
    $topicObject->text( <<"THIS" );
[[$this->{test_web}.$ott]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{new_web}, 'MatchMeFour' );
    $topicObject->text(<<"THIS" );
[[$this->{test_web}.$lott]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NoMatch' );
    $topicObject->text(<<"THIS" );
Refer to $ott and $lott
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{new_web}, 'NoMatch' );
    $topicObject->text(<<"THIS" );
Refer to $ott and $lott
THIS
    $topicObject->save();
    $topicObject->finish();

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

    return;
}

# Test references to a topic in all webs
# Warning; this is a bit of a lottery, as you might have webs that refer
# to the topic outside the test set. For this reason the test is forgiving
# if a ref outside of the test webs is found.
sub test_renameTopic_find_referring_topics_in_all_webs {
    my $this = shift;
    my $ott  = 'Old Topic';
    my $lott = lc($ott);
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeOne' );
    $topicObject->text( <<"THIS" );
[[$ott]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeTwo' );
    $topicObject->text( <<"THIS" );
[[$lott]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{new_web}, 'MatchMeThree' );
    $topicObject->text( <<"THIS" );
[[$this->{test_web}.$ott]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{new_web}, 'MatchMeFour' );
    $topicObject->text( <<"THIS" );
[[$this->{test_web}.$lott]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NoMatch' );
    $topicObject->text( <<"THIS" );
Refer to $ott and $lott
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{new_web}, 'NoMatch' );
    $topicObject->text(<<"THIS" );
Refer to $ott and $lott
THIS
    $topicObject->save();
    $topicObject->finish();

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

    return;
}

# Test references to a topic in this web, where the topic is not a wikiword
sub test_renameTopic_find_referring_topics_when_renamed_topic_is_not_a_WikiWord
{
    my $this = shift;
    my $ott  = 'ranDom';
    my $lott = lc($ott);
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeOne' );
    $topicObject->text( <<'THIS' );
random random random
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeTwo' );
    $topicObject->text( <<'THIS' );
ranDom ranDom ranDom
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeThree' );
    $topicObject->text( <<'THIS' );
Random Random Random
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeFour' );
    $topicObject->text( <<'THIS' );
RanDom RanDom RanDom
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeFive' );
    $topicObject->text( <<'THIS' );
[[random]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeSix' );
    $topicObject->text( <<'THIS' );
[[ranDom]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeSeven' );
    $topicObject->text( <<'THIS' );
[[Random]]
THIS
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'MatchMeEight' );
    $topicObject->text( <<'THIS' );
[[RanDom]]
THIS
    $topicObject->save();
    $topicObject->finish();

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

    return;
}

# There's a reference in a topic in a web which doesn't allow
# read access for the current user [[Foswiki:Tasks.Item1879]]
sub test_rename_topic_reference_in_denied_web {
    my $this = shift;

    # Make sure the reference can't exist outside the text fixture
    my $fnord = "FnordMustNotBeFound" . time;

    # Create the referred-to topic that we're renaming
    my ($m) = Foswiki::Func::readTopic( $this->{test_web}, $fnord );
    $m->text("");
    $m->save();
    $m->finish();

    # Create a subweb
    Foswiki::Func::createWeb("$this->{test_web}/Swamp");

    # Create a topic in the subweb that refers to the topic we're renaming
    ($m) = Foswiki::Func::readTopic( "$this->{test_web}/Swamp", 'TopSecret' );
    $m->text("[[$this->{test_web}.$fnord]]");
    $m->save();
    $m->finish();

    # Make sure the subweb is unprotected (readable)
    ($m) =
      Foswiki::Func::readTopic( "$this->{test_web}/Swamp", 'WebPreferences' );
    $m->text("   * Set ALLOWWEBCHANGE = \n   * Set ALLOWWEBVIEW = \n");
    $m->save();
    $m->finish();

    # Have to restart to clear prefs cache
    $this->_reset_session();

    $this->checkReferringTopics( $this->{test_web}, $fnord, 1,
        ["$this->{test_web}/Swamp.TopSecret"] );

    # Protect the web we made (deny view access)
    ($m) =
      Foswiki::Func::readTopic( "$this->{test_web}/Swamp", 'WebPreferences' );
    $m->text("   * Set ALLOWWEBVIEW = PickMeOhPickMe");
    $m->save();
    $m->finish();

    # Have to restart to clear prefs cache
    $this->_reset_session();

    $this->checkReferringTopics(
        $this->{test_web},
        $fnord, 1,
        [

            # Should be empty
        ]
    );

    # Protect the web we made (deny change access)
    # We need to be able to see these references.
    ($m) =
      Foswiki::Func::readTopic( "$this->{test_web}/Swamp", 'WebPreferences' );
    $m->text("   * Set ALLOWWEBCHANGE = PickMeOhPickMe");
    $m->save();
    $m->finish();

    # Have to restart to clear prefs cache
    $this->_reset_session();

    $this->checkReferringTopics( $this->{test_web}, $fnord, 1,
        ["$this->{test_web}/Swamp.TopSecret"] );

    return;
}

# Rename OldTopic to NewTopic within the same web
sub test_renameTopic_same_web_new_topic_name {
    my $this = shift;

    $this->_reset_session(
        {
            action           => ['rename'],
            newweb           => [ $this->{test_web} ],
            newtopic         => ['NewTopic'],
            referring_topics => [
                "$this->{test_web}.NewTopic", "$this->{test_web}.OtherTopic",
                "$this->{new_web}.OtherTopic"
            ],
            topic => 'OldTopic',

            # The topic in the path should not matter
            path_info => "/$this->{test_web}/SanityCheck"
        }
    );

    my ( $responseText, $result, $stdout, $stderr ) =
      $this->captureWithKey( rename => $UI_FN, $this->{session} );

    # Uncomment to get output from rename command
    #print STDERR $responseText . $result . $stdout . $stderr . "\n";

    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, 'NewTopic' ) );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, 'OldTopic' ) );

# Verify NewTopic references in test_web.NewTopic are updated
#
# SMELL: Line 24 - a quoted topic name - should probably not be renamed.  But it is
# important to handle topic names referenced inside %MACRO{ statements.  It was decided
# that it is more important to rename those quoted topics than to be 100% correct
# and renaming only references that result in a link, and missing the references used on
# line 22 and 23.
    #
    $this->check( $this->{test_web}, 'NewTopic', undef, <<"THIS", 1 );
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
28 NewTopic#anchor
29 $this->{test_web}.NewTopic#anchor
30 [[$this->{test_web}.NewTopic#anchor]]
31 [[NewTopic#anchor]]
32 http://site/$this->{test_web}/NewTopic#anchor
33 https://site/$this->{test_web}/NewTopic#anchor
34 NewTopic#OldTopic
35 [[NewTopic#OldTopic]]
36 [[$this->{test_web}.NewTopic][Old Topic Text]]
37 [[$this->{test_web}/OldTopic][Old Topic Text]]
THIS

    #
    # Verify NewTopic references in test_web.OtherTopic  are updated
    #
    $this->check( $this->{test_web}, 'OtherTopic', undef, <<"THIS", 2 );
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
28 NewTopic#anchor
29 $this->{test_web}.NewTopic#anchor
30 [[$this->{test_web}.NewTopic#anchor]]
31 [[NewTopic#anchor]]
32 http://site/$this->{test_web}/NewTopic#anchor
33 https://site/$this->{test_web}/NewTopic#anchor
34 NewTopic#OldTopic
35 [[NewTopic#OldTopic]]
36 [[$this->{test_web}.NewTopic][Old Topic Text]]
37 [[$this->{test_web}/OldTopic][Old Topic Text]]
THIS

    #
    # Verify NewTopic references in new_web.OtherTopic  are updated
    #
    $this->check( $this->{new_web}, 'OtherTopic', undef, <<"THIS", 3 );
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
28 $this->{test_web}.NewTopic#anchor
29 $this->{test_web}.NewTopic#anchor
30 [[$this->{test_web}.NewTopic#anchor]]
31 [[$this->{test_web}.NewTopic#anchor]]
32 http://site/$this->{test_web}/NewTopic#anchor
33 https://site/$this->{test_web}/NewTopic#anchor
34 $this->{test_web}.NewTopic#OldTopic
35 [[$this->{test_web}.NewTopic#OldTopic]]
36 [[$this->{test_web}.NewTopic][Old Topic Text]]
37 [[$this->{test_web}/OldTopic][Old Topic Text]]
THIS

    return;
}

# Test rename with slash delim
# SMELL: slash delimititers only work as part of an url but not as part of a bracket link
sub test_renameTopic_same_web_new_topic_name_slash_delim {
    my $this = shift;

    # SMELL:  If this gets fixed, then the expected line 37 needs to be changed
    # in test_renameTopic_same_web_new_topic_name.

    $this->expect_failure();
    $this->annotate("[[Web/Topic]] fails");

    $this->_reset_session(
        {
            action           => ['rename'],
            newweb           => [ $this->{test_web} ],
            newtopic         => ['NewTopic'],
            referring_topics => [
                "$this->{test_web}.NewTopic", "$this->{test_web}.OtherTopic",
                "$this->{new_web}.OtherTopic"
            ],
            topic => 'OldTopic',

            # The topic in the path should not matter
            path_info => "/$this->{test_web}/SanityCheck"
        }
    );

    my ( $responseText, $result, $stdout, $stderr ) =
      $this->captureWithKey( rename => $UI_FN, $this->{session} );

    # Uncomment to get output from rename command
    #print STDERR $responseText . $result . $stdout . $stderr . "\n";

    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, 'NewTopic' ) );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, 'OldTopic' ) );

    # Verify line 37.   The expected results are modified to pass
    # in test_renameTopic_same_web_new_topic_name.
    my ( $meta, $actual ) =
      Foswiki::Func::readTopic( $this->{test_web}, 'NewTopic' );
    $this->assert_matches(
        qr/^37 \[\[$this->{test_web}\/NewTopic\]\[Old Topic Text\]\]/ms,
        $actual );

    return;
}

# Rename OldTopic to a different web, keeping the same topic name
sub test_renameTopic_new_web_same_topic_name {
    my $this = shift;

    $this->_reset_session(
        {
            action           => ['rename'],
            newweb           => [ $this->{new_web} ],
            newtopic         => ['OldTopic'],
            referring_topics => [
                "$this->{test_web}.OtherTopic", "$this->{new_web}.OldTopic",
                "$this->{new_web}.OtherTopic"
            ],
            topic     => 'OldTopic',
            path_info => "/$this->{test_web}"
        }
    );

    $this->captureWithKey( rename => $UI_FN, $this->{session} );

    $this->assert( Foswiki::Func::topicExists( $this->{new_web}, 'OldTopic' ) );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, 'OldTopic' ) );

    $this->check( $this->{new_web}, 'OldTopic', undef, <<"THIS", 4 );
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
    $this->check( $this->{new_web}, 'OtherTopic', undef, <<"THIS", 5 );
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

    $this->check( $this->{test_web}, 'OtherTopic', undef, <<"THIS", 6 );
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

    return;
}

# Rename OldTopic to a different web no change access on target web
sub test_renameTopic_new_web_same_topic_name_no_access {
    my $this = shift;

    Foswiki::Func::createWeb("$this->{test_web}/Targetweb");
    $this->assert( Foswiki::Func::webExists("$this->{test_web}/Targetweb") );

    my ($m) = Foswiki::Func::readTopic( "$this->{test_web}/Targetweb",
        'WebPreferences' );
    $m->text("   * Set ALLOWWEBCHANGE = NotMe\n   * Set ALLOWWEBVIEW = \n");
    $m->save();
    $m->finish();

    $this->_reset_session(
        {
            action    => ['rename'],
            newweb    => ["$this->{test_web}/Targetweb"],
            newtopic  => ['OldTopic'],
            topic     => 'OldTopic',
            path_info => "/$this->{test_web}"
        }
    );

    try {
        my ($text) =
          $this->captureWithKey( rename => $UI_FN, $this->{session} );
        $this->assert( 0, $text );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_equals( 'OldTopic',                  $e->{topic} );
        $this->assert_equals( 'CHANGE',                    $e->{mode} );
        $this->assert_equals( 'access not allowed on web', $e->{reason} );
    }
    otherwise {
        $this->assert( 0, shift );
    };

    $this->assert(
        Foswiki::Func::topicExists( "$this->{test_web}", 'OldTopic' ) );
    $this->assert(
        !Foswiki::Func::topicExists(
            "$this->{test_web}/Targetweb", 'OldTopic'
        )
    );

    return;
}

# Rename non-wikiword OldTopic to NewTopic within the same web
sub test_renameTopic_nonWikiWord_same_web_new_topic_name {
    my $this = shift;

    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'OldTopic' );
    $meta->put( "TOPICPARENT", { name => 'Tmp1' } );
    $meta->save();
    $meta->finish();

    $this->checkReferringTopics( $this->{test_web}, 'Tmp1', 0,
        [ "$this->{test_web}.OldTopic", ] );

    $this->_reset_session(
        {
            action           => ['rename'],
            newweb           => [ $this->{test_web} ],
            newtopic         => ['Tmp2'],
            nonwikiword      => '1',
            referring_topics => [ "$this->{test_web}.OldTopic", ],
            topic            => 'Tmp1',

            # The topic in the path should not matter
            path_info => "/$this->{test_web}/SanityCheck"
        }
    );

    #print STDERR "Doing Rename\n";
    my ( $stdout, $stderr, $result ) =
      $this->captureWithKey( rename => $UI_FN, $this->{session} );

#print STDERR "Rename STDOUT = ($this->{stdout})\n STDERR = ($this->{stderr})\n RESULT = ($result)\n" ;

    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, 'Tmp2' ) );
    $this->assert( !Foswiki::Func::topicExists( $this->{test_web}, 'Tmp1' ) );

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'OldTopic' );

    $this->assert_str_equals( 'Tmp2', $meta->getParent() );
    $meta->finish();

    return;
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

    my $topictext = <<'THIS';
One lowercase
Twolowercase
[[lowercase]]
THIS
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'lowercase' );
    $topicObject->text($topictext);
    $topicObject->save();
    $topicObject->finish();
    $this->_reset_session(
        {
            action           => 'rename',
            topic            => 'lowercase',
            newweb           => $this->{test_web},
            newtopic         => 'upperCase',
            referring_topics => ["$this->{test_web}.NewTopic"],
            path_info        => "/$this->{test_web}"
        }
    );

    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    my $ext = $Foswiki::cfg{ScriptSuffix};
    $this->assert_matches( qr/^Status:\s+302/s, $text );

    my $ss = '/view' . $Foswiki::cfg{ScriptSuffix} . '/';
    $ss = $Foswiki::cfg{ScriptUrlPaths}{view} . '/'
      if ( defined $Foswiki::cfg{ScriptUrlPaths}{view} );
    $this->assert_matches( qr([lL]ocation:\s+$ss$this->{test_web}/UpperCase)s,
        $text );
    $this->check( $this->{test_web}, 'UpperCase', $topicObject, <<'THIS', 100 );
One lowercase
Twolowercase
[[UpperCase]]
THIS

    return;
}

sub test_renameTopic_TOPICRENAME_access_denied {
    my $this      = shift;
    my $topictext = "   * Set ALLOWTOPICRENAME = GungaDin\n";
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'OldTopic' );
    $topicObject->text($topictext);
    $topicObject->save();
    $topicObject->finish();
    $this->_reset_session(
        {
            action    => 'rename',
            topic     => 'OldTopic',
            newweb    => $this->{test_web},
            newtopic  => 'NewTopic',
            path_info => "/$this->{test_web}"
        }
    );

    try {
        no strict 'refs';
        my ( $text, $result ) = &{$UI_FN}( $this->{session} );
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

    return;
}

sub test_renameTopic_WEBRENAME_access_denied {
    my $this      = shift;
    my $topictext = "   * Set ALLOWWEBRENAME = GungaDin\n";
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text($topictext);
    $topicObject->save();
    $topicObject->finish();
    $this->_reset_session(
        {
            action    => 'rename',
            topic     => 'OldTopic',
            newweb    => $this->{test_web},
            newtopic  => 'NewTopic',
            path_info => "/$this->{test_web}"
        }
    );

    try {
        no strict 'refs';
        my ( $text, $result ) = &{$UI_FN}( $this->{session} );
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

    return;
}

# Test rename does not corrupt history, see Foswikibug:2299
sub test_renameTopic_preserves_history {
    my $this      = shift;
    my $topicName = 'RenameWithHistory';
    my $time      = time();
    my @history   = qw( First Second Third );

    for my $depth ( 0 .. $#history ) {
        my ($topicObject) =
          Foswiki::Func::readTopic( $this->{test_web}, $topicName );
        $topicObject->text( $history[$depth] );
        $topicObject->save( forcenewrevision => 1 );
        $topicObject->finish();
    }
    $this->_reset_session(
        {
            action    => 'rename',
            topic     => $topicName,
            newweb    => $this->{test_web},
            newtopic  => $topicName . 'Renamed',
            path_info => "/$this->{test_web}"
        }
    );

    $this->captureWithKey( rename => $UI_FN, $this->{session} );
    my ($m) =
      Foswiki::Func::readTopic( $this->{test_web}, $topicName . 'Renamed' );
    $this->assert_equals( $history[-1], $m->text );
    my $info = $m->getRevisionInfo();
    $this->assert_equals( scalar(@history), $info->{version} )
      ;    # rename adds a revision
    $m->finish();

    return;
}

# Purpose: verify that leases are removed when a topic is renamed
sub test_renameTopic_ensure_leases_are_released {
    my $this = shift;

    # Grab a lease
    my ($m) = Foswiki::Func::readTopic( $this->{test_web}, 'OldTopic' );
    $m->setLease(1000);

    $this->_reset_session(
        {
            action    => 'rename',
            topic     => 'OldTopic',
            newweb    => $this->{test_web},
            newtopic  => 'NewTopic',
            path_info => "/$this->{test_web}"
        }
    );

    $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $m->finish();
    ($m) = Foswiki::Func::readTopic( $this->{test_web}, 'OldTopic' );
    my $lease = $m->getLease();
    $this->assert_null( $lease, $lease );
    $m->finish();

    return;
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

    return;
}

# Move a subweb, ensuring that static links to that subweb are re-pointed
sub test_renameWeb_1307a {
    my $this = shift;
    Foswiki::Func::createWeb("$this->{test_web}/Renamedweb");
    Foswiki::Func::createWeb("$this->{test_web}/Renamedweb/Subweb");
    Foswiki::Func::createWeb("$this->{test_web}/Notrenamedweb");
    my $vue =
"$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";
    my ($m) = Foswiki::Func::readTopic( "$this->{test_web}/Notrenamedweb",
        'ReferringTopic' );
    $m->text( <<"CONTENT" );
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

    $this->_reset_session(
        {
            action           => 'renameweb',
            newparentweb     => "$this->{test_web}/Notrenamedweb",
            newsubweb        => "Renamedweb",
            referring_topics => [ $m->getPath() ],
            path_info        => "/$this->{test_web}/Renamedweb/WebHome"
        }
    );
    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert(
        Foswiki::Func::webExists("$this->{test_web}/Notrenamedweb/Renamedweb")
    );
    $this->assert( !Foswiki::Func::webExists("$this->{test_web}/Renamedweb") );
    $m->finish();
    ($m) = Foswiki::Func::readTopic( "$this->{test_web}/Notrenamedweb",
        'ReferringTopic' );
    my @lines = split( /\n/, $m->text() );
    $m->finish();
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

    return;
}

# Move a root web, ensuring that static links are re-pointed
sub test_renameWeb_1307b {
    my $this = shift;

    # Need priveleged user to create root webs with Foswiki::Func.
    $this->_reset_session_with_cuid( undef, $Foswiki::cfg{AdminUserLogin} );
    Foswiki::Func::createWeb("Renamed$this->{test_web}");
    Foswiki::Func::createWeb("Renamed$this->{test_web}/Subweb");
    Foswiki::Func::createWeb("$this->{test_web}");
    my $vue =
"$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";
    my ($m) = Foswiki::Func::readTopic( "$this->{test_web}", 'ReferringTopic' );
    $m->text( <<"CONTENT" );
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
    my ($grope) =
      Foswiki::Func::readTopic( $this->{users_web},
        $Foswiki::cfg{SuperAdminGroup} );
    $grope->text(<<"EOF");
   * Set GROUP = $this->{test_user_wikiname}
EOF
    $grope->save();

    $this->_reset_session(
        {
            action           => 'renameweb',
            newparentweb     => $this->{test_web},
            newsubweb        => "Renamed$this->{test_web}",
            referring_topics => [ $m->getPath() ],
            path_info        => "/Renamed$this->{test_web}/WebHome"
        }
    );
    $m->finish();

    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert(
        Foswiki::Func::webExists("$this->{test_web}/Renamed$this->{test_web}")
    );
    $this->assert( !Foswiki::Func::webExists("Renamed$this->{test_web}") );
    ($m) = Foswiki::Func::readTopic( $this->{test_web}, 'ReferringTopic' );
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
    $m->finish();

    return;
}

# Move a root web, ensuring that topics containing web in topic name are not updated.
sub test_renameWeb_10259 {
    my $this = shift;

    # Need priveleged user to create root webs with Foswiki::Func.
    $this->_reset_session_with_cuid( undef, $Foswiki::cfg{AdminUserLogin} );
    Foswiki::Func::createWeb("$this->{test_web}EdNet");

    my $vue =
"$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";

    my ($m) =
      Foswiki::Func::readTopic( "$this->{test_web}EdNet", 'ReferringTopic' );
    $m->text(<<"CONTENT" );
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
    my ($grope) =
      Foswiki::Func::readTopic( $this->{users_web},
        $Foswiki::cfg{SuperAdminGroup} );
    $grope->text( <<"EOF");
   * Set GROUP = $this->{test_user_wikiname}
EOF
    $grope->save();
    $grope->finish();

    $this->_reset_session(
        {
            action           => 'renameweb',
            newsubweb        => "$this->{test_web}RenamedEdNet",
            referring_topics => [ $m->getPath() ],
            path_info        => "/$this->{test_web}EdNet/WebHome"
        }
    );
    $m->finish();

    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert( Foswiki::Func::webExists("$this->{test_web}RenamedEdNet") );
    $this->assert( !Foswiki::Func::webExists("$this->{test_web}EdNet") );
    $this->assert( Foswiki::Func::webExists("$this->{test_web}RenamedEdNet") );

    ($m) = Foswiki::Func::readTopic( "$this->{test_web}RenamedEdNet",
        'ReferringTopic' );
    my @lines = split( /\n/, $m->text() );
    $m->finish();

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

    return;
}

# Move a sub web, ensuring that topics containing web in topic name are not updated.
sub test_renameSubWeb_10259 {
    my $this = shift;

    # Need priveleged user to create root webs with Foswiki::Func.
    $this->_reset_session_with_cuid( undef, $Foswiki::cfg{AdminUserLogin} );
    Foswiki::Func::createWeb("$this->{test_web}Root");
    Foswiki::Func::createWeb("$this->{test_web}Root/EdNet");

    my $vue =
"$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";

    my ($m) = Foswiki::Func::readTopic( "$this->{test_web}Root/EdNet",
        'ReferringTopic' );
    $m->text( <<"CONTENT" );
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
    my ($grope) =
      Foswiki::Func::readTopic( $this->{users_web},
        $Foswiki::cfg{SuperAdminGroup} );
    $grope->text(<<"EOF");
   * Set GROUP = $this->{test_user_wikiname}
EOF
    $grope->save();

    $this->_reset_session(
        {
            action           => 'renameweb',
            newsubweb        => "$this->{test_web}Root/NewEdNet",
            referring_topics => [ $m->getPath() ],
            path_info        => "/$this->{test_web}Root/EdNet/WebHome"
        }
    );
    $m->finish();

    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert( Foswiki::Func::webExists("$this->{test_web}Root/NewEdNet") );
    $this->assert( !Foswiki::Func::webExists("$this->{test_web}EdNet") );
    $this->assert( Foswiki::Func::webExists("$this->{test_web}Root/NewEdNet") );

    ($m) = Foswiki::Func::readTopic( "$this->{test_web}Root/NewEdNet",
        'ReferringTopic' );
    my @lines = split( /\n/, $m->text() );
    $m->finish();

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

    return;
}

sub test_rename_attachment {
    my $this = shift;

    my ($to) = Foswiki::Func::readTopic( $this->{test_web}, 'NewTopic' );
    $to->text('Wibble');
    $to->save();
    $to->finish();

    # returns undef on OSX with 3.15 version of CGI module (works on 3.42)
    my $stream = File::Temp->new( UNLINK => 0 );
    print $stream "Blah Blah";
    $this->assert( $stream->close() );
    $stream->unlink_on_destroy(1);

    ($to) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $to->attach( name => 'dis.dat', file => $stream->filename );
    $to->finish();

    $this->_reset_session(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
            path_info     => "/$this->{test_web}/$this->{test_topic}"
        }
    );

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

    return;
}

sub test_move_attachment_RENAME_Topic_denied {
    my $this = shift;

    my ($to) = Foswiki::Func::readTopic( $this->{test_web}, 'NewTopic' );
    $to->text('Wibble');
    $to->save();
    $to->finish();

    # returns undef on OSX with 3.15 version of CGI module (works on 3.42)
    my $stream = File::Temp->new( UNLINK => 0 );
    print $stream "Blah Blah";
    $this->assert( $stream->close() );
    $stream->unlink_on_destroy(1);

    ($to) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $to->text("Wibble\n   * Set ALLOWTOPICRENAME = NotMe\n");
    $to->attach( name => 'dis.dat', file => $stream->filename );
    $to->save();
    $to->finish();

    $this->_reset_session(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
            path_info     => "/$this->{test_web}/$this->{test_topic}"
        }
    );

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

    # Make sure rename back fails if change of target is denied
    ($to) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $to->text("Wibble\n   * Set ALLOWTOPICCHANGE = NotMe\n");
    $to->save();
    $to->finish();

    $this->_reset_session(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => [ $this->{test_topic} ],
            newweb        => $this->{test_web},
            path_info     => "/$this->{test_web}/NewTopic"
        }
    );

    try {
        ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
        $this->assert( 0, $text );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_equals( $this->{test_topic},           $e->{topic} );
        $this->assert_equals( 'CHANGE',                      $e->{mode} );
        $this->assert_equals( 'access not allowed on topic', $e->{reason} );
    }
    otherwise {
        $this->assert( 0, shift );
    };

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

    return;
}

sub test_move_attachment_RENAME_Web_denied {
    my $this = shift;

    my ($m) = Foswiki::Func::readTopic( "$this->{test_web}", 'WebPreferences' );
    $m->text("   * Set ALLOWWEBRENAME = NotMe\n");
    $m->save();
    $m->finish();

    my ($to) = Foswiki::Func::readTopic( $this->{new_web}, 'NewTopic' );
    $to->text('Wibble');
    $to->save();
    $to->finish();

    # returns undef on OSX with 3.15 version of CGI module (works on 3.42)
    my $stream = File::Temp->new( UNLINK => 0 );
    print $stream "Blah Blah";
    $this->assert( $stream->close() );
    $stream->unlink_on_destroy(1);

    ($to) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $to->text("Wibble\n");
    $to->attach( name => 'dis.dat', file => $stream->filename );
    $to->finish();

    $this->_reset_session(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{new_web},
            path_info     => "/$this->{test_web}/$this->{test_topic}"
        }
    );

    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert_matches( qr/Status: 302/,                $text );
    $this->assert_matches( qr#/$this->{new_web}/NewTopic#, $text );
    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, $this->{test_topic} ) );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, 'dis.dat'
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{new_web}, 'NewTopic', 'dis.dat'
        )
    );

    return;
}

# Item5464 - Rename of attachment requires change access, not rename access
sub test_rename_attachment_Rename_Denied_Change_Allowed {
    my $this = shift;

    my ($to) = Foswiki::Func::readTopic( $this->{test_web}, 'NewTopic' );
    $to->text("Wibble\n   * Set ALLOWTOPICRENAME = NotMe\n");
    $to->save();
    $to->finish();

    # returns undef on OSX with 3.15 version of CGI module (works on 3.42)
    my $stream = File::Temp->new( UNLINK => 0 );
    print $stream "Blah Blah";
    $this->assert( $stream->close() );
    $stream->unlink_on_destroy(1);

    ($to) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $to->attach( name => 'dis.dat', file => $stream->filename );
    $to->finish();

    $this->_reset_session(
        {
            attachment    => ['dis.dat'],
            newattachment => ['doh.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
            path_info     => "/$this->{test_web}/$this->{test_topic}"
        }
    );

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

    return;
}

# Item5464 - Rename of attachment requires change access, not rename access
sub test_rename_attachment_Rename_Allowed_Change_Denied {
    my $this = shift;

    my ($to) = Foswiki::Func::readTopic( $this->{test_web}, 'NewTopic' );
    $to->text("Wibble\n   * Set ALLOWTOPICCHANGE = NotMe\n");
    $to->save();
    $to->finish();

    # returns undef on OSX with 3.15 version of CGI module (works on 3.42)
    my $stream = File::Temp->new( UNLINK => 0 );
    print $stream "Blah Blah";
    $this->assert( $stream->close() );
    $stream->unlink_on_destroy(1);

    ($to) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $to->attach( name => 'dis.dat', file => $stream->filename );
    $to->finish();

    $this->_reset_session(
        {
            attachment    => ['dis.dat'],
            newattachment => ['doh.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
            path_info     => "/$this->{test_web}/$this->{test_topic}"
        }
    );

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

    return;
}

sub test_rename_attachment_not_in_meta {
    my $this = shift;

    my ($to) = Foswiki::Func::readTopic( $this->{test_web}, 'NewTopic' );
    $to->text('Wibble');
    $to->save();
    $to->finish();

    ($to) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $fh = $to->openAttachment( 'dis.dat', '>' );
    $to->finish();
    print $fh "Oh no not again";
    $this->assert( close($fh) );

    $this->_reset_session(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
            path_info     => "/$this->{test_web}/$this->{test_topic}"
        }
    );

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

    return;
}

sub test_rename_attachment_no_dest_topic {
    my $this = shift;

    my ($to) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $fh = $to->openAttachment( 'dis.dat', '>' );
    $to->finish();
    print $fh "Oh no not again";
    $this->assert( close($fh) );

    $this->_reset_session(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
            path_info     => "/$this->{test_web}/$this->{test_topic}"
        }
    );

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

    return;
}

# Check that an attachment in meta-data but not on the disc can be renamed
# Test disabled by CDot because of Item9352
sub do_not_test_rename_attachment_not_on_disc {
    my $this = shift;

    my $stream = File::Temp->new( UNLINK => 0 );
    print $stream "Blah Blah";
    $this->assert( $stream->close() );
    $stream->unlink_on_destroy(1);

    my ($to) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $to->attach( name => 'dis.dat', file => $stream->filename );
    $to->finish();

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

    ($to) = Foswiki::Func::readTopic( $this->{test_web}, 'NewTopic' );
    $to->text('Wibble');
    $to->save();
    $to->finish();

    $this->_reset_session(
        {
            attachment    => ['dis.dat'],
            newattachment => ['dis.dat'],
            newtopic      => ['NewTopic'],
            newweb        => $this->{test_web},
            path_info     => "/$this->{test_web}/$this->{test_topic}"
        }
    );

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

    return;
}

# Move a root web to something with same spelling bug different case (seemed to cause a MonogDB issue)
sub test_renameWeb_10990 {
    my $this    = shift;
    my $webname = "Renamed$this->{test_web}";

    # Need priveleged user to create root webs with Foswiki::Func.
    $this->_reset_session_with_cuid( undef, $Foswiki::cfg{AdminUserLogin} );
    Foswiki::Func::createWeb($webname);

    # need rename access on the root for this one, which is a bit of a
    # faff to set up, so we'll cheat a bit and add the user to the admin
    # group. Fortunately we have a private users web.
    my ($grope) =
      Foswiki::Func::readTopic( $this->{users_web},
        $Foswiki::cfg{SuperAdminGroup} );
    $grope->text(<<"EOF");
   * Set GROUP = $this->{test_user_wikiname}
EOF
    $grope->save();
    $grope->finish();

    $this->_reset_session(
        {
            action           => 'renameweb',
            newsubweb        => "RENAMED$this->{test_web}",
            referring_topics => [$webname],
            path_info        => "/Renamed$this->{test_web}/WebHome"
        }
    );

    my ($text) = $this->captureWithKey( rename => $UI_FN, $this->{session} );
    $this->assert( Foswiki::Func::webExists("RENAMED$this->{test_web}") );
    $this->assert( !Foswiki::Func::webExists("Renamed$this->{test_web}") );

    #now remove it!
    $this->removeWebFixture( $this->{session}, "RENAMED$this->{test_web}" );

    return;
}

1;
