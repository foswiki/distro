# See bottom of file for default license and copyright information

# Note on separation of concerns: Please *do not* add anything to this
# plugin that is not specific to the Javascript 'configure' interface.
# Generic functionality related to configuration should be implemented
# in the core. The ConfigurePlugin is *just* for handling the UI, no more.

# Note that POD in this module is included in the documentation topic
# by BuildContrib

=pod

---++ Remote Procedure Call (RPC) interface

RPC calls are handled via the =JsonRpcContrib=. Callers must authenticate
as admins, or the request will be rejected with a 403 status.

Note: If Foswiki is running in 'bootstrap' mode (without a !LocalSite.cfg)
then *all* calls are automatically assumed to be from an admin. As soon
as a !LocalSite.cfg is put in place, then the authentication set up
therein will apply, and users are required to logged in as admins.

Entry points for each of the static methods published by the
Foswiki::Configure::Query class are supported. See that class for
descriptions.

=cut

package Foswiki::Plugins::ConfigurePlugin;

use strict;
use warnings;

our $VERSION           = '1.08';
our $RELEASE           = '04 Apr 2017';
our $SHORTDESCRIPTION  = '=configure= interface using json-rpc';
our $NO_PREFS_IN_TOPIC = 1;

use Assert;

use Foswiki::Contrib::JsonRpcContrib ();
use Foswiki::Configure::Auth         ();
use Foswiki::Configure::LoadSpec     ();
use Foswiki::Configure::Load         ();
use Foswiki::Configure::Root         ();
use Foswiki::Configure::Reporter     ();
use Foswiki::Configure::Checker      ();
use Foswiki::Configure::Wizard       ();
use Foswiki::Configure::Query        ();

use constant TRACE => 0;

BEGIN {
    # Note: if Foswiki is in bootstrap mode, Foswiki.pm will try
    # to require this module, thus executing this BEGIN block.

    $Foswiki::cfg{Plugins}{ConfigurePlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{ConfigurePlugin}{Module} =
      'Foswiki::Plugins::ConfigurePlugin';
}

{
    # Required for JSON to serialise Regexp types. Simply
    # converts them to strings.
    package Regexp;

    sub TO_JSON {
        my $regex = shift;
        $regex = "$regex";
        return $regex;
    }
}

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # No way to auto-register JsonRpcContrib, so we have to do it :-(
    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'JsonRpc',
        'Foswiki::Contrib::JsonRpcContrib::JQueryPlugin' );

    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'Configure',
        'Foswiki::Plugins::ConfigurePlugin::JQuery' );

    # Register each of the RPC methods with JsonRpcContrib
    my @methods =
      map { $_ =~ s/^.*:://; $_ }
      grep { defined &{$_} }
      map  { "Foswiki::Configure::Query::$_" }
      grep { $_ =~ m/^[a-z]/ }
      keys %Foswiki::Configure::Query::;

    foreach my $method (@methods) {

        Foswiki::Contrib::JsonRpcContrib::registerMethod( 'configure', $method,
            _JSONwrap("Foswiki::Configure::Query::$method") );
    }

    # Bootstrap code.   Capture the path for the "view" script from the URL
    # and stash it into a session variable for use by jsonrpc commands.
    # Or if it's not in the query, recover it from the session variable.
    # (jsonrpc uses POSTs, so the URL param isn't there.
    my $query = Foswiki::Func::getRequestObject();
    my $viewpath;
    if ( $Foswiki::cfg{isBOOTSTRAPPING} && defined $query ) {
        $viewpath = $query->param('VIEWPATH');
        if ( defined $viewpath ) {
            $Foswiki::cfg{ScriptUrlPaths}{view} = $viewpath;
            $Foswiki::Plugins::SESSION->getLoginManager()
              ->setSessionValue( 'VIEWPATH', $viewpath );
            print STDERR "AUTOCONFIG: Applied viewpath $viewpath from URL\n"
              if (Foswiki::Configure::Load::TRAUTO);
        }
        else {
            $viewpath =
              $Foswiki::Plugins::SESSION->getLoginManager()
              ->getSessionValue('VIEWPATH');
            if ( defined $viewpath ) {
                $Foswiki::cfg{ScriptUrlPaths}{view} = $viewpath;
                print STDERR
                  "AUTOCONFIG: Applied viewpath $viewpath from SESSION\n"
                  if (Foswiki::Configure::Load::TRAUTO);
            }
        }

        # pubdir is calculated relative from the bin dir.  Now that we know that
        # short URL's might be in use,  override the initial bootstrapped value
        # with a better guess.
        if ( defined $viewpath && $viewpath !~ m#/view# ) {
            print STDERR "AUTOCONFIG: Adjust PubUrlPath relative to viewpath\n";
            $Foswiki::cfg{PubUrlPath} = $viewpath . '/pub';
        }
    }

    return 1;

}

sub _JSONwrap {
    my $method = shift;
    return sub {
        my ( $session, $request ) = @_;

        if ( $Foswiki::cfg{isVALID} ) {
            Foswiki::Configure::Auth::checkAccess( $session, 1 );
        }

        my $reporter = Foswiki::Configure::Reporter->new();

        no strict 'refs';
        my $response;

        eval { require Taint::Runtime; };
        if ($@) {
            $response = &$method( $request->params(), $reporter );
        }
        else {
            # Disable taint checking, it's more trouble than it's worth
            local $Taint::Runtime::TAINT = 0;
            $response = &$method( $request->params(), $reporter );
        }

        use strict 'refs';
        unless ($response) {

            # Should never get here
            die $method . " "
              . join( "\n",
                map { "$_->{level}: $_->{text}" } @{ $reporter->messages() } );
        }
        return $response;
      }
}

=pod

---++ Invocation examples

Call using a URL of the format:

=%SCRIPTURL{"jsonrpc"}%/configure=

while POSTing a request encoded according to the JSON-RPC 2.0 specification:

<verbatim>
{
  jsonrpc: "2.0", 
  method: "getspec", 
  params: {
     get : { keys: "{DataDir}" },
     depth : 0
  }, 
  id: "caller's id"
}
</verbatim>

---++ .spec format
The format of .spec files is documented in detail in
There are two node types in the .spec tree:

SECTIONs have:
   * =headline= (default =UNKNOWN=, the root is usually '')
   * =typename= (always =SECTION=)
   * =children= - array of child nodes (sections and keys)
 
Key entries (such as ={DataDir}=) have:
   * =keys= e.g. ={Store}{Cupboard}=
   * =typename= (from the .spec)
   * Other keys from the .spec e.g. =SIZE=, =FEEDBACK=, =CHECK=

=cut

1;

__END__

Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2017 Foswiki Contributors. Foswiki Contributors
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
