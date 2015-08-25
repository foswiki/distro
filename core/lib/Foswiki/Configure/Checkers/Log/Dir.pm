# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Log::Dir;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Load ();

sub check_current_value {
    my ( $this, $reporter ) = @_;

    use filetest 'access';

    unless ( $Foswiki::cfg{Log}{Dir} ) {
        $Foswiki::cfg{Log}{Dir} = "$Foswiki::cfg{WorkingDir}/logs";
    }

    my $ld = $this->checkExpandedValue($reporter);
    return unless defined $ld;

    ($ld) = $ld =~ m/^(.*)$/;    # Untaint

    my $d;
    if ( opendir( $d, $ld ) ) {

        # make sure all the files in the log dir are writable
        foreach my $f ( grep { /^[^\.].*.log/ } readdir($d) ) {
            if ( !-w "$ld/$f" ) {
                $reporter->ERROR("$ld/$f is not writable");
            }
        }
        closedir $d;
    }
    else {
        mkdir($ld)
          || return $reporter->ERROR(
            "$ld does not exist, and I can't create it: $!");
        $reporter->NOTE("Created $ld");
    }
    my $e = Foswiki::Configure::FileUtil::checkCanCreateFile("$ld/tmp.log");
    $reporter->ERROR($e) if $e;

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
