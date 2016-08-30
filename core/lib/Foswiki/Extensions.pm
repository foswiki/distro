# See bottom of file for license and copyright information

package Foswiki::Extensions;

use File::Spec     ();
use IO::Dir        ();
use Devel::Symdump ();
use Scalar::Util qw(blessed);

use Assert;
use Try::Tiny;
use Data::Dumper;
use Foswiki::Exception;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);

# This is the version to be matched agains extension's API version declaration.
# Extension is considered valid only if it's API version is no higher than
# $VERSION.
use version 0.77; our $VERSION = version->declare("2.99.0");

# The minimal API version this module supports. If an extension declares API
# version lower than this it gets rejected.
our $MIN_VERSION = version->declare("2.99.0");

# --- Static data registered upon extension's module load and to be parsed when
# extensions are built.
# NOTE All data stored in globals is raw and must be revalidated before used.
our @extModules;  # List of the extension modules in the order they were loaded.
our %loadedModules;    # Modules been loaded previously.
our %extSubClasses;    # Subclasses registered by extensions.
our %extDeps;   # Module dependecies. Influences the order of extension objects.

# --- END of static data declarations

has extensions => (
    is      => 'rw',
    lazy    => 1,
    default => sub { [] },
);

has extSubdir => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareExtSubdir',
);

=begin TML

---++ ObjectAttribute extPrefix => string

Extension modules name prefix. Used by =normalizeExtName()= method and for locating extension by their =.pm= files.

Default: Foswiki::Extension.

=cut

has extPrefix => (
    is      => 'ro',
    default => 'Foswiki::Extension',
);

has _errors => (
    is      => 'rw',
    lazy    => 1,
    default => sub { [] },
);
has _disabledExtensions => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    default => sub {
        my $this = shift;
        return { map { $this->normalizeExtName($_) => 1 }
              $this->listDisabledExtensions };
    },
);

sub BUILD {
    my $this = shift;

    say STDERR "Initializing extensions" if DEBUG;

    $this->load_extensions;

    say STDERR "Ext sub classes: ", Dumper( \%extSubClasses );
    say STDERR "Ext deps: ",        Dumper( \%extDeps );
}

sub normalizeExtName {
    my $this = shift;
    my ($extName) = @_;
    unless ( $extName =~ /::/ ) {

        # Attempt to load en extension by its short name.
        $extName = $this->extPrefix . "::" . $extName;
    }
    return $extName;
}

sub extEnabled {
    my $this = shift;
    my ($extName) = @_;

    $extName = $this->normalizeExtName($extName);

    return $this->_disabledExtensions->{$extName} ? undef : $extName;
}

sub checkVersion {
    my $this = shift;
    my ($extName) = @_;

    my @apiScalar = grep { /::API_VERSION$/ } Devel::Symdump->scalars($extName);

    Foswiki::Exception::Ext::Load->throw(
        extension => $extName,
        reason    => "No \$API_VERSION scalar defined in $extName",
    ) unless @apiScalar;

    my $api_ver = Foswiki::fetchGlobal( '$' . $apiScalar[0] );

    Foswiki::Exception::Ext::Load->throw(
        extension => $extName,
        reason    => "Failed to fetch \$API_VERSION",
    ) unless defined $api_ver;

    Foswiki::Exception::Ext::Load->throw(
        extension => $extName,
        reason    => "Declared API version "
          . $api_ver
          . " is lower than supported "
          . $MIN_VERSION,
    ) if $api_ver < $MIN_VERSION;

    Foswiki::Exception::Ext::Load->throw(
        extension => $extName,
        reason    => "Declared API version "
          . $api_ver
          . " is higher than supported "
          . $VERSION,
    ) if $api_ver > $VERSION;
}

sub _loadExtModule {
    my $this = shift;
    my ($extModule) = @_;

    return if isLoaded($extModule);

    try {
        Foswiki::load_class($extModule);
        $this->checkVersion($extModule);
        registerExtModule($extModule);
    }
    catch {
        Foswiki::Exception::Ext::Load->rethrow(
            $_,
            extension => $extModule,
            reason    => Foswiki::Exception::errorStr($_),
        );
    };
}

sub load_extensions {
    my $this = shift;

    my $extDir = IO::Dir->new( $this->extSubdir );
    Foswiki::Exception::FileOp->throw(
        file => $this->extSubdir,
        op   => "opendir",
    ) unless defined $extDir;

    while ( my $dirEntry = $extDir->read ) {
        next if -d $dirEntry || $dirEntry !~ /\.pm$/;

        # SMELL $dirEntry is tainted but this we must take care of later.
        my $extModule;
        try {
            if ( $dirEntry =~
                /^(\w+)\.pm$/a )    # We match against ASCII symbols only.
            {
                $extModule = $this->normalizeExtName($1);
                $this->_loadExtModule($extModule);
            }
            else {
                # SMELL Bad extension file name, shall we do something about it?
                # Note that loggins isn't possible yet. But we can rely upon
                # server logging perhaps.
                Foswiki::Exception::Ext::BadName->throw(
                    extension => $dirEntry );
            }
        }
        catch {
            # We don't really fail upon extension load because this ain't fatal
            # in neither way. What bad could unloaded extension cause?
            push @{ $this->_errors },
              Foswiki::Exception::Ext::Load->transmute( $_, 1,
                extension => $extModule );
            say STDERR "Extension $extModule problem: \n",
              Foswiki::Exception::errorStr( $this->_errors->[-1] );
        };
    }
}

sub prepareExtSubdir {
    my $this = shift;

    my $fwPath = $this->app->env->{FOSWIKI_LIBS};

    # If the env is not set guess by Foswiki.pm module.
    $fwPath //= ( File::Spec->splitpath( $INC{'Foswiki.pm'} ) )[1];

    return File::Spec->catfile( $fwPath, split( /::/, $this->extPrefix ) );
}

=begin TML

---++ ObjectMethod listDisabledExtensions => @list

Returns a list of extensions disabled for this installation or host.

=cut

sub listDisabledExtensions {
    my $this     = shift;
    my $env      = $this->app->env;
    my $envVar   = 'FOSWIKI_DISABLED_EXTENSIONS';
    my $disabled = $env->{$envVar} // '';
    my @list;
    if ( my $reftype = ref($disabled) ) {
        Foswiki::Exception::Fatal->throw(
                text => "Environment variable $envVar is a ref to "
              . $reftype
              . " but ARRAY excepted" )
          unless $reftype eq 'ARRAY';
        @list = @$disabled;
    }
    else {
        @list = split /,/, $disabled;
    }
    return @list;
}

sub registerSubClass {
    my ( $extModule, $class, $subClass ) = @_;

    push @{ $extSubClasses{$class} },
      {
        extension => $extModule,
        subClass  => $subClass
      };
}

sub registerExtModule {
    my ($extModule) = @_;

    push @extModules, $extModule;
    $loadedModules{$extModule} = 1;
}

sub registerDeps {
    my $extModule = shift;

    push @{ $extDeps{$extModule} }, @_;
}

sub isLoaded {
    my ($extModule) = @_;

    return $loadedModules{$extModule} // 0;
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
