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

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute status

HTTP response status code. By default is taken from =response= object.

=cut

has status => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareStatus',
);

=begin TML

---+++ ObjectAttribute response

A %PERLDOC{"Foswiki::Response"}% object. If =$Foswiki::app= is defined then
is taken from its =response= attribute. Otherwise a new one is generated.

=cut

has response => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareResponse',
);

=begin TML

---+++ObjectAttribute text

Overrides the base class attribute, makes it read-only.

=cut

has '+text' => (
    is   => 'ro',
    lazy => 1,
);

=begin TML

---++ METHODS

=cut

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

=begin TML

---+++ ObjectMethod prepareText

Overrides base class method.

=cut

around prepareText => sub {
    my $orig = shift;
    my $this = shift;

    return 'HTTP status code "' . $_[0]->status;
};

=begin TML

---+++ ObjectMethod prepareStatus

Initializer for =status= attribute.

=cut

sub prepareStatus {
    return $_[0]->response->status;
}

=begin TML

---+++ ObjectMethod prepareResponse

Initializer for =response= attribute.

=cut

sub prepareResponse {
    return defined($Foswiki::app)
      ? $Foswiki::app->response
      : Foswiki::Response->new;
}

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
