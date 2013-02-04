# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ScriptUrlPaths;

use strict;
use warnings;

use Foswiki::Configure qw/:cgi :auth/;

require Foswiki::Configure::Checkers::URLPATH;
our @ISA = ('Foswiki::Configure::Checkers::URLPATH');

# Type checker for entries in the {ScriptUrlPaths} hash
# Also covers {ScriptUrlPath}

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $keys = ref($valobj) ? $valobj->getKeys : $valobj;

    # non-existent keys are treated differently from
    # null keys.  Just accept non-existent/undefined ones.

    return '' unless ( defined $this->getItemCurrentValue );

    # Should be path to script

    my $e = '';

    $e = $this->SUPER::check($valobj);

    return $e if ( $e =~ /Error:/ );

    my $value = $this->getCfg;

    my $dval;
    my $script = 'view';
    if ( $keys =~ /^\{[^}]+\}\{([^}]+)\}$/ ) {
        $script = $1;
        $value = undef unless ( defined $this->getItemCurrentValue );
    }
    else {
        $dval = $value || '';
        $value .= "/$script" . ( $this->getCfg('{ScriptSuffix}') || '' );
    }

    # Very old config; undefined implies no alias

    $value =
        $this->getCfg('{ScriptUrlPath}')
      . "/$script"
      . ( $this->getCfg('{ScriptSuffix}') || '' )
      unless ( defined $value );

    # Blank implies '/'; Display '/' rather than ''
    $dval = ( $value || '/' ) unless ( defined $dval );

    # Attempt access, but only if LSC is valid, or test will fail.
    unless ($badLSC) {

        my $t = "/Web/Topic/Img/$script?configurationTest=yes";
        my $ok =
          $this->NOTE_OK("Content under $dval has been verfied as accessible.")
          . $this->NOTE("Press Verify button for more extensive tests");
        my $fail = $this->ERROR(
"Content under $dval is inaccessible.  Check the setting and webserver configuration."
        );
        $valobj->{errors}--;

        my $qkeys = $keys;
        $qkeys =~ s/([{}])/\\\\$1/g;

        $e .= $this->NOTE(
            qq{<span class="foswikiJSRequired">
<span name="${keys}Wait">Please wait while the setting is tested.  Disregard any message that appears only briefly.</span>
<span name="${keys}Ok">$ok</span>
<span name="${keys}Error">$fail</span></span>
<span class="foswikiNonJS">Content under $dval is accessible if a green check appears to the right of this text.
<img src="$value$t" style="margin-left:10px;height:15px;"
 onload='\$("[name=\\"${qkeys}Error\\"],[name=\\"${qkeys}Wait\\"]").hide().find("div.configureWarn,div.configureError").removeClass("configureWarn configureError");configure.toggleExpertsMode("");\$("[name=\\"${qkeys}Ok\\"]").show();'
 onerror='\$("[name=\\"${qkeys}Ok\\"],[name=\\"${qkeys}Wait\\"]").hide();\$("[name=\\"${qkeys}Error\\"]").show();'><br />If it does not appear, check the setting and webserver configuration.</span>}
        );
        $this->{JSContent} = 1;
    }

    return $e;
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    my $keys = ref $valobj ? $valobj->getKeys : $valobj;

    my $e = '';

    my $r;

    ( $e, $r ) = $this->SUPER::provideFeedback(@_);

    if ( $button == 2 ) {
        $e .= $this->testPath($keys);
    }
    return wantarray ? ( $e, $r ) : $e;
}

sub testPath {
    my $this = shift;
    my ($keys) = @_;

    my $e = '';

    require Foswiki::Net;
    my $cookie = Foswiki::newCookie($session);
    my $net    = Foswiki::Net->new;

    # Flags must be defined and false.  Avoid 'used once' warnings.

    local $Foswiki::Net::LWPAvailable = 0 && $Foswiki::Net::LWPAvailable;
    local $Foswiki::Net::noHTTPResponse = 1 || $Foswiki::Net::noHTTPResponse;

    unless ( defined $Foswiki::VERSION ) {
        ( my $fwi, $Foswiki::VERSION ) = Foswiki::Configure::UI::extractModuleVersion( 'Foswiki', 1 );
        $Foswiki::Version = '0.0' unless ($fwi);
    }

    my $test   = '/Web/Topic/Env/Echo?configurationTest=yes';
    my $target = $this->getItemCurrentValue;
    my $script = 'view';
    my ( $root, $view, $viewtarget );

    if ( $keys =~ /^\{[^}]+\}\{([^}]+)\}$/ ) {
        $script = $1;
    }
    else {
        $target ||= '';
        $target .= "/$script" . ( $this->getCfg('{ScriptSuffix}') || '' );
        $root       = 1;
        $view       = $this->getItemCurrentValue('{ScriptUrlPaths}{view}');
        $viewtarget = $view;
        $viewtarget = $this->getItemCurrentValue('{ScriptUrlPath}')
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
    $e .= $this->NOTE("Tracing access to <tt>$url</tt>");

    my ( $limit, $try ) = (10);
    my @headers = ( Cookie => join( '=', $cookie->name, $cookie->value ), );

    if ( ( my $user = $query->param('{ConfigureGUI}{TestUsername}') ) ) {
        my $password = $query->param('{ConfigureGUI}{TestPassword}') || '';
        require MIME::Base64;
        my $auth = MIME::Base64::encode_base64( "$user:$password", '' );
        push @headers, Authorization => "Basic $auth";
    }

    for ( $try = 1 ; $try <= $limit ; $try++ ) {
        my $response = $net->getExternalResource( $url, @headers );
        if ( $response->is_error ) {
            my $content = $response->content || '';
            $content =~ s/<([^>]*)>/&lt;$1&gt;/g;
            $e .=
              $this->ERROR( "Failed to access \"<tt>$url</tt>\"<pre>"
                  . $response->code . ' '
                  . $response->message . "\n\n"
                  . $content
                  . "</pre>" );
            last;
        }
        if ( $response->is_redirect ) {
            $url = $response->header('location') || '';
            unless ($url) {
                $e .=
                  $this->ERROR( "Redirected ("
                      . $response->code . ") "
                      . 'without a <i>location</i> header' );
                last;
            }
            $e .=
              $this->NOTE( "Redirected ("
                  . $response->code . ") "
                  . "to \"<tt>$url</tt>\"" );
            next;
        }
        $data = $response->content;
        unless ( $url =~ m,^(https?://([^:/]+)(:\d+)?)(/.*)?\Q$test\E$, ) {
            $e .= $this->ERROR("\"<tt>$url</tt>\" does not match request");
            last;
        }
        my ( $host, $hname, $port, $path ) = ( $1, $2, $3, $4 );
        if ( $host ne $Foswiki::cfg{DefaultUrlHost} ) {
            $e .= $this->WARN(
"\"<tt>$host</tt>\" does not match {DefaultUrlHost} (<tt>$Foswiki::cfg{DefaultUrlHost}</tt>)"
            );
        }
        $path ||= '';
        my @server = split( /\|/, $data, 3 );
        if ( @server != 3 ) {
            my $ddat = ( split( /\r?\n/, $data, 2 ) )[0] || '';
            $e .= $this->ERROR(
                "Server returned incorrect diagnostic data:<pre>$ddat</pre>");
        }
        else {
            if ( $server[0] eq $target ) {
                $e .= $this->NOTE(
                    "Server received the expected path (<tt>$target</tt>)");
            }
            elsif ($root) {
                if ( $server[0] eq $view ) {
                    $e .= $this->NOTE(
"Server received \"<tt>$server[0]</tt>\", which is the value of {ScriptUrlPaths}{view}.  This indicates that short(er) URLs are active and functioning correctly."
                    );
                }
                else {
                    $e .= $this->ERROR(
"Server received \"<tt>$server[0]</tt>\", but the expected path is \"<tt>$viewtarget</tt>\"<br />
Changing {ScriptUrlPaths}{view} to \"<tt>$server[0]</tt>\" will probably correct this error. (Server may be configured for Shorter URLs.) <br />
<a href='#' class='foswikiButtonMini' onclick='return feedback.setValue(&quot;{ScriptUrlPaths}{view}&quot;, &quot;$server[0]&quot;);'>(Click to use this value)</a>"
                    );
                }
            }
            else {
                $e .= $this->ERROR(
"Server received \"<tt>$server[0]</tt>\", but the expected path is \"<tt>$target</tt>\"<br />
The correct setting for $keys is probably \"<tt>$server[0]</tt>\".  (Server may be configured for Shorter URLs.) <br />
<a href='#' class='foswikiButtonMini' onclick='return feedback.setValue(&quot;$keys&quot;, &quot;$server[0]&quot;);'>(Click to use this value)</a>"
                );
            }
        }
        if ( $path eq $target ) {
            $e .= $this->NOTE_OK("Path \"<tt>$path</tt>\" is correct");
        }
        elsif ($root) {
            if ( $path eq $view ) {
                $e .= $this->NOTE_OK(
"Path \"<tt>$path</tt>\" is correct for <tt>view</tt> with short(er) URLs"
                );
            }
            else {
                $this->ERROR( "Path used by "
                      . ( $try > 1 ? "final " : '' )
                      . "GET (<tt>$path</tt>) does not match {ScriptUrlPath} (<tt>$viewtarget</tt>)"
                );
            }
        }
        else {
            $e .=
              $this->ERROR( "Path used by "
                  . ( $try > 1 ? "final " : '' )
                  . "GET (<tt>$path</tt>) does not match $keys (<tt>$target</tt>)"
              );
        }

        last;
    }
    if ( $try > $limit ) {
        $e .= $this->ERROR("Excessive redirects (&gt;$limit) stopped trace.");
    }
    return $e;
}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
