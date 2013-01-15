# Copyright (C) 2013 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatEditPlugin::RestSave;

use strict;
use warnings;
use Foswiki::UI::Save      ();
use Foswiki::OopsException ();
use Encode                 ();
use Error qw( :try );

sub handle {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $query = $session->{request};

    # transform to site charset
    foreach my $key ( $query->param() ) {
        my @val = $query->param($key);

        # hack to prevent redirecting
        if ( $key eq 'redirectto' && @val && $val[0] eq '' ) {

            #print STDERR "deleting bogus redirectto\n";
            $query->delete($key);
            next;
        }

        if ( ref $val[0] eq 'ARRAY' ) {
            $query->param( $key, [ map( toSiteCharSet($_), @{ $val[0] } ) ] );
        }
        else {
            $query->param( $key, [ map( toSiteCharSet($_), @val ) ] );
        }
    }

    # do a normal save
    my $error;
    my $status = 200;
    try {
        Foswiki::UI::Save::save($session);

        # get a new lease
        my $topicObject =
          Foswiki::Meta->new( $session, $session->{webName},
            $session->{topicName} );
        $topicObject->setLease( $Foswiki::cfg{LeaseLength} );

    }
    catch Foswiki::OopsException with {
        $error  = shift;
        $status = 500;
    };

    # clear redirect enforced by a checkpoint action
    $response->deleteHeader( "Location", "Status" );
    $response->pushHeader( "Status", $status );

    return ( defined $error ) ? $error->stringify : 'OK';
}

sub toSiteCharSet {
    my $string = shift;

    my $charSet = Encode::resolve_alias( $Foswiki::cfg{Site}{CharSet} );
    return $string if ( !$charSet || $charSet =~ m/^utf-?8$/i );

    # converts to {Site}{CharSet}, generating HTML NCR's when needed
    my $octets = Encode::decode( 'utf-8', $string );
    return Encode::encode( $charSet, $octets, &Encode::FB_HTMLCREF() );
}

1;
