package ResponseTests;
use strict;
use warnings;

use Unit::TestCase;
our @ISA = qw( Unit::TestCase );
use Assert;

use Foswiki::Response;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $this->{_saved}->{AllowRedirectUrl} = $Foswiki::cfg{AllowRedirectUrl};
    $this->{_saved}->{DefaultUrlHost}   = $Foswiki::cfg{DefaultUrlHost};
    $this->{_saved}->{PermittedRedirectHostUrls} =
      $Foswiki::cfg{PermittedRedirectHostUrls};

    $Foswiki::cfg{AllowRedirectUrl}          = 0;
    $Foswiki::cfg{DefaultUrlHost}            = 'http://wiki.server';
    $Foswiki::cfg{PermittedRedirectHostUrls} = 'http://other.wiki';

    return;
}

sub tear_down {
    my $this = shift;

    $Foswiki::cfg{AllowRedirectUrl} = $this->{_saved}->{AllowRedirectUrl};
    $Foswiki::cfg{DefaultUrlHost}   = $this->{_saved}->{DefaultUrlHost};
    $Foswiki::cfg{PermittedRedirectHostUrls} =
      $this->{_saved}->{PermittedRedirectHostUrls};

    $this->SUPER::tear_down();

    return;
}

sub test_empty_new {
    my ($this) = @_;
    my $res = Foswiki::Response->new();

    $this->assert_null( $res->status, 'Non-empty initial status' ) if not DEBUG;
    $this->assert_null( $res->body, 'Non-empty initial body' );
    $this->assert_matches( $Foswiki::cfg{Site}{CharSet} || 'iso-8859-1',
        $res->charset,
        'Bad default initial charset: ' . ( $res->charset || 'undef' ) );

    my @cookies = $res->cookies();
    $this->assert_str_equals( 0, scalar @cookies, '$res->cookies not empty' );

    my $ref = $res->headers;
    $this->assert_str_equals( 'HASH', ref($ref),
        '$res->headers did not return HASHREF' );
    $this->assert_num_equals(
        0,
        ( scalar keys %{$ref} ),
        'Non-empty initial headers'
    );

    return;
}

sub test_status {
    my ($this) = @_;
    my $res = Foswiki::Response->new();

    my @status = ( 200, 302, 401, 402, '404 not found', 500 );
    foreach (@status) {
        $res->status($_);
        $this->assert_str_equals( $_, $res->status,
            'Wrong return value from status()' );
    }
    $res->status('ivalid status');
    $this->assert_null( $res->status,
        'It was possible to set an invalid status' );

    return;
}

sub test_charset {
    my ($this) = @_;
    my $res = Foswiki::Response->new();

    foreach (qw(utf8 iso-8859-1 iso-8859-15 utf16)) {
        $res->charset($_);
        $this->assert_str_equals( $_, $res->charset, 'Wrong charset value' );
    }

    return;
}

sub test_headers {
    my ($this) = @_;
    my $res = Foswiki::Response->new();

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
        [ sort qw(Content-Type Status Connection F-O-O-Bar Set-Cookie Date) ],
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

    $res->deleteHeader(qw(coNNection content-TYPE set-cookie f-o-o-bar date));
    $this->assert_deep_equals(
        [qw(Pragma Status)],
        [ sort $res->getHeader ],
        'Wrong header fields'
    );
    return;
}

sub test_cookie {
    my ($this) = @_;
    my $res = Foswiki::Response->new('');
    require CGI::Cookie;
    my $c1 = CGI::Cookie->new(
        -name   => 'FOSWIKISID',
        -value  => '80eaee753351a6d4d050320ce4d60822',
        -domain => 'localhost'
    );
    my $c2 = CGI::Cookie->new( -name => 'Foo', -value => 'Bar' );
    $res->cookies( [ $c1, $c2 ] );
    $this->assert_deep_equals(
        [ $c1, $c2 ],
        [ $res->cookies ],
        'Wrong returned cookies'
    );
    return;
}

sub test_body {
    my ($this) = @_;
    my $res    = Foswiki::Response->new('');
    my $length = int( rand( 2**20 ) );
    my $body;
    for ( my $i = 0 ; $i < $length ; $i++ ) {
        $body .= chr( int( rand(256) ) );
    }
    $res->print($body);
    $this->assert_str_equals( $body, $res->body, 'Wrong returned body' );
    $this->assert_num_equals(
        $length,
        $res->getHeader('Content-Length'),
        'Wrong Content-Length header'
    );
    return;
}

sub test_redirect {
    my ($this) = @_;

    my $res = Foswiki::Response->new('');
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

    $res    = Foswiki::Response->new('');
    $uri    = 'http://bar.foo.baz/path/to/script/path/info';
    $status = '301 Moved Permanently';
    require CGI::Cookie;
    my $cookie = CGI::Cookie->new(
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
    $this->assert_deep_equals( [$cookie], [ $res->cookies ], 'Wrong cookie!' );
    return;
}

sub test_header {
    my ($this) = @_;
    my $res = Foswiki::Response->new('');

    require CGI::Cookie;
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
    $this->assert_str_equals( '200 OK', $res->getHeader('Status'),
        'Wrong status' );
    $this->assert_str_equals(
        'close',
        $res->getHeader('Connection'),
        'Wrong custom header value'
    );
    $this->assert_not_null( $res->getHeader('expires'),
        'Expires header not defined' );
    $this->assert_not_null( $res->getHeader('date'),
        'Date header not defined' );
    $this->assert_str_equals( 'utf8', $res->charset,
        'charset object field not defined' );
    $this->assert_deep_equals(
        [$cookie],
        [ $res->cookies ],
        'Cookie not defined'
    );
    return;
}

sub test_isRedirectSafe {
    my ($this) = @_;

    $this->assert( not Foswiki::_isRedirectSafe('http://slashdot.org') );
    $this->assert( Foswiki::_isRedirectSafe('/relative') );

    #$Foswiki::cfg{DefaultUrlHost} based
    my $baseUrlMissingSlash = $Foswiki::cfg{DefaultUrlHost};

    #http://wiki.server.com (missing trailing slash)
    $baseUrlMissingSlash =~ s/(.*)\/$/$1/;
    my $url = $baseUrlMissingSlash;
    $this->assert( Foswiki::_isRedirectSafe($url) );
    $url = $baseUrlMissingSlash . '?somestuff=12';
    $this->assert( Foswiki::_isRedirectSafe($url) );
    $url = $baseUrlMissingSlash . '#header';
    $this->assert( Foswiki::_isRedirectSafe($url) );

    $Foswiki::cfg{DefaultUrlHost} = 'http://wiki.server';
    $Foswiki::cfg{PermittedRedirectHostUrls} =
      'http://wiki.other,http://other.wiki';

    $this->assert( Foswiki::_isRedirectSafe('/wiki.server') );
    $this->assert( Foswiki::_isRedirectSafe('http://wiki.server') );
    $this->assert( Foswiki::_isRedirectSafe('http://wiki.server/') );
    $this->assert( Foswiki::_isRedirectSafe('http://other.wiki') );
    $this->assert( Foswiki::_isRedirectSafe('http://other.wiki/') );
    $this->assert( Foswiki::_isRedirectSafe('http://wiki.other') );
    $this->assert( Foswiki::_isRedirectSafe('http://wiki.other/') );
    $this->assert( not Foswiki::_isRedirectSafe('http://slashdot.org') );
    $this->assert( not Foswiki::_isRedirectSafe('http://slashdot.org/') );

    return;
}

1;
