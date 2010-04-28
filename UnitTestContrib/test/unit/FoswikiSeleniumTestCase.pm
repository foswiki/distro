# Base class for tests for browser-in-the-loop tests
#
# The FoswikiFnTestCase restrictions also apply.

package FoswikiSeleniumTestCase;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;

use Foswiki;
use Unit::Request;
use Unit::Response;
use Foswiki::UI::Register;
use Error qw( :try );
use Encode;
use Scalar::Util qw( weaken );

my $startWait;
my $doze;
BEGIN {
    eval "use Time::HiRes qw/usleep time/;";
    if (not $@) {
        $startWait = sub{ return time(); };
        # success
        $doze = sub {
            usleep(100_000);
            return (time() - $_[0]) * 1000;
        };
    }
    else {
        # use failed
        $startWait = sub{ return time(); };
        $doze = sub {
            sleep(1);
            return (time() - $_[0]) * 1000;
        };
    }
}

my $useSeleniumError;
my $browsers;
my @BrowserFixtureGroups;
my $currentTest;

my $debug = 0;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    if (defined $currentTest) {
        $this->assert(0,
            "There may only be one FoswikiSeleniumTestCase-based test\n"
            . "running in each test process.\n"
            . "Cannot run the $class test \n"
            . "because the $currentTest is still running.");
    }
    $currentTest = $this;
    weaken($currentTest); # Ensure the destructor is called at the normal time

    $this->{selenium_timeout} = 30_000; # Same as WWW::Selenium's default value
    $this->{useSeleniumError} = $this->_loadSeleniumInterface;
    $this->{seleniumBrowsers} = $this->_loadSeleniumBrowsers;

    $this->timeout($Foswiki::cfg{UnitTestContrib}{SeleniumRc}{BaseTimeout});

    return $this;
}

END {
    _shutDownSeleniumBrowsers() if $browsers;
}

sub DESTROY {
    my $this = shift;
    if (not defined($currentTest) or $currentTest != $this) {
        $this->assert(0,
            "Unexpected change of current test:"
          . "Expected $this but found $currentTest");
    }
    $this->SUPER::DESTROY if $this->can('SUPER::DESTROY');
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

    return \@BrowserFixtureGroups if @BrowserFixtureGroups;

    for my $browser (keys %{ $this->{seleniumBrowsers} })
    {
        my $onBrowser = "on$browser";
        push @BrowserFixtureGroups, $onBrowser;
        my $selenium = $this->{seleniumBrowsers}->{$browser};
        eval "sub $onBrowser { my \$this = shift; \$this->{browser} = \$browser; \$this->{selenium} = \$selenium; }";
        die $@ if $@;
    }
    return \@BrowserFixtureGroups;
}

sub _loadSeleniumInterface {
    my $this = shift;

    return $useSeleniumError if defined $useSeleniumError;

    eval "use Test::WWW::Selenium";
    if ($@) {
        $useSeleniumError = $@;
        $useSeleniumError =~ s/\(\@INC contains:.*$//s;
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
        if ($Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers}) {
            for my $browser (keys %{ $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers} }) {
                my %config = %{ $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers}{$browser} };
                $config{host} ||= 'localhost';
                $config{port} ||= 4444;
                $config{browser} ||= '*firefox';
                $config{browser_url} ||= $Foswiki::cfg{DefaultUrlHost};

                # The error callback needs a reference to the current test
                # object. There may be several test objects that use the
                # selenium interface, so the error callback cannot be a 
                # closure (anonymous sub) that uses $this (because $this
                # in a closure would always refers to the first test
                # to run that is derived from FoswikiSeleniumTestCase).
                # Instead, the error callback uses a static class variable
                # that is set (and weakened) in the constructor.
                $config{error_callback} = \&_errorCallback;

                my $selenium = Test::WWW::Selenium->new( %config );
                if ($selenium) {
                    $browsers->{$browser} = $selenium;
                }
                else {
                    $this->assert(0, "Could not create a Test::WWW::Selenium object for $browser");
                }
            }
        }
    }
    if (keys %{ $browsers }) {
        eval "use Test::Builder";
        die $@ if $@;
        my $test = Test::Builder->new;
        $test->reset();
        $test->no_plan();
        $test->no_diag(1);
        $test->no_ending(1);
        my $testOutput = '';
        $test->output(\$testOutput );
    }

    return $browsers;
}

sub _errorCallback {
    if ($currentTest) {
        $currentTest->assert(0, join(' ', @_));
    }
    else {
        die "A Test::WWW::Selenium class reported an error, "
          . "but the associated test-case object has "
          . "already been destroyed. The error is:\n"
          . join(' ', @_);
    }
}

sub _shutDownSeleniumBrowsers {
    #my $pressEnterToContinue = <STDIN>;
    for my $browser (values %$browsers) {
        print STDERR "Shutting down $browser\n" if $debug;
        $browser->stop();
    }
    undef $browsers;
}

sub login {
    my $this = shift;
    $this->{selenium}->open_ok( Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic}, 'login') );
    my $usernameInputFieldLocator = 'css=input[name="username"]';
    $this->{selenium}->wait_for_element_present( $usernameInputFieldLocator, $this->{selenium_timeout} );
    $this->{selenium}->type_ok( $usernameInputFieldLocator, $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username} );

    my $passwordInputFieldLocator = 'css=input[name="password"]';
    $this->assertElementIsPresent($passwordInputFieldLocator);
    $this->{selenium}->type_ok( $passwordInputFieldLocator, $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Password} );

    my $loginFormLocator = 'css=form[name="loginform"]';
    $this->assertElementIsPresent($loginFormLocator);
    $this->{selenium}->click_ok( 'css=input.foswikiSubmit[type="submit"]' );
    $this->{selenium}->wait_for_page_to_load( $this->{selenium_timeout} );

    my $postLoginLocation = $this->{selenium}->get_location();
    my $viewUrl = Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic}, 'view');
    $this->assert_matches(qr/\Q$viewUrl?foswiki_redirect_cache=/, $postLoginLocation);
}

sub timeout {
    my $this = shift;
    my $timeout = shift;
    $this->{selenium_timeout} = $timeout if $timeout;
    return $this->{selenium_timeout};
}

sub waitFor {
    my $this = shift;
    my $testFn = shift;
    my $message = shift;
    my $args = shift;
    my $timeout = shift;
    $timeout ||= $this->{selenium_timeout};
    $args ||= [];
    my $result;
    my $elapsed = 0;
    my $start = $startWait->();
    while (not $result and $elapsed < $timeout)
    {
        $result = $testFn->($this, @$args);
        $elapsed = $doze->($start) if not $result;
    }
    $this->assert($result, $message || "timeout");
}

sub assertElementIsPresent {
    my $this = shift;
    my $locator = shift;
    my $message = shift;
    $message ||= "Element $locator is not present";
    $this->assert( $this->{selenium}->is_element_present($locator), $message );

    return;
}

sub assertElementIsVisible {
    my $this = shift;
    my $locator = shift;
    my $message = shift;
    $message ||= "Element $locator is not visible";
    $this->assert( $this->{selenium}->is_visible($locator), $message );

    return;
}

sub assertElementIsNotVisible {
    my $this = shift;
    my $locator = shift;
    my $message = shift;
    $this->assertElementIsPresent($locator);
    $message ||= "Element $locator is visible";
    $this->assert( not $this->{selenium}->is_visible($locator), $message );

    return;
}

1;
