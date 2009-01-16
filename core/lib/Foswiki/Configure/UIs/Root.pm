# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::Root;
use base 'Foswiki::Configure::UIs::Section';

use Foswiki::Configure::UI;

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

sub startVisit {
    my ( $this, $item ) = @_;
    push( @{ $this->{stack} }, $this->{output} );
    $this->{output} = '';
    return 1;
}

sub endVisit {
    my ( $this, $item ) = @_;
    my $class = ref($item);
    $class =~ s/.*:://;
    my $ui = Foswiki::Configure::UI::loadUI( $class, $item );
    die "Fatal Error - Could not load UI for $class - $@" unless $ui;
    $this->{output} =
        pop( @{ $this->{stack} } )
      . $ui->open_html( $item, $this->{valuer}, $this->{experts} )
      . $this->{output}
      .    # only used for sections
      $ui->close_html( $item, $this->{valuer}, $this->{experts} );
    return 1;
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
