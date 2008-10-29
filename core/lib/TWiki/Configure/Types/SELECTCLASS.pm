#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
package TWiki::Configure::Types::SELECTCLASS;

use strict;

use TWiki::Configure::Types::SELECT;

use base 'TWiki::Configure::Types::SELECT';

# generate an input field for SELECTCLASS types
# Takes a comma-separated list of options
# Each option must be either 'none' or a wildcard expression that matches classes e.g.
# TWiki::Plugins::*Plugin
# * is the only wildcard supported
# Finds all classes that match in @INC
sub prompt {
    my( $this, $id, $opts, $value ) = @_;
    my @ropts;
    $opts =~ s/\s.*$//; # remove e.g. EXPERT
    foreach my $opt (split( /,/, $opts)) {
        if ($opt eq 'none') {
            push(@ropts, 'none');
        } else {
            push(@ropts, @{$this->findClasses($opt)});
        }
    }
    return $this->SUPER::prompt($id, join(',', @ropts), $value);
}

# $pattern is a wildcard expression that matches classes e.g.
# TWiki::Plugins::*Plugin
# * is the only wildcard supported
# Finds all classes that match in @INC
sub findClasses {
    my ($this, $pattern) = @_;

    $pattern =~ s/\*/.*/g;
    my @path = split(/::/, $pattern);

    my $places = \@INC;

    while (scalar(@path) > 1 && @$places) {
        my $pathel = shift(@path);
        eval "\$pathel = qr/^($pathel)\$/"; # () to untaint
        my @newplaces;

        foreach my $place (@$places) {
            if( opendir( DIR, $place ) ) {
                foreach my $subplace ( readdir DIR ) {
                    next unless $subplace =~ $pathel;
                    push(@newplaces, $place.'/'.$1);
                }
            }
        }
        $places = \@newplaces;
    }

    my @list;
    my $leaf = shift(@path);
    eval "\$leaf = qr/$leaf\.pm\$/";
    my %known;
    foreach my $place (@$places) {
        if (opendir( DIR, $place )) {
            foreach my $file ( readdir DIR ) {
                next unless $file =~ $leaf;
                $file =~ /^(.*)\.pm$/;
                my $module = "$place/$1";
                $module =~ s./.::.g;
                $module =~ /($pattern)$/;
                push(@list, $1) unless $known{$1};
                $known{$1} = 1;
            }
        }
    }

    return \@list;
}

1;
