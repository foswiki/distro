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
package TWiki::Configure::UIs::UPDATE;
use base 'TWiki::Configure::UI';

use strict;

use TWiki::Configure::UI;
use TWiki::Configure::TWikiCfg;

sub ui {
    my ($this, $root, $valuer, $updated) = @_;

    $this->{changed} = 0;
    $this->{updated} = $updated;

    $this->{output} = CGI::h2('Updating configuration');

    my $logfile;
    $this->{log} = '';
    $this->{user} = '';
    if (defined $TWiki::query) {
        $this->{user} = $TWiki::query->remote_user() || '';
    }

    TWiki::Configure::TWikiCfg::save($root, $valuer, $this);

    if( $this->{log} && defined( $TWiki::cfg{ConfigurationLogName} )) {
        if (open(F, '>>', $TWiki::cfg{ConfigurationLogName} )) {
            print F $this->{log};
            close(F);
        }
    }

    # Put in a link to the front page of the TWiki
    my $url = "$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath}/view$TWiki::cfg{ScriptSuffix}/";
    return $this->{output}.CGI::p().CGI::strong(
        'Setting ' . $this->{changed}.
          ' configuration item' . (($this->{changed} == 1) ? '' : 's').'.').
            CGI::p().
                CGI::a({ href => $url}, "Go to the TWiki front page")." or ";
}

# Listener for when a saved configuration item is changed.
sub logChange {
    my ($this, $keys, $value) = @_;

    if ($this->{updated}->{$keys}) {
        $this->{output} .= CGI::h3($keys).CGI::code($value);
        $this->{changed}++;
        $this->{log} .= '| '.gmtime().' | '.$this->{user}.' | '.$keys.' | '.
          $value," |\n";
    }
}

1;
