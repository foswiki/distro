package TWiki::UI;

# Bridge between TWiki::UI and Foswiki::UI

use strict;

use Foswiki::UI;

sub TRACE_PASSTHRU { Foswiki::UI::TRACE_PASSTHRU(@_) }
sub handleRequest { Foswiki::UI::handleRequest(@_) }
sub execute { Foswiki::UI::_execute(@_) }
sub logon { Foswiki::UI::logon(@_) }
sub checkWebExists { Foswiki::UI::checkWebExists(@_) }
sub checkTopicExists { Foswiki::UI::checkTopicExists(@_) }
sub checkAccess { Foswiki::UI::checkAccess(@_) }
sub readTemplateTopic { Foswiki::UI::readTemplateTopic(@_) }
sub run { Foswiki::UI::run(@_) }

1;
