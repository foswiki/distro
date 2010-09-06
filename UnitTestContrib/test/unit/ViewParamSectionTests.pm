use strict;

package ViewParamSectionTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;

use Foswiki;
use Foswiki::UI::View;
use Unit::Request;
use Unit::Response;
my $UI_FN;

my $fatwilly;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $UI_FN ||= $this->getUIFn('view');
    my $query = new Unit::Request();
    $fatwilly = Foswiki->new( undef, $query );
    $this->{request}  = $query;
    $this->{response} = new Unit::Response();
}

sub tear_down {
    my $this = shift;

    $fatwilly->finish();
    $this->SUPER::tear_down();
}

sub _viewSection {
    my ( $this, $section ) = @_;

    $fatwilly->{webName}   = 'TestCases';
    $fatwilly->{topicName} = 'IncludeFixtures';

    $this->{request}->param( '-name' => 'skin', '-value' => 'text' );
    $this->{request}->path_info('TestCases/IncludeFixtures');

    $this->{request}->param( '-name' => 'section', '-value' => $section );
    my ($text) = $this->capture( $UI_FN, $fatwilly );
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
}

# ----------------------------------------------------------------------
# Purpose:  Test a nested section
# Verifies: with parameter section=inner returns only the inner part
sub test_sectionInner {
    my $this = shift;

    my $result = $this->_viewSection('inner');
    $this->assert_matches(
        qr(^\s*This is the whole content of the inner section\s*$)s, $result );
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
}

1;
