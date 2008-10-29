package MailerContribSuite;
use base qw(TWikiFnTestCase);

use strict;
use locale;

use TWiki::Contrib::MailerContrib;

my $testWeb2;

my @specs;

my %expectedRevs =
  (
      TestTopic1 => "r1->r3",
      TestTopic11 => "r1->r2",
      TestTopic111 => "r1->r2",
      TestTopic112 => "r1->r2",
      TestTopic12 => "r1->r2",
      TestTopic121 => "r1->r2",
      TestTopic122 => "r1->r2",
      TestTopic1221 => "r1->r2",
      TestTopic2 => "r2->r3",
      TestTopic21 => "r1->r2",
     );

my %finalText =
  (
      TestTopic1 => "beedy-beedy-beedy oh dear, said TWiki, shortly before exploding into a million shards of white hot metal as the concentrated laser fire of a thousand angry public website owners poured into it.",
      TestTopic11 => "fire laser beams",
      TestTopic111 => "Doctor Theopolis",
      TestTopic112 => "Buck, I'm dying",
      TestTopic12 => "Wow! A real Wookie!",
      TestTopic121 => "Where did I put my silver jumpsuit?",
      TestTopic122 => "That danged robot",
      TestTopic1221 => "What's up, Buck?",
      TestTopic2 => "roast my nipple-nuts",
      TestTopic21 => "smoke me a kipper, I'll be back for breakfast",
      # High-bit chars - assumes {Site}{CharSet} is set for a high-bit
      # encoding. No tests for multibyte encodings :-(
      'RequêtesNon' => "makê it so, number onê",
      'RequêtesOui' => "you're such a smêêêêêê heeee",
     );

sub new {
    my $class = shift;
    return $class->SUPER::new('MailerContribTests', @_);
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $TWiki::cfg{EnableHierarchicalWebs} = 1;

    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);

    my $text;

    $testWeb2 = "$this->{test_web}/SubWeb";
    # Will get torn down when the parent web dies
    TWiki::Func::createWeb($testWeb2);

    $this->registerUser("tu1", "Test", "User1", "test1\@example.com");
    $this->registerUser("tu2", "Test", "User2", "test2\@example.com");
    $this->registerUser("tu3", "Test", "User3", "test3\@example.com");

    # test group
    TWiki::Func::saveTopic(
        $this->{users_web},
        "TestGroup", undef, "   * Set GROUP = TestUser3\n");

    # Must create a new twiki to force re-registration of users
    $TWiki::cfg{EnableEmail} = 1;
    $this->{twiki} = new TWiki();
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);
    @TWikiFnTestCase::mails = ();

    @specs =
      (
          # traditional subscriptions
          {
              entry => "$this->{users_web}.TWikiGuest - example\@example.com",
              email => "example\@example.com",
              topicsout => ""
             },
          {
              entry => "$this->{users_web}.NonPerson - nonperson\@example.com",
              email => "nonperson\@example.com",
              topicsout => "*"
             },

          # email subscription
          {
              entry => "person\@example.com",
              email => "person\@example.com",
              topicsout => "*"
             },
          # wikiname subscription
          {
              entry => "TestUser1",
              email => "test1\@example.com",
              topicsout => "*"
             },
          # wikiname subscription
          {
              entry => "%MAINWEB%.TestUser2",
              email => "test2\@example.com",
              topicsout => "*"
             },
          # groupname subscription
          {
              entry => "TestGroup",
              email => "test3\@example.com",
              topicsout => "TestTopic1"
             },
          # single topic with one level of children
          {
              entry => "'email1\@example.com': TestTopic1 (1)",
              email => "email1\@example.com",
              topicsout => "TestTopic1 TestTopic11 TestTopic12",
          },
          # single topic with 2 levels of children
          {
              entry => "TestUser1 : TestTopic1 (2)",
              email => "test1\@example.com",
              topicsout => "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122"
             },
          # single topic with 3 levels of children
          {
              email => "email3\@example.com",
              entry => "email3\@example.com : TestTopic1 (3)",
              topicsout => "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122 TestTopic1221"
             },
          # Comma separated list of subscriptions
          {
              email => "email4\@example.com",
              entry => "email4\@example.com: TestTopic1 (0), TestTopic2 (3)",
              topicsout => "TestTopic1 TestTopic2 TestTopic21"
             },
          # mix of commas, pluses and minuses
          {
              email => "email5\@example.com",
              entry => "email5\@example.com: TestTopic1 + TestTopic2(3), -TestTopic21",
              topicsout => "TestTopic1 TestTopic2"
             },
          # wildcard
          {
              email => "email6\@example.com",
              entry => "email6\@example.com: TestTopic1*1",
              topicsout => "TestTopic11 TestTopic111"
             },
          # wildcard unsubscription
          {
              email => "email7\@example.com",
              entry => "email7\@example.com: TestTopic*1 - \\\n   TestTopic2*",
              topicsout => "TestTopic1 TestTopic11 TestTopic121",
          },
          # Strange group name; just checking parser, here
          {
              email => "email8\@example.com",
              entry => "'IT:admins': TestTopic1",
              topicsout => "",
          },
         );

    if (!$TWiki::cfg{Site}{CharSet}
          || $TWiki::cfg{Site}{CharSet} =~ /^iso-?8859/) {
        # High-bit chars - assumes {Site}{CharSet} is set for a high-bit
        # encoding. No tests for multibyte encodings :-(
        push(@specs, # Francais
             {
                 email => "test1\@example.com",
                 entry => "TestUser1 : Requêtes*",
                 topicsout => "RequêtesNon RequêtesOui",
             },
            );
    } else {
        print STDERR "WARNING: High-bit tests disabled for $TWiki::cfg{Site}{CharSet}\n";
    }

    my $s = "";
    foreach my $spec (@specs) {
        $s .= "   * $spec->{entry}\n";
    }
    foreach my $web ($this->{test_web}, $testWeb2) {
        my $meta = new TWiki::Meta($this->{twiki},$web,
                                   $TWiki::cfg{NotifyTopicName});
        $meta->put( "TOPICPARENT", { name => "$web.WebHome" } );
        TWiki::Func::saveTopic( $web, $TWiki::cfg{NotifyTopicName}, $meta,
                                    "Before\n${s}After");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic1");
        $meta->put( "TOPICPARENT", { name => "WebHome" } );
        TWiki::Func::saveTopic( $web, "TestTopic1", $meta,
            "This is TestTopic1 so there");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic11");
        $meta->put( "TOPICPARENT", { name => "TestTopic1" } );
        TWiki::Func::saveTopic( $web, "TestTopic11",$meta,
                                    "This is TestTopic11 so there");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic111");
        $meta->put( "TOPICPARENT", { name => "TestTopic11" } );
        TWiki::Func::saveTopic( $web, "TestTopic111", $meta,
                                    "This is TestTopic111 so there");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic112");
        $meta->put( "TOPICPARENT", { name => "TestTopic11" } );
        TWiki::Func::saveTopic( $web, "TestTopic112", $meta,
                                    "This is TestTopic112 so there");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic12");
        $meta->put( "TOPICPARENT", { name => "TestTopic1" } );
        TWiki::Func::saveTopic( $web, "TestTopic12", $meta,
                                    "This is TestTopic12 so there");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic121");
        $meta->put( "TOPICPARENT", { name => "TestTopic12" } );
        TWiki::Func::saveTopic( $web, "TestTopic121", $meta,
                                    "This is TestTopic121 so there");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic122");
        $meta->put( "TOPICPARENT", { name => "TestTopic12" } );
        TWiki::Func::saveTopic( $web, "TestTopic122", $meta,
                                    "This is TestTopic122 so there");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic1221");
        $meta->put( "TOPICPARENT", { name => "TestTopic122" } );
        TWiki::Func::saveTopic( $web, "TestTopic1221", $meta,
                                    "This is TestTopic1221 so there");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic2");
        $meta->put( "TOPICPARENT", { name => "WebHome" } );
        TWiki::Func::saveTopic( $web, "TestTopic2", $meta,
                                    "Dylsexia rules");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopic21");
        $meta->put( "TOPICPARENT", { name => "$web.TestTopic2" } );
        TWiki::Func::saveTopic( $web, "TestTopic21", $meta,
                                    "This is TestTopic21 so there");

        $meta = new TWiki::Meta($this->{twiki},$web,"TestTopicDenied");
        TWiki::Func::saveTopic( $web, "TestTopicDenied", $meta,
            "   * Set ALLOWTOPICVIEW = TestUser1");

        # add a second rev to TestTopic2 so the base rev is 2
        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic2");
        TWiki::Func::saveTopic( $web, "TestTopic2", $meta,
                                    "This is TestTopic2 so there",
                                    { forcenewrevision=>1 });

        # stamp the baseline
        my $metadir = TWiki::Func::getWorkArea('MailerContrib');
        my $dirpath = $web;
        $dirpath =~ s#/#.#g;
        $this->assert(open(F, ">$metadir/$dirpath"), "$metadir/$dirpath: $!");
        print F time();
        close(F);

        # wait a wee bit for the clock to tick over
        sleep(1);

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic1");
        TWiki::Func::saveTopic( $web, "TestTopic1", $meta,
                                    "not the last word",
                                    { forcenewrevision=>1 });

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic11");
        TWiki::Func::saveTopic( $web, "TestTopic11", $meta,
                                    $finalText{TestTopic11},
                                    { forcenewrevision=>1 });

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic111");
        TWiki::Func::saveTopic( $web, "TestTopic111", $meta,
                                    $finalText{TestTopic111},
                                    { forcenewrevision=>1 });

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic112");
        TWiki::Func::saveTopic( $web, "TestTopic112", $meta,
                                    $finalText{TestTopic112},
                                    { forcenewrevision=>1 });

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic12");
        TWiki::Func::saveTopic( $web, "TestTopic12", $meta,
                                    $finalText{TestTopic12},
                                    { forcenewrevision=>1 });

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic121");
        TWiki::Func::saveTopic( $web, "TestTopic121", $meta,
                                    $finalText{TestTopic121},
                                    { forcenewrevision=>1 });

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic122");
        TWiki::Func::saveTopic( $web, "TestTopic122", $meta,
                                    $finalText{TestTopic122},
                                    { forcenewrevision=>1 });

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic1221");
        TWiki::Func::saveTopic( $web, "TestTopic1221", $meta,
                                    $finalText{TestTopic1221},
                                    { forcenewrevision=>1 });

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic2");
        TWiki::Func::saveTopic( $web, "TestTopic2", $meta,
                                    $finalText{TestTopic2},
                                    { forcenewrevision=>1 });

        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic21");
        TWiki::Func::saveTopic( $web, "TestTopic21", $meta,
                                    $finalText{TestTopic21},
                                    { forcenewrevision=>1 });

        # wait a wee bit more for the clock to tick over again
        sleep(1);

        # TestTopic1 should now have two change records in the period, so
        # should be going from rev 1 to rev 3
        ( $meta, $text ) = TWiki::Func::readTopic($web,"TestTopic1");
        TWiki::Func::saveTopic( $web, "TestTopic1", $meta,
                                    $finalText{TestTopic1},
                                    { forcenewrevision=>1 });
    }
    # OK, we should have a bunch of changes
}

sub testSimple {
    my $this = shift;

    my @webs = ( $this->{test_web}, $this->{users_web} );
    TWiki::Contrib::MailerContrib::mailNotify( \@webs, $this->{twiki}, 0 );
    #print "REPORT\n",join("\n\n", @TWikiFnTestCase::mails);

    my %matched;
    foreach my $message ( @TWikiFnTestCase::mails ) {
        next unless $message;
        $message =~ /^To: (.*)$/m;
        my $mailto = $1;
        $this->assert($mailto, $message);
        foreach my $spec (@specs) {
            if ($mailto eq $spec->{email}) {
                $this->assert(!$matched{$mailto}, $mailto);
                $matched{$mailto} = 1;
                my $xpect = $spec->{topicsout};
                if ($xpect eq '*') {
                    $xpect = "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122 TestTopic1221 TestTopic2 TestTopic21";
                }
                foreach my $x (split(/\s+/, $xpect)) {
                    $this->assert_matches(qr/^- $x \(.*\) $expectedRevs{$x}/m, $message);
                    #$this->assert_matches(qr/$finalText{$x}/m, $message);
                    $message =~ s/^- $x \(.*\n//m;
                }
                $this->assert_does_not_match(qr/^- \w+ \(/, $message);
                last;
            }
        }
    }
    foreach my $spec (@specs) {
        if ($spec->{topicsout} ne "") {
            $this->assert($matched{$spec->{email}},
                          "Expected mails for ".$spec->{email} .
                            " but only got " .
                              join(" ", keys %matched));
        } else {
            $this->assert(!$matched{$spec->{email}},
                          "Unexpected mails for ".$spec->{email} . " (got " .
                            join(" ", keys %matched));
        }
    }
}

sub testSubweb {
    my $this = shift;

    my @webs = ( $testWeb2, $this->{users_web} );
    TWiki::Contrib::MailerContrib::mailNotify( \@webs, $this->{twiki}, 0 );
    #print "REPORT\n",join("\n\n", @TWikiFnTestCase::mails);

    my %matched;
    foreach my $message ( @TWikiFnTestCase::mails ) {
        next unless $message;
        $message =~ /^To: (.*)$/m;
        my $mailto = $1;
        $this->assert($mailto, $message);
        foreach my $spec (@specs) {
            if ($mailto eq $spec->{email}) {
                $this->assert(!$matched{$mailto});
                $matched{$mailto} = 1;
                my $xpect = $spec->{topicsout};
                if ($xpect eq '*') {
                    $xpect = "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122 TestTopic1221 TestTopic2 TestTopic21";
                }
                foreach my $x (split(/\s+/, $xpect)) {
                    $this->assert_matches(qr/^- $x \(.*\) $expectedRevs{$x}/m, $message);
                    #$this->assert_matches(qr/$finalText{$x}/m, $message);
                    $message =~ s/^- $x \(.*\n//m;
                }
                $this->assert_does_not_match(qr/^- \w+ \(/, $message);
                last;
            }
        }
    }
    foreach my $spec (@specs) {
        if ($spec->{topicsout} ne "") {
            $this->assert(
                $matched{$spec->{email}},
                "Expected mails for ".$spec->{email} .
                  " but only saw mails for " .
                            join(" ", keys %matched));
        } else {
            $this->assert(
                !$matched{$spec->{email}},
                "Didn't expect mails for ".$spec->{email} . "; got " .
                            join(" ", keys %matched));
        }
    }
}

sub testCovers {
    my $this = shift;

    my $s1 = new TWiki::Contrib::MailerContrib::Subscription(
        'A', 0, 0);
    $this->assert($s1->covers($s1));

    my $s2 = new TWiki::Contrib::MailerContrib::Subscription(
        'A', 0, $MailerConst::FULL_TOPIC);
    $this->assert(!$s1->covers($s2));

    $s1 = new TWiki::Contrib::MailerContrib::Subscription(
        'A', 0, $MailerConst::ALWAYS | $MailerConst::FULL_TOPIC);
    $this->assert($s1->covers($s2));
    $this->assert(!$s2->covers($s1));

    $s1 = new TWiki::Contrib::MailerContrib::Subscription(
        'A*', 0, $MailerConst::FULL_TOPIC);
    $this->assert($s1->covers($s2));
    $this->assert(!$s2->covers($s1));

    $s2 = new TWiki::Contrib::MailerContrib::Subscription(
        'A', 1, $MailerConst::FULL_TOPIC);
    $this->assert(!$s1->covers($s2));
    $this->assert(!$s2->covers($s1));

    $s1 = new TWiki::Contrib::MailerContrib::Subscription(
        'A*', 1, $MailerConst::FULL_TOPIC);
    $this->assert($s1->covers($s2));
    $this->assert(!$s2->covers($s1));

    $s2 = new TWiki::Contrib::MailerContrib::Subscription(
        'A*B', 1, $MailerConst::FULL_TOPIC);
    $this->assert($s1->covers($s2));
    $this->assert(!$s2->covers($s1));

    $s1 = new TWiki::Contrib::MailerContrib::Subscription(
        'AxB', 0, $MailerConst::FULL_TOPIC);
    $this->assert(!$s1->covers($s2));
    $this->assert($s2->covers($s1));
    
    # * covers everything.
    my $AStar = new TWiki::Contrib::MailerContrib::Subscription(
        'A*', 1, $MailerConst::FULL_TOPIC);
    my $Star = new TWiki::Contrib::MailerContrib::Subscription(
        '*', 1, $MailerConst::FULL_TOPIC);
    $this->assert($Star->covers($AStar));
    $this->assert(!$AStar->covers($Star));

    #as parent-child relationshipd are broken across webs, * should cover topic (2)
    my $ChildrenOfWebHome = new TWiki::Contrib::MailerContrib::Subscription(
        'WebHome', 2, $MailerConst::FULL_TOPIC);
    $this->assert($Star->covers($ChildrenOfWebHome));
    $this->assert(!$ChildrenOfWebHome->covers($Star));
}

# Check filter-in on email addresses
sub testExcluded {
    my $this = shift;

    $TWiki::cfg{MailerContrib}{EmailFilterIn} = '\w+\@example.com';

    my $s = <<'HERE';
   * bad@disallowed.com: *
   * good@example.com: *
HERE

    my $meta = new TWiki::Meta($this->{twiki},$this->{test_web},
                               $TWiki::cfg{NotifyTopicName});
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    TWiki::Func::saveTopic( $this->{test_web}, $TWiki::cfg{NotifyTopicName},
                            $meta,
                            "Before\n${s}After",
                            $meta);
    TWiki::Contrib::MailerContrib::mailNotify(
        [ $this->{test_web} ], $this->{twiki}, 0 );

    my %matched;
    foreach my $message ( @TWikiFnTestCase::mails ) {
        next unless $message;
        $message =~ /^To: (.*?)$/m;
        my $mailto = $1;
        $this->assert($mailto, $message);
        $this->assert_str_equals('good@example.com', $mailto, $mailto);
    }
    #print "REPORT\n",join("\n\n", @TWikiFnTestCase::mails);
}

sub testExpansion {
    my $this = shift;

    my $s = <<'HERE';
%SEARCH{"gribble.com" multiple="on" topic="%TOPIC%" format="   * search@example.com: *"}%
gribble.com
HERE

    my $meta = new TWiki::Meta($this->{twiki},$this->{test_web},
                               $TWiki::cfg{NotifyTopicName});
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    TWiki::Func::saveTopic( $this->{test_web}, $TWiki::cfg{NotifyTopicName},
                            $meta,
                            "Before\n${s}After",
                            $meta);
    TWiki::Contrib::MailerContrib::mailNotify( [ $this->{test_web} ], $this->{twiki}, 0 );

    my %matched;
    foreach my $message ( @TWikiFnTestCase::mails ) {
        next unless $message;
        $message =~ /^To: (.*?)$/m;
        my $mailto = $1;
        $this->assert($mailto, $message);
        $this->assert_str_equals('search@example.com', $mailto, $mailto);
    }
    #print "REPORT\n",join("\n\n", @TWikiFnTestCase::mails);
}

sub test_5949 {
    my $this = shift;
    my $s = <<'HERE';
   * TestUser1: SpringCabbage
HERE
    my $meta = new TWiki::Meta($this->{twiki},$this->{test_web},
                               $TWiki::cfg{NotifyTopicName});
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    TWiki::Func::saveTopic( $this->{test_web},
                            $TWiki::cfg{NotifyTopicName}, $meta,
                            "Before\n${s}After",
                            $meta);

    my $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $this->{test_web},
        $TWiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals(<<HERE, $wn->stringify());
Before
   * TestUser1: SpringCabbage
After
HERE
    $wn->unsubscribe("TestUser1", "SpringCabbage");
    $this->assert_str_equals(<<HERE, $wn->stringify());
Before
   * TestUser1: 
After
HERE
}

sub test_changeSubscription_and_isSubScribedTo_API {
    my $this = shift;
    
    #start by removing all subscriptions
    my $meta = new TWiki::Meta($this->{twiki},$this->{test_web},
                               $TWiki::cfg{NotifyTopicName});
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    TWiki::Func::saveTopic( $this->{test_web},
                            $TWiki::cfg{NotifyTopicName}, $meta,
                            "Before\nAfter\n",
                            $meta);
    
    my $defaultWeb = $this->{test_web};
    my $who = 'TestUser1';
    my $topicList = 'WebHome';
    my $unsubscribe;    #undefined == subscribe / do what the topicList says..
    
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, $topicList));
    
    TWiki::Contrib::MailerContrib::changeSubscription($defaultWeb, $who, $topicList, $unsubscribe);
    $this->assert(TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, $topicList));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebIndex'));
    my $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $this->{test_web},
        $TWiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals("   * $who: $topicList\n", $wn->stringify(1));
    
    $topicList = '*';
    TWiki::Contrib::MailerContrib::changeSubscription($defaultWeb, $who, $topicList, $unsubscribe);
    $this->assert(TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, $topicList));
    $this->assert(TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebHome'));
    $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $this->{test_web},
        $TWiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals("   * $who: $topicList\n", $wn->stringify(1));
    
    $topicList = '-*';
    TWiki::Contrib::MailerContrib::changeSubscription($defaultWeb, $who, $topicList, $unsubscribe);
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebHome'));
    $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $this->{test_web},
        $TWiki::cfg{NotifyTopicName}, 1 );
    #removing * results in nothing.
    $this->assert_null($wn->stringify(1));
    
    $topicList = 'WebHome (2)';
    TWiki::Contrib::MailerContrib::changeSubscription($defaultWeb, $who, $topicList, $unsubscribe);
    $this->assert(TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebHome'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebChanges'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'SomethingElse'));
    $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $this->{test_web},
        $TWiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals("   * $who: $topicList\n", $wn->stringify(1));

    $topicList = 'WebIndex';
    TWiki::Contrib::MailerContrib::changeSubscription($defaultWeb, $who, $topicList, $unsubscribe);
    $this->assert(TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebHome'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebChanges'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'SomethingElse'));
    $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $this->{test_web},
        $TWiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals("   * $who: WebHome (2) $topicList\n", $wn->stringify(1));

    $topicList = '*';
    $unsubscribe = '-';
    TWiki::Contrib::MailerContrib::changeSubscription($defaultWeb, $who, $topicList, $unsubscribe);
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebHome'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebChanges'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'SomethingElse'));
    $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $this->{test_web},
        $TWiki::cfg{NotifyTopicName}, 1 );
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, $topicList));
    
    $topicList = 'WebHome (2)';
    $unsubscribe = '-';
    TWiki::Contrib::MailerContrib::changeSubscription($defaultWeb, $who, $topicList, $unsubscribe);
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebHome'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebChanges'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'SomethingElse'));
    $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $this->{test_web},
        $TWiki::cfg{NotifyTopicName}, 1 );
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, $topicList));
    
    #it should remove the - WebHome (2) as un-necessary
    $topicList = 'WebIndex - WebHome (2)';
    $unsubscribe = undef;
    TWiki::Contrib::MailerContrib::changeSubscription($defaultWeb, $who, $topicList, $unsubscribe);
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebHome'));
    $this->assert(TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebIndex'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'WebChanges'));
    $this->assert(!TWiki::Contrib::MailerContrib::isSubscribedTo($defaultWeb, $who, 'SomethingElse'));
    $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $this->{test_web},
        $TWiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals("   * $who: WebIndex\n", $wn->stringify(1));
}

1;
