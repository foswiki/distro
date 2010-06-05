# See bottom of file for license and copyright information
package TWiki::UI;

# Bridge between TWiki::UI and Foswiki::UI

use strict;
use warnings;

use Foswiki::UI;

sub TRACE_PASSTHRU    { Foswiki::UI::TRACE_PASSTHRU(@_) }
sub handleRequest     { Foswiki::UI::handleRequest(@_) }
sub execute           { Foswiki::UI::_execute(@_) }
sub logon             { Foswiki::UI::logon(@_) }
sub checkWebExists    { Foswiki::UI::checkWebExists(@_) }
sub checkTopicExists  { Foswiki::UI::checkTopicExists(@_) }
sub checkAccess       { Foswiki::UI::checkAccess(@_) }
sub readTemplateTopic { Foswiki::UI::readTemplateTopic(@_) }
sub run               { Foswiki::UI::run(@_) }

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
