# See bottom of file for license and copyright information

package Foswiki::Configure::Pluggables::SCRIPTHASH;

# Generate configuration items for script redirection hash
#
# Some have individual items in Foswiki.spec; they are not
# duplicated here, assuming they precede the plugable call
# in the spec.
#

use strict;
use warnings;

use File::Spec ();
use FindBin    ();

use Foswiki::Configure::LoadSpec ();

sub construct {
    my ( $settings, $file, $line ) = @_;

    my $bindir = $Foswiki::cfg{ScriptDir};
    unless ($bindir) {
        $bindir = $FindBin::Bin;
        unless ( -e "$bindir/setlib.cfg" ) {
            $bindir =
              Foswiki::Configure::FileUtil::findFileOnPath('../bin/setlib.cfg');
            $bindir =~ s{/setlib.cfg$}{} if $bindir;
        }
    }
    unless ($bindir) {
        die "Unable to locate scripts directory";
    }

    my $dh;
    unless ( opendir( $dh, $bindir ) ) {
        die "Unable to read scripts directory $bindir: $!";
    }

    foreach my $filename ( sort readdir($dh) ) {
        next if $filename =~ /^\./;

        # validate and untaint
        next unless $filename =~ /^([-A-Za-z_.]+)$/;
        $filename = $1;
        my $script;
        my $default;

        if ( $Foswiki::cfg{ScriptSuffix} ) {
            next unless $filename =~ /^(.*)\.$Foswiki::cfg{ScriptSuffix}$/;
            $script = $1;
            $default =
              "\$Foswiki::cfg{ScriptUrlPath}/$1\$Foswiki::cfg{ScriptSuffix}";
        }
        else {
            $script  = $filename;
            $default = "\$Foswiki::cfg{ScriptUrlPath}/$script";
        }

        my $keys = "{ScriptUrlPaths}{$script}";

        # Check it's not already declared
        foreach my $item (@$settings) {
            if ( $item->getValueObject($keys) ) {

                # already been declared outside of *SCRIPTHASH*
                next;
            }
        }

        next unless -f $filename;
        next unless -x $filename;

        # Script must use Foswiki::engine to be redirectable.

        my $sf;
        unless ( open( $sf, '<', File::Spec->catfile( $bindir, $filename ) ) ) {
            Foswiki::Configure::LoadSpec::error( $file, $line,
                "Unable to inspect $bindir/$filename: $!" );
            next;
        }

        my $engine;
        my $n;
        while (<$sf>) {
            $n++;
            last if ( $n == 1 && !/^#!.*\bperl\b/ );
            last if ( $n > 200 || /^__END__/ );
            next if (/^\s*#/);
            next unless (/^\s*\$Foswiki::engine\s*->\s*run/);
            $engine = 1;
            last;
        }
        close $sf;
        next unless ($engine);

        # Create the item under the current heading
        my $value = Foswiki::Configure::Value->new(
            'URLPATH',
            keys        => $keys,
            desc        => "Full URL for $script script. Rarely modified.",
            EXPERT      => 1,
            UNDEFINEDOK => 1,

            # By providing a default we are suggesting it is a
            # good idea - which it isn't. So don't.
            #default     => "'$default'",
            opts =>
'FEEDBACK="label=\'Verify\';wizard=\'ScriptHash\';method=\'verify\';auth=1" CHECK="expand nullok notrail"',
        );

        push( @$settings, $value );
    }
    closedir $dh;
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
