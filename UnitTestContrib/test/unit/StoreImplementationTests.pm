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

use Assert;
use Foswiki       ();
use Foswiki::Meta ();
use Try::Tiny;

use Foswiki::Class -types;
extends qw( FoswikiStoreTestCase );

has sut => (
    is  => 'rw',
    isa => InstanceOf ['Foswiki::Store'],
);

sub skip {
    my ( $this, $test ) = @_;
    my $Item11708 = 'Item11708 Store API fixed in Foswiki 1.2+';

    return $this->skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                __PACKAGE__ . '::verify_getRevisionInfo' => $Item11708,
                __PACKAGE__ . '::verify_repRevTopic'     => $Item11708,
            }
        }
    );
}

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    $Foswiki::cfg{ReplaceIfEditedAgainWithin} = 0;
};

sub set_up_for_verify {
    my $this = shift;

    # have to do this because the store impl changes
    $this->createNewFoswikiApp(
        engineParams => {
            initialAttributes =>
              { user => $this->app->cfg->data->{AdminUserLogin}, },
        },
    );

    # {sut} == store under test
    $this->sut( $this->app->store );

    # No pre-existing webs or topics (except users and System, which we
    # quietly ignore here)
    $this->assert( !$this->sut->webExists( $this->t_web ) );
    $this->assert( !$this->sut->webExists( $this->t_web2 ) );
}

# Create a simple topic containing only text
sub verify_simpleTopic {
    my $this = shift;

    my ( $web, $topic ) = ( $this->t_web, $this->t_topic );
    my $webObject = $this->populateNewWeb($web);
    undef $webObject;

    $this->assert( !$this->sut->topicExists( $web, $topic ) );
    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    $meta->text("1 2 3");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;
    $this->assert( $this->sut->topicExists( $web, $topic ) );

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );

    my ( $rev, $isLatest ) = $this->sut->readTopic($meta);

    $this->assert_num_equals( 1, $rev );
    $this->assert($isLatest);

    # Item12472: verify that readTopic has called Meta::setLoadStatus
    $this->assert_num_equals( 1, $meta->getLoadedRev );
    $this->assert( $meta->latestIsLoaded );

    $this->assert_str_equals( "1 2 3", $meta->text );
    $meta->text("4 5 6");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    $this->sut->readTopic( $meta, 1 );
    $this->assert_equals( "1 2 3", $meta->text() );
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    $this->sut->readTopic( $meta, 2 );
    $this->assert_equals( "4 5 6", $meta->text() );
    undef $meta;

    return;
}

sub _makeWeb {
    my ( $this, $both ) = @_;
    my $webObject = $this->populateNewWeb( $this->t_web );
    undef $webObject;
    if ($both) {
        $webObject = $this->populateNewWeb( $this->t_web2 );
        undef $webObject;
    }
}

sub verify_eachTopic_eachWeb {
    my $this = shift;

    my ( $web, $topic ) = ( $this->t_web, $this->t_topic );
    $this->_makeWeb();
    my $webObject = $this->populateNewWeb( $this->t_web . "/Blah" );
    undef $webObject;

    $this->assert( $this->sut->webExists($web) );
    $webObject = $this->create( 'Foswiki::Meta', web => $web );
    my @topics = $this->sut->eachTopic($webObject)->all();
    my $tops = join( " ", @topics );
    $this->assert_equals( 1, scalar(@topics), $tops )
      ;    # we expect there to be only the preferences topic
    my $wit = $this->sut->eachWeb($webObject);
    undef $webObject;
    my @webs = $wit->all();
    $this->assert_num_equals( 1, scalar(@webs) );
    $this->assert_equals( "Blah",                           $webs[0] );
    $this->assert_equals( $Foswiki::cfg{WebPrefsTopicName}, $tops );

    return;
}

# Get the revision diff
sub verify_getRevisionDiff {
    my $this = shift;

    my ( $web, $topic ) = ( $this->t_web, $this->t_topic );
    $this->_makeWeb();

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    $meta->text($text);
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    $this->assert_equals( 1, $meta->getLatestRev() );
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    $text =~ s/content/maladjusted/;
    $text .= "\nnewline";
    $meta->text($text);
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;

    my $readMeta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    my $readText = $readMeta->text;

    # ignore whitespace at end of data
    $readText =~ s/\s*$//s;
    $this->assert_equals( $text, $readText );
    $this->assert_equals( 2,     $readMeta->getLatestRev() );

    # SMELL: not a complete test by any stretch of the imagination
    my $diffs = $this->sut->getRevisionDiff( $readMeta, 1, 2 );

    my $expect;

    #print STDERR Data::Dumper->Dump([$diffs]);
    unless ( $Foswiki::cfg{Store}{Implementation} =~ m/RcsWrap/ ) {

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
            [ 'l', '1',                      '1' ],
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
    undef $readMeta;
    undef $meta;

    return;
}

sub verify_getRevisionInfo {
    my $this = shift;

    my ( $web, $topic ) = ( $this->t_web, $this->t_topic );
    $this->_makeWeb();

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    $meta->text($text);
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    $this->assert_equals( 1, $meta->getLatestRev() );

    $text .= "\nnewline";
    $meta->text($text);
    $this->sut->saveTopic( $meta, $this->test_user_cuid );

    my $readMeta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    my $readText = $readMeta->text;

    # ignore whitespace at end of data
    $readText =~ s/\s*$//s;
    $this->assert_equals( $text, $readText );
    $this->assert_equals( 2,     $readMeta->getLatestRev() );
    my $info = $this->sut->getVersionInfo($readMeta);
    $this->assert_num_equals( 2, $info->{version} );
    $info = $this->sut->getVersionInfo( $readMeta, 1 );
    $this->expect_failure( 'Item11708 Store API fixed in Foswiki 1.2+',
        with_dep => 'Foswiki,<,1.2' );
    $this->assert_num_equals( 1, $info->{version} );

    $this->removeFromStore($web);
    undef $readMeta;
    undef $meta;

    return;
}

# Move a topic to another name in the same web
sub verify_moveTopic {
    my $this = shift;
    $this->_makeWeb(1);

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $meta->text($text);
    $this->sut->saveTopic( $meta, $this->test_user_cuid );

    $text =
        "This is some test text\n   * some list\n   * "
      . $this->t_topic
      . "\n   * content\n :) :)";
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic . 'a'
    );
    $meta->text($text);
    $meta->saveAs();
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic . 'b'
    );
    $meta->text($text);
    $meta->saveAs();
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic . 'c'
    );
    $meta->text($text);
    $meta->saveAs();
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    my $f = $this->open_data('t_datapath');
    $this->sut->saveAttachment( $meta, "Attachment1", $f, $this->test_user_cuid,
        { comment => 'Feasgar " Bha' } );
    $this->assert( $this->sut->attachmentExists( $meta, "Attachment1" ) );
    undef $meta;

    my $metaOrig = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    my $metaNew = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web2,
        topic => 'TopicMovedHere'
    );
    $this->assert(
        !$this->sut->topicExists( $this->t_web2, 'TopicMovedHere' ) );
    $this->sut->moveTopic( $metaOrig, $metaNew, $this->test_user_cuid );

    $this->assert( !$this->sut->topicExists( $this->t_web, $this->t_topic ) );
    $this->assert( $this->sut->topicExists( $this->t_web2, 'TopicMovedHere' ) );
    $this->assert( !$this->sut->attachmentExists( $metaOrig, "Attachment1" ) );
    $this->assert( $this->sut->attachmentExists( $metaNew, "Attachment1" ) );

    undef $metaOrig;
    undef $metaNew;

    return;
}

sub verify_saveTopic {
    my $this = shift;

    $this->_makeWeb();
    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $meta->text("1 2 3");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );

# Note that the forcedate must be >= the date of the most recent revision of the
# topic - hence the sleep.
    my $t = time;
    sleep(1);
    $meta->text("Catch that pigeon!");
    $this->sut->saveTopic( $meta, $this->test_user_cuid, { forcedate => $t } );
    my $info = $this->sut->getVersionInfo($meta);
    $this->assert( $info->{date} - $t < 5 );
    $this->assert_num_equals( 2, $info->{version} );

# SMELL: Following test commented out because RcsWrap and RcsLite both fail when
# forcedate is used
#$this->assert($this->sut->getApproxRevTime($this->t_web, $this->t_topic) - $t < 5, $this->sut->getApproxRevTime($this->t_web, $this->t_topic));
}

sub verify_repRevTopic {
    my $this = shift;
    my $deffo_cuid =
      Foswiki::Func::getCanonicalUserID( Foswiki::Func::getDefaultUserName() );

    $this->_makeWeb();

    # Create topic with a single rev
    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $meta->text("Web 1 Topic 1 Test 1");
    $this->sut->saveTopic( $meta, $deffo_cuid );

    # Replace that rev

    # A repRev when there is only one rev blows away that rev, so we
    # can play whatever tricks we like with the date - there can't be
    # an earlier rev.
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $meta->text("Web 1 Topic 1 Test 2");
    $this->sut->repRev( $meta, $this->test_user_cuid, forcedate => 1000 );
    my $info = $this->sut->getVersionInfo($meta);
    $this->assert_num_equals( 1, $info->{version} );
    $this->assert_str_equals( $this->test_user_cuid, $info->{author} );
    $this->expect_failure( 'Item11708 Store API fixed in Foswiki 1.2+',
        with_dep => 'Foswiki,<,1.2' );
    $this->assert( $info->{date} - 1000 < 5, $info->{date} );

# SMELL: Following test commented out because RcsWrap and RcsLite both fail when
# forcedate is used
#    $this->assert($this->sut->getApproxRevTime($this->t_web, $this->t_topic) - 1000 < 5);

    # Save another change to force a different user
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $meta->text("Web 1 Topic 1 Test 3");
    $meta->saveAs( author => $deffo_cuid, forcenewrevision => 1 );
    $info = $this->sut->getVersionInfo($meta);
    $this->assert_num_equals( 2, $info->{version} );
    $this->assert_str_equals( $deffo_cuid, $info->{author} );

    # repRev it
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $meta->text("Web 1 Topic 1 Test 4");
    $this->sut->repRev( $meta, $deffo_cuid, forcedate => 1000 );
    $info = $this->sut->getVersionInfo($meta);
    $this->assert_num_equals( 2, $info->{version} );

    # Note: it's the responsibility of the caller to set the topic info
    # correctly before calling the store repRev method
    $this->assert_str_equals( $deffo_cuid, $info->{author} );
}

sub verify_eachChange {
    my $this = shift;
    my ( $web, $topic ) = ( $this->t_web, $this->t_topic );
    $this->_makeWeb();

    $Foswiki::cfg{Store}{RememberChangesFor} = 5;    # very bad memory
    sleep(1);
    my $start = time();
    my $meta  = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => "ClutterBuck"
    );
    $meta->text("One");
    $meta->saveAs();
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => "PiggleNut"
    );
    $meta->text("One");
    $meta->saveAs();

    # Wait a second
    sleep(1);
    my $mid = time();
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => "ClutterBuck"
    );
    $meta->text("One");
    $meta->saveAs();
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => "PiggleNut"
    );
    $meta->text("Two Two Two");
    $meta->saveAs();
    my $change;
    my $it = $this->sut->eachChange( $meta, $start );
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

    $this->assert( 1, $this->sut->getRevisionAtTime( $meta, $start ) );
    $this->assert( 2, $this->sut->getRevisionAtTime( $meta, $mid ) );
}

sub verify_openAttachment {
    my $this = shift;

    $this->_makeWeb();

    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $meta->text("One");
    $meta->saveAs();
    $meta->attach(
        name    => $this->t_datafile,
        file    => $this->t_datapath,
        comment => "a comment"
    );
    $meta->attach(
        name    => $this->t_datafile,
        file    => $this->t_datapath2,
        comment => "a comment"
    );

    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );

    local $/;
    my $f = $this->sut->openAttachment( $meta, $this->t_datafile, "<" );
    $this->assert_equals( $this->t_data2, <$f> );
    close($f);

    $f =
      $this->sut->openAttachment( $meta, $this->t_datafile, "<", version => 1 );
    $this->assert_equals( $this->t_data, <$f> );
    close($f);
    $f =
      $this->sut->openAttachment( $meta, $this->t_datafile, "<", version => 2 );
    $this->assert_equals( $this->t_data2, <$f> );
    close($f);

    return;
}

sub verify_eachAttachment {
    my $this = shift;

    $this->_makeWeb();

    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $meta->text("One");
    $meta->saveAs();

    $meta->attach(
        name    => $this->t_datafile,
        file    => $this->t_datapath,
        comment => "a comment"
    );
    $meta->attach(
        name    => $this->t_datafile2,
        file    => $this->t_datapath2,
        comment => "a comment"
    );

    # Create a directory, it should not be returned as an attacment
    # See Item13541
    my $path =
      "$Foswiki::cfg{PubDir}/" . $this->t_web . "/" . $this->t_topic . "/";
    mkdir $path . "bogusempty";

    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );

    my $it   = $this->sut->eachAttachment($meta);
    my @list = $it->all();
    my ( $t_datafile, $t_datafile2 ) =
      ( $this->t_datafile, $this->t_datafile2 );
    $this->assert( scalar(@list) == 2 );
    @list = grep { !/$t_datafile/ } @list;
    $this->assert( scalar(@list) == 1 );
    @list = grep { !/$t_datafile2/ } @list;
    $this->assert( scalar(@list) == 0 );

    $this->assert( $this->sut->attachmentExists( $meta, $this->t_datafile ) );
    $this->assert( $this->sut->attachmentExists( $meta, $this->t_datafile2 ) );

    my $preDeleteMeta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );

    sleep(1);    #ensure different timestamp on topic text
    $meta->removeFromStore( $this->t_datafile );
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $this->assert( $this->sut->topicExists( $this->t_web, $this->t_topic ) );
    $this->assert( !$this->sut->attachmentExists( $meta, $this->t_datafile ) );
    $this->assert( $this->sut->attachmentExists( $meta, $this->t_datafile2 ) );

    my $postDeleteMeta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );

    $it   = $this->sut->eachAttachment($postDeleteMeta);
    @list = $it->all();
    $this->assert( scalar(@list) == 1 );
    $this->assert_str_equals( $this->t_datafile2, $list[0] );
    undef $preDeleteMeta;
    undef $postDeleteMeta;

    return;
}

sub verify_moveAttachment {
    my $this = shift;

    $this->_makeWeb(1);

    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic1"
    );
    $meta->text("Web 1 Topic 1");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );

    my $f = $this->open_data('t_datapath');
    $this->sut->saveAttachment( $meta, "Attachment1", $f, $this->test_user_cuid,
        { comment => 'Feasgar " Bha' } );
    $this->assert( $this->sut->attachmentExists( $meta, "Attachment1" ) );
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic2"
    );
    $meta->text("Web 1 Topic 2");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web2,
        topic => "Web2Topic1"
    );
    $meta->text("Web 2 Topic 1");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;

    # ###############
    # Rename an attachment - from/to web/topic the same
    # Old attachment removed, new attachment exists
    # ###############
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic1"
    );
    $this->assert( $this->sut->testAttachment( $meta, "Attachment1", "f" ) );
    $this->sut->moveAttachment( $meta, "Attachment1", $meta, "Attachment2",
        $this->test_user_cuid );
    $this->assert( !$this->sut->attachmentExists( $meta, "Attachment1" ) );
    $this->assert( $this->sut->attachmentExists( $meta, "Attachment2" ) );
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic1"
    );
    $this->sut->readTopic($meta);
    my $text  = $meta->text();
    my $meta2 = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic2"
    );
    $this->sut->readTopic($meta2);
    my $text2 = $meta2->text();

    # ###############
    # Move an attachment - from/to topic in the same web
    # Old attachment removed, new attachment exists, and
    # source topic text unchanged
    # ###############
    $this->sut->moveAttachment( $meta, "Attachment2", $meta2, 'Attachment3',
        $this->test_user_cuid );
    $this->assert( !$this->sut->attachmentExists( $meta, "Attachment2" ) );
    $this->assert( $this->sut->attachmentExists( $meta2, "Attachment3" ) );
    undef $meta;
    undef $meta2;

    # ###############
    # Move an attachment - to topic in a different web
    #  Old attachment removed, new attachment exists
    # ###############

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic2"
    );
    $this->sut->readTopic($meta);
    $text  = $meta->text();
    $meta2 = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web2,
        topic => "Web2Topic1"
    );
    $this->sut->readTopic($meta2);
    $text2 = $meta2->text();

    $this->sut->moveAttachment( $meta, "Attachment3", $meta2, 'Attachment4',
        $this->test_user_cuid );

    $this->assert( !$this->sut->attachmentExists( $meta, "Attachment3" ) );
    $this->assert( $this->sut->attachmentExists( $meta2, "Attachment4" ) );
    undef $meta;
    undef $meta2;

    return;
}

sub verify_copyAttachment {
    my $this = shift;
    $this->_makeWeb(1);

    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic1"
    );
    $meta->text("Web 1 Topic 1");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );

    my $f = $this->open_data('t_datapath');
    $this->sut->saveAttachment( $meta, "Attachment1", $f, $this->test_user_cuid,
        { comment => 'Feasgar " Bha' } );
    $this->assert( $this->sut->attachmentExists( $meta, "Attachment1" ) );
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic2"
    );
    $meta->text("Web 1 Topic 2");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web2,
        topic => "Web2Topic1"
    );
    $meta->text("Web 2 Topic 1");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;

    # ###############
    # Copy an attachment - from/to web/topic the same
    # ###############
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic1"
    );

    $this->sut->copyAttachment( $meta, "Attachment1", $meta, "Attachment2",
        $this->test_user_cuid );
    $this->assert( $this->sut->attachmentExists( $meta, "Attachment1" ) );
    $this->assert( $this->sut->attachmentExists( $meta, "Attachment2" ) );
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic1"
    );
    $this->sut->readTopic($meta);
    my $text  = $meta->text();
    my $meta2 = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic2"
    );
    $this->sut->readTopic($meta2);
    my $text2 = $meta2->text();

    # ###############
    # Copy an attachment - from/to topic in the same web
    # ###############
    $this->sut->copyAttachment( $meta, "Attachment2", $meta2, 'Attachment3',
        $this->test_user_cuid );
    $this->assert( $this->sut->attachmentExists( $meta,  "Attachment2" ) );
    $this->assert( $this->sut->attachmentExists( $meta2, "Attachment3" ) );
    undef $meta;
    undef $meta2;

    # ###############
    # Copy an attachment - to topic in a different web
    # ###############

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "Web1Topic2"
    );
    $this->sut->readTopic($meta);
    $text  = $meta->text();
    $meta2 = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web2,
        topic => "Web2Topic1"
    );
    $this->sut->readTopic($meta2);
    $text2 = $meta2->text();

    $this->sut->copyAttachment( $meta, "Attachment3", $meta2, 'Attachment4',
        $this->test_user_cuid );

    $this->assert( $this->sut->attachmentExists( $meta,  "Attachment3" ) );
    $this->assert( $this->sut->attachmentExists( $meta2, "Attachment4" ) );
    undef $meta;
    undef $meta2;

    return;
}

sub verify_moveWeb {
    my $this = shift;
    $this->_makeWeb();
    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "AttEd"
    );
    $meta->text("1 2 3");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "AttEd"
    );
    my $f = $this->open_data('t_datapath');
    $this->sut->saveAttachment( $meta, "Attachment1", $f, $this->test_user_cuid,
        { comment => 'Feasgar " Bha' } );
    undef $meta;

    my $from = $this->create( 'Foswiki::Meta', web => $this->t_web );
    my $to   = $this->create( 'Foswiki::Meta', web => $this->t_web2 );

    $this->assert( !$this->sut->webExists( $this->t_web2 ) );
    $this->sut->moveWeb( $from, $to, $this->test_user_cuid );

    $this->assert( !$this->sut->webExists( $this->t_web ) );
    $this->assert( $this->sut->webExists( $this->t_web2 ) );
    $this->assert( $this->sut->topicExists( $this->t_web2, "AttEd" ) );

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web2,
        topic => "AttEd"
    );
    $this->assert( $this->sut->attachmentExists( $meta, "Attachment1" ) );

    return;
}

sub verify_setLease_getLease {
    my $this = shift;

    $this->_makeWeb();
    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $this->assert_null( $this->sut->getLease($meta) );
    my $t = time;
    $this->sut->setLease(
        $meta,
        {
            user    => $this->test_user_cuid,
            expires => $t + 10,
            taken   => $t
        }
    );
    my $l = $this->sut->getLease($meta);
    $this->assert_num_equals( $t + 10, $l->{expires} );
    $this->assert_num_equals( $t,      $l->{taken} );
    $this->assert_equals( $this->test_user_cuid, $l->{user} );
    $this->sut->setLease( $meta, undef );
    $this->assert_null( $this->sut->getLease($meta) );

    $this->sut->setLease(
        $meta,
        {
            user    => $this->test_user_cuid,
            expires => $t + 10,
            taken   => $t
        }
    );

    # remove the topic
    $this->sut->remove( $this->test_user_cuid, $meta );
    undef $meta;

    $this->sut->removeSpuriousLeases( $this->t_web );
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => $this->t_topic
    );
    $this->assert_null( $this->sut->getLease($meta) );
}

sub verify_delRev {
    my $this = shift;
    $this->_makeWeb();
    my $text = "This is some test text\n   * some list\n   * content\n :) :)";

    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "DelRev"
    );
    $meta->text("Silent");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "DelRev"
    );

    my $bogus;
    try {
        $this->sut->delRev( $meta, $this->test_user_cuid );
    }
    catch {
        if ( !ref($_) ) {
            $bogus = $_;
        }

    };
    $this->assert( !$bogus, $bogus );

    $meta->text("But deadly");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    $this->sut->delRev( $meta, $this->test_user_cuid );
    undef $meta;
    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "DelRev"
    );
    $this->sut->readTopic($meta);
    $this->assert_equals( "Silent", $meta->text() );
}

sub verify_atomicLocks {
    my $this = shift;
    $this->_makeWeb();
    my $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "AtomicLock"
    );
    $meta->text("Kaboom");
    $this->sut->saveTopic( $meta, $this->test_user_cuid );
    undef $meta;

    $meta = $this->create(
        'Foswiki::Meta',
        web   => $this->t_web,
        topic => "AtomicLock"
    );
    my ( $u, $t ) = $this->sut->atomicLockInfo($meta);
    $this->assert_null($u);
    $this->assert_null($t);

    $this->sut->atomicLock( $meta, $this->test_user_cuid );
    ( $u, $t ) = $this->sut->atomicLockInfo($meta);
    $this->assert_equals( $this->test_user_cuid, $u );
    $this->assert( time - $t < 5 );

    $this->sut->atomicUnlock( $meta, $this->test_user_cuid );
    ( $u, $t ) = $this->sut->atomicLockInfo($meta);
    $this->assert_null($u);
    $this->assert_null($t);
    undef $meta;
}

#lets see what happens when we use silly TOPICINFO
#http://foswiki.org/Tasks/Item2274
sub test_cleanUpRevID {
    my $this = shift;

    my $rev = Foswiki::Store::cleanUpRevID('$Rev$');
    $this->assert_not_null($rev);
    $this->assert_equals( 0, $rev );

    $rev = Foswiki::Store::cleanUpRevID('1.666');
    $this->assert_equals( 666, $rev );

    $rev = Foswiki::Store::cleanUpRevID('46');
    $this->assert_equals( 46, $rev );

    #we recognise a txt file that has not been written by foswiki as rev=0
    $rev = Foswiki::Store::cleanUpRevID('');
    $this->assert_not_null($rev);
    $this->assert_equals( 0, $rev );

    return;
}

sub test_getWorkArea {
    my $this = shift;

    # Must return a valid dirpath
    my $dir = $this->app->store->getWorkArea("test_work_area_$$");
    $this->assert( -d $dir );
    $this->assert( open( F, ">", "$dir/blah.dat" ) );
    close(F);
    unlink("$dir/blah.dat");
    rmdir($dir);
}

sub verify_getAttachmentURL {

    # Hmm, tricky. About all we can do is verify that we are given
    # back a url. We *could* LWP it, but...
    my $this = shift;

    my $url = $this->sut->app->cfg->getAttachmentURL('System');
}

sub verify_getRevisionHistory {
    my $this        = shift;
    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $this->test_web,
        topic => 'RevIt',
        text  => "Rev 1"
    );
    $this->sut->saveTopic( $topicObject, $this->test_user_cuid );
    undef $topicObject;

    $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $this->test_web,
        topic => 'RevIt'
    );
    my $revIt = $this->sut->getRevisionHistory($topicObject);
    $this->assert( $revIt->hasNext() );
    $this->assert_equals( 1, $revIt->next() );
    $this->assert( !$revIt->hasNext() );

    $topicObject->text('Rev 2');
    $this->assert_equals( 2, $topicObject->save( forcenewrevision => 1 ) );
    undef $topicObject;
    $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $this->test_web,
        topic => 'RevIt'
    );
    $revIt = $this->sut->getRevisionHistory($topicObject);
    $this->assert( $revIt->hasNext() );
    $this->assert_equals( 2, $revIt->next() );
    $this->assert( $revIt->hasNext() );
    $this->assert_equals( 1, $revIt->next() );
    $this->assert( !$revIt->hasNext() );

    $topicObject->text('Rev 3');
    $this->assert_equals( 3, $topicObject->save( forcenewrevision => 1 ) );
    undef $topicObject;
    $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $this->test_web,
        topic => 'RevIt'
    );
    $revIt = $this->sut->getRevisionHistory($topicObject);
    $this->assert( $revIt->hasNext() );
    $this->assert_equals( 3, $revIt->next() );
    $this->assert( $revIt->hasNext() );
    $this->assert_equals( 2, $revIt->next() );
    $this->assert( $revIt->hasNext() );
    $this->assert_equals( 1, $revIt->next() );
    $this->assert( !$revIt->hasNext() );

    # SMELL: need to test attachments too

    $this->assert_equals( 4, $this->sut->getNextRevision($topicObject) );
    undef $topicObject;
}

sub verify_query {
    my $this = shift;
    my %salgs;

    foreach my $dir (@INC) {
        if ( opendir( my $Dir, "$dir/Foswiki/Store/SearchAlgorithms" ) ) {
            foreach my $alg ( readdir $Dir ) {
                next unless $alg =~ m/^(.*)\.pm$/;
                $alg = $1;

                # skip forking search for now, its extremely broken
                # on windows
                next if ( $^O eq 'MSWin32' && $alg eq 'Forking' );
                $salgs{$alg} = 1;
            }
            closedir($Dir);
        }
    }

    my @topics = ( 'AsciiName', $this->t_topic );
    my $topiclist = join( ',', @topics );
    foreach my $t (@topics) {
        my $topicObject = $this->create(
            'Foswiki::Meta',
            web   => $this->test_web,
            topic => $t,
            text  => "Target " . $this->t_topic
        );
        $topicObject->save();
    }

    foreach my $sa ( sort keys %salgs ) {
        if ( $sa eq 'Forking'
            && ( $Foswiki::cfg{Store}{Encoding} || '' ) eq 'iso-8859-1' )
        {
            print STDERR "**** SKIPPING Forking with iso-8859-1\n";
            next;
        }
        $Foswiki::cfg{Store}{SearchAlgorithm} =
          "Foswiki::Store::SearchAlgorithms::$sa";

        print STDERR "**** $Foswiki::cfg{Store}{SearchAlgorithm} on "
          . ( $Foswiki::cfg{Store}{Encoding} || 'utf-8' ) . "\n";
        $this->createNewFoswikiApp(
            engineParams => { initialAttributes => { user => 'AdminUser', }, },
        );

        my $topicObject = $this->create(
            'Foswiki::Meta',
            web   => $this->test_web,
            topic => 'WebPreferences'
        );

        my $result = $topicObject->expandMacros(
            $this->toSiteCharSet(
                    "%SEARCH{\"Target\" web=\""
                  . $this->test_web
                  . "\" format=\"\$topic\"}%"
            )
        );

        foreach my $t (@topics) {
            $this->assert_matches( qr/$t/, $result );
        }
    }
}

1;
