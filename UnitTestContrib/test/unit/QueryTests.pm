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
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki::Query::Parser;
use Foswiki::Query::Node;
use Foswiki::Func();

use constant MONITOR => 0;

my %qalgs;

sub new {
    my $self = shift()->SUPER::new( 'SEARCH', @_ );
    return $self;
}

sub skip {
    my ( $this, $test ) = @_;

    return $this->skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                'QueryTests::verify_atoms_empty' =>
                  'Empty expressions are broken in Foswiki 1.1',
                'QueryTests::verify_meta_dot_createinfo' =>
                  'META:CREATEINFO is introduced in Foswiki 1.2',
                'QueryTests::verify_array_integer_index' =>
                  'Multiple array indices are introduced in Foswiki 1.2',
                'QueryTests::verify_boolean_uop_list' =>
                  '() lists are introduced in Foswiki 1.2',
                'QueryTests::verify_string_uops_list' =>
                  '() lists are introduced in Foswiki 1.2',
                'QueryTests::verify_numeric_uops_post11' =>
                  'Numeric ops are introduced in Foswiki 1.2',
                'QueryTests::verify_string_bops_arithmetic' =>
'Arithmetic operations on strings are introduced in Foswiki 1.2',
                'QueryTests::verify_numeric_bops' =>
                  'Numeric ops are introduced in Foswiki 1.2',
                'QueryTests::verify_boolean_bop_in' =>
                  'IN operator is introduced in Foswiki 1.2',
                'QueryTests::verify_versions_on_other_topic' =>
                  'versions queries are introduced in Foswiki 1.2',
                'QueryTests::verify_versions_on_other_topic_fail' =>
                  'versions queries are introduced in Foswiki 1.2',
                'QueryTests::verify_versions_out_of_range' =>
                  'versions queries are introduced in Foswiki 1.2',
                'QueryTests::verify_versions_on_cur_topic' =>
                  'versions queries are introduced in Foswiki 1.2',
                'QueryTests::test_maths test_maths' =>
                  'Numeric ops are introduced in Foswiki 1.2',
                'QueryTests::verify_form_name_context' =>
                  'Bareword "FooForm" semantics were changed in Foswiki 1.2',
                'QueryTests::test_maths' =>
'Arithmetic operations on strings are introduced in Foswiki 1.2',
            }
        }
    );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);

    # Force pure perl text search; the query alg may map to a plain text
    # search, and we want to be sure we hit a good one.
    $Foswiki::cfg{Store}{SearchAlgorithm} =
      'Foswiki::Store::SearchAlgorithms::PurePerl';

    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'HitTopic' );
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
            author => 'AlbertCamus',
            date   => '12345',

            #	    format  => '1.1',
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
    $meta->putKeyed(
        'FIELD',
        {
            name  => "brace",
            title => "Brace",
            value => "Some text (really) we have text"
        }
    );
    $meta->putKeyed( 'FIELD',
        { name => 'SillyFuel', title => 'Silly fuel', value => 'Petrol' } );

    $meta->text("Quantum");
    $meta->save();

    # Copy to a new topic
    $meta->topic("AnotherTopic");
    $meta->save();

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'AnotherTopic', 1 );
    $meta->text("Singularity");
    $meta->putKeyed( 'FIELD',
        { name => 'SillyFuel', title => 'Silly fuel', value => 'Petroleum' } );
    $meta->save( forcenewrevision => 1 );
    $meta->text("Superintelligent shades of the colour blue");
    $meta->putKeyed( 'FIELD',
        { name => 'SillyFuel', title => 'Silly fuel', value => 'Diesel' } );
    $meta->save( forcenewrevision => 1 );

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'HitTopic', 1 );
    $meta->text("Green ideas sleep furiously");
    $meta->save( forcenewrevision => 1 );
    $this->{meta} = $meta;
}

sub fixture_groups {
    my (%qalgs);
    foreach my $dir (@INC) {
        if ( opendir( D, "$dir/Foswiki/Store/QueryAlgorithms" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ /^(\w*)\.pm$/;
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
    my \$this = shift;

    require Foswiki::Store::QueryAlgorithms::$alg;
    \$Foswiki::cfg{Store}{QueryAlgorithm} =
        'Foswiki::Store::QueryAlgorithms::$alg';
}
SUB
        die $@ if $@;
    }

    return \@groups;
}

sub loadExtraConfig {
    my $this    = shift;    # the Test::Unit::TestCase object
    my $context = shift;

    $this->SUPER::loadExtraConfig( $context, @_ );

#turn on the MongoDBPlugin so that the saved data goes into mongoDB
#This is temoprary until Crawford and I cna find a way to push dependencies into unit tests
    if ( $this->check_using('MongoDBPlugin') ) {
        $Foswiki::cfg{Plugins}{MongoDBPlugin}{Module} =
          'Foswiki::Plugins::MongoDBPlugin';
        $Foswiki::cfg{Plugins}{MongoDBPlugin}{Enabled}             = 1;
        $Foswiki::cfg{Plugins}{MongoDBPlugin}{EnableOnSaveUpdates} = 1;

#push(@{$Foswiki::cfg{Store}{Listeners}}, 'Foswiki::Plugins::MongoDBPlugin::Listener');
        $Foswiki::cfg{Store}{Listeners}
          {'Foswiki::Plugins::MongoDBPlugin::Listener'} = 1;
        require Foswiki::Plugins::MongoDBPlugin;
        Foswiki::Plugins::MongoDBPlugin::getMongoDB()
          ->remove( $this->{test_web}, 'current',
            { '_web' => $this->{test_web} } );
    }
}

# Check that the query expression $s parses, and that the result of evaluation is as expected.
# Options are:
# eval - the expected result of evaluate() (deep equals)
# fail - expect a parse failure, with this exception
# syntaxOnly - if set, don't try to fold or match
# match - if !syntaxOnly, list of topics expected to match
# simpler - if !syntaxOnly, what the expression should reduce to after constant folding
sub check {
    my ( $this, $s, %opts ) = @_;

    # First check the standard evaluator
    my $queryParser = new Foswiki::Query::Parser();
    my $query;
    eval { $query = $queryParser->parse($s); };
    if ($@) {
        if ( defined $opts{fail} ) {
            $this->assert_str_equals( $opts{fail}, $@ );
        }
        else {
            $this->assert( 0, $@ );
        }
    }
    return if defined $opts{fail};

    #use Data::Dumper;
    #print STDERR "query: $s\nresult: " . Data::Dumper::Dumper($query) . "\n";
    my ($meta) = $this->{meta};

    my $val = $query->evaluate( tom => $meta, data => $meta );
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
            print STDERR "before simplification: " . $query->stringify() . "\n"
              if MONITOR;
            $query->simplify( tom => $meta, data => $meta );
            print STDERR "after simplification: " . $query->stringify() . "\n"
              if MONITOR;
            print STDERR "after simplification: \n"
              . Data::Dumper::Dumper($query) . "\n"
              if MONITOR;
            $this->assert_str_equals( $opts{simpler}, $query->stringify(),
                $query->stringify() . " is not $opts{simpler}" );
        }
        elsif ( $query->evaluatesToConstant() ) {
            $this->assert( 0,
                $query->stringify() . " should not evaluate to a constant" );
        }

        # Next check the search algorithm
        my $expr =
"%SEARCH{\"$s\" type=\"query\" excludetopic=\"WebPreferences,$this->{test_topic},AnotherTopic\" nonoise=\"on\" format=\"\$topic\"}%";
        my $list = $this->{test_topicObject}->expandMacros($expr);
        if ( $opts{'eval'} || $opts{match} ) {
            $this->assert_str_equals( 'HitTopic', $list );
        }
        else {
            $this->assert_str_equals( '', $list );
        }
    }
}

sub verify_atoms {
    my $this = shift;
    $this->check( "'0'", eval => '0', simpler => '0' );
    $this->check( "''",  eval => '',  simpler => q{''} ); # Not 0 - See Item9971
    $this->check( "1",   eval => 1,   simpler => 1 );

    $this->check(
        "1.1965432e-3",
        eval    => 1.1965432e-3,
        simpler => 1.1965432e-3
    );
    $this->check( "number",    eval => 99 );
    $this->check( "text",      eval => "Green ideas sleep furiously" );
    $this->check( "string",    eval => 'String' );
    $this->check( "boolean",   eval => 1 );
    $this->check( "macro",     eval => '%RED%' );
    $this->check( "notafield", eval => undef );
}

# These tests were added by Crawford in Item10121; extracted from verify_items
# by PH in Item11456.
sub verify_atoms_empty {
    my $this = shift;
    $this->check( "",   eval => [], simpler => '()' );
    $this->check( "()", eval => [], simpler => '()' );
}

sub verify_meta_dot {
    my $this = shift;

#longhand to a topic that as more than one rev
#    my ($anotherTopic) = Foswiki::Func::readTopic($this->{test_web}, 'AnotherTopic' );
#    my $anotherTopicInfo = $anotherTopic->getRevisionInfo();
#    $this->check( "'AnotherTopic'/META:CREATEINFO.date",        eval => $anotherTopicInfo->{date} );
#return;

    $this->check( "META:FORM", eval => { name => 'TestForm' } );
    $this->check( "form",      eval => { name => 'TestForm' } );
    $this->check( "form.name", eval => 'TestForm' );
    $this->check( "META:FORM.name", eval => 'TestForm' );

    my $info = $this->{meta}->getRevisionInfo();
    $this->check( "info.date",     eval => $info->{date} );
    $this->check( "info.format",   eval => 1.1 );
    $this->check( "info.version",  eval => $info->{version} );
    $this->check( "info.author",   eval => $info->{author} );
    $this->check( "fields.number", eval => 99 );
    $this->check( "fields.string", eval => 'String' );

#$this->check( "notafield.string", eval => undef );  #crap, this fails on mongoDB because it just drops notafield

    #longhand
    $this->check( "META:TOPICINFO.date",    eval => $info->{date} );
    $this->check( "META:TOPICINFO.format",  eval => 1.1 );
    $this->check( "META:TOPICINFO.version", eval => $info->{version} );
    $this->check( "META:TOPICINFO.author",  eval => $info->{author} );

    #longhand to a topic that as more than one rev
    my ($anotherTopic) =
      Foswiki::Func::readTopic( $this->{test_web}, 'AnotherTopic' );
    my $anotherTopicInfo = $anotherTopic->getRevisionInfo();
    $this->check(
        "'AnotherTopic'/META:TOPICINFO.date",
        eval => $anotherTopicInfo->{date}
    );
    $this->check( "'AnotherTopic'/META:TOPICINFO.format", eval => 1.1 );
    $this->check(
        "'AnotherTopic'/META:TOPICINFO.version",
        eval => $anotherTopicInfo->{version}
    );
    $this->check(
        "'AnotherTopic'/META:TOPICINFO.author",
        eval => $anotherTopicInfo->{author}
    );

    #longhand to a topic that doesn't exist
    $this->check(
        "'DoesNotExist'/META:TOPICINFO.date",
        syntaxOnly => 1,
        eval       => undef
    );
    $this->check(
        "'DoesNotExist'/META:TOPICINFO.format",
        syntaxOnly => 1,
        eval       => undef
    );
    $this->check(
        "'DoesNotExist'/META:TOPICINFO.version",
        syntaxOnly => 1,
        eval       => undef
    );
    $this->check(
        "'DoesNotExist'/META:TOPICINFO.author",
        syntaxOnly => 1,
        eval       => undef
    );

}

sub verify_meta_dot_createinfo {
    my $this = shift;
    my ($anotherTopic) =
      Foswiki::Func::readTopic( $this->{test_web}, 'AnotherTopic' );
    my $anotherTopicInfo = $anotherTopic->getRevisionInfo();

    $anotherTopic->getRev1Info('createdate');
    my $anotherTopicInfoRev1 = $anotherTopic->{_getRev1Info}->{rev1info};
    $this->check(
        "'AnotherTopic'/META:CREATEINFO.date",
        eval => $anotherTopicInfoRev1->{date}
    );

 #interestingly, format is not compulsory
 #    $this->check( "'AnotherTopic'/META:CREATEINFO.format",      eval => 1.1 );
    $this->check(
        "'AnotherTopic'/META:CREATEINFO.version",
        eval => $anotherTopicInfoRev1->{version}
    );
    $this->check(
        "'AnotherTopic'/META:CREATEINFO.author",
        eval => $anotherTopicInfoRev1->{author}
    );

    $this->assert(
        $anotherTopicInfoRev1->{version} < $anotherTopicInfo->{version},
        $anotherTopicInfoRev1->{version} . ' < ' . $anotherTopicInfo->{version}
    );
}

sub verify_array_integer_index {
    my $this = shift;

 #    $this->check( "preferences[0].name", eval => 'Red' );
 #    $this->check( "preferences[1]", eval => { name => 'Green', value => 1 } );
 #    $this->check( "preferences[2].name", eval => 'Blue' );
 #    $this->check( "preferences[3].name", eval => 'White' );
 #    $this->check( "preferences[4].name", eval => 'Yellow' );
 #
 #    # Integer part used as the index
 #    $this->check( "preferences[1.9].name", eval => 'Green' );
 #
 #    # From-the-end indices
 #    $this->check( "preferences[-1].name", eval => 'Yellow' );
 #    $this->check( "preferences[-2].name", eval => 'White' );
 #    $this->check( "preferences[-3].name", eval => 'Blue' );
 #    $this->check( "preferences[-4].name", eval => 'Green' );
 #    $this->check( "preferences[-5].name", eval => 'Red' );
 #
 #    # Out-of-range indices
 #    $this->check( "preferences[5]",  eval => undef );
 #    $this->check( "preferences[-6]", eval => undef );

    # Range of indices using commas
    $this->check( "preferences[0,2,4].name",
        eval => [ 'Red', 'Blue', 'Yellow' ] );
    $this->check( "preferences[2,-1,0].name",
        eval => [ 'Blue', 'Yellow', 'Red' ] );
    $this->check( "preferences[-1,name='White'].name",
        eval => [ 'Yellow', 'White' ] );
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

sub verify_boolean_uops {
    my $this = shift;
    $this->check( "not number",    eval => 0 );
    $this->check( "not boolean",   eval => 0 );
    $this->check( "not 0",         eval => 1, simpler => 1 );
    $this->check( "not notafield", eval => 1 );
}

sub verify_boolean_uop_list {
    my $this = shift;
    $this->check( "not ()", eval => [], simpler => '()' );
}

sub verify_string_uops {
    my $this = shift;
    $this->check( "uc string",      eval => 'STRING' );
    $this->check( "uc(string)",     eval => "STRING" );
    $this->check( "lc string",      eval => 'string' );
    $this->check( "lc(notafield)",  eval => undef );
    $this->check( "lc notafield",   eval => undef );
    $this->check( "uc 'string'",    eval => 'STRING', simpler => "'STRING'" );
    $this->check( "uc (notafield)", eval => undef );
    $this->check( "uc notafield",   eval => undef );
    $this->check( "lc 'STRING'",    eval => 'string', simpler => "'string'" );
    $this->check( "length attachments",     eval => 2 );
    $this->check( "length META:PREFERENCE", eval => 5 );
    $this->check( "length 'five'",          eval => 4, simpler => 4 );
    $this->check( "length info",            eval => 5 );
    $this->check( "length (info)",          eval => 5 );
    $this->check( "length notafield",       eval => 0 );

    $this->check( "brace",         eval => 'Some text (really) we have text' );
    $this->check( "lc(brace)",     eval => 'some text (really) we have text' );
    $this->check( "uc(brace)",     eval => 'SOME TEXT (REALLY) WE HAVE TEXT' );
    $this->check( "length(brace)", eval => 31 );
}

sub verify_string_uops_list {
    my $this = shift;
    $this->check( "uc ()",     eval => [], simpler => '()' );
    $this->check( "lc ()",     eval => [], simpler => '()' );
    $this->check( "length ()", eval => 0,  simpler => 0 );
}

sub verify_numeric_uops_post11 {
    my $this = shift;
    $this->check( "-()", eval => [], simpler => "()" );
    $this->check( "-1",  eval => -1, simpler => -1 );
    $this->check( "--1", eval => 1,  simpler => 1 );

    $this->check( "int 1.5",  eval => 1,  simpler => 1 );
    $this->check( "int -1.5", eval => -1, simpler => -1 );
    $this->check( "int ()",   eval => [], simpler => "()" );
    $this->check( "int notafield", eval => undef );
    $this->check( "int 'foo'",     eval => 0, simpler => 0 );
    $this->check( "d2n ()",        eval => [], simpler => '()' );
}

sub verify_numeric_uops {
    my $this = shift;

    # Item10645 (?) GC checked into Release01x01:
    my $dst = ( localtime(time) )[8];
    my $zeroTime = ($dst) ? 3600 : 0;

    $this->check(
        "d2n '"
          . Foswiki::Time::formatTime( $zeroTime, '$iso', 'servertime' ) . "'",

        # Item10645 (?), prior to GC checkin Foswikirev:11117:
        # $this->check(
        #   "d2n '" . Foswiki::Time::formatTime( 0, '$iso', 'gmtime' ) . "'",
        eval    => 0,
        simpler => 0
    );
    my $t = time;
    $this->check(
        "d2n '" . Foswiki::Time::formatTime( $t, '$iso', 'gmtime' ) . "'",
        eval    => $t,
        simpler => $t,
    );
    $this->check( "d2n 'not a time'", eval => undef, simpler => 0 );
    $this->check( "d2n 0",            eval => undef, simpler => 0 );
    $this->check( "d2n notatime",     eval => undef );
}

sub verify_string_bops {
    my $this = shift;
    $this->check( "string='String'",                eval => 1 );
    $this->check( "string='String '",               eval => 0 );
    $this->check( "string~'String '",               eval => 0 );
    $this->check( "string~notafield",               eval => 0 );
    $this->check( "notafield=~'SomeTextToTestFor'", eval => 0 );
    $this->check( "string!=notafield",              eval => 1 );
    $this->check( "string=notafield",               eval => 0 );
    $this->check( "string='Str'",                   eval => 0 );
    $this->check( "string~'?trin?'",                eval => 1 );
    $this->check( "string~'*'",                     eval => 1 );
    $this->check( "string~'*String'",               eval => 1 );
    $this->check( "string~'*trin*'",                eval => 1 );
    $this->check( "string~'*in?'",                  eval => 1 );
    $this->check( "string~'*ri?'",                  eval => 0 );
    $this->check( "string~'??????'",                eval => 1 );
    $this->check( "string~'???????'",               eval => 0 );
    $this->check( "string~'?????'",                 eval => 0 );
    $this->check( "'SomeTextToTestFor'~'Text'",     eval => 0, simpler => 0 );
    $this->check( "'SomeTextToTestFor'~'*Text'",    eval => 0, simpler => 0 );
    $this->check( "'SomeTextToTestFor'~'Text*'",    eval => 0, simpler => 0 );
    $this->check( "'SomeTextToTestFor'~'*Text*'",   eval => 1, simpler => 1 );
    $this->check( "string!='Str'",                  eval => 1 );
    $this->check( "string!='String '",              eval => 1 );
    $this->check( "string!='String'",               eval => 0 );
    $this->check( "string!='string'",               eval => 1 );
    $this->check( "string='string'",                eval => 0 );
    $this->check( "macro='\%RED\%'", eval => 1, syntaxOnly => 1 );
    $this->check( "macro~'\%RED?'", eval => 1, syntaxOnly => 1 );
    $this->check( "macro~'?RED\%'", eval => 1, syntaxOnly => 1 );
    $this->check( "macro~'?RED\%'", eval => 1, syntaxOnly => 1 );
}

sub verify_string_bops_arithmetic {
    my $this = shift;
    $this->check( "string+notafield", eval => 'String' );
    $this->check(
        "'string'+'string'",
        eval    => 'stringstring',
        simpler => "'stringstring'"
    );
    $this->check( "'string'+1", eval => 'string1', simpler => "'string1'" );
    $this->check( "1+'string'", eval => '1string', simpler => "'1string'" );
}

sub verify_constants {
    my $this = shift;
    $this->check( "undefined",           eval => undef );
    $this->check( "undefined=undefined", eval => 1 )
      ;    #TODO: should really be able to simplify to '1'
    $this->check( "brace=undefined",        eval => 0 );
    $this->check( "NoFieldThere=undefined", eval => 1 );
    $this->check( "now",                    eval => time );
    $this->check( "number<now",             eval => 1 );
    $this->check( "now>number",             eval => 1 );
    $this->check( "now=now",                eval => 1 );
}

sub verify_boolean_corner_cases {
    my $this = shift;
    $this->check( "not not ''", eval => 0,  simpler => 0 );
    $this->check( "0",          eval => 0,  simpler => 0 );
    $this->check( "''",         eval => '', simpler => "''" );
}

sub verify_numeric_bops {
    my $this = shift;
    $this->check( "1+1", eval => 2, simpler => 2 );
    $this->check( "1+notafield",                 eval => 1 );
    $this->check( "2-1",                         eval => 1, simpler => 1 );
    $this->check( "2-notafield",                 eval => 2 );
    $this->check( "2*2",                         eval => 4, simpler => 4 );
    $this->check( "2*notafield",                 eval => undef );
    $this->check( "4 div 2",                     eval => 2, simpler => 2 );
    $this->check( "4 div 0",                     fail => 1 );
    $this->check( "4 div notafield",             fail => 1 );
    $this->check( "notafield div 2",             eval => 0 );
    $this->check( "notafield div 0",             fail => 1 );
    $this->check( "notafield div alsonotafield", fail => 1 );
    $this->check( "'foo' div 2",                 eval => 0, simpler => 0 );
    $this->check( "2 div 'bar'",                 fail => 1 );
    $this->check( "'foo' div 'bar'",             fail => 1 );
}

sub verify_boolean_bops {
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
    $this->check( "1='1'",           eval => 1, simpler => 1 );
    $this->check( "''='0'",          eval => 0, simpler => 0 );
    $this->check( "0=''",            eval => 0, simpler => 0 );
    $this->check( "''=0",            eval => 0, simpler => 0 );
}

sub verify_boolean_bop_in {
    my $this = shift;

    $this->check( "1 in 1",       eval => 1, simpler => 1 );
    $this->check( "1 in 0",       eval => 0, simpler => 0 );
    $this->check( "0 in 1",       eval => 0, simpler => 0 );
    $this->check( "2 in (1,2,3)", eval => 1, simpler => 1 );
    $this->check( "4 in (1,2,3)", eval => 0, simpler => 0 );
    $this->check( "4 in ()",      eval => 0, simpler => 0 );

    $this->check( "'a' in 'a'",           eval => 1, simpler => 1 );
    $this->check( "'a' in 'b'",           eval => 0, simpler => 0 );
    $this->check( "'a' in ''",            eval => 0, simpler => 0 );
    $this->check( "'' in 'a'",            eval => 0, simpler => 0 );
    $this->check( "'b' in ('a','b','c')", eval => 1, simpler => 1 );
    $this->check( "'d' in ('a','b','c')", eval => 0, simpler => 0 );
    $this->check( "'d' in ()",            eval => 0, simpler => 0 );
}

sub verify_match_fail {
    my $this = shift;
    $this->check( "'A'=~'B'", eval => 0, simpler => 0 );
}

sub verify_match_ok_brace {
    my $this = shift;
    $this->check(
        "fields[name~'*' AND value=~'\\(']",
        eval => [
            {
                value => 'Some text (really) we have text',
                name  => 'brace',
                title => 'Brace'
            }
        ]
    );
}

sub verify_match_fail_brace {
    my $this = shift;
    $this->check(
        "fields[name~'*' AND value=~'(']",
        fail => "Illegal regular expression in '('"
    );
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
    $this->check( "'AnotherTopic'/number",    eval => 99, simpler => 99 );
    $this->check( "'AnotherTopic'/number=99", eval => 1,  simpler => 1 );
    $this->check(
        "'$this->{test_web}.AnotherTopic'/number=99",
        eval    => 1,
        simpler => 1
    );
    $this->check(
        "'$this->{test_web}.AnotherTopic'/number=99",
        eval    => 1,
        simpler => 1
    );
    $this->check( "'NotATopic'/rev",    eval => undef, simpler => 0 );
    $this->check( "'NotATopic'/rev=23", eval => 0,     simpler => 0 );
}

sub verify_versions_on_other_topic {
    my $this = shift;
    $this->check( "'AnotherTopic'/versions[0].text",
        eval => "Superintelligent shades of the colour blue" );
    $this->check( "'AnotherTopic'/versions[2].text",  eval => "Quantum" );
    $this->check( "'AnotherTopic'/versions[-1].text", eval => "Quantum" );
    $this->check( "'AnotherTopic'/versions[-2].text", eval => "Singularity" );
    $this->check(
        "'AnotherTopic'/versions.text",
        eval => [
            "Superintelligent shades of the colour blue", "Singularity",
            "Quantum"
        ]
    );
    $this->check(
        "'AnotherTopic'/versions[text =~ 'blue'].text",
        eval => "Superintelligent shades of the colour blue"
    );
    $this->check( "'AnotherTopic'/versions[SillyFuel~'Petrol*'].SillyFuel",
        eval => [qw(Petroleum Petrol)] );
    $this->check( "'AnotherTopic'/versions[0].SillyFuel", eval => 'Diesel' );
    $this->check(
        "'AnotherTopic'/versions.SillyFuel",
        eval => [qw(Diesel Petroleum Petrol)]
    );

    return;
}

sub verify_versions_on_other_topic_fail {
    my $this = shift;

    # These aren't working :( - PH
    $this->expect_failure(
        'Item10121: OP_ref does\'nt play nice with versions queries');
    $this->check( "'AnotherTopic'/versions.META:FIELD[name='SillyFuel'].value",
        eval => [qw(Diesel Petroleum Petrol)] );
    $this->check( "'AnotherTopic'/versions[META:FIELD.name='SillyFuel'].value",
        eval => [qw(Diesel Petroleum Petrol)] );
}

sub verify_versions_out_of_range {
    my $this = shift;
    $this->check( "'AnotherTopic'/versions[-4]", eval => undef, simpler => 0 );
    $this->check( "'AnotherTopic'/versions[4]",  eval => undef, simpler => 0 );
}

sub verify_versions_on_cur_topic {
    my $this = shift;
    $this->check( "versions[0].text", eval => "Green ideas sleep furiously" );
    $this->check( "versions[1].text", eval => "Quantum" );
    $this->check( "versions[info.version=1].text", eval => "Quantum" );
    $this->check( "versions.text",
        eval => [ "Green ideas sleep furiously", "Quantum" ] );
    $this->check( "versions[text =~ 'Green'].text",
        , eval => "Green ideas sleep furiously" );
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

    $this->expect_failure( "in Javascript/MongoDB, undef != ''",
        using => 'MongoDBPlugin' );
    $this->check( "fields[name='string' AND value=~'^qSt.(i|n).*'].name!=''",
        eval => 0 );
}

sub test_match_field {
    my $this = shift;
    $this->check( "string=~'^St.(i|n).*'", eval => 1 );
}

sub test_match_lc_field {
    my $this = shift;

    $this->expect_failure(
'This test should be made to work on Foswiki 1.1, but it doesn\'t, Item11456',
        with_dep => 'Foswiki,<,1.2'
    );
    $this->check(
        "'$this->{test_web}.HitTopic'/fields",
        eval => [
            { value => 99,       name => 'number', title => 'Number' },
            { value => 'String', name => 'string', title => 'String' },
            {
                value =>
                  "n\nn t\tt s\\s q'q o#o h#h X~X \\b \\a \\e \\f \\r \\cX",
                name  => 'StringWithChars',
                title => 'StringWithChars'
            },
            { value => 1,       name => 'boolean', title => 'Boolean' },
            { value => '%RED%', name => 'macro' },
            {
                value => 'Some text (really) we have text',
                name  => 'brace',
                title => 'Brace'
            },
            { value => 'Petrol', name => 'SillyFuel', title => 'Silly fuel' }
        ],
        simpler =>
',{value=>99,name=>number,title=>Number,,{value=>String,name=>string,title=>String,,{value=>n'
          . "\n"
          . 'n t	t s\s q\'q o#o h#h X~X \b \a \e \f \r \cX,name=>StringWithChars,title=>StringWithChars,,{value=>1,name=>boolean,title=>Boolean,,{value=>%RED%,name=>macro,,{value=>Some text (really) we have text,name=>brace,title=>Brace,value=>Petrol,name=>SillyFuel,title=>Silly fuel}}}}}}'
    );

    $this->check(
        "'$this->{test_web}.HitTopic'/fields[NOT lc(name)=~'(s)'].name",
        eval => [qw(number boolean macro brace)] );
}

sub test_match_lc_field_simple {
    my $this = shift;
    $this->check(
        "'$this->{test_web}.HitTopic'/fields[NOT lc(name)=~'(s)'].name",
        eval => [qw(number boolean macro brace)] );
}

sub test_maths {
    my $this        = shift;
    my $queryParser = new Foswiki::Query::Parser();
    my $query       = $queryParser->parse("1+2*-3+4 div 2 + div");
    $this->assert_equals( "+{+{+{1,*{2,-{3}}},div{4,2}},div}",
        $query->stringify() );
    $query = $queryParser->parse("(-1+2*-3+4 div 2)");
    $this->assert_equals( ( -1 + 2 * -3 + 4 / 2 ), $query->evaluate() );
    $query = $queryParser->parse("int 1.5");
    $this->assert_equals( 1, $query->evaluate() );
    $query = $queryParser->parse("1,2,3");
    $this->assert_deep_equals( [ 1, 2, 3 ], $query->evaluate() );
    $query = $queryParser->parse("2 in (1,2,3)");
    $this->assert( $query->evaluate() );
    $query = $queryParser->parse("4 in (1,2,3)");
    $this->assert( !$query->evaluate() );
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
    my ($meta)      = $this->{meta};

    $this->assert( !$query->evaluatesToConstant(), "non-constant" );
}

sub test_regex_name {
    my $this = shift;
    my $expr =
"%SEARCH{\"name~'Hit*'\" type=\"query\" nonoise=\"on\" format=\"\$topic\"}%";
    my $list = $this->{test_topicObject}->expandMacros($expr);
    $this->assert_str_equals( 'HitTopic', $list );
}

sub verify_string_bops_with_mods {
    my $this = shift;
    $this->check( "uc(string)='String'", eval => 0 );
    $this->check( "uc(string)='STRING'", eval => 1 );

    $this->check( "string=uc('String')", eval => 0 );
    $this->check( "string=('String')",   eval => 1 );

    $this->check( "'String'=uc(string)", eval => 0 );
    $this->check( "'STRING'=uc(string)", eval => 1 );

    $this->check( "uc('String')=string", eval => 0 );
    $this->check( "('String')=string",   eval => 1 );

}

sub verify_long_or {
    my $this = shift;
    my $text = "0";

    # make this at least 100 deep to trigger recursion traps
    for ( my $i = 202 ; $i > 98 ; $i-- ) {
        $text .= " OR 0";
    }
    $text .= " OR 1";
    $this->check( $text, eval => 1, simpler => 1 );
}

# Crawford added this test in Item10520, expect_fail for 1.1 added by PH
sub verify_form_name_context {
    my $this = shift;
    $this->check( "TestForm", eval => undef );
    $this->check( "TestForm[title='Number']",
        eval => [ { value => 99, name => 'number', title => 'Number' } ] );
    $this->check( "TestForm.number", eval => 99 );
}

1;
