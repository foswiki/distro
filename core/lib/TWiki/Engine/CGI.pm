# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This module is based/inspired on Catalyst framework. Refer to
#
# http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
# 
# for credits and liscence details.
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

=begin twiki

---+!! package TWiki::Engine::CGI

Class that implements default CGI behavior.

Refer to TWiki::Engine documentation for explanation about methos below.

=cut

package TWiki::Engine::CGI;

use strict;
use base 'TWiki::Engine';
use TWiki::Request;
use TWiki::Request::Upload;
use TWiki::Response;
use Assert;

sub run { 
    my $this = shift;
    my $req = $this->prepare;
    if ( UNIVERSAL::isa($req, 'TWiki::Request') ) {
        my $res = TWiki::UI::handleRequest($req);
        $this->finalize( $res, $req );
    }
}

sub prepareConnection {
    my ( $this, $req ) = @_;

    $req->remoteAddress( $ENV{REMOTE_ADDR} );
    $req->method( $ENV{REQUEST_METHOD} );

    if ( $ENV{HTTPS} && uc( $ENV{HTTPS} ) eq 'ON' ) {
        $req->secure(1);
    }

    if ( $ENV{SERVER_PORT} && $ENV{SERVER_PORT} == 443 ) {
        $req->secure(1);
    }
}

sub prepareQueryParameters {
    my ( $this, $req ) = @_;
    $this->SUPER::prepareQueryParameters($req, $ENV{QUERY_STRING})
        if $ENV{QUERY_STRING};
}

sub prepareHeaders {
    my ( $this, $req ) = @_;
    foreach my $header ( keys %ENV ) {
        next unless $header =~ /^(?:HTTP|CONTENT|COOKIE)/i;
        ( my $field = $header ) =~ s/^HTTPS?_//;
        $req->header( $field => $ENV{$header} );
    }
    $req->remoteUser( $ENV{REMOTE_USER} );
}

sub preparePath {
    my ( $this, $req ) = @_;

    # SMELL: "The Microsoft Internet Information Server is broken with
    # respect to additional path information. If you use the Perl DLL
    # library, the IIS server will attempt to execute the additional
    # path information as a Perl script. If you use the ordinary file
    # associations mapping, the path information will be present in the
    # environment, but incorrect. The best thing to do is to avoid using
    # additional path information."
    
    # Clean up PATH_INFO problems, e.g.  Support.CobaltRaqInstall.  A valid
    # PATH_INFO is '/Main/WebHome', i.e. the text after the script name;
    # invalid PATH_INFO is often a full path starting with '/cgi-bin/...'.
    my $pathInfo = $ENV{PATH_INFO} || '';
    unless ( defined $ENV{SCRIPT_NAME} ) {
        # CGI/1.1 (rfc3875) states that the server MUST set
        # SCRIPT_NAME, so if it doens't we have a broken server
        my $reason = 'SCRIPT_NAME environment variable not defined';
        my $res = new TWiki::Response();
        $res->header(-type => 'text/html', -status => 500);
        my $html = CGI::start_html( '500 - Internal Server Error' );
        $html .= CGI::h1('Internal Server Error');
        $html .= CGI::p( $reason );
        $html .= CGI::end_html();
        $res->body($html);
        throw TWiki::EngineException(500, $reason, $res);
    }
    my $cgiScriptPath = $ENV{SCRIPT_NAME};
    $pathInfo =~ s{$cgiScriptPath/}{/}i;
    my $cgiScriptName = $cgiScriptPath;
    $cgiScriptName =~ s/.*?(\w+)(\.\w+)?$/$1/;

    my $action;
    if( exists $ENV{TWIKI_ACTION} ) {
        # This handles scripts that have set $TWIKI_ACTION
        $action = $ENV{TWIKI_ACTION};
    }
    elsif( exists $TWiki::cfg{SwitchBoard}{$cgiScriptName} ) {
        # This handles other named CGI scripts that have a switchboard entry
        # but haven't set $TWIKI_ACTION (old-style run scripts)
        $action = $cgiScriptName;
    }
    elsif( length $pathInfo > 1 ) {
        # This handles twiki_cgi; use the first path el after the script
        # name as the function
        $pathInfo =~ m{^/([^/]+)(.*)};
        my $first = $1 || '';
        if( exists $TWiki::cfg{SwitchBoard}{$first} ) {
            # The path is of the form script/function/...
            $action   = $first;
            $pathInfo = $2 || '';
        }
    }
    $action ||= 'view';
    ASSERT( defined $pathInfo ) if DEBUG;
    $req->action($action);
    $req->pathInfo( $pathInfo );
    $req->uri( $ENV{REQUEST_URI}
          || $req->url( -absolute => 1, -path => 1, -query => 1 ) );
}

sub prepareBody {
    my ( $this, $req ) = @_;
   
    return unless $ENV{CONTENT_LENGTH};
    my $cgi = new CGI();
    my $err = $cgi->cgi_error;
    throw TWiki::EngineException($1, $2)
        if defined $err && $err =~ /\s*(\d{3})\s*(.*)/o;
    $this->{cgi} = $cgi;
}

sub prepareBodyParameters {
    my ( $this, $req ) = @_;
    
    return unless $ENV{CONTENT_LENGTH};
    my @plist = $this->{cgi}->param();
    foreach my $pname ( @plist ) {
        my @values = $this->{cgi}->param($pname);
        $req->bodyParam( -name => $pname, -value => \@values );
        $this->{uploads}->{$pname} = 1 if scalar $this->{cgi}->upload($pname);
    }
}

sub prepareUploads {
    my ( $this, $req ) = @_;

    return unless $ENV{CONTENT_LENGTH};
    my %uploads;
    foreach my $key ( keys %{ $this->{uploads} } ) {
        my $fname = $this->{cgi}->param($key);
        $uploads{$fname} = new TWiki::Request::Upload(
            headers => $this->{cgi}->uploadInfo($fname),
            tmpname => $this->{cgi}->tmpFileName($fname),
        );
    }
    delete $this->{uploads};
    $req->uploads( \%uploads );
}

sub finalizeUploads {
    my ( $this, $req ) = @_;

    $req->delete($_) foreach keys %{ $req->uploads };
    undef $this->{cgi};
}

sub finalizeHeaders {
    my ( $this, $res, $req ) = @_;
    
    $this->SUPER::finalizeHeaders( $res, $req );
    foreach my $header ( keys %{ $res->headers } ) {
        print $header . ': ' . $_ . $this->CRLF
            foreach $res->getHeader($header);
    }
    print $this->CRLF;
}

sub write {
    my ( $this, $buffer ) = @_;
    print $buffer;
}

1;
