# See bottom of file for license and copyright information
package Foswiki::Configure::ImageTest;

=begin TML

---+ package Foswiki::Configure::ImageTest

Every request that goes through Foswiki::Engine ends up in
Foswik::UI::handleRequest.
If a request's query includes 'configurationTest', this module
is called to respond.

This mechanism allows configure to test the path through the webserver
to the request dispatcher.  We respond with a small image. If the image
appears, the path is clear, and any issues can be addressed without
worrying about basic server configuration.

A text diagnostic is also provided to assist with debugging webserver
rewrite rules, for those webservers that provide apache-style
SCRIPT_NAME and SCRIPT_URI values.

=cut

use warnings;
use strict;

use CGI ();
use CGI::Session;
use File::Temp;
use MIME::Base64;
use JSON ();

my @headers = ( "Cache-Control" => "no-cache", -expires => "-1d" );

sub _json {
    my( $req, $res, $code, $data ) = @_;
    $res->header( -type => "application/json", -status => $code, @headers );
    $res->print(JSON->new->allow_nonref->encode($data));
    return $res;
}

sub respond {
    my $req = shift;

    my $res = Foswiki::Response->new;

    # Matches Configure::Dispatch
# SMELL: WTF does this have to be so complex?
#    my $sid = $req->cookie('FOSWIKI_CONFIGURATION') || undef;
#    if ( defined $sid && $sid =~ m/^([\w_-]+)$/ ) {
#        $sid = $1;
#    }
#    else {
#        return _json($req, $res, 403, "Forbidden, Not authorized by configure");
#    }
#    my $session =
#      CGI::Session->load( Foswiki::Configure::SESSION_DSN, $sid,
#        { Directory => File::Spec->tmpdir } )
#      or die CGI::Session->errstr();
#
#    unless( $req->auth_type
#        || ( !$session->is_expired && !$session->is_new
#             && ($session->param("_RES_OK") || $session->param("_PASSWD_OK")) ) ) {
#        return _json($req, $res, 403, "Forbidden, Expired or no session");
#    }

    # Respond with embedded image

    my $pinfo = $req->pathInfo;
    unless( $pinfo && $pinfo =~ m,^/Web/Topic/(Img|Env)/(\w+), ) {
        return _json( $req, $res, 403, "Forbidden, Incorrect path info " . ($pinfo || "none") );
    }

    if( $1 eq "Env" ) {
        my $data =  { action => $2 };

        my @cgivars = (
            # CGI 'Standard'
            qw/AUTH_TYPE CONTENT_LENGTH CONTENT_TYPE GATEWAY_INTERFACE/,
            qw/PATH_INFO PATH_TRANSLATED QUERY_STRING REMOTE_ADDR/,
            qw/REMOTE_HOST REMOTE_IDENT REMOTE_USER REQUEST_METHOD/,
            qw/SCRIPT_NAME SERVER_NAME SERVER_PORT SERVER_PROTOCOL/,
            qw/SERVER_SOFTWARE/,
            # Apache/common extensions
            qw/DOCUMENT_ROOT PATH_TRANSLATED REQUEST_URI SCRIPT_FILENAME/,
            qw/SCRIPT_URI SCRIPT_URL SERVER_ADDR SERVER_ADMIN SERVER_SIGNATURE/,
            # HTTP headers & SSL data
            grep( /^(?:HTTP|SSL)_/, keys %ENV ),
            # Other
            qw/PATH MOD_PERL MOD_PERL_API_VERSION/,
            );

        foreach my $var (sort @cgivars) {
            next unless( exists $ENV{$var} );
            $data->{ENV}->{$var} = $ENV{$var};
        }

        $data->{'@INC'} = [ @INC ];
        my @gids;
        eval {
            @gids = map { lc getgrgid($_) } split( ' ', $( );
        };
        if( $@ ) {
            @gids = ( lc( qx(sh -c '( id -un ; id -gn) 2>/dev/null' 2>nul ) || 'n/a' ));
        }
        $data->{groups} = [ @gids ];

        $data->{uid} = getlogin() || getpwuid($>);
        $data->{umask} = umask;

        return _json( $req, $res, 200, $data );
    }

   $res->header( -type => 'image/png', -status => '200', @headers );
   $res->print(decode_base64( '
iVBORw0KGgoAAAANSUhEUgAAABAAAAAPCAYAAADtc08vAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJ
bWFnZVJlYWR5ccllPAAAA2tpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdp
bj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6
eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0
MDk0OSwgMjAxMC8xMi8wNy0xMDo1NzowMSAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJo
dHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlw
dGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wUmlnaHRzPSJodHRwOi8vbnMuYWRvYmUuY29tL3hh
cC8xLjAvcmlnaHRzLyIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9t
bS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3Vy
Y2VSZWYjIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcFJpZ2h0
czpNYXJrZWQ9IkZhbHNlIiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOjkwRTMzOTczMUU3MjEx
RTJBMzkyRDNBRkQyREIxMDc4IiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOjkwRTMzOTcyMUU3
MjExRTJBMzkyRDNBRkQyREIxMDc4IiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBD
UzMgTWFjaW50b3NoIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InV1aWQ6
NURENzAxNUY3OEQzREUxMTgwQUY4NzZCMzRFMTJDMEUiIHN0UmVmOmRvY3VtZW50SUQ9InV1aWQ6
RDg0MzU4MDg3OEQzREUxMTgwQUY4NzZCMzRFMTJDMEUiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwv
cmRmOlJERj4gPC94OnhtcG1ldGE+IDw/eHBhY2tldCBlbmQ9InIiPz55rqk+AAABfklEQVR42mJk
OMOADryh2BiIDYD4AhCfBeKtUIwCGJEMEAXimUAcyIAbrAfidCB+DRNggtIqQHyJgGYQCAwVDL1V
JlGmiWwAMxCvAGIJApoZUkVSGZYoLhHw4ffZg2xAONS/eEGmaCbDLPlZDGyMbAy2PLZS2aLZlTAD
omCKeJl5GVgZWbFqniY3Dc6f/Goyw9TXU60hvDMMr4D4v8pllf+3f9z+P+XVlP8gPgxXPqn8jwym
vZoGk3sOiQCowlNfTsEVLXyz8D/jGcb/Dc8aUDSD+EiG/4QZAHZB+N3w/9//focrvvr96v+f/37C
+bVPa1FchuyCLTDBwDuB/3/8+/EfHWDR/B+qDxyIK+Gp5MN6htj7sQy///8G8/8BYc6jHIbm583Y
ImYxLCUyg90BSbZg4MbnxrBAYQED0M8Ms97MwpUig5CTMiglHiYmMQHBCyA2hNLwpHwHiPWgJjMQ
yAt6MM3omQkGQoA4AYjNoBkMlHFOAfECIF6DrhggwACh3ufkau2NHAAAAABJRU5ErkJggg==
' ));
    return $res;
}
1;
#>>>
__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
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
