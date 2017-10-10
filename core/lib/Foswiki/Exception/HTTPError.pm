# See bottom of file for license and copyright information

=begin TML

---+!! Class Foswiki::Exception::HTTPError

Exception for reporting HTTP errors. It is not considered
%PERLDOC{"Foswiki::Exception::Deadly" text="fatal"}% because it doesn't report
a code failure but only used to inform a user.

=cut

package Foswiki::Exception::HTTPError;

use CGI ();
use Assert;

use Foswiki::Class;
extends qw<Foswiki::Exception::HTTPResponse>;

has header => ( is => 'rw', default => '' );

around stringify => sub {
    my $orig = shift;
    my $this = shift;

    my $res = $this->response;
    $res->body('');
    if ( $this->_useHTTP ) {
        $res->header( -type => 'text/html', -status => $this->status );
        my $html = CGI::start_html( $this->status . ' ' . $this->header );
        $html .= CGI::h1( {}, $this->header );
        $html .= CGI::p( {}, $this->text );
        $html .= CGI::p( {}, CGI::pre( $this->stacktrace ) ) if DEBUG;
        $html .= CGI::end_html();
        $res->print($html);
    }
    else {
        $res->print( $this->status . " "
              . $this->header . "\n\n"
              . $this->text
              . $this->stringifyPostfix );
    }

    return $orig->($this);
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
