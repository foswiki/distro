# -*- mode: CPerl; -*-

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

use File::Spec;
use Foswiki::Configure qw/:config/;

use Foswiki::Configure::Pluggable;
our @ISA = (qw/Foswiki::Configure::Pluggable/);

sub new {
    my $class = shift;
    my ( $file, $root, $settings ) = @_;

    my $fileLine = $.;
    my @items;

    my $bindir = Foswiki::Configure::UI->new( {} )->{bin};
    unless ($bindir) {
        push @Foswiki::Configure::FoswikiCfg::errors,
          [ $file, $fileLine, "Unable to locate scripts directory in root?" ];
        return 1;
    }

    my $dh;
    unless ( opendir( $dh, $bindir ) ) {
        push @Foswiki::Configure::FoswikiCfg::errors,
          [ $file, $fileLine, "Unable to read scripts directory: $!" ];
        return 1;
    }

    foreach my $file ( sort grep { !/^\./ && -f $_ && -x _ } readdir($dh) ) {
        $file =~ /^([\w_-]+)$/ or next;
        $file = $1;

        my $script = $file;
        $script =~ s/$Foswiki::cfg{ScriptSuffix}$//
          if ( defined $Foswiki::cfg{ScriptSuffix} );

        my $keys = "{ScriptUrlPaths}{$script}";

        next
          if (
            Foswiki::Configure::FoswikiCfg::_getValueObject( $keys, $settings )
          );

        # Script must use Foswiki::engine to be redirectable.

        my $sf;
        unless ( open( $sf, '<', File::Spec->catfile( $bindir, $file ) ) ) {
            push @Foswiki::Configure::FoswikiCfg::errors,
              [ $file, $fileLine, "Unable to inspect $bindir/$file: $!" ];
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

        my $value = Foswiki::Configure::Value->new('SCRIPTHASH');

        # Don't include a _defined item; besides being meaningless,
        # the users actually require non-existant keys

        $value->set(
            keys => $keys,
            desc => "Full URL for $script script.  Rarely modified.",
            opts => 'EXPERT E CHECK="expand nullok"',
        );

        $value->addAuditGroup(qw/PARS:0/);
        Foswiki::Configure::FoswikiCfg::_pusht( $settings, $value );

        unless ( exists $Foswiki::defaultCfg->{ScriptUrlPaths}{$script} ) {
            $Foswiki::defaultCfg->{ScriptUrlPaths}{$script} =
                '$Foswiki::cfg{ScriptUrlPath}/'
              . $script
              . '$Foswiki::cfg{ScriptSuffix}';
        }
    }
    closedir $dh;

    return 1;
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
