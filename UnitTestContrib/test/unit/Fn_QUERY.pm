use strict;

# tests for the correct expansion of QUERY

package Fn_QUERY;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
use Assert;

sub new {
    my $self = shift()->SUPER::new( 'QUERY', @_ );
    return $self;
}

sub simpleTest {
    my ( $this, %test ) = @_;
    $this->{session}->enterContext('test');
    my $text = $this->{test_topicObject}->expandMacros(
        '%QUERY{"'.$test{test} . '"}%');
    #print STDERR "$text => $result\n";
    $this->assert_equals( $test{expect}, $text );
}

sub test_1 {
    my $this = shift;
    $this->simpleTest( test => "'A'", expect => 'A' );
}

sub test_2 {
    my $this = shift;
    $this->simpleTest( test => "'A'='B'", expect => 0 );
}

sub test_3 {
    my $this = shift;
    $this->simpleTest( test => "'A'='A'", expect => 1 );
}

sub test_5 {
    my $this = shift;
    $this->simpleTest(
        test => "d2n('2007-03-26')",
        expect => Foswiki::Time::parseTime( '2007-03-26', 1 )
    );
}

sub test_6 {
    my $this = shift;
    $this->simpleTest(
        test => "fields[name='nonExistantField']",
        expect => ''
    );
}

sub test_7 {
    my $this = shift;
    $this->simpleTest(
        test => "fields[name='nonExistantField'].value",
        expect => ''
    );
}

sub test_atomic {
    my $this = shift;
    
    #nope, parse failure (empty Expression) :/
    $this->simpleTest( test => "0", expect => 0 );
    
    $this->simpleTest( test => "1", expect => 1 );
    $this->simpleTest( test => "9", expect => 9 );

    $this->simpleTest( test => "-1", expect => -1 );
    $this->simpleTest( test => "-0", expect => 0 );

    $this->simpleTest( test => "0.0", expect => 0 );
    
    ##and again as strings..
    $this->simpleTest( test => "'1'", expect => 1 );
    $this->simpleTest( test => "'9'", expect => 9 );
    #surprisingly..
    $this->simpleTest( test => "'-1'", expect => '-1' );
    $this->simpleTest( test => "'-0'", expect => '-0' );

    $this->simpleTest( test => "'0.0'", expect => '0.0' );
    $this->simpleTest( test => "''", expect => '' );
}

# check parse failures
sub test_badQUERY {
    my $this  = shift;
    my @tests = (
        { test => "'A'=?",   expect => "Syntax error in ''A'=?' at '?'" },
        { test => "'A'==",   expect => "Excess operators (= =) in ''A'=='" },
        { test => "'A' 'B'", expect => "Missing operator in ''A' 'B''" },
        { test => ' ',       expect => "Empty expression" },
    );

    foreach my $test (@tests) {
        my $text   = '%QUERY{"' . $test->{test} . '"}%';
        my $result = $this->{test_topicObject}->expandMacros($text);
        $result =~ s/^.*foswikiAlert'>\s*//s;
        $result =~ s/\s*<\/span>\s*//s;
        $this->assert( $result =~ s/^.*}:\s*//s );
        $this->assert_str_equals( $test->{expect}, $result );
    }
    my $result = $this->{test_topicObject}->expandMacros('%QUERY%');
    $result =~ s/^.*foswikiAlert'>\s*//s;
    $result =~ s/\s*<\/span>\s*//s;
    $this->assert( $result =~ s/^.*}:\s*//s );
    $this->assert_str_equals( 'Empty expression', $result );
}

sub test_CAS {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "DeadHerring",
        <<'SMELL');
%QUERY{ "BleaghForm.Wibble" }%
%QUERY{ "Wibble" }%
%QUERY{ "attachments.name" }%
%META:FORM{name="BleaghForm"}%
%META:FIELD{name="Wibble" title="Wobble" value="Woo"}%
%META:FILEATTACHMENT{name="whatsnot.gif" date="1266942905" size="4586" version="1"}%
%META:FILEATTACHMENT{name="World.gif" date="1266943219" size="2486" version="1"}%
SMELL
    $topicObject->save();
    my $text = <<'PONG';
%INCLUDE{"DeadHerring" NAME="Red" warn="on"}%
PONG
    my $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );
Woo
Woo
whatsnot.gif,World.gif
THIS
}

sub test_perl {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "DeadHerring",
        <<'SMELL');
%QUERY{ "Wibble" style="perl" }%
%QUERY{ "attachments.name" style="perl" }%
%QUERY{ "attachments" style="perl" }%
%META:FORM{name="BleaghForm"}%
%META:FIELD{name="Wibble" title="Wobble" value="Woo"}%
%META:FILEATTACHMENT{name="whatsnot.gif" date="1266942905" size="4586" version="1"}%
%META:FILEATTACHMENT{name="World.gif" date="1266943219" size="2486" version="1"}%
SMELL
    $topicObject->save();
    my $text = <<'PONG';
%INCLUDE{"DeadHerring" NAME="Red" warn="on"}%
PONG
    my $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );
'Woo'
['whatsnot.gif','World.gif']
[{'version' => '1','date' => '1266942905','name' => 'whatsnot.gif','size' => '4586'},{'version' => '1','date' => '1266943219','name' => 'World.gif','size' => '2486'}]
THIS
}

sub test_json {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "DeadHerring",
                          <<'SMELL');
%QUERY{ "Wibble" style="json"}%
%QUERY{ "attachments.name" style="json" }%
%QUERY{ "attachments" style="json" }%
%META:FORM{name="BleaghForm"}%
%META:FIELD{name="Wibble" title="Wobble" value="Woo"}%
%META:FILEATTACHMENT{name="whatsnot.gif" date="1266942905" size="4586" version="1"}%
%META:FILEATTACHMENT{name="World.gif" date="1266943219" size="2486" version="1"}%
SMELL
    $topicObject->save();
    my $text = <<'PONG';
%INCLUDE{"DeadHerring" NAME="Red" warn="on"}%
PONG
    my $result = $this->{test_topicObject}->expandMacros($text);
    eval "require JSON";
    if( $@ ) {
        # Bad JSON
        $this->assert_matches(qr/Perl JSON module is not available/, $result );
    } else {
        # Good JSON
        # The keys are not sorted in the JSON output, so a string comparison
        # that passes on one machine will fail on another.
        # So we have to convert the JSON to perl and do a deep-comparison
        # against a perl data structure. 

        my @perlExpected = (
            "Woo",
            [
                "whatsnot.gif",
                "World.gif"
            ],
            [
                {
                    "date" => "1266942905",
                    "version" => "1",
                    "name" => "whatsnot.gif",
                    "size" => "4586"
                },
                {
                    "date" => "1266943219",
                    "version" => "1",
                    "name" => "World.gif",
                    "size" => "2486"
                }
            ]
        );

        #
        my @result = split /\n/, $result;
        $this->assert_num_equals( scalar(@perlExpected), scalar(@result) );
        my $json = JSON->new->allow_nonref;
        for my $index ( 0 .. $#perlExpected ) {
            my $perlResult = $json->decode( $result[$index] );

            $this->assert_deep_equals( $perlExpected[$index], $perlResult );
        }
    }
}

sub test_ref {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "DeadHerring",
        <<'SMELL');
%META:FORM{name="BleaghForm"}%
%META:FIELD{name="Wibble" title="Wobble" value="Woo"}%
%META:FILEATTACHMENT{name="whatsnot.gif" date="1266942905" size="4586" version="1"}%
%META:FILEATTACHMENT{name="World.gif" date="1266943219" size="2486" version="1"}%
SMELL
    $topicObject->save();

    my $text = <<PONG;
%QUERY{ "'$this->{test_web}.DeadHerring'/form.name"}%
%QUERY{ "'$this->{test_web}.DeadHerring'/attachments.name" }%
PONG
    my $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );
BleaghForm
whatsnot.gif,World.gif
THIS
}

sub test_cfg {
    my $this = shift;

    # Check a few that should be hidden
    foreach my $var ( '{Htpasswd}{FileName}', '{Password}', '{ScriptDir}') {
        my $text = "%QUERY{\"$var\"}%";
        my $result = $this->{test_topicObject}->expandMacros($text);
        $this->assert_equals( '', $result );
    }

    # Try those that *should* be visible (skip 'Filter' because it's a regex
    foreach my $var ( grep { !/Accessible|Filter/ } @{$Foswiki::cfg{AccessibleCFG}}) {
        my $text = "%QUERY{\"$var\"}%";
        my $result = $this->{test_topicObject}->expandMacros($text);
        while ($result =~ s/^\(?xism:(.*)\)$/$1/) {
        }
        my $expected = eval("\$Foswiki::cfg$var");
        $expected = '' unless defined $expected;
        $this->assert_equals( $expected, "$result", "$var!=$expected" );
    }
}

1;
