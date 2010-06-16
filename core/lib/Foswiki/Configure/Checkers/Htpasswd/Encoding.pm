# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Htpasswd::Encoding;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Dependency;

sub check {
    my $this = shift;

    my $enc = $Foswiki::cfg{Htpasswd}{Encoding};
    my $e   = '';

    if ( $enc eq 'md5' ) {
        my $dep = new Foswiki::Configure::Dependency(
            type    => "cpan",
            module  => "Digest::MD5",
            version => ">0"
        );
        my ( $ok, $message ) = $dep->check();
        if ($ok) {
            $e = $this->NOTE($message);
        }
        else {
            $e = $this->ERROR($message);
        }
    }
    elsif ( $enc eq 'sha1' ) {
        my $dep = new Foswiki::Configure::Dependency(
            type    => "cpan",
            module  => "Digest::SHA",
            version => ">0"
        );
        my ( $ok, $message ) = $dep->check();
        if ($ok) {
            $e = $this->NOTE($message);
        }
        else {
            $e = $this->ERROR($message);
        }
    }
    elsif ( $enc eq 'crypt-md5' ) {
        if ( $Foswiki::cfg{DetailedOS} eq 'darwin' ) {
        $e = $this->ERROR("ERROR: crypt-md5 FAILS on OSX (no fix in 2008)");
        }
        use Config;
        if ( $Config{myuname} =~ /strawberry/i ) {
            $e = $this->ERROR("ERROR: crypt-md5 FAILS on Windows with Strawberry perl (no fix in 2010)");
        }
    }

    return $e;
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
