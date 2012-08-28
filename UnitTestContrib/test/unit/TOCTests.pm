package TOCTests;
use strict;
use warnings;

=pod

These tests verify the proper working of the TOC.

The only tests currently covered concern that URL parameters are correctly
propagated into the TOC.

=cut

use FoswikiTestCase();
use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::UI::Edit;
use Foswiki::Form;
use Foswiki::Macros::TOC;
use Unit::Request;
use Unit::Response;
use Error qw( :try );

my $setup_failure = '';

my $aurl;    # Holds the %ATTACHURL%
my $surl;    # Holds the %SCRIPTURL%

my $testtext1 = <<'HERE';
%TOC%

---+ A level 1 headline with %URLPARAMS{"param1"}%

---++ Followed by a level 2 headline with %URLPARAMS{"param2"}%

---++ Another level 2 headline

---+++ Now a level 3 headline

With a few words of text.

---++ And back to level 2

HERE

sub skip {
    my ( $this, $test ) = @_;

    return $this->SUPER::skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                'TOCTests::test_TOC_params' =>
                  'TOC params are Foswiki 1.2+ only',
            }
        }
    );
}

sub setup_TOCtests {
    my ( $this, $text, $params, $tocparams ) = @_;

    my $query = new Unit::Request();

    $surl = $this->{session}->getScriptUrl(1);

    $this->{session}->{webName}   = $this->{test_web};
    $this->{session}->{topicName} = $this->{test_topic};

    use Foswiki::Attrs;
    my $attr = new Foswiki::Attrs($params);
    foreach my $k ( keys %$attr ) {
        next if $k eq '_RAW';
        $this->{request}->param( -name => $k, -value => $attr->{$k} );
    }

    # Now generate the TOC
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $res = $this->{session}->TOC( $text, $topicObject, $tocparams );

    eval 'use HTML::TreeBuilder; use HTML::Element;';
    if ($@) {
        my $current_failure = $@;
        $current_failure =~ s/\(eval \d+\)//g;    # remove number for comparison
        if ( $current_failure eq $setup_failure ) {

            # we've seen the same error before.  Probably one of the CPAN
            # prerequisites is missing.
            $this->assert( 0,
                "Unable to set up test:  Same problem as above." );
        }
        else {
            $setup_failure = $current_failure;
            $this->assert( 0, "Unable to set up test: '$@'" );
        }
        return;
    }

    my $tree = HTML::TreeBuilder->new_from_content($res);

    # ----- now analyze the resultant $tree

    my @children = $tree->content_list();
    return $children[0]->content_list();

}

sub test_parameters {
    my $this = shift;

    my @children = $this->setup_TOCtests( $testtext1,
        'param1="a little luck" param2="no luck"', '' );

    # @children will have alternating ' * ' and an href
    foreach my $c (@children) {
        next if ( $c eq " * " );
        my $res = $c->{href};
        $res =~ s/#.*$//o;    # Delete anchor
        $this->assert_matches( qr/\?[\w;&=%]+$/,             $res );
        $this->assert_matches( qr/param2=no%20luck/,         $res );
        $this->assert_matches( qr/param1=a%20little%20luck/, $res );
    }
}

sub test_no_parameters {
    my $this = shift;

    my @children = $this->setup_TOCtests( $testtext1, '', '' );

    # @children will have alternating ' * ' and an href
    foreach my $c (@children) {
        next if ( $c eq " * " );
        my $res = $c->{href};
        $res =~ s/#.*$//o;    # Delete anchor
        $this->assert_str_equals( '', $res );
    }
}

sub test_Item8592 {
    my $this = shift;
    my $text = <<'HERE';
%TOC%
---+ A level 1 head!line
---++ Followed by a level 2! headline
---++!! Another level 2 headline
HERE
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->text($text);
    $topicObject->save();
    my $res = $topicObject->expandMacros($text);
    $res = $topicObject->renderTML($res);

    my $expected = <<HTML;
<div class="foswikiToc" id="foswikiTOC"> <ul>
  <li> <a href="#A_level_1_head_33line">A level 1 head!line</a>
   <ul>
    <li> <a href="#Followed_by_a_level_2_33_headline">
     Followed by a level 2! headline</a>
    </li>
   </ul> 
  </li>
 </ul> 
</div>
<nop><h1 id="A_level_1_head_33line">  A level 1 head!line </h1>
<nop><h2 id="Followed_by_a_level_2_33_headline">
 Followed by a level 2! headline </h2>
<nop><h2 id="Another_level_2_headline">
 Another level 2 headline </h2>
HTML

    if ( $this->check_dependency('Foswiki,<,1.2') ) {
        $expected =~
s/<div class="foswikiToc" id="foswikiTOC">/<a name="foswikiTOC"><\/a><div class="foswikiToc">/;
        $expected =~ s/<h([1-6]) id="([^"]+)">/<h$1><a name="$2"><\/a>/g;
    }
    $this->assert_html_equals( $expected, $res );
    $topicObject->finish();
}

sub test_Item9009 {
    my $this = shift;

    my $url = $this->{session}->getScriptUrl( 0, 'view' );

    my $text = <<'HERE';
---+ A level 1 head!line
---++ Followed by a level 2! headline
---++!! Another level 2 headline
HERE
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->text($text);
    $topicObject->save();

    my $text2 = <<HERE;
%TOC{"$this->{test_web}.$this->{test_topic}"}%
HERE
    my ($topicObject2) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} . "2" );
    $topicObject2->text($text2);
    $topicObject->save();
    my $res2 = $topicObject2->expandMacros($text2);
    $res2 = $topicObject->renderTML($res2);
    $topicObject->finish();

    #return;

    my $expected = <<HTML;
<div class="foswikiToc" id="foswikiTOC"> <ul> 
<li> <a href="$url/TemporaryTOCTestsTestWebTOCTests/TestTopicTOCTests#A_level_1_head_33line">A level 1 head!line</a> <ul>
<li> <a href="$url/TemporaryTOCTestsTestWebTOCTests/TestTopicTOCTests#Followed_by_a_level_2_33_headline">Followed by a level 2! headline</a>
</li></ul>                                                                                                                              
</li></ul>                                                                                                                              
</div>
HTML
    if ( $this->check_dependency('Foswiki,<,1.2') ) {
        $expected =~
s/<div class="foswikiToc" id="foswikiTOC">/<a name="foswikiTOC"><\/a><div class="foswikiToc">/;
        $expected =~ s/<h([1-6]) id="([^"]+)">/<h$1><a name="$2"><\/a>/g;
    }
    $this->assert_html_equals( $expected, $res2 );
}

sub test_Item2458 {
    my $this = shift;

    my $url = $this->{session}->getScriptUrl( 0, 'view' );

    my $text = <<'HERE';
%TOC%
---+ !WikiWord
HERE
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->text($text);
    $topicObject->save();
    my $res = $topicObject->expandMacros($text);
    $res = $topicObject->renderTML($res);

    my $expected = <<HTML;
<div class="foswikiToc" id="foswikiTOC"> <ul>
<li> <a href="#WikiWord"> <nop>WikiWord</a>
</li></ul> 
</div>
<nop><h1 id="WikiWord">  <nop>WikiWord </h1>
HTML
    if ( $this->check_dependency('Foswiki,<,1.2') ) {
        $expected =~
s/<div class="foswikiToc" id="foswikiTOC">/<a name="foswikiTOC"><\/a><div class="foswikiToc">/;
        $expected =~ s/<h([1-6]) id="([^"]+)">/<h$1><a name="$2"><\/a>/g;
    }
    $this->assert_html_equals( $expected, $res );
    $topicObject->finish();
}

sub test_TOC_SpecialCharacters {
    my ($this) = @_;

    # Each tuple describes one heading comparison and the expected result
    # The first value is the expected anchor.
    # The second value is the heading.
    my @comparisons = (
        [ 'A_1',     '---+ 1',                 'Numbered heading' ],
        [ 'A_1_AN1', "---+ 1\n---+ 1",         'Duplicate heading' ],
        [ 'A_1_AN2', "---+ 1\n---+ 1\n---+ 1", 'Triplicate heading' ],
        [ 'test_361',   '---+ test $1', 'Dollar sign' ],    # Dollar Sign
        [ 'test_40_41', '---+ test ()', 'Parenthesis' ],    # Parenthesis
        [ 'TEST_33_WikiWord', '---+ TEST ! WikiWord', 'WikiWord and !' ]
        ,                                                   # Unescaped WikiWord
        [
            'TEST_WikiWord', '---+ TEST <nop>WikiWord', '<nop> Escaped WikiWord'
        ],                                                  # Escaped WikiWord
        [ 'TEST_WikiWord', '---+ TEST !WikiWord', '! Escaped WikiWord' ]
        ,                                                   # Escaped WikiWord
        [ 'TEST_60_62', '---+ TEST <>', 'Null tag' ],     # Less / greater than.
        [ 'TEST_62',    '---+ TEST >',  'Greater-than' ], # Greater-than
        [ 'TEST_60',    '---+ TEST <',  'Less-than' ],    # Less-than
        [ 'TEST_92x',   '---+ TEST \x', 'Backslash' ],
        [ 'TEST_38_38', '---+ TEST & &amp;',                 'Ampersand' ],
        [ 'Entities',   '---+ Entities &#65; &#x41; &copy;', 'Entities' ],
        [
            'Test_40_41_123_125_91_93_45_43_33_60_62_126_36',
            '---+ Test (){}[]_-+!<>~$',
            'Complex 1'
        ],
        [
            'Test_60_40_41_123_125_91_93_45_43_33_62_126_36',
            '---+ Test <(){}[]_-+!>~$',
            'Complex 2'
        ],
        [ 'Linkword', '---++ [[Linkword]]', 'Squarebracket' ],
        [ 'WikiWord', '---++ [[WikiWord]]', 'Squarebracket with wikiword' ],
        [ 'WikiWord_is_first', '---++ WikiWord is first', 'WikiWord is first' ],
        [
            'System.WikiWord_is_first',
            '---++ System.WikiWord is first',
            'WikiWord is first'
        ],
    );

    my $id = ( $this->check_dependency('Foswiki,<,1.2') ) ? 'name' : 'id';

    foreach my $set (@comparisons) {
        my $expected = $set->[0];
        my $wikitext = <<HERE;
%TOC%
$set->[1]
HERE
        my ($topicObject) =
          Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
        $topicObject->text($wikitext);
        $topicObject->save();
        my $res = $topicObject->expandMacros($wikitext);
        $res = $topicObject->renderTML($res);
        $topicObject->finish();

        # print "RES:$res \n\nEXPECTED:$expected\n\n";
        $this->assert_matches( qr/href="#$expected".*$id="$expected"/sm, $res,
"$set->[2] - Expected Anchor/Link =  $expected  Actual HTML\n====\n$res\n====\n"
        );
    }
}

sub test_TOC_makeAnchorName {
    my ($this) = @_;
    require Foswiki::Render;

    # Each tuple describes one heading comparison and the expected result
    # The first value is the expected anchor.
    # The second value is the heading.
    my @comparisons = (
        [ 'A_1',        '1',       'Numbered heading' ],
        [ 'test_361',   'test $1', 'Dollar sign' ],        # Dollar Sign
        [ 'test_40_41', 'test ()', 'Parenthesis' ],        # Parenthesis
        [ 'TEST_33_WikiWord', 'TEST ! WikiWord', 'WikiWord and !' ]
        ,                                                  # Unescaped WikiWord
        [ 'TEST_WikiWord', 'TEST <nop>WikiWord', '<nop> Escaped WikiWord' ]
        ,                                                  # Escaped WikiWord
        [ 'TEST_WikiWord', 'TEST !WikiWord', '! Escaped WikiWord' ]
        ,                                                  # Escaped WikiWord
        [ 'TEST_asdf', 'TEST <a href="A1"> asdf', 'valid tag' ],
        [ 'TEST_60_62', 'TEST <>', 'Null tag' ],        # Less / greater than.
        [ 'TEST_62',    'TEST >',  'Greater-than' ],    # Greater-than
        [ 'TEST_60',    'TEST <',  'Less-than' ],       # Less-than
        [
            'Test_40_41_123_125_91_93_45_43_33_60_62_126_36',
            'Test (){}[]_-+!<>~$',
            'Complex 1'
        ],
        [
            'Test_60_40_41_123_125_91_93_45_43_33_62_126_36',
            'Test <(){}[]_-+!>~$',
            'Complex 2'
        ],
        [ 'Linkword',          '[[Linkword]]',      'Squarebracket' ],
        [ 'WikiWord_is_first', 'WikiWord is first', 'WikiWord is first' ],
        [ 'WikiWord_escaped',  '!WikiWord escaped', 'WikiWord is escaped' ],
        [ 'ABBREV_escaped',    '!ABBREV escaped',   'ABBREV is escaped' ],
        [
            'System.WikiWord_is_first',
            'System.WikiWord is first',
            'WikiWord is first'
        ],
    );

    foreach my $set (@comparisons) {
        my $expected = $set->[0];
        my $wikitext = $set->[1];

        my $res = Foswiki::Render::Anchors::make($wikitext);
        $this->assert_str_equals( $expected, $res,
            "$set->[2] - Expected = $expected,  ACTUAL = $res\n" );
    }
}

sub test_TOC_params {
    my $this = shift;
    my $text = <<'HERE';
%TOC{title="Table of Contents" align="right" depth="2" id="Qwerty"}%
---+ A level 1 headline
---++ Followed by a level 2 headline
---++ Another level 2 headline
---+++ Level 3 headline
---++++ Level 4 headline
---+++ Another level 3 headline
HERE
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->text($text);
    $topicObject->save();
    my $res = $topicObject->expandMacros($text);
    $res = $topicObject->renderTML($res);

    $this->assert_html_equals( <<HTML, $res );
<div class="foswikiToc foswikiRight" id="Qwerty"><span class="foswikiTocTitle">Table of Contents</span> <ul>
<li> <a href="#A_level_1_headline"> A level 1 headline </a> <ul>
<li> <a href="#Followed_by_a_level_2_headline"> Followed by a level 2 headline </a>
</li> <li> <a href="#Another_level_2_headline"> Another level 2 headline </a>
</li></ul> 
</li></ul> 
</div>
<nop><h1 id="A_level_1_headline">  A level 1 headline </h1>
<nop><h2 id="Followed_by_a_level_2_headline">  Followed by a level 2 headline </h2>
<nop><h2 id="Another_level_2_headline">  Another level 2 headline </h2>
<nop><h3 id="Level_3_headline">  Level 3 headline </h3>
<nop><h4 id="Level_4_headline">  Level 4 headline </h4>
<nop><h3 id="Another_level_3_headline">  Another level 3 headline </h3>
HTML
    $topicObject->finish();
}

1;
