# See bottom of file for license and copyright information
package MailerContribSuite;
use strict;
use warnings;
use locale;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki::Contrib::MailerContrib();

my $testWeb2;

my @specs;
my $high_bit_disabled = 0;

my %expectedRevs = (
    TestTopic1      => "r1->r3",
    TestTopic11     => "r1->r2",
    TestTopic111    => "r1->r2",
    TestTopic112    => "r1->r2",
    TestTopic12     => "r1->r2",
    TestTopic121    => "r1->r2",
    TestTopic122    => "r1->r2",
    TestTopic1221   => "r1->r2",
    TestTopic2      => "r2->r3",
    TestTopic21     => "r1->r2",
    TestTopicDenied => "r1->r2"
);

my %finalText = (
    TestTopic1 =>
"beedy-beedy-beedy oh dear, said Twiki, before exploding into a million shards of white hot metal as the concentrated laser fire of a thousand angry public website owners poured into it.",
    TestTopic11     => "fire laser beams",
    TestTopic111    => "Doctor Theopolis",
    TestTopic112    => "Buck, I'm dying",
    TestTopic12     => "Wow! A real Wookie!",
    TestTopic121    => "Where did I put my silver jumpsuit?",
    TestTopic122    => "That danged robot",
    TestTopic1221   => "What's up, Buck?",
    TestTopic2      => "roast my nipple-nuts",
    TestTopic21     => "smoke me a kipper, I'll be back for breakfast",
    TestTopicDenied => "   * Set ALLOWTOPICVIEW = TestUser1\n",

    # High-bit chars
    'RequêtesNon' => "makê it so, number onê",
    'RequêtesOui' => "you're such a smêêêêêê heeee",

    # High-byte encoding
    '官話' => '太極拳很好',
);

sub new {
    my $class = shift;
    return $class->SUPER::new( 'MailerContribTests', @_ );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    my $text;

    $testWeb2 = "$this->{test_web}/SubWeb";

    # Will get torn down when the parent web dies
    my $webObject = $this->populateNewWeb($testWeb2);
    $webObject->finish();

    $this->registerUser( "tu1", "Test", "User1", "test1\@example.com" );
    $this->registerUser( "tu2", "Test", "User2", "test2\@example.com" );
    $this->registerUser( "tu3", "Test", "User3", "test3\@example.com" );

    # test group
    Foswiki::Func::saveTopic( $this->{users_web}, "TestGroup", undef,
        "   * Set GROUP = TestUser3\n" );

    # Must create a new wiki object to force re-registration of users
    $Foswiki::cfg{EnableEmail} = 1;
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    @FoswikiFnTestCase::mails = ();

    # Each spec corresponds to a line in WebNotify, and should yield subs
    # for a single email address
    @specs = (

        {
            name      => "IGNORED because it's the guest user",
            entry     => "$this->{users_web}.WikiGuest - example\@example.com",
            email     => "example\@example.com",
            topicsout => ""
        },

        {
            name  => "LEGACY format",
            entry => "$this->{users_web}.NonPerson - nonperson\@example.com",
            email => "nonperson\@example.com",
            topicsout => "* -TestTopicDenied"
        },

        {
            name      => "simple email subscription",
            entry     => "person\@example.com",
            email     => "person\@example.com",
            topicsout => "* -TestTopicDenied"
        },

        {
            name      => "simple wikiname subscription to everything",
            entry     => "TestUser1",
            email     => "test1\@example.com",
            topicsout => "*"
        },

        {
            name      => "web.wikiname subscription",
            entry     => "%USERSWEB%.TestUser2",
            email     => "test2\@example.com",
            topicsout => "* -TestTopicDenied"
        },

        {
            name      => "groupname subscription",
            entry     => "TestGroup",
            email     => "test3\@example.com",
            topicsout => "* -TestTopicDenied"
        },

        {
            name      => "single topic with one level of children",
            entry     => "'email1\@example.com': TestTopic1 (1)",
            email     => "email1\@example.com",
            topicsout => "TestTopic1 TestTopic11 TestTopic12",
        },

        {
            name  => "single topic with 2 levels of children",
            entry => "TestUser1 : TestTopic1 (2)",
            email => "test1\@example.com",
            topicsout =>
"TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122"
        },

        {
            name  => "single topic with 3 levels of children",
            email => "email3\@example.com",
            entry => "email3\@example.com : TestTopic1 (3)",
            topicsout =>
"TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122 TestTopic1221"
        },

        {
            name  => "Comma separated list of subscriptions",
            email => "email4\@example.com",
            entry => "email4\@example.com: TestTopic1 (0), 'TestTopic2' (3)",
            topicsout => "TestTopic1 TestTopic2 TestTopic21"
        },

        {
            name  => "mix of commas, pluses and minuses",
            email => "email5\@example.com",
            entry =>
"email5\@example.com: TestTopic1 + 'TestTopic2'(3), -'TestTopic21'",
            topicsout => "TestTopic1 TestTopic2"
        },

        {
            name      => "wildcard",
            email     => "email6\@example.com",
            entry     => "email6\@example.com: TestTopic1*1",
            topicsout => "TestTopic11 TestTopic111 TestTopic121 TestTopic1221"
        },

        {
            name  => "wildcard unsubscription",
            email => "email7\@example.com",
            entry => "email7\@example.com: TestTopic*1 - \\\n   'TestTopic2*'",
            topicsout =>
              "TestTopic1 TestTopic11 TestTopic111 TestTopic1221 TestTopic121",
        },

        {
            name      => "Strange group name; just checking parser, here",
            email     => "email8\@example.com",
            entry     => "'IT:admins': TestTopic1",
            topicsout => "",
        },

        {
            name      => "Item9898: trailing space",
            email     => "email9\@example.com",
            entry     => "FruitBat:  ",
            topicsout => ""
        },

        {
            name =>
"Item11138: no trailing space after : incorrectly results in subscribe to all",
            email     => "email10\@example.com",
            entry     => "email10\@example.com :",
            topicsout => ""
        },

        {
            name      => "wikiname allowed, email denied",
            email     => "jeltz\@vogsphere.com",
            entry     => "ProstectnicVogonJeltz - jeltz\@vogsphere.com",
            topicsout => "* -TestTopicDenied"
        },

        {
            name =>
"Item12786: 'TestTopic111' should not match 'FakeTestTopic1 FakeTestTopic11'",
            email     => "email11\@example.com",
            entry     => "email11\@example.com: FakeTestTopic1 FakeTestTopic11",
            topicsout => ""
        },

        # High-bit chars
        {
            name      => "High bit",
            email     => "test1\@example.com",
            entry     => "TestUser1 : Requêtes*",
            topicsout => "RequêtesNon RequêtesOui",
        },

        # Multi-byte chars
        {
            name      => 'Multi byte',
            email     => "test2\@example.com",
            entry     => 'TestUser1 : 官話',
            topicsout => '官話'
        }
    );

    my $s = "";
    foreach my $spec (@specs) {
        $s .= "   * $spec->{entry}\n";
    }
    foreach my $web ( $this->{test_web}, $testWeb2 ) {
        my ($meta) =
          Foswiki::Func::readTopic( $web, $Foswiki::cfg{NotifyTopicName} );
        $meta->put( "TOPICPARENT", { name => "$web.WebHome" } );
        $meta->text("Before\n${s}After");
        $meta->save();
        $meta->finish();
        for my $testTopic ( keys %expectedRevs ) {
            my $parent = 'WebHome';
            if ( $testTopic =~ /^TestTopic(\d+)\d$/ ) {
                $parent = 'TestTopic' . $1;
            }
            ($meta) = Foswiki::Func::readTopic( $web, $testTopic );
            $meta->put( "TOPICPARENT", { name => $parent } );
            $meta->text("This is $testTopic so there");
            $meta->save();
            $meta->finish();
        }

        # add a second rev to TestTopic2 so the base rev is 2
        ($meta) = Foswiki::Func::readTopic( $web, "TestTopic2" );
        $meta->text("This is TestTopic2 so there");
        $meta->save( forcenewrevision => 1 );
        $meta->finish();

        # stamp the baseline
        my $metadir = Foswiki::Func::getWorkArea('MailerContrib');
        my $dirpath = $web;
        $dirpath =~ s#/#.#g;
        $this->assert( open( F, '>', "$metadir/$dirpath" ),
            "$metadir/$dirpath: $!" );
        print F time();
        close(F);

        # wait a wee bit for the clock to tick over
        sleep(1);

        ($meta) = Foswiki::Func::readTopic( $web, "TestTopic1" );
        $meta->text("not the last word");
        $meta->save( forcenewrevision => 1 );
        $meta->finish();

        # wait a wee bit more for the clock to tick over again
        # TestTopic1 should now have two change records in the period, so
        # should be going from rev 1 to rev 3
        # which is why 1 should be last in the list
        sleep(1);

        for my $testTopic ( reverse sort keys %expectedRevs ) {
            ($meta) = Foswiki::Func::readTopic( $web, $testTopic );
            $meta->text( $finalText{$testTopic} );
            $meta->save( forcenewrevision => 1 );
            $meta->finish();
        }

    }

    # OK, we should have a bunch of changes
}

sub checkSpecs {
    my $this = shift;

    # Check that expected - and only specced - mails were received
    my %matched;
    foreach my $message (@FoswikiFnTestCase::mails) {
        next unless $message;
        $message =~ /^To: (.*)$/m;
        my $mailto = $1;
        $this->assert( $mailto, $message );
        foreach my $spec (@specs) {
            if ( $mailto eq $spec->{email} ) {
                $this->assert( !$matched{$mailto} );
                $matched{$mailto} = 1;
                my $xpect = $spec->{topicsout};
                my @tops;
                foreach my $x ( split( /\s+/, $xpect ) ) {
                    next unless defined $x && $x ne '';
                    if ( $x eq '*' ) {
                        @tops = keys %expectedRevs;
                    }
                    elsif ( $x =~ s/^-// ) {
                        @tops = grep { !/^$x$/ } @tops;
                    }
                    else {
                        push( @tops, $x );
                    }
                }
                foreach my $x (@tops) {
                    unless (
                        $message =~ s/^- $x \(.*\) $expectedRevs{$x}.*$//m )
                    {
                        $this->assert( 0,
                                "$mailto should see changes to "
                              . join( ' ', @tops ) . "\n"
                              . " but $x was missing from the mail" );
                    }
                }

                # Make sure no other topics crept through
                if ( $message =~ /^- \w+ \(/m ) {
                    $this->assert( 0,
                            "$mailto should see changes to "
                          . join( ' ', @tops ) . "\n"
                          . " but the mail also had\n$message" );
                }
                last;
            }
        }
    }
    foreach my $spec (@specs) {
        if ( $spec->{topicsout} ne "" ) {
            $this->assert(
                $matched{ $spec->{email} },
                "Expected mails for "
                  . $spec->{email}
                  . " but only saw mails for "
                  . join( " ", keys %matched )
            );
        }
        else {
            $this->assert(
                !$matched{ $spec->{email} },
                "Didn't expect mails for "
                  . $spec->{email}
                  . "; got "
                  . join( " ", keys %matched )
            );
        }
    }
}

sub testSimple {
    my $this = shift;

    my @webs = ( $this->{test_web}, $this->{users_web} );
    Foswiki::Contrib::MailerContrib::mailNotify(
        \@webs, undef,
        news    => 1,
        changes => 1,
        mail    => 1
    );

    #print "REPORT\n",join("\n\n", @FoswikiFnTestCase::mails);

    $this->checkSpecs();
}

sub testSubweb {
    my $this = shift;

    my @webs = ( $testWeb2, $this->{users_web} );
    Foswiki::Contrib::MailerContrib::mailNotify(
        \@webs, undef,
        news    => 1,
        changes => 1,
        mail    => 1
    );

    #print "REPORT\n",join("\n\n", @FoswikiFnTestCase::mails);

    $this->checkSpecs();
}

sub testCovers {
    my $this = shift;

    my $s1 = new Foswiki::Contrib::MailerContrib::Subscription( 'A', 0, 0 );
    $this->assert( $s1->covers($s1) );

    my $s2 = new Foswiki::Contrib::MailerContrib::Subscription( 'A', 0,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( !$s1->covers($s2) );

    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( 'A', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS |
          Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );
    $this->assert( !$s2->covers($s1) );

    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( 'A*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );
    $this->assert( !$s2->covers($s1) );

    $s2 = new Foswiki::Contrib::MailerContrib::Subscription( 'A', 1,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( !$s1->covers($s2) );
    $this->assert( !$s2->covers($s1) );

    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( 'A*', 1,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );
    $this->assert( !$s2->covers($s1) );

    $s2 = new Foswiki::Contrib::MailerContrib::Subscription( 'A*B', 1,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );
    $this->assert( !$s2->covers($s1) );

    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( 'AxB', 0,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( !$s1->covers($s2) );
    $this->assert( $s2->covers($s1) );

    # * covers everything.
    my $AStar = new Foswiki::Contrib::MailerContrib::Subscription( 'A*', 1,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    my $Star = new Foswiki::Contrib::MailerContrib::Subscription( '*', 1,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $Star->covers($AStar) );
    $this->assert( !$AStar->covers($Star) );

 #as parent-child relationshipd are broken across webs, * should cover topic (2)
    my $ChildrenOfWebHome =
      new Foswiki::Contrib::MailerContrib::Subscription( 'WebHome', 2,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $Star->covers($ChildrenOfWebHome) );
    $this->assert( !$ChildrenOfWebHome->covers($Star) );

    # Special cases involving '*' and modes
    $s2 = new Foswiki::Contrib::MailerContrib::Subscription( 'A', 0, 0 );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0, 0 );
    $this->assert( $s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS );
    $this->assert( $s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS |
          Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );

    $s2 = new Foswiki::Contrib::MailerContrib::Subscription( 'A', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0, 0 );
    $this->assert( !$s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( !$s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS );
    $this->assert( $s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS |
          Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );

    $s2 = new Foswiki::Contrib::MailerContrib::Subscription( 'A', 0,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0, 0 );
    $this->assert( !$s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS );
    $this->assert( !$s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS |
          Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );

    $s2 = new Foswiki::Contrib::MailerContrib::Subscription( 'A', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS |
          Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0, 0 );
    $this->assert( !$s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( !$s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS );
    $this->assert( !$s1->covers($s2) );
    $s1 = new Foswiki::Contrib::MailerContrib::Subscription( '*', 0,
        Foswiki::Contrib::MailerContrib::Subscription::ALWAYS |
          Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC );
    $this->assert( $s1->covers($s2) );
}

# Check filter-in can exlude all
sub testExcludeAll {
    my $this = shift;

    $Foswiki::cfg{MailerContrib}{EmailFilterIn} = '^@@notAnEmail';

    my $s = <<'HERE';
   * bad@disallowed.com: *
   * good@example.com: *
HERE

    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName} );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    $meta->text("Before\n${s}After");
    $meta->save();
    $meta->finish();
    Foswiki::Contrib::MailerContrib::mailNotify(
        [ $this->{test_web} ],
        undef,
        news    => 1,
        changes => 1,
        mail    => 1
    );

    $this->assert( !scalar(@FoswikiFnTestCase::mails),
        "Should not send any mail!" );
}

# Check filter-in on email addresses
sub testExcluded {
    my $this = shift;

    $Foswiki::cfg{MailerContrib}{EmailFilterIn} = '\w+\@example.com';

    my $s = <<'HERE';
   * bad@disallowed.com: *
   * good@example.com: *
HERE

    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName} );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    $meta->text("Before\n${s}After");
    $meta->save();
    $meta->finish();
    Foswiki::Contrib::MailerContrib::mailNotify(
        [ $this->{test_web} ],
        undef,
        news    => 1,
        changes => 1,
        mail    => 1
    );

    my %matched;
    foreach my $message (@FoswikiFnTestCase::mails) {
        next unless $message;
        $message =~ /^To: (.*?)$/m;
        my $mailto = $1;
        $this->assert( $mailto, $message );
        $this->assert_str_equals( 'good@example.com', $mailto, $mailto );
    }

    #print "REPORT\n",join("\n\n", @FoswikiFnTestCase::mails);
}

sub testExpansion {
    my $this = shift;

    my $s = <<'HERE';
%SEARCH{"gribble.com" multiple="on" topic="%TOPIC%" format="   * search@example.com: *"}%
gribble.com
HERE

    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName} );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    $meta->text("Before\n${s}After");
    $meta->save();
    $meta->finish();
    Foswiki::Contrib::MailerContrib::mailNotify(
        [ $this->{test_web} ],
        undef,
        news    => 1,
        changes => 1,
        mail    => 1
    );

    my %matched;
    foreach my $message (@FoswikiFnTestCase::mails) {
        next unless $message;
        $message =~ /^To: (.*?)$/m;
        my $mailto = $1;
        $this->assert( $mailto, $message );
        $this->assert_str_equals( 'search@example.com', $mailto, $mailto );
    }

    #print "REPORT\n",join("\n\n", @FoswikiFnTestCase::mails);
}

# See Foswikitask:1847
sub testExpansion_1847 {
    my $this = shift;

    my $testTopic   = 'TestTopicWebExpansion';
    my $testEmail   = 'email1847@example.com';
    my %shouldMatch = (
        WEB            => $this->{test_web},
        BASEWEB        => $this->{test_web},
        INCLUDINGWEB   => $this->{test_web},
        TOPIC          => $testTopic,
        BASETOPIC      => $testTopic,
        INCLUDINGTOPIC => $testTopic,
    );
    my @token = map {
        my $type = $_;
        map { $_ . $type } ( '', BASE => 'INCLUDING' );
    } qw( WEB TOPIC );
    my $testContent = join "\n", map { "$_: \%$_\%" } @token;

    # Create a WebNotify matching our topic
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName} );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    $meta->text("   * $testEmail: $testTopic!");
    $meta->save();
    $meta->finish();

    # Fill our topic with our test data
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $testTopic );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    $meta->text("This is $testTopic so there");
    $meta->save();

    # stamp the baseline
    my $metadir = Foswiki::Func::getWorkArea('MailerContrib');
    my $dirpath = $this->{test_web};
    $dirpath =~ s#/#.#g;
    $this->assert( open( F, '>', "$metadir/$dirpath" ),
        "$metadir/$dirpath: $!" );
    print F time();
    close(F);

    # wait a wee bit for the clock to tick over
    sleep(1);

    $meta->text("<noautolink>$testContent\n</noautolink>");
    $meta->save( forcenewrevision => 1 );
    $meta->finish();

    # Launch mailNotify
    Foswiki::Contrib::MailerContrib::mailNotify(
        [ $this->{test_web} ],
        undef,
        news    => 1,
        changes => 1,
        mail    => 1
    );

    for my $message (@FoswikiFnTestCase::mails) {
        next unless $message;
        $message =~ /^To: (.*?)$/m;
        my $mailto = $1;
        $this->assert( $mailto, $message );
        $this->assert_str_equals( $testEmail, $mailto, $mailto );
        while ( my ( $key, $value ) = each %shouldMatch ) {
            $this->assert_matches( qr/^$key: $value$/m, $message );
        }
    }
}

sub test_5949 {
    my $this = shift;
    my $s    = <<'HERE';
   * TestUser1: SpringCabbage
HERE
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName} );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    $meta->text("Before\n${s}After");
    $meta->save();
    $meta->finish();

    my $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals( <<HERE, $wn->stringify() );
Before
   * %USERSWEB%.TestUser1: SpringCabbage
After
HERE
}

sub _addRemoveCheck {
    my ( $this, $wn, $add, $remove, $expect ) = @_;
    $wn->subscribe( "TestUser1", $add ) if $add;
    $wn->unsubscribe( "TestUser1", $remove ) if $remove;
    $this->assert_str_equals( <<HERE, $wn->stringify() );
Before
   * %USERSWEB%.TestUser1: $expect
After
HERE
}

sub test_addRemove {
    my $this = shift;
    my $s    = <<'HERE';
   * TestUser1: SpringCabbage
HERE
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName} );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    $meta->text("Before\n${s}After");
    $meta->save();
    $meta->finish();
    my $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );

    $this->_addRemoveCheck(
        $wn,
        "EscherichiaColi ClostridiumDifficile SalmonellaEnterica",
        undef,
        "SpringCabbage EscherichiaColi ClostridiumDifficile SalmonellaEnterica"
    );
    $this->_addRemoveCheck( $wn, undef, "ClostridiumDifficile",
        "SpringCabbage EscherichiaColi SalmonellaEnterica" );
    $this->_addRemoveCheck( $wn, "ClostridiumDifficile", undef,
        "SpringCabbage EscherichiaColi SalmonellaEnterica ClostridiumDifficile"
    );
}

sub test_changeSubscription_and_isSubScribedTo_API {
    my $this = shift;

    #start by removing all subscriptions
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName} );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    $meta->text("Before\nAfter\n");
    $meta->save();
    $meta->finish();

    my $defaultWeb = $this->{test_web};
    my $who        = 'TestUser1';
    my $topicList  = 'WebHome';
    my $unsubscribe;    #undefined == subscribe / do what the topicList says..

    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, $topicList
        )
    );
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        $topicList, $unsubscribe );
    $this->assert(
        Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, $topicList
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebIndex'
        )
    );
    my $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals( "   * %USERSWEB%.$who: $topicList\n",
        $wn->stringify(1) );

    $topicList = '*';
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        $topicList, $unsubscribe );
    $this->assert(
        Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, $topicList
        )
    );
    $this->assert(
        Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebHome'
        )
    );
    $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals( "   * %USERSWEB%.$who: $topicList\n",
        $wn->stringify(1) );

    $topicList = '-*';
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        $topicList, $unsubscribe );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebHome'
        )
    );
    $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );

    #removing * results in nothing.
    $this->assert_equals( '', $wn->stringify(1) );

    $topicList = 'WebHome (2)';
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        $topicList, $unsubscribe );
    $this->assert(
        Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebHome'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebChanges'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'SomethingElse'
        )
    );
    $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals( "   * %USERSWEB%.$who: $topicList\n",
        $wn->stringify(1) );

    $topicList = 'WebIndex';
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        $topicList, $unsubscribe );
    $this->assert(
        Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebHome'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebChanges'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'SomethingElse'
        )
    );
    $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );
    $this->assert_str_equals( "   * %USERSWEB%.$who: WebHome (2) $topicList\n",
        $wn->stringify(1) );

    $topicList   = '*';
    $unsubscribe = '-';
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        $topicList, $unsubscribe );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebHome'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebChanges'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'SomethingElse'
        )
    );
    $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, $topicList
        )
    );

    $topicList   = 'WebHome (2)';
    $unsubscribe = '-';
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        $topicList, $unsubscribe );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebHome'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebChanges'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'SomethingElse'
        )
    );
    $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, $topicList
        )
    );

    #it should remove the - WebHome (2) as un-necessary
    $topicList   = 'WebIndex - WebHome (2)';
    $unsubscribe = undef;
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        $topicList, $unsubscribe );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebHome'
        )
    );
    $this->assert(
        Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebIndex'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebChanges'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'SomethingElse'
        )
    );

# Tests for Item11131: unsubscribe a member of a group by adding a negative subscription

    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb,
        'TestGroup', $topicList, $unsubscribe );

    # Should be subscribed due to the group
    $this->assert(
        Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, 'TestUser3', 'WebIndex'
        )
    );
    $unsubscribe = '-';
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb,
        'TestUser3', $topicList, $unsubscribe );

    # Cannot be unsubscribed as an exception to the group
    $this->assert(
        Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, 'TestUser3', 'WebIndex'
        ),
        'User should still be subscribed as a group member'
    );

    #TODO: not quite implemented - needs a 'covers' test
    #$wn =
    #  new Foswiki::Contrib::MailerContrib::WebNotify(
    #    $this->{test_web}, $Foswiki::cfg{NotifyTopicName}, 1 );
    #$this->assert_str_equals( "   * $who: WebIndex\n", $wn->stringify(1) );
}

# There have been several reports of legacy formats not working, so here's a test
sub test_parseRealTopic {
    my $this = shift;
    Foswiki::Func::saveTopic( $this->{test_web}, "TestWebNotify", undef,
        <<'SEE');
   * FruitBat: 
   * ProstectnicVogonJeltz - jeltz@vogsphere.com
SEE
    my $expect = <<'EXPECT';
   * jeltz@vogsphere.com: *
EXPECT
    my $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        'TestWebNotify', 1 );
    $this->assert_equals( $expect, $wn->stringify() );
}

sub test_12525 {
    my $this = shift;

    # start by removing all subscriptions
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName} );
    $meta->put( "TOPICPARENT", { name => "$this->{test_web}.WebHome" } );
    $meta->text("Before\nAfter\n");
    $meta->save();
    $meta->finish();

    my $defaultWeb = $this->{test_web};
    my $who        = 'TestUser1';
    my $topicList  = 'WebHome';
    my $unsubscribe;
    my $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $this->{test_web},
        $Foswiki::cfg{NotifyTopicName}, 1 );

    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        '*' );
    Foswiki::Contrib::MailerContrib::changeSubscription( $defaultWeb, $who,
        'SomeBogusTopic', '-' );
    $this->assert(
        Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'WebHome'
        )
    );
    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, 'SomeBogusTopic'
        )
    );
}

# Test for Item12786: If subscribed to TestTopic1 and TestTopic 11 it should not match TestTopic111
sub test_doNotMatchPrefix {
    my $this = shift;

    my $defaultWeb = $this->{test_web};
    my $who        = 'email11@example.com';
    my $topicList  = 'FakeTestTopic111';

    $this->assert(
        !Foswiki::Contrib::MailerContrib::isSubscribedTo(
            $defaultWeb, $who, $topicList
        )
    );
}

sub test_access_controls {
    my $this = shift;

    # TestUser1 can access r1, TestUser2 can access r2,
    # TestUser3 can access both
    Foswiki::Func::saveTopic( $this->{test_web}, $Foswiki::cfg{NotifyTopicName},
        undef, <<BLAH);
   * TestUser1: TestNoWayJose
   * TestUser2: TestNoWayJose
   * TestUser3: TestNoWayJose
BLAH
    Foswiki::Func::saveTopic( $this->{test_web}, "TestNoWayJose", undef,
        "   * Set ALLOWTOPICVIEW = TestUser3, TestUser1\n" );
    my $t0 = time;

    # stamp the baseline
    my $metadir = Foswiki::Func::getWorkArea('MailerContrib');
    my $dirpath = $this->{test_web};
    $dirpath =~ s#/#.#g;
    $this->assert( open( F, '>', "$metadir/$dirpath" ),
        "$metadir/$dirpath: $!" );
    print F $t0;
    close(F);

    while ( time == $t0 ) {
        sleep 1;
    }
    Foswiki::Func::saveTopic(
        $this->{test_web}, "TestNoWayJose", undef,
        "   * Set ALLOWTOPICVIEW = TestUser2, TestUser3\n",
        { forcenewrevision => 1 }
    );

    Foswiki::Contrib::MailerContrib::mailNotify(
        [ $this->{test_web} ], undef,
        changes => 1,
        mail    => 1,

        #verbose => 1
    );
    $this->assert_num_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $m1 = $FoswikiFnTestCase::mails[0];
    $this->assert_matches( qr/To: test3\@example.com/s, $m1 );
    $this->assert( $m1 !~ /test1\@example.com/s );
    $this->assert( $m1 !~ /test2\@example.com/s );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
