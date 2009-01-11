package Foswiki::Engine::Apache::MP13;

use strict;
use base 'Foswiki::Engine::Apache';

use Apache            ();
use Apache::Constants ();

BEGIN {
    eval qq{require Apache::Request};
    *queryClass = $@ ? sub { 'CGI' } : sub { 'Apache::Request' };
}

sub finalizeHeaders {
    my ( $this, @p ) = @_;
    $this->SUPER::finalizeHeaders(@p);
    $this->{r}->send_http_header();
}

sub OK { Apache::Constants::OK }

1;
