use strict;

# tests for the correct expansion of INCLUDE

package Fn_INCLUDE;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'INCLUDE', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{other_web} = "$this->{test_web}other";
    my $webObject = $this->populateNewWeb( $this->{other_web} );
    $webObject->finish();
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture( $this->{session}, $this->{other_web} );
    $this->SUPER::tear_down();
}

sub run_test_simple {
    my $this = shift;
    my $includeTopic = shift || $this->{test_web}.'.FirstTopic';
    my $includeError = shift;
    my $noSectionError = shift || $includeError;
    
    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1');
    $this->assert_str_equals($includeError?"A $includeError B":'A 1 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'"}% B', 'WebHome', $this->{other_web}));
    
    $this->assert_str_equals($includeError?"A  B":'A 1 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" warn="off"}% B', 'WebHome', $this->{other_web}));


    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTINCLUDE%2%STOPINCLUDE% 3');
    $this->assert_str_equals($includeError?"A $includeError B":'A 2 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{type="include"}%2%ENDSECTION{type="include"}% 3');
    $this->assert_str_equals($includeError?"A $includeError B":'A 2 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{type="include"}%2%ENDSECTION{type="include"}% 3 %STARTSECTION{type="include"}%4%ENDSECTION{type="include"}% 5');
    $this->assert_str_equals($includeError?"A $includeError B":'A 24 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION%2%ENDSECTION% 3');
    $this->assert_str_equals($includeError?"A $includeError B":'A 1 2 3 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{"_default"}%2%ENDSECTION{"_default"}% 3');
    $this->assert_str_equals($includeError?"A $includeError B":'A 1 2 3 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{"_default"}%2%ENDSECTION{"_default"}% 3 %STARTSECTION{type="include"}%4%ENDSECTION{type="include"}% 5');
    $this->assert_str_equals($includeError?"A $includeError B":'A 2 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="_default"}% B', 'WebHome', $this->{other_web}));
    
    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{"_default"}%2%ENDSECTION{"_default"}% 3 %STARTSECTION{type="include"}%4%ENDSECTION{type="include"}% 5');
    $this->assert_str_equals($noSectionError?"A $noSectionError B":'A 2 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="notthere"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{"_default"}%2%ENDSECTION{"_default"}% 3 %STARTSECTION{type="include"}%4%ENDSECTION{type="include"}% 5');
    $this->assert_str_equals($includeError?"A  B":'A 2 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="_default" warn="off"}% B', 'WebHome', $this->{other_web}));
    
    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{"_default"}%2%ENDSECTION{"_default"}% 3 %STARTSECTION{type="include"}%4%ENDSECTION{type="include"}% 5');
    $this->assert_str_equals($noSectionError?"A  B":'A 2 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="notthere" warn="off"}% B', 'WebHome', $this->{other_web}));

}

sub test_simple {
    my $this = shift;
    $this->run_test_simple(undef, undef,
    "<span class='foswikiAlert'>
    Warning: Can't find named section <nop>notthere in topic <nop>TemporaryINCLUDETestWebINCLUDE.<nop>FirstTopic 
</span>");
}

sub test_simple_not_there {
    my $this = shift;
    $this->run_test_simple('NotThere', "<span class='foswikiAlert'>
    Warning: Can't find topic <nop>TemporaryINCLUDETestWebINCLUDEother.<nop>NotThere 
</span>");
}

sub test_not_there_commas {
    my $this = shift;
    $this->run_test_simple('NotThere, System.NoTopic', "<span class='foswikiAlert'>
    Warning: Can\'t find topic <nop>System.<nop>NoTopic 
</span>");
}

sub test_not_there_spaces {
    my $this = shift;
    $this->run_test_simple('NotThere System.NoTopic', "<span class='foswikiAlert'>
    Warning: Can't find topic <nop>NotThere System.<nop>NoTopic 
</span>");
}

sub test_not_there_newlines {
    my $this = shift;
    $this->run_test_simple('NotThere
System.NoTopic', "<span class='foswikiAlert'>
   Warning: Can't INCLUDE '<nop>NotThere
System.NoTopic', path is empty or contains illegal characters. 
</span>");
}

sub test_first_not_there_commas {
    my $this = shift;
    $this->run_test_simple('NotThere, '.$this->{test_web}.'.FirstTopic', undef, "<span class='foswikiAlert'>
    Warning: Can't find named section <nop>notthere in topic <nop>TemporaryINCLUDETestWebINCLUDE.<nop>FirstTopic 
</span>");
}

sub test_first_not_there_spaces {
    my $this = shift;
    $this->run_test_simple('NotThere '.$this->{test_web}.'.FirstTopic', "<span class='foswikiAlert'>
    Warning: Can't find topic <nop>NotThere TemporaryINCLUDETestWebINCLUDE.<nop>FirstTopic 
</span>");
}

sub test_first_not_there_newlines {
    my $this = shift;
    $this->run_test_simple('NotThere
'.$this->{test_web}.'.FirstTopic', "<span class='foswikiAlert'>
   Warning: Can't INCLUDE '<nop>NotThere
TemporaryINCLUDETestWebINCLUDE.FirstTopic', path is empty or contains illegal characters. 
</span>");
}

sub test_simple_section {
    my $this = shift;
    my $includeSection = shift || '';
    my $includeTopic = shift || $this->{test_web}.'.FirstTopic';
    my $includeError = shift;
    my $noSectionError = shift || $includeError;
    
    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1');
    $this->assert_str_equals($noSectionError?"A $noSectionError B":'A 1 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="'.$includeSection.'"}% B', 'WebHome', $this->{other_web}));
    
    $this->assert_str_equals(($includeError||$noSectionError)?"A  B":'A 1 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="'.$includeSection.'" warn="off"}% B', 'WebHome', $this->{other_web}));


    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTINCLUDE%2%STOPINCLUDE% 3');
    $this->assert_str_equals($noSectionError?"A $noSectionError B":'A 2 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="'.$includeSection.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{type="include"}%2%ENDSECTION{type="include"}% 3');
    $this->assert_str_equals($noSectionError?"A $noSectionError B":'A 2 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="'.$includeSection.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{type="include"}%2%ENDSECTION{type="include"}% 3 %STARTSECTION{type="include"}%4%ENDSECTION{type="include"}% 5');
    $this->assert_str_equals($noSectionError?"A $noSectionError B":'A 24 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="'.$includeSection.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION%2%ENDSECTION% 3');
    $this->assert_str_equals($noSectionError?"A $noSectionError B":'A 1 2 3 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="'.$includeSection.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{"_default"}%2%ENDSECTION{"_default"}% 3');
    $this->assert_str_equals($noSectionError?"A $noSectionError B":'A 1 2 3 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="'.$includeSection.'"}% B', 'WebHome', $this->{other_web}));

    Foswiki::Func::saveTopic($this->{test_web}, 'FirstTopic', undef, '1 %STARTSECTION{"_default"}%2%ENDSECTION{"_default"}% 3 %STARTSECTION{type="include"}%4%ENDSECTION{type="include"}% 5');
    $this->assert_str_equals($includeError?"A $includeError B":'A 2 B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.$includeTopic.'" section="'.$includeSection.'" section="_default"}% B', 'WebHome', $this->{other_web}));

}


sub test_select_first_that_defines_section {
    my $this = shift;
    $this->test_simple_section('section_name', 
            join(', ', ('NoSuchTopic', $this->{test_web}.'.NoSuchTopic')),
            "<span class='foswikiAlert'>
    Warning: Can't find topic <nop>TemporaryINCLUDETestWebINCLUDE.<nop>NoSuchTopic 
</span>"
            );


    $this->test_simple_section('section_name', 
            join(', ', ('NoSuchTopic', $this->{test_web}.'.FirstTopic')),
            undef,
            "<span class='foswikiAlert'>
    Warning: Can't find named section <nop>section_name in topic <nop>TemporaryINCLUDETestWebINCLUDE.<nop>FirstTopic 
</span>"
            );

    Foswiki::Func::saveTopic($this->{test_web}, 'NoSection', undef, '1 %STARTSECTION{"_default"}%2%ENDSECTION{"_default"}% 3 %STARTSECTION{type="include"}%4%ENDSECTION{type="include"}% 5');
    $this->test_simple_section('section_name', 
            join(', ', ('NoSuchTopic', $this->{test_web}.'.NoSection', $this->{test_web}.'.FirstTopic')),
            undef,
            "<span class='foswikiAlert'>
    Warning: Can't find named section <nop>section_name in topic <nop>TemporaryINCLUDETestWebINCLUDE.<nop>FirstTopic 
</span>"
            );

    Foswiki::Func::saveTopic($this->{test_web}, 'TheSection', undef, '1 %STARTSECTION{"section_name"}%::%ENDSECTION{"section_name"}% 3 %STARTSECTION{type="include"}%4%ENDSECTION{type="include"}% 5');
    $this->assert_str_equals('A :: B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.
                            join(', ', ($this->{test_web}.'.TheSection', 'NoSuchTopic', $this->{test_web}.'.FirstTopic'))
                            .'" section="section_name"}% B', 'WebHome', $this->{other_web}));
    $this->assert_str_equals('A :: B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.
                            join(', ', ('NoSuchTopic', $this->{test_web}.'.TheSection', $this->{test_web}.'.FirstTopic'))
                            .'" section="section_name"}% B', 'WebHome', $this->{other_web}));
    $this->assert_str_equals('A :: B', Foswiki::Func::expandCommonVariables( 'A %INCLUDE{"'.
                            join(', ', ('NoSuchTopic', $this->{test_web}.'.FirstTopic', $this->{test_web}.'.TheSection'))
                            .'" section="section_name"}% B', 'WebHome', $this->{other_web}));

}



# Test that web references are correctly expanded when a topic is included
# from another web. Verifies that verbatim, literal and noautolink zones
# are correctly honoured.
sub test_webExpansion {
    my $this = shift;

    # Create topic to include
    my $includedTopic = "TopicToInclude";
    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text( <<THIS);
<literal>
1 [[$includedTopic][one]] $includedTopic
</literal>
<verbatim>
2 [[$includedTopic][two]] $includedTopic
</verbatim>
<pre>
3 [[$includedTopic][three]] $includedTopic
</pre>
<noautolink>
4 [[$includedTopic][four]] [[$includedTopic]] $includedTopic
</noautolink>
5 [[$includedTopic][five]] $includedTopic
$includedTopic 6
7 ($includedTopic)
8 #$includedTopic
9 [[System.$includedTopic]]
10 [[$includedTopic]]
11 [[http://fleegle][$includedTopic]]
12 [[#anchor][$includedTopic]]
13 [[#$includedTopic][$includedTopic]]
THIS
    $inkyDink->save();

    # Expand an include in the context of the test web
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $text = $topicObject->expandMacros(
        "%INCLUDE{$this->{other_web}.$includedTopic}%");
    my @get    = split( /\n/, $text );
    my @expect = split( /\n/, <<THIS);
<literal>
1 [[$includedTopic][one]] $includedTopic
</literal>
<verbatim>
2 [[$includedTopic][two]] $includedTopic
</verbatim>
<pre>
3 [[$this->{other_web}.$includedTopic][three]] $this->{other_web}.$includedTopic
</pre>
<noautolink>
4 [[$this->{other_web}.$includedTopic][four]] [[$this->{other_web}.$includedTopic][$includedTopic]] $includedTopic
</noautolink>
5 [[$this->{other_web}.$includedTopic][five]] $this->{other_web}.$includedTopic
$this->{other_web}.$includedTopic 6
7 ($this->{other_web}.$includedTopic)
8 #$includedTopic
9 [[System.$includedTopic]]
10 [[$this->{other_web}.$includedTopic][$includedTopic]]
11 [[http://fleegle][$includedTopic]]
12 [[#anchor][$includedTopic]]
13 [[#$includedTopic][$includedTopic]]
THIS
    while ( my $e = pop(@expect) ) {
        $this->assert_str_equals( $e, pop(@get) );
    }

}

# Test include of a section when there is no such section in the included
# topic
sub test_3158 {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text(<<THIS);
Snurfle
%STARTSECTION{"suction"}%
Such a section!
%ENDSECTION{"suction"}%
Out of scope
THIS
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"suction\"}%");
    $this->assert_str_equals( "\nSuch a section!\n", $text );

    $inkyDink->text(<<THIS);
%STARTSECTION{"nosuction"}%
No such section!
%ENDSECTION{"nosuction"}%
THIS
    $inkyDink->save();

    #warnings are off
    $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"suction\" warn=\"off\"}%"
      );
    $this->assert_str_equals( '', $text );

    #warning on
    $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"suction\" warn=\"on\"}%"
      );
    $this->assert_str_equals( <<HERE, $text . "\n" );
<span class='foswikiAlert'>
    Warning: Can't find named section <nop>suction in topic <nop>TemporaryINCLUDETestWebINCLUDEother.<nop>TopicToInclude 
</span>
HERE

    #custom warning
    $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"suction\" warn=\"consider yourself warned\"}%"
      );
    $this->assert_str_equals( 'consider yourself warned', $text );
}

# INCLUDE{"" section=""}% should act as though section was not set (ie, return the entire topic)
sub test_5649 {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Snurfle
%STARTSECTION{"suction"}%
Such a section!
%ENDSECTION{"suction"}%
Out of scope
THIS
    my $handledTopicText = $topicText;
    $handledTopicText =~ s/%(START|END)SECTION{"suction"}%//g;

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"\"}%");
    $this->assert_str_equals( $handledTopicText, $text . "\n" )
      ;    #add \n because expandMacros removes it :/
}

sub test_singlequoted_params {
    my $this = shift;
    my $text =
      $this->{test_topicObject}
      ->expandMacros("%INCLUDE{'Oneweb.SomeTopic' section='suction'}%");
    $this->assert_str_equals(
        "<span class='foswikiAlert'>
   Warning: Can't INCLUDE '<nop>'Oneweb.SomeTopic' section='suction'', path is empty or contains illegal characters. 
</span>", $text
    );

    $text =
      $this->{test_topicObject}
      ->expandMacros('%INCLUDE{"I can\'t believe its not butter"}%');
    $this->assert_str_equals(
        "<span class='foswikiAlert'>
   Warning: Can't INCLUDE '<nop>I can't believe its not butter', path is empty or contains illegal characters. 
</span>", $text
    );
}

sub test_fullPattern {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Baa baa black sheep
Have you any socks?
Yes sir, yes sir
But only in acrylic
THIS

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" pattern=\"^.*?(Have.*sir).*\"}%"
      );
    $this->assert_str_equals( "Have you any socks?\nYes sir, yes sir", $text );
}

sub test_pattern {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Baa baa black sheep
Have you any socks?
Yes sir, yes sir
But only in acrylic
THIS

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" pattern=\"(Have.*sir)\"}%"
      );
    $this->assert_str_equals( "Have you any socks?\nYes sir, yes sir", $text );
}

# INCLUDE{"" pattern="(blah)"}% that does not match should return nothing
sub test_patternNoMatch {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Baa baa black sheep
Have you any socks?
Yes sir, yes sir
But only in acrylic
THIS

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"$this->{other_web}.$includedTopic\" pattern=\"(blah)\"}%");
    $this->assert_str_equals( "", $text );
}

# INCLUDE{"" pattern="blah"}% that does not capture should return nothing
sub test_patternNoCapture {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Baa baa black sheep
Have you any socks?
Yes sir, yes sir
But only in acrylic
THIS

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"$this->{other_web}.$includedTopic\" pattern=\".*\"}%");
    $this->assert_str_equals( "", $text );
}

sub test_docInclude {
    my $this = shift;

    my $class = 'Foswiki::IncludeHandlers::doc';
    my $text = $this->{test_topicObject}->expandMacros("%INCLUDE{doc:$class}%");
    my $expected = <<"EXPECTED";

---+ =internal package= Foswiki::IncludeHandlers::doc

This package is designed to be lazy-loaded when Foswiki sees
an INCLUDE macro with the doc: protocol. It implements a single
method INCLUDE which generates perl documentation for a Foswiki class.

EXPECTED
    $this->assert_str_equals( $expected, $text );

    # Add a pattern
    $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"doc:$class\" pattern=\"(Foswiki .*protocol)\"}%");
    $expected = "Foswiki sees\nan INCLUDE macro with the doc: protocol";
    $this->assert_str_equals( $expected, $text );

    # A pattern with no ()'s
    $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"doc:$class\" pattern=\"Foswiki .*protocol\"}%");
    $expected = '';
    $this->assert_str_equals( $expected, $text );

    # A pattern that does not match
    $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"doc:$class\" pattern=\"(cabbage.*avocado)\" warn=\"no\"}%");
    $expected = '';
    $this->assert_str_equals( $expected, $text );
}

sub test_hassleFreeHoff {
    my $this = shift;

    # Create topic to include
    my $includedTopic = "TopicToInclude";
    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{test_web}, $includedTopic );
    $inkyDink->text( <<INCLUDE);
---+ H1
---++ H2
---+++ H3
---++++ H4
---+++++ H5
---++++++ H6
<h6>H6</H6>
<H5>H5</h5>
<H4>H4</H4>
<h3>H3</h3>
<h2 style="color:orange">H2</h2>
<h1>H1</h1>
<ho off="1">
---+ H1
<ho off="-1">
---+ H1
INCLUDE
    $inkyDink->save();

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $text = $topicObject->expandMacros(<<EXPAND);
%INCLUDE{"$includedTopic" headingoffset="1"}%
%INCLUDE{"$includedTopic" headingoffset="+1"}%
%INCLUDE{"$includedTopic" headingoffset="-1"}%
EXPAND
    $text = $topicObject->renderTML($text);
    $text =~ s/<nop>//g;
    my $expect = <<EXPECT;
<h2 id="H1_AN3">  H1 </h2>
<h3 id="H2">  H2 </h3>
<h4 id="H3_AN3">  H3 </h4>
<h5 id="H4_AN3">  H4 </h5>
<h6 id="H5_AN3">  H5 </h6>
<h6 id="H6_AN3">  H6 </h6>
<h6 id="H6"> H6 </h6>
<h6 id="H5"> H5 </h6>
<h5 id="H4"> H4 </h5>
<h4 id="H3"> H3 </h4>
<h3 style="color:orange">H2</h3>
<h2 id="H1"> H1 </h2>
<h3 id="H1_AN4">  H1 </h3>
<h2 id="H1_AN5">  H1 </h2>

<h2 id="H1_AN6">  H1 </h2>
<h3 id="H2_AN1">  H2 </h3>
<h4 id="H3_AN4">  H3 </h4>
<h5 id="H4_AN4">  H4 </h5>
<h6 id="H5_AN4">  H5 </h6>
<h6 id="H6_AN4">  H6 </h6>
<h6 id="H6_AN1"> H6 </h6>
<h6 id="H5_AN1"> H5 </h6>
<h5 id="H4_AN1"> H4 </h5>
<h4 id="H3_AN1"> H3 </h4>
<h3 style="color:orange">H2</h3>
<h2 id="H1_AN1"> H1 </h2>
<h3 id="H1_AN7">  H1 </h3>
<h2 id="H1_AN8">  H1 </h2>

<h1 id="H1_AN9">  H1 </h1>
<h1 id="H2_AN2">  H2 </h1>
<h2 id="H3_AN5">  H3 </h2>
<h3 id="H4_AN5">  H4 </h3>
<h4 id="H5_AN5">  H5 </h4>
<h5 id="H6_AN5">  H6 </h5>
<h5 id="H6_AN2"> H6 </h5>
<h4 id="H5_AN2"> H5 </h4>
<h3 id="H4_AN2"> H4 </h3>
<h2 id="H3_AN2"> H3 </h2>
<h1 style="color:orange">H2</h1>
<h1 id="H1_AN2"> H1 </h1>
<h1 id="H1_AN10">  H1 </h1>
<h1 id="H1_AN11">  H1 </h1>
EXPECT
    $this->assert_html_equals( $expect, $text );
}

1;
