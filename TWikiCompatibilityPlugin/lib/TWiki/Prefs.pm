package TWiki::Prefs;

# Bridge between TWiki::Prefs and Foswiki::Prefs

use strict;

use Foswiki::Prefs;


sub new { Foswiki::Prefs::new(@_) }
sub finish { Foswiki::Prefs::finish(@_) }
sub pushPreferences { Foswiki::Prefs::pushPreferences(@_) }
sub pushWebPreferences { Foswiki::Prefs::pushWebPreferences(@_) }
sub pushGlobalPreferences { Foswiki::Prefs::pushGlobalPreferences(@_) }
sub pushGlobalPreferencesSiteSpecific { Foswiki::Prefs::pushGlobalPreferencesSiteSpecific(@_) }
sub pushPreferenceValues { Foswiki::Prefs::pushPreferenceValues(@_) }
sub mark { Foswiki::Prefs::mark(@_) }
sub restore { Foswiki::Prefs::restore(@_) }
sub getPreferencesValue { Foswiki::Prefs::getPreferencesValue(@_) }
sub isFinalised { Foswiki::Prefs::isFinalised(@_) }
sub getTopicPreferencesValue { Foswiki::Prefs::getTopicPreferencesValue(@_) }
sub getTextPreferencesValue { Foswiki::Prefs::getTextPreferencesValue(@_) }
sub getWebPreferencesValue { Foswiki::Prefs::getWebPreferencesValue(@_) }
sub setPreferencesValue { Foswiki::Prefs::setPreferencesValue(@_) }
sub stringify { Foswiki::Prefs::stringify(@_) }

1;
