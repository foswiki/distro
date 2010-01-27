# Unit tests for REST handlers
# Author: Crawford Currie

package RESTTests;
use base qw(FoswikiFnTestCase);

use strict;
use warnings;
use Foswiki;
use Assert;
use Unit::TestCase;
use Foswiki::Func;
use Foswiki::EngineException;
use Carp;
use Error qw(:try);
use Foswiki::UI::Rest;

our $UI_FN;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $UI_FN ||= \&Foswiki::UI::Rest::rest;

    return;
}

# A simple REST handler
sub rest_handler {
    my ($session, $subject, $verb) = @_;

    Carp::confess $session unless $session->isa('Foswiki');
    Carp::confess $subject unless $subject eq 'RESTTests';
    Carp::confess $verb unless $verb eq 'trial';

    return;
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

    return;
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

    return;
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

    return;
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

    return;
}

sub setupAuthREST {
    my $this = shift;
    my $query = new Unit::Request(
        {
            action => ['rest'],
        });
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->{twiki}->finish();

  return $query;
}

sub attemptAuthREST {
    my ($this, $expectedStatus, $expectException, $msg) = @_;
    my $gotException = 0;

    try {
        $this->capture( $UI_FN, $this->{twiki} );
    } catch Foswiki::EngineException with {
        my $e = shift;
        $gotException = 1;
        $this->assert_equals($expectedStatus, $e->{status}, $e);
        $this->assert_matches(qr/\($expectedStatus\)/, $e->{reason}, $e);
    } otherwise {
        $gotException = 1;
        $this->assert(0, "This shouldn't happen...");
    } finally {
        $this->assert_equals($gotException, $expectException, $msg);
    };

    return;
}

sub tryAuthAndUnauthREST {
    my ($this, $guestShouldFail, $query, $msg) = @_;

    $this->{twiki} = new Foswiki( undef, $query );
    attemptAuthREST($this, 401, $guestShouldFail, $msg . ' + guest user should generate 401 Auth Required.');
    $this->{twiki} = new Foswiki( $this->{test_user_login}, $query );
    attemptAuthREST($this, 200, 0, $msg . ' + authenticated user should generate 200 OK.');

    return;
}

# Test authentication requirement
sub test_undefauthenticate {
    my ($this) = @_;
    my $query = setupAuthREST($this);

    Foswiki::Func::registerRESTHandler('trial', \&rest_handler);
    tryAuthAndUnauthREST($this, 1, $query, 'Handler registered with no options hash');

    return;
}

sub test_noauthenticate {
    my ($this) = @_;
    my $query = setupAuthREST($this);

    Foswiki::Func::registerRESTHandler('trial', \&rest_handler, authenticate => 0);
    tryAuthAndUnauthREST($this, 0, $query, 'Handler registered with authenticate => 0');

    return;
}

sub test_authenticate {
    my ($this) = @_;
    my $query = setupAuthREST($this);

    Foswiki::Func::registerRESTHandler('trial', \&rest_handler, authenticate => 1);
    tryAuthAndUnauthREST($this, 1, $query, 'Handler registered with authenticate => 1');

    return;
}

1;
