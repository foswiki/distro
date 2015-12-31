# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::NFCNormalizeFilenames;

use strict;
use warnings;

use Encode;
use Unicode::Normalize;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;
    my $e;

# Determine if the file system is NFC or NFD.
# Write a UTF8 filename to the data directory, and then read the directory.
# If the filename is returned in NFD format, then the NFCNormalizeFilename flag is enabled.

    my $testfile = 'ČáŘý.testCfgNFC';
    if (
        open(
            my $F, '>', Encode::encode_utf8("$Foswiki::cfg{DataDir}/$testfile")
        )
      )
    {
        close($F);
        opendir( my $dh, Encode::encode_utf8( $Foswiki::cfg{DataDir} ) )
          or die $!;
        my @list = grep { /testCfgNFC/ }
          map { Encode::decode_utf8($_) } readdir($dh);
        if ( scalar @list && $list[0] eq $testfile ) {
            $e .= $reporter->NOTE("NFC Data Storage Detected");
            $Foswiki::cfg{NFCNormalizeFilenames} = 0;
        }
        else {
            if ( scalar @list && NFD($testfile) eq $list[0] ) {
                $e .= $reporter->NOTE("NFD Data Storage Detected");
                $e .= $reporter->ERROR(
"Filename Normalization should be enabled on NFD File Systems."
                ) unless ( $Foswiki::cfg{NFCNormalizeFilenames} );
            }
            else {
                $e .= $reporter->WARN(
"Unable to detect Normalization. Read/write of test file failed."
                );
            }
        }
        unlink "$Foswiki::cfg{DataDir}/$testfile";
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
