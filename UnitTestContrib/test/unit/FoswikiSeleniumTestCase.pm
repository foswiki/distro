# Base class for tests for browser-in-the-loop tests
#
# The FoswikiFnTestCase restrictions also apply.

package FoswikiSeleniumTestCase;
use base 'FoswikiFnTestCase';

use strict;

use Foswiki;
use Unit::Request;
use Unit::Response;
use Foswiki::UI::Register;
use Error qw( :try );
use Encode;

my $useSeleniumError;
my $browsers;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    $this->{useSeleniumError} = $this->_loadSeleniumInterface;
    $this->{seleniumBrowsers} = $this->_loadSeleniumBrowsers;

    return $this;
}

sub list_tests {
    my ( $this, $suite ) = @_;
    my @set = $this->SUPER::list_tests($suite);

    if ($this->{useSeleniumError}) {
        print STDERR "Cannot run Selenium-based tests: $this->{useSeleniumError}";
		return;
	}
	return @set;
}

sub fixture_groups {
    my ( $this, $suite ) = @_;

    if ($this->{useSeleniumError}) {
        print STDERR "Cannot run Selenium-based tests: $this->{useSeleniumError}";
		return;
	}

	my @groups;

	for my $browser (keys %{ $this->{seleniumBrowsers} })
	{
		my $onBrowser = "on$browser";
		push @groups, $onBrowser;
		my $selenium = $this->{seleniumBrowsers}->{$browser};
		eval "sub $onBrowser { my \$this = shift; \$this->{selenium} = \$selenium; }";
		die $@ if $@;
	}
	return \@groups;
}

sub _loadSeleniumInterface {
	my $this = shift;

	return $useSeleniumError if defined $useSeleniumError;

    eval "use Test::WWW::Selenium";
    if ($@) {
        $useSeleniumError = $@;
        $useSeleniumError =~ s/\(\@INC contains:.*$//s;
		#$this->expect_failure();
		#$this->annotate("CANNOT RUN SELENIUM TESTS: $this->{use_selenium_error}");
    }
	else
	{
		$useSeleniumError = '';
	}
	return $useSeleniumError;
}

sub _loadSeleniumBrowsers {
	my $this = shift;

	return $browsers if $browsers;

	$browsers = {};

	unless ($this->{useSeleniumError}) {
		if ($Foswiki::cfg{UnitTestContrib}{SeleniumRc}) {
			for my $browser (keys %{ $Foswiki::cfg{UnitTestContrib}{SeleniumRc} }) {
				my %config = %{ $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{$browser} };
				$config{host} ||= 'localhost';
				$config{port} ||= 4444;
				$config{browser} ||= '*firefox';
				$config{browser_url} ||= $Foswiki::cfg{DefaultUrlHost};

				$config{error_callback} = sub { $this->assert(0, join(' ', @_)); };

				my $selenium = Test::WWW::Selenium->new( %config );
				if ($selenium) {
    				$browsers->{$browser} = $selenium;
				}
				else {
					print STDERR "Could not create Test::WWW::Selenium object for \$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{$browser}\n";
				}
			}
		}
	}
	if (keys %{ $browsers }) {
		eval "use Test::Builder";
		die $@ if $@;
		my $test = Test::Builder->new;
		$test->no_plan();
		$test->no_diag(1);
		$test->no_ending(1);
		my $testOutput = '';
		$test->output(\$testOutput );
	}

	return $browsers;
}


1;
