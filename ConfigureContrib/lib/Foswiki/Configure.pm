# See bottom of file for license and copyright information

use strict;
use warnings;

package Foswiki::Configure;

# ########### Configurable constants

# trace Trace flags

use constant SESSIONTRACE   => 0;    # DEBUG temp
use constant TRANSACTIONLOG => 0;

# session Session management constants

use constant SESSIONEXP  => '60m';            # Lifetime of interactive session
use constant COOKIEEXP   => '10y';            # Lifetime of cookie
use constant SAVEEXP     => '5m';             # Lifetime of cached save password
use constant RESOURCEEXP => '1m';             # Resource access window
use constant COOKIENAME  => 'FOSWIKICFG4SID'; # Change with DSN

use constant RESOURCECACHETIME => ( 30 * 24 * 60 * 60 )
  ;                                           # MAX-AGE of cached resources
                                              # in seconds. 0 to disable caching

# Work-around for https://rt.cpan.org/Public/Bug/Display.html?id=80346
# (Taint failure when Storable is used for cookies with db_file.)

#use constant SESSION_DSN => "driver:file;serializer:storable;id:md5"; # Use Cookie 2
use constant SESSION_DSN =>
  "driver:file;serializer:default;id:md5";    # Use Cookie 3
use constant RT80346 => 0;                    # Set with Storable until fixed...

# Used if code needs to know whether running
# under configure or the webserver.  Set by Dispatch.
our $configureRunning;

# Running in a fork of configure - safe to load Foswiki engine
our $configureFork;

# auth - authentication state
our $newLogin;
our $session;

# config = configuration state
our $badLSC;
our $insane;
our $sanityStatement;
our $defaultCfg;
our $unsavedChangesNotice;

# cgi - CGI-related

# htmlResponse flags
use constant MORE_OUTPUT => 100_000;
use constant NO_REDIRECT => 10_000;
use constant ERROR_FORM  => 1_000;

our $actionURI;
our $redirect;
our $method;
our $pathinfo;
our @pathinfo;
our $query;
our $resourceURI;
our $scriptName;
our $time = time();
our $url;
our $DEFAULT_FIELD_WIDTH_NO_CSS;

# feedback - Feedback-related

our $pendingChanges;

# keys - manipulating configuration keys

# session - session management (not the $sesion variable - see auth)
# See constants above

# trace - trace control flags
# See constants above

package Foswiki;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our %cfg;

# ################ Common symbols and global state

# 'constants' used in Foswiki.spec
our $TRUE  = 1;
our $FALSE = 0;

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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

