# JSON-RPC for Foswiki
#
# Copyright (C) 2011-2015 Michael Daum http://michaeldaumconsulting.com
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
use v5.14;

use Assert;

use Compress::Zlib ();
use JSON           ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);
with qw(Foswiki::AppObject);

use constant TRACE => 0;    # toggle me

has id      => ( is => 'rw', );
has message => ( is => 'rw', );
has code    => ( is => 'rw', lazy => 1, default => 0, );
has json => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $json = JSON->new;
        $json->pretty(DEBUG);
        $json->convert_blessed(1);
        return $json;
    },
);

##############################################################################
# static constructor
sub print {
    my $class = shift;
    my $app   = shift;

    my $this     = $app->create( $class, @_ );
    my $response = $this->app->response;
    my $text     = $this->encode;
    my $hopts    = {
        'status' => $this->code ? 500 : 200,
        'Content-Type' => 'application/json',
    };

    # SMELL: code duplication with core ($Foswiki::UNICODE only)
    my $encoding = $app->env->{'HTTP_ACCEPT_ENCODING'} || 'gzip';
    $encoding =~ s/^.*(x-gzip|gzip).*/$1/g;
    my $compressed = 0;

    if ( $Foswiki::cfg{HttpCompress} || $app->env->{'SPDY'} ) {
        $hopts->{'Content-Encoding'} = $encoding;
        $hopts->{'Vary'}             = 'Accept-Encoding';
        $text                        = Encode::encode_utf8($text);
        $text                        = Compress::Zlib::memGzip($text);
        $compressed                  = 1;
    }

    $response->setDefaultHeaders($hopts);

    if ($compressed) {
        $response->body($text);
    }
    else {
        $response->print($text);
    }
}

################################################################################
sub isError {
    my $this = shift;

    return ( $this->code == 0 ) ? 0 : 1;
}

################################################################################
sub encode {
    my $this = shift;

    my $code    = $this->code;
    my $message = $this->message;

    if ( $this->isError ) {
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

    my $id = $this->id;
    $message->{id} = $id if defined $id;

    return $this->json->encode($message);
}

1;
