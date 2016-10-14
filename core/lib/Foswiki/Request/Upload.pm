# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Request::Upload

Class to encapsulate uploaded file info.

=cut

package Foswiki::Request::Upload;
use v5.14;

use Assert;

use IO::File ();

use Foswiki::Class;
extends qw(Foswiki::Object);

has headers     => ( is => 'ro', );
has filename    => ( is => 'ro', );
has size        => ( is => 'ro', );
has contentType => ( is => 'ro', );
has basename    => ( is => 'ro', );
has tmpname     => ( is => 'ro', );

=begin TML

---++ ClassMethod new( [ headers => \%headers, ] [ tmpname => $tmpname, ] )

Constructs a Foswiki::Request::Upload object

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub DEMOLISH {
    my $this = shift;

    #SMELL: Note: untaint filename. Taken from CGI.pm
    # (had to be updated for OSX in Dec2008)
    $this->tmpname =~ m{^([a-zA-Z0-9_\+ \'\":/.\$\\~-]+)$};
    my $file = $1;
    if ( scalar( unlink($file) ) != 1 ) {
        ASSERT( 0, "unable to unlink $file : $!" ) if DEBUG;
        Foswiki::Exception::Fatal->throw(
            text => "unable to unlink $file : $!" );
    }
}

=begin TML

---++ ObjectMethod uploadInfo() -> $headers

Returns a hashref to information about uploaded
file as sent by browser.

=cut

sub uploadInfo {
    return $_[0]->headers;
}

=begin TML

---++ ObjectMethod handle() -> ( $fh )

Returns an open filehandle to uploaded file.

=cut

sub handle {
    my $fh = new IO::File( $_[0]->tmpname, '<' );
    binmode $fh;
    return $fh;
}

=begin TML

---++ ObjectMethod tmpFileName() -> ( $tmpName )

Returns the names of temporarly created file.

=cut

sub tmpFileName {
    return $_[0]->tmpname;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This module is based/inspired on Catalyst framework. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
for credits and liscence details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
