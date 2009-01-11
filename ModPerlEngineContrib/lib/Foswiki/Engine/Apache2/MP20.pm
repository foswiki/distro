package Foswiki::Engine::Apache2::MP20;

use strict;
use base 'Foswiki::Engine::Apache2';

use Apache2::Connection ();
use Apache2::Const -compile => qw(OK);
use Apache2::RequestIO   ();
use Apache2::RequestRec  ();
use Apache2::RequestUtil ();
use Apache2::Response    ();
use Apache2::URI         ();
use APR::Table           ();

BEGIN {
    eval qq{require Apache2::Request; require Apache2::Upload;};
    *queryClass = $@ ? sub { 'CGI' } : sub { 'Apache2::Request' };
}

sub OK { Apache2::Const::OK }

1;
