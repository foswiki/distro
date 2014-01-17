# See bottom of file for license and copyright information
package EditRowPluginSuite;

use strict;
use warnings;

#use FoswikiFnTestCase;
#our @ISA = 'FoswikiFnTestCase';

use Foswiki::Query::Parser;
use Foswiki::Contrib::DBIStoreContrib::HoistSQL;
my $theParser = new Foswiki::Query::Parser();

# This is an interactive test, allowing you to type in Foswiki queries,
# and inspect the generated SQL and results of the query.
sub test_hoist {
    my $this = shift;
    print "Enter Foswiki query: ";
    my $searchString = <>;
    chomp($searchString);
    my $query = $theParser->parse( $searchString, {} );

    $query = Foswiki::Contrib::DBIStoreContrib::HoistSQL::rewrite($query);
    Foswiki::Contrib::DBIStoreContrib::HoistSQL::reorder( $query, \$query );
    print STDERR "Rewritten "
      . Foswiki::Contrib::DBIStoreContrib::HoistSQL::recreate($query) . "\n";
    my $sql = 'SELECT web,name FROM topic WHERE '
      . Foswiki::Contrib::DBIStoreContrib::HoistSQL::hoist( $query,
        \%hoist_control )
      . ' ORDER BY web,name';
    print STDERR "Generated SQL: $sql\n";
    my $topicSet =
      Foswiki::Contrib::DBIStoreContrib::DBIStore::DBI_query( undef, $sql );

    foreach my $webtopic (@$topicSet) {
        print STDERR "$webtopic\n";
    }
}

while (1) {
    test_hoist;
}

1;
