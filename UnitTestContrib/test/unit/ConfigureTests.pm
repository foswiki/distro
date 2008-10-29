package ConfigureTests;

use strict;

use base qw(TWikiTestCase);

use Error qw( :try );
use File::Temp;

use TWiki::Configure::TWikiCfg;
use TWiki::Configure::Root;
use TWiki::Configure::Valuer;
use TWiki::Configure::UI;

# Parse a cfg; change some values; save the changes
sub test_parseSave {
    my $this = shift;

    my %defaultCfg = (not=>"rag");
    my %cfg = (guff=>"muff");

    my $valuer = new TWiki::Configure::Valuer(\%defaultCfg, \%cfg);
    my $root = new TWiki::Configure::Root();
    my ($fh, $fhname) = File::Temp::tempfile(unlink=>1);
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
# **SELECTCLASS TWiki::Configure::Types::***
$cfg{Types}{Chosen} = 'TWiki::Configure::Types::BOOLEAN';
1;
EXAMPLE
    $fh->close();
    do $fhname;

    foreach my $k (keys %cfg) {
        $defaultCfg{$k} = $cfg{$k};
    }

    TWiki::Configure::TWikiCfg::_parse($fhname, $root, 1);

    # nothing should have changed
    my $saver = new TWiki::Configure::TWikiCfg();
    $saver->{valuer} = $valuer;
    $saver->{root} = $root;
    $saver->{content} = '';
    my $out = $saver->_save();
    $this->assert_str_equals("1;\n", $out);

    # Change some values, make sure they get saved
    $cfg{MandatoryPath} = 'fixed';
    $cfg{MandatoryBoolean} = 0;
    $cfg{Types}{Chosen} = 'TWiki::Configure::Types::STRING';
    $cfg{OptionalRegex} = qr/^X*$/;
    $cfg{DontIgnore} = 'now is';
    $saver->{content} = '';
    $out = $saver->_save();
    my $expectacle = <<'EXAMPLE';
$TWiki::cfg{MandatoryBoolean} = 0;
$TWiki::cfg{MandatoryPath} = 'fixed';
$TWiki::cfg{OptionalRegex} = '^X*$';
$TWiki::cfg{DontIgnore} = 'now is';
$TWiki::cfg{Types}{Chosen} = 'TWiki::Configure::Types::STRING';
1;
EXAMPLE
    my @a = split("\n", $expectacle);
    my @b = split("\n", $out);
    foreach my $a (@a) {
        $this->assert_str_equals($a, shift @b);
    }
}

# Test cumulative additions to the config
sub test_2parse {
    my $this = shift;
    my $root = new TWiki::Configure::Root();

    $this->assert_null($root->getValueObject('{One}'));
    $this->assert_null($root->getValueObject('{Two}'));

    my ($f1, $f1name) = File::Temp::tempfile(unlink=>1);
    print $f1 <<'EXAMPLE';
# **STRING 10**
$TWiki::cfg{One} = 'One';
1;
EXAMPLE
    $f1->close();
    TWiki::Configure::TWikiCfg::_parse($f1name, $root);

    $this->assert_not_null($root->getValueObject('{One}'));
    $this->assert_null($root->getValueObject('{Two}'));

    my ($f2, $f2name) = File::Temp::tempfile(unlink=>1);
    print $f2 <<'EXAMPLE';
# **STRING 10**
$TWiki::cfg{Two} = 'Two';
1;
EXAMPLE
    $f2->close();
    TWiki::Configure::TWikiCfg::_parse($f2name, $root);

    # make sure they are both present
    $this->assert_not_null($root->getValueObject('{One}'));
    $this->assert_not_null($root->getValueObject('{Two}'));
}

sub test_loadpluggables {
    my $this = shift;
    my $root = new TWiki::Configure::Root();
    my ($f1, $f1name) = File::Temp::tempfile(unlink=>1);
    print $f1 <<'EXAMPLE';
# *LANGUAGES*
# *PLUGINS*
$TWiki::cfg{Plugins}{CommentPlugin}{Enabled} = 0;
1;
EXAMPLE
    $f1->close();
    TWiki::Configure::TWikiCfg::_parse($f1name, $root);
    my $vo = $root->getValueObject('{Plugins}{CommentPlugin}{Enabled}');
    $this->assert_not_null($vo);
    $this->assert_str_equals('BOOLEAN', $vo->getType()->{name});
    $vo = $root->getValueObject('{Plugins}{TablePlugin}{Enabled}');
    $this->assert_not_null($vo);
    $this->assert_str_equals('BOOLEAN', $vo->getType()->{name});
}

# Test cumulative additions to the config with a potential conflict
sub test_conflict {
    my $this = shift;

    my $root = new TWiki::Configure::Root();

    my ($f1, $f1name) = File::Temp::tempfile(unlink=>1);
    print $f1 <<'EXAMPLE';
# **STRING 10**
# Good description
$TWiki::cfg{One} = 'One';
$TWiki::cfg{Two} = 'One';
1;
EXAMPLE
    $f1->close();
    TWiki::Configure::TWikiCfg::_parse($f1name, $root);

    my $vo = $root->getValueObject('{One}');
    $this->assert_not_null($vo);
    $this->assert_str_equals("Good description\n", $vo->{desc});
    $vo = $root->getValueObject('{Two}');
    $this->assert_not_null($vo);

    my ($f2, $f2name) = File::Temp::tempfile(unlink=>1);
    print $f2 <<'EXAMPLE';
$TWiki::cfg{Two} = 'Two';
# **BOOLEAN 10**
# Bad description
$TWiki::cfg{One} = 'One';
$TWiki::cfg{Three} = 'Three';
1;
EXAMPLE
    $f2->close();
    TWiki::Configure::TWikiCfg::_parse($f2name, $root);

    $vo = $root->getValueObject('{One}');
    $this->assert_not_null($vo);
    $this->assert_str_equals("Good description\n",
                             $vo->{desc});
    $this->assert_str_equals('STRING', $vo->getType()->{name});
    $vo = $root->getValueObject('{Two}');
    $this->assert_not_null($vo);
    $this->assert_str_equals('UNKNOWN', $vo->getType()->{name});
    $vo = $root->getValueObject('{Three}');
    $this->assert_not_null($vo);
    $this->assert_str_equals('UNKNOWN', $vo->getType()->{name});
}

sub test_resection {
    my $this = shift;
    my %defaultCfg = ();
    my %cfg = ();
    $cfg{One} = 'One';
    $cfg{Two} = 'Two';
    $cfg{Three} = 'Three';
    my $valuer = new TWiki::Configure::Valuer(\%defaultCfg, \%cfg);
    my $root = new TWiki::Configure::Root();

    my ($f1, $f1name) = File::Temp::tempfile(unlink=>1);
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
    TWiki::Configure::TWikiCfg::_parse($f1name, $root, 1);
    foreach my $k (keys %cfg) {
        $defaultCfg{$k} = $cfg{$k};
    }
    $cfg{One} = 1;
    $cfg{Two} = 2;
    $cfg{Three} = 3;
    my $saver = new TWiki::Configure::TWikiCfg();
    $saver->{valuer} = $valuer;
    $saver->{root} = $root;
    $saver->{content} = '';
    my $out = $saver->_save();
    my $expectorate = <<'SPUTUM';
$TWiki::cfg{One} = 1;
$TWiki::cfg{Two} = 2;
$TWiki::cfg{Three} = 3;
1;
SPUTUM
    $this->assert_str_equals($expectorate, $out);
}

sub test_UI {
    my $this = shift;
    my $root = new TWiki::Configure::Root();
    my %defaultCfg = (Value=>"before");
    my %cfg = (Value=>"after");
    my $valuer = new TWiki::Configure::Valuer(\%defaultCfg, \%cfg);

    my ($f1, $f1name) = File::Temp::tempfile(unlink=>1);
    print $f1 <<'EXAMPLE';
# **STRING 10**
$TWiki::cfg{One} = 'One';
# **STRING 10**
$TWiki::cfg{Two} = 'Two';
# ---+ Plugins
# *PLUGINS*
1;
EXAMPLE
    $f1->close();
    TWiki::Configure::TWikiCfg::_parse($f1name, $root);

    foreach my $k (keys %cfg) {
        $defaultCfg{$k} = $cfg{$k};
    }

    # deliberately change a value, so we can see it in the HTML
    $defaultCfg{One} = "Eno";

    my $ui = TWiki::Configure::UI::loadUI('Root', $root);
    my $result = $ui->ui($root, $valuer);
    # visual check
    #print $result;
}

#                print F '| ',gmtime(),' | ',$this->{user},' | ',$txt," |\n";
#            if( $TWiki::cfg{ConfigurationLogName} &&
#                  open(F, '>>'.$TWiki::cfg{ConfigurationLogName} )) {
#                print F '| ',gmtime(),' | ',$this->{user},' | ',$txt," |\n";
#                close(F);
#            }

1;
