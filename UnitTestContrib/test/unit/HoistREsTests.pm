# Test for hoisting REs from query expressions
package HoistREsTests;
use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki::Query::Parser;
use Foswiki::Query::HoistREs;
use Foswiki::Query::Node;
use Foswiki::Meta;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my ($meta) = Foswiki::Func::readTopic( 'Web', 'Topic' );
    $meta->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "att1.dat",
            attr    => "H",
            comment => "Wun",
            path    => 'a path',
            size    => '1',
            user    => 'Junkie',
            rev     => '23',
            date    => '25',
        }
    );
    $meta->putKeyed(
        'FILEATTACHMENT',
        {
            name    => "att2.dot",
            attr    => "",
            comment => "Too",
            path    => 'anuvver path',
            size    => '100',
            user    => 'ProjectContributor',
            rev     => '105',
            date    => '99',
        }
    );
    $meta->put( 'FORM', { name => 'TestForm' } );
    $meta->put(
        'TOPICINFO',
        {
            author  => 'AlbertCamus',
            date    => '12345',
            format  => '1.1',
            version => '1.1913',
        }
    );
    $meta->put(
        'TOPICMOVED',
        {
            by   => 'AlbertCamus',
            date => '54321',
            from => 'BouvardEtPecuchet',
            to   => 'ThePlague',
        }
    );
    $meta->put( 'TOPICPARENT', { name => '' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'Red',    value => '0' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'Green',  value => '1' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'Blue',   value => '0' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'White',  value => '0' } );
    $meta->putKeyed( 'PREFERENCE', { name => 'Yellow', value => '1' } );
    $meta->putKeyed( 'FIELD',
        { name => "number", title => "Number", value => "99" } );
    $meta->putKeyed( 'FIELD',
        { name => "string", title => "String", value => "String" } );
    $meta->putKeyed(
        'FIELD',
        {
            name  => "StringWithChars",
            title => "StringWithChars",
            value => "n\nn t\tt s\\s q'q o#o h#h X~X \\b \\a \\e \\f \\r \\cX"
        }
    );
    $meta->putKeyed( 'FIELD',
        { name => "boolean", title => "Boolean", value => "1" } );
    $meta->putKeyed( 'FIELD', { name => "macro", value => "%RED%" } );

    $meta->{_text} = "Green ideas sleep furiously";

    $this->{meta} = $meta;
}

sub _hoist {
    my ( $this, $query ) = @_;
    my $filter;

    if ( $this->check_dependency('Foswiki,<,1.2') ) {
        $filter = [ Foswiki::Query::HoistREs::hoist($query) ];
        $this->assert_str_equals( 'ARRAY', ref($filter) );
    }
    else {
        $filter = Foswiki::Query::HoistREs::hoist($query);
        $this->assert_str_equals( 'HASH', ref($filter) );
    }

    return $filter;
}

# Filter element key names, mapping from Foswiki 1.2+ to Foswiki 1.1
my %filter_key_map = (
    'text'        => 'regex',
    'name'        => 'regex',
    'name_source' => 'source'
);

sub _getFilterNumElements {
    my ( $this, $filter, $bogus ) = @_;
    my $number;

    $this->assert( !defined $bogus );
    if ( $this->check_dependency('Foswiki,<,1.2') ) {
        $this->assert_str_equals( 'ARRAY', ref($filter) );
        $number = scalar( @{$filter} );
    }
    else {
        $this->assert_str_equals( 'HASH', ref($filter) );
        $number = scalar( keys %{$filter} );
    }

    return $number;
}

sub _getFilterElements {
    my ( $this, $filter, $key, $bogus ) = @_;
    my @elements;

    $this->assert( !defined $bogus );
    if ( $this->check_dependency('Foswiki,<,1.2') ) {
        $this->assert_str_equals( 'ARRAY', ref($filter) );
        if ( exists $filter_key_map{$key} ) {
            @elements = map { $_->{ $filter_key_map{$key} } } @{$filter};
        }
        else {
            @elements = map { $_->{$key} } @{$filter};
        }
    }
    else {
        $this->assert_str_equals( 'HASH',  ref($filter) );
        $this->assert_str_equals( 'ARRAY', ref( $filter->{$key} ) );
        @elements = @{ $filter->{$key} };
    }

    return @elements;
}

sub _getFilterElement {
    my ( $this, $filter, $key, $index ) = @_;
    my $element;

    if ( $this->check_dependency('Foswiki,<,1.2') ) {
        $this->assert_str_equals( 'ARRAY', ref($filter) );
        if ( exists $filter_key_map{$key} ) {
            $element = $filter->[$index]->{ $filter_key_map{$key} };
        }
        else {
            $element = $filter->[$index]->{$key};
        }
    }
    else {
        $this->assert_str_equals( 'HASH', ref($filter) );
        $element = $filter->{$key}->[$index];
    }

    return $element;
}

sub test_hoistSimple {
    my $this        = shift;
    my $s           = "number=99";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);

   #print STDERR "HoistS ",$query->stringify()," -> /",join(';', @filter),"/\n";
    $this->assert_str_equals(
        '^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoistSimple2 {
    my $this        = shift;
    my $s           = "99=number";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);

   #print STDERR "HoistS ",$query->stringify()," -> /",join(';', @filter),"/\n";
    $this->assert_str_equals(
        '^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoistCompound {
    my $this = shift;
    my $s =
"number=99 AND string='String' and (moved.by='AlbertCamus' OR moved.by ~ '*bert*')";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);

   #print STDERR "HoistC ",$query->stringify()," -> /",join(';', @filter),"/\n";
    $this->assert_str_equals(
        '^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
        $this->_getFilterElement( $filter, 'text', 0 )
    );
    $this->assert_str_equals(
        '^%META:FIELD{name=\"string\".*\bvalue=\"String\"',
        $this->_getFilterElement( $filter, 'text', 1 )
    );
    $this->assert_str_equals(
'^%META:TOPICMOVED{.*\bby=\"AlbertCamus\"|^%META:TOPICMOVED{.*\bby=\".*bert.*\"',
        $this->_getFilterElement( $filter, 'text', 2 )
    );
    $this->assert_num_equals( 3,
        scalar( $this->_getFilterElements( $filter, 'text' ) ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoistCompound2 {
    my $this = shift;
    my $s =
"(moved.by='AlbertCamus' OR moved.by ~ '*bert*') AND number=99 AND string='String'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);

   #print STDERR "HoistC ",$query->stringify()," -> /",join(';', @filter),"/\n";
    $this->assert_str_equals(
'^%META:TOPICMOVED{.*\bby=\"AlbertCamus\"|^%META:TOPICMOVED{.*\bby=\".*bert.*\"',
        $this->_getFilterElement( $filter, 'text', 0 )
    );
    $this->assert_str_equals(
        '^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
        $this->_getFilterElement( $filter, 'text', 1 )
    );
    $this->assert_str_equals(
        '^%META:FIELD{name=\"string\".*\bvalue=\"String\"',
        $this->_getFilterElement( $filter, 'text', 2 )
    );
    $this->assert_num_equals( 3,
        scalar( $this->_getFilterElements( $filter, 'text' ) ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoistAlias {
    my $this        = shift;
    my $s           = "info.date=12345";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals( '^%META:TOPICINFO{.*\bdate=\"12345\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoistFormField {
    my $this        = shift;
    my $s           = "TestForm.number=99";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals(
        '^%META:FIELD{name=\"number\".*\bvalue=\"99\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoistText {
    my $this        = shift;
    my $s           = "text ~ '*Green*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals( '.*Green.*',
        join( ';', $this->_getFilterElements( $filter, 'text' ) ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoistName {
    my $this        = shift;
    my $s           = "name ~ 'Web*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_num_equals( 1,
        scalar( $this->_getFilterElements( $filter, 'name' ) ) );
    $this->assert_str_equals( 'Web.*',
        $this->_getFilterElement( $filter, 'name', 0 ) );
    $this->assert_str_equals( 'Web*',
        $this->_getFilterElement( $filter, 'name_source', 0 ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert( !$val );
}

sub test_hoistName2 {
    my $this        = shift;
    my $s           = "name ~ 'Web*' OR name ~ 'A*' OR name = 'Banana'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_num_equals( 1,
        scalar( $this->_getFilterElements( $filter, 'name' ) ) );
    $this->assert_str_equals( 'Web.*|A.*|Banana',
        $this->_getFilterElement( $filter, 'name', 0 ) );
    $this->assert_str_equals( 'Web*,A*,Banana',
        $this->_getFilterElement( $filter, 'name_source', 0 ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert( !$val );
}

sub test_hoist_OPMatch1 {
    my $this        = shift;
    my $s           = "text =~ 'Green'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals( 'Green',
        join( ';', $this->_getFilterElements( $filter, 'text' ) ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoist_OPMatch2 {
    my $this        = shift;
    my $s           = "text =~ '.*Green.*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals( '.*Green.*',
        join( ';', $this->_getFilterElements( $filter, 'text' ) ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoist_OPMatch3 {
    my $this        = shift;
    my $s           = "text =~ '^Green.*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals( '^Green.*',
        join( ';', $this->_getFilterElements( $filter, 'text' ) ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoist_OPMatch4 {
    my $this        = shift;
    my $s           = "text =~ '.*Green\$'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals( '.*Green$',
        join( ';', $this->_getFilterElements( $filter, 'text' ) ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert( !$val );
}

sub test_hoist_OPMatch5 {
    my $this        = shift;
    my $s           = "text =~ '^Green\$'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals( '^Green$',
        join( ';', $this->_getFilterElements( $filter, 'text' ) ) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert( !$val );
}
#############################################
sub test_hoist_OPMatchField1 {
    my $this        = shift;
    my $s           = "string =~ 'rin'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals(
        '^%META:FIELD{name=\"string\".*\bvalue=\".*rin.*\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoist_OPMatchField2 {
    my $this        = shift;
    my $s           = "string =~ '.*rin.*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals(
        '^%META:FIELD{name=\"string\".*\bvalue=\".*rin.*\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoist_OPMatchField3 {
    my $this        = shift;
    my $s           = "string =~ '^rin.*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals(
        '^%META:FIELD{name=\"string\".*\bvalue=\"rin.*\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert( !$val );
}

sub test_hoist_OPMatchField4 {
    my $this        = shift;
    my $s           = "string =~ '.*rin\$'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals(
        '^%META:FIELD{name=\"string\".*\bvalue=\".*rin\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert( !$val );
}

sub test_hoist_OPMatchField5 {
    my $this        = shift;
    my $s           = "string =~ '^rin\$'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $filter      = $this->_hoist($query);
    $this->assert_str_equals(
        '^%META:FIELD{name=\"string\".*\bvalue=\"rin\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert( !$val );
}

sub test_hoist_OPMatch_Item10352 {
    my $this        = shift;
    my $s           = "string=~'^St.(i|n).*'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);

    my $filter = $this->_hoist($query);
    $this->assert_str_equals(
        '^%META:FIELD{name=\"string\".*\bvalue=\"St.(i|n).*\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoist_OPMatch_Item10352_long {
    my $this        = shift;
    my $s           = "fields[name='string' AND value=~'^St.(i|n).*']";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);

    my $filter = $this->_hoist($query);

#$this->assert_str_equals( '^%META:FIELD{name=\"string\".*\bvalue=\"St.(i|n).*\"', join( ';', @{$filter->{text}} ) );
#we fail to regex hoist it
    $this->assert_num_equals( 0, $this->_getFilterNumElements($filter) );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoist_OPMatch_Item10352_1 {
    my $this        = shift;
    my $s           = "string=~'String'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);

    my $filter = $this->_hoist($query);
    $this->assert_str_equals(
        '^%META:FIELD{name=\"string\".*\bvalue=\".*String.*\"',
        join( ';', $this->_getFilterElements( $filter, 'text' ) )
    );
    my $meta = $this->{meta};
    my $val = $query->evaluate( tom => $meta, data => $meta );
    $this->assert($val);
}

sub test_hoist_mixed_or {
    my $this        = shift;
    my $s           = "name='Topic' or string=~'String'";
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);

    my $filter = $this->_hoist($query);
    $this->expect_failure( 'n-ary query nodes are Foswiki 1.2+ only',
        with_dep => 'Foswiki,<,1.2' );
    $this->assert_num_equals( 0, $this->_getFilterNumElements($filter) );
}

1;
