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

use constant TRACE_CHECK  => 0;
use constant TRACE_GETSET => 0;

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
    my ( $params, $root, $reporter, $Foswikicfg ) = @_;

    if ( $params->{set} ) {
        while ( my ( $k, $value ) = each %{ $params->{set} } ) {
            my $spec = $root->getValueObject($k);
            unless ($spec) {
                $reporter->ERROR("$k was not found in any Config.spec");
                next;
            }
            if ( defined $value && !ref($value) ) {
                $value =~ m/^(.*)$/s;    # UNTAINT
                $value = $1;
                eval { $value = $spec->decodeValue($value); };
                if ($@) {
                    $reporter->ERROR(
                            "The value of $k was unreadable: <verbatim>"
                          . Foswiki::Configure::Reporter::stripStacktrace($@)
                          . '</verbatim>' );
                    next;
                }
            }
            if ( defined $value ) {
                if ( $spec->isFormattedType() || ref($value) ) {
                    print STDERR "GETSET $k="
                      . Data::Dumper->Dump( [$value] )
                      . ", spec "
                      . $spec->stringify() . "\n"
                      if TRACE_GETSET;
                    eval("\$Foswikicfg->$k=\$value");
                }
                else {
                    print STDERR "GETSET $k=$value, spec "
                      . $spec->stringify() . "\n"
                      if TRACE_GETSET;

                    # This is needed to prevent expansion of embedded
                    # $Foswiki::cfg variables during the eval.
                    eval("\$Foswikicfg->$k=join('',\$value)");
                }
            }
            else {
                print STDERR "GETSET undef $k\n" if TRACE_GETSET;
                eval("undef \$Foswikicfg->$k");
            }
            if ($@) {
                $reporter->ERROR( '<verbatim>'
                      . Foswiki::Configure::Reporter::stripStacktrace($@)
                      . '</verbatim>' );
            }
            elsif ( $params->{trace} ) {
                $reporter->NOTE("Set $k");
            }
        }
    }
}

=begin TML

---++ StaticMethod getcfg(\%params, $reporter) -> \%response

Retrieve for the value of one or more keys. \%params may include
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
    local %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );
    Foswiki::Configure::Load::readConfig( 1, 1 );

    my $keys = $params->{keys};    # expect a list
    my $what;
    my $root;
    if ( defined $keys && scalar(@$keys) ) {
        $what = {};
        foreach my $key (@$keys) {
            unless ( $key =~ m/^($Foswiki::Configure::Load::ITEMREGEX)$/ ) {
                $reporter->ERROR("Bad key '$key'");
                return undef;
            }

            # Implicit untaint for use in eval
            $key = $1;

            # Avoid loading specs unless we are being asked for a key that's
            # not in LocalSite.cfg
            unless ( eval("exists \$Foswiki::cfg$key") || $root ) {
                $root = Foswiki::Configure::Root->new();
                Foswiki::Configure::LoadSpec::readSpec( $root, $reporter );
                if ( $reporter->has_level('errors') ) {
                    return undef;
                }
                Foswiki::Configure::LoadSpec::addSpecDefaultsToCfg( $root,
                    \%Foswiki::cfg );
            }
            unless ( eval("exists \$Foswiki::cfg$key") ) {
                $reporter->ERROR("$key not defined");
                return undef;
            }
            eval("\$what->$key=\$Foswiki::cfg$key");
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
      && $params->{search} =~ m/\S/;

    my $re =
      join( ".*", map { quotemeta($_) } split( /\s+/, $params->{search} ) );

    my %found;
    foreach my $find ( $root->search($re) ) {
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
    local %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );
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

    local %Foswiki::cfg = %Foswiki::cfg;

    # Load the spec files
    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec( $root, $frep );
    if ( $frep->has_level('errors') ) {
        return undef;
    }

    my @report;

    my $reporter = Foswiki::Configure::Reporter->new();

    # Apply "set" values to $Foswiki::cfg
    eval { _getSetParams( $params, $root, $frep, \%Foswiki::cfg ); };
    if ( $frep->has_level('errors') ) {
        return [ { reports => $frep->messages() } ];
    }

    # Because we're running in a plugin, we already have LocalSite.cfg
    # loaded. It's in $Foswiki::cfg! Of course if we're bootstrapping,
    # that config is wishful thinking, but hey, can't have everything.

    # Determine the set of value keys being checked. We start with
    # the keys passed in as parameters.

    my @keys;
    foreach my $k ( @{ $params->{keys} } ) {
        if ( $root->getValueObject($k) || $root->getSectionObject($k) ) {
            push( @keys, $k );
        }
        else {
            $k = "'$k'" unless $k =~ m/^\{.*\}$/;
            push(
                @report,
                {
                    keys    => $k,
                    path    => [],
                    reports => [
                        {
                            text  => "$k was not found in any Config.spec",
                            level => 'errors'
                        }
                    ]
                }
            );
        }
    }

    if ( scalar(@keys) == 0 ) {
        push( @keys, '' );
    }

    my $deps;    # forward and reverse dependencies computed from values
    if ( $params->{check_dependencies} ) {

        # Get reverse dependencies expressed in CHECK_ON_CHANGE
        # and add them as CHECK="also: forward dependencies to the
        # item they depend on. We only do this if check_dependencies
        # is set, as it is quite demanding.
        $root->find_also_dependencies($root);

        # Reload Foswiki::cfg without expansions so we can find
        # string-embedded dependencies
        local %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );
        Foswiki::Configure::Load::readConfig( 1, 0, 1 );
        if ( $params->{with} ) {
            while ( my ( $k, $v ) = each %{ $params->{with} } ) {
                eval("\$Foswiki::cfg$k=$v");
            }
        }
        $deps = Foswiki::Configure::Load::findDependencies();
    }

    #print STDERR Data::Dumper->Dump([$deps]);

    my %check;     # set of keys to be checked
    my @checko;    # list of Value objects for keys to be checked
    while ( defined( my $k = shift(@keys) ) ) {
        print STDERR "Find dependencies for $k\n" if TRACE_CHECK;
        next if $check{$k};    # already done?
        $check{$k} = 1;
        my $v = $root->getValueObject($k);
        if ($v) {
            print STDERR "\t'$k' is a key\n" if TRACE_CHECK;
            push( @checko, $v );
            if ( $params->{check_dependencies}
                && defined $v->{CHECK}->{also} )
            {

                # Look at the CHECK="also:" explicit dependencies
                foreach my $dep ( @{ $v->{CHECK}->{also} } ) {
                    next if $check{$dep};
                    print STDERR "\t... has a check:also for $dep\n"
                      if TRACE_CHECK;
                    push( @keys, $dep ) unless $check{$dep};
                }
            }
        }
        else {
            $v = $root->getSectionObject($k);
            if ($v) {
                print STDERR "\n'$k' is a section\n" if TRACE_CHECK;
                foreach my $kk ( $v->getAllValueKeys() ) {
                    unless ( $check{$kk} ) {
                        print STDERR "\tcontains key '$kk'\n" if TRACE_CHECK;
                        push( @keys, $kk );
                    }
                }
            }
            else {
                print STDERR "\t'$k' is not a key or a section\n"
                  if TRACE_CHECK;
                if ( $k =~ s/{[^{}]+}$// && !$check{$k} ) {
                    print STDERR "\tcheck parent '$k' instead\n" if TRACE_CHECK;
                    push( @keys, $k );
                }
            }
        }

        # Look at forward dependencies i.e. the keys that depend
        # on the value of this key
        if ( $deps && $deps->{forward}->{$k} ) {
            my @more = grep { !$check{$_} } @{ $deps->{forward}->{$k} };
            map { print STDERR "\t$_ depends on $k\n"; $_ } @more
              if TRACE_CHECK;
            push( @keys, @more );
        }
    }

  SPEC:
    foreach my $spec (@checko) {
        my $e = $spec->{CHECK}->{iff};
        if ( defined $e ) {
            $e = $e->[0];

            # Expand {x} as $Foswiki::cfg{x}
            $e =~ s/(({[^}]+})+)/\$Foswiki::cfg$1/g;
            if ( $e =~ m/\S/ ) {
                my $only_if;
                eval("\$only_if=$e");
                die "Syntax error in $spec->{keys} CHECK='iff:$e' - "
                  . Foswiki::Configure::Reporter::stripStacktrace($@)
                  if $@;
                next SPEC unless $only_if;
            }
        }
        my $checker = Foswiki::Configure::Checker::loadChecker($spec);
        next unless $checker;
        ASSERT( $spec->{keys} ) if DEBUG;
        $reporter->clear();
        $reporter->NOTE("Checking $spec->{keys}") if $params->{trace};
        $checker->check_current_value($reporter);
        my @path = $spec->getPath();
        pop(@path);    # remove keys
        push(
            @report,
            {
                keys    => $spec->{keys},
                path    => [@path],
                reports => $reporter->messages(),
                hints   => $reporter->hints()
            }
        );
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

    local %Foswiki::cfg = %Foswiki::cfg;

    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec( $root, $reporter );
    if ( $reporter->has_level('errors') ) {
        return undef;
    }

    my $target;
    if ( defined $params->{wizard} ) {
        unless ( $params->{wizard} =~ m/^(\w+)$/ ) {    # untaint
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
    unless ( $method =~ m/^(\w+)$/ ) {
        $reporter->ERROR("Bad method");
        return undef;
    }
    $method = $1;    # untaint

    _getSetParams( $params, $root, $reporter, \%Foswiki::cfg );
    return { messages => $reporter->messages() }
      if $reporter->has_level('errors');

    # Most wizards won't need the $root, only those that actually
    # modify it e.g. installers.
    my $response = $target->$method( $reporter, $root );
    return $response if $response;

    # Note: we can't used the value recorded at CHANGED time because that
    # is encoded using Reporter::uneval, which knows nothing about the
    # real type of the value. For the real type we have to use the
    # Value's encoder.
    my %new_values;
    foreach my $k ( keys %{ $reporter->{changes} } ) {
        next if $k =~ /\{EmptyPlugin\}/;
        my $v = $root->getValueObject($k);
        ASSERT( $v, "$k missing from Config.spec $method" ) if DEBUG;
        $new_values{$k} = $v->encodeValue( eval("\$Foswiki::cfg$k") );
    }

    return {
        changes  => \%new_values,
        messages => $reporter->messages(),
        hints    => $reporter->hints()
    };
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014-2015 Foswiki Contributors. Foswiki Contributors
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
