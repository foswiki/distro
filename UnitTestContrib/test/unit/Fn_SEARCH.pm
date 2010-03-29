use strict;
use warnings;

# tests for the correct expansion of SEARCH
# SMELL: this test is pathetic, becase SEARCH has dozens of untested modes

package Fn_SEARCH;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
use Assert;
use Foswiki::Search;
use Foswiki::Search::InfoCache;

sub new {
    my $self = shift()->SUPER::new( 'SEARCH', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OkTopic',
        "BLEEGLE blah/matchme.blah" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OkATopic',
        "BLEEGLE dontmatchme.blah" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OkBTopic',
        "BLEEGLE dont.matchmeblah" );
    $topicObject->save();
}

sub fixture_groups {
    my ( %salgs, %qalgs );
    foreach my $dir (@INC) {
        if ( opendir( D, "$dir/Foswiki/Store/SearchAlgorithms" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ /^(.*)\.pm$/;
                $alg = $1;
                $salgs{$alg} = 1;
            }
            closedir(D);
        }
        if ( opendir( D, "$dir/Foswiki/Store/QueryAlgorithms" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ /^(.*)\.pm$/;
                $alg = $1;
                $qalgs{$alg} = 1;
            }
            closedir(D);
        }
    }
    my @groups;
    foreach my $alg ( keys %salgs ) {
        my $fn = $alg . 'Search';
        push( @groups, $fn );
        next if ( defined(&$fn) );
        eval <<SUB;
sub $fn {
require Foswiki::Store::SearchAlgorithms::$alg;
\$Foswiki::cfg{Store}{SearchAlgorithm} = 'Foswiki::Store::SearchAlgorithms::$alg'; }
SUB
        die $@ if $@;
    }
    foreach my $alg ( keys %qalgs ) {
        my $fn = $alg . 'Query';
        push( @groups, $fn );
        next if ( defined(&$fn) );
        eval <<SUB;
sub $fn {
require Foswiki::Store::QueryAlgorithms::$alg;
\$Foswiki::cfg{Store}{QueryAlgorithm} = 'Foswiki::Store::QueryAlgorithms::$alg'; }
SUB
        die $@ if $@;
    }

    return \@groups;
}

sub loadExtraConfig {
    my $this = shift; # the Test::Unit::TestCase object
    $this->SUPER::loadExtraConfig();
     
    #enable the MongoDBPlugin which keeps the mongodb uptodate with topics changes onsave
    #TODO: make conditional - or figure out how to force this in the MongoDB search and query algo's
    $Foswiki::cfg{Plugins}{MongoDBPlugin}{Module} = 'Foswiki::Plugins::MongoDBPlugin';
    $Foswiki::cfg{Plugins}{MongoDBPlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{MongoDBPlugin}{EnableOnSaveUpdates} = 1;
}


sub verify_simple {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" topic="OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_Item4692 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"BLEEGLE" topic="NonExistant" nonoise="on" format="$topic"}%');

    $this->assert_str_equals( '', $result );
}

sub verify_angleb {
    my $this = shift;

    # Test regex with \< and \>, used in rename searches
    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\<matc[h]me\>" type="regex" topic="OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
}

sub verify_topicName {
    my $this = shift;

    # Test topic name search

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Ok.*" type="regex" scope="topic" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_regex_trivial {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_word {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"blah" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkATopic/, $result );

    # 'blah' is in OkATopic, but not as a word
    $this->assert_does_not_match( qr/OkBTopic/, $result, $result );
}

#####################
sub _septic {
    my ( $this, $head, $foot, $sep, $results, $expected ) = @_;
    my $str = $results ? '*Topic' : 'Septic';
    $head = $head        ? 'header="HEAD"'      : '';
    $foot = $foot        ? 'footer="FOOT"'      : '';
    $sep  = defined $sep ? "separator=\"$sep\"" : '';
    my $result =
      $this->{test_topicObject}->expandMacros(
"%SEARCH{\"name~'$str'\" type=\"query\" nosearch=\"on\" nosummary=\"on\" nototal=\"on\" format=\"\$topic\" $head $foot $sep}%"
      );
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#####################

sub verify_no_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, undef, 1, <<EXPECT);
OkATopic
OkBTopic
OkTopic
EXPECT
}

sub verify_no_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 0, undef, 0, <<EXPECT);
EXPECT
}

sub verify_no_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, "", 1, <<EXPECT);
OkATopicOkBTopicOkTopic
EXPECT
}

sub verify_no_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 0, "", 0, <<EXPECT);
EXPECT
}

sub verify_no_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, ",", 1, <<EXPECT);
OkATopic,OkBTopic,OkTopic
EXPECT
}

sub verify_no_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 0, ",", 0, <<EXPECT);
EXPECT
}
#####################

sub verify_no_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 1, undef, 1, <<EXPECT);
OkATopic
OkBTopic
OkTopic
FOOT
EXPECT
}

sub verify_no_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 1, undef, 0, <<EXPECT);
EXPECT
}

sub verify_no_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 1, "", 1, <<EXPECT);
OkATopicOkBTopicOkTopicFOOT
EXPECT
}

sub verify_no_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 1, "", 0, <<EXPECT);
EXPECT
}

sub verify_no_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 1, ",", 1, <<EXPECT);
OkATopic,OkBTopic,OkTopic,FOOT
EXPECT
}

#####################

sub verify_with_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 1, undef, 1, <<EXPECT);
HEAD
OkATopic
OkBTopic
OkTopic
FOOT
EXPECT
}

sub verify_with_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 1, undef, 0, <<EXPECT);
EXPECT
}

sub verify_with_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 1, "", 1, <<EXPECT);
HEAD
OkATopicOkBTopicOkTopicFOOT
EXPECT
}

sub verify_with_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 1, "", 0, <<EXPECT);
EXPECT
}

sub verify_with_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 1, ",", 1, <<EXPECT);
HEAD
OkATopic,OkBTopic,OkTopic,FOOT
EXPECT
}

sub verify_with_header_with_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 1, ",", 0, <<EXPECT);
EXPECT
}

#####################

sub verify_with_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 0, undef, 1, <<EXPECT);
HEAD
OkATopic
OkBTopic
OkTopic
EXPECT
}

sub verify_with_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 0, undef, 0, <<EXPECT);
EXPECT
}

sub verify_with_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 0, "", 1, <<EXPECT);
HEAD
OkATopicOkBTopicOkTopic
EXPECT
}

sub verify_with_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 0, "", 0, <<EXPECT);
EXPECT
}

sub verify_with_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 0, ",", 1, <<EXPECT);
HEAD
OkATopic,OkBTopic,OkTopic
EXPECT
}

sub verify_with_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 0, ",", 0, <<EXPECT);
EXPECT
}

#####################

sub verify_footer_with_ntopics {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'*Topic\'" type="query"  nonoise="on" footer="Total found: $ntopics" format="$topic"}%'
      );

    $this->assert_str_equals(
        join( "\n", sort qw(OkATopic OkBTopic OkTopic) ) . "\nTotal found: 3",
        $result );
}

sub verify_multiple_and_footer_with_ntopics_and_nhits {
    my $this = shift;

    $this->set_up_for_formatted_search();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Bullet" type="regex" multiple="on" nonoise="on" footer="Total found: $ntopics, Hits: $nhits" format="$text - $nhits"}%'
      );

    $this->assert_str_equals(
"   * Bullet 1 - 1\n   * Bullet 2 - 2\n   * Bullet 3 - 3\n   * Bullet 4 - 4\nTotal found: 1, Hits: 4",
        $result
    );
}

sub verify_footer_with_ntopics_empty_format {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'*Topic\'" type="query"  nonoise="on" footer="Total found: $ntopics" format="" separator=""}%'
      );

    $this->assert_str_equals( "Total found: 3", $result );
}

sub verify_regex_match {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_literal_match {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_keyword_match {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_word_match {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
}

sub verify_regex_matchme {
    my $this = shift;

    # ---------------------
    # Search string 'matchme'
    # regex

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_literal_matchme {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_keyword_matchme {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

}

sub verify_word_matchme {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_minus_regex {
    my $this = shift;

    # ---------------------
    # Search string 'matchme -dont'
    # regex

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
}

sub verify_minus_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_minus_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_minus_word {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_slash_regex {
    my $this = shift;

    # ---------------------
    # Search string 'blah/matchme.blah'
    # regex

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_slash_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_slash_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_slash_word {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_quote_regex {
    my $this = shift;

    # ---------------------
    # Search string 'BLEEGLE dont'
    # regex

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );

}

sub verify_quote_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );

}

sub verify_quote_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

}

sub verify_quote_word {
    my $this = shift;

    # word
    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
}

sub verify_SEARCH_3860 {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros( <<'HERE');
%SEARCH{"BLEEGLE" topic="OkTopic" format="$wikiname $wikiusername" nonoise="on" }%
HERE
    my $wn = $this->{session}->{users}->getWikiName( $this->{session}->{user} );
    $this->assert_str_equals( "$wn $this->{users_web}.$wn\n", $result );

    $result = $this->{test_topicObject}->expandMacros( <<'HERE');
%SEARCH{"BLEEGLE" topic="OkTopic" format="$createwikiname $createwikiusername" nonoise="on" }%
HERE
    $this->assert_str_equals( "$wn $this->{users_web}.$wn\n", $result );
}

sub verify_search_empty_regex {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="regex" scope="text" nonoise="on" format="$topic"}%');
    $this->assert_str_equals( "", $result );
}

sub verify_search_empty_literal {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_empty_keyword {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_empty_word {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="word" scope="text" nonoise="on" format="$topic"}%');
    $this->assert_str_equals( "", $result );
}

sub verify_search_numpty_regex {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-\)" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_numpty_literal {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_numpty_keyword {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_numpty_word {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
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

sub verify_formatted_search_summary_with_exclamation_marks {
    my $this    = shift;
    my $session = $this->{session};

    $this->set_up_for_formatted_search();
    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Anna" topic="FormattedSearchTopic1" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="$summary"}%'
      );
    $actual = $this->{test_topicObject}->renderTML($actual);
    $expected =
'<nop>MichaelAnchor and <nop>AnnaAnchor lived in Skagen in <nop>DenmarkEurope!. There is a very nice museum you can visit!';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Anna" topic="FormattedSearchTopic1" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="$formfield(Name)"}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>AnnaAnchor';
    $this->assert_str_equals( $expected, $actual );
}

# Item8718
sub verify_formatted_search_with_exclamation_marks_inside_bracket_link {
    my $this    = shift;
    my $session = $this->{session};

    $this->set_up_for_formatted_search();
    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Anna" topic="FormattedSearchTopic1" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="[[$web.$topic][$formfield(Name)]]"}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $actual = _cut_the_crap($actual);
    $expected = '<a href=""><nop>AnnaAnchor</a>';
    
    $this->assert_str_equals( $expected, $actual );
}

sub verify_METASEARCH {
    my $this    = shift;
    my $session = $this->{session};

    $this->set_up_for_formatted_search();
    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%METASEARCH{type="topicmoved" topic="FormattedSearchTopic1" title="This topic used to exist and was moved to: "}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = 'This topic used to exist and was moved to: ';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%METASEARCH{type="parent" topic="TestCaseAutoFormattedSearch" title="Children: "}%'
      );
    $actual = $this->{test_topicObject}->renderTML($actual);
    $expected =
      $this->{test_topicObject}->renderTML('Children: FormattedSearchTopic1 ');
    $this->assert_str_equals( $expected, $actual );
}

sub set_up_for_queries {
    my $this = shift;
    my $text = <<'HERE';
%META:TOPICINFO{author="TopicUserMapping_guest" date="1178612772" format="1.1" version="1.1"}%
%META:TOPICPARENT{name="WebHome"}%
something before. Another
This is QueryTopic FURTLE
somethig after
%META:FORM{name="TestForm"}%
%META:FIELD{name="Field1" attributes="H" title="A Field" value="A Field"}%
%META:FIELD{name="Field2" attributes="" title="Another Field" value="2"}%
%META:FIELD{name="Firstname" attributes="" title="First Name" value="Emma"}%
%META:FIELD{name="Lastname" attributes="" title="First Name" value="Peel"}%
%META:TOPICMOVED{by="TopicUserMapping_guest" date="1176311052" from="Sandbox.TestETP" to="Sandbox.TestEarlyTimeProtocol"}%
%META:FILEATTACHMENT{name="README" comment="Blah Blah" date="1157965062" size="5504"}%
HERE
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'QueryTopic',
        $text );
    $topicObject->save();

    $text = <<'HERE';
%META:TOPICINFO{author="TopicUserMapping_guest" date="12" format="1.1" version="1.2"}%
first line
This is QueryTopicTwo SMONG
third line
%META:TOPICPARENT{name="QueryTopic"}%
%META:FORM{name="TestyForm"}%
%META:FIELD{name="FieldA" attributes="H" title="B Field" value="7"}%
%META:FIELD{name="FieldB" attributes="" title="Banother Field" value="8"}%
%META:FIELD{name="Firstname" attributes="" title="Pre Name" value="John"}%
%META:FIELD{name="Lastname" attributes="" title="Post Name" value="Peel"}%
%META:FIELD{name="form" attributes="" title="Blah" value="form good"}%
%META:FIELD{name="FORM" attributes="" title="Blah" value="FORM GOOD"}%
%META:FILEATTACHMENT{name="porn.gif" comment="Cor" date="15062" size="15504"}%
%META:FILEATTACHMENT{name="flib.xml" comment="Cor" date="1157965062" size="1"}%
HERE
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'QueryTopicTwo',
        $text );
    $topicObject->save();

    $this->{session}->finish();
    my $query = new Unit::Request("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->{session} = new Foswiki( undef, $query );
    $this->assert_str_equals( $this->{test_web}, $this->{session}->{webName} );
    $Foswiki::Plugins::SESSION = $this->{session};

    $this->{test_topicObject} =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
}

# NOTE: most query ops are tested in Fn_IF.pm, and are not re-tested here

my $stdCrap = 'type="query" nonoise="on" format="$topic" separator=" "}%';

sub verify_parentQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"parent.name=\'WebHome\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_attachmentSizeQuery1 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"attachments[size > 0]"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic QueryTopicTwo', $result );
}

sub verify_attachmentSizeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"META:FILEATTACHMENT[size > 10000]"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_indexQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"attachments[name=\'flib.xml\']"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_gropeQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic QueryTopicTwo', $result );
}

sub verify_4580Query1 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"text ~ \'*SMONG*\' AND Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_4580Query2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"text ~ \'*FURTLE*\' AND Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_gropeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic QueryTopicTwo', $result );
}

sub verify_formQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"form.name=\'TestyForm\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_formQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestForm"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_formQuery3 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"TestForm[name=\'Field1\'].value=\'A Field\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_formQuery4 {
    my $this = shift;

    if (   $Foswiki::cfg{OS} eq 'WINDOWS'
        && $Foswiki::cfg{DetailedOS} ne 'cygwin' )
    {
        $this->expect_failure();
        $this->annotate("THIS IS WINDOWS; Test will fail because of Item1072");
    }
    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestForm.Field1=\'A Field\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_formQuery5 {
    my $this = shift;

    if (   $Foswiki::cfg{OS} eq 'WINDOWS'
        && $Foswiki::cfg{DetailedOS} ne 'cygwin' )
    {
        $this->expect_failure();
        $this->annotate("THIS IS WINDOWS; Test will fail because of Item1072");
    }

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestyForm.form=\'form good\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestyForm.FORM=\'FORM GOOD\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_refQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"parent.name/(Firstname ~ \'*mm?\' AND Field2=2)"'
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

# make sure syntax errors are handled cleanly. All the error cases thrown by
# the infix parser are tested more thoroughly in Fn_IF, and don't have to
# be re-tested here.
sub test_badQuery1 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros( '%SEARCH{"A * B"' . $stdCrap );
    $this->assert_matches( qr/Error was: Syntax error in 'A \* B' at ' \* B'/s,
        $result );
}

# Compare performance of an RE versus a query. Only enable this if you are
# interested in benchmarking.
sub benchmarktest_largeQuery {
    my $this = shift;

    # Generate 1000 topics
    # half (500) of these match the first term of the AND
    # 100 match the second
    # 10 match the third
    # 1 matches the fourth

    for my $n ( 1 .. 21 ) {
        my $vA = ( $n <= 500 ) ? 'A' : 'B';
        my $vB = ( $n <= 100 ) ? 'A' : 'B';
        my $vC = ( $n <= 10 )  ? 'A' : 'B';
        my $vD = ( $n == 1 )   ? 'A' : 'B';
        my $vE = ( $n == 2 )   ? 'A' : 'B';
        my $text = <<HERE;
%META:TOPICINFO{author="TopicUserMapping_guest" date="12" format="1.1" version="1.2"}%
---+ Progressive Sexuality
A Symbol Interpreted In American Architecture. Meta-Physics Of Marxism & Poverty In The American Landscape. Exploration Of Crime In Mexican Sculptures: A Study Seen In American Literature. Brief Survey Of Suicide In Italian Art: The Big Picture. Special Studies In Bisexual Female Architecture. Brief Survey Of Suicide In Polytheistic Literature: Analysis, Analysis, and Critical Thinking. Radical Paganism: Modern Theories. Liberal Mexican Religion In The Modern Age. Selected Topics In Global Warming: $vD Policy In Modern America. Survey Of The Aesthetic Minority Revolution In The American Landscape. Populist Perspectives: Myth & Reality. Ethnicity In Modern America: The Bisexual Latino Condition. Postmodern Marxism In Modern America. Female Literature As A Progressive Genre. Horror & Life In Recent Times. The Universe Of Female Values In The Postmodern Era.

---++ Work, Politics, And Conflict In European Drama: A Symbol Interpreted In 20th Century Poetry
Sexuality & Socialism In Modern Society. Special Studies In Early Egyptian Art: A Study Of Globalism In The United States. Meta-Physics Of Synchronized Swimming: The Baxter-Floyd Principle At Work. Ad-Hoc Investigation Of Sex In Middle Eastern Art: Contemporary Theories. Concepts In Eastern Mexican Folklore. The Liberated Dimension Of Western Minority Mythology. French Art Interpretation: A Figure Interpreted In American Drama

---+ Theories Of Liberal Pre-Cubism & The Crowell Law.
We are committed to enhance vertical sub-functionalities and skill sets. Our function is to competently reinvent our mega-relationships. Our responsibility is to expertly engineer content. Our obligation is to continue to zealously simplify our customer-centric paradigms as part of our five-year plan to successfully market an overhyped more expensive line of products and produce more dividends for our serfs. $vA It is our mission to optimize progressive schemas and supply-chains to better serve the country. We are committed to astutely deliver our net-niches, user-centric face time, and assets in order to dominate the economy. It is our goal to conveniently facilitate our e-paradigms, our frictionless skill sets, and our architectures to shore up revenue for our workers. Our goal is to work towards skillfully enabling catalysts for metrics.

We resolve to endeavor to synthesize our sub-partnerships in order that we may intelligently unleash bleeding-edge total quality management as part of our master plan to burgeon our bottom line. It is our business to work to enhance our initiatives in order that we may take $vB over the nation and take over the country. It's our task to reinvent massively-parallel relationships. We execute a strategic plan to quickly facilitate our niches and enthusiastically maximize our extensible perspectives.

Our obligation is to work to spearhead cutting-edge portals so that hopefully we may successfully market an overhyped poor product line.

We have committed to work to effectively facilitate global e-channels as part of a larger $vC strategy to create a higher quality product and create a lot of bucks. Our duty is to work to empower our revolutionary functionalities and simplify our idiot-proof synergies as a component of our plan to beat the snot out of our enemies. We resolve to engage our mega-eyeballs, our e-bandwidth, and intuitive face time in order to earn a lot of scratch. It's our obligation to generate our niches.

---+ It is our job to strive to simplify our bandwidth.
We have committed to enable customer-centric supply-chains and our mega-channels as part of our business plan to meet the wants of our valued customers.
We have committed to take steps towards $vE reinventing our cyber-key players and harnessing frictionless net-communities so that hopefully we may better serve our customers.
%META:FORM{name="TestForm"}%
%META:FIELD{name="FieldA" attributes="" title="Banother Field" value="$vA"}%
%META:FIELD{name="FieldB" attributes="" title="Banother Field" value="$vB"}%
%META:FIELD{name="FieldC" attributes="" title="Banother Field" value="$vC"}%
%META:FIELD{name="FieldD" attributes="" title="Banother Field" value="$vD"}%
%META:FIELD{name="FieldE" attributes="" title="Banother Field" value="$vE"}%
HERE
        my $topicObject =
          Foswiki::Meta->new( $this->{session}, $this->{test_web},
            "QueryTopic$n", $text );
        $topicObject->save();
    }
    require Benchmark;

    # Search using a regular expression
    my $start = new Benchmark;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"^[%]META:FIELD{name=\"FieldA\".*\bvalue=\"A\";^[%]META:FIELD{name=\"FieldB\".*\bvalue=\"A\";^[%]META:FIELD{name=\"FieldC\".*\bvalue=\"A\";^[%]META:FIELD{name=\"FieldD\".*\bvalue=\"A\"|^[%]META:FIELD{name=\"FieldE\".*\bvalue=\"A\"" type="regex" nonoise="on" format="$topic" separator=" "}%'
      );
    my $retime = Benchmark::timediff( new Benchmark, $start );
    $this->assert_str_equals( 'QueryTopic1 QueryTopic2', $result );

    # Repeat using a query
    $start = new Benchmark;
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"FieldA=\'A\' AND FieldB=\'A\' AND FieldC=\'A\' AND (FieldD=\'A\' OR FieldE=\'A\')" type="query" nonoise="on" format="$topic" separator=" "}%'
      );
    my $querytime = Benchmark::timediff( new Benchmark, $start );
    $this->assert_str_equals( 'QueryTopic1 QueryTopic2', $result );
    print STDERR "Query " . Benchmark::timestr($querytime),
      "\nRE " . Benchmark::timestr($retime), "\n";
}

sub verify_4347 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
"%SEARCH{\"$this->{test_topic}\" scope=\"topic\" nonoise=\"on\" format=\"\$formfield(Blah)\"}%"
      );
    $this->assert_str_equals( '', $result );
}

sub verify_likeQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*QueryTopicTwo*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result = $topicObject->expandMacros(
        '%SEARCH{"text ~ \'*QueryTopicTwo*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

}

sub verify_likeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*QueryTopicTwo*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*QueryTopicTwo*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*Notinthetopics*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( '', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*before. Another*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub test_pattern {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" topic="OkATopic,OkBTopic,OkTopic" nonoise="on" format="X$pattern(.*?BLEEGLE (.*?)blah.*)Y"}%'
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
'%SEARCH{"BLEEGLE" topic="OkATopic,OkBTopic,OkTopic" nonoise="on" format="X$pattern(.*?BL(??{\'E\' x 2})GLE( .*?)blah.*)Y"}%'
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
sub verify_formatOfLinks {
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
        '%SEARCH{"Item977" scope="topic" nonoise="on" format="$summary"}%');

    $this->assert_str_equals( 'Apache Apache is the well known web server.',
        $result );

#TODO: these test should move to a proper testing of Render.pm - will happen during
#extractFormat feature
    $this->assert_str_equals(
        'Apache is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
'Apache is the [[http://www.apache.org/httpd/][well known web server]].'
        )
    );

    #test a few others to try to not break things
    $this->assert_str_equals(
        'Apache is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
'Apache is the [[http://www.apache.org/httpd/ well known web server]].'
        )
    );
    $this->assert_str_equals(
        'Apache is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
            'Apache is the [[ApacheServer][well known web server]].')
    );

    #SMELL: an unexpected result :/
    $this->assert_str_equals( 'Apache is the   well known web server  .',
        $this->{session}->{renderer}
          ->TML2PlainText('Apache is the [[well known web server]].') );
    $this->assert_str_equals( 'Apache is the well known web server.',
        $this->{session}->{renderer}
          ->TML2PlainText('Apache is the well known web server.') );

}

sub _getTopicList {
    my $this    = shift;
    my $web     = shift;
    my $options = shift;

    #    my $options = {
    #        casesensitive  => $caseSensitive,
    #        wordboundaries => $wordBoundaries,
    #        includeTopics  => $topic,
    #        excludeTopics  => $excludeTopic,
    #    };

    my $webObject = Foswiki::Meta->new( $this->{session}, $web );

    # Run the search on topics in this web
    my $search = $this->{session}->search();
    my $iter =
      Foswiki::Search::InfoCache::getTopicListIterator( $webObject, $options );

    ASSERT( UNIVERSAL::isa( $iter, 'Foswiki::Iterator' ) ) if DEBUG;
    my @topicList = ();
    while ( my $t = $iter->next() ) {
        push( @topicList, $t );
    }

    return \@topicList;
}

sub test_getTopicList {
    my $this = shift;

    #no topics specified..
    $this->assert_deep_equals(
        [
            'OkATopic', 'OkBTopic',
            'OkTopic',  'TestTopicSEARCH',
            'WebPreferences'
        ],
        $this->_getTopicList( $this->{test_web}, {} ),
        'no filters, all topics in test_web'
    );
    $this->assert_deep_equals(
        [
            'WebAtom',           'WebChanges',
            'WebCreateNewTopic', 'WebHome',
            'WebIndex',          'WebLeftBar',
            'WebNotify',         'WebPreferences',
            'WebRss',            'WebSearch',
            'WebSearchAdvanced', 'WebStatistics',
            'WebTopicList'
        ],
        $this->_getTopicList( '_default', {} ),
        'no filters, all topics in test_web'
    );

    #use wildcards
    $this->assert_deep_equals(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->_getTopicList( $this->{test_web}, { includeTopics => 'Ok*' } ),
        'comma separated list'
    );
    $this->assert_deep_equals(
        [
            'WebAtom',           'WebChanges',
            'WebCreateNewTopic', 'WebHome',
            'WebIndex',          'WebLeftBar',
            'WebNotify',         'WebPreferences',
            'WebRss',            'WebSearch',
            'WebSearchAdvanced', 'WebStatistics',
            'WebTopicList'
        ],
        $this->_getTopicList( '_default', { includeTopics => 'Web*' } ),
        'no filters, all topics in test_web'
    );

    #comma separated list specifed for inclusion
    $this->assert_deep_equals(
        [ 'TestTopicSEARCH', 'OkTopic' ],
        $this->_getTopicList(
            $this->{test_web},
            { includeTopics => 'TestTopicSEARCH,OkTopic,NoSuchTopic' }
        ),
        'comma separated list'
    );
    $this->assert_deep_equals(
        [ 'WebStatistics', 'WebCreateNewTopic' ],
        $this->_getTopicList(
            '_default',
            {
                includeTopics => 'WebStatistics, WebCreateNewTopic, NoSuchTopic'
            }
        ),
        'no filters, all topics in test_web'
    );

    #excludes
    $this->assert_deep_equals(
        [ 'OkATopic', 'OkTopic', 'TestTopicSEARCH', 'WebPreferences' ],
        $this->_getTopicList(
            $this->{test_web}, { excludeTopics => 'NoSuchTopic,OkBTopic' }
        ),
        'no filters, all topics in test_web'
    );
    $this->assert_deep_equals(
        [
            'WebAtom',           'WebChanges',
            'WebCreateNewTopic', 'WebHome',
            'WebIndex',          'WebLeftBar',
            'WebNotify',         'WebPreferences',
            'WebRss',            'WebSearchAdvanced',
            'WebStatistics',     'WebTopicList'
        ],
        $this->_getTopicList( '_default', { excludeTopics => 'WebSearch' } ),
        'no filters, all topics in test_web'
    );

    #Talk about missing alot of tests
    $this->assert_deep_equals(
        [
            'OkATopic', 'OkBTopic',
            'OkTopic',  'TestTopicSEARCH',
            'WebPreferences'
        ],
        $this->_getTopicList( $this->{test_web}, { includeTopics => '*' } ),
        'all topics, using wildcard'
    );
    $this->assert_deep_equals(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->_getTopicList( $this->{test_web}, { includeTopics => 'Ok*' } ),
        'Ok* topics, using wildcard'
    );
    $this->assert_deep_equals(
        [],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'ok*',
                casesensitive => 1
            }
        ),
        'case sensitive ok* topics, using wildcard'
    );
    $this->assert_deep_equals(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'ok*',
                casesensitive => 0
            }
        ),
        'case insensitive ok* topics, using wildcard'
    );
    
    #unless ($^O eq 'darwin') {
        # this test won't work on Mac OS X
        $this->assert_deep_equals(
            [],
            $this->_getTopicList(
                $this->{test_web},
                {
                    includeTopics => 'okatopic',
                    casesensitive => 1
                }
            ),
            'case sensitive okatopic topic 1'
        );
    #}
    
    $this->assert_deep_equals(
        ['OkATopic'],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'okatopic',
                casesensitive => 0
            }
        ),
        'case insensitive okatopic topic'
    );
    ##### same again, with excludes.
    $this->assert_deep_equals(
        [
            'OkATopic', 'OkBTopic',
            'OkTopic',  'TestTopicSEARCH',
            'WebPreferences'
        ],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => '*',
                excludeTopics => 'web*'
            }
        ),
        'all topics, using wildcard'
    );
    $this->assert_deep_equals(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'Ok*',
                excludeTopics => 'okatopic'
            }
        ),
        'Ok* topics, using wildcard'
    );
    $this->assert_deep_equals(
        [],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'ok*',
                excludeTopics => 'WebPreferences',
                casesensitive => 1
            }
        ),
        'case sensitive ok* topics, using wildcard'
    );
    $this->assert_deep_equals(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'ok*',
                excludeTopics => '',
                casesensitive => 0
            }
        ),
        'case insensitive ok* topics, using wildcard'
    );

    $this->assert_deep_equals(
        [ 'OkBTopic', 'OkTopic' ],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'Ok*',
                excludeTopics => '*ATopic',
                casesensitive => 1
            }
        ),
        'case sensitive okatopic topic 2'
    );

    $this->assert_deep_equals(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'Ok*',
                excludeTopics => '*atopic',
                casesensitive => 1
            }
        ),
        'case sensitive okatopic topic 3'
    );

    $this->assert_deep_equals(
        [ 'OkBTopic', 'OkTopic' ],
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'ok*topic',
                excludeTopics => 'okatopic',
                casesensitive => 0
            }
        ),
        'case insensitive okatopic topic'
    );

}

sub verify_casesensitivesetting {
    my $this    = shift;
    my $session = $this->{session};

    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic,<nop>TestTopicSEARCH';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"bleegle" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" type="regex" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic,<nop>TestTopicSEARCH';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"bleegle" type="regex" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic,<nop>TestTopicSEARCH';
    $this->assert_str_equals( $expected, $actual );

    #topic scope
    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Ok" type="regex" scope="topic" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"ok" type="regex" scope="topic" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Ok" type="regex" scope="topic" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"ok" type="regex" scope="topic" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic';
    $this->assert_str_equals( $expected, $actual );

}

sub verify_Item6082_Search {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm',
        <<'FORM');
| *Name*         | *Type* | *Size* | *Value*   | *Tooltip message* | *Attributes* |
| Why | text | 32 | | Mandatory field | M |
| Ecks | select | 1 | %SEARCH{"TestForm.Ecks~'Blah*'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}% | | |
FORM
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'SplodgeOne',
        <<FORM);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Ecks" attributes="" title="X" value="Blah"}%
FORM
    $topicObject->save();

    my $actual = $topicObject->expandMacros(
'%SEARCH{"TestForm.Ecks~\'Blah*\'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}%'
    );
    my $expected = 'SplodgeOne;Blah';
    $this->assert_str_equals( $expected, $actual );

}

sub verify_quotemeta {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm',
        <<'FORM');
| *Name*         | *Type* | *Size* | *Value*   | *Tooltip message* | *Attributes* |
| Why | text | 32 | | Mandatory field | M |
| Ecks | select | 1 | %SEARCH{"TestForm.Ecks~'Blah*'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}% | | |
FORM
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'SplodgeOne',
        <<FORM);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Ecks" attributes="" title="X" value="Blah"}%
FORM
    $topicObject->save();

    my $actual = $topicObject->expandMacros(
'%SEARCH{"TestForm.Ecks~\'Blah*\'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}%'
    );
    my $expected = 'SplodgeOne;Blah';
    $this->assert_str_equals( $expected, $actual );

}

sub verify_Search_expression {

    #make sure perl-y characters in SEARCH expressions are escaped well enough
    my $this = shift;

    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{test_web} );

    my $actual = $webObject->expandMacros(
        '%SEARCH{"TestForm.Ecks~\'Bl>ah*\'" type="query" nototal="on"}%' );
    my $expected = <<'HERE';
<span class="patternSearched">Searched: <b><noautolink>TestForm.Ecks~'Bl&gt;ah*'</noautolink></b></span><span id="foswikiNumberOfResultsContainer"></span><span id="foswikiModifySearchContainer"></span>
HERE
    $this->assert_str_equals( $expected, $actual );

    $actual = $webObject->expandMacros(
        '%SEARCH{"TestForm.Ecks = \'B/lah*\'" type="query" nototal="on"}%' );
    $expected = <<'HERE';
<span class="patternSearched">Searched: <b><noautolink>TestForm.Ecks = 'B/lah*'</noautolink></b></span><span id="foswikiNumberOfResultsContainer"></span><span id="foswikiModifySearchContainer"></span>
HERE
    $this->assert_str_equals( $expected, $actual );
}

#####################
#and again for multiple webs. :(
#TODO: rewrite using named params for more flexibility
#need summary, and multiple
sub _multiWebSeptic {
    my ( $this, $head, $foot, $sep, $results, $expected ) = @_;
    my $str = $results ? '*Preferences' : 'Septic';
    $head = $head        ? 'header="HEAD($web)"'            : '';
    $foot = $foot        ? 'footer="FOOT($ntopics,$nhits)"' : '';
    $sep  = defined $sep ? "separator=\"$sep\""             : '';
    my $result = $this->{test_topicObject}->expandMacros(
        "%SEARCH{\"name~'$str'\" 
            web=\"System,Main\" 
            type=\"query\" 
            nosearch=\"on\" 
            nosummary=\"on\" 
            nototal=\"on\" 
            format=\"\$topic\" 
            $head $foot $sep }%"
    );
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#####################

sub verify_multiWeb_no_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, undef, 1, <<EXPECT);
DefaultPreferences
WebPreferences
SitePreferences
WebPreferences
EXPECT
}

sub verify_multiWeb_no_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, undef, 0, <<EXPECT);
EXPECT
}

sub verify_multiWeb_no_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, "", 1, <<EXPECT);
DefaultPreferencesWebPreferencesSitePreferencesWebPreferences
EXPECT
}

sub verify_multiWeb_no_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, "", 0, <<EXPECT);
EXPECT
}

sub verify_multiWeb_no_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, ",", 1, <<EXPECT);
DefaultPreferences,WebPreferences,SitePreferences,WebPreferences
EXPECT
}

sub verify_multiWeb_no_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, ",", 0, <<EXPECT);
EXPECT
}
#####################

sub verify_multiWeb_no_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, undef, 1, <<EXPECT);
DefaultPreferences
WebPreferences
FOOT(2,2)SitePreferences
WebPreferences
FOOT(2,2)
EXPECT
}

sub verify_multiWeb_no_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, undef, 0, <<EXPECT);
EXPECT
}

sub verify_multiWeb_no_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, "", 1, <<EXPECT);
DefaultPreferencesWebPreferencesFOOT(2,2)SitePreferencesWebPreferencesFOOT(2,2)
EXPECT
}

sub verify_multiWeb_no_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, "", 0, <<EXPECT);
EXPECT
}

sub verify_multiWeb_no_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, ",", 1, <<EXPECT);
DefaultPreferences,WebPreferences,FOOT(2,2)SitePreferences,WebPreferences,FOOT(2,2)
EXPECT
}

#####################

sub verify_multiWeb_with_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, undef, 1, <<EXPECT);
HEAD(System)
DefaultPreferences
WebPreferences
FOOT(2,2)HEAD(Main)
SitePreferences
WebPreferences
FOOT(2,2)
EXPECT
}

sub verify_multiWeb_with_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, undef, 0, <<EXPECT);
EXPECT
}

sub verify_multiWeb_with_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, "", 1, <<EXPECT);
HEAD(System)
DefaultPreferencesWebPreferencesFOOT(2,2)HEAD(Main)
SitePreferencesWebPreferencesFOOT(2,2)
EXPECT
}

sub verify_multiWeb_with_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, "", 0, <<EXPECT);
EXPECT
}

sub verify_multiWeb_with_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, ",", 1, <<EXPECT);
HEAD(System)
DefaultPreferences,WebPreferences,FOOT(2,2)HEAD(Main)
SitePreferences,WebPreferences,FOOT(2,2)
EXPECT
}

sub verify_multiWeb_with_header_with_footer_with_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, ",", 0, <<EXPECT);
EXPECT
}

#####################

sub verify_multiWeb_with_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, undef, 1, <<EXPECT);
HEAD(System)
DefaultPreferences
WebPreferences
HEAD(Main)
SitePreferences
WebPreferences
EXPECT
}

sub verify_multiWeb_with_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, undef, 0, <<EXPECT);
EXPECT
}

sub verify_multiWeb_with_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, "", 1, <<EXPECT);
HEAD(System)
DefaultPreferencesWebPreferencesHEAD(Main)
SitePreferencesWebPreferences
EXPECT
}

sub verify_multiWeb_with_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, "", 0, <<EXPECT);
EXPECT
}

sub verify_multiWeb_with_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, ",", 1, <<EXPECT);
HEAD(System)
DefaultPreferences,WebPreferences,HEAD(Main)
SitePreferences,WebPreferences
EXPECT
}

sub verify_multiWeb_with_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, ",", 0, <<EXPECT);
EXPECT
}

#Item1992: calling Foswiki::Search::_makeTopicPattern repeatedly made a big mess.
sub verify_web_and_topic_expansion {
    my $this   = shift;
    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
                "web" 
                type="text"
                web="System,Main,Sandbox"
                topic="WebHome,WebPreferences"
                scope="text" 
                nonoise="on" 
                format="$web.$topic"
                footer="FOOT($ntopics,$nhits)"
        }%'
    );
    my $expected = <<EXPECT;
System.WebHome
System.WebPreferences
FOOT(2,2)Main.WebHome
Main.WebPreferences
FOOT(2,2)Sandbox.WebHome
Sandbox.WebPreferences
FOOT(2,2)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#####################
# PAGING
sub verify_paging_three_webs_first_five {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="1"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
System.WebChanges
System.WebHome
System.WebIndex
System.WebPreferences
FOOT(4,4)Main.WebChanges
FOOT(1,1)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub verify_paging_three_webs_second_five {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="2"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(3,3)Sandbox.WebChanges
Sandbox.WebHome
FOOT(2,2)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub verify_paging_three_webs_third_five {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="3"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(2,2)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub verify_paging_three_webs_fourth_five {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="4"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub verify_paging_three_webs_way_too_far {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="99"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#------------------------------------
# PAGING with limit= does weird things.
sub verify_paging_with_limit_first_five {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="1"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
System.WebChanges
System.WebHome
System.WebIndex
FOOT(3,3)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub verify_paging_with_limit_second_five {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="2"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
Main.WebChanges
Main.WebHome
Main.WebIndex
FOOT(3,3)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub verify_paging_with_limit_third_five {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="3"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
Sandbox.WebChanges
Sandbox.WebHome
Sandbox.WebIndex
FOOT(3,3)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub verify_paging_with_limit_fourth_five {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="4"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub verify_paging_with_limit_way_too_far {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="5"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

# Create three subwebs, and create a topic with the same name in all three
# which has a form and a field called "Order", which defines an ordering
# which is not the same as the ordering of the subwebs names. Now search
# the parent web recursively, with a sort order based on the value of the
# formfield. The sort should be based on the value of the 'Order' field.
#TODO: this is how the code has always worked, as the rendering of SEARCH results is done per web
#TODO: we hope to remove this (unless a compatibility switch is thrown, because its pretty un-useful.
sub DISABLEDtest_sorting_same_topic_in_subwebs {
    my $this = shift;

    my $webObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/A" );
    $webObject->populateNewWeb();
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/A", 'TheTopic',
        <<CRUD);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Order" title="Order" value="3"}%
CRUD
    $topicObject->save();

    $webObject = Foswiki::Meta->new( $this->{session}, "$this->{test_web}/B" );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/B", 'TheTopic',
        <<CRUD);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Order" title="Order" value="1"}%
CRUD
    $topicObject->save();

    $webObject = Foswiki::Meta->new( $this->{session}, "$this->{test_web}/C" );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/C", 'TheTopic',
        <<CRUD);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Order" title="Order" value="2"}%
CRUD
    $topicObject->save();

    my $result = $this->{test_topicObject}->expandMacros( <<GNURF );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="formfield(Order)"
 format="\$web"
 separator=","}%
GNURF
    $this->assert_equals(
        "$this->{test_web}/B,$this->{test_web}/C,$this->{test_web}/A",
        $result );
}

# The results of SEARCH are highly sensitive to the template;
# reduce sensitivity by trimming the result
sub _cut_the_crap {
    my $result = shift;
    $result =~ s/<!--.*?-->//gs;
    $result =~ s/<\/?(em|span|div|b|h\d)\b.*?>//gs;
    $result =~ s/ (class|style|rel)=(["'])[^"']*\2//g;
    $result =~ s/( href=(["']))[^"']*(\2)/$1$3/g;
    $result =~ s/\d\d:\d\d( \(\w+\))?/TIME/g;
    $result =~ s/\d{2} \w{3} \d{4}/DATE/g;
    return $result;
}

sub test_no_format_no_shit {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros('%SEARCH{"BLEEGLE"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME<br />
<a href="">OkATopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dontmatchme.blah

<a href="">OkBTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dont.matchmeblah

<a href="">OkTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE blah/matchme.blah

<a href="">TestTopicSEARCH</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nosummary="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME<br />
<a href="">OkATopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a><br />

<a href="">OkBTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a><br />

<a href="">OkTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a><br />

<a href="">TestTopicSEARCH</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a><br />

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nosearch="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME<br />
<a href="">OkATopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dontmatchme.blah

<a href="">OkBTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dont.matchmeblah

<a href="">OkTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE blah/matchme.blah

<a href="">TestTopicSEARCH</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nototal="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME<br />
<a href="">OkATopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dontmatchme.blah
<a href="">OkBTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dont.matchmeblah
<a href="">OkTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE blah/matchme.blah
<a href="">TestTopicSEARCH</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE

CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" noheader="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
<a href="">OkATopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dontmatchme.blah

<a href="">OkBTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dont.matchmeblah

<a href="">OkTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE blah/matchme.blah

<a href="">TestTopicSEARCH</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" noempty="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME<br />
<a href="">OkATopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dontmatchme.blah

<a href="">OkBTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dont.matchmeblah

<a href="">OkTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE blah/matchme.blah

<a href="">TestTopicSEARCH</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" zeroresults="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME<br />
<a href="">OkATopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dontmatchme.blah

<a href="">OkBTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE dont.matchmeblah

<a href="">OkTopic</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE blah/matchme.blah

<a href="">TestTopicSEARCH</a> TemporarySEARCHUsersWeb.WikiGuest NEW - <a href="">DATE - TIME</a>&nbsp;<br /><nop>BLEEGLE

Number of topics: 4
CRUD

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" nosummary="on" nosearch="on" nototal="on" zeroresults="off" noheader="on" noempty="on"}%'
      );
    my $result2 =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nosummary="on" nonoise="on"}%');
    $this->assert_html_equals( $result, $result2 );
}

sub verify_search_type_word {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals( 'OkBTopic', $result );
    my @list = split( /,/, $result );
    my $dontcount = $#list;
    $this->assert( $dontcount == 0 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"+dont" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    @list = split( /,/, $result );
    $this->assert_str_equals( 'OkBTopic', $result );
    my $plus_dontcount = $#list;
    $this->assert( $plus_dontcount == 0 );
    $this->assert( $plus_dontcount == $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == 3 );

    #$this->assert( $minus_dontcount == ($alltopics - $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 3 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );
}

sub verify_search_type_keyword {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkBTopic', $result );
    my @list = split( /,/, $result );
    my $dontcount = $#list;
    $this->assert( $dontcount == 1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"+dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    @list = split( /,/, $result );
    $this->assert_str_equals( 'OkATopic,OkBTopic', $result );
    my $plus_dontcount = $#list;
    $this->assert( $plus_dontcount == 1 );
    $this->assert( $plus_dontcount == $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals( 'OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == 2 );

    #$this->assert( $minus_dontcount == ($alltopics - $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals( 'OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 2 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );
}

sub verify_search_type_literal {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkBTopic', $result );
    my @list = split( /,/, $result );
    my $dontcount = $#list;
    $this->assert( $dontcount == 1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"+dont" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    @list = split( /,/, $result );
    $this->assert_str_equals( '', $result );
    my $plus_dontcount = $#list;
    $this->assert( $plus_dontcount == -1 );
    $this->assert( $plus_dontcount != $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals( 'OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 2 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );
}

sub verify_search_type_regex {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkBTopic', $result );
    my @list = split( /,/, $result );
    my $dontcount = $#list;
    $this->assert( $dontcount == 1 );

#this causes regex search to throw an error due to the '+'
#    $result =
#      $this->{test_topicObject}->expandMacros(
#        '%SEARCH{"+dont" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%');
#    @list = split(/,/, $result);
#    $this->assert_str_equals( '', $result );
#    my $plus_dontcount = $#list;
#    $this->assert( $plus_dontcount == -1 );
#    $this->assert( $plus_dontcount != $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals( 'OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 2 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );
}

sub verify_stop_words_search_word {
    my $this = shift;

    use Foswiki::Func;
    my $origSetting = Foswiki::Func::getPreferencesValue('SEARCHSTOPWORDS');
    Foswiki::Func::setPreferencesValue( 'SEARCHSTOPWORDS',
        'xxx luv ,kiss, bye' );

    my $TEST_TEXT  = "xxx Shamira";
    my $TEST_TOPIC = 'StopWordTestTopic';
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $TEST_TOPIC,
        $TEST_TEXT );
    $topicObject->save();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Shamira" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_matches( qr/$TEST_TOPIC/, $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"xxx" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( '', $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"+xxx" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( '', $result );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"+xxx" type="word" topic="$TEST_TOPIC" scope="text" nonoise="on" format="$summary(searchcontext)"}%'
      );

    $this->assert_str_equals( '', $result );

    Foswiki::Func::setPreferencesValue( 'SEARCHSTOPWORDS', $origSetting );
}

sub createSummaryTestTopic {
    my ( $this, $topicName ) = @_;

    my $TEST_SUMMARY_TEXT =
"Alan says: 'I was on a landing; there were banisters'. He pauses before describing the exact shape and details of the banisters. 'There was a thin man there. I was toppling him over the banisters. He said to me: 'When you have lost the 4 stone and the 14 stone, then you might topple over.' That's all I can remember.' Alan is thoughtful a while then talks about the 'toppling over'. He thinks that the sense was that the man might get unbalanced and topple over. He considers whether he might be pushing him over in the dream. He thought there was a way in which the man was suggesting that when Alan had lost the 4 stone and the 14 stone then he might topple over too; might lose his balance.

	As Alan thought about different parts of his dream he let his mind follow the thoughts, images and memories which came to him. He thought about his weight loss programme. He couldn't think why he was dreaming about 4 and 14 stone, but it didn't bother him that he couldn't understand that part, something would probably come up later. Perhaps it's because his next goal is 18 stone, he muses. He remembers being thin as a young man at school. In particular in athletics, competing against an arch-rival in running. He remembers something else which happened at that time too. He smiles with surprise, saying that he hasn't thought of it for 30 years until this moment. But now he notices that thinking about this memory makes him feel anxious.

	Just as he's saying this, his analyst notices that as she begins to think of what she might say about the dream she finds herself feeling she'll have to be very careful not to say it insensitively and provoke a fight. Subtly and imperceptibly the atmosphere has become tense. He remembers fighting this rival; really fighting as if to the death. He thinks that he might have completely lost control and killed him if this strange thing hadn't happened at that point. He'd just gone like jelly; he got up and walked away.

	After dwelling a little more on the fears he'd suffered as a young thin man about losing control and being violent, he remembers his father's sudden death from a heart attack when he was a boy. What his analyst knows is that this death, so traumatic for Alan, had precipitated his disturbance as a child. He had developed obsessional routines involving checking and re-checking that he had turned off the taps and secured the locks on the windows at night, as if he believed that in some way he was culpable for the death of his father.

	Alan interrupts himself to say: 'I went to the doctor yesterday, by the way, to discuss coming off all the pills.' He reminds his analyst that he is currently taking four different pills. He reminds her what each is for: an antipsychotic, an antidepressant, a beta blocker and a blood pressure pill. They speak a bit about the visit to the GP and Alan stresses both his desire to give up all his medication now that he is improving with the help of his analysis and his need to do it very carefully. He knows someone who came off antidepressants suddenly, all at once, and nearly died because the doctors hadn't bothered to warn him that it was dangerous. He checked this out with the GP and is stopping at the rate of half a pill per fortnight. His analyst says: 'Perhaps this helps us understand the 4 and the 14 in the dream. While you very much want to be healthy and be doing well in your analysis, and to manage without taking the 4 pills by giving up more every 14 days, you are also afraid that without the pills and the fat jelly you've covered yourself with, you might get unbalanced and be compelled to fight and be violent. Perhaps you fear your violence towards me, your thin analyst, too. The banisters made me think of those outside the consulting room which you see as you come in.'

	Alan says: 'Oh yes; I knew I'd seen them somewhere before! But how do I know I won't go mad and do something to you? I just thought of something, just then.' Alan is now very agitated. 'It makes my blood boil the way analysts never defend themselves when they are attacked in the press. You hear one slander after another about Freud and psychoanalysis, and what do your lot do? Nothing!'";

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topicName,
        $TEST_SUMMARY_TEXT );
    $topicObject->save();
}

=pod

Test the summary, default format.

=cut

sub test_summary_default_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Alan" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
Alan says<nop>: 'I was on a landing; there were banisters'. He pauses before describing the exact shape and details of the banisters. 'There was a thin man there. I was ...
CRUD
}

=pod

Test the default summary, limited to n chars.

=cut

sub test_summary_short_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Alan" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary(12)"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
Alan says<nop>: 'I was ...
CRUD
}

=pod

Test the summary with search context (default length).

=cut

sub test_summary_searchcontext_default_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"do" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary(searchcontext)"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
<b>&hellip;</b>  his analysis and his need to <em>do</em> it very carefully. He knows  <b>&hellip;</b>  somewhere before! But how <em>do</em> I know I won't go mad and do  <b>&hellip;</b>  and psychoanalysis, and what <em>do</em> your lot do? Nothing <b>&hellip;</b>
CRUD
}

=pod

Test the summary with search context, limited to n chars (short).

=cut

sub test_summary_searchcontext_short_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"his" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary(searchcontext,40)"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
<b>&hellip;</b>  topple over too; might lose <em>his</em> balance. As Alan thought  <b>&hellip;</b> 
CRUD
}

=pod

Test the summary with search context, limited to n chars (long)

=cut

sub test_summary_searchcontext_long_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"his" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary(searchcontext,200)"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
<b>&hellip;</b>  topple over too; might lose <em>his</em> balance. As Alan thought  <b>&hellip;</b> about different parts of <em>his</em> dream he let his mind follow  <b>&hellip;</b> came to him. He thought about <em>his</em> weight loss programme. He  <b>&hellip;</b>  later. Perhaps it's because <em>his</em> next goal is 18 stone, he  <b>&hellip;</b> 
CRUD
}

sub verify_zeroresults {
    my $this = shift;
    my $result;
    
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="on"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT
  
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="off"}%');
    $this->assert_equals( '', $result );
  
      $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="I did not find anything."}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT


#nototal=on
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on" zeroresults="on"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on" zeroresults="off"}%');
	$this->assert_equals( '', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on" zeroresults="I did not find anything."}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
RESULT

#nototal=off
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off" zeroresults="on"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off" zeroresults="off"}%');
    $this->assert_equals( '', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off" zeroresults="I did not find anything."}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT
}

1;
