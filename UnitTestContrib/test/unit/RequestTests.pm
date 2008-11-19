package RequestTests;

use base qw(Unit::TestCase);
use strict;
use warnings;

use Foswiki::Request;
use Foswiki::Request::Upload;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $Foswiki::cfg{ScriptUrlPath} = '/twiki/bin';
    delete $Foswiki::cfg{ScriptUrlPaths};
}

# Test default empty constructor
sub test_empty_new {
    my $this = shift;
    my $req = new Foswiki::Request("");

    $this->assert_str_equals('', $req->action, '$req->action() not empty');
    $this->assert_str_equals('', $req->pathInfo, '$req->pathInfo() not empty');
    $this->assert_str_equals('', $req->remoteAddress, '$req->remoteAddress() not empty');
    $this->assert_str_equals('', $req->uri, '$req->uri() not empty');
    $this->assert_null($req->method, '$req->method() not null');
    $this->assert_null($req->remoteUser, '$req->remoteUser() not null');
    $this->assert_null($req->serverPort, '$req->serverPort() not null');

    my @list = $req->header();
    $this->assert_str_equals(0, scalar @list, '$req->header not empty');
    
    @list = ();
    @list = $req->param();
    $this->assert_str_equals(0, scalar @list, '$req->param not empty');
    
    my $ref = $req->cookies();
    $this->assert_str_equals('HASH', ref($ref), '$req->cookies did not returned a hashref');
    $this->assert_str_equals(0, scalar keys %$ref, '$req->cookies not empty');
    
    $ref = $req->uploads();
    $this->assert_str_equals('HASH', ref($ref), '$req->uploads did not returned a hashref');
    $this->assert_str_equals(0, scalar keys %$ref, '$req->uploads not empty');
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
    my $req = new Foswiki::Request(\%init);
    $this->assert_str_equals(5, scalar $req->param(), 'Wrong number of parameteres');
    $this->assert_str_equals('s1', $req->param('simple'), 'Wrong parameter value');
    $this->assert_str_equals('s2', $req->param('simple2'), 'Wrong parameter value');
    $this->assert_str_equals('m1', scalar $req->param('multi'), 'Wrong parameter value');
    my @values = $req->param('multi');
    $this->assert_str_equals(2, scalar @values, 'Wrong number of values');
    $this->assert_str_equals('m1', $values[0], 'Wrong parameter value');
    $this->assert_str_equals('m2', $values[1], 'Wrong parameter value');
    $this->assert_null($req->param('undef'), 'Wrong parameter value');
    @values = $req->param('multi_undef');
    $this->assert_str_equals(0, scalar @values, 'Wrong parameter value');
}

sub test_new_from_file {
    my $this = shift;
    require File::Temp;
    my $tmp = File::Temp->new(UNLINK => 1);
    print($tmp <<EOF
simple=s1
simple2=s2
multi=m1
multi=m2
undef=
=
EOF
);
    seek($tmp, 0, 0);
    my $req = new Foswiki::Request($tmp);
    $this->assert_str_equals(4, scalar $req->param(), 'Wrong number of parameters');
    $this->assert_str_equals('s1', $req->param('simple'), 'Wrong parameter value');
    $this->assert_str_equals('s2', $req->param('simple2'), 'Wrong parameter value');
    my @values = $req->param('multi');
    $this->assert_str_equals(2, scalar @values, 'Wrong number o values');
    $this->assert_str_equals('m1', $values[0], 'Wrong parameter value');
    $this->assert_str_equals('m2', $values[1], 'Wrong parameter value');
    $this->assert_null($req->param('undef'), 'Wrong parameter value');
}

sub test_action {
    my $this = shift;
    my $req = new Foswiki::Request("");
    foreach (qw(view edit save upload preview rdiff)) {
        $this->assert_str_not_equals($_, $req->action, 'Wrong initial "action" value');
        $req->action($_);
        $this->assert_str_equals($_, $req->action, 'Wrong action value');
        $this->assert_str_equals($_, $ENV{TWIKI_ACTION}, 'Wrong TWIKI_ACTION environment');
    }
}

sub test_method {
    my $this = shift;
    my $req = new Foswiki::Request("");
    foreach (qw(GET HEAD POST)) {
        $this->assert_str_not_equals($_, $req->method || '', 'Wrong initial "method" value');
        $req->method($_);
        $this->assert_str_equals($_, $req->method, 'Wrong method value');
    }
}

sub test_pathInfo {
    my $this = shift;
    my $req = new Foswiki::Request("");
    foreach (qw(/ /abc /abc/ /abc/def /abc/def/), '') {
        $this->assert_str_not_equals($_, $req->pathInfo, 'Wrong initial "pathInfo" value');
        $req->pathInfo($_);
        $this->assert_str_equals($_, $req->pathInfo, 'Wrong pathInfo value');
    }
}

sub test_protocol {
    my $this = shift;
    my $req = new Foswiki::Request("");
    $req->secure(0);
    $this->assert_str_equals('http', $req->protocol, 'Wrong protocol');
    $this->assert_num_equals(0, $req->secure, 'Wrong secure flag');
    $req->secure(1);
    $this->assert_str_equals('https', $req->protocol, 'Wrong protocol');
    $this->assert_num_equals(1, $req->secure, 'Wrong secure flag');
}

sub test_uri {
    my $this = shift;
    my $req = new Foswiki::Request("");
    foreach (qw(/ /abc/def /abc/ /Web/Topic?a=b&b=c), '') {
        $this->assert_str_not_equals($_, $req->uri, 'Wrong initial "uri" value');
        $req->uri($_);
        $this->assert_str_equals($_, $req->uri, 'Wrong uri value');
    }
}

sub test_remoteAddress {
    my $this = shift;
    my $req = new Foswiki::Request("");
    foreach (qw(127.0.0.1 10.1.1.1 192.168.0.1)) {
        $req->remoteAddress($_);
        $this->assert_str_equals($_, $req->remoteAddress, 'Wrong remoteAddress value');
    }
}

sub test_remoteUser {
    my $this = shift;
    my $req = new Foswiki::Request("");
    foreach (qw(WikiGuest guest foo bar Baz)) {
        $req->remoteUser($_);
        $this->assert_str_equals($_, $req->remoteUser, 'Wrong remoteUser value');
    }
}

sub test_serverPort {
    my $this = shift;
    my $req = new Foswiki::Request("");
    foreach (qw(80 443 8080)) {
        $req->serverPort($_);
        $this->assert_num_equals($_, $req->serverPort, 'Wrong serverPort value');
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
    $req->param( -name => 'multi', -value => [qw(m1 m2)] );
    $this->assert_matches( 'simple1=s1[;&]simple2=s2[;&]multi=m1[;&]multi=m2',
        $req->query_string, 'Wrong query string' );
}

sub perform_url_test {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    my ( $secure, $host, $action, $path ) = @_;
    $req->secure($secure);
    $req->header( Host => $host );
    $req->action($action);
    $req->path_info($path);
    $req->param( -name => 'simple1', -value => 's1 s1' );
    $req->param( -name => 'simple2', -value => 's2' );
    $req->param( -name => 'multi',   -value => [qw(m1 m2)] );
    my $base = $secure ? 'https' : 'http';
    $base .= '://' . $host;
    $this->assert_str_equals( $base, $req->url( -base => 1 ),
        'Wrong BASE url' );
    my $absolute .= $Foswiki::cfg{ScriptUrlPath} . "/$action";
    $this->assert_str_equals( $base . $absolute, $req->url, 'Wrong FULL url' );
    $this->assert_str_equals( $absolute,
        $req->url( -absolute => 1, 'Wrong ABSOLUTE url' ) );
    $this->assert_str_equals( $action,
        $req->url( -relative => 1, 'Wrong RELATIVE url' ) );

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
        $action . $path,
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
        $action . $query,
        $req->url( -relative => 1, -query => 1 ),
        'Wrong RELATIVE+QUERY_STRING url'
    );

    $this->assert_matches(
        $base . $absolute . $query,
        $req->url( -full => 1, -query => 1, -path => 1 ),
        'Wrong FULL+PATH_INFO+QUERY_STRING url'
    );
    $this->assert_matches(
        $absolute . $query,
        $req->url( -absolute => 1, -query => 1, -path => 1 ),
        'Wrong ABSOLUTE+PATH_INFO+QUERY_STRING url'
    );
    $this->assert_matches(
        $action . $query,
        $req->url( -relative => 1, -query => 1, -path => 1 ),
        'Wrong RELATIVE+PATH_INFO+QUERY_STRING url'
    );
}

sub test_url {
    my $this = shift;
    $this->perform_url_test(0, 'foo.bar',  'baz', '/Web/Topic');
    $this->perform_url_test(1, 'foo.bar',  'baz', '/Web/Topic');
    $this->perform_url_test(0, 'example.com', 'view', '/Main/WebHome');
    $this->perform_url_test(1, 'example.com', 'edit', '/Sandbox/TestTopic');
}

sub test_query_param {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    
    $req->queryParam( -name => 'q1', -value => 'v1' );
    my @result = $req->param('q1');
    $this->assert_deep_equals(['v1'], \@result, 'wrong value from queryParam()');
    
    $req->queryParam( -name => 'q2', -values => [qw(v1 v2)] );
    @result = $req->param('q2');
    $this->assert_deep_equals([qw(v1 v2)], \@result, 'wrong value from queryParam()');
    
    $req->queryParam('p', qw(qv1 qv2 qv3));
    @result =  $req->param('p');
    $this->assert_deep_equals([qw(qv1 qv2 qv3)], \@result, 'wrong value from queryParam()');
    
    @result = $req->queryParam();
    $this->assert_deep_equals([qw(q1 q2 p)], \@result, 'wrong parameter name from queryParam()');
    
    @result = (scalar $req->param('q2'));
    $this->assert_deep_equals(['v1'], \@result, 'wrong parameter name from queryParam()');

    @result = (scalar $req->queryParam('nonexistent'));
    $this->assert_deep_equals([undef], \@result, 'wrong parameter name from queryParam()');
    
    @result = $req->queryParam('nonexistent');
    $this->assert_num_equals(0, scalar @result, 'wrong parameter name from queryParam()');

    $req = new Foswiki::Request("");
    $req->method('POST');
    $req->queryParam( -name => 'q1', -value => 'v1' );
    @result = $req->param('q1');
    $this->assert_num_equals(0, scalar @result, 'wrong value from queryParam()');
}

sub test_body_param {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    
    $req->bodyParam( -name => 'q1', -value => 'v1' );
    my @result = $req->param('q1');
    $this->assert_deep_equals(['v1'], \@result, 'wrong value from bodyParam()');
    
    $req->bodyParam( -name => 'q2', -values => [qw(v1 v2)] );
    @result = $req->param('q2');
    $this->assert_deep_equals([qw(v1 v2)], \@result, 'wrong value from bodyParam()');
    
    $req->bodyParam('p', qw(qv1 qv2 qv3));
    @result =  $req->param('p');
    $this->assert_deep_equals([qw(qv1 qv2 qv3)], \@result, 'wrong value from bodyParam()');
    
    @result = $req->bodyParam();
    $this->assert_deep_equals([qw(q1 q2 p)], \@result, 'wrong parameter name from bodyParam()');
    
    @result = (scalar $req->param('q2'));
    $this->assert_deep_equals(['v1'], \@result, 'wrong parameter name from bodyParam()');

    @result = (scalar $req->bodyParam('nonexistent'));
    $this->assert_deep_equals([undef], \@result, 'wrong parameter name from bodyParam()');
    
    @result = $req->bodyParam('nonexistent');
    $this->assert_deep_equals([], \@result, 'wrong parameter name from bodyParam()');
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

    $result[0] = $req->cookie(-value => 'test');
    $this->assert_null($result[0], 'cookie() did not return undef for invalid parameters');
    
    $result[0] = $req->cookie(-value => 'test', -name=> '');
    $this->assert_null($result[0], 'cookie() did not return undef for invalid parameters');
    
    $result[0] = $req->cookie(
        -name    => 'c3',
        -value   => 'value3',
        -path    => '/test',
        -expires => '1234',
        -secure  => 1
    );
    $result[1] = new CGI::Cookie(
        -name    => 'c3',
        -value   => 'value3',
        -path    => '/test',
        -expires => '1234',
        -secure  => 1
    );
    $this->assert_deep_equals($result[0], $result[1], 'Wrong returned cookie');
}

sub test_delete {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->param( -name => 'q2', -values => [qw(v1 v2)] );
    $req->param( -name => 'q1', -value  => 'v1' );
    $req->param( -name => 'null', -value => 0);
    $req->param( 'p', qw(qv1 qv2 qv3) );
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

    my @result = $req->param();
    $this->assert_deep_equals( [qw(q2 q1 null p q3 file)], \@result,
        'wrong returned parameter values' );

    $req->delete('q1');
    @result = $req->param();
    $this->assert_deep_equals( [qw(q2 null p q3 file)], \@result,
        'wrong returned parameter values' );

    $req->Delete(qw(q2 q3 null));
    @result = $req->param();
    $this->assert_deep_equals( [qw(p file)], \@result,
        'wrong returned parameter values' );

    $req->delete('file');
    @result = $req->param();
    $this->assert_deep_equals( [qw(p)], \@result,
        'wrong returned parameter values' );
    $this->assert( !-e $tmp->filename,
        'Uploaded file not deleted after call to delete()' );
}

sub test_delete_all {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->param( -name => 'q2', -values => [qw(v1 v2)] );
    $req->param( -name => 'q1', -value  => 'v1' );
    $req->param( 'p', qw(qv1 qv2 qv3) );
    $req->param( -name => 'q3', -value  => 'v3' );
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
    
    my @result = $req->param();
    $this->assert_deep_equals( [qw(q2 q1 p q3 file)], \@result,
        'wrong returned parameter values' );
    
    $req->deleteAll();
    @result = $req->param();
    $this->assert_num_equals(0, scalar @result, "deleteAll didn't work");
    
    $req->param( -name => 'q2', -values => [qw(v1 v2)] );
    $req->param( -name => 'q1', -value  => 'v1' );
    $req->param( 'p', qw(qv1 qv2 qv3) );
    $req->param( -name => 'q3', -value  => 'v3' );
    $tmp = File::Temp->new( UNLINK => 0 );
    $req->param( file => "Temp.txt" );
    $uploads{"Temp.txt"} = new Foswiki::Request::Upload(
        headers => {%headers},
        tmpname => $tmp->filename,
    );
    $req->uploads( \%uploads );
    
    $req->delete_all();
    @result = $req->param();
    $this->assert_num_equals(0, scalar @result, "deleteAll didn't work");
}

sub test_header {
    my $this = shift;
    my $req  = new Foswiki::Request("");
    
    $req->header( 'h-1' => 'v1' );
    my @result = $req->header('H-1');
    $this->assert_deep_equals(['v1'], \@result, 'wrong value from header()');
    
    $req->header( 'h2' => [qw(v1 v2)] );
    
    @result = $req->header('h2');
    $this->assert_deep_equals([qw(v1 v2)], \@result, 'wrong value from header()');
    
    $req->header('h', qw(v1 v2 v3));
    @result =  $req->header('h');
    $this->assert_deep_equals([qw(v1 v2 v3)], \@result, 'wrong value from header()');
    
    @result = sort $req->header();
    $this->assert_deep_equals([qw(h h-1 h2)], \@result, 'wrong header field names from header()');
    
    @result = (scalar $req->header('h2'));
    $this->assert_deep_equals(['v1'], \@result, 'wrong header field values from header()');

    @result = (scalar $req->header('nonexistent'));
    $this->assert_deep_equals([undef], \@result, 'wrong header field values from header()');
    
    @result = $req->header('nonexistent');
    $this->assert_deep_equals([], \@result, 'wrong header field values from header()');
}

sub test_save {
    my $this = shift;
    my $req = new Foswiki::Request("");
    $req->param(-name => 'simple', -value => 's1');
    $req->param(-name => 'simple2', -value => 's2');
    $req->param(-name => 'multi', -value => [qw(m1 m2)]);
    $req->param(-name => 'undef', -value => [undef]);
    require File::Temp;
    my $tmp = File::Temp->new(UNLINK => 1);
    $req->save($tmp);
    seek($tmp, 0, 0);
    $this->assert_str_equals(<<EOF
simple=s1
simple2=s2
multi=m1
multi=m2
undef=
=
EOF
, join('', <$tmp>), 'Wrong generated file');
}

sub test_load {
    my $this = shift;
    require File::Temp;
    my $tmp = File::Temp->new(UNLINK => 1);
    print($tmp <<EOF
simple=s1
simple2=s2
multi=m1
multi=m2
undef=
=
EOF
);
    seek($tmp, 0, 0);
    my $req = new Foswiki::Request("");
    $req->load($tmp);
    $this->assert_str_equals(4, scalar $req->param(), 'Wrong number of parameters');
    $this->assert_str_equals('s1', $req->param('simple'), 'Wrong parameter value');
    $this->assert_str_equals('s2', $req->param('simple2'), 'Wrong parameter value');
    my @values = $req->param('multi');
    $this->assert_str_equals(2, scalar @values, 'Wrong number o values');
    $this->assert_str_equals('m1', $values[0], 'Wrong parameter value');
    $this->assert_str_equals('m2', $values[1], 'Wrong parameter value');
    $this->assert_null($req->param('undef'), 'Wrong parameter value');
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
    seek($tmp, 0, 0);
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
    my $text = join('', <$fh>);
    $this->assert_str_equals("Arbitrary file...\n", $text, 'Wrong file contents');
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
