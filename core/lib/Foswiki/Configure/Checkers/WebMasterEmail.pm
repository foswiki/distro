# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WebMasterEmail;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $e = '';

    if ( $Foswiki::cfg{WebMasterEmail} eq 'SERVER_ADMIN') {
        if ( $ENV{SERVER_ADMIN} && $ENV{SERVER_ADMIN} !~ /^\[/ ) {
            my $serverAdmin = $ENV{SERVER_ADMIN};
            if ($serverAdmin !~ /^([a-z0-9!+$%&'*+-\/=?^_`{|}~.]+\@[a-z0-9\.\-]+)$/i ) {
                $e .= $this->ERROR("Foswiki will try to use the web server, SERVER_ADMIN as the WebMasterEmail address.  But $ENV{SERVER_ADMIN} does not appear to be a valid address.)");
            }
            else {
                $e .= $this->WARN("Foswiki will use the web server, SERVER_ADMIN ($ENV{SERVER_ADMIN}) as the WebMasterEmail address.  It is preferable to set an explicit email address here.");
            }
        }
        else {
            $e .= $this->ERROR('SERVER_ADMIN email address is not available.  Set WebMasterEmail to a valid address for proper operation.');
        }
        return $e;
    }

    if ( !$Foswiki::cfg{WebMasterEmail} ) {
        $e .= $this->ERROR(
'Please make sure you enter the e-mail address of the webmaster. This is required for registration to work and appears as a feedback address  It is preferable to set an explicit email address here.'
        );
    }

    #    $regex{emailAddrRegex} ...
    elsif ( $Foswiki::cfg{WebMasterEmail} !~
        /^([a-z0-9!+$%&'*+-\/=?^_`{|}~.]+\@[a-z0-9\.\-]+)$/i )
    {
        $e .= $this->WARN('I don\'t recognise this as a valid email address.');
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
