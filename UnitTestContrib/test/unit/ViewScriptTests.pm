use strict;

package ViewScriptTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );

my $twiki;

my $topic1 = <<'HERE';
CONTENT
HERE

my $templateTopicContent1 = <<'HERE';
pretemplate%STARTTEXT%pre%TEXT%post%ENDTEXT%posttemplate
HERE

my $templateTopicContent2 = <<'HERE';
pretemplate%TEXT%post%ENDTEXT%posttemplate
HERE

my $templateTopicContent3 = <<'HERE';
pretemplate%STARTTEXT%pre%TEXT%posttemplate
HERE

my $templateTopicContent4 = <<'HERE';
pretemplate%TEXT%posttemplate
HERE

my $templateTopicContent5 = <<'HERE';
pretemplate%STARTTEXT%posttemplate
HERE

## Should this be supported?
my $templateTopicContentX = <<'HERE';
pretemplate%STARTTEXT%pre%ENDTEXT%posttemplate
HERE

sub new {
    my $self = shift()->SUPER::new("ViewScript", @_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $twiki = $this->{twiki};
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_web}, 'TestTopic1',
        $topic1, undef );
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_web}, 'ViewoneTemplate',
        $templateTopicContent1, undef );
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_web}, 'ViewtwoTemplate',
        $templateTopicContent2, undef );
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_web}, 'ViewthreeTemplate',
        $templateTopicContent3, undef );
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_web}, 'ViewfourTemplate',
        $templateTopicContent4, undef );
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_web}, 'ViewfiveTemplate',
        $templateTopicContent5, undef );
}

sub setup_view {
    my ( $this, $web, $topic, $tmpl ) = @_;
    my $query = new Unit::Request({
        webName => [ $web ],
        topicName => [ $topic ],
        template => [ $tmpl ],
    });
    $query->path_info( "/$web/$topic" );
    $twiki = new Foswiki( $this->{test_user_login}, $query );
    my ($text, $result) = $this->capture( \&Foswiki::UI::View::view, $twiki);
    $twiki->finish();
    $text =~ s/\r//g;
    $text =~ s/^.*?\n\n+//s; # remove CGI header
    return $text;
}

# This test verifies the handling of preamble (the text following
# %STARTTEXT%) and postamble (the text between %TEXT% and %ENDTEXT%).
sub test_prepostamble {
    my $this = shift;
    my $text;

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewone' );
    $text =~ s/\n+$//s;
    $this->assert_equals('pretemplatepreCONTENT
postposttemplate', $text);

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewtwo' );
    $this->assert_equals('pretemplateCONTENT
postposttemplate', $text);

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewthree' );
    $this->assert_equals('pretemplatepreCONTENTposttemplate', $text);

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewfour' );
    $this->assert_equals('pretemplateCONTENTposttemplate', $text);

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewfive' );
    $this->assert_equals('pretemplateposttemplate', $text);
}

1;
