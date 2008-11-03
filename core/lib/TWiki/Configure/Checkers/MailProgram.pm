#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
package TWiki::Configure::Checkers::MailProgram;

use strict;

use TWiki::Configure::Checker;

use base 'TWiki::Configure::Checker';

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
    elsif ( !$TWiki::cfg{SMTP}{MAILHOST} ) {
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
        my $val = $TWiki::cfg{MailProgram} || '';
        $val =~ s/\s.*$//g;
        if ( !( -x $val ) ) {
            $n .= $this->WARN("<tt>$val</tt> was not found. Check the path.");
        }
    }
    return $n;
}

1;
