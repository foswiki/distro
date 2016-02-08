# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::If::OP_context

=cut

package Foswiki::If::OP_context;
use v5.14;

use Moo;
use namespace::clean;
extends qw(Foswiki::Query::UnaryOP);
with qw(Foswiki::Query::OP);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    return $orig->(
        $class,
        name        => 'context',
        prec        => 600,
        casematters => 0
    );
};

sub evaluate {
    my $this    = shift;
    my $node    = shift;
    my $a       = $node->params->[0];
    my $text    = $a->_evaluate(@_) || '';
    my %domain  = @_;
    my $session = $domain{tom}->session;
    Foswiki::Exception->throw(
        text => 'No context in which to evaluate "' . $a->stringify() . '"' )
      unless $session;
    return $session->inContext($text) || 0;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
