# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PLUGIN_MODULE;

# Common (type) checker used by all {Plugins}{Module} sub-keys.
# It is selected in Pluggables/PLUGINS. It should *not* be used in
# .spec files.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');
use Assert;

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $keys = $this->{item}->{keys};

    # NOTE: this checker is also invoked from the PLUGIN_ENABLED
    # checker, hence the /{Enabled}$/
    $keys =~ m/^\{Plugins\}\{(.*)\}\{(Module|Enabled)\}$/;
    ASSERT($1) if DEBUG;
    my $plug = $1;
    my $key  = $2;
    my $mod  = $Foswiki::cfg{Plugins}{$plug}{Module};

    unless ($mod) {
        $reporter->ERROR(
"$plug has no {Plugins}{$plug}{Module}. It has been reset to the default value - this change must be saved."
        );
        $reporter->hint( 'reset_may_repair', 1 );
        return;
    }

    # Don't check it if it's not enabled
    return unless $Foswiki::cfg{Plugins}{$plug}{Enabled};

    my @plugpath = split( '::', $mod );
    my $enabled  = shift @plugpath;
    my $plugpath = join( '/', @plugpath );

    my $altmod = ( $enabled eq 'Foswiki' ) ? 'TWiki' : 'Foswiki';

    my %found;

    foreach my $dir (@INC) {
        if ( -e "$dir/$enabled/$plugpath.pm" ) {
            $found{"$dir/$enabled/$plugpath.pm"} = 1;
        }
        if ( -e "$dir/$altmod/$plugpath.pm" ) {
            $found{"$dir/$altmod/$plugpath.pm"} = 1;
        }
    }
    if ( !scalar( keys %found ) ) {
        $reporter->ERROR(
"$mod is enabled in LocalSite.cfg but was not found in the \@INC path"
        );
    }
    elsif ( scalar( keys %found ) > 1 ) {
        if ( $enabled eq 'TWiki' ) {
            $reporter->WARN(
"$mod module is enabled - be sure this is what you want. Multiple versions are possibly installed."
            );
        }
        else {
            $reporter->WARN(
"$mod found in multiple locations in the library path. Possible obsolete extensions should be removed. Duplicates: "
                  . join( ' ', keys %found ) );
        }
    }

    # if there's an explicit checker, invoke it
    my $ec = Foswiki::Configure::Checker::loadChecker( $this->{item}, 1 );
    $ec->check_current_value($reporter) if ($ec);
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
