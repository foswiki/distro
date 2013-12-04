# See bottom of file for license and copyright information

# Pluggable for finding and handling the script redirection hash. Implements
# *SCRIPTHASH* in Foswiki.spec.

package Foswiki::Plugins::ConfigurePlugin::SCRIPTHASH;

use strict;
use warnings;

# Refer to PLUGINS.pm for information on how this works
sub load {
    my ($factory) = @_;

    # Find the script directory from $0
    my $bindir = $0;
    $bindir =~ s#[^/\\]*$##;

    # Can't do any more if we can't open it
    my $dh;
    die $@ unless ( opendir( $dh, $bindir ) );

    my @entries;

    # Read the contents and identify scripts therein
    foreach my $file ( sort grep { !/^\./ && -f $_ && -x _ } readdir($dh) ) {
        $file =~ /^([\w_-]+)$/ or next;
        $file = $1;

        my $script = $file;
        $script =~ s/$Foswiki::cfg{ScriptSuffix}$//
          if ( defined $Foswiki::cfg{ScriptSuffix} );

        my $keys = "{ScriptUrlPaths}{$script}";

        # Script must use Foswiki::engine to be redirectable.
        my $sf;
        next unless open( $sf, '<', File::Spec->catfile( $bindir, $file ) );

        # It's a script if:

        # 1. It has a shebang line
        local $/ = "\n";
        my $line = <$sf>;
        next unless $line =~ /^#!.*\bperl\b/;

        # 2. It refers to $Foswiki::engine->run somewhere before __END__
        my $n = 1;
        while ( $line = <$sf> ) {
            $n++;
            next if ( $line =~ /^\s*#/ );
            last if ( $line =~ /^__END__/ );
            if (/^\s*\$Foswiki::engine\s*->\s*run/) {

                # Create the item
                push(
                    @entries,
                    $factory->createSpecEntry(
                        type       => 'SCRIPTHASH',
                        desc       => "Full URL for $script script",
                        keys       => $keys,
                        spec_value => '$Foswiki::cfg{ScriptUrlPath}/'
                          . $script
                          . '$Foswiki::cfg{ScriptSuffix}',
                        opts => 'EXPERT'
                    )
                );
                last;
            }
        }
        close $sf;
    }
    closedir $dh;

    return @entries;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors
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
