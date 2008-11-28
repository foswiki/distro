# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::UPDATE;
use base 'Foswiki::Configure::UI';

use strict;

use Foswiki::Configure::UI;
use Foswiki::Configure::FoswikiCfg;

sub ui {
    my ( $this, $root, $valuer, $updated ) = @_;

    $this->{changed} = 0;
    $this->{updated} = $updated;

    $this->{output} = CGI::h2('Updating configuration');

    my $logfile;
    $this->{log}  = '';
    $this->{user} = '';
    if ( defined $Foswiki::query ) {
        $this->{user} = $Foswiki::query->remote_user() || '';
    }

    Foswiki::Configure::FoswikiCfg::save( $root, $valuer, $this );

    if ( $this->{log} && defined( $Foswiki::cfg{ConfigurationLogName} ) ) {
	# configuration variable may be coming from POST, and might thus
	# be tainted, we must be able to trust that the adminstrator has
	# input a proper path and therefore untaint rigourously
	# NOTE: this assumes configure is properly hardened through the web
	# server as instructed in the fine manual!
	$Foswiki::cfg{ConfigurationLogName} =~ /^(.*)$/;
	$Foswiki::cfg{ConfigurationLogName} = $1;
        if ( open( F, '>>', $Foswiki::cfg{ConfigurationLogName} ) ) {
            print F $this->{log};
            close(F);
        }
    }

    # Put in a link to the front page of the Foswiki
    my $url =
"$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}/";
    return
        $this->{output}
      . CGI::p()
      . CGI::strong( 'Setting '
          . $this->{changed}
          . ' configuration item'
          . ( ( $this->{changed} == 1 ) ? '' : 's' )
          . '.' )
      . CGI::p()
      . CGI::a( { href => $url }, "Go to the Foswiki front page" ) . " or ";
}

# Listener for when a saved configuration item is changed.
sub logChange {
    my ( $this, $keys, $value ) = @_;

    if ( $this->{updated}->{$keys} ) {
        $this->{output} .= CGI::h3($keys) . CGI::code($value);
        $this->{changed}++;
        $this->{log} .= '| '
          . gmtime() . ' | '
          . $this->{user} . ' | '
          . $keys . ' | '
          . $value, " |\n";
    }
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
