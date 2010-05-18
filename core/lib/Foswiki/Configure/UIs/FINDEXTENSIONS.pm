# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::FINDEXTENSIONS;

use strict;

use Foswiki::Configure::UIs::Section ();
our @ISA = ('Foswiki::Configure::UIs::Section');

sub renderHtml {
    my ( $this, $section, $root, $output ) = @_;

    # Check that the extensions UI is loadable
    my $bad = 0;
    foreach my $module qw(Foswiki::Configure::UIs::EXTEND) {
        eval "use $module ()";
        if ($@) {
            $bad = 1;
            last;
        }
    }

    my $template =
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('findextensionsintro');
    Foswiki::Configure::UI::getTemplateParser()->parse(
        $template,
        {
            'hasError'   => $bad,
            'scriptName' => Foswiki::Configure::Util::getScriptName(),
        }
    );
    $output .= $template;
    $output = $this->SUPER::renderHtml( $section, $root, $output );
    return $output;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
