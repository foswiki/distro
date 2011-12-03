# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::TemplatePath;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    my $e = '';

    my @path = split( ',', $Foswiki::cfg{TemplatePath} );

    foreach my $orig (@path) {
        my $path = $orig;
        Foswiki::Configure::Load::expandValue($path);

        if ( $path =~ m/\$(?!name|web|skin)/ ) {
            $e .= $this->ERROR(
"Unknown token - not \$name, \$web, \$skin or \$Foswiki::cfg{...}, found in $orig"
            );
        }

        my ($cfgparm) = $orig =~ m/.*(\$Foswiki::cfg\{.*\})/;
        if ($cfgparm) {
            Foswiki::Configure::Load::expandValue($cfgparm);
            $e .=
              $this->ERROR("Unknown Foswiki::cfg variable referenced in $orig")
              if ( $cfgparm eq 'undef' );
        }

        #}

        my ( $dir, $file ) = $path =~ m#^\s*([^\$]+)(.*)$#;

        if ( $dir
            && ( substr( $dir, 0, 1 ) eq '/' || substr( $dir, 1, 1 ) eq ':' ) )
        {
            $e .= $this->ERROR("Path $dir not found, at $orig")
              unless ( -e $dir && -d $dir );
        }

    }

    $e .= $this->showExpandedValue( $Foswiki::cfg{TemplatePath} );

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
