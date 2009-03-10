package RenameTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::UI::Rename;
use Error ':try';

my $notawwtopic1 = "random";
my $notawwtopic2 = "Random";
my $notawwtopic3 = "ranDom";
my $debug        = 0;
my $UI_FN;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $UI_FN ||= $this->getUIFn('rename');

    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login},
        new Unit::Request( { topic => "/$this->{test_web}/OldTopic" } ) );

    $this->{new_web} = $this->{test_web} . 'New';
    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{new_web} );
    $webObject->populateNewWeb();
    $Foswiki::Plugins::SESSION = $this->{session};

    my $originaltext = <<THIS;
1 $this->{test_web}.OldTopic
$this->{test_web}.OldTopic 2
3 $this->{test_web}.OldTopic more
OldTopic 4
5 OldTopic
7 (OldTopic)
8 [[$this->{test_web}.OldTopic]]
9 [[OldTopic]]
10 [[$this->{test_web}.OldTopic][the text]]
11 [[OldTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{test_web}/OldTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{test_web}.OldTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
</noautolink>
THIS

    foreach my $topic ( 'OldTopic', 'OtherTopic', 'random', 'Random', 'ranDom' )
    {
        my $meta =
          Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );
        $meta->putKeyed(
            'FIELD',
            {
                name  => $this->{test_web},
                value => $this->{test_web}
            }
        );
        $meta->putKeyed(
            'FIELD',
            {
                name  => "$this->{test_web}.OldTopic",
                value => "$this->{test_web}.OldTopic"
            }
        );
        $meta->putKeyed(
            'FIELD',
            {
                name  => 'OldTopic',
                value => 'OldTopic'
            }
        );
        $meta->putKeyed(
            'FIELD',
            {
                name  => "OLD",
                value => "$this->{test_web}.OldTopic"
            }
        );
        $meta->putKeyed(
            'FIELD',
            {
                name  => "NEW",
                value => "$this->{new_web}.NewTopic"
            }
        );
        $meta->put( "TOPICPARENT", { name => "$this->{test_web}.OldTopic" } );
        $meta =
          Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic,
            $originaltext, $meta );
        $meta->save();
    }

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'OtherTopic' );
    $meta->putKeyed(
        'FIELD',
        {
            name  => $this->{test_web},
            value => $this->{test_web}
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name  => "$this->{test_web}.OldTopic",
            value => "$this->{test_web}.OldTopic"
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name  => 'OldTopic',
            value => 'OldTopic'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name  => "OLD",
            value => "$this->{test_web}.OldTopic"
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name  => "NEW",
            value => "$this->{new_web}.NewTopic"
        }
    );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.OldTopic" } );
    $meta->text($originaltext);
    $meta->save();

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web},
        $Foswiki::cfg{HomeTopicName}, 'junk' );
    $topicObject->save();
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture( $this->{session}, $this->{new_web} );
    $this->SUPER::tear_down();
}

sub check {
    my ( $this, $web, $topic, $emeta, $expected, $num ) = @_;
    my $meta   = Foswiki::Meta->load( $this->{session}, $web, $topic );
    my $actual = $meta->text;
    my @old    = split( /\n+/, $expected );
    my @new    = split( /\n+/, $actual );

    while ( scalar(@old) ) {
        my $o = "$num: " . shift(@old);
        my $n = "$num: " . shift(@new);
        $this->assert_str_equals( $o, $n,
            "Expect $o\nActual $n\n" . join( ",", caller ) );
    }
}

sub checkReferringTopics {
    my ( $this, $web, $topic, $all, $expected, $forgiving ) = @_;

    my $m = Foswiki::Meta->new( $this->{session}, $web, $topic );
    my $refs =
      Foswiki::UI::Rename::_getReferringTopics( $this->{session}, $m, $all );
    $this->assert_str_equals( 'HASH', ref($refs) );
    if ($forgiving) {
        foreach my $k ( keys %$refs ) {
            unless ( $k =~ /^$this->{test_web}/ ) {
                delete( $refs->{$k} );
            }
        }
    }

    my %expected_but_unseen;
    my %e = map { $_ => 1 } @$expected;
    foreach my $r ( keys %e ) {
        unless ( $refs->{$r} ) {
            $expected_but_unseen{$r} = 1;
        }
    }
    my %not_expected;
    foreach my $r ( keys %$refs ) {
        $this->assert_not_null($r);
        unless ( $e{$r} ) {
            $not_expected{$r} = 1;
        }
    }

    $this->assert_equals(
        0,
        scalar( keys %not_expected ),
        join( ' ', keys %not_expected )
    );
    $this->assert_equals(
        0,
        scalar( keys %expected_but_unseen ),
        join( ' ', keys %expected_but_unseen )
    );

    my $i = scalar( keys %$refs );
    my @e = sort @$expected;
    my $j = scalar(@e);
    my @r = sort keys %$refs;
    while ( --$i >= 0 && scalar(@e) ) {
        my $e = $e[ --$j ];
        while ( $i >= 0 && $r[$i] ne $e ) {
            $i--;
        }
        $this->assert_str_equals( $e, $r[$i],
                "Mismatch expected\n"
              . join( ',', @e )
              . " got\n"
              . join( ',', @r ) );
    }
    $this->assert_equals( 0, $j );
}

# Test references to a topic in this web
sub test_referringTopicsThisWeb {
    my $this = shift;
    my $ott  = 'Old Topic';
    my $lott = lc($ott);
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeOne',
        <<THIS );
[[$ott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeTwo',
        <<THIS );
[[$lott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'MatchMeThree',
        <<THIS );
[[$this->{test_web}.$ott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'MatchMeFour',
        <<THIS );
[[$this->{test_web}.$lott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'NoMatch',
        <<THIS );
Refer to $ott and $lott
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'NoMatch',
        <<THIS );
Refer to $ott and $lott
THIS
    $topicObject->save();

    # Just Web
    $this->checkReferringTopics(
        $this->{test_web},
        'OldTopic',
        0,
        [
            "$this->{test_web}.OtherTopic", "$this->{test_web}.MatchMeOne",
            "$this->{test_web}.MatchMeTwo", "$this->{test_web}.random",
            "$this->{test_web}.Random",     "$this->{test_web}.ranDom"
        ]
    );
}

# Test references to a topic in all webs
# Warning; this is a bit of a lottery, as you might have webs that refer
# to the topic outside the test set. For this reason the test is forgiving
# if a ref outside of the test webs is found.
sub test_referringTopicsAllWebs {
    my $this = shift;
    my $ott  = 'Old Topic';
    my $lott = lc($ott);
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeOne',
        <<THIS );
[[$ott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeTwo',
        <<THIS );
[[$lott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'MatchMeThree',
        <<THIS );
[[$this->{test_web}.$ott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'MatchMeFour',
        <<THIS );
[[$this->{test_web}.$lott]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'NoMatch',
        <<THIS );
Refer to $ott and $lott
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{new_web}, 'NoMatch',
        <<THIS );
Refer to $ott and $lott
THIS
    $topicObject->save();

    # All webs
    $this->checkReferringTopics(
        $this->{test_web},
        'OldTopic',
        1,
        [
            "$this->{new_web}.OtherTopic", "$this->{new_web}.MatchMeThree",
            "$this->{new_web}.MatchMeFour",
        ],
        1
    );
}

# Test references to a topic in this web, where the topic is not a wikiword
sub test_referringTopicsNotAWikiWord {
    my $this = shift;
    my $ott  = 'ranDom';
    my $lott = lc($ott);
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeOne',
        <<THIS );
random random random
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeTwo',
        <<THIS );
ranDom ranDom ranDom
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeThree',
        <<THIS );
Random Random Random
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeFour',
        <<THIS );
RanDom RanDom RanDom
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeFive',
        <<THIS );
[[random]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeSix',
        <<THIS );
[[ranDom]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeSeven',
        <<THIS );
[[Random]]
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'MatchMeEight',
        <<THIS );
[[RanDom]]
THIS
    $topicObject->save();

    $this->checkReferringTopics(
        $this->{test_web},
        'random', 0,
        [
            "$this->{test_web}.MatchMeFive", "$this->{test_web}.OldTopic",
            "$this->{test_web}.OtherTopic",  "$this->{test_web}.Random",
            "$this->{test_web}.ranDom"
        ]
    );
    $this->checkReferringTopics(
        $this->{test_web},
        'ranDom', 0,
        [
            "$this->{test_web}.MatchMeSix", "$this->{test_web}.OldTopic",
            "$this->{test_web}.OtherTopic", "$this->{test_web}.Random",
            "$this->{test_web}.random"
        ]
    );
    $this->checkReferringTopics(
        $this->{test_web},
        'Random', 0,
        [
            "$this->{test_web}.MatchMeSeven", "$this->{test_web}.OldTopic",
            "$this->{test_web}.OtherTopic",   "$this->{test_web}.random",
            "$this->{test_web}.ranDom"
        ]
    );
}

# Rename OldTopic to NewTopic within the same web
sub test_rename_oldwebnewtopic {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action           => ['rename'],
            newweb           => [ $this->{test_web} ],
            newtopic         => ['NewTopic'],
            referring_topics => [
                "$this->{test_web}.NewTopic", "$this->{test_web}.OtherTopic",
                "$this->{new_web}.OtherTopic"
            ],
            topic => 'OldTopic'
        }
    );

    $this->{session}->finish();

    # The topic in the path should not matter
    $query->path_info("/$this->{test_web}/SanityCheck");
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->capture( \&$UI_FN, $this->{session} );

    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, 'NewTopic' ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, 'OldTopic' ) );
    $this->check( $this->{test_web}, 'NewTopic', undef, <<THIS, 1 );
1 $this->{test_web}.NewTopic
$this->{test_web}.NewTopic 2
3 $this->{test_web}.NewTopic more
NewTopic 4
5 NewTopic
7 (NewTopic)
8 [[$this->{test_web}.NewTopic]]
9 [[NewTopic]]
10 [[$this->{test_web}.NewTopic][the text]]
11 [[NewTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{test_web}/NewTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{test_web}.NewTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
</noautolink>
THIS
    $this->check( $this->{test_web}, 'OtherTopic', undef, <<THIS, 2 );
1 $this->{test_web}.NewTopic
$this->{test_web}.NewTopic 2
3 $this->{test_web}.NewTopic more
NewTopic 4
5 NewTopic
7 (NewTopic)
8 [[$this->{test_web}.NewTopic]]
9 [[NewTopic]]
10 [[$this->{test_web}.NewTopic][the text]]
11 [[NewTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{test_web}/NewTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{test_web}.NewTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
</noautolink>
THIS

    $this->check( $this->{new_web}, 'OtherTopic', undef, <<THIS, 3 );
1 $this->{test_web}.NewTopic
$this->{test_web}.NewTopic 2
3 $this->{test_web}.NewTopic more
$this->{test_web}.NewTopic 4
5 $this->{test_web}.NewTopic
7 ($this->{test_web}.NewTopic)
8 [[$this->{test_web}.NewTopic]]
9 [[$this->{test_web}.NewTopic]]
10 [[$this->{test_web}.NewTopic][the text]]
11 [[$this->{test_web}.NewTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{test_web}/NewTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{test_web}.NewTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
</noautolink>
THIS
}

# Rename OldTopic to a different web, keeping the same topic name
sub test_rename_newweboldtopic {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            action           => ['rename'],
            newweb           => [ $this->{new_web} ],
            newtopic         => ['OldTopic'],
            referring_topics => [
                "$this->{test_web}.OtherTopic", "$this->{new_web}.OldTopic",
                "$this->{new_web}.OtherTopic"
            ],
            topic => 'OldTopic'
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->capture( $UI_FN, $this->{session} );

    $this->assert(
        $this->{session}->topicExists( $this->{new_web}, 'OldTopic' ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, 'OldTopic' ) );

    $this->check( $this->{new_web}, 'OldTopic', undef, <<THIS, 4 );
1 $this->{new_web}.OldTopic
$this->{new_web}.OldTopic 2
3 $this->{new_web}.OldTopic more
OldTopic 4
5 OldTopic
7 (OldTopic)
8 [[$this->{new_web}.OldTopic]]
9 [[OldTopic]]
10 [[$this->{new_web}.OldTopic][the text]]
11 [[OldTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 $this->{test_web}.OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{new_web}/OldTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{new_web}.OldTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
</noautolink>
THIS
    $this->check( $this->{new_web}, 'OtherTopic', undef, <<THIS, 5 );
1 $this->{new_web}.OldTopic
$this->{new_web}.OldTopic 2
3 $this->{new_web}.OldTopic more
OldTopic 4
5 OldTopic
7 (OldTopic)
8 [[$this->{new_web}.OldTopic]]
9 [[OldTopic]]
10 [[$this->{new_web}.OldTopic][the text]]
11 [[OldTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{new_web}/OldTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{new_web}.OldTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
</noautolink>
THIS

    $this->check( $this->{test_web}, 'OtherTopic', undef, <<THIS, 6 );
1 $this->{new_web}.OldTopic
$this->{new_web}.OldTopic 2
3 $this->{new_web}.OldTopic more
$this->{new_web}.OldTopic 4
5 $this->{new_web}.OldTopic
7 ($this->{new_web}.OldTopic)
8 [[$this->{new_web}.OldTopic]]
9 [[$this->{new_web}.OldTopic]]
10 [[$this->{new_web}.OldTopic][the text]]
11 [[$this->{new_web}.OldTopic][the text]]
12 $this->{test_web}.NewTopic
13 $this->{new_web}.OldTopic
14 OtherTopic
15 $this->{test_web}.OtherTopic
16 $this->{new_web}.OtherTopic
17 MeMeOldTopicpick$this->{test_web}.OldTopicme
18 http://site/$this->{new_web}/OldTopic
19 [[http://blah/OldTopic/blah][ref]]
20 random Random ranDom
21 $this->{test_web}.random $this->{test_web}.Random $this->{test_web}.ranDom
<verbatim>
protected $this->{test_web}.OldTopic
</verbatim>
<pre>
pre $this->{new_web}.OldTopic
</pre>
<noautolink>
protected $this->{test_web}.OldTopic
</noautolink>
THIS
}

# Purpose:  Rename a topic which starts with a lowercase letter
# Verifies:
#    * Return status is a redirect
#    * New script is view, not oops
#    * New topic name is changed
#    * In the new topic, the initial letter is changed to upper case
sub test_rename_from_lowercase {
    my $this      = shift;
    my $topictext = <<THIS;
One lowercase
Twolowercase
[[lowercase]]
THIS
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'lowercase',
        $topictext );
    $topicObject->save();
    my $query = new Unit::Request(
        {
            action           => 'rename',
            topic            => 'lowercase',
            newweb           => $this->{test_web},
            newtopic         => 'upperCase',
            referring_topics => ["$this->{test_web}.NewTopic"],
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my ( $text, $result ) = $this->capture( \&$UI_FN, $this->{session} );
    my $ext = $Foswiki::cfg{ScriptSuffix};
    $this->assert_matches( qr/^Status:\s+302/s, $text );
    $this->assert_matches(
        qr([lL]ocation:\s+\S+?/view$ext/$this->{test_web}/UpperCase)s, $text );
    $this->check( $this->{test_web}, 'UpperCase', $topicObject, <<THIS, 100 );
One lowercase
Twolowercase
[[UpperCase]]
THIS
}

sub test_accessRenameRestrictedTopic {
    my $this      = shift;
    my $topictext = "   * Set ALLOWTOPICRENAME = GungaDin\n";
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OldTopic',
        $topictext );
    $topicObject->save();
    my $query = new Unit::Request(
        {
            action   => 'rename',
            topic    => 'OldTopic',
            newweb   => $this->{test_web},
            newtopic => 'NewTopic',
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    try {
        no strict 'refs';
        my ( $text, $result ) = &$UI_FN( $this->{session} );
        use strict 'refs';
        $this->assert(0);
    }
    catch Foswiki::OopsException with {
        $this->assert_str_equals(
"OopsException(accessdenied/topic_access web=>$this->{test_web} topic=>OldTopic params=>[RENAME,access not allowed on topic])",
            shift->stringify()
        );
    }
}

sub test_accessRenameRestrictedWeb {
    my $this      = shift;
    my $topictext = "   * Set ALLOWWEBRENAME = GungaDin\n";
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, $topictext );
    $topicObject->save();
    my $query = new Unit::Request(
        {
            action   => 'rename',
            topic    => 'OldTopic',
            newweb   => $this->{test_web},
            newtopic => 'NewTopic',
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    try {
        no strict 'refs';
        my ( $text, $result ) = &$UI_FN( $this->{session} );
        use strict 'refs';
        $this->assert(0);
    }
    catch Foswiki::OopsException with {
        $this->assert_str_equals(
"OopsException(accessdenied/topic_access web=>$this->{test_web} topic=>OldTopic params=>[RENAME,access not allowed on web])",
            shift->stringify()
        );
    }
}

# Purpose: verify that leases are removed when a topic is renamed
sub test_leaseReleaseMeLetMeGo {
    my $this = shift;

    # Grab a lease
    my $m =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OldTopic' );
    $m->setLease(1000);

    my $query = new Unit::Request(
        {
            action   => 'rename',
            topic    => 'OldTopic',
            newweb   => $this->{test_web},
            newtopic => 'NewTopic',
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->capture( \&$UI_FN, $this->{session} );
    $m = Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OldTopic' );
    my $lease = $m->getLease();
    $this->assert_null( $lease, $lease );
}

sub test_makeSafeTopicName {
    my $this = shift;

    {
        my $result   = Foswiki::UI::Rename::_safeTopicName('Abc/Def');
        my $expected = 'Abc_Def';
        print("result=$result.\n")     if $debug;
        print("expected=$expected.\n") if $debug;
        $this->assert( $result eq $expected );
    }
    {
        my $result   = Foswiki::UI::Rename::_safeTopicName('Abc.Def');
        my $expected = 'Abc_Def';
        print("result=$result.\n")     if $debug;
        print("expected=$expected.\n") if $debug;
        $this->assert( $result eq $expected );
    }
    {
        my $result   = Foswiki::UI::Rename::_safeTopicName('Abc Def');
        my $expected = 'AbcDef';
        print("result=$result.\n")     if $debug;
        print("expected=$expected.\n") if $debug;
        $this->assert( $result eq $expected );
    }
}

1;
