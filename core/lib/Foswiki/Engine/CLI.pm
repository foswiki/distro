# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Engine::CLI

Class that implements CGI scripts functionality when called from
command line or cron job

Refer to Foswiki::Engine documentation for explanation about methos below.

=cut

package Foswiki::Engine::CLI;

use strict;
use warnings;
use Assert;

use Foswiki::Engine ();
our @ISA = ('Foswiki::Engine');

use Foswiki::Request         ();
use Foswiki::Request::Upload ();
use Foswiki::Response        ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub run {
    my $this = shift;
    my @args = @ARGV;    # Copy, so original @ARGV doesn't get modified
    while ( scalar(@args) ) {
        my $name;
        my $arg = shift @args;
        if ( $arg =~ m/^-?([a-z0-9_+]+)=(.*)$/i ) {
            ( $name, $arg ) = ( TAINT($1), TAINT($2) );
        }
        elsif ( $arg =~ m/^-([a-z0-9_+]+)/i ) {
            ( $name, $arg ) = ( TAINT($1), shift(@args) );
        }
        if ( $name && $name eq 'user' ) {
            $this->{user} = $arg;
        }
        elsif ($name) {
            push @{ $this->{plist} }, $name
              unless exists $this->{params}->{$name};
            push @{ $this->{params}->{$name} }, $arg;
        }
        else {
            $this->{path_info} = $arg;    # keep it tainted
        }
    }
    my $req = $this->prepare;
    if ( UNIVERSAL::isa( $req, 'Foswiki::Request' ) ) {
        my $res = Foswiki::UI::handleRequest($req);
        $this->finalize( $res, $req );
    }
}

sub prepareConnection {
    my ( $this, $req ) = @_;
    $req->remoteAddress('127.0.0.1');
    $req->method( $ENV{FOSWIKI_ACTION} );
}

sub prepareQueryParameters {
    my ( $this, $req ) = @_;
    foreach my $name ( @{ $this->{plist} } ) {
        $req->param( -name => $name, -value => $this->{params}->{$name} );
    }
    delete $this->{plist};
    delete $this->{params};
}

sub prepareHeaders {
    my ( $this, $req ) = @_;
    if ( defined $this->{user} ) {
        $req->remoteUser( $this->{user} );
        delete $this->{user};
    }
    else {
        if ( $Foswiki::cfg{Register}{AllowLoginName} ) {
            $req->remoteUser( $Foswiki::cfg{AdminUserLogin} );
        }
        else {
            $req->remoteUser( $Foswiki::cfg{AdminUserWikiName} );
        }
    }
}

sub preparePath {
    my ( $this, $req ) = @_;
    if ( $ENV{FOSWIKI_ACTION} ) {
        $req->action( $ENV{FOSWIKI_ACTION} );
    }
    else {
        require File::Spec;
        $req->action( ( File::Spec->splitpath($0) )[2] );
    }
    if ( exists $this->{path_info} ) {
        $req->pathInfo( $this->{path_info} );
        delete $this->{path_info};
    }
}

sub prepareUploads {
    my ( $this, $req ) = @_;
    my %uploads;

    #SMELL: CLI and CGI appear to support multiple uploads
    # but Foswiki::UI::Upload only processes a single upload.
    foreach my $fname ( @{ $req->{param}{filepath} } ) {
        $uploads{$fname} = new Foswiki::Request::Upload(
            headers => {},
            tmpname => $fname
        );
    }
    delete $this->{uploads};
    $req->uploads( \%uploads );
}

sub prepareCookies { }

sub finalizeHeaders { }

sub write {
    my ( $this, $buffer ) = @_;
    print $buffer;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This module is based/inspired on Catalyst framework. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
for credits and license details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
