# Copyright (C) 2005 Sven Dowideit & Crawford Currie
require 5.006;

package StoreTests;

use base qw(FoswikiFnTestCase);

use Foswiki;
use strict;
use Assert;
use Error qw( :try );
use Foswiki::AccessControlException;

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

my $web   = "TestStoreWeb";
my $topic = "TestStoreTopic";

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    #    $this->{session} = new Foswiki($this->{test_user_login});

    open( FILE, ">$Foswiki::cfg{TempfileDir}/testfile.gif" );
    print FILE "one two three";
    close(FILE);

}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $web )
      if ( -e "$Foswiki::cfg{DataDir}/$web" );

    unlink("$Foswiki::cfg{TempfileDir}/testfile.gif");
    unlink "$Foswiki::cfg{DataDir}/$web/.changes";

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
    $webObject->populateNewWeb('_default', { WEBBGCOLOR => 'SITEMAPLIST' });
    $this->assert( $this->{session}->webExists($web) );
    $this->assert_equals('SITEMAPLIST',
                         $webObject->getPreference('WEBBGCOLOR'));
    $this->assert_equals('on', $webObject->getPreference('SITEMAPLIST'));
    my $it        = $webObject->eachTopic();
    my @topics    = $it->all();
    $webObject->removeFromStore();
    $webObject = Foswiki::Meta->new( $this->{session}, '_default' );
    $it = $webObject->eachTopic();
    my @defaultTopics = $it->all();
    $this->assert_equals( $#topics, $#defaultTopics,
        join( ",", @topics ) . " != " . join( ',', @defaultTopics ) );
}

sub test_CreateWebWithNonExistantBaseWeb {
    my $this = shift;

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
    $meta->{_session}   = $readMeta->{_session}   = undef;
    $meta->{_loadedRev} = $readMeta->{_loadedRev} = undef;

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
    $this->assert_equals( 1, $meta->getMaxRevNo() );

    $text .= "\nnewline";
    $meta->text($text);
    $meta->save( forcenewrevision => 1 );

    my $readMeta = Foswiki::Meta->load( $this->{session}, $web, $topic );
    my $readText = $readMeta->text;

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;
    $this->assert_equals( $text, $readText );
    $this->assert_equals( 2,     $readMeta->getMaxRevNo() );
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
        Foswiki::Meta->new( $this->{session}, $web, 'TopicMovedToHere' )
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
    $meta->remove( 'TOPICINFO', 'rev' );
    $readMeta->remove( 'TOPICINFO', 'rev' );
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

    # set expected meta
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    $meta->remove( 'TOPICINFO', 'rev' );
    $readMeta->remove( 'TOPICINFO', 'rev' );
    $this->assert_str_equals( $meta->stringify(), $readMeta->stringify() );
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();
}

# Handler used in next test
sub beforeAttachmentSaveHandler {
    my ( $attrHash, $topic, $web ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq "testfile.gif";
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";

    open( F, "<" . $attrHash->{tmpFilename} )
      || die "$attrHash->{tmpFilename}: $!";
    local $/ = undef;
    my $text = <F>;
    close(F) || die "$attrHash->{tmpFilename}: $!";

    $text =~ s/two/four/;

    open( F, ">" . $attrHash->{tmpFilename} )
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

sub test_attachmentSaveHandlers {
    my $this = shift;
    my $args = {
        name  => "fieldname",
        value => "fieldvalue",
    };

    Foswiki::Func::createWeb( $web, '_default' );
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, '' );
    $meta->save();

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
              ->{registeredHandlers}{afterAttachmentSaveHandler}
          },
        new Foswiki::Plugin( $this->{session}, "StoreTestPlugin", 'StoreTests' )
    );

    $meta->attach(
        name    => "testfile.gif",
        file    => "$Foswiki::cfg{TempfileDir}/testfile.gif",
        comment => "a comment"
    );

    $this->assert( $meta->hasAttachment("testfile.gif") );

    my $text = $meta->readAttachment("testfile.gif");
    $this->assert_str_equals( "one four three", $text );

    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->removeFromStore();
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

1;
