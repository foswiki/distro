# Copyright (C) 2005 Sven Dowideit & Crawford Currie
require 5.006;

package StoreTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use strict;
use Assert;
use Error qw( :try );
use Foswiki::AccessControlException;
use File::Temp;

#Test the upper level Store API

#TODO
# attachments
# check meta data for correctness
# diffs?
# lists of topics & webs
# locking
# streams
# web creation with options for WebPreferences
# search

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $web   = "TemporaryTestStoreWeb";
my $topic = "TestStoreTopic";

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    my $testWebObj = Foswiki::Meta->new( $this->{session}, $web );
    $testWebObj->populateNewWeb();

    #  Store doesn't do access checks anyway, so run as admin
    #  so that Func:: works
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );

    open( FILE, ">$Foswiki::cfg{TempfileDir}/testfile.gif" );
    print FILE "one two three";
    close(FILE);

}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $web )
      if ( Foswiki::Func::webExists($web) );
    unlink("$Foswiki::cfg{TempfileDir}/testfile.gif");

    #$this->{session}->finish();
    $this->SUPER::tear_down();
}

#============================================================================
# tests
sub test_CreateEmptyWeb {
    my $this = shift;

    #create an empty web
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->populateNewWeb();
    $this->assert( $this->{session}->webExists($web) );
    my @topics = $webObject->eachTopic()->all();
    $this->assert_equals( 1, scalar(@topics), join( " ", @topics ) )
      ;    #we expect there to be only the home topic
    $webObject->removeFromStore();
}

sub test_CreateWeb {
    my $this = shift;

#create a web using _default
#TODO how should this fail if we are testing a store impl that does not have a _deault web ?
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->populateNewWeb( '_default',
        { WEBBGCOLOR => '#123432', SITEMAPLIST => 'on' } );
    $this->assert( $this->{session}->webExists($web) );
    $this->assert_equals( '#123432', $webObject->getPreference('WEBBGCOLOR') );
    $this->assert_equals( 'on',      $webObject->getPreference('SITEMAPLIST') );
    my $it     = $webObject->eachTopic();
    my @topics = $it->all();
    $webObject->removeFromStore();
    $webObject = Foswiki::Meta->new( $this->{session}, '_default' );
    $it = $webObject->eachTopic();
    my @defaultTopics = $it->all();
    $this->assert_equals( $#topics, $#defaultTopics,
        join( ",", @topics ) . " != " . join( ',', @defaultTopics ) );
}

sub test_CreateWebWithNonExistantBaseWeb {
    my $this = shift;
    my $web  = 'FailToCreate';

    #create a web using non-existent Web
    my $ok = 0;
    try {
        Foswiki::Func::createWeb( $web, 'DoesNotExists' );
    }
    catch Error::Simple with {
        $ok = 1;
    };
    $this->assert($ok);
    $this->assert( !$this->{session}->webExists($web) );
}

sub test_CreateSimpleTextTopic {
    my $this = shift;

    Foswiki::Func::createWeb( $web, '_default' );
    $this->assert( $this->{session}->webExists($web) );
    $this->assert( !$this->{session}->topicExists( $web, $topic ) );

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $meta->save();
    $this->assert( $this->{session}->topicExists( $web, $topic ) );
    my $readMeta = Foswiki::Meta->load( $this->{session}, $web, $topic );
    $this->assert_str_equals( $text, $readMeta->text );
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();
}

sub test_CreateSimpleMetaTopic {
    my $this = shift;

    Foswiki::Func::createWeb( $web, '_default' );
    $this->assert( $this->{session}->webExists($web) );
    $this->assert( !$this->{session}->topicExists( $web, $topic ) );

    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, '' );
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    $meta->save();
    $this->assert( $this->{session}->topicExists( $web, $topic ) );

    my $readMeta = Foswiki::Meta->load( $this->{session}, $web, $topic );
    $this->assert_equals( '', $readMeta->text );

    # Clear out stuff that blocks assert_deep_equals
    $meta->remove('TOPICINFO');
    $readMeta->remove('TOPICINFO');
    foreach my $m ($meta, $readMeta) {
        $m->{_preferences} = $m->{_session} =
          $m->{_latestIsLoaded} = $m->{_loadedRev} = undef;
    }
    $this->assert_deep_equals( $meta, $readMeta );
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();
}

sub test_getRevisionInfo {
    my $this = shift;

    Foswiki::Func::createWeb( $web, '_default' );

    $this->assert( $this->{session}->webExists($web) );
    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $meta->save();
    $this->assert_equals( 1, $meta->getLatestRev() );

    $text .= "\nnewline";
    $meta->text($text);
    $meta->save( forcenewrevision => 1 );

    my $readMeta = Foswiki::Meta->load( $this->{session}, $web, $topic );
    my $readText = $readMeta->text;

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;
    $this->assert_equals( $text, $readText );
    $this->assert_equals( 2,     $readMeta->getLatestRev() );
    my $info = $readMeta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 2, $info->{version} );

 #TODO
 #getRevisionDiff (  $web, $topic, $rev1, $rev2, $contextLines  ) -> \@diffArray
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();
}

sub test_moveTopic {
    my $this = shift;

    Foswiki::Func::createWeb( $web, '_default' );
    $this->assert( $this->{session}->webExists($web) );
    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $meta->save( user => $this->{test_user_login} );

    $text =
"This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
    $meta =
      Foswiki::Meta->new( $this->{session}, $web, $topic . 'a', $text, $meta );
    $meta->save( user => $this->{test_user_login} );
    $text =
"This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
    $meta =
      Foswiki::Meta->new( $this->{session}, $web, $topic . 'b', $text, $meta );
    $meta->save( user => $this->{test_user_login} );
    $text =
"This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
    $meta =
      Foswiki::Meta->new( $this->{session}, $web, $topic . 'c', $text, $meta );
    $meta->save( user => $this->{test_user_login} );

    $this->{session}->{store}->moveTopic(
        Foswiki::Meta->new( $this->{session}, $web, $topic ),
        Foswiki::Meta->new( $this->{session}, $web, 'TopicMovedToHere' ),
        $this->{test_user_cuid}
    );

    #compare number of refering topics?
    #compare list of references to moved topic
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();

}

sub test_leases {
    my $this = shift;

    Foswiki::Func::createWeb( $web, '_default' );
    my $testtopic = $Foswiki::cfg{HomeTopicName};

    my $m = Foswiki::Meta->new( $this->{session}, $web, $testtopic );
    my $lease = $m->getLease( $web, $testtopic );
    $this->assert_null($lease);

    my $locker = $this->{session}->{user};
    my $set    = time();
    $m->setLease(10);

    # check the lease
    $lease = $m->getLease();
    $this->assert_not_null($lease);
    $this->assert_str_equals( $locker, $lease->{user} );
    $this->assert( $set,                 $lease->{taken} );
    $this->assert( $lease->{taken} + 10, $lease->{expires} );

    # clear the lease
    $m->clearLease( $web, $testtopic );
    $lease = $m->getLease( $web, $testtopic );
    $this->assert_null($lease);
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();
}

# Handler used in next test
sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;
    if ( $text =~ /CHANGETEXT/ ) {
        $_[0] =~ s/fieldvalue/text/;
    }
    if ( $text =~ /CHANGEMETA/ ) {
        $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    }
}

use Foswiki::Plugin;

sub test_beforeSaveHandlerChangeText {
    my $this = shift;
    my $args = {
        name  => "fieldname",
        value => "fieldvalue",
    };

    Foswiki::Func::createWeb( $web, '_default' );
    $this->assert( $this->{session}->webExists($web) );
    $this->assert( !$this->{session}->topicExists( $web, $topic ) );

    # inject a handler directly into the plugins object
    push(
        @{
            $this->{session}->{plugins}->{registeredHandlers}{beforeSaveHandler}
          },
        new Foswiki::Plugin( $this->{session}, "StoreTestPlugin", 'StoreTests' )
    );

    my $text = 'CHANGETEXT';
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $meta->putKeyed( "FIELD", $args );
    $meta->save( user => $this->{test_user_login} );
    $this->assert( $this->{session}->topicExists( $web, $topic ) );

    my $readMeta = Foswiki::Meta->load( $this->{session}, $web, $topic );
    my $readText = $readMeta->text;

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

    $this->assert_equals( $text, $readText );

    # remove topicinfo, useless for test
    $readMeta->remove('TOPICINFO');
    $meta->remove('TOPICINFO');

    # set expected meta
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'text' } );
    $this->assert_str_equals( $meta->stringify(), $readMeta->stringify() );
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();
}

sub test_beforeSaveHandlerChangeMeta {
    my $this = shift;
    my $args = {
        name  => "fieldname",
        value => "fieldvalue",
    };

    Foswiki::Func::createWeb( $web, '_default' );
    $this->assert( $this->{session}->webExists($web) );
    $this->assert( !$this->{session}->topicExists( $web, $topic ) );

    # inject a handler directly into the plugins object
    push(
        @{
            $this->{session}->{plugins}->{registeredHandlers}{beforeSaveHandler}
          },
        new Foswiki::Plugin( $this->{session}, "StoreTestPlugin", 'StoreTests' )
    );

    my $text = 'CHANGEMETA';
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $meta->putKeyed( "FIELD", $args );
    $meta->save( user => $this->{test_user_login} );
    $this->assert( $this->{session}->topicExists( $web, $topic ) );
    my $readMeta = Foswiki::Meta->load( $this->{session}, $web, $topic );
    my $readText = $readMeta->text;

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

    $this->assert_equals( $text, $readText );

    # set expected meta
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    foreach my $fld qw(rev version date) {
        delete $meta->get('TOPICINFO')->{$fld};
        delete $readMeta->get('TOPICINFO')->{$fld};
    }
    $this->assert_str_equals( $meta->stringify(), $readMeta->stringify() );
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();
}

sub test_beforeSaveHandlerChangeBoth {
    my $this = shift;
    my $args = {
        name  => "fieldname",
        value => "fieldvalue",
    };

    Foswiki::Func::createWeb( $web, '_default' );
    $this->assert( $this->{session}->webExists($web) );
    $this->assert( !$this->{session}->topicExists( $web, $topic ) );

    # inject a handler directly into the plugins object
    push(
        @{
            $this->{session}->{plugins}->{registeredHandlers}{beforeSaveHandler}
          },
        new Foswiki::Plugin( $this->{session}, "StoreTestPlugin", 'StoreTests' )
    );

    my $text = 'CHANGEMETA CHANGETEXT';
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $meta->putKeyed( "FIELD", $args );
    $meta->save( user => $this->{test_user_login} );
    $this->assert( $this->{session}->topicExists( $web, $topic ) );

    my $readMeta = Foswiki::Meta->load( $this->{session}, $web, $topic );
    my $readText = $readMeta->text;

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

    $this->assert_equals( $text, $readText );

    # set expected meta. Changes in the *meta object* take priority
    # over conflicting changes in the *text*.
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    foreach my $fld qw(rev version date) {
        delete $meta->get('TOPICINFO')->{$fld};
        delete $readMeta->get('TOPICINFO')->{$fld};
    }
    $this->assert_str_equals( $meta->stringify(), $readMeta->stringify() );
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();
}

# Handler used in next test
sub beforeUploadHandler {
    my ( $attrHash, $meta ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq "testfile.gif";
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";

    local $/ = undef;
    my $fh   = $attrHash->{stream};
    my $text = <$fh>;

    $text =~ s/call/beforeUploadHandler/;

    $fh = new File::Temp();
    print $fh $text;

    # $fh->seek only in File::Temp 0.17 and later
    seek( $fh, 0, 0 );
    $attrHash->{stream} = $fh;
}

sub beforeAttachmentSaveHandler {
    my ( $attrHash, $topic, $web ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq "testfile.gif";
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";

    open( F, '<', $attrHash->{tmpFilename} )
      || die "$attrHash->{tmpFilename}: $!";
    local $/ = undef;
    my $text = <F>;
    close(F) || die "$attrHash->{tmpFilename}: $!";

    $text =~ s/call/beforeAttachmentSaveHandler/;
    open( F, '>', $attrHash->{tmpFilename} )
      || die "$attrHash->{tmpFilename}: $!";
    print F $text;
    close(F) || die "$attrHash->{tmpFilename}: $!";
}

# Handler used in next test
sub afterAttachmentSaveHandler {
    my ( $attrHash, $topic, $web, $error ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq "testfile.gif";
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";
}

sub afterUploadHandler {
    my ( $attrHash, $meta ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq "testfile.gif";
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";
}

sub registerAttachmentHandlers {
    my $this = shift;

    # SMELL: assumed implementation
    push(
        @{
            $this->{session}->{plugins}
              ->{registeredHandlers}{beforeAttachmentSaveHandler}
          },
        new Foswiki::Plugin( $this->{session}, "StoreTestPlugin", 'StoreTests' )
    );
    push(
        @{
            $this->{session}->{plugins}
              ->{registeredHandlers}{beforeUploadHandler}
          },
        new Foswiki::Plugin( $this->{session}, "StoreTestPlugin", 'StoreTests' )
    );
    push(
        @{
            $this->{session}->{plugins}
              ->{registeredHandlers}{afterAttachmentSaveHandler}
          },
        new Foswiki::Plugin( $this->{session}, "StoreTestPlugin", 'StoreTests' )
    );
    push(
        @{
            $this->{session}->{plugins}
              ->{registeredHandlers}{afterUploadHandler}
          },
        new Foswiki::Plugin( $this->{session}, "StoreTestPlugin", 'StoreTests' )
    );
}

sub test_attachmentSaveHandlers_file {
    my $this = shift;

    open( FILE, ">$Foswiki::cfg{TempfileDir}/testfile.gif" );
    print FILE "call call call";
    close(FILE);

    Foswiki::Func::createWeb( $web, '_default' );
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, '' );
    $meta->save();

    $this->registerAttachmentHandlers();

    $meta->attach(
        name    => "testfile.gif",
        file    => "$Foswiki::cfg{TempfileDir}/testfile.gif",
        comment => "a comment",
    );

    $this->assert( $meta->hasAttachment("testfile.gif") );

    my $fh = $meta->openAttachment( "testfile.gif", '<' );
    my $text = <$fh>;
    close($fh);
    $this->assert_str_equals(
        "beforeAttachmentSaveHandler beforeUploadHandler call", $text );
}

sub test_attachmentSaveHandlers_stream {
    my $this = shift;

    open( FILE, ">$Foswiki::cfg{TempfileDir}/testfile.gif" );
    print FILE "call call call";
    close(FILE);

    Foswiki::Func::createWeb( $web, '_default' );
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, '' );
    $meta->save();

    $this->registerAttachmentHandlers();

    $this->assert( open( my $fh, "$Foswiki::cfg{TempfileDir}/testfile.gif" ) );
    $meta->attach(
        name    => "testfile.gif",
        stream  => $fh,
        comment => "a comment",
    );

    $this->assert( $meta->hasAttachment("testfile.gif") );

    $fh = $meta->openAttachment( "testfile.gif", '<' );
    my $text = <$fh>;
    close($fh);
    $this->assert_str_equals(
        "beforeAttachmentSaveHandler beforeUploadHandler call", $text );
}

sub test_attachmentSaveHandlers_file_and_stream {
    my $this = shift;

    open( FILE, ">$Foswiki::cfg{TempfileDir}/testfile.gif" );
    print FILE "call call call";
    close(FILE);

    Foswiki::Func::createWeb( $web, '_default' );
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, '' );
    $meta->save();

    $this->registerAttachmentHandlers();

    $this->assert( open( my $fh, "$Foswiki::cfg{TempfileDir}/testfile.gif" ) );
    $meta->attach(
        name    => "testfile.gif",
        file    => "$Foswiki::cfg{TempfileDir}/testfile.gif",
        stream  => $fh,
        comment => "a comment",
    );

    $this->assert( $meta->hasAttachment("testfile.gif") );

    $fh = $meta->openAttachment( "testfile.gif", '<' );
    my $text = <$fh>;
    close($fh);
    $this->assert_str_equals(
        "beforeAttachmentSaveHandler beforeUploadHandler call", $text );
}

sub test_eachChange {
    my $this = shift;
    Foswiki::Func::createWeb($web);
    $Foswiki::cfg{Store}{RememberChangesFor} = 5;    # very bad memory
    sleep(1);
    my $start = time();
    my $meta =
      Foswiki::Meta->new( $this->{session}, $web, "ClutterBuck", "One" );
    $meta->save();
    $meta = Foswiki::Meta->new( $this->{session}, $web, "PiggleNut", "One" );
    $meta->save();

    # Wait a second
    sleep(1);
    my $mid = time();
    $meta = Foswiki::Meta->new( $this->{session}, $web, "ClutterBuck", "One" );
    $meta->save( forcenewrevision => 1 );
    $meta = Foswiki::Meta->new( $this->{session}, $web, "PiggleNut", "Two" );
    $meta->save( forcenewrevision => 1 );
    my $change;
    my $it = $this->{session}->{store}->eachChange( $meta, $start );
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
    $it = $this->{session}->{store}->eachChange( $meta, $mid );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 2, $change->{revision} );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 2, $change->{revision} );
    $this->assert( !$it->hasNext() );
}

sub test_eachAttachment {
    my $this = shift;

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, "One" );
    $meta->attach(
        name    => "testfile.gif",
        file    => "$Foswiki::cfg{TempfileDir}/testfile.gif",
        comment => "a comment"
    );
    $meta->save();
    #load the disk version
    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        $this->{test_topic});

    my $f =
      "$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/noise.dat";
    $this->assert( open( F, ">", $f ) );
    print F "Naff\n";
    close(F);
    $this->assert( -e $f );

    $meta->save();
    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        $this->{test_topic});

    my $it = $this->{session}->{store}->eachAttachment($meta);
    my $list = join( ' ', sort $it->all() );
    $this->assert_str_equals( "noise.dat testfile.gif", $list );

   $this->assert(Foswiki::Func::attachmentExists($this->{test_web}, $this->{test_topic}, 'testfile.gif'));
   $this->assert(Foswiki::Func::attachmentExists($this->{test_web}, $this->{test_topic}, 'noise.dat'));

    my $preDeleteMeta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        $this->{test_topic});

   sleep(1); #ensure different timestamp on topic text
   $meta->removeFromStore('testfile.gif');
   
   $this->assert(Foswiki::Func::topicExists($this->{test_web}, $this->{test_topic}));
   $this->assert(not Foswiki::Func::attachmentExists($this->{test_web}, $this->{test_topic}, 'testfile.gif'));
   $this->assert(Foswiki::Func::attachmentExists($this->{test_web}, $this->{test_topic}, 'noise.dat'));

    my $postDeleteMeta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        $this->{test_topic});

    #Item10124: SvenDowideit thinks that the Meta API should retain consistency, so if you 'remove' an attachment, its META entry should also be removed
    #if we do this, the following line will fail.
    $this->assert_deep_equals( $preDeleteMeta->{FILEATTACHMENT}, $postDeleteMeta->{FILEATTACHMENT} );

    $it = $this->{session}->{store}->eachAttachment($postDeleteMeta);
    $list = join( ' ', sort $it->all() );
    $this->assert_str_equals( "noise.dat", $list );

    

}

1;
