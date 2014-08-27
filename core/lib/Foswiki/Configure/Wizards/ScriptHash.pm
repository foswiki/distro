# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::ScriptHash;

use strict;
use warnings;

use Assert;

use Foswiki::Configure::Dependency ();
use Foswiki::Configure::Load       ();

require Foswiki::Configure::Wizard;
our @ISA = ('Foswiki::Configure::Wizard');

# This is brutally hard work - don't do it unless you have to!
sub verify {
    my ( $this, $reporter ) = @_;

    my $keys = $this->param('keys');
    $keys =~ /^(\{[^}]+\}\{[^}]+\})$/;
    $keys = $1;    # untaint

    require Foswiki::Net;

    # These are set NOSAVE in Foswiki.spec; when testing
    # potential values, they will be set in the incoming query
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

    # Flags must be defined and false.  Avoid 'used once' warnings.

    local $Foswiki::Net::LWPAvailable = 0 && $Foswiki::Net::LWPAvailable;
    local $Foswiki::Net::noHTTPResponse = 1 || $Foswiki::Net::noHTTPResponse;

    unless ( defined $Foswiki::VERSION ) {
        ( my $fwi, $Foswiki::VERSION ) = Foswiki::Configure::Dependency::extractModuleVersion( 'Foswiki', 1 );
        $Foswiki::Version = '0.0' unless ($fwi);
    }

    my $test   = '/Web/Topic/Env/Echo?configurationTest=yes';
    my $target = eval "\$Foswiki::cfg$keys";
    $target = '' unless defined $target;
    Foswiki::Configure::Load::expandValue($target);

    my $script = 'view';
    my ( $root, $view, $viewtarget );

    if ( $keys =~ /^\{[^}]+\}\{([^}]+)\}$/ ) {
        $script = $1;
    }
    else {
        $target ||= '';
        $target .= "/$script" . ( $Foswiki::cfg{ScriptSuffix} || '' );
        $root       = 1;
        $view       = $Foswiki::cfg{ScriptUrlPaths}{view};
        $viewtarget = $view;
        $viewtarget = $Foswiki::cfg{ScriptUrlPath}
          if ( !defined $viewtarget );
        Foswiki::Configure::Load::expandValue($viewtarget);
        $view = '$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}'
          if ( !defined $view );
        Foswiki::Configure::Load::expandValue($view);
    }
    $target =
      '$Foswiki::cfg{ScriptUrlPath}/' . $script . '$Foswiki::cfg{ScriptSuffix}'
      if ( !defined $target );
    Foswiki::Configure::Load::expandValue($target);
    my $data;

    my $url = $Foswiki::cfg{DefaultUrlHost} . $target . $test;
    $reporter->NOTE("Tracing access to =$url=");

    my ( $limit, $try ) = (10);
    my @headers = ( Cookie => join( '=', $cookie->name, $cookie->value ), );

    if ($user) {
        require MIME::Base64;
        my $auth = MIME::Base64::encode_base64( "$user:$password", '' );
        push @headers, Authorization => "Basic $auth";
    }
    push( @headers, 'X-Requested-With' => 'FoswikiReflectionRequest' );

    for ( $try = 1 ; $try <= $limit ; $try++ ) {
        my $response = $net->getExternalResource( $url, @headers );

        if ( $response->is_error ) {
            my $content = $response->content || '';
            $content =~ s/<([^>]*)>/&lt;$1&gt;/g;
            $reporter->ERROR( "Failed to access \"=$url=\"<pre>"
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
                "Redirected (" . $response->code . ") " . "to \"=$url=\"" );
            next;
        }
        $data = $response->content;
        unless ( $url =~ m,^(https?://([^:/]+)(:\d+)?)(/.*)?\Q$test\E$, ) {
            $reporter->ERROR("\"=$url=\" does not match request");
            last;
        }
        my ( $host, $hname, $port, $path ) = ( $1, $2, $3, $4 );
        if ( $host ne $Foswiki::cfg{DefaultUrlHost} ) {
            $reporter->WARN(
"\"=$host=\" does not match {DefaultUrlHost} (=$Foswiki::cfg{DefaultUrlHost}=)"
            );
        }
        $path ||= '';
        my @server = split( /\|/, $data, 3 );
        if ( @server != 3 ) {
            my $ddat = ( split( /\r?\n/, $data, 2 ) )[0] || '';
            $reporter->ERROR(
                "Server returned incorrect diagnostic data:<pre>$ddat</pre>");
        }
        else {
            if ( $server[0] eq $target ) {
                $reporter->NOTE(
                    "Server received the expected path (=$target=)");
            }
            elsif ($root) {
                if ( $server[0] eq $view ) {
                    $reporter->NOTE(
"Server received \"=$server[0]=\", which is the value of {ScriptUrlPaths}{view}.  This indicates that short(er) URLs are active and functioning correctly."
                    );
                }
                else {
                    $reporter->ERROR(
"Server received \"=$server[0]=\", but the expected path is \"=$viewtarget=\"<br />
Changing {ScriptUrlPaths}{view} to \"=$server[0]=\" will probably correct this error. (Server may be configured for Shorter URLs.) <br />
<a href='#' class='foswikiButtonMini' onclick='return feedback.setValue(&quot;{ScriptUrlPaths}{view}&quot;, &quot;$server[0]&quot;);'>(Click to use this value)</a>"
                    );
                }
            }
            else {
                $reporter->ERROR(
"Server received \"=$server[0]=\", but the expected path is \"=$target=\"<br />
The correct setting for $keys is probably \"=$server[0]=\".  (Server may be configured for Shorter URLs.) <br />
<a href='#' class='foswikiButtonMini' onclick='return feedback.setValue(&quot;$keys&quot;, &quot;$server[0]&quot;);'>(Click to use this value)</a>"
                );
            }
        }
        if ( $path eq $target ) {
            $reporter->NOTE_OK("Path \"=$path=\" is correct");
        }
        elsif ($root) {
            if ( $path eq $view ) {
                $reporter->NOTE_OK(
                    "Path \"=$path=\" is correct for =view= with short(er) URLs"
                );
            }
            else {
                $reporter->ERROR( "Path used by "
                      . ( $try > 1 ? "final " : '' )
                      . "GET (=$path=) does not match {ScriptUrlPath} (=$viewtarget=)"
                );
            }
        }
        else {
            $reporter->ERROR( "Path used by "
                  . ( $try > 1 ? "final " : '' )
                  . "GET (=$path=) does not match $keys (=$target=)" );
        }

        last;
    }
    if ( $try > $limit ) {
        $reporter->ERROR("Excessive redirects (&gt;$limit) stopped trace.");
    }
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
