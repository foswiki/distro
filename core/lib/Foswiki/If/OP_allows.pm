# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::If::OP_allows
Test that the topic name on the LHS allows the access mode on the RHS.

=cut

package Foswiki::If::OP_allows;

use strict;
use warnings;

use Foswiki::Query::OP ();
our @ISA = ('Foswiki::Query::OP');

use Assert;
use Foswiki::Meta ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my $class = shift;
    return $class->SUPER::new( arity => 2, name => 'allows', prec => 600 );
}

sub evaluate {
    my $this    = shift;
    my $node    = shift;
    my $a       = $node->{params}->[0];          # topic name (string)
    my $b       = $node->{params}->[1];          # access mode (string)
    my $mode    = $b->_evaluate(@_) || 'view';
    my %domain  = @_;
    my $session = $domain{tom}->session;
    throw Error::Simple(
        'No context in which to evaluate "' . $a->stringify() . '"' )
      unless $session;

    my $str = $a->evaluate(@_);
    return 0 unless $str;

    my ( $web, $topic ) =
      $session->normalizeWebTopicName( $session->{webName}, $str );

    my $ok = 0;

    # Try for an existing topic first.
    if ( $session->topicExists( $web, $topic ) ) {

        my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
        $ok = $topicObject->haveAccess($mode);
    }

    # Not an existing web.topic name, see if the string on its own
    # is a web name
    elsif ( $session->webExists($str) ) {
        my $webObject = Foswiki::Meta->new( $session, $str );
        $ok = $webObject->haveAccess($mode);
    }

    # Not an existing web.topic or a web on it's own; maybe it's
    # web.topic for an existing web but non-existing topic
    elsif ( $session->webExists($web) ) {
        my $webObject = Foswiki::Meta->new( $session, $web );
        $ok = $webObject->haveAccess($mode);
    }
    else {
        $ok = 0;
    }
    return $ok ? 1 : 0;
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
