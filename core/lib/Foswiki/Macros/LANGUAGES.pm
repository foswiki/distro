# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub LANGUAGES {
    my ( $this, $params ) = @_;
    my $format    = $params->{format}    // "   * \$langname";
    my $separator = $params->{separator} // "\n";
    $separator =~ s/\\n/\n/g;
    my $selection = $params->{selection} // '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} // 'selected="selected"';

    # $languages is a hash reference:
    my $languages = $this->i18n->enabled_languages();

    my @tags = sort( keys( %{$languages} ) );

    my $result = '';
    my $i      = 0;
    foreach my $lang (@tags) {
        my $item = $format;
        my $name = ${$languages}{$lang};
        $item =~ s/\$langname/$name/g;
        $item =~ s/\$langtag/$lang/g;
        my $mark = ( $selection =~ m/ \Q$lang\E / ) ? $marker : '';
        $item =~ s/\$marker/$mark/g;
        $result .= $separator if $i;
        $result .= $item;
        $i++;
    }
    $result = Foswiki::expandStandardEscapes($result);

    return $result;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
