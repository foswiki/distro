# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::EngineException

Exception used to raise an engine related error. This exception has the
following fields:
   * =status= - status code to send to client
   * =reason= a text string giving the reason for the refusal.

=cut

package Foswiki::EngineException;
use v5.14;

use Moo;
extends qw(Foswiki::Exception);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---+ ClassMethod new( status => $status, reason => $reason [, response => $response] )

   * =$status= - status code to send to client
   * =$reason= - string reason for failure
   * =$response= - custom Foswiki::Response object to be sent to client. Optional.

All the above fields are accessible from the object in a catch clause
in the usual way e.g. =$e->{status}= and =$e->{reason}=

=cut

has status => ( is => 'rw', required => 1, );
has reason => ( is => 'rw', required => 1, );
has response => ( is => 'rw', );

=begin TML

---++ ObjectMethod stringify() -> $string

Generate a summary string. This is mainly for debugging.

=cut

around stringify => sub {
    my $orig = shift;
    my $this = shift;
    my ( $status, $reason ) = ( $this->status, $this->reason );
    $this->_set_text(
        qq(EngineException: Status code "$status" defined because of "$reason".)
    );
    return $orig->( $this, @_ );
};

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
