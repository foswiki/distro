package QueryTests;
use base 'FoswikiFnTestCase';

use Foswiki::Query::Parser;
use Foswiki::Query::HoistREs;
use Foswiki::Query::Node;
use Foswiki::Meta;
use strict;

sub new {
    my $self = shift()->SUPER::new('SEARCH', @_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $meta = new Foswiki::Meta($this->{twiki}, 'Web', 'Topic');
    $meta->putKeyed('FILEATTACHMENT',
                    { name=>"att1.dat",
                      attr=>"H",
                      comment=>"Wun",
                      path=>'a path',
                      size=>'1',
                      user=>'Junkie',
                      rev=>'23',
                      date=>'25',
                  });
    $meta->putKeyed('FILEATTACHMENT',
                    { name=>"att2.dot",
                      attr=>"",
                      comment=>"Too",
                      path=>'anuvver path',
                      size=>'100',
                      user=>'ProjectContributor',
                      rev=>'105',
                      date=>'99',
                  });
    $meta->put('FORM', { name=>'TestForm' });
    $meta->put('TOPICINFO', {
        author=>'AlbertCamus',
        date=>'12345',
        format=>'1.1',
        version=>'1.1913',
    });
    $meta->put('TOPICMOVED', {
        by=>'AlbertCamus',
        date=>'54321',
        from=>'BouvardEtPecuchet',
        to=>'ThePlague',
    });
    $meta->put('TOPICPARENT', { name=>'' });
    $meta->putKeyed('PREFERENCE', { name=>'Red', value=>'0' });
    $meta->putKeyed('PREFERENCE', { name=>'Green', value=>'1' });
    $meta->putKeyed('PREFERENCE', { name=>'Blue', value=>'0' });
    $meta->putKeyed('PREFERENCE', { name=>'White', value=>'0' });
    $meta->putKeyed('PREFERENCE', { name=>'Yellow', value=>'1' });
    $meta->putKeyed('FIELD',
                    { name=>"number", title=>"Number", value=>"99"});
    $meta->putKeyed('FIELD',
                    {name=>"string", title=>"String", value=>"String"});
    $meta->putKeyed('FIELD',
                    {name=>"boolean", title=>"Boolean", value=>"1"});

    $meta->{_text} = "Green ideas sleep furiously";

    $this->{meta} = $meta;
}

sub check {
    my ( $this, $s, $r ) = @_;
    my $queryParser = new Foswiki::Query::Parser();
    my $query = $queryParser->parse($s);
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom=>$meta, data=>$meta );
    if(ref($r)) {
        $this->assert_deep_equals(
            $r, $val,
            "Expected $r, got ".Foswiki::Query::Node::toString($val)." for $s in ".
           join(' ', caller));
    } else {
        $this->assert_str_equals(
            $r, $val,
            "Expected $r, got ".Foswiki::Query::Node::toString($val)." for $s in ".
           join(' ', caller));
    }
}

sub test_atoms {
    my $this = shift;
    $this->check("'0'", '0');
    $this->check("''", '');
    $this->check("1", 1);
    $this->check("-1", -1);
    $this->check("-1.1965432e-3", -1.1965432e-3);
    $this->check("number", 99);
    $this->check("text", "Green ideas sleep furiously");
    $this->check("string", 'String');
    $this->check("boolean", 1);
}

sub test_meta_dot {
    my $this = shift;
    $this->check("META:FORM", { name=>'TestForm' });
    $this->check("META:FORM.name", 'TestForm');
    $this->check("form.name", 'TestForm');
    $this->check("info.author", 'AlbertCamus');
    $this->check("fields.number", 99);
    $this->check("fields.string", 'String');
}

sub test_array_dot {
    my $this = shift;
    $this->check("preferences[value=0].Red", 0);
    $this->check("preferences[value=1].Yellow", 1);
}

sub test_meta_squabs {
    my $this = shift;
    $this->check("fields[name='number'].value", 99);
    $this->check("fields[name='number' AND value='99'].value", 99);
    $this->check("fields[name='number' AND value='99'].value", 99);
}

sub test_array_squab {
    my $this = shift;
    $this->check("preferences[value=0][name='Blue'].name", "Blue");
}

sub test_slashes {
    my $this = shift;
}

sub test_boolean_uops {
    my $this = shift;
    $this->check("not number", 0);
    $this->check("not boolean", 0);
    $this->check("not 0", 1);
}

sub test_string_uops {
    my $this = shift;
    $this->check("uc string",'STRING');
    $this->check("uc(string)","STRING");
    $this->check("lc string",'string');
    $this->check("uc 'string'",'STRING');
    $this->check("lc 'STRING'",'string');
}

sub test_string_bops {
    my $this = shift;
    $this->check("string='String'", 1);
    $this->check("string='String '", 0);
    $this->check("string~'String '", 0);
    $this->check("string='Str'", 0);
    $this->check("string~'?trin?'", 1);
    $this->check("string~'*'", 1);
    $this->check("string~'*String'", 1);
    $this->check("string~'*trin*'", 1);
    $this->check("string~'*in?'", 1);
    $this->check("string~'*ri?'", 0);
    $this->check("string~'??????'", 1);
    $this->check("string~'???????'", 0);
    $this->check("string~'?????'", 0);
    $this->check("'SomeTextToTestFor'~'Text'", 0);
    $this->check("'SomeTextToTestFor'~'*Text'", 0);
    $this->check("'SomeTextToTestFor'~'Text*'", 0);
    $this->check("'SomeTextToTestFor'~'*Text*'", 1);
    $this->check("string!='Str'", 1);
    $this->check("string!='String '", 1);
    $this->check("string!='String'", 0);
    $this->check("string!='string'", 1);
    $this->check("string='string'", 0);
    $this->check("string~'string'", 0);
}

sub test_num_uops {
    my $this = shift;
    $this->check("d2n '".Foswiki::Time::formatTime(0,'$iso')."'", 0);
    $this->check("length attachments", 2);
    $this->check("length META:PREFERENCE", 5);
    $this->check("length 'five'", 4);
    $this->check("length info", 4);
}

sub test_num_bops {
    my $this = shift;
    $this->check("number=99", 1);
    $this->check("number=98", 0);
    $this->check("number!=99", 0);
    $this->check("number!=0", 1);
    $this->check("number<100", 1);
    $this->check("number<99", 0);
    $this->check("number>98", 1);
    $this->check("number>99", 0);
    $this->check("number<=99", 1);
    $this->check("number<=100", 1);
    $this->check("number<=98", 0);
    $this->check("number>=98", 1);
    $this->check("number>=99", 1);
    $this->check("number>=100", 0);
}

sub test_boolean_bops {
    my $this = shift;
    $this->check("number=99 AND string='String'", 1);
    $this->check("number=98 AND string='String'", 0);
    $this->check("number=99 AND string='Sring'", 0);
    $this->check("number=99 OR string='Spring'", 1);
    $this->check("number=98 OR string='String'", 1);
    $this->check("number=98 OR string='Spring'", 0);
}

sub conjoin {
    my ( $this, $last, $A, $B, $a, $b, $c, $r ) = @_;

    my @ac = (98, 99);
    my $ae = "number=$ac[$a]";
    my @bc = qw(Spring String);
    my $be = "string='$bc[$b]'";
    my $ce = ($c ? '' : 'not ')."boolean";
    my $expr;
    if ( $last ) {
        $expr = "$ae $A ( $be $B $ce )";
    } else {
        $expr = "( $ae $A $be ) $B $ce";
    }
    $this->check($expr, $r);
}

sub test_brackets {
    my $this = shift;
    for (my $a = 0; $a < 2; $a++) {
        for (my $b = 0; $b < 2; $b++) {
            for (my $c = 0; $c < 2; $c++) {
                $this->conjoin(1,"AND","OR", $a, $b, $c, $a && ($b || $c));
                $this->conjoin(1,"OR","AND", $a, $b, $c, $a || ($b && $c));
                $this->conjoin(0,"AND","OR",$a, $b, $c, ($a && $b) || $c);
                $this->conjoin(0,"OR","AND",$a, $b, $c, ($a || $b) && $c);
            }
        }
    }
}

sub test_hoistSimple {
    my $this = shift;
    my $s = "number=99";
    my $queryParser = new Foswiki::Query::Parser();
    my $query = $queryParser->parse($s);
    require Foswiki::Query::HoistREs;
    my @filter = Foswiki::Query::HoistREs::hoist( $query ) || 'undef';
    #print STDERR "HoistS ",$query->stringify()," -> /",join(';', @filter),"/\n";
    $this->assert_str_equals('^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
                            join(';', @filter));
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom=>$meta, data=>$meta );
}

sub test_hoistSimple2 {
    my $this = shift;
    my $s = "99=number";
    my $queryParser = new Foswiki::Query::Parser();
    my $query = $queryParser->parse($s);
    require Foswiki::Query::HoistREs;
    my @filter = Foswiki::Query::HoistREs::hoist( $query ) || 'undef';
    #print STDERR "HoistS ",$query->stringify()," -> /",join(';', @filter),"/\n";
    $this->assert_str_equals('^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
                            join(';', @filter));
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom=>$meta, data=>$meta );
}

sub test_hoistCompound {
    my $this = shift;
    my $s = "number=99 AND string='String' and (moved.by='AlbertCamus' OR moved.by ~ '*bert*')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query = $queryParser->parse($s);
    require Foswiki::Query::HoistREs;
    my @filter = Foswiki::Query::HoistREs::hoist( $query );
    #print STDERR "HoistC ",$query->stringify()," -> /",join(';', @filter),"/\n";
    $this->assert_str_equals('^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
                             $filter[0]);
    $this->assert_str_equals('^%META:FIELD{name=\"string\".*\bvalue=\"String\"',
                             $filter[1]);
    $this->assert_str_equals('^%META:TOPICMOVED{.*\bby=\"AlbertCamus\"|^%META:TOPICMOVED{.*\bby=\".*bert.*\"',
                             $filter[2]);
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom=>$meta, data=>$meta );
}

sub test_hoistCompound2 {
    my $this = shift;
    my $s = "(moved.by='AlbertCamus' OR moved.by ~ '*bert*') AND number=99 AND string='String'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query = $queryParser->parse($s);
    require Foswiki::Query::HoistREs;
    my @filter = Foswiki::Query::HoistREs::hoist( $query );
    #print STDERR "HoistC ",$query->stringify()," -> /",join(';', @filter),"/\n";
    $this->assert_str_equals('^%META:TOPICMOVED{.*\bby=\"AlbertCamus\"|^%META:TOPICMOVED{.*\bby=\".*bert.*\"',
                             $filter[0]);
    $this->assert_str_equals('^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
                             $filter[1]);
    $this->assert_str_equals('^%META:FIELD{name=\"string\".*\bvalue=\"String\"',
                             $filter[2]);
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom=>$meta, data=>$meta );
}

sub test_hoistAlias {
    my $this = shift;
    my $s = "info.date=12345";
    my $queryParser = new Foswiki::Query::Parser();
    my $query = $queryParser->parse($s);
    require Foswiki::Query::HoistREs;
    my @filter = Foswiki::Query::HoistREs::hoist( $query ) || 'undef';
    $this->assert_str_equals('^%META:TOPICINFO{.*\bdate=\"12345\"',
                             join(';', @filter));
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom=>$meta, data=>$meta );
}

sub test_hoistFormField {
    my $this = shift;
    my $s = "TestForm.number=99";
    my $queryParser = new Foswiki::Query::Parser();
    my $query = $queryParser->parse($s);
    require Foswiki::Query::HoistREs;
    my @filter = Foswiki::Query::HoistREs::hoist( $query ) || 'undef';
    $this->assert_str_equals('^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
                             join(';', @filter));
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom=>$meta, data=>$meta );
}

sub test_hoistText {
    my $this = shift;
    my $s = "text ~ '*Green*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query = $queryParser->parse($s);
    require Foswiki::Query::HoistREs;
    my @filter = Foswiki::Query::HoistREs::hoist( $query ) || 'undef';
    $this->assert_str_equals('.*Green.*',
                             join(';', @filter));
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom=>$meta, data=>$meta );
}

1;
