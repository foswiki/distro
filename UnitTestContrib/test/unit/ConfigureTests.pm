package ConfigureTests;

use strict;

use base qw(FoswikiTestCase);

use Error qw( :try );
use File::Temp;
use FindBin;

use Foswiki::Configure::Util ();
use Foswiki::Configure::FoswikiCfg ();
use Foswiki::Configure::Root ();
use Foswiki::Configure::Valuer ();
use Foswiki::Configure::UI ();
use Foswiki::Configure::GlobalControls ();

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);
    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;

     $this->{rootdir} = $root;
     $this->{user} = $Foswiki::cfg{AdminUserLogin};
     $this->{session} = new Foswiki( $this->{user} );
     $this->{test_web} = 'Testsystemweb1234';
     my $webObject = Foswiki::Meta->new( $this->{session}, $this->{test_web} );
     $webObject->populateNewWeb();
     $this->{trash_web} = 'Testtrashweb1234';
     $webObject = Foswiki::Meta->new( $this->{session}, $this->{trash_web} );
     $webObject->populateNewWeb();
     $this->{sandbox_web} = 'Testsandboxweb1234';
     $webObject = Foswiki::Meta->new( $this->{session}, $this->{sandbox_web} );
     $webObject->populateNewWeb();
     $this->{tempdir} = $Foswiki::cfg{TempfileDir} . '/test_ConfigureTests';
     mkpath($this->{tempdir});


}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $this->{test_web} );
    $this->removeWebFixture( $this->{session}, $this->{trash_web} );
    $this->removeWebFixture( $this->{session}, $this->{sandbox_web} );
    rmtree($this->{tempdir});  # Cleanup any old tests
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

    my ( $f1, $f1name ) =  File::Temp::tempfile( DIR => $this->{tempdir} );  #  File::Temp::tempfile( unlink => 1 );
    print $f1 <<'EXAMPLE';
# **STRING 10**
$Foswiki::cfg{One} = 'One';
1;
EXAMPLE
    $f1->close();
    Foswiki::Configure::FoswikiCfg::_parse( $f1name, $root );

    $this->assert_not_null( $root->getValueObject('{One}') );
    $this->assert_null( $root->getValueObject('{Two}') );

    my ( $f2, $f2name ) =  File::Temp::tempfile( DIR => $this->{tempdir} );  #File::Temp::tempfile( unlink => 1 );
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
    my ( $f1, $f1name ) =  File::Temp::tempfile( DIR => $this->{tempdir} );  #File::Temp::tempfile( unlink => 1 );
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

    my ( $f1, $f1name ) =  File::Temp::tempfile( DIR => $this->{tempdir} );  #File::Temp::tempfile( unlink => 1 );
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

    my ( $f2, $f2name ) =  File::Temp::tempfile( DIR => $this->{tempdir} );  #File::Temp::tempfile( unlink => 1 );
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

    my ( $f1, $f1name ) =  File::Temp::tempfile( DIR => $this->{tempdir} );  #File::Temp::tempfile( unlink => 1 );
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

    my ( $f1, $f1name ) =  File::Temp::tempfile( DIR => $this->{tempdir} );  #File::Temp::tempfile( unlink => 1 );
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

    my $ui = Foswiki::Configure::UI::loadUI( 'Root', $root );
    my $controls = new Foswiki::Configure::GlobalControls();
    my $result = $ui->ui( $root, $valuer, $controls );

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

    my $savePub     = $Foswiki::cfg{PubDir};
    my $saveData    = $Foswiki::cfg{DataDir};
    my $saveTools   = $Foswiki::cfg{ToolsDir};
    my $saveScript  = $Foswiki::cfg{ScriptDir};
    my $saveSuffix  = $Foswiki::cfg{ScriptSuffix};

    my $saveTrash   = $Foswiki::cfg{TrashWebName};
    #my $saveSandbox = $Foswiki::cfg{SandboxWebName};
    my $saveUser    = $Foswiki::cfg{UsersWebName};
    my $saveSystem  = $Foswiki::cfg{SystemWebName};

    my $saveNotify  = $Foswiki::cfg{NotifyTopicName};
    my $saveHome    = $Foswiki::cfg{HomeTopicName};
    my $savePrefs   = $Foswiki::cfg{WebPrefsTopicName};
    my $saveMime    = $Foswiki::cfg{MimeTypesFileName};

    $Foswiki::cfg{TrashWebName} = $this->{trash_web};

# Remap system web

    $Foswiki::cfg{SystemWebName} = 'Fizbin';
    my $file = 'pub/System/System/MyAtt.gif';
    my $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( "$this->{rootdir}pub/Fizbin/System/MyAtt.gif", $results );

    $file = 'data/System/System.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( "$this->{rootdir}data/Fizbin/System.txt", $results );

# Remap data and pub directory names

    $Foswiki::cfg{PubDir} = '/var/www/foswiki/public';
    $Foswiki::cfg{DataDir} = '/var/www/foswiki/storage';

    $file = 'pub/Trash/Fizbin/Data.attachment';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( "/var/www/foswiki/public/$this->{trash_web}/Fizbin/Data.attachment", $results );

    $file = 'data/Trash/Fizbin.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( "/var/www/foswiki/storage/$this->{trash_web}/Fizbin.txt", $results );

# Verify default Users and Main web names

    $Foswiki::cfg{PubDir} = '/var/www/foswiki/public';
    $Foswiki::cfg{DataDir} = '/var/www/foswiki/storage';

    $file = 'pub/Users/Fizbin/asdf.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/public/Main/Fizbin/asdf.txt', $results );

    $file = 'data/Users/Fizbin.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/storage/Main/Fizbin.txt', $results );

# Remap the UsersWebName

    $Foswiki::cfg{UsersWebName} = 'Blah';

    $file = 'pub/Main/Fizbin/Blah.gif';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/public/Blah/Fizbin/Blah.gif', $results );

    $file = 'data/Main/Fizbin.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/storage/Blah/Fizbin.txt', $results );

# Remap the SandboxWebName

    #$Foswiki::cfg{SandboxWebName} = 'Litterbox';

    #$file = 'pub/Sandbox/Fizbin/Blah.gif';
    #$results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    #$this->assert_str_equals( '/var/www/foswiki/public/Litterbox/Fizbin/Blah.gif', $results );

    #$file = 'data/Sandbox/Fizbin.txt';
    #$results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    #$this->assert_str_equals( '/var/www/foswiki/storage/Litterbox/Fizbin.txt', $results );

    #$Foswiki::cfg{SandboxWebName} = 'Sandbox';

# Remap topic names -  NotifyTopicName - default WebNotify

    $Foswiki::cfg{NotifyTopicName} = 'TellMe';
    $file = 'data/Sandbox/WebNotify.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/storage/Sandbox/TellMe.txt', $results );

    $file = 'pub/Sandbox/WebNotify/Blah.gif';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/public/Sandbox/TellMe/Blah.gif', $results );

# Remap topic names -  HomeTopicName - default WebHome

    $Foswiki::cfg{HomeTopicName} = 'HomePage';
    $file = 'data/Sandbox/WebHome.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/storage/Sandbox/HomePage.txt', $results );

    $file = 'pub/Sandbox/WebNotify/Blah.gif';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/public/Sandbox/TellMe/Blah.gif', $results );

# Remap topic names -  WebPrefsTopicName - default WebPreferences

    $Foswiki::cfg{WebPrefsTopicName} = 'Settings';
    $file = 'data/Sandbox/WebPreferences.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/storage/Sandbox/Settings.txt', $results );

    $file = 'pub/Sandbox/WebPreferences/Logo.gif';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/public/Sandbox/Settings/Logo.gif', $results );

# Remap bin directory and script suffix -  WebPrefsTopicName - default WebPreferences

    $Foswiki::cfg{ScriptSuffix} = '.pl';
    $Foswiki::cfg{ScriptDir} = 'C:/asdf/bin/';
    $file = 'bin/compare';
    $results = Foswiki::Configure::Util::mapTarget("C:/asdf/", "$file");
    $this->assert_str_equals( 'C:/asdf/bin/compare.pl', $results );

# Remap the data/mime.types file location

    $Foswiki::cfg{MimeTypesFileName} = "$Foswiki::cfg{DataDir}/mymime.types";
    $file = 'data/mime.types';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/storage/mymime.types', $results );

    $Foswiki::cfg{ToolsDir} = '/var/www/foswiki/stuff';
    $file = 'tools/testrun';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/stuff/testrun', $results );

    $Foswiki::cfg{PubDir} = $savePub;
    $Foswiki::cfg{DataDir} = $saveData;
    $Foswiki::cfg{ToolsDir} = $saveTools;
    $Foswiki::cfg{ScriptDir} = $saveScript;
    $Foswiki::cfg{ScriptSuffix} = $saveSuffix;

    $Foswiki::cfg{UsersWebName} = $saveUser;
    $Foswiki::cfg{SystemWebName} = $saveSystem;
    $Foswiki::cfg{TrashWebName} = $saveTrash;
    #$Foswiki::cfg{SandboxWebName} = $saveSandbox;

    $Foswiki::cfg{WebPrefsTopicName} = $savePrefs;
    $Foswiki::cfg{NotifyTopicName} = $saveNotify;
    $Foswiki::cfg{HomeTopicName} = $saveHome;
    $Foswiki::cfg{MimeTypesFileName} = $saveMime;

}

sub test_Util_listDir {
    my $this = shift;
    use File::Path qw(mkpath rmtree);
 
    my $tempdir = $this->{tempdir} . '/test_Util_ListDir';
    rmtree($tempdir);  # Cleanup any old tests

    mkpath($tempdir);
    mkpath($tempdir."/asdf");
    mkpath($tempdir."/asdf/qwerty");

    _makefile ( "$tempdir/asdf/qwerty", "test.txt", "asdfasdf \n");

    my @dir = Foswiki::Configure::Util::listDir("$tempdir");

    my $count = @dir;

    $this->assert_num_equals( 3, $count, "listDir returned incorrect number of directories");
    $this->assert_str_equals( "asdf/qwerty/test.txt", pop @dir, "Wrong directory returned");
    $this->assert_str_equals( "asdf/qwerty/", pop @dir, "Wrong directory returned");
    $this->assert_str_equals( "asdf/", pop @dir, "Wrong directory returned");


    _makefile ( "$tempdir", "/asdf/qwerty/f~#asdf", "asdfasdf \n");

    my $stdout = '';
    my $stderr = '';

    eval 'use Capture::Tiny';
    if( $@ ) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN listDir test for illegal file names:  $mess");
    } else {
        eval 'use Capture::Tiny qw/capture/;
            ($stdout, $stderr) = capture {
                 @dir= Foswiki::Configure::Util::listDir("$tempdir") ;
            };
            $this->assert_str_equals( "WARNING: skipping possibly unsafe file (not able to show it for the same reason :( )<br />\n", $stdout );
            $this->assert_num_equals( 3, $count, "listDir returned incorrect number of directories");
            ';
        }

   
    rmtree($tempdir);

    @dir = Foswiki::Configure::Util::listDir("$tempdir");
    $count = @dir;
    $this->assert_num_equals( 0, $count, "listDir returned incorrect number of directories for empty/missing directory");

}

sub test_getPerlLocation {
    my $this = shift;

    use File::Path qw(mkpath rmtree);
 
    my $tempdir = $this->{tempdir} . '/test_util_getperllocation';
    mkpath($tempdir); 

    my $holddir = $Foswiki::cfg{ScriptDir};
    $Foswiki::cfg{ScriptDir} = "$tempdir/";
    my $holdsfx = $Foswiki::cfg{ScriptSuffix};
    
    _doLocationTest($this, $tempdir, "#!/usr/bin/perl -w -T ", "/usr/bin/perl" ); 
    _doLocationTest($this, $tempdir, "#!/usr/bin/perl  ", "/usr/bin/perl" ); 
    _doLocationTest($this, $tempdir, "#!/usr/bin/perl -wT ", "/usr/bin/perl" ); 
    _doLocationTest($this, $tempdir, "#!/usr/bin/perl -wT", "/usr/bin/perl" ); 
    _doLocationTest($this, $tempdir, "#! /usr/bin/perl    -wT ", "/usr/bin/perl" ); 
    _doLocationTest($this, $tempdir, "#! /usr/bin/perl -wT ", "/usr/bin/perl" ); 
    _doLocationTest($this, $tempdir, "#! /usr/bin/perl", "/usr/bin/perl" ); 
    _doLocationTest($this, $tempdir, "#!    /usr/bin/perl        ", "/usr/bin/perl" ); 
    _doLocationTest($this, $tempdir, "#! perl  -wT ", "perl" ); 
    _doLocationTest($this, $tempdir, "#!C:\\Progra~1\\Strawberry\\bin\\perl.exe  -wT ", "C:\\Progra~1\\Strawberry\\bin\\perl.exe" ); 
    _doLocationTest($this, $tempdir, "#!c:\\strawberry\\perl\\bin\\perl.exe  -w ", "c:\\strawberry\\perl\\bin\\perl.exe" ); 
    _doLocationTest($this, $tempdir, "#!C:\\Program Files\\Strawberry\\bin\\perl.exe  -wT ", "C:\\Program Files\\Strawberry\\bin\\perl.exe" ); 
    _doLocationTest($this, $tempdir, "#! C:\\Program Files\\Strawberry\\bin\\perl.exe", "C:\\Program Files\\Strawberry\\bin\\perl.exe" ); 

    $Foswiki::cfg{ScriptSuffix} = ".pl";
    _doLocationTest($this, $tempdir, "#!/usr/bin/perl -wT ", "/usr/bin/perl" ); 

    $Foswiki::cfg{ScriptDir} = $holddir;
    rmtree($tempdir);  # Cleanup any old tests

    }

sub _doLocationTest {
    my $this = shift;
    my $tempdir = shift;
    my $shbang = shift;
    my $expected = shift;
   
    open (my $fh, ">$tempdir/configure$Foswiki::cfg{ScriptSuffix}") || die "Unable to open \n $! \n\n ";
    print $fh "$shbang \n";
    close ($fh);

    my $perl = Foswiki::Configure::Util::getPerlLocation();
    $this->assert_str_equals( $expected, $perl );

}

sub test_rewriteShbang {
    my $this = shift;

    use File::Path qw(mkpath rmtree);
 
    my $tempdir = $this->{tempdir} . '/test_util_rewriteShbang';
    mkpath($tempdir); 

    #                                Template File         Shbang to write       Expected line
    _doRewriteTest($this, $tempdir, '#!/usr/bin/perl -wT', 'C:\asdf\perl.exe', '#! C:\asdf\perl.exe -wT');
    _doRewriteTest($this, $tempdir, '#!/usr/bin/perl -wT', '/usr/bin/perl', '#! /usr/bin/perl -wT');
    _doRewriteTest($this, $tempdir, '#! /usr/bin/perl -wT', '/usr/bin/perl', '#! /usr/bin/perl -wT');
    _doRewriteTest($this, $tempdir, '#! /usr/bin/perl ', '/usr/bin/perl', '#! /usr/bin/perl -wT');
    _doRewriteTest($this, $tempdir, '#! /usr/bin/perl', '/usr/bin/perl', '#! /usr/bin/perl -wT');
    _doRewriteTest($this, $tempdir, '#! /usr/bin/perl', '/usr/bin/perl', '#! /usr/bin/perl -wT');
    _doRewriteTest($this, $tempdir, '#!/usr/bin/perl -wT', 'C:\Program Files\Active State\perl.exe', '#! C:\Program Files\Active State\perl.exe -wT');

}    

sub _doRewriteTest {
    my $this = shift;
    my $tempdir = shift;
    my $testline = shift;
    my $shbang = shift;
    my $expected = shift;
   
    open (my $fh, ">$tempdir/myscript$Foswiki::cfg{ScriptSuffix}") || die "Unable to open \n $! \n\n ";
    print $fh <<DONE;
$testline
#!blah
bleh
DONE
    close ($fh);

    my $err = Foswiki::Configure::Util::rewriteShbang("$tempdir/myscript$Foswiki::cfg{ScriptSuffix}", '$shbang');

    open (BINCFG, '<', "$Foswiki::cfg{ScriptDir}/myscript$Foswiki::cfg{ScriptSuffix}") 
        || return '' ;
    my $shBangLine  = <BINCFG>;
    chomp $shBangLine;

    $this->assert_str_equals( $expected, $shBangLine );

}

sub _test_extractPkgData {
    my $this = shift;
    my $tempdir = $this->{_tempdir};

    my %MANIFEST;
    my %DEPENDENCIES;

    my $extension = "MyPlugin";
    my $err = Foswiki::Configure::Util::extractPkgData($tempdir, $extension, \%MANIFEST, \%DEPENDENCIES );

    $this->assert_str_equals( '1a9a1da563535b2dad241d8571acd170', $MANIFEST{'data/System/FamFamFamContrib.txt'}{md5} );
    $this->assert_str_equals( '1', $MANIFEST{'data/System/FamFamFamContrib.txt'}{ci} );
    $this->assert_str_equals( '0644', $MANIFEST{'data/System/FamFamFamContrib.txt'}{perms} );
    $this->assert_str_equals( '0664', $MANIFEST{'pub/System/FamFamFamFlagIcons/ae.png'}{perms} );
    $this->assert_str_equals( '0', $MANIFEST{'pub/System/FamFamFamFlagIcons/ae.png'}{ci} );

    $this->assert_str_equals( '>=0.68', $DEPENDENCIES{'SOAP::Lite'}{condition} );
    $this->assert_str_equals( 'CPAN', $DEPENDENCIES{'SOAP::Lite'}{type} );
    $this->assert_str_equals( '1', $DEPENDENCIES{'SOAP::Lite'}{trigger} );
    $this->assert_str_equals( 'Required. install from CPAN', $DEPENDENCIES{'SOAP::Lite'}{desc} );
    $this->assert_str_equals( '', $DEPENDENCIES{'ImageMagick'}{desc} );
    $this->assert_str_equals( '', $DEPENDENCIES{'ImageMagick'}{type} );

    #for my $key ( keys %MANIFEST ) {
    #    my $md5 = $MANIFEST{$key}{md5} || '';
    #    print "FILE:  $key PERM: $MANIFEST{$key}{perms}  CI: $MANIFEST{$key}{ci}  MD5: $md5 \n";
    #    }
    
    $extension = "NotHere";
    #$err = Foswiki::Configure::Util::extractPkgData($tempdir, $extension, \%MANIFEST, \%DEPENDENCIES );
    $this->assert_str_equals('ERROR - Extension NotHere package not found ',  $err );

    my $key;
    my $k2;

    foreach $key ( keys %{ $MANIFEST{ATTACH} } ) {
       print "ATTACH key = $key \n";
       foreach  $k2 ( keys %{ $MANIFEST{ATTACH}{"$key"} }) {
            print "ATTACH key = $key, $k2, $MANIFEST{ATTACH}{$key}{$k2} \n";
            }
        }

    rmtree($tempdir); 
}

sub _test_applyManifest {
    my $this = shift;

    my $tempdir = $this->{tempdir} . '/test_util_applyManifest';
    rmtree($tempdir);  # Clean up old files if left behind 
    mkpath($tempdir); 
    
    $Foswiki::cfg{DataDir} = "$tempdir/data";

    open (my $fh, '>',  "$tempdir/MyPlugin_installer$Foswiki::cfg{ScriptSuffix}") || die "Unable to open \n $! \n\n ";
    print $fh <<DONE;
#!blah
bleh
__DATA__
<<<< MANIFEST >>>>
data/test.txt,0606,Documentation
lib/MyMod.pm,0444,Perl module

DONE
    close ($fh);

    my %MANIFEST;
    my %DEPENDENCIES;

    my $extension = "MyPlugin";
    my $err = Foswiki::Configure::Util::extractPkgData($tempdir, $extension, \%MANIFEST, \%DEPENDENCIES );

    $this->assert_str_equals( '0606', $MANIFEST{'data/test.txt'}{perms} );
    $this->assert_str_equals( '0444', $MANIFEST{'lib/MyMod.pm'}{perms} );

    my @files = ('data/test.txt','lib/MyMod.pm');


    _makefile ( "$tempdir/lib", "MyMod.pm", "asdfasdf\n");
    _makefile ( "$tempdir/data", "test.txt");

    Foswiki::Configure::Util::applyManifest( $tempdir, \@files, \%MANIFEST );

    $this->assert_num_equals( 0444, (stat("$tempdir/lib/MyMod.pm"))[2] & 07777 );
    $this->assert_num_equals( 0606, (stat("$tempdir/data/test.txt"))[2] & 07777 );


    rmtree($tempdir); 
}

sub _makefile {
    my $path = shift;
    my $file = shift;
    my $content = shift;

    $content = "datadata/n" unless ($content);

    mkpath("$path");
    open ( my $fh, '>', "$path/$file");
    print $fh "$content \n";
    close ($fh);
}

sub _test_removeManifestFiles {
    my $this = shift;

    my $tempdir = $this->{tempdir} . '/test_util_removeManifestFiles';
    rmtree($tempdir);  # Clean up old files if left behind 
    mkpath($tempdir); 
    
    $Foswiki::cfg{DataDir} = "$tempdir/data";

    open (my $fh, ">$tempdir/MyPlugin_installer$Foswiki::cfg{ScriptSuffix}") || die "Unable to open \n $! \n\n ";
    print $fh <<DONE;
#!blah
bleh
__DATA__
<<<< MANIFEST >>>>
data/test.txt,0606,Documentation
lib/MyMod.pm,0444,Perl module

DONE
    close ($fh);

    my %MANIFEST;
    my %DEPENDENCIES;

    my $extension = "MyPlugin";
    my $err = Foswiki::Configure::Util::extractPkgData($tempdir, $extension, \%MANIFEST, \%DEPENDENCIES );

    my @files = ('data/test.txt','lib/MyMod.pm');

    _makefile ( "$tempdir/lib", "MyMod.pm", "asdfasdf\n");
    chmod ('0400', "$tempdir/lib/MyMod.pm");  #write protect 
    _makefile ( "$tempdir/data", "test.txt", "asdfasdf\n");
    _makefile ( "$tempdir/data", "test.txt,v", "asdfasdf\n");
    chmod ('0400', "$tempdir/data/test.txt,v");  #write protect 

    my @removed = Foswiki::Configure::Util::removeManifestFiles( $tempdir, \%MANIFEST );

    my $cnt = @removed;

    $this->assert_num_equals( 3, $cnt);

    $this->assert( !-e "$tempdir/data/test.txt");
    $this->assert( !-e "$tempdir/data/test.txt,v");
    $this->assert( !-e "$tempdir/lib/MyMod.pm");

    rmtree($tempdir); 
}


sub test_makeBackup {
    my $this = shift;

    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);
    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;

    my $result = '';
    my $err = '';

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    rmtree($tempdir);  # Clean up old files if left behind 
    mkpath($tempdir); 

    my $extension = "MyPlugin";
    _makePackage ($tempdir, $extension);

    use Foswiki::Configure::Package;
    my $pkg = new Foswiki::Configure::Package ($root, "$extension", 'Plugin', $this->{session} );

    ($result, $err)  = $pkg->loadInstaller($tempdir);
    $this->assert_str_equals( '', $err ); 

    ($result, $err) = $pkg->install($tempdir);

    my $msg = $pkg->createBackup();
    $this->assert_str_equals( 'Backup saved into', substr($msg, 0,17) );
    #print "$msg \n";

}

sub _makePackage {
    my ($tempdir, $plugin) = @_;

    open (my $fh, '>', "$tempdir/${plugin}_installer$Foswiki::cfg{ScriptSuffix}") || die "Unable to open \n $! \n\n ";
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
        my $mapped = Foswiki::Configure::Util::mapTarget( $this->{_rootdir},
        'tools/obsolete.pl');
        my $count = unlink $mapped if ( -e $mapped );
        return "Removed $mapped \n " if ($count);
        }
}

Foswiki::Extender::install( $PACKAGES_URL, 'CommentPlugin', 'CommentPlugin', @DATA );

1;

# MANIFEST and DEPENDENCIES are done this way
# to make it easy to extract them from this script.

__DATA__
<<<< MANIFEST >>>>
data/Sandbox/TestTopic1.txt,0644,Documentation (noci)
data/Sandbox/TestTopic43.txt,0644,Documentation 
pub/Sandbox/TestTopic1/file.att,0664, (noci) 
pub/Sandbox/TestTopic43/file.att,0664, 
pub/Sandbox/TestTopic43/file2.att,0664, 

<<<< MANIFEST2 >>>>
data/Sandbox/TestTopic1.txt,0644,1a9a1da563535b2dad241d8571acd170,Documentation (noci)
data/Sandbox/TestTopic43.txt,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation 
pub/Sandbox/TestTopic1/file.att,0664,ede33d5e092a0cb2fa00d9146eed5f9a, (noci) 
pub/Sandbox/TestTopic43/file.att,0664,1a9a1da563535b2dad241d8571acd170, 
pub/Sandbox/TestTopic43/file2.att,0664,ede33d5e092a0cb2fa00d9146eed5f9a,

<<<< DEPENDENCIES >>>>
.\@#$%}{SOAP::Lite,>=0.68,1,CPAN,Required. install from CPAN
Time::ParseDate,>=2003.0211,1,cpan,Required. Available from the CPAN:Time::ParseDate archive.
Foswiki::Contrib::JSCalendarContrib,>=0.961,1,perl,Optional, used if installed. Used to display a neat calendar popup when editing actions. Available from the Foswiki:Extensions/JSCalendarContrib repository.
Foswiki::Contrib::BehaviourContrib,>=0,1,perl,Javascript module
Foswiki::Plugins::WysiwygPlugin,>=4315,1,perl,Translator module
Foswiki::Plugins::JQueryPlugin,>=0.5,1,perl,Required if using jquery twisties.
Foswiki::Plugins::DojoToolkitContrib,>=0,1,perl,Required if using dojo twisties.
Foswiki::Contribs::FamFamFamContrib,>=0,1,perl,Icons
FCGI, >0.67,1,cpan,FastCGI perl library
File::Spec, >0,1,cpan,This module is shipped as part of standard perl
Cwd, >0,1,cpan,This module is shipped as part of standard perl
POSIX, >0,1,cpan,This module is shipped as part of standard perl
Getopt::Long, >2.37,1,cpan,Extended processing of command line options
Pod::Usage, >1.35,1,cpan,print a usage message from embedded pod documentation


DONE
    close ($fh);
    _makefile ( "$tempdir/data/Sandbox", "TestTopic1.txt", <<'DONE');
%META:TOPICINFO{author="BaseUserMapping_333" comment="reprev" date="1267729185" format="1.1" reprev="1.1" version="1.1"}%
Test rev 132412341234
==qr/[\s\*?~^\$@%`"'&;|&lt;&gt;\[\]\x00-\x1f]/;==

-- Main.AdminUser - 04 Mar 2010
DONE
    _makefile ( "$tempdir/data/Sandbox", "TestTopic43.txt", <<'DONE');
%META:TOPICINFO{author="BaseUserMapping_333" comment="reprev" date="1267729185" format="1.1" reprev="1.1" version="1.1"}%
Test rev 132412341234
==qr/[\s\*?~^\$@%`"'&;|&lt;&gt;\[\]\x00-\x1f]/;==

-- Main.AdminUser - 04 Mar 2010
DONE
    _makefile ( "$tempdir/pub/Sandbox/TestTopic1", "file.att", <<'DONE');
Test file data
DONE
    _makefile ( "$tempdir/pub/Sandbox/TestTopic43", "file.att", <<'DONE');
Test file data
DONE
    _makefile ( "$tempdir/pub/Sandbox/TestTopic43", "file2.att", <<'DONE');
Test file data
DONE

}

sub test_Package {
    my $this = shift;
    my $root = $this->{rootdir};
    use Foswiki::Configure::Package;
    my $result = '';
    my $err = '';

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    rmtree($tempdir);  # Clean up old files if left behind 
    mkpath($tempdir); 
   
    _makefile ( "$root/tools", "obsolete.pl", <<'DONE');
Test file data
DONE

    my $extension = "MyPlugin";
    _makePackage ($tempdir, $extension);

    #
    #   Make sure that the package is removed, that no old topics were left around
    #
    #
    my $pkg = new Foswiki::Configure::Package ($root, 'MyPlugin', 'Plugin', $this->{session});
    ($result, $err) = $pkg->loadInstaller($tempdir);
    $pkg->uninstall();
    $pkg->finish();
    undef $pkg;
    

    #
    #   Install the package - as a fresh install, no checkin or rcs files created
    #

    _makePackage ($tempdir, $extension);
    $pkg = new Foswiki::Configure::Package ($root, 'MyPlugin', 'Plugin', $this->{session});
    ($result, $err) = $pkg->loadInstaller($tempdir);
    ($result, $err) = $pkg->install($tempdir);
    $this->assert_str_equals( '', $err ); 

    my $expresult = "Installed:  data/Sandbox/TestTopic1.txt
Installed:  data/Sandbox/TestTopic43.txt
Installed:  pub/Sandbox/TestTopic1/file.att
Installed:  pub/Sandbox/TestTopic43/file.att
Installed:  pub/Sandbox/TestTopic43/file2.att
Installed:  MyPlugin_installer
";

    $this->assert_str_equals( $expresult, $result, 'Verify Checked in vs. Installed');

    my @mfiles = $pkg->files();
    $this->assert_num_equals( 5, scalar @mfiles, 'Unexpected number of files in manifest'); # 5 files in manifest

    my @ifiles = $pkg->files('1');
    $this->assert_num_equals( 5, scalar @ifiles, 'Unexpected number of files installed');   # and 5 files installed 

    $pkg->finish();
    undef $pkg;

    #
    # Install a 2nd time - RCS files should be created when checkin is requested.
    #
    _makePackage ($tempdir, $extension);

    my $pkg2 = new Foswiki::Configure::Package ($root, 'MyPlugin', 'Plugin', $this->{session});
    ($result, $err) = $pkg2->loadInstaller($tempdir);

    $result = '';
    ($result, $err) = $pkg2->install($tempdir);

    $expresult = "Installed:  data/Sandbox/TestTopic1.txt
Checked in: data/Sandbox/TestTopic43.txt  as Sandbox.TestTopic43
Attached:   pub/Sandbox/TestTopic43/file.att to Sandbox/TestTopic43
Attached:   pub/Sandbox/TestTopic43/file2.att to Sandbox/TestTopic43
Installed:  pub/Sandbox/TestTopic1/file.att
Installed:  MyPlugin_installer
";
    my @ifiles2 = $pkg2->files('1');

    $this->assert_str_equals( $expresult, $result, 'Verify Checked in vs. Installed');
    $this->assert_num_equals( 8, scalar @ifiles2, 'Unexpected number of files installed on 2nd install ');   # + 3 rcs files after checkin
    $this->assert_str_equals( '', $err, "Error $err remported" ); 
     
    $this->assert_str_equals( 'Pre-uninstall entered', $pkg2->preuninstall());
    $this->assert_str_equals( 'Pre-install entered', $pkg2->preinstall());
    $this->assert_null( $pkg2->postuninstall());
    $this->assert_str_equals( 'Removed ', substr( $pkg2->postinstall(), 0, 8));

    my ($installed, $missing,  @install, @cpan) = $pkg2->checkDependencies();
    print "===== INSTALLED =======\n$installed\n";
    print "====== MISSING ========\n$missing\n";

    #  
    #  Now uninistall the package
    #
    my @ufiles = $pkg2->uninstall();

    $this->assert_num_equals( 9, scalar @ufiles, 'Unexpected number of files uninstalled'); # 8 files + the installer file are removed

    foreach my $f ( @ufiles ) {
       $this->assert( (! -e $f), "File $f not deleted" );
       }

    $pkg2->finish();
    undef $pkg2;

    rmtree($tempdir);

}

#sub test_Util_createArchive {

#    my ($rslt, $err) = Foswiki::Configure::Util::createArchive( 'GenPDFAddOn-backup-20100319-195250', '/var/www/SVN/foswiki/core/working/configure/backup/', '0');

#    print "createArchive Error $err \n" if ($err);

#}

sub test_Load_expandValue {
    my $this = shift;
    #$Foswiki::cfg{WorkingDir} = '/tmp/asdf';
    my $logv = '$Foswiki::cfg{WorkingDir}/test';
    require Foswiki::Configure::Load;
    Foswiki::Configure::Load::expandValue($logv);
    $this->assert_str_equals( "$Foswiki::cfg{WorkingDir}/test", $logv ); 
}


1;
