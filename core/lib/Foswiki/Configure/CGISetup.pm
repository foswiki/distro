# See bottom of file for license and copyright information
package Foswiki::Configure::CGISetup;

=begin TML

---+ package Foswiki::Configure::CGISetup

Special Section with server environment status.

=cut

use strict;
use warnings;

use Foswiki::Configure::Section ();
our @ISA = ('Foswiki::Configure::Section');

sub new {
    my $class = shift;
    my $root  = shift;

    my $self =
      $class->SUPER::new( 'Web server environment', '' );    # Headline, options
    $self->set( desc => << "DESC" );
Click the action button to analyze and display the webserver environment.
DESC

    my $item = Foswiki::Configure::Value->new(
        "CGISetup",
        opts => '/FEEDBACK="~p[/test/pathinfo]Analyze Environment Now"',
        keys => '{WebserverEnvironmentStatus}',
    );
    $self->addChild($item);

    $item = Foswiki::Configure::Value->new(
        "PATHINFO",
        keys => '{ConfigureGUI}{PATHINFO}',
        desc =>
qq{Extended path information (PATH_INFO) is used to provide arguments to CGI scripts such as configure. 
<p>Verifying that your webserver correctly delivers PATH_INFO is particularly important if you are using mod_perl, Apache or IIS, or are using a web hosting provider, as these environments are frequently misconfigured or running out-of-date software.
<p>When you click <strong>Analyze Environment</strong>, configure tests PATH_INFO by making a special request to itself with known PATH_INFO. Configure verifies that it receives the correct information from the webserver.
<p>Any error that is detected by this test will be reported above.},
    );
    $self->addChild($item);
    $Foswiki::cfg{ConfigureGUI}{PATHINFO} = '';

    return $self;
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
