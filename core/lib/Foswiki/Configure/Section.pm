# See bottom of file for license and copyright information
package Foswiki::Configure::Section;

=begin TML

---+ package Foswiki::Configure::Section

A tree node in a configuration item tree; a collection of configuration
items and subsections.

=cut

use strict;
use warnings;

use Foswiki::Configure::Item ();
our @ISA = ('Foswiki::Configure::Item');

=begin TML

---++ ClassMethod new($head, $opts)
   * $head - headline e.g. 'Security Settings'
   * $opts - options

Constructor

=cut

sub new {
    my ( $class, $head, $opts ) = @_;

    my $this = $class->SUPER::new();
    $this->{headline} = $head;
    $this->{opts} = $opts || '';

    @{ $this->{children} } = ();
    @{ $this->{values} }   = ();

    return $this;
}

=begin TML

---++ ObjectMethod addChild($child)
Add a child node under this node.

=cut

sub addChild {
    my ( $this, $child ) = @_;
    foreach my $kid ( @{ $this->{children} } ) {
        Carp::confess if $child eq $kid;
    }
    $child->{parent} = $this;

    if ( $child->isa('Foswiki::Configure::Value') ) {
        push( @{ $this->{values} }, $child );
    }

    push( @{ $this->{children} }, $child );

}

# See Foswiki::Configure::Item
# A section is expert if any of it's children are expert.
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

# See Foswiki::Configure::Item
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

# See Foswiki::Configure::Item
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

# See Foswiki::Configure::Item
sub getValueObject {
    my ( $this, $keys ) = @_;
    foreach my $child ( @{ $this->{children} } ) {
        my $cvo = $child->getValueObject($keys);
        return $cvo if $cvo;
    }
    return;
}

# See Foswiki::Configure::Item
# See if this section is changed from the default values.
sub needsSaving {
    my ( $this, $valuer ) = @_;
    my $count = 0;
    foreach my $child ( @{ $this->{children} } ) {
        $count += $child->needsSaving($valuer);
    }
    return $count;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
