# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::Root;

use strict;
use warnings;

use Foswiki::Configure::UI ();

use Foswiki::Configure::UIs::Section ();
our @ISA = ('Foswiki::Configure::UIs::Section');

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);
    $this->{tabs} = [];
    return $this;
}

# Visit the nodes in a tree of configuration items, and generate
# their UIs.
sub ui {
    my ( $this, $tree, $valuer ) = @_;

    $this->{valuer} = $valuer;
    $this->{output} = '';
    @{ $this->{stack} } = ();
    $tree->visit($this);
    return $this->{output};
}

# Called on each node in the tree as a visit starts
sub startVisit {
    my ( $this, $item ) = @_;

    # Stack the output from previously visited nodes

    my $class = ref($item);
    $class =~ s/.*:://;
    return 1
      if ( $class eq 'Value' )
      ;    # rendering of values - en groupe - is done in Section object

    push( @{ $this->{stack} }, $this->{output} );
    $this->{output} = '';
    return 1;
}

# Called on each node in the tree as a visit ends
sub endVisit {
    my ( $this, $item ) = @_;

    my $class = ref($item);
    $class =~ s/.*:://;
    return 1
      if ( $class eq 'Value' )
      ;    # rendering of values - en groupe - is done in Section object

    my $ui = Foswiki::Configure::UI::loadUI( $class, $item );
    die "Fatal Error - Could not load UI for $class - $@" unless $ui;
    $this->{output} =
      pop( @{ $this->{stack} } )
      . $ui->renderHtml( $item, $this, $this->{output} );

    return 1;
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
