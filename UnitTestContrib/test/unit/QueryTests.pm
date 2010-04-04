# Tests for query parser and evaluation

# This testcase is focused on the correct implementation of the queries, rather
# than %SEARCH itself. The main purpose is to test the query parser, but it
# also acts as a validation check for store-specific query algorithm
# implementations.
# There are two types of test here; verify_ tests that are applied to each
# query algorithm. It's assumed that these algorithms are working off a
# query parse tree, so the focus is on testing the semantics of the queries.
# The other type are test_ tests, which are focused on testing the
# query syntax.

package QueryTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki::Query::Parser;
use Foswiki::Query::HoistREs;
use Foswiki::Query::Node;
use Foswiki::Meta;
use strict;

my %qalgs;

sub new {
    my $self = shift()->SUPER::new( 'SEARCH', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $meta = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, 'HitTopic' );
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
    $meta->putKeyed( 'FIELD',
        { name => "StringWithChars", title => "StringWithChars",
          value => "n\nn t\tt s\\s q'q o#o h#h X~X \\b \\a \\e \\f \\r \\cX" } );
    $meta->putKeyed( 'FIELD',
        { name => "boolean", title => "Boolean", value => "1" } );
    $meta->putKeyed( 'FIELD',
        { name => "macro", value => "%RED%" } );

    $meta->{_text} = "Green ideas sleep furiously";
    $this->{meta} = $meta;
    $meta->save();
}

sub fixture_groups {
    my ( %qalgs );
    foreach my $dir (@INC) {
        if ( opendir( D, "$dir/Foswiki/Store/QueryAlgorithms" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ /^(.*)\.pm$/;
                $alg = $1;
                $qalgs{$alg} = 1;
            }
            closedir(D);
        }
    }
    my @groups;
    foreach my $alg ( keys %qalgs ) {
        my $fn = $alg . 'Query';
        push( @groups, $fn );
        next if ( defined(&$fn) );
        eval <<SUB;
sub $fn {
require Foswiki::Store::QueryAlgorithms::$alg;
\$Foswiki::cfg{Store}{QueryAlgorithm} = 'Foswiki::Store::QueryAlgorithms::$alg'; }
SUB
        die $@ if $@;
    }

    return \@groups;
}

sub check {
    my ( $this, $s, $r, $syntaxOnly ) = @_;

    # First check that standard evaluator
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $meta        = $this->{meta};
    my $val         = $query->evaluate( tom => $meta, data => $meta );
    if ( ref($r) ) {
        $this->assert_deep_equals( $r, $val,
                "Expected ".ref($r)." $r, got "
              . Foswiki::Query::Node::toString($val)
              . " for $s in "
              . join( ' ', caller ) );
    }
    elsif (defined $r) {
        $this->assert_str_equals( $r, $val,
                "Expected scalar $r, got "
              . Foswiki::Query::Node::toString($val)
              . " for $s in "
              . join( ' ', caller ) );
    }
    else {
        $this->assert(!defined($val),
                "Expected undef, got "
              . Foswiki::Query::Node::toString($val)
              . " for $s in "
              . join( ' ', caller ) );
    }

    unless ($syntaxOnly) {
        # Next check the search algorithm
        my $expr = "%SEARCH{\"$s\" type=\"query\" excludetopic=\"WebPreferences,$this->{test_topic}\" nonoise=\"on\" format=\"\$topic\"}%";
        my $list = $this->{test_topicObject}->expandMacros($expr);
        if ($r) {
            $this->assert_str_equals( 'HitTopic', $list);
        } else {
            $this->assert_str_equals( '', $list);
        }
    }
}

sub verify_atoms {
    my $this = shift;
    $this->check( "'0'",           '0' );
    $this->check( "''",            '' );
    $this->check( "1",             1 );
    $this->check( "-1",            -1 );
    $this->check( "-1.1965432e-3", -1.1965432e-3 );
    $this->check( "number",        99 );
    $this->check( "text",          "Green ideas sleep furiously" );
    $this->check( "string",        'String' );
    $this->check( "boolean",       1 );
    $this->check( "macro",         '%RED%' );
    $this->check( "notafield",     undef );
}

sub verify_meta_dot {
    my $this = shift;
    $this->check( "META:FORM", { name => 'TestForm' } );
    $this->check( "META:FORM.name", 'TestForm' );
    $this->check( "form.name",      'TestForm' );
    $this->check( "info.author",    'AlbertCamus' );
    $this->check( "fields.number",  99 );
    $this->check( "fields.string",  'String' );
    $this->check( "notafield.string",  undef );
}

sub verify_array_integer_index {
    my $this = shift;
    $this->check( "preferences[0].name", 'Red' );
    $this->check( "preferences[1]", { name => 'Green', value => 1 } );
    $this->check( "preferences[2].name", 'Blue' );
    $this->check( "preferences[3].name", 'White' );
    $this->check( "preferences[4].name", 'Yellow' );
    # Integer part used as the index
    $this->check( "preferences[1.9].name", 'Green' );

    # From-the-end indices
    $this->check( "preferences[-1].name", 'Yellow' );
    $this->check( "preferences[-2].name", 'White' );
    $this->check( "preferences[-3].name", 'Blue' );
    $this->check( "preferences[-4].name", 'Green' );
    $this->check( "preferences[-5].name", 'Red' );

    # Out-of-range indices
    $this->check( "preferences[5]", undef );
    $this->check( "preferences[-6]", undef );
}

sub verify_array_dot {
    my $this = shift;
    $this->check( "preferences[value=0].Red",    0 );
    $this->check( "preferences[value=1].Yellow", 1 );
}

sub verify_meta_squabs {
    my $this = shift;
    $this->check( "fields[name='number'].value",                99 );
    $this->check( "fields[name='number' AND value='99'].value", 99 );
    $this->check( "fields[name='number' AND value='99'].value", 99 );
}

sub verify_array_squab {
    my $this = shift;
    $this->check( "preferences[value=0][name='Blue'].name", "Blue" );
}

sub verify_slashes {
    my $this = shift;
}

sub verify_boolean_uops {
    my $this = shift;
    $this->check( "not number",  0 );
    $this->check( "not boolean", 0 );
    $this->check( "not 0",       1 );
    $this->check( "not notafield", 1 );
}

sub verify_string_uops {
    my $this = shift;
    $this->check( "uc string",   'STRING' );
    $this->check( "uc(string)",  "STRING" );
    $this->check( "lc string",   'string' );
    $this->check( "lc(notafield)",   undef );
    $this->check( "uc 'string'", 'STRING' );
    $this->check( "uc (notafield)", undef );
    $this->check( "lc 'STRING'", 'string' );
}

sub verify_string_bops {
    my $this = shift;
    $this->check( "string='String'",              1 );
    $this->check( "string='String '",             0 );
    $this->check( "string~'String '",             0 );
    $this->check( "string='Str'",                 0 );
    $this->check( "string~'?trin?'",              1 );
    $this->check( "string~'*'",                   1 );
    $this->check( "string~'*String'",             1 );
    $this->check( "string~'*trin*'",              1 );
    $this->check( "string~'*in?'",                1 );
    $this->check( "string~'*ri?'",                0 );
    $this->check( "string~'??????'",              1 );
    $this->check( "string~'???????'",             0 );
    $this->check( "string~'?????'",               0 );
    $this->check( "'SomeTextToTestFor'~'Text'",   0 );
    $this->check( "'SomeTextToTestFor'~'*Text'",  0 );
    $this->check( "'SomeTextToTestFor'~'Text*'",  0 );
    $this->check( "'SomeTextToTestFor'~'*Text*'", 1 );
    $this->check( "string!='Str'",                1 );
    $this->check( "string!='String '",            1 );
    $this->check( "string!='String'",             0 );
    $this->check( "string!='string'",             1 );
    $this->check( "string='string'",              0 );
    $this->check( "string~'string'",              0 );
}

sub test_string_bops {
    my $this = shift;
    $this->check( "macro='\%RED\%'",              1, 1 );
    $this->check( "macro~'\%RED?'",               1, 1 );
    $this->check( "macro~'?RED\%'",               1, 1 );
}

sub verify_length {
    my $this = shift;
    $this->check( "length attachments",     2 );
    $this->check( "length META:PREFERENCE", 5 );
    $this->check( "length 'five'",          4 );
    $this->check( "length info",            4 );
    $this->check( "length notafield",       0 );
}

sub verify_d2n {
    my $this = shift;
    $this->check(
        "d2n '" . Foswiki::Time::formatTime( 0, '$iso', 'servertime' )
          . "'", 0 );
    my $t = time;
    $this->check(
        "d2n '" . Foswiki::Time::formatTime( $t, '$iso', 'servertime' )
          . "'", $t );
    $this->check( "d2n 'not a time'", undef );
    $this->check( "d2n 0", undef );
    $this->check( "d2n notatime", undef );
}

sub verify_num_bops {
    my $this = shift;
    $this->check( "number=99",   1 );
    $this->check( "number=98",   0 );
    $this->check( "number!=99",  0 );
    $this->check( "number!=0",   1 );
    $this->check( "number<100",  1 );
    $this->check( "number<99",   0 );
    $this->check( "number>98",   1 );
    $this->check( "number>99",   0 );
    $this->check( "number<=99",  1 );
    $this->check( "number<=100", 1 );
    $this->check( "number<=98",  0 );
    $this->check( "number>=98",  1 );
    $this->check( "number>=99",  1 );
    $this->check( "number>=100", 0 );

    $this->check( "number=notafield", 0);
    $this->check( "0=notafield", 0);
    $this->check( "notafield=number", 0);
    $this->check( "number!=notafield", 1);
    $this->check( "notafield!=number", 1);
    $this->check( "number>=notafield", 1);
    $this->check( "notafield>=number", 0);
    $this->check( "number<=notafield", 0);
    $this->check( "notafield<=number", 1);
    $this->check( "number>notafield", 1);
    $this->check( "notafield>number", 0);
    $this->check( "number<notafield", 0);
    $this->check( "notafield<number", 1);

    $this->check( "notafield=undefined", 1);
}

sub verify_boolean_bops {
    my $this = shift;

    $this->check( "1 AND 1", 1 );
    $this->check( "0 AND 1", 0 );
    $this->check( "1 AND 0", 0 );

    $this->check( "1 OR 1", 1 );
    $this->check( "0 OR 1", 1 );
    $this->check( "1 OR 0", 1 );

    $this->check( "number=99 AND string='String'", 1 );
    $this->check( "number=98 AND string='String'", 0 );
    $this->check( "number=99 AND string='Sring'",  0 );
    $this->check( "number=99 OR string='Spring'",  1 );
    $this->check( "number=98 OR string='String'",  1 );
    $this->check( "number=98 OR string='Spring'",  0 );

    $this->check( "notafield AND 1",  0 );
    $this->check( "1 AND notafield",  0 );
    $this->check( "0 AND notafield",  0 );
    $this->check( "notafield OR 1",   1 );
    $this->check( "1 OR notafield",   1 );
    $this->check( "notafield OR 0",   0 );
    $this->check( "0 OR notafield",   0 );
}

sub verify_match_fail {
    my $this = shift;
    $this->check( "'A'=~'B'", 0);
}

sub verify_match_good {
    my $this = shift;
    $this->check( "'A'=~'A'", 1);
}

sub verify_partial_match {
    my $this = shift;
    $this->check( "'AA'=~'A'", 1);
}

sub verify_word_bound_match_good {
    my $this = shift;
    $this->check( "'foo bar baz'=~'\\bbar\\b'", 1);
}

sub verify_word_bound_match_fail {
    my $this = shift;
    $this->check( "'foo bar baz'=~'\\bbam\\b'", 0);
}

sub verify_word_end_match_fail {
    my $this = shift;
    $this->check( "'foob'=~'foo\\b'", 0);
}

sub verify_ref {
    my $this = shift;
    $this->check( "'HitTopic'/number=99", 1);
    $this->check( "'$this->{test_web}.HitTopic'/number=99", 1);
    $this->check( "'NotATopic'/number", undef);
    $this->check( "'NotATopic'/number=99", 0);
}

sub test_backslash_match_fail {
    my $this = shift;
    $this->check( "' \\ '=~' \\\\ '", 0, 1);
}

sub test_backslash_match_good {
    my $this = shift;
    $this->check( "' \\\' '=~' \\\' '", 1, 1);
}

sub test_constant_strings {
    my $this = shift;
    my $in = 'n\nn t\tt s\\\\s q\\\'q o\\043o h\\x23h X\\x{7e}X \\b \\a \\e \\f \\r \\cX';

    $this->check( "'$in'=StringWithChars", 1, 1 );
}

sub conjoin {
    my ( $this, $last, $A, $B, $a, $b, $c, $r ) = @_;

    my @ac = ( 98, 99 );
    my $ae = "number=$ac[$a]";
    my @bc = qw(Spring String);
    my $be = "string='$bc[$b]'";
    my $ce = ( $c ? '' : 'not ' ) . "boolean";
    my $expr;
    if ($last) {
        $expr = "$ae $A ( $be $B $ce )";
    }
    else {
        $expr = "( $ae $A $be ) $B $ce";
    }
    $this->check( $expr, $r );
}

sub verify_brackets {
    my $this = shift;
    for ( my $a = 0 ; $a < 2 ; $a++ ) {
        for ( my $b = 0 ; $b < 2 ; $b++ ) {
            for ( my $c = 0 ; $c < 2 ; $c++ ) {
                $this->conjoin( 1, "AND", "OR", $a, $b, $c,
                    $a && ( $b || $c ) );
                $this->conjoin( 1, "OR", "AND", $a, $b, $c,
                    $a || ( $b && $c ) );
                $this->conjoin( 0, "AND", "OR", $a, $b, $c,
                    ( $a && $b ) || $c );
                $this->conjoin( 0, "OR", "AND", $a, $b, $c,
                    ( $a || $b ) && $c );
            }
        }
    }
}

1;
