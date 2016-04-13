# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::If::OP_allows
Test that the topic name on the LHS allows the access mode on the RHS.

=cut

package Foswiki::If::OP_allows;
use v5.14;

use Assert;
use Foswiki::Meta ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Infix::OP);
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
    return $orig->( $class, arity => 2, name => 'allows', prec => 600 );
};

sub evaluate {
    my $this   = shift;
    my $node   = shift;
    my $a      = $node->params->[0];            # topic name (string)
    my $b      = $node->params->[1];            # access mode (string)
    my $mode   = $b->_evaluate(@_) || 'view';
    my %domain = @_;
    my $app    = $domain{tom}->app;
    Foswiki::Exception->throw(
        text => 'No context in which to evaluate "' . $a->stringify() . '"' )
      unless $app;
    my $req = $app->request;

    my $str = $a->evaluate(@_);
    return 0 unless $str;

    my ( $web, $topic ) = $req->normalizeWebTopicName( $req->web, $str );

    my $ok = 0;

    # Try for an existing topic first.
    if ( $app->store->topicExists( $web, $topic ) ) {

        my $topicObject = Foswiki::Meta->new(
            app   => $app,
            web   => $web,
            topic => $topic
        );
        $ok = $topicObject->haveAccess($mode);
    }

    # Not an existing web.topic name, see if the string on its own
    # is a web name
    elsif ( $app->store->webExists($str) ) {
        my $webObject = Foswiki::Meta->new( app => $app, web => $str );
        $ok = $webObject->haveAccess($mode);
    }

    # Not an existing web.topic or a web on it's own; maybe it's
    # web.topic for an existing web but non-existing topic
    elsif ( $app->store->webExists($web) ) {
        my $webObject = $this->create( 'Foswiki::Meta', web => $web );
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
