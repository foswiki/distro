# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::If::OP_istopic

=cut

package Foswiki::If::OP_istopic;

use strict;
use warnings;

use Foswiki::Query::UnaryOP ();
our @ISA = ('Foswiki::Query::UnaryOP');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my $class = shift;
    return $class->SUPER::new( name => 'istopic', prec => 600 );
}

sub evaluate {
    my $this    = shift;
    my $node    = shift;
    my $a       = $node->{params}->[0];
    my %domain  = @_;
    my $session = $domain{tom}->session;
    throw Error::Simple(
        'No context in which to evaluate "' . $a->stringify() . '"' )
      unless $session;
    my ( $web, $topic ) = ( $session->{webName}, $a->_evaluate(@_) );

    return 0
      unless ( defined $topic && length($topic) )
      ;    # null/empty topic cannot possibly exist
    return 0
      if ( $topic eq '0' ); # special case, topic name '0' normalizes to WebHome

    ( $web, $topic ) = $session->normalizeWebTopicName( $web, $topic );

    return $session->topicExists( $web, $topic ) ? 1 : 0;
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
