# These tests cycle through the available store implementations
# and check that calls to the methods of Foswiki::Meta respond
# approrpiately. The tests are cursory, and only intended as a
# "sanity check" of store functionality. More complete tests of
# VC functionality can be found in VCStoreTests and VCHandlerTests.
package VCMetaTests;
use strict;
use warnings;

use FoswikiStoreTestCase();
our @ISA = qw( FoswikiStoreTestCase );

use Foswiki();
use Foswiki::Meta();
use Foswiki::Func();
use Foswiki::OopsException();
use Error qw( :try );

my $testUser1;
my $testUser2;
my $UI_FN;

# Set up the test fixture
sub set_up_for_verify {
    my $this = shift;

    $UI_FN ||= $this->getUIFn('save');

    $Foswiki::cfg{WarningFileName} = "$Foswiki::cfg{TempfileDir}/junk";
    $Foswiki::cfg{LogFileName}     = "$Foswiki::cfg{TempfileDir}/junk";

    $this->createNewFoswikiSession();

    $testUser1 = "DummyUserOne";
    $testUser2 = "DummyUserTwo";
    $this->registerUser( $testUser1, $testUser1, $testUser1,
        $testUser1 . '@example.com' );
    $this->registerUser( $testUser2, $testUser2, $testUser2,
        $testUser2 . '@example.com' );

    return;
}

sub tear_down {
    my $this = shift;
    unlink $Foswiki::cfg{WarningFileName};
    unlink $Foswiki::cfg{LogFileName};
    $this->SUPER::tear_down();

    return;
}

sub verify_notopic {
    my $this  = shift;
    my $topic = "UnitTest1";
    my ($m) = Foswiki::Func::readTopic( $this->{test_web}, "UnitTest1" );
    my $rev = $m->getLatestRev();
    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, $topic ) );
    $this->assert_num_equals( 0, $rev );
    $m->finish();

    return;
}

sub verify_checkin {
    my $this  = shift;
    my $topic = "UnitTest1";
    my $text  = "hi";
    my $user  = $testUser1;

    $this->assert(
        !$this->{session}->topicExists( $this->{test_web}, $topic ) );
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $meta->text($text);
    $meta->save( user => $user );
    my $rev = $meta->getLatestRev();
    $this->assert_num_equals( 1, $rev );

    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic, 0 );
    my $text1 = $meta->text;

    $text1 =~ s/[\s]*$//go;
    $this->assert_str_equals( $text, $text1 );

    # Check revision number from meta data
    my $info = $meta->getRevisionInfo();
    $this->assert_num_equals( 1, $info->{version},
        "Rev from meta data should be 1 when first created $info->{version}" );

    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $info = $meta->getRevisionInfo();
    $this->assert_num_equals( 1, $info->{version} );

    # Check-in with different text, under different user (to force change)
    $this->createNewFoswikiSession($testUser2);
    $text = "bye";
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $info = $meta->getRevisionInfo();
    $meta->save();
    $this->assert_num_equals( 2, $meta->getLatestRev() );

    # Force reload
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic, 0 );
    $info = $meta->getRevisionInfo();
    $this->assert_num_equals( 2, $info->{version},
        "Rev from meta should be 2 after one change" );
    $meta->finish();

    return;
}

sub verify_checkin_attachment {
    my $this = shift;

    # Create topic
    my $topic = "UnitTest2";
    my $text  = "hi";
    my $user  = $testUser1;

    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $meta->text($text);
    $meta->save( user => $user );

    # ensure pub directory for topic exists (SMELL surely not needed?)
    my $dir = $Foswiki::cfg{PubDir};
    $dir = "$dir/$this->{test_web}/$topic";
    if ( !-e "$dir" ) {
        umask(0);
        mkdir( $dir, 0777 );
    }

    my $attachment = "afile.txt";
    $this->assert(
        open( my $FILE, '>', "$Foswiki::cfg{TempfileDir}/$attachment" ) );
    print $FILE "Test attachment\n";
    $this->assert( close($FILE) );

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
    $this->assert(
        open( $FILE, '>', "$Foswiki::cfg{TempfileDir}/$attachment" ) );
    print $FILE "Test attachment\nAnd a second line";
    $this->assert( close($FILE) );

    $meta->attach(
        name => $attachment,
        user => $user,
        file => "$Foswiki::cfg{TempfileDir}/$attachment"
    );

    unlink "$Foswiki::cfg{TempfileDir}/$attachment";

    # Check revision number
    $rev = $meta->getLatestRev($attachment);
    $this->assert_num_equals( 2, $rev );
    $meta->finish();

    return;
}

sub verify_rename {
    my $this = shift;

    my $oldWeb   = $this->{test_web};
    my $oldTopic = "UnitTest2";
    my $newWeb   = $oldWeb;
    my $newTopic = "UnitTest2Moved";
    my $user     = $testUser1;

    my ($meta) = Foswiki::Func::readTopic( $oldWeb, $oldTopic );
    $meta->text("Elucidate the goose");
    $meta->save( user => $user );
    $this->assert( !$this->{session}->topicExists( $newWeb, $newTopic ) );

    my $attachment = "afile.txt";
    $this->assert(
        open( my $FILE, '>', "$Foswiki::cfg{TempfileDir}/$attachment" ) );
    print $FILE "Test her attachment to me\n";
    $this->assert( close($FILE) );
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
    $meta->finish();
    $nmeta->finish();

    return;
}

sub verify_releaselocksonsave {
    my $this  = shift;
    my $topic = "MultiEditTopic";

    # create rev 1 as TestUser1
    my $query = Unit::Request->new(
        {
            originalrev => [0],
            'action'    => ['save'],
            text        => ["Before\nBaseline\nText\nAfter\n"],
        }
    );
    $query->path_info("/$this->{test_web}/$topic");

    $this->createNewFoswikiSession( $testUser1, $query );
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
    my ($m) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    my $t1 = $m->getRevisionInfo()->{date};

    # create rev 2 as TestUser1
    $query = Unit::Request->new(
        {
            originalrev      => ["1_$t1"],
            'action'         => ['save'],
            text             => ["Before\nChanged\nLines\nAfter\n"],
            forcenewrevision => [1],
        }
    );
    $query->path_info("/$this->{test_web}/$topic");
    $this->createNewFoswikiSession( $testUser1, $query );
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
    $query = Unit::Request->new(
        {
            originalrev      => ["1_$t1"],
            'action'         => ['save'],
            text             => ["Before\nSausage\nChips\nAfter\n"],
            forcenewrevision => [1],
        }
    );

    $query->path_info("/$this->{test_web}/$topic");
    $this->createNewFoswikiSession( $testUser2, $query );
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

    $this->assert(
        open(
            my $F, '<', "$Foswiki::cfg{DataDir}/$this->{test_web}/$topic.txt"
        )
    );
    local $/ = undef;
    my $text = <$F>;
    $this->assert( close($F) );
    $this->assert_matches( qr/version="(1.)?3"/, $text );
    $this->assert_matches(
qr/<div\s+class="foswikiConflict">.+version\s+2.*<\/div>\s*Changed\nLines[\s.]+<div/,
        $text
    );
    $this->assert_matches(
qr/<div\s+class="foswikiConflict">.+version\s+new.*<\/div>\s*Sausage\nChips[\s.]+<div/,
        $text
    );

    return;
}

1;
