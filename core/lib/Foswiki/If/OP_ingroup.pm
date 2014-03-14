# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::If::OP_ingroup
Test if the user named on the LHS is in the user group named on the RHS.

=cut

package Foswiki::If::OP_ingroup;

use strict;
use warnings;

use Foswiki::Query::OP ();
our @ISA = ('Foswiki::Query::OP');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my $class = shift;
    return $class->SUPER::new(
        arity       => 2,
        name        => 'ingroup',
        prec        => 600,
        casematters => 1
    );
}

sub evaluate {
    my $this = shift;
    my $node = shift;
    my $a =
      $node->{params}->[0]
      ;    # user cUID/ loginname / WikiName / WebDotWikiName :( (string)
    my $b       = $node->{params}->[1];    # group name (string
    my %domain  = @_;
    my $session = $domain{tom}->session;
    throw Error::Simple(
        'No context in which to evaluate "' . $a->stringify() . '"' )
      unless $session;
    my $user = $session->{users}->getCanonicalUserID( $a->evaluate(@_) );
    return 0 unless $user;
    my $group = $b->_evaluate(@_);
    return 0 unless $group;
    return 1 if ( $session->{users}->isInGroup( $user, $group ) );
    return 0;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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
