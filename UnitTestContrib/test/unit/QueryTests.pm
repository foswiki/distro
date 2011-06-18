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

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'HitTopic' );
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
    $meta->put( 'FORM',        { name => 'TestForm' } );
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
    $this->{meta}  = $meta;
    $meta->save();
}

sub fixture_groups {
    my (%qalgs);
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
    my ( $this, $s, %opts ) = @_;

    # First check that standard evaluator
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse($s);
    my $meta        = $this->{meta};
    my $val         = $query->evaluate( tom => $meta, data => $meta );
    if ( ref( $opts{'eval'} ) ) {
        $this->assert_deep_equals( $opts{'eval'}, $val,
                "Expected "
              . ref( $opts{'eval'} )
              . " $opts{'eval'}, got "
              . Foswiki::Query::Node::toString($val)
              . " for $s in "
              . join( ' ', caller ) );
    }
    elsif ( defined $opts{'eval'} ) {
        $this->assert_str_equals( $opts{'eval'}, $val,
                "Expected scalar $opts{'eval'}, got "
              . Foswiki::Query::Node::toString($val)
              . " for $s in "
              . join( ' ', caller ) );
    }
    else {
        $this->assert( !defined($val),
                "Expected undef, got "
              . Foswiki::Query::Node::toString($val)
              . " for $s in "
              . join( ' ', caller ) );
    }

    unless ( $opts{syntaxOnly} ) {
        if ( defined $opts{simpler} ) {
            $query->simplify( tom => $meta, data => $meta );
            $this->assert_str_equals( $opts{simpler}, $query->stringify(),
                $query->stringify() . " is not $opts{simpler}" );
        }
        elsif ( $query->evaluatesToConstant() ) {
            $this->assert( $opts{simpler},
                $query->stringify() . " should be variable" );
        }

        # Next check the search algorithm
        my $expr =
"%SEARCH{\"$s\" type=\"query\" excludetopic=\"WebPreferences,$this->{test_topic}\" nonoise=\"on\" format=\"\$topic\"}%";
        my $list = $this->{test_topicObject}->expandMacros($expr);
        if ( $opts{'eval'} ) {
            $this->assert_str_equals( 'HitTopic', $list );
        }
        else {
            $this->assert_str_equals( '', $list );
        }
    }
}

sub verify_atoms {
    my $this = shift;
    $this->check( "'0'", eval => '0', simpler => 0 );
    $this->check( "''",  eval => '',  simpler => q{''} ); # Not 0 - See Item9971
    $this->check( "1",   eval => 1,   simpler => 1 );
    $this->check( "-1",  eval => -1,  simpler => -1 );
    $this->check(
        "-1.1965432e-3",
        eval    => -1.1965432e-3,
        simpler => -1.1965432e-3
    );
    $this->check( "number",    eval => 99 );
    $this->check( "text",      eval => "Green ideas sleep furiously" );
    $this->check( "string",    eval => 'String' );
    $this->check( "boolean",   eval => 1 );
    $this->check( "macro",     eval => '%RED%' );
    $this->check( "notafield", eval => undef );
}

sub verify_meta_dot {
    my $this = shift;
    $this->check( "META:FORM", eval => { name => 'TestForm' } );
    $this->check( "META:FORM.name", eval => 'TestForm' );
    $this->check( "form.name",      eval => 'TestForm' );
    my $info = $this->{meta}->getRevisionInfo();
    $this->check( "info.date",        eval => $info->{date} );
    $this->check( "info.format",      eval => 1.1 );
    $this->check( "info.version",     eval => $info->{version} );
    $this->check( "info.author",      eval => $info->{author} );
    $this->check( "fields.number",    eval => 99 );
    $this->check( "fields.string",    eval => 'String' );
    $this->check( "notafield.string", eval => undef );
}

sub verify_array_integer_index {
    my $this = shift;
    $this->check( "preferences[0].name", eval => 'Red' );
    $this->check( "preferences[1]", eval => { name => 'Green', value => 1 } );
    $this->check( "preferences[2].name", eval => 'Blue' );
    $this->check( "preferences[3].name", eval => 'White' );
    $this->check( "preferences[4].name", eval => 'Yellow' );

    # Integer part used as the index
    $this->check( "preferences[1.9].name", eval => 'Green' );

    # From-the-end indices
    $this->check( "preferences[-1].name", eval => 'Yellow' );
    $this->check( "preferences[-2].name", eval => 'White' );
    $this->check( "preferences[-3].name", eval => 'Blue' );
    $this->check( "preferences[-4].name", eval => 'Green' );
    $this->check( "preferences[-5].name", eval => 'Red' );

    # Out-of-range indices
    $this->check( "preferences[5]",  eval => undef );
    $this->check( "preferences[-6]", eval => undef );
}

sub verify_array_dot {
    my $this = shift;
    $this->check( "preferences[value=0].Red",    eval => 0 );
    $this->check( "preferences[value=1].Yellow", eval => 1 );
}

sub verify_meta_squabs {
    my $this = shift;
    $this->check( "fields[name='number'].value",                eval => 99 );
    $this->check( "fields[name='number' AND value='99'].value", eval => 99 );
    $this->check( "fields[name='number' AND value='99'].value", eval => 99 );
}

sub verify_array_squab {
    my $this = shift;
    $this->check( "preferences[value=0][name='Blue'].name", eval => "Blue" );
}

sub verify_slashes {
    my $this = shift;
}

sub verify_boolean_uops {
    my $this = shift;
    $this->check( "not number",    eval => 0 );
    $this->check( "not boolean",   eval => 0 );
    $this->check( "not 0",         eval => 1, simpler => 1 );
    $this->check( "not notafield", eval => 1 );
}

sub verify_string_uops {
    my $this = shift;
    $this->check( "uc string",      eval => 'STRING' );
    $this->check( "uc(string)",     eval => "STRING" );
    $this->check( "lc string",      eval => 'string' );
    $this->check( "lc(notafield)",  eval => undef );
    $this->check( "uc 'string'",    eval => 'STRING', simpler => "'STRING'" );
    $this->check( "lc notafield",  eval => '' );
    $this->check( "uc (notafield)", eval => undef );
    $this->check( "uc notafield", eval => '' );
    $this->check( "lc 'STRING'",    eval => 'string', simpler => "'string'" );
    $this->check( "brace",         eval => 'Some text (really) we have text' );
    $this->check( "lc(brace)",     eval => 'some text (really) we have text' );
    $this->check( "uc(brace)",     eval => 'SOME TEXT (REALLY) WE HAVE TEXT' );
}

sub verify_string_bops {
    my $this = shift;
    $this->check( "string='String'",              eval => 1 );
    $this->check( "string='String '",             eval => 0 );
    $this->check( "string~'String '",             eval => 0 );
    $this->check( "string~notafield",               eval => 0 );
    $this->check( "notafield=~'SomeTextToTestFor'", eval => 0 );
    $this->check( "string!=notafield",              eval => 1 );
    $this->check( "string='Str'",                 eval => 0 );
    $this->check( "string~'?trin?'",              eval => 1 );
    $this->check( "string~'*'",                   eval => 1 );
    $this->check( "string~'*String'",             eval => 1 );
    $this->check( "string~'*trin*'",              eval => 1 );
    $this->check( "string~'*in?'",                eval => 1 );
    $this->check( "string~'*ri?'",                eval => 0 );
    $this->check( "string~'??????'",              eval => 1 );
    $this->check( "string~'???????'",             eval => 0 );
    $this->check( "string~'?????'",               eval => 0 );
    $this->check( "'SomeTextToTestFor'~'Text'",   eval => 0, simpler => 0 );
    $this->check( "'SomeTextToTestFor'~'*Text'",  eval => 0, simpler => 0 );
    $this->check( "'SomeTextToTestFor'~'Text*'",  eval => 0, simpler => 0 );
    $this->check( "'SomeTextToTestFor'~'*Text*'", eval => 1, simpler => 1 );
    $this->check( "string!='Str'",                eval => 1 );
    $this->check( "string!='String '",            eval => 1 );
    $this->check( "string!='String'",             eval => 0 );
    $this->check( "string!='string'",             eval => 1 );
    $this->check( "string='string'",              eval => 0 );
    $this->check( "string~'string'",              eval => 0 );
}

sub test_string_bops {
    my $this = shift;
    $this->check( "macro='\%RED\%'", eval => 1, syntaxOnly => 1 );
    $this->check( "macro~'\%RED?'",  eval => 1, syntaxOnly => 1 );
    $this->check( "macro~'?RED\%'",  eval => 1, syntaxOnly => 1 );
}

sub verify_length {
    my $this = shift;
    $this->check( "length attachments",     eval => 2 );
    $this->check( "length META:PREFERENCE", eval => 5 );
    $this->check( "length 'five'",          eval => 4, simpler => 4 );
    $this->check( "length info",            eval => 5 );
    $this->check( "length notafield",       eval => 0 );
}

sub verify_d2n {
    my $this = shift;

    my $dst = (localtime(time))[8];
    my $zeroTime = ( $dst ) ? 3600 : 0;

    $this->check(
        "d2n '" . Foswiki::Time::formatTime( $zeroTime, '$iso', 'servertime' ) . "'",
        eval    => 0,
        simpler => 0
    );
    my $t = time;
    $this->check(
        "d2n '" . Foswiki::Time::formatTime( $t, '$iso', 'servertime' ) . "'",
        eval    => $t,
        simpler => $t
    );
    $this->check( "d2n 'not a time'", eval => undef, simpler => 0 );
    $this->check( "d2n 0",            eval => undef, simpler => 0 );
    $this->check( "d2n notatime",     eval => undef );
    $this->check( "d2n ()",           eval => [],    simpler => '()' );
}

sub verify_num_bops {
    my $this = shift;
    $this->check( "number=99",   eval => 1 );
    $this->check( "99=99",       eval => 1, simpler => 1 );
    $this->check( "number=98",   eval => 0 );
    $this->check( "number!=99",  eval => 0 );
    $this->check( "number!=0",   eval => 1 );
    $this->check( "number<100",  eval => 1 );
    $this->check( "number<99",   eval => 0 );
    $this->check( "number>98",   eval => 1 );
    $this->check( "number>99",   eval => 0 );
    $this->check( "number<=99",  eval => 1 );
    $this->check( "number<=100", eval => 1 );
    $this->check( "number<=98",  eval => 0 );
    $this->check( "number>=98",  eval => 1 );
    $this->check( "number>=99",  eval => 1 );
    $this->check( "number>=100", eval => 0 );

    $this->check( "number=notafield",  eval => 0 );
    $this->check( "0=notafield",       eval => 0 );
    $this->check( "notafield=number",  eval => 0 );
    $this->check( "number!=notafield", eval => 1 );
    $this->check( "notafield!=number", eval => 1 );
    $this->check( "number>=notafield", eval => 1 );
    $this->check( "notafield>=number", eval => 0 );
    $this->check( "number<=notafield", eval => 0 );
    $this->check( "notafield<=number", eval => 1 );
    $this->check( "number>notafield",  eval => 1 );
    $this->check( "notafield>number",  eval => 0 );
    $this->check( "number<notafield",  eval => 0 );
    $this->check( "notafield<number",  eval => 1 );

    $this->check( "notafield=undefined", eval => 1 );
}

sub verify_boolean_bops {
    my $this = shift;

    $this->check( "1 AND 1", eval => 1, simpler => 1 );
    $this->check( "0 AND 1", eval => 0, simpler => 0 );
    $this->check( "1 AND 0", eval => 0, simpler => 0 );
    $this->check( "0 AND 0", eval => 0, simpler => 0 );

    $this->check( "1 OR 1", eval => 1, simpler => 1 );
    $this->check( "0 OR 1", eval => 1, simpler => 1 );
    $this->check( "1 OR 0", eval => 1, simpler => 1 );
    $this->check( "0 OR 0", eval => 0, simpler => 0 );

    $this->check( "number=99 AND string='String'", eval => 1 );
    $this->check( "number=98 AND string='String'", eval => 0 );
    $this->check( "number=99 AND string='Sring'",  eval => 0 );
    $this->check( "number=99 OR string='Spring'",  eval => 1 );
    $this->check( "number=98 OR string='String'",  eval => 1 );
    $this->check( "number=98 OR string='Spring'",  eval => 0 );

    $this->check( "notafield AND 1", eval => 0 );
    $this->check( "1 AND notafield", eval => 0 );
    $this->check( "0 AND notafield", eval => 0, simpler => 0 );
    $this->check( "notafield OR 1",  eval => 1, simpler => 1 );
    $this->check( "1 OR notafield",  eval => 1, simpler => 1 );
    $this->check( "notafield OR 0",  eval => 0 );
    $this->check( "0 OR notafield",  eval => 0 );
}

sub verify_match_fail {
    my $this = shift;
    $this->check( "'A'=~'B'", eval => 0, simpler => 0 );
}

sub verify_match_good {
    my $this = shift;
    $this->check( "'A'=~'A'", eval => 1, simpler => 1 );
}

sub verify_partial_match {
    my $this = shift;
    $this->check( "'AA'=~'A'", eval => 1, simpler => 1 );
}

sub verify_word_bound_match_good {
    my $this = shift;
    $this->check( "'foo bar baz'=~'\\bbar\\b'", eval => 1, simpler => 1 );
}

sub verify_word_bound_match_fail {
    my $this = shift;
    $this->check( "'foo bar baz'=~'\\bbam\\b'", eval => 0, simpler => 0 );
}

sub verify_word_end_match_fail {
    my $this = shift;
    $this->check( "'foob'=~'foo\\b'", eval => 0, simpler => 0 );
}

sub verify_ref {
    my $this = shift;
    $this->check( "'HitTopic'/number",    eval => 99, simpler => 99 );
    $this->check( "'HitTopic'/number=99", eval => 1,  simpler => 1 );
    $this->check(
        "'$this->{test_web}.HitTopic'/number=99",
        eval    => 1,
        simpler => 1
    );
    $this->check( "'NotATopic'/rev",    eval => undef, simpler => 0 );
    $this->check( "'NotATopic'/rev=23", eval => 0,     simpler => 0 );
}

sub test_backslash_match_fail {
    my $this = shift;
    $this->check(
        "' \\ '=~' \\\\ '",
        eval       => 0,
        syntaxOnly => 1,
        simpler    => 1
    );
}

sub test_backslash_match_good {
    my $this = shift;
    $this->check(
        "' \\\' '=~' \\\' '",
        eval       => 1,
        syntaxOnly => 1,
        simpler    => 1
    );
}

sub test_match_fields_longhand {
    my $this = shift;
    $this->check( "fields[name='string' AND value=~'^St.(i|n).*'].name!=''",
        eval => 1 );
}

sub test_nomatch_fields_longhand {
    my $this = shift;
    $this->check( "fields[name='string' AND value=~'^qSt.(i|n).*'].name!=''",
        eval => 0 );
}

sub test_match_field {
    my $this = shift;
    $this->check( "string=~'^St.(i|n).*'", eval => 1 );
}

sub test_match_lc_field {
    my $this = shift;
    $this->check(
        "'$this->{test_web}.HitTopic'/fields[NOT lc(name)=~'(s)'].name",
        eval => [qw(number boolean macro)]);
}

sub test_constant_strings {
    my $this = shift;
    my $in =
'n\nn t\tt s\\\\s q\\\'q o\\043o h\\x23h X\\x{7e}X \\b \\a \\e \\f \\r \\cX';

    $this->check( "'$in'=StringWithChars", eval => 1, syntaxOnly => 1 );
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
    $this->check( $expr, eval => $r );
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

sub verify_evaluatesToConstant {
    my $this = shift;

    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse("notafield AND 1");
    my $meta        = $this->{meta};

    $this->assert( !$query->evaluatesToConstant(), "non-constant" );
}

1;
