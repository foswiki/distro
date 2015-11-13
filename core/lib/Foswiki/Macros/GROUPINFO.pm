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

sub GROUPINFO {
    my ( $this, $params ) = @_;

    my $group  = $params->{_DEFAULT};
    my $format = $params->{format};
    my $sep    = $params->{separator};
    $sep = ', ' unless defined $sep;
    my $limit = $params->{limit} || 100000000;
    my $limited = $params->{limited};
    $limited = '' unless defined $limited;
    my $header = $params->{header};
    $header = '' unless defined $header;
    my $footer = $params->{footer};
    $footer = '' unless defined $footer;
    my $show = $params->{show};
    $show = 'all' unless defined $show;
    my $zeroresults = $params->{zeroresults};
    my $expand      = $params->{expand};
    $expand = '1' unless defined $expand;

    $expand = Foswiki::Func::isTrue($expand);

    my $it;    #erator
    my @rows;

    if ($group) {
        if ( $group =~ m/[\.\/]/ ) {    # Contains a web/topic separator
            ( my $web, $group ) =
              Foswiki::Func::normalizeWebTopicName( $Foswiki::cfg{UsersWebName},
                $group );
            return '' unless ( $web eq $Foswiki::cfg{UsersWebName} );
        }

        $it = $this->{users}->eachGroupMember( $group, { expand => $expand } );
        $format = '$wikiusername' unless defined $format;
    }
    else {
        $it = $this->{users}->eachGroup();
        $format = '$name' unless defined $format;
    }
    while ( $it->hasNext() ) {
        my $cUID = $it->next();
        my $row  = $format;
        if ($group) {
            next unless ( $this->{users}->groupAllowsView($cUID) );
            my $change = $this->{users}->groupAllowsChange($cUID);

            #filter by show="" param
            next if ( ( $show eq 'allowchange' ) and ( not $change ) );
            next if ( ( $show eq 'denychange' )  and ($change) );
            if ( $show =~ m/allowchange\((.*)\)/ ) {
                next
                  if (
                    not $this->{users}->groupAllowsChange(
                        $group, $this->{users}->getCanonicalUserID($1)
                    )
                  );
            }
            if ( $show =~ m/denychange\((.*)\)/ ) {
                next
                  if (
                    $this->{users}->groupAllowsChange(
                        $group, $this->{users}->getCanonicalUserID($1)
                    )
                  );
            }

            my $wname  = $this->{users}->getWikiName($cUID);
            my $uname  = $this->{users}->getLoginName($cUID) || $wname;
            my $wuname = $this->{users}->webDotWikiName($cUID);

            $row =~ s/\$wikiname/$wname/ge;
            $row =~ s/\$username/$uname/ge;
            $row =~ s/\$wikiusername/$wuname/ge;
            $row =~ s/\$name/$group/g;

            #TODO: should return 0 if $1 is not a valid user?
            $row =~
s/\$allowschange\((.*?)\)/$this->{users}->groupAllowsChange( $group , $this->{users}->getCanonicalUserID($1))/ges;
            $row =~ s/\$allowschange/$change/ge;
        }
        else {

            # all groups
            next unless ( $this->{users}->groupAllowsView($cUID) );
            my $change = $this->{users}->groupAllowsChange($cUID);

            #filter by show="" param
            next if ( ( $show eq 'allowchange' ) and ( not $change ) );
            next if ( ( $show eq 'denychange' )  and ($change) );
            if ( $show =~ m/allowchange\((.*)\)/ ) {
                next
                  if (
                    not $this->{users}->groupAllowsChange(
                        $cUID, $this->{users}->getCanonicalUserID($1)
                    )
                  );
            }
            if ( $show =~ m/denychange\((.*)\)/ ) {
                next
                  if (
                    $this->{users}->groupAllowsChange(
                        $cUID, $this->{users}->getCanonicalUserID($1)
                    )
                  );
            }

            $row =~ s/\$name/$cUID/g;

            #TODO: should return 0 if $1 is not a valid user?
            $row =~
s/\$allowschange\((.*?)\)/$this->{users}->groupAllowsChange( $cUID , $this->{users}->getCanonicalUserID($1))/ges;
            $row =~ s/\$allowschange/$change/ge;
        }
        push( @rows, $row );
        last if ( --$limit == 0 );
    }
    $footer = $limited . $footer if $limit == 0;

    my $result;
    if ( defined($zeroresults) and ( scalar(@rows) <= 0 ) ) {
        $result = $zeroresults;
    }
    else {
        $result = $header . join( $sep, @rows ) . $footer;
    }
    return expandStandardEscapes($result);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
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
