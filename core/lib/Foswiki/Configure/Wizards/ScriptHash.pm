# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::ScriptHash;

=begin TML

---++ package Foswiki::Configure::Wizards::ScriptHash

Wizard to verify script paths.

=cut

use strict;
use warnings;

use Assert;

use JSON ();

use Foswiki::Configure::Dependency ();
use Foswiki::Configure::Load       ();

require Foswiki::Configure::Wizard;
our @ISA = ('Foswiki::Configure::Wizard');

=begin TML

---++ WIZARD verify

Verify the validity of scripthash entries.
This is brutally hard work - don't do it unless you have to!

=cut

sub verify {
    my ( $this, $reporter ) = @_;

    my $keys = $this->param('keys');
    $keys =~ m/^(\{[^}]+\}\{[^}]+\})$/;
    $keys = $1;    # untaint

    require Foswiki::Net;

    my $user     = $this->param('cfgusername');
    my $password = $this->param('cfgpassword');

    my @pars = (
        -name  => 'FOSWIKI_CONFIGURATION',
        -value => time,

        # Can't include path since we test short URLs.
        -path    => '/',
        -expires => "+1h"
    );
    push @pars, -secure => 1 if ( $ENV{HTTPS} && $ENV{HTTPS} eq 'on' );

    my $cookie = CGI->cookie(@pars);
    my $net    = Foswiki::Net->new;

    unless ( defined $Foswiki::VERSION ) {
        ( my $fwi, $Foswiki::VERSION ) = Foswiki::Configure::Dependency::extractModuleVersion( 'Foswiki', 1 );
        $Foswiki::Version = '0.0' unless ($fwi);
    }

    my $script;

    if ( $keys =~ m/^\{ScriptUrlPaths\}\{([^}]+)\}$/ ) {
        $script = $1;
    }
    else {
        $script = 'view';
    }

    my $url =
        $Foswiki::cfg{DefaultUrlHost}
      . $Foswiki::cfg{ScriptUrlPath}
      . "/$script"
      . ( $Foswiki::cfg{ScriptSuffix} || '' );

    my $target = $Foswiki::cfg{ScriptUrlPaths}{$script};
    unless ( defined $target ) {
        $target = "$Foswiki::cfg{ScriptUrlPath}/$script"
          . ( $Foswiki::cfg{ScriptSuffix} || '' );
    }

    $reporter->NOTE("Tracing access to =$url=, $keys = '$target'");

    my $try     = 10;
    my %headers = (
        Cookie             => join( '=', $cookie->name, $cookie->value ),
        'X-Foswiki-Tickle' => 1,
        'X-Requested-With' => 'FoswikiReflectionRequest'
    );

    if ($user) {
        require MIME::Base64;
        my $auth = MIME::Base64::encode_base64( "$user:$password", '' );
        $headers{Authorization} = "Basic $auth";
    }

    while ( $try-- ) {
        my $response = $net->getExternalResource( $url, headers => \%headers );

        if ( $response->is_error ) {
            my $content = $response->content || '';
            $content =~ s/<([^>]*)>/&lt;$1&gt;/g;
            $reporter->ERROR( "Failed to access =$url="
                  . $response->code . ' '
                  . $response->message . "\n\n"
                  . $content
                  . "</pre>" );
            last;
        }
        if ( $response->is_redirect ) {
            $url = $response->header('location') || '';
            unless ($url) {
                $reporter->ERROR( "Redirected ("
                      . $response->code . ") "
                      . 'without a <i>location</i> header' );
                last;
            }
            $reporter->NOTE(
                "Redirected (" . $response->code . ") " . "to =$url=" );
            next;
        }
        unless ( $url =~ m,^(https?://([^:/]+)(:\d+)?)(/.*)?, ) {
            $reporter->ERROR("=$url= does not match request");
            last;
        }

        my $data = $response->content;

        my $info = JSON->new->decode($data);

        unless ( ref($info) && defined $info->{SCRIPT_NAME} ) {
            $reporter->ERROR(
                "Server returned incorrect diagnostic data: =$data= ");
            last;
        }

        my $ptarget = ($target) ? $target : 'empty';

        if ( $script eq 'view' ) {
            if ( $info->{SCRIPT_NAME} eq $Foswiki::cfg{ScriptUrlPath} ) {
                $reporter->NOTE(
"Server received =$info->{SCRIPT_NAME}=, which is the value of {ScriptUrlPaths}{$script}.  This indicates that short(er) URLs are active and functioning correctly."
                );
            }
            elsif ( $info->{SCRIPT_NAME} eq $target ) {
                $reporter->NOTE(
                    "Server received the expected path: (=$ptarget=) ");
            }
            else {
                $reporter->ERROR(
"Server received =($info->{SCRIPT_NAME})=, but the configured path to =view= is =($Foswiki::cfg{ScriptUrlPath})=.
Changing {ScriptUrlPaths}{view} to =($info->{SCRIPT_NAME})= will probably correct this error. (Server may be configured for Shorter URLs.)"
                );
            }
        }
        elsif ( $info->{SCRIPT_NAME} eq $target ) {
            $reporter->NOTE("Server received the expected path: (=$ptarget=) ");
        }
        else {
            $reporter->ERROR(
"Server received (=$info->{SCRIPT_NAME}=), but the expected path is =($ptarget)=.
The correct setting for $keys is probably =$info->{SCRIPT_NAME}=.  (Server may be configured for Shorter URLs.)"
            );
        }
        last;
    }
    unless ($try) {
        $reporter->ERROR("Excessive redirects stopped trace.");
    }
    return undef;    # return the report
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
