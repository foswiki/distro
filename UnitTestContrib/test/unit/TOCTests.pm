package TOCTests;

=pod

These tests verify the proper working of the TOC.

The only tests currently covered concern that URL parameters are correctly
propagated into the TOC.

=cut

use FoswikiTestCase;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
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
    my $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, $this->{test_topic} );
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

    my @children =
      $this->setup_TOCtests( $testtext1, '', '' );

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
    my $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, $this->{test_topic}, $text );
    $topicObject->save();
    my $res = $topicObject->expandMacros($text );
    $res = $topicObject->renderTML( $res );

    $this->assert_html_equals(<<HTML, $res);
<a name="foswikiTOC"></a>
<div class="foswikiToc">
 <ul>
  <li> <a href="#A_level_1_head_33line">A level 1 head!line</a>
   <ul>
    <li> <a href="#Followed_by_a_level_2_33_headline">
     Followed by a level 2! headline</a>
    </li>
   </ul> 
  </li>
 </ul> 
</div>
<nop><h1><a name="A_level_1_head_33line"></a>  A level 1 head!line </h1>
<nop><h2><a name="Followed_by_a_level_2_33_headline"></a>
 Followed by a level 2! headline </h2>
<nop><h2><a name="Another_level_2_headline"></a>
 Another level 2 headline </h2>
HTML
}

sub test_TOC_SpecialCharacters {
    my ($this) = @_;

    # Each tuple describes one heading comparison and the expected result
    # The first value is the expected anchor. 
    # The second value is the heading.
    my @comparisons = (
        ['A_1', '---+ 1', 'Numbered heading' ],         # Numbered heading
        ['test_361', '---+ test $1', 'Dollar sign'],    # Dollar Sign
        ['test_40_41', '---+ test ()', 'Parenthesis'],                 # Parenthesis
        ['TEST_33_WikiWord', '---+ TEST ! WikiWord', 'WikiWord and !'],   # Unescaped WikiWord
        ['TEST_WikiWord', '---+ TEST !WikiWord', 'Escaped WikiWord'],       # Escaped WikiWord
        ['TEST_60', '---+ TEST <', 'Less-than'],                     # Less-than
        ['TEST_61', '---+ TEST >', 'Greater-than'],                     # Greater-than
        ['TEST_60_61', '---+ TEST <>'],                 # Less / greater than.
        ['Test_40_41_123_125_91_93_45_43_33_60_61_62_126_36', '---+ Test (){}[]_-+!<>~$', 'Complex 1'],
        #['Test_60_40_41_123_125_91_93_45_43_33_62_126_36', '---+ Test <(){}[]_-+!>~$', 'Complex 2'],

    );
    foreach my $set (@comparisons) {
        my $expected = $set->[0];
        my $wikitext = <<HERE;
%TOC%
$set->[1]
HERE
        my $topicObject = Foswiki::Meta->new(
            $this->{session}, $this->{test_web}, $this->{test_topic}, $wikitext );
        $topicObject->save();
        my $res = $topicObject->expandMacros($wikitext );
        $res = $topicObject->renderTML( $res );
        #print "RES $res \n\n";
        $this->assert_matches( 
            qr/href="#$expected".*name="$expected"/sm, 
            $res, "$set->[2] - Expected Anchor/Link =  $expected  Actual HTML\n====\n$res\n====\n" );
    }
}

1;
