# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ConfigureGUI::PATHINFO;

=begin TML

---+ package Foswiki::Configure::Checkers::ConfigureGUI::PATHINFO

Foswiki::Configure::Checker for PATHINFO

=cut

use strict;
use warnings;

use Foswiki::Configure(qw/:cgi/);

use Foswiki::Configure::Checker ();

our @ISA = qw(Foswiki::Configure::Checker);

sub new {
    my ( $class, $item ) = @_;
    my $this = $class->SUPER::new($item);

    return $this;
}

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = $valobj->{keys};
    $query->delete($keys);

    return $this->NOTE("Not yet tested");
}

# A request is made for feedback with /test/pathinfo as the pathinfo
# Verify that we get the right feedback.
#
# This feedback routine is not called by a direct-mapped button; rather
# the CGISetup button's provideFeedback routine explicitly requests that
# this routine run.

sub provideFeedback {
    my $this   = shift;
    my $valobj = shift;

    #    my $button = shift;
    #    my $buttonValue = shift;

    my $keys = $valobj->{keys};
    my $pinfo = $query->path_info() || '';

    $query->delete($keys);

    my $fb = '';
    if ( !$pinfo ) {
        $fb = $this->ERROR( << "PINONE" ) . $this->FB_VALUE( $keys, $pinfo );
The webserver did not return any extended path information, although
a request used <strong>/test/pathinfo</strong>.
<p>Please correct your webserver's configuration and/or patchlevel.
PINONE
    }
    elsif ( $pinfo eq '/test/pathinfo' ) {
        $fb = $this->NOTE( << "PIOK") . $this->FB_VALUE( $keys, $pinfo );
The webserver returned the correct extended path information for this test.
PIOK
    }
    else {
        $fb = $this->ERROR( << "PIBAD") . $this->FB_VALUE( $keys, $pinfo );
The webserver provided incorrect extended path information for a request.
<p>The request used <strong>/test/pathinfo</strong>, 
<strong style="color:black;">, but the webserver returned $pinfo</strong>.
<p>Please correct your webserver's configuration and/or patchlevel.
PIBAD
    }
    return wantarray ? ( $fb, 0 ) : $fb;
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
