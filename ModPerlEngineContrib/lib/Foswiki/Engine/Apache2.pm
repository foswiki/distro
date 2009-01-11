package Foswiki::Engine::Apache2;

use strict;
use base 'Foswiki::Engine::Apache';

sub finalizeHeaders {
    my ( $this, @p ) = @_;

    $this->SUPER::finalizeHeaders( @p );

    # This handles the case where Apache2 will remove the Content-Length
    # header on a HEAD request.
    # http://perl.apache.org/docs/2.0/user/handlers/http.html
    if ( $this->{r}->header_only ) {
        $this->{r}->rflush;
    }
}

1;
