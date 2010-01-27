# Unit tests for REST handlers
# Author: Crawford Currie

package RESTTests;
use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Assert;
use Foswiki::Func;
use Foswiki::EngineException;
use Carp;
use Error ':try';
use Foswiki::UI::Rest;

our $UI_FN;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $UI_FN ||= \&Foswiki::UI::Rest::rest;
}

# A simple REST handler
sub rest_handler {
    my ($session, $subject, $verb) = @_;

    Carp::confess $session unless $session->isa('Foswiki');
    Carp::confess $subject unless $subject eq 'RESTTests';
    Carp::confess $verb unless $verb eq 'trial';
}

# Simple no-options REST call
sub test_simple {
    my $this = shift;
    Foswiki::Func::registerRESTHandler('trial', \&rest_handler);

    my $query = new Unit::Request(
        {
            action => ['rest'],
        });
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{twiki}->finish();
    $query->method('post');
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $this->capture( $UI_FN, $this->{twiki} );
}

# Test the (unused) endPoint parameter
sub test_endPoint {
    my $this = shift;
    Foswiki::Func::registerRESTHandler('trial', \&rest_handler);

    my $query = new Unit::Request(
        {
            action => ['rest'],
            endPoint => 'this/that',
        });
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{twiki}->finish();
    $query->method('post');
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    my ($text, $result) = $this->capture( $UI_FN, $this->{twiki} );
    $this->assert_matches(qr#^Status: 302#m, $text);
    $this->assert_matches(qr#^Location:.*/this/that\s*$#m, $text);
}

# Test the http_allow option, to ensure it restricts the request methods
sub test_http_allow {
    my $this = shift;
    Foswiki::Func::registerRESTHandler('trial', \&rest_handler,
                                      http_allow => 'GET');

    my $query = new Unit::Request(
        {
            action => ['rest'],
        });
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{twiki}->finish();
    $query->method('POST');
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    try {
        $this->capture( $UI_FN, $this->{twiki} );
    } catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals(404, $e->{status}, $e);
    } otherwise {
        $this->assert(0);
    };
    $this->{twiki}->finish();
    $query->method('GET');
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $this->capture( $UI_FN, $this->{twiki} );
}

# Test checking the validation key
sub test_validate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler('trial', \&rest_handler,
                                      validate => 1);

    my $query = new Unit::Request(
        {
            action => ['rest'],
        });
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{twiki}->finish();
    $query->method('post');
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    # Make sure a request with no validation key is trapped
    try {
        $this->capture( $UI_FN, $this->{twiki} );
    } catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals(401, $e->{status}, $e);
        $this->assert_matches(qr/\(403\)/, $e->{reason}, $e);
    } otherwise {
        $this->assert(0);
    };
    # Make sure a request with validation is OK
    $this->captureWithKey( rest => $UI_FN, $this->{twiki} );
}

# Test authentication requirement
sub test_authenticate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler('trial', \&rest_handler,
                                       authenticate => 1);

    my $query = new Unit::Request(
        {
            action => ['rest'],
        });
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{twiki}->finish();
    $query->method('post');
    $this->{twiki} = new Foswiki( undef, $query );
    # Make sure a request with no authentication is trapped
    try {
        $this->capture( $UI_FN, $this->{twiki} );
    } catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals(401, $e->{status}, $e);
        $this->assert_matches(qr/\(401\)/, $e->{reason}, $e);
    } otherwise {
        $this->assert(0);
    };
    # Make sure a request with session authentication is OK
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    $this->capture( $UI_FN, $this->{twiki} );
}

1;
