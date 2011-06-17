use strict;

#test the FORMAT rendering operator extracted from legacy SEARCH

package Fn_FORMAT;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
use Assert;
use Foswiki::Search;

sub new {
    my $self = shift()->SUPER::new( 'SEARCH', @_ );
    return $self;
}

sub test_separator {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic" separator=","}%'
      );

    $this->assert_str_equals( "OkATopic,OkBTopic,OkTopic", $result );
}

sub test_perl_newline_separator {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic" separator="'."\n".'"}%'
      );

    $this->assert_str_equals( "OkATopic\nOkBTopic\nOkTopic", $result );
}
sub test_newline_separator {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic" separator="
"}%'
      );

    $this->assert_str_equals( "OkATopic\nOkBTopic\nOkTopic", $result );
}
sub test_dollar_newline_separator {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic" separator="$n"}%'
      );

    $this->assert_str_equals( "OkATopic\nOkBTopic\nOkTopic", $result );
}
#TODO: Sven isn't sure we use \n
sub test_backslash_escaped_newline_separator {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic" separator="\n"}%'
      );

    $this->assert_str_equals( "OkATopic\\nOkBTopic\\nOkTopic", $result );
}

sub test_separator_with_header {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic" header="RESULT:" nonoise="on" format="$topic" separator=","}%'
      );

    $this->assert_str_equals(
        "RESULT:OkATopic,OkBTopic,OkTopic", $result
    );
}

sub test_footer_with_ntopics {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic"  nonoise="on" footer="$n()Total found: $ntopics" format="$topic"}%'
    );

    $this->assert_str_equals(
        join( "\n", qw(OkATopic OkBTopic OkTopic) ) . "\nTotal found: 3",
        $result );
}

sub test_footer_with_ntopics_no_format {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic"  nonoise="on" footer="Total found: $ntopics" separator=""}%'
    );

    $this->assert_str_equals( "Total found: 3", $result );
}

sub test_footer_with_ntopics_no_format_nonoise {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic"  nonoise="off" footer="Total found: $ntopics" separator=""}%'
    );

    $this->assert_str_equals( "Total found: 3", $result );
}
sub test_footer_with_ntopics_no_format_nonosummary_nononoise {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic"   nosummary="off" nonoise="off" footer="Total found: $ntopics" separator=""}%'
    );

    $this->assert_str_equals( "Total found: 3", $result );
}
sub test_footer_with_ntopics_no_format_nonosummary_nonoise {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic"   nosummary="off" nonoise="on" footer="Total found: $ntopics" separator=""}%'
    );

    $this->assert_str_equals( "Total found: 3", $result );
}


sub test_footer_with_ntopics_empty_format {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic"  nonoise="on" footer="Total found: $ntopics" format="" separator=""}%'
    );

    $this->assert_str_equals( "Total found: 3", $result );
}

sub test_SEARCH_3860 {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros( <<'HERE');
%FORMAT{"OkTopic" format="$wikiname $wikiusername" nonoise="on" }%
HERE
    my $wn = $this->{session}->{users}->getWikiName( $this->{session}->{user} );
    $this->assert_str_equals( "$wn $this->{users_web}.$wn\n", $result );

    $result = $this->{test_topicObject}->expandMacros( <<'HERE');
%FORMAT{"OkTopic" format="$createdate $createusername $createwikiname $createwikiusername" nonoise="on" }%
HERE
    $this->assert_str_equals( "01 Jan 1970 - 00:00 guest $wn $this->{users_web}.$wn\n", $result );
}


sub set_up_for_formatted_search {
    my $this = shift;

    my $text = <<'HERE';
%META:TOPICINFO{author="ProjectContributor" date="1169714817" format="1.1" version="1.2"}%
%META:TOPICPARENT{name="TestCaseAutoFormattedSearch"}%
!MichaelAnchor and !AnnaAnchor lived in Skagen in !DenmarkEurope!. There is a very nice museum you can visit!

This text is fill in text which is there to ensure that the unique word below does not show up in a summary.

   * Bullet 1
   * Bullet 2
   * Bullet 3
   * Bullet 4

%META:FORM{name="FormattedSearchForm"}%
%META:FIELD{name="Name" attributes="" title="Name" value="!AnnaAnchor"}%
HERE

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'FormattedSearchTopic1', $text );
    $topicObject->save();
}

sub test_same_topic_listed_twice {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
'%FORMAT{
    "OkATopic,OkBTopic,OkTopic,OkATopic"  
    nonoise="on" 
    footer="Total found: $ntopics" 
    format="$topic"
}%'
    );

    $this->assert_str_equals(
        join( "\n", qw(OkATopic OkBTopic OkTopic OkATopic) ) . "Total found: 4",
        $result );
}

#TODO: ?? sumarizeText fails?
sub DISABLEtest_formatted_search_summary_with_exclamation_marks {
    my $this    = shift;
    my $session = $this->{session};

    $this->set_up_for_formatted_search();
    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"FormattedSearchTopic1" format="$summary"}%'
      );
    $actual = $this->{test_topicObject}->renderTML($actual);
    $expected =
'<nop>MichaelAnchor and <nop>AnnaAnchor lived in Skagen in <nop>DenmarkEurope!. There is a very nice museum you can visit!';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"FormattedSearchTopic1" format="$formfield(Name)"
}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>AnnaAnchor';
    $this->assert_str_equals( $expected, $actual );
}

#dunno what i broke that causes this to fail :(
sub DISABLEtest_pattern {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic" nonoise="on" format="X$pattern(.*?BLEEGLE (.*?)blah.*)Y"}%'
      );
    $this->assert_matches( qr/Xdontmatchme\.Y/, $result );
    $this->assert_matches( qr/Xdont.matchmeY/,  $result );
    $this->assert_matches( qr/XY/,              $result );
}

sub test_badpattern {
    my $this = shift;

    # The (??{ pragma cannot be run at runtime since perl 5.5

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic" nonoise="on" format="X$pattern(.*?BL(??{\'E\' x 2})GLE( .*?)blah.*)Y"}%'
      );

    # If (??{ is evaluated, the topics should match:
    $this->assert_does_not_match( qr/XdontmatchmeY/,  $result );
    $this->assert_does_not_match( qr/Xdont.matchmeY/, $result );
    $this->assert_does_not_match( qr/X Y/,            $result );
    # If (??{ isn't evaluated, $pattern should return empty
    # and format should be XY for all 3 topics
    $this->assert_equals( 3, $result =~ s/^XY$//gm );
}

sub test_validatepattern {
    my $this = shift;
    my ( $pattern, $temp );

    # Test comment
    $pattern = Foswiki::validatePattern('foo(?#comment)bar');
    $this->assert_matches( qr/$pattern/, 'foobar' );

    # Test clustering and pattern-match modifiers
    $pattern = Foswiki::validatePattern('(?i:foo)(?-i)bar');
    $this->assert_matches( qr/$pattern/, 'FoObar' );
    $this->assert_does_not_match( qr/$pattern/, 'FoObAr' );

    # Test zero-width positive look-ahead
    $pattern = Foswiki::validatePattern('foo(?=bar)');
    $this->assert_matches( qr/$pattern/, 'foobar' );
    $this->assert_does_not_match( qr/$pattern/, 'barfoo bar' );
    $temp = 'foobar';
    $this->assert_equals( 1, $temp =~ s/$pattern// );
    $this->assert_equals( 'bar', $temp );

    # Test zero-width negative look-ahead
    $pattern = Foswiki::validatePattern('foo(?!bar)');
    $this->assert_does_not_match( qr/$pattern/, 'foobar' );
    $this->assert_matches( qr/$pattern/, 'barfoo bar' );
    $this->assert_matches( qr/$pattern/, 'foo' );
    $temp = 'fooblue';
    $this->assert_equals( 1, $temp =~ s/$pattern// );
    $this->assert_equals( 'blue', $temp );

    # Test independent sub-expression
    $pattern = Foswiki::validatePattern('foo(?>blue)bar');
    $this->assert_matches( qr/$pattern/, 'foobluebar' );

}

#Item977
sub test_formatOfLinks {
    my $this = shift;

    my $topicObject = Foswiki::Meta->new(
        $this->{session},
        $this->{test_web}, 'Item977', "---+ Apache

Apache is the [[http://www.apache.org/httpd/][well known web server]].
"
    );
    $topicObject->save();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%FORMAT{"Item977" format="$summary"}%');

    $this->assert_str_equals( 'Apache Apache is the well known web server.',
        $result );
}

##############################################################
# add Crawford's septic system
#####################
sub _septic {
    my ($this, $head, $foot, $sep, $results, $expected) = @_;
    my $str = $results ? '*Topic' : 'Septic';
    $head = $head ? 'header="HEAD"' : '';
    $foot = $foot ? 'footer="FOOT"' : '';
    $sep = defined $sep ? "separator=\"$sep\"" : '';
    my $topiclist = $results ? 'OkATopic,OkBTopic,OkTopic' : '';
    my $result =
      $this->{test_topicObject}->expandMacros(
          "%FORMAT{\"$topiclist\" format=\"\$topic\" $head $foot $sep}%" );
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#####################
sub test_no_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic(0, 0, undef, 1, <<EXPECT);
OkATopic
OkBTopic
OkTopic
EXPECT
}

sub test_no_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic(0, 0, undef, 0, <<EXPECT);
EXPECT
}

sub test_no_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic(0, 0, "", 1, <<EXPECT);
OkATopicOkBTopicOkTopic
EXPECT
}

sub test_no_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic(0, 0, "", 0, <<EXPECT);
EXPECT
}

sub test_no_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic(0, 0, ",", 1, <<EXPECT);
OkATopic,OkBTopic,OkTopic
EXPECT
}

sub test_no_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic(0, 0, ",", 0, <<EXPECT);
EXPECT
}
#####################

sub test_no_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic(0, 1, undef, 1, <<EXPECT);
OkATopic
OkBTopic
OkTopicFOOT
EXPECT
}

sub test_no_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic(0, 1, undef, 0, <<EXPECT);
EXPECT
}

sub test_no_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic(0, 1, "", 1, <<EXPECT);
OkATopicOkBTopicOkTopicFOOT
EXPECT
}

sub test_no_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic(0, 1, "", 0, <<EXPECT);
EXPECT
}

sub test_no_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic(0, 1, ",", 1, <<EXPECT);
OkATopic,OkBTopic,OkTopicFOOT
EXPECT
}

#####################

sub test_with_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic(1, 1, undef, 1, <<EXPECT);
HEADOkATopic
OkBTopic
OkTopicFOOT
EXPECT
}

sub test_with_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic(1, 1, undef, 0, <<EXPECT);
EXPECT
}

sub test_with_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic(1, 1, "", 1, <<EXPECT);
HEADOkATopicOkBTopicOkTopicFOOT
EXPECT
}

sub test_with_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic(1, 1, "", 0, <<EXPECT);
EXPECT
}

sub test_with_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic(1, 1, ",", 1, <<EXPECT);
HEADOkATopic,OkBTopic,OkTopicFOOT
EXPECT
}

sub test_with_header_with_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic(1, 1, ",", 0, <<EXPECT);
EXPECT
}

#####################

sub testtest_with_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic(1, 0, undef, 1, <<EXPECT);
HEADOkATopic
OkBTopic
OkTopic
EXPECT
}

sub test_with_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic(1, 0, undef, 0, <<EXPECT);
EXPECT
}

sub test_with_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic(1, 0, "", 1, <<EXPECT);
HEADOkATopicOkBTopicOkTopic
EXPECT
}

sub test_with_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic(1, 0, "", 0, <<EXPECT);
EXPECT
}

sub test_with_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic(1, 0, ",", 1, <<EXPECT);
HEADOkATopic,OkBTopic,OkTopic
EXPECT
}

sub test_with_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic(1, 0, ",", 0, <<EXPECT);
EXPECT
}

sub test_delayed_expansion {
    my $this = shift;
eval "require Foswiki::Macros::FORMAT";
    
    my $result = $Foswiki::Plugins::SESSION->FORMAT({
                                    _DEFAULT=>"WebHome,WebIndex, WebPreferences",
                                    format=>'$topic',
                                    separator=>", ",
                                }, $this->{test_topicObject});
    $this->assert_str_equals( <<EXPECT, $result."\n" );
WebHome, WebIndex, WebPreferences
EXPECT

    $result = $Foswiki::Plugins::SESSION->FORMAT({
                                    _DEFAULT=>"WebHome,WebIndex, WebPreferences",
                                    format=>'$percentWIKINAME$percent',
                                    separator=>", ",
                                }, $this->{test_topicObject});
    $this->assert_str_equals( <<EXPECT, $result."\n" );
%WIKINAME%, %WIKINAME%, %WIKINAME%
EXPECT

    $result = $Foswiki::Plugins::SESSION->FORMAT({
                                    _DEFAULT=>"WebHome,WebIndex, WebPreferences",
                                    header=>'$percentINCLUDE{Main.WebHome}$percent',
                                    footer=>'$percentINCLUDE{Main.WebHome}$percent',
                                    format=>'$topic',
                                    separator=>", ",
                                }, $this->{test_topicObject});
    $this->assert_str_equals( <<EXPECT, $result."\n" );
%INCLUDE{Main.WebHome}%WebHome, WebIndex, WebPreferences%INCLUDE{Main.WebHome}%
EXPECT

}

sub test_not_topics {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{",+&,@:{},!!," type="string" header="HEAD " footer=" FOOT" format="$index:($item)" separator=";"}%'
      );

    $this->assert_str_equals(
        "HEAD 1:();2:(+&);3:(\@:{});4:(!!) FOOT", $result );

    $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"A,B,C" type="string" format="$index:($item)" separator=";"}%'
      );

    $this->assert_str_equals(
        '1:(A);2:(B);3:(C)', $result );
        
#use all the topic based thingies and see what they do, so that anyone modifying this code has an idea of what they are in for.
    $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"A,B,C" type="string" format="$index:($item) - $web, $topic, $parent, $text, $locked,
$date, $isodate, $rev, $username, $wikiname, $wikiusername,
$createdate, $createusername, $createwikiname, $createwikiusername,
$summary, $changes, $formname, $formfield, $pattern, $count,
$ntopics, $nhits, $pager" separator=";"}%'
      );

    $this->assert_str_equals(
        '1:(A) - $web, $topic, $parent, $text, $locked,
$longdate, $iso, $rev, $username, $wikiname, $wikiusername,
01 Jan 1970 - 00:00, guest, WikiGuest, TemporarySEARCHUsersWeb.WikiGuest,
$summary, $changes, $formname, $formfield, $pattern, $count,
1, 1, $pager;2:(B) - $web, $topic, $parent, $text, $locked,
$longdate, $iso, $rev, $username, $wikiname, $wikiusername,
01 Jan 1970 - 00:00, guest, WikiGuest, TemporarySEARCHUsersWeb.WikiGuest,
$summary, $changes, $formname, $formfield, $pattern, $count,
2, 2, $pager;3:(C) - $web, $topic, $parent, $text, $locked,
$longdate, $iso, $rev, $username, $wikiname, $wikiusername,
01 Jan 1970 - 00:00, guest, WikiGuest, TemporarySEARCHUsersWeb.WikiGuest,
$summary, $changes, $formname, $formfield, $pattern, $count,
3, 3, $pager', $result );
}

#%STARTINCLUDE%| =$n= or =$n()= | New line. Use =$n()= if followed by alphanumeric character, e.g. write =Foo$n()Bar= instead of =Foo$nBar= |
#| =$nop= or =$nop()= | Is a "no operation". This token gets removed; useful for nested search |
#| =$quot= | Double quote (="=) (\" also works) |
#| =$percent= | Percent sign (=%=) (=$percnt= also works) |
#| =$dollar= | Dollar sign (=$=) |
#| =$lt= | Less than sign (=<=) |
#| =$gt= | Greater than sign (=>=) |
#| =$amp= | Ampersand (=&=) |
#| =$comma= | Comma (=,=) |
#%STOPINCLUDE%
sub test_standard_escapes {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{
        "OkATopic,OkBTopic,OkTopic" 
        header="RESULT: $comma" 
        footer="$amp"
        nonoise="on" 
        format="$topic" 
        separator="$quot"
}%'
      );

    $this->assert_str_equals(
        "RESULT: ,OkATopic\"OkBTopic\"OkTopic&", $result
    );
    
    #do the string version too - so long as there are no topic specific expansions, the output needs to be identical
    $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{
        "OkATopic,OkBTopic,OkTopic" 
        type="String"
        header="RESULT: $comma" 
        footer="$amp"
        nonoise="on" 
        format="$topic" 
        separator="$quot"
}%'
      );

    $this->assert_str_equals(
        "RESULT: ,OkATopic\"OkBTopic\"OkTopic&", $result
    );
}


sub test_Item9269 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{"OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic ($dollarntopics=$ntopics)" separator=","}%'
      );

    $this->assert_str_equals( 'OkATopic ($ntopics=1),OkBTopic ($ntopics=2),OkTopic ($ntopics=3)', $result );
}

#Item10888
sub test_subweb_web_token {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%FORMAT{ 
  "Mangroves/Bibliography.Lovelock_1993, Mangroves/Bibliography.Duke_2006, Mangroves/Bibliography.Boto_etal_1984" 
  format="$web.$topic" 
  separator=", "
  type="topic" 
}%');

    $this->assert_str_equals(
        "Mangroves/Bibliography.Lovelock_1993, Mangroves/Bibliography.Duke_2006, Mangroves/Bibliography.Boto_etal_1984", $result
    );
}

1;
