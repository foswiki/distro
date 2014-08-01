# See bottom of file for license and copyright information

package Foswiki::Configure::FileUtil;

=begin TML

---+ package Foswiki::Configure::FileUtil

Basic file utilities

=cut

use strict;
use warnings;

=begin TML

---++ StaticMethod findFileOnPath($filename) ->> $fullpath
Find a file on the @INC path, or undef if not found.

$filename may be a simple file name e.g. Example.pm
or may be a /-separated path e.g. Net/Util
or a class path e.g. Net::Util

Note that a terminating .pm is required to find a
perl module.

=cut

sub findFileOnPath {
    my $file = shift;

    $file =~ s(::)(/)g;

    foreach my $dir (@INC) {
        if ( -e "$dir/$file" ) {
            return "$dir/$file";
        }
    }
    return undef;
}

=begin TML

---++ StaticMethod findPackages( $pattern ) -> @list

Finds all packages that match the pattern in @INC

   * =$pattern= is a wildcard expression that matches classes e.g.
     Foswiki::Plugins::*Plugin. * is the only wildcard supported.

Return a list of package names.

=cut

sub findPackages {
    my ($pattern) = @_;

    $pattern =~ s/\*/.*/g;
    my @path = split( /::/, $pattern );

    my $places = \@INC;

    while ( scalar(@path) > 1 && @$places ) {
        my $pathel = shift(@path);
        eval "\$pathel = qr/^($pathel)\$/";    # () to untaint
        my @newplaces;

        foreach my $place (@$places) {
            if ( opendir( DIR, $place ) ) {

                #next if ($place =~ /^\..*/);
                foreach my $subplace ( readdir DIR ) {
                    next unless $subplace =~ $pathel;

                    #next if ($subplace =~ /^\..*/);
                    push( @newplaces, $place . '/' . $1 );
                }
                closedir DIR;
            }
        }
        $places = \@newplaces;
    }

    my @list;
    my $leaf = shift(@path);
    eval "\$leaf = qr/$leaf\.pm\$/";
    my %known;
    foreach my $place (@$places) {
        if ( opendir( DIR, $place ) ) {
            foreach my $file ( readdir DIR ) {
                next unless $file =~ $leaf;
                next if ( $file =~ /^\..*/ );
                $file =~ /^(.*)\.pm$/;
                my $module = "$place/$1";
                $module =~ s./.::.g;
                $module =~ /($pattern)$/;
                push( @list, $1 ) unless $known{$1};
                $known{$1} = 1;
            }
            closedir DIR;
        }
    }

    return @list;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
