# tests for the correct expansion of FORMFIELD

package Fn_FORMFIELD;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'FORMFIELD', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm',
        <<FORM);
| *Name*    | *Type* | *Size* |
| Marjorie  | text   | 30     |
| Priscilla | text   | 30     |
| Daphne | text   | 30     |
FORM
    $topicObject->save();

    $topicObject = $this->{test_topicObject};
    $topicObject->put( 'FORM', { name => 'TestForm' } );
    $topicObject->putKeyed( 'FIELD',
        { name => "Marjorie", title => "Number", value => "99" } );
    $topicObject->putKeyed( 'FIELD',
        { name => "Priscilla", title => "String", value => "" } );
    $topicObject->putKeyed( 'FIELD',
        { name => "Daphne", title => "String", value => "<nop>ElleBelle" } );
    $topicObject->save();
}

sub test_FORMFIELD_simple {
    my $this = shift;

    my $topicObject = $this->{test_topicObject};
    my $result = $topicObject->expandMacros(
        "%FORMFIELD%");
    $this->assert_str_equals('', $result);
}

sub test_FORMFIELD_byname {
    my $this = shift;

    my $topicObject = $this->{test_topicObject};
    my $result = $topicObject->expandMacros(
        '%FORMFIELD{"Marjorie"}%');
    $this->assert_str_equals('99', $result);
}

# default="..." Text shown when no value is defined for the field
sub test_FORMFIELD_default {
    my $this = shift;

    my $topicObject = $this->{test_topicObject};
    my $result = $topicObject->expandMacros(
        '%FORMFIELD{"Priscilla"}%');
    $this->assert_str_equals('', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Priscilla" default="Clementina" alttext="Cressida"}%');
    $this->assert_str_equals('Clementina', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Priscilla" default="Clementina"}%');
    $this->assert_str_equals('Clementina', $result);

}

# alttext="..." Text shown when field is not found in the form
sub test_FORMFIELD_alttext {
    my $this = shift;

    my $topicObject = $this->{test_topicObject};
    my $result = $topicObject->expandMacros(
        '%FORMFIELD{"Ffiona"}%');
    $this->assert_str_equals('', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Ffiona" alttext="Candida"}%');
    $this->assert_str_equals('Candida', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Ffiona" alttext="Candida" default="Cressida"}%');
    $this->assert_str_equals('Candida', $result);
}

# format="..." Format string. =$value= expands to the field value, and =$name= expands to the field name, =$title= to the field title, =$form= to the name of the form the field is in. The [[FormatTokens][standard format tokens]] are also expanded.
sub test_FORMFIELD_format {
    my $this = shift;

    my $topicObject = $this->{test_topicObject};
    my $result = $topicObject->expandMacros(
        '%FORMFIELD{"Marjorie" format="$name/$dollar$value/$title/$form"}%');
    $this->assert_str_equals('Marjorie/$99/Number/TestForm', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Marjorie" format=""}%');
    $this->assert_str_equals('', $result);
}

# topic="..." Topic where form data is located. May be of the form Web.<nop>TopicName
sub test_FORMFIELD_topic {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm');
    $this->{session}->{webName} = $this->{test_web};
    my $result = $topicObject->expandMacros(
        '%FORMFIELD{"Marjorie"}%');
    $this->assert_str_equals('', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Marjorie" topic="'.$this->{test_topic}.'"}%');
    $this->assert_str_equals('99', $result);
    $topicObject =
      Foswiki::Meta->new( $this->{session},
                          $Foswiki::cfg{SystemWebName},
                          $Foswiki::cfg{HomeTopicName});
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Marjorie" topic="'.$this->{test_topic}.'"}%');
    $this->assert_str_equals('', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Marjorie" topic="'.
          $this->{test_web}.'.'.$this->{test_topic}.'"}%');
    $this->assert_str_equals('99', $result);
}

# Check if ! and <nop> are properly rendered
sub test_FORMFIELD_render_nops {
    my $this = shift;

    my $topicObject = $this->{test_topicObject};
    my $result = $topicObject->expandMacros(
        '%FORMFIELD{"Daphne"}%');
    $this->assert_str_equals('<nop>ElleBelle', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Ffiona" alttext="!NiceAsPie" default="Cressida"}%');
    $this->assert_str_equals('<nop>NiceAsPie', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Priscilla" default="!NiceAsPie"}%');
    $this->assert_str_equals('<nop>NiceAsPie', $result);
    $result = $topicObject->expandMacros(
        '%FORMFIELD{"Priscilla" default="<nop>NiceAsPie"}%');
    $this->assert_str_equals('<nop>NiceAsPie', $result);

}

1;
