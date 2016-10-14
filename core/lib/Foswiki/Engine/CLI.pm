# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Engine::CLI

Class that implements CGI scripts functionality when called from
command line or cron job

Refer to Foswiki::Engine documentation for explanation about methos below.

=cut

package Foswiki::Engine::CLI;
use v5.14;

use File::Spec;

use Foswiki::Request         ();
use Foswiki::Request::Upload ();
use Foswiki::Response        ();

use Foswiki::Class;
extends qw(Foswiki::Engine);

use constant HTTP_COMPLIANT => 0;

has path_info => ( is => 'rw', clearer => 1, predicate => 1, );
has plist => ( is => 'rw', lazy => 1, clearer => 1, default => sub { [] }, );
has params => ( is => 'rw', lazy => 1, clearer => 1, default => sub { {} }, );

# CLI is the last resort engine. Thus – always return true on probe.
sub probe { 1; }

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;
    my @args   = @ARGV;    # Copy, so original @ARGV doesn't get modified

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
            $params{user} = $arg;
        }
        elsif ($name) {
            push @{ $params{plist} }, $name
              unless exists $params{params}{$name};
            push @{ $params{params}{$name} }, $arg;
        }
        else {
            $params{path_info} = $arg;    # keep it tainted
        }
    }
    return $orig->( $class, %params );
};

around _prepareConnection => sub {
    my $orig = shift;
    my $this = shift;
    return {
        remoteAddress => '127.0.0.1',
        method        => $this->env->{FOSWIKI_METHOD} // 'GET',
    };
};

around _prepareQueryParameters => sub {
    my $orig = shift;
    my ( $this, $req ) = @_;
    my @params;
    foreach my $name ( @{ $this->plist } ) {
        push @params, { -name => $name, -value => $this->params->{$name} };
    }
    $this->clear_plist;
    $this->clear_params;
    return \@params;
};

# This initializer will be called only when no =user= parameter is set by the
# object constructor.
around _prepareUser => sub {
    my $orig = shift;
    my $this = shift;
    my $user = $orig->($this);
    if ( !$user ) {
        if ( $Foswiki::cfg{Register}{AllowLoginName} ) {
            $user = $Foswiki::cfg{AdminUserLogin};
        }
        else {
            $user = $Foswiki::cfg{AdminUserWikiName};
        }
    }
    return $user;
};

around _preparePath => sub {
    my $orig   = shift;
    my ($this) = @_;
    my $env    = $this->env;
    my ( $action, $path_info );
    if ( $env->{FOSWIKI_ACTION} ) {
        $action = $env->{FOSWIKI_ACTION};
    }
    else {
        $action = ( File::Spec->splitpath($0) )[2];
    }
    if ( $this->has_path_info ) {
        $path_info = $this->pathInfo;
        $this->clear_pathInfo;
    }
    $action = 'view'
      unless defined $this->app->cfg->data->{SwitchBoard}{$action};
    return {
        action    => $action,
        path_info => $path_info,
    };
};

around prepareUploads => sub {
    my $orig = shift;
    my ( $this, $req ) = @_;
    my %uploads;

    #SMELL: CLI and CGI appear to support multiple uploads
    # but Foswiki::UI::Upload only processes a single upload.
    foreach my $fname ( @{ $req->_param->{filepath} } ) {
        $uploads{$fname} = $this->create(
            'Foswiki::Request::Upload',
            headers => {},
            tmpname => $fname
        );
    }
    $req->clear_uploads;
    $req->uploads( \%uploads );
};

around write => sub {
    my $orig = shift;
    my ( $this, $buffer ) = @_;
    print $buffer;
};

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
