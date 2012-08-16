# Unit tests for REST handlers
# Author: Crawford Currie

package RESTTests;
use strict;
use warnings;
use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Assert;
use Foswiki();
use Foswiki::Func();
use Foswiki::EngineException();
use Carp();
use Error ':try';

our $UI_FN;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $UI_FN ||= $this->getUIFn('rest');

    return;
}

# A simple REST handler
sub rest_handler {
    my ( $session, $subject, $verb ) = @_;

    Carp::confess $session unless $session->isa('Foswiki');
    Carp::confess $subject unless $subject eq 'RESTTests';
    Carp::confess $verb    unless $verb eq 'trial';

    return;
}

# A simple REST handler with error
sub rest_and_be_thankful {
    my ( $session, $subject, $verb ) = @_;

    die "meistersinger";

    return;
}

# Simple no-options REST call
sub test_simple {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->capture( $UI_FN, $this->{session} );

    return;
}

# Test the endPoint parameter
sub test_endPoint {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action   => ['rest'],
            endPoint => "$this->{test_web}/$this->{test_topic}",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    &$UI_FN( $this->{session} );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
        qr#^Location:.*$this->{test_web}/$this->{test_topic}\s*$#m, $text );

    return;
}

# Test the redirectto parameter
sub test_redirectto {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action     => ['rest'],
            redirectto => "$this->{test_web}/$this->{test_topic}",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    &$UI_FN( $this->{session} );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
        qr#^Location:.*$this->{test_web}/$this->{test_topic}\s*$#m, $text );

    return;
}

# Test the endPoint parameter with anchor
sub test_endPoint_Anchor {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action   => ['rest'],
            endPoint => "$this->{test_web}/$this->{test_topic}#MyAnch",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
        qr#^Location:.*$this->{test_web}/$this->{test_topic}\#MyAnch\s*$#m,
        $text );

    return;
}

# Test the redirectto parameter with anchor
sub test_redirectto_Anchor {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action     => ['rest'],
            redirectto => "$this->{test_web}/$this->{test_topic}#MyAnch",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
        qr#^Location:.*$this->{test_web}/$this->{test_topic}\#MyAnch\s*$#m,
        $text );

    return;
}

# Test the endPoint parameter with querystring
sub test_endPoint_Query {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action   => ['rest'],
            endPoint => "$this->{test_web}/$this->{test_topic}?blah1=;q=2&y=3",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
qr#^Location:.*$this->{test_web}/$this->{test_topic}%3fblah1%3d%3bq%3d2%26y%3d3\s*$#m,
        $text
    );

    return;
}

# Test the redirectto parameter with querystring
sub test_redirectto_Query {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action => ['rest'],
            redirectto =>
              "$this->{test_web}/$this->{test_topic}?blah1=;q=2&y=3",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
qr#^Location:.*$this->{test_web}/$this->{test_topic}%3fblah1%3d%3bq%3d2%26y%3d3\s*$#m,
        $text
    );

    return;
}

# Test the endPoint parameter with querystring
sub test_endPoint_Illegal {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action   => ['rest'],
            endPoint => 'http://this/that?blah=1;q=2',
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
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

    return;
}

# Test the redirectto parameter with querystring
sub test_redirectto_Illegal {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action     => ['rest'],
            redirectto => 'http://this/that?blah=1;q=2',
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
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

    return;
}

# Test the http_allow option, to ensure it restricts the request methods
sub test_http_allow {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler,
        http_allow => 'GET' );

    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('POST');
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
    $query->method('GET');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->capture( $UI_FN, $this->{session} );

    return;
}

# Test checking the validation key
sub test_validate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler,
        validate => 1 );

    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
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

    return;
}

# Test authentication requirement
sub test_authenticate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler,
        authenticate => 1 );

    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( undef, $query );

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
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->capture( $UI_FN, $this->{session} );

    return;
}

# Test the endPoint parameter with a URL
sub test_endPoint_URL {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );
    $Foswiki::cfg{PermittedRedirectHostUrls} = 'http://lolcats.com';

    my $query = Unit::Request->new(
        {
            action   => ['rest'],
            endPoint => "http://lolcats.com/funny?pussy=cat",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    &$UI_FN( $this->{session} );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
        qr#^Location: http://lolcats.com/funny\?pussy=cat\s*$#m, $text );

    return;
}

# Test the redirectto parameter with a URL
sub test_redirectto_URL {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );
    $Foswiki::cfg{PermittedRedirectHostUrls} = 'http://lolcats.com';

    my $query = Unit::Request->new(
        {
            action     => ['rest'],
            redirectto => "http://lolcats.com/funny?pussy=cat",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    &$UI_FN( $this->{session} );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
        qr#^Location: http://lolcats.com/funny\?pussy=cat\s*$#m, $text );

    return;
}

# Test the endPoint parameter with a bad URL
sub test_endPoint_badURL {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action   => ['rest'],
            endPoint => "http://lolcats.com/funny?pussy=cat",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    &$UI_FN( $this->{session} );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 403#m, $text );

    return;
}

# Test the redirectto parameter with a bad URL
sub test_redirectto_badURL {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $query = Unit::Request->new(
        {
            action     => ['rest'],
            redirectto => "http://lolcats.com/funny?pussy=cat",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    &$UI_FN( $this->{session} );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 403#m, $text );

    return;
}

# Test the redirectto parameter with a bad URL
sub test_500 {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_and_be_thankful );

    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    &$UI_FN( $this->{session} );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 500#m, $text );
    return;
}

1;
