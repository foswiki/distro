# See bottom of file for license and copyright information

# Pluggable for finding and handling languages. Implements
# *LANGUAGES* in Foswiki.spec.

package Foswiki::Plugins::ConfigurePlugin::LANGUAGES;

use strict;
use warnings;

# Refer to PLUGINS.pm for information on how this works
sub load {
    my ($factory) = @_;

    # Insert a bunch of configuration items based on what's in
    # the locales dir
    my $d = $Foswiki::cfg{LocalesDir};
    Foswiki::Configure::Load::expandValue($d);
    opendir( DIR, $d ) or return;

    my @entries;
    foreach my $file ( sort ( readdir DIR ) ) {
        next unless ( $file =~ m/^([\w-]+)\.po$/ );
        my $lang = $1;
        $lang = "'$lang'" if $lang =~ /\W/;
        push(
            @entries,
            $factory->createSpecEntry(
                type    => 'BOOLEAN',
                keys    => '{Languages}{' . $lang . '}{Enabled}',
                options => 'DISPLAY_IF {UserInterfaceInternationalisation}'
            )
        );
    }
    closedir(DIR);
    return @entries;
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
