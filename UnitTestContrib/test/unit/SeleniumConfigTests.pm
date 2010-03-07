use strict;

package SeleniumConfigTests;

use base qw(FoswikiSeleniumTestCase);

use Foswiki::Func;

sub new {
    my $self = shift()->SUPER::new( 'SeleniumConfig', @_ );
    return $self;
}

sub set_up {
    my $this = shift();

    $this->SUPER::set_up();

}

sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();
}

sub verify_SeleniumRc_config {
    my $this = shift;
    $this->{selenium}->open_ok( Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic}, 'view') );
}

sub verify_SeleniumRc_ok_failure_reporting {
    my $this = shift;
	$this->expect_failure();
	$this->annotate("Testing that failures from Test::WWW::Selenium find their way to the Unit::TestCase infrastructure");
    $this->{selenium}->open_ok( Foswiki::Func::getScriptUrl( 'Milkshakes', 'BronzeMoth', 'bananaFlavour') );
}

sub verify_SeleniumRc_like_failure_reporting {
    my $this = shift;
    $this->{selenium}->open_ok( Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic}, 'view') );
	$this->expect_failure();
	$this->annotate("Testing that failures from Test::WWW::Selenium find their way to the Unit::TestCase infrastructure");
    $this->{selenium}->title_like( qr/There is no way that this would ever find its way into the title of web page. That would be simply insane!/ );
}

1;
