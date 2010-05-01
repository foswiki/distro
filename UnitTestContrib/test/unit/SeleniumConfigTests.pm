use strict;

package SeleniumConfigTests;

use FoswikiSeleniumTestCase;
our @ISA = qw( FoswikiSeleniumTestCase );

use Foswiki::Func;

sub new {
    my $self = shift()->SUPER::new( 'SeleniumConfig', @_ );
    return $self;
}

sub verify_SeleniumRc_config {
    my $this = shift;
    $this->{selenium}->open_ok( Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic}, 'view') );
    $this->login();
}

sub verify_SeleniumRc_ok_failure_reporting {
    my $this = shift;
    eval {
        $this->{selenium}->open_ok( Foswiki::Func::getScriptUrl( 'Milkshakes', 'BronzeMoth', 'bananaFlavour') );
    };
    $this->assert_matches( "^\nopen, ", $@, "Expected an exception");
}

sub verify_SeleniumRc_like_failure_reporting {
    my $this = shift;
    $this->{selenium}->open_ok( Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic}, 'view') );
    eval {
        $this->{selenium}->title_like( qr/There is no way that this would ever find its way into the title of web page. That would be simply insane!/ );
    };
    $this->assert_matches( "^\nget_title, ", $@, "Expected an exception");
}

1;
