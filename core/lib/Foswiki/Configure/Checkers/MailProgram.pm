# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::MailProgram;

use strict;

use Foswiki::Configure::Checker;

use base 'Foswiki::Configure::Checker';

sub check {
    my $this = shift;

    return '' if ( !$Twiki::cfg{EnableEmail} );

    eval "use Net::SMTP";
    my $n;
    my $useprog = 0;
    if ($@) {
        $n       = "Net::SMTP is <b>not</b> installed in this environment. ";
        $useprog = 1;
    }
    elsif ( !$Foswiki::cfg{SMTP}{MAILHOST} ) {
        $n = $this->WARN(
'Net::SMTP is installed in this environment, but {SMTP}{MAILHOST} is not defined, so the {MailProgram} <b>will</b> be used..'
        );
        $useprog = 1;
    }
    else {
        $n = $this->NOTE(
'<em>Net::SMTP is installed in this environment, so this setting will <b>not</b> be used.</em>'
        );
        $useprog = 0;
    }
    if ($useprog) {
        my $val = $Foswiki::cfg{MailProgram} || '';
        $val =~ s/\s.*$//g;
        if ( !( -x $val ) ) {
            $n .= $this->WARN("<tt>$val</tt> was not found. Check the path.");
        }
    }
    return $n;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
