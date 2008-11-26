package ResponseTests;

use base qw(Unit::TestCase);
use strict;
use warnings;

use Foswiki::Response;

sub test_empty_new {
    my $this = shift;
    my $res = new Foswiki::Response;

    $this->assert_null($res->status, 'Non-empty initial status');
    $this->assert_null($res->body,   'Non-empty initial body');
    $this->assert_matches('ISO-8859-1', $res->charset, 'Bad default initial charset');
    
    my @cookies = $res->cookies();
    $this->assert_str_equals(0, scalar @cookies, '$res->cookies not empty');

    my $ref = $res->headers;
    $this->assert_str_equals('HASH', ref($ref), '$res->headers did not return HASHREF');
    $this->assert_num_equals(0, (scalar keys %$ref), 'Non-empty initial headers');
}

sub test_status {
    my $this = shift;
    my $res = new Foswiki::Response;

    my @status = (200, 302, 401, 402, '404 not found', 500);
    foreach (@status) {
        $res->status($_);
        $this->assert_str_equals($_, $res->status, 'Wrong return value from status()');
    }
    $res->status('ivalid status');
    $this->assert_null($res->status, 'It was possible to set an invalid status');
}

sub test_charset {
    my $this = shift;
    my $res = new Foswiki::Response;

    foreach (qw(utf8 iso-8859-1 iso-8859-15 utf16)) {
        $res->charset($_);
        $this->assert_str_equals($_, $res->charset, 'Wrong charset value');
    }
}

sub test_headers {
    my $this = shift;
    my $res  = new Foswiki::Response;

    my %hdr = (
        'CoNtEnT-tYpE' => 'text/plain; charset=utf8',
        'sTATUS'       => '200 OK',
        'Connection'   => 'Close',
        'f-o-o-bar'    => 'baz',
        'Set-COOKIe'   => [
            'FOSWIKISID=4ed0fb8647881e17852dff882f0cfaa7; path=/',
            'SID=8f3d9cb028e4f7dabe435bcfc4905cda; path=/'
        ],
    );
    $res->headers( \%hdr );
    $this->assert_deep_equals(
        [ sort qw(Content-Type Status Connection F-O-O-Bar Set-Cookie) ],
        [ sort $res->getHeader() ],
        'Wrong header field names'
    );
    $this->assert_str_equals(
        'Close',
        $res->getHeader('connection'),
        'Wrong header value'
    );
    $this->assert_str_equals(
        'text/plain; charset=utf8',
        $res->getHeader('CONTENT-TYPE'),
        'Wrong header value'
    );
    $this->assert_str_equals(
        '200 OK',
        $res->getHeader('Status'),
        'Wrong header value'
    );
    $this->assert_str_equals(
        'baz',
        $res->getHeader('F-o-o-bAR'),
        'Wrong header value'
    );
    my @cookies = $res->getHeader('Set-Cookie');
    $this->assert_deep_equals(
        [
            'FOSWIKISID=4ed0fb8647881e17852dff882f0cfaa7; path=/',
            'SID=8f3d9cb028e4f7dabe435bcfc4905cda; path=/'
        ],
        \@cookies,
        'Wrong multivalued header value'
    );

    $res->pushHeader( 'f-o-o-bar' => 'baz2' );
    $this->assert_deep_equals(
        [qw(baz baz2)],
        [ $res->getHeader('F-O-o-bAR') ],
        'pushHeader did not work'
    );

    $res->pushHeader( 'f-o-o-bar' => 'baz3' );
    $this->assert_deep_equals(
        [qw(baz baz2 baz3)],
        [ $res->getHeader('F-o-o-bar') ],
        'pushHeader did not work'
    );

    $res->pushHeader( 'pragma' => 'no-cache' );
    $this->assert_str_equals(
        'no-cache',
        $res->getHeader('PRAGMA'),
        'pushHeader did not work'
    );

    $res->deleteHeader(qw(coNNection content-TYPE set-cookie f-o-o-bar));
    $this->assert_deep_equals(
        [qw(Pragma Status)],
        [ sort $res->getHeader ],
        'Wrong header fields'
    );
}

sub test_cookie {
    my $this = shift;
    my $res  = new Foswiki::Response('');
    require CGI::Cookie;
    my $c1 = new CGI::Cookie(
        -name   => 'FOSWIKISID',
        -value  => '80eaee753351a6d4d050320ce4d60822',
        -domain => 'localhost'
    );
    my $c2 = new CGI::Cookie( -name => 'Foo', -value => 'Bar' );
    $res->cookies([$c1, $c2]);
    $this->assert_deep_equals([$c1, $c2], [$res->cookies], 'Wrong returned cookies');
}

sub test_body {
    my $this   = shift;
    my $res    = new Foswiki::Response('');
    my $length = int( rand( 2**20 ) );
    my $body;
    for ( my $i = 0 ; $i < $length ; $i++ ) {
        $body .= chr( int( rand(256) ) );
    }
    $res->body($body);
    $this->assert_str_equals( $body, $res->body, 'Wrong returned body' );
    $this->assert_num_equals(
        $length,
        $res->getHeader('Content-Length'),
        'Wrong Content-Length header'
    );
}

sub test_redirect {
    my $this = shift;

    my $res = new Foswiki::Response('');
    my ( $uri, $status ) = ();
    $uri = 'http://foo.bar';
    $res->redirect($uri);
    $this->assert_str_equals(
        $uri,
        $res->getHeader('Location'),
        'Wrong Location header'
    );
    $this->assert_matches(
        '^3\d\d',
        $res->getHeader('Status'),
        'Wrong generated Status code'
    );

    $res    = new Foswiki::Response('');
    $uri    = 'http://bar.foo.baz/path/to/script/path/info';
    $status = '301 Moved Permanently';
    require CGI::Cookie;
    my $cookie = new CGI::Cookie(
        -name   => 'Cookie',
        -value  => 'tasty cookie',
        -domain => '.foo.baz'
    );
    $res->redirect( -status => $status, -Location => $uri, -Cookie => $cookie );
    $this->assert_str_equals(
        $uri,
        $res->getHeader('Location'),
        'Wrong Location header'
    );
    $this->assert_str_equals(
        $status,
        $res->getHeader('Status'),
        'Wrong returned Status header'
    );
    $this->assert_deep_equals(
        [$cookie],
        [ $res->cookies ],
        'Wrong cookie!'
    );
}

sub test_header {
    my $this = shift;
    my $res  = new Foswiki::Response('');

    my $cookie = CGI::Cookie->new(
        -name    => 'Foo',
        -value   => 'bar',
        -expires => '+1h'
    );
    $res->header(
        -type       => 'text/plain',
        -status     => '200 OK',
        -cookie     => $cookie,
        -expires    => '+2h',
        -Connection => 'close',
        -charset    => 'utf8',
    );
    $this->assert_str_equals(
        'text/plain; charset=utf8',
        $res->getHeader('Content-Type'),
        'Wrong content-type'
    );
    $this->assert_str_equals('200 OK', $res->getHeader('Status'), 'Wrong status');
    $this->assert_str_equals('close', $res->getHeader('Connection'), 'Wrong custom header value');
    $this->assert_not_null($res->getHeader('expires'), 'Expires header not defined');
    $this->assert_not_null($res->getHeader('date'), 'Date header not defined');
    $this->assert_str_equals('utf8', $res->charset, 'charset object field not defined');
    $this->assert_deep_equals([$cookie], [$res->cookies], 'Cookie not defined');
}


1;
