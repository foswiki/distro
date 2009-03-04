package EngineTests;

use strict;
use warnings;
our @ISA;

BEGIN {
    if ( $ENV{FOSWIKI_SERVER} && length( $ENV{FOSWIKI_SERVER} ) > 0 ) {
        require Unit::ExternalEngine;
        @ISA = qw(Unit::ExternalEngine);
    }
    else {
        require Unit::CGIEngine;
        @ISA = qw(Unit::CGIEngine);
    }
}

use Foswiki;
use Foswiki::Request;
use Foswiki::Request::Upload;
use Foswiki::Response;

use File::Spec;
use File::Temp;
use Cwd;
use Storable qw(freeze thaw);

sub list_tests {
    my $this = shift;
    eval 'use HTTP::Message; use HTTP::Headers; use HTTP::Request; 1;';
    if ($@) {
        print STDERR 'Install libwww-perl in order to run EngineTests', "\n";
        return ();
    }
    return $this->SUPER::list_tests(@_);
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $Foswiki::cfg{ScriptUrlPath} = '/bin';
    delete $Foswiki::cfg{ScriptUrlPaths};
}

sub test_simple_request {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->method('GET');
    $req->uri('/bin/test');
    $req->remote_addr('10.0.0.1');
    $req->server_port('8080');
    $req->path_info('/path/info');
    $req->header( 'X-Header1' => 'v1' );
    $req->header( 'X-Header2' => 'v2' );
    my $response = $this->make_request($req);
    my $result   = thaw( $response->content )->{request};

    $this->assert_str_equals( 'GET', $result->method, 'Wrong Method' );
    $this->assert( length( $result->remote_addr ) > 0, 'remote_addr not set' );
    $this->assert( length( $result->server_port ) > 0, 'server_port not set' );
    $this->assert_str_equals( '/path/info', $result->path_info,
        'Wrong path_info' );
    $this->assert_str_equals(
        'v1',
        $result->header('X-Header1'),
        'Wrong header value'
    );
    $this->assert_str_equals(
        'v2',
        $result->header('X-Header2'),
        'Wrong header value'
    );
}

sub _newBasicRequest {
    my ($method) = @_;

    my $req = new Foswiki::Request("");
    $req->method( $method || 'GET' );
    $req->uri('/bin/test');
    $req->remote_addr('127.0.0.1');
    $req->server_port('80');
    return $req;
}

sub test_path_info {
    my $this = shift;

    my $req = _newBasicRequest();
    for my $p ( '', qw(/Path/Info /Path /Info /<&;>/foo /foo/bar/baz) ) {
        $req->path_info($p);
        my $response = $this->make_request($req);
        my $result   = thaw( $response->content )->{request};
        $this->assert_str_equals( $p, $result->path_info, 'Wrong path_info' );
    }
}

sub test_header {
    my $this = shift;

    my $req     = _newBasicRequest();
    my @referer = ( 'http://foo.bar/', 'http://foswiki.org' );
    my @agent   = (
        'UA-1', 'Mozilla',
        'AnyBot (compatible; X11)',
        '!@#$%&*()-_=+§ªº°/?;:.,<>\|¹²³£¢¬{[]}'
    );
    my %custom = (
        'X-H1'      => 'first header value.',
        'X-Abc-Def' => 'second+value;/-_+=',
    );
    $req->header( $_ => $custom{$_} ) foreach keys %custom;

    foreach my $r (@referer) {
        $req->header( Referer => $r );
        foreach my $a (@agent) {
            $req->header( 'User-Agent' => $a );
            my $response = $this->make_request($req);
            my $result   = thaw( $response->content )->{request};
            $this->assert_str_equals(
                $r,
                $result->header('Referer'),
                'Wrong Referer header'
            );
            $this->assert_str_equals(
                $a,
                $result->header('User-Agent'),
                'Wrong User-Agent header'
            );
            while ( my ( $key, $value ) = each %custom ) {
                $this->assert_str_equals( $value, $result->header($key),
                    "Wrong $key header" );
            }
        }
    }
}

sub test_cookie {
    my $this = shift;

    my $req = _newBasicRequest();
    require CGI::Cookie;
    my %jar = ();
    $jar{SID} = new CGI::Cookie(
        -name  => 'SID',
        -value => 'asdfsaf982311kkljh2134',
    );
    $jar{'<SID>'} = new CGI::Cookie(
        -name  => '<SID>',
        -value => '<>.,;:?/°^~ºª§=+-_)\'(*&%$#@!¹²³£¢¬',
    );

    $req->cookies( { SID => $jar{SID} } );
    my $response = $this->make_request($req);
    my $result   = thaw( $response->content )->{request};
    $this->assert_deep_equals(
        { SID => $jar{SID} },
        $result->cookies,
        'Wrong Cookies'
    );

    $req->cookies( { '<SID>' => $jar{'<SID>'} } );
    $response = $this->make_request($req);
    $result   = thaw( $response->content )->{request};
    $this->assert_deep_equals( { '<SID>' => $jar{'<SID>'} },
        $result->cookies, 'Wrong Cookies' );

    $req->cookies( \%jar );
    $response = $this->make_request($req);
    $result   = thaw( $response->content )->{request};
    $this->assert_deep_equals( \%jar, $result->cookies, 'Wrong Cookies' );
}

sub _fillSimpleParam {
    my $req = shift;
    $req->deleteAll();
    $req->param( -name => 'p1', -value => '0' );
    $req->param( -name => 'p2', -value => 'v2' );
    $req->param( -name => 'p+', -value => 'a.#<>;' );
    $req->param( -name => '0',  -value => '' );
    return $req;
}

sub _fillMultiParam {
    my $req = shift;
    $req->deleteAll();
    $req->param( -name => 'p1', -value => [ 0, 0, 7 ] );
    $req->param( -name => 'p2', -value => [ '0',      'v21' ] );
    $req->param( -name => 'p+', -value => [ 'a.#<>;', "'<html>'" ] );
    $req->param( -name => '0',  -value => [ '',       '' ] );
    return $req;
}

sub checkParam {
    my ( $this, $req, $result ) = @_;
    $this->assert_str_equals( $req->method, $result->method,
        'Wrong request method' );
    $this->assert_deep_equals(
        [ $req->param ],
        [ $result->param ],
        'Wrong parameter names'
    );
    foreach my $p ( $req->param ) {
        $this->assert_deep_equals(
            [ $req->param($p) ],
            [ $result->param($p) ],
            'Wrong parameter value'
        );
    }
}

sub test_get_param_simple {
    my $this = shift;

    my $req = _newBasicRequest();
    _fillSimpleParam($req);
    my $response = $this->make_request($req);
    my $result   = thaw( $response->content )->{request};
    $this->checkParam( $req, $result );
}

sub test_get_param_multi {
    my $this = shift;

    my $req = _newBasicRequest();
    _fillMultiParam($req);
    my $response = $this->make_request($req);
    my $result   = thaw( $response->content )->{request};
    $this->checkParam( $req, $result );
}

sub test_head_param_simple {
    my $this = shift;

    my $req = _newBasicRequest('HEAD');
    _fillSimpleParam($req);
    my $response = $this->make_request($req);
    my $result   = thaw( Foswiki::urlDecode( $response->header('X-Result') ) );
    $this->checkParam( $req, $result );
    $this->assert_str_equals( '', $response->content, 'HEAD not respected' );
}

sub test_head_param_multi {
    my $this = shift;

    my $req = _newBasicRequest('HEAD');
    _fillMultiParam($req);
    my $response = $this->make_request($req);
    my $result   = thaw( Foswiki::urlDecode( $response->header('X-Result') ) );
    $this->checkParam( $req, $result );
    $this->assert_str_equals( '', $response->content, 'HEAD not respected' );
}

sub test_post_param_simple {
    my $this = shift;

    my $req = _newBasicRequest('POST');
    _fillSimpleParam($req);
    my $response = $this->make_request($req);
    my $result   = thaw( $response->content )->{request};
    $this->checkParam( $req, $result );
}

sub test_post_param_multi {
    my $this = shift;

    my $req = _newBasicRequest('POST');
    _fillMultiParam($req);
    my $response = $this->make_request($req);
    my $result   = thaw( $response->content )->{request};
    $this->checkParam( $req, $result );
}

#sub test_post_file {
#    my $this = shift;
#
#    my $req = _newBasicRequest('POST');
#    $req->header( 'User-Agent' => 'EngineTests' );
#    my $tmp1 = File::Temp->new(
#        UNLINK => 1,
#        DIR    => Cwd::abs_path(
#            File::Spec->catdir( $Foswiki::cfg{WorkingDir}, 'tmp' )
#        ),
#    );
#    my $content1 = '';
#    $content1 .= chr($_) foreach 0 .. 127;
#    print $tmp1 $content1;
#    $tmp1->flush;
#    seek( $tmp1, 0, 0 );
#    my ( %uploads, %headers ) = ();
#    %headers = (
#        'Content-Type'        => 'application/octet-stream',
#        'Content-Disposition' => 'form-data; name="file"; filename="Temp.dat"',
#    );
#    $req->param( file => "Temp.dat" );
#    $uploads{"Temp.dat"} = new Foswiki::Request::Upload(
#        headers => {%headers},
#        tmpname => $tmp1->filename,
#    );
#    $req->uploads( \%uploads );
#    my $response = $this->make_request($req);
#    my $result   = thaw( $response->content );
#    my $res      = $result->{request};
#    $this->assert_deep_equals(
#        [ $req->param ],
#        [ $res->param ],
#        'Wrong parameter list'
#    );
#    $this->assert_deep_equals(
#        \%headers,
#        $uploads{'Temp.dat'}->{headers},
#        'Wrong update info'
#    );
#    $this->assert_str_equals( $content1, $result->{'Temp.dat'},
#        'Wrong file contents' );
#
#    my $tmp2 = File::Temp->new(
#        UNLINK => 1,
#        DIR    => Cwd::abs_path(
#            File::Spec->catdir( $Foswiki::cfg{WorkingDir}, 'tmp' )
#        ),
#    );
#    my $content2 = '';
#    $content2 .= chr( 127 - $_ ) foreach 0 .. 127;
#    print $tmp2 $content2;
#    $tmp2->flush;
#    seek( $tmp2, 0, 0 );
#    %headers = (
#        'Content-Type' => 'application/octet-stream',
#        'Content-Disposition' =>
#          'form-data; name="file2"; filename="Temp2.dat"',
#    );
#    $req->param( file2 => "Temp2.dat" );
#    $uploads{"Temp2.dat"} = new Foswiki::Request::Upload(
#        headers => {%headers},
#        tmpname => $tmp2->filename,
#    );
#    $req->uploads( \%uploads );
#    $response = $this->make_request($req);
#    $result   = thaw( $response->content );
#    $res      = $result->{request};
#    $this->assert_deep_equals(
#        [ $req->param ],
#        [ $res->param ],
#        'Wrong parameter list'
#    );
#    $this->assert_deep_equals(
#        \%headers,
#        $uploads{'Temp2.dat'}->{headers},
#        'Wrong update info'
#    );
#    $this->assert_str_equals( $content1, $result->{'Temp.dat'},
#        'Wrong file contents' );
#    $this->assert_str_equals(
#        $content2,
#        $result->{'Temp2.dat'},
#        'Wrong file contents'
#    );
#}

sub test_alien_get {
    my $this = shift;

    my $uri = '';
    if ( $ENV{FOSWIKI_SERVER} ) {
        $uri = $ENV{FOSWIKI_PORT}
          && $ENV{FOSWIKI_PORT} == 443 ? 'https://' : 'http://';
        $uri .= $ENV{FOSWIKI_SERVER};
        $uri .= ':' . $ENV{FOSWIKI_PORT}
          if $ENV{FOSWIKI_PORT} && $ENV{FOSWIKI_PORT} !~ /^(?:80|443)$/;
        $uri .= $ENV{FOSWIKI_PATH} || '/bin';
    }
    else {
        $uri = '/bin';
    }
    my $req      = new HTTP::Request( 'GET', $uri . '/test?a' );
    my $response = $this->make_bare_request($req);
    my $result   = thaw( $response->content )->{request};
    $this->assert_deep_equals(
        ['a'],
        [ $result->param() ],
        'Wrong parameter list'
    );

    $req      = new HTTP::Request( 'GET', $uri . '/test?a&b' );
    $response = $this->make_bare_request($req);
    $result   = thaw( $response->content )->{request};
    $this->assert_deep_equals(
        [qw(a b)],
        [ $result->param() ],
        'Wrong parameter list'
    );

    $req      = new HTTP::Request( 'GET', $uri . '/test?a&b;=' );
    $response = $this->make_bare_request($req);
    $result   = thaw( $response->content )->{request};
    $this->assert_deep_equals(
        [ qw(a b), '' ],
        [ $result->param() ],
        'Wrong parameter list'
    );
}

sub test_simple_response {
    my $this = shift;
    my $res  = new Foswiki::Response;
    $res->pushHeader( 'X-BLI' => 'teste' );
    
    my $req  = new Foswiki::Request;
    $req->method('POST');
    $req->param( 'desired_test_response' => freeze($res) );
    my $response = $this->make_request($req);
    $this->assert_deep_equals(['teste'], [$response->header('X-Bli')], 'Wrong header value');
}

1;
