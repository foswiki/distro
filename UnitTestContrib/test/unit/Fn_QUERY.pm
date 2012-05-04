# tests for the correct expansion of QUERY

package Fn_QUERY;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::Configure::Dependency ();
use Error qw( :try );
use Assert;

my $post11;

sub new {
    my $self = shift()->SUPER::new( 'QUERY', @_ );
    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki",
        version => ">=1.2"
    );
    ( $post11, my $depmsg ) = $dep->check();

    return $self;
}

sub simpleTest {
    my ( $this, %test ) = @_;
    $this->{session}->enterContext('test');
    my $text =
      $this->{test_topicObject}
      ->expandMacros( '%QUERY{"' . $test{test} . '"}%' );

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
        test   => "d2n('2007-03-26')",
        expect => Foswiki::Time::parseTime( '2007-03-26', 1 )
    );
}

sub test_6 {
    my $this = shift;
    $this->simpleTest(
        test   => "fields[name='nonExistantField']",
        expect => ''
    );
}

sub test_7 {
    my $this = shift;
    $this->simpleTest(
        test   => "fields[name='nonExistantField'].value",
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
    $this->simpleTest( test => "''",    expect => '' );
}

# check parse failures
sub test_badQUERY {
    my $this  = shift;
    my @tests = (
        { test => "'A'=?",   expect => "Syntax error in ''A'=?' at '?'" },
        { test => "'A'==",   expect => "Excess operators (= =) in ''A'=='" },
        { test => "'A' 'B'", expect => "Missing operator in ''A' 'B''" },
    );

    push @tests, ( { test => ' ', expect => "Empty expression" }, )
      unless ($post11);

    foreach my $test (@tests) {
        my $text   = '%QUERY{"' . $test->{test} . '"}%';
        my $result = $this->{test_topicObject}->expandMacros($text);
        $result =~ s/^.*foswikiAlert'>\s*//s;
        $result =~ s/\s*<\/span>\s*//s;
        $this->assert( $result =~ s/^.*}:\s*//s, $text );
        $this->assert_str_equals( $test->{expect}, $result );
    }
    my $result = $this->{test_topicObject}->expandMacros('%QUERY%');

    if ($post11) {
        $this->assert_str_equals( '', $result );
    }
    else {
        $result =~ s/^.*foswikiAlert'>\s*//s;
        $result =~ s/\s*<\/span>\s*//s;
        $this->assert( $result =~ s/^.*}:\s*//s );
        $this->assert_str_equals( 'Empty expression', $result );
    }
}

sub test_CAS {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "DeadHerring" );
    $topicObject->text( <<'SMELL');
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
    $topicObject->finish();
}

sub test_perl {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "DeadHerring" );
    $topicObject->text( <<'SMELL');
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
    $topicObject->finish();
}

sub test_json {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "DeadHerring" );
    $topicObject->text( <<'SMELL');
[
%QUERY{ "Wibble" style="json"}%,
%QUERY{ "attachments.name" style="json" }%,
%QUERY{ "attachments" style="json" }%
]
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
    if ($@) {

        # Bad JSON
        $this->assert_matches(
            qr/Perl (JSON::XS or )?JSON module is not available/, $result );
    }
    else {

        # Good JSON
        $this->assert_json_equals( <<THIS, $result );
[
"Woo",
["whatsnot.gif","World.gif"],
[{"date":"1266942905","version":"1","name":"whatsnot.gif","size":"4586"},{"date":"1266943219","version":"1","name":"World.gif","size":"2486"}]
]
THIS
    }
    $topicObject->finish();
}

#style defaults to Simplified (ie style=default)
sub test_InvalidStyle {
    my $this = shift;

    unless ($post11) {
        print "InvalidStyle test not supported prior to Release 1.2\n";
        return;
    }

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "DeadHerring" );
    $topicObject->text( <<'SMELL');
%QUERY{ "BleaghForm.Wibble"  style="NoSuchStyle" }%
%QUERY{ "Wibble"  style="NoSuchStyle" }%
%QUERY{ "attachments.name"  style="NoSuchStyle" }%
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
    $topicObject->finish();
}

sub test_ref {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "DeadHerring" );
    $topicObject->text( <<'SMELL');
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
    $topicObject->finish();
}

sub test_cfg {
    my $this = shift;

    # Check a few that should be hidden
    foreach my $var ( '{Htpasswd}{FileName}', '{Password}', '{ScriptDir}' ) {
        my $text   = "%QUERY{\"$var\"}%";
        my $result = $this->{test_topicObject}->expandMacros($text);
        $this->assert_equals( '', $result );
    }

    # Try those that *should* be visible (skip 'Filter' because it's a regex
    foreach my $var ( grep { !/Accessible|Filter/ }
        @{ $Foswiki::cfg{AccessibleCFG} } )
    {
        my $text   = "%QUERY{\"$var\"}%";
        my $result = $this->{test_topicObject}->expandMacros($text);
        while ( $result =~ s/^\(?xism:(.*)\)$/$1/ ) {
        }
        my $expected = eval("\$Foswiki::cfg$var");
        $expected = '' unless defined $expected;
        $this->assert_equals( $expected, "$result", "$var!=$expected" );
    }
}

# Item11502
sub test_opWHERE {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "DeadHerring" );
    $topicObject->text( <<'SMELL');
%META:FORM{name="BleaghForm"}%
%META:FIELD{name="Wibble" title="Wobble" value="Woo"}%
%META:FILEATTACHMENT{name="asdf.pl.txt" attachment="asdf.pl.txt" attr="" comment="Wobble" date="1333656208" path="asdf.pl" size="984" user="BaseUserMapping_333" version="1"}%
SMELL
    $topicObject->save();

    my ($topicObject2Att) =
      Foswiki::Func::readTopic( $this->{test_web}, "DeadHerring2Att" );
    $topicObject2Att->text( <<'SMELL');
%META:FORM{name="BleaghForm"}%
%META:FIELD{name="Wibble" title="Wobble" value="Woo"}%
%META:FILEATTACHMENT{name="asdf.pl.txt" attachment="asdf.pl.txt" attr="" comment="Wobble" date="1333656208" path="asdf.pl" size="984" user="BaseUserMapping_333" version="1"}%
%META:FILEATTACHMENT{name="asdf.pl2.txt" attachment="asdf.pl2.txt" attr="" comment="Wobble2" date="1333656208" path="asdf2.pl" size="984" user="BaseUserMapping_333" version="1"}%
SMELL
    $topicObject2Att->save();

    my ($topicObject0Att) =
      Foswiki::Func::readTopic( $this->{test_web}, "DeadHerring0Att" );
    $topicObject0Att->text( <<'SMELL');
%META:FORM{name="BleaghForm"}%
%META:FIELD{name="Wibble" title="Wobble" value="Woo"}%
SMELL
    $topicObject0Att->save();

    my $text = <<PONG;
%QUERY{ "'$this->{test_web}.DeadHerring'/META:FIELD[name='Wibble'].value"}%
PONG
    my $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );
Woo
THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring'/attachments[comment='Wobble'].name"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );
asdf.pl.txt
THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring2Att'/attachments[comment='Wobble'].name"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );
asdf.pl.txt
THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring0Att'/attachments[comment='Wobble'].name"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );

THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring'/attachments[comment='Wobble Trouble'].name"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );

THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring2Att'/attachments[comment='Wobble Trouble'].name"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );

THIS

    ##################################################
    # Array indexing tests - Item11730
    ##################################################

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring'/attachments[0].comment"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );
Wobble
THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring'/attachments[1].comment"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );

THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring2Att'/attachments[0].comment"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );
Wobble
THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring2Att'/attachments[1].comment"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );
Wobble2
THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring2Att'/attachments[2].comment"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );

THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring0Att'/attachments[0].comment"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );

THIS

    $text = <<PONG;
%QUERY{"'$this->{test_web}.DeadHerring0Att'/attachments[7].comment"}%
PONG
    $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( <<THIS, $result );

THIS

    $topicObject->finish();
    $topicObject0Att->finish();
    $topicObject2Att->finish();
}

1;
