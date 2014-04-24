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

sub skip {
    my ( $this, $test ) = @_;

    return $this->SUPER::skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                'RESTTests::test_redirectto' =>
                  'redirectto  is Foswiki 1.2+ only',
                'RESTTests::test_redirectto_Anchor' =>
                  'redirectto  is Foswiki 1.2+ only',
                'RESTTests::test_redirectto_Query' =>
                  'redirectto  is Foswiki 1.2+ only',
                'RESTTests::test_redirectto_URL' =>
                  'redirectto  is Foswiki 1.2+ only',
                'RESTTests::test_redirectto_badURL' =>
                  'redirectto  is Foswiki 1.2+ only',
                'RESTTests::test_500' => 'redirectto  is Foswiki 1.2+ only',
            }
        }
    );
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

# A REST handler for checking context
sub rest_context {
    my ( $session, $subject, $verb ) = @_;

    my $web   = $session->{webName};
    my $topic = $session->{topicName};

    Foswiki::Func::pushTopicContext( $web, $Foswiki::cfg{NotifyTopicName} );
    Foswiki::Func::popTopicContext();

    my $newweb = $session->{webName};

    return "$newweb";
}

# A REST handler for checking authentication
sub rest_authtest {
    my ( $session, $subject, $verb ) = @_;

    my $auth  = ( $session->inContext('authenticated') ) ? 'AUTH'  : 'UNAUTH';
    my $cli   = ( $session->inContext('command_line') )  ? 'CLI'   : 'CGI';
    my $adm   = ( Foswiki::Func::isAnAdmin() )           ? 'ADMIN' : '';
    my $guest = ( Foswiki::Func::isGuest() )             ? 'GUEST' : '';

    return "RESULTS:$auth.$cli.$adm.$guest";
}

# Test the authentication methods
sub test_authmethods {
    my $this = shift;

    $Foswiki::cfg{Session}{AcceptUserPwParam}      = qr/^rest(auth)?$/;
    $Foswiki::cfg{Session}{AcceptUserPwParamOnGET} = 1;

    Foswiki::Func::registerRESTHandler(
        'trial', \&rest_authtest,
        authenticate => 1,  # Set to 0 if handler should be useable by WikiGuest
        validate     => 1,  # Set to 0 to disable StrikeOne CSRF protection
        http_allow => 'POST', # Set to 'GET,POST' to allow use HTTP GET and POST
        description => 'Example handler for Empty Plugin'
    );

    my $query = Unit::Request->new( { action => ['rest'], } );

    $query->setUrl( '/'
          . __PACKAGE__
          . "/trial?username=$this->{test_user_login};password=''" );
    $query->method('post');
    $query->action('rest');

    my $text;

    # SMELL:  This test needs to really test a username / password
    # on the URL.  I've been unable to get the test user to validate
    # a with a password.  So this passes, because the test is broken,
    # not because the id/password didn't validate
    #
    # Auth failed session - should fail with 401 due to invalid password
    #
    $this->createNewFoswikiSession( undef, $query );
    try {
        ($text) = $this->capture( $UI_FN, $this->{session} );
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals( 401, $e->{status}, $e );
    }
    otherwise {
        $this->assert(0);
    };

    # Auth but no validation key - fail with 403
    #
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );

    try {
        ($text) = $this->capture( $UI_FN, $this->{session} );
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals( 403, $e->{status}, $e );
    }
    otherwise {
        $this->assert(0);
    };

    # Auth and key, but GET, not post,  fail with 405
    #
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('get');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );

    try {
        ($text) = $this->capture( $UI_FN, $this->{session} );
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $this->assert_equals( 405, $e->{status}, $e );
    }
    otherwise {
        $this->assert(0);
    };

    # Authenticated,  POST and validation key - should work
    #
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $query->method('post');
    ($text) = $this->captureWithKey( rest => $UI_FN, $this->{session} );

    $this->assert_matches( qr/RESULTS:AUTH\.CGI\.\./, $text );

    Foswiki::Func::registerRESTHandler(
        'trial', \&rest_authtest,
        authenticate => 0,  # Set to 0 if handler should be useable by WikiGuest
        validate     => 1,  # Set to 0 to disable StrikeOne CSRF protection
        http_allow => 'POST', # Set to 'GET,POST' to allow use HTTP GET and POST
        description => 'Example handler for Empty Plugin'
    );

    # Unauthenticated, POST with validation key - Now should work
    #
    $this->createNewFoswikiSession( 'guest', $query );
    ($text) = $this->captureWithKey( rest => $UI_FN, $this->{session} );
    $this->assert_matches( qr/RESULTS:UNAUTH\.CGI\.\.GUEST/, $text );

    # Authenticated, POST with validation key from Admin User
    #
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin}, $query );
    ($text) = $this->captureWithKey( rest => $UI_FN, $this->{session} );
    $this->assert_matches( qr/RESULTS:AUTH\.CGI\.ADMIN\./, $text );

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
            endPoint => "$this->{test_web}/$this->{test_topic}?blah1=;q=2;y=3",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
qr#^Location:.*$this->{test_web}/$this->{test_topic}\?blah1=;q=2;y=3\s*$#m,
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
              "$this->{test_web}/$this->{test_topic}?blah1=;q=2;y=3",
        }
    );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr#^Status: 302#m, $text );
    $this->assert_matches(
qr#^Location:.*$this->{test_web}/$this->{test_topic}\?blah1=;q=2;y=3\s*$#m,
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
        $this->assert_equals( 405, $e->{status}, $e );
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
    $this->expect_failure( 'Redirect to a URL is new in 1.2',
        with_dep => 'Foswiki,<,1.2' );
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
    $this->expect_failure( 'Redirect to a URL is new in 1.2',
        with_dep => 'Foswiki,<,1.2' );
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

# Test the redirectto with handler that dies
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

# Test the topic context
#  - Item12055: PopTopicContext in rest handler loses default context.
sub test_topic_context {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'context', \&rest_context );

    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/context' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );

    $this->assert_matches( qr#$Foswiki::cfg{UsersWebName}#,
        $text, "Users web context was lost" );
    return;
}

1;
