# Copyright (C) 2013-2021 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatEditPlugin::RestUsers;

use strict;
use warnings;

use Foswiki::Func ();
use JSON          ();

sub handle {
    my ( $session, $plugin, $verb, $response ) = @_;

    my @results = ();
    my $request = $session->{request};
    my $term    = $request->param("term");

    my $it             = Foswiki::Func::eachUser();
    my $thisUser       = Foswiki::Func::getWikiName();
    my $useTopicTitles = Foswiki::Func::getContext()->{TopicTitlePluginEnabled};

    while ( $it->hasNext() ) {
        my $user = $it->next();
        next if $term && $user !~ /$term/i;
        next
          if Foswiki::Func::topicExists( $Foswiki::cfg{UsersWebName}, $user )
          && !Foswiki::Func::checkAccessPermission( "VIEW", $thisUser, undef,
            $user, $Foswiki::cfg{UsersWebName} );

        push @results,
          {
            value => $user,
            label => $useTopicTitles
            ? Foswiki::Func::getTopicTitle(
                $Foswiki::cfg{UsersWebName}, $user
              )
            : $user,
          };
    }

    $it = Foswiki::Func::eachGroup();
    while ( $it->hasNext() ) {
        my $group = $it->next();
        next if $term && $group !~ /$term/i;

        push @results,
          {
            value => $group,
            label => $useTopicTitles
            ? Foswiki::Func::getTopicTitle( $Foswiki::cfg{UsersWebName},
                $group )
            : $group,
          };
    }

    @results = sort { $a->{label} cmp $b->{label} } @results;

    my $results = JSON::to_json( \@results, { pretty => 1 } );

    $response->header(
        -status => 200,
        -type   => 'text/plain',
    );
    $response->print($results);

    return "";
}

1;
