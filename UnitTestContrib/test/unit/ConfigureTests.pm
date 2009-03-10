package ConfigureTests;

use strict;

use base qw(FoswikiTestCase);

use Error qw( :try );
use File::Temp;

use Foswiki::Configure::FoswikiCfg;
use Foswiki::Configure::Root;
use Foswiki::Configure::Valuer;
use Foswiki::Configure::UI;

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
    my $result = $ui->ui( $root, $valuer );

    # visual check
    #print $result;
}

#                print F '| ',gmtime(),' | ',$this->{user},' | ',$txt," |\n";
#            if( $Foswiki::cfg{ConfigurationLogName} &&
#                  open(F, '>>'.$Foswiki::cfg{ConfigurationLogName} )) {
#                print F '| ',gmtime(),' | ',$this->{user},' | ',$txt," |\n";
#                close(F);
#            }

1;
