# Copyright (C) 2012 Crawford Currie
#
# Tests for the Foswiki::Store API used by the Foswiki::Meta class to
# interact with the store.
#
# These tests must be independent of the actual store implementation.
#
# Note that these tests do *not* cover functionality that is implemented
# by the Foswiki::Meta class; they are focused on testing the low-level
# store implementation only.
#
# NOTE:
# No method of the Foswiki::Meta class should be called other than "new"
# No method of Foswiki::Func should be called
#
package StoreImplementationTests;
use strict;
use warnings;
require 5.008;

use FoswikiStoreTestCase();
our @ISA = qw( FoswikiStoreTestCase );

use Assert;
use Foswiki       ();
use Foswiki::Meta ();
use Error qw( :try );

my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
my $data2 = "$data XXX $data";

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $Foswiki::cfg{Site}{Locale} = 'en_US.utf-8';
    $Foswiki::cfg{UseLocale} = 1;

    $this->{tmpdatafile} = "$Foswiki::cfg{TempfileDir}/testfile.gif";
    ASSERT( open( my $FILE, '>', $this->{tmpdatafile} ) );
    print $FILE $data;
    ASSERT( close($FILE) );

    # Ignore the standard {test_web} and {test_topic} - they were created
    # using the default store, and we're changing the store impl.

    $this->{t_web}   = 'TemporaryStoreTestsWeb';
    $this->{t_web2}  = 'TemporaryStoreTestsWeb2';
    $this->{t_topic} = 'TestTopic';

    return;
}

sub tear_down {
    my $this = shift;

    # {sut} is still active
    $this->removeWeb( $this->{t_web} )
      if ( $this->{sut}->webExists( $this->{t_web} ) );
    $this->removeWeb( $this->{t_web2} )
      if ( $this->{sut}->webExists( $this->{t_web2} ) );
    unlink( $this->{tmpdatafile} );
    $this->SUPER::tear_down();

    return;
}

sub set_up_for_verify {
    my $this = shift;

    # have to do this because the store impl changes
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );

    # {sut} == store under test
    $this->{sut} = $this->{session}->{store};

    # No pre-existing webs or topics (except users and System, which we
    # quietly ignore here)
    $this->assert( !$this->{sut}->webExists( $this->{t_web} ) );
    $this->assert( !$this->{sut}->webExists( $this->{t_web2} ) );

    return;
}

# Create a simple topic containing only text
sub verify_simpleTopic {
    my $this = shift;

    my ( $web, $topic ) = ( $this->{t_web}, $this->{t_topic} );
    my $webObject = $this->populateNewWeb($web);
    $webObject->finish();

    $this->assert( !$this->{sut}->topicExists( $web, $topic ) );
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $meta->text("1 2 3");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    $this->assert( $this->{sut}->topicExists( $web, $topic ) );
    $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    my ( $rev, $isLatest ) = $this->{sut}->readTopic($meta);
    $this->assert_num_equals( 1, $rev );
    $this->assert($isLatest);
    $this->assert_str_equals( "1 2 3", $meta->text );
    $meta->text("4 5 6");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $this->{sut}->readTopic($meta, 1);
    $this->assert_equals("1 2 3", $meta->text());
    $meta->finish();

    $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $this->{sut}->readTopic($meta, 2);
    $this->assert_equals("4 5 6", $meta->text());
    $meta->finish();

    return;
}

sub _makeWeb {
    my ( $this, $both ) = @_;
    my $webObject = $this->populateNewWeb( $this->{t_web} );
    $webObject->finish();
    if ($both) {
        $webObject = $this->populateNewWeb( $this->{t_web2} );
        $webObject->finish();
    }
}

sub verify_eachTopic_eachWeb {
    my $this = shift;

    my ( $web, $topic ) = ( $this->{t_web}, $this->{t_topic} );
    $this->_makeWeb();
    my $webObject = $this->populateNewWeb("$this->{t_web}/Blah");
    $webObject->finish();

    $this->assert( $this->{sut}->webExists($web) );
    $webObject = Foswiki::Meta->new( $this->{session}, $web );
    my @topics = $this->{sut}->eachTopic($webObject)->all();
    my $tops = join( " ", @topics );
    $this->assert_equals( 1, scalar(@topics), $tops )
      ;    # we expect there to be only the preferences topic
    my $wit = $this->{sut}->eachWeb($webObject);
    $webObject->finish();
    my @webs = $wit->all();
    $this->assert_num_equals( 1, scalar(@webs) );
    $this->assert_equals( "Blah",                           $webs[0] );
    $this->assert_equals( $Foswiki::cfg{WebPrefsTopicName}, $tops );

    return;
}

# Get the revision diff
sub verify_getRevisionDiff {
    my $this = shift;

    my ( $web, $topic ) = ( $this->{t_web}, $this->{t_topic} );
    $this->_makeWeb();

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $meta->text($text);
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $this->assert_equals( 1, $meta->getLatestRev() );
    $meta->finish();

    $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $text =~ s/content/maladjusted/;
    $text .= "\nnewline";
    $meta->text($text);
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    my $readMeta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    my $readText = $readMeta->text;

    # ignore whitespace at end of data
    $readText =~ s/\s*$//s;
    $this->assert_equals( $text, $readText );
    $this->assert_equals( 2,     $readMeta->getLatestRev() );

    # SMELL: not a complete test by any stretch of the imagination
    my $diffs = $this->{sut}->getRevisionDiff( $readMeta, 1, 2 );

    my $expect;

    #print STDERR Data::Dumper->Dump([$diffs]);
    unless ( $Foswiki::cfg{Store}{Implementation} =~ /RcsWrap/ ) {

        # RcsLite, PlainFile
        $expect = [
            [ 'u', 'This is some test text', 'This is some test text' ],
            [ 'u', '   * some list',         '   * some list' ],
            [ 'c', '   * maladjusted',       '   * content' ],
            [ 'u', ' :) :)',                 ' :) :)' ],
            [ '-', 'newline',                '' ]
        ];
    }
    else {
        $expect = [
	    [ 'l', '1', '1' ],
            [ 'u', 'This is some test text', 'This is some test text' ],
            [ 'u', '   * some list',         '   * some list' ],
            [ '-', '   * maladjusted',       '' ],
            [ '+', '',                       '   * content' ],
            [ 'u', ' :) :)',                 ' :) :)' ],
            [ '-', 'newline',                '' ],
            [
                'u',
                '\\ No newline at end of file',
                '\\ No newline at end of file'
            ]
        ];
    }
    $this->assert_num_equals( $#$expect, $#$diffs );
    foreach my $e (@$expect) {
        my $r = shift @$diffs;
        $this->assert_equals( $e->[0], $r->[0] );
        $this->assert_equals( $e->[1], $r->[1] );
        $this->assert_equals( $e->[2], $r->[2] );
    }

    $this->removeFromStore($web);
    $readMeta->finish();
    $meta->finish();

    return;
}

sub verify_getRevisionInfo {
    my $this = shift;

    my ( $web, $topic ) = ( $this->{t_web}, $this->{t_topic} );
    $this->_makeWeb();

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $meta->text($text);
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $this->assert_equals( 1, $meta->getLatestRev() );

    $text .= "\nnewline";
    $meta->text($text);
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );

    my $readMeta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    my $readText = $readMeta->text;

    # ignore whitespace at end of data
    $readText =~ s/\s*$//s;
    $this->assert_equals( $text, $readText );
    $this->assert_equals( 2,     $readMeta->getLatestRev() );
    my $info = $this->{sut}->getVersionInfo($readMeta);
    $this->assert_num_equals( 2, $info->{version} );
    $info = $this->{sut}->getVersionInfo( $readMeta, 1 );
    $this->assert_num_equals( 1, $info->{version} );

    $this->removeFromStore($web);
    $readMeta->finish();
    $meta->finish();

    return;
}

# Move a topic to another name in the same web
sub verify_moveTopic {
    my $this = shift;
    $this->_makeWeb(1);

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    $meta->text($text);
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );

    $text =
"This is some test text\n   * some list\n   * $this->{t_topic}\n   * content\n :) :)";
    $meta->finish();
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web},
        $this->{t_topic} . 'a' );
    $meta->text($text);
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web},
        $this->{t_topic} . 'b' );
    $meta->text($text);
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web},
        $this->{t_topic} . 'c' );
    $meta->text($text);
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    my $f;
    open( $f, '<', $this->{tmpdatafile} );
    $this->{sut}
      ->saveAttachment( $meta, "Attachment1", $f, $this->{test_user_cuid},
        'Feasgar Bha' );
    $this->assert( $this->{sut}->attachmentExists( $meta, "Attachment1" ) );
    $meta->finish();

    my $metaOrig =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    my $metaNew =
      Foswiki::Meta->new( $this->{session}, $this->{t_web2}, 'TopicMovedHere' );
    $this->assert(
        !$this->{sut}->topicExists( $this->{t_web2}, 'TopicMovedHere' ) );
    $this->{sut}->moveTopic( $metaOrig, $metaNew, $this->{test_user_cuid} );

    $this->assert(
        !$this->{sut}->topicExists( $this->{t_web}, $this->{t_topic} ) );
    $this->assert(
        $this->{sut}->topicExists( $this->{t_web2}, 'TopicMovedHere' ) );
    $this->assert(
        !$this->{sut}->attachmentExists( $metaOrig, "Attachment1" ) );
    $this->assert( $this->{sut}->attachmentExists( $metaNew, "Attachment1" ) );

    $metaOrig->finish();
    $metaNew->finish();

    return;
}

sub verify_saveTopic {
    my $this = shift;

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    $meta->text("1 2 3");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );

# Note that the forcedate must be >= the date of the most recent revision of the
# topic - hence the sleep.
    my $t = time;
    sleep(1);
    $meta->text("Catch that pigeon!");
    $this->{sut}
      ->saveTopic( $meta, $this->{test_user_cuid}, { forcedate => $t } );
    my $info = $this->{sut}->getVersionInfo($meta);
    $this->assert( $info->{date} - $t < 5 );
    $this->assert_num_equals( 2, $info->{version} );

# SMELL: Following test commented out because RcsWrap and RcsLite both fail when
# forcedate is used
#$this->assert($this->{sut}->getApproxRevTime($this->{t_web}, $this->{t_topic}) - $t < 5, $this->{sut}->getApproxRevTime($this->{t_web}, $this->{t_topic}));
}

sub verify_repRevTopic {
    my $this = shift;

    $this->_makeWeb();

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    $meta->text("Web 1 Topic 1");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );

    # A repRev blows away the first rev, so we can play whatever tricks we like
    # with the date - there's can't be an earlier rev.
    $this->{sut}->repRev( $meta, $this->{test_user_cuid}, forcedate => 1000 );
    my $info = $this->{sut}->getVersionInfo($meta);
    $this->assert( $info->{date} - 1000 < 5, $info->{date} );
    $this->assert_num_equals( 1, $info->{version} );

# SMELL: Following test commented out because RcsWrap and RcsLite both fail when
# forcedate is used
#    $this->assert($this->{sut}->getApproxRevTime($this->{t_web}, $this->{t_topic}) - 1000 < 5);
}

sub verify_eachChange {
    my $this = shift;
    my ( $web, $topic ) = ( $this->{t_web}, $this->{t_topic} );
    $this->_makeWeb();

    $Foswiki::cfg{Store}{RememberChangesFor} = 5;    # very bad memory
    sleep(1);
    my $start = time();
    my $meta = Foswiki::Meta->new( $this->{session}, $web, "ClutterBuck" );
    $meta->text("One");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();
    $meta = Foswiki::Meta->new( $this->{session}, $web, "PiggleNut" );
    $meta->text("One");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );

    # Wait a second
    sleep(1);
    my $mid = time();
    $meta->finish();
    $meta = Foswiki::Meta->new( $this->{session}, $web, "ClutterBuck" );
    $meta->text("One");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();
    $meta = Foswiki::Meta->new( $this->{session}, $web, "PiggleNut" );
    $meta->text("Two");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    my $change;
    my $it = $this->{sut}->eachChange( $meta, $start );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 2, $change->{revision} );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 2, $change->{revision} );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 1, $change->{revision} );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 1, $change->{revision} );
    $this->assert( !$it->hasNext() );
    $it = $this->{sut}->eachChange( $meta, $mid );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 2, $change->{revision} );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 2, $change->{revision} );
    $this->assert( !$it->hasNext() );
    $meta->finish();

    return;
}

sub verify_openAttachment {
    my $this = shift;

    $this->_makeWeb();

    ASSERT( open( my $FILE, '>', "$this->{tmpdatafile}2" ) );
    print $FILE $data2;
    ASSERT( close($FILE) );

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    $meta->text("One");
    $meta->attach(
        name    => "testfile.gif",
        file    => $this->{tmpdatafile},
        comment => "a comment"
    );
    $meta->attach(
        name    => "testfile.gif",
        file    => "$this->{tmpdatafile}2",
        comment => "a comment"
    );
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );

    local $/;
    my $f = $this->{sut}->openAttachment($meta, "testfile.gif", "<");
    $this->assert_equals($data2, <$f>);
    close($f);

    $f = $this->{sut}->openAttachment($meta, "testfile.gif", "<", version => 1);
    $this->assert_equals($data, <$f>);
    close($f);
    $f = $this->{sut}->openAttachment($meta, "testfile.gif", "<", version => 2);
    $this->assert_equals($data2, <$f>);
    close($f);

    return;
}

sub verify_eachAttachment {
    my $this = shift;

    $this->_makeWeb();

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    $meta->text("One");
    $meta->attach(
        name    => "testfile.gif",
        file    => $this->{tmpdatafile},
        comment => "a comment"
    );
    $meta->attach(
        name    => "noise.dat",
        file    => $this->{tmpdatafile},
        comment => "a comment"
    );
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );

    my $it = $this->{sut}->eachAttachment($meta);
    my $list = join( ' ', sort $it->all() );
    $this->assert_str_equals( "noise.dat testfile.gif", $list );

    $this->assert( $this->{sut}->attachmentExists( $meta, 'testfile.gif' ) );
    $this->assert( $this->{sut}->attachmentExists( $meta, 'noise.dat' ) );

    my $preDeleteMeta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );

    sleep(1);    #ensure different timestamp on topic text
    $meta->removeFromStore('testfile.gif');
    $meta->finish();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    $this->assert(
        $this->{sut}->topicExists( $this->{t_web}, $this->{t_topic} ) );
    $this->assert( !$this->{sut}->attachmentExists( $meta, 'testfile.gif' ) );
    $this->assert( $this->{sut}->attachmentExists( $meta, 'noise.dat' ) );

    my $postDeleteMeta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );

    $it = $this->{sut}->eachAttachment($postDeleteMeta);
    $list = join( ' ', sort $it->all() );
    $this->assert_str_equals( "noise.dat", $list );
    $preDeleteMeta->finish();
    $postDeleteMeta->finish();

    return;
}

sub verify_moveAttachment {
    my $this = shift;

    $this->_makeWeb(1);

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic1" );
    $meta->text("Web 1 Topic 1");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );

    my $f;
    open( $f, '<', $this->{tmpdatafile} );
    $this->{sut}
      ->saveAttachment( $meta, "Attachment1", $f, $this->{test_user_cuid},
        'Feasgar Bha' );
    $this->assert( $this->{sut}->attachmentExists( $meta, "Attachment1" ) );
    $meta->finish();
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic2" );
    $meta->text("Web 1 Topic 2");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web2}, "Web2Topic1" );
    $meta->text("Web 2 Topic 1");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    # ###############
    # Rename an attachment - from/to web/topic the same
    # Old attachment removed, new attachment exists
    # ###############
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic1" );
    $this->assert( $this->{sut}->testAttachment( $meta, "Attachment1", "f" ) );
    $this->{sut}->moveAttachment( $meta, "Attachment1", $meta, "Attachment2",
        $this->{test_user_cuid} );
    $this->assert( !$this->{sut}->attachmentExists( $meta, "Attachment1" ) );
    $this->assert( $this->{sut}->attachmentExists( $meta, "Attachment2" ) );
    $meta->finish();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic1" );
    $this->{sut}->readTopic($meta);
    my $text = $meta->text();
    my $meta2 =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic2" );
    $this->{sut}->readTopic($meta2);
    my $text2 = $meta2->text();

    # ###############
    # Move an attachment - from/to topic in the same web
    # Old attachment removed, new attachment exists, and
    # source topic text unchanged
    # ###############
    $this->{sut}->moveAttachment( $meta, "Attachment2", $meta2, 'Attachment3',
        $this->{test_user_cuid} );
    $this->assert( !$this->{sut}->attachmentExists( $meta, "Attachment2" ) );
    $this->assert( $this->{sut}->attachmentExists( $meta2, "Attachment3" ) );
    $meta->finish();
    $meta2->finish();

    # ###############
    # Move an attachment - to topic in a different web
    #  Old attachment removed, new attachment exists
    # ###############

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic2" );
    $this->{sut}->readTopic($meta);
    $text = $meta->text();
    $meta2 =
      Foswiki::Meta->new( $this->{session}, $this->{t_web2}, "Web2Topic1" );
    $this->{sut}->readTopic($meta2);
    $text2 = $meta2->text();

    $this->{sut}->moveAttachment( $meta, "Attachment3", $meta2, 'Attachment4',
        $this->{test_user_cuid} );

    $this->assert( !$this->{sut}->attachmentExists( $meta, "Attachment3" ) );
    $this->assert( $this->{sut}->attachmentExists( $meta2, "Attachment4" ) );
    $meta->finish();
    $meta2->finish();

    return;
}

sub verify_copyAttachment {
    my $this = shift;
    $this->_makeWeb(1);

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic1" );
    $meta->text("Web 1 Topic 1");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );

    my $f;
    open( $f, '<', $this->{tmpdatafile} );
    $this->{sut}
      ->saveAttachment( $meta, "Attachment1", $f, $this->{test_user_cuid},
        'Feasgar Bha' );
    $this->assert( $this->{sut}->attachmentExists( $meta, "Attachment1" ) );
    $meta->finish();
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic2" );
    $meta->text("Web 1 Topic 2");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web2}, "Web2Topic1" );
    $meta->text("Web 2 Topic 1");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    # ###############
    # Copy an attachment - from/to web/topic the same
    # ###############
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic1" );

    $this->{sut}->copyAttachment( $meta, "Attachment1", $meta, "Attachment2",
        $this->{test_user_cuid} );
    $this->assert( $this->{sut}->attachmentExists( $meta, "Attachment1" ) );
    $this->assert( $this->{sut}->attachmentExists( $meta, "Attachment2" ) );
    $meta->finish();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic1" );
    $this->{sut}->readTopic($meta);
    my $text = $meta->text();
    my $meta2 =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic2" );
    $this->{sut}->readTopic($meta2);
    my $text2 = $meta2->text();

    # ###############
    # Copy an attachment - from/to topic in the same web
    # ###############
    $this->{sut}->copyAttachment( $meta, "Attachment2", $meta2, 'Attachment3',
        $this->{test_user_cuid} );
    $this->assert( $this->{sut}->attachmentExists( $meta,  "Attachment2" ) );
    $this->assert( $this->{sut}->attachmentExists( $meta2, "Attachment3" ) );
    $meta->finish();
    $meta2->finish();

    # ###############
    # Copy an attachment - to topic in a different web
    # ###############

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "Web1Topic2" );
    $this->{sut}->readTopic($meta);
    $text = $meta->text();
    $meta2 =
      Foswiki::Meta->new( $this->{session}, $this->{t_web2}, "Web2Topic1" );
    $this->{sut}->readTopic($meta2);
    $text2 = $meta2->text();

    $this->{sut}->copyAttachment( $meta, "Attachment3", $meta2, 'Attachment4',
        $this->{test_user_cuid} );

    $this->assert( $this->{sut}->attachmentExists( $meta,  "Attachment3" ) );
    $this->assert( $this->{sut}->attachmentExists( $meta2, "Attachment4" ) );
    $meta->finish();
    $meta2->finish();

    return;
}

sub verify_moveWeb {
    my $this = shift;

    $this->_makeWeb();
    my $meta = Foswiki::Meta->new( $this->{session}, $this->{t_web}, "AttEd" );
    $meta->text("1 2 3");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    $meta = Foswiki::Meta->new( $this->{session}, $this->{t_web}, "AttEd" );
    my $f;
    open( $f, '<', $this->{tmpdatafile} );
    $this->{sut}
      ->saveAttachment( $meta, "Attachment1", $f, $this->{test_user_cuid},
        'Feasgar Bha' );
    $meta->finish();

    my $from = Foswiki::Meta->new( $Foswiki::Plugins::SESSION, $this->{t_web} );
    my $to = Foswiki::Meta->new( $Foswiki::Plugins::SESSION, $this->{t_web2} );
    $this->{sut}->moveWeb( $from, $to, $this->{test_user_cuid} );

    $this->assert( !$this->{sut}->webExists( $this->{t_web} ) );
    $this->assert( $this->{sut}->webExists( $this->{t_web2} ) );
    $this->assert( $this->{sut}->topicExists( $this->{t_web2}, "AttEd" ) );

    $meta = Foswiki::Meta->new( $this->{session}, $this->{t_web2}, "AttEd" );
    $this->assert( $this->{sut}->attachmentExists( $meta, "Attachment1" ) );

    return;
}

sub verify_setLease_getLease {
    my $this = shift;

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    $this->assert_null( $this->{sut}->getLease($meta) );
    my $t = time;
    $this->{sut}->setLease(
        $meta,
        {
            user    => $this->{test_user_cuid},
            expires => $t + 10,
            taken   => $t
        }
    );
    my $l = $this->{sut}->getLease($meta);
    $this->assert_num_equals( $t + 10, $l->{expires} );
    $this->assert_num_equals( $t,      $l->{taken} );
    $this->assert_equals( $this->{test_user_cuid}, $l->{user} );
    $this->{sut}->setLease( $meta, undef );
    $this->assert_null( $this->{sut}->getLease($meta) );

    $this->{sut}->setLease(
        $meta,
        {
            user    => $this->{test_user_cuid},
            expires => $t + 10,
            taken   => $t
        }
    );

    # remove the topic
    $this->{sut}->remove( $this->{test_user_cuid}, $meta );
    $meta->finish();

    $this->{sut}->removeSpuriousLeases( $this->{t_web} );

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, $this->{t_topic} );
    $this->assert_null( $this->{sut}->getLease($meta) );
}

sub verify_delRev {
    my $this = shift;
    $this->_makeWeb();
    my $text = "This is some test text\n   * some list\n   * content\n :) :)";

    my $meta = Foswiki::Meta->new( $this->{session}, $this->{t_web}, "DelRev" );
    $meta->text("Silent");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    $meta = Foswiki::Meta->new( $this->{session}, $this->{t_web}, "DelRev" );

    my $bogus;
    try {
        $this->{sut}->delRev( $meta, $this->{test_user_cuid} );
    }
    catch Error::Simple with {

        # Expected, can't delete initial revision
      } otherwise {
        $bogus = shift;
      };
    $this->assert( !$bogus, $bogus );

    $meta->text("But deadly");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $this->{sut}->delRev( $meta, $this->{test_user_cuid} );
    $meta->finish();
    $meta = Foswiki::Meta->new( $this->{session}, $this->{t_web}, "DelRev" );
    $this->{sut}->readTopic($meta);
    $this->assert_equals( "Silent", $meta->text() );
}

sub verify_atomicLocks {
    my $this = shift;
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "AtomicLock" );
    $meta->text("Kaboom");
    $this->{sut}->saveTopic( $meta, $this->{test_user_cuid} );
    $meta->finish();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{t_web}, "AtomicLock" );
    my ( $u, $t ) = $this->{sut}->atomicLockInfo($meta);
    $this->assert_null($u);
    $this->assert_null($t);

    $this->{sut}->atomicLock( $meta, $this->{test_user_cuid} );
    ( $u, $t ) = $this->{sut}->atomicLockInfo($meta);
    $this->assert_equals( $this->{test_user_cuid}, $u );
    $this->assert( time - $t < 5 );

    $this->{sut}->atomicUnlock( $meta, $this->{test_user_cuid} );
    ( $u, $t ) = $this->{sut}->atomicLockInfo($meta);
    $this->assert_null($u);
    $this->assert_null($t);
    $meta->finish();
}

1;
