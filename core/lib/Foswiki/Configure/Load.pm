# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Load

Handling for loading configuration information (Foswiki.spec, Config.spec and
LocalSite.cfg) as efficiently and flexibly as possible.

This reads *values* from these files and does *not* parse the
structured comments or build a spec database. For that, see LoadSpec.pm

=cut

package Foswiki::Configure::Load;

use strict;
use warnings;

use Cwd qw( abs_path );
use Assert;
use Encode;
use File::Basename;
use File::Spec;
use POSIX qw(locale_h);
use Unicode::Normalize;

use Foswiki::Configure::FileUtil;

# Enable to trace auto-configuration (Bootstrap)
use constant TRAUTO => 1;

# This should be the one place in Foswiki that knows the syntax of valid
# configuration item keys. Only simple scalar hash keys are supported.
#
our $ITEMREGEX = qr/(?:\{(?:'(?:\\.|[^'])+'|"(?:\\.|[^"])+"|[A-Za-z0-9_]+)\})+/;

# Generic booleans, used in some older LSC's
our $TRUE  = 1;
our $FALSE = 0;

# Configuration items that have been deprecated and must be mapped to
# new configuration items. The value is mapped unchanged.
our %remap = (
    '{StoreImpl}'           => '{Store}{Implementation}',
    '{AutoAttachPubFiles}'  => '{RCS}{AutoAttachPubFiles}',
    '{QueryAlgorithm}'      => '{Store}{QueryAlgorithm}',
    '{SearchAlgorithm}'     => '{Store}{SearchAlgorithm}',
    '{Site}{CharSet}'       => '{Store}{Encoding}',
    '{RCS}{FgrepCmd}'       => '{Store}{FgrepCmd}',
    '{RCS}{EgrepCmd}'       => '{Store}{EgrepCmd}',
    '{RCS}{overrideUmask}'  => '{Store}{overrideUmask}',
    '{RCS}{dirPermission}'  => '{Store}{dirPermission}',
    '{RCS}{filePermission}' => '{Store}{filePermission}',
    '{RCS}{WorkAreaDir}'    => '{Store}{WorkAreaDir}'
);

=begin TML

---++ StaticMethod readConfig([$noexpand][,$nospec][,$config_spec][,$noLocal)

In normal Foswiki operations as a web server this method is called by the
=BEGIN= block of =Foswiki.pm=.  However, when benchmarking/debugging it can be
replaced by custom code which sets the configuration hash.  To prevent us from
overriding the custom code again, we use an "unconfigurable" key
=$cfg{ConfigurationFinished}= as an indicator.

Note that this method is called by Foswiki and configure, and normally reads
=Foswiki.spec= to get defaults. Other spec files (those for extensions) are
*not* read unless the $config_spec flag is set.

The assumption is that =configure= will be run when an extension is installed,
and that will add the config values to LocalSite.cfg, so no defaults are
needed. Foswiki.spec is still read because so much of the core code doesn't
provide defaults, and it would be silly to have them in two places anyway.

   * =$noexpand= - suppress expansion of $Foswiki vars embedded in
     values.
   * =$nospec= - can be set when the caller knows that Foswiki.spec
     has already been read.
   * =$config_spec= - if set, will also read Config.spec files located
     using the standard methods (iff !$nospec). Slow.
   * =$noLocal= - if set, Load will not re-read an existing LocalSite.cfg.
     this is needed when testing the bootstrap.  If it rereads an existing
     config, it overlays all the bootstrapped settings.
=cut

sub readConfig {
    my ( $noexpand, $nospec, $config_spec, $noLocal ) = @_;

    # To prevent us from overriding the custom code in test mode
    return 1 if $Foswiki::cfg{ConfigurationFinished};

    # Assume LocalSite.cfg is valid - will be set false if errors detected.
    my $validLSC = 1;

    # Read Foswiki.spec and LocalSite.cfg
    # (Suppress Foswiki.spec if already read)

    my @files;
    unless ($nospec) {
        push @files, 'Foswiki.spec';
    }
    if ( !$nospec && $config_spec ) {
        foreach my $dir (@INC) {
            foreach my $subdir ( 'Foswiki/Plugins', 'Foswiki/Contrib' ) {
                my $d;
                next unless opendir( $d, "$dir/$subdir" );
                my %read;
                foreach
                  my $extension ( grep { !/^\./ && !/^Empty/ } readdir $d )
                {
                    next if $read{$extension};
                    $extension =~ m/(.*)/;    # untaint
                    my $file = "$dir/$subdir/$1/Config.spec";
                    next unless -e $file;
                    push( @files, $file );
                    $read{$extension} = 1;
                }
                closedir($d);
            }
        }
    }
    unless ($noLocal) {
        push @files, 'LocalSite.cfg';
    }

    for my $file (@files) {
        my $return = do $file;

        unless ( defined $return && $return eq '1' ) {

            my $errorMessage;
            if ($@) {
                $errorMessage = "Failed to parse $file: $@";
                warn "couldn't parse $file: $@" if $@;
            }
            next if ( !DEBUG && ( $file =~ m/Config\.spec$/ ) );
            if ( not defined $return ) {
                unless ( $! == 2 && $file eq 'LocalSite.cfg' ) {

                    # LocalSite.cfg doesn't exist, which is OK
                    warn "couldn't do $file: $!";
                    $errorMessage = "Could not do $file: $!";
                }
                $validLSC = 0;
            }

            # Pointless (says CDot), Config.spec does not need 1; at the end
            #elsif ( not $return eq '1' ) {
            #   print STDERR
            #   "Running file $file returned  unexpected results: $return \n";
            #}
            if ($errorMessage) {
                die <<GOLLYGOSH;
Content-type: text/plain

$errorMessage
Please inform the site admin.
GOLLYGOSH
                exit 1;
            }
        }
    }

    # Patch deprecated config settings
    # TODO: remove this in version 2.0
    if ( exists $Foswiki::cfg{StoreImpl} ) {
        $Foswiki::cfg{Store}{Implementation} =
          'Foswiki::Store::' . $Foswiki::cfg{StoreImpl};
        delete $Foswiki::cfg{StoreImpl};
    }
    foreach my $el ( keys %remap ) {

        # Only remap if the old key extsts, and the new key does NOT exist
        if ( ( eval("exists \$Foswiki::cfg$el") ) ) {
            eval( <<CODE );
\$Foswiki::cfg$remap{$el}=\$Foswiki::cfg$el unless ( exists \$Foswiki::cfg$remap{$el} );
delete \$Foswiki::cfg$el;
CODE
            print STDERR "REMAP failed $@" if ($@);
        }
    }

    # Old configs might not bootstrap the OS settings, so set if needed.
    unless ( $Foswiki::cfg{OS} && $Foswiki::cfg{DetailedOS} ) {
        require Foswiki::Configure::Bootstrap;
        Foswiki::Configure::Bootstrap::workOutOS();
    }

    # Expand references to $Foswiki::cfg vars embedded in the values of
    # other $Foswiki::cfg vars.
    expandValue( \%Foswiki::cfg ) unless $noexpand;

    $Foswiki::cfg{ConfigurationFinished} = 1;

    if ( $^O eq 'MSWin32' ) {

        #force paths to use '/'
        $Foswiki::cfg{PubDir}      =~ s|\\|/|g;
        $Foswiki::cfg{DataDir}     =~ s|\\|/|g;
        $Foswiki::cfg{ToolsDir}    =~ s|\\|/|g;
        $Foswiki::cfg{ScriptDir}   =~ s|\\|/|g;
        $Foswiki::cfg{TemplateDir} =~ s|\\|/|g;
        $Foswiki::cfg{LocalesDir}  =~ s|\\|/|g;
        $Foswiki::cfg{WorkingDir}  =~ s|\\|/|g;
    }

    # Alias TWiki cfg to Foswiki cfg for plugins and contribs
    *TWiki::cfg = \%Foswiki::cfg;

    # Add explicit {Site}{CharSet} for older extensions. Default to utf-8.
    # Explanation is in http://foswiki.org/Tasks/Item13435
    $Foswiki::cfg{Site}{CharSet} = 'utf-8';

    # Explicit return true if we've completed the load
    return $validLSC;
}

=begin TML

---++ StaticMethod expanded($value) -> $expanded

Given a value of a configuration item, expand references to
$Foswiki::cfg configuration items within strings in the value.

If an embedded $Foswiki::cfg reference is not defined, it will
be expanded as 'undef'.

=cut

sub expanded {
    my $val = shift;
    return undef unless defined $val;
    expandValue($val);
    return $val;
}

=begin TML

---++ StaticMethod expandValue($datum [, $mode])

Expands references to Foswiki configuration items which occur in the
values configuration items contained within the datum, which may be a
hash or array reference, or a scalar value. The replacement is done in-place.

$mode - How to handle undefined values:
   * false:  'undef' (string) is returned when an undefined value is
     encountered.
   * 1 : return undef if any undefined value is encountered.
   * 2 : return  '' for any undefined value (including embedded)
   * 3 : die if an undefined value is encountered.

=cut

sub expandValue {
    my $undef;
    _expandValue( $_[0], ( $_[1] || 0 ), $undef );

    $_[0] = undef if ($undef);
}

# $_[0] - value being expanded
# $_[1] - $mode
# $_[2] - $undef (return)
sub _expandValue {
    if ( ref( $_[0] ) eq 'HASH' ) {
        expandValue( $_, $_[1] ) foreach ( values %{ $_[0] } );
    }
    elsif ( ref( $_[0] ) eq 'ARRAY' ) {
        expandValue( $_, $_[1] ) foreach ( @{ $_[0] } );

        # Can't do this, because Windows uses an object (Regexp) for regular
        # expressions.
        #    } elsif (ref($_[0])) {
        #        die("Can't handle a ".ref($_[0]));
    }
    else {
        1 while ( defined( $_[0] )
            && $_[0] =~
            s/(\$Foswiki::cfg$ITEMREGEX)/_handleExpand($1, @_[1,2])/ges );
    }
}

# Used to expand the $Foswiki::cfg variable in the expand* routines.
# $_[0] - $item
# $_[1] - $mode
# $_[2] - $undef
sub _handleExpand {
    my $val = eval( $_[0] );
    die "Error expanding $_[0]: $@" if ($@);

    return $val                                      if ( defined $val );
    return 'undef'                                   if ( !$_[1] );
    return ''                                        if ( $_[1] == 2 );
    die "Undefined value in expanded string $_[0]\n" if ( $_[1] == 3 );
    $_[2] = 1;
    return '';
}

=begin TML

---++ StaticMethod findDependencies(\%cfg) -> \%deps

   * =\%cfg= configuration hash to scan; defaults to %Foswiki::cfg

Recursively locate references to other keys in the values of keys.
Returns a hash containing two keys:
   * =forward= => a hash mapping keys to a list of the keys that depend
     on their value
   * =reverse= => a hash mapping keys to a list of keys whose value they
     depend on.

=cut

sub findDependencies {
    my ( $fwcfg, $deps, $extend_keypath, $keypath ) = @_;

    unless ( defined $fwcfg ) {
        ( $fwcfg, $extend_keypath, $keypath ) = ( \%Foswiki::cfg, 1, '' );
    }

    $deps ||= { forward => {}, reverse => {} };

    if ( ref($fwcfg) eq 'HASH' ) {
        while ( my ( $k, $v ) = each %$fwcfg ) {
            if ( defined $v ) {
                my $subkey = $extend_keypath ? "$keypath\{$k\}" : $keypath;
                findDependencies( $v, $deps, $extend_keypath, $subkey );
            }
        }
    }
    elsif ( ref($fwcfg) eq 'ARRAY' ) {
        foreach my $v (@$fwcfg) {
            if ( defined $v ) {
                findDependencies( $v, $deps, 0, $keypath );
            }
        }
    }
    else {
        while ( $fwcfg =~ m/\$Foswiki::cfg(({[^}]*})+)/g ) {
            push( @{ $deps->{forward}->{$1} },       $keypath );
            push( @{ $deps->{reverse}->{$keypath} }, $1 );
        }
    }
    return $deps;
}

=begin TML

---++ StaticMethod specChanged -> @list

Find all the Spec files (Config.spec and Foswiki.spec) and return
a list of extensions with Spec files newer than LocalSite.cfg.

=cut

sub specChanged {

    my $lsc_m = 0;
    my @list;

    foreach my $dir (@INC) {

        my $file = $dir . '/LocalSite.cfg';
        if ( -e $file && !$lsc_m ) {
            $lsc_m = ( stat($file) )[9];
        }

        $file = $dir . '/Foswiki.spec';
        if ( -e $file ) {
            my $fw_m = ( stat($file) )[9];
            push( @list, 'the core' ) if ( $fw_m > $lsc_m );
        }

        foreach my $subdir ( 'Foswiki/Plugins', 'Foswiki/Contrib' ) {
            my $d;
            next unless opendir( $d, "$dir/$subdir" );
            my %read;
            foreach my $extension ( grep { !/^\./ && !/^Empty/ } readdir $d ) {
                next if $read{$extension};
                $extension =~ m/(.*)/;    # untaint
                $file = "$dir/$subdir/$1/Config.spec";
                next unless -e $file;
                my $ext_m = ( stat($file) )[9];
                push( @list, $extension ) if ( $ext_m > $lsc_m );
            }
            closedir($d);
        }
    }
    return @list;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
