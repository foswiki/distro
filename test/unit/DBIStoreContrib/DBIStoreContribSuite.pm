# See bottom of file for license and copyright information
package EditRowPluginSuite;

use strict;
use warnings;

#use FoswikiFnTestCase;
#our @ISA = 'FoswikiFnTestCase';

use Foswiki::Query::Parser;
use Foswiki::Contrib::DBIStoreContrib::HoistSQL;
my $theParser = new Foswiki::Query::Parser();

sub test_hoist {
    my $this = shift;
    print "Enter Foswiki query: ";
    my $searchString = <>;
    chomp($searchString);
    my $query = $theParser->parse( $searchString, {} );
    my $rewrite = Foswiki::Contrib::DBIStoreContrib::HoistSQL::_rewrite($query);
    print STDERR "Rewritten: " . $rewrite->stringify() . "\n";
    my ( $h, @ht ) = Foswiki::Contrib::DBIStoreContrib::HoistSQL::hoist($query);
    print STDERR "HOIST $h IN " . join( ',', @ht ) . "\n";
}
while (1) {
    test_hoist;
}
1;
