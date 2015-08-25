# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Htpasswd::FileName;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    use filetest 'access';

    #NOTE:  If there are any other PasswordManagers that require .htpasswd,
    #       they should be added to this list.
    return
      if ( $Foswiki::cfg{PasswordManager} ne 'Foswiki::Users::HtPasswdUser' );

    my $f = $Foswiki::cfg{Htpasswd}{FileName};
    Foswiki::Configure::Load::expandValue($f);

    ($f) = $f =~ m/(.*)/;    # Untaint needed to prevent a failure.

    unless ( -e $f ) {

        # password file does not exist; check it can be created
        my $fh;
        if ( !open( $fh, ">", $f ) || !close($fh) ) {
            return $reporter->ERROR(
                "Password file $f does not exist and could not be created: $!");
        }
        else {
            $reporter->NOTE("A new password file $f has been created.");
            unless ( chmod( 0600, $f ) ) {
                $reporter->WARN(
"Permissions could not be changed on the new password file $f"
                );
            }
        }
    }
    elsif ( !( -f $f && -w $f ) ) {

        # password file exists but is not writable
        return $reporter->ERROR( "$f is not a writable plain file. "
              . "User registration will be disabled until this is corrected." );
    }
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
