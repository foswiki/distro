#
# Unit tests for Foswiki::Func
#
package FuncTests;

use strict;
use warnings;
use utf8;    # For test_unicode_attachment

use Assert;
use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );
use Foswiki();
use Foswiki::Func();

sub TRACE { return 0 }

sub skip {
    my ( $this, $test ) = @_;

    return $this->SUPER::skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                'FuncTests::test_getUrlHost_ForceDefaultUrlHost' =>
                  'ForceDefaultUrlHost is Foswiki 1.2+ only, Item11900',
            }
        }
    );
}

my $MrWhite;

# The second word in the string below consists only of two _graphemes_
# (logical characters as humans know them) both built from single _base
# characters_ but then decorated w/additional _modifier_ characters to add
# vowel marks and other signs.
#
# vim, scite, and probably other monospace/grid-based editors have problems
# with this and may show all five unicode characters separately.
# It's the word "hindi" in devanagari script. http://translate.google.com/#auto|hi|hindi
#
# - "use utf8;" needs to be at the top of this .pm.
# - Your editor/terminal needs to be editing in utf8.
# - You might also want ttf-devanagari-fonts or ttf-indic-fonts-core
# - First word german 'übermaß' to make the failure mode more easy to follow
my $uniname = 'übermaß_हिंदी';

# http://translate.google.com/#auto|hi|standard
my $unicomment = 'मानक';

my @scripturl_tests = (
    {
        expected => {
            'view' => '/path/to/bin/view',
            'edit' => '/path/to/bin/edit'
        }
    },
    {
        cfg      => { ScriptUrlPaths => { 'view' => '/path/to' } },
        expected => {
            'view' => '/path/to',
            'edit' => '/path/to/bin/edit'
        }
    },
    {
        cfg      => { ScriptUrlPaths => { 'view' => '' } },
        expected => {
            'view' => '',
            'edit' => '/path/to/bin/edit'
        }
    },
    {
        cfg      => { ScriptUrlPaths => { 'edit' => '' } },
        expected => {
            'view' => '/path/to/bin/view',
            'edit' => ''
        }
    },
    {
        cfg      => { ScriptUrlPaths => { 'edit' => '/somewhere/else' } },
        expected => {
            'view' => '/path/to/bin/view',
            'edit' => '/somewhere/else'
        }
    },
);

sub new {
    my ( $class, @args ) = @_;

    return $class->SUPER::new( "Func", @args );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my ($topicObject) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{DefaultUserWikiName} );
    $topicObject->save();
    $topicObject->finish();
    $this->registerUser( 'white', 'Mr', "White", 'white@example.com' );
    $MrWhite = $this->{session}->{users}->getCanonicalUserID('white');

    $this->{tmpdatafile}  = $Foswiki::cfg{TempfileDir} . '/tmpity-tmp.gif';
    $this->{tmpdatafile2} = $Foswiki::cfg{TempfileDir} . '/tmpity-tmp2.gif';
    $this->{test_web2}    = $this->{test_web} . 'Extra';
    my $webObject = $this->populateNewWeb( $this->{test_web2} );
    $webObject->finish();

    return;
}

sub tear_down {
    my $this = shift;
    unlink $this->{tmpdatafile};
    unlink $this->{tmpdatafile2};
    $this->removeWebFixture( $this->{session}, $this->{test_web2} );
    $this->SUPER::tear_down();

    return;
}

# Helper function to wrap asserts around file accesses
sub write_file {
    my ( $this, $filename, $data, $options ) = @_;

    # Check input parameters
    $options ||= {};
    $this->assert_not_null( $filename,
        "Need to pass a filename to write_file" );

    # Write data into the file
    my $filehandle;
    $this->assert(
        open( $filehandle, '>', $filename ),
        "Failed to open $filename for writing: $!"
    );
    binmode $filehandle if $options->{binmode};
    print $filehandle $data;
    $this->assert( close($filehandle) );

    return unless $options->{read};
    $this->assert(
        open( $filehandle, '<', $filename ),
        "Failed to open $filename for reading: $!"
    );
    binmode $filehandle if $options->{binmode};
    return $filehandle;
}

sub test_saveFile_readFile {
    my $this = shift;
    my $text = <<ASCII;
Now is the time for all
Jack and Jill went up the hill.
ASCII
    my $f = "$Foswiki::cfg{WorkingDir}/${$}.dat";
    Foswiki::Func::saveFile( $f, $text );
    my $newtext = Foswiki::Func::readFile($f);
    $this->assert_equals( length($text), length($newtext) );
    $this->assert_str_equals( $text, $newtext );
    unlink($f);

    # Test with missing file
    $newtext = Foswiki::Func::readFile('File does not exist');
    $this->assert_equals( 0, length($newtext) );
}

sub test_saveFile_readFile_Binary {
    my $this = shift;
    my $data = Foswiki::Func::readFile(
        "$Foswiki::cfg{PubDir}/System/ProjectLogos/foswiki-logo.png");
    $this->assert( length($data) );    # make sure we actually get something
    my $f = "$Foswiki::cfg{WorkingDir}/${$}.dat";
    Foswiki::Func::saveFile( $f, $data );
    my $newdata = Foswiki::Func::readFile($f);
    $this->assert_equals( length($data), length($newdata) );
    $this->assert_str_equals( $data, $newdata );
    unlink($f);
}

sub test_saveFile_readFile_Unicode {
    my $this = shift;
    my $text = <<POWETRY;
Dolorěṁ dêḻêcťůṡ iľļó áńįṁị îpşaṁ auṫ. Sapìëňte possiṁuś ratìoňe ļaboŕįõsām ĥįc ṗariatúř ëť. Rerụṁ ìṫaqūė excēpțuři ńeṁọ vọḻuṗťaś volŭṗtaş aüteṁ ratiòne ńéṡcîuṉț. Mødí qúø veḻîṫ saèpe ŕēpelĺènḋuś eť. Culṗă ṗraēsēńtium vero äb ödïo. Vero ċőrṗöŕīŝ doļőŕ ḋůċimus ḻàḃorum ódio paríatur quia. Reịçîêndįṡ eț pāřiatūr omṅis. Consěqúatůr íṁpedįť ćòṅsēquatuř quăși. Cöňseqųaṫùr dīștinçtío nëṁó ịste.
Voḻŭṗťas illo rèćusandaė ęt dįcťã nôṉ qųaŝ qui pørŕo. Iṗsűm ñọn iŝte võłůpṫáțųṁ. Unde qùo űť cumque ṗerḟeŕenḋiš ďiĝnisšįmoş et. Vọľuptațèṁ ňịĥil ďọļôr doloř ešť verītátïş. Uńdē ĥìc ēūm viṫae ut oṁñịș ďọloř. Dọlõrėm ṗerfërêndìș miňus řąťìọnë exṗlićåḃo. Temṗọrá nôbîs teṁpore pariaṫůr et. Voľuptáțê ṫenetur omniš est áụt eĺigendi. Quí vèlit ea moĺlìṫiā qụişqüãṁ möĺeštîaë đebitîṡ veĺit năṁ.
POWETRY
    my $f = "$Foswiki::cfg{WorkingDir}/${$}.dat";
    Foswiki::Func::saveFile( $f, $text, 1 );
    my $newtext = Foswiki::Func::readFile( $f, 1 );
    $this->assert_str_equals( $text, $newtext );
    unlink($f);
}

sub test_createWeb_permissions {
    my $this = shift;
    use Error qw( :try );
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );

    $this->assert(
        !Foswiki::Func::saveTopicText(
            $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName}, <<"HERE") );
\t* Set DENYWEBCHANGE = $Foswiki::cfg{DefaultUserWikiName}
HERE

    $this->createNewFoswikiSession();

    # Verify that create of a root web is denied by default user.
    try {
        Foswiki::Func::createWeb("Blahweb");
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_matches( qr/access not allowed on root/,
            $e, "Unexpected error $e" );
    };
    $this->assert(
        !Foswiki::Func::webExists("Blahweb"),
        "Test should not have created the web"
    );

# Verify that create of a sub web is denied by default user if denied in webPreferences.
    try {
        Foswiki::Func::createWeb("$this->{test_web}/Blahsub");
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_matches(
qr/Access to CHANGE TemporaryFuncTestWebFunc\/Blahsub. for BaseUserMapping_666 is denied. access denied on web/,
            $e,
            "Unexpected error $e"
        );
    };
    $this->assert( !Foswiki::Func::webExists("$this->{test_web}/Blahsub"),
        "Test should not have created the web" );

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );

    Foswiki::Func::saveTopicText(
        $this->{test_web}, 'WebPreferences', <<"END",
\t* Set ALLOWWEBCHANGE = $Foswiki::cfg{DefaultUserWikiName}
END
    );

    $this->createNewFoswikiSession();

# Verify that create of a sub web is allowed by default user if allowed in webPreferences.
    try {
        Foswiki::Func::createWeb("$this->{test_web}/Blahsub");
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert("Unexpected error $e");
    };
    $this->assert( Foswiki::Func::webExists("$this->{test_web}/Blahsub"),
        "Test should have created the web" );
    $this->assert(
        !defined Foswiki::Func::getPreferencesValue(
            'WEBBGCOLOR', "$this->{test_web}/Blahsub"
        )
    );

    $this->createNewFoswikiSession();

    # Verify that createWeb copys the _default web.
    try {
        Foswiki::Func::createWeb( "$this->{test_web}/Blahsub", '_default' );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert("Unexpected error $e");
    };
    $this->assert( Foswiki::Func::webExists("$this->{test_web}/Blahsub"),
        "Test should have created the web" );
    $this->assert_equals(
        '#DDDDDD',
        Foswiki::Func::getPreferencesValue(
            'WEBBGCOLOR', "$this->{test_web}/Blahsub"
        )
    );

    return;
}

sub test_Item9021 {
    my $this = shift;
    use Error qw( :try );
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );

    try {
        Foswiki::Func::createWeb( $this->{test_web} . "Missing/Blah" );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert_matches(
            qr/^Parent web TemporaryFuncTestWebFuncMissing does not exist.*/,
            $e, "Unexpected error $e" );
    };
    $this->assert( !Foswiki::Func::webExists( $this->{test_web} . "Missing" ),
        "test should not have created the web" );
    $this->assert(
        !Foswiki::Func::webExists( $this->{test_web} . "Missing/Blah" ),
        "Test should not have created the web" );

    return;
}

sub test_createWeb_InvalidBase {
    my $this = shift;
    use Error qw( :try );
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );

    try {
        Foswiki::Func::createWeb( $this->{test_web} . "InvaliBase",
            "Invalidbase" );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert_matches( qr/^Template web Invalidbase does not exist.*/,
            $e, "Unexpected error $e" );
    };
    $this->assert(
        !Foswiki::Func::webExists( $this->{test_web} . "invaliBase" ) );

    return;
}

sub test_createWeb_hierarchyDisabled {
    my $this = shift;
    use Error qw( :try );
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 0;

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );

    try {
        Foswiki::Func::createWeb( $this->{test_web} . "/Subweb" );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert_matches(
            qr/^Unable to create .*- Hierarchical webs are disabled.*/,
            $e, "Unexpected error $e" );
    };
    $this->assert( !Foswiki::Func::webExists( $this->{test_web} . "/Subweb" ) );

    return;
}

sub test_createWeb_pref_option {
    my $this = shift;

    $this->createNewFoswikiSession();

# Verify that create of a sub web is allowed by default user if allowed in webPreferences.
    try {
        Foswiki::Func::createWeb( "$this->{test_web}/Blahsub", undef,
            { WEBBGCOLOR => '#999' } );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert("Unexpected error $e");
    };
    $this->assert( Foswiki::Func::webExists("$this->{test_web}/Blahsub"),
        "Test should have created the web" );
    $this->assert_equals(
        '#999',
        Foswiki::Func::getPreferencesValue(
            'WEBBGCOLOR', "$this->{test_web}/Blahsub"
        )
    );

    return;
}

sub test_moveWeb {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $webObject = $this->populateNewWeb( $this->{test_web} . "Blah" );
    $webObject->finish();
    $webObject = $this->populateNewWeb( $this->{test_web} . "Blah/SubWeb" );
    $webObject->finish();

    $this->assert( Foswiki::Func::webExists( $this->{test_web} . 'Blah' ) );
    $this->assert(
        Foswiki::Func::webExists( $this->{test_web} . 'Blah/SubWeb' ) );

    Foswiki::Func::moveWeb( $this->{test_web} . 'Blah',
        $this->{test_web} . 'Blah2' );

    $this->assert( !Foswiki::Func::webExists( $this->{test_web} . 'Blah' ) );
    $this->assert( Foswiki::Func::webExists( $this->{test_web} . 'Blah2' ) );
    $this->assert(
        Foswiki::Func::webExists( $this->{test_web} . 'Blah2/SubWeb' ) );
    $this->removeWebFixture( $this->{session}, $this->{test_web} . 'Blah2' );

    return;
}

sub test_getViewUrl {
    my $this = shift;
    my $ss;

    if ( defined $Foswiki::cfg{ScriptUrlPaths}{view} ) {
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

    $this->createNewFoswikiSession( undef,
        Unit::Request->new( { topic => "Sausages.AndMash" } ) );

    $result = Foswiki::Func::getViewUrl( "Sausages", "AndMash" );
    $this->assert_matches( qr!${ss}/Sausages/AndMash!, $result );

    $result = Foswiki::Func::getViewUrl( "", "AndMash" );
    $this->assert_matches( qr!${ss}/Sausages/AndMash!, $result );

    return;
}

sub test_getScriptUrl {
    my $this = shift;

    my $ss = 'wibble' . $Foswiki::cfg{ScriptSuffix};
    my $result =
      Foswiki::Func::getScriptUrl( $this->{users_web}, "WebHome", 'wibble' );
    $this->assert_matches( qr!/$ss/$this->{users_web}/WebHome!, $result );

    $result = Foswiki::Func::getScriptUrl( "", "WebHome", 'wibble' );
    $this->assert_matches( qr!/$ss/$this->{home_web}/WebHome!, $result );

    my $q = Unit::Request->new( {} );
    $q->path_info('/Sausages/AndMash');
    $this->createNewFoswikiSession( undef, $q );

    $result = Foswiki::Func::getScriptUrl( "Sausages", "AndMash", 'wibble' );
    $this->assert_matches( qr!/$ss/Sausages/AndMash!, $result );

    $result = Foswiki::Func::getScriptUrl( "", "AndMash", 'wibble' );
    $this->assert_matches( qr!/$ss/$this->{home_web}/AndMash!, $result );

    $result = Foswiki::Func::getScriptUrl(
        $this->{users_web}, "WebHome", 'wibble',
        '#'    => 'wazzock',
        wobble => 'wimple'
    );
    $this->assert_matches(
        qr!/$ss/$this->{users_web}/WebHome\?wobble=wimple#wazzock$!, $result );

    $result = Foswiki::Func::getScriptUrl(
        $this->{users_web}, "WebHome", 'wibble',
        wobble => 1,
        wimple => 2
    );
    $this->assert_matches( qr!wobble=1!, $result );
    $this->assert_matches( qr!wimple=2!, $result );
    $this->assert_matches(
        qr!/$ss/$this->{users_web}/WebHome\?w\w+=\d[;&]w\w+=\d$!, $result );

    return;
}

sub test_getOopsUrl {
    my $this = shift;
    my $url =
      Foswiki::Func::getOopsUrl( 'Incy', 'Wincy', 'Spider', 'Hurble', 'Burble',
        'Wurble', 'Murble' );
    $this->assert_URI_equals(
        Foswiki::Func::getScriptUrl( 'Incy', 'Wincy', 'oops' )
          . "?template=Spider;param1=Hurble;param2=Burble;param3=Wurble;param4=Murble",
        $url
    );
    $url = Foswiki::Func::getOopsUrl(
        'Incy',   'Wincy',  'oopspider', 'Hurble',
        'Burble', 'Wurble', 'Murble'
    );
    $this->assert_URI_equals(
        Foswiki::Func::getScriptUrl( 'Incy', 'Wincy', 'oops' )
          . "?template=oopspider;param1=Hurble;param2=Burble;param3=Wurble;param4=Murble",
        $url
    );

    return;
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

    return;
}

# As much as I'd like to remove this dumb function, make sure it's still
# compatible
sub test_saveTopicText {
    my $this  = shift;
    my $topic = 'SaveTopicText';
    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, <<'NONNY' );
   * Set ALLOWTOPICCHANGE = NotMeNoNotMe
NONNY
    $this->assert(
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef, $topic, $this->{test_web}
        )
    );

    # This should fail and return an oopsUrl (FFS, what a poor spec)
    my $oopsURL =
      Foswiki::Func::saveTopicText( $this->{test_web}, $topic, 'Gasp' );
    $this->assert($oopsURL);
    my @ri = Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic );
    $this->assert_matches( qr/1$/, $ri[2] );

    # This should succeed and return undef
    $oopsURL =
      Foswiki::Func::saveTopicText( $this->{test_web}, $topic, 'Beam', 1 );
    $this->assert( !$oopsURL, $oopsURL );

    return;
}

# Verify that a round trip doesn't remove or add any newlines between the topic and
# the metadata in the raw text.
sub test_saveTopicRoundTrip {
    my $this     = shift;
    my $topic    = 'SaveTopicText2';
    my $origtext = <<'NONNY';
Tis some text
and a trailing newline



%META:FILEATTACHMENT{name="IMG_0608.JPG" attr="" autoattached="1" comment="A Comment" date="1162233146" size="762004" user="Main.AUser" version="1"}%
NONNY

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, $origtext );
    my $text1 = Foswiki::Func::readTopicText( $this->{test_web}, $topic );

    my ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    Foswiki::Func::saveTopic( $this->{test_web}, $topic, $meta, $text,
        { comment => 'atp save', forcenewrevision => 1 } );
    $meta->finish();

    my $text2 = Foswiki::Func::readTopicText( $this->{test_web}, $topic );
    my $matchText =
'%META:TOPICINFO\{author="BaseUserMapping_666" comment="atp save" date=".*?" format="1.1" version="2"\}%'
      . "\n"
      . "\Q$origtext\E";
    $this->assert_matches( qr/$matchText/, $text2 );

    return;
}

sub test_saveTopic {
    my $this  = shift;
    my $topic = 'SaveTopic';
    Foswiki::Func::saveTopic( $this->{test_web}, $topic, undef, <<'NONNY' );
%META:PREFERENCE{name="Bird" value="Kakapo"}%
   * Set ALLOWTOPICCHANGE = NotMeNoNotMe
NONNY
    $this->assert(
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef, $topic, $this->{test_web}
        )
    );
    my @ri = Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic );
    $this->assert_matches( qr/1$/, $ri[2] );

    # Make sure the meta got into the topic
    my ( $m, $t ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    my $el = $m->get( 'PREFERENCE', 'Bird' );
    $this->assert_equals( 'Kakapo', $el->{value} );

    # This should succeed
    Foswiki::Func::saveTopic( $this->{test_web}, $topic, $m, 'Gasp',
        { forcenewrevision => 1, ignorepermissions => 1 } );
    $m->finish();
    @ri = Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic );
    $this->assert_matches( qr/2$/, $ri[2] );

    ( $m, $t ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );

    # Make sure the meta is still there
    $el = $m->get( 'PREFERENCE', 'Bird' );
    $m->finish();
    $this->assert_equals( 'Kakapo', $el->{value} );
    $this->assert_equals( 'Gasp',   $t );

    return;
}

sub test_saveTopicAUTOINC {
    my $this  = shift;
    my $topic = 'SaveTopic001';
    Foswiki::Func::saveTopic( $this->{test_web}, 'SaveTopicAUTOINC001', undef,
        <<'NONNY' );
%META:PREFERENCE{name="Bird" value="Kakapo"}%
   * Set ALLOWTOPICCHANGE = NotMeNoNotMe
NONNY
    $this->assert(
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef, $topic, $this->{test_web}
        )
    );

    $topic = 'SaveTopic001';
    Foswiki::Func::saveTopic( $this->{test_web}, 'SaveTopicAUTOINC001', undef,
        <<'NONNY' );
%META:PREFERENCE{name="Bird" value="Kakapo"}%
   * Set ALLOWTOPICCHANGE = NotMeNoNotMe
NONNY
    $this->assert(
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef, $topic, $this->{test_web}
        )
    );
    my @ri = Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic );
    $this->assert_matches( qr/1$/, $ri[2] );

    # Make sure the meta got into the topic
    my ( $m, $t ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    my $el = $m->get( 'PREFERENCE', 'Bird' );
    $this->assert_equals( 'Kakapo', $el->{value} );

    # This should succeed
    Foswiki::Func::saveTopic( $this->{test_web}, $topic, $m, 'Gasp',
        { forcenewrevision => 1, ignorepermissions => 1 } );
    $m->finish();
    @ri = Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic );
    $this->assert_matches( qr/2$/, $ri[2] );

    ( $m, $t ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );

    # Make sure the meta is still there
    $el = $m->get( 'PREFERENCE', 'Bird' );
    $m->finish();
    $this->assert_equals( 'Kakapo', $el->{value} );
    $this->assert_equals( 'Gasp',   $t );

    return;
}

sub test_Item8713 {
    my $this  = shift;
    my $tweb  = 'A:B';
    my $topic = 'C:D';
    try {
        Foswiki::Func::saveTopic( $tweb, $topic, undef, <<'NONNY' );
%META:PREFERENCE{name="Bird" value="Kakapo"}%
   * Set ALLOWTOPICCHANGE = NotMeNoNotMe
NONNY
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert_matches(
            qr/Unable to save topic C:D - web A:B does not exist.*/,
            $e, "Unexpected error $e" );
    }

    #$this->assert(
    #   ! Foswiki::Func::webExists( $tweb ));
    #$this->assert(
    #   ! Foswiki::Func::topicExists( $tweb, $topic ) );

    return;
}

sub test_attachments {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $data  = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $data2 = "\0h\1a\2l\3b\4h\5a\6l\7b";
    my $attnm = 'blahblahblah.gif';

    #$attnm = Assert::TAINT($attnm);
    my $name1 = 'blahblahblah.gif';

    #$name1 = Assert::TAINT($name1);
    my $name2 = 'bleagh.sniff';

    #$name2 = Assert::TAINT($name2);
    my $topic = "BlahBlahBlah";

    #$topic = Assert::TAINT($topic);

    my $stream =
      $this->write_file( $this->{tmpdatafile}, $data,
        { binmode => 1, read => 1 } );
    $this->write_file( $this->{tmpdatafile2}, $data2, { binmode => 1 } );

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, '' );

    #$name1 = TAINT($name1);

    my $e = Foswiki::Func::saveAttachment(
        $this->{test_web},
        $topic, $name1,
        {
            dontlog  => 1,
            comment  => 'Feasgar " Bha',
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

    $meta->finish();
    ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    @attachments = $meta->find('FILEATTACHMENT');
    $meta->finish();
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
        !(
            Foswiki::Func::attachmentExists(
                $this->{test_web}, $topic, "NotExists"
            )
        )
    );

    # This should fail - attachment is not present
    $this->assert(
        !Foswiki::Func::readAttachment(
            $this->{test_web}, $topic, "NotExists"
        )
    );

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
    $x =
      Foswiki::Func::readAttachment( $this->{test_web}, $topic, $name2, "1" );
    $this->assert_str_equals( $data, $x );

    return;
}

sub test_attachment_comment {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $data  = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $data2 = "\0h\1a\2l\3b\4h\5a\6l\7b";
    my $attnm = 'blahblahblah.gif';

    my $topic = "BlahBlahBlah";
    my $name1 = 'blahblahblah.gif';

    my $stream =
      $this->write_file( $this->{tmpdatafile}, $data,
        { binmode => 1, read => 1 } );
    $this->write_file( $this->{tmpdatafile2}, $data2, { binmode => 1 } );

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, '' );

    my $attachComment = 'Feasgar " Blha';

    my $e = Foswiki::Func::saveAttachment(
        $this->{test_web},
        $topic, $name1,
        {
            dontlog  => 1,
            comment  => $attachComment,
            stream   => $stream,
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert( !$e, $e );

    my ( $date, $user, $rev, $actualComment ) =
      Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic, undef,
        $name1 );

    $this->assert_str_equals( $attachComment, $actualComment );

    $actualComment .= ' changed';

    $e = Foswiki::Func::saveAttachment(
        $this->{test_web},
        $topic, $name1,
        {
            dontlog => 1,
            comment => $attachComment,
        }
    );
    $this->assert( !$e, $e );

    ( $date, $user, $rev, $actualComment ) =
      Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic, undef,
        $name1 );

    $this->assert_str_equals( $attachComment, $actualComment );

    return;
}

sub test_noauth_saveAttachment {
    my $this = shift;
    use Foswiki::AccessControlException;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $data  = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $name1 = 'blahblahblah.gif';
    my $topic = "BlahBlahBlah";

    my $stream =
      $this->write_file( $this->{tmpdatafile}, $data,
        { binmode => 1, read => 1 } );

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic,
        " \n   * Set ALLOWTOPICCHANGE = SomeUser\n" );

    try {
        my $e = Foswiki::Func::saveAttachment(
            $this->{test_web},
            $topic, $name1,
            {
                dontlog  => 1,
                comment  => 'Feasgar " Bha',
                stream   => $stream,
                filepath => '/local/file',
                filesize => 999,
                filedate => 0,
            }
        );
        $this->assert( 0, "saveAttachment worked for unauthorized user" );

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_matches(
qr/^AccessControlException: Access to CHANGE TemporaryFuncTestWebFunc.BlahBlahBlah for BaseUserMapping_666 is denied.*/,
            $e,
            "Unexpected error $e"
        );
    };

    return;
}

sub test_noauth_saveTopic {
    my $this = shift;

    my $curUser   = 'MrWhite';
    my $userLogin = 'white';
    my $topic     = "BlahBlahcwBlah";
    my $ttext =
" APPLE \n   * Set ALLOWTOPICVIEW = SomeUser \n   * Set DENYTOPICCHANGE = BaseUserMapping_666,MrWhite \n ";

    my $query = Unit::Request->new();
    $this->createNewFoswikiSession( $userLogin, $query );
    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, $ttext );

    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, $topic ) );

    $this->assert(
        !Foswiki::Func::checkAccessPermission(
            'VIEW', $curUser, '', $topic, $this->{test_web}
        ),
        "VIEW check failed - $curUser should be denied"
    );
    $this->assert(
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', $curUser, '', $topic, $this->{test_web}
        ),
        "CHANGE check failed - $curUser should be denied"
    );

    # Validate that saveTopicText throws an exception
    my $except =
      Foswiki::Func::saveTopicText( $this->{test_web}, $topic,
        " \n   * Set ALLOWTOPIVIEW = SomeUser \n blah" );
    $this->assert_URI_equals(
        Foswiki::Func::getScriptUrl(
            $this->{test_web}, $topic, 'oops',
            def      => 'topic_access',
            param1   => 'FuncTests',
            template => 'oopsattention'
        ),
        $except
    );

    $this->assert(
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', $curUser, '', $topic, $this->{test_web}
        )
    );

    # Also validate that saveTopic throws an exception
    my ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    try {
        Foswiki::Func::saveTopic( $this->{test_web}, $topic, $meta, $text );
        $this->assert( 0, "saveTopic worked for unauthorized user" );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert_matches(
qr/^AccessControlException: Access to CHANGE TemporaryFuncTestWebFunc.BlahBlahcwBlah for white is denied.*/,
            $e,
            "Unexpected error $e"
        );
    };
    $meta->finish();

    return;
}

sub test_resaveDenied {
    my $this = shift;

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        <<"HEY" );
   * Set DENYTOPICCHANGE = $Foswiki::cfg{DefaultUserWikiName}
HEY
    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        <<"NONNY", { ignorepermissions => 1 } );
   * Set DENYTOPICCHANGE = $Foswiki::cfg{DefaultUserWikiName}
NONNY
    eval {
        Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
            "No!" );
    };
    $this->assert_matches( qr/AccessControlException: Access to CHANGE/, $@ );

    return;
}

sub test_subweb_attachments {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $data  = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $data2 = "\0h\1a\2l\3b\4h\5a\6l\7b";
    my $attnm = 'blahblahblah.gif';
    my $name1 = 'blahblahblah.gif';
    my $name2 = 'bleagh.sniff';
    my $topic = "BlahBlahBlah";

    #$topic = Assert::TAINT($topic);
    my $web = $this->{test_web} . "/SubWeb";

    #$web = Assert::TAINT($web);
    #
    my $webObject = $this->populateNewWeb($web);
    $webObject->finish();

    my $stream =
      $this->write_file( $this->{tmpdatafile}, $data,
        { binmode => 1, read => 1 } );
    $this->write_file( $this->{tmpdatafile2}, $data2, { binmode => 1 } );

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, '' );

    #$name1 = Assert::TAINT($name1);
    my $e = Foswiki::Func::saveAttachment(
        $web, $topic, $name1,
        {
            dontlog  => 1,
            comment  => 'Feasgar " Bha',
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
        $web, $topic, $name2,
        {
            dontlog  => 1,
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
    $ft = Foswiki::Func::getPubDir() . "/" . $web;
    if ( $Foswiki::cfg{Store}{Implementation} =~ /PlainFile|RcsWrap|RcsWrite/ )
    {
        $this->assert( ( -d $ft ), "Web directory for attachment not created" );
        $ft .= "/" . $topic;
        $this->assert( ( -d $ft ),
            "Topic directory for attachment not created?" );
        $this->assert( ( -e $ft . "/$name1" ),
            "Attachment file $ft/$name1  was not written to disk?" );
        if ( $Foswiki::cfg{Store}{Implementation} =~ /RcsWrap|RcsWrite/ ) {
            $this->assert(
                ( -e $ft . "/$name1,v" ),
                "Attachment RCS Filename $ft/$name1,v was not written to disk?"
            );
            $this->assert(
                ( -e $ft . "/$name2,v" ),
                "Attachment RCS Filename $ft/$name2,v was not written to disk?"
            );
        }
        $this->assert( ( -e $ft . "/$name2" ),
            "Attachment file $ft/$name2  was not written to disk?" );
    }

    $meta->finish();
    ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    @attachments = $meta->find('FILEATTACHMENT');
    $meta->finish();
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
    $this->assert( Foswiki::Func::attachmentExists( $web, $topic, $name1 ) );

    # This should fail - attachment is not present
    $this->assert(
        !( Foswiki::Func::attachmentExists( $web, $topic, "NotExists" ) ) );

    # This should fail - attachment is not present
    $this->assert(
        !Foswiki::Func::readAttachment( $web, $topic, "NotExists" ) );

    # Update the attachment and check that the data is updated.
    $e = Foswiki::Func::saveAttachment(
        $web, $topic, $name2,
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
    $x = Foswiki::Func::readAttachment( $web, $topic, $name2, "1" );
    $this->assert_str_equals( $data, $x );

    return;
}

sub test_getrevinfo {
    my $this  = shift;
    my $topic = "RevInfo";
    my $now   = time();
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $webObject = $this->populateNewWeb( $this->{test_web} . "/Blah" );
    $webObject->finish();

    Foswiki::Func::saveTopicText( $this->{test_web},        $topic, 'blah' );
    Foswiki::Func::saveTopicText( "$this->{test_web}/Blah", $topic, 'blah' );

    my ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $this->{test_web}, $topic );
    $this->assert_equals( 1, $rev );
    my $wikiname = Foswiki::Func::getWikiName();
    $this->assert_str_equals( $wikiname, $user );
    $this->assert_equals( 1, $rev );
    $this->assert( $date >= $now, $date );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( "$this->{test_web}/Blah", $topic );
    $this->assert_str_equals( $wikiname, $user );
    $this->assert_equals( 1, $rev );
    $this->assert( $date >= $now, $date );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( "$this->{test_web}.Blah", $topic );
    $this->assert_str_equals( $wikiname, $user );
    $this->assert_equals( 1, $rev );
    $this->assert( $date >= $now, $date );

    return;
}

# Helper function for test_moveTopic
sub _checkMoveTopic {
    my ( $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;
    my $meta;
    my $text;
    $newWeb   ||= $oldWeb;
    $newTopic ||= $oldTopic;
    ( $meta, $text ) = Foswiki::Func::readTopic( $newWeb, $newTopic );

    foreach ( @{ $meta->{TOPICMOVED} } ) {

        # pick out the meta entry that indicates this move.
        next if ( $_->{to}   ne "$newWeb.$newTopic" );
        next if ( $_->{from} ne "$oldWeb.$oldTopic" );
        return 1;
    }
    $meta->finish();

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
    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $stream =
      $this->write_file( $this->{tmpdatafile}, $data,
        { binmode => 1, read => 1 } );

    Foswiki::Func::saveAttachment(
        $this->{test_web},
        "SourceTopic",
        "Name1",
        {
            dontlog  => 1,
            comment  => 'Feasgar " Bha',
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
        )
    );

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
        )
    );

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
        )
    );

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
        )
    );

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
        )
    );

    return;
}

sub test_moveAttachment {
    my $this = shift;

    Foswiki::Func::saveTopicText( $this->{test_web}, "SourceTopic", "Wibble" );

    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $stream =
      $this->write_file( $this->{tmpdatafile}, $data,
        { binmode => 1, read => 1 } );

    Foswiki::Func::saveAttachment(
        $this->{test_web},
        "SourceTopic",
        "Name1",
        {
            dontlog  => 1,
            comment  => 'Feasgar " Bha',
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
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/ );

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
    $meta->finish();
    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/ );

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
    $meta->finish();
    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/ );

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
    $meta->finish();
    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/ );
    $meta->finish();

    return;
}

sub test_copyAttachment {
    my $this = shift;

    Foswiki::Func::saveTopicText( $this->{test_web}, "SourceTopic", "Wibble" );

    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $stream =
      $this->write_file( $this->{tmpdatafile}, $data,
        { binmode => 1, read => 1 } );

    Foswiki::Func::saveAttachment(
        $this->{test_web},
        "SourceTopic",
        "Name1",
        {
            dontlog  => 1,
            comment  => 'Feasgar " Bha',
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
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/ );

    Foswiki::Func::saveTopicText( $this->{test_web},  "TargetTopic", "Wibble" );
    Foswiki::Func::saveTopicText( $this->{test_web2}, "TargetTopic", "Wibble" );

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
    $meta->finish();
    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "SourceTopic" );
    $this->assert( $text =~ m/Wibble/ );

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
    $meta->finish();
    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/ );

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
    $meta->finish();
    ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, "TargetTopic" );
    $this->assert( $text =~ m/Wibble/ );
    $meta->finish();

    return;
}

sub test_attachmentExists {
    my $this = shift;

    my $topic = "AttachmentExists";

    $this->write_file( "$Foswiki::cfg{TempfileDir}/testfile.txt",
        "one two three" );

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, 'foo' );
    Foswiki::Func::saveAttachment(
        $this->{test_web},
        $topic,
        "testfile.txt",
        {
            file    => "$Foswiki::cfg{TempfileDir}/testfile.txt",
            comment => "a comment"
        }
    );

    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, $topic, "testfile.txt"
        )
    );

    return;
}

sub test_attachmentExistsInMetaOnly {
    my $this = shift;

    my $topic = "AttachmentExistsInMetaOnly";
    my $text  = <<'HERE';
foo

%META:FILEATTACHMENT{name="Sample.txt" attr="" comment="Just a sample" date="964294620" path="Sample.txt" size="30" user="ProjectContributor" version=""}%
HERE

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, $text );

    $this->assert(
        not Foswiki::Func::attachmentExists(
            $this->{test_web}, $topic, "Sample.txt"
        )
    );

    return;
}

sub test_workarea {
    my $this = shift;

    my $dir = Foswiki::Func::getWorkArea('TestPlugin');
    $this->assert( -d $dir );

    # SMELL: check the permissions

    unlink $dir;

    return;
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

    return;
}

sub test_w2em {
    my $this = shift;

    my $ems = join( ',',
        $this->{session}->{users}->getEmails( $this->{session}->{user} ) );
    my $user = Foswiki::Func::getWikiName();
    $this->assert_str_equals( $ems, Foswiki::Func::wikiToEmail($user) );

    return;
}

sub test_normalizeWebTopicName {
    my $this = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my ( $w, $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web', 'Topic' );
    $this->assert_str_equals( 'Web',   $w );
    $this->assert_str_equals( 'Topic', $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', 'Topic' );
    $this->assert_str_equals( $Foswiki::cfg{HomeWebName}, $w );
    $this->assert_str_equals( 'Topic',                    $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', '' );
    $this->assert_str_equals( $Foswiki::cfg{HomeWebName}, $w );
    $this->assert_str_equals( 'WebHome',                  $t );
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

    ( $w, $t ) =
      Foswiki::Func::normalizeWebTopicName( '', 'Sandbox.ALLOWTOPICCHANGE' );
    $this->assert_str_equals( 'Sandbox',          $w );
    $this->assert_str_equals( 'ALLOWTOPICCHANGE', $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', 'ALLOWTOPICCHANGE' );
    $this->assert_str_equals( $Foswiki::cfg{HomeWebName}, $w );
    $this->assert_str_equals( 'ALLOWTOPICCHANGE',         $t );

    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( '', 'Web.' );
    $this->assert_str_equals( 'Web',     $w );
    $this->assert_str_equals( 'WebHome', $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web1', 'Web2.' );
    $this->assert_str_equals( 'Web2',    $w );
    $this->assert_str_equals( 'WebHome', $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web1', 'Web2.Web3.' );
    $this->assert_str_equals( 'Web2/Web3', $w );
    $this->assert_str_equals( 'WebHome',   $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web1', 'Web2/Web3/' );
    $this->assert_str_equals( 'Web2/Web3', $w );
    $this->assert_str_equals( 'WebHome',   $t );
    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web1', 'Web2/' );
    $this->assert_str_equals( 'Web2',    $w );
    $this->assert_str_equals( 'WebHome', $t );

    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web1', 'Web2.look' );
    $this->assert_str_equals( 'Web2', $w );
    $this->assert_str_equals( 'look', $t );

    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web1', 'Web2~look' );
    $this->assert_str_equals( 'Web1',      $w );
    $this->assert_str_equals( 'Web2~look', $t );

    ( $w, $t ) = Foswiki::Func::normalizeWebTopicName( 'Web1', 'Web2.j~look' );
    $this->assert_str_equals( 'Web2',   $w );
    $this->assert_str_equals( 'j~look', $t );

    return;
}

sub test_checkWebAccessPermission {
    my $this = shift;

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );

    Foswiki::Func::saveTopicText( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<"HERE");
\t* Set DENYWEBCHANGE = $Foswiki::cfg{DefaultUserWikiName}
HERE

    Foswiki::Func::saveTopicText( $this->{test_web}, 'WeeblesWobble', <<"HERE");
\t* Set ALLOWTOPICCHANGE = $Foswiki::cfg{DefaultUserWikiName}
HERE

    $this->createNewFoswikiSession();

    # Test with undefined topic - web permissions tested
    my $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, undef, $this->{test_web} );
    $this->assert($access);

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
    $this->assert($access);

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
    $this->assert($access);

    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, 'WeeblesWobble', $this->{test_web} );
    $this->assert($access);

    # Test with invalid topic - web permissions applied (Item2380)
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, 'WibblesWobble', $this->{test_web} );
    $this->assert($access);

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
    $this->assert($access);

    # Test for null web name, default to Users web (Main)
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, 'WibblesWobble', '' );
    $this->assert($access);

    # Test for simple tainted topic name
    my $taintedTopic = 'WeeblesWobble';
    $taintedTopic = Assert::TAINT($taintedTopic);
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, $taintedTopic, $this->{test_web} );
    $this->assert($access);

    # Test with illegal, tainted topic name.
    #  - Untainting the name detects the illegal characters.
    $taintedTopic = 'Weebles!@#$%^&**(())__+Wobble';
    $taintedTopic = Assert::TAINT($taintedTopic);
    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, $taintedTopic, $this->{test_web} );
    $this->assert( !$access );

    return;
}

sub test_checkAccessPermission {
    my $this  = shift;
    my $topic = "NoWayJose";

    Foswiki::Func::saveTopicText(
        $this->{test_web}, $topic, <<"END",
\t* Set DENYTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}
END
    );
    $this->createNewFoswikiSession();
    my $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        undef, $topic, $this->{test_web} );
    $this->assert( !$access );    # no access because the text says DENY

    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', $topic, $this->{test_web} );
    $this->assert( !$access );    # no access still

    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        0, $topic, $this->{test_web} );
    $this->assert( !$access );    # no access still

    $access = Foswiki::Func::checkAccessPermission(
        'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        "Please me, let me go",
        $topic, $this->{test_web}
    );

    # Supplied text should override text from topic
    $this->assert($access)
      ;    # the text has been removed temporarily, so guest has got access now

    # make sure meta overrides text, as documented - Item2953
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
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
    $this->assert($access)
      ;    # got access now as META's ALLOW overrides the text's ALLOW

    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
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
    $meta->finish();
    $this->assert( !$access );    # no access as META overrides text

    #I'm not clear from the docco so...
    #what happens if we check the perms on a topic that doesn't exist.
    #first up on a web we can write to
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', $this->{test_web} );
    $this->assert($access);

    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', $this->{test_web} );
    $this->assert($access);

    $access =
      Foswiki::Func::checkAccessPermission( 'DONTTHINGTHEREISSUCHAPERM',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'System' );
    $this->assert($access);

    #next System, which we shouldn't be able to write to
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'System' );
    $this->assert($access);

    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'System' );
    $this->assert( !$access );

    $access =
      Foswiki::Func::checkAccessPermission( 'DONTTHINGTHEREISSUCHAPERM',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'System' );
    $this->assert($access);

    # next _default, which Sven Dowideit thinks we shouldn't be able to view,
    # but CDot can't see any good reason for that as restriction, given that
    # the permissions in that web allow it. Test checks CDot's view.
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', '_default' );
    $this->assert($access);

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
    $this->assert($access);

    #next NonExistantWeb, which doesn't exist
    # If a web doesn't exist, then there is no WebPreferences and
    # access controls come from the parent web, or the site access
    # controls. Just because a web doesn't exist doesn't mean an access
    # control check should fail.
    $access =
      Foswiki::Func::checkAccessPermission( 'VIEW',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'NonExistantWeb' );
    $this->assert($access);

    $access =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'NonExistantWeb' );
    $this->assert($access);

    $access =
      Foswiki::Func::checkAccessPermission( 'DONTTHINGTHEREISSUCHAPERM',
        $Foswiki::cfg{DefaultUserWikiName},
        '', 'NoSuchTopicPleaseDontMakeIt', 'NonExistantWeb' );
    $this->assert($access);

    return;
}

sub test_checkAccessPermission_login_name {
    my $this  = shift;
    my $topic = "NoWayJose";

    Foswiki::Func::saveTopicText(
        $this->{test_web}, $topic, <<"END",
\t* Set DENYTOPICVIEW = $Foswiki::cfg{DefaultUserWikiName}
END
    );
    $this->createNewFoswikiSession();
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
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
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
    $this->assert($access);  # ACCESS as META's ALLOW overrides the text's ALLOW

    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
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
    $meta->finish();

    return;
}

sub test_getExternalResource {
    my $this = shift;

    # need a known, simple, robust URL to get
    my $response = Foswiki::Func::getExternalResource(
        'http://foswiki.org/System/FAQWhatIsWikiWiki');
    $this->assert_equals( 200, $response->code() );
    $this->assert_matches(
qr/A set of pages of information that are open and free for anyone to edit as they wish. They are stored in a server and managed using some software. The system creates cross-reference hyperlinks between pages automatically./s,
        $response->content()
    );
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

#examples of perl insanity (inspired by Item10324, Sven thought he'd add a few tests to show what Foswiki::isTrue actually does')
    $this->assert_equals( 1, Foswiki::Func::isTrue('onon') );
    $this->assert_equals( 1, Foswiki::Func::isTrue('truetrue') );
    $this->assert_equals( 1, Foswiki::Func::isTrue('11') );
    $this->assert_equals( 0, Foswiki::Func::isTrue('offoff') );
    $this->assert_equals( 0, Foswiki::Func::isTrue('falsefalse') );
    $this->assert_equals( 1, Foswiki::Func::isTrue('00') );

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

    return;
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
$lt()()$n()()$gt()()
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
<()
()>()
TEST

    #"
    my $output = Foswiki::Func::decodeFormatTokens($input);
    $this->assert_str_equals( $expected, $output );

    return;
}

sub test_eachChangeSince {
    my $this = shift;
    $Foswiki::cfg{Store}{RememberChangesFor} = 5;    # very bad memory

    require Foswiki::Users::BaseUserMapping;
    my $user1 = $Foswiki::cfg{DefaultUserLogin};
    my $user2 = $this->{session}->{users}->findUserByWikiName("ScumBag")->[0];

    sleep(1);    # to move into a new time step
    my $start = time();

    $this->createNewFoswikiSession($user1);
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, "ClutterBuck" );
    $meta->text("One");
    $meta->save();

    $this->createNewFoswikiSession($user2);
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, "PiggleNut" );
    $meta->text("One");
    $meta->save();

    # Wait a second
    sleep(1);
    my $mid = time();

    $this->createNewFoswikiSession($user2);
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, "ClutterBuck" );
    $meta->text("One");
    $meta->save();

    $this->createNewFoswikiSession($user1);
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, "PiggleNut" );
    $meta->text("Two");
    $meta->save();
    $meta->finish();

    my $change;
    my $it = Foswiki::Func::eachChangeSince( $this->{test_web}, $start );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 2, $change->{revision} );
    $this->assert_equals( $Foswiki::cfg{DefaultUserWikiName}, $change->{user} );
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
    $this->assert_equals( 1, $change->{revision} );
    $this->assert_equals( $Foswiki::cfg{DefaultUserWikiName}, $change->{user} );
    $this->assert( !$it->hasNext() );

    $it = Foswiki::Func::eachChangeSince( $this->{test_web}, $mid );
    $this->assert( $it->hasNext() );
    $change = $it->next();
    $this->assert_str_equals( "PiggleNut", $change->{topic} );
    $this->assert_equals( 2, $change->{revision} );
    $this->assert_equals( $Foswiki::cfg{DefaultUserWikiName}, $change->{user} );
    $change = $it->next();
    $this->assert_str_equals( "ClutterBuck", $change->{topic} );
    $this->assert_equals( 2,         $change->{revision} );
    $this->assert_equals( 'ScumBag', $change->{user} );

    $this->assert( !$it->hasNext() );

    return;
}

# Check consistency between getListofWebs and webExists
sub test_4308 {
    my $this = shift;
    my @list = Foswiki::Func::getListOfWebs('user');
    foreach my $web (@list) {
        $this->assert_does_not_match( qr#^_|\/_#, $web,
            "template web returned as user web from Func\n" );
        $this->assert( Foswiki::Func::webExists($web), $web );
    }
    @list = Foswiki::Func::getListOfWebs('user public');
    foreach my $web (@list) {
        $this->assert_does_not_match( qr#^_|\/_#, $web,
            "template web returned as user web from Func\n" );
        $this->assert( Foswiki::Func::webExists($web), $web );
    }
    @list = Foswiki::Func::getListOfWebs('template');
    foreach my $web (@list) {
        $this->assert_matches( qr#^_|\/_#, $web,
            "non-template web returned as template from Func\n" );
        $this->assert( Foswiki::Func::webExists($web), $web );
    }
    @list = Foswiki::Func::getListOfWebs('public template');
    foreach my $web (@list) {
        $this->assert( Foswiki::Func::webExists($web), $web );
    }

    return;
}

sub test_4411 {
    my $this = shift;
    $this->assert( Foswiki::Func::isGuest(), $this->{session}->{user} );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
    $this->assert( !Foswiki::Func::isGuest(), $this->{session}->{user} );

    return;
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
        $Foswiki::cfg{WebPrefsTopicName}, <<'HERE');
   * Set PSIBG = naff
   * Set FINALPREFERENCES = PSIBG
HERE
    $this->createNewFoswikiSession( $Foswiki::cfg{GuestUserLogin}, $q );
    $this->assert_str_equals( "naff",
        Foswiki::Func::getPreferencesValue("PSIBG") );
    Foswiki::Func::setPreferencesValue( "PSIBG", "KJHD" );
    $this->assert_str_equals( "naff",
        Foswiki::Func::getPreferencesValue("PSIBG") );
    ###
    Foswiki::Func::saveTopicText( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<'HERE');
   * Set PSIBG = naff
HERE
    $this->createNewFoswikiSession( $Foswiki::cfg{GuestUserLogin}, $q );
    $this->assert_str_equals( "naff",
        Foswiki::Func::getPreferencesValue("PSIBG") );
    Foswiki::Func::setPreferencesValue( "PSIBG", "KJHD" );
    $this->assert_str_equals( "KJHD",
        Foswiki::Func::getPreferencesValue("PSIBG") );

    return;
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

    return;
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
    $this->assert_null(
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

    return;
}

sub test_getAttachmentList {
    my $this = shift;

    my $shortname = "testfile.gif";
    my $filename  = "$Foswiki::cfg{TempfileDir}/$shortname";
    $this->write_file( $filename, "Naff\n" );
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $meta->text("One");
    $meta->attach(
        name    => $shortname,
        file    => $filename,
        comment => "a comment"
    );
    $meta->save();
    $meta->finish();
    unlink $filename;
    my @list =
      Foswiki::Func::getAttachmentList( $this->{test_web},
        $this->{test_topic} );
    my $list = join( ' ', @list );
    $this->assert_str_equals( $shortname, $list );

    return;
}

sub test_searchInWebContent {
    my $this = shift;

    my $matches =
      Foswiki::Func::searchInWebContent( "broken", 'System', undef,
        { casesensitive => 0, files_without_match => 0 } );
    my @topics = keys( %{$matches} );
    $this->assert( $#topics > 1 )
      ;    #gosh i hope we alway have a document with the word broken in it..
    my ( $web, $searchTopic ) =
      Foswiki::Func::normalizeWebTopicName( '', $topics[0] );

    #its supposed to return a list of topics, not web.topics.
    $this->assert_str_equals( $searchTopic, $topics[0] );

    return;
}

sub test_query {
    my $this = shift;

    my $matches = Foswiki::Func::query( "text ~ '*broken*'",
        undef,
        { web => 'System', casesensitive => 0, files_without_match => 0 } );

    $this->assert( $matches->hasNext )
      ;    #gosh i hope we alway have a document with the word broken in it..
    my $webtopic = $matches->next;
    my ( $web, $searchTopic ) =
      Foswiki::Func::normalizeWebTopicName( '', $webtopic );

    #its supposed to return web.topics.
    $this->assert_str_equals( "$web.$searchTopic", $webtopic );

    return;
}

sub test_pushPopContext {
    my $this   = shift;
    my $topic1 = "DanTien";
    my $topic2 = "SandWich";

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic1, <<'SETS' );
   * Set ICE = COLD
SETS

    # Force re-read of prefs
    $this->createNewFoswikiSession( undef,
        Unit::Request->new( { topic => "$this->{test_web}.$topic1" } ) );

    Foswiki::Func::saveTopicText( $this->{test_web}, $topic2, <<'SETS' );
   * Set ICE = SLIPPERY
SETS

    $this->assert_equals( $this->{test_web}, $this->{session}->{webName} );
    $this->assert_equals( $topic1,           $this->{session}->{topicName} );
    $this->assert_equals( $this->{test_web},
        Foswiki::Func::getPreferencesValue('BASEWEB') );
    $this->assert_equals( $topic1,
        Foswiki::Func::getPreferencesValue('BASETOPIC') );
    $this->assert_equals( $this->{test_web},
        Foswiki::Func::getPreferencesValue('INCLUDINGWEB') );
    $this->assert_equals( $topic1,
        Foswiki::Func::getPreferencesValue('INCLUDINGTOPIC') );
    $this->assert_equals( "COLD", Foswiki::Func::getPreferencesValue('ICE') );

    Foswiki::Func::pushTopicContext( $this->{test_web}, $topic2 );

    $this->assert_equals( $this->{test_web}, $this->{session}->{webName} );
    $this->assert_equals( $topic2,           $this->{session}->{topicName} );
    $this->assert_equals( $this->{test_web},
        Foswiki::Func::getPreferencesValue('BASEWEB') );
    $this->assert_equals( $topic2,
        Foswiki::Func::getPreferencesValue('BASETOPIC') );
    $this->assert_equals( $this->{test_web},
        Foswiki::Func::getPreferencesValue('INCLUDINGWEB') );
    $this->assert_equals( $topic2,
        Foswiki::Func::getPreferencesValue('INCLUDINGTOPIC') );
    $this->assert_equals( "SLIPPERY",
        Foswiki::Func::getPreferencesValue('ICE') );

    Foswiki::Func::popTopicContext();

    $this->assert_equals( $this->{test_web}, $this->{session}->{webName} );
    $this->assert_equals( $topic1,           $this->{session}->{topicName} );
    $this->assert_equals( $this->{test_web},
        Foswiki::Func::getPreferencesValue('BASEWEB') );
    $this->assert_equals( $topic1,
        Foswiki::Func::getPreferencesValue('BASETOPIC') );
    $this->assert_equals( $this->{test_web},
        Foswiki::Func::getPreferencesValue('INCLUDINGWEB') );
    $this->assert_equals( $topic1,
        Foswiki::Func::getPreferencesValue('INCLUDINGTOPIC') );
    $this->assert_equals( "COLD", Foswiki::Func::getPreferencesValue('ICE') );

    return;
}

sub test_writeEvent {
    my $this = shift;
    my $now  = time();
    Foswiki::Func::writeEvent( "cereal", "milk" );
    require Time::HiRes;
    Time::HiRes::sleep(0.25) while ( time() == $now );
    $now = time();
    Foswiki::Func::writeEvent( "sausage", "eggs" );
    Foswiki::Func::writeEvent("bacon");
    Foswiki::Func::writeEvent();
    Foswiki::Func::writeEvent( "toast", "jam" );
    my $it = Foswiki::Func::eachEventSince($now);
    $this->assert( $it->hasNext() );
    my $e = $it->next();
    $this->assert_equals( $now,      $e->[0] );
    $this->assert_equals( 'sausage', $e->[2] );
    $this->assert_equals( 'eggs',    $e->[4] );
    $e = $it->next() while ( $it->hasNext() && $e->[2] ne 'bacon' );
    $e = $it->next() while ( $it->hasNext() && $e->[2] ne '' );
    $e = $it->next() while ( $it->hasNext() && $e->[2] ne 'toast' );
    $this->assert_equals( 'jam', $e->[4] );

    return;
}

sub test_loadTemplate {
    my $this = shift;
    my $view = Foswiki::Func::loadTemplate('view');
    $this->assert( length($view) );
    my $print = Foswiki::Func::loadTemplate( 'view', 'print' );
    $this->assert( length($print) );
    $this->assert( $print ne $view );
    $this->assert_str_equals( '', Foswiki::Func::loadTemplate('crud') );

    return;
}

sub test_readTemplate {
    my $this = shift;
    my $view = Foswiki::Func::readTemplate('view');
    $this->assert( length($view) );
    my $print = Foswiki::Func::readTemplate( 'view', 'print' );
    $this->assert( length($print) );
    $this->assert( $print ne $view );
    $this->assert_str_equals( '', Foswiki::Func::readTemplate('crud') );

    return;
}

# Test that we can attach a file named with unicode chars.
sub DISABLEDtest_unicode_attachment {
    my ($this) = @_;

    $this->assert( utf8::is_utf8($uniname),
        "Our attachment name '$uniname' doesn\'t have utf8 flag set" );
    $this->assert( utf8::is_utf8($uniname),
        "Our attachment comment '$unicomment' doesn\'t have utf8 flag set" );
    $this->do_attachment( $uniname, $unicomment );

    return;
}

# Test that we can attach a file named with unicode chars.
sub test_unicode_attachment_utf8_encoded {
    my ($this) = @_;

    $this->assert( utf8::is_utf8($uniname),
        "The attachment name '$uniname' doesn\'t have utf8 flag set" );
    $this->assert( utf8::is_utf8($uniname),
        "The attachment comment '$unicomment' doesn\'t have utf8 flag set" );

    $this->do_attachment( $uniname, $unicomment );

    return;
}

sub do_attachment {
    my ( $this, $name, $comment ) = @_;

    my $query;
    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $stream;

    require Unit::Request;
    $query = Unit::Request->new("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->createNewFoswikiSession( undef, $query );
    $this->{request}  = $query;
    $this->{response} = Unit::Response->new();
    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->{test_topicObject}->text("BLEEGLE\n");
    $this->{test_topicObject}->save();

    $stream =
      $this->write_file( $this->{tmpdatafile}, $data,
        { binmode => 1, read => 1 } );

    my $e = Foswiki::Func::saveAttachment(
        $this->{test_web},
        $this->{test_topic},
        $name,
        {
            comment  => $comment,
            stream   => $stream,
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
        }
    );
    $this->assert( !$e, $e );

    # See also: RobustnessTests::test_sanitizeAttachmentNama_unicode
    my ($sanitized) = Foswiki::Sandbox::sanitizeAttachmentName($name);
    $this->assert_str_equals( $name, $sanitized );

    if ( $Foswiki::cfg{Store}{Implementation} =~ /PlainFile|Rcs/ ) {
        require File::Spec;
        $this->assert(
            -f File::Spec->catfile(
                File::Spec->splitdir( $Foswiki::cfg{PubDir} ),
                $this->{test_web}, $this->{test_topic}, $name
            )
        );
    }
    my $itr = $this->{test_topicObject}->eachAttachment();
    $this->assert( $itr->hasNext() );

# Item11185: Foswiki::Meta/store aren't returning strings with utf8 flag set, so our test fails from here on down
    $this->assert_str_equals( $name, $itr->next() );

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my @attachments = $meta->find('FILEATTACHMENT');
    $meta->finish();

    $this->assert( $name eq $attachments[0]->{name},
        "Got $attachments[0]->{name}  but expected $name " );
    $this->assert_str_equals( $comment, $attachments[0]->{comment} );

    my $x =
      Foswiki::Func::readAttachment( $this->{test_web}, $this->{test_topic},
        $name );
    $this->assert_str_equals( $data, $x );

    # This should succeed - attachment exists
    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, $name
        )
    );

    return;
}

sub _save_config {
    my ($this) = @_;

    $this->{_backup_config} = \%Foswiki::cfg;

    return;
}

sub _restore_config {
    my ($this) = @_;

    %Foswiki::cfg = %{ $this->{_backup_config} };

    return;
}

sub _test_path_func {
    my ( $this, $func, $junk ) = @_;

    $this->assert( ref($func) eq 'CODE' );
    $junk ||= '';
    $this->_save_config();
    $Foswiki::cfg{ScriptUrlPath} = '/path/to/bin';
    delete $Foswiki::cfg{ScriptUrlPaths};
    print "Testing no args\n" if TRACE;
    $this->assert_str_equals( $junk . '/path/to/bin', $func->() );
    print "Testing script only\n" if TRACE;
    $this->assert_str_equals( $junk . '/path/to/bin/save',
        $func->( undef, undef, 'save' ) );
    print "Testing script/Web/Topic\n" if TRACE;
    $this->assert_str_equals(
        $junk . '/path/to/bin/save/Web/Topic',
        $func->( 'Web', 'Topic', 'save' )
    );

    foreach my $test (@scripturl_tests) {
        $Foswiki::cfg{ScriptUrlPath} = '/path/to/bin';
        delete $Foswiki::cfg{ScriptUrlPaths};
        if ( $test->{cfg} ) {
            %Foswiki::cfg = ( %Foswiki::cfg, %{ $test->{cfg} } );
        }

        #$this->createNewFoswikiSession();
        while ( my ( $script, $path ) = each %{ $test->{expected} } ) {
            my $expected_path = $junk . $path . '/Web/Topic';
            my $actual_path = $func->( 'Web', 'Topic', $script );

            if (TRACE) {
                require Data::Dumper;
                print "Testing script '$script' with ScriptUrlPaths: "
                  . Data::Dumper->Dump( [ $Foswiki::cfg{ScriptUrlPaths} ] );
                print "\tExpected: '$expected_path', got: '$actual_path'\n";
            }
            $this->assert_str_equals( $expected_path, $actual_path );
        }
        if ( $test->{cfg} ) {
            $this->_restore_config();
        }
    }
    $this->_restore_config();

    return;
}

sub test_getScriptUrl_spec {
    my ($this) = @_;

    $this->_test_path_func( \&Foswiki::Func::getScriptUrl,
        $Foswiki::cfg{DefaultUrlHost} );

    return;
}

sub test_getScriptUrlPath_spec {
    my ($this) = @_;

    $this->_test_path_func( \&Foswiki::Func::getScriptUrlPath );

    return;
}

# Verify that saveTopicText uses embedded meta
sub test_saveTopicTextEmbeddedMeta {
    my $this = shift;

    # Only works on filesystem based stores
    return unless ( $Foswiki::cfg{Store}{Implementation} =~ /PlainFile|Rcs/ );

    my $topic    = 'SaveTopicText2';
    my $origtext = <<'NONNY';
%META:TOPICINFO{author="BaseUserMapping_123" comment="save topic" date=".*?" format="1.1" reprev="1" version="1"}%
'Tis some text

Sïṁîḻīqųē éț äůț ąśśùṁěṅďă

Sêqui dòĺórém ḟụģìt molļîṫīã òmnis. Sụṅť quãsí ręṗudịanđae õćcåęcatï ṁołlitia įṗšam. Hic fuga iurë ėarum qŭo arcĥīťèctò. Aütem nątüṡ ḃëàtãe ęț eaqųë. Rėrụṁ êā répřehëṅdeřïť āĺiqŭám ēšť bêătâe eă deḃitis omnīs. Añimi vįțaê volụṗṫaṫëṁ ofḟiĉiis. Ađipiscį ḋóĺõřęmqùe éṫ vọlüptatụṁ. Práèşēntiuṁ ęiuș ḟačere eṫ esț cörrŭpțị àțquè. Nôstruṁ esť ïṁṗeďïț ařchïtęçțø dïģnissiṁóś pêrḟeŕeṉdis. Súscïpiť oṁṅis ęxĉepturi ãd ṉïĥįļ oḟfičia oṁnis ñám acčusàńťiům.
Siť vołupťäțùm ṡụšcïṗìt řérúṁ eñíṁ ët qúia võlŭptåțem. Istė eòŝ veŕo ṫęṁṗóre qűia nihiľ ařċhìtêctọ døľořěṁquë. Quì asperṉățúr dișțínćtio ņọn. Tøtàm ēűm şapiėṉťě ńëquè mõļėștiäe īđ ēt eoś ṗérḟèreṉdiŝ. Suňt qui undē sūnt voluptäș åspêrnåtűr nequė ëlïgëndị quï. Et diĝníšșimos ċulṗa pāřįáťűř üt nuṁquâm. Harŭm ċoṅšéqŭaṫuř voļűṗťãṡ aċćuşamuş rąțìonė ḃeatäė. Añimî éx ćoṅsêċtetúŕ âlīqųîḋ îṅ řatįoņé. Eṫ šéd iuşṫo ćónseqụațuř ēt eť recuṡandäe.

and a trailing newline

%META:FORM{name="TestForm"}%
%META:FIELD{name="FORM" title="Blah" value="FORM GOOD"}%
%META:FILEATTACHMENT{name="IMG_0608.JPG" attr="" autoattached="1" comment="A Comment" date="1162233146" size="762004" user="Main.AUser" version="1"}%
NONNY

    #'
    Foswiki::Func::saveTopicText( $this->{test_web}, $topic, $origtext );
    my $rawtext = Foswiki::Func::readFile(
        $Foswiki::cfg{DataDir} . '/' . $this->{test_web} . "/$topic.txt", 1 );
    $this->assert_str_not_equals( $origtext, $rawtext );

    my $readtext = Foswiki::Func::readTopicText( $this->{test_web}, $topic );

    #lets start by making sure that the readTopic == what is on disk
    $this->assert_str_equals( $rawtext, $readtext );

    my @orig_metas;
    $origtext =~ s/^(\%META:[^}]*}%)/push(@orig_metas, $1)/gems;

    #print STDERR "\n   orig  ".join("\n   * ", @orig_metas)."\n";
    $this->assert_equals( 4, scalar(@orig_metas) );
    my @raw_metas;

    $rawtext =~ s/^(\%META:[^}]*}%)/push(@raw_metas, $1)/gems;

    #print STDERR "\n   raw  ".join("\n   * ", @raw_metas)."\n";
    #in 1.0.10 the FILEATTACHMENT is removed - presumably because the
    # file is not there?
    #in 1.1 the FILEATTACHMENT is kept - frustrating.
    #TODO: check this
    $this->assert_equals( 4, scalar(@raw_metas) );

    #TOPICINFO from commit
    # make sure that the save changed the topicinfo (this is the 1.1.0
    # introduced bug (fixed in 1.1.4) where by we use the TOPICINFO passed
    # to saveTopicText literally, without recording who actually called save)
    $this->assert_str_not_equals( shift @orig_metas, shift @raw_metas );

    #FORM
    $this->assert_str_equals( shift @orig_metas, shift @raw_metas );

    #FIELD
    $this->assert_str_equals( shift @orig_metas, shift @raw_metas );

    #leaving only the FILEATTACHMENT
    $this->assert_str_equals( shift @orig_metas, shift @raw_metas );

    #$this->assert_matches(qr/FILEATTACHMENT/, shift @orig_metas);
    $this->assert_equals( 0, scalar(@raw_metas) );
    $this->assert_equals( 0, scalar(@orig_metas) );

    my ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );

    #make sure that the save extracted the META:
    $this->assert_does_not_match( qr/%META/, $text );

    return;
}

sub test_getUrlHost {
    my ($this) = @_;

    my $query;

    require Unit::Request;
    $query = Unit::Request->new("");

    #$query->path_info("/$this->{test_web}/$this->{test_topic}");
    $Foswiki::cfg{DefaultUrlHost}      = 'http://foswiki.org';
    $Foswiki::cfg{ForceDefaultUrlHost} = 0;

    # always use the request's url
    $query->setUrl('http://localhost/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( 'http://localhost', Foswiki::Func::getUrlHost() );

    $query->setUrl('http://localhost:8080/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( 'http://localhost:8080',
        Foswiki::Func::getUrlHost() );

    $query->setUrl('https://localhost/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( 'https://localhost',
        Foswiki::Func::getUrlHost() );

    $query->setUrl('https://localhost:8080/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( 'https://localhost:8080',
        Foswiki::Func::getUrlHost() );

    $Foswiki::cfg{RemovePortNumber} = 1;
    $query->setUrl('http://localhost:8080/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( 'http://localhost', Foswiki::Func::getUrlHost() );

    $query->setUrl('https://localhost:8080/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( 'https://localhost',
        Foswiki::Func::getUrlHost() );

    return;
}

# Item11900 Force override to DefaultUrlHost
sub test_getUrlHost_ForceDefaultUrlHost {
    my ($this) = @_;

    my $query;

    require Unit::Request;
    $query = Unit::Request->new("");

    $Foswiki::cfg{DefaultUrlHost}      = 'http://foswiki.org';
    $Foswiki::cfg{ForceDefaultUrlHost} = 1;

    $query->setUrl('http://localhost/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( $Foswiki::cfg{DefaultUrlHost},
        Foswiki::Func::getUrlHost() );

    $query->setUrl('http://localhost:8080/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( $Foswiki::cfg{DefaultUrlHost},
        Foswiki::Func::getUrlHost() );

    $query->setUrl('https://www.foswiki.org/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( $Foswiki::cfg{DefaultUrlHost},
        Foswiki::Func::getUrlHost() );

    $query->setUrl('https:8443//www.foswiki.org/Main/AdminUser');
    $this->createNewFoswikiSession( undef, $query );
    $this->assert_str_equals( $Foswiki::cfg{DefaultUrlHost},
        Foswiki::Func::getUrlHost() );

}

1;
