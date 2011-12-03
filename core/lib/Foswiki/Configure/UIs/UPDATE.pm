# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::UPDATE

Special UI, invoked directly from =configure=, that implements the
save changes screen.

=cut

package Foswiki::Configure::UIs::UPDATE;

use strict;
use warnings;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

use Foswiki::Configure::FoswikiCfg ();

my $insane;    # Set if existing config is not usable.

=begin TML

---++ ObjectMethod setInsane()

Set status to insane if existing configuration is not usable

=cut

sub setInsane {
    $insane = 1;
}

=begin TML

---++ ObjectMethod commitChanges()

Commit changes to disk.

=cut

sub commitChanges {
    my ( $this, $root, $valuer, $updated ) = @_;

    $this->{changed} = 0;
    $this->{updated} = $updated;

    my @changesList = ();
    $this->{changesList} = \@changesList;

    my $logfile;
    $this->{log}  = '';
    $this->{user} = $Foswiki::query->remote_user() || $ENV{REMOTE_USER} || '';
    $this->{addr} = $Foswiki::query->remote_addr() || $ENV{REMOTE_ADDR} || '';

    # Pass ourselves as log listener
    Foswiki::Configure::FoswikiCfg::save( $root, $valuer, $this, $insane );

    if ( $this->{log} && defined( $Foswiki::cfg{Log}{Dir} ) ) {

        # configuration variable may be coming from POST, and might thus
        # be tainted, we must be able to trust that the adminstrator has
        # input a proper path and therefore untaint rigourously
        # NOTE: this assumes configure is properly hardened through the web
        # server as instructed in the fine manual!
        my $logdir = $Foswiki::cfg{Log}{Dir};
        Foswiki::Configure::Load::expandValue($logdir);
        ($logdir) = $logdir =~ /^(.*)$/;
        unless ( -d $logdir ) {
            mkdir $logdir;
        }
        if ( open( my $lf, '>>', "$logdir/configure.log" ) ) {
            print $lf $this->{log};
            close($lf);
        }
    }
}

=begin TML

---++ ObjectMethod logChange($keys, $value)

Listener for when a configuration item is saved. Called by
Foswiki::Configure::FoswikiCfg during the save process.

=cut

sub logChange {
    my ( $this, $keys, $value ) = @_;

    if ( $this->{updated}->{$keys} ) {
        push( @{ $this->{changesList} }, { key => $keys, value => $value } );
        $this->{changed}++;
        $this->{log} .= '| '
          . gmtime() . ' | '
          . $this->{user} . ' | '
          . $this->{addr} . ' | '
          . $keys . ' | '
          . $value . " |\n";
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
