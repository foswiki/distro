package RequestTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );
use strict;
use warnings;

use Foswiki::Request;
use Foswiki::Request::Upload;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $Foswiki::cfg{ScriptUrlPath} = '/fatwilly/bin';
    $Foswiki::cfg{Sessions}{CookieRealm} = 'weebles.wobble';
    delete $Foswiki::cfg{ScriptUrlPaths};
}

# Test default empty constructor
sub test_empty_new {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $this->assert_str_equals( '', $req->action, '$req->action() not empty' );
    $this->assert_str_equals( '', $req->pathInfo,
        '$req->pathInfo() not empty' );
    $this->assert_str_equals( '', $req->remoteAddress,
        '$req->remoteAddress() not empty' );
    $this->assert_str_equals( '', $req->uri, '$req->uri() not empty' );
    $this->assert_null( $req->method,     '$req->method() not null' );
    $this->assert_null( $req->remoteUser, '$req->remoteUser() not null' );
    $this->assert_null( $req->serverPort, '$req->serverPort() not null' );

    my @list = $req->header();
    $this->assert_str_equals( 0, scalar @list, '$req->header not empty' );

    @list = ();
    @list = $req->multi_param();
    $this->assert_str_equals( 0, scalar @list, '$req->param not empty' );

    my $ref = $req->cookies();
    $this->assert_str_equals( 'HASH', ref($ref),
        '$req->cookies did not returned a hashref' );
    $this->assert_str_equals( 0, scalar keys %$ref, '$req->cookies not empty' );

    $ref = $req->uploads();
    $this->assert_str_equals( 'HASH', ref($ref),
        '$req->uploads did not returned a hashref' );
    $this->assert_str_equals( 0, scalar keys %$ref, '$req->uploads not empty' );
}

sub test_new_from_hash {
    my $this = shift;
    my %init = (
        simple      => 's1',
        simple2     => ['s2'],
        multi       => [qw(m1 m2)],
        'undef'     => undef,
        multi_undef => [],
    );
    my $req = new Foswiki::Request( \%init );
    $this->assert_str_equals(
        5,
        scalar $req->multi_param(),
        'Wrong number of parameteres'
    );
    $this->assert_str_equals(
        's1',
        scalar $req->param('simple'),
        'Wrong parameter value'
    );
    $this->assert_str_equals(
        's2',
        scalar $req->param('simple2'),
        'Wrong parameter value'
    );
    $this->assert_str_equals(
        'm1',
        scalar $req->param('multi'),
        'Wrong parameter value'
    );
    my @values = $req->multi_param('multi');
    $this->assert_str_equals( 2,    scalar @values, 'Wrong number of values' );
    $this->assert_str_equals( 'm1', $values[0],     'Wrong parameter value' );
    $this->assert_str_equals( 'm2', $values[1],     'Wrong parameter value' );
    $this->assert_null( scalar $req->param('undef'), 'Wrong parameter value' );
    @values = $req->multi_param('multi_undef');
    $this->assert_str_equals( 0, scalar @values, 'Wrong parameter value' );
}

sub test_new_from_file {
    my $this = shift;
    require File::Temp;
    my $tmp = File::Temp->new( UNLINK => 1 );
    print( $tmp <<EOF
simple=s1
simple2=s2
multi=m1
multi=m2
empty=
=
EOF
    );
    seek( $tmp, 0, 0 );
    my $req = new Foswiki::Request($tmp);
    $this->assert_str_equals(
        4,
        scalar $req->param(),
        'Wrong number of parameters'
    );
    $this->assert_str_equals(
        's1',
        scalar $req->param('simple'),
        'Wrong parameter value'
    );
    $this->assert_str_equals(
        's2',
        scalar $req->param('simple2'),
        'Wrong parameter value'
    );
    my @values = $req->multi_param('multi');
    $this->assert_str_equals( 2,    scalar @values, 'Wrong number o values' );
    $this->assert_str_equals( 'm1', $values[0],     'Wrong parameter value' );
    $this->assert_str_equals( 'm2', $values[1],     'Wrong parameter value' );
    $this->assert_str_equals(
        '',
        scalar $req->param('empty'),
        'Wrong parameter value'
    );
}

#  Note, the ViewScriptTests also has some url parsing tests, so
#  check there too!
#
sub test_Request_parse {
    my $this = shift;

    $Foswiki::cfg{StrictURLParsing} = 0;
    my @paths = my @comparisons = (

        #Query Path  Params,     Web     topic,   invalidWeb,   invalidTopic
        [ '/', undef, '', undef, undef, undef ],
        [ '/', { topic => 'Main.WebHome' }, 'Main', 'WebHome', undef, undef ],

        # topic= overrides any pathinfo
        [
            '/Foo/Bar', { topic => 'Main.WebHome' },
            'Main', 'WebHome',
            undef,  undef
        ],

# defaultweb is not processed by the request object, so web is unset by the Request.
        [
            '/', { defaultweb => 'Sandbox', topic => 'WebHome' },
            '', 'WebHome', undef, undef
        ],

        [ '/Main/WebHome',   undef, 'Main',    'WebHome', undef,  undef ],
        [ '//Main//WebHome', undef, 'Main',    'WebHome', undef,  undef ],
        [ '//Sandbox///',    undef, 'Sandbox', undef,     undef,  undef ],
        [ '/Main..WebHome',  undef, 'Main',    'WebHome', undef,  undef ],
        [ '/blah/asdf',      undef, undef,     undef,     'blah', undef ],
        [ '/Main.WebHome',   undef, 'Main',    'WebHome', undef,  undef ],
        [ '/Web/SubWeb.WebHome', undef, 'Web/SubWeb', 'WebHome', undef, undef ],
        [ '/Web/SubWeb/WebHome', undef, 'Web/SubWeb', 'WebHome', undef, undef ],
        [ '/Web.Subweb.WebHome', undef, 'Web/Subweb', 'WebHome', undef, undef ],
        [
            '/Web.Subweb.Webhome/', undef, 'Web/Subweb/Webhome', undef,
            undef,                  undef
        ],
        [ '/3#/blah',          undef, undef, undef, '3#',  undef ],
        [ '/Web.a<script>lah', undef, undef, undef, undef, 'a<script>lah' ],

        # This next one  works because of auto fix-up of lower case topic name
        [ '/Blah/asdf', undef, 'Blah', 'Asdf', undef, undef ],

        # non-Strict URL parsing tests
        [ '/WebHome', undef, undef,    'WebHome', undef, undef ],
        [ '/Notaweb', undef, undef,    'Notaweb', undef, undef ],
        [ '/System',  undef, 'System', undef,     undef, undef ],

    );
    my $tn = 0;
    foreach my $set (@paths) {
        $tn++;
        my $req = new Foswiki::Request( $set->[1] );
        $req->pathInfo( $set->[0] );
        $this->createNewFoswikiSession( 'AdminUser', $req );

        #print STDERR $req->pathInfo() . " web "
        #  . ( ( defined $req->web() ) ? $req->web() : 'undef' )
        #  . " topic "
        #  . ( ( defined $req->topic() ) ? $req->topic() : 'undef' ) . "\n";

        $this->assert_str_equals( $set->[0], $req->pathInfo,
            "Test $tn: Wrong pathInfo value" );
        $this->assert_equals( $set->[2], $req->web(),
            "Test $tn: Incorrect web returned" );
        $this->assert_equals( $set->[3], $req->topic(),
            "Test $tn: Incorrect topic returned" );

        $this->assert_equals( $set->[4], $req->invalidWeb(),
            "Test $tn: Unexpected invalid web" );
        $this->assert_equals( $set->[5], $req->invalidTopic(),
            "Test $tn: Unexpected invalid topic" );
    }
}

sub test_action {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    foreach (qw(view edit save upload preview rdiff)) {
        $this->assert_str_not_equals( $_, $req->action,
            'Wrong initial "action" value' );
        $req->action($_);
        $this->assert_str_equals( $_, $req->action, 'Wrong action value' );
        $this->assert_str_equals( $_, $ENV{FOSWIKI_ACTION},
            'Wrong FOSWIKI_ACTION environment' );
    }
}

sub test_method {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    foreach (qw(GET HEAD POST)) {
        $this->assert_str_not_equals(
            $_,
            $req->method || '',
            'Wrong initial "method" value'
        );
        $req->method($_);
        $this->assert_str_equals( $_, $req->method, 'Wrong method value' );
    }
}

sub test_pathInfo {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    foreach ( qw(/ /abc /abc/ /abc/def /abc/def/), '' ) {
        $this->assert_str_not_equals( $_, $req->pathInfo,
            'Wrong initial "pathInfo" value' );
        $req->pathInfo($_);
        $this->assert_str_equals( $_, $req->pathInfo, 'Wrong pathInfo value' );
    }
}

sub test_protocol {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    $req->secure(0);
    $this->assert_str_equals( 'http', $req->protocol, 'Wrong protocol' );
    $this->assert_num_equals( 0, $req->secure, 'Wrong secure flag' );
    $req->secure(1);
    $this->assert_str_equals( 'https', $req->protocol, 'Wrong protocol' );
    $this->assert_num_equals( 1, $req->secure, 'Wrong secure flag' );
}

sub test_uri {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    foreach ( qw(/ /abc/def /abc/ /Web/Topic?a=b&b=c), '' ) {
        $this->assert_str_not_equals( $_, $req->uri,
            'Wrong initial "uri" value' );
        $req->uri($_);
        $this->assert_str_equals( $_, $req->uri, 'Wrong uri value' );
    }
}

sub test_remoteAddress {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    foreach (qw(127.0.0.1 10.1.1.1 192.168.0.1)) {
        $req->remoteAddress($_);
        $this->assert_str_equals( $_, $req->remoteAddress,
            'Wrong remoteAddress value' );
    }
}

sub test_remoteUser {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    foreach (qw(WikiGuest guest foo bar Baz)) {
        $req->remoteUser($_);
        $this->assert_str_equals( $_, $req->remoteUser,
            'Wrong remoteUser value' );
    }
}

sub test_serverPort {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    foreach (qw(80 443 8080)) {
        $req->serverPort($_);
        $this->assert_num_equals( $_, $req->serverPort,
            'Wrong serverPort value' );
    }
}

sub test_queryString {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    $req->param( -name => 'simple1', -value => 's1' );
    $this->assert_equals( 'simple1=s1', $req->query_string,
        'Wrong query string' );
    $req->param( -name => 'simple2', -value => 's2' );
    $this->assert_matches( 'simple1=s1[;&]simple2=s2', $req->query_string,
        'Wrong query string' );
    $req->multi_param( -name => 'multi', -value => [qw(m1 m2)] );
    $this->assert_matches(
        'simple1=s1[;&]simple2=s2[;&]multi=m1[;&]multi=m2',
        scalar $req->query_string,
        'Wrong query string'
    );
}

sub test_forwarded_for {
    my $this = shift;
    $ENV{HOST}                   = "myhost.com";
    $ENV{HTTP_X_FORWARDED_FOR}   = '1.2.3.4';
    $ENV{HTTP_X_FORWARDED_HOST}  = 'hop1.com, hop2.com';
    $ENV{HTTP_X_FORWARDED_PROTO} = 'https';

    #$ENV{HTTP_X_FORWARDED_PORT}  = '443';
    $Foswiki::cfg{PROXY}{UseForwardedFor}     = 1;
    $Foswiki::cfg{PROXY}{UseForwardedHeaders} = 1;

    my $req = new Foswiki::Request("");
    $req->secure('1');
    $req->action('view');
    $req->path_info('/Main/WebHome');

    # These are not needed.   HTTP_ env variables are parsed from the headers
    # by the server.  Foswiki::Request::url calls Engine::_getConnectionData
    # which processes the headers
    #$req->header( Host               => 'myhost.com' );
    #$req->header( 'X-Forwarded-Host' => 'hop1.com,  hop2.com' );

    my $base = 'https://hop1.com';
    $this->assert_str_equals(
        $base,
        $req->url( -base => 1 ),
        'Wrong BASE url with Forwarded-Host header'
    );

    # Verify that port is recovered from first forwarded host
    $ENV{HTTP_X_FORWARDED_HOST} = 'onehop.com:8080, hop2.com';
    $base = 'https://onehop.com:8080';
    $this->assert_str_equals(
        $base,
        $req->url( -base => 1 ),
        'Wrong BASE url with Forwarded-Host multiple header'
    );

    # Verify that Forwarded-Port overrides forwarded host port
    $ENV{HTTP_X_FORWARDED_HOST} = 'onehop.com:8080, hop2.com';
    $ENV{HTTP_X_FORWARDED_PORT} = '443';
    $base                       = 'https://onehop.com';
    $this->assert_str_equals(
        $base,
        $req->url( -base => 1 ),
        'Wrong BASE url with Forwarded-Host multiple header'
    );

    $base                              = 'http://your.domain.com';
    $Foswiki::cfg{DefaultUrlHost}      = 'http://your.domain.com';
    $Foswiki::cfg{ForceDefaultUrlHost} = 1;
    $this->assert_str_equals(
        $base,
        $req->url( -base => 1 ),
        'Wrong BASE url with Forwarded-Host single header + forceDefaultUrlHost'
    );

}

sub perform_url_test {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    my ( $secure, $host, $action, $path ) = @_;
    $ENV{HTTP_HOST} = $host;
    $ENV{HTTPS} = ($secure) ? 'ON' : undef;

    $req->secure($secure);
    $req->header( Host => $host );
    $req->action($action);
    $req->path_info($path);
    $req->param( -name => 'simple1', -value => 's1 s1' );
    $req->param( -name => 'simple2', -value => 's2' );
    $req->multi_param( -name => 'multi', -value => [qw(m1 m2)] );
    my $base = $secure ? 'https' : 'http';
    $base .= '://' . $host;
    $this->assert_str_equals( $base, $req->url( -base => 1 ),
        'Wrong BASE url' );
    my $absolute .=
      $Foswiki::cfg{ScriptUrlPath} . "/$action$Foswiki::cfg{ScriptSuffix}";
    $this->assert_str_equals( $base . $absolute, $req->url, 'Wrong FULL url' );
    $this->assert_str_equals(
        $absolute,
        $req->url( -absolute => 1 ),
        'Wrong ABSOLUTE url'
    );
    $this->assert_str_equals(
        $action . $Foswiki::cfg{ScriptSuffix},
        $req->url( -relative => 1 ),
        'Wrong RELATIVE url'
    );

    $this->assert_str_equals(
        $base . $absolute . $path,
        $req->url( -full => 1, -path => 1 ),
        'Wrong FULL+PATH url'
    );
    $this->assert_str_equals(
        $absolute . $path,
        $req->url( -absolute => 1, -path => 1 ),
        'Wrong ABSOLUTE+PATH url'
    );
    $this->assert_str_equals(
        $action . $Foswiki::cfg{ScriptSuffix} . $path,
        $req->url( -relative => 1, -path => 1 ),
        'Wrong RELATIVE+PATH url'
    );

    my $query = '\?simple1=s1%20s1[&;]simple2=s2[;&]multi=m1[;&]multi=m2';
    $base =~ s/\./\\./g;
    $this->assert_matches(
        $base . $absolute . $query,
        $req->url( -full => 1, -query => 1 ),
        'Wrong FULL+QUERY_STRING url'
    );
    $this->assert_matches(
        $absolute . $query,
        $req->url( -absolute => 1, -query => 1 ),
        'Wrong ABSOLUTE+QUERY_STRING url'
    );
    $this->assert_matches(
        $action . $Foswiki::cfg{ScriptSuffix} . $query,
        $req->url( -relative => 1, -query => 1 ),
        'Wrong RELATIVE+QUERY_STRING url'
    );

    $this->assert_matches(
        $base . $absolute . $path . $query,
        $req->url( -full => 1, -query => 1, -path => 1 ),
        'Wrong FULL+PATH_INFO+QUERY_STRING url'
    );
    $this->assert_matches(
        $absolute . $path . $query,
        $req->url( -absolute => 1, -query => 1, -path => 1 ),
        'Wrong ABSOLUTE+PATH_INFO+QUERY_STRING url'
    );
    $this->assert_matches(
        $action . $Foswiki::cfg{ScriptSuffix} . $path . $query,
        $req->url( -relative => 1, -query => 1, -path => 1 ),
        'Wrong RELATIVE+PATH_INFO+QUERY_STRING url'
    );
}

sub battery_url_tests {
    my ( $this, $suffix ) = @_;
    $Foswiki::cfg{ScriptSuffix} = $suffix;
    $this->perform_url_test( 0, 'foo.bar',     'baz',  '/Web/Topic' );
    $this->perform_url_test( 1, 'foo.bar',     'baz',  '/Web/Topic' );
    $this->perform_url_test( 0, 'example.com', 'view', '/Main/WebHome' );
    $this->perform_url_test( 1, 'example.com', 'edit', '/Sandbox/TestTopic' );
}

sub test_url_no_suffix {
    my $this = shift;
    $this->battery_url_tests('');
}

sub test_url_pl_suffix {
    my $this = shift;
    $this->battery_url_tests('.pl');
}

sub test_url_cgi_suffix {
    my $this = shift;
    $this->battery_url_tests('.cgi');
}

sub test_url_alien_suffix {
    my $this = shift;
    $this->battery_url_tests('.abcdef');
}

sub test_query_param {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->queryParam( -name => 'q1', -value => 'v1' );
    my @result = $req->multi_param('q1');
    $this->assert_deep_equals( ['v1'], \@result,
        'wrong value from queryParam()' );

    $req->queryParam( -name => 'q2', -values => [qw(v1 v2)] );
    @result = $req->multi_param('q2');
    $this->assert_deep_equals( [qw(v1 v2)], \@result,
        'wrong value from queryParam()' );

    $req->queryParam( 'p', qw(qv1 qv2 qv3) );
    @result = $req->multi_param('p');
    $this->assert_deep_equals( [qw(qv1 qv2 qv3)], \@result,
        'wrong value from queryParam()' );

    @result = $req->queryParam();
    $this->assert_deep_equals( [qw(q1 q2 p)], \@result,
        'wrong parameter name from queryParam()' );

    @result = ( scalar $req->param('q2') );
    $this->assert_deep_equals( ['v1'], \@result,
        'wrong parameter name from queryParam()' );

    @result = ( scalar $req->queryParam('nonexistent') );
    $this->assert_deep_equals( [undef], \@result,
        'wrong parameter name from queryParam()' );

    @result = $req->queryParam('nonexistent');
    $this->assert_num_equals(
        0,
        scalar @result,
        'wrong parameter name from queryParam()'
    );

    $req->deleteAll();
    $req->queryParam( '0' => 'defined' );
    @result = $req->multi_param();
    $this->assert_deep_equals( ['0'], \@result,
        'wrong parameter names from queryParam()' );
    @result = $req->multi_param(0);
    $this->assert_deep_equals( ['defined'], \@result,
        'wrong value from queryParam()' );

    $req->queryParam( '0' => '' );
    @result = $req->multi_param(0);
    $this->assert_deep_equals( [''], \@result,
        'wrong value from queryParam()' );

    $req->queryParam( '0' => [ '', 0 ] );
    @result = $req->multi_param(0);
    $this->assert_deep_equals( [ '', 0 ],
        \@result, 'wrong value from queryParam()' );

    $req->queryParam( '' => [ 0, '', 0 ] );
    @result = $req->multi_param('');
    $this->assert_deep_equals( [ 0, '', 0 ],
        \@result, 'wrong value from queryParam()' );

    $req = new Foswiki::Request("");
    $req->method('POST');
    $req->queryParam( -name => 'q1', -value => 'v1' );
    @result = $req->multi_param('q1');
    $this->assert_num_equals(
        0,
        scalar @result,
        'wrong value from queryParam()'
    );
}

sub test_body_param {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->bodyParam( -name => 'q1', -value => 'v1' );
    my @result = $req->multi_param('q1');
    $this->assert_deep_equals( ['v1'], \@result,
        'wrong value from bodyParam()' );

    $req->bodyParam( -name => 'q2', -values => [qw(v1 v2)] );
    @result = $req->multi_param('q2');
    $this->assert_deep_equals( [qw(v1 v2)], \@result,
        'wrong value from bodyParam()' );

    $req->bodyParam( 'p', qw(qv1 qv2 qv3) );
    @result = $req->multi_param('p');
    $this->assert_deep_equals( [qw(qv1 qv2 qv3)], \@result,
        'wrong value from bodyParam()' );

    @result = $req->bodyParam();
    $this->assert_deep_equals( [qw(q1 q2 p)], \@result,
        'wrong parameter name from bodyParam()' );

    @result = ( scalar $req->param('q2') );
    $this->assert_deep_equals( ['v1'], \@result,
        'wrong parameter name from bodyParam()' );

    @result = ( scalar $req->bodyParam('nonexistent') );
    $this->assert_deep_equals( [undef], \@result,
        'wrong parameter name from bodyParam()' );

    @result = $req->bodyParam('nonexistent');
    $this->assert_deep_equals( [], \@result,
        'wrong parameter name from bodyParam()' );

    $req->deleteAll();
    $req->queryParam( '0' => 'defined' );
    @result = $req->param();
    $this->assert_deep_equals( ['0'], \@result,
        'wrong parameter names from queryParam()' );
    @result = $req->multi_param(0);
    $this->assert_deep_equals( ['defined'], \@result,
        'wrong value from queryParam()' );

    $req->queryParam( '0' => '' );
    @result = $req->multi_param(0);
    $this->assert_deep_equals( [''], \@result,
        'wrong value from queryParam()' );

    $req->queryParam( '0' => [ '', 0 ] );
    @result = $req->multi_param(0);
    $this->assert_deep_equals( [ '', 0 ],
        \@result, 'wrong value from queryParam()' );

    $req->queryParam( '' => [ 0, '', 0 ] );
    @result = $req->multi_param('');
    $this->assert_deep_equals( [ 0, '', 0 ],
        \@result, 'wrong value from queryParam()' );
}

sub test_cookies {
    my $this    = shift;
    my $req     = new Foswiki::Request("");
    my %cookies = ();
    $cookies{c1} = $req->cookie( -name => 'c1', -value => 'value1' );
    $this->assert(
        UNIVERSAL::isa( $cookies{c1}, 'CGI::Cookie' ),
        "cookie() didn't return a CGI::Cookie object"
    );
    $cookies{c2} = $req->cookie( -name => 'c2', -value => 'value2' );
    my @result = $req->cookie();
    $this->assert_num_equals(
        0,
        scalar @result,
        'cookie() method must not store cookies created'
    );

    $req->cookies( \%cookies );
    @result = $req->cookie();
    $this->assert_deep_equals(
        [qw(c1 c2)],
        [ sort @result ],
        'wrong returned cookie names'
    );
    $this->assert_equals( 'value1', $req->cookie('c1'), 'wrong cookie value' );
    $this->assert_equals( 'value2', $req->cookie('c2'), 'wrong cookie value' );

    @result = $req->cookie('nonexistent');
    $this->assert_num_equals(
        0,
        scalar @result,
        'returned value for non-existent cookie name'
    );

    $result[0] = $req->cookie( -value => 'test' );
    $this->assert_null( $result[0],
        'cookie() did not return undef for invalid parameters' );

    $result[0] = $req->cookie( -value => 'test', -name => '' );
    $this->assert_null( $result[0],
        'cookie() did not return undef for invalid parameters' );

    $result[0] = $req->cookie(
        -name    => 'c3',
        -value   => 'value3',
        -path    => '/test',
        -expires => '1234',
        -secure  => 1
    );
    $result[1] = new CGI::Cookie(
        -name    => 'c3',
        -domain  => 'weebles.wobble',
        -value   => 'value3',
        -path    => '/test',
        -expires => '1234',
        -secure  => 1
    );

    $this->assert_deep_equals( $result[0], $result[1],
        'Wrong returned cookie' );
}

sub test_delete {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->multi_param( -name => 'q2', -values => [qw(v1 v2)] );
    $req->param( -name => 'q1',   -value => 'v1' );
    $req->param( -name => 'null', -value => 0 );
    $req->multi_param( 'p', qw(qv1 qv2 qv3) );
    $req->param( -name => 'q3', -value => 'v3' );
    require File::Temp;
    my $tmp = File::Temp->new( UNLINK => 0 );
    my ( %uploads, %headers ) = ();
    %headers = (
        'Content-Type'        => 'text/plain',
        'Content-Disposition' => 'form-data; name="file"; filename="Temp.txt"'
    );
    $req->param( file => "Temp.txt" );
    $uploads{"Temp.txt"} = new Foswiki::Request::Upload(
        headers => {%headers},
        tmpname => $tmp->filename,
    );
    $req->uploads( \%uploads );

    my @result = $req->multi_param();
    $this->assert_deep_equals( [qw(q2 q1 null p q3 file)],
        \@result, 'wrong returned parameter values' );

    #Windows refuses (sensibly?) to refuse to unlink a file which is open
    #so we need to close the File::Temp (this isa hackjobbie i think)
    close($tmp);

    $req->delete('q1');
    @result = $req->multi_param();
    $this->assert_deep_equals( [qw(q2 null p q3 file)], \@result,
        'wrong returned parameter values' );

    $req->Delete(qw(q2 q3 null));
    @result = $req->multi_param();
    $this->assert_deep_equals( [qw(p file)], \@result,
        'wrong returned parameter values' );

    $req->delete('file');
    @result = $req->multi_param();
    $this->assert_deep_equals( [qw(p)], \@result,
        'wrong returned parameter values' );
    $this->assert(
        !-e $tmp->filename,
        'Uploaded file not deleted after call to delete() - see :'
          . $tmp->filename
    );
}

sub test_delete_all {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->multi_param( -name => 'q2', -values => [qw(v1 v2)] );
    $req->param( -name => 'q1', -value => 'v1' );
    $req->multi_param( 'p', qw(qv1 qv2 qv3) );
    $req->param( -name => 'q3', -value => 'v3' );
    require File::Temp;
    my $tmp = File::Temp->new( UNLINK => 0 );
    my ( %uploads, %headers ) = ();
    %headers = (
        'Content-Type'        => 'text/plain',
        'Content-Disposition' => 'form-data; name="file"; filename="Temp.txt"'
    );
    $req->param( file => "Temp.txt" );
    $uploads{"Temp.txt"} = new Foswiki::Request::Upload(
        headers => {%headers},
        tmpname => $tmp->filename,
    );
    $req->uploads( \%uploads );

    my @result = $req->multi_param();
    $this->assert_deep_equals( [qw(q2 q1 p q3 file)], \@result,
        'wrong returned parameter values' );

    #Windows refuses (sensibly?) to refuse to unlink a file which is open
    #so we need to close the File::Temp (this isa hackjobbie i think)
    close($tmp);

    $req->deleteAll();
    @result = $req->multi_param();
    $this->assert_num_equals( 0, scalar @result, "deleteAll didn't work" );

    $req->multi_param( -name => 'q2', -values => [qw(v1 v2)] );
    $req->param( -name => 'q1', -value => 'v1' );
    $req->multi_param( 'p', qw(qv1 qv2 qv3) );
    $req->param( -name => 'q3', -value => 'v3' );
    $tmp = File::Temp->new( UNLINK => 0 );
    $req->param( file => "Temp.txt" );
    $uploads{"Temp.txt"} = new Foswiki::Request::Upload(
        headers => {%headers},
        tmpname => $tmp->filename,
    );
    $req->uploads( \%uploads );

    close($tmp);
    $req->delete_all();
    @result = $req->multi_param();
    $this->assert_num_equals( 0, scalar @result, "deleteAll didn't work" );
    $this->assert(
        !-e $tmp->filename,
        'Uploaded file not deleted after call to delete() - see :'
          . $tmp->filename
    );
}

sub test_header {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->header( 'h-1' => 'v1' );
    my @result = $req->header('H-1');
    $this->assert_deep_equals( ['v1'], \@result, 'wrong value from header()' );

    $req->header( 'h2' => [qw(v1 v2)] );

    @result = $req->header('h2');
    $this->assert_deep_equals( [qw(v1 v2)], \@result,
        'wrong value from header()' );

    $req->header( 'h', qw(v1 v2 v3) );
    @result = $req->header('h');
    $this->assert_deep_equals( [qw(v1 v2 v3)], \@result,
        'wrong value from header()' );

    @result = sort $req->header();
    $this->assert_deep_equals( [qw(h h-1 h2)], \@result,
        'wrong header field names from header()' );

    @result = ( scalar $req->header('h2') );
    $this->assert_deep_equals( ['v1'], \@result,
        'wrong header field values from header()' );

    @result = ( scalar $req->header('nonexistent') );
    $this->assert_deep_equals( [undef], \@result,
        'wrong header field values from header()' );

    @result = $req->header('nonexistent');
    $this->assert_deep_equals( [], \@result,
        'wrong header field values from header()' );
}

sub test_save {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    scalar $req->param( -name => 'simple',  -value => 's1' );
    scalar $req->param( -name => 'simple2', -value => 's2' );
    scalar $req->multi_param( -name => 'multi', -value => [qw(m1 m2)] );
    (undef) = $req->multi_param( -name => 'undef', -value => [undef] );
    require File::Temp;
    my $tmp = File::Temp->new( UNLINK => 1 );
    $req->save($tmp);
    seek( $tmp, 0, 0 );
    $this->assert_str_equals(
        <<EOF
simple=s1
simple2=s2
multi=m1
multi=m2
undef=
=
EOF
        , join( '', <$tmp> ), 'Wrong generated file'
    );
}

sub test_load {
    my $this = shift;
    require File::Temp;
    my $tmp = File::Temp->new( UNLINK => 1 );
    print( $tmp <<EOF
simple=s1
simple2=s2
multi=m1
multi=m2
empty=
=
EOF
    );
    seek( $tmp, 0, 0 );
    my $req = new Foswiki::Request("");
    $req->load($tmp);
    $this->assert_str_equals(
        4,
        scalar $req->multi_param(),
        'Wrong number of parameters'
    );
    $this->assert_str_equals(
        's1',
        scalar $req->param('simple'),
        'Wrong parameter value'
    );
    $this->assert_str_equals(
        's2',
        scalar $req->param('simple2'),
        'Wrong parameter value'
    );
    my @values = $req->multi_param('multi');
    $this->assert_str_equals( 2,    scalar @values, 'Wrong number o values' );
    $this->assert_str_equals( 'm1', $values[0],     'Wrong parameter value' );
    $this->assert_str_equals( 'm2', $values[1],     'Wrong parameter value' );
    $this->assert_str_equals(
        '',
        scalar $req->param('empty'),
        'Wrong parameter value'
    );
}

sub test_upload {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    require File::Temp;
    my $tmp = File::Temp->new( UNLINK => 1 );
    print( $tmp <<EOF
Arbitrary file...
EOF
    );
    seek( $tmp, 0, 0 );
    my ( %uploads, %headers ) = ();
    %headers = (
        'Content-Type'        => 'text/plain',
        'Content-Disposition' => 'form-data; name="file"; filename="Temp.txt"'
    );
    $req->param( file => "Temp.txt" );
    $uploads{"Temp.txt"} = new Foswiki::Request::Upload(
        headers => {%headers},
        tmpname => $tmp->filename,
    );
    $req->uploads( \%uploads );

    my $fname = $req->param('file');
    $this->assert_deep_equals(
        \%headers,
        $req->uploadInfo($fname),
        'Wrong uploadInfo'
    );
    $this->assert_str_equals(
        $tmp->filename,
        $req->tmpFileName($fname),
        'Wrong tmpFileName()'
    );
    my $fh = $req->upload('file');
    my $text = join( '', <$fh> );
    $this->assert_str_equals( "Arbitrary file...\n",
        $text, 'Wrong file contents' );
}

sub test_accessors {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    my $accept =
      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
    $req->header( 'User-Agent' => 'Mozilla/5.0' );
    $req->header( 'Referer'    => 'http://foo.bar' );
    $req->header( 'Accept'     => $accept );
    $req->secure(0);

    $this->assert_str_equals( 'Mozilla/5.0', $req->user_agent,
        'Wrong User-Agent' );
    $this->assert_str_equals( 'Mozilla/5.0', $req->userAgent,
        'Wrong User-Agent' );
    $this->assert_str_equals( 'http://foo.bar', $req->referer,
        'Wrong referer()' );
    $this->assert_str_equals( $accept, $req->http('accept'),
        'Wrong value from http()' );
    $this->assert_str_equals(
        $accept,
        $req->http('http_accept'),
        'Wrong value from http()'
    );
    $this->assert_str_equals(
        $accept,
        $req->http('HTTP_ACCEPT'),
        'Wrong value from http()'
    );
    $this->assert_num_equals( 0, $req->https, 'Wrong https flag' );

    $req->secure(1);
    $this->assert_num_equals( 1, $req->https('https'), 'Wrong https flag' );

    my @result = sort $req->http();
    $this->assert_deep_equals( [qw(accept referer user-agent)],
        \@result, 'Wrong header field names' );
}

1;
