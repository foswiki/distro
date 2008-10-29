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
package TWiki::Configure::UIs::FINDEXTENSIONS;
use base 'TWiki::Configure::UIs::Section';

use strict;
use TWiki::Configure::Type;

sub close_html {
    my ($this, $section) = @_;

    my $button = <<HERE;
Consult online extensions repositories for
new extensions. <b>If you made any changes, save them first!<b>
HERE
    # Check that the extensions UI is loadable
    my $bad = 0;
    foreach my $module qw(TWiki::Configure::UIs::EXTEND TWiki::Configure::UIs::FINDEXTENSIONS) {
        eval "require $module";
        if ($@) {
            $bad = 1;
            last;
        }
    }
    my $actor;
    if (!$bad) {
        # Can't use a submit here, because if we do, it is invoked when
        # the user presses Enter in a text field.
        my @script = File::Spec->splitdir($ENV{SCRIPT_NAME} || 'THISSCRIPT');
        my $scriptName = pop(@script);
        $scriptName =~ s/.*[\/\\]//;  # Fix for Item3511, on Win XP

        $actor = CGI::a({ href => $scriptName.'?action=FindMoreExtensions',
                          class=>'twikiSubmit',
                          accesskey => 'P' },
                        'Find More Extensions');
    } else {
        $actor = $this->WARN(<<MESSAGE);
Cannot load the extensions installer.
Check 'Perl Modules' in the 'CGI Setup' section above, and install any
missing modules required for the Extensions Installer.
MESSAGE
    }
    return CGI::Tr(CGI::td($button),CGI::td($actor)).
      $this->SUPER::close_html($section);
}

1;
