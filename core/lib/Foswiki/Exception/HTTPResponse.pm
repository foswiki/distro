# See bottom of file for license and copyright information

=begin TML

---+!! Class Foswiki::Exception::HTTPResponse

Used to send HTTP status responses to the user.

The exception is %PERLDOC{"Foswiki::Exception::Harmless" text="harmless"}%.

Attributes:

   $ =status= : HTTP status code, integer; response status code used if omitted.
   $ =response= : a Foswiki::Response object. If not supplied then the default
   from =$Foswiki::app->response= is used.
   $ =text= : read-only, generated using the exception attributes.

=cut

package Foswiki::Exception::HTTPResponse;
use Foswiki::Class;
extends qw<Foswiki::Exception>;
with qw<Foswiki::Exception::Harmless>;

has status =>
  ( is => 'ro', lazy => 1, default => sub { $_[0]->response->status, }, );
has response => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return defined($Foswiki::app)
          ? $Foswiki::app->response
          : Foswiki::Response->new;
    },
);

# SMELL To be replaced by prepareText() overriding.
has '+text' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return 'HTTP status code "' . $_[0]->status;
    },
);

sub _useHTTP {
    my $this = shift;
    return
         defined($Foswiki::app)
      && defined( $Foswiki::app->engine )
      && $Foswiki::app->engine->HTTPCompliant;
}

# Simplified version of stringify() method.
around stringify => sub {
    my $orig = shift;
    my $this = shift;

    my $str = '';
    if ( $this->_useHTTP ) {
        $str .= $this->response->printHeaders;
    }

    $str .= $this->response->body;

    return $str;
};

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2017 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
