# Tests for Foswiki::Net
package NetTests;
use base 'Unit::TestCase';

use strict;

use Foswiki::Net;

our $expectedHeader;

sub new {
    my $self = shift()->SUPER::new( "Net", @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{net} = new Foswiki::Net();
}

sub LWP {
    $expectedHeader = qr#text/html; charset=(utf-?8|iso-?8859-?1)#;
    # Force re-eval
    undef $Foswiki::Net::LWPAvailable;
}

sub Sockets {
    $expectedHeader = qr#text/html#;
    $Foswiki::Net::LWPAvailable = 0;
}

sub HTTPResponse {
    $Foswiki::Net::noHTTPResponse = 0;
}

sub noHTTPResponse {
    $Foswiki::Net::noHTTPResponse = 1;
}

sub fixture_groups {
    return ( [ 'LWP', 'Sockets' ],
             [ 'HTTPResponse', 'noHTTPResponse' ] );
}

sub verify_getExternalResource {
    my $this = shift;

    # need a known, simple, robust URL to get
    my $response = $this->{net}->getExternalResource('http://foswiki.org');
    $this->assert_equals( 200, $response->code() );

    # Note: HTTP::Response doesn't clean out \r correctly
    my $mess = $response->message();
    $mess =~ s/\r//g;
    $this->assert_str_equals( 'OK', $mess );
    $this->assert_matches( qr/$expectedHeader/is,
        ~~ $response->header('content-type') ); # ~~ forces scalar context
    $this->assert_matches(
        qr/Foswiki is the open, programmable collaboration platform for the Enterprise/s,
        $response->content() );
    $this->assert( !$response->is_error() );
    $this->assert( !$response->is_redirect() );
}

sub test_sendMail {
    # SMELL: needs to be written!
}

1;

