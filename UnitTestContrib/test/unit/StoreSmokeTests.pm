# Smoke tests for Foswiki::Store
package StoreSmokeTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::Meta;
use Error qw( :try );
use Foswiki::OopsException;
use Devel::Symdump;

my $testUser1;
my $testUser2;
my $UI_FN;

sub fixture_groups {
    my @groups;
    foreach my $dir (@INC) {
        if ( opendir( D, "$dir/Foswiki/Store" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ s/^(.*)\.pm$/$1/;
                next if defined &$alg;
                $ENV{PATH} =~ /^(.*)$/ms;
                $ENV{PATH} = $1;
                if ($alg =~ /RcsWrap/) {
                    eval {
                        `co -V`;    # Check to see if we have co
                    };
                    if ( $@ || $? ) {
                        print STDERR "*** CANNOT RUN RcsWrap TESTS - NO COMPATIBLE co: $@\n";
                        next;
                    }
                }
                ($alg) = $alg =~ /^(.*)$/ms;
                eval "require Foswiki::Store::$alg";
                die $@ if $@;
                no strict 'refs';
                *$alg = sub {
                    my $this = shift;
                    $Foswiki::cfg{Store}{Implementation} =
                      'Foswiki::Store::'.$alg;
                    $this->set_up_for_verify();
                };
                use strict 'refs';
                push(@groups, $alg);
            }
            closedir(D);
        }
    }
    return \@groups;
}

# Set up the test fixture
sub set_up_for_verify {
    my $this = shift;

    $UI_FN ||= $this->getUIFn('save');

    $Foswiki::cfg{WarningFileName} = "$Foswiki::cfg{TempfileDir}/junk";
    $Foswiki::cfg{LogFileName}     = "$Foswiki::cfg{TempfileDir}/junk";

    $this->{session} = new Foswiki();

    $testUser1 = "DummyUserOne";
    $testUser2 = "DummyUserTwo";
    $this->registerUser( $testUser1, $testUser1, $testUser1,
        $testUser1 . '@example.com' );
    $this->registerUser( $testUser2, $testUser2, $testUser2,
        $testUser2 . '@example.com' );
}

sub tear_down {
    my $this = shift;
    unlink $Foswiki::cfg{WarningFileName};
    unlink $Foswiki::cfg{LogFileName};
    $this->SUPER::tear_down();
}

sub verify_notopic {
    my $this  = shift;
    my $topic = "UnitTest1";
    my $m =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "UnitTest1" );
    my $rev = $m->getLatestRev();
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, $topic ) );
    $this->assert_num_equals( 0, $rev );
}

sub verify_checkin {
    my $this  = shift;
    my $topic = "UnitTest1";
    my $text  = "hi";
    my $user  = $testUser1;

    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, $topic ) );
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic, $text );
    $meta->save( user => $user );
    my $rev = $meta->getLatestRev();
    $this->assert_num_equals( 1, $rev );

    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, $topic, 0 );
    my $text1 = $meta->text;

    $text1 =~ s/[\s]*$//go;
    $this->assert_str_equals( $text, $text1 );

    # Check revision number from meta data
    my $info = $meta->getRevisionInfo();
    $this->assert_num_equals( 1, $info->{version},
        "Rev from meta data should be 1 when first created $info->{version}" );

    $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );
    $info = $meta->getRevisionInfo();
    $this->assert_num_equals( 1, $info->{version} );

    # Check-in with different text, under different user (to force change)
    $this->{session}->finish();
    $this->{session} = new Foswiki($testUser2);
    $text = "bye";
    $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );
    $info = $meta->getRevisionInfo();
    $meta->save();
    $this->assert_num_equals( 2, $meta->getLatestRev() );

    # Force reload
    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, $topic, 0 );
    $info = $meta->getRevisionInfo();
    $this->assert_num_equals( 2, $info->{version},
        "Rev from meta should be 2 after one change" );
}

sub verify_checkin_attachment {
    my $this = shift;

    # Create topic
    my $topic = "UnitTest2";
    my $text  = "hi";
    my $user  = $testUser1;

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic, $text );
    $meta->save( user => $user );

    # ensure pub directory for topic exists (SMELL surely not needed?)
    my $dir = $Foswiki::cfg{PubDir};
    $dir = "$dir/$this->{test_web}/$topic";
    if ( !-e "$dir" ) {
        umask(0);
        mkdir( $dir, 0777 );
    }

    my $attachment = "afile.txt";
    open( FILE, ">$Foswiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test attachment\n";
    close(FILE);

    my $saveCmd         = "";
    my $doNotLogChanges = 0;
    my $doUnlock        = 1;

    $meta->attach(
        name => $attachment,
        user => $user,
        file => "$Foswiki::cfg{TempfileDir}/$attachment"
    );
    unlink "$Foswiki::cfg{TempfileDir}/$attachment";

    # Check revision number
    my $rev = $meta->getLatestRev($attachment);
    $this->assert_num_equals( 1, $rev );

    # Save again and check version number goes up by 1
    open( FILE, ">$Foswiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test attachment\nAnd a second line";
    close(FILE);

    $meta->attach(
        name => $attachment,
        user => $user,
        file => "$Foswiki::cfg{TempfileDir}/$attachment"
    );

    unlink "$Foswiki::cfg{TempfileDir}/$attachment";

    # Check revision number
    $rev = $meta->getLatestRev($attachment);
    $this->assert_num_equals( 2, $rev );
}

sub verify_rename {
    my $this = shift;

    my $oldWeb   = $this->{test_web};
    my $oldTopic = "UnitTest2";
    my $newWeb   = $oldWeb;
    my $newTopic = "UnitTest2Moved";
    my $user     = $testUser1;

    my $meta =
      Foswiki::Meta->new( $this->{session}, $oldWeb, $oldTopic,
        "Elucidate the goose" );
    $meta->save( user => $user );
    $this->assert( !$this->{session}->topicExists( $newWeb, $newTopic ) );

    my $attachment = "afile.txt";
    open( FILE, ">$Foswiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test her attachment to me\n";
    close(FILE);
    $user = $testUser2;
    $this->{session}->{user} = $user;
    $meta->attach(
        name => $attachment,
        user => $user,
        file => "$Foswiki::cfg{TempfileDir}/$attachment"
    );

    my $oldRevAtt = $meta->getLatestRev($attachment);
    my $oldRevTop = $meta->getLatestRev();

    $user = $testUser1;
    $this->{session}->{user} = $user;

    #$Foswiki::Sandbox::_trace = 1;
    my $nmeta = Foswiki::Meta->new( $this->{session}, $newWeb, $newTopic );
    $this->{session}->{store}->moveTopic( $meta, $nmeta, $user );

    #$Foswiki::Sandbox::_trace = 0;

    $this->assert( !$this->{session}->topicExists( $oldWeb, $oldTopic ) );
    $this->assert( $this->{session}->topicExists( $newWeb, $newTopic ) );
    $this->assert( $nmeta->hasAttachment($attachment) );

    my $newRevAtt = $nmeta->getLatestRev($attachment);
    $this->assert_num_equals( $oldRevAtt, $newRevAtt );
}

sub verify_releaselocksonsave {
    my $this  = shift;
    my $topic = "MultiEditTopic";
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );

    # create rev 1 as TestUser1
    my $query = new Unit::Request(
        {
            originalrev => [0],
            'action'    => ['save'],
            text        => ["Before\nBaseline\nText\nAfter\n"],
        }
    );
    $query->path_info("/$this->{test_web}/$topic");

    $this->{session} = new Foswiki( $testUser1, $query );
    try {
        $this->captureWithKey( save => $UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    }
    catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # get the date
    my $m = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $topic );
    my $t1 = $m->getRevisionInfo()->{date};

    # create rev 2 as TestUser1
    $query = new Unit::Request(
        {
            originalrev      => ["1_$t1"],
            'action'         => ['save'],
            text             => ["Before\nChanged\nLines\nAfter\n"],
            forcenewrevision => [1],
        }
    );
    $query->path_info("/$this->{test_web}/$topic");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $testUser1, $query );
    try {
        $this->captureWithKey( save => $UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    }
    catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # now TestUser2 has a go, based on rev 1
    $query = new Unit::Request(
        {
            originalrev      => ["1_$t1"],
            'action'         => ['save'],
            text             => ["Before\nSausage\nChips\nAfter\n"],
            forcenewrevision => [1],
        }
    );

    $query->path_info("/$this->{test_web}/$topic");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $testUser2, $query );
    try {
        $this->captureWithKey( save => $UI_FN, $this->{session} );
        $this->annotate(
"\na merge notice exception should have been thrown for /$this->{test_web}/$topic"
        );
        $this->assert(0);
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_equals( 'attention',    $e->{template} );
        $this->assert_equals( 'merge_notice', $e->{def} );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->{-text} );
    };

    open( F, "<$Foswiki::cfg{DataDir}/$this->{test_web}/$topic.txt" );
    local $/ = undef;
    my $text = <F>;
    close(F);
    $this->assert_matches( qr/version="(1.)?3"/, $text );
    $this->assert_matches(
qr/<div\s+class="foswikiConflict">.+version\s+2.*<\/div>\s*Changed\nLines[\s.]+<div/,
        $text
    );
    $this->assert_matches(
qr/<div\s+class="foswikiConflict">.+version\s+new.*<\/div>\s*Sausage\nChips[\s.]+<div/,
        $text
    );

}

1;
