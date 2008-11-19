# Copyright (C) 2005 Sven Dowideit & Crawford Currie
require 5.006;
package StoreTests;

use base qw(FoswikiFnTestCase);

use Foswiki;
use strict;
use Assert;
use Error qw( :try );

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

my $web = "TestStoreWeb";
my $topic = "TestStoreTopic";

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
#    $this->{twiki} = new Foswiki($this->{test_user_login});
	
    open( FILE, ">$Foswiki::cfg{TempfileDir}/testfile.gif" );
    print FILE "one two three";
    close(FILE);

}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture($this->{twiki}, $web)
      if( -e "$Foswiki::cfg{DataDir}/$web");

    unlink("$Foswiki::cfg{TempfileDir}/testfile.gif");
    unlink "$Foswiki::cfg{DataDir}/$web/.changes";

    #$this->{twiki}->finish();
    $this->SUPER::tear_down();
}

#===============================================================================
# tests
sub test_CreateEmptyWeb {
    my $this = shift;

	$this->assert_not_null( $this->{twiki}->{store} );
	
	#create an empty web
	$this->assert( ! $this->{twiki}->{store}->createWeb($this->{twiki}->{user},$web));		#TODO: how can this succeed without a user? to check perms?
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	my @topics = $this->{twiki}->{store}->getTopicNames($web);
	$this->assert_equals( 1, scalar(@topics), join(" ",@topics) );#we expect there to be only the home topic
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

sub test_CreateWeb {
    my $this = shift;

	$this->assert_not_null( $this->{twiki}->{store} );
	
	#create a web using _default 
	#TODO how should this fail if we are testing a store impl that does not have a _deault web ?
	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	my @topics = $this->{twiki}->{store}->getTopicNames($web);
	my @defaultTopics = $this->{twiki}->{store}->getTopicNames('_default');
	$this->assert_equals( $#topics, $#defaultTopics,
                          join(",",@topics)." != ".join(',',@defaultTopics));
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

sub test_CreateWebWithNonExistantBaseWeb {
    my $this = shift;

	$this->assert_not_null( $this->{twiki}->{store} );
	
	#create a web using non-exsisatant Web 
    my $ok = 0;
    try {
        $this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, 'DoesNotExists');
    } catch Error::Simple with {
        $ok = 1;
    };
    $this->assert($ok);
	$this->assert( ! $this->{twiki}->{store}->webExists($web) );
}


sub test_CreateSimpleTopic {
    my $this = shift;

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	$this->assert( ! $this->{twiki}->{store}->topicExists($web, $topic) );
	
	my $meta = undef;
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic, $text, $meta );
	$this->assert( $this->{twiki}->{store}->topicExists($web, $topic) );
	my ($readMeta, $readText) = $this->{twiki}->{store}->readTopic($this->{test_user_login}, $web, $topic);

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

sub test_CreateSimpleMetaTopic {
    my $this = shift;

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	$this->assert( ! $this->{twiki}->{store}->topicExists($web, $topic) );
	
	my $text = '';
	my $meta = new Foswiki::Meta($this->{twiki}, $web, $topic);
	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic, $text, $meta );
	$this->assert( $this->{twiki}->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $this->{twiki}->{store}->readTopic($this->{test_user_login}, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # remove topicinfo, useless for test
    $readMeta->remove('TOPICINFO');
    $meta->remove('TOPICINFO');
    @{$meta->{FILEATTACHMENT}} = () unless $meta->{FILEATTACHMENT};
	$this->assert_deep_equals($meta, $readMeta);
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

sub test_CreateSimpleCompoundTopic {
    my $this = shift;

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	$this->assert( ! $this->{twiki}->{store}->topicExists($web, $topic) );
	
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	my $meta = new Foswiki::Meta($this->{twiki}, $web, $topic);
    $meta->{_text} = $text;
	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic, $text, $meta );
	$this->assert( $this->{twiki}->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $this->{twiki}->{store}->readTopic($this->{test_user_login}, $web, $topic);

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # remove topicinfo, useless for test
    $readMeta->remove('TOPICINFO');
    $meta->remove('TOPICINFO');
    @{$meta->{FILEATTACHMENT}} = () unless $meta->{FILEATTACHMENT};
    $this->assert_deep_equals($meta, $readMeta);
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

sub test_getRevisionInfo {
    my $this = shift;

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	my $meta = new Foswiki::Meta($this->{twiki}, $web, $topic);
	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic, $text, $meta );

	$this->assert_equals(1, $this->{twiki}->{store}->getRevisionNumber($web, $topic));

    $text .= "\nnewline";
	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic, $text, $meta, { forcenewrevision => 1 } );

	my ($readMeta, $readText) = $this->{twiki}->{store}->readTopic($this->{test_user_login}, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;
	$this->assert_equals($text, $readText);
	$this->assert_equals(2, $this->{twiki}->{store}->getRevisionNumber($web, $topic));
	my ( $infodate, $infouser, $inforev, $infocomment ) = $this->{twiki}->{store}->getRevisionInfo($web, $topic);
	$this->assert_equals($this->{test_user_login}, $infouser);
	$this->assert_equals(2, $inforev);
	
	#TODO
	#getRevisionDiff (  $web, $topic, $rev1, $rev2, $contextLines  ) -> \@diffArray
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

sub test_moveTopic {
    my $this = shift;

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	my $meta = new Foswiki::Meta($this->{twiki}, $web, $topic);
	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic, $text, $meta );

	$text = "This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic.'a', $text, $meta );
	$text = "This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic.'b', $text, $meta );
	$text = "This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic.'c', $text, $meta );
	
	$this->{twiki}->{store}->moveTopic($web, $topic, $web, 'TopicMovedToHere', $this->{test_user_login});
	
	#compare number of refering topics?
	#compare list of references to moved topic
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);

}

sub test_leases {
    my $this = shift;

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
    my $testtopic = $Foswiki::cfg{HomeTopicName};

    my $lease = $this->{twiki}->{store}->getLease($web, $testtopic);
    $this->assert_null($lease);

    my $locker = $this->{twiki}->{user};
    my $set = time();
    $this->{twiki}->{store}->setLease($web, $testtopic, $locker, 10);

    # check the lease
    $lease = $this->{twiki}->{store}->getLease($web, $testtopic);
    $this->assert_not_null($lease);
    $this->assert_str_equals($locker, $lease->{user});
    $this->assert($set, $lease->{taken});
    $this->assert($lease->{taken}+10, $lease->{expires});

    # clear the lease
    $this->{twiki}->{store}->clearLease( $web, $testtopic );
    $lease = $this->{twiki}->{store}->getLease($web, $testtopic);
    $this->assert_null($lease);
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

# Handler used in next test
sub beforeSaveHandler {
    my( $text, $topic, $web, $meta ) = @_;
    if( $text =~ /CHANGETEXT/ ) {
        $_[0] =~ s/fieldvalue/text/;
    }
    if( $text =~ /CHANGEMETA/ ) {
        $meta->putKeyed('FIELD', {name=>'fieldname', value=>'meta'});
    }
}

use Foswiki::Plugin;

sub test_beforeSaveHandlerChangeText {
    my $this = shift;
    my $args = {
        name => "fieldname",
        value  => "fieldvalue",
       };

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	$this->assert( ! $this->{twiki}->{store}->topicExists($web, $topic) );
	
    # inject a handler directly into the plugins object
    push(@{$this->{twiki}->{plugins}->{registeredHandlers}{beforeSaveHandler}},
        new Foswiki::Plugin($this->{twiki}, "StoreTestPlugin", 'StoreTests'));

	my $text = 'CHANGETEXT';
	my $meta = new Foswiki::Meta($this->{twiki}, $web, $topic);
    $meta->putKeyed( "FIELD", $args );

	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic, $text, $meta );
	$this->assert( $this->{twiki}->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $this->{twiki}->{store}->readTopic($this->{test_user_login}, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # remove topicinfo, useless for test
    $readMeta->remove('TOPICINFO');
    # set expected meta
    $meta->putKeyed('FIELD', {name=>'fieldname', value=>'text'});
	$this->assert_str_equals($meta->stringify(), $readMeta->stringify());
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

sub test_beforeSaveHandlerChangeMeta {
    my $this = shift;
    my $args = {
        name => "fieldname",
        value  => "fieldvalue",
       };

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	$this->assert( ! $this->{twiki}->{store}->topicExists($web, $topic) );
	
    # inject a handler directly into the plugins object
    push(@{$this->{twiki}->{plugins}->{registeredHandlers}{beforeSaveHandler}},
        new Foswiki::Plugin($this->{twiki}, "StoreTestPlugin", 'StoreTests'));

	my $text = 'CHANGEMETA';
	my $meta = new Foswiki::Meta($this->{twiki}, $web, $topic);
    $meta->putKeyed( "FIELD", $args );

	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic, $text, $meta );
	$this->assert( $this->{twiki}->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $this->{twiki}->{store}->readTopic($this->{test_user_login}, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # set expected meta
    $meta->putKeyed('FIELD', {name=>'fieldname', value=>'meta'});
	$this->assert_str_equals($meta->stringify(), $readMeta->stringify());
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

sub test_beforeSaveHandlerChangeBoth {
    my $this = shift;
    my $args = {
        name => "fieldname",
        value  => "fieldvalue",
       };

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->assert( $this->{twiki}->{store}->webExists($web) );
	$this->assert( ! $this->{twiki}->{store}->topicExists($web, $topic) );
	
    # inject a handler directly into the plugins object
    push(@{$this->{twiki}->{plugins}->{registeredHandlers}{beforeSaveHandler}},
        new Foswiki::Plugin($this->{twiki}, "StoreTestPlugin", 'StoreTests'));

	my $text = 'CHANGEMETA CHANGETEXT';
	my $meta = new Foswiki::Meta($this->{twiki}, $web, $topic);
    $meta->putKeyed( "FIELD", $args );

	$this->{twiki}->{store}->saveTopic( $this->{test_user_login}, $web, $topic, $text, $meta );
	$this->assert( $this->{twiki}->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $this->{twiki}->{store}->readTopic($this->{test_user_login}, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # set expected meta
    $meta->putKeyed('FIELD', {name=>'fieldname', value=>'meta'});
	$this->assert_str_equals($meta->stringify(), $readMeta->stringify());
	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

# Handler used in next test
sub beforeAttachmentSaveHandler {
    my( $attrHash, $topic, $web ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq "testfile.gif";
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";

    open(F, "<".$attrHash->{tmpFilename}) ||
      die "$attrHash->{tmpFilename}: $!";
    local $/ = undef;
    my $text = <F>;
    close(F) || die "$attrHash->{tmpFilename}: $!";

    $text =~ s/two/four/;

    open(F, ">".$attrHash->{tmpFilename}) ||
      die "$attrHash->{tmpFilename}: $!";
    print F $text;
    close(F) || die "$attrHash->{tmpFilename}: $!";
}

# Handler used in next test
sub afterAttachmentSaveHandler {
    my( $attrHash, $topic, $web, $error ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq "testfile.gif";
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";
}

sub test_attachmentSaveHandlers {
    my $this = shift;
    my $args = {
        name => "fieldname",
        value  => "fieldvalue",
       };

	$this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web, '_default');
	$this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $web, $topic, "", undef );

    # SMELL: assumed implementation
    push(@{$this->{twiki}->{plugins}->{registeredHandlers}{beforeAttachmentSaveHandler}},
        new Foswiki::Plugin($this->{twiki}, "StoreTestPlugin", 'StoreTests'));
    push(@{$this->{twiki}->{plugins}->{registeredHandlers}{afterAttachmentSaveHandler}},
        new Foswiki::Plugin($this->{twiki}, "StoreTestPlugin", 'StoreTests'));

    $this->{twiki}->{store}->saveAttachment(
        $web, $topic, "testfile.gif", $this->{test_user_login},
        { file => "$Foswiki::cfg{TempfileDir}/testfile.gif",
          comment => "a comment" } );

    my $text = $this->{twiki}->{store}->readAttachment(
        $this->{twiki}->{user},
        $web, $topic, "testfile.gif");
    $this->assert_str_equals("one four three", $text);

	$this->{twiki}->{store}->removeWeb($this->{twiki}->{user}, $web);
}

sub test_eachChange {
    my $this = shift;
    $this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $web);
    $Foswiki::cfg{Store}{RememberChangesFor} = 5; # very bad memory
    sleep(1);
    my $start = time();
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $web, "ClutterBuck",
                                "One" );
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $web, "PiggleNut",
                                "One" );
    # Wait a second
    sleep(1);
    my $mid = time();
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $web, "ClutterBuck",
                                "One", undef, { forcenewrevision => 1 } );
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $web, "PiggleNut",
                                "Two", undef, { forcenewrevision => 1 } );
    my $change;
    my $it = $this->{twiki}->{store}->eachChange($web, $start);
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("PiggleNut", $change->{topic});
    $this->assert_equals(2, $change->{revision});
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("ClutterBuck", $change->{topic});
    $this->assert_equals(2, $change->{revision});
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("PiggleNut", $change->{topic});
    $this->assert_equals(1, $change->{revision});
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("ClutterBuck", $change->{topic});
    $this->assert_equals(1, $change->{revision});
    $this->assert(!$it->hasNext());
    $it = $this->{twiki}->{store}->eachChange($web, $mid);
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("PiggleNut", $change->{topic});
    $this->assert_equals(2, $change->{revision});
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("ClutterBuck", $change->{topic});
    $this->assert_equals(2, $change->{revision});
    $this->assert(!$it->hasNext());
}

1;
