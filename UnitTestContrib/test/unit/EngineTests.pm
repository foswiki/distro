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
    eval 'use HTTP::Message; use HTTP::Headers; 1;';
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

sub test_simple {
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

sub test_path_info {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->method('GET');
    $req->uri('/bin/test');
    $req->remote_addr('127.0.0.1');
    $req->server_port('80');
    for my $p ('', qw(/Path/Info /Path /Info /<&;>/foo /foo/bar/baz)) {
        $req->path_info($p);
        my $response = $this->make_request($req);
        my $result = thaw( $response->content )->{request};
        $this->assert_str_equals( $p, $result->path_info, 'Wrong path_info' );
    }
}

sub test_header {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    $req->method('GET');
    $req->uri('/bin/test');
    $req->remote_addr('127.0.0.1');
    $req->server_port('80');
    my @referer = ( 'http://foo.bar/', 'http://foswiki.org' );
    my @agent = (
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
            my $result = thaw( $response->content )->{request};
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
}

sub test_get_param_simple {
}

sub test_get_param_multi {
}

sub test_head_param_simple {
}

sub test_head_param_multi {
}

sub test_post_param_simple {
}

sub test_post_param_multi {
}

sub test_post_file {
}

#sub test_simple {
#    my $this = shift;
#    my $req  = new Foswiki::Request("");
#    $req->method('POST');
#    $req->uri('/bin/test');
#    $req->param( -name => 'foo', -value => [ 'bar', 'baz' ] );
#    $req->param( -name => 'up',  -value => 'file.dat' );
#    $req->param( -name => 'bli', -value => '' );
#    $req->path_info('/Path/info');
#    $req->header( -name => 'X-FoswikiAction', -value => 'test' );
#    $req->header(
#        -name => 'Accept',
#        -value =>
#          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
#    );
#    $req->header( 'User-Agent' => 'EngineTests' );
#    $req->remote_addr('192.168.254.1');
#    $req->remote_user('admin');
#    my %uploads;
#    my $file = new File::Temp(
#        DIR => Cwd::abs_path(
#            File::Spec->catdir( $Foswiki::cfg{WorkingDir}, 'tmp' )
#        ),
#    );
#    print $file "Conteúdo\nbinário\nqualquer...";
#    $file->flush;
#    $uploads{'file.dat'} = new Foswiki::Request::Upload(
#        headers => { 'Content-Type' => 'application/octet-stream' },
#        tmpname => $file->filename,
#    );
#    $req->uploads( \%uploads );
#
#    my %cookies;
#    require CGI::Cookie;
#    $cookies{C1} = new CGI::Cookie( -name => 'C1', -value => 'Teste%&;C1' );
#    $cookies{'&*;'} = new CGI::Cookie( -name => '&*;', -value => "bli\nbar" );
#    $req->cookies( \%cookies );
#    my $response = $this->make_request($req);
#    my $result = eval { thaw( ${ $response->decoded_content( ref => 1 ) } ) };
#
#   #$this->assert(!$@, "Error on thaw: $@");
#   #$this->assert_equals( $req->method, $result->method,    'Wrong METHOD' );
#   #$this->assert_equals( '',           $result->path_info, 'Wrong PATH_INFO' );
#   #$this->assert_deep_equals( [], [ $result->param ], 'Wrong parameter list' );
#   #$this->assert_equals( 'test', $result->action, 'Wrong action' );
#}
#
#sub test_simple_response {
#    my $this = shift;
#    my $req  = new Foswiki::Request;
#    my $res  = new Foswiki::Response;
#    $res->pushHeader( 'X-BLI' => 'teste' );
#    $req->method('POST');
#    $req->param( 'desired_test_response' => freeze($res) );
#    my $response = $this->make_request($req);
#}

1;
