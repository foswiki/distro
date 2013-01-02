# See bottom of file for license and copyright information

package Foswiki::Configure::Types::PASSWORD;

use strict;
use warnings;

use MIME::Base64 qw/encode_base64/;

use Foswiki::Configure::Types::STRING ();
our @ISA = ('Foswiki::Configure::Types::STRING');

sub prompt {
    my ( $this, $id, $opts, $value, $class ) = @_;

    my $size = $Foswiki::DEFAULT_FIELD_WIDTH_NO_CSS;

    # percentage size should be set in CSS

    return CGI::password_field(
        -name         => $id,
        -size         => $size,
        -default      => $value,
        -autocomplete => 'off',
        -onchange     => 'valueChanged(this)',
        -class        => "foswikiInputField $class",
    );
}

# The encoding is for protection against shoulder-surfing.
# Encryption would be nice, but there's no place to store
# the decryption password, and consumers need plaintext.
#
# Modify $logValue to keep passwords out of the logfiles.
#
# See Type.pm for API.

sub value2string {
    my $this = shift;
    my ( $keys, $value, $logValue ) = @_;

    $_[2] = '*' x 15;

    my $txt = Data::Dumper->Dump( [ encode_base64( $value, '' ) ] );
    $txt =~
s/VAR1\s+=\s+(.*?);\n/Foswiki::cfg$keys = MIME::Base64::decode_base64( $1 );\n/ms;

    return ( $txt, 'MIME::Base64' );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
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
