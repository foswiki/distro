package TopicTemplatesTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::UI::Save();
use Unit::Request();
use Error qw( :try );

my $UI_FN;
my $testform1 = <<'HERE';
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |
| Select | select | 1 | Value_1, Value_2, *Value_3* |  |
| Radio | radio | 3 | 1, 2, 3 | |
| Checkbox | checkbox | 3 | red,blue,green | |
| Checkbox and Buttons | checkbox+buttons | 3 | dog,cat,bird,hamster,goat,horse | |
| Textfield | text | 60 | test | |
HERE

my $testtext1 = <<'HERE';

A guest of this Foswiki web, not unlike yourself. You can leave your trace behind you, just add your name in %SYSTEMWEB%.UserRegistration and create your own page.

%META:PREFERENCE{name="VIEW_TEMPLATE" title="VIEW_TEMPLATE" value="UserTopic"}%
HERE

sub new {
    my ( $class, @args ) = @_;

    return $class->SUPER::new( 'TopicTemplates', @args );
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $UI_FN ||= $this->getUIFn('save');

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'TestForm1' );
    $topicObject->text($testform1);
    $topicObject->save();
    $topicObject->finish();

    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'CONTENT');
   * Set WEBFORMS = TestForm1
CONTENT
    $topicObject->save();
    $topicObject->finish();

    return;
}

sub test_templateTopicTextSave {
    my $this  = shift;
    my $query = Unit::Request->new(
        {
            text   => ['Template Topic'],
            action => ['save'],
            topic  => [ $this->{test_web} . '.TemplateTopic' ]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $query = Unit::Request->new(
        {
            templatetopic => ['TemplateTopic'],
            action        => ['save'],
            topic         => [ $this->{test_web} . '.TemplateTopic' ]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'TemplateTopic' );
    my $text = $meta->text;
    $this->assert_matches( qr/Template Topic/, $text );
    $this->assert_null( $meta->get('FORM') );
    $meta->finish();

    return;
}

sub test_templateTopicFormSave {
    my $this  = shift;
    my $query = Unit::Request->new(
        {
            text         => ['Template Topic'],
            formtemplate => ['TestForm1'],
            'Select'     => ['Value_1'],
            'Textfield'  => ['Fred'],
            action       => ['save'],
            topic        => [ $this->{test_web} . '.TemplateTopic' ]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );

    my ($xmeta) =
      Foswiki::Func::readTopic( $this->{test_web}, 'TemplateTopic' );
    my $xtext = $xmeta->text;
    $xmeta->finish();
    $query = Unit::Request->new(
        {
            templatetopic => ['TemplateTopic'],
            action        => ['save'],
            topic         => [ $this->{test_web} . '.TemplateTopicAgain' ]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, 'TemplateTopicAgain' );
    my $text = $meta->text;
    $this->assert_matches( qr/Template Topic/, $text );
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );

    $this->assert_str_equals( 'Value_1',
        $meta->get( 'FIELD', 'Select' )->{value} );
    $this->assert_str_equals( 'Fred',
        $meta->get( 'FIELD', 'Textfield' )->{value} );
    $meta->finish();

    return;
}

# meta data (other than FORM, FIELD, TOPICPARENT, etc.) is inherited from
# templatetopic
sub test_templateTopicWithMeta {
    my $this = shift;

    Foswiki::Func::saveTopicText( $this->{test_web}, "TemplateTopic",
        $testtext1 );
    my $query = Unit::Request->new(
        {
            templatetopic => ['TemplateTopic'],
            action        => ['save'],
            topic         => [ $this->{test_web} . '.TemplateTopicWithMeta' ]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, 'TemplateTopicWithMeta' );
    my $text = $meta->text;
    my $pref = $meta->get( 'PREFERENCE', 'VIEW_TEMPLATE' );
    $this->assert_not_null($pref);
    $this->assert_str_equals( 'UserTopic', $pref->{value} );
    $meta->finish();

    return;
}

# attachments are copied over from templatetopic
sub test_templateTopicWithAttachments {
    my $this = shift;

    $this->assert(
        open( my $FILE, ">", "$Foswiki::cfg{TempfileDir}/testfile.txt" ) );
    print $FILE "one two three";
    $this->assert( close($FILE) );
    $this->assert(
        open( $FILE, ">", "$Foswiki::cfg{TempfileDir}/testfile2.txt" ) );
    print $FILE "four five six";
    $this->assert( close($FILE) );

    my $templateTopic = "TemplateTopic";
    my $testTopic     = "TemplateTopicWithAttachment";

    Foswiki::Func::saveTopic( $this->{test_web}, $templateTopic, undef,
        "test with an attachment" );

    Foswiki::Func::saveAttachment(
        $this->{test_web},
        $templateTopic,
        "testfile.txt",
        {
            file    => "$Foswiki::cfg{TempfileDir}/testfile.txt",
            comment => "a comment"
        }
    );
    Foswiki::Func::saveAttachment(
        $this->{test_web},
        $templateTopic,
        "testfile2.txt",
        {
            file    => "$Foswiki::cfg{TempfileDir}/testfile2.txt",
            comment => "a comment"
        }
    );

    my $query = Unit::Request->new(
        {
            templatetopic => ['TemplateTopic'],
            action        => ['save'],
            topic         => ["$this->{test_web}.$testTopic"]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $testTopic );

    $this->assert_matches( qr/test with an attachment/, $text );
    $this->assert_not_null(
        $meta->get( 'FILEATTACHMENT', 'testfile.txt' ),
        "attachment meta copied for testfile.txt"
    );
    $this->assert_not_null(
        $meta->get( 'FILEATTACHMENT', 'testfile2.txt' ),
        "attachment meta copied for testfile2.txt"
    );
    $this->assert( $meta->testAttachment( "testfile.txt", 'e' ),
        "testfile.txt copied" );
    $this->assert( $meta->testAttachment( "testfile2.txt", 'e' ),
        "testfile2.txt copied" );
    $meta->finish();

    return;
}

sub test_templateTopicWithEOTCMacros {
    my $this = shift;
    $Foswiki::cfg{ExpandSomeMacrosOnTopicCreation} = 1;
    my $query = Unit::Request->new(
        {
            text => [<<'TEXT'],
   * NOP: No%NOP%Link
   * DATE: %DATE%
   * CREATE:DATE: %CREATE:DATE%
   * GMTIME: %GMTIME%
   * SERVERTIME: %SERVERTIME%
   * USERNAME: %USERNAME%
   * URLPARAM: %URLPARAM{"purple"}%
   * WIKINAME: %WIKINAME%
   * WIKIUSERNAME: %WIKIUSERNAME%
   * COMMENT: #{ ... comment }#
%STARTSECTION{type="templateonly"}%
Mither me not
%ENDSECTION{type="templateonly"}%
%STARTSECTION{type="expandvariables"}%
%TOPIC%
%ENDSECTION{type="expandvariables"}%
%TOPIC%
TEXT
            action => ['save'],
            topic  => [ $this->{test_web} . '.TemplateTopic' ]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $query = Unit::Request->new(
        {
            templatetopic => ['TemplateTopic'],
            action        => ['save'],
            purple        => ['ok'],
            topic         => [ $this->{test_web} . '.TemplatedTopic' ]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $responseText, $result, $stdout, $stderr ) =
      $this->captureWithKey( save => $UI_FN, $this->{session} );
    print STDERR $stderr;
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, 'TemplatedTopic' );
    my $text = $meta->text;
    $this->assert( $text =~ s/^\s*\* DATE: \d+ \w+ \d+$//m,             $text );
    $this->assert( $text =~ s/^\s*\* CREATE:DATE: \d+ \w+ \d+$//m,      $text );
    $this->assert( $text =~ s/^\s*\* GMTIME: \d+ \w+ \d+ - \d+:\d+$//m, $text );
    $this->assert( $text =~ s/^\s*\* SERVERTIME: \d+ \w+ \d+ - \d+:\d+$//m,
        $text );
    $this->assert( $text =~ s/^\s*\* USERNAME: scum$//m,             $text );
    $this->assert( $text =~ s/^\s*\* WIKINAME: ScumBag$//m,          $text );
    $this->assert( $text =~ s/^\s*\* WIKIUSERNAME: \w+\.ScumBag$//m, $text );
    $this->assert( $text =~ s/^\s*\* URLPARAM: ok$//m,               $text );
    $this->assert( $text =~ s/^\s*\* NOP: NoLink$//m,                $text );
    $this->assert( $text =~ s/^\s*\* COMMENT: $//m,                  $text );
    $this->assert( $text =~ s/^TemplatedTopic$//m,                   $text );
    $this->assert( $text =~ s/^%TOPIC%$//m,                          $text );
    $this->assert( $text !~ /Mither me not/s, $text );
    $text =~ s/\s+//gs;
    $this->assert_equals( "", $text );
    $meta->finish();

    return;
}

sub test_templateTopicWithCREATEMacros {
    my $this = shift;
    $Foswiki::cfg{DisableEOTC} = 1;
    my $query = Unit::Request->new(
        {
            text => [<<'TEXT'],
   * NOP: No%NOP%Link
   * DATE: %DATE%
   * CREATE:DATE: %CREATE:DATE%
   * CREATE:USERNAME: %CREATE:USERNAME%
   * CREATE:URLPARAM: %CREATE:URLPARAM{"purple"}%
   * URLPARAM: %URLPARAM{"purple"}%
   * COMMENT: %{ ... comment }%
   * CREATE:IF: %CREATE:IF{"1=1" then="OK" else="BAD"}%
%STARTSECTION{type="templateonly"}%
Mither me not
%ENDSECTION{type="templateonly"}%
%STARTSECTION{type="expandvariables"}%
%TOPIC%
%ENDSECTION{type="expandvariables"}%
%TOPIC%
TEXT
            action => ['save'],
            topic  => [ $this->{test_web} . '.TemplateTopic' ]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $query = Unit::Request->new(
        {
            templatetopic => ['TemplateTopic'],
            action        => ['save'],
            purple        => ['ok'],
            topic         => [ $this->{test_web} . '.TemplatedTopic' ]
        }
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $responseText, $result, $stdout, $stderr ) =
      $this->captureWithKey( save => $UI_FN, $this->{session} );
    print STDERR $stderr;
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, 'TemplatedTopic' );
    my $text = $meta->text;
    $this->assert( $text =~ s/^\s*\* DATE: %DATE%$//m,             $text );
    $this->assert( $text =~ s/^\s*\* CREATE:DATE: \d+ \w+ \d+$//m, $text );
    $this->assert( $text =~ s/^\s*\* CREATE:USERNAME: scum$//m,    $text );
    $this->assert( $text =~ s/^\s*\* CREATE:URLPARAM: ok$//m,      $text );
    $this->assert( $text =~ s/^\s*\* URLPARAM: %URLPARAM\{"purple"\}%$//m,
        $text );
    $this->assert( $text =~ s/^\s*\* NOP: NoLink$//m,                  $text );
    $this->assert( $text =~ s/^\s*\* CREATE:IF: OK$//m,                $text );
    $this->assert( $text =~ s/^\s*\* COMMENT: %\{ ... comment \}%$//m, $text );
    $this->assert( $text =~ s/^TemplatedTopic$//m,                     $text );
    $this->assert( $text =~ s/^%TOPIC%$//m,                            $text );
    $this->assert( $text !~ /Mither me not/s, $text );
    $text =~ s/\s+//gs;
    $this->assert_equals( "", $text );
    $meta->finish();

    return;
}

1;
