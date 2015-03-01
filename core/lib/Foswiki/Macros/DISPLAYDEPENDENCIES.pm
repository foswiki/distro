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

sub DISPLAYDEPENDENCIES {
    my ( $this, $params ) = @_;

    my $web       = $params->{web}    || $this->{webName};
    my $topic     = $params->{topic}  || $this->{topicName};
    my $header    = $params->{header} || '';
    my $footer    = $params->{footer} || '';
    my $format    = $params->{format} || '   1 [[$web.$topic]]';
    my $separator = $params->{sep}    || $params->{separator} || "\n";
    my $exclude = $params->{exclude};

    ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

    my $deps = $this->{cache}->getDependencies( $web, $topic );
    my @lines;
    my $thisWeb;
    my $thisTopic;
    foreach my $dep ( sort @$deps ) {
        next if $exclude && $dep =~ m/$exclude/;
        $dep =~ m/^(.*)[\.\/](.*?)$/;
        $thisWeb   = $1;
        $thisTopic = $2;
        my $text = $format;
        $text =~ s/\$web/$thisWeb/g;
        $text =~ s/\$topic/$thisTopic/g;
        push @lines, $text;
    }
    return '' unless @lines;
    return expandStandardEscapes(
        $header . join( $separator, @lines ) . $footer );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
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
