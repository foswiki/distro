# See bottom of file for license and copyright information

=begin TML

---+!! Package Foswiki::FeatureSet

This module provides feature sets functionality.

---++ Synopsis

<verbatim>

use Foswiki::FeatureSet;

features_provided
  FEATURE1 => [ 2.99, undef, undef, ],
  FEATURE2 => [ 1.1, 3.0, 4.0, ],
  OLDWIKI_COMPATIBILITY => [ undef, 2.99, 4.0, ],
  PSGI => [ 'v2.99.1', undef, undef, ],
  FEATURE3 => [ qw(v1.0 v2.99.9 v5.0)],
  UNICODE => [
    v2.0, undef, undef,
    -desc => 'Unicode support',
  ]
  ;
</verbatim>

Test if certain features are provided:

<verbatim>

use Foswiki::FeatureSet qw(:all);

# 
featuresComply(
    # -version => '3.0',
    -features => [qw(PSGI FEATURE2)],
);
</verbatim>

---++ Description

A feature set is a list of keywords describing what features are implemented by
Foswiki components. For example, paragraph indentation support is declared by
=PARA_INDENT= keyword. =PSGI= keyword defines that core supports CPAN:PSGI.

Every feature has its life cycle. Usually it is described by three software
version numbers: the version where the feature was first introduced; where it
was declared deprecated; and finally the version when support for the feature is
cancelled. A keyword paired with version triplet represents a complete feature
information required to technically describe a feature.

*NOTE* An obsoleted feature description must never be removed from the source
code. First in order to provide necesarry information to some third-party code
which may rely on this entry to exists. Second to avoid re-use of the same
keyword for different or differently implemented feature. For example, would
old plugins framework be described by =EXTENSIONS= keyword then the new framework
with incompatible API is better be named after the core version where it was first
introduced: =EXTENSIONS_3=.

Feature sets has two most typica use cases:

   1. An extension could declare what features it requires to function. Failure
      to comply would draw the extension invalid and lead to core rejecting to
      load it. For example, a very old extension could require
      =OLDWIKI_COMPATIBILITY= and until adapted for the new core it won't
      function on versions 4.0 and later.
   1. A wiki topic could check against context to check if certain functionality
      could be used with current Foswiki version.
      
Of course, these are not the only possible uses.

---++ Feature meta data.

While verion triplet is mandatory for a feature entry, additional meta data
could be provided after it. The format of the data is a key/value pair similar
to hashes. In the synoposis above such metadata represented by =-desc= key which
is a short name of =-description= and provides brief information about the feature.

Metadata keys are of almost free form and are not controlled by the feature set
framework. The only limitation applied is that every key must be prefixed with a
dash.

Though few of the keys are expected to be supported by Foswiki documentation
handler or a special macro which would generate a table of provided features.
These keys are:

| *Key* | *Description* |
| =-desc= or =-description= | Brief description of the feature. |
| =-proposal= | Name of the proposal where the feature was described. |
| =-doc= or =-documentation= | A topic or a link where feature is documented. |

---++ Namespaces

A namespace is a way to group features into isolated subsets. Namespaces are
named. As with meta data keys above there is no limitations imposed on the names
except that the word _CORE_ is reserved for the default system namespace.

*NOTE* It is not recommended to use the word _CORE_ directly to refer to the
default namespace. Though very unlikely but it is possible that the name would
change in the future.

But since any freedom comes with responsibility a namespace must be called responsively
in order to avoid possible clashes with other namespaces. The following rules are
to be followed:

   * Namespace is to be named after the module it is bound to.
   * If module name has =Foswiki::= prefix it could be omitted.
   * If namespace is bound to an extension then it could be named using =Ext::=
     prefix and short extension name. For example, an extension
     =Foswiki::Extension::EmptyOne= could register a namespace _Ext::EmptyOne_.
     
A feature must have a unique name within its namespace. An attempt to register
a duplicate feature keyword will result in raising =Foswiki::Exception::Fatal=
exception.

#AppContext
---++ Application context

Active features (including the deprecated ones) are registered in the application
context and could be checked by any code where the context is accessible. This
is specifically useful as not all code has access to the core API.

Before registered in the context a feature names gets transofrmed to avoid
possible name conflicts with other context entries and between featues from
different namespaces. The transformation is as simple as:

   1. SUPPORTS_ prefix is appended to the feature keyword.
   1. If feature comes from the default namespace then nothing else is done to it.
   1. If feature is registered in a non-default namespace then it is prefixed
      with namespace's name and double colon '::'.
      
For example:

| *Feature* | *Namespace* | *Context key* |
| =PARA_INDENT= | _default_ | =SUPPORTS_PARA_INDENT= |
| =NS_FEATURE= | Ext::Test | =Ext::Test::SUPPORTS_NS_FEATURE= |

---++ API

=cut

package Foswiki::FeatureSet;
use v5.14;

use strict;
use warnings;

use version 0.77;
use Data::Dumper;

use Foswiki::Exception;

use Exporter qw(import);

our @EXPORT    = qw(features_provided);
our @EXPORT_OK = qw(
  activeFeatures getFSNamespaces features2Context featuresComply
  isActiveFeature isActiveVersion isDeprecaredFeature isDeprecatedVersion
  cleanupFeatures getNSFeatures featureMeta featureVersions
  FS_CORE_NS
);
our %EXPORT_TAGS = ( all => [ @EXPORT, @EXPORT_OK ], );

use constant FS_CORE_NS => 'CORE';

our %features;

=begin TML

---+++ StaticMethod features_provided(@)

Registers features within default or a specified namespace. See synopsis for
usage example.

This function is prototyped to receive a list of parameters. The list contain
even number of elements and represent key/value pairs. The keys representing
either feature names (keywords) or options. Options are differentiated from
keywords by prefixing their names with a dash. This calling convention is
used by all functions provided by the module.

For now the only option supported by this function is =-namespace=. It defines
namespace to which the following features will belong. For example:

<verbatim>
features_provided
    FEATURE1 => [ undef, undef, undef, ],
    -namespace => 'Aux::NS',
    FEATURE2 => [ undef, undef, undef, ],
    FEATURE1 => [ undef, undef, undef, ],
    ;
</verbatim>

In this code the first =FEATURE1= would belong to the default namespace
while =FEATURE2= and second =FEATURE1= will go into =Aux::NS=. Note also
that without the =-namespace= option this call would generate a fatal
exception because of the duplicating features.

The default namespace could be referred by any _FALSE_ perl value. The example
above could be rewritten in the following way:

<verbatim>
features_provided
    -namespace => 'Aux::NS',
    FEATURE2 => [ undef, undef, undef, ],
    FEATURE1 => [ undef, undef, undef, ],
    -namespace => '',
    FEATURE1 => [ undef, undef, undef, ],
    ;
</verbatim>

=cut

sub features_provided (@) {

    Foswiki::Exception::Fatal->throw(
        text => "Odd number of elements in call to features_provided", )
      unless ( @_ % 2 ) == 0;

    my $namespace = _nsFromParam();       # Returns default NS if no arguments.
    my $nsHash    = _getNS($namespace);
    while (@_) {
        my $key   = shift;
        my $value = shift;

        if ( $key =~ /^-/ ) {

            # Process an option.

            if ( $key eq '-namespace' ) {

                # If option value is not defined then reset NS to the default;
                $namespace = _nsFromParam( $key => $value );
                $nsHash = _getNS($namespace);
            }
            else {
                warn "Feature set option $key is not supported";
            }
        }
        else {
            Foswiki::Exception::Fatal->throw(
                text => "Duplicated feature " . $key . " detected", )
              if $nsHash->{$key};

            my $data = _verifyFeatureData( $key, $value );

            $nsHash->{$key} = $data;
        }
    }
}

=begin TML

---+++ StatucMethod getFSNamespaces => @nsList

Returns unordered list of registered namespaces.

=cut

sub getFSNamespaces {
    return grep { $_ ne FS_CORE_NS } keys %features;
}

=begin TML

---++ StatucMethod nsExists( $ns ) => $bool

Returns true if namespace defined by =$ns= exists.

=cut

sub nsExists {
    my $ns = shift;

    # The default NS always exists.
    return !$ns || $ns eq FS_CORE_NS || defined $features{$ns};
}

=begin TML

---+++ StaticMethod getNSFeatures( $ns ) => @features

Returns unordered list of features registered under specified namespace.

=cut

sub getNSFeatures {
    my $namespace;

    $namespace = _nsFromParam(@_);
    _checkNSExists($namespace);
    return keys %{ _getNS($namespace) };
}

=begin TML

---+++ StaticMethod featureMeta($feature [, -namespace => $ns]) => \%metaHash

Returns meta data for a feature. If feature doesn't exists in
the namespace =$ns= then _undef_ is returned.

Another calling notation is possible: =featureMeta($feature[, $ns])=.

=cut

sub featureMeta {
    my $feature   = shift;
    my $namespace = _nsFromParam(@_);

    return undef unless nsExists($namespace);

    my %meta = %{ _getNS($namespace)->{$feature} };

    # Only keys starting with - belong to meta data.
    delete @meta{ grep { !/^-/ } keys %meta };
    return \%meta;
}

=begin TML

---+++ StaticMethod featureVersions($feature [, -namespace => $ns]) => [ $introduced, $deprecated, $obsoleted ]

Returns feature's version triplet or _undef_ for a missing namespace or feature.

Similarly to =featureMeta()= function =featureVersions($feature [, $ns])=
calling convention is valid.

=cut

sub featureVersions {
    my $feature   = shift;
    my $namespace = _nsFromParam(@_);

    return undef unless nsExists($namespace);
    my $nsHash = _getNS($namespace);
    return undef unless defined $nsHash->{$feature};

    my @vTriplet = @{ $nsHash->{$feature}{'.versions'} };

    return \@vTriplet;
}

=begin TML

---+++ StaticMethod activeFeatures($version [, -namespace => $ns]) => \@activeFeatures

Returns unordered list of features in namespace =$ns= active for version
=$version=.

If =$version= is _undef_ then the current Foswiki version is used
(check out $Foswiki::VERSION). A call:

<verbatim>
my @fsList = activeFeatures;
</verbatim>

would return all feature from the default namespace active for the
current version.

=cut

sub activeFeatures {
    my $version = shift;

    my @active;
    foreach my $feature ( getNSFeatures(@_) ) {

        push @active, $feature
          if isActiveFeature( $feature, $version, @_ );
    }

    return @active;
}

=begin TML

---+++ StaticMethod deprecatedFeatures($version [, -namespace => $ns ])

Similar to the =activeFeatures= function but returns unordered list of
deprecated features.

=cut

sub deprecatedFeatures {
    my $version = shift;

    my @deprecated;
    foreach my $feature ( getNSFeatures(@_) ) {

        push @deprecated, $feature
          if isDeprecatedFeature( $feature, $version, @_ );
    }

    return @deprecated;
}

=begin TML

---+++ StaticMethod isActiveFeature($feature, $version [, -namespace => $ns]) => $bool

Returns true if feature =$feature= is active in version =$version=.

Similarly to =featureMeta()= function =-namespace= option could be ommited and
only namespace name =$ns= used.

=cut

sub isActiveFeature {
    my $feature = shift;
    my $version = shift;

    my $fsVersions = featureVersions( $feature, @_ );

    return 0 unless defined $fsVersions;

    return isActiveVersion( $fsVersions, $version, @_ );
}

=begin TML

---+++ StaticMethod isDeprecatedFeature($feature, $version [, -namespace => $ns]) => $bool

Returns true if feature is deprecated in version =$version=.

The =-namespace= option could be oimmited too as for =isActiveFeature()=.

=cut

sub isDeprecatedFeature {
    my $feature = shift;
    my $version = shift;

    my $fsVersions = featureVersions( $feature, @_ );

    return 0 unless defined $fsVersions;

    return isDeprecatedVersion( $fsVersions, $version, @_ );
}

=begin TML

---+++ StaticMethod isActiveVersion(\@verTriplet, $version) => $bool

Returns true if =$version= belongs to the active range of versions
as defined by version triplet in =@verTriplet=.

=cut

sub isActiveVersion {
    my $vTriplet = shift;
    my $version  = _normalizeVersion(shift);

    # Obsoletion version is not the last one where the feature exists but the
    # first one where it's extinct.
    return ( !defined( $vTriplet->[0] ) || $version >= $vTriplet->[0] )
      && ( !defined( $vTriplet->[2] ) || $version < $vTriplet->[2] );
}

=begin TML

---+++ StaticMethod isDeprecatedVersion(\@verTriplet, $version) => $bool

Returns true if =$version= belongs to the deprecated range of versions
as defined by version triplet in =@verTriplet=.

=cut

sub isDeprecatedVersion {
    my $vTriplet = shift;
    my $version  = _normalizeVersion(shift);

    return 0 unless defined $vTriplet->[1];

    return ( $version >= $vTriplet->[1] )
      && ( !defined( $vTriplet->[2] ) || $version < $vTriplet->[2] );
}

=begin TML

---+++ StaticMethod featuresComply(%options) => $bool

This function checks if a set of required features complies with
a set active features. The check could be performed for a specific
version and a specific namespace.

The =%options= hash can have the following keys:

| *Key* | *Description* | *Default* |
| =-version= | The version we check for | =$Foswiki::VERSION= |
| =-features= | A list of required features | |
| =-namespace= | A namespace names | _the default namespace_ |

Returns true if all features from the =-features= list exist and active in
version =-version=.

=cut

sub featuresComply {
    my %params = @_;

    my $version = $params{-version};
    my @fsList  = @{ $params{-features} };

    delete @params{qw(-version -features)};

    my $comply = ( @fsList > 0 );

    while ( $comply && @fsList ) {
        my $feature = shift @fsList;
        $comply &&= isActiveFeature( $feature, $version, %params );
    }

    return $comply;
}

=begin TML

---+++ StaticMethod ns2Context($ns) => $contextPrefix

Returns prefix to be prepended to a feature keyword to form a valid context
entry. See the [[#AppContext][Application Context]] section.

=cut

sub ns2Context {
    my $ns = shift;

    return ( $ns && ( $ns eq FS_CORE_NS ) ) ? '' : $ns . "::";
}

=begin TML

---+++ StaticMethod features2Context(%options) => %contextHash or \%contextHash

Fetches all features from all namespaces and forms context hash to be inserted
into the application context as described in [[#AppContext][Application Context]]
section.

The following =%options= keys are supported:

| *Key* | *Description* | *Default* |
| =-version= | Version to generate context for. | =$Foswiki::VERSION= |


Returns either hash or hash ref depending on the calling context (scalar or
array).

=cut

sub features2Context {
    my %params = @_;

    my $ver = $params{-version};

    my @nsList = getFSNamespaces;

    push @nsList, FS_CORE_NS;

    my %context;

    foreach my $ns (@nsList) {
        my $contextNS = ns2Context($ns);
        my @fsList = activeFeatures( $ver, -namespace => $ns );
        foreach my $feature (@fsList) {
            $context{ $contextNS . 'SUPPORTS_' . $feature } = 1;
        }
    }
    return wantarray ? %context : \%context;
}

# XXX For test purposes only, must not be used in real life!
sub cleanupFeatures {
    %features = ();
}

=begin TML

---+++ StaticMethod _nsFromParam(@options) => $namespace

Fetches namespace from an options list and returns it
if found. Otherwise the default namespace is returned. The function supports
both key/value list calling convention and a single namespace parameter.
I.e. it could be called either as:

<verbatim>
my $ns = _nsFromParam(-version => 'v1.2', -namespace => 'Test::NS', -feature => 'FEATURE');
</verbatim>

or as:

<verbatim>
my $ns = _nsFromParam('Test::NS');
</verbatim>

For functions with mixed positional and named parameters this approach
allows to use both system- and user-friendly ways of calling them. I.e.
whereas system would prefer named parameters for uniformity users
would like positional more for less typing. Check out methods like
=featureVersions= or =getNSFeatures= for example.

Every code using or working with namespace must get the name by
calling this function. 

=cut

sub _nsFromParam {
    my $ns;

    # A little trick to make it possible to use both single parameter and
    # (-option => value) calling conventions.
    if ( @_ == 1 ) {
        $ns = $_[0];
    }
    else {
        my %opts = @_;
        $ns = $opts{-namespace};
    }
    return $ns || FS_CORE_NS;
}

=begin TML

---+++ StaticMethod _verifyFeatureData($feature, $data) => $bool

This function checks if data supplied with a feature keyword is valid.
This means:

   1. The data is an arrayref
   1. The array is at least three elements long
   1. The first three elements of the array are either undef or valid versions (see =_normalizeVersion=)
   1. The remaining elements are valid option key/value pairs where option key is prefixed with a dash
   
In case any of the above conditions fail a =Foswiki::Exception::Fatal= is raised.

=cut

sub _verifyFeatureData {
    my $feature = shift;
    my $data    = shift;

    my $dataType = defined($data) ? ( ref($data) || 'scalar' ) : 'undef';
    my $errPrefix = "Feature $feature data";
    Foswiki::Exception::Fatal->throw(
        text => "$errPrefix must be an array, not " . $dataType )
      unless $dataType eq 'ARRAY';
    Foswiki::Exception::Fatal->throw( text =>
          "$errPrefix array must have at least three elements (versions)." )
      unless ( @$data >= 3 );
    Foswiki::Exception::Fatal->throw( text =>
          "$errPrefix has odd number of elements after versions triplet." )
      unless ( ( @$data - 3 ) % 2 == 0 );

    my @ver;
    for ( 1 .. 3 ) {
        my $vstr = shift @$data;
        if ( defined $vstr ) {
            push @ver, _normalizeVersion($vstr);
        }
        else {
            push @ver, undef;
        }
    }

    my %fsMeta = ( '.versions' => \@ver );

    while (@$data) {
        my $key = shift @$data;
        my $val = shift @$data;

        # Don't allow non-option format keys as this is the only allowed format
        # for user-defined data.
        Foswiki::Exception::Fatal->throw( text => "Feature meta-data key ("
              . $key
              . ") must begin with dash." )
          unless $key =~ /^-/;
        $fsMeta{$key} = $val;
    }

    return \%fsMeta;
}

=begin TML

---+++ StaticMethod _normalizeVersion($version) => $verObject

Converts its parameter into a valid =version= object. If =$version=
is _undef_ then =$Foswiki::VERSION= is used as the default.

=Foswiki::Exception::Fatal= is raised if =$version= cannot be parsed
into a valid version object (see =version::is_lax()=).

=cut

sub _normalizeVersion {
    my $version = shift;

    $version //= $Foswiki::VERSION;

    Foswiki::Exception::Fatal->throw(
        text => "Invalid version string " . $version )
      unless version::is_lax($version);

    return version->parse($version);
}

=begin TML

---+++ StaticMethod _getNS($ns) => \%namespaceHash

Returns namespace hash; creates a new one if specified namespace
doesn't exists yet.

=cut

sub _getNS {
    my $ns = shift;

    $features{$ns} //= {};

    return $features{$ns};
}

=begin TML

---+++ StaticMethod _checkNSExists($ns)

Raises an =Foswiki::Exception::Fatal= if namespace defined by =$ns= doesn't
exists.

=cut

sub _checkNSExists {
    my $ns = shift;

    Foswiki::Exception::Fatal->throw(
        text => "Non existant namespace `" . $ns . "'", )
      unless nsExists($ns);
}

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
