# See bottom of file for license and copyright information
package TWiki::Prefs;

# Bridge between TWiki::Prefs and Foswiki::Prefs

use strict;
use warnings;

use Foswiki::Prefs;

sub new                   { Foswiki::Prefs::new(@_) }
sub finish                { Foswiki::Prefs::finish(@_) }
sub pushPreferences       { Foswiki::Prefs::pushPreferences(@_) }
sub pushWebPreferences    { Foswiki::Prefs::pushWebPreferences(@_) }
sub pushGlobalPreferences { Foswiki::Prefs::pushGlobalPreferences(@_) }

sub pushGlobalPreferencesSiteSpecific {
    Foswiki::Prefs::pushGlobalPreferencesSiteSpecific(@_);
}
sub pushPreferenceValues     { Foswiki::Prefs::pushPreferenceValues(@_) }
sub mark                     { Foswiki::Prefs::mark(@_) }
sub restore                  { Foswiki::Prefs::restore(@_) }
sub getPreferencesValue      { Foswiki::Prefs::getPreferencesValue(@_) }
sub isFinalised              { Foswiki::Prefs::isFinalised(@_) }
sub getTopicPreferencesValue { Foswiki::Prefs::getTopicPreferencesValue(@_) }
sub getTextPreferencesValue  { Foswiki::Prefs::getTextPreferencesValue(@_) }
sub getWebPreferencesValue   { Foswiki::Prefs::getWebPreferencesValue(@_) }
sub setPreferencesValue      { Foswiki::Prefs::setPreferencesValue(@_) }
sub stringify                { Foswiki::Prefs::stringify(@_) }

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
