# See bottom of file for license and copyright information
#
# Unit tests for TWiki::Func
#

package TWikiFuncTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use TWiki();
use TWiki::Func();
use Foswiki::Func();

sub new {
    my ( $class, @args ) = @_;

    my $self = $class->SUPER::new( "Func", @args );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{tmpdatafile} = $TWiki::cfg{TempfileDir} . '/tmpity-tmp.gif';
    $this->{test_web2}   = $this->{test_web} . 'Extra';
    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{test_web2} );
    $webObject->populateNewWeb();

    return;
}

sub tear_down {
    my $this = shift;
    unlink $this->{tmpdatafile};
    $this->removeWebFixture( $this->{session}, $this->{test_web2} );
    $this->SUPER::tear_down();

    return;
}

sub test_web {
    my $this = shift;

    $this->{session}->finish();
    $this->{session} = Foswiki->new( $Foswiki::cfg{AdminUserLogin} );

    TWiki::Func::createWeb( $this->{test_web} . "/Blah" );
    $this->assert( TWiki::Func::webExists( $this->{test_web} . "/Blah" ) );

    TWiki::Func::moveWeb( $this->{test_web} . "/Blah",
        $this->{test_web} . "/Blah2" );
    $this->assert( !TWiki::Func::webExists( $this->{test_web} . "/Blah" ) );
    $this->assert( TWiki::Func::webExists( $this->{test_web} . "/Blah2" ) );

    return;
}

sub test_TWiki_web {
    my $this = shift;

    $this->{session}->finish();
    $this->{session} = Foswiki->new( $Foswiki::cfg{AdminUserLogin} );

    $this->assert( Foswiki::Func::webExists('TWiki') );
    $this->assert( TWiki::Func::webExists('TWiki') );

    $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} = 0;

    $this->assert( !Foswiki::Func::webExists('TWiki') );
    $this->assert( !TWiki::Func::webExists('TWiki') );

    $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} = 1;

    return;
}

sub test_getViewUrl {
    my $this = shift;

    my $ss = 'view' . $TWiki::cfg{ScriptSuffix};

    # relative to specified web
    my $result = TWiki::Func::getViewUrl( $this->{users_web}, "WebHome" );

    # Item11121: ShortURLs wil break this test
    if (    exists $Foswiki::cfg{ScriptUrlPaths}{view}
        and $Foswiki::cfg{ScriptUrlPaths}{view}
        and not $Foswiki::cfg{ScriptUrlPaths}{view} =~ /$ss$/ )
    {
        $this->expect_failure();
    }
    $this->assert_matches( qr!/$ss/$this->{users_web}/WebHome!, $result );

    # relative to web in path_info
    $result = TWiki::Func::getViewUrl( "", "WebHome" );
    $this->assert_matches( qr!/$ss/$this->{test_web}/WebHome!, $result );

    $TWiki::Plugins::SESSION =
      TWiki->new( undef,
        Unit::Request->new( { topic => "Sausages.AndMash" } ) );

    $result = TWiki::Func::getViewUrl( "Sausages", "AndMash" );
    $this->assert_matches( qr!/$ss/Sausages/AndMash!, $result );

    $result = TWiki::Func::getViewUrl( "", "AndMash" );
    $this->assert_matches( qr!/$ss/Sausages/AndMash!, $result );
    $TWiki::Plugins::SESSION->finish();

    return;
}

sub test_getScriptUrl {
    my $this = shift;

    my $ss = 'wibble' . $TWiki::cfg{ScriptSuffix};
    my $result =
      TWiki::Func::getScriptUrl( $this->{users_web}, "WebHome", 'wibble' );
    $this->assert_matches( qr!/$ss/$this->{users_web}/WebHome!, $result );

    $result = TWiki::Func::getScriptUrl( "", "WebHome", 'wibble' );
    $this->assert_matches( qr!/$ss/$this->{users_web}/WebHome!, $result );

    my $q = Unit::Request->new( {} );
    $q->path_info('/Sausages/AndMash');
    $TWiki::Plugins::SESSION = TWiki->new( undef, $q );

    $result = TWiki::Func::getScriptUrl( "Sausages", "AndMash", 'wibble' );
    $this->assert_matches( qr!/$ss/Sausages/AndMash!, $result );

    $result = TWiki::Func::getScriptUrl( "", "AndMash", 'wibble' );
    $this->assert_matches( qr!/$ss/$this->{users_web}/AndMash!, $result );
    $TWiki::Plugins::SESSION->finish();

    return;
}

sub test_getOopsUrl {
    my $this = shift;
    my $url =
      TWiki::Func::getOopsUrl( 'Incy', 'Wincy', 'Spider', 'Hurble', 'Burble',
        'Wurble', 'Murble' );
    $this->assert_str_equals(
        TWiki::Func::getScriptUrl( 'Incy', 'Wincy', 'oops' )
          . "?template=Spider;param1=Hurble;param2=Burble;param3=Wurble;param4=Murble",
        $url
    );
    $url = TWiki::Func::getOopsUrl(
        'Incy',   'Wincy',  'oopspider', 'Hurble',
        'Burble', 'Wurble', 'Murble'
    );
    $this->assert_str_equals(
        TWiki::Func::getScriptUrl( 'Incy', 'Wincy', 'oops' )
          . "?template=oopspider;param1=Hurble;param2=Burble;param3=Wurble;param4=Murble",
        $url
    );

    return;
}

# Check lease handling
sub test_leases {
    my $this = shift;

    my $testtopic = $TWiki::cfg{HomeTopicName};

    # Check that there is no lease on the home topic
    my ( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock( $this->{test_web}, $testtopic );
    $this->assert( !$oops, $oops );
    $this->assert( !$login );
    $this->assert_equals( 0, $time );

    # Take out a lease on behalf of the current user
    TWiki::Func::setTopicEditLock( $this->{test_web}, $testtopic, 1 );

    # Work out who leased it. The login name is used in the lease check.
    my $locker = TWiki::Func::wikiToUserName( TWiki::Func::getWikiName() );
    $this->assert($locker);

    # check the lease
    ( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock( $this->{test_web}, $testtopic );
    $this->assert_equals( $locker, $login );
    $this->assert( $time > 0 );
    $this->assert_matches( qr/leaseconflict/, $oops );
    $this->assert_matches( qr/active/,        $oops );

    # try and clear the lease. This should always succeed.
    TWiki::Func::setTopicEditLock( $this->{test_web}, $testtopic, 0 );

    ( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock( $this->{test_web}, $testtopic );
    $this->assert( !$oops, $oops );
    $this->assert( !$login );
    $this->assert_equals( 0, $time );

    return;
}

sub test_attachments {
    my $this = shift;

    my $data  = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $attnm = 'blahblahblah.gif';
    my $name1 = 'blahblahblah.gif';
    my $name2 = 'bleagh.sniff';
    my $topic = "BlahBlahBlah";

    my $stream;
    $this->assert( open( $stream, '>', $this->{tmpdatafile} ) );
    binmode($stream);
    print $stream $data;
    $this->assert( close($stream) );

    $this->assert( open( $stream, '<', $this->{tmpdatafile} ) );
    binmode($stream);

    TWiki::Func::saveTopicText( $this->{test_web}, $topic, '' );

    my $e = TWiki::Func::saveAttachment(
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
    $this->assert( close($stream) );
    $this->assert( !$e, $e );

    my ( $meta, $text ) = TWiki::Func::readTopic( $this->{test_web}, $topic );
    my @attachments = $meta->find('FILEATTACHMENT');
    $this->assert_str_equals( $name1, $attachments[0]->{name} );

    $e = TWiki::Func::saveAttachment(
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

    ( $meta, $text ) = TWiki::Func::readTopic( $this->{test_web}, $topic );
    @attachments = $meta->find('FILEATTACHMENT');
    $this->assert_str_equals( $name1, $attachments[0]->{name} );
    $this->assert_str_equals( $name2, $attachments[1]->{name} );

    my $x = TWiki::Func::readAttachment( $this->{test_web}, $topic, $name1 );
    $this->assert_str_equals( $data, $x );
    $x = TWiki::Func::readAttachment( $this->{test_web}, $topic, $name2 );
    $this->assert_str_equals( $data, $x );

    return;
}

sub test_getrevinfo {
    my $this  = shift;
    my $topic = "RevInfo";

    #    my $login = TWiki::Func::wikiToUserName(TWiki::Func::getWikiName());
    my $wikiname = TWiki::Func::getWikiName();
    TWiki::Func::saveTopicText( $this->{test_web}, $topic, 'blah' );

    my ( $date, $user, $rev, $comment ) =
      TWiki::Func::getRevisionInfo( $this->{test_web}, $topic );
    $this->assert_equals( 1, $rev );
    $this->assert_str_equals( $wikiname, $user )
      ;    # the Func::getRevisionInfo quite clearly says wikiname

    return;
}

sub test_moveTopic {
    my $this = shift;

    TWiki::Func::saveTopicText( $this->{test_web}, "SourceTopic", "Wibble" );
    $this->assert(
        TWiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        !TWiki::Func::topicExists( $this->{test_web}, "TargetTopic" ) );
    $this->assert(
        !TWiki::Func::topicExists( $this->{test_web2}, "SourceTopic" ) );
    $this->assert(
        !TWiki::Func::topicExists( $this->{test_web2}, "TargetTopic" ) );

    TWiki::Func::moveTopic( $this->{test_web}, "SourceTopic", $this->{test_web},
        "TargetTopic" );
    $this->assert(
        !TWiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        TWiki::Func::topicExists( $this->{test_web}, "TargetTopic" ) );

    TWiki::Func::moveTopic( $this->{test_web}, "TargetTopic", undef,
        "SourceTopic" );
    $this->assert(
        TWiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        !TWiki::Func::topicExists( $this->{test_web}, "TargetTopic" ) );

    TWiki::Func::moveTopic( $this->{test_web}, "SourceTopic",
        $this->{test_web2}, "SourceTopic" );
    $this->assert(
        !TWiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        TWiki::Func::topicExists( $this->{test_web2}, "SourceTopic" ) );

    TWiki::Func::moveTopic( $this->{test_web2}, "SourceTopic",
        $this->{test_web}, undef );
    $this->assert(
        TWiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        !TWiki::Func::topicExists( $this->{test_web2}, "SourceTopic" ) );

    TWiki::Func::moveTopic( $this->{test_web}, "SourceTopic",
        $this->{test_web2}, "TargetTopic" );
    $this->assert(
        !TWiki::Func::topicExists( $this->{test_web}, "SourceTopic" ) );
    $this->assert(
        TWiki::Func::topicExists( $this->{test_web2}, "TargetTopic" ) );

    return;
}

sub test_moveAttachment {
    my $this = shift;

    TWiki::Func::saveTopicText( $this->{test_web}, "SourceTopic", "Wibble" );
    my $stream;
    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    $this->assert( open( $stream, '>', $this->{tmpdatafile} ) );
    binmode($stream);
    print $stream $data;
    $this->assert( close($stream) );
    TWiki::Func::saveAttachment(
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
        TWiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name1"
        )
    );

    TWiki::Func::saveTopicText( $this->{test_web},  "TargetTopic", "Wibble" );
    TWiki::Func::saveTopicText( $this->{test_web2}, "TargetTopic", "Wibble" );

    TWiki::Func::moveAttachment( $this->{test_web}, "SourceTopic", "Name1",
        $this->{test_web}, "SourceTopic", "Name2" );
    $this->assert(
        !TWiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name1"
        )
    );
    $this->assert(
        TWiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name2"
        )
    );

    TWiki::Func::moveAttachment( $this->{test_web}, "SourceTopic", "Name2",
        $this->{test_web}, "TargetTopic", undef );
    $this->assert(
        !TWiki::Func::attachmentExists(
            $this->{test_web}, "SourceTopic", "Name2"
        )
    );
    $this->assert(
        TWiki::Func::attachmentExists(
            $this->{test_web}, "TargetTopic", "Name2"
        )
    );

    TWiki::Func::moveAttachment( $this->{test_web}, "TargetTopic", "Name2",
        $this->{test_web2}, "TargetTopic", "Name1" );
    $this->assert(
        !TWiki::Func::attachmentExists(
            $this->{test_web}, "TargetTopic", "Name2"
        )
    );
    $this->assert(
        TWiki::Func::attachmentExists(
            $this->{test_web2}, "TargetTopic", "Name1"
        )
    );

    return;
}

sub test_workarea {
    my $this = shift;

    my $dir = TWiki::Func::getWorkArea('TestPlugin');
    $this->assert( -d $dir );

    # SMELL: check the permissions

    unlink $dir;

    return;
}

sub test_extractParameters {
    my $this = shift;

    my %attrs = TWiki::Func::extractParameters('"a" b="c"');
    my %expect = ( _DEFAULT => "a", b => "c" );
    foreach my $a ( keys %attrs ) {
        $this->assert( $expect{$a}, $a );
        $this->assert_str_equals( $expect{$a}, $attrs{$a}, $a );
        delete $expect{$a};
    }

    return;
}

sub test_w2em {
    my $this = shift;

    my $ems = join( ',',
        $this->{session}->{users}->getEmails( $this->{session}->{user} ) );
    my $user = TWiki::Func::getWikiName();
    $this->assert_str_equals( $ems, TWiki::Func::wikiToEmail($user) );

    return;
}

sub test_normalizeWebTopicName {
    my $this = shift;
    $TWiki::cfg{EnableHierarchicalWebs} = 1;
    my ( $w, $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( 'Web', 'Topic' );
    $this->assert_str_equals( 'Web',   $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '', 'Topic' );
    $this->assert_str_equals( $TWiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'Topic',                   $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '', '' );
    $this->assert_str_equals( $TWiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'WebHome',                 $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '', 'Web/Topic' );
    $this->assert_str_equals( 'Web',   $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '', 'Web.Topic' );
    $this->assert_str_equals( 'Web',   $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( 'Web1', 'Web2.Topic' );
    $this->assert_str_equals( 'Web2',  $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '%USERSWEB%', 'Topic' );
    $this->assert_str_equals( $TWiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'Topic',                   $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '%USERSWEB%', 'Topic' );
    $this->assert_str_equals( $TWiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'Topic',                   $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( 'Web', '' );
    $this->assert_str_equals( 'Web',                      $w );
    $this->assert_str_equals( $TWiki::cfg{HomeTopicName}, $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '%SYSTEMWEB%', 'Topic' );
    $this->assert_str_equals( $TWiki::cfg{SystemWebName}, $w );
    $this->assert_str_equals( 'Topic',                    $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '%SYSTEMWEB%', 'Topic' );
    $this->assert_str_equals( $TWiki::cfg{SystemWebName}, $w );
    $this->assert_str_equals( 'Topic',                    $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '%DOCWEB%', 'Topic' );
    $this->assert_str_equals( $TWiki::cfg{SystemWebName}, $w );
    $this->assert_str_equals( 'Topic',                    $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '', '%USERSWEB%.Topic' );
    $this->assert_str_equals( $TWiki::cfg{UsersWebName}, $w );
    $this->assert_str_equals( 'Topic',                   $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '', '%SYSTEMWEB%.Topic' );
    $this->assert_str_equals( $TWiki::cfg{SystemWebName}, $w );
    $this->assert_str_equals( 'Topic',                    $t );
    ( $w, $t ) =
      TWiki::Func::normalizeWebTopicName( '%USERSWEB%', 'Web2.Topic' );
    $this->assert_str_equals( 'Web2',  $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) =
      TWiki::Func::normalizeWebTopicName( '%SYSTEMWEB%', 'Web2.Topic' );
    $this->assert_str_equals( 'Web2',  $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( 'Wibble.Web', 'Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w );
    $this->assert_str_equals( 'Topic',      $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '', 'Wibble.Web/Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w );
    $this->assert_str_equals( 'Topic',      $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '', 'Wibble/Web/Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w );
    $this->assert_str_equals( 'Topic',      $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '', 'Wibble.Web.Topic' );
    $this->assert_str_equals( 'Wibble/Web', $w );
    $this->assert_str_equals( 'Topic',      $t );
    ( $w, $t ) =
      TWiki::Func::normalizeWebTopicName( 'Wibble.Web1', 'Wibble.Web2.Topic' );
    $this->assert_str_equals( 'Wibble/Web2', $w );
    $this->assert_str_equals( 'Topic',       $t );
    ( $w, $t ) =
      TWiki::Func::normalizeWebTopicName( '%USERSWEB%.Wibble', 'Topic' );
    $this->assert_str_equals( $TWiki::cfg{UsersWebName} . '/Wibble', $w );
    $this->assert_str_equals( 'Topic',                               $t );
    ( $w, $t ) =
      TWiki::Func::normalizeWebTopicName( '%SYSTEMWEB%.Wibble', 'Topic' );
    $this->assert_str_equals( $TWiki::cfg{SystemWebName} . '/Wibble', $w );
    $this->assert_str_equals( 'Topic',                                $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '%USERSWEB%.Wibble',
        'Wibble.Web2.Topic' );
    $this->assert_str_equals( 'Wibble/Web2', $w );
    $this->assert_str_equals( 'Topic',       $t );
    ( $w, $t ) = TWiki::Func::normalizeWebTopicName( '%SYSTEMWEB%.Wibble',
        'Wibble.Web2.Topic' );
    $this->assert_str_equals( 'Wibble/Web2', $w );
    $this->assert_str_equals( 'Topic',       $t );

    return;
}

sub test_checkAccessPermission {
    my $this  = shift;
    my $topic = "NoWayJose";

    TWiki::Func::saveTopicText(
        $this->{test_web}, $topic, <<"END",
\t* Set DENYTOPICVIEW = $TWiki::cfg{DefaultUserWikiName}
END
    );
    eval { $this->{session}->finish() };
    $this->{session} = TWiki->new();
    $TWiki::Plugins::SESSION = $this->{session};
    my $access =
      TWiki::Func::checkAccessPermission( 'VIEW',
        $TWiki::cfg{DefaultUserWikiName},
        undef, $topic, $this->{test_web} );
    $this->assert( !$access );
    $access =
      TWiki::Func::checkAccessPermission( 'VIEW',
        $TWiki::cfg{DefaultUserWikiName},
        '', $topic, $this->{test_web} );
    $this->assert( !$access );
    $access =
      TWiki::Func::checkAccessPermission( 'VIEW',
        $TWiki::cfg{DefaultUserWikiName},
        0, $topic, $this->{test_web} );
    $this->assert( !$access );
    $access = TWiki::Func::checkAccessPermission(
        'VIEW',
        $TWiki::cfg{DefaultUserWikiName},
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
            value => $TWiki::cfg{DefaultUserWikiName}
        }
    );
    $meta->save();
    $access = TWiki::Func::checkAccessPermission(
        'VIEW',
        $TWiki::cfg{DefaultUserWikiName},
        "   * Set ALLOWTOPICVIEW = NotASoul\n",
        $topic, $this->{test_web}, $meta
    );
    $this->assert($access);
    $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => 'DENYTOPICVIEW',
            title => 'DENYTOPICVIEW',
            type  => 'Set',
            value => $TWiki::cfg{DefaultUserWikiName}
        }
    );
    $meta->save();
    $access = TWiki::Func::checkAccessPermission(
        'VIEW',
        $TWiki::cfg{DefaultUserWikiName},
        "   * Set ALLOWTOPICVIEW = $TWiki::cfg{DefaultUserWikiName}\n",
        $topic, $this->{test_web}, $meta
    );
    $this->assert( !$access );

    return;
}

# Since 4.2.1, checkAccessPermission accepts a login name
sub test_checkAccessPermission_421 {
    my $this  = shift;
    my $topic = "NoWayJose";

    TWiki::Func::saveTopicText(
        $this->{test_web}, $topic, <<"END",
\t* Set DENYTOPICVIEW = $TWiki::cfg{DefaultUserWikiName}
END
    );
    eval { $this->{session}->finish() };
    $this->{session} = TWiki->new();
    $TWiki::Plugins::SESSION = $this->{session};
    my $access =
      TWiki::Func::checkAccessPermission( 'VIEW', $TWiki::cfg{DefaultUserLogin},
        undef, $topic, $this->{test_web} );
    $this->assert( !$access );
    $access =
      TWiki::Func::checkAccessPermission( 'VIEW', $TWiki::cfg{DefaultUserLogin},
        '', $topic, $this->{test_web} );
    $this->assert( !$access );
    $access =
      TWiki::Func::checkAccessPermission( 'VIEW', $TWiki::cfg{DefaultUserLogin},
        0, $topic, $this->{test_web} );
    $this->assert( !$access );
    $access = TWiki::Func::checkAccessPermission(
        'VIEW',
        $TWiki::cfg{DefaultUserLogin},
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
            value => $TWiki::cfg{DefaultUserWikiName}
        }
    );
    $meta->save();
    $access = TWiki::Func::checkAccessPermission(
        'VIEW',
        $TWiki::cfg{DefaultUserLogin},
        "   * Set ALLOWTOPICVIEW = NotASoul\n",
        $topic, $this->{test_web}, $meta
    );
    $this->assert($access);
    $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic );
    $meta->putKeyed(
        'PREFERENCE',
        {
            name  => 'DENYTOPICVIEW',
            title => 'DENYTOPICVIEW',
            type  => 'Set',
            value => $TWiki::cfg{DefaultUserWikiName}
        }
    );
    $meta->save();
    $access = TWiki::Func::checkAccessPermission(
        'VIEW',
        $TWiki::cfg{DefaultUserLogin},
        "   * Set ALLOWTOPICVIEW = $TWiki::cfg{DefaultUserWikiName}\n",
        $topic, $this->{test_web}, $meta
    );
    $this->assert( !$access );

    return;
}

sub test_getExternalResource {
    my $this = shift;

    # Totally pathetic sanity test

    # First check the LWP impl
    # need a known, simple, robust URL to get
    my $response = TWiki::Func::getExternalResource('http://develop.twiki.org');
    $this->assert_equals( 200, $response->code() );
    $this->assert_str_equals( 'OK', $response->message() );
    $this->assert_matches(
        qr/text\/html; charset=utf-8/s,
        lc( $response->header('content-type') )
    );
    $this->assert_matches( qr/Welcome to DevelopBranch TWiki/s,
        $response->content() );
    $this->assert( !$response->is_error() );
    $this->assert( !$response->is_redirect() );

    # Now force the braindead sockets impl
    $TWiki::Net::LWPAvailable = 0;
    $response = TWiki::Func::getExternalResource('http://develop.twiki.org');
    $this->assert_equals( 200, $response->code() );
    $this->assert_str_equals( 'OK', $response->message() );
    $this->assert_str_equals( 'text/html; charset=UTF-8',
        $response->header('content-type') );
    $this->assert_matches( qr/Welcome to DevelopBranch TWiki/s,
        $response->content() );
    $this->assert( !$response->is_error() );
    $this->assert( !$response->is_redirect() );

    return;
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
    $this->assert_equals( 0, TWiki::Func::isTrue() );
    $this->assert_equals( 1, TWiki::Func::isTrue( undef, 1 ) );
    $this->assert_equals( 0, TWiki::Func::isTrue( undef, undef ) );

    #TRUE
    $this->assert_equals( 1, TWiki::Func::isTrue( 'true', 'bad' ) );
    $this->assert_equals( 1, TWiki::Func::isTrue( 'True', 'bad' ) );
    $this->assert_equals( 1, TWiki::Func::isTrue( 'TRUE', 'bad' ) );
    $this->assert_equals( 1, TWiki::Func::isTrue( 'bad',  'bad' ) );
    $this->assert_equals( 1, TWiki::Func::isTrue( 'Bad',  'bad' ) );
    $this->assert_equals( 1, TWiki::Func::isTrue('BAD') );

    $this->assert_equals( 1, TWiki::Func::isTrue(1) );
    $this->assert_equals( 1, TWiki::Func::isTrue(-1) );
    $this->assert_equals( 1, TWiki::Func::isTrue(12) );
    $this->assert_equals( 1, TWiki::Func::isTrue( { a => 'me', b => 'ed' } ) );

    #FALSE
    $this->assert_equals( 0, TWiki::Func::isTrue( 'off',   'bad' ) );
    $this->assert_equals( 0, TWiki::Func::isTrue( 'no',    'bad' ) );
    $this->assert_equals( 0, TWiki::Func::isTrue( 'false', 'bad' ) );

    $this->assert_equals( 0, TWiki::Func::isTrue( 'Off',   'bad' ) );
    $this->assert_equals( 0, TWiki::Func::isTrue( 'No',    'bad' ) );
    $this->assert_equals( 0, TWiki::Func::isTrue( 'False', 'bad' ) );

    $this->assert_equals( 0, TWiki::Func::isTrue( 'OFF',   'bad' ) );
    $this->assert_equals( 0, TWiki::Func::isTrue( 'NO',    'bad' ) );
    $this->assert_equals( 0, TWiki::Func::isTrue( 'FALSE', 'bad' ) );

    $this->assert_equals( 0, TWiki::Func::isTrue(0) );
    $this->assert_equals( 0, TWiki::Func::isTrue('0') );
    $this->assert_equals( 0, TWiki::Func::isTrue(' 0') );

    #SPACES
    $this->assert_equals( 0, TWiki::Func::isTrue( '  off',     'bad' ) );
    $this->assert_equals( 0, TWiki::Func::isTrue( 'no  ',      'bad' ) );
    $this->assert_equals( 0, TWiki::Func::isTrue( '  false  ', 'bad' ) );

    $this->assert_equals( 0, TWiki::Func::isTrue(0) );

    return;
}

sub test_decodeFormatTokens {
    my $this = shift;

    my $input = <<'TEST';
$n embed$nembed$n()embed
$nop embed$nopembed$nop()embed
$quot embed$quotembed$quot()embed
$percnt embed$percntembed$percnt()embed
$dollar embed$dollarembed$dollar()embed
TEST
    my $expected = <<'TEST';

 embed$nembed
embed
 embedembedembed
" embed"embed"embed
% embed%embed%embed
$ embed$embed$embed
TEST
    my $output = TWiki::Func::decodeFormatTokens($input);
    $this->assert_str_equals( $expected, $output );

    return;
}

sub test_eachChangeSince {
    my $this = shift;
    $TWiki::cfg{Store}{RememberChangesFor} = 5;    # very bad memory
    $TWiki::cfg{ReplaceIfEditedAgainWithin} = 0;
    my $gus = $this->{session}->{user};
    my $sb  = $this->{session}->{users}->findUserByWikiName("ScumBag")->[0];

    sleep(1);
    my $start = time();
    my $users = $this->{session}->{users};
    Foswiki::Func::saveTopic( $this->{test_web}, "ClutterBuck", undef, "One" );
    Foswiki::Func::saveTopic( $this->{test_web}, "PiggleNut",   undef, "One" );

    # Wait a second
    sleep(1);
    my $mid = time();
    Foswiki::Func::saveTopic( $this->{test_web}, "ClutterBuck", undef, "One" );
    Foswiki::Func::saveTopic( $this->{test_web}, "PiggleNut", undef, "Two",
        undef );
    my $change;
    my $it = TWiki::Func::eachChangeSince( $this->{test_web}, $start );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 2,           $change->{revision} );
    $this->assert_equals( 'WikiGuest', $change->{user} );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 2,           $change->{revision} );
    $this->assert_equals( 'WikiGuest', $change->{user} );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 1,           $change->{revision} );
    $this->assert_equals( 'WikiGuest', $change->{user} );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 1,           $change->{revision} );
    $this->assert_equals( 'WikiGuest', $change->{user} );
    $this->assert( !$it->hasNext() );

    $it = TWiki::Func::eachChangeSince( $this->{test_web}, $mid );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 2,           $change->{revision} );
    $this->assert_equals( 'WikiGuest', $change->{user} );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 2,           $change->{revision} );
    $this->assert_equals( 'WikiGuest', $change->{user} );

    $this->assert( !$it->hasNext() );

    return;
}

# Check consistency between getListofWebs and webExists
sub test_4308 {
    my $this = shift;
    my @list = TWiki::Func::getListOfWebs('user');
    foreach my $web (@list) {
        $this->assert( TWiki::Func::webExists($web), $web );
    }
    @list = TWiki::Func::getListOfWebs('user public');
    foreach my $web (@list) {
        $this->assert( TWiki::Func::webExists($web), $web );
    }
    @list = TWiki::Func::getListOfWebs('template');
    foreach my $web (@list) {
        $this->assert( TWiki::Func::webExists($web), $web );
    }
    @list = TWiki::Func::getListOfWebs('public template');
    foreach my $web (@list) {
        $this->assert( TWiki::Func::webExists($web), $web );
    }

    return;
}

sub test_4411 {
    my $this = shift;
    $this->assert( TWiki::Func::isGuest(), $this->{session}->{user} );
    $this->{session}->finish();
    $this->{session} = TWiki->new( $TWiki::cfg{AdminUserLogin} );
    $this->assert( !TWiki::Func::isGuest(), $this->{session}->{user} );

    return;
}

sub test_setPreferences {
    my $this = shift;
    $this->assert( !TWiki::Func::getPreferencesValue("PSIBG") );
    $this->assert( TWiki::Func::setPreferencesValue( "PSIBG", "KJHD" ) );
    $this->assert_str_equals( "KJHD",
        TWiki::Func::getPreferencesValue("PSIBG") );
    my $q = TWiki::Func::getCgiQuery();

    ####
    TWiki::Func::saveTopicText( $this->{test_web},
        $TWiki::cfg{WebPrefsTopicName}, <<"HERE");
   * Set PSIBG = naff
   * Set FINALPREFERENCES = PSIBG
HERE
    $this->{session}->finish();
    $this->{session} = TWiki->new( $TWiki::cfg{GuestUserLogin}, $q );
    $this->assert_str_equals( "naff",
        TWiki::Func::getPreferencesValue("PSIBG") );
    TWiki::Func::setPreferencesValue( "PSIBG", "KJHD" );
    $this->assert_str_equals( "naff",
        TWiki::Func::getPreferencesValue("PSIBG") );
    ###
    TWiki::Func::saveTopicText( $this->{test_web},
        $TWiki::cfg{WebPrefsTopicName}, <<"HERE");
   * Set PSIBG = naff
HERE
    $this->{session}->finish();
    $this->{session} = TWiki->new( $TWiki::cfg{GuestUserLogin}, $q );
    $this->assert_str_equals( "naff",
        TWiki::Func::getPreferencesValue("PSIBG") );
    $this->assert( TWiki::Func::setPreferencesValue( "PSIBG", "KJHD" ) );
    $this->assert_str_equals( "KJHD",
        TWiki::Func::getPreferencesValue("PSIBG") );

    return;
}

sub test_getPluginPreferences {
    my $this = shift;
    my $pvar = "PSIBG";
    my $var  = uc(__PACKAGE__) . "_$pvar";
    $this->assert_null( TWiki::Func::getPreferencesValue($var) );
    $this->assert_null( TWiki::Func::getPreferencesValue($pvar) );
    $this->assert( TWiki::Func::setPreferencesValue( $var, "on" ) );
    $this->assert_str_equals( "on",
        TWiki::Func::getPluginPreferencesValue($pvar) );
    $this->assert( TWiki::Func::getPluginPreferencesFlag($pvar) );
    $this->assert( TWiki::Func::setPreferencesValue( $var, "off" ) );
    $this->assert_str_equals( "off",
        TWiki::Func::getPluginPreferencesValue($pvar) );
    $this->assert( !TWiki::Func::getPluginPreferencesFlag($pvar) );

    return;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
