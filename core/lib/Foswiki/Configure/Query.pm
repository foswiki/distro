# See bottom of file for default license and copyright information
package Foswiki::Configure::Query;

use strict;
use warnings;

use Assert;

use Foswiki::Configure::Load     ();
use Foswiki::Configure::Root     ();
use Foswiki::Configure::LoadSpec ();
use Foswiki::Configure::Reporter ();
use Foswiki::Configure::Checker  ();
use Foswiki::Configure::Wizard   ();

=begin TML

---+ package Foswiki::Configure::Query

Methods used to query and manipulate the configuration spec.

*Contract*

All the methods take two parameters; a parameter hash, and a
reporter. The parameter hash is described for each method,
as is the return value, which is always a perl reference.

All methods return undef if they fail badly. $reporter->ERROR is used to
describe fatal errors to the caller.

The $reporter should be clear before calling any of these methods,
as existing errors in the reporter will be detected as fatal errors
and cause the method to fail.

=cut

# Get =set= parameters and set the values in %Foswiki::cfg
sub _getSetParams {
    my ( $params, $root, $reporter ) = @_;
    if ( $params->{set} ) {
        while ( my ( $k, $v ) = each %{ $params->{set} } ) {
            if ( defined $v && $v ne '' ) {
                my $spec  = $root->getValueObject($k);
                my $value = $v;
                if ($spec) {
                    eval { $value = $spec->decodeValue( $value, 1 ); };
                    if ($@) {
                        $reporter->ERROR(
                            "The value of $k was unreadable: <verbatim>"
                              . Foswiki::Configure::Reporter::stripStacktrace(
                                $@)
                              . '</verbatim>' );
                        next;
                    }
                }
                if ( defined $value ) {
                    eval "\$Foswiki::cfg$k=\$value";
                }
                else {
                    eval "undef \$Foswiki::cfg$k";
                }
                if ( $params->{trace} ) {
                    $reporter->NOTE("Set $k");
                }
            }
            else {
                eval "undef \$Foswiki::cfg$k";
            }
            if ($@) {
                $reporter->ERROR( '<verbatim>'
                      . Foswiki::Configure::Reporter::stripStacktrace($@)
                      . '</verbatim>' );
            }
        }

        # Expand imported values
        Foswiki::Configure::Load::expandValue( \%Foswiki::cfg );
    }
}

=begin TML

---++ StaticMethod getcfg(\%params, $reporter) -> \%response

Retrieve for the value of one or more keys. \%params may include
   * =set= - hash of key-value pairs that maps the names of keys
     to the value to be set. Strings in the values are assumed to be
     unexpanded (i.e. with =$Foswiki::cfg= references intact).
   * =keys= - array of key names to recover values for.
If there isn't at least one key parameter, returns the
entire configuration hash. Values are returned unexpanded
(with embedded $Foswiki::cfg references intact.)

The result is a hash containing that subsection of %Foswiki::cfg
that has the keys requested.

=cut

sub getcfg {
    my ( $params, $reporter ) = @_;

    # Reload Foswiki::cfg without expansions
    local %Foswiki::cfg = ();
    Foswiki::Configure::Load::readConfig( 1, 1 );

    my $keys = $params->{keys};    # expect a list
    my $what;
    my $root;
    if ( defined $keys && scalar(@$keys) ) {
        $what = {};
        foreach my $key (@$keys) {
            unless ( $key =~ /^($Foswiki::Configure::Load::ITEMREGEX)$/ ) {
                $reporter->ERROR("Bad key '$key'");
                return undef;
            }

            # Implicit untaint for use in eval
            $key = $1;

            # Avoid loading specs unless we are being asked for a key that's
            # not in LocalSite.cfg
            unless ( eval "exists \$Foswiki::cfg$key" || $root ) {
                $root = Foswiki::Configure::Root->new();
                Foswiki::Configure::LoadSpec::readSpec( $root, $reporter );
                if ( $reporter->has_level('errors') ) {
                    return undef;
                }
                Foswiki::Configure::LoadSpec::addSpecDefaultsToCfg( $root,
                    \%Foswiki::cfg );
            }
            unless ( eval "exists \$Foswiki::cfg$key" ) {
                $reporter->ERROR("$key not defined");
                return undef;
            }
            eval "\$what->$key=\$Foswiki::cfg$key";
            if ($@) {
                $reporter->ERROR(
                    Foswiki::Configure::Reporter::stripStacktrace($@) );
                return undef;
            }
        }
    }
    else {
        $what = \%Foswiki::cfg;
    }
    return $what;
}

=begin TML

---++ StaticMethod search(\%params, $reporter) -> \@response

   * =search= - text fragment to search for

Search headlines and keys for a fragment of text. The response
gives the path(s) to the item(s) matched in an array of arrays,
where each entry is a single path.

Searches are case-sensitive.

=cut

sub search {
    my ( $params, $reporter ) = @_;
    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec( $root, $reporter );
    if ( $reporter->has_level('errors') ) {
        return undef;
    }

    # An empty search isn't fatal, just uninteresting
    return []
      unless defined $params->{search}
      && $params->{search} =~ /\S/;

    my %found;
    foreach my $find ( $root->search( $params->{search} ) ) {
        my @path = $find->getPath();
        $found{ join( '>', @path ) } = \@path;
    }
    my $finds = [ map { $found{$_} } sort keys %found ];

    return $finds;
}

=begin TML

---++ StaticMethod getspec(\%params, $reporter) -> \%response

Use a search to find a configuration item spec. \%params may include:
   * =get= - specifies the search. The following fields can be
     used in searches:
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

The response is a reference to the spec subtree. Note that this will
contained blessed hashes.

=cut

sub getspec {
    my ( $params, $reporter ) = @_;

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

    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec( $root, $reporter );
    if ( $reporter->has_level('errors') ) {
        return undef;
    }
    Foswiki::Configure::LoadSpec::addCfgValuesToSpec( \%Foswiki::cfg, $root );

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

=begin TML

---++ StaticMethod check_current_value(\%params, $reporter) -> \@response

Runs the server-side =check-current_value= checkers on a set of keys.
The keys to be checked are passed in as key-value pairs. You can also
pass in candidate values that will be set before any keys are checked.
   * =set= - hash of key-value pairs that maps the names of keys
     to the value to be set. Strings in the values are assumed to be
     unexpanded (i.e. with =$Foswiki::cfg= references intact).
   * =keys= - array of keys to be checked (or the headline(s) of the
     sections(s) to be recursively checked. '' checks the root. All
     keys under the headlined section(s) will be checked). The default
     is to check everything under the root.
   * =check_dependencies= - if true, check everything that depends
     on any of the keys being checked. This include dependencies
     explicitly expressed through CHECK and implicit dependencies found
     from the value of the checked item.

The results of the check are reported in an array where each entry is a
hash with fields =keys= and =reports=. =reports= is an array of reports,
each being a hash with keys =level= (e.g. =warnings=, =errors=), and
=message=.

*NOTE* check_dependencies will look into the values of other keys for
$Foswiki::cfg references, for example into the entries in a PERL hash.
If a dependency is found, the closest checkable entity (i.e. the PERL
key) will be checked, and *not* the subkey.

=cut

sub check_current_value {
    my ( $params, $frep ) = @_;

    # Load the spec files
    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec( $root, $frep );
    if ( $frep->has_level('errors') ) {
        return undef;
    }

    my @report;

    my $reporter = Foswiki::Configure::Reporter->new();

    # Because we're running in a plugin, we already have LocalSite.cfg
    # loaded. It's in $Foswiki::cfg! Of course if we're bootstrapping,
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
                push(
                    @report,
                    {
                        keys    => $k,
                        path    => [],
                        reports => "$k is not part of this .spec"
                    }
                );
            }
        }
    }

    # Are we to follow dependencies?
    my $dependants = 0;

    # Apply "set" values to $Foswiki::cfg
    eval { _getSetParams( $params, $root, $frep ); };
    if ( $frep->has_level('errors') ) {
        return undef;
    }

    if ( $params->{check_dependencies} ) {

        # First get reverse dependencies expressed in CHECK_ON_CHANGE
        # and add them as CHECK="also: forward dependencies to the
        # item they depend on. We only do this now, as it is quite
        # demanding.
        $root->find_also_dependencies($root);

        # Now look at the CHECK="also: for the items we've been asked
        # to check.
        my $changed;
        do {
            $changed = 0;
            foreach my $k ( keys %check ) {
                next unless $k;
                my $spec = $root->getValueObject($k);
                next unless $spec;
                foreach my $ch ( @{ $spec->{CHECK} } ) {
                    next unless $ch->{also};
                    foreach my $dep ( @{ $ch->{also} } ) {
                        next if $check{$dep};
                        $check{$dep} = 1;
                        $changed = 1;
                    }
                }
            }
        } while ($changed);

        # Reload Foswiki::cfg without expansions so we can find
        # string-embedded dependencies
        local %Foswiki::cfg = ();
        Foswiki::Configure::Load::readConfig( 1, 0, 1 );
        if ( $params->{with} ) {
            while ( my ( $k, $v ) = each %{ $params->{with} } ) {
                eval "\$Foswiki::cfg$k=$v";
            }
        }
        my $deps = Foswiki::Configure::Load::findDependencies();

        # Extend the list of requested keys with the keys that depend
        # on their values.
        my @dep_keys = keys %check;
        my %done;
        while ( my $dep = shift @dep_keys ) {
            next if $done{$dep};
            $done{$dep} = 1;

            # Find the closest enclosing key that has a spec (we only
            # check things with specs) and add it to the check set
            my $cd = $dep;
            while ( $cd && !$root->getValueObject($cd) ) {
                $cd =~ s/(.*){.*?}$/$1/;
            }
            $check{$cd} = 1 if $cd;
            push( @dep_keys, @{ $deps->{forward}->{$dep} } )
              if $deps->{forward}->{$dep};
        }
    }
    foreach my $k ( keys %check ) {
        next unless $k;
        my $spec = $root->getValueObject($k);
        ASSERT( $spec, $k ) if DEBUG;
        my $checker = Foswiki::Configure::Checker::loadChecker($spec);
        if ($checker) {
            $reporter->clear();
            $reporter->NOTE("Checking $k") if $params->{trace};
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

=begin TML

---++ StaticMethod wizard(\%params, $reporter) -> \%response

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
    my ( $params, $reporter ) = @_;

    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec( $root, $reporter );
    if ( $reporter->has_level('errors') ) {
        return undef;
    }

    my $target;
    if ( defined $params->{wizard} ) {
        unless ( $params->{wizard} =~ /^(\w+)$/ ) {    # untaint
            $reporter->ERROR("Bad wizard");
            return undef;
        }
        $target = Foswiki::Configure::Wizard::loadWizard( $1, $params );
    }
    else {
        unless ( $params->{keys} ) {
            $reporter->ERROR("No wizard and no keys");
            return undef;
        }
        my $vob = $root->getValueObject( $params->{keys} );
        $target = Foswiki::Configure::Checker::loadChecker($vob);
    }
    unless ($target) {
        $reporter->ERROR("Bad thing");
        return undef;
    }
    my $method = $params->{method};
    unless ( $method =~ /^(\w+)$/ ) {
        $reporter->ERROR("Bad method");
        return undef;
    }
    $method = $1;    # untaint

    _getSetParams( $params, $root, $reporter );
    return { messages => $reporter->messages() }
      if $reporter->has_level('errors');

    my $response = $target->$method($reporter);
    return $response if $response;

    return {
        changes  => $reporter->changes(),
        messages => $reporter->messages()
    };
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

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
