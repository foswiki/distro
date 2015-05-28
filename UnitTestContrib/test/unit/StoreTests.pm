# Copyright (C) 2005-2011 Sven Dowideit & Crawford Currie
#
# Tests for the Foswiki::Store API used by the Foswiki::Meta class to
# interact with the store.
#
# Note: these are not really Store tests; they are actually tests for
# store functionality that resides in Foswiki::Meta. If you were
# looking for the unit tests for the actual Store API, see
# StoreImplementationTests.pm
#
# These tests must be independent of the actual store implementation.

package StoreTests;
use strict;
use warnings;
require 5.006;

use FoswikiStoreTestCase();
our @ISA = qw( FoswikiStoreTestCase );

use Assert;
use Foswiki();
use Foswiki::Plugin();
use Foswiki::Func();
use File::Temp();
use Foswiki::AccessControlException();
use Error qw( :try );

#TODO
# attachments
# check meta data for correctness
# diffs?
# lists of topics & webs
# locking
# streams
# web creation with options for WebPreferences
# search
# getRevisionAtTime

our $TESTS;

sub set_up_for_verify {
    my $this = shift;

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );

    $TESTS = $this;
    return;
}

#============================================================================
# Create an empty web. There is no template web, so it should be populated with
# a dummy WebPreferences and nothing else.
sub verify_CreateEmptyWeb {
    my $this = shift;

    #create an empty web
    my $webObject = $this->populateNewWeb( $this->{t_web} );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    my @topics = $webObject->eachTopic()->all();
    my $tops = join( " ", @topics );
    $this->assert_equals( 1, scalar(@topics), $tops )
      ;    #we expect there to be only the preferences topic
    $this->assert_equals( $Foswiki::cfg{WebPrefsTopicName}, $tops );
    $webObject->removeFromStore();
    $webObject->finish();

    return;
}

# Create a web using _default template
sub verify_CreateWeb {
    my $this = shift;

    my $webObject =
      $this->populateNewWeb( $this->{t_web}, '_default',
        { WEBBGCOLOR => '#123432', SITEMAPLIST => 'on' } );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    $this->assert_equals( '#123432', $webObject->getPreference('WEBBGCOLOR') );
    $this->assert_equals( 'on',      $webObject->getPreference('SITEMAPLIST') );
    my $it     = $webObject->eachTopic();
    my @topics = $it->all();
    $webObject->removeFromStore();
    $webObject->finish();
    $webObject = $this->getWebObject('_default');
    $it        = $webObject->eachTopic();
    my @defaultTopics = $it->all();
    $this->assert_equals( $#topics, $#defaultTopics,
        join( ",", @topics ) . " != " . join( ',', @defaultTopics ) );
    $webObject->finish();

    return;
}

sub verify_CreateWebWithAttachments {
    my $this = shift;

    my $webObject = $this->populateNewWeb( $this->{t_web}, '_default' );
    my $it        = $webObject->eachTopic();
    my $topic     = $it->next();
    my $top = Foswiki::Meta->load( $this->{session}, $webObject->web, $topic );
    my $fh;
    open( $fh, '>', "$Foswiki::cfg{TempfileDir}/$topic" );
    $this->assert($fh);
    my $nonsense = time . <<NONSENSE;
Twas brillig, and the slithy toves
did gyre and gimbal in the wabe.
All mimsy were the borogroves,
and the mome raths outgrabe.
NONSENSE
    print $fh $nonsense;
    close($fh);
    open( $fh, '<', "$Foswiki::cfg{TempfileDir}/$topic" );
    $top->attach(
        name          => 'Nom',
        dontlog       => 1,
        comment       => 'Idiot',
        hide          => 1,
        stream        => $fh,
        notopicchange => 1
    );
    close($fh);
    $top->save();
    $webObject->finish();
    unlink "$Foswiki::cfg{TempfileDir}/$topic";

    # make another web, using the one we created as a template
    $webObject = $this->populateNewWeb( "Anotherweb", $this->{t_web} );

    $top = Foswiki::Meta->load( $this->{session}, $webObject->web, $topic );
    $fh = $top->openAttachment( 'Nom', '<' );
    $this->assert($fh);
    local $/;
    $this->assert_str_equals( $nonsense, <$fh> );
    close($fh);
    $webObject->finish();
    $this->removeFromStore( $this->{t_web} );

    return;
}

# Create a web using non-existent Web - it should not create the web
sub verify_CreateWebWithNonExistantBaseWeb {
    my $this = shift;
    my $web  = 'FailToCreate';

    my $ok = 0;
    try {
        Foswiki::Func::createWeb( $web, 'DoesNotExists' );
    }
    catch Error::Simple with {
        $ok = 1;
    };
    $this->assert($ok);
    $this->assert( !$this->{session}->webExists($web) );

    return;
}

# Create a simple topic containing only text
sub verify_CreateSimpleTextTopic {
    my $this = shift;

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text($text);
    $meta->save();
    $meta->finish();
    $this->assert(
        $this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );
    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $this->assert_str_equals( $text, $readMeta->text );
    $readMeta->finish();
    $this->removeFromStore( $this->{t_web} );

    return;
}

# Create a simple topic containing meta-data
sub verify_CreateSimpleMetaTopic {
    my $this = shift;

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text('');
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    $meta->save();
    $this->assert(
        $this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $this->assert_equals( '', $readMeta->text );

    # Clear out stuff that blocks assert_deep_equals
    $meta->remove('TOPICINFO');
    $readMeta->remove('TOPICINFO');
    foreach my $m ( $meta, $readMeta ) {
        $m->{_preferences} = $m->{_session} = undef;
        $m->setLoadStatus( undef, undef );
    }
    $this->assert_deep_equals( $meta, $readMeta );
    $meta->finish();
    $readMeta->finish();

    return;
}

# Save a second version of a topic, without forcing a new revision. Should
# re-use the existing rev number. Stores don't actually need to support this,
# but we currently have no way of interrogating a store for it's capabilities.
sub verify_noForceRev_RepRev {
    my $this = shift;

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    my ( $date, $user, $rev, $comment );

    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $this->{t_web}, $this->{t_topic} );
    $this->assert_num_equals( 0, $rev );    # topic does not exist

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text($text);
    $meta->save();
    $this->assert(
        $this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $this->{t_web}, $this->{t_topic} );
    $this->assert_num_equals( 1, $rev );

    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $this->assert_str_equals( $text, $readMeta->text );

    $text = "new text";
    $meta->text($text);
    $meta->save();
    $this->assert(
        $this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $this->{t_web}, $this->{t_topic} );
    $this->assert_num_equals( 1, $rev );

    #cleanup
    $this->removeFromStore( $this->{t_web} );
    $readMeta->finish();
    $meta->finish();

    return;
}

# Save a topic, forcing a new revision. Should increment the rev number.
sub verify_ForceRev {
    my $this = shift;

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    my ( $date, $user, $rev, $comment );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $this->{t_web}, $this->{t_topic} );
    $this->assert_num_equals( 0, $rev );    # doesn't exist yet

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text($text);
    $meta->save( forcenewrevision => 1 );
    $this->assert(
        $this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $this->{t_web}, $this->{t_topic} );
    $this->assert_num_equals( 1, $rev );

    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $this->assert_str_equals( $text, $readMeta->text );

    $text = "new text";
    $meta->text($text);
    $meta->save( forcenewrevision => 1 );
    $this->assert(
        $this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $this->{t_web}, $this->{t_topic} );
    $this->assert_num_equals( 2, $rev );

    #cleanup
    $this->removeFromStore( $this->{t_web} );
    $readMeta->finish();
    $meta->finish();

    return;
}

# Get the revision info of the latest rev of the topic.
sub verify_getRevisionInfo {
    my $this = shift;

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );

    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text($text);
    $meta->save();
    $this->assert_equals( 1, $meta->getLatestRev() );

    $text .= "\nnewline";
    $meta->text($text);
    $meta->save( forcenewrevision => 1 );

    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    my $readText = $readMeta->text;

    # ignore whitespace at end of data
    $readText =~ s/\s*$//s;
    $this->assert_equals( $text, $readText );
    $this->assert_equals( 2,     $readMeta->getLatestRev() );
    my $info = $readMeta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 2, $info->{version} );

#TODO
#getRevisionDiff (  $this->{t_web}, $this->{t_topic}, $rev1, $rev2, $contextLines  ) -> \@diffArray
    $this->removeFromStore( $this->{t_web} );
    $readMeta->finish();
    $meta->finish();

    return;
}

# Move a topic to another name in the same web
sub verify_moveTopic {
    my $this = shift;

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text($text);
    $meta->save( user => $this->{test_user_login} );

    ($text) =
"This is some test text\n   * some list\n   * $this->{t_topic}\n   * content\n :) :)";
    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} . 'a' );
    $meta->text($text);
    $meta->save( user => $this->{test_user_login} );
    ($text) =
"This is some test text\n   * some list\n   * $this->{t_topic}\n   * content\n :) :)";
    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} . 'b' );
    $meta->text($text);
    $meta->save( user => $this->{test_user_login} );
    ($text) =
"This is some test text\n   * some list\n   * $this->{t_topic}\n   * content\n :) :)";
    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} . 'c' );
    $meta->text($text);
    $meta->save( user => $this->{test_user_login} );
    my ($metaOrig) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    my ($metaNew) =
      Foswiki::Func::readTopic( $this->{t_web}, 'TopicMovedHere' );

    $this->{session}->{store}
      ->moveTopic( $metaOrig, $metaNew, $this->{test_user_cuid} );

    #compare number of refering topics?
    #compare list of references to moved topic
    $this->removeFromStore( $this->{t_web} );
    $meta->finish();
    $metaOrig->finish();
    $metaNew->finish();

    return;
}

# Check that leases are taken, and timed correctly
sub verify_leases {
    my $this = shift;

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    my $testtopic = $Foswiki::cfg{HomeTopicName};

    my ($m) = Foswiki::Func::readTopic( $this->{t_web}, $testtopic );
    my $lease = $m->getLease( $this->{t_web}, $testtopic );
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
    $m->clearLease( $this->{t_web}, $testtopic );
    $lease = $m->getLease( $this->{t_web}, $testtopic );
    $this->assert_null($lease);
    $this->removeFromStore( $this->{t_web} );
    $m->finish();

    return;
}

# Handler used in next test
sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;
    if ( $text =~ m/CHANGETEXT/ ) {
        $_[0] =~ s/fieldvalue/text/;
    }
    if ( $text =~ m/CHANGEMETA/ ) {
        $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    }

    return;
}

# Ensure the beforeSaveHandler is called when saving text changes
sub verify_beforeSaveHandlerChangeText {
    my $this = shift;
    my $args = {
        name  => "fieldname",
        value => "fieldvalue",
    };

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    # inject a handler directly into the plugins object
    push(
        @{
            $this->{session}->{plugins}->{registeredHandlers}{beforeSaveHandler}
        },
        Foswiki::Plugin->new(
            $this->{session}, "StoreTestPlugin", 'StoreTests'
        )
    );

    my $text = 'CHANGETEXT';
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text($text);
    $meta->putKeyed( "FIELD", $args );
    $meta->save( user => $this->{test_user_login} );
    $this->assert(
        $this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
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
    $this->removeFromStore( $this->{t_web} );
    $readMeta->finish();
    $meta->finish();

    return;
}

# Ensure the beforeSaveHandler is called when saving meta changes
sub verify_beforeSaveHandlerChangeMeta {
    my $this = shift;
    my $args = {
        name  => "fieldname",
        value => "fieldvalue",
    };

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    # inject a handler directly into the plugins object
    push(
        @{
            $this->{session}->{plugins}->{registeredHandlers}{beforeSaveHandler}
        },
        Foswiki::Plugin->new(
            $this->{session}, "StoreTestPlugin", 'StoreTests'
        )
    );

    my $text = 'CHANGEMETA';
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text($text);
    $meta->putKeyed( "FIELD", $args );
    $meta->save( user => $this->{test_user_login} );
    $this->assert(
        $this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );
    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    my $readText = $readMeta->text;

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

    $this->assert_equals( $text, $readText );

    # set expected meta
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    foreach my $fld (qw(rev version date comment)) {
        delete $meta->get('TOPICINFO')->{$fld};
        delete $readMeta->get('TOPICINFO')->{$fld};
    }
    $this->assert_str_equals( $meta->stringify(), $readMeta->stringify() );
    $this->removeFromStore( $this->{t_web} );
    $readMeta->finish();
    $meta->finish();

    return;
}

# Ensure the beforeSaveHandler is called when saving text and meta changes
sub verify_beforeSaveHandlerChangeBoth {
    my $this = shift;
    my $args = {
        name  => "fieldname",
        value => "fieldvalue",
    };

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    $this->assert( $this->{session}->webExists( $this->{t_web} ) );
    $this->assert(
        !$this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    # inject a handler directly into the plugins object
    push(
        @{
            $this->{session}->{plugins}->{registeredHandlers}{beforeSaveHandler}
        },
        Foswiki::Plugin->new(
            $this->{session}, "StoreTestPlugin", 'StoreTests'
        )
    );

    my $text = 'CHANGEMETA CHANGETEXT';
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text($text);
    $meta->putKeyed( "FIELD", $args );
    $meta->save( user => $this->{test_user_login} );
    $this->assert(
        $this->{session}->topicExists( $this->{t_web}, $this->{t_topic} ) );

    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    my $readText = $readMeta->text;

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

    $this->assert_equals( $text, $readText );

    # set expected meta. Changes in the *meta object* take priority
    # over conflicting changes in the *text*.
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    foreach my $fld (qw(rev version date comment)) {
        delete $meta->get('TOPICINFO')->{$fld};
        delete $readMeta->get('TOPICINFO')->{$fld};
    }
    $this->assert_str_equals( $meta->stringify(), $readMeta->stringify() );
    $this->removeFromStore( $this->{t_web} );
    $meta->finish();
    $readMeta->finish();

    return;
}

# Handler used in next test
sub beforeUploadHandler {
    my ( $attrHash, $meta ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq $TESTS->{t_datafile};
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";

    local $/ = undef;
    my $fh   = $attrHash->{stream};
    my $text = <$fh>;

    $text =~ s/call/beforeUploadHandler/;

    $fh = File::Temp->new();
    print $fh $text;

    # $fh->seek only in File::Temp 0.17 and later
    seek( $fh, 0, 0 );
    $attrHash->{stream} = $fh;

    return;
}

# Handler used in next test
sub beforeAttachmentSaveHandler {
    my ( $attrHash, $topic, $web ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq $TESTS->{t_datafile};
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";

    ASSERT( open( my $F, '<', $attrHash->{tmpFilename} ),
        "$attrHash->{tmpFilename}: $!" );
    local $/ = undef;
    my $text = <$F>;
    ASSERT( close($F), "$attrHash->{tmpFilename}: $!" );

    $text =~ s/call/beforeAttachmentSaveHandler/;
    ASSERT( open( $F, '>', $attrHash->{tmpFilename} ),
        "$attrHash->{tmpFilename}: $!" );
    print $F $text;
    ASSERT( close($F), "$attrHash->{tmpFilename}: $!" );

    return;
}

# Handler used in next test
sub afterAttachmentSaveHandler {
    my ( $attrHash, $topic, $web, $error ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq $TESTS->{t_datafile};
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";

    return;
}

# Handler used in next test
sub afterUploadHandler {
    my ( $attrHash, $meta ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq $TESTS->{t_datafile};
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";

    return;
}

sub registerAttachmentHandlers {
    my $this = shift;

    # SMELL: assumed implementation
    push(
        @{
            $this->{session}->{plugins}
              ->{registeredHandlers}{beforeAttachmentSaveHandler}
        },
        Foswiki::Plugin->new(
            $this->{session}, "StoreTestPlugin", 'StoreTests'
        )
    );
    push(
        @{
            $this->{session}->{plugins}
              ->{registeredHandlers}{beforeUploadHandler}
        },
        Foswiki::Plugin->new(
            $this->{session}, "StoreTestPlugin", 'StoreTests'
        )
    );
    push(
        @{
            $this->{session}->{plugins}
              ->{registeredHandlers}{afterAttachmentSaveHandler}
        },
        Foswiki::Plugin->new(
            $this->{session}, "StoreTestPlugin", 'StoreTests'
        )
    );
    push(
        @{
            $this->{session}->{plugins}
              ->{registeredHandlers}{afterUploadHandler}
        },
        Foswiki::Plugin->new(
            $this->{session}, "StoreTestPlugin", 'StoreTests'
        )
    );

    return;
}

sub verify_attachmentSaveHandlers_file {
    my $this = shift;

    $this->assert( open( my $FILE, '>', $this->{t_datapath} ) );
    print $FILE "call call call";
    $this->assert( close($FILE) );

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text('');
    $meta->save();

    $this->registerAttachmentHandlers();

    $meta->attach(
        name    => $this->{t_datafile},
        file    => $this->{t_datapath},
        comment => "a comment",
    );

    $this->assert( $meta->hasAttachment( $this->{t_datafile} ) );

    my $fh = $meta->openAttachment( $this->{t_datafile}, '<' );
    my $text = <$fh>;
    $this->assert( close($fh) );
    $this->assert_str_equals(
        "beforeAttachmentSaveHandler beforeUploadHandler call", $text );
    $meta->finish();

    return;
}

sub verify_attachmentSaveHandlers_stream {
    my $this = shift;

    $this->assert( open( my $FILE, '>', $this->{t_datapath} ) );
    print $FILE "call call call";
    $this->assert( close($FILE) );

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text('');
    $meta->save();

    $this->registerAttachmentHandlers();

    $this->assert( open( my $fh, '<', $this->{t_datapath} ) );
    $meta->attach(
        name    => $this->{t_datafile},
        stream  => $fh,
        comment => "a comment",
    );

    $this->assert( $meta->hasAttachment( $this->{t_datafile} ) );

    $fh = $meta->openAttachment( $this->{t_datafile}, '<' );
    my $text = <$fh>;
    $this->assert( close($fh) );
    $this->assert_str_equals(
        "beforeAttachmentSaveHandler beforeUploadHandler call", $text );
    $meta->finish();

    return;
}

sub verify_attachmentSaveHandlers_file_and_stream {
    my $this = shift;

    $this->assert( open( my $FILE, '>', $this->{t_datapath} ) );
    print $FILE "call call call";
    $this->assert( close($FILE) );

    Foswiki::Func::createWeb( $this->{t_web}, '_default' );
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, $this->{t_topic} );
    $meta->text('');
    $meta->save();

    $this->registerAttachmentHandlers();

    $this->assert( open( my $fh, '<', $this->{t_datapath} ) );
    $meta->attach(
        name    => $this->{t_datafile},
        file    => $this->{t_datapath},
        stream  => $fh,
        comment => "a comment",
    );

    $this->assert( $meta->hasAttachment( $this->{t_datafile} ) );

    $fh = $meta->openAttachment( $this->{t_datafile}, '<' );
    my $text = <$fh>;
    $this->assert( close($fh) );
    $this->assert_str_equals(
        "beforeAttachmentSaveHandler beforeUploadHandler call", $text );
    $meta->finish();

    return;
}

sub verify_eachChange {
    my $this = shift;
    Foswiki::Func::createWeb( $this->{t_web} );
    $Foswiki::cfg{Store}{RememberChangesFor} = 5;    # very bad memory
    sleep(1);
    my $start = time();
    my ($meta) = Foswiki::Func::readTopic( $this->{t_web}, "ClutterBuck" );
    $meta->text("One");
    $meta->save();
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{t_web}, "PiggleNut" );
    $meta->text("One");
    $meta->save();

    # Wait a second
    sleep(1);
    my $mid = time();
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{t_web}, "ClutterBuck" );
    $meta->text("One");
    $meta->save( forcenewrevision => 1 );
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{t_web}, "PiggleNut" );
    $meta->text("Two");
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
    $meta->finish();

    return;
}

{

    package Foswiki::Store::StoreTestFilter;
    our @changeStack;

    sub new {
        my $class = shift;

        #print STDERR "new($class)";
        @changeStack = ('newStoreTest');
        return $class->SUPER::new(@_);
    }

    sub NOTreadTopic {
        my $this = shift;
        print STDERR "holla";
        return $this->SUPER::readTopic(@_);
    }

    sub recordChange {
        my $this = shift;
        my %args = @_;

        #print STDERR "record($args{verb})";
        push( @changeStack, $args{verb} );
        return $this->SUPER::recordChange(%args);
    }

}

sub verify_StoreClassSettings {
    my $this = shift;

    $Foswiki::cfg{Store}{ImplementationClasses} =
      ['Foswiki::Store::StoreTestFilter'];
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
    $this->verify_eachChange();

    #and now verify the results of the extra Store filter.
    $this->assert_deep_equals(
        [qw/newStoreTest insert insert insert update update/],
        \@Foswiki::Store::StoreTestFilter::changeStack,
        join( ':', @Foswiki::Store::StoreTestFilter::changeStack )
    );
}

#TODO: need to write a test to understand what exactly the moveTopic with inter web move records

sub verify_eachAttachment {
    my $this = shift;

    # Use {test}web/{test_topic} so we can trivially save without
    # mucking around with encodings
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $meta->text("One");
    $meta->attach(
        name    => $this->{t_datafile},
        file    => $this->{t_datapath},
        comment => "a comment"
    );
    $meta->save();

    #load the disk version
    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    my @expected = ( $this->{t_datafile} );

    if ( $Foswiki::cfg{Store}{Implementation} =~ /Rcs|PlainFile/ ) {
        my ($f) =
"$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/xtra.dat";
        $this->assert( open( my $F, ">", $f ) );
        print $F "Naff\n";
        close($F);
        $this->assert( -e $f );

        push( @expected, "xtra.dat" );
    }
    $meta->save();
    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    my $it   = $this->{session}->{store}->eachAttachment($meta);
    my @list = $it->all();
    $this->assert( scalar(@list) == scalar(@expected) );

    foreach my $a (@expected) {
        $this->assert(
            Foswiki::Func::attachmentExists(
                $this->{test_web}, $this->{test_topic}, $a
            ),
            "'$a' missing"
        );
    }

    my ($preDeleteMeta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    sleep(1);    #ensure different timestamp on topic text
    $meta->removeFromStore( $this->{t_datafile} );
    $meta->finish();

    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, $this->{test_topic} ) );
    $this->assert(
        not Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, $this->{t_datafile}
        )
    );

    my ($postDeleteMeta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    #Item10124: SvenDowideit thinks that the Meta API should retain consistency,
    #so if you 'remove' an attachment, its META entry should also be removed
    #if we do this, the following line will fail.
    $this->assert_deep_equals( $preDeleteMeta->{FILEATTACHMENT},
        $postDeleteMeta->{FILEATTACHMENT} );

    if ( grep( /xtra/, @expected ) ) {
        $it   = $this->{session}->{store}->eachAttachment($postDeleteMeta);
        @list = $it->all();
        $this->assert_deep_equals( ["xtra.dat"], \@list );
    }
    $preDeleteMeta->finish();
    $postDeleteMeta->finish();

    return;
}

1;
