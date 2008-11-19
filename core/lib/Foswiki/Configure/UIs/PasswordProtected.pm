#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2006 Foswiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# Base class of password protected update UIs. It always saves the
# base configuration (content of LocalSite.cfg) but also can
#
package Foswiki::Configure::UIs::PasswordProtected;

use strict;

use Foswiki::Configure::UI;

use base 'Foswiki::Configure::UI';

use Foswiki::Configure::Type;

sub ui {
    my $this   = shift;
    my $output = '';

    if ( $Foswiki::query->param('newCfgP') ) {
        if ( $Foswiki::query->param('newCfgP') eq $Foswiki::query->param('confCfgP')
          )
        {
            $this->{updates}{'{Password}'} =
              $this->_encode( $Foswiki::query->param('newCfgP') );
            $output .= 'Password changed';
        }
        else {
            die 'New password and confirmation do not match';
        }
    }

    return $output . CGI::hr();
}

1;
