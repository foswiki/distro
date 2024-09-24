# tests for the correct expansion of SEARCH
# SMELL: this test is pathetic, becase SEARCH has dozens of untested modes
#
# In order to keep this test down to a manageable run time, the fixture
# groups are only applied to those tests where we are testing the correct
# parsing of the search expression and its correct application in searching.
# Where we are primarily testing formatting and pagination, we keep the
# test out of the fixture groups on the assumption that all search and
# query algorithms output is formatted by the same code.
#
# NOTE: When developing, or after modifying search or query algorithms,
# you are highly recommended to run this suite with the "test" functions
# converted to "verify" - just in case!
#
package Fn_SEARCH;

use utf8;

use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Assert;
use Foswiki();
use Foswiki::Func();
use Foswiki::Search();
use Foswiki::Search::InfoCache();
use English qw( -no_match_vars );
use Error qw( :try );
use HTML::Entities;
use File::Spec;

sub new {
    my ( $class, @args ) = @_;
    my $self = $class->SUPER::new( 'SEARCH', @args );

    return $self;
}

# This particular test makes perl chew several hundred megabytes underl 5.10.0
# Devel::Leak::Object does not report any particular problems with this test.
# This test is run in a separate process to be able to reclaim that memory
# after the test is complete.
sub run_in_new_process {
    return 1;
}

our $AElig;

sub set_up {
    my ($this) = shift;
    $this->SUPER::set_up(@_);

    my $timestamp = time();
    $AElig = $this->toSiteCharSet('OkÆTopic');
    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $AElig );
    $topicObject->text("BLEEGLE blah/matchme.blah");
    $topicObject->save( forcedate => $timestamp + 120 );
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'OkATopic' );
    $topicObject->text("BLEEGLE dontmatchme.blah");
    $topicObject->save( forcedate => $timestamp + 240 );
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'OkBTopic' );
    $topicObject->text("BLEEGLE dont.matchmeblah");
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web},
        $this->toSiteCharSet('SomeOtherÆØÅTopic') );
    $topicObject->text("forrin speak");
    $topicObject->save( forcedate => $timestamp + 720 );
    $topicObject->finish();

    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'InvisibleTopic' );
    $topicObject->text("BLEEGLE dont.matchmeblah");
    $topicObject->putKeyed( 'PREFERENCE',
        { name => 'ALLOWTOPICVIEW', value => 'OnlySuperman' } );
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();

    return;
}

sub skip {
    my ( $this, $test ) = @_;

    return $this->skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                'Fn_SEARCH::test_headingoffset' =>
                  'Heading offset is new in 1.2',
            }
        }
    );
}

#TODO: figure out how to bomb out informativly if a dependency for one of the algo's isn't met - like no grep...
sub fixture_groups {
    my ( %salgs, %qalgs );
    foreach my $dir (@INC) {
        if ( opendir( my $Dir, "$dir/Foswiki/Store/SearchAlgorithms" ) ) {
            foreach my $alg ( readdir $Dir ) {
                next unless $alg =~ m/^(.*)\.pm$/;
                $alg = $1;

                # skip forking search for now, its extremely broken
                # on windows
                next if ( $^O eq 'MSWin32' && $alg eq 'Forking' );
                $salgs{$alg} = 1;
            }
            closedir($Dir);
        }
        if ( opendir( my $Dir, "$dir/Foswiki/Store/QueryAlgorithms" ) ) {
            foreach my $alg ( readdir $Dir ) {
                next unless $alg =~ m/^(.*)\.pm$/;
                $alg = $1;
                $qalgs{$alg} = 1;
            }
            closedir($Dir);
        }
    }
    my @groups;
    foreach my $alg ( keys %salgs ) {
        my $fn = $alg . 'Search';
        push( @groups, $fn );
        next if ( defined( &{$fn} ) );
        if ( not eval <<"SUB" or $EVAL_ERROR ) {
sub $fn {
    require Foswiki::Store::SearchAlgorithms::$alg;
    \$Foswiki::cfg{Store}{SearchAlgorithm} = 'Foswiki::Store::SearchAlgorithms::$alg';
}
1;
SUB
            die $EVAL_ERROR;
        }
    }
    foreach my $alg ( keys %qalgs ) {
        my $fn = $alg . 'Query';
        push( @groups, $fn );
        next if ( defined(&$fn) );
        if ( not eval <<"SUB" or $EVAL_ERROR ) {
sub $fn {
    require Foswiki::Store::QueryAlgorithms::$alg;
    \$Foswiki::cfg{Store}{QueryAlgorithm} = 'Foswiki::Store::QueryAlgorithms::$alg';
}
1;
SUB
            die $EVAL_ERROR;
        }
    }

    return ( \@groups );
}

sub loadExtraConfig {
    my ( $this, $context, @args ) = @_;    # the Test::Unit::TestCase object

    $this->SUPER::loadExtraConfig( $context, @args );

#turn on the MongoDBPlugin so that the saved data goes into mongoDB
#This is temoprary until Crawford and I cna find a way to push dependencies into unit tests
    if (   ( $Foswiki::cfg{Store}{SearchAlgorithm} =~ m/MongoDB/ )
        or ( $Foswiki::cfg{Store}{QueryAlgorithm} =~ m/MongoDB/ )
        or ( $context =~ m/MongoDB/ ) )
    {
        $Foswiki::cfg{Plugins}{MongoDBPlugin}{Module} =
          'Foswiki::Plugins::MongoDBPlugin';
        $Foswiki::cfg{Plugins}{MongoDBPlugin}{Enabled}             = 1;
        $Foswiki::cfg{Plugins}{MongoDBPlugin}{EnableOnSaveUpdates} = 1;

#push(@{$Foswiki::cfg{Store}{Listeners}}, 'Foswiki::Plugins::MongoDBPlugin::Listener');
        $Foswiki::cfg{Store}{Listeners}
          {'Foswiki::Plugins::MongoDBPlugin::Listener'} = 1;
        require Foswiki::Plugins::MongoDBPlugin;
        Foswiki::Plugins::MongoDBPlugin::getMongoDB()
          ->remove( $this->{test_web}, 'current',
            { '_web' => $this->{test_web} } );
    }

    return;
}

sub tear_down {
    my $this = shift;    # the Test::Unit::TestCase object

    $this->SUPER::tear_down(@_);

    #need to clear the web every test?
    if (   ( $Foswiki::cfg{Store}{SearchAlgorithm} =~ m/MongoDB/ )
        or ( $Foswiki::cfg{Store}{QueryAlgorithm} =~ m/MongoDB/ ) )
    {
        require Foswiki::Plugins::MongoDBPlugin;
        Foswiki::Plugins::MongoDBPlugin::getMongoDB()
          ->remove( $this->{test_web}, 'current',
            { '_web' => $this->{test_web} } );
    }

    return;
}

sub verify_simple {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        $this->toSiteCharSet(
'%SEARCH{"BLEEGLE" topic="OkATopic,OkBTopic,OkÆTopic" nonoise="on" format="$topic"}%'
        )
    );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

    return;
}

sub verify_Item4692 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"BLEEGLE" topic="NonExistant" nonoise="on" format="$topic"}%');

    $this->assert_str_equals( '', $result );

    return;
}

sub verify_b {
    my $this = shift;

    # Test regex with \b, used in rename searches
    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\bmatc[h]me\b" type="regex" topic="OkATopic,OkBTopic,OkÆTopic" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

    return;
}

sub verify_stop_word_Item13383 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"a" type="word" pager="on"}%');

    $this->assert_matches( qr#Number of topics: <span>0</span>#, $result );

    return;
}

sub verify_topicName {
    my $this = shift;

    # Test topic name search

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Ok.*" type="regex" scope="topic" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

    return;
}

sub verify_regex_trivial {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

    return;
}

sub verify_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

    return;
}

sub verify_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

    return;
}

sub verify_word {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"blah" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

    # 'blah' is in OkATopic, but not as a word
    $this->assert_does_not_match( qr/OkBTopic/, $result, $result );

    return;
}

sub verify_scope_all_type_word {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'VirtualBeer' );
    $topicObject->text("There are alot of Virtual Beers to go around");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'RealBeer' );
    $topicObject->text("There are alot of Virtual Beer to go around");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'FamouslyBeered' );
    $topicObject->text(
        "Virtually speaking there could be alot of famous Beers");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'VirtualLife' );
    $topicObject->text("In a all life, I would expect to find fine Beer");
    $topicObject->save();
    $topicObject->finish();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Virtual Beer" type="word" scope="all" nonoise="on" format="$topic"}%'
      );

    my $expected = $this->toSiteCharSet(<<'EXPECT');
RealBeer
VirtualBeer
VirtualLife
EXPECT
    $this->assert_str_equals( $expected, $result . "\n" );

    return;
}

sub verify_scope_all_type_keyword {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'VirtualBeer' );
    $topicObject->text("There are alot of Virtual Beers to go around");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'RealBeer' );
    $topicObject->text("There are alot of Virtual Beer to go around");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'FamouslyBeered' );
    $topicObject->text(
        "Virtually speaking there could be alot of famous Beers");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'VirtualLife' );
    $topicObject->text("In a all life, I would expect to find fine Beer");
    $topicObject->save();
    $topicObject->finish();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Virtual Beer" type="keyword" scope="all" nonoise="on" format="$topic"}%'
      );

    my $expected = $this->toSiteCharSet(<<'EXPECT');
FamouslyBeered
RealBeer
VirtualBeer
VirtualLife
EXPECT
    $this->assert_str_equals( $expected, $result . "\n" );

    return;
}

sub verify_scope_all_type_literal {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'VirtualBeer' );
    $topicObject->text("There are alot of Virtual Beers to go around");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'RealBeer' );
    $topicObject->text("There are alot of Virtual Beer to go around");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'FamouslyBeered' );
    $topicObject->text(
        "Virtually speaking there could be alot of famous Beers");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'VirtualLife' );
    $topicObject->text("In a all life, I would expect to find fine Beer");
    $topicObject->save();
    $topicObject->finish();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Virtual Beer" type="literal" scope="all" nonoise="on" format="$topic"}%'
      );

    my $expected = $this->toSiteCharSet(<<'EXPECT');
RealBeer
VirtualBeer
EXPECT
    $this->assert_str_equals( $expected, $result . "\n" );

    return;
}

sub _expect_with_deps {
    my ( $this, $default, %expectations ) = @_;
    my @deps = sort( keys %expectations );
    my $expected;
    my $checking = 1;

    while ( $checking && scalar(@deps) ) {
        my $dep = shift(@deps);

        if ( $this->check_dependency($dep) ) {
            $expected = $expectations{$dep};
            $checking = 0;
        }
    }
    if ($checking) {
        $expected = $default;
    }

    return $expected;
}

# Verify that the default result orering is independent of the web= and
# topic= parameters
sub verify_default_alpha_order_query {
    my $this   = shift;
    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
                "1" 
                type="query"
                web="System,Main,Sandbox"
                topic="WebSearch,WebHome,WebPreferences"
                nonoise="on" 
                format="$web.$topic"
        }%'
    );
    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Main.WebHome
Main.WebPreferences
Main.WebSearch
Sandbox.WebHome
Sandbox.WebPreferences
Sandbox.WebSearch
System.WebHome
System.WebPreferences
System.WebSearch
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
System.WebHome
System.WebPreferences
System.WebSearch
Main.WebHome
Main.WebPreferences
Main.WebSearch
Sandbox.WebHome
Sandbox.WebPreferences
Sandbox.WebSearch
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub verify_default_alpha_order_search {
    my $this   = shift;
    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
                "." 
                type="regex"
                web="System,Main,Sandbox"
                topic="WebSearch,WebHome,WebPreferences"
                nonoise="on" 
                format="$web.$topic"
        }%'
    );
    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Main.WebHome
Main.WebPreferences
Main.WebSearch
Sandbox.WebHome
Sandbox.WebPreferences
Sandbox.WebSearch
System.WebHome
System.WebPreferences
System.WebSearch
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
System.WebHome
System.WebPreferences
System.WebSearch
Main.WebHome
Main.WebPreferences
Main.WebSearch
Sandbox.WebHome
Sandbox.WebPreferences
Sandbox.WebSearch
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

#####################
sub _septic {
    my ( $this, $head, $foot, $sep, $results, $expected ) = @_;
    my $str = $results ? '*Topic' : 'Septic';
    $head = $head        ? 'header="HEAD"'      : '';
    $foot = $foot        ? 'footer="FOOT"'      : '';
    $sep  = defined $sep ? "separator=\"$sep\"" : '';
    my $result = $this->{test_topicObject}->expandMacros(
        $this->toSiteCharSet(
"%SEARCH{\"name~'$str'\" type=\"query\" nosearch=\"on\" nosummary=\"on\" nototal=\"on\" excludetopic=\"Some*\" format=\"\$topic\" $head $foot $sep}%"
        )
    );
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

#####################

sub test_no_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, undef, 1, <<'EXPECT');
OkATopic
OkBTopic
OkÆTopic
EXPECT

    return;
}

sub test_no_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 0, undef, 0, <<'EXPECT');
EXPECT

    return;
}

sub test_no_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, "", 1, <<'EXPECT');
OkATopicOkBTopicOkÆTopic
EXPECT

    return;
}

sub test_no_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 0, "", 0, <<'EXPECT');
EXPECT

    return;
}

sub test_no_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, ",", 1, <<'EXPECT');
OkATopic,OkBTopic,OkÆTopic
EXPECT

    return;
}

sub test_no_header_no_footer_with_nl_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, '$n', 1, <<'EXPECT');
OkATopic
OkBTopic
OkÆTopic
EXPECT

    return;
}

sub test_no_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 0, ",", 0, <<'EXPECT');
EXPECT

    return;
}
#####################

sub test_no_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 1, undef, 1, <<'EXPECT');
OkATopic
OkBTopic
OkÆTopic
FOOT
EXPECT

    return;
}

sub test_no_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 1, undef, 0, <<'EXPECT');
EXPECT

    return;
}

sub test_no_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 1, "", 1, <<'EXPECT');
OkATopicOkBTopicOkÆTopicFOOT
EXPECT

    return;
}

sub test_no_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 1, "", 0, <<'EXPECT');
EXPECT

    return;
}

sub test_no_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 1, ",", 1, <<'EXPECT');
OkATopic,OkBTopic,OkÆTopicFOOT
EXPECT

    return;
}

#####################

sub test_with_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 1, undef, 1, <<'EXPECT');
HEAD
OkATopic
OkBTopic
OkÆTopic
FOOT
EXPECT

    return;
}

sub test_with_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 1, undef, 0, <<'EXPECT');
EXPECT

    return;
}

sub test_with_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 1, "", 1, <<'EXPECT');
HEADOkATopicOkBTopicOkÆTopicFOOT
EXPECT

    return;
}

sub test_with_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 1, "", 0, <<'EXPECT');
EXPECT

    return;
}

sub test_with_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 1, ",", 1, <<'EXPECT');
HEADOkATopic,OkBTopic,OkÆTopicFOOT
EXPECT

    return;
}

sub test_with_header_with_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 1, ",", 0, <<'EXPECT');
EXPECT

    return;
}

#####################

sub test_with_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 0, undef, 1, <<'EXPECT');
HEAD
OkATopic
OkBTopic
OkÆTopic
EXPECT

    return;
}

sub test_with_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 0, undef, 0, <<'EXPECT');
EXPECT

    return;
}

sub test_with_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 0, "", 1, <<'EXPECT');
HEADOkATopicOkBTopicOkÆTopic
EXPECT

    return;
}

sub test_with_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 0, "", 0, <<'EXPECT');
EXPECT

    return;
}

sub test_with_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 0, ",", 1, <<'EXPECT');
HEADOkATopic,OkBTopic,OkÆTopic
EXPECT

    return;
}

sub test_with_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 0, ",", 0, <<'EXPECT');
EXPECT

    return;
}

sub test_no_header_no_footer_with_nl_separator {
    my $this = shift;
    $this->_septic( 0, 0, '$n', 1, <<'EXPECT');
OkATopic
OkBTopic
OkÆTopic
EXPECT

    return;
}

sub test_headingoffset {
    my ( $this, $query, $web ) = @_;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'TestHINC' );
    $topicObject->text(<<HERE);
---+ H4
<ho off="1">
---+ H5
<h1>H2</h1>
<ho off="+2">
---+ H6
<h1>H6</h1>
<ho off="-3">
---+ H4
HERE
    $topicObject->save();
    $topicObject->finish();
    my $result = $this->{test_topicObject}->expandMacros(<<HERE);
%SEARCH{"---+" web="$this->{test_web}" topic="TestHINC" format="\$text" headingoffset="3"}%
###
%SEARCH{"---+" multiple="on" web="$this->{test_web}" topic="TestHINC" format="\$text" headingoffset="3"}%
HERE

    $this->assert_str_equals( <<EXPECT, $result );
<div class="foswikiSearchResultsHeader"><span>Searched: <b><noautolink>---+</noautolink></b></span><span id="foswikiNumberOfResultsContainer"></span></div>
<ho off="3">
---+ H4
<ho off="1">
---+ H5
<h1>H2</h1>
<ho off="+2">
---+ H6
<h1>H6</h1>
<ho off="-3">
---+ H4

<ho off="-3"/>
<div class="foswikiSearchResultCount">Number of topics: <span>1</span></div>
###
<div class="foswikiSearchResultsHeader"><span>Searched: <b><noautolink>---+</noautolink></b></span><span id="foswikiNumberOfResultsContainer"></span></div>
---+ H4
<ho off="1">
---+ H5
<h1>H2</h1>
<ho off="+2">
---+ H6
<h1>H6</h1>
<ho off="-3">
---+ H4

<div class="foswikiSearchResultCount">Number of topics: <span>1</span></div>
EXPECT
}

sub verify_regex_match {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
}

sub verify_literal_match {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
}

sub verify_keyword_match {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
}

sub verify_word_match {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/${AElig}/,             $result );
    $this->assert_does_not_match( qr/OkBTopic/,             $result );
    $this->assert_does_not_match( qr/OkATopic/,             $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
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

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
}

sub verify_literal_matchme {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
}

sub verify_keyword_matchme {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
}

sub verify_word_matchme {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkBTopic/,             $result );
    $this->assert_does_not_match( qr/OkATopic/,             $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
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

    $this->assert_does_not_match( qr/${AElig}/,             $result );
    $this->assert_does_not_match( qr/OkBTopic/,             $result );
    $this->assert_does_not_match( qr/OkATopic/,             $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
}

sub verify_minus_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/${AElig}/,             $result );
    $this->assert_does_not_match( qr/OkBTopic/,             $result );
    $this->assert_does_not_match( qr/OkATopic/,             $result );
    $this->assert_does_not_match( qr/SomeOtherÆØÅTopic/, $result );

    return;
}

sub verify_minus_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

    return;
}

sub verify_minus_word {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

    return;
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

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

    return;
}

sub verify_slash_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

    return;
}

sub verify_slash_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

    return;
}

sub verify_slash_word {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

    return;
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

    $this->assert_does_not_match( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );

    return;
}

sub verify_quote_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );

    return;
}

sub verify_quote_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/${AElig}/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

    return;
}

sub verify_quote_word {
    my $this = shift;

    # word
    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_does_not_match( qr/${AElig}/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );

    return;
}

sub verify_SEARCH_3860 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros( $this->toSiteCharSet(<<'HERE') );
%SEARCH{"BLEEGLE" topic="OkÆTopic" format="$wikiname $wikiusername" nonoise="on" }%
HERE
    my $wn = $this->{session}->{users}->getWikiName( $this->{session}->{user} );
    $this->assert_str_equals( "$wn $this->{users_web}.$wn\n", $result );

    $result =
      $this->{test_topicObject}->expandMacros( $this->toSiteCharSet(<<'HERE') );
%SEARCH{"BLEEGLE" topic="OkÆTopic" format="$createwikiname $createwikiusername" nonoise="on" }%
HERE
    $this->assert_str_equals( "$wn $this->{users_web}.$wn\n", $result );

    return;
}

sub verify_search_empty_regex {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="regex" scope="text" nonoise="on" format="$topic"}%');
    $this->assert_str_equals( "", $result );

    return;
}

sub verify_search_empty_literal {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );

    return;
}

sub verify_search_empty_keyword {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );

    return;
}

sub verify_search_empty_word {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="word" scope="text" nonoise="on" format="$topic"}%');
    $this->assert_str_equals( "", $result );

    return;
}

sub verify_search_numpty_regex {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-\)" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );

    return;
}

sub verify_search_numpty_literal {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );

    return;
}

sub verify_search_numpty_keyword {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );

    return;
}

sub verify_search_numpty_word {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );

    return;
}

sub set_up_for_formatted_search {
    my $this = shift;

    my $text = $this->toSiteCharSet(<<'HERE');
!MichaelAnchor, One/WIKI.NET and !AnnaAnchor lived in Skagen in !DenmarkEurope!. There is a very nice museum you can visit!

This text is fill in text which is there to ensure that the unique word below does not show up in a summary.

   * Bullet 1
   * Bullet 2
   * Bullet 3
   * Bullet 4
HERE

    # Create the form
    Foswiki::Func::saveTopic( $this->{test_web}, "FormattedSearchForm", undef,
        <<FORM);
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* |
| Name | text | 40 | | |
| Role | text | 40 | | |
| Testsample | text | 40 | | |
| Groupe | select+values | 1 | A: Tous=A, B: Financiers; Rapports =Bollocks, C: Négociation; Syndicat =C, | Quel est le groupe de diffusion du document? | |
| Chinese | checkbox+values | 1 | 一=one, 二=two, 三=three | | |
FORM

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'FormattedSearchTopic1' );
    $topicObject->put( 'TOPICPARENT',
        { name => "TestCaseAutoFormattedSearch" } );
    $topicObject->put( 'FORM', { name => "FormattedSearchForm" } );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Name",
            title => "Name",
            value => "!AnnaAnchor"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Groupe",
            title => "Groupe",
            value => "Bollocks"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Chinese",
            title => "Chinese",
            value => "three"
        }
    );
    $topicObject->text($text);
    $topicObject->save();
    $topicObject->finish();

    return;
}

sub test_footer_with_ntopics {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'*Topic\'" type="query"  nonoise="on" footer="Total found: $ntopics" format="$topic" excludetopic="SomeOther*"}%'
      );

    $this->assert_str_equals(
        $this->toSiteCharSet(
            join( "\n", sort qw(OkATopic OkBTopic OkÆTopic) )
          )
          . "\nTotal found: 3",
        $result
    );

    return;
}

sub test_multiple_and_footer_with_ntopics_and_nhits {
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

    return;
}

sub test_footer_with_ntopics_empty_format {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'*Topic\'" type="query"  nonoise="on" footer="Total found: $ntopics" format="" separator=""}%'
      );

    $this->assert_str_equals( "Total found: 4", $result );

    return;
}

sub test_nofinalnewline {
    my $this = shift;

    # nofinalnewline="off"
    my $result = $this->{test_topicObject}->expandMacros(
        $this->toSiteCharSet(
'%SEARCH{"name~\'OkÆTopic\'" type="query"  nonoise="on" format="$topic" nofinalnewline="off"}%'
        )
    );

    $this->assert_str_equals( "${AElig}\n", $result );

    # nofinalnewline="on"
    $result = $this->{test_topicObject}->expandMacros(
        $this->toSiteCharSet(
'%SEARCH{"name~\'OkÆTopic\'" type="query"  nonoise="on" format="$topic" nofinalnewline="on"}%'
        )
    );

    $this->assert_str_equals( "OkÆTopic", $result );

    # nofinalnewline should default be on
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'OkÆTopic\'" type="query"  nonoise="on" format="$topic"}%'
      );

    $this->assert_str_equals( "OkÆTopic", $result );

    return;
}

sub test_formatted_search_summary_with_exclamation_marks {
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
'<nop>MichaelAnchor, <nop>One/WIKI.NET and <nop>AnnaAnchor lived in Skagen in <nop>DenmarkEurope!. There is a very nice museum you can visit!';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Anna" topic="FormattedSearchTopic1" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="$formfield(Name)"}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>AnnaAnchor';
    $this->assert_str_equals( $expected, $actual );

    return;
}

# Item8718
sub test_formatted_search_with_exclamation_marks_inside_bracket_link {
    my $this    = shift;
    my $session = $this->{session};

    $this->set_up_for_formatted_search();
    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Anna" topic="FormattedSearchTopic1" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="[[$web.$topic][$formfield(Name)]]"}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $actual   = _cut_the_crap($actual);
    $expected = '<a href=""><nop>AnnaAnchor</a>';

    $this->assert_str_equals( $expected, $actual );

    return;
}

sub test_format_tokens_topic_truncated {
    my $this = shift;

    $this->set_up_for_formatted_search();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Bullet" type="regex" multiple="on" nonoise="on" format="I found $topic(5,...)" excludetopic="SomeOther*"}%'
      );

    $this->assert_str_equals(
"I found Forma...\nI found Forma...\nI found Forma...\nI found Forma...",
        $result
    );

    return;
}

sub test_format_tokens_dont_expand {
    my $this = shift;

    $this->set_up_for_formatted_search();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Bullet" type="regex" nonoise="on" format="$topic $email $html $time"}%'
      );

    $this->assert_str_equals( "FormattedSearchTopic1 \$email \$html \$time",
        $result );

    return;
}

sub test_format_displayed_value {
    my $this = shift;

    $this->set_up_for_formatted_search();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Bullet" type="regex" nonoise="on" format="$formfield(Groupe, display) $formfield(Groupe):$formfield(Groupe,  display,  3)"}%'
      );

    $this->assert_str_equals(
"B: Financiers; Rapports  Bollocks:B: - Fin- anc- ier- s; - Rap- por- ts",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Bullet" type="regex" nonoise="on" format="$formfield(Chinese, display) $formfield(Chinese)"}%'
      );

    $this->assert_str_equals( "三 three", $result );

    return;
}

sub test_METASEARCH {
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

    return;
}

sub set_up_for_queries {
    my $this = shift;
    my $text = $this->toSiteCharSet(<<'HERE');
something before. Another
This is QueryTopic FURTLE
somethig after
HERE
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopic' );
    $topicObject->put(
        'TOPICINFO',
        {
            author  => "TopicUserMapping_guest",
            date    => "1178612772",
            format  => "1.1",
            version => "1.1"
        }
    );
    $topicObject->put( 'TOPICPARENT', { name => "WebHome" } );
    $topicObject->put( 'FORM',        { name => "TestForm" } );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Field1",
            title => "A Field",
            value => "A Field"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Field2",
            title => "Another Field",
            value => "2"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Firstname",
            title => "First Name",
            value => "Emma"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Lastname",
            title => "First Name",
            value => "Peel"
        }
    );
    $topicObject->put(
        'TOPICMOVED',
        {
            by   => "TopicUserMapping_guest",
            date => "1176311052",
            from => "Sandbox.TestETP",
            to   => "Sandbox.TestEarlyTimeProtocol"
        }
    );
    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "README",
            comment => "Blah Blah",
            date    => "1157965062",
            size    => "5504"
        }
    );
    $topicObject->text($text);
    $topicObject->save();
    $topicObject->finish();

    $text = $this->toSiteCharSet(<<'HERE');
first line
This is QueryTopicTwo SMONG
third line
HERE
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicTwo' );
    $topicObject->text($text);
    $topicObject->put( 'TOPICPARENT', { name => "QueryTopic" } );
    $topicObject->put(
        'TOPICINFO',
        {
            author  => "TopicUserMapping_guest",
            date    => "12",
            format  => "1.1",
            version => "1.2"
        }
    );
    $topicObject->put( 'FORM', { name => "TestyForm" } );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldA",
            title => "B Field",
            value => "7"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldB",
            title => "Banother Field",
            value => "8"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Firstname",
            title => "Pre Name",
            value => "John"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Lastname",
            title => "Post Name",
            value => "Peel"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "form",
            title => "Blah",
            value => "form good"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FORM",
            title => "Blah",
            value => "FORM GOOD"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "NewField",
            title => "Item10269",
            value => "Profile/Builder.TermForm"
        }
    );
    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "porn.gif",
            comment => "Cor",
            date    => "15062",
            size    => "15504"
        }
    );
    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "flib.xml",
            comment => "Cor",
            date    => "1157965062",
            size    => "1"
        }
    );
    $topicObject->save();
    $topicObject->finish();

    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( $this->{test_web}, $this->{session}->{webName} );

    return;
}

# NOTE: most query ops are tested in Fn_IF.pm, and are not re-tested here

my $stdCrap =
'type="query" nonoise="on" format="$topic" separator=" " excludetopic="Some*"}%';

sub verify_parentQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"parent.name=\'WebHome\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );

    return;
}

sub verify_attachmentSizeQuery1 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"attachments[size > 0]"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic QueryTopicTwo', $result );

    return;
}

sub verify_attachmentSizeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"META:FILEATTACHMENT[size > 10000]"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    return;
}

sub verify_indexQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"attachments[name=\'flib.xml\']"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    return;
}

sub verify_gropeQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic QueryTopicTwo', $result );

    return;
}

sub verify_4580Query1 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"text ~ \'*SMONG*\' AND Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    return;
}

sub verify_4580Query2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"text ~ \'*FURTLE*\' AND Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );

    return;
}

sub verify_gropeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic QueryTopicTwo', $result );

    return;
}

sub verify_formQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"form.name=\'TestyForm\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    return;
}

#Item10520: in Sven's reading of System.QuerySearch, this should return no results, as there is no field of the name 'TestForm'
sub verify_formQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestForm"' . $stdCrap );
    my $expected =
      $this->_expect_with_deps( '', 'Foswiki,<,1.2' => 'QueryTopic' );

    $this->assert_str_equals( $expected, $result );

    return;
}

sub verify_formQuery3 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"TestForm[name=\'Field1\'].value=\'A Field\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );

    return;
}

sub verify_formQuery4 {
    my $this = shift;

    $this->expect_failure(
        "THIS IS WINDOWS & grep; Test will fail because of Item1072",
        using => [ 'PlatformWindows', 'SearchAlgorithmForking' ]
    );

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestForm.Field1=\'A Field\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );

    return;
}

sub verify_formQuery5 {
    my $this = shift;

    $this->expect_failure(
        "THIS IS WINDOWS & grep; Test will fail because of Item1072",
        using => [ 'PlatformWindows', 'SearchAlgorithmForking' ]
    );

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestyForm.form=\'form good\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestyForm.FORM=\'FORM GOOD\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    return;
}

sub verify_refQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"parent.name/(Firstname ~ \'*mm?\' AND Field2=2)"'
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    return;
}

sub verify_lc_field_short {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"lc(Firstname) ~ lc(\'Emma\')"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_lc_field_qualified {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"lc(TestForm.Firstname) ~ lc(\'Emma\')"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_lc_field_fully_qualified {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"lc(TestForm[name=\'Firstname\'].value) ~ lc(\'Emma\')"'
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

# make sure syntax errors are handled cleanly. All the error cases thrown by
# the infix parser are tested more thoroughly in Fn_IF, and don't have to
# be re-tested here.
sub verify_badQuery1 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros( '%SEARCH{"A ¬ B"' . $stdCrap );
    $this->assert_matches( qr/Error was: Syntax error in 'A ¬ B' at ' ¬ B'/s,
        $result );

    return;
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
        my $text = <<"HERE";
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
HERE
        my ($topicObject) =
          Foswiki::Func::readTopic( $this->{test_web}, "QueryTopic$n", );
        $topicObject->put(
            'TOPICINFO',
            {
                author  => "TopicUserMapping_guest",
                date    => "12",
                format  => "1.1",
                version => "1.2"
            }
        );
        $topicObject->put( 'FORM', { name => "TestForm" } );
        $topicObject->putKeyed(
            'FIELD',
            {
                name  => "FieldA",
                title => "Banother Field",
                value => "$vA"
            }
        );
        $topicObject->putKeyed(
            'FIELD',
            {
                name  => "FieldB",
                title => "Banother Field",
                value => "$vB"
            }
        );
        $topicObject->putKeyed(
            'FIELD',
            {
                name  => "FieldC",
                title => "Banother Field",
                value => "$vC"
            }
        );
        $topicObject->putKeyed(
            'FIELD',
            {
                name  => "FieldD",
                title => "Banother Field",
                value => "$vD"
            }
        );
        $topicObject->putKeyed(
            'FIELD',
            {
                name  => "FieldE",
                title => "Banother Field",
                value => "$vE"
            }
        );
        $topicObject->text($text);
        $topicObject->save();
        $topicObject->finish();
    }
    require Benchmark;

    # Search using a regular expression
    my $start = Benchmark->new();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"^[%]META:FIELD\{name=\"FieldA\".*\bvalue=\"A\";^[%]META:FIELD\{name=\"FieldB\".*\bvalue=\"A\";^[%]META:FIELD\{name=\"FieldC\".*\bvalue=\"A\";^[%]META:FIELD\{name=\"FieldD\".*\bvalue=\"A\"|^[%]META:FIELD\{name=\"FieldE\".*\bvalue=\"A\"" type="regex" nonoise="on" format="$topic" separator=" "}%'
      );
    my $retime = Benchmark::timediff( Benchmark->new(), $start );
    $this->assert_str_equals( 'QueryTopic1 QueryTopic2', $result );

    # Repeat using a query
    $start = Benchmark->new;
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"FieldA=\'A\' AND FieldB=\'A\' AND FieldC=\'A\' AND (FieldD=\'A\' OR FieldE=\'A\')" type="query" nonoise="on" format="$topic" separator=" "}%'
      );
    my $querytime = Benchmark::timediff( new Benchmark, $start );
    $this->assert_str_equals( 'QueryTopic1 QueryTopic2', $result );
    print STDERR "Query " . Benchmark::timestr($querytime),
      "\nRE " . Benchmark::timestr($retime), "\n";

    return;
}

sub test_4347 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
"%SEARCH{\"$this->{test_topic}\" scope=\"topic\" nonoise=\"on\" format=\"\$formfield(Blah)\"}%"
      );
    $this->assert_str_equals( '', $result );

    return;
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

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicTwo' );
    $result = $topicObject->expandMacros(
        '%SEARCH{"text ~ \'*QueryTopicTwo*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
    $topicObject->finish();

    return;
}

sub test_metaCache_madness {
    my ($this) = @_;

    my $text = $this->toSiteCharSet(<<'HERE');
This is QueryTopicTwo SMONG
HERE
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicTwo' );

    $topicObject->text($text);
    $topicObject->save();
    $topicObject->finish();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*QueryTopicTwo*\'" ' . $stdCrap );

    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicTwo' );

    $this->assert( $this->{session}
          ->metaCache->isCached( $this->{test_web}, 'QueryTopicTwo' ) );
    $topicObject->finish();

    $this->assert( !$this->{session}
          ->metaCache->isCached( $this->{test_web}, 'QueryTopicTwo' ) );

    return;
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

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*QueryTopicTwo*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*Notinthetopics*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( '', $result );
    $topicObject->finish();

    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*before. Another*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );

    return;
}

sub test_pattern {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" topic="OkATopic,OkBTopic,OkÆTopic" nonoise="on" format="X$pattern(.*?BLEEGLE (.*?)blah.*)Y"}%'
      );
    $this->assert_matches( qr/Xdontmatchme\.Y/, $result );
    $this->assert_matches( qr/Xdont.matchmeY/,  $result );
    $this->assert_matches( qr/XY/,              $result );

    return;
}

sub test_extract {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'ExtractTopic' );
    $topicObject->text("BLEEGLE \"<>&%\$\"blah");
    $topicObject->save();
    $topicObject->finish();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" topic="ExtractTopic" nonoise="on" format="X$percentENCODE{$extract(.*?BLEEGLE (.*?)blah.*)}$percentY"}%'
      );
    $this->assert_matches( qr/X%3c%3e%26%25%24Y/, $result );
    return;
}

sub test_badpattern {
    my $this = shift;

    # The (??{ pragma cannot be run at runtime since perl 5.5

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" topic="OkATopic,OkBTopic,OkÆTopic" nonoise="on" format="X$pattern(.*?BL(??{\'E\' x 2})GLE( .*?)blah.*)Y"}%'
      );

    # If (??{ is evaluated, the topics should match:
    $this->assert_does_not_match( qr/XdontmatchmeY/,  $result );
    $this->assert_does_not_match( qr/Xdont.matchmeY/, $result );
    $this->assert_does_not_match( qr/X Y/,            $result );

    # If (??{ isn't evaluated, $pattern should return empty
    # and format should be XY for all 3 topics
    $this->assert_equals( 3, $result =~ s/^XY$//gm );

    return;
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

    return;
}

#Item977
sub test_formatOfLinks {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'Item977' );
    $topicObject->text( $this->toSiteCharSet(<<'HERE') );
---+ Apache

Apache is the [[http://www.apache.org/httpd/][well known web server]].
HERE
    $topicObject->save();
    $topicObject->finish();

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
    $this->assert_matches(
qr/Apache is the\s+http:\/\/www\.apache\.org\/httpd\/ well known web server\s*\./,
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

    return;
}

sub _getTopicList {
    my ( $this, $web, $options, $sadness, $default_expected, %expected_list ) =
      @_;
    my $expected =
      $this->_expect_with_deps( $default_expected, %expected_list );

    #    my $options = {
    #        casesensitive  => $caseSensitive,
    #        wordboundaries => $wordBoundaries,
    #        includeTopics  => $topic,
    #        excludeTopics  => $excludeTopic,
    #    };

    $this->assert_str_equals( 'ARRAY', ref($expected) );
    my $webObject = $this->getWebObject($web);

    # Run the search on topics in this web
    my $search = $this->{session}->search();
    my $iter =
      Foswiki::Search::InfoCache::getTopicListIterator( $webObject, $options );

    ASSERT( $iter->isa('Foswiki::Iterator') ) if DEBUG;
    my @topicList = ();
    while ( my $t = $iter->next() ) {
        next if ( $t eq 'InvisibleTopic' );    #and user != admin or...
        push( @topicList, $t );
    }
    $webObject->finish();

    my $l1 = join( ',', @{$expected} );
    my $l2 = join( ',', @topicList );
    $this->assert_str_equals( $l1, $l2, "$sadness:\nwant: $l2\n got: $l1" );
    return \@topicList;
}

sub verify_getTopicList {
    my $this = shift;

    #no topics specified..
    $this->_getTopicList(
        $this->{test_web},
        {},
        'no filters, all topics in test_web',
        [
            'OkATopic',        'OkBTopic',
            'OkÆTopic',       'SomeOtherÆØÅTopic',
            'TestTopicSEARCH', 'WebPreferences'
        ],
    );
    $this->_getTopicList(
        '_default',
        {},
        'no filters, all topics in default web',
        [
            'WebAtom',           'WebChanges',
            'WebCreateNewTopic', 'WebHome',
            'WebIndex',          'WebLeftBar',
            'WebNotify',         'WebPreferences',
            'WebRss',            'WebSearch',
            'WebSearchAdvanced', 'WebTopicList'
        ],
    );

    #use wildcards
    $this->_getTopicList(
        $this->{test_web},
        { includeTopics => 'Ok*' },
        'comma separated list',
        [ 'OkATopic', 'OkBTopic', 'OkÆTopic' ],
    );
    $this->_getTopicList(
        '_default',
        { includeTopics => 'Web*' },
        'no filters, all topics in test_web',
        [
            'WebAtom',           'WebChanges',
            'WebCreateNewTopic', 'WebHome',
            'WebIndex',          'WebLeftBar',
            'WebNotify',         'WebPreferences',
            'WebRss',            'WebSearch',
            'WebSearchAdvanced', 'WebTopicList'
        ],
    );

    #comma separated list specifed for inclusion
    $this->_getTopicList(
        $this->{test_web},
        { includeTopics => 'TestTopicSEARCH,OkÆTopic,NoSuchTopic' },
        'comma separated list',
        [ 'OkÆTopic', 'TestTopicSEARCH' ],
        'Foswiki,<,1.2' => [ 'TestTopicSEARCH', 'OkÆTopic' ],
    );
    $this->_getTopicList(
        '_default',
        { includeTopics => 'WebTopicList, WebCreateNewTopic, NoSuchTopic' },
        'no filters, all topics in test_web',
        [ 'WebCreateNewTopic', 'WebTopicList' ],
        'Foswiki,<,1.2' => [ 'WebTopicList', 'WebCreateNewTopic' ],
    );

    #excludes
    $this->_getTopicList(
        $this->{test_web},
        { excludeTopics => 'NoSuchTopic,OkBTopic,SomeOtherÆØÅTopic' },
        'no filters, all topics in test_web',
        [ 'OkATopic', 'OkÆTopic', 'TestTopicSEARCH', 'WebPreferences' ],
    );
    $this->_getTopicList(
        '_default',
        { excludeTopics => 'WebSearch' },
        'no filters, all topics in default web',
        [
            'WebAtom',           'WebChanges',
            'WebCreateNewTopic', 'WebHome',
            'WebIndex',          'WebLeftBar',
            'WebNotify',         'WebPreferences',
            'WebRss',            'WebSearchAdvanced',
            'WebTopicList'
        ],
    );

    #Talk about missing alot of tests
    $this->_getTopicList(
        $this->{test_web},
        { includeTopics => '*' },
        'all topics, using wildcard',
        [
            'OkATopic',        'OkBTopic',
            'OkÆTopic',       'SomeOtherÆØÅTopic',
            'TestTopicSEARCH', 'WebPreferences'
        ],
    );
    $this->_getTopicList(
        $this->{test_web},
        { includeTopics => 'Ok*' },
        'Ok* topics, using wildcard',
        [ 'OkATopic', 'OkBTopic', 'OkÆTopic' ],
    );
    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => 'ok*',
            casesensitive => 1
        },
        'case sensitive ok* topics, using wildcard',
        [],
    );
    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => 'ok*',
            casesensitive => 0
        },
        'case insensitive ok* topics, using wildcard',
        [ 'OkATopic', 'OkBTopic', 'OkÆTopic' ],
    );

    if ( File::Spec->case_tolerant() ) {
        print STDERR "WARNING: case insensitive file system, skipping a test\n";
    }
    else {

        # this test won't work on Mac OS X or windows.
        $this->_getTopicList(
            $this->{test_web},
            {
                includeTopics => 'okatopic',
                casesensitive => 1
            },
            'case sensitive okatopic topic 1',
            [],
        );
    }

    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => 'okatopic',
            casesensitive => 0
        },
        'case insensitive okatopic topic',
        ['OkATopic'],
    );
    ##### same again, with excludes.
    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => '*',
            excludeTopics => 'web*'
        },
        'all topics, using wildcard',
        [
            'OkATopic',        'OkBTopic',
            'OkÆTopic',       'SomeOtherÆØÅTopic',
            'TestTopicSEARCH', 'WebPreferences'
        ],
    );
    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => 'Ok*',
            excludeTopics => 'okatopic'
        },
        'Ok* topics, using wildcard',
        [ 'OkATopic', 'OkBTopic', 'OkÆTopic' ],
    );
    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => 'ok*',
            excludeTopics => 'WebPreferences',
            casesensitive => 1
        },
        'case sensitive ok* topics, using wildcard',
        [],
    );
    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => 'ok*',
            excludeTopics => '',
            casesensitive => 0
        },
        'case insensitive ok* topics, using wildcard',
        [ 'OkATopic', 'OkBTopic', 'OkÆTopic' ],
    );

    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => 'Ok*',
            excludeTopics => '*ATopic',
            casesensitive => 1
        },
        'case sensitive okatopic topic 2',
        [ 'OkBTopic', 'OkÆTopic' ],
    );

    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => 'Ok*',
            excludeTopics => '*atopic',
            casesensitive => 1
        },
        'case sensitive okatopic topic 3',
        [ 'OkATopic', 'OkBTopic', 'OkÆTopic' ],
    );

    $this->_getTopicList(
        $this->{test_web},
        {
            includeTopics => 'ok*topic',
            excludeTopics => 'okatopic',
            casesensitive => 0
        },
        'case insensitive okatopic topic',
        [ 'OkBTopic', 'OkÆTopic' ],
    );

    return;
}

sub verify_casesensitivesetting {
    my $this    = shift;
    my $session = $this->{session};

    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual = $this->{test_topicObject}->renderTML($actual);
    $expected =
      '<nop>OkATopic,<nop>OkBTopic,<nop>OkÆTopic,<nop>TestTopicSEARCH';
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
    $actual = $this->{test_topicObject}->renderTML($actual);
    $expected =
      '<nop>OkATopic,<nop>OkBTopic,<nop>OkÆTopic,<nop>TestTopicSEARCH';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"bleegle" type="regex" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual = $this->{test_topicObject}->renderTML($actual);
    $expected =
      '<nop>OkATopic,<nop>OkBTopic,<nop>OkÆTopic,<nop>TestTopicSEARCH';
    $this->assert_str_equals( $expected, $actual );

    #topic scope
    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Ok" type="regex" scope="topic" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkÆTopic';
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
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkÆTopic';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"ok" type="regex" scope="topic" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkÆTopic';
    $this->assert_str_equals( $expected, $actual );

    return;
}

sub verify_Item6082_Search {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'TestForm' );
    $topicObject->text(<<'FORM');
| *Name*         | *Type* | *Size* | *Value*   | *Tooltip message* | *Attributes* |
| Why | text | 32 | | Mandatory field | M |
| Ecks | select | 1 | %SEARCH{"TestForm.Ecks~'Blah*'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}% | | |
FORM
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'SplodgeOne' );
    $topicObject->put( 'FORM', { name => "TestForm" } );
    $topicObject->putKeyed( 'FIELD',
        { name => "Ecks", title => "X", value => "Blah" } );
    $topicObject->save();

    my $actual = $topicObject->expandMacros(
'%SEARCH{"TestForm.Ecks~\'Blah*\'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}%'
    );
    my $expected = 'SplodgeOne;Blah';
    $this->assert_str_equals( $expected, $actual );
    $topicObject->finish();

    return;
}

sub verify_quotemeta {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'TestForm' );
    $topicObject->text( <<'FORM');
| *Name*         | *Type* | *Size* | *Value*   | *Tooltip message* | *Attributes* |
| Why | text | 32 | | Mandatory field | M |
| Ecks | select | 1 | %SEARCH{"TestForm.Ecks~'Blah*'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}% | | |
FORM
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'SplodgeOne' );
    $topicObject->put( 'FORM', { name => "TestForm" } );
    $topicObject->putKeyed( 'FIELD',
        { name => "Ecks", title => "X", value => "Blah" } );
    $topicObject->save();

    my $actual = $topicObject->expandMacros(
'%SEARCH{"TestForm.Ecks~\'Blah*\'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}%'
    );
    my $expected = 'SplodgeOne;Blah';
    $this->assert_str_equals( $expected, $actual );
    $topicObject->finish();

    return;
}

sub verify_Search_expression {

    #make sure perl-y characters in SEARCH expressions are escaped well enough
    my $this = shift;

    my $actual =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"TestForm.Ecks~\'Bl>ah*\'" type="query" nototal="on"}%');
    my $expected = $this->toSiteCharSet(<<'HERE');
<div class="foswikiSearchResultsHeader"><span>Searched: <b><noautolink>TestForm.Ecks~&#39;Bl&#62;ah&#42;&#39;</noautolink></b></span><span id="foswikiNumberOfResultsContainer"></span></div>
HERE

    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"TestForm.Ecks = \'B/lah*\'" type="query" nototal="on"}%');
    $expected = $this->toSiteCharSet(<<'HERE');
<div class="foswikiSearchResultsHeader"><span>Searched: <b><noautolink>TestForm.Ecks &#61; &#39;B/lah&#42;&#39;</noautolink></b></span><span id="foswikiNumberOfResultsContainer"></span></div>
HERE
    $this->assert_str_equals( $expected, $actual );

    return;
}

#####################
#and again for multiple webs. :(
#TODO: rewrite using named params for more flexibility
#need summary, and multiple
sub _multiWebSeptic {
    my ( $this, $head, $foot, $sep, $results, $format, $default, %expectations )
      = @_;
    my $str = $results ? '*Preferences' : 'Septic';
    $head = $head        ? 'header="HEAD($web)"'            : '';
    $foot = $foot        ? 'footer="FOOT($ntopics,$nhits)"' : '';
    $sep  = defined $sep ? "separator=\"$sep\""             : '';
    $format = '$topic' unless ( defined($format) );
    my $expected = $this->_expect_with_deps( $default, %expectations );

    my $result = $this->{test_topicObject}->expandMacros(
        "%SEARCH{\"name~'$str'\" 
            web=\"System,Main\" 
            type=\"query\" 
            nosearch=\"on\" 
            nosummary=\"on\" 
            nototal=\"on\" 
            format=\"$format\" 
            $head $foot $sep }%"
    );
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

#####################

sub test_multiWeb_no_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        0, 0, undef, 1, undef, <<'FOSWIKI12',
SitePreferences
WebPreferences
DefaultPreferences
WebPreferences
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
DefaultPreferences
WebPreferences
SitePreferences
WebPreferences
FOSWIKI11

    return;
}

sub test_multiWeb_no_header_no_footer_no_separator_with_results_counters {
    my $this = shift;
    $this->_multiWebSeptic(
        0,                                  0, undef, 1,
        '$nhits, $ntopics, $index, $topic', <<'FOSWIKI12',
1, 1, 1, SitePreferences
2, 2, 2, WebPreferences
1, 1, 3, DefaultPreferences
2, 2, 4, WebPreferences
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
1, 1, 1, DefaultPreferences
2, 2, 2, WebPreferences
1, 1, 3, SitePreferences
2, 2, 4, WebPreferences
FOSWIKI11

    return;
}

sub test_multiWeb_no_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, undef, 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

sub test_multiWeb_no_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        0, 0, "", 1, undef, <<'FOSWIKI12',
SitePreferencesWebPreferencesDefaultPreferencesWebPreferences
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
DefaultPreferencesWebPreferencesSitePreferencesWebPreferences
FOSWIKI11

    return;
}

sub test_multiWeb_no_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, "", 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

sub test_multiWeb_no_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        0, 0, ",", 1, undef, <<'FOSWIKI12',
SitePreferences,WebPreferences,DefaultPreferences,WebPreferences
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
DefaultPreferences,WebPreferences,SitePreferences,WebPreferences
FOSWIKI11

    return;
}

sub test_multiWeb_no_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, ",", 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}
#####################

sub test_multiWeb_no_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        0, 1, undef, 1, undef, <<'FOSWIKI12',
SitePreferences
WebPreferences
FOOT(2,2)DefaultPreferences
WebPreferences
FOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
DefaultPreferences
WebPreferences
FOOT(2,2)SitePreferences
WebPreferences
FOOT(2,2)
FOSWIKI11

    return;
}

sub test_multiWeb_no_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, undef, 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

sub test_multiWeb_no_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        0, 1, "", 1, undef, <<'FOSWIKI12',
SitePreferencesWebPreferencesFOOT(2,2)DefaultPreferencesWebPreferencesFOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
DefaultPreferencesWebPreferencesFOOT(2,2)SitePreferencesWebPreferencesFOOT(2,2)
FOSWIKI11

    return;
}

sub test_multiWeb_no_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, "", 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

sub test_multiWeb_no_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        0, 1, ",", 1, undef, <<'FOSWIKI12',
SitePreferences,WebPreferencesFOOT(2,2)DefaultPreferences,WebPreferencesFOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
DefaultPreferences,WebPreferencesFOOT(2,2)SitePreferences,WebPreferencesFOOT(2,2)
FOSWIKI11

    return;
}

#####################

sub test_multiWeb_with_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        1, 1, undef, 1, undef, <<'FOSWIKI12',
HEAD(Main)
SitePreferences
WebPreferences
FOOT(2,2)HEAD(System)
DefaultPreferences
WebPreferences
FOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
HEAD(System)
DefaultPreferences
WebPreferences
FOOT(2,2)HEAD(Main)
SitePreferences
WebPreferences
FOOT(2,2)
FOSWIKI11

    return;
}

sub test_multiWeb_with_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, undef, 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

sub test_multiWeb_with_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        1, 1, "", 1, undef, <<'FOSWIKI12',
HEAD(Main)SitePreferencesWebPreferencesFOOT(2,2)HEAD(System)DefaultPreferencesWebPreferencesFOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
HEAD(System)DefaultPreferencesWebPreferencesFOOT(2,2)HEAD(Main)SitePreferencesWebPreferencesFOOT(2,2)
FOSWIKI11

    return;
}

sub test_multiWeb_with_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, "", 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

sub test_multiWeb_with_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        1, 1, ",", 1, undef, <<'FOSWIKI12',
HEAD(Main)SitePreferences,WebPreferencesFOOT(2,2)HEAD(System)DefaultPreferences,WebPreferencesFOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
HEAD(System)DefaultPreferences,WebPreferencesFOOT(2,2)HEAD(Main)SitePreferences,WebPreferencesFOOT(2,2)
FOSWIKI11

    return;
}

sub test_multiWeb_with_header_with_footer_with_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, ",", 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

#####################

sub test_multiWeb_with_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        1, 0, undef, 1, undef, <<'FOSWIKI12',
HEAD(Main)
SitePreferences
WebPreferences
HEAD(System)
DefaultPreferences
WebPreferences
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
HEAD(System)
DefaultPreferences
WebPreferences
HEAD(Main)
SitePreferences
WebPreferences
FOSWIKI11

    return;
}

sub test_multiWeb_with_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, undef, 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

sub test_multiWeb_with_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        1, 0, "", 1, undef, <<'FOSWIKI12',
HEAD(Main)SitePreferencesWebPreferencesHEAD(System)DefaultPreferencesWebPreferences
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
HEAD(System)DefaultPreferencesWebPreferencesHEAD(Main)SitePreferencesWebPreferences
FOSWIKI11

    return;
}

sub test_multiWeb_with_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, "", 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

sub test_multiWeb_with_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic(
        1, 0, ",", 1, undef, <<'FOSWIKI12',
HEAD(Main)SitePreferences,WebPreferencesHEAD(System)DefaultPreferences,WebPreferences
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
HEAD(System)DefaultPreferences,WebPreferencesHEAD(Main)SitePreferences,WebPreferences
FOSWIKI11

    return;
}

sub test_multiWeb_with_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, ",", 0, undef, <<'FOSWIKI12');
FOSWIKI12

    return;
}

#Item1992: calling Foswiki::Search::_makeTopicPattern repeatedly made a big mess.
sub test_web_and_topic_expansion {
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
    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Main.WebHome
Main.WebPreferences
FOOT(2,2)Sandbox.WebHome
Sandbox.WebPreferences
FOOT(2,2)System.WebHome
System.WebPreferences
FOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
System.WebHome
System.WebPreferences
FOOT(2,2)Main.WebHome
Main.WebPreferences
FOOT(2,2)Sandbox.WebHome
Sandbox.WebPreferences
FOOT(2,2)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

#####################
# PAGING
sub test_paging_three_webs_first_page {
    my $this   = shift;
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

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)Sandbox.WebChanges
FOOT(1,1)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
System.WebChanges
System.WebHome
System.WebIndex
System.WebPreferences
FOOT(4,4)Main.WebChanges
FOOT(1,1)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_three_webs_second_page {
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

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)System.WebChanges
System.WebHome
FOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(3,3)Sandbox.WebChanges
Sandbox.WebHome
FOOT(2,2)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_three_webs_third_page {
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

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
System.WebIndex
System.WebPreferences
FOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(2,2)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_three_webs_fourth_page {
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

    my $expected = $this->toSiteCharSet(<<'EXPECT');
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_three_webs_way_too_far {
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

    my $expected = $this->toSiteCharSet(<<'EXPECT');
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

#Item11860: SEARCH paging with zeroresults
#-----------------------------------
sub test_paging_three_webs_first_page_zeroresultsset {
    my $this   = shift;
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
    zeroresults="Empty"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)Sandbox.WebChanges
FOOT(1,1)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
System.WebChanges
System.WebHome
System.WebIndex
System.WebPreferences
FOOT(4,4)Main.WebChanges
FOOT(1,1)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_three_webs_second_page_zeroresultsset {
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
    zeroresults="Empty"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)System.WebChanges
System.WebHome
FOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(3,3)Sandbox.WebChanges
Sandbox.WebHome
FOOT(2,2)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_three_webs_third_page_zeroresultsset {
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
    zeroresults="Empty"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
System.WebIndex
System.WebPreferences
FOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(2,2)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_three_webs_fourth_page_zeroresultsset {
    my $this = shift;
    $this->expect_failure( 'Item11860 needs to be fixed!',
        with_dep => 'Foswiki,<,1.2' );

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
    zeroresults="Empty"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = $this->toSiteCharSet(<<'EXPECT');
Empty
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_three_webs_way_too_far_zeroresultsset {
    my $this = shift;
    $this->expect_failure( 'Item11860 needs to be fixed!',
        with_dep => 'Foswiki,<,1.2' );

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
    zeroresults="Empty"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = $this->toSiteCharSet(<<'EXPECT');
Empty
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

# Item10471
#------------------------------------
# non-PAGING with limit= should apply a per-web limit
sub verify_non_paging_with_limit {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    ".*"
    type="regex"
    web="System,Main,Sandbox"
    topic="WebPreferences"
    scope="text"
    nonoise="on"
    format="$web.$topic"
    limit="1"
    footer="FOOT($ntopics,$nhits)$n()"
}%'
    );
    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Main.WebPreferences
FOOT(1,1)
Sandbox.WebPreferences
FOOT(1,1)
System.WebPreferences
FOOT(1,1)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
System.WebPreferences
FOOT(1,1)
Main.WebPreferences
FOOT(1,1)
Sandbox.WebPreferences
FOOT(1,1)
FOSWIKI11

    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

#------------------------------------
# PAGING with limit= does weird things.
sub test_paging_with_limit_first_page {
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

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Main.WebChanges
Main.WebHome
Main.WebIndex
FOOT(3,3)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
System.WebChanges
System.WebHome
System.WebIndex
FOOT(3,3)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_with_limit_second_page {
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

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Sandbox.WebChanges
Sandbox.WebHome
Sandbox.WebIndex
FOOT(3,3)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
Main.WebChanges
Main.WebHome
Main.WebIndex
FOOT(3,3)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_with_limit_third_page {
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

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
System.WebChanges
System.WebHome
System.WebIndex
FOOT(3,3)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
Sandbox.WebChanges
Sandbox.WebHome
Sandbox.WebIndex
FOOT(3,3)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_with_limit_fourth_page {
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

    my $expected = $this->toSiteCharSet(<<'EXPECT');
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_paging_with_limit_way_too_far {
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

    my $expected = $this->toSiteCharSet(<<'EXPECT');
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

# Create three subwebs, and create a topic with the same name in all three
# which has a form and a field called "Order", which defines an ordering
# which is not the same as the ordering of the subwebs names. Now search
# the parent web recursively, with a sort order based on the value of the
# formfield. The sort should be based on the value of the 'Order' field.
#TODO: this is how the code has always worked, as the rendering of SEARCH results is done per web
#http://foswiki.org/Development/MakeSEARCHResultPartitioningByWebOptional
sub test_groupby_none_using_subwebs {
    my $this = shift;

    my $webObject = $this->populateNewWeb("$this->{test_web}/A");
    $webObject->finish();
    my ($topicObject) =
      Foswiki::Func::readTopic( "$this->{test_web}/A", 'TheTopic' );
    $topicObject->put( 'FORM', { name => "TestForm" } );
    $topicObject->putKeyed( 'FIELD',
        { name => "Order", title => "Order", value => "3" } );
    $topicObject->save( forcedate => 1000 );
    $topicObject->finish();

    $webObject = $this->populateNewWeb("$this->{test_web}/B");
    $webObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( "$this->{test_web}/B", 'TheTopic' );
    $topicObject->put( 'FORM', { name => "TestForm" } );
    $topicObject->putKeyed( 'FIELD',
        { name => "Order", title => "Order", value => "1" } );
    $topicObject->save( forcedate => 100 );
    $topicObject->finish();

    $webObject = $this->populateNewWeb("$this->{test_web}/C");
    $webObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( "$this->{test_web}/C", 'TheTopic' );
    $topicObject->put( 'FORM', { name => "TestForm" } );
    $topicObject->putKeyed( 'FIELD',
        { name => "Order", title => "Order", value => "2" } );
    $topicObject->save( forcedate => 500 );
    $topicObject->finish();
    my $result;

    #order by formfield, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<"GNURF" );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="formfield(Order)"
 format="\$web"
 separator=","
 groupby="none"
}%
GNURF
    $this->assert_equals(
        "$this->{test_web}/B,$this->{test_web}/C,$this->{test_web}/A\n",
        $result );

    #order by modified date, reverse=off, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<"GNURF" );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="modified"
 reverse="off"
 format="\$web \$date"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
"$this->{test_web}/B 01 Jan 1970 - 00:01, $this->{test_web}/C 01 Jan 1970 - 00:08, $this->{test_web}/A 01 Jan 1970 - 00:16\n",
        $result
    );

    #order by modified date, reverse=n, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<"GNURF" );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="modified"
 reverse="on"
 format="\$web \$date"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
"$this->{test_web}/A 01 Jan 1970 - 00:16, $this->{test_web}/C 01 Jan 1970 - 00:08, $this->{test_web}/B 01 Jan 1970 - 00:01\n",
        $result
    );

#and the same again, this time using header&footer, as that is what really shows the issue.
#order by formfield, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<"GNURF" );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="formfield(Order)"
 header="HEADER"
 format="\$web"
 footer="FOOTER"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
"HEADER$this->{test_web}/B, $this->{test_web}/C, $this->{test_web}/AFOOTER\n",
        $result
    );

    #order by modified date, reverse=off, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<"GNURF" );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="modified"
 reverse="off"
 header="HEADER"
 format="\$web \$date"
 footer="FOOTER"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
"HEADER$this->{test_web}/B 01 Jan 1970 - 00:01, $this->{test_web}/C 01 Jan 1970 - 00:08, $this->{test_web}/A 01 Jan 1970 - 00:16FOOTER\n",
        $result
    );

    #order by modified date, reverse=n, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<"GNURF" );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="modified"
 reverse="on"
 header="HEADER"
 format="\$web \$date"
 footer="FOOTER"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
"HEADER$this->{test_web}/A 01 Jan 1970 - 00:16, $this->{test_web}/C 01 Jan 1970 - 00:08, $this->{test_web}/B 01 Jan 1970 - 00:01FOOTER\n",
        $result
    );

    #order by modified, limit=2, with groupby=none
    # As order is last modification time, we need to ensure they're different
    # and that the order is fixed. So creating a bunch of test topics
    # SMELL: cdot disabled this test, because it craps all over Main,
    # System and Sandbox webs :-(
    return;

    my $now = time;
    my %testWebs = ( Main => 0, System => 60, Sandbox => 120 );
    while ( my ( $web, $delay ) = each %testWebs ) {
        my ($ltopicObject) = Foswiki::Func::readTopic( $web, 'TheTopic' );
        $ltopicObject->text(<<'CRUD');
Just some dummy search topic.
CRUD
        $ltopicObject->save( forcedate => $now - 240 + $delay );
        $ltopicObject->finish();
    }

    $result = $this->{test_topicObject}->expandMacros( <<"GNURF" );
%SEARCH{"1"
 type="query"
 web="$this->{test_web}/A,Main,System,Sandbox,"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="modified"
 header="HEADER"
 format="\$web \$topic"
 footer="FOOTER"
 separator=", "
 groupby="none"
 limit="2"
}%
GNURF
    $this->assert_equals( "HEADERMain TheTopic, System TheTopicFOOTER\n",
        $result );

    return;
}

# The results of SEARCH are highly sensitive to the template;
# reduce sensitivity by trimming the result
sub _cut_the_crap {
    my $result = shift;
    $result =~ s/<!--.*?-->//gs;
    $result =~ s/<\/?(em|span|div|b|h\d)\b.*?>//gs;
    $result =~ s/ (class|style|id|rel)=(["'])[^"']*\2//g;
    $result =~ s/( href=(["']))[^"']*(\2)/$1$3/g;
    $result =~ s/\d\d:\d\d( \(\w+\))?/TIME/g;
    $result =~ s/\d{2} \w{3} \d{4}/DATE/g;
    HTML::Entities::encode_entities( $result, '\x00-\x09\x0B-\x1F' );
    return $result;
}

sub test_no_format_no_junk {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros('%SEARCH{"BLEEGLE"}%');
    $this->assert_html_equals( <<"CRUD", _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>Results from <nop>$this->{test_web} web retrieved at TIME

<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by !WikiGuest

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by !WikiGuest

<a href="">Ok&AElig;Topic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by !WikiGuest

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by !WikiGuest

Number of topics: 4
CRUD

    # Now we create the WikiGuest user topic, to test both outputs
    my $session = $this->{session};
    if ( !$session->topicExists( 'TemporarySEARCHUsersWeb', 'WikiGuest' ) ) {
        my ($userTopic) =
          Foswiki::Func::readTopic( 'TemporarySEARCHUsersWeb', 'WikiGuest' );
        $userTopic->text('Just this poor old WikiGuest');
        $userTopic->save();
        $userTopic->finish();
    }
    $this->assert(
        $session->topicExists( 'TemporarySEARCHUsersWeb', 'WikiGuest' ),
        'Failed to create user topic in TemporarySEACHUsersWeb'
    );

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nosummary="on"}%');
    $this->assert_html_equals( <<"CRUD", _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>Results from <nop>$this->{test_web} web retrieved at TIME

<a href="">OkATopic</a>
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">OkBTopic</a>
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">Ok&AElig;Topic</a>
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">TestTopicSEARCH</a>
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nosearch="on"}%');
    $this->assert_html_equals( <<"CRUD", _cut_the_crap($result) );
Results from <nop>$this->{test_web} web retrieved at TIME

<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">Ok&AElig;Topic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]


<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nototal="on"}%');
    $this->assert_html_equals( <<"CRUD", _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>$this->{test_web} web retrieved at TIME

<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]



<a href="">Ok&AElig;Topic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" noheader="on"}%');
    $this->assert_html_equals( <<"CRUD", _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">Ok&AElig;Topic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" noempty="on"}%');
    $this->assert_html_equals( <<"CRUD", _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>$this->{test_web} web retrieved at TIME




<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">Ok&AElig;Topic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" zeroresults="on"}%');
    $this->assert_html_equals( <<"CRUD", _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>$this->{test_web} web retrieved at TIME




<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">Ok&AElig;Topic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by [[TemporarySEARCHUsersWeb.WikiGuest][WikiGuest]]

Number of topics: 4
CRUD

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" nosummary="on" nosearch="on" nototal="on" zeroresults="off" noheader="on" noempty="on"}%'
      );
    my $result2 =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nosummary="on" nonoise="on"}%');
    $result =
      HTML::Entities::encode_entities( $result, '^\n\x20-\x25\x27-\x7e' );
    $result2 =
      HTML::Entities::encode_entities( $result2, '^\n\x20-\x25\x27-\x7e' );

    $this->assert_html_equals( $result, $result2 );

    return;
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
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="word" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkÆTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == 3 );

    #$this->assert( $minus_dontcount == ($alltopics - $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="word" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkÆTopic,TestTopicSEARCH,WebPreferences', $result );
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
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="word" excludetopic="Some*"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkÆTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );

    return;
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
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals( 'OkÆTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == 2 );

    #$this->assert( $minus_dontcount == ($alltopics - $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals( 'OkÆTopic,TestTopicSEARCH,WebPreferences',
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
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="keyword" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkÆTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );

    return;
}

sub verify_search_type_literal {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="literal" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkBTopic', $result );
    my @list = split( /,/, $result );
    my $dontcount = $#list;
    $this->assert( $dontcount == 1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"+dont" scope="all" nonoise="on" format="$topic" separator="," type="literal" excludetopic="SomeOther*"}%'
      );
    @list = split( /,/, $result );
    $this->assert_str_equals( '', $result );
    my $plus_dontcount = $#list;
    $this->assert( $plus_dontcount == -1 );
    $this->assert( $plus_dontcount != $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="literal" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="literal" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals( 'OkÆTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 2 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="literal" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="literal" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkÆTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );

    return;
}

sub verify_search_type_regex {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="regex" excludetopic="SomeOther*"}%'
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
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="regex" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="regex" excludetopic="Some*"}%'
      );
    $this->assert_str_equals( 'OkÆTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 2 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="regex" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="regex" excludetopic="SomeOther*"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkÆTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );

    return;
}

# Item12951: Verify that regex characters in the stopwords string are not interpreted.
sub verify_stop_words_regex_meta_search_word {
    my $this = shift;

    use Foswiki::Func;
    my $origSetting = Foswiki::Func::getPreferencesValue('SEARCHSTOPWORDS');
    Foswiki::Func::setPreferencesValue( 'SEARCHSTOPWORDS',
        'xxx luv ,kiss, bye, i.e., a(b)' );

    my $TEST_TEXT  = "xxx i.e. Shamira IEEE a(b)";
    my $TEST_TOPIC = 'StopWordTestTopic';
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $TEST_TOPIC );
    $topicObject->text($TEST_TEXT);
    $topicObject->save();
    $topicObject->finish();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"IEEE" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_matches( qr/$TEST_TOPIC/, $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"a(b)" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( '', $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"i.e." type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( '', $result );

    Foswiki::Func::setPreferencesValue( 'SEARCHSTOPWORDS', $origSetting );

    return;
}

sub verify_stop_words_search_word {
    my $this = shift;

    use Foswiki::Func;
    my $origSetting = Foswiki::Func::getPreferencesValue('SEARCHSTOPWORDS');
    Foswiki::Func::setPreferencesValue( 'SEARCHSTOPWORDS',
        'xxx luv ,kiss, bye' );

    my $TEST_TEXT  = "xxx Shamira";
    my $TEST_TOPIC = 'StopWordTestTopic';
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $TEST_TOPIC );
    $topicObject->text($TEST_TEXT);
    $topicObject->save();
    $topicObject->finish();

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

    return;
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

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $topicName );
    $topicObject->text($TEST_SUMMARY_TEXT);
    $topicObject->save();
    $topicObject->finish();

    return;
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

    $this->assert_html_equals( <<'CRUD', $result );
Alan says<nop>: 'I was on a landing; there were banisters'. He pauses before describing the exact shape and details of the banisters. 'There was a thin man there. I wa...
CRUD

    return;
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

    $this->assert_html_equals( <<'CRUD', $result );
Alan says<nop>: 'I wa...
CRUD

    return;
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

    $this->assert_html_equals( <<'CRUD', $result );
<b>&hellip;</b>  his analysis and his need to <em>do</em> it very carefully. He knows  <b>&hellip;</b>  somewhere before! But how <em>do</em> I know I won't go mad and do  <b>&hellip;</b>  and psychoanalysis, and what <em>do</em> your lot do? Nothing <b>&hellip;</b>
CRUD

    return;
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

    $this->assert_html_equals( <<'CRUD', $result );
<b>&hellip;</b>  topple over too; might lose <em>his</em> balance. As Alan thought  <b>&hellip;</b> 
CRUD

    return;
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

    $this->assert_html_equals( <<'CRUD', $result );
<b>&hellip;</b>  topple over too; might lose <em>his</em> balance. As Alan thought  <b>&hellip;</b> about different parts of <em>his</em> dream he let his mind follow  <b>&hellip;</b> came to him. He thought about <em>his</em> weight loss programme. He  <b>&hellip;</b>  later. Perhaps it's because <em>his</em> next goal is 18 stone, he  <b>&hellip;</b> 
CRUD

    return;
}

sub verify_zeroresults {
    my $this = shift;
    my $result;

    $result = $this->{test_topicObject}->expandMacros('%SEARCH{"NOBLEEGLE"}%');
    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="on"}%');
    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="off"}%');
    $this->assert_equals( '', $result );

    #Item10324: should return the string '0' ? (I'm not so sure)
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="0"}%');
    $this->assert_equals( '', $result );
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="%NOP%0"}%');
    $this->assert_equals( '<nop>0', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults=" 0"}%');
    $this->assert_equals( '', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="1"}%');
    $this->assert_equals( '1', $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"NOBLEEGLE" zeroresults="I did not find anything."}%');
    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
I did not find anything.
RESULT

    #nototal=on
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on"}%');
    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on" zeroresults="on"}%');
    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on" zeroresults="off"}%');
    $this->assert_equals( '', $result );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"NOBLEEGLE" nototal="on" zeroresults="I did not find anything."}%'
      );
    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
I did not find anything.
RESULT

    #nototal=off
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off"}%');
    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off" zeroresults="on"}%');
    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off" zeroresults="off"}%');
    $this->assert_equals( '', $result );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"NOBLEEGLE" nototal="off" zeroresults="I did not find anything."}%'
      );
    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
I did not find anything.
RESULT

    return;
}

# Item8800: SEARCH date param
sub verify_date_param {
    my $this = shift;

    my $text = $this->toSiteCharSet(<<'HERE');
---+ Progressive Sexuality
A Symbol Interpreted In American Architecture. Meta-Physics Of Marxism & Poverty In The American Landscape. Exploration Of Crime In Mexican Sculptures: A Study Seen In American Literature. Brief Survey Of Suicide In Italian Art: The Big Picture. Special Studies In Bisexual Female Architecture. Brief Survey Of Suicide In Polytheistic Literature: Analysis, Analysis, and Critical Thinking. Radical Paganism: Modern Theories. Liberal Mexican Religion In The Modern Age. 

HERE
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "VeryOldTopic" );
    $topicObject->text($text);
    $topicObject->put(
        'TOPICINFO',
        {
            author  => "TopicUserMapping_guest",
            date    => "1",
            format  => "1.1",
            version => "1.2"
        }
    );
    my $rev = $topicObject->save( forcedate => 86420 ); # > 86400, see Item10389
    $this->assert_num_equals( 1, $rev );
    $topicObject->finish();

    #TODO: sadly, the core Handlers don't set the filedate
    # even though they could
    # my $file_date =
    #   $this->{session}->{store}
    #   ->getApproxRevTime( $this->{test_web}, "VeryOldTopic" );
    # $this->assert_num_equals(86420, $file_date);

    my $result = $this->{test_topicObject}

      #SMELL:
      #TODO: the query type should be abstracted to test each&all backends
      ->expandMacros(
        '%SEARCH{"1" type="query" date="1970" nonoise="on" format="$topic"}%');

    $this->assert_html_equals( <<'RESULT', _cut_the_crap($result) );
VeryOldTopic
RESULT

    return;
}

sub verify_nl_in_result {
    my $this = shift;
    my $text = $this->toSiteCharSet(<<'HERE');
Radical Meta-Physics
Marxism
Crime
Suicide
Paganism.
HERE
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "OffColour" );
    $topicObject->text($text);
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Name",
            title => "Name",
            value => "Meta-Physics\nMarxism\nCrime\nSuicide\nPaganism."
        }
    );
    $topicObject->save();
    $topicObject->finish();

    my $result;

    # Default $formfield, \n expands to <br /> because people most often display
    # multiline form fields in TML tables and \n would disturb the tables
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"OffColour" scope="topic" nonoise="on" format="$formfield(Name)"}%'
      );
    $this->assert_str_equals( <<'RESULT', "$result\n" );
Meta-Physics<br />Marxism<br />Crime<br />Suicide<br />Paganism.
RESULT

    # Default $pattern, \n expands to \n (more sensible)
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"OffColour" scope="topic" nonoise="on" format="$pattern(.*?(Meta.*?Paganism).*)"}%'
      );
    $this->assert_str_equals( <<'RESULT', "$result\n" );
Meta-Physics
Marxism
Crime
Suicide
Paganism
RESULT

    # $pattern newline="X", \n expands to X
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"OffColour" scope="topic" nonoise="on" format="$pattern(.*?(Meta.*?Paganism).*)" newline="X"}%'
      );
    $this->assert_str_equals( <<'RESULT', "$result\n" );
Meta-PhysicsXMarxismXCrimeXSuicideXPaganism
RESULT

    # $formfield, newline="X", \n in form data expands to X
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"OffColour" scope="topic" nonoise="on" format="$formfield(Name)" newline="X"}%'
      );
    $this->assert_str_equals( <<RESULT, "$result\n" );
Meta-PhysicsXMarxismXCrimeXSuicideXPaganism.
RESULT

    return;
}

###########################################
#pager formatting
sub test_pager_on {
    my $this = shift;

    my $viewTopicUrl =
      Foswiki::Func::getScriptUrl( $this->{test_topicObject}->web,
        $this->{test_topicObject}->topic, 'view' );

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
    pager="on"
}%'
    );

    my $expected = $this->_expect_with_deps(
        <<"FOSWIKI12",
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)Sandbox.WebChanges
FOOT(1,1)<div class="foswikiSearchResultsPager">
  Page 1 of 3  [[$viewTopicUrl?SEARCHc6139cf1d63c9614230f742fca2c6a36=2][Next >]]
</div>
FOSWIKI12
        'Foswiki,<,1.2' => <<"FOSWIKI11");
System.WebChanges
System.WebHome
System.WebIndex
System.WebPreferences
FOOT(4,4)Main.WebChanges
FOOT(1,1)<div class="foswikiSearchResultsPager">
   Page 1 of 3   [[$viewTopicUrl?SEARCHc6139cf1d63c9614230f742fca2c6a36=2][Next >]]
</div>
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    $result = $this->{test_topicObject}->expandMacros(
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
    pager="on"
}%'
    );

    $expected = $this->_expect_with_deps(
        <<"FOSWIKI12",
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)System.WebChanges
System.WebHome
FOOT(2,2)<div class="foswikiSearchResultsPager">
[[$viewTopicUrl?SEARCH6331ae02a320baf1478c8302e38b7577=1][< Previous]]  Page 2 of 3  [[$viewTopicUrl?SEARCH6331ae02a320baf1478c8302e38b7577=3][Next >]]
</div>
FOSWIKI12
        'Foswiki,<,1.2' => <<"FOSWIKI11");
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(3,3)Sandbox.WebChanges
Sandbox.WebHome
FOOT(2,2)<div class="foswikiSearchResultsPager">
[[$viewTopicUrl?SEARCH6331ae02a320baf1478c8302e38b7577=1][< Previous]]   Page 2 of 3   [[$viewTopicUrl?SEARCH6331ae02a320baf1478c8302e38b7577=3][Next >]]
</div>
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_pager_on_pagerformat {
    my $this = shift;

    my $viewTopicUrl =
      Foswiki::Func::getScriptUrl( $this->{test_topicObject}->web,
        $this->{test_topicObject}->topic, 'view' );

    my $result = $this->{test_topicObject}->expandMacros(<<'EXPECT');
%SEARCH{
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
    pager="on"
    pagerformat="$n..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize, prevurl=$previousurl, nexturl=$nexturl..$n"
}%
EXPECT

    my $expected = $this->_expect_with_deps(
        <<"FOSWIKI12",
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)Sandbox.WebChanges
FOOT(1,1)
..prev=0, 1, next=2, numberofpages=3, pagesize=5, prevurl=, nexturl=$viewTopicUrl?SEARCHe9863b5d7ec27abeb8421578b0747c25=2..
FOSWIKI12
        'Foswiki,<,1.2' => <<"FOSWIKI11");
System.WebChanges
System.WebHome
System.WebIndex
System.WebPreferences
FOOT(4,4)Main.WebChanges
FOOT(1,1)
..prev=0, 1, next=2, numberofpages=3, pagesize=5, prevurl=, nexturl=$viewTopicUrl?SEARCHe9863b5d7ec27abeb8421578b0747c25=2..
FOSWIKI11
    $this->assert_str_equals( $expected, $result );

    $result = $this->{test_topicObject}->expandMacros(
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
    pager="on"
    pagerformat="$n..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize, prevurl=$previousurl, nexturl=$nexturl..$n"
}%
'
    );

    $expected = $this->_expect_with_deps(
        <<"FOSWIKI12",
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)System.WebChanges
System.WebHome
FOOT(2,2)
..prev=1, 2, next=3, numberofpages=3, pagesize=5, prevurl=$viewTopicUrl?SEARCHc5ceccfcec96473a9efe986cf3597eb1=1, nexturl=$viewTopicUrl?SEARCHc5ceccfcec96473a9efe986cf3597eb1=3..
FOSWIKI12
        'Foswiki,<,1.2' => <<"FOSWIKI11");
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(3,3)Sandbox.WebChanges
Sandbox.WebHome
FOOT(2,2)
..prev=1, 2, next=3, numberofpages=3, pagesize=5, prevurl=$viewTopicUrl?SEARCHc5ceccfcec96473a9efe986cf3597eb1=1, nexturl=$viewTopicUrl?SEARCHc5ceccfcec96473a9efe986cf3597eb1=3..
FOSWIKI11
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_pager_off_pagerformat {
    my $this = shift;

    my $viewTopicUrl =
      Foswiki::Func::getScriptUrl( $this->{test_topicObject}->web,
        $this->{test_topicObject}->topic, 'view' );

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
    pager="off"
    pagerformat="$n..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize, prevurl=$previousurl, nexturl=$nexturl..$n"
}%'
    );

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)Sandbox.WebChanges
FOOT(1,1)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
System.WebChanges
System.WebHome
System.WebIndex
System.WebPreferences
FOOT(4,4)Main.WebChanges
FOOT(1,1)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    $result = $this->{test_topicObject}->expandMacros(
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
    OFFpager="on"
    pagerformat="$n..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize, prevurl=$previousurl, nexturl=$nexturl..$n"
}%'
    );

    $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)System.WebChanges
System.WebHome
FOOT(2,2)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(3,3)Sandbox.WebChanges
Sandbox.WebHome
FOOT(2,2)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_pager_off_pagerformat_pagerinheaderfooter {
    my $this = shift;

    my $viewTopicUrl =
      Foswiki::Func::getScriptUrl( $this->{test_topicObject}->web,
        $this->{test_topicObject}->topic, 'view' );

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
    header="HEADER($pager)"
    footer="FOOT($ntopics,$nhits)($pager)"
    pager="off"
    pagerformat="..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize.."
}%'
    );

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
HEADER(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)HEADER(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)
Sandbox.WebChanges
FOOT(1,1)(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
HEADER(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)
System.WebChanges
System.WebHome
System.WebIndex
System.WebPreferences
FOOT(4,4)(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)HEADER(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)
Main.WebChanges
FOOT(1,1)(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    $result = $this->{test_topicObject}->expandMacros(
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
    header="HEADER($pager)"
    footer="FOOT($ntopics,$nhits)($pager)"
    OFFpager="on"
    pagerformat="..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize.."
}%'
    );

    $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
HEADER(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)HEADER(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
System.WebChanges
System.WebHome
FOOT(2,2)(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
HEADER(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(3,3)(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)HEADER(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
Sandbox.WebChanges
Sandbox.WebHome
FOOT(2,2)(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
FOSWIKI11
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub verify_pager_off_pagerformat_pagerinall {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic ($pager)ntopics=$ntopics"
    showpage="2"
    pagesize="5"
    header="HEADER($pager)ntopics=$ntopics"
    footer="FOOT($ntopics,$nhits)($pager)"
    OFFpager="on"
    pagerformat="ntopics=$ntopics..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize.."
}%'
    );

    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
HEADER(ntopics=0..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=0
Sandbox.WebHome (ntopics=1..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=1
Sandbox.WebIndex (ntopics=2..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=2
Sandbox.WebPreferences (ntopics=3..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=3
FOOT(3,3)(ntopics=3..prev=1, 2, next=3, numberofpages=3, pagesize=5..)HEADER(ntopics=0..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=0
System.WebChanges (ntopics=1..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=1
System.WebHome (ntopics=2..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=2
FOOT(2,2)(ntopics=2..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
HEADER(ntopics=0..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=0
Main.WebHome (ntopics=1..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=1
Main.WebIndex (ntopics=2..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=2
Main.WebPreferences (ntopics=3..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=3
FOOT(3,3)(ntopics=3..prev=1, 2, next=3, numberofpages=3, pagesize=5..)HEADER(ntopics=0..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=0
Sandbox.WebChanges (ntopics=1..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=1
Sandbox.WebHome (ntopics=2..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=2
FOOT(2,2)(ntopics=2..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
FOSWIKI11

    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    return;
}

sub test_simple_format {
    my $this = shift;

    my $actual = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "(WebPreferences|WebTopicList|WebHome)$"
    type="regex"
    scope="topic"
    web="TestCases, %SYSTEMWEB%, Main, Sandbox"
    format="   * !$web.$topic"
    nosearch="on"
}%
'
    );
    my $expected = $this->_expect_with_deps(
        <<'FOSWIKI12',
   * !Main.WebHome
   * !Main.WebPreferences
   * !Main.WebTopicList
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
   * !Sandbox.WebHome
   * !Sandbox.WebPreferences
   * !Sandbox.WebTopicList
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
   * !System.WebHome
   * !System.WebPreferences
   * !System.WebTopicList
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
   * !TestCases.WebHome
   * !TestCases.WebPreferences
   * !TestCases.WebTopicList
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
FOSWIKI12
        'Foswiki,<,1.2' => <<'FOSWIKI11');
   * !TestCases.WebHome
   * !TestCases.WebPreferences
   * !TestCases.WebTopicList
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
   * !System.WebHome
   * !System.WebPreferences
   * !System.WebTopicList
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
   * !Main.WebHome
   * !Main.WebPreferences
   * !Main.WebTopicList
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
   * !Sandbox.WebHome
   * !Sandbox.WebPreferences
   * !Sandbox.WebTopicList
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
FOSWIKI11

    $this->assert_str_equals( $expected, $actual );

    return;
}

sub test_formatdotBang {
    my $this = shift;

    my $actual = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "(WebPreferences|WebTopicList|WebHome)$"
    type="regex"
    scope="topic"
    web="%SYSTEMWEB%"
    format="   * !$web.!$topic"
    nosearch="on"
}%
'
    );
    my $expected = $this->toSiteCharSet(<<'HERE');
   * !System.!WebHome
   * !System.!WebPreferences
   * !System.!WebTopicList
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
HERE

    $this->assert_str_equals( $expected, $actual );

    return;
}

sub test_delayed_expansion {
    my $this = shift;
    $this->assert( eval { require Foswiki::Macros::SEARCH; 1; }
          and not $EVAL_ERROR );

    my $result = $Foswiki::Plugins::SESSION->SEARCH(
        {
            _DEFAULT  => "1",
            type      => "query",
            nonoise   => "on",
            web       => "Main, System",
            topic     => "WebHome,WebIndex, WebPreferences",
            format    => '$topic',
            separator => ", ",
        },
        $this->{test_topicObject}
    );
    $this->assert_str_equals(
        $this->toSiteCharSet(<<'EXPECT'), $result . "\n" );
WebHome, WebIndex, WebPreferences, WebHome, WebIndex, WebPreferences
EXPECT

    $result = $Foswiki::Plugins::SESSION->SEARCH(
        {
            _DEFAULT  => "1",
            type      => "query",
            nonoise   => "on",
            web       => "Main, System",
            topic     => "WebHome,WebIndex, WebPreferences",
            format    => '$percentWIKINAME$percent',
            separator => ", ",
        },
        $this->{test_topicObject}
    );
    $this->assert_str_equals(
        $this->toSiteCharSet(<<'EXPECT'), $result . "\n" );
%WIKINAME%, %WIKINAME%, %WIKINAME%, %WIKINAME%, %WIKINAME%, %WIKINAME%
EXPECT

#Item8849: the header (and similarly footer) are expended once too often, FOREACh and SEARCH should return the raw TML, which is _then_ expanded
    $result = $Foswiki::Plugins::SESSION->SEARCH(
        {
            _DEFAULT  => "1",
            type      => "query",
            nonoise   => "on",
            web       => "Main, System",
            topic     => "WebHome,WebIndex, WebPreferences",
            header    => '$percentINCLUDE{Main.WebHeader}$percent',
            footer    => '$percentINCLUDE{Main.WebFooter}$percent',
            format    => '$topic',
            separator => ", ",
        },
        $this->{test_topicObject}
    );
    $this->assert_str_equals(
        $this->toSiteCharSet(<<'EXPECT'), $result . "\n" );
%INCLUDE{Main.WebHeader}%WebHome, WebIndex, WebPreferences%INCLUDE{Main.WebFooter}%%INCLUDE{Main.WebHeader}%WebHome, WebIndex, WebPreferences%INCLUDE{Main.WebFooter}%
EXPECT

    return;
}

####################################
#order tests.
sub set_up_for_sorting {
    my $this = shift;
    my $text = $this->toSiteCharSet(<<'HERE');
something before. Another
This is QueryTopic FURTLE
somethig after

HERE

#    $this->{twiki}->{store}->saveTopic( 'simon',
#        $this->{test_web}, 'QueryTopic', $text, undef, {forcedate=>1178612772} );
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopic' );
    $topicObject->text($text);
    $topicObject->put(
        'TOPICINFO',
        {
            author  => "TopicUserMapping_simon",
            date    => "1178612772",
            format  => "1.1",
            version => "1.1"
        }
    );
    $topicObject->put( 'TOPICPARENT', { name => "WebHome" } );
    $topicObject->put( 'FORM',        { name => "TestyForm" } );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldA",
            title => "B Field",
            value => "1234"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldB",
            title => "Banother Field",
            value => "098"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldC",
            title => "Banother Field",
            value => "11"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Firstname",
            title => "Pre Name",
            value => "Pedro"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Lastname",
            title => "Post Name",
            value => "Peal"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "form",
            title => "Blah",
            value => "form good"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FORM",
            title => "Blah",
            value => "FORM GOOD"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Date",
            title => "Date",
            value => "12 Dec 2010"
        }
    );
    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "porn.gif",
            comment => "Cor",
            date    => "15062",
            size    => "15504"
        }
    );
    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "flib.xml",
            comment => "Cor",
            date    => "1157965062",
            size    => "1"
        }
    );
    $topicObject->save(
        forcedate        => 1178412772,
        author           => 'admin',
        forcenewrevision => 1
    );
    $topicObject->save(
        forcedate        => 1178612772,
        author           => 'simon',
        forcenewrevision => 1
    );
    $topicObject->finish();

    $text = $this->toSiteCharSet(<<'HERE');
first line
This is QueryTopicTwo SMONG
third line
HERE

    #$this->{twiki}->{store}->saveTopic( 'admin',
    #    $this->{test_web}, 'QueryTopicTwo', $text, undef, {forcedate=>12} );
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicTwo' );
    $topicObject->text($text);
    $topicObject->put(
        'TOPICINFO',
        {
            author  => "BaseUserMapping_666",
            date    => "1108412772",
            format  => "1.1",
            version => "1.2"
        }
    );
    $topicObject->put( 'TOPICPARENT', { name => "QueryTopic" } );
    $topicObject->put( 'FORM',        { name => "TestyForm" } );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldA",
            title => "B Field",
            value => "7"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldB",
            title => "Banother Field",
            value => "8"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldC",
            title => "Banother Field",
            value => "2"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Firstname",
            title => "Pre Name",
            value => "John"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Lastname",
            title => "Post Name",
            value => "Peel"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "form",
            title => "Blah",
            value => "form good"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FORM",
            title => "Blah",
            value => "FORM GOOD"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Date",
            title => "Date",
            value => "15 Nov 2010"
        }
    );
    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "porn.gif",
            comment => "Cor",
            date    => "15062",
            size    => "15504"
        }
    );
    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "flib.xml",
            comment => "Cor",
            date    => "1157965062",
            size    => "1"
        }
    );
    $topicObject->save(
        forcedate        => 1108312772,
        author           => 'admin',
        forcenewrevision => 1
    );
    $topicObject->save(
        forcedate        => 1178612772,
        author           => 'simon',
        forcenewrevision => 1
    );
    $topicObject->finish();

    $text = $this->toSiteCharSet(<<'HERE');
first line
This is QueryTopicThree SMONG
third line
HERE

    #$this->{twiki}->{store}->saveTopic( 'Gerald',
    #    $this->{test_web}, 'QueryTopicThree', $text, undef, {forcedate=>14} );
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'QueryTopicThree' );
    $topicObject->text($text);
    $topicObject->put(
        'TOPICINFO',
        {
            author  => "TopicUserMapping_Gerald",
            date    => "1108412782",
            format  => "1.1",
            version => "1.2"
        }
    );
    $topicObject->put( 'TOPICPARENT', { name => "QueryTopic" } );
    $topicObject->put( 'FORM',        { name => "TestyForm" } );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldA",
            title => "B Field",
            value => "2"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldB",
            title => "Banother Field",
            value => "-0.12"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FieldC",
            title => "Banother Field",
            value => "10"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Firstname",
            title => "Pre Name",
            value => "Jason"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Lastname",
            title => "Post Name",
            value => "Peel"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "form",
            title => "Blah",
            value => "form good"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "FORM",
            title => "Blah",
            value => "FORM GOOD"
        }
    );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Date",
            title => "Date",
            value => "30 Jan 2010"
        }
    );
    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "porn.gif",
            comment => "Cor",
            date    => "15062",
            size    => "15504"
        }
    );
    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "flib.xml",
            comment => "Cor",
            date    => "1157965062",
            size    => "1"
        }
    );
    $topicObject->save( forcedate => 1108413782, author => 'Gerald' );
    $topicObject->finish();

    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( $this->{test_web}, $this->{session}->{webName} );

    return;
}

sub test_orderTopic {
    my $this = shift;

    $this->set_up_for_sorting();
    my $search =
        '%SEARCH{".*" type="regex" scope="topic" web="'
      . $this->{test_web}
      . '" format="$topic" separator="," nonoise="on" '
      . 'excludetopic="SomeOtherÆØÅTopic" ';
    my $result;

    #DEFAULT sort=topic..
    $result = $this->{test_topicObject}->expandMacros( $search . '}%' );
    $this->assert_str_equals(

"OkATopic,OkBTopic,OkÆTopic,QueryTopic,QueryTopicThree,QueryTopicTwo,TestTopicSEARCH,WebPreferences",
        $result
    );

    #order=topic
    $result =
      $this->{test_topicObject}->expandMacros( $search . 'order="topic"}%' );
    $this->assert_str_equals(
"OkATopic,OkBTopic,OkÆTopic,QueryTopic,QueryTopicThree,QueryTopicTwo,TestTopicSEARCH,WebPreferences",
        $result
    );

    $result =
      $this->{test_topicObject}
      ->expandMacros( $search . 'order="topic" reverse="on"}%' );
    $this->assert_str_equals(
"WebPreferences,TestTopicSEARCH,QueryTopicTwo,QueryTopicThree,QueryTopic,OkÆTopic,OkBTopic,OkATopic",
        $result
    );

    #order=created
    $result =
      $this->{test_topicObject}
      ->expandMacros( $search . 'order="created" format="$topic"}%' );

    $this->assert_str_equals(
"QueryTopicTwo,QueryTopicThree,QueryTopic,WebPreferences,TestTopicSEARCH,OkÆTopic,OkATopic,OkBTopic",
        $result
    );

    $result =
      $this->{test_topicObject}
      ->expandMacros( $search . 'order="created" reverse="on"}%' );

    $this->assert_str_equals(
"OkBTopic,OkATopic,OkÆTopic,TestTopicSEARCH,WebPreferences,QueryTopic,QueryTopicThree,QueryTopicTwo",
        $result
    );

    #order=modified
    $result =
      $this->{test_topicObject}->expandMacros( $search . 'order="modified"}%' );

    $this->assert_str_equals(
"QueryTopicThree,QueryTopic,QueryTopicTwo,WebPreferences,TestTopicSEARCH,OkÆTopic,OkATopic,OkBTopic",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros(
        $search . 'order="modified" reverse="on" format="$topic"}%' );

#be very careful with this test and the one above - the change in order between QueryTopicTwo,QueryTopic is due to them having the same date, so its sorting by topicname
    $this->assert_str_equals(
"OkBTopic,OkATopic,OkÆTopic,TestTopicSEARCH,WebPreferences,QueryTopic,QueryTopicTwo,QueryTopicThree",
        $result
    );

    #order=editby
    #TODO: imo this is a bug - alpha sorting should be caseinsensitive
    $result =
      $this->{test_topicObject}->expandMacros(
        $search . 'order="editby" format="$topic ($wikiname)"}%' );

#    $this->assert_str_equals( "QueryTopicThree (Gerald),OkATopic (WikiGuest),OkBTopic (WikiGuest),OkÆTopic (WikiGuest),TestTopicSEARCH (WikiGuest),WebPreferences (WikiGuest),QueryTopicTwo (admin),QueryTopic (simon)", $result );
#    $this->assert_str_equals(
#"QueryTopicThree (Gerald),OkÆTopic (WikiGuest),OkBTopic (WikiGuest),WebPreferences (WikiGuest),TestTopicSEARCH (WikiGuest),OkATopic (WikiGuest),QueryTopicTwo (admin),QueryTopic (simon)",
#        $result
#    );
#needed to allow for store based differences in non-specified fields (ie, if sort on editby, then topic order is random - dependent on store impl)
    $this->assert_matches(
qr/^QueryTopicThree \(Gerald\),.*WikiGuest\),QueryTopic \(simon\),QueryTopicTwo \(simon\)$/,
        $result
    );

    #TODO: why is this different from 1.0.x?

    $result =
      $this->{test_topicObject}->expandMacros(
        $search . 'order="editby" reverse="on" format="$topic ($wikiname)"}%' );

#    $this->assert_str_equals( "QueryTopic (simon),QueryTopicTwo (admin),OkATopic (WikiGuest),OkBTopic (WikiGuest),OkÆTopic (WikiGuest),TestTopicSEARCH (WikiGuest),WebPreferences (WikiGuest),QueryTopicThree (Gerald)", $result );
#    $this->assert_str_equals(
#"QueryTopic (simon),QueryTopicTwo (admin),OkÆTopic (WikiGuest),OkBTopic (WikiGuest),WebPreferences (WikiGuest),TestTopicSEARCH (WikiGuest),OkATopic (WikiGuest),QueryTopicThree (Gerald)",
#        $result
#    );
#needed to allow for store based differences in non-specified fields (ie, if sort on editby, then topic order is random - dependent on store impl)
    $this->assert_matches(
qr/^QueryTopic \(simon\),QueryTopicTwo \(simon\),.*\(WikiGuest\),QueryTopicThree \(Gerald\)$/,
        $result
    );

    #TODO: why is this different from 1.0.x?

    #order=formfield(FieldA)
    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(FieldA)" format="$topic ($formfield(FieldA))"}%'
      );

#$this->assert_str_equals( "OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicThree (2),QueryTopicTwo (7),QueryTopic (1234)", $result );
#    $this->assert_str_equals(
#"OkÆTopic (),OkBTopic (),WebPreferences (),TestTopicSEARCH (),OkATopic (),QueryTopicThree (2),QueryTopicTwo (7),QueryTopic (1234)",
#        $result
#    );
    $this->assert_matches(
        qr/\(\),QueryTopicThree \(2\),QueryTopicTwo \(7\),QueryTopic \(1234\)$/,
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(FieldA)" reverse="on" format="$topic ($formfield(FieldA))"}%'
      );

#$this->assert_str_equals( "QueryTopic (1234),QueryTopicTwo (7),QueryTopicThree (2),OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences ()", $result );
    $this->assert_str_equals(
"QueryTopic (1234),QueryTopicTwo (7),QueryTopicThree (2),OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences ()",
        $result
    );

    #order=formfield(FieldB)
    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(FieldB)" format="$topic ($formfield(FieldB))"}%'
      );

#$this->assert_str_equals( "OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicThree (-0.12),QueryTopicTwo (8),QueryTopic (098)", $result );
    $this->assert_str_equals(
"OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicThree (-0.12),QueryTopicTwo (8),QueryTopic (098)",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(FieldB)" reverse="on" format="$topic ($formfield(FieldB))"}%'
      );

#$this->assert_str_equals( "QueryTopic (098),QueryTopicTwo (8),QueryTopicThree (-0.12),OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences ()", $result );
    $this->assert_str_equals(
"QueryTopic (098),QueryTopicTwo (8),QueryTopicThree (-0.12),OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences ()",
        $result
    );

    #order=formfield(FieldC)
    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(FieldC)" format="$topic ($formfield(FieldC))"}%'
      );

#$this->assert_str_equals( "OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicTwo (2),QueryTopicThree (10),QueryTopic (11)", $result );
    $this->assert_str_equals(
"OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicTwo (2),QueryTopicThree (10),QueryTopic (11)",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(FieldC)" reverse="on" format="$topic ($formfield(FieldC))"}%'
      );

#$this->assert_str_equals( "QueryTopic (11),QueryTopicThree (10),QueryTopicTwo (2),OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences ()", $result );
    $this->assert_str_equals(
"QueryTopic (11),QueryTopicThree (10),QueryTopicTwo (2),OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences ()",
        $result
    );

    #order=formfield(Firstname)
    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(Firstname)" format="$topic ($formfield(Firstname))"}%'
      );

#$this->assert_str_equals( "OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicThree (Jason),QueryTopicTwo (John),QueryTopic (Pedro)", $result );
    $this->assert_str_equals(
"OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicThree (Jason),QueryTopicTwo (John),QueryTopic (Pedro)",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(Firstname)" reverse="on" format="$topic ($formfield(Firstname))"}%'
      );

#$this->assert_str_equals( "QueryTopic (Pedro),QueryTopicTwo (John),QueryTopicThree (Jason),OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences ()", $result );
    $this->assert_str_equals(
"QueryTopic (Pedro),QueryTopicTwo (John),QueryTopicThree (Jason),OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences ()",
        $result
    );

    #order=formfield(Date)
    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(Date)" format="$topic ($formfield(Date))"}%' );

    $this->assert_str_equals(
"OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicThree (30 Jan 2010),QueryTopicTwo (15 Nov 2010),QueryTopic (12 Dec 2010)",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros( $search
          . 'order="formfield(Date)" reverse="on" format="$topic ($formfield(Date))"}%'
      );

    $this->assert_str_equals(
"QueryTopic (12 Dec 2010),QueryTopicTwo (15 Nov 2010),QueryTopicThree (30 Jan 2010),OkATopic (),OkBTopic (),OkÆTopic (),TestTopicSEARCH (),WebPreferences ()",
        $result
    );

    return;
}

sub verify_bad_order {
    my $this = shift;

    $this->set_up_for_sorting();
    my $search =
        '%SEARCH{".*" type="regex" scope="topic" web="'
      . $this->{test_web}
      . '" format="$topic" separator="," nonoise="on"  excludetopic="Some*"';
    my $result =
      $this->{test_topicObject}
      ->expandMacros( $search . 'order="formfield()"}%' );

    # Should get the default search order (or an error message, perhaps?)
    $this->assert_str_equals(
"OkATopic,OkBTopic,OkÆTopic,QueryTopic,QueryTopicThree,QueryTopicTwo,TestTopicSEARCH,WebPreferences",
        $result
    );

    return;
}

sub test_Item9269 {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"does not matc[h]" 
  type="regex" 
  zeroresults="$dollarweb=$web" 
  format="dummy" 
}%'
    );

    $this->assert_str_equals( "\$web=$this->{test_web}", $result );

    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{".*" 
  limit="1" 
  type="regex" 
  nonoise="on"
  header="header: $dollarweb=$web%BR%" 
  format="format: $dollarweb=$web%BR%" 
  footer="footer: $dollarweb=$web" 
}%'
    );

    $this->assert_str_equals(
        "header: \$web=$this->{test_web}<br />
format: \$web=$this->{test_web}<br />
footer: \$web=$this->{test_web}", $result
    );

    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{".*"
  type="regex"
  nonoise="on"
  format="   1 $topic"
  pager="on"
  pagesize="4"
  pagerformat="pagerformat: $dollarweb=$web"
  excludetopic="*Other*"
}%'
    );
    $this->assert_str_equals(
        "   1 OkATopic
   1 OkBTopic
   1 OkÆTopic
   1 TestTopicSEARCH
pagerformat: \$web=$this->{test_web}", $result
    );

    return;
}

sub test_Item13995 {
    my $this = shift;

    # Create 3 revisions
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'RevTopic' );
    $topicObject->text("Drums Beat");
    $topicObject->save( forcenewrevision => 1 );
    $topicObject->text("BLEEGLE blah/matchme.blah");
    $topicObject->save( forcenewrevision => 1 );
    $topicObject->text("BELLS Ring");
    $topicObject->save( forcenewrevision => 1 );
    $topicObject->finish();

    #Simple $changes -  compare Rev 2 - Rev 3
    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"1"
  type="query"
  web="%WEB%"
  topic="RevTopic"
  nonoise="on"
  format="FOO $changes$n"
}%'
    );

    my $expected = <<"EXP";
FOO  <nop>$this->{test_web}.RevTopic 
-<nop>BLEEGLE blah/matchme.blah
+<nop>BELLS Ring
EXP
    $this->assert_equals( $expected, $result );

    #$changes(1) -  compare Rev 1 - Rev 3
    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"1"
  type="query"
  web="%WEB%"
  topic="RevTopic"
  nonoise="on"
  format="FOO $changes(1)$n"
}%'
    );

    $expected = <<"EXP";
FOO  <nop>$this->{test_web}.RevTopic 
-Drums Beat
+<nop>BELLS Ring
EXP
    $this->assert_equals( $expected, $result );

    #$changes() -  undef rev,  generate a summary
    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"1"
  type="query"
  web="%WEB%"
  topic="RevTopic"
  nonoise="on"
  format="FOO $changes()$n"
}%'
    );

    $expected = <<"EXP";
FOO <nop>$this->{test_web}.RevTopic <nop>BELLS Ring
EXP
    $this->assert_equals( $expected, $result );

    return;
}

sub test_Item9502 {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"1"
  type="query"
  web="%WEB%"
  topic="%TOPIC%"
  nonoise="on"
  format="FOO $changes(x)"
}%'
    );

    $this->assert_matches( qr/^FOO /, $result );

    return;
}

# Item9915 and Item9911
sub test_format_tokens {
    my $this = shift;
    local $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $emailAddress =
      $this->{test_topicObject}
      ->expandMacros('%USERINFO{"ScumBag" format="$emails"}%');
    $this->assert_matches( qr/^[a-z]+\@[a-z.]+$/, $emailAddress );
    my $testTopic = 'TestFormatTokens';
    my $header    = "Search with Userinfo";
    my $body      = '   * Set POTLEADER = ScumBag';
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $testTopic );
    $topicObject->text("---++ $header\n$body\n");
    $topicObject->put( 'FORM',        { name => "TestyForm" } );
    $topicObject->put( 'TOPICPARENT', { name => "WebHome" } );
    $topicObject->putKeyed(
        'FIELD',
        {
            name  => "Option",
            title => "Some option",
            value => "Some long test I can truncate later"
        }
    );
    $topicObject->save();

    my $testUser        = 'WikiGuest';
    my $nop             = qr/(?:<nop>)+/o;
    my $topicWithDashes = $testTopic;
    $topicWithDashes =~ s/\G(.....)/$1-/g;
    my $isodate_pattern;
    if ( $Foswiki::cfg{DisplayTimeValues} eq 'gmtime' ) {
        $isodate_pattern = qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/;
    }
    else {
        $isodate_pattern =
          qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[\+\-]\d\d(:?\d\d)?$/;
    }
    my %testFormatTokens = (
        '$web'           => $this->{test_web},
        '$topic'         => $testTopic,
        '$topic(20)'     => substr( $testTopic, 0, 20 ),
        '$topic(5, -)'   => $topicWithDashes,
        '$topic(5, ...)' => substr( $testTopic, 0, 5 ) . '...',
        '$parent'        => 'WebHome',
        '$parent(5)'     => 'WebHo- me',
        '$text'          => "---++ $header\n$body",
        '$locked'        => '$locked',                          # Does not work?
        '$date'          => qr/^\d\d \w{3} \d{4} - \d\d:\d\d$/,
        '$createdate'    => qr/^\d\d \w{3} \d{4} - \d\d:\d\d$/,
        '$isodate'       => $isodate_pattern,
        '$index'         => 1,
        '$nhits'         => 1,
        '$ntopics'       => 1,
        '$item'          => "$this->{test_web}.$testTopic",
        '$rev'           => 1,
        '$username'      => 'guest',
        '$wikiname'      => $testUser,
        '$wikiusername'       => "$Foswiki::cfg{UsersWebName}.$testUser",
        '$createusername'     => 'guest',
        '$createwikiname'     => $testUser,
        '$createwikiusername' => "$Foswiki::cfg{UsersWebName}.$testUser",
        '$changes'            => qr/^$nop$this->{test_web}\.$testTopic $header/,
        '$changes(1)' => '',            # Only 1 revision
        '$formname'   => 'TestyForm',
        '$formfield(Option)'     => 'Some long test I can truncate later',
        '$formfield(Option, 10)' => 'Some long - test I can-  truncate - later',
        '$formfield(Option, 20, -<br />)' =>
          'Some long test I can-<br /> truncate later',
        '$formfield(Option, 30, ...)' => 'Some long test I can truncate ...',
        '$nop'                        => q{},
        '$nop()'                      => q{},
        '$quot'                       => q{"},
        '$percent'                    => q{%},
        '$percnt'                     => q{%},
        '$dollar'                     => q{$},
        '$lt'                         => q{<},
        '$gt'                         => q{>},
        '$amp'                        => q{&},
        '$comma'                      => q{,},
        '$n'                          => q{},
        '$n()'                        => q{},
        '$pager'                      => '$pager',
'$percntUSERINFO{$quot$pattern(.*?POTLEADER *= *([^\n]*).*)$quot format=$quot$emails$quot}$percnt'
          => $emailAddress,
        '$summary'     => qr/^$header \* Set ${nop}POTLEADER = ${nop}ScumBag$/,
        '$summary(29)' => qq{$header \* Set...},
        '$summary(showvarnames)' =>
          qr/^$header \* Set ${nop}POTLEADER = ${nop}ScumBag$/,
        '$summary(searchcontext)' =>
          qr/^$header \* Set ${nop}POTLEADER = ${nop}ScumBag$/,
        '$summary(searchcontext, 29)' => qq{$header \* Set...},
        '$summary(noheader)' => qr/^\* Set ${nop}POTLEADER = ${nop}ScumBag$/,
        '$pattern(.*?POTLEADER *= *([^\n]*).*)' => 'ScumBag',
        '$count(.*S.*)'                         => 2,          # Not sure why...
    );
    while ( my ( $token, $expected ) = each %testFormatTokens ) {
        my $text =
            '%SEARCH{ "POTLEADER" topic="%TOPIC%" web="%WEB%"'
          . ' type="regex" nonoise="on" separator=""'
          . " format=\"$token\" }%";
        my $result       = $topicObject->expandMacros($text);
        my $testFunction = $this->can('assert_equals');
        if ( ref($expected) eq 'Regexp' ) {
            $testFunction = $this->can('assert_matches');
        }
        $this->$testFunction( $expected, $result,
                "Expansion of SEARCH token $token failed!\n"
              . "Expected:'$expected'\n But got:'$result'\n" );
    }
    $topicObject->finish();

    return;
}

# Item11190
sub test_format_percent_tokens {
    my $this      = shift;
    my $testTopic = 'TestFormatIncludedTokens';
    my $body      = '%PUBURL%/%WEB%/%TOPIC%/Something.jpg';
    my $testWeb   = $this->{test_web} . '/TestSearchFormatWeb';
    my $search = "%SEARCH{\"Something\" web=\"$testWeb\" topic=\"$testTopic\" "
      . 'expandvariables="on" nonoise="on" format="$pattern(.*?begin (.*?) end.*)"}%';

    Foswiki::Func::createWeb($testWeb);
    my ($topicObject) = Foswiki::Func::readTopic( $testWeb, $testTopic );
    $topicObject->text("begin $body end\n");
    $topicObject->save();
    my $expected     = $topicObject->expandMacros($body);
    my $expectedFail = $expected;
    for ($expectedFail) {
        s/$testWeb/$this->{test_web}/g;
        s/$testTopic/$this->{test_topic}/g;
    }

    my $result = $topicObject->expandMacros($search);
    $this->assert_equals( $expected, $result,
            "Expansion of SEARCH failed locally!\n"
          . "Expected:'$expected'\n But got:'$result'\n" );
    $result = $this->{test_topicObject}->expandMacros($search);
    $this->assert_equals( $expected, $result,
            "Expansion of SEARCH failed remotely!\n"
          . "Expected:'$expected'\n But got:'$result'\n" );

    $search =~ s/(expandvariables)="on"/$1="off"/;
    $result = $this->{test_topicObject}->expandMacros($search);
    $this->assert_equals( $expectedFail, $result,
            "Expansion of SEARCH failed remotely (expandvariables=\"off\")!\n"
          . "Expected:'$expectedFail'\n But got:'$result'\n" );
    $topicObject->finish();
    return;
}

sub test_search_scope_topic {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"VarREMOTE" web="%SYSTEMWEB%" scope="topic" format="$topic" separator="," nonoise="on"}%'
      );

    my @topics = split( /,/, $result );
    $this->assert_num_equals( 3, scalar(@topics) );
    $this->assert_equals( 'VarREMOTEADDR,VarREMOTEPORT,VarREMOTEUSER',
        $result );

    return;
}

sub test_minus_scope_all {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'VirtualBeer' );
    $topicObject->text("There are alot of Virtual Beers to go around");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'RealBeer' );
    $topicObject->text("There are alot of Virtual Beer to go around");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'FamouslyBeered' );
    $topicObject->text(
        "Virtually speaking there could be alot of famous Beers");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'VirtualLife' );
    $topicObject->text("In a all life, I would expect to find fine Beer");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NoLife' );
    $topicObject->text("In a all life, I would expect to find fine Beer");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NoBeer' );
    $topicObject->text("In a all life, I would expect to find fine Beer");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'SomeBeer' );
    $topicObject->text("In a all life, I would expect to find fine Wine");
    $topicObject->save();
    $topicObject->finish();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-Virtual" scope="all" type="word" nonoise="on" format="$topic" excludetopic="SomeOther*"}%'
      );

    my $expected = $this->toSiteCharSet(<<'EXPECT');
FamouslyBeered
NoBeer
NoLife
OkATopic
OkBTopic
OkÆTopic
SomeBeer
TestTopicSEARCH
WebPreferences
EXPECT
    $this->assert_str_equals( $expected, $result . "\n" );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Beer" scope="all" type="word" nonoise="on" format="$topic" excludetopic="SomeOther*"}%'
      );

    $expected = $this->toSiteCharSet(<<'EXPECT');
FamouslyBeered
NoBeer
NoLife
RealBeer
SomeBeer
VirtualBeer
VirtualLife
EXPECT
    $this->assert_str_equals( $expected, $result . "\n" );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-Virtual Beer" scope="all" type="word" nonoise="on" format="$topic" excludetopic="SomeOther*"}%'
      );

    $expected = $this->toSiteCharSet(<<'EXPECT');
FamouslyBeered
NoBeer
NoLife
SomeBeer
EXPECT
    $this->assert_str_equals( $expected, $result . "\n" );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Beer -Virtual" scope="all" type="word" nonoise="on" format="$topic" excludetopic="SomeOther*"}%'
      );

    $expected = $this->toSiteCharSet(<<'EXPECT');
FamouslyBeered
NoBeer
NoLife
SomeBeer
EXPECT
    $this->assert_str_equals( $expected, $result . "\n" );

    return;
}

#Profile/Builder.TermForm
sub verify_Item10269 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"NewField=\'Profile/Builder.TermForm\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    return;
}

#Profile/Builder.TermForm
sub verify_Item10398 {
    my $this = shift;

    $this->set_up_for_queries();

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'Trash.MainBobTest' );
    $topicObject->text("BLEEGLE blah/matchme.blah");
    $topicObject->save();
    $topicObject->finish();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"name=\'WebPreferences\'" type="query" web="'
          . $this->{test_web}
          . '" recurse="on" nonoise="on" format="$topic"}%' );
    $this->assert_str_equals( 'WebPreferences', $result );

    return;
}

#Item10515
sub verify_lhs_lc_field_rhs_lc_string {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"lc(Firstname)=lc(\'JOHN\')"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    return;
}

#%SEARCH{"SomeString" web="Tasks"  scope="all" order="topic" type="word" }%
sub verify_Item10491 {
    my $this = shift;

    #$this->set_up_for_queries();

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'Item10491' );
    $topicObject->text(<<'TOPICTEXT' );
Search on Foswiki.org has been showing some signs of corruption.   The topic Tasks/Item968 appeared to be related, however it can be created  From IRC:

 SomeString.txt

So hopefully this topic will cause the same issue once I save it...

-- Main.GeorgeClark - 15 Mar 2011



The WikiWord is being expanded in the first hit of the search results.  2nd and subsequent hits don't get corrupted.

<verbatim>
<div class="foswikiSearchResult"><div class="foswikiTopRow">
<a href="/Item10491/txt: <span class="foswikiNewLink">SomeString<a href="/bin/edit/System/SomeString?topicparent=System.WebSearch" rel="nofollow" title="Create this topic">?</a></span> "><b>txt: <span class="foswikiNewLink">SomeString<a href="/bin/edit/System/SomeString?topicparent=System.WebSearch" rel="nofollow" title="Create this topic">?</a></span> </b></a>
<div class="foswikiSummary"></div></div>
</verbatim>

And worse,  the string is then interpreted as if it were a web.  See the following search results:  Reports 2 webs: Results from Tasks web, and Results from Item10491 web

http://foswiki.org/System/WebSearch?tab=searchadvanced&search=SomeString&scope=all&order=topic&type=word&limit=;web=Tasks


-- %USERSWEB%.GeorgeClark - 15 Mar 2011


Sample search
-------
<verbatim>
%SEARCH{"SomeString" web="Tasks"  scope="text" order="topic" type="word" }%
</verbatim>
--------
%SEARCH{"SomeString" web="Tasks"  scope="text" order="topic" type="word" }%
--------

-- %USERSWEB%.GeorgeClark - 15 Mar 2011


This might be related to Trunk issue [[Item10479]] in that the searches that exhibit corruption on Release11 cause the crash on Trunk.  There were some patches applied to Foswiki.org by PaulHarvey that I've removed.  But that did not improve the issue.

I'm able to duplicate the issue locally on a 1.1.3 checkout (two webs returned with a single web search).  However the same search macro run from the Unit Test framework only returns a single web,  so unable to reproduce for a unit test.


-- %USERSWEB%.GeorgeClark - 15 Mar 2011
%COMMENT%
TOPICTEXT

    #'
    $topicObject->save();
    $topicObject->finish();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"SomeString" type="word" web="'
          . $this->{test_web}
          . '"  scope="all" order="topic"}%' );
    $this->assert_str_equals(
        _cut_the_crap(<<"RESULT"), _cut_the_crap( $result . "\n" ) );
<div class="foswikiSearchResultsHeader"><span>Searched: <b><noautolink>SomeString</noautolink></b></span><span id="foswikiNumberOfResultsContainer"></span></div>
<h4 class="foswikiSearchResultsHeader"  style="border-color:#FF00FF"><b>Results from <nop>$this->{test_web} web</b> retrieved at 04:34 (GMT)</h4>
<div class="foswikiSearchResult"><div class="foswikiTopRow">
<a href="/~sven/core/bin/view/$this->{test_web}/Item10491"><b>Item10491</b></a>
<div class="foswikiSummary"><b>&hellip;</b> it can be created From <nop>IRC<nop>: <em><nop>SomeString</em>.txt So hopefully this topic  <b>&hellip;</b>  hits don't get corrupted. <em><nop>SomeString</em>? " txt<nop>: <nop>SomeString? And  <b>&hellip;</b> ?tab=searchadvanced search=<em><nop>SomeString</em> scope=all order=topic type= <b>&hellip;</b> </div></div>
<div class="foswikiBottomRow"><span class="foswikiSRRev"><span class="foswikiNew">NEW</span> - <a href="/~sven/core/bin/rdiff/$this->{test_web}/Item10491" rel='nofollow'>16 Mar 2011 - 04:34</a></span> <span class="foswikiSRAuthor">by !WikiGuest </span></div>
</div>
<div class="foswikiSearchResultCount">Number of topics: <span>1</span></div>
RESULT

    #'
    return;
}

#Item10898
sub verify_multiple_order_fields {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"1" order="formfield(Firstname),formfield(Lastname)" '
          . $stdCrap );
    $this->assert_str_equals(
'OkATopic OkBTopic OkÆTopic QueryTopic QueryTopicTwo TestTopicSEARCH WebPreferences',
        $result
    );

    return;
}

sub verify_crossweb_op_ref {
    my $this   = shift;
    my %topics = (
        "$this->{test_web}/LLB/Analyses/Sequences.00001" => <<"HERE",
%META:TOPICINFO{author="BaseUserMapping_333" date="1313039642" format="1.1" version="1"}%
%META:TOPICPARENT{name="All"}%

%META:FORM{name="Profile/Definitions.Acacia_Sequence_Form"}%
%META:FIELD{name="Acacia_TraceSet" title="TraceSet" type="llb+input" value="$this->{test_web}/LLB/Results/TraceSets.00001"}%
%META:FIELD{name="Acacia_WorkState" title="Editing" type="list+one" value="done"}%
%META:FIELD{name="Acacia_Complete" title="Complete" type="boolean" value="1"}%
%META:FIELD{name="Acacia_DateCompleted" title="Date completed" type="date" value=""}%
%META:FIELD{name="Acacia_GenbankNumber" title="Genbank number" type="text" value="AF523110"}%
%META:FIELD{name="Acacia_GenbankLink" title="Genbank Link" type="text" value="http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?db=nucleotide&val=22725481"}%
%META:FIELD{name="Acacia_SequenceNotes" title="Notes" type="richtext" value=""}%
%META:FIELD{name="Acacia_Sequence" title="Sequence" type="llb+sequence" value="TCGGCTTTTAAGTGCGACTCAAAATTTTACACATTTCTATGAAGCAATGGATTCATCCATACCATCGGTAGAGTTTGTAAGACCACGACTGATCCAGAAAGGAATGAATGGAAAAAGCAGCATGTCGTATCAATGGAGAATTCTAAGACTATCTCATTTTTATTGGATCGGGCCCAAATCCATGTTTGTATTCTTGGCTCGCAACAAAAGCAAAAGAAATTCACAGTTGGGTTGAATTAATAAATGGATAGAGTTTGGTGACTCCAATTATAGGGAAACAAAAAGGAACGAGCTTTTGTTTTGAATTTGAATGATTCCCCCATCTAATTATACGTTAAAAATATAAAATATTAGTACTTGATGGGGGAAAAGCTTTTCCCATGAATGGATTATTGATTTTTGTTATGAATCCTAACTATTAGCTATTCTCCATTATAATTAGATTATGGGGTGGCGATAAATGTGTAGAAGAAAGAGTATATTGATAAAGATCTTTTTTTTTTTTCCAAAATCAAAAGAGCGATTGGGTTGAGAAAATAAAGGATTTCTAACTATCTTGTTATCCTAGAACGAACATAAAACAATTAGATGGAAAAAGCGAGTAGAGAGAGTCCGTTGATGAGTCTTACTTGTTTTCTAGGTATCTTTTTTTAGAATAGAATACCCTGTTTTGACTGTATCGCACTATGTATTATTTGATAACCCAATAAATCTTCGATCCTCGGCCCAAATCAAATTTCAAAAAATGGAGGAATTTCAAGTATATTTAGAACTAGATAGATCTCGTCAACATGACTTCCTATACCCACTTATTTTTCGGGAGTATATTTTTGCACTTGCTTACGATCATGGTTTAAATAGTTCCATTTTGGTGCAAGATCTAGGTTATGACAATAAATCTAGTTTACTAATTGTAAAACGTTTAATTACTCGAATGTATCACCAGAATCATTTGATTATTTCTGCTAATAATTCTAACAAAAATCCATTTTGGGGGTACAACAAGAATTTGTATTCTCAAATAATATCAGAGGGGCTTGCCGTCAGTGTGGAAATTCCATTTTCCCTACAACTAATCTCTTCCTTAGAGAAGGCAGAAATTATAAAATCCTATAATTTACGATCAATTCATTCAATATTTCCTTTTTTTGAGGAAAAATTTCCATATTTAAATTATGTGTCAGATGTACAAATACCCTACCCTATACATCTGGAAATCTTGATTCAAACCCTTCGATACTGGGTGAAAGATGCCTCCTCCTTTCATTTATTAAGGCTCTTTCTTTATGAGTATTGTAATTGGAATAGTCTTATTACTCCAAAAAAAAGGATTTCTACTTTTTCAAAAAGTAATCCAAGATTTTTCCTGTTCCTATATAATTTTTATGTAGGTGAATACGAATCCATCTTTCTTTTTCTCCGTAACAAATCTTCTTATTTACGATTAACATCTTCTGGAGTCTTTTTTGAACGAATCTATTTCTATGCAAAAATAAAACATTTTGTAGAAGTCTTTGATAAGGATTTTCCGTCCACCCTATGGTTCTTCAAGGACCCTTTCATTCATTATGTTAGATATCAAGGAAAATCCATTCTAGCTTCAAAGAATACGCCCTTTTTGATGAAAAAATGGAAATACTATCTTATCCATTTATGGCAATGTCATTTTTTTGTTTGGTCTCAACCAGGAAAGATCCATATAAACCAATTATCCGAGCATTCATTTTCCTTTTTGGGTTATTTTTCAAATGTGCGGCTAAATCCTTCAGTGGTACGGAGTCAAATGTTGGAAAAGTCATTTATAATGGAAAATCTTATGAAAAAGCTTGATACAATAATTCCAATTATTCCTCTAATTAGATCATTGGCTAAAGCAAATTTTTGTAATGTATTAGGACATCCCATTAGTAAGCCGGTCTGGGCCGATTCATCCGATTTTGATATTATTGAGCGATTTTTGCAGATATGCAGAGATCTCTCTCATTATTACAACGGATCCTCAAAAAAAAAGAGTTTGTATCGAATCAAAAAAAACTTCGGGCTTNNTGGATNAAAACTTTGGNGGGTAACNCCAAAAGTCCNNNCGGGTTTTTTAAAAAANTAGGTTTTNAANTANTGGAANAATTNTTTCANAGGAAAAAAANATTTTTTTTTTNATTTTTTCNANAGNTTTTTTTNCTTTGCNNAAGNTANAAAAAGGCGGNTTTGGGANTTTGAAANTTTTGANTTTCNNCNANGATNTGGGCCATCATGAAAAACNGGNTATCNNACNTTGANAANGGGAACNANCCNTNAATNNGGGAAAGATNAAAAAAAAAAGAATTCATTCGTTTCTATTATGAAATTTCTATTATGAAATATGAAATGGATTATGAAATGCTCATGTAGTAAGAGTAGGAATTGATAAACTAAGNACTTAACTTTTTTAGAGTCCNGTTCTAGGGAAGGAACTGAGGTTTAGATGTATACATAGGGAAAGCCGTGTGCAATGAAAAATGCAAGTACGGCCTGGGGAGGNNTTTTTTT"}%
HERE
        "$this->{test_web}/LLB/Analyses/Sequences.00002" => <<"HERE",
%META:TOPICINFO{author="BaseUserMapping_333" date="1313039642" format="1.1" version="1"}%
%META:TOPICPARENT{name="All"}%

%META:FORM{name="Profile/Definitions.Acacia_Sequence_Form"}%
%META:FIELD{name="Acacia_TraceSet" title="TraceSet" type="llb+input" value="$this->{test_web}/LLB/Results/TraceSets.00002"}%
%META:FIELD{name="Acacia_WorkState" title="Editing" type="list+one" value="done"}%
%META:FIELD{name="Acacia_Complete" title="Complete" type="boolean" value="1"}%
%META:FIELD{name="Acacia_DateCompleted" title="Date completed" type="date" value=""}%
%META:FIELD{name="Acacia_GenbankNumber" title="Genbank number" type="text" value="AF195707"}%
%META:FIELD{name="Acacia_GenbankLink" title="Genbank Link" type="text" value="http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?db=nucleotide&val=10880548"}%
%META:FIELD{name="Acacia_SequenceNotes" title="Notes" type="richtext" value=""}%
%META:FIELD{name="Acacia_Sequence" title="Sequence" type="llb+sequence" value="AAAATCTTGGTCTTAATGTATACGAGTTTTTGAACGTAAAGGAGCAATAATTAATTTATTGTTCTATCAAGAGGGTTAATATTGCTCCTTTACTTTTTAGTAGTTTCATACATCAATTTTGTATTTACTTCAACATTCTTTACCGTTGTTTTAAGATAAGAAAAAAATATTGGAGTTTCATACTTTTTGTTTCTTTTTTACTAATTTATTTTATACGTTTTTTTCAGCAATCTTTCTTTATCTTTTGAAATGAAAAAAAAAAACAAAAGAAAGAATACAAATATCTCTGTAATTTTTAGATGGTTTTTAGATGGTATAGG"}%
HERE
        "$this->{test_web}/LLB/Results/TraceSets.00001" => <<"HERE",
%META:TOPICINFO{author="BaseUserMapping_333" date="1313040485" format="1.1" version="1"}%
%META:TOPICPARENT{name="All"}%

%META:FORM{name="Profile/Definitions.Acacia_TraceSet_Form"}%
%META:FIELD{name="Acacia_PCRProduct" title="PCR Product" type="llb+input" value="$this->{test_web}/LLB/Samples/PCRs.00001"}%
HERE
        "$this->{test_web}/LLB/Results/TraceSets.00002" => <<"HERE",
%META:TOPICINFO{author="BaseUserMapping_333" date="1313040748" format="1.1" version="1"}%
%META:TOPICPARENT{name="All"}%

%META:FORM{name="Profile/Definitions.Acacia_TraceSet_Form"}%
%META:FIELD{name="Acacia_PCRProduct" title="PCR Product" type="llb+input" value="$this->{test_web}/LLB/Samples/PCRs.00002"}%
HERE
        "$this->{test_web}/LLB/Samples/PCRs.00001" => <<"HERE",
%META:TOPICINFO{author="BaseUserMapping_333" date="1313038798" format="1.1" version="1"}%
%META:TOPICPARENT{name="All"}%

%META:FORM{name="Profile/Definitions.Acacia_SamplePCR_Form"}%
%META:FIELD{name="Acacia_Extract" title="Extract" type="llb+input" value="$this->{test_web}/LLB/Samples/Extracts.0000"}%
%META:FIELD{name="Acacia_Gene" title="Gene" type="fwaddress" value="$this->{test_web}/LLB/Genes.MatK"}%
%META:FIELD{name="Acacia_WorkState" title="PCR Done" type="list+one" value="working"}%
%META:FIELD{name="Acacia_Cleaned" title="PCR Cleaned" type="boolean" value="1"}%
%META:FIELD{name="Acacia_FreezerLocation" title="Freezer Location" type="text" value=""}%
HERE
        "$this->{test_web}/LLB/Samples/PCRs.00002" => <<"HERE",
%META:TOPICINFO{author="BaseUserMapping_333" date="1313038798" format="1.1" version="1"}%
%META:TOPICPARENT{name="All"}%

%META:FORM{name="Profile/Definitions.Acacia_SamplePCR_Form"}%
%META:FIELD{name="Acacia_Extract" title="Extract" type="llb+input" value="$this->{test_web}/LLB/Samples/Extracts.0000"}%
%META:FIELD{name="Acacia_Gene" title="Gene" type="fwaddress" value="$this->{test_web}/LLB/Genes.PsbA"}%
%META:FIELD{name="Acacia_WorkState" title="PCR Done" type="list+one" value="done"}%
%META:FIELD{name="Acacia_Cleaned" title="PCR Cleaned" type="boolean" value="0"}%
%META:FIELD{name="Acacia_FreezerLocation" title="Freezer Location" type="text" value=""}%
HERE
        "$this->{test_web}/LLB/Samples/Extracts.0000" => <<"HERE",
%META:TOPICINFO{author="BaseUserMapping_333" date="1313038766" format="1.1" version="1"}%
%META:TOPICPARENT{name="All"}%

%META:FORM{name="Profile/Definitions.Acacia_Extract_Form"}%
%META:FIELD{name="Acacia_Specimen" title="Specimen" type="llb+input" value="$this->{test_web}/LLB/Materials/Specimens.0120"}%
%META:FIELD{name="Acacia_ExtractMethod" title="Extraction method" type="text" value="$this->{test_web}/LLB/Methods.10"}%
%META:FIELD{name="Acacia_TissueType" title="Tissue type" type="list+one" value=""}%
%META:FIELD{name="Acacia_DNAQuality" title="DNA quality" type="list+one" value="Wig L Bug"}%
%META:FIELD{name="Acacia_DNAQuality" title="Picture" type="label" value=""}%
%META:FIELD{name="Acacia_LaneNumber" title="Lane number" type="label" value="7"}%
%META:FIELD{name="Acacia_PictureInfoFile" title="Picture info file" type="label" value=""}%
%META:FIELD{name="Acacia_Concentration" title="Concentration (ng/<B5>L)" type="text" value=""}%
%META:FIELD{name="Acacia_DNANotes" title="DNA Notes" type="text" value=""}%
%META:FIELD{name="Acacia_FreezerLocation" title="Freezer Location" type="text" value=""}%
HERE
        "$this->{test_web}/LLB/Samples/Extracts.0001" => <<"HERE"
%META:TOPICINFO{author="BaseUserMapping_333" date="1313038766" format="1.1" version="1"}%
%META:TOPICPARENT{name="All"}%

%META:FORM{name="Profile/Definitions.Acacia_Extract_Form"}%
%META:FIELD{name="Acacia_Specimen" title="Specimen" type="llb+input" value="$this->{test_web}/LLB/Materials/Specimens.1220"}%
%META:FIELD{name="Acacia_ExtractMethod" title="Extraction method" type="text" value="$this->{test_web}/LLB/Methods.03"}%
%META:FIELD{name="Acacia_TissueType" title="Tissue type" type="list+one" value=""}%
%META:FIELD{name="Acacia_DNAQuality" title="DNA quality" type="list+one" value=""}%
%META:FIELD{name="Acacia_DNAQuality" title="Picture" type="label" value=""}%
%META:FIELD{name="Acacia_LaneNumber" title="Lane number" type="label" value="3"}%
%META:FIELD{name="Acacia_PictureInfoFile" title="Picture info file" type="label" value=""}%
%META:FIELD{name="Acacia_Concentration" title="Concentration (ng/<B5>L)" type="text" value=""}%
%META:FIELD{name="Acacia_DNANotes" title="DNA Notes" type="text" value=""}%
%META:FIELD{name="Acacia_FreezerLocation" title="Freezer Location" type="text" value=""}%
HERE
    );
    my %tests = (
        "Acacia_Specimen='$this->{test_web}/LLB/Materials/Specimens.1220'" =>
          "$this->{test_web}/LLB/Samples/Extracts.0001",
        "Acacia_Extract/Acacia_ExtractMethod='$this->{test_web}/LLB/Methods.10'"
          => "$this->{test_web}/LLB/Samples/PCRs.00001, $this->{test_web}/LLB/Samples/PCRs.00002",
        "Acacia_ExtractMethod='$this->{test_web}/LLB/Methods.03'" =>
          "$this->{test_web}/LLB/Samples/Extracts.0001",
        "Acacia_Extract/Acacia_ExtractMethod='$this->{test_web}/LLB/Methods.03'"
          => '',
        "Acacia_PCRProduct='$this->{test_web}/LLB/Samples/PCRs.00002'" =>
          "$this->{test_web}/LLB/Results/TraceSets.00002",
"Acacia_PCRProduct/Acacia_Extract/Acacia_ExtractMethod='$this->{test_web}/LLB/Methods.10'"
          => "$this->{test_web}/LLB/Results/TraceSets.00001, $this->{test_web}/LLB/Results/TraceSets.00002",
"Acacia_TraceSet/Acacia_PCRProduct/Acacia_Extract/Acacia_ExtractMethod='$this->{test_web}/LLB/Methods.10'"
          => "$this->{test_web}/LLB/Analyses/Sequences.00001, $this->{test_web}/LLB/Analyses/Sequences.00002",
        "Acacia_TraceSet/Acacia_PCRProduct/Acacia_WorkState='done'" =>
          "$this->{test_web}/LLB/Analyses/Sequences.00002",
        "Acacia_TraceSet/Acacia_PCRProduct/Acacia_Cleaned" =>
          "$this->{test_web}/LLB/Analyses/Sequences.00001",
"form.name='Profile/Definitions.Acacia_Sequence_Form' AND Acacia_TraceSet/Acacia_PCRProduct/Acacia_Extract/Acacia_LaneNumber > 5"
          => "$this->{test_web}/LLB/Analyses/Sequences.00001, $this->{test_web}/LLB/Analyses/Sequences.00002",
"form.name='Profile/Definitions.Acacia_Sequence_Form' AND Acacia_TraceSet/Acacia_PCRProduct/Acacia_Extract/Acacia_LaneNumber < 5"
          => ''
    );
    my $query = Unit::Request->new('');

    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin}, $query );
    $this->assert_str_equals( $this->{test_web}, $this->{session}->{webName} );
    while ( my ( $fwaddress, $metatext ) = each %topics ) {
        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( '', $fwaddress );
        my $topicObj;

        if ( not Foswiki::Func::webExists($web) ) {
            my @webs;

            foreach my $part ( split( /\//, $web ) ) {
                my $w;

                push( @webs, $part );
                $w = join( '/', @webs );
                if ( not Foswiki::Func::webExists($w) ) {
                    Foswiki::Func::createWeb( $w, '_default' );
                }
            }
        }
        ($topicObj) = Foswiki::Func::readTopic( $web, $topic );
        $topicObj->setEmbeddedStoreForm($metatext);
        $topicObj->save();
        $topicObj->finish();
    }
    while ( my ( $querysearch, $expected ) = each %tests ) {
        my $result =
          $this->_test_query( $querysearch, "$this->{test_web}/LLB" );
        $this->assert_str_equals( $expected, $result,
            "Testing: '$querysearch'\nExpected:'$expected'\nBut got: '$result'"
        );

    }

    return;
}

sub _test_query {
    my ( $this, $query, $web ) = @_;
    my $result = $this->{test_topicObject}->expandMacros(<<"HERE");
%SEARCH{
    "$query"
    type="query"
    web="$web"
    recurse="on"
    nonoise="on"
    separator=", "
    format="\$web.\$topic"
}%
HERE
    chomp($result);

    return $result;
}

sub test_pager_details_Item10350_one {
    my $this = shift;

    my $search = $this->toSiteCharSet( $this->toSiteCharSet(<<'HERE') );
%SEARCH{
    "web"
    type="text"
    web="System"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text"
    nonoise="on"
    format="$web.$topic"
    pager="on"
}%
HERE
    my $result = $this->{test_topicObject}->expandMacros($search);

    # Should get the default search order (or an error message, perhaps?)
    $this->assert_str_equals( <<'THERE', $result );
System.WebChanges
System.WebHome
System.WebIndex
System.WebPreferences
THERE

    return;
}

sub test_pager_details_Item10350_two {
    my $this = shift;

    my $search = $this->toSiteCharSet(<<'HERE');
%SEARCH{
    "web"
    type="text"
    web="System"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text"
    nonoise="on"
    format="$web.$topic"
    showpage="1"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
    pager="on"
}%
HERE
    my $result = $this->{test_topicObject}->expandMacros($search);

    # Should get the default search order (or an error message, perhaps?)
    $this->assert_str_equals( <<'THERE', $result );
System.WebChanges
System.WebHome
System.WebIndex
System.WebPreferences
FOOT(4,4)
THERE

    return;
}

#Item12166
sub verify_search_for_star {
    my $this = shift;

    my $search = <<'HERE';
%SEARCH{ 
    "*"
    type="word"
    scope="all" 
    web="TestCases"
}%
HERE
    my $result = $this->{test_topicObject}->expandMacros($search);

    # Should get the default search order (or an error message, perhaps?)
    $this->assert( 0, $result )
      unless $result =~ /Number of topics: <span>(\d+)<\/span>/;
    print STDERR "$1 topic\n";
    $this->assert( $1 >= 4 );

    return;
}

sub verify_decode_options {
    my $this = shift;

    my $search = <<'HERE';
%SEARCH{
    "%ENCODE{"'" type="entities"}%"
    type="literal"
    decode="entity"
    scope="all"
    web="TestCases"
}%
HERE
    my $result = $this->{test_topicObject}->expandMacros($search);

    # Should get the default search order (or an error message, perhaps?)
    $this->assert( 0, $result )
      unless $result =~ /Number of topics: <span>(\d+)<\/span>/;
    $this->assert( 0, $result )
      unless $result =~ /Searched: <b><noautolink>&#39;<\/noautolink><\/b>/;

    $search = <<'HERE';
%SEARCH{
    "%ENCODE{"' \" < > and %" type="safe"}%"
    type="literal"
    decode="safe"
    scope="all"
    web="TestCases"
}%
HERE
    $result = $this->{test_topicObject}->expandMacros($search);

    # Should get the default search order (or an error message, perhaps?)
    $this->assert( 0, $result )
      unless $result =~ /Number of topics: <span>(\d+)<\/span>/;
    $this->assert( 0, $result )
      unless $result =~
/Searched: <b><noautolink>&#39; &#34; &#60; &#62; and &#37;<\/noautolink><\/b>/;

    $search = <<'HERE';
%SEARCH{
    "%ENCODE{"'" type="url"}%"
    type="literal"
    decode="url"
    scope="all"
    web="TestCases"
}%
HERE
    $result = $this->{test_topicObject}->expandMacros($search);

    # Should get the default search order (or an error message, perhaps?)
    $this->assert( 0, $result )
      unless $result =~ /Number of topics: <span>(\d+)<\/span>/;
    $this->assert( 0, $result )
      unless $result =~ /Searched: <b><noautolink>&#39;<\/noautolink><\/b>/;

    $search = <<'HERE';
%SEARCH{
    "%ENCODE{"%ENCODE{"'" type="url"}%" type="entities"}%"
    type="literal"
    decode="entities, url"
    scope="all"
    web="TestCases"
}%
HERE
    $result = $this->{test_topicObject}->expandMacros($search);

    # Should get the default search order (or an error message, perhaps?)
    $this->assert( 0, $result )
      unless $result =~ /Number of topics: <span>(\d+)<\/span>/;
    $this->assert( 0, $result )
      unless $result =~ /Searched: <b><noautolink>&#39;<\/noautolink><\/b>/;

    return;
}

1;
