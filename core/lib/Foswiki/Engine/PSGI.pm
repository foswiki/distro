# See bottom of file for license and copyright information

=begin TML

---+!! Class Foswiki::Engine::PSGI

Class that implements default PSGI behavior.

Refer to Foswiki::Engine documentation for explanation about methods below.

=cut

package Foswiki::Engine::PSGI;
use v5.14;

use Assert;
use Plack::Request;
use Unicode::Normalize;
use File::Spec ();
use Encode     ();

use Foswiki::Class;
extends qw(Foswiki::Engine);

use constant HTTP_COMPLIANT => 1;

has psgi => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return Plack::Request->new( $_[0]->env );
    },

    # Import methods used by configure for transparent use.
    handles => [qw(request_uri path_info secure)],
);

sub probe {
    my %params = @_;

    return defined $params{env}{'psgi.version'};
}

around prepareConnection => sub {
    my $orig = shift;
    my $this = shift;

    my $psgi = $this->psgi;
    return {
        remoteAddress => $psgi->address,
        method        => $psgi->method,
        secure        => $psgi->secure,
        serverPort    => $this->env->{SERVER_PORT},
        serverName    => $this->env->{SERVER_NAME},
    };
};

around prepareHeaders => sub {
    my $orig = shift;
    my $this = shift;

    my $hdrObject = $this->psgi->headers;
    my %hdrHash =
      map { $_ => $hdrObject->header($_) } $hdrObject->header_field_names;
    return \%hdrHash;
};

around prepareUser => sub {
    my $orig = shift;
    my $this = shift;
    return $this->psgi->user;
};

around preparePath => sub {
    my $orig = shift;
    my ($this) = @_;

    my $app      = $this->app;
    my $cfgData  = $app->cfg->data;
    my $psgi     = $this->psgi;
    my $pathInfo = $psgi->path_info;

    if ( $pathInfo =~ m/['"]/g ) {
        $pathInfo = substr( $pathInfo, 0, ( ( pos $pathInfo ) - 1 ) );
    }

    my $cgiScriptPath = $psgi->script_name;
    unless ( defined $cgiScriptPath ) {

        # CGI/1.1 (rfc3875) states that the server MUST set
        # SCRIPT_NAME, so if it doens't we have a broken server
        Foswiki::Exception::Engine->throw(
            header => 'Inernal Server Error',
            text   => 'SCRIPT_NAME environment variable not defined',
        );
    }
    $pathInfo =~ s{^$cgiScriptPath(?:/+|$)}{/};
    my $cgiScriptName = $cgiScriptPath;
    $cgiScriptName =~ s/.*?(\w+)(\.\w+)?$/$1/;

    my $action;
    if ( exists $this->env->{FOSWIKI_ACTION} ) {

        # This handles scripts that have set $FOSWIKI_ACTION
        $action = $this->env->{FOSWIKI_ACTION};
    }
    elsif ( exists $cfgData->{SwitchBoard}{$cgiScriptName} ) {

        # This handles other named CGI scripts that have a switchboard entry
        # but haven't set $FOSWIKI_ACTION (old-style run scripts)
        $action = $cgiScriptName;
    }
    elsif ( length $pathInfo > 1 ) {

        # Use the first path el after the script
        # name as the function
        $pathInfo =~ m{^/([^/]+)(.*)};
        my $first = $1;    # implicit untaint OK; checked below
        if ( exists $cfgData->{SwitchBoard}{$first} ) {

            # The path is of the form script/function/...
            $action = $first;
            $pathInfo = $2 || '';
        }
    }
    $action ||= 'view';
    ASSERT( defined $pathInfo ) if DEBUG;
    return {
        action    => $action,
        path_info => $pathInfo,
        uri       => $psgi->uri,
    };
};

around prepareBodyParameters => sub {
    my $orig = shift;
    my $this = shift;

    my $psgi = $this->psgi;
    return [] unless $psgi->content_length;

    my $params = $psgi->body_parameters;
    my @params;
    foreach my $pname ( $params->keys ) {
        my $upname = NFC( Foswiki::decode_utf8($pname) );
        my @values =
          map { NFC( Foswiki::decode_utf8($_) ) } $params->get_all($pname);
        my $param = {
            -name  => $upname,
            -value => \@values,
        };
        push @params, $param;
    }
    return \@params;
};

around prepareQueryParameters => sub {
    my $orig = shift;
    my $this = shift;

    my $psgi = $this->psgi;

    my $params = $psgi->query_parameters;
    my @params;
    foreach my $pname ( $params->keys ) {
        push @params, {
            -name  => NFC( Foswiki::decode_utf8($pname) ),
            -value => [
                map { NFC( Foswiki::decode_utf8($_) ) } $params->get_all($pname)
            ],

        };
    }
    return \@params;
};

around preparePostData => sub {
    my $orig = shift;
    my $this = shift;
    return $this->psgi->raw_body;
};

around prepareUploads => sub {
    my $orig = shift;
    my ( $this, $req ) = @_;

    my @uploads;
    my $psgi = $this->psgi;
    foreach my $key ( keys %{ $psgi->uploads } ) {
        my $upload   = $psgi->upload($key);
        my $filename = Encode::decode_utf8( $upload->filename );
        my $basename = ( File::Spec->splitpath($filename) )[2];

        # SMELL Not only filenames but all data should be passed thru
        # decode_utf8.
        push @uploads,
          {
            filename    => $filename,
            basename    => $basename,
            tmpname     => $upload->path,
            headers     => $upload->headers,
            contentType => $upload->content_type,
            size        => $upload->size,
          };
    }
    return \@uploads;
};

around finalizeReturn => sub {
    my $orig = shift;
    my $this = shift;

    return shift;
};

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
