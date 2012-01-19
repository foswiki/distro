# Unit tests for REST handlers
# Author: Crawford Currie

package RESTTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Assert;
use Foswiki::Func;
use Foswiki::EngineException;
use Carp;
use Error ':try';

our $UI_FN;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $UI_FN ||= $this->getUIFn('rest');
}

# A simple REST handler
sub rest_handler {
    my ( $session, $subject, $verb ) = @_;

    Carp::confess $session unless $session->isa('Foswiki');
    Carp::confess $subject unless $subject eq 'RESTTests';
    Carp::confess $verb    unless $verb eq 'trial';
}

# Simple no-options REST call
sub test_simple {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = new Unit::Request( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{session}->finish();
    $query->method('post');
    $this->{session} =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->capture( $UI_FN, $this->{session} );
}

# Test the (unused) endPoint parameter
sub test_endPoint {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = new Unit::Request(
        {
            action   => ['rest'],
            endPoint => "$this->{test_web}/$this->{test_topic}",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{session}->finish();
    $query->method('post');
    $this->{session} =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
        qr#^Location:.*$this->{test_web}/$this->{test_topic}\s*$#m, $text );
}

# Test the endPoint parameter with anchor
sub test_endPoint_Anchor {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = new Unit::Request(
        {
            action   => ['rest'],
            endPoint => "$this->{test_web}/$this->{test_topic}#MyAnch",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{session}->finish();
    $query->method('post');
    $this->{session} =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
        qr#^Location:.*$this->{test_web}/$this->{test_topic}\#MyAnch\s*$#m,
        $text );
}

# Test the endPoint parameter with querystring
sub test_endPoint_Query {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = new Unit::Request(
        {
            action   => ['rest'],
            endPoint => "$this->{test_web}/$this->{test_topic}?blah1=;q=2&y=3",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{session}->finish();
    $query->method('post');
    $this->{session} =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
qr#^Location:.*$this->{test_web}/$this->{test_topic}\?blah1=;q=2&y=3\s*$#m,
        $text
    );
}

# Test the endPoint parameter with querystring
sub test_endPoint_Illegal {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = new Unit::Request(
        {
            action   => ['rest'],
            endPoint => 'http://this/that?blah=1;q=2',
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{session}->finish();
    $query->method('post');
    $this->{session} =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my $text = '';
    try {
        ($text) = $this->capture( $UI_FN, $this->{session} );
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals( 404, $e->{status}, $e );
    }
    otherwise {
        $this->assert(0);
    };
}

# Test the http_allow option, to ensure it restricts the request methods
sub test_http_allow {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler,
        http_allow => 'GET' );

    my $query = new Unit::Request( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{session}->finish();
    $query->method('POST');
    $this->{session} =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    try {
        $this->capture( $UI_FN, $this->{session} );
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals( 404, $e->{status}, $e );
    }
    otherwise {
        $this->assert(0);
    };
    $this->{session}->finish();
    $query->method('GET');
    $this->{session} =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->capture( $UI_FN, $this->{session} );
}

# Test checking the validation key
sub test_validate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler,
        validate => 1 );

    my $query = new Unit::Request( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{session}->finish();
    $query->method('post');
    $this->{session} =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );

    # Make sure a request with no validation key is trapped
    try {
        $this->capture( $UI_FN, $this->{session} );
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals( 403, $e->{status}, $e );
        $this->assert_matches( qr/\(403\)/, $e->{reason}, $e );
    }
    otherwise {
        $this->assert(0);
    };

    # Make sure a request with validation is OK
    $this->captureWithKey( rest => $UI_FN, $this->{session} );
}

# Test authentication requirement
sub test_authenticate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler,
        authenticate => 1 );

    my $query = new Unit::Request( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $this->{session}->finish();
    $query->method('post');
    $this->{session} = $this->createNewFoswikiSession( undef, $query );

    # Make sure a request with no authentication is trapped
    try {
        $this->capture( $UI_FN, $this->{session} );
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals( 401, $e->{status}, $e );
        $this->assert_matches( qr/\(401\)/, $e->{reason}, $e );
    }
    otherwise {
        $this->assert(0);
    };

    # Make sure a request with session authentication is OK
    $this->{session}->finish();
    $this->{session} =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->capture( $UI_FN, $this->{session} );
}

1;
