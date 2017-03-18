# Tests for Foswiki::Net
package NetTests;
use Unit::TestCase;
our @ISA = qw( Unit::TestCase );

use strict;

use Foswiki::Net;

sub new {
    my $self = shift()->SUPER::new( "Net", @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{net} = new Foswiki::Net();
}

sub test_getExternalResource {
    my $this = shift;

    # need a known, simple, robust URL to get
    my $response =
      $this->{net}
      ->getExternalResource('https://foswiki.org/System/FAQWhatIsWikiWiki');
    $this->assert_equals( 200, $response->code() );

    # Note: HTTP::Response doesn't clean out \r correctly
    my $mess           = $response->message();
    my $expectedHeader = qr#text/html; charset=(utf-?8|iso-?8859-?1)#;
    $mess =~ s/\r//g;
    $this->assert_str_equals( 'OK', $mess );
    $this->assert_matches( qr/$expectedHeader/is,
        ~~ $response->header('content-type') );    # ~~ forces scalar context
    $this->assert_matches(
qr/A set of pages of information that are open and free for anyone to edit as they wish. They are stored in a server and managed using some software. The system creates cross-reference hyperlinks between pages automatically./s,
        $response->content()
    );
    $this->assert( !$response->is_error() );
    $this->assert( !$response->is_redirect() );
}

sub test_sendMail {

    # SMELL: needs to be written!
}

1;

