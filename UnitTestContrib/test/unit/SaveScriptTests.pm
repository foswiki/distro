package SaveScriptTests;
use v5.14;

use Foswiki();
use Foswiki::UI::Save();
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

my $testform1 = <<'HERE';
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |
| Select | select | 1 | Value_1, Value_2, *Value_3* |  |
| Radio | radio | 3 | 1, 2, 3 | |
| Checkbox | checkbox | 3 | red,blue,green | |
| Checkbox and Buttons | checkbox+buttons | 3 | dog,cat,bird,hamster,goat,horse | |
| Textfield | text | 60 | test | |
HERE

my $testform2 = $testform1 . <<'HERE';
| Mandatory | text | 60 | | | M |
| Field not in TestForm1 | text | 60 | text |
HERE

my $testform3 = <<'HERE';
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |
| Select | select | 1 | Value_1, Value_2, *Value_3* |  |
| Radio | radio | 3 | 1, 2, 3 | |
| Checkbox | checkbox | 3 | red,blue,green | |
| Textfield | text | 60 | test | |
HERE

my $testform4 = $testform1 . <<'HERE';
| Textarea | textarea | 4X2 | Green eggs and ham |
HERE

my $testtext1 = <<'HERE';
%META:TOPICINFO{author="ProjectContributor" date="1111931141" format="1.1" version="0"}%

A guest of this Foswiki web, not unlike yourself. You can leave your trace behind you, just add your name in %SYSTEMWEB%.UserRegistration and create your own page.

%META:FORM{name="TestForm1"}%
%META:FIELD{name="Select" title="Select" value="Value_2"}%
%META:FIELD{name="Radio" title="Radio" value="3"}%
%META:FIELD{name="Checkbox" title="Checkbox" value="red"}%
%META:FIELD{name="Textfield" title="Textfield" value="Test"}%
%META:FIELD{name="CheckboxandButtons" title="CheckboxandButtons" value=""}%
%META:PREFERENCE{name="VIEW_TEMPLATE" title="VIEW_TEMPLATE" value="UserTopic"}%
HERE

my $testtext_nometa = <<'HERE';

A guest of this Foswiki web, not unlike yourself. You can leave your trace behind you, just add your name in %SYSTEMWEB%.UserRegistration and create your own page.

HERE

#"

around BUILDARGS => sub {
    my $orig = shift;
    $orig->( @_, testSuite => 'Save' );
};

sub skip {
    my ( $this, $test ) = @_;

    return $this->skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                'SaveScriptTests::test_preferenceSave' =>
                  'Preference setting from save is new in 1.2',
                'SaveScriptTests::test_simpleTextPreview' =>
                  'Links in preview is new in 1.2',
            }
        }
    );
}

has test_user_2_forename => ( is => 'rw', );
has test_user_2_surname  => ( is => 'rw', );
has test_user_2_wikiname => ( is => 'rw', );
has test_user_2_login    => ( is => 'rw', );
has test_user_2_email    => ( is => 'rw', );
has test_user_3_forename => ( is => 'rw', );
has test_user_3_surname  => ( is => 'rw', );
has test_user_3_wikiname => ( is => 'rw', );
has test_user_3_login    => ( is => 'rw', );
has test_user_3_email    => ( is => 'rw', );

# Set up the test fixture
around set_up => sub {
    my $orig = shift;
    my $this = shift;
    $orig->( $this, @_ );

    $this->test_user_2_forename('Buck');
    $this->test_user_2_surname('Rogers');
    $this->test_user_2_wikiname(
        $this->test_user_forename . $this->test_user_surname );
    $this->test_user_2_login('buck');
    $this->test_user_2_email('rogers@example.com');
    $this->registerUser(
        $this->test_user_2_login,   $this->test_user_2_forename,
        $this->test_user_2_surname, $this->test_user_2_email
    );

    $this->test_user_3_forename('Duck');
    $this->test_user_3_surname('Dodgers');
    $this->test_user_3_wikiname(
        $this->test_user_3_forename . $this->test_user_3_surname );
    $this->test_user_3_login('duck');
    $this->test_user_3_email('dodgers@example.com');
    $this->registerUser(
        $this->test_user_3_login,   $this->test_user_3_forename,
        $this->test_user_3_surname, $this->test_user_3_email
    );

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, 'TestForm1' );
    $topicObject->text($testform1);
    $topicObject->save();
    undef $topicObject;

    ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'TestForm2' );
    $topicObject->text($testform2);
    $topicObject->save();
    undef $topicObject;

    ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'TestForm3' );
    $topicObject->text($testform3);
    $topicObject->save();
    undef $topicObject;

    ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'TestForm4' );
    $topicObject->text($testform4);
    $topicObject->save();
    undef $topicObject;

    ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web,
        $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'CONTENT');
   * Set WEBFORMS = TestForm1,TestForm2,TestForm3,TestForm4
   * Set DENYWEBCHANGE = DuckDodgers
CONTENT
    $topicObject->save();

    return;
};

# Foswiki::App handleRequestException callback function.
sub _cbHRE {
    my $obj  = shift;
    my %args = @_;
    $args{params}{exception}->rethrow;
}

around createNewFoswikiApp => sub {
    my $orig = shift;
    my $this = shift;

    my %params = @_;

    $params{engineParams}{initialAttributes}{action} //= 'save';

    $this->app->cfg->data->{DisableAllPlugins} = 1;

    return $orig->( $this, @_,
        callbacks => { handleRequestException => \&_cbHRE }, );
};

# AUTOINC
sub test_AUTOINC {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                text   => ['nowt'],
            },
        },
        engineParams => {
            initialAttributes => {
                user      => $this->test_user_login,
                path_info => '/' . $this->test_web . '.TestAutoAUTOINC00',
                method    => 'post',
            },
        },
    );
    my %old;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {
        $old{$t} = 1;
    }
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {
        if ( $t eq 'TestAuto00' ) {
            $seen = 1;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert($seen);
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                text   => ['nowt'],
            },
        },
        engineParams => {
            initialAttributes => {
                user      => $this->test_user_login,
                path_info => '/' . $this->test_web . '.TestAutoAUTOINC00',
                method    => 'pOsT',
            },
        },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {

        if ( $t =~ m/^TestAuto0[01]$/ ) {
            $seen++;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert_equals( 2, $seen );

    return;
}

# 10X
sub test_XXXXXXXXXX {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                text   => ['nowt'],
            },
        },
        engineParams => {
            initialAttributes => {
                user      => $this->test_user_login,
                path_info => '/' . $this->test_web . '.TestTopicXXXXXXXXXX',
            },
        },
    );
    my %old;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {
        $old{$t} = 1;
    }
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {
        if ( $t eq 'TestTopic0' ) {
            $seen = 1;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert($seen);
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                text   => ['nowt'],
            },
        },
        engineParams => {
            initialAttributes => {
                user      => $this->test_user_login,
                path_info => '/' . $this->test_web . '.TestTopicXXXXXXXXXX',
            },
        },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {
        if ( $t =~ m/^TestTopic[01]$/ ) {
            $seen++;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert_equals( 2, $seen );

    return;
}

# 9X
sub test_XXXXXXXXX {
    my $this = shift;
    $this->assert(
        !$this->app->store->topicExists( $this->test_web, 'TestTopic0' ) );
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                text   => ['nowt'],
            },
        },
        engineParams => {
            initialAttributes => {
                user      => $this->test_user_login,
                path_info => '/' . $this->test_web . '.TestTopicXXXXXXXXX',
            },
        },
    );
    my %old;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {
        $old{$t} = 1;
    }
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $this->assert(
        !$this->app->store->topicExists( $this->test_web, 'TestTopic0' ) );
    my $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {
        if ( $t eq 'TestTopicXXXXXXXXX' ) {
            $seen = 1;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert($seen);

    return;
}

#11X
sub test_XXXXXXXXXXX {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                text   => ['nowt'],
            },
        },
        engineParams => {
            initialAttributes => {
                user      => $this->test_user_login,
                path_info => '/' . $this->test_web . '.TestTopicXXXXXXXXXX',
            },
        },
    );
    my %old;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {
        $old{$t} = 1;
    }
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->test_web ) ) {
        if ( $t eq 'TestTopic0' ) {
            $seen = 1;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert($seen);

    return;
}

sub test_emptySave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                topic  => [ $this->test_web . '.EmptyTestSaveScriptTopic' ],
            },
        },
        enginParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my ($meta) =
      Foswiki::Func::readTopic( $this->test_web, 'EmptyTestSaveScriptTopic' );
    my $text = $meta->text;
    $this->assert_matches( qr/^\s*$/, $text );
    $this->assert_null( $meta->get('FORM') );

    return;
}

sub test_simpleTextPreview {
    my $this = shift;
    my ( $test_web, $test_topic ) = ( $this->test_web, $this->test_topic );
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text => [<<HERE],
CUT##
<a href="blah.com">no target</a>
<a href='bloo.com' target=_self>self undelim</a>
<a href='blerg.com' target='_self' asdf="what">self SQ</a>
[[$test_web.$test_topic]]
<a href='blerg.com' target="your'_self'" asdf="what">messed up</a>
##CUT
HERE
                action => ['preview'],
                topic  => [ $test_web . '.DeleteTestSaveScriptTopic' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    my ( $text, $results, $stdout, $stderr ) =
      $this->captureWithKey( save => sub { $this->app->handleRequest }, );

    $text =~ s/.*CUT##(.*?)##CUT.*/$1/ms;

    $this->assert_html_equals( <<HERE, $text );
<a target="_blank" href="blah.com">no target</a>
<a href='bloo.com' target="_blank">self undelim</a>
<a href='blerg.com' target="_blank" asdf="what">self SQ</a>
<a target="_blank" href="$Foswiki::cfg{ScriptUrlPaths}{view}/$test_web/$test_topic">$test_web.$test_topic</a>
<a href='blerg.com' target="_blank" asdf="what">messed up</a>
HERE
    $this->assert( !$stdout );
    $this->assert( !$stderr );

    return;
}

sub test_simpleTextSave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text   => ['CORRECT'],
                action => ['save'],
                topic  => [ $this->test_web . '.DeleteTestSaveScriptTopic' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my ($meta) =
      Foswiki::Func::readTopic( $this->test_web, 'DeleteTestSaveScriptTopic' );
    my $text = $meta->text;
    $this->assert_matches( qr/CORRECT/, $text );
    $this->assert_null( $meta->get('FORM') );

    return;
}

sub test_simpleTextSaveDeniedWebCHANGE {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text   => ['CORRECT'],
                action => ['save'],
                topic  => [ $this->test_web . '.DeleteTestSaveScriptTopic3' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_3_login, }, },
        callbacks => { handleRequestException => \&_cbHRE },
    );

    my $exception;
    try {
        $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    }
    catch {
        $exception = $_;
        if ( ref($exception) ) {
            if ( $exception->isa('Foswiki::OopsException') ) {
                if (   ( "attention" eq $exception->template )
                    && ( "thanks" eq $exception->def ) )
                {
                    print STDERR "---------" . $exception->stringify() . "\n"
                      if ($Error::Debug);
                    $exception = undef;    #the only correct answer
                }
            }
        }
        else {
            $exception = Foswiki::Exception::Fatal->transmute($exception);
        }
    };

    $this->assert_matches(
qr/AccessControlException: Access to CHANGE TemporarySaveTestWebSave. for duck is denied. access denied on web/,
        $exception->stringify
    );
    $this->assert(
        !$this->app->store->topicExists(
            $this->test_web, 'DeleteTestSaveScriptTopic3'
        )
    );

    return;
}

sub test_templateTopicTextSave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text   => ['Template Topic'],
                action => ['save'],
                topic  => [ $this->test_web . '.TemplateTopic' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text   => ['Template Topic'],
                action => ['save'],
                topic  => [ $this->test_web . '.TemplateTopic' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my ($meta) = Foswiki::Func::readTopic( $this->test_web, 'TemplateTopic' );
    my $text = $meta->text;
    $this->assert_matches( qr/Template Topic/, $text );
    $this->assert_null( $meta->get('FORM') );

    return;
}

# Save over existing topic
sub test_prevTopicTextSave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text   => ['WRONG'],
                action => ['save'],
                topic  => [ $this->test_web . '.PrevTopicTextSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text   => ['CORRECT'],
                action => ['save'],
                topic  => [ $this->test_web . '.PrevTopicTextSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my ($meta) =
      Foswiki::Func::readTopic( $this->test_web, 'PrevTopicTextSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/CORRECT/, $text );
    $this->assert_null( $meta->get('FORM') );

    return;
}

# Save into missing web
sub test_missingWebSave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text   => ['WRONG'],
                action => ['save'],
                topic  => ['MissingWeb.PrevTopicTextSave']
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    try {
        $this->captureWithKey( save => sub { $this->app->handleRequest }, );
        $this->assert( 0, 'save into missing web worked' );
    }
    catch {
        my $e = shift;
        if ( ref($e) && $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( 'no_such_web', $e->def );
        }
        else {
            Foswiki::Exception::Fatal->rethrow($e);
        }
    };

    return;
}

# Save over existing topic with no text
sub test_prevTopicEmptyTextSave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text   => ['CORRECT'],
                action => ['save'],
                topic  => [ $this->test_web . '.PrevTopicEmptyTextSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                topic  => [ $this->test_web . '.PrevTopicEmptyTextSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my ($meta) =
      Foswiki::Func::readTopic( $this->test_web, 'PrevTopicEmptyTextSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/^\s*CORRECT\s*$/, $text );
    $this->assert_null( $meta->get('FORM') );

    return;
}

sub test_simpleFormSave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text         => ['CORRECT'],
                formtemplate => ['TestForm1'],
                action       => ['save'],
                'Textfield'  => ['Flintstone'],
                topic        => [ $this->test_web . '.SimpleFormSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $this->assert(
        $this->app->store->topicExists( $this->test_web, 'SimpleFormSave' ) );
    my ($meta) = Foswiki::Func::readTopic( $this->test_web, 'SimpleFormSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/^CORRECT\s*$/, $text );
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );

    # field default values should be all ''
    $this->assert_str_equals( 'Flintstone',
        $meta->get( 'FIELD', 'Textfield' )->{value} );

    return;
}

sub test_templateTopicFormSave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text         => ['Template Topic'],
                formtemplate => ['TestForm1'],
                'Select'     => ['Value_1'],
                'Textfield'  => ['Fred'],
                action       => ['save'],
                topic        => [ $this->test_web . '.TemplateTopic' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );

    my ($xmeta) = Foswiki::Func::readTopic( $this->test_web, 'TemplateTopic' );
    my $xtext = $xmeta->text;
    undef $xmeta;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                templatetopic => ['TemplateTopic'],
                action        => ['save'],
                topic         => [ $this->test_web . '.TemplateTopicAgain' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my ($meta) =
      Foswiki::Func::readTopic( $this->test_web, 'TemplateTopicAgain' );
    my $text = $meta->text;
    $this->assert_matches( qr/Template Topic/, $text );
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );

    $this->assert_str_equals( 'Value_1',
        $meta->get( 'FIELD', 'Select' )->{value} );
    $this->assert_str_equals( 'Fred',
        $meta->get( 'FIELD', 'Textfield' )->{value} );

    return;
}

sub test_prevTopicFormSave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text         => ['Template Topic'],
                formtemplate => ['TestForm1'],
                'Select'     => ['Value_1'],
                'Textfield'  => ['Rubble'],
                action       => ['save'],
                topic        => [ $this->test_web . '.PrevTopicFormSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action      => ['save'],
                'Textfield' => ['Barney'],
                topic       => [ $this->test_web . '.PrevTopicFormSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    my ( $responseText, $result, $stdout, $stderr ) =
      $this->captureWithKey( save => sub { $this->app->handleRequest }, );

    # Uncomment to get output from command
    #print STDERR $responseText . $result . $stdout . $stderr . "\n";

    my ($meta) =
      Foswiki::Func::readTopic( $this->test_web, 'PrevTopicFormSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/Template Topic/, $text );
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );
    $this->assert_str_equals( 'Value_1',
        $meta->get( 'FIELD', 'Select' )->{value} );
    $this->assert_str_equals( 'Barney',
        $meta->get( 'FIELD', 'Textfield' )->{value} );

    return;
}

sub test_simpleFormSave1 {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action               => ['save'],
                text                 => [$testtext_nometa],
                formtemplate         => ['TestForm1'],
                'Select'             => ['Value_2'],
                'Radio'              => ['3'],
                'Checkbox'           => ['red'],
                'CheckboxandButtons' => ['hamster'],
                'Textfield'          => ['Test'],
                topic                => [ $this->test_web . '.SimpleFormTopic' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $this->assert(
        $this->app->store->topicExists( $this->test_web, 'SimpleFormTopic' ) );
    my ($meta) = Foswiki::Func::readTopic( $this->test_web, 'SimpleFormTopic' );
    my $text = $meta->text;
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );
    $this->assert_str_equals( 'Test',
        $meta->get( 'FIELD', 'Textfield' )->{value} );

    return;
}

# Field values that do not have a corresponding definition in form
# are deleted.
sub test_simpleFormSave2 {
    my $this = shift;
    $this->createNewFoswikiApp;

    my ($oldmeta) =
      Foswiki::Func::readTopic( $this->test_web, 'SimpleFormSave2' );
    my $oldtext = $testtext1;
    $oldmeta->setEmbeddedStoreForm($oldtext);
    my ($meta) = Foswiki::Func::readTopic( $this->test_web, 'SimpleFormSave2' );
    $meta->text($testform1);
    $meta->copyFrom($oldmeta);
    undef $oldmeta;
    $meta->save( user => $this->test_user_login );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action               => ['save'],
                text                 => [$testtext_nometa],
                formtemplate         => ['TestForm3'],
                'Select'             => ['Value_2'],
                'Radio'              => ['3'],
                'Checkbox'           => ['red'],
                'CheckboxandButtons' => ['hamster'],
                'Textfield'          => ['Test'],
                topic                => [ $this->test_web . '.SimpleFormSave2' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $this->assert(
        $this->app->store->topicExists( $this->test_web, 'SimpleFormSave2' ) );
    undef $meta;
    ($meta) = Foswiki::Func::readTopic( $this->test_web, 'SimpleFormSave2' );
    my $text = $meta->text;
    $this->assert_str_equals( 'TestForm3', $meta->get('FORM')->{name} );
    $this->assert_str_equals( 'Test',
        $meta->get( 'FIELD', 'Textfield' )->{value} );
    $this->assert_null( $meta->get( 'FIELD', 'CheckboxandButtons' ) );

    return;
}

# meta data (other than FORM, FIELD, TOPICPARENT, etc.) is preserved
# during saves.
sub test_simpleFormSave3 {
    my $this = shift;
    $this->createNewFoswikiApp;

    my ($oldmeta) =
      Foswiki::Func::readTopic( $this->test_web, 'SimpleFormSave3' );
    my $oldtext = $testtext1;
    $oldmeta->setEmbeddedStoreForm($oldtext);
    my ($meta) = Foswiki::Func::readTopic( $this->test_web, 'SimpleFormSave3' );
    $meta->text($testform1);
    $meta->copyFrom($oldmeta);
    undef $oldmeta;
    $meta->save( user => $this->test_user_login );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action               => ['save'],
                text                 => [$testtext_nometa],
                formtemplate         => ['TestForm1'],
                'Select'             => ['Value_2'],
                'Radio'              => ['3'],
                'Checkbox'           => ['red'],
                'CheckboxandButtons' => ['hamster'],
                'Textfield'          => ['Test'],
                topic                => [ $this->test_web . '.SimpleFormSave3' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $this->assert(
        $this->app->store->topicExists( $this->test_web, 'SimpleFormSave3' ) );
    undef $meta;
    ($meta) = Foswiki::Func::readTopic( $this->test_web, 'SimpleFormSave3' );
    my $text = $meta->text;
    $this->assert($meta);
    $this->assert_str_equals( 'UserTopic',
        $meta->get( 'PREFERENCE', 'VIEW_TEMPLATE' )->{value} );

    return;
}

# Testing zero value form field values - Item9970
# The purpose of this test is to confirm that we can save the value 0
# We have made this bug several times in history
sub test_simpleFormSaveZeroValue {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text         => ['CORRECT'],
                formtemplate => ['TestForm1'],
                action       => ['save'],
                'Textfield'  => ['0'],
                topic        => [ $this->test_web . '.SimpleFormSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $this->assert(
        $this->app->store->topicExists( $this->test_web, 'SimpleFormSave' ) );
    my ($meta) = Foswiki::Func::readTopic( $this->test_web, 'SimpleFormSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/^CORRECT\s*$/, $text );
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );

    $this->assert_str_equals( '0',
        $meta->get( 'FIELD', 'Textfield' )->{value} );

    return;
}

# Testing empty value form field values - Item9970
# The purpose of this test is to confirm that we can save an empty value
sub test_simpleFormSaveEmptyValue {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text         => ['CORRECT'],
                formtemplate => ['TestForm1'],
                action       => ['save'],
                'Textfield'  => [''],
                topic        => [ $this->test_web . '.SimpleFormSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $this->assert(
        $this->app->store->topicExists( $this->test_web, 'SimpleFormSave' ) );
    my ($meta) = Foswiki::Func::readTopic( $this->test_web, 'SimpleFormSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/^CORRECT\s*$/, $text );
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );

    $this->assert_str_equals( '', $meta->get( 'FIELD', 'Textfield' )->{value} );

    return;
}

# meta data (other than FORM, FIELD, TOPICPARENT, etc.) is inherited from
# templatetopic
sub test_templateTopicWithMeta {
    my $this = shift;

    Foswiki::Func::saveTopicText( $this->test_web, "TemplateTopic",
        $testtext1 );
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                templatetopic => ['TemplateTopic'],
                action        => ['save'],
                topic         => [ $this->test_web . '.TemplateTopicWithMeta' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my ($meta) =
      Foswiki::Func::readTopic( $this->test_web, 'TemplateTopicWithMeta' );
    my $text = $meta->text;
    my $pref = $meta->get( 'PREFERENCE', 'VIEW_TEMPLATE' );
    $this->assert_not_null($pref);
    $this->assert_str_equals( 'UserTopic', $pref->{value} );

    return;
}

# attachments are copied over from templatetopic
sub test_templateTopicWithAttachments {
    my $this = shift;

    my $FILE;
    my $testfile = $this->app->cfg->data->{TempfileDir} . "/testfile.txt";
    $this->assert( open( $FILE, ">", $testfile ), "Write to $testfile: $!" );
    print $FILE "one two three";
    $this->assert( close($FILE) );
    $this->assert(
        open(
            $FILE, ">", $this->app->cfg->data->{TempfileDir} . "/testfile2.txt"
        )
    );
    print $FILE "four five six";
    $this->assert( close($FILE) );

    my $templateTopic = "TemplateTopic";
    my $testTopic     = "TemplateTopicWithAttachment";

    Foswiki::Func::saveTopic( $this->test_web, $templateTopic, undef,
        "test with an attachment" );

    Foswiki::Func::saveAttachment(
        $this->test_web,
        $templateTopic,
        "testfile.txt",
        {
            file    => "$Foswiki::cfg{TempfileDir}/testfile.txt",
            comment => "a comment"
        }
    );
    Foswiki::Func::saveAttachment(
        $this->test_web,
        $templateTopic,
        "testfile2.txt",
        {
            file    => "$Foswiki::cfg{TempfileDir}/testfile2.txt",
            comment => "a comment"
        }
    );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                templatetopic => ['TemplateTopic'],
                action        => ['save'],
                topic         => [ $this->test_web . ".$testTopic" ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->test_web, $testTopic );

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

    return;
}

#Mergeing is only enabled if the topic text comes from =text= and =originalrev= is &gt; 0 and is not the same as the revision number of the most recent revision. If mergeing is enabled both the topic and the meta-data are merged.

sub test_merge {
    my $this = shift;
    $this->createNewFoswikiApp;

    # Set up the original topic that the two edits started on
    my ($oldmeta) = Foswiki::Func::readTopic( $this->test_web, 'MergeSave' );
    my $oldtext = $testtext1;
    $oldmeta->setEmbeddedStoreForm($oldtext);
    $oldmeta->text($testform4);
    $oldmeta->save( user => $this->test_user_2_login );

    undef $oldmeta;
    my ($meta) = Foswiki::Func::readTopic( $this->test_web, 'MergeSave' );
    my $text   = $meta->text;
    my $info   = $meta->getRevisionInfo();
    my $original = "$info->{version}_$info->{date}";

    #print STDERR "Starting at $original\n";

    # Now build a query for the save at the end of the first edit,
    # forcing a revision increment.
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action               => ['save'],
                text                 => ["Soggy bat"],
                originalrev          => $original,
                forcenewrevision     => 1,
                formtemplate         => ['TestForm4'],
                'Select'             => ['Value_2'],
                'Radio'              => ['3'],
                'Checkbox'           => ['red'],
                'CheckboxandButtons' => ['hamster'],
                'Textfield'          => ['Bat'],
                'Textarea'           => [ <<'GUMP' ],
Glug Glug
Blog Glog
Bungdit Din
Glaggie
GUMP
                topic => [ $this->test_web . '.MergeSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    $info = $meta->getRevisionInfo();

    #print STDERR "First edit saved as $info->{version}_$info->{date}\n";

    # Build a second query for the other save, based on the same original
    # version as the previous edit
    # This time we expect a merge exception
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action               => ['save'],
                text                 => ["Wet rat"],
                originalrev          => $original,
                formtemplate         => ['TestForm4'],
                'Select'             => ['Value_2'],
                'Radio'              => ['3'],
                'Checkbox'           => ['red'],
                'CheckboxandButtons' => ['hamster'],
                'Textfield'          => ['Rat'],
                'Textarea'           => [ <<'GUMP' ],
Spletter Glug
Blog Splut
Bungdit Din
GUMP
                topic => [ $this->test_web . '.MergeSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_2_login, }, },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    try {
        $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    }
    catch {
        my $e = shift;
        if ( ref($e) && $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( 'merge_notice', $e->def );
        }
        else {
            Foswiki::Exception::Fatal->rethrow($e);
        }
    };

    # Get the merged topic and pick it apart
    undef $meta;
    ($meta) = Foswiki::Func::readTopic( $this->test_web, 'MergeSave' );
    $text = $meta->text;
    my $e = <<'END';
<div class="foswikiConflict"><b>CONFLICT</b> original 1:</div>
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |
<div class="foswikiConflict"><b>CONFLICT</b> version 2:</div>
Soggy bat
<div class="foswikiConflict"><b>CONFLICT</b> version new:</div>
Wet rat
<div class="foswikiConflict"><b>CONFLICT</b> end</div>
END
    $this->assert_str_equals( $e, $text );

    my $v = $meta->get( 'FIELD', 'Select' );
    $this->assert_str_equals( 'Value_2', $v->{value} );
    $v = $meta->get( 'FIELD', 'Radio' );
    $this->assert_str_equals( '3', $v->{value} );
    $v = $meta->get( 'FIELD', 'Checkbox' );
    $this->assert_str_equals( 'red', $v->{value} );
    $v = $meta->get( 'FIELD', 'CheckboxandButtons' );
    $this->assert_str_equals( 'hamster', $v->{value} );
    $v = $meta->get( 'FIELD', 'Textfield' );
    $this->assert_str_equals( '<del>Bat</del><ins>Rat</ins>', $v->{value} );
    $v = $meta->get( 'FIELD', 'Textarea' );
    $this->assert_str_equals( <<'ZIS', $v->{value} );
<del>Glug </del><ins>Spletter </ins>Glug
Blog <del>Glog
</del><ins>Splut
</ins>Bungdit Din
Glaggie
ZIS

    return;
}

# test interaction with reprev. Testcase:
#
# 1. A edits and saves (rev 1 now on disc)
# 2. B hits the EDIT button. (originalrev=1)
# 3. A hits the EDIT button. (originalrev=1)
# 5. A saves the SimultaneousEdit (repRevs rev 1)
# 6. B saves the SimultaneousEdit (no change, so no merge)
#

sub test_1897 {
    my $this = shift;

    # make sure we have time to complete the test
    $Foswiki::cfg{ReplaceIfEditedAgainWithin} = 7200;

    $this->createNewFoswikiApp( engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, }, );

    my ($oldmeta) = Foswiki::Func::readTopic( $this->test_web, 'MergeSave' );
    my $oldtext = $testtext1;
    my $query;
    $oldmeta->setEmbeddedStoreForm($oldtext);

    $this->assert_str_equals( $testtext1, $oldmeta->getEmbeddedStoreForm() );

    # First, user A saves to create rev 1
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->test_web, 'MergeSave' );
    $meta->copyFrom($oldmeta);
    $meta->text("Smelly\ncat");
    $meta->save();
    undef $meta;

    ( $meta, $text ) = Foswiki::Func::readTopic( $this->test_web, 'MergeSave' );

    my $info = $meta->getRevisionInfo();
    my ( $orgDate, $orgAuth, $orgRev ) =
      ( $info->{date}, $info->{author}, $info->{version} );

    $this->assert_equals( 1, $orgRev );
    $this->assert_str_equals( "Smelly\ncat", $text );

    my $original = "${orgRev}_$orgDate";
    sleep(1);    # tick the clock to ensure the date changes

    # A saves again, reprev triggers to create rev 1 again
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action      => ['save'],
                text        => ["Sweaty\ncat"],
                originalrev => $original,
                topic       => [ $this->test_web . '.MergeSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );

    # make sure it's still rev 1 as expected
    my $text2;
    ( $meta, $text2 ) =
      Foswiki::Func::readTopic( $this->test_web, 'MergeSave' );

    $info = $meta->getRevisionInfo();
    my ( $repRevDate, $repRevAuth, $repRevRev ) =
      ( $info->{date}, $info->{author}, $info->{version} );
    $this->assert_equals( 1, $repRevRev );
    $this->assert_str_equals( "Sweaty\ncat\n",        $text2 );
    $this->assert_str_equals( $this->test_user_login, $repRevAuth );
    $this->assert( $repRevDate != $orgDate );

    # User B saves; make sure we get a merge notice.
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action      => ['save'],
                text        => ["Smelly\nrat"],
                originalrev => $original,
                topic       => [ $this->test_web . '.MergeSave' ]
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_2_login, }, },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    try {
        $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    }
    catch {
        my $e = shift;
        if ( ref($e) && $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( 'merge_notice', $e->def );
        }
        else {
            Foswiki::Exception::Fatal->rethrow($e);
        }
    };

    undef $meta;
    ($meta) = Foswiki::Func::readTopic( $this->test_web, 'MergeSave' );
    $text = $meta->text();

    $info = $meta->getRevisionInfo();
    my ( $mergeDate, $mergeAuth, $mergeRev ) =
      ( $info->{date}, $info->{author}, $info->{version} );
    $this->assert_equals( 2, $mergeRev );
    $this->assert_str_equals(
"<del>Sweaty\n</del><ins>Smelly\n</ins><del>cat\n</del><ins>rat\n</ins>",
        $text
    );

    return;
}

sub test_cmdEqualsReprev {
    my $this = shift;

    # make sure we have time to complete the test
    $Foswiki::cfg{ReplaceIfEditedAgainWithin} = 7200;

    $this->createNewFoswikiApp( engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, }, );

    my ($oldmeta) = Foswiki::Func::readTopic( $this->test_web, 'RepRev' );
    my $oldtext = $testtext1;
    my $query;
    $oldmeta->setEmbeddedStoreForm($oldtext);

    $this->assert_str_equals( $testtext1, $oldmeta->getEmbeddedStoreForm() );

    # First, user A saves to create rev 1
    my ( $meta, $text ) = Foswiki::Func::readTopic( $this->test_web, 'RepRev' );
    $meta->copyFrom($oldmeta);
    $meta->text("Les Miserables");
    $meta->save();
    undef $meta;

    ( $meta, $text ) = Foswiki::Func::readTopic( $this->test_web, 'RepRev' );

    my $info = $meta->getRevisionInfo();
    my ( $orgDate, $orgAuth, $orgRev ) =
      ( $info->{date}, $info->{author}, $info->{version} );

    my $original = "${orgRev}_$orgDate";
    sleep(1);    # tick the clock to ensure the date changes

    # admin reprevs to create rev 1 again with new text
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                text   => ["A Tale of Two Cities"],
                cmd    => ['repRev'],
                topic  => [ $this->test_web . '.RepRev' ]
            },
        },
        engineParams => {
            initialAttributes =>
              { user => $this->app->cfg->data->{SuperAdminGroup}, },
        },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );

    # make sure it's still rev 1 as expected
    my $text2;
    ( $meta, $text2 ) = Foswiki::Func::readTopic( $this->test_web, 'RepRev' );

    # make sure original rev info is preserved
    $info = $meta->getRevisionInfo();
    my ( $repRevDate, $repRevAuth, $repRevRev ) =
      ( $info->{date}, $info->{author}, $info->{version} );
    $this->assert_equals( $orgRev, $repRevRev );
    $this->assert_str_equals( "A Tale of Two Cities", $text2 );
    $this->assert_str_equals( $orgAuth,               $repRevAuth );

    # The new rev is offset by 60s to avoid problems with revision control
    # systems (see note in Meta.pm)
    print STDERR "$orgDate + 60, $repRevDate\n";
    $this->assert( $orgDate < $repRevDate );

    return;
}

sub test_missingTemplateTopic {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                templatetopic => ['NonExistantTemplateTopic'],
                action        => ['save'],
                topic         => [ $this->test_web . '.FlibbleDeDib' ]
            },
        },
        engineParams => {
            initialAttributes =>
              { user => $this->test_user_login, method => 'post', },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    try {
        $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    }
    catch {
        my $e = shift;
        if ( ref($e) && $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( 'no_such_topic_template', $e->def );
        }
        else {
            Foswiki::Exception::Fatal->rethrow($e);
        }
    };

    return;
}

sub test_addform {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['addform'],
                topic  => [ $this->test_web . "." . $this->test_topic ],
            },
        },
        engineParams => {
            initialAttributes =>
              { user => $this->test_user_login, method => 'POST', },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    try {
        my ($text) =
          $this->captureWithKey( save => sub { $this->app->handleRequest }, );

        foreach my $val (qw(TestForm1 TestForm2 TestForm3 TestForm4)) {
            ( my $tf ) = $text =~ m/.*(<input .*?value="$val".*?>).*/;
            $this->assert_matches( qr/name="formtemplate"/, $tf );
        }
    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    };

    return;
}

sub test_get {
    my $this = shift;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action => ['save'],
                topic  => [ $this->test_web . "." . $this->test_topic ]
            },
        },
        engineParams => {
            initialAttributes =>
              { user => $this->test_user_login, method => 'GET', },
        },
        callbacks => { handleRequestException => \&_cbHRE },
    );
    try {
        my ($text) =
          $this->captureWithKey( save => sub { $this->app->handleRequest }, );
        $this->assert_matches( qr/^Status: 403.*$/m, $text );
    }
    catch {
        #catch Error::Simple with {};
        Foswiki::Exception::Fatal->rethrow($_);
    }

    return;
}

sub test_preferenceSave {
    my $this = shift;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text             => ["CORRECT\n   * Set UNSETME = x\n"],
                action           => ['save'],
                topic            => [ $this->test_web . '.PrefTopic' ],
                "Set+SETME"      => ['set me'],
                "Set+SETME2"     => ['set me 2'],
                "Local+LOCALME"  => ['local me'],
                "Local+LOCALME2" => ['local me 2']
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    my ($meta) = Foswiki::Func::readTopic( $this->test_web, 'PrefTopic' );
    my $text = $meta->text;
    $this->assert_equals( 'local me',
        $meta->get( 'PREFERENCE', 'LOCALME' )->{value} );
    $this->assert_equals( 'local me 2',
        $meta->get( 'PREFERENCE', 'LOCALME2' )->{value} );
    $this->assert_equals( 'set me',
        $meta->get( 'PREFERENCE', 'SETME' )->{value} );
    $this->assert_equals( 'set me 2',
        $meta->get( 'PREFERENCE', 'SETME2' )->{value} );
    undef $meta;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                text             => ["CORRECT\n   * Set UNSETME = x\n"],
                action           => ['save'],
                topic            => [ $this->test_web . '.PrefTopic' ],
                "Unset+SETME"    => [1],
                "Unset+LOCALME2" => [1],

                # Default+ does nothing without a corresponding Set+ or Local+
                "Set+SETME2"      => ['set me 2'],
                "Local+LOCALME"   => ['local me'],
                "Default+LOCALME" => ['local me'],
                "Default+SETME2"  => ['set me 2']
            },
        },
        engineParams =>
          { initialAttributes => { user => $this->test_user_login, }, },
    );
    $this->captureWithKey( save => sub { $this->app->handleRequest }, );
    ($meta) = Foswiki::Func::readTopic( $this->test_web, 'PrefTopic' );
    $text = $meta->text;
    $this->assert_null( $meta->get( 'PREFERENCE', 'SETME' ) );
    $this->assert_null( $meta->get( 'PREFERENCE', 'LOCALME' ) );
    $this->assert_null( $meta->get( 'PREFERENCE', 'SETME2' ) );
    $this->assert_null( $meta->get( 'PREFERENCE', 'LOCALME2' ) );

    return;
}

1;
