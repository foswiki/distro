# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::JQueryPlugin::JQueryVersion;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
use File::Spec();
our @ISA = qw( Foswiki::Configure::Checker );

sub check {
    my $this          = shift;
    my $e             = '';
    my $jQueryVersion = $Foswiki::cfg{JQueryPlugin}{JQueryVersion};

    if ( !$jQueryVersion ) {
        return $this->ERROR("There is no configured jQuery version. ");
    }

    if ( $jQueryVersion =~ /^jquery-(\d+)\.(\d+)\.(\d+)/ && defined $1 ) {
        my $version = $1 * 10000 + $2 * 100 + $3;

        if ( $version <= 20203 ) {
            $e .= $this->WARN("jQuery 2.2.3 and earlier are deprecated. ");
        }

        if ( $version >= 30000 ) {
            $e .= $this->WARN(
"jQuery 3 and later are not yet compatible with Foswiki. You might experience incompatibilities with other jQuery plugins. "
            );
        }
    }

    if (
        not -f File::Spec->catfile(
            File::Spec->splitdir( $Foswiki::cfg{PubDir} ),
            $Foswiki::cfg{SystemWebName},
            'JQueryPlugin',
            $jQueryVersion . '.js'
        )
      )
    {
        $e .= $this->ERROR("The configured jQuery version does not exist. ");
    }

    return $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2020 Foswiki Contributors. Foswiki Contributors
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
