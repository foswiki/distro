# Simple test script for the baseline Configure classes, also useful#
# for testing .spec changes.
#
# Run from the lib/Foswiki/Configure directory.
#
# Reads the .spec (including configured plugins) and, if it is error free,
# LocalSite.cfg, before printing the root as JSON.

use lib '../..';

use Foswiki::Configure::Root;
use Foswiki::Configure::LoadSpec;
use Foswiki::Configure::Load;
use JSON;

my $root = Foswiki::Configure::Root->new();
Foswiki::Configure::LoadSpec::readSpec($root);

#$Foswiki::Configure::LoadSpec::RAW_VALS = 1;
#$Foswiki::Configure::LoadSpec::FIRST_SECTION_ONLY = 1;
if (@Foswiki::Configure::LoadSpec::errors) {
    foreach my $e (@Foswiki::Configure::LoadSpec::errors) {
        print "ERROR " . join( ' ', @$e ) . "\n";
    }
}
else {
    if (@Foswiki::Configure::LoadSpec::warnings) {
        foreach my $e (@Foswiki::Configure::LoadSpec::warnings) {
            print "WARNING " . join( ' ', @$e ) . "\n";
        }
    }
    Foswiki::Configure::Load::readConfig();
    my $json = JSON->new();
    print $json->pretty->convert_blessed->encode($root);
}

1;
