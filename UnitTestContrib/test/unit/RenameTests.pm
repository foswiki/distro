use strict;

package RenameTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::UI::Manage;
use Error ':try';

my $notawwtopic1 = "random";
my $notawwtopic2 = "Random";
my $notawwtopic3 = "ranDom";

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki(
        $this->{test_user_login}, new Unit::Request({topic=>"/$this->{test_web}/OldTopic"}));

    $this->{new_web} = $this->{test_web}.'New';
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{new_web});

    $Foswiki::Plugins::SESSION = $this->{twiki};

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

    foreach my $topic ('OldTopic', 'OtherTopic', 'random',
                       'Random', 'ranDom' ) {
        my $meta = new Foswiki::Meta($this->{twiki}, $this->{test_web}, $topic);
        $meta->putKeyed( 'FIELD', {name=>$this->{test_web},
                                   value=>$this->{test_web}} );
        $meta->putKeyed( 'FIELD', {name=>"$this->{test_web}.OldTopic",
                                   value=>"$this->{test_web}.OldTopic"} );
        $meta->putKeyed( 'FIELD', {name=>'OldTopic',
                                   value=>'OldTopic'} );
        $meta->putKeyed( 'FIELD', {name=>"OLD",
                                   value=>"$this->{test_web}.OldTopic"} );
        $meta->putKeyed( 'FIELD', {name=>"NEW",
                                   value=>"$this->{new_web}.NewTopic"} );
        $meta->put( "TOPICPARENT", {name=> "$this->{test_web}.OldTopic"} );
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user}, $this->{test_web}, $topic,
            $originaltext, $meta );
    }

    my $meta = new Foswiki::Meta($this->{twiki}, $this->{new_web}, 'OtherTopic');
    $meta->putKeyed( 'FIELD', {name=>$this->{test_web},
                          value=>$this->{test_web}} );
    $meta->putKeyed( 'FIELD', {name=>"$this->{test_web}.OldTopic",
                          value=>"$this->{test_web}.OldTopic"} );
    $meta->putKeyed( 'FIELD', {name=>'OldTopic',
                          value=>'OldTopic'} );
    $meta->putKeyed( 'FIELD', {name=>"OLD",
                          value=>"$this->{test_web}.OldTopic"} );
    $meta->putKeyed( 'FIELD', {name=>"NEW",
                          value=>"$this->{new_web}.NewTopic"} );
    $meta->put( "TOPICPARENT", {name=> "$this->{test_web}.OldTopic"} );
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{new_web}, 'OtherTopic',
        $originaltext, $meta );

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{new_web},
        $Foswiki::cfg{HomeTopicName}, 'junk' );
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture($this->{twiki},$this->{new_web});
    $this->removeWebFixture($this->{twiki},"Renamed$this->{new_web}")
      if ($this->{twiki}->{store}->webExists("Renamed$this->{new_web}"));
    $this->SUPER::tear_down();
}

sub check {
    my($this, $web, $topic, $emeta, $expected, $num) = @_;
    my($meta,$actual) = $this->{twiki}->{store}->readTopic( undef, $web, $topic );
    my @old = split(/\n+/, $expected);
    my @new = split(/\n+/, $actual);

    while (scalar(@old)) {
        my $o = "$num: ".shift(@old);
        my $n = "$num: ".shift(@new);
        $this->assert_str_equals($o, $n, "Expect $o\nActual $n\n".join(",",caller));
    }
}

sub checkReferringTopics {
    my ($this, $web, $topic, $all, $expected, $forgiving) = @_;

    my $refs = Foswiki::UI::Manage::getReferringTopics(
        $this->{twiki}, $web, $topic, $all);
    $this->assert_str_equals('HASH', ref($refs));

    if ($forgiving) {
        foreach my $k (keys %$refs) {
            unless ($k =~ /^$this->{test_web}/) {
                delete($refs->{$k});
            }
        }
    }

    my $i = scalar(keys %$refs);
    $this->assert_equals(scalar(@$expected), $i, join(",", keys %$refs));

    my @e = sort @$expected;
    my $j = scalar(@e);
    my @r = sort keys %$refs;
    while (--$i >= 0 && scalar(@e)) {
        my $e = $e[--$j];
        while ($i >= 0 && $r[$i] ne $e) {
            $i--;
        };
        $this->assert_str_equals(
            $e, $r[$i], "Mismatch expected\n".join(',', @e).
              " got\n".join(',',@r));
    }
    $this->assert_equals(0, $j);
}

# Test references to a topic in this web
sub test_referringTopicsThisWeb {
    my $this = shift;
    my $ott = 'Old Topic';
    my $lott = lc($ott);
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeOne', <<THIS );
[[$ott]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeTwo', <<THIS );
[[$lott]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{new_web}, 'MatchMeThree', <<THIS );
[[$this->{test_web}.$ott]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{new_web}, 'MatchMeFour', <<THIS );
[[$this->{test_web}.$lott]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'NoMatch', <<THIS );
Refer to $ott and $lott
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{new_web}, 'NoMatch', <<THIS );
Refer to $ott and $lott
THIS

    # Just Web
    $this->checkReferringTopics(
        $this->{test_web}, 'OldTopic', 0,
        [ "$this->{test_web}.OtherTopic",
          "$this->{test_web}.MatchMeOne",
          "$this->{test_web}.MatchMeTwo",
          "$this->{test_web}.random",
          "$this->{test_web}.Random",
          "$this->{test_web}.ranDom" ]);
}

# Test references to a topic in all webs
# Warning; this is a bit of a lottery, as you might have webs that refer
# to the topic outside the test set. For this reason the test is forgiving
# if a ref outside of the test webs is found.
sub test_referringTopicsAllWebs {
    my $this = shift;
    my $ott = 'Old Topic';
    my $lott = lc($ott);
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeOne', <<THIS );
[[$ott]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeTwo', <<THIS );
[[$lott]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{new_web}, 'MatchMeThree', <<THIS );
[[$this->{test_web}.$ott]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{new_web}, 'MatchMeFour', <<THIS );
[[$this->{test_web}.$lott]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'NoMatch', <<THIS );
Refer to $ott and $lott
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{new_web}, 'NoMatch', <<THIS );
Refer to $ott and $lott
THIS

    # All webs
    $this->checkReferringTopics(
        $this->{test_web}, 'OldTopic', 1, [
            "$this->{new_web}.OtherTopic",
            "$this->{new_web}.MatchMeThree",
            "$this->{new_web}.MatchMeFour",
           ], 1);
}

# Test references to a topic in this web, where the topic is not a wikiword
sub test_referringTopicsNotAWikiWord {
    my $this = shift;
    my $ott = 'ranDom';
    my $lott = lc($ott);
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeOne', <<THIS );
random random random
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeTwo', <<THIS );
ranDom ranDom ranDom
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeThree', <<THIS );
Random Random Random
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeFour', <<THIS );
RanDom RanDom RanDom
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeFive', <<THIS );
[[random]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeSix', <<THIS );
[[ranDom]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeSeven', <<THIS );
[[Random]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'MatchMeEight', <<THIS );
[[RanDom]]
THIS

    $this->checkReferringTopics($this->{test_web}, 'random', 0, [
        "$this->{test_web}.MatchMeFive",
        "$this->{test_web}.OldTopic",
        "$this->{test_web}.OtherTopic",
        "$this->{test_web}.Random",
        "$this->{test_web}.ranDom"
       ]);
    $this->checkReferringTopics($this->{test_web}, 'ranDom', 0, [
        "$this->{test_web}.MatchMeSix",
        "$this->{test_web}.OldTopic",
        "$this->{test_web}.OtherTopic",
        "$this->{test_web}.Random",
        "$this->{test_web}.random"
       ]);
    $this->checkReferringTopics($this->{test_web}, 'Random', 0, [
        "$this->{test_web}.MatchMeSeven",
        "$this->{test_web}.OldTopic",
        "$this->{test_web}.OtherTopic",
        "$this->{test_web}.random",
        "$this->{test_web}.ranDom"
       ]);
}

# Rename OldTopic to NewTopic within the same web
sub test_rename_oldwebnewtopic {
    my $this = shift;
    my $query = new Unit::Request({
                         action => [ 'rename' ],
                         newweb => [ $this->{test_web} ],
                         newtopic => [ 'NewTopic' ],
                         referring_topics => [ "$this->{test_web}.NewTopic",
                                               "$this->{test_web}.OtherTopic",
                                               "$this->{new_web}.OtherTopic" ],
                         topic => 'OldTopic'
                        });

    $this->{twiki}->finish();
    # The topic in the path should not matter
    $query->path_info( "/$this->{test_web}/SanityCheck" );
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{twiki};
    $this->captureWithKey( rename => \&Foswiki::UI::Manage::rename, $this->{twiki} );

    $this->assert( $this->{twiki}->{store}->topicExists(
        $this->{test_web}, 'NewTopic' ));
    $this->assert(!$this->{twiki}->{store}->topicExists(
        $this->{test_web}, 'OldTopic' ));
    $this->check($this->{test_web}, 'NewTopic', undef, <<THIS, 1);
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
    $this->check($this->{test_web}, 'OtherTopic', undef, <<THIS, 2);
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

    $this->check($this->{new_web}, 'OtherTopic', undef, <<THIS, 3);
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
    my $this = shift;
    my $query = new Unit::Request({
                         action => [ 'rename' ],
                         newweb => [ $this->{new_web} ],
                         newtopic => [ 'OldTopic' ],
                         referring_topics => [ "$this->{test_web}.OtherTopic",
                                               "$this->{new_web}.OldTopic",
                                               "$this->{new_web}.OtherTopic" ],
                         topic => 'OldTopic'
                        });

    $query->path_info("/$this->{test_web}" );
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{twiki};
    $this->captureWithKey( rename => \&Foswiki::UI::Manage::rename, $this->{twiki} );

    $this->assert( $this->{twiki}->{store}->topicExists(
        $this->{new_web}, 'OldTopic' ));
    $this->assert(!$this->{twiki}->{store}->topicExists(
        $this->{test_web}, 'OldTopic' ));

    $this->check($this->{new_web}, 'OldTopic', undef, <<THIS, 4);
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
    $this->check($this->{new_web}, 'OtherTopic', undef, <<THIS, 5);
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

    $this->check($this->{test_web}, 'OtherTopic', undef, <<THIS, 6);
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
    my $this       =  shift;
    my $meta       =  new Foswiki::Meta(
        $this->{twiki}, $this->{test_web}, 'lowercase');
    my $topictext  =  <<THIS;
One lowercase
Twolowercase
[[lowercase]]
THIS
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'lowercase',
                                $topictext, $meta );
    my $query = new Unit::Request({
        action   => 'rename',
        topic    => 'lowercase',
        newweb   => $this->{test_web},
        newtopic => 'upperCase',
        referring_topics => [ "$this->{test_web}.NewTopic" ],
    });

    $query->path_info("/$this->{test_web}" );
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{twiki};
    my ($text,$result) =
      $this->captureWithKey( rename => \&Foswiki::UI::Manage::rename, $this->{twiki} );
    my $ext = $Foswiki::cfg{ScriptSuffix};
    $this->assert_matches(qr/^Status:\s+302/s,$text);
    $this->assert_matches(qr([lL]ocation:\s+\S+?/view$ext/$this->{test_web}/UpperCase)s,$text);
    $this->check($this->{test_web}, 'UpperCase', $meta, <<THIS, 100);
One lowercase
Twolowercase
[[UpperCase]]
THIS
}

sub test_accessRenameRestrictedTopic {
    my $this       =  shift;
    my $meta       =  new Foswiki::Meta(
        $this->{twiki}, $this->{test_web}, 'OldTopic');
    my $topictext  =  "   * Set ALLOWTOPICRENAME = GungaDin\n";
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'OldTopic',
                                $topictext, $meta );
    my $query = new Unit::Request({
                         action   => 'rename',
                         topic    => 'OldTopic',
                         newweb   => $this->{test_web},
                         newtopic => 'NewTopic',
                        });

    $query->path_info("/$this->{test_web}" );
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{twiki};
    try {
        my ($text,$result) = Foswiki::UI::Manage::rename( $this->{twiki} );
        $this->assert(0);
    } catch Foswiki::AccessControlException with {
        $this->assert_str_equals('AccessControlException: Access to RENAME TemporaryRenameTestsTestWebRenameTests.OldTopic for scum is denied. access not allowed on topic', shift->stringify());
    }
}

sub test_accessRenameRestrictedWeb {
    my $this       =  shift;
    my $meta       =  new Foswiki::Meta(
        $this->{twiki}, $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName});
    my $topictext  =  "   * Set ALLOWWEBRENAME = GungaDin\n";
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, $topictext, $meta );
    my $query = new Unit::Request({
                         action   => 'rename',
                         topic    => 'OldTopic',
                         newweb   => $this->{test_web},
                         newtopic => 'NewTopic',
                        });

    $query->path_info("/$this->{test_web}" );
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{twiki};
    try {
        my ($text,$result) = Foswiki::UI::Manage::rename( $this->{twiki} );
        $this->assert(0);
    } catch Foswiki::AccessControlException with {
        $this->assert_str_equals('AccessControlException: Access to RENAME TemporaryRenameTestsTestWebRenameTests.OldTopic for scum is denied. access not allowed on web', shift->stringify());
    }
}

# Test rename does not corrupt history, see Foswikibug:2299
sub test_renameTopic_preserves_history
{
    my $this      = shift;
    my $topicName = 'RenameWithHistory';
    my $time      = time();
    my @history   = map { "$_\n" } qw( First Second Third );

    for my $depth ( 0 .. $#history ) {
        my $meta       =  new Foswiki::Meta(
            $this->{twiki}, $this->{test_web}, $topicName );
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user}, $this->{test_web},
            $topicName, $history[$depth], $meta, { forcenewrevision => 1 } );
    }
    my $query = new Unit::Request(
        {
            action   => 'rename',
            topic    => $topicName,
            newweb   => $this->{test_web},
            newtopic => $topicName . 'Renamed',
        }
    );

    $query->path_info("/$this->{test_web}");
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{twiki};
    $this->captureWithKey( rename => \&Foswiki::UI::Manage::rename, $this->{twiki} );
    my ($meta, $text) = $this->{twiki}->{store}->readTopic( $this->{twiki}->{user}, $this->{test_web}, $topicName . 'Renamed' );
    $this->assert_equals( $history[$#history], $text );
    my ( $date, $author, $rev, $comment ) = $meta->getRevisionInfo();
    $this->assert_equals( $#history + 1, $rev ); # rename creates a new revision

}

# Purpose: verify that leases are removed when a topic is renamed
sub test_leaseReleasemeLetMeGo {
    my $this =  shift;

    # Grab a lease
    $this->{twiki}->{store}->setLease(
        $this->{test_web}, 'OldTopic', $this->{twiki}->{user}, 1000);

    my $query = new Unit::Request({
                         action   => 'rename',
                         topic    => 'OldTopic',
                         newweb   => $this->{test_web},
                         newtopic => 'NewTopic',
                        });

    $query->path_info("/$this->{test_web}" );
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{twiki};
    $this->captureWithKey( rename => \&Foswiki::UI::Manage::rename, $this->{twiki} );

    my $lease = $this->{twiki}->{store}->getLease(
        $this->{test_web}, 'OldTopic');
    $this->assert_null($lease, $lease);
}

sub test_renameWeb_1307a {
    my $this = shift;
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, "$this->{test_web}/Renamedweb" );
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, "$this->{test_web}/Renamedweb/Subweb" );
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, "$this->{test_web}/Notrenamedweb" );

    my $vue = "$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, "$this->{test_web}/Notrenamedweb",
        'ReferringTopic',
        <<CONTENT );
$this->{test_web}.Renamedweb.Subweb
$this->{test_web}/Renamedweb/Subweb
$this->{test_web}.Notrenamedweb.Subweb
$this->{test_web}/Notrenamedweb/Subweb
$vue/$this->{test_web}/Renamedweb/WebHome
$vue/$this->{test_web}/Renamedweb/SubwebWebHome
CONTENT

    my $query = new Unit::Request(
        {
            action   => 'renameweb',
            newparentweb => "$this->{test_web}/Notrenamedweb",
            newsubweb => "Renamedweb",
            referring_topics => [ "$this->{test_web}/Notrenamedweb/ReferringTopic" ],
        }
       );
    $query->path_info("/$this->{test_web}/Renamedweb/WebHome");

    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{twiki};
    my ($text, $exit) = $this->captureWithKey( rename => \&Foswiki::UI::Manage::rename, $this->{twiki} );
    $this->assert(!$exit);
    $this->assert(Foswiki::Func::webExists("$this->{test_web}/Notrenamedweb/Renamedweb"));
    $this->assert(!Foswiki::Func::webExists("$this->{test_web}/Renamedweb"));
    my ($me, $te) = Foswiki::Func::readTopic(
        "$this->{test_web}/Notrenamedweb", 'ReferringTopic' );
    my @lines = split(/\n/, $te);
    $this->assert_str_equals(
        "$this->{test_web}/Notrenamedweb/Renamedweb.Subweb",
        $lines[0]);
    $this->assert_str_equals(
        "$this->{test_web}/Notrenamedweb/Renamedweb/Subweb",
        $lines[1]);
    $this->assert_str_equals(
        "$this->{test_web}.Notrenamedweb.Subweb",
        $lines[2]);
    $this->assert_str_equals(
        "$this->{test_web}/Notrenamedweb/Subweb",
        $lines[3]);
    $this->assert_str_equals(
        "$vue/$this->{test_web}/Notrenamedweb/Renamedweb/WebHome",
        $lines[4]);
 $this->assert_str_equals(
     "$vue/$this->{test_web}/Notrenamedweb/Renamedweb/SubwebWebHome",
     $lines[5]);
}

sub test_renameWeb_1307b {
    my $this = shift;
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, "Renamed$this->{test_web}" );
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, "Renamed$this->{test_web}/Subweb" );
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, "$this->{test_web}" );
    my $vue = "$Foswiki::cfg{DefaultUrlHost}/$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}";
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, "$this->{test_web}",
        'ReferringTopic',
        <<CONTENT );
Renamed$this->{test_web}.Subweb
Renamed$this->{test_web}/Subweb
$this->{test_web}.Subweb
$this->{test_web}/Subweb
$vue/Renamed$this->{test_web}/WebHome
$vue/Renamed$this->{test_web}/SubwebWebHome
CONTENT

    # need rename access on the root for this one, which is a bit of a
    # faff to set up, so we'll cheat a bit and add the user to the admin
    # group. Fortunately we have a private users web.
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user},
        $this->{users_web},
        $Foswiki::cfg{SuperAdminGroup}, <<EOF);
   * Set GROUP = $this->{test_user_wikiname}
EOF

    my $query = new Unit::Request(
        {
            action   => 'renameweb',
            newparentweb => $this->{test_web},
            newsubweb => "Renamed$this->{test_web}",
            referring_topics => [ "$this->{test_web}/ReferringTopic" ],
        }
       );
    $query->path_info("/Renamed$this->{test_web}/WebHome");

    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{twiki};

    my ($text, $exit) = $this->captureWithKey( rename =>
        \&Foswiki::UI::Manage::rename, $this->{twiki} );

    $this->assert(!$exit);
    $this->assert(Foswiki::Func::webExists("$this->{test_web}/Renamed$this->{test_web}"));
    $this->assert(!Foswiki::Func::webExists("Renamed$this->{test_web}"));
    my ($me, $te) = Foswiki::Func::readTopic(
        "$this->{test_web}", 'ReferringTopic' );
    my @lines = split(/\n/, $te);
    $this->assert_str_equals(
        "$this->{test_web}/Renamed$this->{test_web}.Subweb",
        $lines[0]);
    $this->assert_str_equals(
        "$this->{test_web}/Renamed$this->{test_web}/Subweb",
        $lines[1]);
    $this->assert_str_equals(
        "$this->{test_web}.Subweb",
        $lines[2]);
    $this->assert_str_equals(
        "$this->{test_web}/Subweb",
        $lines[3]);
    $this->assert_str_equals(
        "$vue/$this->{test_web}/Renamed$this->{test_web}/WebHome",
        $lines[4]);
 $this->assert_str_equals(
     "$vue/$this->{test_web}/Renamed$this->{test_web}/SubwebWebHome",
     $lines[5]);
}

1;
