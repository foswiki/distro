#
# Unit tests for Foswiki::Func
#

package FuncTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::Func;
use Assert;

my $MrWhite;

sub new {
    my $self = shift()->SUPER::new( "Func", @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $topicObject = Foswiki::Meta->new(
        $this->{session},
        $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{DefaultUserWikiName}, ''
    );
    $topicObject->save();
    $this->registerUser( 'white', 'Mr', "White", 'white@example.com' );
    $MrWhite = $this->{session}->{users}->getCanonicalUserID('white');

    $this->{tmpdatafile} = $Foswiki::cfg{TempfileDir} . '/tmpity-tmp.gif';
    $this->{tmpdatafile2} = $Foswiki::cfg{TempfileDir} . '/tmpity-tmp2.gif';
    $this->{test_web2}   = $this->{test_web} . 'Extra';
    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{test_web2} );
    $webObject->populateNewWeb();
}

sub tear_down {
    my $this = shift;
    unlink $this->{tmpdatafile};
    unlink $this->{tmpdatafile2};
    $this->removeWebFixture( $this->{session}, $this->{test_web2} );
    $this->SUPER::tear_down();
}

sub test_createWeb_permissions {
    my $this = shift;
    use Error qw( :try );
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );

    Foswiki::Func::saveTopicText( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<HERE);
\t* Set DENYWEBCHANGE = $Foswiki::cfg{DefaultUserWikiName}
HERE

    $this->{session}->finish();
    $this->{session} = new Foswiki();

    # Verify that create of a root web is denied by default user.
    try {
        Foswiki::Func::createWeb("Blahweb");
    } catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_matches( qr/access not allowed on root/, $e, "Unexpected error $e");
    };
    $this->assert(! Foswiki::Func::webExists("Blahweb"), "Test should not have created the web");

    # Verify that create of a sub web is denied by default user if denied in webPreferences.
    try {
        Foswiki::Func::createWeb("$this->{test_web}/Blahsub");
    } catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_matches( qr/Access to CHANGE TemporaryFuncTestWebFunc\/Blahsub. for BaseUserMapping_666 is denied. access denied on web/, $e, "Unexpected error $e");
    };
    $this->assert(! Foswiki::Func::webExists("$this->{test_web}/Blahsub"), "Test should not have created the web");

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );

    Foswiki::Func::saveTopicText(
        $this->{test_web}, 'WebPreferences', <<END,
\t* Set ALLOWWEBCHANGE = $Foswiki::cfg{DefaultUserWikiName}
END
    );

    $this->{session}->finish();
    $this->{session} = new Foswiki();

    # Verify that create of a sub web is allowed by default user if allowed in webPreferences.
    try {
        Foswiki::Func::createWeb("$this->{test_web}/Blahsub");
    } catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert("Unexpected error $e");
    };
    $this->assert( Foswiki::Func::webExists("$this->{test_web}/Blahsub"), "Test should have created the web");
}

sub test_Item9021 {
    my $this = shift;
    use Error qw( :try );
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );

    try {
        Foswiki::Func::createWeb($this->{test_web}."Missing/Blah");
    } catch Error::Simple with {
        my $e = shift;
        $this->assert_matches( qr/^Parent web TemporaryFuncTestWebFuncMissing does not exist.*/, $e, "Unexpected error $e");
    };
    $this->assert(! Foswiki::Func::webExists($this->{test_web}."Missing"), "test should not have created the web");
    $this->assert(! Foswiki::Func::webExists($this->{test_web}."Missing/Blah"), "Test should not have created the web");
}

sub test_createWeb_InvalidBase {
    my $this = shift;
    use Error qw( :try );
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );

    try {
        Foswiki::Func::createWeb($this->{test_web}."InvaliBase", "Invalidbase");
    } catch Error::Simple with {
        my $e = shift;
        $this->assert_matches( qr/^Template web Invalidbase does not exist.*/, $e, "Unexpected error $e");
    };
    $this->assert(! Foswiki::Func::webExists($this->{test_web}."invaliBase"));
}

sub test_createWeb_hierarchyDisabled {
    my $this = shift;
    use Error qw( :try );
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 0;

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );

    try {
        Foswiki::Func::createWeb($this->{test_web} . "/Subweb");
    } catch Error::Simple with {
        my $e = shift;
        $this->assert_matches( qr/^Unable to create .*- Hierarchical webs are disabled.*/, $e, "Unexpected error $e");
    };
    $this->assert(! Foswiki::Func::webExists($this->{test_web}."/Subweb"));
}


sub test_moveWeb {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{test_web} . "Blah"  );
    $webObject->populateNewWeb();
    undef $webObject;
    $webObject = Foswiki::Meta->new( $this->{session}, $this->{test_web} . "Blah/SubWeb"  );
    $webObject->populateNewWeb();

    $this->assert( Foswiki::Func::webExists( $this->{test_web} . 'Blah' ) );
    $this->assert(
        Foswiki::Func::webExists( $this->{test_web} . 'Blah/SubWeb' ) );

    Foswiki::Func::moveWeb( $this->{test_web} . 'Blah',
        $this->{test_web} . 'Blah2' );

    $this->assert( !Foswiki::Func::webExists( $this->{test_web} . 'Blah' ) );
    $this->assert( Foswiki::Func::webExists( $this->{test_web} . 'Blah2' ) );
    $this->assert(
        Foswiki::Func::webExists( $this->{test_web} . 'Blah2/SubWeb' ) );
    $this->removeWebFixture( $this->{session}, $this->{test_web}.'Blah2' );
}

sub test_getViewUrl {
    my $this = shift;
    my $ss;

    if (defined $Foswiki::cfg{ScriptUrlPaths}{view} ) {
        $ss = $Foswiki::cfg{ScriptUrlPaths}{view};
        }
    else {
        $ss = 'view' . $Foswiki::cfg{ScriptSuffix};
        }

    # relative to specified web
    my $result = Foswiki::Func::getViewUrl( $this->{users_web}, "WebHome" );
    $this->assert_matches( qr!$ss/$this->{users_web}/WebHome!, $result );

    # relative to web in path_info
    $result = Foswiki::Func::getViewUrl( "", "WebHome" );
    $this->assert_matches( qr!$ss/$this->{test_web}/WebHome!, $result );

    $Foswiki::Plugins::SESSION =
      new Foswiki( undef,
        new Unit::Request( { topic => "Sausages.AndMash" } ) );

    $result = Foswiki::Func::getViewUrl( "Sausages", "AndMash" );
    $this->assert_matches( qr!${ss}/Sausages/AndMash!, $result );

    $result = Foswiki::Func::getViewUrl( "", "AndMash" );
    $this->assert_matches( qr!${ss}/Sausages/AndMash!, $result );
    $Foswiki::Plugins::SESSION->finish();
}

sub test_getScriptUrl {
    my $this = shift;

    my $ss = 'wibble' . $Foswiki::cfg{ScriptSuffix};
    my $result =
      Foswiki::Func::getScriptUrl( $this->{users_web}, "WebHome", 'wibble' );
    $this->assert_matches( qr!/$ss/$this->{users_web}/WebHome!, $result );

    $result = Foswiki::Func::getScriptUrl( "", "WebHome", 'wibble' );
    $this->assert_matches( qr!/$ss/$this->{users_web}/WebHome!, $result );

    my $q = new Unit::Request( {} );
    $q->path_info('/Sausages/AndMash');
    $Foswiki::Plugins::SESSION = new Foswiki( undef, $q );

    $result = Foswiki::Func::getScriptUrl( "Sausages", "AndMash", 'wibble' );
    $this->assert_matches( qr!/$ss/Sausages/AndMash!, $result );

    $result = Foswiki::Func::getScriptUrl( "", "AndMash", 'wibble' );
    $this->assert_matches( qr!/$ss/$this->{users_web}/AndMash!, $result );
    $Foswiki::Plugins::SESSION->finish();
}

sub test_getOopsUrl {
    my $this = shift;
    my $url =
      Foswiki::Func::getOopsUrl( 'Incy', 'Wincy', 'Spider', 'Hurble', 'Burble',
        'Wurble', 'Murble' );
    $this->assert_str_equals(
        Foswiki::Func::getScriptUrl( 'Incy', 'Wincy', 'oops' )
          . "?template=Spider;param1=Hurble;param2=Burble;param3=Wurble;param4=Murble",
        $url
    );
    $url = Foswiki::Func::getOopsUrl(
        'Incy',   'Wincy',  'oopspider', 'Hurble',
        'Burble', 'Wurble', 'Murble'
    );
    $this->assert_str_equals(
        Foswiki::Func::getScriptUrl( 'Incy', 'Wincy', 'oops' )
          . "?template=oopspider;param1=Hurble;param2=Burble;param3=Wurble;param4=Murble",
        $url
    );
}

# Check lease handling
sub test_leases {
    my $this = shift;

    my $testtopic = $Foswiki::cfg{HomeTopicName};

    # Check that there is no lease on the home topic
    my ( $oops, $login, $time ) =
      Foswiki::Func::checkTopicEditLock( $this->{test_web}, $testtopic );
    $this->assert( !$oops, $oops );
    $this->assert( !$login );
    $this->assert_equals( 0, $time );

    # Take out a lease on behalf of the current user
    Foswiki::Func::setTopicEditLock( $this->{test_web}, $testtopic, 1 );

    # Work out who leased it. The login name is used in the lease check.
    my $locker = Foswiki::Func::wikiToUserName( Foswiki::Func::getWikiName() );
    $this->assert($locker);

    # check the lease
    ( $oops, $login, $time ) =
      Foswiki::Func::checkTopicEditLock( $this->{test_web}, $testtopic );
    $this->assert_equals( $locker, $login );
    $this->assert( $time > 0 );
    $this->assert_matches( qr/leaseconflict/, $oops );
    $this->assert_matches( qr/active/,        $oops );

    # try and clear the lease. This should always succeed.
    Foswiki::Func::setTopicEditLock( $this->{test_web}, $testtopic, 0 );

    ( $oops, $login, $time ) =
      Foswiki::Func::checkTopicEditLock( $this->{test_web}, $testtopic );
    $this->assert( !$oops, $oops );
    $this->assert( !$login );
    $this->assert_equals( 0, $time );
}

# As much as I'd like to remove this dumb function, make sure it's still
# compatible
sub test_saveTopicText {
    my $this = shift;
    my $topic = 'SaveTopicText';
    Foswiki::Func::saveTopicText(
        $this->{test_web}, $topic, <<NONNY );
   * Set ALLOWTOPICCHANGE = NotMeNoNotMe
NONNY
    $this->assert(!
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        Foswiki::Func::getWikiName(), undef, $topic, $this->{test_web} ));

    # This should fail and return an oopsUrl (FFS, what a shit spec)
    my $oopsURL = Foswiki::Func::saveTopicText(
        $this->{test_web}, $topic, 'Gasp' );
    $this->assert($oopsURL);
    my @ri = Foswiki::Func::getRevisionInfo($this->{test_web}, $topic);
    $this->assert_matches(qr/1$/, $ri[2]);

    # This should succeed and return undef
    $oopsURL = Foswiki::Func::saveTopicText(
        $this->{test_web}, $topic, 'Beam', 1 );
    $this->assert(!$oopsURL, $oopsURL);
}

sub test_saveTopic {
    my $this = shift;
    my $topic = 'SaveTopic';
    Foswiki::Func::saveTopic(
        $this->{test_web}, $topic, undef, <<NONNY );
%META:PREFERENCE{name="Bird" value="Kakapo"}%
   * Set ALLOWTOPICCHANGE = NotMeNoNotMe
NONNY
    $this->assert(!
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        Foswiki::Func::getWikiName(), undef, $topic, $this->{test_web} ));
    my @ri = Foswiki::Func::getRevisionInfo($this->{test_web}, $topic);
    $this->assert_matches(qr/1$/, $ri[2]);

    # Make sure the meta got into the topic
    my ($m, $t) = Foswiki::Func::readTopic($this->{test_web}, $topic);
    my $el = $m->get('PREFERENCE', 'Bird');
    $this->assert_equals('Kakapo', $el->{value});

    # This should succeed
    Foswiki::Func::saveTopic($this->{test_web}, $topic, undef, 'Gasp',
                            { forcenewrevision => 1 });
    @ri = Foswiki::Func::getRevisionInfo($this->{test_web}, $topic);
    $this->assert_matches(qr/2$/, $ri[2]);
}

sub test_Item8713 {
    my $this = shift;
    my $tweb = 'A:B';
    my $topic = 'C:D';
    try {
    Foswiki::Func::saveTopic(
        $tweb, $topic, undef, <<NONNY );
%META:PREFERENCE{name="Bird" value="Kakapo"}%
   * Set ALLOWTOPICCHANGE = NotMeNoNotMe
NONNY
    } catch Error::Simple with {
        my $e = shift;
        $this->assert_matches( qr/Unable to save topic C:D - web A:B does not exist.*/, $e, "Unexpected error $e");
    }


    #$this->assert(
    #   ! Foswiki::Func::webExists( $tweb ));
    #$this->assert(
    #   ! Foswiki::Func::topicExists( $tweb, $topic ) );
}

sub test_attachments {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $data  = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $data2  = "\0h\1a\2l\3b\4h\5a\6l\7b";
    my $attnm = 'blahblahblah.gif';
    #$attnm = Assert::TAINT($attnm);
    my $name1 = 'blahblahblah.gif';
    #$name1 = Assert::TAINT($name1);
    my $name2 = 'bleagh.sniff';
    #$name2 = Assert::TAINT($name2);
    my $topic = "BlahBlahBlah";
    #$topic = Assert::TAINT($topic);

    my $stream;
    $this->assert( open( $stream, ">$this->{tmpdatafile}" ) );
    binmode($stream);
    print $stream $data;
    close($stream);

    $this->assert( open( $stream, "<$this->{tmpdatafile}" ) );
    binmode($stream);

    my $stream2;
    $this->assert( open( $stream2, ">$this->{tmpdatafile2}" ) );
    binmode($stream2);
    print $stream2 $data2;
    close($stream2);

    $this->assert( open( $stream2, "<$this->{tmpdatafile2}" ) );
    binmode($stream2);

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, '' );

    #$name1 = TAINT($name1);

    my $e = Foswiki::Func::saveAttachment(
        $this->{test_web},
        $topic, $name1,
        {
            dontlog  => 1,
            comment  => 'Feasgar Bha',
            stream   => $stream,
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert( !$e, $e );

    my ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    my @attachments = $meta->find('FILEATTACHMENT');
    $this->assert_str_equals( $name1, $attachments[0]->{name} );

    #$name2 = TAINT($name2);
    $e = Foswiki::Func::saveAttachment(
        $this->{test_web},
        $topic, $name2,
        {
            dontlog  => 1,
            comment  => 'Ciamar a tha u',
            file     => $this->{tmpdatafile},
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert( !$e, $e );

    ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    @attachments = $meta->find('FILEATTACHMENT');
    $this->assert_str_equals( $name1, $attachments[0]->{name} );
    $this->assert_str_equals( $name2, $attachments[1]->{name} );

    my $x = Foswiki::Func::readAttachment( $this->{test_web}, $topic, $name1 );
    $this->assert_str_equals( $data, $x );
    $x = Foswiki::Func::readAttachment( $this->{test_web}, $topic, $name2 );
    $this->assert_str_equals( $data, $x );

    # This should succeed - attachment exists
    $this->assert(
        Foswiki::Func::attachmentExists( $this->{test_web}, $topic, $name1 ) );

    # This should fail - attachment is not present
    $this->assert(
        !(Foswiki::Func::attachmentExists( $this->{test_web}, $topic, "NotExists" )) );

    # This should fail - attachment is not present
    $this->assert( 
        !Foswiki::Func::readAttachment( $this->{test_web}, $topic, "NotExists" ));

    # Update the attachment and check that the data is updated.
    $e = Foswiki::Func::saveAttachment(
        $this->{test_web},
        $topic, $name2,
        {
            dontlog  => 1,
            comment  => 'Ciamar a tha u',
            file     => $this->{tmpdatafile2},
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert( !$e, $e );
    $x = Foswiki::Func::readAttachment( $this->{test_web}, $topic, $name2 );
    $this->assert_str_equals( $data2, $x );

    # Verify that the prior revision contains the old data
    $x = Foswiki::Func::readAttachment( $this->{test_web}, $topic, $name2, "1");
    $this->assert_str_equals( $data, $x );

}

sub test_noauth_saveAttachment {
    my $this = shift;
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $name1 = 'blahblahblah.gif';
    my $topic = "BlahBlahBlah";

    my $stream;
    $this->assert(open($stream,">$this->{tmpdatafile}"));
    binmode($stream);
    print $stream $data;
    close($stream);

    $this->assert(open($stream, "<$this->{tmpdatafile}"));
    binmode($stream);

	Foswiki::Func::saveTopicText( $this->{test_web}, $topic," \n   * Set ALLOWTOPICCHANGE = SomeUser\n" );

    try {
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
      $this->assert(0, "saveAttachment worked for unauthorized user");

    } catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_matches( qr/^AccessControlException: Access to CHANGE TemporaryFuncTestWebFunc.BlahBlahBlah for BaseUserMapping_666 is denied.*/, $e, "Unexpected error $e");
    };
}

sub test_noauth_saveTopic {
    my $this = shift;

    my $curUser = 'MrWhite';
    my $userLogin = 'white';
    my $topic = "BlahBlahcwBlah";
    my $ttext = " APPLE \n   * Set ALLOWTOPICVIEW = SomeUser \n   * Set DENYTOPICCHANGE = BaseUserMapping_666,MrWhite \n ";

    my $query = new Unit::Request();
    $this->{session} = new Foswiki( $userLogin, $query );
	Foswiki::Func::saveTopicText( $this->{test_web}, $topic, $ttext );

    $this->assert(Foswiki::Func::topicExists( $this->{test_web}, $topic ));

    $this->assert(!Foswiki::Func::checkAccessPermission( 'VIEW', $curUser, '', $topic, $this->{test_web} ), "VIEW check failed - $curUser should be denied");
    $this->assert(!Foswiki::Func::checkAccessPermission( 'CHANGE', $curUser, '', $topic, $this->{test_web} ), "CHANGE check failed - $curUser should be denied");

    # Validate that saveTopicText throws an exception
	$this->assert_matches( qr/oopsattention;def=topic_access/,
      Foswiki::Func::saveTopicText( $this->{test_web}, $topic," \n   * Set ALLOWTOPIVIEW = SomeUser \n blah" )) ;
    $this->assert(!Foswiki::Func::checkAccessPermission( 'CHANGE', $curUser, '', $topic, $this->{test_web} ));

    # Also validate that saveTopic throws an exception
    my( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    try {
        Foswiki::Func::saveTopic( $this->{test_web}, $topic, $meta, $text );
        $this->assert(0, "saveTopic worked for unauthorized user");
    } catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_matches( qr/^AccessControlException: Access to CHANGE TemporaryFuncTestWebFunc.BlahBlahcwBlah for white is denied.*/, $e, "Unexpected error $e");
    };
}


sub test_subweb_attachments {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $data  = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $data2  = "\0h\1a\2l\3b\4h\5a\6l\7b";
    my $attnm = 'blahblahblah.gif';
    my $name1 = 'blahblahblah.gif';
    my $name2 = 'bleagh.sniff';
    my $topic = "BlahBlahBlah";
    #$topic = Assert::TAINT($topic);
    my $web = $this->{test_web}."/SubWeb";
    #$web = Assert::TAINT($web);
    #
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->populateNewWeb();

    my $stream;
    $this->assert( open( $stream, ">$this->{tmpdatafile}" ) );
    binmode($stream);
    print $stream $data;
    close($stream);

    $this->assert( open( $stream, "<$this->{tmpdatafile}" ) );
    binmode($stream);

    my $stream2;
    $this->assert( open( $stream2, ">$this->{tmpdatafile2}" ) );
    binmode($stream2);
    print $stream2 $data2;
    close($stream2);

    $this->assert( open( $stream2, "<$this->{tmpdatafile2}" ) );
    binmode($stream2);

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, '' );

    #$name1 = Assert::TAINT($name1);
    my $e = Foswiki::Func::saveAttachment(
        $web,
        $topic, $name1,
        {
            dontlog  => 1,
            comment  => 'Feasgar Bha',
            stream   => $stream,
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert( !$e, $e );

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my @attachments = $meta->find('FILEATTACHMENT');
    $this->assert_str_equals( $name1, $attachments[0]->{name} );

    #$name2 = Assert::TAINT($name2);
    my $infile = $this->{tmpdatafile};

    #my $web = Assert::TAINT($web);
    #my $infile = Assert::TAINT($this->{tmpdatafile1});

    my @stats    = stat $this->{tmpdatafile};
    my $fileSize = $stats[7];
    my $fileDate = $stats[9];
    $e = Foswiki::Func::saveAttachment(
        $web, 
        $topic,
        $name2,
        {
            dontlog => 1,
            file     => $infile, 
            filedate => $fileDate,
            filesize => $fileSize,
            comment  => '<nop>DirectedGraphPlugin: DOT graph',
            hide     => 1,
        }
       );
    $this->assert( !$e, $e );

    # Verify that the files and directories actually were created
    #
    my $ft = '';
    $ft = Foswiki::Func::getPubDir(). "/" . $web;
    $this->assert( (-d $ft), "Web directory for attachment not created"  );
    $ft .= "/".$topic;
    $this->assert( (-d $ft), "Topic directory for attachment not created?"  );
    $this->assert(
        (-e $ft."/$name1" ),
        "Attachment file $ft/$name1  was not written to disk?" );
    $this->assert(
        (-e $ft."/$name1,v" ),
        "Attachment RCS Filename $ft/$name1,v was not written to disk?" );
    $this->assert(
        (-e $ft."/$name2,v" ),
        "Attachment RCS Filename $ft/$name2,v was not written to disk?" );
    $this->assert(
        (-e $ft."/$name2" ),
        "Attachment file $ft/$name2  was not written to disk?" );

    ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    @attachments = $meta->find('FILEATTACHMENT');
    $this->assert_str_equals( $name1, $attachments[0]->{name} );
    # Make sure it has a non-0 date
    $this->assert( $attachments[1]->{date} );
    $this->assert_str_equals( $name2, $attachments[1]->{name} );
    $this->assert_num_equals( $fileDate, $attachments[1]->{date} );

    my $x = Foswiki::Func::readAttachment( $web, $topic, $name1 );
    $this->assert_str_equals( $data, $x );
    $x = Foswiki::Func::readAttachment( $web, $topic, $name2 );
    $this->assert_str_equals( $data, $x );

    # This should succeed - attachment exists
    $this->assert(
        Foswiki::Func::attachmentExists( $web, $topic, $name1 ) );

    # This should fail - attachment is not present
    $this->assert(
        !(Foswiki::Func::attachmentExists( $web, $topic, "NotExists" )) );

    # This should fail - attachment is not present
    $this->assert( 
        !Foswiki::Func::readAttachment( $web, $topic, "NotExists" ));

    # Update the attachment and check that the data is updated.
    $e = Foswiki::Func::saveAttachment(
        $web,
        $topic, $name2,
        {
            dontlog  => 1,
            comment  => 'Ciamar a tha u',
            file     => $this->{tmpdatafile2},
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert( !$e, $e );
    $x = Foswiki::Func::readAttachment( $web, $topic, $name2 );
    $this->assert_str_equals( $data2, $x );

    # Verify that the prior revision contains the old data
    $x = Foswiki::Func::readAttachment( $web, $topic, $name2, "1");
    $this->assert_str_equals( $data, $x );

}

sub test_getrevinfo {
    my $this  = shift;
    my $topic = "RevInfo";
    my $now = time();
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{test_web} . "/Blah"  );
    $webObject->populateNewWeb();

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, 'blah' );
    Foswiki::Func::saveTopicText( "$this->{test_web}/Blah", $topic, 'blah' );

    my ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic );
    $this->assert_equals( 1, $rev );
    my $wikiname = Foswiki::Func::getWikiName();
    $this->assert_str_equals( $wikiname, $user );
    $this->assert_equals( 1, $rev );
    $this->assert( $date >= $now, $date);
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( "$this->{test_web}/Blah", $topic );
    $this->assert_str_equals( $wikiname, $user );
    $this->assert_equals( 1, $rev );
    $this->assert( $date >= $now, $date);
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( "$this->{test_web}.Blah", $topic );
    $this->assert_str_equals( $wikiname, $user );
    $this->assert_equals( 1, $rev );
    $this->assert( $date >= $now, $date);
}

# Helper function for test_moveTopic
sub _checkMoveTopic($$$$) {
    my ( $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;
    my $meta;
    my $text;
    my $count = 0;
    $newWeb   ||= $oldWeb;
    $newTopic ||= $oldTopic;
    ( $meta, $text ) = Foswiki::Func::readTopic( $newWeb, $newTopic );

    #print STDERR "looking for $oldWeb.$oldTopic -> $newWeb.$newTopic\n";
    $count = @{ $meta->{TOPICMOVED} } if $meta->{TOPICMOVED};

    #print STDERR "there are $count TOPICMOVED entries.\n";
    foreach ( @{ $meta->{TOPICMOVED} } ) {

        #print STDERR "$_->{from} -> $_->{to}\n";
        # pick out the meta entry that indicates this move.
        next if ( $_->{to}   ne "$newWeb.$newTopic" );
        next if ( $_->{from} ne "$oldWeb.$oldTopic" );

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
    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, "TargetTopic" ) );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web2}, "SourceTopic" ) );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web2}, "TargetTopic" ) );

    # TEST:  Attach a file and make sure it exists.  It should follow the topic through moves.
    my $stream;
    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    $this->assert( open( $stream, ">$this->{tmpdatafile}" ) );
    binmode($stream);
    print $stream $data;
    close($stream);
    Foswiki::Func::saveAttachment(
        $this->{test_web},
        "SourceTopic",
        "Name1",
        {
            dontlog  => 1,
            comment  => 'Feasgar Bha',
            file     => $this->{tmpdatafile},
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name1"
        )
    );


    # TEST: move within the test web.
    Foswiki::Func::moveTopic( $this->{test_web}, "SourceTopic",
        $this->{test_web}, "TargetTopic" );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, "TargetTopic" ) );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "TargetTopic", "Name1"
        ) );


    # TEST: Move with undefined destination web; should stay in test_web.
    Foswiki::Func::moveTopic( $this->{test_web}, "TargetTopic", undef,
        "SourceTopic" );
    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, "TargetTopic" ) );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name1"
        ) );

    # TEST: Move to test_web2.
    Foswiki::Func::moveTopic( $this->{test_web}, "SourceTopic",
        $this->{test_web2}, "SourceTopic" );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web2}, "SourceTopic" ) );
    $this->assert(
        _checkMoveTopic(
            $this->{test_web},  "SourceTopic",
            $this->{test_web2}, "SourceTopic"
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web2}, "SourceTopic", "Name1"
        ) );

    # TEST: move with undefined destination topic.
    Foswiki::Func::moveTopic( $this->{test_web2}, "SourceTopic",
        $this->{test_web}, undef );
    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web2}, "SourceTopic" ) );
    $this->assert(
        _checkMoveTopic(
            $this->{test_web2}, "SourceTopic",
            $this->{test_web},  "SourceTopic"
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name1"
        ) );

    # TEST: move to test_web2 again.
    Foswiki::Func::moveTopic( $this->{test_web}, "SourceTopic",
        $this->{test_web2}, "TargetTopic" );
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        Foswiki::Func::topicExists( $this->{test_web2}, "TargetTopic" ) );
    $this->assert(
        _checkMoveTopic(
            $this->{test_web},  "SourceTopic",
            $this->{test_web2}, "TargetTopic"
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web2}, "TargetTopic", "Name1"
        ) );
}

sub test_moveAttachment {
    my $this = shift;

    Foswiki::Func::saveTopicText( $this->{test_web}, "SourceTopic", "Wibble" );
    my $stream;
    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    $this->assert( open( $stream, ">$this->{tmpdatafile}" ) );
    binmode($stream);
    print $stream $data;
    close($stream);
    Foswiki::Func::saveAttachment(
        $this->{test_web},
        "SourceTopic",
        "Name1",
        {
            dontlog  => 1,
            comment  => 'Feasgar Bha',
            file     => $this->{tmpdatafile},
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name1"
        )
    );

    # Verify that the source topic contains the string "Wibble"
    my ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/o );

    Foswiki::Func::saveTopicText( $this->{test_web},  "TargetTopic", "Wibble" );
    Foswiki::Func::saveTopicText( $this->{test_web2}, "TargetTopic", "Wibble" );

    # ###############
    # Rename an attachment - from/to web/topic the same
    #  Old attachment removed, new attachment exists, and source topic text unchanged
    # ###############
    Foswiki::Func::moveAttachment( $this->{test_web}, "SourceTopic", "Name1",
        $this->{test_web}, "SourceTopic", "Name2" );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name1"
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name2"
        )
    );
    # Verify that the source topic still contains the string "Wibble" following attachment move
    ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/o );

    # ###############
    # Move an attachment - from/to topic in the same web
    #  Old attachment removed, new attachment exists, and source topic text unchanged
    # ###############
    Foswiki::Func::moveAttachment( $this->{test_web}, "SourceTopic", "Name2",
        $this->{test_web}, "TargetTopic", undef );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name2"
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "TargetTopic", "Name2"
        )
    );
    # Verify that the target topic contains the string "Wibble"
    ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/o );

    # ###############
    # Move an attachment - to topic in a different web
    #  Old attachment removed, new attachment exists, and source topic text unchanged
    # ###############
    Foswiki::Func::moveAttachment( $this->{test_web}, "TargetTopic", "Name2",
        $this->{test_web2}, "TargetTopic", "Name1" );
    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, "TargetTopic", "Name2"
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web2}, "TargetTopic", "Name1"
        )
    );
    # Verify that the target topic still contains the string "Wibble" following attachment move
    ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/o );

}

sub test_copyAttachment {
    my $this = shift;

    Foswiki::Func::saveTopicText( $this->{test_web}, "SourceTopic", "Wibble" );
    my $stream;
    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    $this->assert( open( $stream, ">$this->{tmpdatafile}" ) );
    binmode($stream);
    print $stream $data;
    close($stream);
    Foswiki::Func::saveAttachment(
        $this->{test_web},
        "SourceTopic",
        "Name1",
        {
            dontlog  => 1,
            comment  => 'Feasgar Bha',
            file     => $this->{tmpdatafile},
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name1"
        )
    );

    # Verify that the source topic contains the string "Wibble"
    my ( $meta, $text ) = Foswiki::Func::readTopic(
        $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/o );

    Foswiki::Func::saveTopicText(
        $this->{test_web},  "TargetTopic", "Wibble" );
    Foswiki::Func::saveTopicText(
        $this->{test_web2}, "TargetTopic", "Wibble" );

    # ###############
    Foswiki::Func::copyAttachment( $this->{test_web}, "SourceTopic", "Name1",
        $this->{test_web}, "SourceTopic", "Name2" );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name1"
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name2"
        )
    );
    # Verify that the source topic still contains the string "Wibble"
    # following attachment copy
    ( $meta, $text ) = Foswiki::Func::readTopic(
        $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/o );

    # ###############
    # Move an attachment - from/to topic in the same web
    #  Old attachment removed, new attachment exists, and source topic
    # text unchanged
    # ###############
    Foswiki::Func::copyAttachment( $this->{test_web}, "SourceTopic", "Name2",
        $this->{test_web}, "TargetTopic", undef );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name2"
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "TargetTopic", "Name2"
        )
    );
    # Verify that the target topic contains the string "Wibble"
    ( $meta, $text ) = Foswiki::Func::readTopic(
        $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/o );

    # ###############
    # Copy an attachment - to topic in a different web
    #  Old attachment removed, new attachment exists, and source topic
    # text unchanged
    # ###############
    Foswiki::Func::copyAttachment( $this->{test_web}, "TargetTopic", "Name2",
        $this->{test_web2}, "TargetTopic", "Name1" );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, "TargetTopic", "Name2"
        )
    );
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web2}, "TargetTopic", "Name1"
        )
    );
    # Verify that the target topic still contains the string "Wibble"
    # following attachment copy
    ( $meta, $text ) = Foswiki::Func::readTopic(
        $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/o );

}

sub test_attachmentExists {
    my $this = shift;

    my $topic = "AttachmentExists";

    open( FILE, ">", "$Foswiki::cfg{TempfileDir}/testfile.txt" );
    print FILE "one two three";
    close( FILE );

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, 'foo' );
    Foswiki::Func::saveAttachment(
        $this->{test_web}, $topic, "testfile.txt",
        { file => "$Foswiki::cfg{TempfileDir}/testfile.txt",
          comment => "a comment" } );

    $this->assert(Foswiki::Func::attachmentExists( $this->{test_web}, $topic,
                                                 "testfile.txt"));
}

sub test_attachmentExistsInMetaOnly {
    my $this = shift;

    my $topic = "AttachmentExistsInMetaOnly";
    my $text = <<'HERE';
foo

%META:FILEATTACHMENT{name="Sample.txt" attr="" comment="Just a sample" date="964294620" path="Sample.txt" size="30" user="ProjectContributor" version=""}%
HERE

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, $text );

    $this->assert(not Foswiki::Func::attachmentExists( $this->{test_web}, $topic,
                                                 "Sample.txt"));
}

sub test_workarea {
    my $this = shift;

    my $dir = Foswiki::Func::getWorkArea('TestPlugin');
    $this->assert( -d $dir );

    # SMELL: check the permissions

    unlink $dir;
}

sub test_extractParameters {
    my $this = shift;

    my %attrs = Foswiki::Func::extractParameters('"a" b="c"');
    my %expect = ( _DEFAULT => "a", b => "c" );
    foreach my $a ( keys %attrs ) {
        $this->assert( $expect{$a}, $a );
        $this->assert_str_equals( $expect{$a}, $attrs{$a}, $a );
        delete $expect{$a};
    }
}

sub test_w2em {
    my $this = shift;

    my $ems = join( ',',
        $this->{session}->{users}->getEmails( $this->{session}->{user} ) );
    my $user = Foswiki::Func::getWikiName();
    $this->assert_str_equals( $ems, Foswiki::Func::wikiToEmail($user) );
}

sub test_normalizeWebTopicName {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my ( $w, $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web', 'Topic' );
    $this->assert_str_equals( 'Web',   $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'Topic',                     $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', '' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'WebHome',                   $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', 'Web/Topic' );
    $this->assert_str_equals( 'Web',   $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', 'Web.Topic' );
    $this->assert_str_equals( 'Web',   $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web1', 'Web2.Topic' );
    $this->assert_str_equals( 'Web2',  $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '%USERSWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'Topic',                     $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '%USERSWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'Topic',                     $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web', '' );
    $this->assert_str_equals( 'Web',                        $w );
    $this->assert_str_equals( $Foswiki::cfg{HomeTopicName}, $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName}, $w );
    $this->assert_str_equals( 'Topic',                      $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName}, $w );
    $this->assert_str_equals( 'Topic',                      $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '%DOCWEB%', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName}, $w );
    $this->assert_str_equals( 'Topic',                      $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', '%USERSWEB%.Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'Topic',                     $t );
    ( $w, $t ) =
      Foswiki::Func::normalizeWebTopicName( '', '%SYSTEMWEB%.Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName}, $w );
    $this->assert_str_equals( 'Topic',                      $t );
    ( $w, $t ) =
      Foswiki::Func::normalizeWebTopicName( '%USERSWEB%', 'Web2.Topic' );
    $this->assert_str_equals( 'Web2',  $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) =
      Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%', 'Web2.Topic' );
    $this->assert_str_equals( 'Web2',  $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Wibble.Web', 'Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w );
    $this->assert_str_equals( 'Topic',      $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', 'Wibble.Web/Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w );
    $this->assert_str_equals( 'Topic',      $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', 'Wibble/Web/Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w );
    $this->assert_str_equals( 'Topic',      $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', 'Wibble.Web.Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w );
    $this->assert_str_equals( 'Topic',      $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Wibble.Web1',
        'Wibble.Web2.Topic' );
    $this->assert_str_equals( 'Wibble/Web2', $w );
    $this->assert_str_equals( 'Topic',       $t );
    ( $w, $t ) =
      Foswiki::Func::normalizeWebTopicName( '%USERSWEB%.Wibble', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{UsersWebName} . '/Wibble', $w );
    $this->assert_str_equals( 'Topic',                                 $t );
    ( $w, $t ) =
      Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%.Wibble', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{SystemWebName} . '/Wibble', $w );
    $this->assert_str_equals( 'Topic',                                  $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '%USERSWEB%.Wibble',
        'Wibble.Web2.Topic' );
    $this->assert_str_equals( 'Wibble/Web2', $w );
    $this->assert_str_equals( 'Topic',       $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '%SYSTEMWEB%.Wibble',
        'Wibble.Web2.Topic' );
    $this->assert_str_equals( 'Wibble/Web2', $w );
    $this->assert_str_equals( 'Topic',       $t );
}

sub test_checkWebAccessPermission {
    my $this  = shift;

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );

    Foswiki::Func::saveTopicText( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<HERE);
\t* Set DENYWEBCHANGE = $Foswiki::cfg{DefaultUserWikiName}
HERE

    Foswiki::Func::saveTopicText( $this->{test_web},
        'WeeblesWobble', <<HERE);
\t* Set ALLOWTOPICCHANGE = $Foswiki::cfg{DefaultUserWikiName}
HERE

    $this->{session}->finish();
    $this->{session} = new Foswiki();

    $Foswiki::Plugins::SESSION = $this->{session};

    # Test with undefined topic - web permissions tested
    my $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, undef, $this->{test_web} );
    $this->assert( $access );

    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, undef, $this->{test_web} );
    $this->assert( !$access );

    # Test with null topic - default topic (WebHome) permissions tested
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, '', $this->{test_web} );
    $this->assert( $access );

    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, '', $this->{test_web} );
    $this->assert( !$access );

    # Test with valid topic - web permissions overridden by topic
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, 'WeeblesWobble', $this->{test_web} );
    $this->assert( $access );

    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, 'WeeblesWobble', $this->{test_web} );
    $this->assert( $access );

    # Test with invalid topic - web permissions applied (Item2380)
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, 'WibblesWobble', $this->{test_web} );
    $this->assert( $access );

    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, 'WibblesWobble', $this->{test_web} );
    $this->assert( !$access );

    # Test for missing web name, default to Users web (Main)
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, 'WibblesWobble', undef );
    $this->assert( $access );

    # Test for null web name, default to Users web (Main)
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, 'WibblesWobble', '' );
    $this->assert( $access );

    # Test for simple tainted topic name
    my $taintedTopic = 'WeeblesWobble';
    $taintedTopic = Assert::TAINT($taintedTopic);
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, $taintedTopic, $this->{test_web} );
    $this->assert( $access );

    # Test with illegal, tainted topic name.
    #  - Untainting the name detects the illegal characters.
    $taintedTopic = 'Weebles!@#$%^&**(())__+Wobble';
    $taintedTopic = Assert::TAINT($taintedTopic);
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, $taintedTopic, $this->{test_web} );
    $this->assert( !$access );
}


sub test_checkAccessPermission {
    my $this  = shift;
    my $topic = "NoWayJose";

    Foswiki::Func::saveTopicText(
        $this->{test_web}, $topic, <<END,
\t* Set DENYTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}
END
    );
    eval { $this->{session}->finish() };
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    my $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, $topic, $this->{test_web} );
    $this->assert( !$access );
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', $topic, $this->{test_web} );
    $this->assert( !$access );
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        0, $topic, $this->{test_web} );
    $this->assert( !$access );
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        "Please me, let me go",
        $topic, $this->{test_web}
    );
    # Supplied text should override text from topic
    $this->assert($access);

    # make sure meta overrides text, as documented - Item2953
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => 'ALLOWTOPICVIEW',
            title => 'ALLOWTOPICVIEW',
            type  => 'Set',
            value => $Foswiki::cfg{DefaultUserWikiName}
        }
    );
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        "   * Set ALLOWTOPICVIEW = NotASoul\n",
        $topic, $this->{test_web}, $meta
    );
    $this->assert( !$access );
    $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => 'DENYTOPICVIEW',
            title => 'DENYTOPICVIEW',
            type  => 'Set',
            value => $Foswiki::cfg{DefaultUserWikiName}
        }
    );
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        "   * Set ALLOWTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}\n",
        $topic,
        $this->{test_web},
        $meta
    );
    $this->assert( !$access );
    
    #I'm not clear from the docco so...
    #what happens if we check the perms on a topic that doesn't exist.
    #first up on a web we can write to
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', $this->{test_web} );
    $this->assert( $access );
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', $this->{test_web} );
    $this->assert( $access );
    $access =
      Foswiki::Func::checkAccessPermission( 'DONTTHINGTHEREISSUCHAPERM',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'System' );
    $this->assert( $access );
    #next System, which we shouldn't be able to write to
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'System' );
    $this->assert( $access );
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'System' );
    $this->assert( !$access );
    $access =
      Foswiki::Func::checkAccessPermission( 'DONTTHINGTHEREISSUCHAPERM',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'System' );
    $this->assert( $access );

    # next _default, which Sven Dowideit thinks we shouldn't be able to view,
    # but CDot can't see any good reason for that as restriction, given that
    # the permissions in that web allow it. Test checks CDot's view.
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', '_default' );
    $this->assert( $access );

    # However CHANGE access is denied for non-admins
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', '_default' );
    $this->assert( !$access );

    # The default behaviour for access controls is to permit access unless
    # there is some constraint that says otherwise. If we test a non-
    # existant permission, we should be given access.
    $access =
      Foswiki::Func::checkAccessPermission( 'DONTTHINKTHEREISSUCHAPERM',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', '_default' );
    $this->assert( $access );

    #next NonExistantWeb, which doesn't exist
    # If a web doesn't exist, then there is no WebPreferences and
    # access controls come from the parent web, or the site access
    # controls. Just because a web doesn't exist doesn't mean an access
    # control check should fail.
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'NonExistantWeb' );
    $this->assert( $access );

    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'NonExistantWeb' );
    $this->assert( $access );

    $access =
      Foswiki::Func::checkAccessPermission( 'DONTTHINGTHEREISSUCHAPERM',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'NonExistantWeb' );
    $this->assert( $access );
}

sub test_checkAccessPermission_login_name {
    my $this  = shift;
    my $topic = "NoWayJose";

    Foswiki::Func::saveTopicText(
        $this->{test_web}, $topic, <<END,
\t* Set DENYTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}
END
    );
    eval { $this->{session}->finish() };
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    my $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserLogin},
        undef, $topic, $this->{test_web} );
    $this->assert( !$access );
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserLogin},
        '', $topic, $this->{test_web} );
    $this->assert( !$access );
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserLogin},
        0, $topic, $this->{test_web} );
    $this->assert( !$access );
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserLogin},
        "Please me, let me go",
        $topic, $this->{test_web}
    );
    $this->assert($access);

    # make sure meta overrides text, as documented - Item2953
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => 'ALLOWTOPICVIEW',
            title => 'ALLOWTOPICVIEW',
            type  => 'Set',
            value => $Foswiki::cfg{DefaultUserWikiName}
        }
    );
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserLogin},
        "   * Set ALLOWTOPICVIEW = NotASoul\n",
        $topic, $this->{test_web}, $meta
    );
    $this->assert( !$access );
    $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => 'DENYTOPICVIEW',
            title => 'DENYTOPICVIEW',
            type  => 'Set',
            value => $Foswiki::cfg{DefaultUserWikiName}
        }
    );
    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserLogin},
        "   * Set ALLOWTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}\n",
        $topic,
        $this->{test_web},
        $meta
    );
    $this->assert( !$access );
}

sub test_getExternalResource {
    my $this = shift;

    # need a known, simple, robust URL to get
    my $response = Foswiki::Func::getExternalResource('http://foswiki.org/System/WhatIsWikiWiki');
    $this->assert_equals( 200, $response->code() );
    $this->assert_matches(
        qr/A set of pages of information that are open and free for anyone to edit as they wish. They are stored in a server and managed using some software. The system creates cross-reference hyperlinks between pages automatically./s,
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
    $this->assert_equals( 0, Foswiki::Func::isTrue() );
    $this->assert_equals( 1, Foswiki::Func::isTrue( undef, 1 ) );
    $this->assert_equals( 0, Foswiki::Func::isTrue( undef, undef ) );

    #TRUE
    $this->assert_equals( 1, Foswiki::Func::isTrue( 'true', 'bad' ) );
    $this->assert_equals( 1, Foswiki::Func::isTrue( 'True', 'bad' ) );
    $this->assert_equals( 1, Foswiki::Func::isTrue( 'TRUE', 'bad' ) );
    $this->assert_equals( 1, Foswiki::Func::isTrue( 'bad',  'bad' ) );
    $this->assert_equals( 1, Foswiki::Func::isTrue( 'Bad',  'bad' ) );
    $this->assert_equals( 1, Foswiki::Func::isTrue('BAD') );

    $this->assert_equals( 1, Foswiki::Func::isTrue(1) );
    $this->assert_equals( 1, Foswiki::Func::isTrue(-1) );
    $this->assert_equals( 1, Foswiki::Func::isTrue(12) );
    $this->assert_equals( 1,
        Foswiki::Func::isTrue( { a => 'me', b => 'ed' } ) );

    #FALSE
    $this->assert_equals( 0, Foswiki::Func::isTrue( 'off',   'bad' ) );
    $this->assert_equals( 0, Foswiki::Func::isTrue( 'no',    'bad' ) );
    $this->assert_equals( 0, Foswiki::Func::isTrue( 'false', 'bad' ) );

    $this->assert_equals( 0, Foswiki::Func::isTrue( 'Off',   'bad' ) );
    $this->assert_equals( 0, Foswiki::Func::isTrue( 'No',    'bad' ) );
    $this->assert_equals( 0, Foswiki::Func::isTrue( 'False', 'bad' ) );

    $this->assert_equals( 0, Foswiki::Func::isTrue( 'OFF',   'bad' ) );
    $this->assert_equals( 0, Foswiki::Func::isTrue( 'NO',    'bad' ) );
    $this->assert_equals( 0, Foswiki::Func::isTrue( 'FALSE', 'bad' ) );

    $this->assert_equals( 0, Foswiki::Func::isTrue(0) );
    $this->assert_equals( 0, Foswiki::Func::isTrue('0') );
    $this->assert_equals( 0, Foswiki::Func::isTrue(' 0') );

    #SPACES
    $this->assert_equals( 0, Foswiki::Func::isTrue( '  off',     'bad' ) );
    $this->assert_equals( 0, Foswiki::Func::isTrue( 'no  ',      'bad' ) );
    $this->assert_equals( 0, Foswiki::Func::isTrue( '  false  ', 'bad' ) );

    $this->assert_equals( 0, Foswiki::Func::isTrue(0) );

}

sub test_decodeFormatTokens {
    my $this = shift;

    my $input = <<'TEST';
$n embed$nembed$n()embed
$nop embed$nopembed$nop()embed
$quot embed$quotembed$quot()embed
$percnt embed$percntembed$percnt()embed
$percent embed$percentembed$percent()embed
$dollar embed$dollarembed$dollar()embed
$comma embed$commaembed$comma()embed
$lt embed$ltembed$lt()embed
$gt embed$gtembed$gt()embed
$n$n!$n()gnnnnh
$amp embed$ampembed$amp()embed
$dollarlt
TEST
    my $expected = <<'TEST';

 embed$nembed
embed
 embedembedembed
" embed"embed"embed
% embed%embed%embed
% embed%embed%embed
$ embed$embed$embed
, embed,embed,embed
< embed<embed<embed
> embed>embed>embed


!
gnnnnh
& embed&embed&embed
$lt
TEST
    my $output = Foswiki::Func::decodeFormatTokens($input);
    $this->assert_str_equals( $expected, $output );
}

sub test_eachChangeSince {
    my $this = shift;
    $Foswiki::cfg{Store}{RememberChangesFor} = 5;    # very bad memory

    require Foswiki::Users::BaseUserMapping;
    my $user1 = $Foswiki::cfg{DefaultUserLogin};
    my $user2  = $this->{session}->{users}->findUserByWikiName("ScumBag")->[0];

    sleep(1); # to move into a new time step
    my $start = time();

    $this->{session}->finish();
    $this->{session} = new Foswiki($user1);
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "ClutterBuck",
        "One" );
    $meta->save();

    $this->{session}->finish();
    $this->{session} = new Foswiki($user2);
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "PiggleNut",
        "One" );
    $meta->save();

    # Wait a second
    sleep(1);
    my $mid = time();

    $this->{session}->finish();
    $this->{session} = new Foswiki($user2);
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "ClutterBuck",
        "One" );
    $meta->save();

    $this->{session}->finish();
    $this->{session} = new Foswiki($user1);
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "PiggleNut",
        "Two" );
    $meta->save();

    my $change;
    my $it = Foswiki::Func::eachChangeSince( $this->{test_web}, $start );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 2,                     $change->{revision} );
    $this->assert_equals(
        $Foswiki::cfg{DefaultUserWikiName}, $change->{user} );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 2,         $change->{revision} );
    $this->assert_equals( 'ScumBag', $change->{user} );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 1,         $change->{revision} );
    $this->assert_equals( 'ScumBag', $change->{user} );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 1,                     $change->{revision} );
    $this->assert_equals(
        $Foswiki::cfg{DefaultUserWikiName}, $change->{user} );
    $this->assert( !$it->hasNext() );

    $it = Foswiki::Func::eachChangeSince( $this->{test_web}, $mid );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 2,                     $change->{revision} );
    $this->assert_equals(
        $Foswiki::cfg{DefaultUserWikiName}, $change->{user} );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 2,         $change->{revision} );
    $this->assert_equals( 'ScumBag', $change->{user} );

    $this->assert( !$it->hasNext() );
}

# Check consistency between getListofWebs and webExists
sub test_4308 {
    my $this = shift;
    my @list = Foswiki::Func::getListOfWebs('user');
    foreach my $web (@list) {
        $this->assert( Foswiki::Func::webExists($web), $web );
    }
    @list = Foswiki::Func::getListOfWebs('user public');
    foreach my $web (@list) {
        $this->assert( Foswiki::Func::webExists($web), $web );
    }
    @list = Foswiki::Func::getListOfWebs('template');
    foreach my $web (@list) {
        $this->assert( Foswiki::Func::webExists($web), $web );
    }
    @list = Foswiki::Func::getListOfWebs('public template');
    foreach my $web (@list) {
        $this->assert( Foswiki::Func::webExists($web), $web );
    }
}

sub test_4411 {
    my $this = shift;
    $this->assert( Foswiki::Func::isGuest(), $this->{session}->{user} );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );
    $this->assert( !Foswiki::Func::isGuest(), $this->{session}->{user} );
}

sub test_setPreferences {
    my $this = shift;
    $this->assert( !Foswiki::Func::getPreferencesValue("PSIBG") );
    Foswiki::Func::setPreferencesValue( "PSIBG", "KJHD" );
    $this->assert_str_equals( "KJHD",
        Foswiki::Func::getPreferencesValue("PSIBG") );
    my $q = Foswiki::Func::getRequestObject();

    ####
    Foswiki::Func::saveTopicText( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<HERE);
   * Set PSIBG = naff
   * Set FINALPREFERENCES = PSIBG
HERE
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{GuestUserLogin}, $q );
    $this->assert_str_equals( "naff",
        Foswiki::Func::getPreferencesValue("PSIBG") );
    Foswiki::Func::setPreferencesValue( "PSIBG", "KJHD" );
    $this->assert_str_equals( "naff",
        Foswiki::Func::getPreferencesValue("PSIBG") );
    ###
    Foswiki::Func::saveTopicText( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<HERE);
   * Set PSIBG = naff
HERE
    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{GuestUserLogin}, $q );
    $this->assert_str_equals( "naff",
        Foswiki::Func::getPreferencesValue("PSIBG") );
    Foswiki::Func::setPreferencesValue( "PSIBG", "KJHD" );
    $this->assert_str_equals( "KJHD",
        Foswiki::Func::getPreferencesValue("PSIBG") );

}

sub test_getPluginPreferences {
    my $this = shift;
    my $pvar = "PSIBG";
    my $var  = uc(__PACKAGE__) . "_$pvar";
    $this->assert_null( Foswiki::Func::getPreferencesValue($var) );
    $this->assert_null( Foswiki::Func::getPreferencesValue($pvar) );
    Foswiki::Func::setPreferencesValue( $var, "on" );
    $this->assert_str_equals( "on",
        Foswiki::Func::getPluginPreferencesValue($pvar) );
    $this->assert( Foswiki::Func::getPluginPreferencesFlag($pvar) );
    Foswiki::Func::setPreferencesValue( $var, "off" );
    $this->assert_str_equals( "off",
        Foswiki::Func::getPluginPreferencesValue($pvar) );
    $this->assert( !Foswiki::Func::getPluginPreferencesFlag($pvar) );
}

sub test_getRevisionAtTime {
    my $this = shift;
    my $t1   = Foswiki::Time::parseTime("21 Jun 2001");
    Foswiki::Func::saveTopic(
        $this->{test_web},
        "ShutThatDoor",
        undef, "Glum",
        {
            comment          => 'Initial revision',
            forcenewrevision => 1,
            forcedate        => $t1
        }
    );
    my $t2 = Foswiki::Time::parseTime("21 Jun 2003");
    Foswiki::Func::saveTopic(
        $this->{test_web},
        "ShutThatDoor",
        undef, "Happy",
        {
            comment          => 'New revision',
            forcenewrevision => 1,
            forcedate        => $t2
        }
    );
    $this->assert_equals(
        0,
        Foswiki::Func::getRevisionAtTime(
            $this->{test_web}, "ShutThatDoor", $t1 - 60
        )
    );
    $this->assert_equals(
        1,
        Foswiki::Func::getRevisionAtTime(
            $this->{test_web}, "ShutThatDoor", $t1 + 60
        )
    );
    $this->assert_equals(
        1,
        Foswiki::Func::getRevisionAtTime(
            $this->{test_web}, "ShutThatDoor", $t2 - 60
        )
    );
    $this->assert_equals(
        2,
        Foswiki::Func::getRevisionAtTime(
            $this->{test_web}, "ShutThatDoor", $t2 + 60
        )
    );
}

sub test_getAttachmentList {
    my $this = shift;

    my $f = "$Foswiki::cfg{TempfileDir}/testfile.gif";
    $this->assert(open(F, ">", $f));
    print F "Naff\n";
    close(F);
    my $meta =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, $this->{test_topic}, "One" );
    $meta->attach(
        name    => "testfile.gif",
        file    => "$Foswiki::cfg{TempfileDir}/testfile.gif",
        comment => "a comment"
    );
    $meta->save();
    unlink $f;
    my @list = Foswiki::Func::getAttachmentList(
        $this->{test_web}, $this->{test_topic});
    my $list = join(' ', @list);
    $this->assert_str_equals("testfile.gif", $list);
}

sub test_searchInWebContent {
    my $this = shift;
}

sub test_pushPopContext {
    my $this = shift;
    my $topic1 = "DanTien";
    my $topic2 = "SandWich";

    Foswiki::Func::saveTopicText(
        $this->{test_web}, $topic1, <<SETS );
   * Set ICE = COLD
SETS

    # Force re-read of prefs
    $Foswiki::Plugins::SESSION = $this->{session} =
      new Foswiki( undef,
        new Unit::Request( { topic => "$this->{test_web}.$topic1" } ) );

    Foswiki::Func::saveTopicText(
        $this->{test_web}, $topic2, <<SETS );
   * Set ICE = SLIPPERY
SETS

    $this->assert_equals($this->{test_web},
                         $this->{session}->{webName});
    $this->assert_equals($topic1,
                         $this->{session}->{topicName});
    $this->assert_equals($this->{test_web},
                         Foswiki::Func::getPreferencesValue('BASEWEB'));
    $this->assert_equals($topic1,
                         Foswiki::Func::getPreferencesValue('BASETOPIC'));
    $this->assert_equals($this->{test_web},
                         Foswiki::Func::getPreferencesValue('INCLUDINGWEB'));
    $this->assert_equals($topic1,
                         Foswiki::Func::getPreferencesValue('INCLUDINGTOPIC'));
    $this->assert_equals("COLD",
                         Foswiki::Func::getPreferencesValue('ICE'));

    Foswiki::Func::pushTopicContext($this->{test_web}, $topic2);

    $this->assert_equals($this->{test_web},
                         $this->{session}->{webName});
    $this->assert_equals($topic2,
                         $this->{session}->{topicName});
    $this->assert_equals(
        $this->{test_web}, Foswiki::Func::getPreferencesValue('BASEWEB'));
    $this->assert_equals(
        $topic2, Foswiki::Func::getPreferencesValue('BASETOPIC'));
    $this->assert_equals(
        $this->{test_web}, Foswiki::Func::getPreferencesValue('INCLUDINGWEB'));
    $this->assert_equals(
        $topic2, Foswiki::Func::getPreferencesValue('INCLUDINGTOPIC'));
    $this->assert_equals("SLIPPERY",
                         Foswiki::Func::getPreferencesValue('ICE'));

    Foswiki::Func::popTopicContext();

    $this->assert_equals($this->{test_web},
                         $this->{session}->{webName});
    $this->assert_equals($topic1,
                         $this->{session}->{topicName});
    $this->assert_equals($this->{test_web},
                         Foswiki::Func::getPreferencesValue('BASEWEB'));
    $this->assert_equals($topic1,
                         Foswiki::Func::getPreferencesValue('BASETOPIC'));
    $this->assert_equals($this->{test_web},
                         Foswiki::Func::getPreferencesValue('INCLUDINGWEB'));
    $this->assert_equals($topic1,
                         Foswiki::Func::getPreferencesValue('INCLUDINGTOPIC'));
    $this->assert_equals("COLD",
                         Foswiki::Func::getPreferencesValue('ICE'));
}

sub test_writeEvent {
    my $this = shift;
    my $now = time();
    Foswiki::Func::writeEvent("cereal", "milk");
    select(undef, undef, undef, 0.25) while (time() == $now);
    $now = time();
    Foswiki::Func::writeEvent("sausage", "eggs");
    Foswiki::Func::writeEvent("bacon");
    Foswiki::Func::writeEvent();
    Foswiki::Func::writeEvent("toast", "jam");
    my $it = Foswiki::Func::eachEventSince($now);
    $this->assert($it->hasNext());
    my $e = $it->next();
    $this->assert_equals($now, $e->[0]);
    $this->assert_equals('sausage', $e->[2]);
    $this->assert_equals('eggs', $e->[4]);
    $e = $it->next() while ($it->hasNext() && $e->[2] ne 'bacon');
    $e = $it->next() while ($it->hasNext() && $e->[2] ne '');
    $e = $it->next() while ($it->hasNext() && $e->[2] ne 'toast');
    $this->assert_equals('jam', $e->[4]);
}

sub test_loadTemplate {
    my $this = shift;
    my $view = Foswiki::Func::loadTemplate('view');
    $this->assert(length($view));
    my $print = Foswiki::Func::loadTemplate('view', 'print');
    $this->assert(length($print));
    $this->assert($print ne $view);
    $this->assert_str_equals('', Foswiki::Func::loadTemplate('crud'));
}

sub test_readTemplate {
    my $this = shift;
    my $view = Foswiki::Func::readTemplate('view');
    $this->assert(length($view));
    my $print = Foswiki::Func::readTemplate('view', 'print');
    $this->assert(length($print));
    $this->assert($print ne $view);
    $this->assert_str_equals('', Foswiki::Func::readTemplate('crud'));
}
1;
