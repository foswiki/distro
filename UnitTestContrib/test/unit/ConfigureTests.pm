package ConfigureTests;

use strict;
use warnings;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Error qw( :try );
use File::Temp;
use FindBin;
use File::Path qw(mkpath rmtree);

use Foswiki::Configure::Util           ();
use Foswiki::Configure::FoswikiCfg     ();
use Foswiki::Configure::Root           ();
use Foswiki::Configure::Valuer         ();
use Foswiki::Configure::UI             ();
use Foswiki::Configure::GlobalControls ();

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    require Foswiki::Configure::UIs::EXTEND;
    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;
    $root =~ s|\\|/|g;

    $this->{rootdir}  = $root;
    $this->{user}     = $Foswiki::cfg{AdminUserLogin};
    $this->{session}  = new Foswiki( $this->{user} );
    $this->{test_web} = 'Testsystemweb1234';
    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{test_web} );
    $webObject->populateNewWeb();
    $this->{trash_web} = 'Testtrashweb1234';
    $webObject = Foswiki::Meta->new( $this->{session}, $this->{trash_web} );
    $webObject->populateNewWeb();
    $this->{sandbox_web} = 'Testsandboxweb1234';
    $webObject = Foswiki::Meta->new( $this->{session}, $this->{sandbox_web} );
    $webObject->populateNewWeb();
    $this->{sandbox_subweb} = 'Testsandboxweb1234/Subweb';
    $webObject =
      Foswiki::Meta->new( $this->{session}, $this->{sandbox_subweb} );
    $webObject->populateNewWeb();
    $this->{tempdir} = $Foswiki::cfg{TempfileDir} . '/test_ConfigureTests';
    rmtree( $this->{tempdir} ) if (-e $this->{tempdir});    # Cleanup any old tests
    mkpath( $this->{tempdir} );
    $this->{scriptdir}       = $this->{tempdir} . '/bin';
    $Foswiki::cfg{ScriptDir} = $this->{scriptdir};
    $this->{toolsdir}        = $this->{tempdir} . '/tools';
    $Foswiki::cfg{ToolsDir}  = $this->{toolsdir};
    $this->{logdir}        = $this->{tempdir} . '/logs';
    $Foswiki::cfg{Log}{Dir}  = $this->{logdir};

    $Foswiki::cfg{TrashWebName}   = $this->{trash_web};
    $Foswiki::cfg{SandboxWebName} = $this->{sandbox_web};
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $this->{test_web} );
    $this->removeWebFixture( $this->{session}, $this->{trash_web} );
    $this->removeWebFixture( $this->{session}, $this->{sandbox_web} );
    rmtree( $this->{tempdir} );    # Cleanup any old tests
    $this->SUPER::tear_down();

}

sub removeWeb {
    my ( $this, $web ) = @_;
    $this->removeWebFixture( $this->{session}, $web );
}

# Parse a cfg; change some values; save the changes
sub test_parseSave {
    my $this = shift;

    my %defaultCfg = ( not  => "rag" );
    my %cfg        = ( guff => "muff" );

    my $valuer = new Foswiki::Configure::Valuer( \%defaultCfg, \%cfg );
    my $root = new Foswiki::Configure::Root();
    my ( $fh, $fhname ) = File::Temp::tempfile( DIR => $this->{tempdir} );
    print $fh <<'EXAMPLE';
# Crud
my $pubDir = $cfg{PubDir} || '';
# More crud
#---+ One
# message for level one
# **URL M**
#  Mandatory boolean in a comment
# $cfg{MandatoryBoolean} = 1;
#---+ Two
#---++ Two.One
# message for Two.One
# ** PATH M**
# Mandatory path
$cfg{MandatoryPath} = 'mandatory path';
#---+++ Two.One.One
# **REGEX **
# Optional RE
$cfg{OptionalRegex} = qr/^.*$/;
$cfg{DontIgnore} = 'must not ignore';
#---+ Three
# ---++++ Three.1.1.One
# **SELECTCLASS Foswiki::Configure::Types::***
$cfg{Types}{Chosen} = 'Foswiki::Configure::Types::BOOLEAN';
1;
EXAMPLE
    $fh->close();
    do $fhname;

    foreach my $k ( keys %cfg ) {
        $defaultCfg{$k} = $cfg{$k};
    }

    Foswiki::Configure::FoswikiCfg::_parse( $fhname, $root, 1 );

    # nothing should have changed
    my $saver = new Foswiki::Configure::FoswikiCfg();
    $saver->{valuer}  = $valuer;
    $saver->{root}    = $root;
    $saver->{content} = '';
    my $out = $saver->_save();
    $this->assert_str_equals( "1;\n", $out );

    # Change some values, make sure they get saved
    $cfg{MandatoryPath}    = 'fixed';
    $cfg{MandatoryBoolean} = 0;
    $cfg{Types}{Chosen}    = 'Foswiki::Configure::Types::STRING';
    $cfg{OptionalRegex}    = qr/^X*$/;
    $cfg{DontIgnore}       = 'now is';
    $saver->{content}      = '';
    $out                   = $saver->_save();
    my $expectacle = <<'EXAMPLE';
$Foswiki::cfg{MandatoryBoolean} = 0;
$Foswiki::cfg{MandatoryPath} = 'fixed';
$Foswiki::cfg{OptionalRegex} = '^X*$';
$Foswiki::cfg{DontIgnore} = 'now is';
$Foswiki::cfg{Types}{Chosen} = 'Foswiki::Configure::Types::STRING';
1;
EXAMPLE
    my @a = split( "\n", $expectacle );
    my @b = split( "\n", $out );

    foreach my $a (@a) {
        $this->assert_str_equals( $a, shift @b );
    }
}

# Test cumulative additions to the config
sub test_2parse {
    my $this = shift;
    my $root = new Foswiki::Configure::Root();

    $this->assert_null( $root->getValueObject('{One}') );
    $this->assert_null( $root->getValueObject('{Two}') );

    my ( $f1, $f1name ) =
      File::Temp::tempfile( DIR => $this->{tempdir} )
      ;    #  File::Temp::tempfile( unlink => 1 );
    print $f1 <<'EXAMPLE';
# **STRING 10**
$Foswiki::cfg{One} = 'One';
1;
EXAMPLE
    $f1->close();
    Foswiki::Configure::FoswikiCfg::_parse( $f1name, $root );

    $this->assert_not_null( $root->getValueObject('{One}') );
    $this->assert_null( $root->getValueObject('{Two}') );

    my ( $f2, $f2name ) =
      File::Temp::tempfile( DIR => $this->{tempdir} )
      ;    #File::Temp::tempfile( unlink => 1 );
    print $f2 <<'EXAMPLE';
# **STRING 10**
$Foswiki::cfg{Two} = 'Two';
1;
EXAMPLE
    $f2->close();
    Foswiki::Configure::FoswikiCfg::_parse( $f2name, $root );

    # make sure they are both present
    $this->assert_not_null( $root->getValueObject('{One}') );
    $this->assert_not_null( $root->getValueObject('{Two}') );
}

sub test_loadpluggables {
    my $this = shift;
    my $root = new Foswiki::Configure::Root();
    my ( $f1, $f1name ) =
      File::Temp::tempfile( DIR => $this->{tempdir} )
      ;    #File::Temp::tempfile( unlink => 1 );
    print $f1 <<'EXAMPLE';
# *LANGUAGES*
# *PLUGINS*
$Foswiki::cfg{Plugins}{CommentPlugin}{Enabled} = 0;
1;
EXAMPLE
    $f1->close();
    Foswiki::Configure::FoswikiCfg::_parse( $f1name, $root );
    my $vo = $root->getValueObject('{Plugins}{CommentPlugin}{Enabled}');
    $this->assert_not_null($vo);
    $this->assert_str_equals( 'BOOLEAN', $vo->getType()->{name} );
    $vo = $root->getValueObject('{Plugins}{TablePlugin}{Enabled}');
    $this->assert_not_null($vo);
    $this->assert_str_equals( 'BOOLEAN', $vo->getType()->{name} );
}

# Test cumulative additions to the config with a potential conflict
sub test_conflict {
    my $this = shift;

    my $root = new Foswiki::Configure::Root();

    my ( $f1, $f1name ) =
      File::Temp::tempfile( DIR => $this->{tempdir} )
      ;    #File::Temp::tempfile( unlink => 1 );
    print $f1 <<'EXAMPLE';
# **STRING 10**
# Good description
$Foswiki::cfg{One} = 'One';
$Foswiki::cfg{Two} = 'One';
1;
EXAMPLE
    $f1->close();
    Foswiki::Configure::FoswikiCfg::_parse( $f1name, $root );

    my $vo = $root->getValueObject('{One}');
    $this->assert_not_null($vo);
    $this->assert_str_equals( "Good description\n", $vo->{desc} );
    $vo = $root->getValueObject('{Two}');
    $this->assert_not_null($vo);

    my ( $f2, $f2name ) =
      File::Temp::tempfile( DIR => $this->{tempdir} )
      ;    #File::Temp::tempfile( unlink => 1 );
    print $f2 <<'EXAMPLE';
$Foswiki::cfg{Two} = 'Two';
# **BOOLEAN 10**
# Bad description
$Foswiki::cfg{One} = 'One';
$Foswiki::cfg{Three} = 'Three';
1;
EXAMPLE
    $f2->close();
    Foswiki::Configure::FoswikiCfg::_parse( $f2name, $root );

    $vo = $root->getValueObject('{One}');
    $this->assert_not_null($vo);
    $this->assert_str_equals( "Good description\n", $vo->{desc} );
    $this->assert_str_equals( 'STRING',             $vo->getType()->{name} );
    $vo = $root->getValueObject('{Two}');
    $this->assert_not_null($vo);
    $this->assert_str_equals( 'UNKNOWN', $vo->getType()->{name} );
    $vo = $root->getValueObject('{Three}');
    $this->assert_not_null($vo);
    $this->assert_str_equals( 'UNKNOWN', $vo->getType()->{name} );
}

sub test_resection {
    my $this       = shift;
    my %defaultCfg = ();
    my %cfg        = ();
    $cfg{One}   = 'One';
    $cfg{Two}   = 'Two';
    $cfg{Three} = 'Three';
    my $valuer = new Foswiki::Configure::Valuer( \%defaultCfg, \%cfg );
    my $root = new Foswiki::Configure::Root();

    my ( $f1, $f1name ) =
      File::Temp::tempfile( DIR => $this->{tempdir} )
      ;    #File::Temp::tempfile( unlink => 1 );
    print $f1 <<'EXAMPLE';
#---+ Section
# ** STRING **
$cfg{One} = 'One';
#---++ Section
$cfg{Two} = 'Two';
# ---+    Section
# ** STRING **
$cfg{Three} = 'Three';
1;
EXAMPLE
    $f1->close();
    Foswiki::Configure::FoswikiCfg::_parse( $f1name, $root, 1 );
    foreach my $k ( keys %cfg ) {
        $defaultCfg{$k} = $cfg{$k};
    }
    $cfg{One}   = 1;
    $cfg{Two}   = 2;
    $cfg{Three} = 3;
    my $saver = new Foswiki::Configure::FoswikiCfg();
    $saver->{valuer}  = $valuer;
    $saver->{root}    = $root;
    $saver->{content} = '';
    my $out         = $saver->_save();
    my $expectorate = <<'SPUTUM';
$Foswiki::cfg{One} = 1;
$Foswiki::cfg{Two} = 2;
$Foswiki::cfg{Three} = 3;
1;
SPUTUM
    $this->assert_str_equals( $expectorate, $out );
}

sub test_UI {
    my $this       = shift;
    my $root       = new Foswiki::Configure::Root();
    my %defaultCfg = ( Value => "before" );
    my %cfg        = ( Value => "after" );
    my $valuer     = new Foswiki::Configure::Valuer( \%defaultCfg, \%cfg );

    my ( $f1, $f1name ) =
      File::Temp::tempfile( DIR => $this->{tempdir} )
      ;    #File::Temp::tempfile( unlink => 1 );
    print $f1 <<'EXAMPLE';
# **STRING 10**
$Foswiki::cfg{One} = 'One';
# **STRING 10**
$Foswiki::cfg{Two} = 'Two';
# ---+ Plugins
# *PLUGINS*
1;
EXAMPLE
    $f1->close();
    Foswiki::Configure::FoswikiCfg::_parse( $f1name, $root );

    foreach my $k ( keys %cfg ) {
        $defaultCfg{$k} = $cfg{$k};
    }

    # deliberately change a value, so we can see it in the HTML
    $defaultCfg{One} = "Eno";

    my $ui       = Foswiki::Configure::UI::loadUI( 'Root', $root );
    my $controls = new Foswiki::Configure::GlobalControls();
    my $result   = $ui->createUI( $root, $valuer, $controls );

    # visual check
    #print $result;
}

#                print F '| ',gmtime(),' | ',$this->{user},' | ',$txt," |\n";
#            if( $Foswiki::cfg{ConfigurationLogName} &&
#                  open(F, '>>'.$Foswiki::cfg{ConfigurationLogName} )) {
#                print F '| ',gmtime(),' | ',$this->{user},' | ',$txt," |\n";
#                close(F);
#            }

#
#  Tests for Configure::Util::mapTarget (RootDir, Filename)
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

    # Remap system web

    $Foswiki::cfg{SystemWebName} = 'Fizbin';
    my $file = 'pub/System/System/MyAtt.gif';
    my $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "$this->{rootdir}pub/Fizbin/System/MyAtt.gif",
        $results );

    $file = 'data/System/System.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "$this->{rootdir}data/Fizbin/System.txt",
        $results );

    # Remap data and pub directory names
    ############Note that in windows \var\www etc _is_ a valid path - it will go into the 'currently selected' drive

    $Foswiki::cfg{PubDir}  = '/var/www/foswiki/public';
    $Foswiki::cfg{DataDir} = '/var/www/foswiki/storage';

    $file = 'pub/Trash/Fizbin/Data.attachment';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/public/$this->{trash_web}/Fizbin/Data.attachment",
        $results );

    $file = 'data/Trash/Fizbin.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/storage/$this->{trash_web}/Fizbin.txt", $results );

    # Verify default Users and Main web names

    $Foswiki::cfg{PubDir}  = '/var/www/foswiki/public';
    $Foswiki::cfg{DataDir} = '/var/www/foswiki/storage';

    $file = 'pub/Users/Fizbin/asdf.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/public/Main/Fizbin/asdf.txt",
        $results );

    $file = 'data/Users/Fizbin.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Main/Fizbin.txt",
        $results );

    # Remap the UsersWebName

    $Foswiki::cfg{UsersWebName} = 'Blah';

    $file = 'pub/Main/Fizbin/Blah.gif';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/public/Blah/Fizbin/Blah.gif",
        $results );

    $file = 'data/Main/Fizbin.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Blah/Fizbin.txt",
        $results );

    # Remap the SandboxWebName

    $Foswiki::cfg{SandboxWebName} = 'Litterbox';

    $file = 'pub/Sandbox/Fizbin/Blah.gif';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/public/Litterbox/Fizbin/Blah.gif", $results );

    $file = 'data/Sandbox/Fizbin.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Litterbox/Fizbin.txt",
        $results );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap the SandboxWebName with Subweb

    $Foswiki::cfg{SandboxWebName} = 'Litterbox';

    $file = 'pub/Sandbox/Beta/Fizbin/Blah.gif';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/public/Litterbox/Beta/Fizbin/Blah.gif", $results );

    $file = 'data/Sandbox/Beta/Fizbin.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/storage/Litterbox/Beta/Fizbin.txt", $results );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  NotifyTopicName - default WebNotify

    $Foswiki::cfg{SandboxWebName} = 'Sandbox';

    $Foswiki::cfg{NotifyTopicName} = 'TellMe';
    $file = 'data/Sandbox/WebNotify.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Sandbox/TellMe.txt",
        $results );

    $file = 'pub/Sandbox/WebNotify/Blah.gif';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/public/Sandbox/TellMe/Blah.gif",
        $results );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  HomeTopicName - default WebHome

    $Foswiki::cfg{SandboxWebName} = 'Sandbox';

    $Foswiki::cfg{HomeTopicName} = 'HomePage';
    $file = 'data/Sandbox/WebHome.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/Sandbox/HomePage.txt",
        $results );

    $file = 'pub/Sandbox/WebNotify/Blah.gif';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/public/Sandbox/TellMe/Blah.gif",
        $results );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  WebPrefsTopicName - default WebPreferences

    $Foswiki::cfg{WebPrefsTopicName} = 'Settings';
    $file = 'data/Sandbox/WebPreferences.txt';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/storage/$this->{sandbox_web}/Settings.txt",
        $results );

    $file = 'pub/Sandbox/WebPreferences/Logo.gif';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals(
        "/var/www/foswiki/public/$this->{sandbox_web}/Settings/Logo.gif",
        $results );

# Remap bin directory and script suffix -  WebPrefsTopicName - default WebPreferences

    $Foswiki::cfg{ScriptSuffix} = '.pl';
    $Foswiki::cfg{ScriptDir}    = 'C:/asdf/cgi-bin';
    $file                       = 'bin/compare';
    $results = Foswiki::Configure::Util::mapTarget( "C:/asdf/", "$file" );
    $this->assert_str_equals( "C:/asdf/cgi-bin/compare.pl", $results );

# Remap bin directory and script suffix -  Include spaces in the path

    $Foswiki::cfg{ScriptSuffix} = '.pl';
    $Foswiki::cfg{ScriptDir}    = 'C:/Program Files (x86)/Apache Software Foundation/Apache2.2/cgi-bin/wiki/bin';
    $file                       = 'bin/compare';
    $results = Foswiki::Configure::Util::mapTarget( 'C:/Program Files (x86)/Apache Software Foundation/Apache2.2/cgi-bin/wiki/', "$file" );
    $this->assert_str_equals( 'C:/Program Files (x86)/Apache Software Foundation/Apache2.2/cgi-bin/wiki/bin/compare.pl', $results );

    # Remap the data/mime.types file location

    $Foswiki::cfg{MimeTypesFileName} = "$Foswiki::cfg{DataDir}/mymime.types";
    $file = 'data/mime.types';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
    $this->assert_str_equals( "/var/www/foswiki/storage/mymime.types",
        $results );

    $Foswiki::cfg{ToolsDir} = '/var/www/foswiki/stuff';
    $file = 'tools/testrun';
    $results =
      Foswiki::Configure::Util::mapTarget( "/var/www/foswiki/", "$file" );
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

}

#
#  Tests for Configure::Util::getMappedWebTopic (Filename)
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

    $Foswiki::cfg{TrashWebName} = $this->{trash_web};

    my $wname = '';
    my $tname = '';

    # Remap system web

    my $file = 'data/System/System.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
    $this->assert_str_equals( 'System', $wname );
    $this->assert_str_equals( 'System', $tname );

    $Foswiki::cfg{SystemWebName} = 'Fizbin';

    $file = 'data/System/System.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
    $this->assert_str_equals( 'Fizbin', $wname );
    $this->assert_str_equals( 'System', $tname );

    # Verify default Users and Main web names

    $file = 'data/Users/Fizbin.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
    $this->assert_str_equals( 'Main',   $wname );
    $this->assert_str_equals( 'Fizbin', $tname );

    # Remap the UsersWebName

    $Foswiki::cfg{UsersWebName} = 'Blah';

    $file = 'data/Main/Fizbin.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
    $this->assert_str_equals( 'Blah',   $wname );
    $this->assert_str_equals( 'Fizbin', $tname );

    # Remap the SandboxWebName

    $Foswiki::cfg{SandboxWebName} = 'Litterbox';

    $file = 'data/Sandbox/Fizbin.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
    $this->assert_str_equals( 'Litterbox', $wname );
    $this->assert_str_equals( 'Fizbin',    $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap the SandboxWebName with Subweb

    $Foswiki::cfg{SandboxWebName} = 'Litterbox';

    $file = 'data/Sandbox/Beta/Fizbin.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
    $this->assert_str_equals( 'Litterbox/Beta', $wname );
    $this->assert_str_equals( 'Fizbin',         $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  NotifyTopicName - default WebNotify

    $Foswiki::cfg{SandboxWebName} = 'Sandbox';

    $Foswiki::cfg{NotifyTopicName} = 'TellMe';
    $file = 'data/Sandbox/WebNotify.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
    $this->assert_str_equals( 'Sandbox', $wname );
    $this->assert_str_equals( 'TellMe',  $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  HomeTopicName - default WebHome

    $Foswiki::cfg{SandboxWebName} = 'Sandbox';

    $Foswiki::cfg{HomeTopicName} = 'HomePage';
    $file = 'data/Sandbox/WebHome.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
    $this->assert_str_equals( 'Sandbox',  $wname );
    $this->assert_str_equals( 'HomePage', $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;

    # Remap topic names -  HomeTopicName - with Subweb and mapped web

    $Foswiki::cfg{SandboxWebName} = 'WorkArea';
    $Foswiki::cfg{HomeTopicName}  = 'HomePage';
    $file                         = 'data/Sandbox/Testing/WebHome.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
    $this->assert_str_equals( 'WorkArea/Testing', $wname );
    $this->assert_str_equals( 'HomePage',         $tname );

    $Foswiki::cfg{SandboxWebName} = $saveSandbox;
    $Foswiki::cfg{HomeTopicName}  = $saveHome;

    # Remap topic names -  WebPrefsTopicName - default WebPreferences

    $Foswiki::cfg{SandboxWebName}    = 'Sandbox';
    $Foswiki::cfg{WebPrefsTopicName} = 'Settings';
    $file                            = 'data/Sandbox/WebPreferences.txt';
    ( $wname, $tname ) = Foswiki::Configure::Util::getMappedWebTopic("$file");
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

}

sub test_Util_listDir {
    my $this = shift;

    my $tempdir = $this->{tempdir} . '/test_Util_ListDir';
    rmtree($tempdir);    # Cleanup any old tests

    mkpath($tempdir);
    mkpath( $tempdir . "/asdf" );
    mkpath( $tempdir . "/asdf/qwerty" );

    _makefile( "$tempdir/asdf/qwerty", "test.txt", "asdfasdf \n" );

    my @dir = Foswiki::Configure::Util::listDir("$tempdir");

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
            @dir = Foswiki::Configure::Util::listDir($tempdir);
        }
    );
    $this->assert_str_equals(
"WARNING: skipping possibly unsafe file (not able to show it for the same reason :( )<br />\n",
        $stdout
    );
    $this->assert_num_equals( 3, $count,
        "listDir returned incorrect number of directories" );

    rmtree($tempdir);

    @dir   = Foswiki::Configure::Util::listDir("$tempdir");
    $count = @dir;
    $this->assert_num_equals( 0, $count,
"listDir returned incorrect number of directories for empty/missing directory"
    );

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
        Foswiki::Configure::Util::getPerlLocation("$tempdir/loctestf") );

    $Foswiki::cfg{ScriptSuffix} = ".pl";
    _doLocationTest( $this, $tempdir, "#!/usr/bin/perl -wT ", "/usr/bin/perl" );

    $Foswiki::cfg{ScriptDir} = $holddir;
    rmtree($tempdir);    # Cleanup any old tests

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
        close($fh);
    }

    my $perl = Foswiki::Configure::Util::getPerlLocation();
    $this->assert_str_equals( $expected, $perl );

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
    _doRewriteTest( $this, $tempdir, '#! /usr/bin/perl -wT',
        '/usr/bin/perl', '#! /usr/bin/perl -wT', 'No change required' );
    _doRewriteTest( $this, $tempdir, '#!/usr/bin/perl -wT',
        '/usr/bin/perl', '#! /usr/bin/perl -wT' );
    _doRewriteTest( $this, $tempdir, '#! /usr/bin/perl ',
        '/usr/bin/perl', '#! /usr/bin/perl ', 'No change required' );
    _doRewriteTest( $this, $tempdir, '#! /usr/bin/perl -wT ',
        '/my/bin/perl', '#! /my/bin/perl -wT ' );
    _doRewriteTest(
        $this, $tempdir,
        '#!/usr/bin/perl -wT',
        'C:\Program Files\Active State\perl.exe',
        '#! C:\Program Files\Active State\perl.exe -wT'
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

    my $err = Foswiki::Configure::Util::rewriteShebang(
        "$tempdir/missing$Foswiki::cfg{ScriptSuffix}",
        "/usr/shebang" );
    $this->assert_str_equals( 'Not a file', $err );

}

sub _doRewriteTest {
    my $this      = shift;
    my $tempdir   = shift;
    my $testline  = shift;
    my $shebang   = shift;
    my $expected  = shift;
    my $errReturn = shift;

    open( my $fh, '>', "$tempdir/myscript$Foswiki::cfg{ScriptSuffix}" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<DONE;
$testline
#!blah
bleh
DONE
    close($fh);

    my $err = Foswiki::Configure::Util::rewriteShebang(
        "$tempdir/myscript$Foswiki::cfg{ScriptSuffix}", "$shebang" );

    if ($errReturn) {
        $this->assert_str_equals( $errReturn, $err );
    }
    else {
        $this->assert_str_equals( '', $err );
        _testShebang( $this, "$tempdir/myscript$Foswiki::cfg{ScriptSuffix}",
            "$expected" );
    }
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
        close $bfh;
    }
    else {
        die "Open failed $! ";
    }

    $this->assert_str_equals( $expected, $ShebangLine );
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
    close($fh);
}

sub test_Package_makeBackup {
    my $this = shift;

    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;

    my $result = '';
    my $err    = '';

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    rmtree($tempdir);    # Clean up old files if left behind
    mkpath($tempdir);

    my $extension = "MyPlugin";
    _makePackage( $tempdir, $extension );

    use Foswiki::Configure::Package;
    my $pkg =
      new Foswiki::Configure::Package( $root, "$extension", $this->{session} );

    ( $result, $err ) =
      $pkg->loadInstaller( { DIR => $tempdir, USELOCAL => 1 } );
    $this->assert( !$err );

    ( $result, $err ) = $pkg->_install( { DIR => $tempdir, EXPANDED => 1 } );

    $this->assert( !$err );

    my $msg = $pkg->createBackup();
    $this->assert_matches( qr/Backup saved into/, $msg );
    $result = $pkg->uninstall();

    my @expFiles = qw(
Testsandboxweb1234/Subweb/TestTopic43.txt
Testsandboxweb1234/TestTopic1.txt
Testsandboxweb1234/TestTopic43.txt
Testsandboxweb1234/Subweb/TestTopic43/file3.att
Testsandboxweb1234/Subweb/TestTopic43/subdir-1.2.3/file4.att
Testsandboxweb1234/TestTopic1/file.att
Testsandboxweb1234/TestTopic43/file.att
Testsandboxweb1234/TestTopic43/file2.att
configure/pkgdata/MyPlugin_installer
);

    push @expFiles, "$this->{scriptdir}/shbtest1";
    push @expFiles, "$this->{toolsdir}/shbtest2";

    foreach my $expFile ( @expFiles ) {
        #print STDERR "Checkkng $expFile\n";
        $this->assert_matches( qr/$expFile/, $result, "Missing file $expFile" );
        }

    $pkg->finish();

}

#
# Utility subroutine to build the files for an installable package
#
sub _makePackage {
    my ( $tempdir, $plugin ) = @_;

    open( my $fh, '>',
        "$tempdir/${plugin}_installer$Foswiki::cfg{ScriptSuffix}" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<'DONE';
#!blah
bleh

sub preuninstall {

    return "Pre-uninstall entered";
}

sub postuninstall {

    # # No POSTUNINSTALL script;
}

sub preinstall {

    return "Pre-install entered";
}

sub postinstall {

    my $this = shift;   # Get the object instance passed to the routine
    if ($this) {        # Verify that you are running in the new environment
DONE
    print $fh "        my \$file = \"$tempdir/obsolete.pl\";\n";
    print $fh <<'DONE';
        return "Removed $file" if unlink $file;
    }
}

Foswiki::Extender::install( $PACKAGES_URL, 'CommentPlugin', 'CommentPlugin', @DATA );

1;
our $VERSION = '2.1';
# MANIFEST and DEPENDENCIES are done this way
# to make it easy to extract them from this script.

__DATA__
<<<< MANIFEST >>>>
bin/shbtest1,0755,
data/Sandbox/TestTopic1.txt,0644,Documentation (noci)
data/Sandbox/TestTopic43.txt,0644,Documentation
data/Sandbox/Subweb/TestTopic43.txt,0644,Documentation
pub/Sandbox/TestTopic1/file.att,0664, (noci)
pub/Sandbox/TestTopic43/file.att,0664,
pub/Sandbox/TestTopic43/file2.att,0664,
pub/Sandbox/Subweb/TestTopic43/file3.att,0644,Documentation
pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att,0644,Documentation
tools/shbtest2,0755,

<<<< MANIFEST2 >>>>
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
.\@#$%}{Filtrx::Invalid::Blah,>=0.68,1,CPAN,Required. install from CPAN
Time::ParseDate,>=2003.0211,1,cpan,Required. Available from the CPAN:Time::ParseDate archive.
Foswiki::Plugins::RequiredTriggeredModule,>=0.1,( $Foswiki::Plugins::VERSION < 3.2 ),perl,Required
Foswiki::Plugins::UnneededTriggeredModule,>=0.1,( $Foswiki::Plugins::VERSION < 2.1 ),perl,Required
Foswiki::Contrib::OptionalDependency,>=14754,1,perl,optional module
Foswiki::Contrib::UnitTestContrib::MultiDottedVersion,>=14754,1,perl,Required
File::Spec, >0,1,cpan,This module is shipped as part of standard perl
Cwd, >55,1,cpan,This module is shipped as part of standard perl
htmldoc, >24.3,1,c,Required for generating PDF

DONE
    close($fh);
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
}

sub test_Package_sub_install {
    my $this = shift;
    my $root = $this->{rootdir};
    use Foswiki::Configure::Package;
    my $result = '';
    my $err    = '';

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    rmtree($tempdir);    # Clean up old files if left behind
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
  #   Make sure that the package is removed, that no old topics were left around
  #
  #
    my $pkg =
      new Foswiki::Configure::Package( $root, 'MyPlugin', $this->{session} );

    ( $result, $err ) =
      $pkg->loadInstaller( { DIR => $tempdir, USELOCAL => 1 } );
    $pkg->uninstall();
    $pkg->finish();
    undef $pkg;

   #
   #   Install the package - as a fresh install, no checkin or rcs files created
   #

    _makePackage( $tempdir, $extension );
    $pkg =
      new Foswiki::Configure::Package( $root, 'MyPlugin', $this->{session} );
    ( $result, $err ) =
      $pkg->loadInstaller( { DIR => $tempdir, USELOCAL => 1 } );
    ( $result, $err ) = $pkg->_install( { DIR => $tempdir, EXPANDED => 1 } );
    $this->assert_str_equals( '', $err );

    my $expresult = "Installed:  bin/shbtest1 as $Foswiki::cfg{ScriptDir}/shbtest1
Installed:  data/Sandbox/Subweb/TestTopic43.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43.txt
Installed:  data/Sandbox/TestTopic1.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1.txt
Installed:  data/Sandbox/TestTopic43.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43.txt
Installed:  pub/Sandbox/Subweb/TestTopic43/file3.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/file3.att
Installed:  pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/subdir-1.2.3/file4.att
Installed:  pub/Sandbox/TestTopic1/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1/file.att
Installed:  pub/Sandbox/TestTopic43/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43/file.att
Installed:  pub/Sandbox/TestTopic43/file2.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43/file2.att
Installed:  tools/shbtest2 as $Foswiki::cfg{ToolsDir}/shbtest2
Installed:  MyPlugin_installer to $Foswiki::cfg{WorkingDir}/configure/pkgdata
";

    $this->assert_str_equals( $expresult, $result,
        'Verify Checked in vs. Installed' );

    my @mfiles = $pkg->listFiles();
    $this->assert_num_equals(
        10,
        scalar @mfiles,
        'Unexpected number of files in manifest'
    );    # 5 files in manifest

    my @ifiles = $pkg->listFiles('1');
    $this->assert_num_equals(
        10,
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

   #
   # Install a 2nd time - RCS files should be created when checkin is requested.
   #
    _makePackage( $tempdir, $extension );

    my $pkg2 =
      new Foswiki::Configure::Package( $root, 'MyPlugin', $this->{session} );
    ( $result, $err ) =
      $pkg2->loadInstaller( { DIR => $tempdir, USELOCAL => 1 } );

    print "ERRORS: $err\n" if ($err);

    $result = '';
    ( $result, $err ) = $pkg2->_install( { DIR => $tempdir, EXPANDED => 1 } );

    $expresult = "Installed:  bin/shbtest1 as $Foswiki::cfg{ScriptDir}/shbtest1
Checked in: data/Sandbox/Subweb/TestTopic43.txt  as $this->{sandbox_subweb}.TestTopic43
Attached:   pub/Sandbox/Subweb/TestTopic43/file3.att to $this->{sandbox_subweb}/TestTopic43
Installed:  data/Sandbox/TestTopic1.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1.txt
Checked in: data/Sandbox/TestTopic43.txt  as $this->{sandbox_web}.TestTopic43
Attached:   pub/Sandbox/TestTopic43/file.att to $this->{sandbox_web}/TestTopic43
Attached:   pub/Sandbox/TestTopic43/file2.att to $this->{sandbox_web}/TestTopic43
Installed:  pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/subdir-1.2.3/file4.att
Installed:  pub/Sandbox/TestTopic1/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1/file.att
Installed:  tools/shbtest2 as $Foswiki::cfg{ToolsDir}/shbtest2
Installed:  MyPlugin_installer to $Foswiki::cfg{WorkingDir}/configure/pkgdata
";

    my @ifiles2 = $pkg2->listFiles('1');

    $this->assert_str_equals( $expresult, $result );
    $this->assert_num_equals(
        15,
        scalar @ifiles2,
        'Unexpected number of files installed on 2nd install: ' . @ifiles2
    );    # + 3 rcs files after checkin
    $this->assert_str_equals( '', $err, "Error $err reported" );

    #
    # Verify the pre/post install exits
    #

    $pkg2->loadExits();
    $this->assert_str_equals( '', $pkg2->errors(), "Load exits failed " );

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
    foreach my $dep ( @{$wiki} ) {
        $mods .= "$dep->{module};";
    }
    $this->assert_str_equals(
"Foswiki::Plugins::RequiredTriggeredModule;Foswiki::Contrib::UnitTestContrib::MultiDottedVersion;",
        $mods, 'Wiki modules to be installed'
    );

    $mods = '';
    foreach my $dep ( @{$install} ) {
        $mods .= "$dep->{module};";
    }
    my $expected =
        'Filtrx::Invalid::Blah;'
      . ( eval "use Time::ParseDate 2003.0211;1;" ? '' : 'Time::ParseDate;' )
      . 'Cwd;';
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

    #print "====== MISSING ========\n$missing\n";
    $this->assert_matches( qr/Filtrx::Invalid::Blah/, $missing,
        'Filtering invalid characters from module name' );
    $this->assert_matches(
        qr/^Foswiki::Plugins::RequiredTriggeredModule(.*)^ -- Triggered by/ms,
        $missing, 'Module requirement triggered by Foswiki API version' );
    $this->assert_does_not_match(
        qr/^Foswiki::Plugins::UnneededTriggeredModule(.*)^ -- Triggered by/ms,
        $missing, 'Module requirement triggered by Foswiki API version' );
    $this->assert_matches(
        qr/^Cwd version > 55 required(.*)^ -- installed version is /ms,
        $missing, 'Test for backlevel module' );
    $this->assert_matches(
qr/^Foswiki::Contrib::OptionalDependency version >=14754 required(.*)^ -- perl module is not installed(.*)^ -- Description: [Oo]ptional module(.*)^ -- Optional dependency will not be automatically installed/ms,
        $missing,
        "Test for optional module - Returned \n$missing\n\n"
    );

    #print "===== INSTALLED =======\n$installed\n";
    $this->assert_matches( qr/^File::Spec(.*)loaded/ms, $installed,
        'Installed module File::Spec' );

    #
    #  Now uninistall the package
    #
    my $results = $pkg2->uninstall();

    my @expFiles = (
'Testsandboxweb1234/Subweb/TestTopic43.txt',
'Testsandboxweb1234/Subweb/TestTopic43.txt,v',
'Testsandboxweb1234/TestTopic1.txt',
'Testsandboxweb1234/TestTopic43.txt',
'Testsandboxweb1234/TestTopic43.txt,v',
'Testsandboxweb1234/Subweb/TestTopic43/file3.att',
'Testsandboxweb1234/Subweb/TestTopic43/file3.att,v',
'Testsandboxweb1234/Subweb/TestTopic43/subdir-1.2.3/file4.att',
'Testsandboxweb1234/TestTopic1/file.att',
'Testsandboxweb1234/TestTopic43/file.att',
'Testsandboxweb1234/TestTopic43/file.att,v',
'Testsandboxweb1234/TestTopic43/file2.att',
'Testsandboxweb1234/TestTopic43/file2.att,v',
'configure/pkgdata/MyPlugin_installer'
);

    push @expFiles, "$this->{scriptdir}/shbtest1";
    push @expFiles, "$this->{toolsdir}/shbtest2";

    foreach my $expFile ( @expFiles ) {
        #print STDERR "Checkkng $expFile\n";
        $this->assert_matches( qr/$expFile/, $results, "Missing file $expFile" );
        }

    $pkg2->finish();
    undef $pkg2;

    rmtree($tempdir);

}

sub test_Package_install {
    my $this = shift;
    my $root = $this->{rootdir};
    use Foswiki::Configure::Package;
    my $result = '';
    my $err    = '';
    my $plugins;
    my $cpan;

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    rmtree($tempdir);    # Clean up old files if left behind
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
    my $pkg =
      new Foswiki::Configure::Package( $root, 'MyPlugin', $this->{session} );
    ( $result, $err ) =
      $pkg->loadInstaller( { DIR => $tempdir, USELOCAL => 1 } );
    $pkg->uninstall();
    $pkg->finish();
    undef $pkg;

   #
   #   Install the package - as a fresh install, no checkin or rcs files created
   #

    _makePackage( $tempdir, $extension );
    $pkg = new Foswiki::Configure::Package(
        $root,
        'MyPlugin',
        $this->{session},
        {
            SIMULATE => 1,           # Don't actually install any files
            DIR      => $tempdir,    # Location of expanded package
            EXPANDED => 1,           # Already expanded
            USELOCAL => 1,           # Use local files don't download
            SHELL    => 1,           # Shell version, no HTML markup
            NODEPS   => 1            # No dependencies
        }
    );
    ( $result, $plugins, $cpan ) = $pkg->install();

    $this->assert_matches( qr/.*MyPlugin-[0-9]{8,8}-[0-9]{6,6}-Install\.log/, $pkg->logfile() );

    foreach my $pn ( keys %$plugins ) {
        print "PLUGIN $pn \n";
    }

    my $cplist = '';
    foreach my $cpdep ( sort { lc($a) cmp lc($b) } keys %$cpan ) {
        $cplist .= "$cpdep;";
    }
    $this->assert_str_equals(
        'Cwd;Filtrx::Invalid::Blah;'
          . (
            eval "use Time::ParseDate 2003.0211;1;" ? '' : 'Time::ParseDate;' ),
        $cplist,
        "Unexpected CPAN Dependencies"
    );

    my $expresult = <<HERE;
Creating Backup of MyPlugin ...

Nothing to backup


Installing MyPlugin...

Simulated - Installed:  bin/shbtest1 as $Foswiki::cfg{ScriptDir}/shbtest1
Simulated - Installed:  data/Sandbox/Subweb/TestTopic43.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43.txt
Simulated - Installed:  data/Sandbox/TestTopic1.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1.txt
Simulated - Installed:  data/Sandbox/TestTopic43.txt as $Foswiki::cfg{DataDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43.txt
Simulated - Installed:  pub/Sandbox/Subweb/TestTopic43/file3.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/file3.att
Simulated - Installed:  pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/Subweb/TestTopic43/subdir-1.2.3/file4.att
Simulated - Installed:  pub/Sandbox/TestTopic1/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic1/file.att
Simulated - Installed:  pub/Sandbox/TestTopic43/file.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43/file.att
Simulated - Installed:  pub/Sandbox/TestTopic43/file2.att as $Foswiki::cfg{PubDir}/$Foswiki::cfg{SandboxWebName}/TestTopic43/file2.att
Simulated - Installed:  tools/shbtest2 as $Foswiki::cfg{ToolsDir}/shbtest2
Simulated - Installed:  MyPlugin_installer to $Foswiki::cfg{WorkingDir}/configure/pkgdata
HERE

    $this->assert_matches( qr#(.*)$expresult(.*)#, $result,
        "Unexpected Installed files from Simulated Install" );

    $expresult = <<'HERE';
====== MISSING ========
Filtrx::Invalid::Blah version >=0.68 required
 -- CPAN module is not installed
 -- Description: Required. install from CPAN

(Time::ParseDate version >=2003.0211 required
 -- cpan module is not installed
 -- Description: Required. Available from the CPAN:Time::ParseDate archive.

)?Foswiki::Plugins::RequiredTriggeredModule version >=0.1 required
 -- perl module is not installed
 -- Triggered by \( \$Foswiki::Plugins::VERSION < 3.2 \)
 -- Description: Required

Foswiki::Contrib::OptionalDependency version >=14754 required
 -- perl module is not installed
 -- Description: optional module
 -- Optional dependency will not be automatically installed

Foswiki::Contrib::UnitTestContrib::MultiDottedVersion version >= 14754 required
 -- installed version is 1.23.4
 -- Description: Required

Cwd version > 55 required
 -- installed version is (.*)?
 -- Description: This module is shipped as part of standard perl

htmldoc is type c, and cannot be automatically checked.
Please check it manually and install if necessary.
 -- Description: Required for generating PDF
HERE

    $this->assert_matches( qr#(.*)$expresult(.*)#, $result,
"Unexpected dependency results from Simulated Install - Returned\n$result\n\nExpected \n$expresult\n\n"
    );

    $pkg->finish();
    undef $pkg;

    rmtree($tempdir);

}

sub test_Util_createArchive_shellZip {
    my $this = shift;

    my $file;
    my $rslt;

    my $tempdir = $this->{tempdir} . '/test_Util_createArchive';
    rmtree($tempdir);    # Clean up old files if left behind

    my $extension = "MyPlugin";
    my $extbkup   = "$extension-backup-20100329-123456";

    mkpath("$tempdir/$extbkup");
    _makePackage( "$tempdir/$extbkup", $extension );

    eval {
        local ( *STDOUT, *STDERR );
        use File::Spec;
        my $blah = system( 'zip -v >' . File::Spec->devnull() . ' 2>&1' );

        #print "zip returns $? ($blah) \n";
        die $! unless ( $? == 0 );
        1;
      }
      or do {
        my $mess = $@;
        $this->expect_failure();
        $this->annotate("CANNOT RUN shell test for zip archive:  $mess");
        $this->assert(0);
      };

    ( $file, $rslt ) =
      Foswiki::Configure::Util::createArchive( "$extbkup", "$tempdir", '0',
        'zip' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create zip archive" );
    $this->assert( ( -e "$tempdir/$extbkup" ),
        "$tempdir was incorrectly removed by the archive operation" );

    ( $file, $rslt ) =
      Foswiki::Configure::Util::createArchive( "$extbkup", "$tempdir", '1',
        'zip' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create zip archive" );
    $this->assert( ( !-e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    unlink "$tempdir/$extbkup";    # Clean up old files if left behind
}

sub test_Util_createArchive_shellTar {
    my $this = shift;

    my $file;
    my $rslt;

    my $tempdir = $this->{tempdir} . '/test_Util_createArchive';
    rmtree($tempdir);              # Clean up old files if left behind

    my $extension = "MyPlugin";
    my $extbkup   = "$extension-backup-20100329-123456";

    mkpath("$tempdir/$extbkup");
    _makePackage( "$tempdir/$extbkup", $extension );

    eval {
        local ( *STDOUT, *STDERR );
        use File::Spec;
        my $blah =
          system( 'tar --version >' . File::Spec->devnull() . ' 2>&1' );

        #print "tar returns $? ($blah) \n";
        die $! unless ( $? == 0 );
        1;
      }
      or do {
        my $mess = $@;
        $this->expect_failure();
        $this->annotate("CANNOT RUN shell test for tar archive:  $mess");
        $this->assert(0);
      };

    ( $file, $rslt ) =
      Foswiki::Configure::Util::createArchive( "$extbkup", "$tempdir", '0',
        'tar' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create tar archive" );
    $this->assert( ( -e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    ( $file, $rslt ) =
      Foswiki::Configure::Util::createArchive( "$extbkup", "$tempdir", '1',
        'tar' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create tar archive" );
    $this->assert( ( !-e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    unlink($file);    # Cleanup for next test

}

sub test_Util_createArchive_perlTar {
    my $this = shift;

    my $file;
    my $rslt;

    my $tempdir = $this->{tempdir} . '/test_Util_createArchive';
    rmtree($tempdir);    # Clean up old files if left behind

    my $extension = "MyPlugin";
    my $extbkup   = "$extension-backup-20100329-123456";

    mkpath("$tempdir/$extbkup");
    _makePackage( "$tempdir/$extbkup", $extension );

    eval 'use Archive::Tar;
       1;
       '
      or do {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN test for tar archive:  $mess");
        $this->assert(0);
      };

    ( $file, $rslt ) =
      Foswiki::Configure::Util::createArchive( "$extbkup", "$tempdir", '0',
        'Ptar' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create Archive::Tar archive" );
    $this->assert( ( -e "$tempdir/$extbkup" ),
        "$tempdir was incorrectly removed by the archive operation" );

    ( $file, $rslt ) =
      Foswiki::Configure::Util::createArchive( "$extbkup", "$tempdir", '1',
        'Ptar' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create Archive::Tar archive" );
    $this->assert( ( !-e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    unlink "$tempdir/$extbkup";    # Clean up old files if left behind
}

sub test_Util_createArchive_perlZip {
    my $this = shift;

    my $file;
    my $rslt;

    my $tempdir = $this->{tempdir} . '/test_Util_createArchive';
    rmtree($tempdir);              # Clean up old files if left behind

    my $extension = "MyPlugin";
    my $extbkup   = "$extension-backup-20100329-123456";

    mkpath("$tempdir/$extbkup");
    _makePackage( "$tempdir/$extbkup", $extension );

    eval 'use Archive::Zip;
       1;
       '
      or do {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN test for zip archive:  $mess");
        $this->assert(0);
      };

    ( $file, $rslt ) =
      Foswiki::Configure::Util::createArchive( "$extbkup", "$tempdir", '0',
        'Pzip' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create Archive::Zip archive" );
    $this->assert( ( -e "$tempdir/$extbkup" ),
        "$tempdir was incorrectly removed by the archive operation" );

    ( $file, $rslt ) =
      Foswiki::Configure::Util::createArchive( "$extbkup", "$tempdir", '1',
        'Pzip' );
    $this->assert( ( -f $file ),
        "$file does not appear to exist - Create Archive::Zip archive" );
    $this->assert( ( !-e "$tempdir/$extbkup" ),
        "$tempdir was not removed by the archive operation" );

    unlink "$tempdir/$extbkup";    # Clean up old files if left behind
}

#
# Determine that installer can download the package from Foswiki.org if not available locally
#
sub test_Package_loadInstaller {
    my $this = shift;
    my $root = $this->{rootdir};

    my $tempdir = $this->{tempdir} . '/test_Package_loadInstaller';
    rmtree($tempdir);              # Clean up old files if left behind
    mkpath($tempdir);

    my $repository = {
        name => 'Foswiki',
        data => 'http://foswiki.org/Extensions/',
        pub  => 'http://foswiki.org/pub/Extensions/'
    };
    my $pkg =
      new Foswiki::Configure::Package( $root, 'EmptyPlugin', $this->{session} );
    $pkg->repository($repository);
    my ( $result, $err ) =
      $pkg->loadInstaller( { DIR => $tempdir, USELOCAL => 1 } );

    chomp $result;
    $this->assert_matches(
qr#Unable to find EmptyPlugin locally in (.*) ...fetching installer from http://foswiki.org/pub/Extensions/ ... succeeded#,
        $result,
        "Unexpected $result from loadInstaller"
    );

    $this->assert_str_equals( '', $err, "Error from loadInstaller $err" );

    my @files = $pkg->listFiles();
    $this->assert_num_equals(
        3,
        scalar @files,
        "Unexpected number of files in EmptyPlugin manifest"
    );

    #
    # Test listPlugins
    #
    my %plugins = $pkg->listPlugins();

    $this->assert_str_equals( '1', $plugins{EmptyPlugin},
        'Failed to discover plugin in manifest' );
    $pkg->finish();
    undef $pkg;
}

sub test_Load_expandValue {
    my $this = shift;

    my $logv = '$Foswiki::cfg{WorkingDir}/test';
    require Foswiki::Configure::Load;
    Foswiki::Configure::Load::expandValue($logv);
    $this->assert_str_equals( "$Foswiki::cfg{WorkingDir}/test", $logv );
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
        my $pkg = new Foswiki::Configure::Package( $root, 'EmptyPlugin' );
        $pkg->repository($repository);

        ( $resp, $file ) = $pkg->_fetchFile('_installer');
        $this->assert_str_equals( '', $resp );
    }
    except {
        my $E = shift;
    }
}

#
# Verify error handling for the Package class
#
sub test_Package_errors {
    my $this = shift;
    my $root = $this->{rootdir};

    my $tempdir = $this->{tempdir} . '/test_Package_loadInstaller';
    rmtree($tempdir);    # Clean up old files if left behind
    mkpath($tempdir);

    my $repository = {
        name => 'Foswiki',
        data => 'http://foswiki.org/Extensions/',
        pub  => 'http://foswiki.org/pub/Extensions/'
    };

    #
    # Verify error when download fails
    #
    my $pkg =
      new Foswiki::Configure::Package( $root, 'EmptyPluginx', $this->{session},
        { DIR => $tempdir, USELOCAL => 1 } );
    $pkg->repository($repository);
    my ( $result, $err ) = $pkg->loadInstaller();

    my $expected = <<HERE;
I can't download http://foswiki.org/pub/Extensions/EmptyPluginx/EmptyPluginx_installer because of the following error:
Not Found
HERE
    $this->assert_matches( qr/$expected/, $pkg->errors(),
        "Unexpected error from download" );

    #
    # Verify error expanding .tgz file
    #
    my $extension = "MyPlugin";
    _makePackage( $tempdir, $extension );

    $pkg =
      new Foswiki::Configure::Package( $root, 'MyPlugin', $this->{session},
        { DIR => $tempdir, USELOCAL => 1 } );
    ( $result, $err ) = $pkg->loadInstaller();

    _makefile( $tempdir, "MyPlugin.tgz", <<'DONE');
Test file data
DONE
    $pkg->_install();

    $this->assert_matches( qr/Failed to unpack archive(.*)MyPlugin.tgz/,
        $pkg->errors(), 'Unexpected results from failed tgz test' );

    unlink $tempdir . "/MyPlugin.tgz";
    $pkg->finish();
    undef $pkg;

    #
    # Verify error expanding .zip file
    #
    $pkg =
      new Foswiki::Configure::Package( $root, 'MyPlugin', $this->{session},
        { DIR => $tempdir, USELOCAL => 1 } );
    ( $result, $err ) = $pkg->loadInstaller();
    _makefile( $tempdir, "MyPlugin.zip", <<'DONE');
Test file data
DONE
    $pkg->_install();
    $this->assert_matches( qr/(format error|unzip failed)/,
        $pkg->errors(), 'Unexpected results from failed zip test' );
    unlink $tempdir . "/MyPlugin.tgz";
    $pkg->finish();
    undef $pkg;

}

1;
