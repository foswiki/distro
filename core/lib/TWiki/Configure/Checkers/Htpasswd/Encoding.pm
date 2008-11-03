#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
package TWiki::Configure::Checkers::Htpasswd::Encoding;
use base 'TWiki::Configure::Checker';

use strict;

sub check {
    my $this = shift;

    my $enc = $TWiki::cfg{Htpasswd}{Encoding};
    my $e   = '';

    if ( $enc eq 'digest' ) {
        $e .= $this->checkPerlModules(
            name           => 'Digest::MD5',
            usage          => "MD5 encoded passwords",
            minimumVersion => 1,
            disposition    => 'required'
        );
    }
    elsif ( $enc eq 'sha1' ) {
        $e .= $this->checkPerlModules(
            name           => 'MIME::Base64',
            usage          => "SHA1 password encoding",
            minimumVersion => 1,
            disposition    => 'required'
        );
    }
    my $pe = $this->checkTreePerms( $TWiki::cfg{Htpasswd}{FileName}, 'r' );
    $e .= $this->ERROR($pe) if $pe;
    return $e;
}

1;
