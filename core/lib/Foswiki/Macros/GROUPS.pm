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

# Legacy
sub GROUPS {
    my ( $this, $params ) = @_;

    my $groups = $this->{users}->eachGroup();
    my @table;
    while ( $groups->hasNext() ) {
        my $group = $groups->next();
        next unless ( $this->{users}->groupAllowsView($group) );

        # Nop it to prevent wikiname expansion unless the topic exists.
        my $groupLink = "<nop>$group";
        $groupLink = '[[' . $Foswiki::cfg{UsersWebName} . ".$group][$group]]"
          if ( $this->topicExists( $Foswiki::cfg{UsersWebName}, $group ) );
        my $descr        = "| $groupLink |";
        my $it           = $this->{users}->eachGroupMember($group);
        my $limit_output = 32;
        while ( $it->hasNext() ) {
            my $user = $it->next();
            next unless ( $this->{users}->groupAllowsView($user) );
            $descr .= ' [['
              . $this->{users}->webDotWikiName($user) . ']['
              . $this->{users}->getWikiName($user) . ']]';
            if ( $limit_output == 0 ) {
                $descr .= '<div>%MAKETEXT{"user list truncated"}%</div>';
                last;
            }
            $limit_output--;
        }
        push( @table, "$descr |" );
    }

    return '| *Group* | *Members* |' . "\n" . join( "\n", sort @table );
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
