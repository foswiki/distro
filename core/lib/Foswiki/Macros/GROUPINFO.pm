# See bottom of file for license and copyright information
package Foswiki;

use strict;

sub GROUPINFO {
    my ( $this, $params ) = @_;

    my $group = $params->{_DEFAULT};
    my $format = $params->{format};
    my $sep = $params->{separator}; $sep = ', ' unless defined $sep;
    my $limit = $params->{limit} || 100000000;
    my $limited = $params->{limited}; $limited = '' unless defined $limited;
    my $header = $params->{header}; $header = '' unless defined $header;
    my $footer = $params->{footer}; $footer = '' unless defined $footer;

    my $it;#erator
    my @rows;
    if ($group) {
        $it = $this->{users}->eachGroupMember($group);
        $format = '$wikiusername' unless defined $format;
    } else {
        $it = $this->{users}->eachGroup();
        $format = '$name' unless defined $format;
    }
    while ($it->hasNext()) {
        my $cUID = $it->next();
        my $row = $format;
        if ($group) {
            next unless($this->{users}->groupAllowsView( $group ));
            my $wname = $this->{users}->getWikiName( $cUID );
            my $uname = $this->{users}->getLoginName( $cUID );
            my $wuname = $this->{users}->webDotWikiName( $cUID );
            my $change = $this->{users}->groupAllowsChange( $group );

            $row =~ s/\$wikiname/$wname/ge;
            $row =~ s/\$username/$uname/ge;
            $row =~ s/\$wikiusername/$wuname/ge;
            $row =~ s/\$name/$group/g;
            $row =~ s/\$allowschange/$change/ge;
        } else {
            # all groups
            next unless($this->{users}->groupAllowsView( $cUID ));
            my $change = $this->{users}->groupAllowsChange( $cUID );
            
            $row =~ s/\$name/$cUID/g;
            $row =~ s/\$allowschange/$change/ge;
        }
        push(@rows, $row);
        last if (--$limit == 0);
    }
    $footer = $limited.$footer if $limit == 0;
    return expandStandardEscapes($header.join($sep, @rows).$footer);
}

1;
__DATA__
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
