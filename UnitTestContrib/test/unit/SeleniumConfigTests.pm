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

1;
