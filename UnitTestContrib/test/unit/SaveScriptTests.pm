use strict;

package SaveScriptTests;
use base qw(TWikiFnTestCase);

use strict;
use TWiki;
use TWiki::UI::Save;
use Error qw( :try );

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
%META:TOPICINFO{author="ProjectContributor" date="1111931141" format="1.0" version="$Rev: 4579 $"}%

A guest of this TWiki web, not unlike yourself. You can leave your trace behind you, just add your name in %SYSTEMWEB%.UserRegistration and create your own page.

%META:FORM{name="TestForm1"}%
%META:FIELD{name="Select" attributes="" title="Select" value="Value_2"}%
%META:FIELD{name="Radio" attributes="" title="Radio" value="3"}%
%META:FIELD{name="Checkbox" attributes="" title="Checkbox" value="red"}%
%META:FIELD{name="Textfield" attributes="" title="Textfield" value="Test"}%
%META:FIELD{name="CheckboxandButtons" attributes="" title="CheckboxandButtons" value=""}%
%META:PREFERENCE{name="VIEW_TEMPLATE" title="VIEW_TEMPLATE" value="UserTopic"}%
HERE

my $testtext_nometa = <<'HERE';

A guest of this TWiki web, not unlike yourself. You can leave your trace behind you, just add your name in %SYSTEMWEB%.UserRegistration and create your own page.

HERE

sub new {
    my $self = shift()->SUPER::new('Save', @_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $this->{test_user_2_forename} = 'Buck';
    $this->{test_user_2_surname} = 'Rogers';
    $this->{test_user_2_wikiname} =
      $this->{test_user_forename}.$this->{test_user_surname};
    $this->{test_user_2_login} = 'buck';
    $this->{test_user_2_email} = 'rogers@example.com';
    $this->registerUser($this->{test_user_2_login},
                        $this->{test_user_2_forename},
                        $this->{test_user_2_surname},
                        $this->{test_user_2_email});

	$this->{twiki}->{store}->saveTopic(
        $this->{test_user_login}, $this->{test_web}, 'TestForm1',
        $testform1, undef );

	$this->{twiki}->{store}->saveTopic(
        $this->{test_user_2_login}, $this->{test_web}, 'TestForm2',
        $testform2, undef );

	$this->{twiki}->{store}->saveTopic(
        $this->{test_user_login}, $this->{test_web}, 'TestForm3',
        $testform3, undef );

	$this->{twiki}->{store}->saveTopic(
        $this->{test_user_login}, $this->{test_web}, 'TestForm4',
        $testform4, undef );

	$this->{twiki}->{store}->saveTopic(
        $this->{test_user_2_login}, $this->{test_web},
        $TWiki::cfg{WebPrefsTopicName}, <<CONTENT);
   * Set WEBFORMS = TestForm1,TestForm2,TestForm3,TestForm4
CONTENT

    $TWiki::Plugins::SESSION = $this->{twiki};
}

# AUTOINC
sub test_AUTOINC {
    my $this = shift;
    my $query = new Unit::Request({
        action => [ 'save' ],
        text => [ 'nowt' ],
    });
    $query->path_info( '/' . $this->{test_web}.'.TestAutoAUTOINC00' );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    my %old;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        $old{$t} = 1;
    }
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my $seen = 0;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        if($t eq 'TestAuto00') {
            $seen = 1;
        } elsif( !$old{$t}) {
            $this->assert(0, "Unexpected topic $t");
        }
    }
    $this->assert($seen);
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $seen = 0;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        if($t =~ /^TestAuto0[01]$/) {
            $seen++;
        } elsif( !$old{$t}) {
            $this->assert(0, "Unexpected topic $t");
        }
    }
    $this->assert_equals(2,$seen);
}


# 10X
sub test_XXXXXXXXXX {
    my $this = shift;
    my $query = new Unit::Request({
        action => [ 'save' ],
        text => [ 'nowt' ],
    });
    $query->path_info( '/' . $this->{test_web}.'.TestTopicXXXXXXXXXX' );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    my %old;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        $old{$t} = 1;
    }
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my $seen = 0;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        if($t eq 'TestTopic0') {
            $seen = 1;
        } elsif( !$old{$t}) {
            $this->assert(0, "Unexpected topic $t");
        }
    }
    $this->assert($seen);
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $seen = 0;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        if($t =~ /^TestTopic[01]$/) {
            $seen++;
        } elsif( !$old{$t}) {
            $this->assert(0, "Unexpected topic $t");
        }
    }
    $this->assert_equals(2,$seen);
}

# 9X
sub test_XXXXXXXXX {
    my $this = shift;
    my $query = new Unit::Request({
        action => [ 'save' ],
        text => [ 'nowt' ],
    });
    $query->path_info("/$this->{test_web}/TestTopicXXXXXXXXX");
    $this->assert(
        !$this->{twiki}->{store}->topicExists($this->{test_web},'TestTopic0'));
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    my %old;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        $old{$t} = 1;
    }
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $this->assert(!$this->{twiki}->{store}->topicExists($this->{test_web},'TestTopic0'));
    my $seen = 0;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        if($t eq 'TestTopicXXXXXXXXX') {
            $seen = 1;
        } elsif( !$old{$t}) {
            $this->assert(0, "Unexpected topic $t");
        }
    }
    $this->assert($seen);
}

#11X
sub test_XXXXXXXXXXX {
    my $this = shift;
    my $query = new Unit::Request({
        action => [ 'save' ],
        text => [ 'nowt' ],
    });
    $query->path_info("/$this->{test_web}/TestTopicXXXXXXXXXXX");
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    my %old;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        $old{$t} = 1;
    }
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my $seen = 0;
    foreach my $t ($this->{twiki}->{store}->getTopicNames( $this->{test_web})) {
        if($t eq 'TestTopic0') {
            $seen = 1;
        } elsif( !$old{$t}) {
            $this->assert(0, "Unexpected topic $t");
        }
    }
    $this->assert($seen);
}

sub test_emptySave {
    my $this = shift;
    my $query = new Unit::Request({
        action => [ 'save' ],
        topic => [ $this->{test_web}.'.EmptyTestSaveScriptTopic' ]
       });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web},
                                                  'EmptyTestSaveScriptTopic');
    $this->assert_matches(qr/^\s*$/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub test_simpleTextSave {
    my $this = shift;
    my $query = new Unit::Request({
        text => [ 'CORRECT' ],
        action => [ 'save' ],
        topic => [ $this->{test_web}.'.DeleteTestSaveScriptTopic' ]
       });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web},
                                                 'DeleteTestSaveScriptTopic');
    $this->assert_matches(qr/CORRECT/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub test_templateTopicTextSave {
    my $this = shift;
    my $query = new Unit::Request({
        text => [ 'Template Topic' ],
        action => [ 'save' ],
        topic => [ $this->{test_web}.'.TemplateTopic' ]
       });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $query = new Unit::Request({
        templatetopic => [ 'TemplateTopic' ],
        action => [ 'save' ],
        topic => [ $this->{test_web}.'.TemplateTopic' ]
       });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'TemplateTopic');
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_null($meta->get('FORM'));
}

# Save over existing topic
sub test_prevTopicTextSave {
    my $this = shift;
    my $query = new Unit::Request({
                         text => [ 'WRONG' ],
                         action => [ 'save' ],
                         topic => [ $this->{test_web}.'.PrevTopicTextSave' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $query = new Unit::Request({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                         topic => [ $this->{test_web}.'.PrevTopicTextSave' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'PrevTopicTextSave');
    $this->assert_matches(qr/CORRECT/, $text);
    $this->assert_null($meta->get('FORM'));
}

# Save over existing topic with no text
sub test_prevTopicEmptyTextSave {
    my $this = shift;
    my $query = new Unit::Request({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                         topic => [ $this->{test_web}.'.PrevTopicEmptyTextSave' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $query = new Unit::Request({
                         action => [ 'save' ],
                         topic => [ $this->{test_web}.'.PrevTopicEmptyTextSave' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'PrevTopicEmptyTextSave');
    $this->assert_matches(qr/^\s*CORRECT\s*$/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub test_simpleFormSave {
    my $this = shift;
    my $query = new Unit::Request({
                         text => [ 'CORRECT' ],
                         formtemplate => [ 'TestForm1' ],
                         action => [ 'save' ],
                         'Textfield' =>
                         [ 'Flintstone' ],
                         topic => [ $this->{test_web}.'.SimpleFormSave' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $this->assert($this->{twiki}->{store}->topicExists($this->{test_web}, 'SimpleFormSave'));
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'SimpleFormSave');
    $this->assert_matches(qr/^CORRECT\s*$/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    # field default values should be all ''
    $this->assert_str_equals('Flintstone', $meta->get('FIELD', 'Textfield' )->{value});
}

sub test_templateTopicFormSave {
    my $this = shift;
    my $query = new Unit::Request({
                         text => [ 'Template Topic' ],
                         formtemplate => [ 'TestForm1' ],
                         'Select' =>
                         [ 'Value_1' ],
                         'Textfield' =>
                         [ 'Fred' ],
                         action => [ 'save' ],
                         topic => [ $this->{test_web}.'.TemplateTopic' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});

    my($xmeta, $xtext) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'TemplateTopic');
    $query = new Unit::Request({
                         templatetopic => [ 'TemplateTopic' ],
                         action => [ 'save' ],
                         topic => [ $this->{test_web}.'.TemplateTopicAgain' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web},
                                                  'TemplateTopicAgain');
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});

    $this->assert_str_equals('Value_1', $meta->get('FIELD', 'Select' )->{value});
    $this->assert_str_equals('Fred', $meta->get('FIELD', 'Textfield' )->{value});
}

sub test_prevTopicFormSave {
    my $this = shift;
    my $query = new Unit::Request({
                         text => [ 'Template Topic' ],
                         formtemplate => [ 'TestForm1' ],
                         'Select' =>
                         [ 'Value_1' ],
                         'Textfield' =>
                         [ 'Rubble' ],
                         action => [ 'save' ],
                         topic => [ $this->{test_web}.'.PrevTopicFormSave' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $query = new Unit::Request({
                      action => [ 'save' ],
                      'Textfield' =>
                      [ 'Barney' ],
                      topic => [ $this->{test_web}.'.PrevTopicFormSave' ]
                     });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'PrevTopicFormSave');
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    $this->assert_str_equals('Value_1', $meta->get('FIELD','Select')->{value});
    $this->assert_str_equals('Barney', $meta->get('FIELD','Textfield')->{value});
}

sub test_simpleFormSave1 {
    my $this = shift;
    my $query = new Unit::Request({
                         action => [ 'save' ],
			 text   => [ $testtext_nometa ],
                         formtemplate => [ 'TestForm1' ],
                         'Select' => [ 'Value_2' ],
                         'Radio' => [ '3' ],
                         'Checkbox' => [ 'red' ],
                         'CheckboxandButtons' => [ 'hamster' ],
                         'Textfield' => [ 'Test' ],
			 topic  => [ $this->{test_web}.'.SimpleFormTopic' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $this->assert($this->{twiki}->{store}->topicExists($this->{test_web}, 'SimpleFormTopic'));
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'SimpleFormTopic');
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    $this->assert_str_equals('Test', $meta->get('FIELD', 'Textfield' )->{value});

}

# Field values that do not have a corresponding definition in form
# are deleted.
sub test_simpleFormSave2 {
    my $this = shift;
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();

    my $oldmeta = new TWiki::Meta( $this->{twiki}, $this->{test_web}, 'SimpleFormSave2');
    my $oldtext = $testtext1;
    $this->{twiki}->{store}->extractMetaData( $oldmeta, $oldtext );
    $this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $this->{test_web}, 'SimpleFormSave2',
                                $testform1, $oldmeta );
    my $query = new Unit::Request({
                         action => [ 'save' ],
			 text   => [ $testtext_nometa ],
                         formtemplate => [ 'TestForm3' ],
                         'Select' => [ 'Value_2' ],
                         'Radio' => [ '3' ],
                         'Checkbox' => [ 'red' ],
                         'CheckboxandButtons' => [ 'hamster' ],
                         'Textfield' => [ 'Test' ],
			 topic  => [ $this->{test_web}.'.SimpleFormSave2' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $this->assert($this->{twiki}->{store}->topicExists($this->{test_web}, 'SimpleFormSave2'));
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'SimpleFormSave2');
    $this->assert_str_equals('TestForm3', $meta->get('FORM')->{name});
    $this->assert_str_equals('Test', $meta->get('FIELD', 'Textfield' )->{value});
    $this->assert_null($meta->get('FIELD', 'CheckboxandButtons' ));
}

# meta data (other than FORM, FIELD, TOPICPARENT, etc.) is preserved
# during saves.
sub test_simpleFormSave3 {
    my $this = shift;
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();

    my $oldmeta = new TWiki::Meta(
        $this->{twiki}, $this->{test_web}, 'SimpleFormSave3');
    my $oldtext = $testtext1;
    $this->{twiki}->{store}->extractMetaData( $oldmeta, $oldtext );
    $this->{twiki}->{store}->saveTopic(
        $this->{test_user_login}, $this->{test_web}, 'SimpleFormSave3',
        $testform1, $oldmeta );
    my $query = new Unit::Request(
        {
            action => [ 'save' ],
            text   => [ $testtext_nometa ],
            formtemplate => [ 'TestForm1' ],
            'Select' => [ 'Value_2' ],
            'Radio' => [ '3' ],
            'Checkbox' => [ 'red' ],
            'CheckboxandButtons' => [ 'hamster' ],
            'Textfield' => [ 'Test' ],
            topic  => [ $this->{test_web}.'.SimpleFormSave3' ]
           });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    $this->assert($this->{twiki}->{store}->topicExists($this->{test_web}, 'SimpleFormSave3'));
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'SimpleFormSave3');
    $this->assert($meta);
    $this->assert_str_equals('UserTopic', $meta->get('PREFERENCE', 'VIEW_TEMPLATE' )->{value});

}

# meta data (other than FORM, FIELD, TOPICPARENT, etc.) is inherited from
# templatetopic
sub test_templateTopicWithMeta {
    my $this = shift;

    TWiki::Func::saveTopicText($this->{test_web},"TemplateTopic",$testtext1);
    my $query = new Unit::Request(
        {
            templatetopic => [ 'TemplateTopic' ],
            action => [ 'save' ],
            topic => [ $this->{test_web}.'.TemplateTopicWithMeta' ]
           });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki} );
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'TemplateTopicWithMeta');
    my $pref = $meta->get( 'PREFERENCE', 'VIEW_TEMPLATE' );
    $this->assert_not_null($pref);
    $this->assert_str_equals('UserTopic', $pref->{value});
}

#Mergeing is only enabled if the topic text comes from =text= and =originalrev= is &gt; 0 and is not the same as the revision number of the most recent revision. If mergeing is enabled both the topic and the meta-data are merged.

sub test_merge {
    my $this = shift;
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();

    # Set up the original topic that the two edits started on
    my $oldmeta = new TWiki::Meta(
        $this->{twiki}, $this->{test_web}, 'MergeSave');
    my $oldtext = $testtext1;
    $this->{twiki}->{store}->extractMetaData( $oldmeta, $oldtext );
    $this->{twiki}->{store}->saveTopic( $this->{test_user_2_login},
                                $this->{test_web}, 'MergeSave',
                                $testform4, $oldmeta );
    my($meta, $text) = $this->{twiki}->{store}->readTopic(
        undef, $this->{test_web}, 'MergeSave');
    my( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    my $original = "${orgRev}_$orgDate";

    #print STDERR "Starting at $original\n";

    # Now build a query for the save at the end of the first edit,
    # forcing a revision increment.
    my $query1 = new Unit::Request(
        {
            action => [ 'save' ],
            text   => [ "Soggy bat" ],
            originalrev => $original,
            forcenewrevision => 1,
            formtemplate => [ 'TestForm4' ],
            'Select' => [ 'Value_2' ],
            'Radio' => [ '3' ],
            'Checkbox' => [ 'red' ],
            'CheckboxandButtons' => [ 'hamster' ],
            'Textfield' => [ 'Bat' ],
            'Textarea' => [ <<GUMP ],
Glug Glug
Blog Glog
Bungdit Din
Glaggie
GUMP
            topic  => [ $this->{test_web}.'.MergeSave' ]
           });
    # Do the save
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query1);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    my( $r1Date, $r1Auth, $r1Rev ) = $meta->getRevisionInfo();

    #print STDERR "First edit saved as ${r1Rev}_$r1Date\n";

    # Build a second query for the other save, based on the same original
    # version as the previous edit
    my $query2 = new Unit::Request(
        {
            action => [ 'save' ],
            text   => [ "Wet rat" ],
            originalrev => $original,
            formtemplate => [ 'TestForm4' ],
            'Select' => [ 'Value_2' ],
            'Radio' => [ '3' ],
            'Checkbox' => [ 'red' ],
            'CheckboxandButtons' => [ 'hamster' ],
            'Textfield' => [ 'Rat' ],
            'Textarea' => [ <<GUMP ],
Spletter Glug
Blog Splut
Bungdit Din
GUMP
            topic  => [ $this->{test_web}.'.MergeSave' ]
           });
    # Do the save. This time we expect a merge exception
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_2_login}, $query2);
    try {
        $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals('merge_notice', $e->{def});
    } otherwise {
        $this->assert(0, shift);
    };

    # Get the merged topic and pick it apart
    ($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web},
                                                  'MergeSave');
    my $e = <<'END';
<div class="twikiConflict"><b>CONFLICT</b> original 1:</div>
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |
<div class="twikiConflict"><b>CONFLICT</b> version 2:</div>
Soggy bat
<div class="twikiConflict"><b>CONFLICT</b> version new:</div>
Wet rat
<div class="twikiConflict"><b>CONFLICT</b> end</div>
END
    $this->assert_str_equals($e, $text);

    my $v = $meta->get('FIELD', 'Select');
    $this->assert_str_equals('Value_2', $v->{value});
    $v = $meta->get('FIELD', 'Radio');
    $this->assert_str_equals('3', $v->{value});
    $v = $meta->get('FIELD', 'Checkbox');
    $this->assert_str_equals('red', $v->{value});
    $v = $meta->get('FIELD', 'CheckboxandButtons');
    $this->assert_str_equals('hamster', $v->{value});
    $v = $meta->get('FIELD', 'Textfield');
    $this->assert_str_equals('<del>Bat</del><ins>Rat</ins>', $v->{value});
    $v = $meta->get('FIELD', 'Textarea');
    $this->assert_str_equals(<<ZIS, $v->{value});
<del>Glug </del><ins>Spletter </ins>Glug
Blog <del>Glog
</del><ins>Splut
</ins>Bungdit Din
Glaggie
ZIS
}

sub test_restoreRevision {
    my $this = shift;
    
    # first write topic without meta
    my $query = new Unit::Request({
        text => [ 'FIRST REVISION' ],
        action => [ 'save' ],
        topic => [ $this->{test_web}.'.DeleteTestRestoreRevisionTopic' ]
       });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    
    # retrieve revision number
    my($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'DeleteTestRestoreRevisionTopic');
    my( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    my $original = "${orgRev}_$orgDate";
    $this->assert_equals(1, $orgRev);
        
    # write second revision with meta
    $query = new Unit::Request({
                         action => [ 'save' ],
			 text   => [ 'SECOND REVISION' ],
			             originalrev => $original,
                         forcenewrevision => 1,
                         formtemplate => [ 'TestForm1' ],
                         'Select' => [ 'Value_2' ],
                         'Radio' => [ '3' ],
                         'Checkbox' => [ 'red' ],
                         'CheckboxandButtons' => [ 'hamster' ],
                         'Textfield' => [ 'Test' ],
			 topic  => [ $this->{test_web}.'.DeleteTestRestoreRevisionTopic' ]
                        });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});

    ($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'DeleteTestRestoreRevisionTopic');
    ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    $original = "${orgRev}_$orgDate";
    $this->assert_equals(2, $orgRev);

    # now restore topic to revision 1
    # the form should be removed as well
    $query = new Unit::Request({
        action => [ 'manage' ],
        rev => 1,
        forcenewrevision => 1,
        topic => [ $this->{test_web}.'.DeleteTestRestoreRevisionTopic' ]
       });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    ($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'DeleteTestRestoreRevisionTopic');
    ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    $original = "${orgRev}_$orgDate";
    $this->assert_equals(3, $orgRev);
    $this->assert_matches(qr/FIRST REVISION/, $text);
    $this->assert_null($meta->get('FORM'));
    
    # and restore topic to revision 2
    # the form should be re-appended
    $query = new Unit::Request({
        action => [ 'manage' ],
        rev => 2,
        forcenewrevision => 1,
        topic => [ $this->{test_web}.'.DeleteTestRestoreRevisionTopic' ]
       });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    ($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'DeleteTestRestoreRevisionTopic');
    ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    $original = "${orgRev}_$orgDate";
    $this->assert_equals(4, $orgRev);
    $this->assert_matches(qr/SECOND REVISION/, $text);
    $this->assert_not_null($meta->get('FORM'));
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    # field default values should be all ''
    $this->assert_str_equals('Test', $meta->get('FIELD', 'Textfield' )->{value});
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
    $TWiki::cfg{ReplaceIfEditedAgainWithin} = 7200;

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki($this->{test_user_login});

    my $oldmeta = new TWiki::Meta(
        $this->{twiki}, $this->{test_web}, 'MergeSave');
    my $oldtext = $testtext1;
    my $query;
    $this->{twiki}->{store}->extractMetaData( $oldmeta, $oldtext );

    # First, user A saves to create rev 1
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MergeSave',
                                "Smelly\ncat", $oldmeta );
    my($meta, $text) = $this->{twiki}->{store}->readTopic(
        undef, $this->{test_web}, 'MergeSave');
    my( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();

    $this->assert_equals(1, $orgRev);
    $this->assert_str_equals("Smelly\ncat", $text);

    my $original = "${orgRev}_$orgDate";
    sleep(1); # tick the clock to ensure the date changes

    # A saves again, reprev triggers to create rev 1 again
    $query = new Unit::Request(
        {
            action => [ 'save' ],
            text   => [ "Sweaty\ncat" ],
            originalrev => $original,
            topic  => [ $this->{test_web}.'.MergeSave' ]
           });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query);
    $this->capture( \&TWiki::UI::Save::save, $this->{twiki});

    # make sure it's still rev 1 as expected
    ($meta, $text) = $this->{twiki}->{store}->readTopic(
        undef, $this->{test_web}, 'MergeSave');
    ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    $this->assert_equals(1, $orgRev);
    $this->assert_str_equals("Sweaty\ncat\n", $text);

    # User B saves; make sure we get a merge notice.
    $query = new Unit::Request(
        {
            action => [ 'save' ],
            text   => [ "Smelly\nrat" ],
            originalrev => $original,
            topic  => [ $this->{test_web}.'.MergeSave' ]
           });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_2_login}, $query);
    try {
        $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals('merge_notice', $e->{def});
    } otherwise {
        $this->assert(0, shift);
    };

    ($meta, $text) = $this->{twiki}->{store}->readTopic(undef, $this->{test_web},
                                                'MergeSave');
    ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    $this->assert_equals(2, $orgRev);
    $this->assert_str_equals("<del>Sweaty\n</del><ins>Smelly\n</ins><del>cat\n</del><ins>rat\n</ins>", $text);
}

sub test_missingTemplateTopic {
    my $this = shift;
    $this->{twiki}->finish();
    my $query = new Unit::Request({
        templatetopic => [ 'NonExistantTemplateTopic' ],
        action => [ 'save' ],
        topic => [ $this->{test_web}.'.FlibbleDeDib' ]
       });
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    try {
        $this->capture( \&TWiki::UI::Save::save, $this->{twiki});
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals('no_such_topic_template', $e->{def});
    } otherwise {
        $this->assert(0, shift);
    };
}

1;
