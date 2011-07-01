use strict;

# tests for the correct expansion of preferences (*not* FoswikiFns, which
# should have their own individual testcase)

package VariableTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    my $query = new Unit::Request("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( 'scum', $query );
    $this->{test_topicObject} =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
}

sub new {
    my $self = shift()->SUPER::new( 'Variables', @_ );
    return $self;
}

sub test_embeddedExpansions {
    my $this = shift;
    $this->{session}->{prefs}->setSessionPreferences(
        EGGSAMPLE => 'Egg sample',
        A         => 'EGG',
        B         => 'SAMPLE',
        C         => '%%A%',
        D         => '%B%%',
        E         => '%EGG',
        F         => 'SAMPLE%',
        PA        => 'A',
        SB        => 'B',
        EXEMPLAR  => 'Exem plar',
        XA        => 'EXEM',
        XB        => 'PLAR',
    );

    my $result = $this->{test_topicObject}->expandMacros("%%A%%B%%");
    $this->assert_equals( 'Egg sample', $result );

    $result = $this->{test_topicObject}->expandMacros("%C%%D%");
    $this->assert_equals( 'Egg sample', $result );

    $result = $this->{test_topicObject}->expandMacros("%E%%F%");
    $this->assert_equals( 'Egg sample', $result );

    $result = $this->{test_topicObject}->expandMacros("%%XA{}%%XB{}%%");
    $this->assert_equals( 'Exem plar', $result );

    $result = $this->{test_topicObject}->expandMacros("%%XA%%XB%{}%");
    $this->assert_equals( 'Exem plar', $result );

    $result = $this->{test_topicObject}->expandMacros("%%%PA%%%%SB{}%%%");
    $this->assert_equals( 'Egg sample', $result );

}

sub test_topicCreationExpansions {
    my $this = shift;

    my $text = <<'END';
%USERNAME%
%STARTSECTION{type="templateonly"}%
Kill me
%ENDSECTION{type="templateonly"}%
%WIKINAME%
%WIKIUSERNAME%
%WEBCOLOR%
%STARTSECTION{name="fred" type="section"}%
%USERINFO%
%USERINFO{format="$emails,$username,$wikiname,$wikiusername"}%
%USER%NOP%INFO{format="$emails,$username,$wikiname,$wikiusername"}%
%ENDSECTION{name="fred" type="section"}%
END
    $this->{test_topicObject}->text($text);
    $this->{test_topicObject}->put('PREFERENCE',
                                   {name=>"BLAH", value=>"%WIKINAME%"});
    $this->{test_topicObject}->expandNewTopic();

    my $xpect  = <<END;
scum

ScumBag
$this->{users_web}.ScumBag
%WEBCOLOR%
%STARTSECTION{name="fred" type="section"}%
scum, $this->{users_web}.ScumBag, scumbag\@example.com
scumbag\@example.com,scum,ScumBag,$this->{users_web}.ScumBag
%USERINFO{format="\$emails,\$username,\$wikiname,\$wikiusername"}%
%ENDSECTION{name="fred" type="section"}%
END
    $this->assert_str_equals( $xpect, $this->{test_topicObject}->text() );
    $this->assert_str_equals( "ScumBag", $this->{test_topicObject}->get('PREFERENCE', 'BLAH')->{value} );
}

sub test_userExpansions {
    my $this = shift;
    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;

    my $text = <<'END';
%USERNAME%
%WIKINAME%
%WIKIUSERNAME%
%USERINFO%
%USERINFO{format="$cUID,$emails,$username,$wikiname,$wikiusername"}%
%USERINFO{"WikiGuest" format="$cUID,$emails,$username,$wikiname,$wikiusername"}%
END
    my $result = $this->{test_topicObject}->expandMacros($text);
    my $xpect  = <<END;
scum
ScumBag
$this->{users_web}.ScumBag
scum, $this->{users_web}.ScumBag, scumbag\@example.com
${Foswiki::Users::TopicUserMapping::FOSWIKI_USER_MAPPING_ID}scum,scumbag\@example.com,scum,ScumBag,$this->{users_web}.ScumBag
$Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID,,guest,WikiGuest,$this->{users_web}.WikiGuest
END
    $this->annotate( "Foswiki::cfg{Register}{AllowLoginName} == "
          . $Foswiki::cfg{Register}{AllowLoginName} );
    $this->assert_str_equals( $xpect, $result );
}

sub test_macroParams {
    my $this = shift;
    # Check default on undefined macros
    # Check default given, given but null, not given
    # Check quotes and other standard expansions
    # Check override of standard macros
    $this->{session}->{prefs}->setSessionPreferences(
	ARFLE => '%BARFLE{default="gloop"}%',
	TING => '%DEFAULT% %DEFAULT{default="tong"}%',
	ALING =>  '\'%DEFAULT%\' \'%DEFAULT{default="tong"}%\'',
	TOOT => '\'%NOP%\'',
	WOOF =>  '%MIAOW{default="$quot$percent$quot"}%');
    my $input = <<'INPUT';
| gloop | %BARFLE{default="gloop"}% |
| mong | %ARFLE{BARFLE="mong"}% |
| %DEFAULT% tong | %TING% |
| ding ding | %TING{"ding"}% |
| '' '' | %ALING{""}% |
| 'sweet' | %TOOT{NOP="sweet"}% |
| "%" | %WOOF% |
| p"r"r | %WOOF{MIAOW="p$quot()r$quot()r"}% |
INPUT
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, $input );
    my $result = $topicObject->expandMacros($input);
    my $expected = <<'EXPECTED';
| gloop | gloop |
| mong | mong |
| %DEFAULT% tong | %DEFAULT% tong |
| ding ding | ding ding |
| '' '' | '' '' |
| 'sweet' | 'sweet' |
| "%" | "%" |
| p"r"r | p"r"r |
EXPECTED
    $this->assert_str_equals( $expected, $result );

}

1;
