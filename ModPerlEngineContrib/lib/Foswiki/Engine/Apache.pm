# mod_perl Runtime Engine of Foswiki - The Free and Open Source Wiki,
# http://foswiki.org/
#
# Copyright (C) 2009 Gilmar Santos Jr, jgasjr@gmail.com and Foswiki
# contributors. Foswiki contributors are listed in the AUTHORS file in the root
# of Foswiki distribution.
#
# This module is based/inspired on Catalyst framework. Refer to
#
# http://search.cpan.org/perldoc?Catalyst
#
# for credits and license details.
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

=begin TML

---+!! package Foswiki::Engine::Apache

Base class that implements mod_perl execution mode.

Refer to Foswiki::Engine documentation for explanation about methos below.

=cut

package Foswiki::Engine::Apache;

use strict;

use Foswiki::Engine;
our @ISA = qw( Foswiki::Engine );

BEGIN {
    if ( $ENV{MOD_PERL} ) {
        my ( $software, $version ) =
          $ENV{MOD_PERL} =~ m{^(\S+)/(\d+(?:[\.\_]\d+)+)};

        $version =~ s/_//g;
        $version =~ s/(\.[^.]+)\./$1/g;

        if ( $software eq 'mod_perl' ) {
            if ( !$Foswiki::cfg{Engine} ) {
                if ( $version >= 1.99922 ) {
                    $Foswiki::cfg{Engine} = 'Foswiki::Engine::Apache2::MP20';
                }
                elsif ( $version >= 1.24 ) {
                    $Foswiki::cfg{Engine} = 'Foswiki::Engine::Apache::MP13';
                }
                else {
                    die qq(Unsupported mod_perl version: $ENV{MOD_PERL} );
                }
            }
            *handler = \&run;
        }

        # suppress stupid warning in CGI::Cookie
        if ( !defined( $ENV{MOD_PERL_API_VERSION} ) ) {
            $ENV{MOD_PERL_API_VERSION} = 1;
        }
    }

    require Carp;
    $SIG{__DIE__} = \&Carp::confess;
}

use Foswiki                  ();
use Foswiki::UI              ();
use Foswiki::Request         ();
use Foswiki::Request::Upload ();
use Foswiki::Response        ();
use File::Spec               ();
use Assert;
use Unicode::Normalize;

sub run {
    my $this = $Foswiki::engine;
    $this->{r} = shift;
    my $req = $this->prepare();

    if ( UNIVERSAL::isa( $req, 'Foswiki::Request' ) ) {
        my $res = Foswiki::UI::handleRequest($req);
        $this->finalize( $res, $req );
    }
    return $this->OK;
}

sub prepareConnection {
    my ( $this, $req ) = @_;
    $req->method( $this->{r}->method );
    $req->remoteAddress(
          $this->{r}->connection->can('remote_ip')
        ? $this->{r}->connection->remote_ip
        : $this->{r}->connection->client_ip
    );
    if ( $INC{'Apache2/ModSSL.pm'} ) {
        $req->secure( $this->{r}->connection->is_https ? 1 : 0 );
    }
    else {
        my $https = $this->{r}->subprocess_env('HTTPS');
        $req->secure( defined $https && uc($https) eq 'ON' ? 1 : 0 );
    }
}

sub prepareQueryParameters {
    my ( $this, $req ) = @_;
    my $queryString = $this->{r}->args;
    $this->SUPER::prepareQueryParameters( $req, $queryString )
      if $queryString;
}

sub prepareHeaders {
    my ( $this, $req ) = @_;

    my %headers = %{ $this->{r}->headers_in() };
    while ( my ( $header, $value ) = each %headers ) {
        $req->header( $header => $value );
    }
    $req->remoteUser( $this->{r}->user );
    if ( $Foswiki::cfg{BehindProxy} ) {
        if ( my $source = $req->header('X-Forwarded-For') ) {
            my $ip = ( split /[, ]+/, $source )[-1];
            $req->remoteAddress($1)
              if defined $ip and $ip =~ /^((?:\d{1,3}\.){3}\d{1,3})$/;
        }
    }
}

sub preparePath {
    my ( $this, $req ) = @_;
    my $action   = ( File::Spec->splitpath( $this->{r}->filename ) )[2];
    my $pathInfo = $this->{r}->path_info;
    if ( defined $Foswiki::cfg{SwitchBoard}{$action} ) {
        $req->action($action);
    }
    else {    # Shorter URL in use. Assume 'view'.
        $req->action('view');

        # mod_perl takes the first component of
        # path_info as 'filename'. This restores
        # the path_info.
        $pathInfo = '/' . $action . $pathInfo;
    }
    $req->pathInfo($pathInfo);

    #SMELL: CGI and FastCGI leave the URI encoded, mod_perl decodes it.
    my $uri = Foswiki::urlEncode( $this->{r}->uri );
    my $qs  = $this->{r}->args;
    $uri .= '?' . $qs if $qs;
    $req->uri($uri);
}

sub prepareBody {
    my ( $this, $req ) = @_;
    my $contentLength = $req->header('Content-Length') || 0;
    return unless $contentLength > 0;

    $this->{query} = $this->queryClass->new( $this->{r} );
}

sub prepareBodyParameters {
    my ( $this, $req ) = @_;
    my $contentLength = $req->header('Content-Length') || 0;
    return unless $contentLength > 0;

    my @plist = $this->{query}->param();
    if (@plist) {
        foreach my $pname (@plist) {
            my @values;
            if ( $this->{query}->can('multi_param') ) {
                @values = $this->{query}->multi_param($pname);
            }
            else {
                @values = ( $this->{query}->param($pname) );
            }
            my $upname = $pname;
            if ($Foswiki::UNICODE) {
                @values = map { NFC( Foswiki::decode_utf8($_) ) } @values;
                $upname = NFC( Foswiki::decode_utf8($pname) );
            }

            $req->bodyParam( -name => $upname, -value => \@values );
            $this->{uploads}->{$upname} = 1
              if scalar $this->{query}->upload($pname);
        }
    }

    # SMELL: There really ought to be a better way to accomplish this.
    # Bit of a hack to support application/json.  It is an "upload" without a
    # filename.  Apache2::Request however doesn't capture the data as POSTDATA.
    # If this finds an unnamed body parameter of type application/json, it
    # converts it to POSTDATA.
    else {
        if ( $req->header('Content-type') =~ m#application/json# ) {
            $this->{query}->read( my $data, $contentLength );
            $data = NFC( Foswiki::decode_utf8($data) ) if $Foswiki::UNICODE;
            $req->bodyParam( -name => 'POSTDATA', -value => $data );
        }
    }
}

sub prepareUploads {
    my ( $this, $req ) = @_;
    my $contentLength = $req->header('Content-Length') || 0;
    return unless $contentLength > 0;

    my %uploads;
    if ( $this->{query}->isa('CGI') ) {
        foreach my $key ( keys %{ $this->{uploads} } ) {
            my $fname = $this->{query}->param($key);
            my $ufname =
              ($Foswiki::UNICODE)
              ? NFC( Foswiki::decode_utf8($fname) )
              : $fname;
            $uploads{$ufname} = new Foswiki::Request::Upload(
                headers => $this->{query}->uploadInfo($fname),
                tmpname => $this->{query}->tmpFileName($fname),
            );
        }
    }
    else {
        foreach my $key ( keys %{ $this->{uploads} } ) {
            my $obj = $this->{query}->upload($key);
            my $ufname =
              ($Foswiki::UNICODE)
              ? NFC( Foswiki::decode_utf8( $obj->filename ) )
              : $obj->filename;
            $uploads{$ufname} = new Foswiki::Request::Upload(
                headers => $obj->info,
                tmpname => $obj->tempname,
            );
        }
    }
    delete $this->{uploads};
    $req->uploads( \%uploads );
}

sub finalizeUploads {
    my ( $this, $res, $req ) = @_;

    $req->delete($_) foreach keys %{ $req->uploads };
    undef $this->{query};
}

sub finalizeHeaders {
    my ( $this, $res, $req ) = @_;
    $this->SUPER::finalizeHeaders( $res, $req );

    # If REDIRECT_STATUS is useful, preserve it. See Foswikitask:Item2549
    # and http://httpd.apache.org/docs/2.2/en/custom-error.html#custom
    my $status;
    if ( defined $ENV{REDIRECT_STATUS} && $ENV{REDIRECT_STATUS} !~ /^2/o ) {
        $status = $ENV{REDIRECT_STATUS};
    }
    elsif ( defined $res->status && $res->status =~ /^\s*(\d{3})/o ) {
        $status = $1;
    }
    else {
        $status = 200;
    }
    $this->{r}->status($status);

    while ( my ( $header, $value ) = each %{ $res->headers } ) {
        if ( lc($header) eq 'content-type' ) {
            $this->{r}->content_type($value);
        }
        elsif ( lc($header) eq 'content-encoding' ) {
            $this->{r}->content_encoding($value);
        }
        elsif ( lc($header) eq 'content-language' ) {
            $this->{r}->content_language($value);
        }
        elsif ( lc($header) eq 'set-cookie' ) {
            foreach ( ref($value) eq 'ARRAY' ? @$value : ($value) ) {

                # Send cookies even if an error occour
                $this->{r}->err_headers_out->add( $header => $_ );
            }
        }
        elsif ( lc($header) ne 'status' ) {
            foreach ( ref($value) eq 'ARRAY' ? @$value : ($value) ) {
                $this->{r}->headers_out->add( $header => $_ );
            }
        }
    }
    $this->{r}->content_type('text/plain') unless $this->{r}->content_type;
}

sub write {
    my ( $this, $data ) = @_;
    if ( !$this->{r}->connection->aborted && defined $data ) {
        return $this->{r}->print($data);
    }
    return undef;
}

1;
