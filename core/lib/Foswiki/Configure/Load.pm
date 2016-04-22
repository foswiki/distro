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

# This should be the one place in Foswiki that knows the syntax of valid
# configuration item keys. Only simple scalar hash keys are supported.
#
our $ITEMREGEX = qr/(?:\{(?:'(?:\\.|[^'])+'|"(?:\\.|[^"])+"|[A-Za-z0-9_]+)\})+/;

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
    $Foswiki::app->cfg->expandValue($val);
    return $val;
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
