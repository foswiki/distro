# See bottom of file for license and copyright information
package Foswiki::Configure::TypeUIs::BOOLGROUP;

use strict;
use warnings;

use Foswiki::Configure::TypeUI ();
our @ISA = ('Foswiki::Configure::TypeUI');

sub prompt {
    my ( $this, $model, $value, $class ) = @_;
    
    my @selected;
    if ( defined($value) ) {
        foreach my $sel ( split( /,\s*/, $value ) ) {
            push @selected, $sel;
        }
    }
    
    return CGI::checkbox_group(
        -name     => $model->{keys},
        -values   => \@{$model->{select_from}},
        -default  => \@selected,
        -label    => '',
        -onchange => 'valueChanged(this)',
        -rows     => 1,
        -columns  => scalar @{$model->{select_from}},
        );
}

sub string2value {
    my ( $this, @vals ) = @_;
    
    return join( ',', @vals );
}

sub equals {
    my ( $this, $val, $def ) = @_;
    
    return ( $val eq $def );
}
	
1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/
	
Copyright (C) 2012-2014 Foswiki Contributors. Foswiki Contributors
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
