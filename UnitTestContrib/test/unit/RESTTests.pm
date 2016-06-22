# Unit tests for REST handlers
# Author: Crawford Currie

package RESTTests;
use v5.14;

use Assert;
use Foswiki();
use Foswiki::Func();
use Foswiki::EngineException();
use Carp();
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

around set_up => sub {
    my $orig = shift;
    my $this = shift;
    $Foswiki::cfg{LegacyRESTSecurity} = 1;
    $orig->( $this, @_ );

    return;
};

sub skip {
    my ( $this, $test ) = @_;

    return $this->skip_test_if(
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
    my ( $app, $subject, $verb ) = @_;

    Carp::confess $app     unless $app->isa('Foswiki::App');
    Carp::confess $subject unless $subject eq 'RESTTests';
    Carp::confess $verb    unless $verb eq 'trial';

    return;
}

# A simple REST handler with error
sub rest_and_be_thankful {
    my ( $app, $subject, $verb ) = @_;

    die "meistersinger";

    return;
}

# A REST handler for checking context
sub rest_context {
    my ( $app, $subject, $verb ) = @_;

    my $req   = $app->request;
    my $web   = $req->web;
    my $topic = $req->topic;

    Foswiki::Func::pushTopicContext( $web, $Foswiki::cfg{NotifyTopicName} );
    Foswiki::Func::popTopicContext();

    my $newweb = $req->web;

    return "$newweb";
}

# A REST handler for checking authentication
sub rest_authtest {
    my ( $app, $subject, $verb ) = @_;

    my $auth  = ( $app->inContext('authenticated') ) ? 'AUTH'  : 'UNAUTH';
    my $cli   = ( $app->inContext('command_line') )  ? 'CLI'   : 'CGI';
    my $adm   = ( Foswiki::Func::isAnAdmin() )       ? 'ADMIN' : '';
    my $guest = ( Foswiki::Func::isGuest() )         ? 'GUEST' : '';

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

    # PATH_INFO is the default source of request initialization. But we want uri
    # be the one.

    my $text;

    # SMELL:  This test needs to really test a username / password
    # on the URL.  I've been unable to get the test user to validate
    # a with a password.  So this passes, because the test is broken,
    # not because the id/password didn't validate
    #
    # Auth failed session - should fail with 401 due to invalid password
    #
    try {
        ($text) = $this->capture(
            sub {
                $this->createNewFoswikiApp(
                    requestParams =>
                      { initializer => { action => ['rest'], }, },
                    engineParams => {
                        initialAttributes => {
                            uri => '/'
                              . __PACKAGE__
                              . "/trial?username="
                              . $this->test_user_login
                              . ";password=''",
                            path_info => '/' . __PACKAGE__ . "/trial",
                            method    => 'post',
                            action    => 'rest',
                        },
                    },
                );
                return $this->app->handleRequest;
            },
        );
    }
    catch {
        my $e = $_;
        if ( ref($e) && $e->isa('Foswiki::EngineException') ) {
            $this->assert_equals( 401, $e->status, $e->stringify );
        }
        else {
            $e->rethrow;
        }
    };

    # Auth but no validation key - fail with 403
    #

    try {
        ($text) = $this->capture(
            sub {
                $this->createNewFoswikiApp(
                    requestParams =>
                      { initializer => { action => ['rest'], }, },
                    engineParams => {
                        initialAttributes => {
                            uri       => '/' . __PACKAGE__ . '/trial',
                            path_info => '/' . __PACKAGE__ . "/trial",
                            method    => 'post',
                            action    => 'rest',
                            user      => $this->test_user_login,
                        },
                    },
                );
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;
        if ( ref($e) && $e->isa('Foswiki::EngineException') ) {
            $this->assert_equals( 403, $e->status, $e->stringify );
        }
        else {
            $e->rethrow;
        }
    };

    # Auth and key, but GET, not post,  fail with 405
    #

    try {
        ($text) = $this->capture(
            sub {
                $this->createNewFoswikiApp(
                    requestParams =>
                      { initializer => { action => ['rest'], }, },
                    engineParams => {
                        initialAttributes => {
                            uri       => '/' . __PACKAGE__ . '/trial',
                            path_info => '/' . __PACKAGE__ . "/trial",
                            method    => 'get',
                            action    => 'rest',
                            user      => $this->test_user_login,
                        },
                    },
                );
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;
        if ( ref($e) && $e->isa('Foswiki::EngineException') ) {
            $this->assert_equals( 405, $e->status, $e->stringify );
        }
        else {
            $e->rethrow;
        }
    };

    # Authenticated,  POST and validation key - should work
    #
    ($text) = $this->captureWithKey(
        rest => sub {
            $this->createNewFoswikiApp(
                requestParams => { initializer => { action => ['rest'], }, },
                engineParams  => {
                    initialAttributes => {
                        uri       => '/' . __PACKAGE__ . '/trial',
                        path_info => '/' . __PACKAGE__ . "/trial",
                        method    => 'post',
                        action    => 'rest',
                        user      => $this->test_user_login,
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );

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
    ($text) = $this->captureWithKey(
        rest => sub {
            $this->createNewFoswikiApp(
                requestParams => { initializer => { action => ['rest'], }, },
                engineParams  => {
                    initialAttributes => {
                        uri       => '/' . __PACKAGE__ . '/trial',
                        path_info => '/' . __PACKAGE__ . "/trial",
                        method    => 'post',
                        action    => 'rest',
                        user      => 'guest',
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr/RESULTS:UNAUTH\.CGI\.\.GUEST/, $text );

    # Authenticated, POST with validation key from Admin User
    #
    ($text) = $this->captureWithKey(
        rest => sub {
            $this->createNewFoswikiApp(
                requestParams => { initializer => { action => ['rest'], }, },
                engineParams  => {
                    initialAttributes => {
                        uri       => '/' . __PACKAGE__ . '/trial',
                        path_info => '/' . __PACKAGE__ . "/trial",
                        method    => 'post',
                        action    => 'rest',
                        user      => $Foswiki::cfg{AdminUserLogin},
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr/RESULTS:AUTH\.CGI\.ADMIN\./, $text );

    return;
}

# Simple no-options REST call
sub test_simple {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my ($text) = $this->capture(
        sub {
            $this->createNewFoswikiApp(
                requestParams => { initializer => { action => ['rest'], }, },
                engineParams  => {
                    initialAttributes => {
                        path_info => '/' . __PACKAGE__ . '/trial',
                        method    => 'post',
                        action    => 'rest',
                        user      => $this->test_user_login,
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );

    return;
}

# Test the endPoint parameter
sub test_endPoint {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action   => ['rest'],
                endPoint => $this->test_web . "/" . $this->test_topic,
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => '/' . __PACKAGE__ . '/trial',
                method    => 'post',
                action    => 'rest',
                user      => $this->test_user_login,
            },
        },
    );
    $this->app->handleRequest;
    my ($text) = $this->capture(
        sub {
            $this->app->clear_response;
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr#^Status: 302#m, $text );
    my ( $test_web, $test_topic ) = ( $this->test_web, $this->test_topic );
    $this->assert_matches( qr#^Location:.*$test_web/$test_topic\s*$#m, $text );

    return;
}

# Test the redirectto parameter
sub test_redirectto {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action   => ['rest'],
                endPoint => $this->test_web . "/" . $this->test_topic,
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => '/' . __PACKAGE__ . '/trial',
                method    => 'post',
                action    => 'rest',
                user      => $this->test_user_login,
            },
        },
    );
    $this->app->handleRequest;
    my ($text) = $this->capture(
        sub {
            $this->app->clear_response;
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr#^Status: 302#m, $text );
    my ( $test_web, $test_topic ) = ( $this->test_web, $this->test_topic );
    $this->assert_matches( qr#^Location:.*$test_web/$test_topic\s*$#m, $text );

    return;
}

# Test the endPoint parameter with anchor
sub test_endPoint_Anchor {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my ($text) = $this->capture(
        sub {
            $this->createNewFoswikiApp(
                requestParams => {
                    initializer => {
                        action   => ['rest'],
                        endPoint => $this->test_web . "/"
                          . $this->test_topic
                          . "#MyAnch",
                    },
                },
                engineParams => {
                    initialAttributes => {
                        path_info => '/' . __PACKAGE__ . '/trial',
                        method    => 'post',
                        action    => 'rest',
                        user      => $this->test_user_login,
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr#^Status: 302#m, $text );
    my ( $test_web, $test_topic ) = ( $this->test_web, $this->test_topic );
    $this->assert_matches( qr#^Location:.*$test_web/$test_topic\#MyAnch\s*$#m,
        $text );

    return;
}

# Test the redirectto parameter with anchor
sub test_redirectto_Anchor {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my ($text) = $this->capture(
        sub {
            $this->createNewFoswikiApp(
                requestParams => {
                    initializer => {
                        action     => ['rest'],
                        redirectto => $this->test_web . "/"
                          . $this->test_topic
                          . "#MyAnch",
                    },
                },
                engineParams => {
                    initialAttributes => {
                        path_info => '/' . __PACKAGE__ . '/trial',
                        method    => 'post',
                        action    => 'rest',
                        user      => $this->test_user_login,
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr#^Status: 302#m, $text );
    my ( $test_web, $test_topic ) = ( $this->test_web, $this->test_topic );
    $this->assert_matches( qr#^Location:.*$test_web/$test_topic\#MyAnch\s*$#m,
        $text );

    return;
}

# Test the endPoint parameter with querystring
sub test_endPoint_Query {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action   => ['rest'],
                endPoint => $this->test_web . "/"
                  . $this->test_topic
                  . "?blah1=;q=2;y=3",
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => '/' . __PACKAGE__ . '/trial',
                method    => 'post',
                action    => 'rest',
                user      => $this->test_user_login,
            },
        },
    );

    my ($text) = $this->capture(
        sub {
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr#^Status: 302#m, $text );
    my ( $test_web, $test_topic ) = ( $this->test_web, $this->test_topic );
    $this->assert_matches(
        qr#^Location:.*$test_web/$test_topic\?blah1=;q=2;y=3\s*$#m, $text );

    return;
}

# Test the redirectto parameter with querystring
sub test_redirectto_Query {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my ($text) = $this->capture(
        sub {
            $this->createNewFoswikiApp(
                requestParams => {
                    initializer => {
                        action     => ['rest'],
                        redirectto => $this->test_web . "/"
                          . $this->test_topic
                          . "?blah1=;q=2;y=3",
                    },
                },
                engineParams => {
                    initialAttributes => {
                        path_info => '/' . __PACKAGE__ . '/trial',
                        method    => 'post',
                        action    => 'rest',
                        user      => $this->test_user_login,
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr#^Status: 302#m, $text );
    my ( $test_web, $test_topic ) = ( $this->test_web, $this->test_topic );
    $this->assert_matches(
        qr#^Location:.*$test_web/$test_topic\?blah1=;q=2;y=3\s*$#m, $text );

    return;
}

# Test the endPoint parameter with querystring
sub test_endPoint_Illegal {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $text = '';
    try {
        ($text) = $this->capture(
            sub {
                $this->createNewFoswikiApp(
                    requestParams => {
                        initializer => {
                            action   => ['rest'],
                            endPoint => 'http://this/that?blah=1;q=2',
                        },
                    },
                    engineParams => {
                        initialAttributes => {
                            path_info => '/' . __PACKAGE__ . '/trial',
                            method    => 'post',
                            action    => 'rest',
                            user      => $this->test_user_login,
                        },
                    },
                );
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;
        if ( ref($e) && $e->isa('Foswiki::EngineException') ) {
            $this->assert_equals( 404, $e->status, $e->stringify );
        }
        else {
            $e->rethrow;
        }
    };

    return;
}

# Test the redirectto parameter with querystring
sub test_redirectto_Illegal {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    my $text = '';
    try {
        ($text) = $this->capture(
            sub {
                $this->createNewFoswikiApp(
                    requestParams => {
                        initializer => {
                            action     => ['rest'],
                            redirectto => 'http://this/that?blah=1;q=2',
                        },
                    },
                    engineParams => {
                        initialAttributes => {
                            path_info => '/' . __PACKAGE__ . '/trial',
                            method    => 'post',
                            action    => 'rest',
                            user      => $this->test_user_login,
                        },
                    },
                );
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;
        if ( ref($e) && $e->isa('Foswiki::EngineException') ) {
            $this->assert_equals( 404, $e->status, $e->stringify );
        }
        else {
            $e->rethrow;
        }
    };

    return;
}

# Test the http_allow option, to ensure it restricts the request methods
sub test_http_allow {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler,
        http_allow => 'GET' );

    try {
        $this->capture(
            sub {
                $this->createNewFoswikiApp(
                    requestParams =>
                      { initializer => { action => ['rest'], }, },
                    engineParams => {
                        initialAttributes => {
                            path_info => '/' . __PACKAGE__ . '/trial',
                            method    => 'post',
                            action    => 'rest',
                            user      => $this->test_user_login,
                        },
                    },
                );
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;
        if ( ref($e) && $e->isa('Foswiki::EngineException') ) {
            $this->assert_equals( 405, $e->status, $e->stringify );
        }
        else {
            $e->rethrow;
        }
    };
    $this->capture(
        sub {
            $this->createNewFoswikiApp(
                requestParams => { initializer => { action => ['rest'], }, },
                engineParams  => {
                    initialAttributes => {
                        path_info => '/' . __PACKAGE__ . '/trial',
                        method    => 'get',
                        action    => 'rest',
                        user      => $this->test_user_login,
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );

    return;
}

# Test checking the validation key
sub test_validate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler,
        validate => 1 );

    # Make sure a request with no validation key is trapped
    try {
        $this->capture(
            sub {
                $this->createNewFoswikiApp(
                    requestParams =>
                      { initializer => { action => ['rest'], }, },
                    engineParams => {
                        initialAttributes => {
                            path_info => '/' . __PACKAGE__ . '/trial',
                            method    => 'post',
                            action    => 'rest',
                            user      => $this->test_user_login,
                        },
                    },
                );
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;
        if ( ref($e) && $e->isa('Foswiki::EngineException') ) {
            $this->assert_equals( 403, $e->status, $e->stringify );
            $this->assert_matches( qr/\(403\)/, $e->reason, $e->stringify );
        }
        else {
            $e->rethrow;
        }
    };

    # Make sure a request with validation is OK
    $this->captureWithKey(
        rest => sub {
            $this->createNewFoswikiApp(
                requestParams => { initializer => { action => ['rest'], }, },
                engineParams  => {
                    initialAttributes => {
                        path_info => '/' . __PACKAGE__ . '/trial',
                        method    => 'post',
                        action    => 'rest',
                        user      => $this->test_user_login,
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );

    return;
}

# Test authentication requirement
sub test_authenticate {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler,
        authenticate => 1 );

    # Make sure a request with no authentication is trapped
    try {
        $this->capture(
            sub {
                $this->createNewFoswikiApp(
                    requestParams =>
                      { initializer => { action => ['rest'], }, },
                    engineParams => {
                        initialAttributes => {
                            path_info => '/' . __PACKAGE__ . '/trial',
                            method    => 'post',
                            action    => 'rest',
                            user      => undef,
                        },
                    },
                );
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;
        if ( ref($e) && $e->isa('Foswiki::EngineException') ) {
            $this->assert_equals( 401, $e->status, $e->stringify );
            $this->assert_matches( qr/\(401\)/, $e->reason, $e->stringify );
        }
        else {
            $e->rethrow;
        }
    };

    # Make sure a request with session authentication is OK
    $this->capture(
        sub {
            $this->createNewFoswikiApp(
                requestParams => { initializer => { action => ['rest'], }, },
                engineParams  => {
                    initialAttributes => {
                        path_info => '/' . __PACKAGE__ . '/trial',
                        method    => 'post',
                        action    => 'rest',
                        user      => $this->test_user_login,
                    },
                },
            );
            return $this->app->handleRequest;
        }
    );

    return;
}

# Test the endPoint parameter with a URL
sub test_endPoint_URL {
    my $this = shift;
    $this->expect_failure( 'Redirect to a URL is new in 1.2',
        with_dep => 'Foswiki,<,1.2' );
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );
    $Foswiki::cfg{PermittedRedirectHostUrls} = 'http://lolcats.com';

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action   => ['rest'],
                endPoint => "http://lolcats.com/funny?pussy=cat",
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => '/' . __PACKAGE__ . '/trial',
                method    => 'post',
                action    => 'rest',
                user      => $this->test_user_login,
            },
        },
    );
    $this->app->handleRequest;
    my ($text) = $this->capture(
        sub {
            $this->app->clear_response;
            return $this->app->handleRequest;
        }
    );
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

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action     => ['rest'],
                redirectto => "http://lolcats.com/funny?pussy=cat",
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => '/' . __PACKAGE__ . '/trial',
                method    => 'post',
                action    => 'rest',
                user      => $this->test_user_login,
            },
        },
    );
    $this->app->handleRequest;
    my ($text) = $this->capture(
        sub {
            $this->app->clear_response;
            return $this->app->handleRequest;
        }
    );
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

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action   => ['rest'],
                endPoint => "http://lolcats.com/funny?pussy=cat",
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => '/' . __PACKAGE__ . '/trial',
                method    => 'post',
                action    => 'rest',
                user      => $this->test_user_login,
            },
        },
    );
    $this->app->handleRequest;
    my ($text) = $this->capture(
        sub {
            $this->app->clear_response;
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr#^Status: 403#m, $text );

    return;
}

# Test the redirectto parameter with a bad URL
sub test_redirectto_badURL {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_handler );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                action     => ['rest'],
                redirectto => "http://lolcats.com/funny?pussy=cat",
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => '/' . __PACKAGE__ . '/trial',
                method    => 'post',
                action    => 'rest',
                user      => $this->test_user_login,
            },
        },
    );
    $this->app->handleRequest;
    my ($text) = $this->capture(
        sub {
            $this->app->clear_response;
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr#^Status: 403#m, $text );

    return;
}

# Test the redirectto with handler that dies
sub test_500 {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'trial', \&rest_and_be_thankful );

    $this->createNewFoswikiApp(
        requestParams => { initializer => { action => ['rest'], }, },
        engineParams  => {
            initialAttributes => {
                path_info => '/' . __PACKAGE__ . '/trial',
                method    => 'post',
                action    => 'rest',
                user      => $this->test_user_login,
            },
        },
    );
    $this->app->handleRequest;
    my ($text) = $this->capture(
        sub {
            $this->app->clear_response;
            return $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr#^Status: 500#m, $text );
    return;
}

# Test the topic context
#  - Item12055: PopTopicContext in rest handler loses default context.
sub test_topic_context {
    my $this = shift;
    Foswiki::Func::registerRESTHandler( 'context', \&rest_context );
    $this->createNewFoswikiApp(
        requestParams => { initializer => { action => ['rest'], }, },
        engineParams  => {
            initialAttributes => {
                path_info => '/' . __PACKAGE__ . '/context',
                method    => 'post',
                action    => 'rest',
                user      => $this->test_user_login,
            },
        },
    );

    my ($text) = $this->capture(
        sub {
            return $this->app->handleRequest;
        }
    );

    $this->assert_matches( qr#$Foswiki::cfg{UsersWebName}#,
        $text, "Users web context was lost" );
    return;
}

1;
