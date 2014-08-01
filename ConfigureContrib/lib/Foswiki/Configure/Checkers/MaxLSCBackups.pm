# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::MaxLSCBackups;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');
use Foswiki::Configure::SaveLSC;

sub check {
    my $this = shift;
    my $e;

    my $lsc = Foswiki::Configure::SaveLSC::lscFileName();
    my ( $vol, $dir, $file ) = File::Spec->splitpath($lsc);
    my $lscBackup =
      File::Spec->catpath( $vol, $dir, 'LocalSite.cfg.' . time() );

    my $err = $this->checkCanCreateFile($lscBackup);

    $err .=
'<br />No backups are possible because configure was unable to write to the directory.'
      if ($err);

    return $this->NOTE($err)
      unless $Foswiki::cfg{MaxLSCBackups};

    if ($err) {
        $e .= $this->WARN($err);
        $e .= $this->ERROR(
            "<tt>{MaxLSCBackups}</tt> has been changed to 0 to disable backups."
        );
        $e .= $this->NOTE(
"To resolve this error, either make <tt>$dir</tt> writable, or save the configuration to make the change permanent."
        );
        $Foswiki::cfg{MaxLSCBackups} = 0;
    }
    else {
        $e .= $this->NOTE(
"Changes to <tt>LocalSite.cfg</tt> will be backed up in <tt>$dir</tt>"
        );
    }

    return $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
