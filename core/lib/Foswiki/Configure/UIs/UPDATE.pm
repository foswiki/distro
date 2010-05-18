# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::UPDATE;

use strict;
use warnings;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

use Foswiki::Configure::FoswikiCfg ();

sub ui {
    my ( $this, $root, $valuer, $updated ) = @_;

    $this->{changed} = 0;
    $this->{updated} = $updated;

    my @changesList = ();
    $this->{changesList} = \@changesList;

    my $logfile;
    $this->{log}  = '';
    $this->{user} = '';
    if ( defined $Foswiki::query ) {
        $this->{user} = $Foswiki::query->remote_user() || '';
    }

    Foswiki::Configure::FoswikiCfg::save( $root, $valuer, $this );

    if ( $this->{log} && defined( $Foswiki::cfg{Log}{Dir} ) ) {

        # configuration variable may be coming from POST, and might thus
        # be tainted, we must be able to trust that the adminstrator has
        # input a proper path and therefore untaint rigourously
        # NOTE: this assumes configure is properly hardened through the web
        # server as instructed in the fine manual!
        $Foswiki::cfg{Log}{Dir} =~ /^(.*)$/;
        $Foswiki::cfg{Log}{Dir} = $1;
        unless ( -d $Foswiki::cfg{Log}{Dir} ) {
            mkdir $Foswiki::cfg{Log}{Dir};
        }
        if ( open( F, '>>', "$Foswiki::cfg{Log}{Dir}/configure.log" ) ) {
            print F $this->{log};
            close(F);
        }
    }

    return $this->{changesList};
}

# Listener for when a saved configuration item is changed.
sub logChange {
    my ( $this, $keys, $value ) = @_;

    if ( $this->{updated}->{$keys} ) {
        push( @{ $this->{changesList} }, { key => $keys, value => $value } );
        $this->{changed}++;
        $this->{log} .= '| '
          . gmtime() . ' | '
          . $this->{user} . ' | '
          . $keys . ' | '
          . $value, " |\n";
    }
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
