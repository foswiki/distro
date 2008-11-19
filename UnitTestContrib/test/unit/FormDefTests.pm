# Copyright (C) 2006 WikiRing http://wikiring.com
# Tests for form def parser
package FormDefTests;

use base qw(FoswikiFnTestCase);

use Foswiki;
use Foswiki::Form;
use strict;
use Assert;
use Error qw( :try );

sub test_minimalForm {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'TestForm', <<FORM);
| *Name* | *Type* | *Size* |
| Date | date | 30 |
FORM
    my $def = Foswiki::Form->new($this->{twiki}, $this->{test_web}, 'TestForm');

    $this->assert_equals(1, scalar @{$def->getFields()});
    my $f = $def->getField('Date');
    $this->assert_str_equals('date', $f->{type});
    $this->assert_str_equals('Date', $f->{name});
    $this->assert_str_equals('Date', $f->{title});
    $this->assert_str_equals('30', $f->{size});
    $this->assert_str_equals('', $f->{value});
    $this->assert_str_equals('', $f->{tooltip});
    $this->assert_str_equals('', $f->{attributes});
    $this->assert_str_equals('', $f->{definingTopic});
}

sub test_allCols {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'TestForm', <<FORM);
| *Name*     | *Type*   | *Size* | *Value* | *Tooltip* | *Attributes* |
| Select     | select   | 2..4   | a,b,c   | Tippity   | M            |
| Checky Egg | checkbox | 1      | 1,2,3,4   | Blip      |              |
FORM
    my $def = new Foswiki::Form($this->{twiki}, $this->{test_web}, 'TestForm');

    $this->assert_equals(2, scalar @{$def->getFields()});
    my $f = $def->getField('Select');
    $this->assert_str_equals('select', $f->{type});
    $this->assert_str_equals('Select', $f->{name});
    $this->assert_str_equals('Select', $f->{title});
    $this->assert_equals(2, $f->{minSize});
    $this->assert_equals(4, $f->{maxSize});
    $this->assert_equals(3, scalar(@{$f->getOptions()}));
    $this->assert_str_equals('a,b,c', join(',',@{$f->getOptions()}));
    $this->assert_str_equals('Tippity', $f->{tooltip});
    $this->assert_str_equals('M', $f->{attributes});
    $this->assert_str_equals('', $f->{definingTopic});
    $f = $def->getField('CheckyEgg');
    $this->assert_str_equals('checkbox', $f->{type});
    $this->assert_str_equals('CheckyEgg', $f->{name});
    $this->assert_str_equals('Checky Egg', $f->{title});
    $this->assert_equals(1, $f->{size});
    $this->assert_str_equals('1;2;3;4', join(';',@{$f->getOptions()}));
    $this->assert_str_equals('Blip', $f->{tooltip});
    $this->assert_str_equals('', $f->{attributes});
    $this->assert_str_equals('', $f->{definingTopic});
}

sub test_valsFromOtherTopic {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'TestForm', <<FORM);
| *Name*         | *Type* | *Size* | *Value*   |
| Vals Elsewhere | select |        |           |
FORM
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'ValsElsewhere', <<FORM);
| *Name* |
| ValOne |
| RowName |
| Age |
FORM
    my $def = new Foswiki::Form($this->{twiki}, $this->{test_web}, 'TestForm');

    $this->assert_equals(1, scalar @{$def->getFields()});
    my $f = $def->getField('ValsElsewhere');
    $this->assert_str_equals('select', $f->{type});
    $this->assert_str_equals('ValsElsewhere', $f->{name});
    $this->assert_str_equals('Vals Elsewhere', $f->{title});
    $this->assert_equals(1, $f->{minSize});
    $this->assert_equals(1, $f->{maxSize});
    $this->assert_equals(3, scalar(@{$f->getOptions()}));
    $this->assert_str_equals('ValOne,RowName,Age', join(',', @{$f->getOptions()}));
    $this->assert_str_equals('', $f->{definingTopic});
}

sub test_squabValRef {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'TestForm', <<FORM);
| *Name*         | *Type* | *Size* | *Value*   |
| [[$this->{test_web}.Splodge][Vals Elsewhere]] | select |        |           |
FORM
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'Splodge', <<FORM);
| *Name* |
| ValOne |
| RowName |
| Age |
FORM
    my $def = new Foswiki::Form($this->{twiki}, $this->{test_web}, 'TestForm');

    $this->assert_equals(1, scalar @{$def->getFields()});
    my $f = $def->getField('ValsElsewhere');
    $this->assert_str_equals('select', $f->{type});
    $this->assert_str_equals('ValsElsewhere', $f->{name});
    $this->assert_str_equals('Vals Elsewhere', $f->{title});
    $this->assert_str_equals('ValOne,RowName,Age',
                             join(',', @{$f->getOptions()}));
    $this->assert_str_equals($this->{test_web}.'.Splodge', $f->{definingTopic});
}

sub test_searchForOptions {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'TestForm', <<'FORM');
| *Name*         | *Type* | *Size* | *Value*   |
| Ecks | select | 1 | %SEARCH{"^\\| (Age\|Beauty)" type="regex" nonoise="on" separator="," format="$topic"}% |
FORM
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'SplodgeOne', <<FORM);
| Age |
FORM
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'SplodgeTwo', <<FORM);
| Beauty |
FORM
    my $def = new Foswiki::Form($this->{twiki}, $this->{test_web}, 'TestForm');

    $this->assert_equals(1, scalar @{$def->getFields()});
    my $f = $def->getField('Ecks');
    $this->assert_str_equals(
        'SplodgeOne,SplodgeTwo',
        join(',', sort @{$f->getOptions()}));
}

sub test_Item6082 {
    my $this = shift;
    # Form definition that requires the form definition to be loaded before
    # it can be loaded.
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'TestForm', <<'FORM');
| *Name*         | *Type* | *Size* | *Value*   | *Tooltip message* | *Attributes* |
| Why | text | 32 | | Mandatory field | M |
| Ecks | select | 1 | %SEARCH{"TestForm.Ecks~'Blah*'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}% | | |
FORM
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'SplodgeOne', <<FORM);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Ecks" attributes="" title="X" value="Blah"}%
FORM

    my $def = new Foswiki::Form($this->{twiki}, $this->{test_web}, 'TestForm');

    my $f = $def->getField('Ecks');
    $this->assert_str_equals(
        'SplodgeOne;Blah',
        join(',', sort @{$f->getOptions()}));

    my ($meta, $text) =
      $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, 'TestForm');
    $meta->renderFormForDisplay();
}

sub test_makeFromMeta {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'SplodgeOne', <<FORM);
%META:FORM{name="NonExistantForm"}%
%META:FIELD{name="Ecks" attributes="" title="X" value="Blah"}%
FORM
    my ($meta, $text) =
      $this->{twiki}->{store}->readTopic(
          undef, $this->{test_web}, 'SplodgeOne');
    my $form = new Foswiki::Form(
        $this->{twiki}, $this->{test_web}, 'NonExistantForm', $meta);
    my $f = $form->getField('Ecks');
    $this->assert_str_equals('', $f->getDefaultValue());
    $this->assert_str_equals('Ecks', $f->{name});
    $this->assert_str_equals('X', $f->{title});
    $this->assert_str_equals('', $f->{size});
}

1;
