# See bottom of file for license and copyright information

=pod

---+ package CompareRevisionsAddonPlugin

This is a helper plugin for the CompareRevisionsAddon package.

=cut

# change the package name and $pluginName!!!
package Foswiki::Plugins::CompareRevisionsAddonPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki;

# Keep this in sync with CompareRevsionsAddOn
our $VERSION = '1.114';
our $RELEASE = '1.114';

# Name of this Plugin, only used in this module
our $pluginName = 'CompareRevisionsAddonPlugin';

# We have no prefs in plugin topic
our $NO_PREFS_IN_TOPIC = 1;

our $debug = 0;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub commonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    Foswiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    $_[0] =~ s/%RDIFF2COMPARE\{"?(.*?)"?\}%/&_handleRdiff2Compare($1)/ge;
}

sub _handleRdiff2Compare {

    my $text = shift;
    $text =~ s{/rdiff  $Foswiki::cfg{ScriptSuffix}/}
              {/compare$Foswiki::cfg{ScriptSuffix}/}xmsg;
    return $text;

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
