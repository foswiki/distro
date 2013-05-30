# JSON-RPC for Foswiki
#
# Copyright (C) 2011-2013 Michael Daum http://michaeldaumconsulting.com
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
#
# As per the GPL, removal of this notice is prohibited.

package Foswiki::Contrib::JsonRpcContrib::Response;

use strict;
use warnings;

use JSON ();
use constant DEBUG => 0;    # toggle me

################################################################################
sub new {
    my $class   = shift;
    my $session = shift;

    my $this = {
        session => $session,
        @_
    };

    return bless( $this, $class );
}

##############################################################################
# static constructor
sub print {
    my $class   = shift;
    my $session = shift;

    my $this = $class->new( $session, @_ );

    $this->{session}->{response}->header(
        -status => $this->code() ? 500 : 200,
        -type => 'text/plain',
    );

    $this->{session}->{response}->print( $this->encode() );
}

##############################################################################
sub id {
    my ( $this, $value ) = @_;

    $this->{id} = $value if defined $value;
    return $this->{id};
}

##############################################################################
sub code {
    my ( $this, $value ) = @_;

    $this->{code} = $value if defined $value;
    return ( $this->{code} || 0 );
}

##############################################################################
sub message {
    my ( $this, $value ) = @_;

    $this->{message} = $value if defined $value;
    return $this->{message};
}

################################################################################
sub isError {
    my $this = shift;

    return ( $this->code() == 0 ) ? 0 : 1;
}

################################################################################
sub encode {
    my $this = shift;

    my $code    = $this->code();
    my $message = $this->message();

    if ( $this->isError() ) {
        $message = {
            jsonrpc => "2.0",
            error   => {
                code    => $code,
                message => $message,
            },
        };
    }
    else {
        $message = {
            jsonrpc => "2.0",
            result  => $message,
        };
    }

    my $id = $this->id();
    $message->{id} = $id if defined $id;

    return $this->parser->convert_blessed->encode($message);
}

##############################################################################
sub parser {
    my $this = shift;

    unless ( defined $this->{parser} ) {
        $this->{parser} = new JSON;
    }

    return $this->{parser};
}

1;
