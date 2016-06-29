package ViewParamSectionTests;
use v5.14;

use Foswiki();
use Foswiki::UI::View();
use Unit::Response();
my $UI_FN;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

# Set up the test fixture
around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );
    $this->createNewFoswikiApp(
        engineParams => { initialAttributes => { action => 'view', }, }, );

    return;
};

sub _viewSection {
    my ( $this, $section ) = @_;

    $this->app->request->web('TestCases');
    $this->app->request->topic('IncludeFixtures');
    $this->app->request->param( '-name' => 'skin', '-value' => 'text' );
    $this->app->request->path_info('TestCases/IncludeFixtures');

    $this->app->request->param( '-name' => 'section', '-value' => $section );
    my ($text) = $this->capture( sub { $this->app->handleRequest } );
    $text =~ s/(.*?)\r?\n\r?\n//s;

    return ($text);
}

# ----------------------------------------------------------------------
# General:  All tests assume that formatting parameters (especially
#           skin) are applied correctly after the section has been
#           extracted from the topic

# ----------------------------------------------------------------------
# Purpose:  Test a simple section
# Verifies: with parameter section=first returns text of first section
sub test_sectionFirst {
    my $this = shift;

    my $result = $this->_viewSection('first');
    $this->assert_matches( qr(^\s*This is the first section\s*$)s, $result );

    return;
}

# ----------------------------------------------------------------------
# Purpose:  Test a nesting section
# Verifies: with parameter section=outer returns all text parts from
#           outer and inner
sub test_sectionOuter {
    my $this = shift;

    my $result = $this->_viewSection('outer');
    $this->assert_matches( qr(^\s*This is the start of the outer section)s,
        $result );
    $this->assert_matches( qr(This is the whole content of the inner section)s,
        $result );
    $this->assert_matches( qr(This is the end of the outer section\s*$)s,
        $result );

    return;
}

# ----------------------------------------------------------------------
# Purpose:  Test a nested section
# Verifies: with parameter section=inner returns only the inner part
sub test_sectionInner {
    my $this = shift;

    my $result = $this->_viewSection('inner');
    $this->assert_matches(
        qr(^\s*This is the whole content of the inner section\s*$)s, $result );

    return;
}

# ----------------------------------------------------------------------
# Purpose:  Test a non-existing section
# Verifies: with parameter section=notExisting returns nothing
#           (allows one space because the current template ends with
#           a newline)
sub test_sectionNotExisting {
    my $this = shift;

    my $result = $this->_viewSection('notExisting');
    $this->assert_matches( qr/\s*/, $result );

    return;
}

1;
