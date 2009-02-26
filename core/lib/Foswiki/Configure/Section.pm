# See bottom of file for license and copyright information

package Foswiki::Configure::Section;

use base 'Foswiki::Configure::Item';

use strict;

sub new {
    my ( $class, $head ) = @_;

    # SMELL: What is the base object supposed to do with the UI class?
    my $this = $class->SUPER::new('Foswiki::Configure::UIs::Section');

    $this->{headline} = $head;
    @{ $this->{children} } = ();

    return $this;
}

sub addChild {
    my ( $this, $child ) = @_;
    foreach my $kid ( @{ $this->{children} } ) {
        Carp::confess if $child eq $kid;
    }
    $child->{parent} = $this;
    push( @{ $this->{children} }, $child );
}

sub isExpertsOnly {
    my $this = shift;
    if ( !defined( $this->{isExpert} ) ) {
        $this->{isExpert} = 1;
        foreach my $kid ( @{ $this->{children} } ) {
            if ( !$kid->isExpertsOnly() ) {
                $this->{isExpert} = 0;
                last;
            }
        }
    }
    return $this->{isExpert};
}

sub visit {
    my ( $this, $visitor ) = @_;
    my %visited;
    return 0 unless $visitor->startVisit($this);
    foreach my $child ( @{ $this->{children} } ) {
        if ( $visited{$child} ) {
            die join( ' ', @{ $this->{children} } );
        }
        $visited{$child} = 1;
        return 0 unless $child->visit($visitor);
    }
    return 0 unless $visitor->endVisit($this);
    return 1;
}

sub getDepth {
    my $depth = 0;
    my $mum   = shift;

    while ($mum) {
        $depth++;
        $mum = $mum->{parent};
    }
    return $depth;
}

# Get the section object associated with the given headline and depth
sub getSectionObject {
    my ( $this, $head, $depth ) = @_;
    if ( $this->{headline} eq $head && $this->getDepth() == $depth ) {
        return $this;
    }
    foreach my $child ( @{ $this->{children} } ) {
        my $cvo = $child->getSectionObject( $head, $depth );
        return $cvo if $cvo;
    }
    return undef;
}

# Get the value object associated with the given keys
sub getValueObject {
    my ( $this, $keys ) = @_;
    foreach my $child ( @{ $this->{children} } ) {
        my $cvo = $child->getValueObject($keys);
        return $cvo if $cvo;
    }
    return undef;
}

# See if this section is changed from the default values. Should
# return a count of changed values.
sub needsSaving {
    my ( $this, $valuer ) = @_;
    my $count = 0;
    foreach my $child ( @{ $this->{children} } ) {
        $count += $child->needsSaving($valuer);
    }
    return $count;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
#
# Collection of configuration items
