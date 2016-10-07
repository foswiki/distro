# Unit tests for REST handlers
# Author: Crawford Currie

package JsonrpcTests;
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

use Unit::Request::JSON;

our $UI_FN;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $UI_FN ||= $this->getUIFn('jsonrpc');

    return;
}

# A simple REST handler
sub json_handler {
    my ( $session, $request ) = @_;
    die "No Foswiki Session"     unless $session->isa('Foswiki');
    die "Not a JSON Request"     unless $request->isa('Unit::Request::JSON');
    die "incorrect jsonmethod()" unless $request->jsonmethod() eq 'trial';
    die "incorrect method()"     unless $request->method() eq 'trial';
    die "Incorrect topic"        unless $session->{topicName} eq 'WebChanges';
    die "Incorrect web"          unless $session->{webName} eq 'System';
    return 'SUCCESS';
}

# A simple REST handler with error
sub json_and_be_thankful {
    my ( $session, $subject, $verb ) = @_;

    die "meistersinger";

    return;
}

# A JSON handler for checking context
sub json_context {
    my ( $session, $subject, $verb ) = @_;

    my $web   = $session->{webName};
    my $topic = $session->{topicName};

    Foswiki::Func::pushTopicContext( $web, $Foswiki::cfg{NotifyTopicName} );
    Foswiki::Func::popTopicContext();

    my $newweb = $session->{webName};

    return "$newweb";
}

# A JSON handler for checking authentication
sub json_authtest {
    my ( $session, $subject, $verb ) = @_;

    my $auth  = ( $session->inContext('authenticated') ) ? 'AUTH'  : 'UNAUTH';
    my $cli   = ( $session->inContext('command_line') )  ? 'CLI'   : 'CGI';
    my $adm   = ( Foswiki::Func::isAnAdmin() )           ? 'ADMIN' : '';
    my $guest = ( Foswiki::Func::isGuest() )             ? 'GUEST' : '';

    return "RESULTS:$auth.$cli.$adm.$guest";
}

# Simple jsonrpc, using posted data
sub test_simple_postdata {
    my $this = shift;
    Foswiki::Contrib::JsonRpcContrib::registerMethod( __PACKAGE__, 'trial',
        \&json_handler );

    my $query = Unit::Request::JSON->new( { action => ['jsonrpc'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $query->param( 'POSTDATA',
'{"jsonrpc":"2.0","method":"trial","params":{"wizard":"ScriptHash","method":"verify","keys":"{ScriptUrlPaths}{view}","set":{},"topic":"System.WebChanges","cfgpassword":"xxxxxxx"},"id":"iCall-verify_6"}'
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $response, $result, $out, $err ) =
      $this->capture( $UI_FN, $this->{session} );

    $this->assert_matches( qr/"result" : "SUCCESS"/, $response );
    return;
}

# Simple jsonrpc, using query params
sub test_simple_query_params {
    my $this = shift;
    Foswiki::Contrib::JsonRpcContrib::registerMethod( __PACKAGE__, 'trial',
        \&json_handler );

    my $query = Unit::Request::JSON->new( { action => ['jsonrpc'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $query->param( 'topic',      'WebChanges' );
    $query->param( 'defaultweb', 'System' );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $response, $result, $out, $err ) =
      $this->capture( $UI_FN, $this->{session} );

    $this->assert_matches( qr/"result" : "SUCCESS"/, $response );
    return;
}

# -32601: Method not found - The method does not exist / is not available.
sub test_method_missing {
    my $this = shift;
    Foswiki::Contrib::JsonRpcContrib::registerMethod( __PACKAGE__, 'trial',
        \&json_handler );

    my $query = Unit::Request::JSON->new( { action => ['jsonrpc'], } );
    $query->path_info( '/' . __PACKAGE__ . '/saywhat' );
    $query->method('post');
    $query->param( 'topic',      'WebChanges' );
    $query->param( 'defaultweb', 'System' );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $response, $result, $out, $err ) =
      $this->capture( $UI_FN, $this->{session} );

    $this->assert_matches( qr/"code" : -32601/, $response );

    return;
}

# -32600: Invalid Request - The JSON sent is not a valid Request object.
sub test_invalid_request {
    my $this = shift;
    Foswiki::Contrib::JsonRpcContrib::registerMethod( __PACKAGE__, 'trial',
        \&json_handler );

    my $query = Unit::Request::JSON->new( { action => ['jsonrpc'], } );
    $query->path_info( '/' . __PACKAGE__ . '/saywhat' );
    $query->param( 'POSTDATA',
'{"jsonrpc":"2.0","method":"trial","params":"wizard":"ScriptHash","method":"verify","keys":"{ScriptUrlPaths}{view}","set":{},"topic":"System.WebChanges","cfgpassword":"xxxxxxx"},"id":"iCall-verify_6"}'
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $response, $result, $out, $err ) =
      $this->capture( $UI_FN, $this->{session} );
    $this->assert_matches( qr/"code" : -32600/, $response );
    $this->assert_matches(
        qr/"message" : "Invalid JSON-RPC request - must be jsonrpc: '2.0'"/,
        $response );

    return;
}

sub test_post_required {
    my $this = shift;
    Foswiki::Contrib::JsonRpcContrib::registerMethod( __PACKAGE__, 'trial',
        \&json_handler );

    my $query = Unit::Request::JSON->new( { action => ['jsonrpc'], } );
    $query->method('get');
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->param( 'POSTDATA',
'{"jsonrpc":"2.0","method":"trial","params":{"wizard":"ScriptHash","method":"verify","keys":"{ScriptUrlPaths}{view}","set":{},"topic":"WebChanges","cfgpassword":"xxxxxxx"},"id":"iCall-verify_6"}'
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $response, $result, $out, $err ) =
      $this->capture( $UI_FN, $this->{session} );

    $this->assert_matches( qr/"code" : -32600/,                   $response );
    $this->assert_matches( qr/"message" : "Method must be POST"/, $response );

    return;
}

# Test the handler that dies
sub test_500 {
    my $this = shift;
    Foswiki::Contrib::JsonRpcContrib::registerMethod( __PACKAGE__, 'trial',
        \&json_and_be_thankful );

    my $query = Unit::Request::JSON->new( { action => ['jsonrpc'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    &$UI_FN( $this->{session} );
    my ($text) = $this->capture( $UI_FN, $this->{session} );

    $this->assert_matches( qr#^Status: 500#m, $text );
    $this->assert_matches( qr#"code" : 1#,    $text );  # Code 1 if handler dies
    return;
}

# Test the redirectto parameter as a json param
sub test_redirectto {
    my $this = shift;
    Foswiki::Contrib::JsonRpcContrib::registerMethod( __PACKAGE__, 'trial',
        \&json_handler );

    my $query = Unit::Request::JSON->new( { action => ['jsonrpc'], } );
    $query->path_info( '/' . __PACKAGE__ . '/trial' );
    $query->method('post');
    $query->param( 'POSTDATA',
'{"jsonrpc":"2.0","method":"trial","params":{"wizard":"ScriptHash","method":"verify","redirectto":"'
          . "$this->{test_web}/$this->{test_topic}"
          . '","set":{},"topic":"System.WebChanges","cfgpassword":"xxxxxxx"},"id":"iCall-verify_6"}'
    );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $response, $result, $out, $err ) =
      $this->capture( $UI_FN, $this->{session} );

    $this->assert_matches( qr#^Status: 302#m, $response );
    $this->assert_matches(
        qr#^Location:.*$this->{test_web}/$this->{test_topic}\s*$#m, $response );

    return;
}

# Test the redirectto parameter with anchor
sub future_test_redirectto_Anchor {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&json_handler );

    my $query = Unit::Request::JSON->new(
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

## Test the authentication methods
sub future_test_authmethods {
    my $this = shift;

    $Foswiki::cfg{Session}{AcceptUserPwParam}      = qr/^rest(auth)?$/;
    $Foswiki::cfg{Session}{AcceptUserPwParamOnGET} = 1;

    Foswiki::Func::registerRESTHandler(
        'trial', \&json_authtest,
        authenticate => 1,  # Set to 0 if handler should be useable by WikiGuest
        validate     => 1,  # Set to 0 to disable StrikeOne CSRF protection
        http_allow => 'POST', # Set to 'GET,POST' to allow use HTTP GET and POST
        description => 'Example handler for Empty Plugin'
    );

    my $query = Unit::Request::JSON->new( { action => ['rest'], } );

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
        'trial', \&json_authtest,
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

# Test the redirectto parameter with querystring
sub future_test_redirectto_Query {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&json_handler );

    my $query = Unit::Request::JSON->new(
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

# Test the redirectto parameter with illegal
sub future_test_redirectto_Illegal {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&json_handler );

    my $query = Unit::Request::JSON->new(
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
sub future_test_http_allow {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&json_handler,
        http_allow => 'GET' );

    my $query = Unit::Request::JSON->new( { action => ['rest'], } );
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
sub future_test_validate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&json_handler,
        validate => 1 );

    my $query = Unit::Request::JSON->new( { action => ['rest'], } );
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
sub future_test_authenticate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&json_handler,
        authenticate => 1 );

    my $query = Unit::Request::JSON->new( { action => ['rest'], } );
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

# Test the redirectto parameter with a URL
sub future_test_redirectto_URL {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&json_handler );
    $Foswiki::cfg{PermittedRedirectHostUrls} = 'http://lolcats.com';

    my $query = Unit::Request::JSON->new(
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

# Test the redirectto parameter with a bad URL
sub future_test_redirectto_badURL {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&json_handler );

    my $query = Unit::Request::JSON->new(
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

# Test the topic context
#  - Item12055: PopTopicContext in rest handler loses default context.
sub future_test_topic_context {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'context', \&json_context );

    my $query = Unit::Request::JSON->new( { action => ['rest'], } );
    $query->path_info( '/' . __PACKAGE__ . '/context' );
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture( $UI_FN, $this->{session} );

    $this->assert_matches( qr#$Foswiki::cfg{UsersWebName}#,
        $text, "Users web context was lost" );
    return;
}

1;
