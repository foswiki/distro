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

The following procedures are supported:

=cut

package Foswiki::Plugins::ConfigurePlugin;

use strict;
use warnings;
use version; our $VERSION = version->declare("v1.0.0_001");
use Assert;

use Foswiki::Contrib::JsonRpcContrib ();
use Foswiki::Configure::LoadSpec     ();
use Foswiki::Configure::Load         ();
use Foswiki::Configure::Root         ();
use Foswiki::Configure::Reporter     ();
use Foswiki::Configure::Checker      ();
use Foswiki::Configure::Wizard       ();

our $RELEASE          = '25 Sep 2014';
our $SHORTDESCRIPTION = '=configure= interface using json-rpc';

our $NO_PREFS_IN_TOPIC = 1;

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
    foreach my $method (qw(getcfg getspec search check_current_value wizard)) {
        Foswiki::Contrib::JsonRpcContrib::registerMethod( 'configure', $method,
            _JSONwrap($method) );
    }

    # Bootstrap code.   Capture the path for the "view" script from the URL
    # and stash it into a session variable for use by jsonrpc commands.
    # Or if it's not in the query, recover it from the session variable.
    # (jsonrpc uses POSTs, so the URL param isn't there.
    my $query = Foswiki::Func::getRequestObject();
    if ( $Foswiki::cfg{isBOOTSTRAPPING} && defined $query ) {
        my $viewpath = $query->param('VIEWPATH');
        if ( defined $viewpath ) {
            $Foswiki::cfg{ScriptUrlPaths}{view} = $viewpath;
            $Foswiki::Plugins::SESSION->getLoginManager()
              ->setSessionValue( 'VIEWPATH', $viewpath );
            print STDERR "AUTOCONFIG: Applied viewpath $viewpath from URL\n";
        }
        else {
            $viewpath =
              $Foswiki::Plugins::SESSION->getLoginManager()
              ->getSessionValue('VIEWPATH');
            if ( defined $viewpath ) {
                $Foswiki::cfg{ScriptUrlPaths}{view} = $viewpath;
                print STDERR
                  "AUTOCONFIG: Applied viewpath $viewpath from SESSION\n";
            }
        }
    }

    return 1;

}

sub _JSONwrap {
    my $method = shift;
    return sub {
        my ( $session, $request ) = @_;

        if ( $Foswiki::cfg{isVALID} ) {

            if ( defined $Foswiki::cfg{ConfigureFilter}
                && length( $Foswiki::cfg{ConfigureFilter} ) )
            {
                unless ( $session->{user} =~ m/$Foswiki::cfg{ConfigureFilter}/ )
                {
                    die
                      "You must have special permission to use this interface.";
                }
            }
            else {
                # Check rights to use this interface - admins only
                die
"You must be logged in as an administrator to use this interface."
                  unless Foswiki::Func::isAnAdmin();
            }
        }
        else {
            # Otherwise we must be bootstrapping - an inherently dangerous
            # operation. TODO: check we can do this safely.
        }

        no strict 'refs';
        return &$method( $request->params() );
        use strict 'refs';
      }
}

# For each key in the spec missing from the %cfg passed, add the
# default (unexpanded) from the spec to the %cfg, if it exists.
sub _addSpecDefaultsToCfg {
    my ( $spec, $cfg ) = @_;
    if ( $spec->{children} ) {
        foreach my $child ( @{ $spec->{children} } ) {
            _addSpecDefaultsToCfg( $child, $cfg );
        }
    }
    else {
        if ( exists( $spec->{default} )
            && eval("!exists(\$cfg->$spec->{keys})") )
        {
            # {default} stores a value string. Convert it to the
            # value suitable for storing in cfg
            my $value = $spec->decodeValue( $spec->{default} );
            if ( defined $value ) {
                eval("\$cfg->$spec->{keys}=\$value");
            }
            else {
                eval("undef \$cfg->$spec->{keys}");
            }
        }
    }
}

# For each key in the spec add the current value from the %cfg
# as current_value. If the key is
# not set in the %cfg, then set it to the default.
# Note that the %cfg should contain *unexpanded* values.
sub _addCfgValuesToSpec {
    my ( $cfg, $spec ) = @_;
    if ( $spec->{children} ) {
        foreach my $child ( @{ $spec->{children} } ) {
            _addCfgValuesToSpec( $cfg, $child );
        }
    }
    else {
        if ( eval("exists(\$cfg->$spec->{keys})") ) {

            # Encode the value as something that can be handled by
            # UIs
            my $value = eval "\$cfg->$spec->{keys}";
            ASSERT( !$@ ) if DEBUG;
            $spec->{current_value} = $spec->encodeValue($value);
        }

        # Don't do this; it's not the case that the default value
        # will end up in LocalSite.cfg
        #elsif (exists($spec->{default})) {
        #    eval("\$spec->{current_value}=eval(\$spec->{default})");
        #}
    }
}

=pod

---+++ =getcfg=
Retrieve for the value of one or more keys.
   * =keys= - array of key names to recover values for.
If there isn't at least one key parameter, returns the
entire configuration hash. Values are returned unexpanded
(with embedded $Foswiki::cfg references intact)
The result is a hash containing that subsection of %Foswiki::cfg
that has the keys requested.

=cut

sub getcfg {
    my $params = shift;

    # Reload Foswiki::cfg without expansions
    local %Foswiki::cfg = ();
    Foswiki::Configure::Load::readConfig( 1, 1 );
    my $keys = $params->{keys};    # expect a list
    my $what;
    my $root;
    if ( defined $keys ) {
        $what = {};
        foreach my $key (@$keys) {
            die "Bad key '$key'"
              unless $key =~ /^($Foswiki::Configure::Load::ITEMREGEX)$/;

            # Implicit untaint for use in eval
            $key = $1;

            # Avoid loading specs unless we are being asked for a key that's
            # not in LocalSite.cfg
            unless ( eval "exists \$Foswiki::cfg$key" || $root ) {
                $root = _loadSpec();
                _addSpecDefaultsToCfg( $root, \%Foswiki::cfg );
            }
            die "$key not defined" unless eval "exists \$Foswiki::cfg$key";
            eval "\$what->$key=\$Foswiki::cfg$key";
            die $@ if $@;
        }
    }
    else {
        $what = \%Foswiki::cfg;
    }
    return $what;
}

=pod

---+++ =search=

Search headlines and keys for a fragment of text. Return the path(s) to
the item(s) matched in an array or arrays, where each entry is a single
path.

=cut

sub search {
    my $params = shift;
    my $root   = _loadSpec();

    return () unless $params->{search};

    my %found;
    foreach my $find ( $root->search( $params->{search} ) ) {
        my @path = $find->getPath();
        $found{ join( '>', @path ) } = \@path;
    }
    my $finds = [ map { $found{$_} } sort keys %found ];

    return $finds;
}

=pod

---+++ =getspec=

Use a search to find a configuration item spec
   * =get= specifies the search. The following fields can be used in searches:
      * =headline= - title of a section,
      * =typename= - type of a leaf spec entry,
      * =parent= - a structure that will be used to match a parent,
      * =keys= - keys of a spec entry,
      * =desc= - descriptive text of a section or entry.
      * =depth= - matches the depth of a node under the root
        (which is depth 0)
   * =depth= - specifies the depth of the subtree below matched items
     to return.
Only exact matches are supported.

For example, ={ 'get': {'headline':'Store'}}= will retrieve the entire
spec subtree for the section called 'Store'.

={ 'get' : {'keys' : '{Store}{Implementation}'}}= will retrieve the spec
for that one entry. You cannot pass a list; if you require the spec for a
subsection, retrieve the section title.

={ 'get' : { 'parent' : {'headline' : 'Something'}, 'depth' : 0}= will
return all specs within the section named =Something=.

=cut

sub getspec {
    my $params = shift;

    # Reload Foswiki::cfg without expansions so we get the unexpanded
    # values in the spec structure
    my $upper_cfg = \%Foswiki::cfg;
    local %Foswiki::cfg = ();
    if ( $upper_cfg->{isBOOTSTRAPPING} ) {

        # If we're bootstrapping, retain the values calculated in
        # the bootstrap process. They are almost certainly wrong,
        # but are a better starting point that the .spec defaults.
        %Foswiki::cfg = %$upper_cfg;
    }
    Foswiki::Configure::Load::readConfig( 1, 1 );

    my $root = _loadSpec();
    _addCfgValuesToSpec( \%Foswiki::cfg, $root );

    my $depth  = $params->{depth};
    my $search = $params->{get};

    my @matches = ();
    if ($search) {
        @matches = $root->find(%$search);
    }
    else {
        @matches = ($root);
    }

    foreach my $m (@matches) {
        $m->unparent();
        $m->prune($depth) if defined $depth;
    }

    return \@matches;
}

# Recursive locate references to other keys in the values of keys
# Returns a =forward= hash mapping keys to a list of the keys that depend
# on their value, and a =reverse= hash mapping keys to a list of keys
# whose value they depend on.
sub _findDependencies {
    my ( $deps, $fwcfg, $extend_keypath, $keypath ) = @_;

    unless ( defined $fwcfg ) {
        ( $fwcfg, $extend_keypath, $keypath ) = ( \%Foswiki::cfg, 1, '' );
    }

    if ( ref($fwcfg) eq 'HASH' ) {
        while ( my ( $k, $v ) = each %$fwcfg ) {
            if ( defined $v ) {
                my $subkey = $extend_keypath ? "$keypath\{$k\}" : $keypath;
                _findDependencies( $deps, $v, $extend_keypath, $subkey );
            }
        }
    }
    elsif ( ref($fwcfg) eq 'ARRAY' ) {
        foreach my $v (@$fwcfg) {
            if ( defined $v ) {
                _findDependencies( $deps, $v, 0, $keypath );
            }
        }
    }
    else {
        while ( $fwcfg =~ /\$Foswiki::cfg(({[^}]*})+)/g ) {
            push( @{ $deps->{forward}->{$1} },       $keypath );
            push( @{ $deps->{reverse}->{$keypath} }, $1 );
        }
    }
}

sub _loadSpec {
    my $reporter = shift;

    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec($root);
    if ( @Foswiki::Configure::LoadSpec::errors && $reporter ) {
        foreach my $e (@Foswiki::Configure::LoadSpec::errors) {
            $reporter->ERROR( join( ' ', @$e ) );
        }
    }
    if ( @Foswiki::Configure::LoadSpec::warnings && $reporter ) {
        foreach my $e (@Foswiki::Configure::LoadSpec::warnings) {
            $reporter->WARN( join( ' ', @$e ) );
        }
    }
    return $root;
}

=pod

---+++ =check_current_value=

Runs the server-side =check-current_value= checkers on a set of keys.
The keys to be checked are passed in as key-value pairs. You can also
pass in candidate values that will be set before any keys are checked.
   * =keys= - array of keys to be checked (or the headline(s) of the
     sections(s) to be recursively checked. '' checks the root. All
     keys under the headlined section(s) will be checked). The default
     is to check everything under the root.
   * =check_dependencies= - if true, check everything that depends
     on any of the keys being checked
   * =set= - hash of key-value pairs that maps the names of keys
     to the value to be set. Strings in the values are assumed to be
     unexpanded (i.e. with =$Foswiki::cfg= references intact).

The results of the check are reported in an array where each entry is a
hash with fields =keys= and =reports=. =reports= is an array of reports,
each being a hash with keys =level= (e.g. =warnings=, =errors=), and
=message=.

=cut

sub _getSetParams {
    my ( $params, $root ) = @_;
    if ( $params->{set} ) {
        while ( my ( $k, $v ) = each %{ $params->{set} } ) {
            if ( defined $v && $v ne '' ) {
                my $spec  = $root->getValueObject($k);
                my $value = $v;
                if ($spec) {
                    $value = $spec->decodeValue($value);
                }
                if ( defined $value ) {
                    eval "\$Foswiki::cfg$k=\$value";
                }
                else {
                    eval "undef \$Foswiki::cfg$k";
                }
            }
            else {
                eval "undef \$Foswiki::cfg$k";
            }
            die $@ if $@;
        }

        # Expand imported values
        Foswiki::Configure::Load::expandValue( \%Foswiki::cfg );
    }
}

sub check_current_value {
    my $params = shift;

    # Load the spec files
    my $reporter = Foswiki::Configure::Reporter->new();
    my $root     = _loadSpec($reporter);
    my @report;

    if ( scalar @{ $reporter->messages() } ) {
        push( @report, { reports => $reporter->messages(), } );
    }

    $reporter->clear();

    # Because we're running in a plugin, we already have LocalSite.cfg
    # loaded. It's in $Foswiki::cfg! of course if we're bootstrapping,
    # that config is wishful thinking, but hey, can't have everything.

    # Determine the set of value keys being checked

    my $keys = $params->{keys};
    if ( !$keys || scalar @$keys == 0 ) {
        push( @$keys, '' );
    }

    my %check;
    foreach my $k (@$keys) {

        # $k='' is the root section
        my $v = $root->getValueObject($k);
        if ($v) {
            $check{$k} = 1;
        }
        else {
            $v = $root->getSectionObject($k);
            if ($v) {
                foreach my $kk ( $v->getAllValueKeys() ) {
                    $check{$kk} = 1;
                }
            }
            else {
                $k = "'$k'" unless $k =~ /^\{.*\}$/;
                $reporter->ERROR("$k is not part of this .spec");
            }
        }
    }

    # Are we to follow dependencies?
    my $dependants = 0;
    my %deps;

    # Apply "set" values to $Foswiki::cfg
    _getSetParams( $params, $root );

    if ( $params->{check_dependencies} ) {

        # Reload Foswiki::cfg without expansions so we can find
        # dependencies
        local %Foswiki::cfg = ();
        Foswiki::Configure::Load::readConfig( 1, 1 );
        if ( $params->{with} ) {
            while ( my ( $k, $v ) = each %{ $params->{with} } ) {
                eval "\$Foswiki::cfg$k=$v";
            }
        }
        _findDependencies( \%deps );

        # Extend the list of requested keys with the keys that depend
        # on their values.
        my @dep_keys = keys %check;
        my %done;
        while ( my $dep = shift @dep_keys ) {
            next if $done{$dep};
            $check{$dep} = 1;
            $done{$dep}  = 1;
            push( @dep_keys, @{ $deps{forward}->{$dep} } )
              if $deps{forward}->{$dep};
        }
    }

    foreach my $k ( keys %check ) {
        next unless $k;
        my $spec = $root->getValueObject($k);
        ASSERT( $spec, $k ) if DEBUG;
        my $checker = Foswiki::Configure::Checker::loadChecker($spec);
        if ($checker) {
            $reporter->clear();
            print STDERR "Checking $k\n" if TRACE;
            $checker->check_current_value($reporter);
            my @path = $spec->getPath();
            pop(@path);    # remove keys
            push(
                @report,
                {
                    keys    => $k,
                    path    => [@path],
                    reports => $reporter->messages()
                }
            );
        }
    }
    return \@report;
}

=pod

---+++ wizard

Call a configuration wizard.

Configuration wizards are modules that support complex operations on
configuration data; for example, auto-configuration of email and complex
and time-consuming integrity checks.

   * =wizard= - name of a wizard class to load
   * =keys= - name of a checker to use if =wizard= is not given
   * =method= - name of the method in the wizard or checker to call

If the wizard method returns an object, that will be passed back
as the result of the call. If the wizard method returns undef, the
return result is a hash containing the following keys:
    * =report= - Error/Warning etc messages, formatted as HTML. Each
      entry in this array is a hash with keys 'level' (e.g. error, warning)
      and 'message'.
   * =changes= - This is a hash mapping changed keys to their new values

=cut

sub wizard {
    my $params = shift;

    my $target;
    my $root = _loadSpec();
    if ( defined $params->{wizard} ) {
        die "Bad wizard" unless $params->{wizard} =~ /^(\w+)$/;    # untaint
        $target = Foswiki::Configure::Wizard::loadWizard( $1, $params );
    }
    else {
        die "No wizard and no keys" unless $params->{keys};
        my $vob = $root->getValueObject( $params->{keys} );
        $target = Foswiki::Configure::Checker::loadChecker($vob);
    }
    die unless $target;
    my $method = $params->{method};
    die unless $method =~ /^(\w+)$/;
    $method = $1;                                                  # untaint
    my $reporter = Foswiki::Configure::Reporter->new();

    _getSetParams( $params, $root );

    my $response = $target->$method($reporter);

    unless ($response) {
        $response = {
            changes  => $reporter->changes(),
            messages => $reporter->messages()
        };
    }

    return $response;
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

Copyright (C) 2013-2014 Foswiki Contributors. Foswiki Contributors
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
