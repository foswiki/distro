# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::Introduction

UI used by =configure= to generate the introduction from a template.

=cut

package Foswiki::Configure::UIs::Introduction;

use strict;
use warnings;

use Foswiki::Configure::TemplateParser ();
use Foswiki::Configure::UIs::Section   ();
our @ISA = ('Foswiki::Configure::UIs::Section');

# See Foswiki::Configure::UIs::Section
sub renderHtml {
    my ( $this, $section, $root ) = @_;

    my $parser   = Foswiki::Configure::TemplateParser->new;
    my $contents = $parser->getResource(
        'intro.html',
        SYSTEMWEB     => $Foswiki::cfg{SystemWebName},
        USERSWEB      => $Foswiki::cfg{UsersWebName},
        SCRIPTURLPATH => $Foswiki::cfg{ScriptUrlPath},
        SCRIPTSUFFIX  => $Foswiki::cfg{ScriptSuffix},
        ADMINGROUP    => $Foswiki::cfg{SuperAdminGroup},
        RESOURCEURI   => $Foswiki::Configure::resourceURI,
        ACTIONURI     => $Foswiki::Configure::actionURI,
    );

    # do not simply return the contents as we want to have
    # this formatted inside a html container
    return $this->SUPER::renderHtml( $section, $root, $contents );
}

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
