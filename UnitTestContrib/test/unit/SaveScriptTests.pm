use strict;

package SaveScriptTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::UI::Save;
use Error qw( :try );
use Unit::Request;

our $UI_FN;

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
%META:TOPICINFO{author="ProjectContributor" date="1111931141" format="1.0" version="$Rev$"}%

A guest of this Foswiki web, not unlike yourself. You can leave your trace behind you, just add your name in %SYSTEMWEB%.UserRegistration and create your own page.

%META:FORM{name="TestForm1"}%
%META:FIELD{name="Select" attributes="" title="Select" value="Value_2"}%
%META:FIELD{name="Radio" attributes="" title="Radio" value="3"}%
%META:FIELD{name="Checkbox" attributes="" title="Checkbox" value="red"}%
%META:FIELD{name="Textfield" attributes="" title="Textfield" value="Test"}%
%META:FIELD{name="CheckboxandButtons" attributes="" title="CheckboxandButtons" value=""}%
%META:PREFERENCE{name="VIEW_TEMPLATE" title="VIEW_TEMPLATE" value="UserTopic"}%
HERE

my $testtext_nometa = <<'HERE';

A guest of this Foswiki web, not unlike yourself. You can leave your trace behind you, just add your name in %SYSTEMWEB%.UserRegistration and create your own page.

HERE

sub new {
    my $self = shift()->SUPER::new( 'Save', @_ );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $UI_FN ||= $this->getUIFn('save');

    $this->{test_user_2_forename} = 'Buck';
    $this->{test_user_2_surname}  = 'Rogers';
    $this->{test_user_2_wikiname} =
      $this->{test_user_forename} . $this->{test_user_surname};
    $this->{test_user_2_login} = 'buck';
    $this->{test_user_2_email} = 'rogers@example.com';
    $this->registerUser(
        $this->{test_user_2_login},   $this->{test_user_2_forename},
        $this->{test_user_2_surname}, $this->{test_user_2_email}
    );

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm1',
        $testform1, undef );
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm2',
        $testform2, undef );
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm3',
        $testform3, undef );
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm4',
        $testform4, undef );
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<CONTENT);
   * Set WEBFORMS = TestForm1,TestForm2,TestForm3,TestForm4
CONTENT
    $topicObject->save();

    $Foswiki::Plugins::SESSION = $this->{session};
}

# AUTOINC
sub test_AUTOINC {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action => ['save'],
            text   => ['nowt'],
        }
    );
    $query->path_info( '/' . $this->{test_web} . '.TestAutoAUTOINC00' );
    $this->{session}->finish();
    $query->method('post');
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    my %old;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        $old{$t} = 1;
    }
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        if ( $t eq 'TestAuto00' ) {
            $seen = 1;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert($seen);
    $this->{session}->finish();
    $query->method('pOsT');
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {

        if ( $t =~ /^TestAuto0[01]$/ ) {
            $seen++;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert_equals( 2, $seen );
}

# 10X
sub test_XXXXXXXXXX {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action => ['save'],
            text   => ['nowt'],
        }
    );
    $query->path_info( '/' . $this->{test_web} . '.TestTopicXXXXXXXXXX' );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    my %old;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        $old{$t} = 1;
    }
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        if ( $t eq 'TestTopic0' ) {
            $seen = 1;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert($seen);
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        if ( $t =~ /^TestTopic[01]$/ ) {
            $seen++;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert_equals( 2, $seen );
}

# 9X
sub test_XXXXXXXXX {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action => ['save'],
            text   => ['nowt'],
        }
    );
    $query->path_info("/$this->{test_web}/TestTopicXXXXXXXXX");
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, 'TestTopic0' ) );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    my %old;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        $old{$t} = 1;
    }
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, 'TestTopic0' ) );
    my $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        if ( $t eq 'TestTopicXXXXXXXXX' ) {
            $seen = 1;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert($seen);
}

#11X
sub test_XXXXXXXXXXX {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action => ['save'],
            text   => ['nowt'],
        }
    );
    $query->path_info("/$this->{test_web}/TestTopicXXXXXXXXXXX");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    my %old;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        $old{$t} = 1;
    }
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $seen = 0;
    foreach my $t ( Foswiki::Func::getTopicList( $this->{test_web} ) ) {
        if ( $t eq 'TestTopic0' ) {
            $seen = 1;
        }
        elsif ( !$old{$t} ) {
            $this->assert( 0, "Unexpected topic $t" );
        }
    }
    $this->assert($seen);
}

sub test_emptySave {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action => ['save'],
            topic  => [ $this->{test_web} . '.EmptyTestSaveScriptTopic' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'EmptyTestSaveScriptTopic' );
    my $text = $meta->text;
    $this->assert_matches( qr/^\s*$/, $text );
    $this->assert_null( $meta->get('FORM') );
}

sub test_simpleTextSave {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            text   => ['CORRECT'],
            action => ['save'],
            topic  => [ $this->{test_web} . '.DeleteTestSaveScriptTopic' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'DeleteTestSaveScriptTopic' );
    my $text = $meta->text;
    $this->assert_matches( qr/CORRECT/, $text );
    $this->assert_null( $meta->get('FORM') );
}

sub test_templateTopicTextSave {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            text   => ['Template Topic'],
            action => ['save'],
            topic  => [ $this->{test_web} . '.TemplateTopic' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $query = new Unit::Request(
        {
            templatetopic => ['TemplateTopic'],
            action        => ['save'],
            topic         => [ $this->{test_web} . '.TemplateTopic' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'TemplateTopic' );
    my $text = $meta->text;
    $this->assert_matches( qr/Template Topic/, $text );
    $this->assert_null( $meta->get('FORM') );
}

# Save over existing topic
sub test_prevTopicTextSave {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            text   => ['WRONG'],
            action => ['save'],
            topic  => [ $this->{test_web} . '.PrevTopicTextSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $query = new Unit::Request(
        {
            text   => ['CORRECT'],
            action => ['save'],
            topic  => [ $this->{test_web} . '.PrevTopicTextSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'PrevTopicTextSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/CORRECT/, $text );
    $this->assert_null( $meta->get('FORM') );
}

# Save into missing web
sub test_missingWebSave {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            text   => ['WRONG'],
            action => ['save'],
            topic  => [ 'MissingWeb' . '.PrevTopicTextSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    try {
        $this->captureWithKey( save => $UI_FN, $this->{session} );
        $this->assert(0, 'save into missing web worked');
        }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'no_such_web', $e->{def} );
    }
    otherwise {
        $this->assert( 0, shift );
    };
}

# Save over existing topic with no text
sub test_prevTopicEmptyTextSave {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            text   => ['CORRECT'],
            action => ['save'],
            topic  => [ $this->{test_web} . '.PrevTopicEmptyTextSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $query = new Unit::Request(
        {
            action => ['save'],
            topic  => [ $this->{test_web} . '.PrevTopicEmptyTextSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'PrevTopicEmptyTextSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/^\s*CORRECT\s*$/, $text );
    $this->assert_null( $meta->get('FORM') );
}

sub test_simpleFormSave {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            text         => ['CORRECT'],
            formtemplate => ['TestForm1'],
            action       => ['save'],
            'Textfield'  => ['Flintstone'],
            topic        => [ $this->{test_web} . '.SimpleFormSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, 'SimpleFormSave' ) );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'SimpleFormSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/^CORRECT\s*$/, $text );
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );

    # field default values should be all ''
    $this->assert_str_equals( 'Flintstone',
        $meta->get( 'FIELD', 'Textfield' )->{value} );
}

sub test_templateTopicFormSave {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            text         => ['Template Topic'],
            formtemplate => ['TestForm1'],
            'Select'     => ['Value_1'],
            'Textfield'  => ['Fred'],
            action       => ['save'],
            topic        => [ $this->{test_web} . '.TemplateTopic' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );

    my $xmeta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'TemplateTopic' );
    my $xtext = $xmeta->text;
    $query = new Unit::Request(
        {
            templatetopic => ['TemplateTopic'],
            action        => ['save'],
            topic         => [ $this->{test_web} . '.TemplateTopicAgain' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'TemplateTopicAgain' );
    my $text = $meta->text;
    $this->assert_matches( qr/Template Topic/, $text );
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );

    $this->assert_str_equals( 'Value_1',
        $meta->get( 'FIELD', 'Select' )->{value} );
    $this->assert_str_equals( 'Fred',
        $meta->get( 'FIELD', 'Textfield' )->{value} );
}

sub test_prevTopicFormSave {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            text         => ['Template Topic'],
            formtemplate => ['TestForm1'],
            'Select'     => ['Value_1'],
            'Textfield'  => ['Rubble'],
            action       => ['save'],
            topic        => [ $this->{test_web} . '.PrevTopicFormSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $query = new Unit::Request(
        {
            action      => ['save'],
            'Textfield' => ['Barney'],
            topic       => [ $this->{test_web} . '.PrevTopicFormSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'PrevTopicFormSave' );
    my $text = $meta->text;
    $this->assert_matches( qr/Template Topic/, $text );
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );
    $this->assert_str_equals( 'Value_1',
        $meta->get( 'FIELD', 'Select' )->{value} );
    $this->assert_str_equals( 'Barney',
        $meta->get( 'FIELD', 'Textfield' )->{value} );
}

sub test_simpleFormSave1 {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action               => ['save'],
            text                 => [$testtext_nometa],
            formtemplate         => ['TestForm1'],
            'Select'             => ['Value_2'],
            'Radio'              => ['3'],
            'Checkbox'           => ['red'],
            'CheckboxandButtons' => ['hamster'],
            'Textfield'          => ['Test'],
            topic                => [ $this->{test_web} . '.SimpleFormTopic' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, 'SimpleFormTopic' ) );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'SimpleFormTopic' );
    my $text = $meta->text;
    $this->assert_str_equals( 'TestForm1', $meta->get('FORM')->{name} );
    $this->assert_str_equals( 'Test',
        $meta->get( 'FIELD', 'Textfield' )->{value} );

}

# Field values that do not have a corresponding definition in form
# are deleted.
sub test_simpleFormSave2 {
    my $this = shift;
    $this->{session}->finish();
    $this->{session} = new Foswiki();

    my $oldmeta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'SimpleFormSave2' );
    my $oldtext = $testtext1;
    $oldmeta->setEmbeddedStoreForm($oldtext);
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'SimpleFormSave2', $testform1 );
    $meta->copyFrom($oldmeta);
    $meta->save( user => $this->{test_user_login} );

    my $query = new Unit::Request(
        {
            action               => ['save'],
            text                 => [$testtext_nometa],
            formtemplate         => ['TestForm3'],
            'Select'             => ['Value_2'],
            'Radio'              => ['3'],
            'Checkbox'           => ['red'],
            'CheckboxandButtons' => ['hamster'],
            'Textfield'          => ['Test'],
            topic                => [ $this->{test_web} . '.SimpleFormSave2' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, 'SimpleFormSave2' ) );
    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'SimpleFormSave2' );
    my $text = $meta->text;
    $this->assert_str_equals( 'TestForm3', $meta->get('FORM')->{name} );
    $this->assert_str_equals( 'Test',
        $meta->get( 'FIELD', 'Textfield' )->{value} );
    $this->assert_null( $meta->get( 'FIELD', 'CheckboxandButtons' ) );
}

# meta data (other than FORM, FIELD, TOPICPARENT, etc.) is preserved
# during saves.
sub test_simpleFormSave3 {
    my $this = shift;
    $this->{session}->finish();
    $this->{session} = new Foswiki();

    my $oldmeta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'SimpleFormSave3' );
    my $oldtext = $testtext1;
    $oldmeta->setEmbeddedStoreForm($oldtext);
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'SimpleFormSave3', $testform1 );
    $meta->copyFrom($oldmeta);
    $meta->save( user => $this->{test_user_login} );

    my $query = new Unit::Request(
        {
            action               => ['save'],
            text                 => [$testtext_nometa],
            formtemplate         => ['TestForm1'],
            'Select'             => ['Value_2'],
            'Radio'              => ['3'],
            'Checkbox'           => ['red'],
            'CheckboxandButtons' => ['hamster'],
            'Textfield'          => ['Test'],
            topic                => [ $this->{test_web} . '.SimpleFormSave3' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, 'SimpleFormSave3' ) );
    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'SimpleFormSave3' );
    my $text = $meta->text;
    $this->assert($meta);
    $this->assert_str_equals( 'UserTopic',
        $meta->get( 'PREFERENCE', 'VIEW_TEMPLATE' )->{value} );

}

# meta data (other than FORM, FIELD, TOPICPARENT, etc.) is inherited from
# templatetopic
sub test_templateTopicWithMeta {
    my $this = shift;

    Foswiki::Func::saveTopicText( $this->{test_web}, "TemplateTopic",
        $testtext1 );
    my $query = new Unit::Request(
        {
            templatetopic => ['TemplateTopic'],
            action        => ['save'],
            topic         => [ $this->{test_web} . '.TemplateTopicWithMeta' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'TemplateTopicWithMeta' );
    my $text = $meta->text;
    my $pref = $meta->get( 'PREFERENCE', 'VIEW_TEMPLATE' );
    $this->assert_not_null($pref);
    $this->assert_str_equals( 'UserTopic', $pref->{value} );
}

#Mergeing is only enabled if the topic text comes from =text= and =originalrev= is &gt; 0 and is not the same as the revision number of the most recent revision. If mergeing is enabled both the topic and the meta-data are merged.

sub test_merge {
    my $this = shift;
    $this->{session}->finish();
    $this->{session} = new Foswiki();

    # Set up the original topic that the two edits started on
    my $oldmeta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MergeSave' );
    my $oldtext = $testtext1;
    $oldmeta->setEmbeddedStoreForm($oldtext);
    $oldmeta->text($testform4);
    $oldmeta->save( user => $this->{test_user_2_login} );

    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'MergeSave' );
    my $text     = $meta->text;
    my $info     = $meta->getRevisionInfo();
    my $original = "$info->{version}_$info->{date}";

    #print STDERR "Starting at $original\n";

    # Now build a query for the save at the end of the first edit,
    # forcing a revision increment.
    my $query1 = new Unit::Request(
        {
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
            'Textarea'           => [ <<GUMP ],
Glug Glug
Blog Glog
Bungdit Din
Glaggie
GUMP
            topic => [ $this->{test_web} . '.MergeSave' ]
        }
    );

    # Do the save
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query1 );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    $info = $meta->getRevisionInfo();

    #print STDERR "First edit saved as $info->{version}_$info->{date}\n";

    # Build a second query for the other save, based on the same original
    # version as the previous edit
    my $query2 = new Unit::Request(
        {
            action               => ['save'],
            text                 => ["Wet rat"],
            originalrev          => $original,
            formtemplate         => ['TestForm4'],
            'Select'             => ['Value_2'],
            'Radio'              => ['3'],
            'Checkbox'           => ['red'],
            'CheckboxandButtons' => ['hamster'],
            'Textfield'          => ['Rat'],
            'Textarea'           => [ <<GUMP ],
Spletter Glug
Blog Splut
Bungdit Din
GUMP
            topic => [ $this->{test_web} . '.MergeSave' ]
        }
    );

    # Do the save. This time we expect a merge exception
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_2_login}, $query2 );
    try {
        $this->captureWithKey( save => $UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'merge_notice', $e->{def} );
    }
    otherwise {
        $this->assert( 0, shift );
    };

    # Get the merged topic and pick it apart
    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'MergeSave' );
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
    $this->assert_str_equals( <<ZIS, $v->{value} );
<del>Glug </del><ins>Spletter </ins>Glug
Blog <del>Glog
</del><ins>Splut
</ins>Bungdit Din
Glaggie
ZIS
}

# CC commented this test out, because it doesn't bear any relationship to any
# documented interaction mode for the save script :-/
#sub test_restoreRevision {
#    my $this = shift;
#
#    # first write topic without meta
#    my $query = new Unit::Request({
#        text => [ 'FIRST REVISION' ],
#        action => [ 'save' ],
#        topic => [ $this->{test_web}.'.DeleteTestRestoreRevisionTopic' ]
#       });
#    $this->{session}->finish();
#    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
#    $this->captureWithKey( save => &$UI_FN, $this->{session});
#
#    # retrieve revision number
#    my $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'DeleteTestRestoreRevisionTopic');
#    my $text = $meta->text;
#    my $info = $meta->getRevisionInfo();
#
#    my $original = "$info->{version}_$info->{date}";
#    $this->assert_equals(1, $info->{version});
#
#    # write second revision with meta
#    $query = new Unit::Request({
#                         action => [ 'save' ],
#			 text   => [ 'SECOND REVISION' ],
#			             originalrev => $original,
#                         forcenewrevision => 1,
#                         formtemplate => [ 'TestForm1' ],
#                         'Select' => [ 'Value_2' ],
#                         'Radio' => [ '3' ],
#                         'Checkbox' => [ 'red' ],
#                         'CheckboxandButtons' => [ 'hamster' ],
#                         'Textfield' => [ 'Test' ],
#			 topic  => [ $this->{test_web}.'.DeleteTestRestoreRevisionTopic' ]
#                        });
#    $this->{session}->finish();
#    $this->{session} = new Foswiki( $this->{test_user_login}, $query);
#    $this->captureWithKey( save => $UI_FN, $this->{session});
#
#    $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'DeleteTestRestoreRevisionTopic');
#    $text = $meta->text;
#    $info = $meta->getRevisionInfo();
#    $original = "$info->{version}_$info->{date}";
#    $this->assert_equals(2, $info->{version});
#
#    # now restore topic to revision 1
#    # the form should be removed as well
#    $query = new Unit::Request({
#        action => [ 'manage' ],
#        rev => 1,
#        forcenewrevision => 1,
#        topic => [ $this->{test_web}.'.DeleteTestRestoreRevisionTopic' ]
#       });
#    $this->{session}->finish();
#    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
#    $this->captureWithKey( save => $UI_FN, $this->{session});
#    $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'DeleteTestRestoreRevisionTopic');
#    $text = $meta->text;
#    $info = $meta->getRevisionInfo();
#    $original = "$info->{version}_$info->{date}";
#    $this->assert_equals(3, $info->{version});
#    $this->assert_matches(qr/FIRST REVISION/, $text);
#    $this->assert_null($meta->get('FORM'));
#
#    # and restore topic to revision 2
#    # the form should be re-appended
#    $query = new Unit::Request({
#        action => [ 'manage' ],
#        rev => 2,
#        forcenewrevision => 1,
#        topic => [ $this->{test_web}.'.DeleteTestRestoreRevisionTopic' ]
#       });
#    $this->{session}->finish();
#    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
#    $this->captureWithKey( save => $UI_FN, $this->{session});
#    $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'DeleteTestRestoreRevisionTopic');
#    $text = $meta->text;
#    $info = $meta->getRevisionInfo();
#    $original = "$info->{version}_$info->{date}";
#    $this->assert_equals(4, $info->{rev});
#    $this->assert_matches(qr/SECOND REVISION/, $text);
#    $this->assert_not_null($meta->get('FORM'));
#    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
#    # field default values should be all ''
#    $this->assert_str_equals('Test', $meta->get('FIELD', 'Textfield' )->{value});
#}

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

    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login} );

    my $oldmeta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MergeSave' );
    my $oldtext = $testtext1;
    my $query;
    $oldmeta->setEmbeddedStoreForm($oldtext);

    # First, user A saves to create rev 1
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MergeSave',
        "Smelly\ncat", $oldmeta );
    $meta->save();
    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'MergeSave' );
    my $text = $meta->text();
    my $info = $meta->getRevisionInfo();
    my ( $orgDate, $orgAuth, $orgRev ) =
      ( $info->{date}, $info->{author}, $info->{version} );

    $this->assert_equals( 1, $orgRev );
    $this->assert_str_equals( "Smelly\ncat", $text );

    my $original = "${orgRev}_$orgDate";
    sleep(1);    # tick the clock to ensure the date changes

    # A saves again, reprev triggers to create rev 1 again
    $query = new Unit::Request(
        {
            action      => ['save'],
            text        => ["Sweaty\ncat"],
            originalrev => $original,
            topic       => [ $this->{test_web} . '.MergeSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );

    # make sure it's still rev 1 as expected
    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'MergeSave' );
    $text = $meta->text();
    $info = $meta->getRevisionInfo();
    my ( $repRevDate, $repRevAuth, $repRevRev ) =
      ( $info->{date}, $info->{author}, $info->{version} );
    $this->assert_equals( 1, $repRevRev );
    $this->assert_str_equals( "Sweaty\ncat\n", $text );
    $this->assert( $repRevDate != $orgDate );

    # User B saves; make sure we get a merge notice.
    $query = new Unit::Request(
        {
            action      => ['save'],
            text        => ["Smelly\nrat"],
            originalrev => $original,
            topic       => [ $this->{test_web} . '.MergeSave' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_2_login}, $query );
    try {
        $this->captureWithKey( save => $UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'merge_notice', $e->{def} );
    }
    otherwise {
        $this->assert( 0, shift );
    };

    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'MergeSave' );
    $text = $meta->text();

    $info = $meta->getRevisionInfo();
    my ( $mergeDate, $mergeAuth, $mergeRev ) =
      ( $info->{date}, $info->{author}, $info->{version} );
    $this->assert_equals( 2, $mergeRev );
    $this->assert_str_equals(
"<del>Sweaty\n</del><ins>Smelly\n</ins><del>cat\n</del><ins>rat\n</ins>",
        $text
    );
}

sub test_missingTemplateTopic {
    my $this = shift;
    $this->{session}->finish();
    my $query = new Unit::Request(
        {
            templatetopic => ['NonExistantTemplateTopic'],
            action        => ['save'],
            topic         => [ $this->{test_web} . '.FlibbleDeDib' ]
        }
    );
    $query->method('post');
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    try {
        $this->captureWithKey( save => $UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'no_such_topic_template', $e->{def} );
    }
    otherwise {
        $this->assert( 0, shift );
    };
}

sub test_addform {
    my $this = shift;
    $this->{session}->finish();
    my $query = new Unit::Request(
        {
            action => ['addform'],
            topic  => ["$this->{test_web}.$this->{test_topic}"],
        }
    );
    $query->method('POST');
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    try {
        my ($text) =
          $this->captureWithKey( save => $UI_FN, $this->{session} );
        $this->assert_matches( qr/input value="TestForm1" name="formtemplate"/,
            $text );
        $this->assert_matches( qr/value="TestForm2" name="formtemplate"/,
            $text );
        $this->assert_matches( qr/value="TestForm3" name="formtemplate"/,
            $text );
        $this->assert_matches( qr/value="TestForm4" name="formtemplate"/,
            $text );
    }
    catch Error::Simple with {
        $this->assert( 0, shift );
    };
}

sub test_get {
    my $this = shift;

    $this->{session}->finish();
    my $query = new Unit::Request(
        {
            action => ['save'],
            topic  => ["$this->{test_web}.$this->{test_topic}"]
        }
    );
    $query->method('GET');
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );

    try {
        my ($text) =
          $this->captureWithKey( save => $UI_FN, $this->{session} );
        $this->assert_matches( qr/^Status: 403.*$/m, $text );
    }
    catch Error::Simple with {};
}

1;
