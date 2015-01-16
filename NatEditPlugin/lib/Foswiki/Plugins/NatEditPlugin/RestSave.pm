# Copyright (C) 2013-2015 Michael Daum http://michaeldaumconsulting.com
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
use Foswiki::Validation    ();
use Encode                 ();
use Error qw( :try );

sub handle {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request = $session->{request};

    # transform to site charset
    foreach my $key ( $request->multi_param() ) {
        my @val = $request->multi_param($key);

        # hack to prevent redirecting
        if ( $key eq 'redirectto' && @val && $val[0] eq '' ) {

            #print STDERR "deleting bogus redirectto\n";
            $request->delete($key);
            next;
        }

        if ( ref $val[0] eq 'ARRAY' ) {
            $request->param( $key, [ map( toSiteCharSet($_), @{ $val[0] } ) ] );
        }
        else {
            $request->param( $key, [ map( toSiteCharSet($_), @val ) ] );
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
        $status = 419;
    };

    # clear redirect enforced by a checkpoint action
    $response->deleteHeader( "Location", "Status" );
    $response->pushHeader( "Status", $status );

    # add validation key to HTTP header, if required
    unless ( $response->getHeader('X-Foswiki-Validation') ) {

        my $cgis = $session->getCGISession();
        my $context =
          $request->url( -full => 1, -path => 1, -query => 1 ) . time();

        my $usingStrikeOne = $Foswiki::cfg{Validation}{Method} eq 'strikeone';

        $response->pushHeader( 'X-Foswiki-Validation',
            _generateValidationKey( $cgis, $context, $usingStrikeOne ) );
    }

    return ( defined $error ) ? stringifyError($error) : '';
}

# compatibility wrapper
sub _generateValidationKey {

    my $nonce;
    if ( Foswiki::Validation->can("generateValidationKey") ) {
        $nonce = Foswiki::Validation::generateValidationKey(@_);
    }
    else
    { # extract from "<input type='hidden' name='validation_key' value='?$nonce' />";

        my $html = Foswiki::Validation::addValidationKey(@_);
        if ( $html =~ /value='\?(.*?)'/ ) {
            $nonce = $1;
        }
    }

    return $nonce;
}

sub stringifyError {
    my $error = shift;

    my $s = '';

    $s .= $error->{-text} if defined $error->{-text};
    $s .= ' ' . join( ',', @{ $error->{params} } )
      if defined $error->{params};

    return $s;
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
