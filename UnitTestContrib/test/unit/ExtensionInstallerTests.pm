package ExtensionInstallerTests;

use strict;
use warnings;

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Error qw( :try );
use File::Temp();
use FindBin;
use File::Path qw(mkpath rmtree);

use Foswiki::Configure::FileUtil ();
use Foswiki::Configure::Package  ();
use Foswiki::Configure::Reporter ();

use Foswiki::Sandbox;

my $reporter;

sub skip {
    my ( $this, $test ) = @_;

    return $this->SUPER::skip_test_if(
        $test,
        {
            condition => { without_dep => 'Archive::Tar' },
            tests     => {
                'ConfigureTests::test_Util_createArchive_perlTar' =>
                  'Missing Archive::Tar'
            }
        },
        {
            condition => { without_dep => 'Archive::Zip' },
            tests     => {
                'ConfigureTests::test_Util_createArchive_perlZip' =>
                  'Missing Archive::Zip'
            }
        }
    );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    # tests assume RCS
    $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsLite';

    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;
    $root =~ s|\\|/|g;

    $this->{rootdir} = $root;
    $this->{user}    = $Foswiki::cfg{AdminUserLogin};
    $this->createNewFoswikiSession( $this->{user} );
    $this->{test_web} = 'Testsystemweb1234';
    my $webObject = $this->populateNewWeb( $this->{test_web} );
    $webObject->finish();
    $this->{trash_web} = 'Testtrashweb1234';
    $webObject = $this->populateNewWeb( $this->{trash_web} );
    $webObject->finish();
    $this->{sandbox_web} = 'Testsandboxweb1234';
    $webObject = $this->populateNewWeb( $this->{sandbox_web} );
    $webObject->finish();
    $this->{sandbox_subweb} = 'Testsandboxweb1234/Subweb';
    $webObject = $this->populateNewWeb( $this->{sandbox_subweb} );
    $webObject->finish();
    $this->{tempdir} = $Foswiki::cfg{TempfileDir} . '/test_ConfigureTests';
    rmtree( $this->{tempdir} )
      if ( -e $this->{tempdir} );    # Cleanup any old tests
    mkpath( $this->{tempdir} );
    $this->{scriptdir}       = $this->{tempdir} . '/bin';
    $Foswiki::cfg{ScriptDir} = $this->{scriptdir};
    $this->{toolsdir}        = $this->{tempdir} . '/tools';
    $Foswiki::cfg{ToolsDir}  = $this->{toolsdir};
    $this->{logdir}          = $this->{tempdir} . '/logs';
    $Foswiki::cfg{Log}{Dir}  = $this->{logdir};

    $Foswiki::cfg{TrashWebName}   = $this->{trash_web};
    $Foswiki::cfg{SandboxWebName} = $this->{sandbox_web};

    $reporter = Foswiki::Configure::Reporter->new();

    return;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $this->{test_web} );
    $this->removeWebFixture( $this->{session}, $this->{trash_web} );
    $this->removeWebFixture( $this->{session}, $this->{sandbox_web} );
    eval { rmtree( $this->{tempdir} ) };    # Cleanup any old tests
    $this->SUPER::tear_down();

    return;
}

sub sniff {
    my ( $this, @what ) = @_;

    if ( scalar @what ) {

        # Expected error
        my $messages = $reporter->messages();
        my $mi       = 0;
        while ( scalar @what ) {
            my $level = shift @what;
            my $re    = shift @what;
            my $found = 0;
            while ( $mi < scalar(@$messages) ) {
                my $m = $messages->[ $mi++ ];
                if ( $m->{level} eq $level ) {
                    if ( $m->{text} =~ m/$re/s ) {
                        $found = 1;
                        last;
                    }
                }
            }
            $this->assert(
                0,
                "$level: $re\n *not seen* in:\n"
                  . join( "\n",
                    map { "$_->{level}: $_->{text}" }
                      grep { $_->{level} eq $level }
                      @{ $reporter->messages() } )
            ) unless $found;
        }
    }
    else {
        my $mess = '';
        foreach my $m ( @{ $reporter->messages() } ) {
            if ( $m->{level} eq 'errors' ) {
                $mess .= "\n$m->{text}";
            }
        }
        $this->assert( !$mess, $mess );
    }
}

#
#  Tests for _mapTarget (RootDir, Filename)
#

sub test_Util_mapTarget {

    my $this = shift;

    my $savePub    = $Foswiki::cfg{PubDir};
    my $saveData   = $Foswiki::cfg{DataDir};
    my $saveTools  = $Foswiki::cfg{ToolsDir};
    my $saveScript = $Foswiki::cfg{ScriptDir};
    my $saveSuffix = $Foswiki::cfg{ScriptSuffix};

    my $saveTrash   = $Foswiki::cfg{TrashWebName};
    my $saveSandbox = $Foswiki::cfg{SandboxWebName};
    my $saveUser    = $Foswiki::cfg{UsersWebName};
    my $saveSystem  = $Foswiki::cfg{SystemWebName};

    my $saveNotify = $Foswiki::cfg{NotifyTopicName};
    my $saveHome   = $Foswiki::cfg{HomeTopicName};
    my $savePrefs  = $Foswiki::cfg{WebPrefsTopicName};
    my $saveMime   = $Foswiki::cfg{MimeTypesFileName};

    $Foswiki::cfg{TrashWebName} = $this->{trash_web};
    $Foswiki::cfg{UsersWebName} = 'Main';

    # Verify file in root of pub

    my $file = 'pub/rootfile.gif';
    my $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "$this->{rootdir}pub/rootfile.gif", $results );

    # Verify file in root of data

    $file = 'data/mime.types';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "$this->{rootdir}data/mime.types", $results );

    # Remap system web

    $Foswiki::cfg{SystemWebName} = 'Fizbin';
    $file = 'pub/System/System/MyAtt.gif';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "$this->{rootdir}pub/Fizbin/System/MyAtt.gif",
        $results );

    $file = 'data/System/System.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "$this->{rootdir}data/Fizbin/System.txt",
        $results );

    # Remap data and pub directory names
    ############Note that in windows \var\www etc _is_ a valid path - it will go into the 'currently selected' drive

    $Foswiki::cfg{PubDir}  = '/var/www/foswiki/public';
    $Foswiki::cfg{DataDir} = '/var/www/foswiki/storage';

    $file = 'pub/Trash/Fizbin/Data.attachment';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/public/$this->{trash_web}/Fizbin/Data.attachment",
        $results );

    $file = 'data/Trash/Fizbin.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/storage/$this->{trash_web}/Fizbin.txt", $results );

    # Verify default Users and Main web names

    $Foswiki::cfg{PubDir}  = '/var/www/foswiki/public';
    $Foswiki::cfg{DataDir} = '/var/www/foswiki/storage';

    $file = 'pub/Users/Fizbin/asdf.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/public/Main/Fizbin/asdf.txt",
        $results );

    $file = 'data/Users/Fizbin.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Main/Fizbin.txt",
        $results );

    # Remap the UsersWebName

    $Foswiki::cfg{UsersWebName} = 'Blah';

    $file = 'pub/Main/Fizbin/Blah.gif';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/public/Blah/Fizbin/Blah.gif",
        $results );

    $file = 'data/Main/Fizbin.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Blah/Fizbin.txt",
        $results );

    # Remap the SandboxWebName

    $Foswiki::cfg{SandboxWebName} = 'Litterbox';

    $file = 'pub/Sandbox/Fizbin/Blah.gif';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/public/Litterbox/Fizbin/Blah.gif", $results );

    $file = 'data/Sandbox/Fizbin.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Litterbox/Fizbin.txt",
        $results );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap the SandboxWebName with Subweb

    $Foswiki::cfg{SandboxWebName} = 'Litterbox';

    $file = 'pub/Sandbox/Beta/Fizbin/Blah.gif';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/public/Litterbox/Beta/Fizbin/Blah.gif", $results );

    $file = 'data/Sandbox/Beta/Fizbin.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/storage/Litterbox/Beta/Fizbin.txt", $results );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  NotifyTopicName - default WebNotify

    $Foswiki::cfg{SandboxWebName} = 'Sandbox';

    $Foswiki::cfg{NotifyTopicName} = 'TellMe';
    $file = 'data/Sandbox/WebNotify.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Sandbox/TellMe.txt",
        $results );

    $file = 'pub/Sandbox/WebNotify/Blah.gif';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/public/Sandbox/TellMe/Blah.gif",
        $results );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  HomeTopicName - default WebHome

    $Foswiki::cfg{SandboxWebName} = 'Sandbox';

    $Foswiki::cfg{HomeTopicName} = 'HomePage';
    $file = 'data/Sandbox/WebHome.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Sandbox/HomePage.txt",
        $results );

    $file = 'pub/Sandbox/WebNotify/Blah.gif';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/public/Sandbox/TellMe/Blah.gif",
        $results );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  WebPrefsTopicName - default WebPreferences

    $Foswiki::cfg{WebPrefsTopicName} = 'Settings';
    $file = 'data/Sandbox/WebPreferences.txt';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/storage/$this->{sandbox_web}/Settings.txt",
        $results );

    $file = 'pub/Sandbox/WebPreferences/Logo.gif';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/public/$this->{sandbox_web}/Settings/Logo.gif",
        $results );

# Remap bin directory and script suffix -  WebPrefsTopicName - default WebPreferences

    $Foswiki::cfg{ScriptSuffix} = '.pl';
    $Foswiki::cfg{ScriptDir}    = 'C:/asdf/cgi-bin';
    $file                       = 'bin/compare';
    $results = Foswiki::Configure::Package::_mapTarget( "C:/asdf/", "$file" );
    $this->assert_str_equals( "C:/asdf/cgi-bin/compare.pl", $results );

    # Remap bin directory and script suffix -  Include spaces in the path

    $Foswiki::cfg{ScriptSuffix} = '.pl';
    $Foswiki::cfg{ScriptDir} =
'C:/Program Files (x86)/Apache Software Foundation/Apache2.2/cgi-bin/wiki/bin';
    $file    = 'bin/compare';
    $results = Foswiki::Configure::Package::_mapTarget(
'C:/Program Files (x86)/Apache Software Foundation/Apache2.2/cgi-bin/wiki/',
        "$file"
    );
    $this->assert_str_equals(
'C:/Program Files (x86)/Apache Software Foundation/Apache2.2/cgi-bin/wiki/bin/compare.pl',
        $results
    );

    # Remap the data/mime.types file location

    $Foswiki::cfg{MimeTypesFileName} = "$Foswiki::cfg{DataDir}/mymime.types";
    $file = 'data/mime.types';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/mymime.types",
        $results );

    $Foswiki::cfg{ToolsDir} = '/var/www/foswiki/stuff';
    $file = 'tools/testrun';
    $results =
      Foswiki::Configure::Package::_mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/stuff/testrun", $results );

    $Foswiki::cfg{PubDir}       = $savePub;
    $Foswiki::cfg{DataDir}      = $saveData;
    $Foswiki::cfg{ToolsDir}     = $saveTools;
    $Foswiki::cfg{ScriptDir}    = $saveScript;
    $Foswiki::cfg{ScriptSuffix} = $saveSuffix;

    $Foswiki::cfg{UsersWebName}   = $saveUser;
    $Foswiki::cfg{SystemWebName}  = $saveSystem;
    $Foswiki::cfg{TrashWebName}   = $saveTrash;
    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    $Foswiki::cfg{WebPrefsTopicName} = $savePrefs;
    $Foswiki::cfg{NotifyTopicName}   = $saveNotify;
    $Foswiki::cfg{HomeTopicName}     = $saveHome;
    $Foswiki::cfg{MimeTypesFileName} = $saveMime;

    return;
}

#
#  Tests for Configure::Package::_getMappedWebTopic (Filename)
#

sub test_Util_getMappedWebTopic {

    my $this = shift;

    my $saveTrash   = $Foswiki::cfg{TrashWebName};
    my $saveSandbox = $Foswiki::cfg{SandboxWebName};
    my $saveUser    = $Foswiki::cfg{UsersWebName};
    my $saveSystem  = $Foswiki::cfg{SystemWebName};

    my $saveNotify = $Foswiki::cfg{NotifyTopicName};
    my $saveHome   = $Foswiki::cfg{HomeTopicName};
    my $savePrefs  = $Foswiki::cfg{WebPrefsTopicName};
    my $saveMime   = $Foswiki::cfg{MimeTypesFileName};

    # Make sure local config has expected defaults
    $Foswiki::cfg{SystemWebName} = 'System';
    $Foswiki::cfg{UsersWebName}  = 'Main';

    $Foswiki::cfg{TrashWebName} = $this->{trash_web};

    my $wname = '';
    my $tname = '';

    # Remap system web
    my $file = 'data/System/System.txt';
    ( $wname, $tname ) =
      Foswiki::Configure::Package::_getMappedWebTopic("$file");
    $this->assert_str_equals( 'System', $wname );
    $this->assert_str_equals( 'System', $tname );

    $Foswiki::cfg{SystemWebName} = 'Fizbin';

    $file = 'data/System/System.txt';
    ( $wname, $tname ) =
      Foswiki::Configure::Package::_getMappedWebTopic("$file");
    $this->assert_str_equals( 'Fizbin', $wname );
    $this->assert_str_equals( 'System', $tname );

    # Verify default Users and Main web names

    $file = 'data/Users/Fizbin.txt';
    ( $wname, $tname ) =
      Foswiki::Configure::Package::_getMappedWebTopic("$file");
    $this->assert_str_equals( 'Main',   $wname );
    $this->assert_str_equals( 'Fizbin', $tname );

    # Remap the UsersWebName

    $Foswiki::cfg{UsersWebName} = 'Blah';

    $file = 'data/Main/Fizbin.txt';
    ( $wname, $tname ) =
      Foswiki::Configure::Package::_getMappedWebTopic("$file");
    $this->assert_str_equals( 'Blah',   $wname );
    $this->assert_str_equals( 'Fizbin', $tname );

    # Remap the SandboxWebName

    $Foswiki::cfg{SandboxWebName} = 'Litterbox';

    $file = 'data/Sandbox/Fizbin.txt';
    ( $wname, $tname ) =
      Foswiki::Configure::Package::_getMappedWebTopic("$file");
    $this->assert_str_equals( 'Litterbox', $wname );
    $this->assert_str_equals( 'Fizbin',    $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap the SandboxWebName with Subweb

    $Foswiki::cfg{SandboxWebName} = 'Litterbox';

    $file = 'data/Sandbox/Beta/Fizbin.txt';
    ( $wname, $tname ) =
      Foswiki::Configure::Package::_getMappedWebTopic("$file");
    $this->assert_str_equals( 'Litterbox/Beta', $wname );
    $this->assert_str_equals( 'Fizbin',         $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  NotifyTopicName - default WebNotify

    $Foswiki::cfg{SandboxWebName} = 'Sandbox';

    $Foswiki::cfg{NotifyTopicName} = 'TellMe';
    $file = 'data/Sandbox/WebNotify.txt';
    ( $wname, $tname ) =
      Foswiki::Configure::Package::_getMappedWebTopic("$file");
    $this->assert_str_equals( 'Sandbox', $wname );
    $this->assert_str_equals( 'TellMe',  $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  HomeTopicName - default WebHome

    $Foswiki::cfg{SandboxWebName} = 'Sandbox';

    $Foswiki::cfg{HomeTopicName} = 'HomePage';
    $file = 'data/Sandbox/WebHome.txt';
    ( $wname, $tname ) =
      Foswiki::Configure::Package::_getMappedWebTopic("$file");
    $this->assert_str_equals( 'Sandbox',  $wname );
    $this->assert_str_equals( 'HomePage', $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  HomeTopicName - with Subweb and mapped web

    $Foswiki::cfg{SandboxWebName} = 'WorkArea';
    $Foswiki::cfg{HomeTopicName}  = 'HomePage';
    $file                         = 'data/Sandbox/Testing/WebHome.txt';
    ( $wname, $tname ) =
      Foswiki::Configure::Package::_getMappedWebTopic("$file");
    $this->assert_str_equals( 'WorkArea/Testing', $wname );
    $this->assert_str_equals( 'HomePage',         $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;
    $Foswiki::cfg{HomeTopicName}  = $saveHome;

    # Remap topic names -  WebPrefsTopicName - default WebPreferences

    $Foswiki::cfg{SandboxWebName}    = 'Sandbox';
    $Foswiki::cfg{WebPrefsTopicName} = 'Settings';
    $file                            = 'data/Sandbox/WebPreferences.txt';
    ( $wname, $tname ) = Foswiki::Configure::Package::_getMappedWebTopic($file);
    $this->assert_str_equals( 'Sandbox',  $wname );
    $this->assert_str_equals( 'Settings', $tname );
    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Cleanup anything mapped above -

    $Foswiki::cfg{UsersWebName}   = $saveUser;
    $Foswiki::cfg{SystemWebName}  = $saveSystem;
    $Foswiki::cfg{TrashWebName}   = $saveTrash;
    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    $Foswiki::cfg{WebPrefsTopicName} = $savePrefs;
    $Foswiki::cfg{NotifyTopicName}   = $saveNotify;
    $Foswiki::cfg{HomeTopicName}     = $saveHome;
    $Foswiki::cfg{MimeTypesFileName} = $saveMime;

    return;
}

sub test_Util_listDir {
    my $this = shift;

    my $tempdir = $this->{tempdir} . '/test_Util_ListDir';
    eval { rmtree($tempdir) };    # Cleanup any old tests

    mkpath($tempdir);
    mkpath( $tempdir . "/asdf" );
    mkpath( $tempdir . "/asdf/qwerty" );

    _makefile( "$tempdir/asdf/qwerty", "test.txt", "asdfasdf \n" );

    my @dir = Foswiki::Configure::FileUtil::listDir("$tempdir");

    my $count = @dir;

    $this->assert_num_equals( 3, $count,
        "listDir returned incorrect number of directories" );
    $this->assert_str_equals( "asdf/qwerty/test.txt", pop @dir,
        "Wrong directory returned" );
    $this->assert_str_equals( "asdf/qwerty/", pop @dir,
        "Wrong directory returned" );
    $this->assert_str_equals( "asdf/", pop @dir, "Wrong directory returned" );

    _makefile( "$tempdir", "/asdf/qwerty/f~#asdf", "asdfasdf \n" );
    my ( $response, $result, $stdout ) = $this->capture(
        sub {
            @dir = Foswiki::Configure::FileUtil::listDir($tempdir);
        }
    );
    $this->assert_str_equals(
"WARNING: skipping possibly unsafe file (not able to show it for the same reason :( )<br />\n",
        $stdout
    );
    $this->assert_num_equals( 3, $count,
        "listDir returned incorrect number of directories" );

    eval { rmtree($tempdir) };

    @dir   = Foswiki::Configure::FileUtil::listDir("$tempdir");
    $count = @dir;
    $this->assert_num_equals( 0, $count,
"listDir returned incorrect number of directories for empty/missing directory"
    );

    return;
}

sub test_Util_getPerlLocation {
    my $this = shift;

    my $tempdir = $this->{tempdir} . '/test_util_getperllocation';
    mkpath($tempdir);

    my $holddir = $Foswiki::cfg{ScriptDir};
    $Foswiki::cfg{ScriptDir} = "$tempdir/";
    my $holdsfx = $Foswiki::cfg{ScriptSuffix};

    _doLocationTest( $this, $tempdir, '', '' )
      ;    # Test with missing bin/configure file

    _doLocationTest( $this, $tempdir, "#!/usr/bin/perl -w -T ",
        "/usr/bin/perl" );
    _doLocationTest( $this, $tempdir, "#!/usr/bin/perl  ",    "/usr/bin/perl" );
    _doLocationTest( $this, $tempdir, "#!/usr/bin/perl -wT ", "/usr/bin/perl" );
    _doLocationTest( $this, $tempdir, "#!/usr/bin/perl -wT",  "/usr/bin/perl" );
    _doLocationTest( $this, $tempdir, "#! /usr/bin/perl    -wT ",
        "/usr/bin/perl" );
    _doLocationTest( $this, $tempdir, "#! /usr/bin/perl -wT ",
        "/usr/bin/perl" );
    _doLocationTest( $this, $tempdir, "#! /usr/bin/perl", "/usr/bin/perl" );
    _doLocationTest( $this, $tempdir, "#!    /usr/bin/perl        ",
        "/usr/bin/perl" );
    _doLocationTest( $this, $tempdir, "#! perl  -wT ", "perl" );
    _doLocationTest(
        $this, $tempdir,
        "#!C:\\Progra~1\\Strawberry\\bin\\perl.exe  -wT ",
        "C:\\Progra~1\\Strawberry\\bin\\perl.exe"
    );
    _doLocationTest(
        $this, $tempdir,
        "#!c:\\strawberry\\perl\\bin\\perl.exe  -w ",
        "c:\\strawberry\\perl\\bin\\perl.exe"
    );
    _doLocationTest(
        $this, $tempdir,
        "#!C:\\Program Files\\Strawberry\\bin\\perl.exe  -wT ",
        "C:\\Program Files\\Strawberry\\bin\\perl.exe"
    );
    _doLocationTest(
        $this, $tempdir,
        "#! C:\\Program Files\\Strawberry\\bin\\perl.exe",
        "C:\\Program Files\\Strawberry\\bin\\perl.exe"
    );

    _makefile( "$tempdir", "loctestf", <<'DONE');
#! /a/b/perl
Test file data
DONE

    $this->assert_str_equals( '/a/b/perl',
        Foswiki::Configure::FileUtil::getPerlLocation("$tempdir/loctestf") );

    $Foswiki::cfg{ScriptSuffix} = ".pl";
    _doLocationTest( $this, $tempdir, "#!/usr/bin/perl -wT ", "/usr/bin/perl" );

    $Foswiki::cfg{ScriptDir} = $holddir;
    eval { rmtree($tempdir) };    # Cleanup any old tests

    return;
}

sub _doLocationTest {
    my $this     = shift;
    my $tempdir  = shift;
    my $shebang  = shift;
    my $expected = shift;

    if ($shebang) {
        open( my $fh, '>', "$tempdir/configure$Foswiki::cfg{ScriptSuffix}" )
          || die "Unable to open \n $! \n\n ";
        print $fh "$shebang \n";
        $this->assert( close($fh) );
    }

    my $perl = Foswiki::Configure::FileUtil::getPerlLocation();
    $this->assert_str_equals( $expected, $perl );

    return;
}

sub test_Util_rewriteShebang {
    my $this = shift;

    my $tempdir = $this->{tempdir} . '/test_util_rewriteShebang';
    mkpath($tempdir);

#                                    Target Script File       New Shebang        Expected line
    _doRewriteTest( $this, $tempdir, '#!/usr/bin/perl -wT',
        'C:\asdf\perl.exe', '#! C:\asdf\perl.exe -wT' );
    _doRewriteTest( $this, $tempdir, '#!/usr/bin/perl -wT',
        '/usr/bin/perl', '#! /usr/bin/perl -wT' );
    _doRewriteTest(
        $this, $tempdir, '#! /usr/bin/perl -wT',
        '/usr/bin/perl',
        '#! /usr/bin/perl -wT',
        'No change required'
    );
    _doRewriteTest( $this, $tempdir, '#!/usr/bin/perl -wT',
        '/usr/bin/perl', '#! /usr/bin/perl -wT' );
    _doRewriteTest(
        $this, $tempdir, '#! /usr/bin/perl ',
        '/usr/bin/perl',
        '#! /usr/bin/perl ',
        'No change required'
    );
    _doRewriteTest(
        $this, $tempdir, '#! /usr/bin/env perl ',
        '/usr/bin/perl', '#! /usr/bin/perl ',
    );
    _doRewriteTest(
        $this, $tempdir,
        '#! /usr/bin/perl -wT ',
        '/usr/bin/env perl',
        '#! /usr/bin/env perl ',
    );
    _doRewriteTest( $this, $tempdir, '#! /usr/bin/perl -wT ',
        '/my/bin/perl', '#! /my/bin/perl -wT ' );
    _doRewriteTest(
        $this, $tempdir,
        '#!/usr/bin/perl -wT',
        'C:\Program Files\Active State\perl.exe',
        '#! C:\Program Files\Active State\perl.exe -wT'
    );
    _doRewriteTest(
        $this, $tempdir,
        '#!/usr/bin/env perl',
        'C:\Program Files\Active State\perl.exe',
        '#! C:\Program Files\Active State\perl.exe -T',
        '', 1
    );
    _doRewriteTest( $this, $tempdir,
        '#! C:\Program Files\Active State\perl.exe -wT',
        '/usr/bin/perl', '#! /usr/bin/perl -wT' );

    #  Negative testing
    _doRewriteTest( $this, $tempdir, '#! ', '/usr/bin/perl', '#! /bin/sh',
        'Not a perl script' );
    _doRewriteTest( $this, $tempdir, '#! /bin/sh', '/usr/bin/perl',
        '#! /bin/sh', 'Not a perl script' );
    _doRewriteTest( $this, $tempdir, '#!/bin/sh', '/usr/bin/perl', '#!/bin/sh',
        'Not a perl script' );
    _doRewriteTest( $this, $tempdir, '#! /bin/sh ', '/usr/bin/perl',
        '#! /bin/sh ', 'Not a perl script' );
    _doRewriteTest( $this, $tempdir, '#! /bin/sh ', '', '#! /bin/sh ',
        'Missing Shebang' );
    _doRewriteTest( $this, $tempdir, '#perl', '/usr/bin/perl', '',
        'Not a perl script' );
    _doRewriteTest(
        $this, $tempdir, "asdf\n#!/usr/bin/perl", '/usr/bin/perl',
        '#! /bin/sh What a perl',
        'Not a perl script'
    );
    _doRewriteTest(
        $this, $tempdir, "\n#!/usr/bin/perl", '/usr/bin/perl',
        '#! /bin/sh What a perl',
        'Not a perl script'
    );
    _doRewriteTest(
        $this, $tempdir, "\n#! /usr/bin/perl -wT",
        '/usr/bin/perl',
        '#! /bin/sh What a perl',
        'Not a perl script'
    );

    my $err = Foswiki::Configure::FileUtil::rewriteShebang(
        "$tempdir/missing$Foswiki::cfg{ScriptSuffix}",
        "/usr/shebang" );
    $this->assert_str_equals( 'Not a file', $err );

    # Taint checking
    _doRewriteTest(
        $this, $tempdir, '#!/usr/bin/perl -wT',
        '/usr/bin/perl', '#! /usr/bin/perl -wT',
        undef, 1
    );
    _doRewriteTest(
        $this, $tempdir, '#!/usr/bin/perl -wT',
        '/usr/bin/perl', '#! /usr/bin/perl -w',
        undef, 0
    );
    _doRewriteTest(
        $this, $tempdir, '#!/usr/bin/perl -w',
        '/usr/bin/perl', '#! /usr/bin/perl -wT',
        undef, 1
    );
    _doRewriteTest( $this, $tempdir, '#!/usr/bin/perl',
        '/usr/bin/perl', '#! /usr/bin/perl -T',
        undef, 1 );
    _doRewriteTest(
        $this, $tempdir, '#!/usr/bin/env perl',
        '/usr/bin/perl', '#! /usr/bin/perl -T',
        undef, 1
    );

    # Even if Taint requested, don't set -T for env perl
    _doRewriteTest(
        $this, $tempdir,
        '#!/usr/bin/perl -wT',
        '/usr/bin/env perl',
        '#! /usr/bin/env perl',
        undef, 1
    );
    _doRewriteTest(
        $this, $tempdir,
        '#!/usr/bin/perl -wT',
        'C:\Program Files\Active-State\perl.exe',
        '#! C:\Program Files\Active-State\perl.exe -w',
        undef, 0
    );
    _doRewriteTest(
        $this, $tempdir, '#!/usr/bin/perl',
        'C:\Program Files\Active-State\perl.exe',
        '#! C:\Program Files\Active-State\perl.exe -T',
        undef, 1
    );
    _doRewriteTest(
        $this,
        $tempdir,
        '#! C:\Program Files\Active-State\perl.exe -T',
        'C:\Program Files\Active-State\perl.exe',
        '#! C:\Program Files\Active-State\perl.exe',
        undef,
        0
    );

    return;
}

sub _doRewriteTest {
    my $this      = shift;
    my $tempdir   = shift;
    my $testline  = shift;
    my $shebang   = shift;
    my $expected  = shift;
    my $errReturn = shift;
    my $taint     = shift;

    open( my $fh, '>', "$tempdir/myscript$Foswiki::cfg{ScriptSuffix}" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<"DONE";
$testline
#!blah
bleh
DONE
    $this->assert( close($fh) );

    my $err = Foswiki::Configure::FileUtil::rewriteShebang(
        "$tempdir/myscript$Foswiki::cfg{ScriptSuffix}",
        "$shebang", $taint );

    if ($errReturn) {
        $this->assert_str_equals( $errReturn, $err );
    }
    else {
        $this->assert_str_equals( '', $err );
        _testShebang( $this, "$tempdir/myscript$Foswiki::cfg{ScriptSuffix}",
            "$expected" );
    }

    return;
}

sub _testShebang {
    my $this     = shift;
    my $testfile = shift;
    my $expected = shift;

    my $ShebangLine = '';

    #my $bfh;

    if ( open( my $bfh, '<', "$testfile" ) ) {

        $ShebangLine = <$bfh>;
        chomp $ShebangLine;
        $this->assert( close($bfh) );
    }
    else {
        die "Open failed $! ";
    }

    $this->assert_str_equals( $expected, $ShebangLine );

    return;
}

sub _makefile {
    my $path    = shift;
    my $file    = shift;
    my $content = shift;

    $content = "datadata/n" unless ($content);

    mkpath($path);
    open( my $fh, '>', "$path/$file" )
      or die "Unable to open $path/$file for writing: $!\n";
    print $fh "$content \n";
    close($fh) or die "Couldn't close $path/$file: $!\n";

    return;
}

sub test_Package_makeBackup {
    my $this = shift;

    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    eval { rmtree($tempdir) };    # Clean up old files if left behind
    mkpath($tempdir);

    my $extension = "MyPlugin";
    _makePackage( $tempdir, $extension );

    my $pkg = Foswiki::Configure::Package->new(
        root     => $root,
        module   => $extension,
        DIR      => $tempdir,
        EXPANDED => 1,
        USELOCAL => 1
    );
    $this->assert( $pkg->loadInstaller($reporter) );
    $this->sniff();

    $this->assert( $pkg->install($reporter) );
    $this->sniff();

    $pkg->_createBackup($reporter);
    $this->sniff( notes => qr/Backup saved into/ );
    $this->assert( $pkg->uninstall($reporter) );
    $this->sniff(
        notes => 'Testsandboxweb1234/Subweb/TestTopic43.txt',
        notes => 'Testsandboxweb1234/TestTopic1.txt',
        notes => 'Testsandboxweb1234/TestTopic43.txt',
        notes => 'Testsandboxweb1234/Subweb/TestTopic43/file3.att',
        notes => 'Testsandboxweb1234/Subweb/TestTopic43/subdir-1.2.3/file4.att',
        notes => 'Testsandboxweb1234/TestTopic1/file.att',
        notes => 'Testsandboxweb1234/TestTopic43/file.att',
        notes => 'Testsandboxweb1234/TestTopic43/file2.att',
        notes => 'configure/pkgdata/MyPlugin_installer',
        notes => "$this->{scriptdir}/shbtest1",
        notes => "$this->{toolsdir}/shbtest2"
    );

    $pkg->finish();

    return;
}

my $INSTALL_HEAD = <<'HERE';
#!blah
bleh

sub preuninstall {

        return "Pre-uninstall entered";
}

sub postuninstall {

    # # No POSTUNINSTALL script;

    return;
}

sub preinstall {

    return "Pre-install entered";
}

sub postinstall {

    my $this = shift;   # Get the object instance passed to the routine
    if ($this) {        # Verify that you are running in the new environment
HERE

# postinstall body will go here

my $INSTALL_FOOT = <<'HERE';
        return unlink($file) ? "Removed $file" : "Problem in post-install $file";
    }

    return;
}

Foswiki::Extender::install(
    $PACKAGES_URL, 'CommentPlugin', 'CommentPlugin', @DATA );

1;
our $VERSION = '2.1';
# MANIFEST and DEPENDENCIES are done this way
# to make it easy to extract them from this script.

__DATA__
<<<< MANIFEST >>>>
bin/shbtest1,0755,1a9a1da563535b2dad241d8571acd170,
data/mimedata,0644,1a9a1da563535b2dad241d8571acd170,
data/.htpasswd,0644,1a9a1da563535b2dad241d8571acd170,
data/Sandbox/.changes,0644,1a9a1da563535b2dad241d8571acd170,
data/Sandbox/TestTopic1.txt,0644,1a9a1da563535b2dad241d8571acd170,Documentation (noci)
data/Sandbox/TestTopic43.txt,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
data/Sandbox/Subweb/TestTopic43.txt,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
pub/pubfile,0644,1a9a1da563535b2dad241d8571acd170,
pub/.htaccess,0644,1a9a1da563535b2dad241d8571acd170,
pub/Sandbox/TestTopic1/file.att,0664,ede33d5e092a0cb2fa00d9146eed5f9a, (noci)
pub/Sandbox/TestTopic43/file.att,0664,1a9a1da563535b2dad241d8571acd170,
pub/Sandbox/TestTopic43/file2.att,0664,ede33d5e092a0cb2fa00d9146eed5f9a,
pub/Sandbox/Subweb/TestTopic43/file3.att,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
tools/shbtest2,0755,1a9a1da563535b2dad241d8571acd170,

<<<< DEPENDENCIES >>>>
.\@#$%}{Filtrx::Invalid::Blah,>=0.68,1,CPAN,Required. install from CPAN
Time::ParseDate,>=2003.0211,1,cpan,Required. Available from the CPAN:Time::ParseDate archive.
Foswiki::Plugins::RequiredTriggeredModule,>=0.1,( $Foswiki::Plugins::VERSION < 3.2 ),perl,Required
Foswiki::Plugins::UnneededTriggeredModule,>=0.1,( $Foswiki::Plugins::VERSION < 2.1 ),perl,Required
Foswiki::Contrib::OptionalDependency,>=14754,1,perl,optional module
Foswiki::Contrib::UnitTestContrib::MultiDottedVersion,>=14754,1,perl,Required
Foswiki::Contrib::QuickMenuSkin,>=14754,1,perl,Required
File::Spec, >0,1,cpan,This module is shipped as part of standard perl
Cwd, >55,1,cpan,This module is shipped as part of standard perl
htmldoc, >24.3,1,c,Required for generating PDF

HERE

my $INSTALL_ONLYIF = <<'HERE';
        return "Removed $file" if unlink $file;
    }

    return;
}

Foswiki::Extender::install( $PACKAGES_URL, 'CommentPlugin', 'CommentPlugin', @DATA );

1;
our $VERSION = '2.1';
# MANIFEST and DEPENDENCIES are done this way
# to make it easy to extract them from this script.

__DATA__
<<<< MANIFEST >>>>
bin/shbtest1,0755,1a9a1da563535b2dad241d8571acd170,
data/Sandbox/TestTopic1.txt,0644,1a9a1da563535b2dad241d8571acd170,Documentation (noci)
data/Sandbox/TestTopic43.txt,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
data/Sandbox/Subweb/TestTopic43.txt,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
pub/Sandbox/TestTopic1/file.att,0664,ede33d5e092a0cb2fa00d9146eed5f9a, (noci)
pub/Sandbox/TestTopic43/file.att,0664,1a9a1da563535b2dad241d8571acd170,
pub/Sandbox/TestTopic43/file2.att,0664,ede33d5e092a0cb2fa00d9146eed5f9a,
pub/Sandbox/Subweb/TestTopic43/file3.att,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
tools/shbtest2,0755,1a9a1da563535b2dad241d8571acd170,

<<<< DEPENDENCIES >>>>
Foswiki::Plugins::TriggerFoswikiOldAPI,>=0.1,( $Foswiki::Plugins::VERSION < 3.2 ),perl,Required
Foswiki::Plugins::TriggerFoswikiGoodAPI,>=0.1,( $Foswiki::Plugins::VERSION > 2.1 ),perl,Required
Foswiki::Plugins::TriggerOSLinux,>=0.1,( $^O eq 'linux' ),perl,Required
Foswiki::Plugins::TriggerGoodFoswiki,>=0.1,( $Foswiki::VERSION < '1.1.1' ),perl,Required
Foswiki::Plugins::TriggerOldFoswiki,>=0.1,( $Foswiki::VERSION < '3.2.1' ),perl,Required
Foswiki::Plugins::TriggerSyntaxError,>=0.1, {no warnings 'exec'; my $sts = system('selinuxenabled'); return !($sts == -1 ||($sts>>8) && !($sts & 127)));} ,perl,Required
Foswiki::Plugins::TriggerSELinux,>=0.1, {no warnings 'exec'; my $sts = system('selinuxenabled'); return !($sts == -1 ||($sts>>8) && !($sts & 127));} ,perl,Required

HERE

#
# Utility subroutine to build the files for an installable package
#
sub _makePackage {
    my ( $tempdir, $plugin, $alt ) = @_;
    open( my $fh, '>',
        "$tempdir/${plugin}_installer$Foswiki::cfg{ScriptSuffix}" )
      || die "Unable to open \n $! \n\n ";
    print $fh $INSTALL_HEAD;
    print $fh "        my \$file = \"$tempdir/obsolete.pl\";\n";
    my $foot = ($alt) ? $INSTALL_ONLYIF : $INSTALL_FOOT;
    print $fh $foot;
    close($fh) or die "Couldn't close: $!\n";

    _makefile( "$tempdir/pub", "pubfile", <<'DONE');
Blah blah
Test file data
DONE
    _makefile( "$tempdir/pub", ".htaccess", <<'DONE');
Blah blah
Test file data
DONE
    _makefile( "$tempdir/data", "mimedata", <<'DONE');
Blah blah
Test file data
DONE
    _makefile( "$tempdir/data/Sandbox", ".changes", <<'DONE');
Blah blah
Test file data
DONE
    _makefile( "$tempdir/data", ".htpasswd", <<'DONE');
Blah blah
Test file data
DONE
    _makefile( "$tempdir/data/Sandbox", "TestTopic1.txt", <<'DONE');
%META:TOPICINFO{author="BaseUserMapping_333" comment="reprev" date="1267729185" format="1.1" reprev="1.1" version="1.1"}%
Test rev 132412341234
==qr/[\s\*?~^\$@%`"'&;|&lt;&gt;\[\]\x00-\x1f]/;==

-- Main.AdminUser - 04 Mar 2010
DONE
    _makefile( "$tempdir/data/Sandbox", "TestTopic43.txt", <<'DONE');
%META:TOPICINFO{author="BaseUserMapping_333" comment="reprev" date="1267729185" format="1.1" reprev="1.1" version="1.1"}%
Test rev 132412341234
==qr/[\s\*?~^\$@%`"'&;|&lt;&gt;\[\]\x00-\x1f]/;==

-- Main.AdminUser - 04 Mar 2010
DONE
    _makefile( "$tempdir/pub/Sandbox/TestTopic1", "file.att", <<'DONE');
#! /usr/bin/perl
Test file data
DONE
    _makefile( "$tempdir/pub/Sandbox/TestTopic43", "file.att", <<'DONE');
Test file data
DONE
    _makefile( "$tempdir/pub/Sandbox/TestTopic43", "file2.att", <<'DONE');
Test file data
DONE
    _makefile( "$tempdir/bin", "shbtest1", <<'DONE');
#! /usr/bin/perl
Test file data
DONE
    _makefile( "$tempdir/tools", "shbtest2", <<'DONE');
#! /usr/bin/perl
Test file data
DONE
    _makefile( "$tempdir/data/Sandbox/Subweb", "TestTopic43.txt", <<'DONE');
#! /usr/bin/perl
Test file data
DONE
    _makefile( "$tempdir/pub/Sandbox/Subweb/TestTopic43", "file3.att",
        <<'DONE');
Test file data
DONE
    _makefile( "$tempdir/pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3",
        "file4.att", <<'DONE');
Test file data
DONE

    return;
}

sub test_Package_dependencies {
    my $this   = shift;
    my $root   = $this->{rootdir};
    my $result = '';
    my $err    = '';

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    eval { rmtree($tempdir) };    # Clean up old files if left behind
    mkpath($tempdir);

    _makefile( $tempdir, "obsolete.pl", <<'DONE');
Test file data
DONE

    _makefile( "$this->{scriptdir}", "configure", <<'DONE');
#! /my/bin/perl
Test file data
DONE

    my $extension = "MyPlugin";
    _makePackage( $tempdir, $extension, 1 );

    #
    # Make sure that the package is removed, that no old topics
    # were left around
    #
    my $pkg = Foswiki::Configure::Package->new(
        root     => $root,
        module   => 'MyPlugin',
        DIR      => $tempdir,
        USELOCAL => 1
    );

    $this->assert( $pkg->loadInstaller($reporter) );
    $this->sniff();

    my ( $installed, $missing, $wiki, $install, $cpan ) =
      $pkg->checkDependencies();

    $missing = join( "\n", @$missing );

    $this->assert_matches( qr/Foswiki::Plugins::TriggerFoswikiOldAPI/,
        $missing );
    $this->assert_matches( qr/Foswiki::Plugins::TriggerFoswikiGoodAPI/,
        $missing );
    $this->assert_matches( qr/Foswiki::Plugins::TriggerOSLinux/, $missing )
      if ( $^O eq 'linux' );
    $this->assert_does_not_match( qr/Foswiki::Plugins::TriggerOSLinux/,
        $missing )
      unless ( $^O eq 'linux' );
    $this->assert_matches( qr/Foswiki::Plugins::TriggerOldFoswiki/, $missing );
    $this->assert_does_not_match( qr/Foswiki::Plugins::TriggerGoodFoswiki/,
        $missing );
    $this->assert_does_not_match( qr/Foswiki::Plugins::TriggerSELinux/,
        $missing );
    $this->assert_matches(
        qr/Foswiki::Plugins::TriggerSyntaxError.*-- syntax error/ms, $missing );

    $pkg->finish();
    undef $pkg;

}

sub test_Package_sub_install {
    my $this   = shift;
    my $root   = $this->{rootdir};
    my $result = '';
    my $err    = '';

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    eval { rmtree($tempdir) };    # Clean up old files if left behind
    mkpath($tempdir);

    _makefile( $tempdir, "obsolete.pl", <<'DONE');
Test file data
DONE

    _makefile( "$this->{scriptdir}", "configure", <<'DONE');
#! /my/bin/perl
Test file data
DONE

    my $extension = "MyPlugin";
    _makePackage( $tempdir, $extension );

    #
    #   Make sure that the package is removed, that no old
    # topics were left around
    #
    my $pkg = Foswiki::Configure::Package->new(
        root     => $root,
        module   => 'MyPlugin',
        DIR      => $tempdir,
        USELOCAL => 1
    );

    $this->assert( $pkg->loadInstaller($reporter) );
    $this->sniff();
    $this->assert( $pkg->uninstall($reporter) );
    $this->sniff();
    $pkg->finish();
    undef $pkg;

    #
    #   Install the package - as a fresh install, no checkin or files created
    #

    _makePackage( $tempdir, $extension );
    $pkg = Foswiki::Configure::Package->new(
        root     => $root,
        module   => 'MyPlugin',
        DIR      => $tempdir,
        USELOCAL => 1,
        EXPANDED => 1
    );
    $this->assert( $pkg->loadInstaller($reporter) );
    $this->sniff();
    $this->assert( $pkg->install($reporter) );
    $this->sniff();

    $this->sniff(
        warnings =>
'Extension installer will not install data/.htpasswd. Server configuration file.',
        warnings =>
'Extension installer will not install data/Sandbox/.changes. Server configuration file.',
        warnings =>
'Extension installer will not install pub/.htaccess. Server configuration file.',
    );

    $this->sniff(
        notes =>
          "Installed:  bin/shbtest1 as $Foswiki::cfg{ScriptDir}/shbtest1",
        notes =>
"Installed:  data/Sandbox/Subweb/TestTopic43.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43.txt",
        notes =>
"Installed:  data/Sandbox/TestTopic1.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1.txt",
        notes =>
"Installed:  data/Sandbox/TestTopic43.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43.txt",
        notes => "Installed:  data/mimedata as $Foswiki::cfg{DataDir}/mimedata",
        notes =>
"Installed:  pub/Sandbox/Subweb/TestTopic43/file3.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/file3.att",
        notes =>
"Installed:  pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/subdir-1.2.3/file4.att",
        notes =>
"Installed:  pub/Sandbox/TestTopic1/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1/file.att",
        notes =>
"Installed:  pub/Sandbox/TestTopic43/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43/file.att",
        notes =>
"Installed:  pub/Sandbox/TestTopic43/file2.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43/file2.att",
        notes => "Installed:  pub/pubfile as $Foswiki::cfg{PubDir}/pubfile",
        notes =>
          "Installed:  tools/shbtest2 as $Foswiki::cfg{ToolsDir}/shbtest2",
        notes =>
"Installed:  MyPlugin_installer to $Foswiki::cfg{WorkingDir}/configure/pkgdata"
    );

    my @mfiles = $pkg->_listFiles();
    $this->assert_num_equals(
        12,
        scalar @mfiles,
        'Unexpected number of files in manifest'
    );    # 5 files in manifest

    my @ifiles = $pkg->_listFiles('1');

    $this->assert_num_equals(
        12,
        scalar @ifiles,
        'Unexpected number of files installed'
    );    # and 5 files installed

    _testShebang(
        $this,
        "$Foswiki::cfg{ScriptDir}/shbtest1",
        '#! /my/bin/perl'
    );
    _testShebang( $this, "$Foswiki::cfg{ToolsDir}/shbtest2",
        '#! /my/bin/perl' );

    # Verify that we don't change shebang in attachments
    _testShebang(
        $this,
        "$Foswiki::cfg{PubDir}/$this->{sandbox_web}/TestTopic1/file.att",
        '#! /usr/bin/perl'
    );

    $pkg->finish();
    undef $pkg;

    # Clean out and restart the reporter
    $reporter->clear();

    #
    # Install a 2nd time - files should be created when checkin is requested.
    #
    _makePackage( $tempdir, $extension );
    my $pkg2 = Foswiki::Configure::Package->new(
        root     => $root,
        module   => 'MyPlugin',
        DIR      => $tempdir,
        USELOCAL => 1,
        EXPANDED => 1
    );
    $this->assert( $pkg2->loadInstaller($reporter) );
    $this->sniff();

    $this->assert( $pkg2->install($reporter) );
    $this->sniff();

    $this->sniff(
        warnings =>
'Extension installer will not install data/.htpasswd. Server configuration file.',
        warnings =>
'Extension installer will not install data/Sandbox/.changes. Server configuration file.',
        warnings =>
'Extension installer will not install pub/.htaccess. Server configuration file.',
    );

    $this->sniff(
        notes =>
          "Installed:  bin/shbtest1 as $Foswiki::cfg{ScriptDir}/shbtest1",
        notes =>
"Checked in: data/Sandbox/Subweb/TestTopic43.txt  as $this->{sandbox_subweb}.TestTopic43",
        notes =>
"Attached:   pub/Sandbox/Subweb/TestTopic43/file3.att to $this->{sandbox_subweb}/TestTopic43",
        notes =>
"Installed:  data/Sandbox/TestTopic1.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1.txt",
        notes =>
"Checked in: data/Sandbox/TestTopic43.txt  as $this->{sandbox_web}.TestTopic43",
        notes =>
"Attached:   pub/Sandbox/TestTopic43/file.att to $this->{sandbox_web}/TestTopic43",
        notes =>
"Attached:   pub/Sandbox/TestTopic43/file2.att to $this->{sandbox_web}/TestTopic43",
        notes => "Installed:  data/mimedata as $Foswiki::cfg{DataDir}/mimedata",
        notes =>
"Installed:  pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/subdir-1.2.3/file4.att",
        notes =>
"Installed:  pub/Sandbox/TestTopic1/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1/file.att",
        notes => "Installed:  pub/pubfile as $Foswiki::cfg{PubDir}/pubfile",
        notes =>
          "Installed:  tools/shbtest2 as $Foswiki::cfg{ToolsDir}/shbtest2",
        notes =>
"Installed:  MyPlugin_installer to $Foswiki::cfg{WorkingDir}/configure/pkgdata"
    );

    my @ifiles2 = $pkg2->_listFiles('1');

    $this->assert_num_equals(
        17,
        scalar @ifiles2,
        'Unexpected number of files installed on 2nd install: ' . @ifiles2
    );    # + 3 rcs files after checkin
    $this->assert_str_equals( '', $err, "Error $err reported" );

    #
    # Verify the pre/post install exits
    #

    $pkg2->_loadExits();

    _makefile( $tempdir, "obsolete.pl", <<'DONE');
Test file data
DONE

    $this->assert_str_equals( 'Pre-install entered', $pkg2->preinstall() );
    $this->assert_str_equals( "Removed $tempdir/obsolete.pl",
        $pkg2->postinstall() );
    $this->assert_str_equals( 'Pre-uninstall entered', $pkg2->preuninstall() );
    $this->assert_null( $pkg2->postuninstall() );

    #
    #  Dependency Tests
    #
    my ( $installed, $missing, $wiki, $install, $cpan ) =
      $pkg2->checkDependencies();

    my $mods;
    my $mnames;
    foreach my $dep ( @{$wiki} ) {
        $mods   .= "$dep->{module};";
        $mnames .= "$dep->{name};";
    }
    $this->assert_str_equals(
"Foswiki::Plugins::RequiredTriggeredModule;Foswiki::Contrib::UnitTestContrib::MultiDottedVersion;Foswiki::Contrib::QuickMenuSkin;",
        $mods, 'Wiki modules to be installed: got:' . $mods
    );

    $this->assert_str_equals(
        'RequiredTriggeredModule;UnitTestContrib;QuickMenuSkin;',
        $mnames, 'Wiki module names to be installed: got:' . $mnames );

    $mods = '';
    foreach my $dep ( @{$install} ) {
        $mods .= "$dep->{module};";
    }
    my $expected = 'Filtrx::Invalid::Blah;' . (
        eval {
            require Time::ParseDate;
            Time::ParseDate->VERSION(2003.0211);
            1;
        } ? '' : 'Time::ParseDate;'
    ) . 'Cwd;';
    $this->assert_str_equals( $expected, $mods );
    $this->assert_str_equals( $expected, $mods,
        'CPAN modules to be installed' );

    $mods = '';
    foreach my $dep ( @{$cpan} ) {
        $mods .= "$dep->{module};";
    }

    #print "$mods\n";
    $this->assert_str_equals( "htmldoc;", $mods,
        'External modules to be installed' );

    $missing = join( "\n", @$missing );

    #print "====== MISSING ========\n$missing\n";
    $this->assert_matches( qr/Filtrx::Invalid::Blah/, $missing,
        'Filtering invalid characters from module name' );
    $this->assert_matches(
        qr/^Foswiki::Plugins::RequiredTriggeredModule(.*)Triggered by/m,
        $missing, 'Module requirement triggered by Foswiki API version' );
    $this->assert_does_not_match(
        qr/^Foswiki::Plugins::UnneededTriggeredModule(.*)^ -- Triggered by/ms,
        $missing, 'Module requirement triggered by Foswiki API version' );
    $this->assert_matches(
        qr/^Cwd version > 55 required(.*)installed version is /m,
        $missing, 'Test for backlevel module' );
    $this->assert_matches(
qr/^Foswiki::Contrib::OptionalDependency version >=14754 required(.*)[- ]+perl module is not installed(.*)Optional dependency, will not be automatically installed/ms,
        $missing,
        "Test for optional module - Returned \n$missing\n\n"
    );

    #print "===== INSTALLED =======\n$installed\n";
    $installed = join( "\n", @$installed );
    $this->assert_matches( qr/^File::Spec(.*)installed/ms,
        $installed, 'Installed module File::Spec' );

    # Clean out and restart the reporter
    $reporter->clear();

    #
    #  Now uninistall the package
    #
    $this->assert( $pkg2->uninstall($reporter) );

    $this->sniff(
        notes => 'Testsandboxweb1234/Subweb/TestTopic43.txt',
        notes => 'Testsandboxweb1234/Subweb/TestTopic43.txt,v',
        notes => 'Testsandboxweb1234/TestTopic1.txt',
        notes => 'Testsandboxweb1234/TestTopic43.txt',
        notes => 'Testsandboxweb1234/TestTopic43.txt,v',
        notes => 'Testsandboxweb1234/Subweb/TestTopic43/file3.att',
        notes => 'Testsandboxweb1234/Subweb/TestTopic43/file3.att,v',
        notes => 'Testsandboxweb1234/Subweb/TestTopic43/subdir-1.2.3/file4.att',
        notes => 'Testsandboxweb1234/TestTopic1/file.att',
        notes => 'Testsandboxweb1234/TestTopic43/file.att',
        notes => 'Testsandboxweb1234/TestTopic43/file.att,v',
        notes => 'Testsandboxweb1234/TestTopic43/file2.att',
        notes => 'Testsandboxweb1234/TestTopic43/file2.att,v',
    );
    $this->sniff(
        notes => 'configure/pkgdata/MyPlugin_installer',
        notes => "$this->{scriptdir}/shbtest1",
        notes => "$this->{toolsdir}/shbtest2",
    );

    $pkg2->finish();
    undef $pkg2;

    eval { rmtree($tempdir) };

    return;
}

sub test_Package_install {
    my $this = shift;
    my $root = $this->{rootdir};

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    eval { rmtree($tempdir) };    # Clean up old files if left behind
    mkpath($tempdir);

    _makefile( $tempdir, "obsolete.pl", <<'DONE');
Test file data
DONE

    my $extension = "MyPlugin";
    _makePackage( $tempdir, $extension );

  #
  #   Make sure that the package is removed, that no old topics were left around
  #
  #
    my $pkg = Foswiki::Configure::Package->new(
        root     => $root,
        module   => 'MyPlugin',
        DIR      => $tempdir,
        USELOCAL => 1
    );
    $this->assert( $pkg->loadInstaller($reporter) );
    $this->sniff();

    $this->assert( $pkg->uninstall($reporter) );
    $this->sniff();
    $pkg->finish();
    undef $pkg;

    #
    # Install the package - as a fresh install, no checkin
    #

    _makePackage( $tempdir, $extension );
    $reporter->clear();
    $pkg = Foswiki::Configure::Package->new(
        root     => $root,
        module   => 'MyPlugin',
        SIMULATE => 1,            # Don't actually install any files
        DIR      => $tempdir,     # Location of expanded package
        EXPANDED => 1,            # Already expanded
        USELOCAL => 1,            # Use local files don't download
        SHELL    => 1,            # Shell version, no HTML markup
        NODEPS   => 1             # No dependencies
    );
    my ( $ok, $plugins, $cpan ) = $pkg->install($reporter);
    $this->assert($ok);
    $this->sniff();

    foreach my $pn ( keys %{$plugins} ) {
        print "PLUGIN $pn \n";
    }

    my $cplist = '';
    foreach my $cpdep ( sort { lc($a) cmp lc($b) } keys %{$cpan} ) {
        $cplist .= "$cpdep;";
    }
    $this->assert_str_equals(
        'Cwd;Filtrx::Invalid::Blah;' . (
            eval {
                require Time::ParseDate;
                Time::ParseDate->VERSION(2003.0211);
                1;
            } ? '' : 'Time::ParseDate;'
        ),
        $cplist,
        "Unexpected CPAN Dependencies $cplist"
    );

    $this->sniff(
        notes => "Installing MyPlugin",
        notes => "Creating backup of MyPlugin",
        notes => "Nothing to backup",
        notes =>
"Simulated - Installed:  bin/shbtest1 as $Foswiki::cfg{ScriptDir}/shbtest1",
        notes =>
"Simulated - Installed:  data/Sandbox/Subweb/TestTopic43.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43.txt",
        notes =>
"Simulated - Installed:  data/Sandbox/TestTopic1.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1.txt",
        notes =>
"Simulated - Installed:  data/Sandbox/TestTopic43.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43.txt",
        notes =>
"Simulated - Installed:  pub/Sandbox/Subweb/TestTopic43/file3.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/file3.att",
        notes =>
"Simulated - Installed:  pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/subdir-1.2.3/file4.att",
        notes =>
"Simulated - Installed:  pub/Sandbox/TestTopic1/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1/file.att",
        notes =>
"Simulated - Installed:  pub/Sandbox/TestTopic43/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43/file.att",
        notes =>
"Simulated - Installed:  pub/Sandbox/TestTopic43/file2.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43/file2.att",
        notes =>
"Simulated - Installed:  tools/shbtest2 as $Foswiki::cfg{ToolsDir}/shbtest2",
        notes =>
"Simulated - Installed:  MyPlugin_installer to $Foswiki::cfg{WorkingDir}/configure/pkgdata"
    );

    $this->sniff(
        warnings => "MISSING",
        warnings =>
"Filtrx::Invalid::Blah version >=[0-9.]+ required[- ]+CPAN module is not installed[- ]+Required. install from CPAN",
        warnings =>
qr/Foswiki::Plugins::RequiredTriggeredModule version >=0.1 required[- ]+perl module is not installed[- ]+Triggered by \( \$Foswiki::Plugins::VERSION < [0-9.]+ \)[- ]+Required/,
        warnings =>
"Foswiki::Contrib::OptionalDependency version >=[0-9.]+ required[- ]+perl module is not installed[- ]+optional module[- ]+Optional dependency, will not be automatically installed",
        warnings =>
"Foswiki::Contrib::UnitTestContrib::MultiDottedVersion version >= [0-9.]+ required[- ]+installed version is [0-9.]+[- ]+Required",
        warnings =>
"Foswiki::Contrib::QuickMenuSkin version >=[0-9.]+ required[- ]+perl module is not installed[- ]+Required",
        warnings =>
"Cwd version > [0-9.]+ required[- ]+installed version is [0-9._]+[- ]+This module is shipped as part of standard perl",
        warnings => "htmldoc is type 'c', and cannot be automatically checked."
    );

    $pkg->finish();
    undef $pkg;

    eval { rmtree($tempdir) };

    return;
}

sub test_Util_createArchive_shellZip {
    my $this = shift;

    my $file;
    my $rslt;

    my $tempdir = $this->{tempdir} . '/test_Util_createArchive';
    eval { rmtree($tempdir) };    # Clean up old files if left behind

    my $extension = "MyPlugin";
    my $extbkup   = "$extension-backup-20100329-123456";

    mkpath("$tempdir/$extbkup");
    _makePackage( "$tempdir/$extbkup", $extension );

    eval {
        local ( *STDOUT, *STDERR );
        require File::Spec;

        my $blah = system( 'zip -v >' . File::Spec->devnull() . ' 2>&1' );

        #print "zip returns $? ($blah) \n";
        die $! unless ( $? == 0 );
        1;
    } or do {
        my $mess = $@;
        $this->expect_failure("CANNOT RUN shell test for zip archive:  $mess");
        $this->assert(0);
    };

    ( $file, $rslt ) =
      Foswiki::Configure::FileUtil::createArchive( "$extbkup", "$tempdir", '0',
        'zip' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create zip archive" );
    $this->assert( ( -e "$tempdir/$extbkup" ),
        "$tempdir was incorrectly removed by the archive operation" );

    ( $file, $rslt ) =
      Foswiki::Configure::FileUtil::createArchive( "$extbkup", "$tempdir", '1',
        'zip' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create zip archive" );
    $this->assert( ( !-e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    unlink "$tempdir/$extbkup";    # Clean up old files if left behind

    return;
}

sub test_Util_createArchive_shellTar {
    my $this = shift;

    my $file;
    my $rslt;

    my $tempdir = $this->{tempdir} . '/test_Util_createArchive';
    eval { rmtree($tempdir) };     # Clean up old files if left behind

    my $extension = "MyPlugin";
    my $extbkup   = "$extension-backup-20100329-123456";

    mkpath("$tempdir/$extbkup");
    _makePackage( "$tempdir/$extbkup", $extension );

    eval {
        local ( *STDOUT, *STDERR );
        require File::Spec;
        my $blah =
          system( 'tar --version >' . File::Spec->devnull() . ' 2>&1' );

        #print "tar returns $? ($blah) \n";
        die $! unless ( $? == 0 );
        1;
    } or do {
        my $mess = $@;
        $this->expect_failure("CANNOT RUN shell test for tar archive:  $mess");
        $this->assert(0);
    };

    ( $file, $rslt ) =
      Foswiki::Configure::FileUtil::createArchive( "$extbkup", "$tempdir", '0',
        'tar' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create tar archive" );
    $this->assert( ( -e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    ( $file, $rslt ) =
      Foswiki::Configure::FileUtil::createArchive( "$extbkup", "$tempdir", '1',
        'tar' );
    $file = Foswiki::Sandbox::untaintUnchecked($file);
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create tar archive" );
    $this->assert( ( !-e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    unlink($file);    # Cleanup for next test

    return;
}

sub test_Util_createArchive_perlTar {
    my $this = shift;

    my $file;
    my $rslt;

    my $tempdir = $this->{tempdir} . '/test_Util_createArchive';
    eval { rmtree($tempdir) };    # Clean up old files if left behind

    my $extension = "MyPlugin";
    my $extbkup   = "$extension-backup-20100329-123456";

    mkpath("$tempdir/$extbkup");
    _makePackage( "$tempdir/$extbkup", $extension );

    eval { require Archive::Tar; 1; } or do {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure("CANNOT RUN test for tar archive:  $mess");
        $this->assert(0);
    };

    ( $file, $rslt ) =
      Foswiki::Configure::FileUtil::createArchive( "$extbkup", "$tempdir", '0',
        'Ptar' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create Archive::Tar archive" );
    $this->assert( ( -e "$tempdir/$extbkup" ),
        "$tempdir was incorrectly removed by the archive operation" );

    ( $file, $rslt ) =
      Foswiki::Configure::FileUtil::createArchive( "$extbkup", "$tempdir", '1',
        'Ptar' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create Archive::Tar archive" );
    $this->assert( ( !-e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    unlink "$tempdir/$extbkup";    # Clean up old files if left behind

    return;
}

sub test_Util_createArchive_perlZip {
    my $this = shift;

    my $file;
    my $rslt;

    my $tempdir = $this->{tempdir} . '/test_Util_createArchive';
    eval { rmtree($tempdir) };     # Clean up old files if left behind

    my $extension = "MyPlugin";
    my $extbkup   = "$extension-backup-20100329-123456";

    mkpath("$tempdir/$extbkup");
    _makePackage( "$tempdir/$extbkup", $extension );

    eval { require Archive::Zip; 1; } or do {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure("CANNOT RUN test for zip archive:  $mess");
        $this->assert(0);
    };

    ( $file, $rslt ) =
      Foswiki::Configure::FileUtil::createArchive( "$extbkup", "$tempdir", '0',
        'Pzip' );
    $this->assert( ( defined $file ),
        "createArchive returned undefined filename" );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create Archive::Zip archive" );
    $this->assert( ( -e "$tempdir/$extbkup" ),
        "$tempdir was incorrectly removed by the archive operation" );

    ( $file, $rslt ) =
      Foswiki::Configure::FileUtil::createArchive( "$extbkup", "$tempdir", '1',
        'Pzip' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create Archive::Zip archive" );
    $this->assert( ( !-e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    unlink "$tempdir/$extbkup";    # Clean up old files if left behind

    return;
}

#
# Determine that installer can download the package from Foswiki.org if not available locally
#
sub test_Package_loadInstaller {
    my $this = shift;
    my $root = $this->{rootdir};

    my $tempdir = $this->{tempdir} . '/test_Package_loadInstaller';
    eval { rmtree($tempdir) };    # Clean up old files if left behind
    mkpath($tempdir);

    my $repository = {
        name => 'Foswiki',
        data => 'http://foswiki.org/Extensions/',
        pub  => 'http://foswiki.org/pub/Extensions/'
    };
    my $pkg = Foswiki::Configure::Package->new(
        root       => $root,
        module     => 'EmptyPlugin',
        DIR        => $tempdir,
        USELOCAL   => 1,
        repository => $repository
    );
    $this->assert( $pkg->loadInstaller($reporter) );
    $this->sniff();

    $this->sniff(
        warnings => 'Unable to find EmptyPlugin locally in (.*) ...' );
    $this->sniff( notes =>
'fetching EmptyPlugin installer from http://foswiki.org/pub/Extensions/...'
    );

    my @files = $pkg->_listFiles();
    $this->assert_num_equals(
        4,
        scalar @files,
        "Unexpected number of files in EmptyPlugin manifest"
    );

    #
    # Test listPlugins
    #
    my %plugins = $pkg->_listPlugins();

    $this->assert_str_equals( '1', $plugins{EmptyPlugin},
        'Failed to discover plugin in manifest' );
    $pkg->finish();
    undef $pkg;

    return;
}

sub test_Load_expandValue {
    my $this = shift;

    my $logv = '$Foswiki::cfg{WorkingDir}/test';
    require Foswiki::Configure::Load;
    Foswiki::Configure::Load::expandValue($logv);
    $this->assert_str_equals( "$Foswiki::cfg{WorkingDir}/test", $logv );

    return;
}

sub test_Package_fetchFile {
    my $this = shift;
    my $root = $this->{_rootdir};

    my $repository = {
        name => 'Foswiki',
        data => 'http://foswiki.org/Extensions/',
        pub  => 'http://foswiki.org/pub/Extensions/'
    };

    my ( $resp, $file );
    try {
        my $pkg = Foswiki::Configure::Package->new(
            root       => $root,
            module     => 'EmptyPlugin',
            repository => $repository
        );

        ( $resp, $file ) = $pkg->_fetchFile('_installer');
        $this->assert_str_equals( '', $resp );
    }
    except {
        my $E = shift;
    }

    return;
}

#
# Verify error handling for the Package class
#
sub test_Package_errors {
    my $this = shift;
    my $root = $this->{rootdir};

    my $tempdir = $this->{tempdir} . '/test_Package_loadInstaller';
    eval { rmtree($tempdir) };    # Clean up old files if left behind
    mkpath($tempdir);

    my $repository = {
        name => 'Foswiki',
        data => 'http://foswiki.org/Extensions/',
        pub  => 'http://foswiki.org/pub/Extensions/'
    };

    #
    # Verify error when download fails
    #
    my $pkg = Foswiki::Configure::Package->new(
        root       => $root,
        module     => 'EmptyPluginx',
        DIR        => $tempdir,
        USELOCAL   => 1,
        repository => $repository
    );
    $this->assert( !$pkg->loadInstaller($reporter) );
    $this->sniff( errors =>
qr{Download failed - I can't download http://foswiki.org/pub/Extensions/EmptyPluginx/EmptyPluginx_installer because of the following error:}s
    );

    #
    # Verify error expanding .tgz file
    #
    my $extension = "MyPlugin";
    _makePackage( $tempdir, $extension );

    $reporter->clear();
    $pkg = Foswiki::Configure::Package->new(
        root     => $root,
        module   => 'MyPlugin',
        DIR      => $tempdir,
        USELOCAL => 1
    );
    $this->assert( $pkg->loadInstaller($reporter) );
    $this->sniff();

    _makefile( $tempdir, "MyPlugin.tgz", <<'DONE');
Test file data
DONE
    $this->assert( !$pkg->install($reporter) );
    $this->sniff( errors => 'Failed to unpack archive(.*)MyPlugin.tgz' );

    unlink $tempdir . "/MyPlugin.tgz";
    $pkg->finish();
    undef $pkg;

    return;
}

#
# Verify error handling for the Package class
#
sub test_Package_errors_zip {
    my $this = shift;
    my $root = $this->{rootdir};

    my $tempdir = $this->{tempdir} . '/test_Package_loadInstaller';
    eval { rmtree($tempdir) };    # Clean up old files if left behind
    mkpath($tempdir);

    my $repository = {
        name => 'Foswiki',
        data => 'http://foswiki.org/Extensions/',
        pub  => 'http://foswiki.org/pub/Extensions/'
    };

    #
    # Verify error expanding .zip file
    #
    my $extension = "MyPlugin";
    _makePackage( $tempdir, $extension );

    $reporter->clear();
    my $pkg = Foswiki::Configure::Package->new(
        root     => $root,
        module   => 'MyPlugin',
        DIR      => $tempdir,
        USELOCAL => 1
    );
    $this->assert( $pkg->loadInstaller($reporter) );
    $this->sniff();

    eval { require Archive::Zip; 1; } or do {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure("CANNOT RUN test for zip archive:  $mess");
    };

    $reporter->clear();
    $pkg = Foswiki::Configure::Package->new(
        root     => $root,
        module   => 'MyPlugin',
        DIR      => $tempdir,
        USELOCAL => 1
    );
    $this->assert( $pkg->loadInstaller($reporter) );
    $this->sniff();
    _makefile( $tempdir, "MyPlugin.zip", <<'DONE');
Test file data
DONE
    $this->assert( !$pkg->install($reporter) );
    $this->sniff( errors => '(format error|unzip failed|Unpack failed)' );
    unlink $tempdir . "/MyPlugin.zip";
    $pkg->finish();
    undef $pkg;

    return;
}
1;
