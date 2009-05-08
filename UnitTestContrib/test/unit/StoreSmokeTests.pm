# Smoke tests for Foswiki::Store
package StoreSmokeTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::Meta;
use Error qw( :try );
use Foswiki::UI::Save;
use Foswiki::OopsException;
use Devel::Symdump;

my $testUser1;
my $testUser2;

sub RcsLite {
    my $this = shift;
    $Foswiki::cfg{StoreImpl} = 'RcsLite';
    $this->set_up_for_verify();
}

sub RcsWrap {
    my $this = shift;
    $Foswiki::cfg{StoreImpl} = 'RcsWrap';
    $this->set_up_for_verify();
}

sub fixture_groups {
    my $groups = [ 'RcsLite' ];
    eval {
        `co -V`; # Check to see if we have co
    };
    if ($@ || $?) {
        print STDERR "*** CANNOT RUN RcsWrap TESTS - NO COMPATIBLE co: $@\n";
    } else {
        push(@$groups, 'RcsWrap');
    }
    return ( $groups );
}

# Set up the test fixture
sub set_up_for_verify {
    my $this = shift;

    $Foswiki::cfg{WarningFileName} = "$Foswiki::cfg{TempfileDir}/junk";
    $Foswiki::cfg{LogFileName} = "$Foswiki::cfg{TempfileDir}/junk";

    $this->{twiki} = new Foswiki();
    
    $testUser1 = "DummyUserOne";
    $testUser2 = "DummyUserTwo";    
    $this->registerUser($testUser1,
                        $testUser1,
                        $testUser1,
                        $testUser1.'@example.com');
    $this->registerUser($testUser2,
                        $testUser2,
                        $testUser2,
                        $testUser2.'@example.com');
}

sub tear_down {
    my $this = shift;
    unlink $Foswiki::cfg{WarningFileName};
    unlink $Foswiki::cfg{LogFileName};
    $this->SUPER::tear_down();
}

sub verify_notopic {
    my $this = shift;
    my $topic = "UnitTest1";
    my $rev = $this->{twiki}->{store}->getRevisionNumber( $this->{test_web}, "UnitTest1" );
    $this->assert(!$this->{twiki}->{store}->topicExists($this->{test_web}, $topic));
    $this->assert_num_equals(0, $rev);
}

sub verify_checkin {
    my $this = shift;
    my $topic = "UnitTest1";
    my $text = "hi";
    my $user = $testUser1;

    $this->assert(!$this->{twiki}->{store}->topicExists($this->{test_web},$topic));
    $this->{twiki}->{store}->saveTopic( $user, $this->{test_web}, $topic, $text );

    my $rev = $this->{twiki}->{store}->getRevisionNumber( $this->{test_web}, $topic );
    $this->assert_num_equals(1, $rev);

    my( $meta, $text1 ) = $this->{twiki}->{store}->readTopic(
        $user, $this->{test_web}, $topic, undef, 0 );

    $text1 =~ s/[\s]*$//go;
    $this->assert_str_equals( $text, $text1 );

    # Check revision number from meta data
    my( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo();
    $this->assert_num_equals( 1, $revMeta, "Rev from meta data should be 1 when first created $revMeta" );

    $meta = new Foswiki::Meta($this->{twiki}, $this->{test_web}, $topic);
    my( $dateMeta0, $authorMeta0, $revMeta0 ) = $meta->getRevisionInfo();
    $this->assert_num_equals( $revMeta0, $revMeta );
    # Check-in with different text, under different user (to force change)
    $user = $testUser2;
    $text = "bye";

    $this->{twiki}->{store}->saveTopic($user, $this->{test_web}, $topic, $text, $meta );

    $rev = $this->{twiki}->{store}->getRevisionNumber( $this->{test_web}, $topic );
    $this->assert_num_equals(2, $rev );
    ( $meta, $text1 ) = $this->{twiki}->{store}->readTopic( $user, $this->{test_web}, $topic, undef, 0 );
    ( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo();
    $this->assert_num_equals(2, $revMeta, "Rev from meta should be 2 after one change" );
}

sub verify_checkin_attachment {
    my $this = shift;

    # Create topic
    my $topic = "UnitTest2";
    my $text = "hi";
    my $user = $testUser1;

    $this->{twiki}->{store}->saveTopic($user, $this->{test_web}, $topic, $text );

    # ensure pub directory for topic exists (SMELL surely not needed?)
    my $dir = $Foswiki::cfg{PubDir};
    $dir = "$dir/$this->{test_web}/$topic";
    if( ! -e "$dir" ) {
        umask( 0 );
        mkdir( $dir, 0777 );
    }

    my $attachment = "afile.txt";
    open( FILE, ">$Foswiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test attachment\n";
    close(FILE);

    my $saveCmd = "";
    my $doNotLogChanges = 0;
    my $doUnlock = 1;

    $this->{twiki}->{store}->saveAttachment($this->{test_web}, $topic, $attachment, $user,
                                { file => "$Foswiki::cfg{TempfileDir}/$attachment" } );
    unlink "$Foswiki::cfg{TempfileDir}/$attachment";

    # Check revision number
    my $rev = $this->{twiki}->{store}->getRevisionNumber($this->{test_web}, $topic, $attachment);
    $this->assert_num_equals(1,$rev);

    # Save again and check version number goes up by 1
    open( FILE, ">$Foswiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test attachment\nAnd a second line";
    close(FILE);

    $this->{twiki}->{store}->saveAttachment( $this->{test_web}, $topic, $attachment, $user,
                                  { file => "$Foswiki::cfg{TempfileDir}/$attachment" } );

    unlink "$Foswiki::cfg{TempfileDir}/$attachment";

    # Check revision number
    $rev = $this->{twiki}->{store}->getRevisionNumber( $this->{test_web}, $topic, $attachment );
    $this->assert_num_equals(2, $rev);
}

sub verify_rename() {
    my $this = shift;

    my $oldWeb = $this->{test_web};
    my $oldTopic = "UnitTest2";
    my $newWeb = $oldWeb;
    my $newTopic = "UnitTest2Moved";
    my $user = $testUser1;

    $this->{twiki}->{store}->saveTopic($user, $oldWeb, $oldTopic, "Elucidate the goose" );
    $this->assert(!$this->{twiki}->{store}->topicExists($newWeb, $newTopic));

    my $attachment = "afile.txt";
    open( FILE, ">$Foswiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test her attachment to me\n";
    close(FILE);
    $user = $testUser2;
    $this->{twiki}->{userName} = $user;
    $this->{twiki}->{store}->saveAttachment($oldWeb, $oldTopic, $attachment, $user,
                                { file => "$Foswiki::cfg{TempfileDir}/$attachment" } );

    my $oldRevAtt =
      $this->{twiki}->{store}->getRevisionNumber( $oldWeb, $oldTopic, $attachment );
    my $oldRevTop =
      $this->{twiki}->{store}->getRevisionNumber( $oldWeb, $oldTopic );

    $user = $testUser1;
    $this->{twiki}->{user} = $user;

    #$Foswiki::Sandbox::_trace = 1;
    $this->{twiki}->{store}->moveTopic($oldWeb, $oldTopic, $newWeb,
                               $newTopic, $user);
    #$Foswiki::Sandbox::_trace = 0;

    $this->assert(!$this->{twiki}->{store}->topicExists($oldWeb, $oldTopic));
    $this->assert(!$this->{twiki}->{store}->attachmentExists($oldWeb, $oldTopic,
                                                     $attachment));
    $this->assert($this->{twiki}->{store}->topicExists($newWeb, $newTopic));
    $this->assert($this->{twiki}->{store}->attachmentExists($newWeb, $newTopic,
                                                    $attachment));

    my $newRevAtt =
      $this->{twiki}->{store}->getRevisionNumber($newWeb, $newTopic, $attachment );
    $this->assert_num_equals($oldRevAtt, $newRevAtt);

    # Topic is modified in move, because meta information is updated
    # to indicate move
    # THIS IS NOW DONE IN UI::Manage
#    my $newRevTop =
#      $this->{twiki}->{store}->getRevisionNumber( $newWeb, $newTopic );
#    $this->assert_matches(qr/^\d+$/, $newRevTop);
#    my $revTopShouldBe = $oldRevTop + 1;
#    $this->assert_num_equals($revTopShouldBe, $newRevTop );
}

sub verify_releaselocksonsave {
    my $this = shift;
    my $topic = "MultiEditTopic";
    my $meta = new Foswiki::Meta($this->{twiki}, $this->{test_web}, $topic);

    # create rev 1 as TestUser1
    my $query = new Unit::Request ({
                          originalrev => [ 0 ],
                          'action' => [ 'save' ],
                          text => [ "Before\nBaseline\nText\nAfter\n" ],
                         });
    $query->path_info( "/$this->{test_web}/$topic" );

    $this->{twiki} = new Foswiki( $testUser1, $query );
    try {
        $this->captureWithKey(save => \&Foswiki::UI::Save::save, $this->{twiki} );
    } catch Foswiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    } catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # create rev 2 as TestUser1
    $query = new Unit::Request ({
                       originalrev => [ 1 ],
                       'action' => [ 'save' ],
                       text => [ "Before\nChanged\nLines\nAfter\n" ],
                       forcenewrevision => [ 1 ],
                      });
    $query->path_info( "/$this->{test_web}/$topic" );
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $testUser1, $query );
    try {
        $this->captureWithKey( save => \&Foswiki::UI::Save::save,  $this->{twiki} );
    } catch Foswiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    } catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # now TestUser2 has a go, based on rev 1
    $query = new Unit::Request ({
                       originalrev => [ 1 ],
                       'action' => [ 'save' ],
                       text => [ "Before\nSausage\nChips\nAfter\n" ],
                       forcenewrevision => [ 1 ],
                      });

    $query->path_info( "/$this->{test_web}/$topic" );
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $testUser2, $query );
    try {
        $this->captureWithKey( save => \&Foswiki::UI::Save::save,  $this->{twiki} );
        $this->annotate("\na merge notice exception should have been thrown for /$this->{test_web}/$topic");
        $this->assert(0);
    } catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_equals('attention', $e->{template});
        $this->assert_equals('merge_notice', $e->{def});
    } catch Error::Simple with {
        $this->assert(0,shift->{-text});
    };

    open(F,"<$Foswiki::cfg{DataDir}/$this->{test_web}/$topic.txt");
    local $/ = undef;
    my $text = <F>;
    close(F);
    $this->assert_matches(qr/version="1.3"/, $text);
    $this->assert_matches(qr/<div\s+class="twikiConflict">.+version\s+2.*<\/div>\s*Changed\nLines[\s.]+<div/, $text);
    $this->assert_matches(qr/<div\s+class="twikiConflict">.+version\s+new.*<\/div>\s*Sausage\nChips[\s.]+<div/, $text);

}

1;
