use strict;

# tests for the correct expansion of macros

package ExpandMacrosTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

my $dontCare = "It really does not matter what the actual value is, ".
               "so long as it exists. Never use this text, ".
               "or anything like it, in any test in this test case.";

my $macroWasHere = "ThereWasA_MACRO_Here";

sub new {
    my $self = shift()->SUPER::new( 'ExpandMacrosTests', @_ );
    return $self;
}

my $saveMacroExists;
my $saveMacroHandler;
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $saveMacroExists = exists $Foswiki::macros{MACRO};
    $saveMacroHandler = $Foswiki::macros{MACRO};
    $Foswiki::macros{MACRO} = \&_testMacroHandler;
}

sub tear_down {
    my $this = shift;
    $Foswiki::macros{MACRO} = $saveMacroHandler;
    delete $Foswiki::macros{MACRO} if not $saveMacroExists;
    $this->SUPER::tear_down();
}

# _testExpand takes two parameters: 
#   (1) TML to expand and 
#   (2) a hash containing the expected attributes
# The TML should contain a call to %MACRO{}%
# _textExpand checks that MACRO's handler is called.
# MACRO's handler checks the attributes passed to it.
#
# The keys in the attributes passed to MACRO's handler are expected to
# correspond exactly to the keys in the expected-attributes hash.
#
# If a value in the expected-attributes hash equals $dontCare,
# then the MACRO's handler ignores the actual value for that attribute.
# Otherwise, the actual values must equal the expected values.

sub test_makeSureDontCareWorks {
    my $this = shift;

    # Test the test environment
    $this->_testExpand('%MACRO%', {_RAW=>$dontCare});
    $this->_testExpand('%MACRO{}%', {_RAW=>$dontCare});
    $this->_testExpand('%MACRO{""}%', {_RAW=>$dontCare, _DEFAULT=>$dontCare});
    $this->_testExpand('%MACRO{" "}%', {_RAW=>$dontCare, _DEFAULT=>$dontCare});
    $this->_testExpand('%MACRO{"0"}%', {_RAW=>$dontCare, _DEFAULT=>$dontCare});
    $this->_testExpand('%MACRO{"00"}%', {_RAW=>$dontCare, _DEFAULT=>$dontCare});
    $this->_testExpand('%MACRO{ignore="me"}%', {_RAW=>$dontCare, ignore=>$dontCare});
}


sub test_plainInline {
    my $this = shift;

    $this->_testExpand("%MACRO%", {_RAW=>undef});

    $this->_testExpand("%MACRO{}%", {_RAW=>''});

    $this->_testExpand('%MACRO{"ping"}%', {_RAW=>$dontCare, _DEFAULT=>"ping"});

    $this->_testExpand('%MACRO{"flurble" cheese="gouda" say="\\"Hello\\""}%', {_RAW=>$dontCare, _DEFAULT=>"flurble", cheese=>"gouda", say=>'"Hello"'});
}

sub test_inlineWithDoubleEscapedQuotes {
    my $this = shift;

    $this->_testExpand('%MACRO{cheese="gouda" say="\\"Hello\\"" perlgreeting="print \\"say \\\\"Hello\\\\"\\""}%', 
                       {_RAW=>$dontCare, cheese=>"gouda", say=>'"Hello"', perlgreeting=>'print "say \\"Hello\\""'});
}

sub test_inlineWithEmbeddedNewline {
    my $this = shift;

    $this->_testExpand(<<'END',
%MACRO{"Embedded
newline"}%
END
      {_RAW=>$dontCare, _DEFAULT=>"Embedded\nnewline"});

    Foswiki::Func::registerTagHandler('FOO', sub {''});
    $this->_testExpand(<<'END',
%MACRO{"Escaped embedded%FOO{
}%newline"}%
END
      {_RAW=>$dontCare, _DEFAULT=>"Escaped embeddednewline"});

    Foswiki::Func::setPreferencesValue('BAR', '');
    $this->_testExpand(<<'END',
%MACRO{"Escaped embedded%BAR{
}%newline"}%
END
      {_RAW=>$dontCare, _DEFAULT=>"Escaped embeddednewline"});
}

sub test_simpleNestedMacrosInline {
    my $this = shift;
    my $expandedWikiName = $this->_expand('%WIKINAME%');
    $this->assert($expandedWikiName, "Expansion of %WIKINAME%");

    $this->_testExpand('%MACRO{"%WIKINAME%"}%', { _RAW => '"'.$expandedWikiName.'"', _DEFAULT => $expandedWikiName});

    $this->_testExpand('%MACRO{"%<nop>WIKINAME%"}%', { _RAW => $dontCare, _DEFAULT => "%<nop>WIKINAME%"});

    $this->_testExpand('%MACRO{"$percntWIKINAME%"}%', { _RAW => $dontCare, _DEFAULT => '$percntWIKINAME%'});

    $this->_testExpand('%MACRO{"$percentWIKINAME$percnt"}%', { _RAW => $dontCare, _DEFAULT => '$percentWIKINAME$percnt'});
}

sub test_nonDelayedExpansionInline {
    my $this = shift;

    my $result = $this->_expand(<<'END');
%FOREACH{"OneHump,TwoEyes,ThreeTeeth" format="%ENCODE{"%EXPAND{"%SPACEOUT{"$topic"}%"}%"}%" separator=","}%
END
    $this->assert_str_equals("%24topic,%24topic,%24topic\n", $result);
}

sub test_delayedExpansionInline {
    my $this = shift;

    my $result = $this->_expand(<<'END');
%FOREACH{"OneHump,TwoEyes,ThreeTeeth" format="$percntSPACEOUT{\"$topic\"}$percnt" separator=","}%
END
    $this->assert_str_equals("One Hump,Two Eyes,Three Teeth\n", $result);
}


sub test_preferenceWithParameter {
    my $this = shift;

    Foswiki::Func::setPreferencesValue('BAR', 'bar');
    my $result = $this->_expand('%BAR%');
    $this->assert_str_equals('bar', $result);

    $result = $this->_expand('%BAR{}%');
    $this->assert_str_equals('bar', $result);

    $result = $this->_expand('%BAR{ foo="ignored" }%');
    $this->assert_str_equals('bar', $result);

}

sub test_preferenceOverridesMacro {
    my $this = shift;

    Foswiki::Func::setPreferencesValue('MACRO', 'foo');
    my $result = $this->_expand('%MACRO{"bar"}%');
    $this->assert_str_equals('foo', $result);

}

my @expected;
my $test;
my $handlerInvoked;
sub _testExpand {
    $test = shift;
    my $tml = shift;
    @expected = @_;
    $handlerInvoked = 0;
    my $result = $test->_expand($tml);
    $test->assert( $handlerInvoked, "Test macro handler not invoked");
    return $result;
}

sub _expand {
    my ($this, $tml) = @_;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    return $topicObject->expandMacros($tml);
}

sub _testMacroHandler {
    my ($session, $attrs, $topic) = @_;
   
    # Check that all expected attributes are present, and have the correct value
    $test->assert( scalar(@expected), "MACRO handler called too many times");
    my %expected = %{ shift @expected };
    for my $expectedKey (keys %expected) {
        $test->assert( exists($attrs->{$expectedKey}), "$expectedKey should exist");
        if (defined $expected{$expectedKey}) {
            if ($expected{$expectedKey} eq $dontCare) {
                # ignore actual attr value
            }
            elsif (0) {
                #SMELL: These checks really belongs in AttrsTests
                $test->assert_str_equals( "ARRAY", ref($attrs->{$expectedKey}));
                scalar(@{ $attrs->{$expectedKey} }) == scalar(@{ $expected{$expectedKey} }) or
                  $test->assert(0, "$expectedKey: ".scalar(@{ $attrs->{$expectedKey} })." elements instead of ".scalar(@{ $expected{$expectedKey} }));
                for (my $i = 0; $i < scalar(@{ $expected{$expectedKey} }); $i++) {
                    defined($attrs->{$expectedKey}->[$i]) or
                      $test->assert( 0, "$expectedKey [$i] should be defined: (undef)");
                    ($expected{$expectedKey}->[$i] eq $attrs->{$expectedKey}->[$i]) or
                      $test->assert( 0, "$expectedKey [$i]: '$attrs->{$expectedKey}->[$i]' instead of '$expected{$expectedKey}->[$i]'" );
                }
            }
            else {
                defined($attrs->{$expectedKey}) or
                  $test->assert( 0, "$expectedKey should be defined: (undef)");
                ($expected{$expectedKey} eq $attrs->{$expectedKey}) or
                  $test->assert( 0, "$expectedKey : '$attrs->{$expectedKey}' instead of '$expected{$expectedKey}'" );
            }
        }
        else {
            !defined($attrs->{$expectedKey}) or
              $test->assert( 0, "$expectedKey should not be defined: '$attrs->{$expectedKey}'");
        }
    }
    
    # Check that there are no extra attributes
    for my $actualKey (keys %$attrs) {
        if (not exists $expected{$actualKey}) {
            my $value = '(undef)';
            if (defined $attrs->{$actualKey}) {
                $value = "'$attrs->{$actualKey}'";
            }
            $test->assert( 0, "Unexpected $actualKey: $value");
        }
    }

    $handlerInvoked ++;
    return $handlerInvoked.$macroWasHere;
}

sub test_EXPAND_bad {
    my $this = shift;
    my $r = $this->_expand("%EXPAND{}%");
    $this->assert_matches(qr/EXPAND failed - no macro/, $r);
    $r = $this->_expand('%EXPAND{"schlob" scope="bandersnatch"}%');
    $this->assert_matches(qr/EXPAND failed - no such topic 'bandersnatch'/, $r);
    # TODO: check access controls
}

1;
