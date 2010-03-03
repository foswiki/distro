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

# Parse a cfg; change some values; save the changes
sub test_parseSave {
    my $this = shift;

    my %defaultCfg = ( not  => "rag" );
    my %cfg        = ( guff => "muff" );

    my $valuer = new Foswiki::Configure::Valuer( \%defaultCfg, \%cfg );
    my $root = new Foswiki::Configure::Root();
    my ( $fh, $fhname ) = File::Temp::tempfile( unlink => 1 );
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

    my ( $f1, $f1name ) = File::Temp::tempfile( unlink => 1 );
    print $f1 <<'EXAMPLE';
# **STRING 10**
$Foswiki::cfg{One} = 'One';
1;
EXAMPLE
    $f1->close();
    Foswiki::Configure::FoswikiCfg::_parse( $f1name, $root );

    $this->assert_not_null( $root->getValueObject('{One}') );
    $this->assert_null( $root->getValueObject('{Two}') );

    my ( $f2, $f2name ) = File::Temp::tempfile( unlink => 1 );
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
    my ( $f1, $f1name ) = File::Temp::tempfile( unlink => 1 );
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

    my ( $f1, $f1name ) = File::Temp::tempfile( unlink => 1 );
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

    my ( $f2, $f2name ) = File::Temp::tempfile( unlink => 1 );
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

    my ( $f1, $f1name ) = File::Temp::tempfile( unlink => 1 );
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

    my ( $f1, $f1name ) = File::Temp::tempfile( unlink => 1 );
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

    $Foswiki::cfg{TrashWebName} = 'Dump';
    $Foswiki::cfg{PubDir} = '/var/www/foswiki/pub';
    $Foswiki::cfg{DataDir} = '/var/www/foswiki/data';

# Remap system web

    $Foswiki::cfg{SystemWebName} = 'Fizbin';
    my $file = 'pub/System/System/MyAtt.gif';
    my $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/pub/Fizbin/System/MyAtt.gif', $results );

    $file = 'data/System/System.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/data/Fizbin/System.txt', $results );

# Remap data and pub directory names

    $Foswiki::cfg{PubDir} = '/var/www/foswiki/public';
    $Foswiki::cfg{DataDir} = '/var/www/foswiki/storage';

    $file = 'pub/Trash/Fizbin/Data.attachment';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/public/Dump/Fizbin/Data.attachment', $results );

    $file = 'data/Trash/Fizbin.txt';
    $results = Foswiki::Configure::Util::mapTarget("/var/www/foswiki/", "$file");
    $this->assert_str_equals( '/var/www/foswiki/storage/Dump/Fizbin.txt', $results );

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

}

sub test_Util_listDir {
    my $this = shift;
    use File::Path qw(mkpath rmtree);
 
    my $tempdir = $Foswiki::cfg{TempfileDir} . '/test_Util_ListDir';
    rmtree($tempdir);  # Cleanup any old tests

    mkpath($tempdir);
    mkpath($tempdir."/asdf");
    mkpath($tempdir."/asdf/qwerty");

    open ( FILE, ">$tempdir/asdf/qwerty/test.txt");
    print FILE "asdfasdf \n";
    close FILE;

    my @dir = Foswiki::Configure::Util::listDir("$tempdir");

    my $count = @dir;

    $this->assert_num_equals( 3, $count, "listDir returned incorrect number of directories");
    $this->assert_str_equals( "asdf/qwerty/test.txt", pop @dir, "Wrong directory returned");
    $this->assert_str_equals( "asdf/qwerty/", pop @dir, "Wrong directory returned");
    $this->assert_str_equals( "asdf/", pop @dir, "Wrong directory returned");


    open ( FILE2, ">$tempdir" . '/asdf/qwerty/f~#asdf');
    print FILE2 "asdfasdf \n";
    close FILE2;

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
            };';
        }

    $this->assert_str_equals( "WARNING: skipping possibly unsafe file (not able to show it for the same reason :( )<br />\n", $stdout );
    $this->assert_num_equals( 3, $count, "listDir returned incorrect number of directories");
   
    rmtree($tempdir);

    @dir = Foswiki::Configure::Util::listDir("$tempdir");
    $count = @dir;
    $this->assert_num_equals( 0, $count, "listDir returned incorrect number of directories for empty/missing directory");

}

1;
