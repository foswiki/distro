use strict;

#
# Unit tests for Foswiki::Func
#

package FuncTests;

use base qw(FoswikiFnTestCase);

use Foswiki;
use Foswiki::Func;

sub new {
	my $self = shift()->SUPER::new("Func", @_);
	return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{tmpdatafile} = $Foswiki::cfg{TempfileDir}.'/tmpity-tmp.gif';
    $this->{test_web2} = $this->{test_web}.'Extra';
    $this->assert_null($this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $this->{test_web2}));
}

sub tear_down {
    my $this = shift;
    unlink $this->{tmpdatafile};
    $this->removeWebFixture($this->{twiki},$this->{test_web2});
    $this->SUPER::tear_down();
}

sub test_web {
    my $this = shift;

    Foswiki::Func::createWeb($this->{test_web}."Blah");
    $this->assert(Foswiki::Func::webExists($this->{test_web}."Blah"));

    Foswiki::Func::moveWeb($this->{test_web}."Blah", $this->{test_web}."Blah2");
    $this->assert(!Foswiki::Func::webExists($this->{test_web}."Blah"));
    $this->assert(Foswiki::Func::webExists($this->{test_web}."Blah2"));

    Foswiki::Func::moveWeb($this->{test_web}."Blah2",
                         $Foswiki::cfg{TrashWebName}.'.'.$this->{test_web});
    $this->assert(!Foswiki::Func::webExists($this->{test_web}."Blah2"));
    $this->assert(Foswiki::Func::webExists(
        $Foswiki::cfg{TrashWebName}.'.'.$this->{test_web}));

    $this->{twiki}->{store}->removeWeb($this->{twiki}->{user},
                               $Foswiki::cfg{TrashWebName}.'.'.$this->{test_web});
}

sub test_getViewUrl {
    my $this = shift;

    my $ss = 'view'.$Foswiki::cfg{ScriptSuffix};

    # relative to specified web
    my $result = Foswiki::Func::getViewUrl ( $this->{users_web}, "WebHome" );
    $this->assert_matches(qr!/$ss/$this->{users_web}/WebHome!, $result );

    # relative to web in path_info
    $result = Foswiki::Func::getViewUrl ( "", "WebHome" );
    $this->assert_matches(qr!/$ss/$this->{test_web}/WebHome!, $result );

    $Foswiki::Plugins::SESSION = new Foswiki(
        undef,
        new Unit::Request( { topic=>"Sausages.AndMash" } ));

    $result = Foswiki::Func::getViewUrl ( "Sausages", "AndMash" );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );

    $result = Foswiki::Func::getViewUrl ( "", "AndMash" );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );
    $Foswiki::Plugins::SESSION->finish();
}

sub test_getScriptUrl {
    my $this = shift;

    my $ss = 'wibble'.$Foswiki::cfg{ScriptSuffix};
    my $result = Foswiki::Func::getScriptUrl ( $this->{users_web}, "WebHome", 'wibble' );
    $this->assert_matches(qr!/$ss/$this->{users_web}/WebHome!, $result );

    $result = Foswiki::Func::getScriptUrl ( "", "WebHome", 'wibble' );
    $this->assert_matches(qr!/$ss/$this->{users_web}/WebHome!, $result );

    my $q = new Unit::Request( {} );
    $q->path_info( '/Sausages/AndMash' );
    $Foswiki::Plugins::SESSION = new Foswiki(undef, $q);

    $result = Foswiki::Func::getScriptUrl ( "Sausages", "AndMash", 'wibble' );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );

    $result = Foswiki::Func::getScriptUrl ( "", "AndMash", 'wibble' );
    $this->assert_matches(qr!/$ss/$this->{users_web}/AndMash!, $result );
    $Foswiki::Plugins::SESSION->finish();
}

sub test_getOopsUrl {
    my $this = shift;
    my $url =
      Foswiki::Func::getOopsUrl('Incy','Wincy', 'Spider', 'Hurble', 'Burble',
                             'Wurble', 'Murble');
    $this->assert_str_equals(
      Foswiki::Func::getScriptUrl('Incy', 'Wincy', 'oops').
      "?template=Spider;param1=Hurble;param2=Burble;param3=Wurble;param4=Murble",
      $url);
    $url =
      Foswiki::Func::getOopsUrl('Incy','Wincy', 'oopspider', 'Hurble', 'Burble',
                             'Wurble', 'Murble');
    $this->assert_str_equals(
      Foswiki::Func::getScriptUrl('Incy', 'Wincy', 'oops').
      "?template=oopspider;param1=Hurble;param2=Burble;param3=Wurble;param4=Murble",
      $url);
}

# Check lease handling
sub test_leases {
    my $this = shift;

    my $testtopic = $Foswiki::cfg{HomeTopicName};

    # Check that there is no lease on the home topic
    my( $oops, $login, $time ) =
      Foswiki::Func::checkTopicEditLock($this->{test_web}, $testtopic);
    $this->assert(!$oops, $oops);
    $this->assert(!$login);
    $this->assert_equals(0,$time);

    # Take out a lease on behalf of the current user
    Foswiki::Func::setTopicEditLock($this->{test_web}, $testtopic, 1);

    # Work out who leased it. The login name is used in the lease check.
    my $locker = Foswiki::Func::wikiToUserName(Foswiki::Func::getWikiName());
    $this->assert($locker);

    # check the lease
    ( $oops, $login, $time ) =
      Foswiki::Func::checkTopicEditLock($this->{test_web}, $testtopic);
    $this->assert_equals($locker, $login);
    $this->assert($time > 0);
    $this->assert_matches(qr/leaseconflict/,$oops);
    $this->assert_matches(qr/active/,$oops);

    # try and clear the lease. This should always succeed.
    Foswiki::Func::setTopicEditLock($this->{test_web}, $testtopic, 0);

    ( $oops, $login, $time ) =
      Foswiki::Func::checkTopicEditLock($this->{test_web}, $testtopic);
    $this->assert(!$oops,$oops);
    $this->assert(!$login);
    $this->assert_equals(0,$time);
}

sub test_attachments {
    my $this = shift;

    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $attnm = 'blahblahblah.gif';
    my $name1 = 'blahblahblah.gif';
    my $name2 = 'bleagh.sniff';
    my $topic = "BlahBlahBlah";

    my $stream;
    $this->assert(open($stream,">$this->{tmpdatafile}"));
    binmode($stream);
    print $stream $data;
    close($stream);

    $this->assert(open($stream, "<$this->{tmpdatafile}"));
    binmode($stream);

	Foswiki::Func::saveTopicText( $this->{test_web}, $topic,'' );

    my $e = Foswiki::Func::saveAttachment(
        $this->{test_web}, $topic, $name1,
        {
            dontlog => 1,
            comment => 'Feasgar Bha',
            stream => $stream,
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
      } );
    $this->assert(!$e,$e);

    my( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    my @attachments = $meta->find( 'FILEATTACHMENT' );
    $this->assert_str_equals($name1, $attachments[0]->{name} );

    $e = Foswiki::Func::saveAttachment(
        $this->{test_web}, $topic, $name2,
        {
            dontlog => 1,
            comment => 'Ciamar a tha u',
            file => $this->{tmpdatafile},
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
      } );
    $this->assert(!$e,$e);

    ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    @attachments = $meta->find( 'FILEATTACHMENT' );
    $this->assert_str_equals($name1, $attachments[0]->{name} );
    $this->assert_str_equals($name2, $attachments[1]->{name} );

    my $x = Foswiki::Func::readAttachment($this->{test_web}, $topic, $name1);
    $this->assert_str_equals($data, $x);
    $x = Foswiki::Func::readAttachment($this->{test_web}, $topic, $name2);
    $this->assert_str_equals($data, $x);

    # This should succeed - attachment exists
    $this->assert(
        Foswiki::Func::attachmentExists( $this->{test_web}, $topic, $name1 ) );
   
    # This should fail - attachment is not present
    $this->assert(
        !(Foswiki::Func::attachmentExists( $this->{test_web}, $topic, "NotExists" )) );

    # This should fail - attachment is not present
    $this->assert( 
        !(Foswiki::Func::readAttachment( $this->{test_web}, $topic, "NotExists") ));
}

sub test_getrevinfo {
    my $this = shift;
    my $topic = "RevInfo";

#    my $login = Foswiki::Func::wikiToUserName(Foswiki::Func::getWikiName());
    my $wikiname = Foswiki::Func::getWikiName();
	Foswiki::Func::saveTopicText( $this->{test_web}, $topic, 'blah' );

    my( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic );
    $this->assert_equals( 1, $rev );
    $this->assert_str_equals( $wikiname, $user );   # the Func::getRevisionInfo quite clearly says wikiname
}

# Helper function for test_moveTopic
sub _checkMoveTopic($$$$)
{
my ($oldWeb, $oldTopic, $newWeb, $newTopic) = @_;
my $meta;
my $text;
my $count = 0;
	$newWeb ||= $oldWeb;
	$newTopic ||= $oldTopic;
	($meta, $text) = Foswiki::Func::readTopic($newWeb, $newTopic);
	#print STDERR "looking for $oldWeb.$oldTopic -> $newWeb.$newTopic\n";
	$count = @{$meta->{TOPICMOVED}} if $meta->{TOPICMOVED};
	#print STDERR "there are $count TOPICMOVED entries.\n";
	foreach (@{$meta->{TOPICMOVED}})
	{
		#print STDERR "$_->{from} -> $_->{to}\n";
		# pick out the meta entry that indicates this move.
		next if ($_->{to} ne "$newWeb.$newTopic");
		next if ($_->{from} ne "$oldWeb.$oldTopic");
		#print STDERR "Found it!\n";
		return 1;
	}
	#print STDERR "Didn't find it!\n";
	return 0;
}

sub test_moveTopic {
    my $this = shift;
# TEST: create test_web.SourceTopic with content "Wibble".
	Foswiki::Func::saveTopicText( $this->{test_web}, "SourceTopic", "Wibble" );
    $this->assert(Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic"));
    $this->assert(!Foswiki::Func::topicExists( $this->{test_web}, "TargetTopic"));
    $this->assert(!Foswiki::Func::topicExists( $this->{test_web2}, "SourceTopic"));
    $this->assert(!Foswiki::Func::topicExists( $this->{test_web2}, "TargetTopic"));

# TEST: move within the test web.
	Foswiki::Func::moveTopic( $this->{test_web}, "SourceTopic",
                              $this->{test_web}, "TargetTopic" );
    $this->assert(!Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic"));
    $this->assert(Foswiki::Func::topicExists( $this->{test_web}, "TargetTopic"));

# TEST: Move with undefined destination web; should stay in test_web.
	Foswiki::Func::moveTopic( $this->{test_web}, "TargetTopic",
                              undef, "SourceTopic" );
    $this->assert(Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic"));
    $this->assert(!Foswiki::Func::topicExists( $this->{test_web}, "TargetTopic"));

# TEST: Move to test_web2.
	Foswiki::Func::moveTopic( $this->{test_web}, "SourceTopic",
                              $this->{test_web2}, "SourceTopic" );
    $this->assert(!Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic"));
    $this->assert(Foswiki::Func::topicExists( $this->{test_web2}, "SourceTopic"));
	$this->assert(_checkMoveTopic($this->{test_web}, "SourceTopic", $this->{test_web2}, "SourceTopic"));

# TEST: move with undefined destination topic.
	Foswiki::Func::moveTopic( $this->{test_web2}, "SourceTopic",
                              $this->{test_web}, undef );
    $this->assert(Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic"));
    $this->assert(!Foswiki::Func::topicExists( $this->{test_web2}, "SourceTopic"));
	$this->assert(_checkMoveTopic($this->{test_web2}, "SourceTopic", $this->{test_web}, "SourceTopic"));

# TEST: move to test_web2 again.
	Foswiki::Func::moveTopic( $this->{test_web}, "SourceTopic",
                              $this->{test_web2}, "TargetTopic" );
    $this->assert(!Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic"));
    $this->assert(Foswiki::Func::topicExists( $this->{test_web2}, "TargetTopic"));
	$this->assert(_checkMoveTopic($this->{test_web}, "SourceTopic", $this->{test_web2}, "TargetTopic"));
}

sub test_moveAttachment {
    my $this = shift;

	Foswiki::Func::saveTopicText( $this->{test_web}, "SourceTopic", "Wibble" );
    my $stream;
    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    $this->assert(open($stream,">$this->{tmpdatafile}"));
    binmode($stream);
    print $stream $data;
    close($stream);
    Foswiki::Func::saveAttachment(
        $this->{test_web}, "SourceTopic", "Name1",
        {
            dontlog => 1,
            comment => 'Feasgar Bha',
            file => $this->{tmpdatafile},
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
      } );
    $this->assert(Foswiki::Func::attachmentExists( $this->{test_web}, "SourceTopic",
                                                  "Name1"));

    # Verify that the source topic contains the string "Wibble"
    my ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/o );


    Foswiki::Func::saveTopicText( $this->{test_web}, "TargetTopic", "Wibble" );
    Foswiki::Func::saveTopicText( $this->{test_web2}, "TargetTopic", "Wibble" );

	Foswiki::Func::moveAttachment( $this->{test_web}, "SourceTopic", "Name1",
                              $this->{test_web}, "SourceTopic", "Name2" );
    $this->assert(!Foswiki::Func::attachmentExists( $this->{test_web}, "SourceTopic",
                                                  "Name1"));
    $this->assert(Foswiki::Func::attachmentExists( $this->{test_web}, "SourceTopic",
                                                 "Name2"));

    # Verify that the source topic still contains the string "Wibble"
    ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/o );


	Foswiki::Func::moveAttachment( $this->{test_web}, "SourceTopic", "Name2",
                              $this->{test_web}, "TargetTopic", undef );
    $this->assert(!Foswiki::Func::attachmentExists( $this->{test_web}, "SourceTopic",
                                                  "Name2"));
    $this->assert(Foswiki::Func::attachmentExists( $this->{test_web}, "TargetTopic",
                                                 "Name2"));

    # Verify that the target topic contains the string "Wibble"
    ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/o );

	Foswiki::Func::moveAttachment( $this->{test_web}, "TargetTopic", "Name2",
                              $this->{test_web2}, "TargetTopic", "Name1" );
    $this->assert(!Foswiki::Func::attachmentExists( $this->{test_web}, "TargetTopic",
                                                  "Name2"));
    $this->assert(Foswiki::Func::attachmentExists( $this->{test_web2}, "TargetTopic",
                                                 "Name1"));

    # Verify that the target topic still contains the string "Wibble" after the attachment move.
    ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/o );

}

sub test_workarea {
    my $this = shift;

    my $dir = Foswiki::Func::getWorkArea( 'TestPlugin' );
    $this->assert( -d $dir );

    # SMELL: check the permissions

    unlink $dir;
}

sub test_extractParameters {
    my $this = shift;

    my %attrs = Foswiki::Func::extractParameters('"a" b="c"');
    my %expect = ( _DEFAULT=>"a", b=>"c" );
    foreach my $a (keys %attrs) {
        $this->assert($expect{$a},$a);
        $this->assert_str_equals($expect{$a}, $attrs{$a}, $a);
        delete $expect{$a};
    }
}

sub test_w2em {
    my $this = shift;

    my $ems = join(',', $this->{twiki}->{users}->getEmails(
        $this->{twiki}->{user}));
    my $user = Foswiki::Func::getWikiName();
    $this->assert_str_equals($ems, Foswiki::Func::wikiToEmail($user));
}

sub test_normalizeWebTopicName {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my ($w, $t);
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( 'Web',  'Topic' );
    $this->assert_str_equals( 'Web', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '',     'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '',     '' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w);
    $this->assert_str_equals( 'WebHome', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '',     'Web/Topic' );
    $this->assert_str_equals( 'Web', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '',     'Web.Topic' );
    $this->assert_str_equals( 'Web', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( 'Web1', 'Web2.Topic' );
    $this->assert_str_equals( 'Web2', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%USERSWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%USERSWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( 'Web',     '' );
    $this->assert_str_equals( 'Web', $w);
    $this->assert_str_equals( $Foswiki::cfg{HomeTopicName}, $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName}, $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName}, $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%DOCWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName}, $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '', '%USERSWEB%.Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '', '%SYSTEMWEB%.Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName}, $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%USERSWEB%', 'Web2.Topic' );
    $this->assert_str_equals( 'Web2', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%', 'Web2.Topic' );
    $this->assert_str_equals( 'Web2', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( 'Wibble.Web',  'Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '',     'Wibble.Web/Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '',     'Wibble/Web/Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '',     'Wibble.Web.Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( 'Wibble.Web1', 'Wibble.Web2.Topic' );
    $this->assert_str_equals( 'Wibble/Web2', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%USERSWEB%.Wibble', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}.'/Wibble', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%.Wibble', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName}.'/Wibble', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%USERSWEB%.Wibble', 'Wibble.Web2.Topic' );
    $this->assert_str_equals( 'Wibble/Web2', $w);
    $this->assert_str_equals( 'Topic', $t );
    ($w, $t) = Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%.Wibble', 'Wibble.Web2.Topic' );
    $this->assert_str_equals( 'Wibble/Web2', $w);
    $this->assert_str_equals( 'Topic', $t );
}

sub test_checkAccessPermission {
    my $this = shift;
    my $topic = "NoWayJose";

	Foswiki::Func::saveTopicText( $this->{test_web}, $topic, <<END,
\t* Set DENYTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}
END
 );
    eval{$this->{twiki}->finish()};
    $this->{twiki} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{twiki};
    my $access = Foswiki::Func::checkAccessPermission(
        'VIEW', $Foswiki::cfg{DefaultUserWikiName}, undef, $topic, $this->{test_web});
    $this->assert(!$access);
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW', $Foswiki::cfg{DefaultUserWikiName}, '', $topic, $this->{test_web});
    $this->assert(!$access);
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW', $Foswiki::cfg{DefaultUserWikiName}, 0, $topic, $this->{test_web});
    $this->assert(!$access);
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW', $Foswiki::cfg{DefaultUserWikiName}, "Please me, let me go",
        $topic, $this->{test_web});
    $this->assert($access);
    # make sure meta overrides text, as documented - Item2953
    my $meta = new Foswiki::Meta($this->{twiki}, $this->{test_web}, $topic);
    $meta->putKeyed('PREFERENCE', {
        name => 'ALLOWTOPICVIEW',
        title => 'ALLOWTOPICVIEW',
        type => 'Set',
        value => $Foswiki::cfg{DefaultUserWikiName}});
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        "   * Set ALLOWTOPICVIEW = NotASoul\n",
        $topic, $this->{test_web}, $meta);
    $this->assert($access);
    $meta = new Foswiki::Meta($this->{twiki}, $this->{test_web}, $topic);
    $meta->putKeyed('PREFERENCE', {
        name => 'DENYTOPICVIEW',
        title => 'DENYTOPICVIEW',
        type => 'Set',
        value => $Foswiki::cfg{DefaultUserWikiName} });
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        "   * Set ALLOWTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}\n",
        $topic, $this->{test_web}, $meta);
    $this->assert(!$access);
}

# Since 4.2.1, checkAccessPermission accepts a login name
sub test_checkAccessPermission_421 {
    my $this = shift;
    my $topic = "NoWayJose";

	Foswiki::Func::saveTopicText( $this->{test_web}, $topic, <<END,
\t* Set DENYTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}
END
 );
    eval{$this->{twiki}->finish()};
    $this->{twiki} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{twiki};
    my $access = Foswiki::Func::checkAccessPermission(
        'VIEW', $Foswiki::cfg{DefaultUserLogin}, undef, $topic, $this->{test_web});
    $this->assert(!$access);
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW', $Foswiki::cfg{DefaultUserLogin}, '', $topic, $this->{test_web});
    $this->assert(!$access);
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW', $Foswiki::cfg{DefaultUserLogin}, 0, $topic, $this->{test_web});
    $this->assert(!$access);
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW', $Foswiki::cfg{DefaultUserLogin}, "Please me, let me go",
        $topic, $this->{test_web});
    $this->assert($access);
    # make sure meta overrides text, as documented - Item2953
    my $meta = new Foswiki::Meta($this->{twiki}, $this->{test_web}, $topic);
    $meta->putKeyed('PREFERENCE', {
        name => 'ALLOWTOPICVIEW',
        title => 'ALLOWTOPICVIEW',
        type => 'Set',
        value => $Foswiki::cfg{DefaultUserWikiName}});
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserLogin},
        "   * Set ALLOWTOPICVIEW = NotASoul\n",
        $topic, $this->{test_web}, $meta);
    $this->assert($access);
    $meta = new Foswiki::Meta($this->{twiki}, $this->{test_web}, $topic);
    $meta->putKeyed('PREFERENCE', {
        name => 'DENYTOPICVIEW',
        title => 'DENYTOPICVIEW',
        type => 'Set',
        value => $Foswiki::cfg{DefaultUserWikiName} });
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserLogin},
        "   * Set ALLOWTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}\n",
        $topic, $this->{test_web}, $meta);
    $this->assert(!$access);
}

sub test_getExternalResource {
    my $this = shift;

    # need a known, simple, robust URL to get
    my $response = Foswiki::Func::getExternalResource('http://foswiki.org');
    $this->assert_equals( 200, $response->code() );
    $this->assert_matches(
        qr/Foswiki is the open, programmable collaboration platform for the Enterprise/s, 
        $response->content() );
    $this->assert( !$response->is_error() );
    $this->assert( !$response->is_redirect() );
}

sub test_isTrue {
    my $this = shift;

#Returns 1 if =$value= is true, and 0 otherwise. "true" means set to
#something with a Perl true value, with the special cases that "off",
#"false" and "no" (case insensitive) are forced to false. Leading and
#trailing spaces in =$value= are ignored.
#
#If the value is undef, then =$default= is returned. If =$default= is
#not specified it is taken as 0.

#DEFAULTS
    $this->assert_equals(0, Foswiki::Func::isTrue());
    $this->assert_equals(1, Foswiki::Func::isTrue(undef, 1));
    $this->assert_equals(0, Foswiki::Func::isTrue(undef, undef));

#TRUE
    $this->assert_equals(1, Foswiki::Func::isTrue('true', 'bad'));
    $this->assert_equals(1, Foswiki::Func::isTrue('True', 'bad'));
    $this->assert_equals(1, Foswiki::Func::isTrue('TRUE', 'bad'));
    $this->assert_equals(1, Foswiki::Func::isTrue('bad', 'bad'));
    $this->assert_equals(1, Foswiki::Func::isTrue('Bad', 'bad'));
    $this->assert_equals(1, Foswiki::Func::isTrue('BAD'));

    $this->assert_equals(1, Foswiki::Func::isTrue(1));
    $this->assert_equals(1, Foswiki::Func::isTrue(-1));
    $this->assert_equals(1, Foswiki::Func::isTrue(12));
    $this->assert_equals(1, Foswiki::Func::isTrue({a=>'me', b=>'ed'}));

#FALSE
    $this->assert_equals(0, Foswiki::Func::isTrue('off', 'bad'));
    $this->assert_equals(0, Foswiki::Func::isTrue('no', 'bad'));
    $this->assert_equals(0, Foswiki::Func::isTrue('false', 'bad'));

    $this->assert_equals(0, Foswiki::Func::isTrue('Off', 'bad'));
    $this->assert_equals(0, Foswiki::Func::isTrue('No', 'bad'));
    $this->assert_equals(0, Foswiki::Func::isTrue('False', 'bad'));

    $this->assert_equals(0, Foswiki::Func::isTrue('OFF', 'bad'));
    $this->assert_equals(0, Foswiki::Func::isTrue('NO', 'bad'));
    $this->assert_equals(0, Foswiki::Func::isTrue('FALSE', 'bad'));

    $this->assert_equals(0, Foswiki::Func::isTrue(0));
    $this->assert_equals(0, Foswiki::Func::isTrue('0'));
    $this->assert_equals(0, Foswiki::Func::isTrue(' 0'));

#SPACES
    $this->assert_equals(0, Foswiki::Func::isTrue('  off', 'bad'));
    $this->assert_equals(0, Foswiki::Func::isTrue('no  ', 'bad'));
    $this->assert_equals(0, Foswiki::Func::isTrue('  false  ', 'bad'));

    $this->assert_equals(0, Foswiki::Func::isTrue(0));

}

sub test_decodeFormatTokens {
    my $this = shift;

    my $input = <<'TEST';
$n embed$nembed$n()embed
$nop embed$nopembed$nop()embed
$quot embed$quotembed$quot()embed
$percnt embed$percntembed$percnt()embed
$dollar embed$dollarembed$dollar()embed
$lt embed$ltembed$lt()embed
$gt embed$gtembed$gt()embed
$amp embed$ampembed$amp()embed
TEST
    my $expected = <<'TEST';

 embed$nembed
embed
 embedembedembed
" embed"embed"embed
% embed%embed%embed
$ embed$embed$embed
< embed<embed<embed
> embed>embed>embed
& embed&embed&embed
TEST
    my $output = Foswiki::Func::decodeFormatTokens($input);
    $this->assert_str_equals($expected, $output);
}

sub test_eachChangeSince {
    my $this = shift;
    $Foswiki::cfg{Store}{RememberChangesFor} = 5; # very bad memory
    my $gus = $this->{twiki}->{user};
    my $sb = $this->{twiki}->{users}->findUserByWikiName("ScumBag")->[0];

    sleep(1);
    my $start = time();
    my $users = $this->{twiki}->{users};
    $this->{twiki}->{store}->saveTopic(
        $gus, $this->{test_web}, "ClutterBuck",
        "One" );
    $this->{twiki}->{store}->saveTopic(
        $sb,
        $this->{test_web}, "PiggleNut",
        "One" );
    # Wait a second
    sleep(1);
    my $mid = time();
    $this->{twiki}->{store}->saveTopic(
        $sb,
        $this->{test_web}, "ClutterBuck",
        "One" );
    $this->{twiki}->{store}->saveTopic(
        $gus,
        $this->{test_web}, "PiggleNut",
        "Two", undef );
    my $change;
    my $it = Foswiki::Func::eachChangeSince($this->{test_web}, $start);
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("PiggleNut", $change->{topic});
    $this->assert_equals(2, $change->{revision});
    $this->assert_equals('WikiGuest', $change->{user});
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("ClutterBuck", $change->{topic});
    $this->assert_equals(2, $change->{revision});
    $this->assert_equals('ScumBag', $change->{user});
    $change = $it->next();
    $this->assert_str_equals("PiggleNut", $change->{topic});
    $this->assert_equals(1, $change->{revision});
    $this->assert_equals('ScumBag', $change->{user});
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("ClutterBuck", $change->{topic});
    $this->assert_equals(1, $change->{revision});
    $this->assert_equals('WikiGuest', $change->{user});
    $this->assert(!$it->hasNext());

    $it = Foswiki::Func::eachChangeSince($this->{test_web}, $mid);
    $this->assert($it->hasNext());
    $change = $it->next();
    $this->assert_str_equals("PiggleNut", $change->{topic});
    $this->assert_equals(2, $change->{revision});
    $this->assert_equals('WikiGuest', $change->{user});
    $change = $it->next();
    $this->assert_str_equals("ClutterBuck", $change->{topic});
    $this->assert_equals(2, $change->{revision});
    $this->assert_equals('ScumBag', $change->{user});

    $this->assert(!$it->hasNext());
}

# Check consistency between getListofWebs and webExists
sub test_4308 {
    my $this = shift;
    my @list = Foswiki::Func::getListOfWebs('user');
    foreach my $web (@list) {
        $this->assert(Foswiki::Func::webExists($web), $web);
    }
    @list = Foswiki::Func::getListOfWebs('user public');
    foreach my $web (@list) {
        $this->assert(Foswiki::Func::webExists($web), $web);
    }
    @list = Foswiki::Func::getListOfWebs('template');
    foreach my $web (@list) {
        $this->assert(Foswiki::Func::webExists($web), $web);
    }
    @list = Foswiki::Func::getListOfWebs('public template');
    foreach my $web (@list) {
        $this->assert(Foswiki::Func::webExists($web), $web);
    }
}

sub test_4411 {
    my $this = shift;
    $this->assert(Foswiki::Func::isGuest(), $this->{twiki}->{user});
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki($Foswiki::cfg{AdminUserLogin});
    $this->assert(!Foswiki::Func::isGuest(), $this->{twiki}->{user});
}

sub test_setPreferences {
    my $this = shift;
    $this->assert(!Foswiki::Func::getPreferencesValue("PSIBG"));
    $this->assert(Foswiki::Func::setPreferencesValue("PSIBG", "KJHD"));
    $this->assert_str_equals("KJHD", Foswiki::Func::getPreferencesValue("PSIBG"));
    my $q = Foswiki::Func::getCgiQuery();

    ####
	Foswiki::Func::saveTopicText( $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName}, <<HERE);
   * Set PSIBG = naff
   * Set FINALPREFERENCES = PSIBG
HERE
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki($Foswiki::cfg{GuestUserLogin}, $q);
    $this->assert_str_equals("naff",
                             Foswiki::Func::getPreferencesValue("PSIBG"));
    $this->assert(!Foswiki::Func::setPreferencesValue("PSIBG", "KJHD"));
    $this->assert_str_equals("naff", Foswiki::Func::getPreferencesValue("PSIBG"));
    ###
	Foswiki::Func::saveTopicText( $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName}, <<HERE);
   * Set PSIBG = naff
HERE
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki($Foswiki::cfg{GuestUserLogin}, $q);
    $this->assert_str_equals("naff",
                             Foswiki::Func::getPreferencesValue("PSIBG"));
    $this->assert(Foswiki::Func::setPreferencesValue("PSIBG", "KJHD"));
    $this->assert_str_equals("KJHD", Foswiki::Func::getPreferencesValue("PSIBG"));

}

sub test_getPluginPreferences {
    my $this = shift;
    my $pvar = "PSIBG";
    my $var = uc(__PACKAGE__)."_$pvar";
    $this->assert_null(Foswiki::Func::getPreferencesValue($var));
    $this->assert_null(Foswiki::Func::getPreferencesValue($pvar));
    $this->assert(Foswiki::Func::setPreferencesValue($var, "on"));
    $this->assert_str_equals("on", Foswiki::Func::getPluginPreferencesValue($pvar));
    $this->assert(Foswiki::Func::getPluginPreferencesFlag($pvar));
    $this->assert(Foswiki::Func::setPreferencesValue($var, "off"));
    $this->assert_str_equals("off", Foswiki::Func::getPluginPreferencesValue($pvar));
    $this->assert(!Foswiki::Func::getPluginPreferencesFlag($pvar));
}

1;

