# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::MaxLSCBackups;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::FileUtil ();

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $max = $Foswiki::cfg{MaxLSCBackups} || 0;

    unless ($max) {
        $reporter->WARN('No backups will be saved.');
        return;
    }

    my $lsc = Foswiki::Configure::FileUtil::findFileOnPath('LocalSite.cfg');
    unless ($lsc) {

        # Still in bootstrap mode - nothing to back up
        return;
    }
    my ( $vol, $dir, $file ) = File::Spec->splitpath($lsc);
    my $lscBackup =
      File::Spec->catpath( $vol, $dir, 'LocalSite.cfg.' . time() );

    my $e = Foswiki::Configure::FileUtil::checkCanCreateFile($lscBackup);
    if ($e) {
        $reporter->ERROR( <<WHINE );
No backups are possible because configure was unable to write
to the directory $lscBackup: $e.
WHINE
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
