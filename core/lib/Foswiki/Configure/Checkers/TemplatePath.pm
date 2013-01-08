# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::TemplatePath;

use strict;
use warnings;

use Foswiki::Configure qw/:keys/;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    my $e = '';

    my @path = split( ',', $Foswiki::cfg{TemplatePath} );

    my $n        = 0;
    my $expanded = '';
    foreach my $orig (@path) {
        $n++;
        my $path = $orig;
        Foswiki::Configure::Load::expandValue($path);
        $expanded .= "<li>$path";

        if ( $path =~ m/\$(?!name|web|skin)/ ) {
            my $p = $path;
            $p =~ s/\$(?:name|web|skin)//g;
            $p = join( ', ', $p =~ /(\$\w*)/g );
            $e .= $this->ERROR(
"Unknown token(s) $p - not \$name, \$web, \$skin or \$Foswiki::cfg{...}, found in item $n"
            );
        }

        my (@vars) = ( $orig =~ m/(\$Foswiki::cfg$configItemRegex)/g );
        foreach my $cfgparm (@vars) {
            my $xpn = $cfgparm;
            Foswiki::Configure::Load::expandValue( $xpn, 1 );

            unless ( defined $xpn ) {
                $e .=
                  $this->ERROR("$cfgparm is undefined, referenced in item $n");
                next;
            }
        }

        my ( $dir, $file ) = $path =~ m#^\s*([^\$]+)(.*)$#;

        if ( $dir
            && ( substr( $dir, 0, 1 ) eq '/' || substr( $dir, 1, 1 ) eq ':' ) )
        {
            $e .= $this->ERROR("Path $dir not found, in item $n")
              unless ( -e $dir && -d $dir );
        }

    }
    if ($expanded) {
        $e .= $this->NOTE("Expands to:<ol>$expanded</ol>");
    }
    else {
        $e .= $this->ERROR("Value must not be empty");
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
