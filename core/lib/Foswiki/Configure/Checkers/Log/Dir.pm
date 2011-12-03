# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Log::Dir;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Load ();

sub check {
    my $this = shift;
    my $mess = '';

    unless ( $Foswiki::cfg{Log}{Dir} ) {
        $Foswiki::cfg{Log}{Dir} = "$Foswiki::cfg{WorkingDir}/logs";
    }
    $mess .= $this->showExpandedValue( $Foswiki::cfg{Log}{Dir} );

    my $ld = $this->getCfg("{Log}{Dir}");

    my $d;
    if ( opendir( $d, $ld ) ) {

        # make sure all the files in the log dir are writable
        foreach my $f ( grep { /^[^\.].*.log/ } readdir($d) ) {
            if ( !-w "$ld/$f" ) {
                $mess .= $this->ERROR("$ld/$f is not writable");
            }
        }
    }
    else {
        mkdir($ld)
          || return $this->ERROR(
            "$ld does not exist, and I can't create it: $!");
        $mess .= $this->NOTE("Created $ld");
    }
    my $e = $this->checkCanCreateFile("$ld/tmp.log");
    $mess .= $this->ERROR($e) if $e;

    # Automatic upgrade of script action logging
    foreach my $a ( keys %{ $Foswiki::cfg{Log}{Action} } ) {
        next unless ( defined $Foswiki::cfg{Log}{$a} );
        $Foswiki::cfg{Log}{Action}{$a} = $Foswiki::cfg{Log}{$a};
        delete $Foswiki::cfg{Log}{$a};
        $mess .= $this->WARN(
"Deprecated \$Foswiki::cfg{Log}{$a} setting should be removed from lib/LocalSite.cfg"
        );
    }
    return $mess;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
