# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PluginsOrder;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
use File::stat;
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    # Assuming this is relatively fast; see PubDir.pm for a model
    # of only doing the checks in provideFeedback.

    my $msg = $this->provideFeedback(@_);
    if ($msg) {
        $msg = $this->NOTE("Click the Re-test button to revalidate") . $msg;
    }

    return $msg;
}

sub provideFeedback {
    my $this = shift;

    my $e = '';

    my @plugins   = split( ',', $Foswiki::cfg{PluginsOrder} );
    my $count     = 0;
    my $foundTWCP = 0;

    foreach my $plug (@plugins) {
        my $enabled = $Foswiki::cfg{Plugins}{$plug}{Enabled};
        $foundTWCP = 1 if ( $plug eq 'TWikiCompatibilityPlugin' );
        if ( $plug eq 'TWikiCompatibilityPlugin' && $enabled ) {
            $e .=
              $this->WARN(
                $plug . ' must be first in the list for proper operation' )
              unless ( $count == 0 );
        }
        $count++;
        unless ($enabled) {
            unless ( $plug eq 'TWikiCompatibilityPlugin' ) {
                $e .=
                  $this->WARN( $plug . ' is not enabled or is not installed' );
            }
        }
    }

    if (  !$foundTWCP
        && $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} )
    {
        $e .= $this->WARN(
'TWikiCompatibilityPlugin is enabled.  It  must be first in the PluginsOrder list for proper operation'
        );
    }

    my %libs;
    foreach my $dir (@INC) {
        $libs{$dir} = 1;
    }

    foreach my $plug ( keys %{ $Foswiki::cfg{Plugins} } ) {
        next unless ( $plug =~ m/Plugin$/ );
        my $mod = $Foswiki::cfg{Plugins}{$plug}{Module};

        if ($mod) {

            my @plugpath = split( '::', $mod );
            my $enabled  = shift @plugpath;
            my $plugpath = join( '/', @plugpath );

            my $altmod = ( $enabled eq 'Foswiki' ) ? 'TWiki' : 'Foswiki';

            my $found  = 0;
            my $fcount = 0;
            my %dups   = ();

            foreach my $dir ( keys %libs ) {
                if ( -e "$dir/$enabled/$plugpath.pm" ) {
                    $fcount++;
                    $found = 1;
                    my $sb = stat("$dir/$enabled/$plugpath.pm");
                    $dups{$plugpath} .= $this->NOTE(
                            "$dir/$enabled/$plugpath.pm <br/>&nbsp;&nbsp;Size: "
                          . $sb->size
                          . " Modified: "
                          . scalar localtime $sb->mtime );
                }
                if ( -e "$dir/$altmod/$plugpath.pm" ) {
                    $fcount++;
                    my $sb = stat("$dir/$altmod/$plugpath.pm");
                    $dups{$plugpath} .= $this->NOTE(
                            "$dir/$altmod/$plugpath.pm <br/>&nbsp;&nbsp;Size: "
                          . $sb->size
                          . " Modified: "
                          . scalar localtime $sb->mtime );
                }
            }
            if ( $fcount > 1 ) {
                $e .= $this->WARN(
" $plug found in multiple locations in the library path. Possible obsolete extensions should be removed. Duplicates listed below:"
                );
                $e .= $dups{$plugpath};
            }
            $e .= $this->WARN(
" $mod module is enabled - be sure this is what you want. Multiple versions are possibly installed."
            ) if ( $enabled eq 'TWiki' && $fcount > 1 );
            $e .= $this->ERROR(
                "$mod is enabled in LocalSite.cfg but was not found in the path"
            ) if ( !$found && $Foswiki::cfg{Plugins}{$plug}{Enabled} );
        }
    }
    return wantarray ? ( $e, 0 ) : $e;
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
